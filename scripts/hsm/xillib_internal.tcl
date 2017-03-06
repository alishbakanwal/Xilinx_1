
namespace eval ::hsi::__internal {
}

proc ::hsi::__internal::dep_msg { older_proc new_proc args } {
    puts "INFO:\[hsi-utils-101\] \"$older_proc\" tcl procedure is deprecated, use \"hsi::utils::$new_proc $args\" instead"
    #error "ERROR:\[hsi-utils-101\] \"$older_proc\" tcl procedure is deprecated, use \"hsi::utils::$new_proc $args\" instead"
}

#
#TODO: Currently exported xml does not have internal interrupt connectivity for ps7 
# internal IPs so for the time being, this hard coding is placed. It will be removed
# once the internal interrupt connectivy is exposed in exported xml file.
#
proc ::hsi::__internal::special_handling_for_ps7_interrupt { periph_name} {

    set periph [::hsi::get_cells -hier "$periph_name"]
    if { [llength $periph] != 1}  {
        return $ret
    }

    #current processor should be ps7_cortexa9
    set sw_core [::hsi::get_sw_processor]
    set proc_name [common::get_property HW_INSTANCE $sw_core]
	if { [llength $proc_name] != 0 } {
    set hw_core [::hsi::get_cells -hier -filter "NAME==$proc_name" ]
    set proc_type [common::get_property IP_NAME $hw_core ]
    if { [string compare -nocase "$proc_type"  ps7_cortexa9] != 0} {
        return 0
    }
	}
    #peripheral should have driver list
	if { [llength $periph_name] != 0 } {
    set periph_driver [::hsi::get_drivers -filter "HW_INSTANCE==$periph_name"]
    if { [llength $periph_driver] != 1 } {
        return 0
    }
	}
    #peripheral name should have ps7 name 
    set ip_name [common::get_property IP_NAME $periph]
    if { [string match -nocase ps7* "$ip_name"] } {
        return 1
    }
    return 0
}

#It assume that XLCONCAT IP cell object is passed to this function
proc ::hsi::__internal::get_concat_interrupt_sources { concat_ip_obj } {
    lappend source_pins
    set num_ports [common::get_property CONFIG.NUM_PORTS $concat_ip_obj]
    for { set i 0 } { $i < $num_ports } { incr i } {
        set in_pin [::hsi::get_pins -of_objects $concat_ip_obj "In$i"]
        set pins [::hsi::utils::get_source_pins $in_pin]
        foreach pin $pins {
            set source_cell [::hsi::get_cells -of_objects $pin]
            if { [llength $source_cell] } {
                set ip_name [common::get_property IP_NAME $source_cell]
                #Cascading case of concat IP
                if { [string match -nocase $ip_name "xlconcat"] } {
                    set tmp_pins [::hsi::__internal::get_concat_interrupt_sources $source_cell]
                    foreach tmp_pin $tmp_pins {
                        lappend source_pins $tmp_pin
                    }
                } else {
                    lappend source_pins $pin
                }

            } else {
                lappend source_pins $pin
            }
        }
    }
    return $source_pins
}

proc ::hsi::__internal::get_intc_cascade_id_offset { intc } {
#proc get_intc_cascade_id_offset { intc } 
    set cascade_offset 0
    set cascade 0
    set intc_type [::common::get_property IP_NAME $intc]
    set intc_name [::common::get_property NAME $intc]
    set other_intc_periphs [::hsi::get_cells -hier -filter "NAME!=$intc_name&&IP_NAME==$intc_type"] 
    foreach other_intc_periph $other_intc_periphs {
        set intc_src_ports [::hsi::utils::get_interrupt_sources $other_intc_periph]
        set total_intr_count 0
        foreach src_port $intc_src_ports {
            set periph [::hsi::get_cells -of_objects $src_port]
            set intr_width [::hsi::utils::get_port_width $src_port]
            if { [llength $periph] } {
                if {[common::get_property IS_PL $periph] == 0} {
                    continue
                }
                set periph_name [::common::get_property NAME $periph]
                if { [string match -nocase "$periph_name" "$intc_name"] } {
                    set cascade 1
                }
            }
            set total_intr_count [expr $total_intr_count + $intr_width]
        }
        if { $cascade } {
            set cascade_offset [expr $total_intr_count + [::hsi::__internal::get_intc_cascade_id_offset $other_intc_periph] ]
            #set cascade_offset [expr $total_intr_count + [get_intc_cascade_id_offset $other_intc_periph] ]
            break;
        }
    }
    return $cascade_offset
}

#############################################################################

#############################################################################
# Deprecated TCL procs for backward compatibility
#############################################################################
proc xget_connected_intf { periph_name intf_name} {
    ::hsi::__internal::dep_msg xget_connected_intf get_connected_intf $periph_name $intf_name
    return [::hsi::utils::get_connected_intf $periph_name $intf_name]
}
proc xget_hw_port_value {ip_inst ip_pin} {
    ::hsi::__internal::dep_msg xget_hw_port_value get_net_name $ip_inst $ip_pin
    return [::hsi::utils::get_net_name $ip_inst $ip_pin]
}
proc xget_hw_busif_value {ip_inst ip_busif} {
    ::hsi::__internal::dep_msg xget_hw_busif_value get_intfnet_name $ip_inst $ip_busif
    return [::hsi::utils::get_intfnet_name $ip_inst $ip_busif]
}
proc xget_hw_proc_slave_periphs {proc_handle} {
    ::hsi::__internal::dep_msg xget_hw_proc_slave_periphs get_proc_slave_periphs $proc_handle
    return [::hsi::utils::get_proc_slave_periphs $proc_handle]
}
proc xget_ip_clk_pin_freq { cell_obj clk_port} {
    ::hsi::__internal::dep_msg xget_ip_clk_pin_freq get_clk_pin_freq $cell_obj $clk_port
    return [::hsi::utils::get_clk_pin_freq $cell_obj $clk_port]
}
proc is_external_pin { pin_obj } {
    ::hsi::__internal::dep_msg is_external_pin is_external_pin $pin_obj
    return [::hsi::utils::is_external_pin $pin_obj]
}
proc xget_port_width { port_handle} {
    ::hsi::__internal::dep_msg xget_port_width get_port_width $port_handle
    return [::hsi::utils::get_port_width $port_handle]
}
proc xget_interrupt_sources {periph_handle} {
    ::hsi::__internal::dep_msg xget_interrupt_sources get_interrupt_sources $periph_handle
    return [::hsi::utils::get_interrupt_sources $periph_handle]
}
proc xget_source_pins {periph_pin} {
    ::hsi::__internal::dep_msg xget_source_pins get_source_pins $periph_pin
    return [::hsi::utils::get_source_pins $periph_pin]
}
proc xget_sink_pins {periph_pin} {
    ::hsi::__internal::dep_msg xget_sink_pins get_sink_pins $periph_pin
    return [::hsi::utils::get_sink_pins $periph_pin]
}
proc xget_connected_pin_count { periph_pin } {
    ::hsi::__internal::dep_msg xget_connected_pin_count get_connected_pin_count $periph_pin
    return [::hsi::utils::get_connected_pin_count $periph_pin]
}
proc xget_param_value {periph_handle param_name} {
    ::hsi::__internal::dep_msg xget_param_value get_param_value $periph_handle $param_name
    return [::hsi::utils::get_param_value $periph_handle $param_name]
}
proc xget_p2p_name {periph arg} {
    ::hsi::__internal::dep_msg xget_p2p_name get_p2p_name $periph $arg
    return [::hsi::utils::get_p2p_name $periph $arg]
}
proc xget_procs { } {
    ::hsi::__internal::dep_msg xget_procs get_procs
    return [::hsi::utils::get_procs]
}
proc xget_port_interrupt_id { periph_name intr_port_name } {
    ::hsi::__internal::dep_msg xget_port_interrupt_id get_port_intr_id $periph_name $intr_port_name
    return [::hsi::utils::get_port_intr_id $periph_name $intr_port_name]
}
proc is_interrupt_controller { periph_name } {
    ::hsi::__internal::dep_msg is_interrupt_controller is_intr_cntrl $periph_name
    return [::hsi::utils::is_intr_cntrl $periph_name]
}
proc get_connected_interrupt_controller { periph_name intr_pin_name } {
    ::hsi::__internal::dep_msg get_connected_interrupt_controller get_connected_intr_cntrl $periph_name $intr_pin_name
    return [::hsi::utils::get_connected_intr_cntrl $periph_name $intr_pin_name]
}
proc get_ip_version { ip_name } {
    ::hsi::__internal::dep_msg get_ip_version get_ip_version $ip_name
    return [::hsi::utils::get_ip_version $ip_name]
}
proc get_ip_param_value { ip param} {
    ::hsi::__internal::dep_msg  get_ip_param_value get_ip_param_value $ip $param
    return [::hsi::utils::get_ip_param_value $ip $param]
}
proc get_board_name { } {
    ::hsi::__internal::dep_msg get_board_name get_board_name
    return [::hsi::utils::get_board_name]
}
proc get_trimmed_param_name { param } {
    ::hsi::__internal::dep_msg get_trimmed_param_name get_trimmed_param_name $param
    return [::hsi::utils::get_trimmed_param_name $param]
}
proc get_ip_sub_type { ip_inst_object} {
    ::hsi::__internal::dep_msg get_ip_sub_type get_ip_sub_type $ip_inst_object
    return [::hsi::utils::get_ip_sub_type $ip_inst_object]
}

#############################################################################
# Deprecated TCL procs for backward compatibility
#############################################################################
proc is_it_in_pl {ip} {
	set ip_type [common::get_property IP_NAME $ip]
	if {![regexp "ps7_*" "$ip_type" match]} {
		return 1
	}
	return -1
}
proc get_exact_arg_list { args } {
    ::hsi::__internal::dep_msg get_exact_arg_list get_exact_arg_list $args
    return [::hsi::utils::get_exact_arg_list $args]
}
proc xopen_include_file {file_name} {
    ::hsi::__internal::dep_msg xopen_include_file open_include_file $file_name
    return [::hsi::utils::open_include_file $file_name]
}
proc xget_name {periph_handle param} {
    ::hsi::__internal::dep_msg xget_name get_ip_param_name $periph_handle $param
    return [::hsi::utils::get_ip_param_name $periph_handle $param]
}
proc xget_dname {driver_name param} {
    ::hsi::__internal::dep_msg xget_dname get_driver_param_name $driver_name $param
    return [::hsi::utils::get_driver_param_name $driver_name $param]
}
proc xdefine_include_file {drv_handle file_name drv_string args} {
    #::hsi::__internal::dep_msg xdefine_include_file define_include_file $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_include_file $drv_handle $file_name $drv_string $args]
}
proc xdefine_zynq_include_file {drv_handle file_name drv_string args} {
    #::hsi::__internal::dep_msg xdefine_zynq_include_file define_zynq_include_file $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_zynq_include_file $drv_handle $file_name $drv_string $args]
}
proc xdefine_if_all {drv_handle file_name drv_string args} {
    ::hsi::__internal::dep_msg xdefine_if_all define_if_all $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_if_all $drv_handle $file_name $drv_string $args]
}
proc xdefine_max {drv_handle file_name define_name arg} {
    ::hsi::__internal::dep_msg xdefine_max define_max $drv_handle $file_name $define_name $arg
    return [::hsi::utils::define_max $drv_handle $file_name $define_name $arg]
}
proc xdefine_config_file {drv_handle file_name drv_string args} {
    #::hsi::__internal::dep_msg xdefine_config_file define_config_file $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_config_file $drv_handle $file_name $drv_string $args]
}
proc xdefine_zynq_config_file {drv_handle file_name drv_string args} {
    #::hsi::__internal::dep_msg xdefine_zynq_config_file define_zynq_config_file $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_zynq_config_file $drv_handle $file_name $drv_string $args]
}
proc xdefine_with_names {drv_handle periph_handle file_name args} {
    ::hsi::__internal::dep_msg xdefine_with_names define_with_names $drv_handle $periph_handle $file_name $args
    return [::hsi::utils::define_with_names $drv_handle $periph_handle $file_name $args]
}
proc xdefine_include_file_membank {drv_handle file_name args} {
    ::hsi::__internal::dep_msg xdefine_include_file_membank define_include_file_membank $drv_handle $file_name $args
    return [::hsi::utils::define_include_file_membank $drv_handle $file_name $args]
}
proc xdefine_membank { periph file_name args } {
    ::hsi::__internal::dep_msg xdefine_membank define_membank $periph $file_name $args
    return [::hsi::utils::define_membank $periph $file_name $args]
}
proc xfind_addr_params {periph} {
    ::hsi::__internal::dep_msg xfind_addr_params find_addr_params $periph
    return [::hsi::utils::find_addr_params $periph]
}
proc xdefine_addr_params {drv_handle file_name} {
    ::hsi::__internal::dep_msg xdefine_addr_params define_addr_params $drv_handle $file_name
    return [::hsi::utils::define_addr_params $drv_handle $file_name]
}
proc xdefine_all_params {drv_handle file_name} {
    ::hsi::__internal::dep_msg xdefine_all_params define_all_params $drv_handle $file_name
    return [::hsi::utils::define_all_params $drv_handle $file_name]
}
proc xdefine_canonical_xpars {drv_handle file_name drv_string args} {
    #::hsi::__internal::dep_msg xdefine_canonical_xpars define_canonical_xpars $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_canonical_xpars $drv_handle $file_name $drv_string $args]
}
proc xdefine_zynq_canonical_xpars {drv_handle file_name drv_string args} {
    #::hsi::__internal::dep_msg xdefine_zynq_canonical_xpars define_zynq_canonical_xpars $drv_handle $file_name $drv_string $args
    return [::hsi::utils::define_zynq_canonical_xpars $drv_handle $file_name $drv_string $args]
}
proc xdefine_processor_params {drv_handle file_name} {
    ::hsi::__internal::dep_msg xdefine_processor_params define_processor_params $drv_handle $file_name
    return [::hsi::utils::define_processor_params $drv_handle $file_name]
}
proc xget_ip_mem_ranges {periph} {
    ::hsi::__internal::dep_msg xget_ip_mem_ranges get_ip_mem_ranges $periph
    return [::hsi::utils::get_ip_mem_ranges $periph]
}
proc handle_stdin {drv_handle} {
    ::hsi::__internal::dep_msg handle_stdin handle_stdin $drv_handle
    return [::hsi::utils::handle_stdin $drv_handle]
}
proc handle_stdout {drv_handle} {
    ::hsi::__internal::dep_msg handle_stdout handle_stdout $drv_handle
    return [::hsi::utils::handle_stdout $drv_handle]
}
proc xget_sw_iplist_for_driver {driver_handle} {
    ::hsi::__internal::dep_msg xget_sw_iplist_for_driver get_common_driver_ips $driver_handle
    return [::hsi::utils::get_common_driver_ips $driver_handle]
}
proc is_interrupting_current_processor { periph_name intr_pin_name} {
    ::hsi::__internal::dep_msg is_interrupting_current_processor is_pin_interrupting_current_proc  $periph_name $intr_pin_name
    return [::hsi::utils::is_pin_interrupting_current_proc $periph_name $intr_pin_name]
}
proc get_current_processor_interrupt_controller { } {
    ::hsi::__internal::dep_msg get_current_processor_interrupt_controller get_current_proc_intr_cntrl]
    return [::hsi::utils::get_current_proc_intr_cntrl]
}
proc is_ip_interrupting_current_processor { periph_name} {
    ::hsi::__internal::dep_msg is_ip_interrupting_current_processor is_ip_interrupting_current_proc $periph_name
    return [::hsi::utils::is_ip_interrupting_current_proc $periph_name]
}

#############################################################################
# Deprecated TCL procs for backward compatibility
#############################################################################
proc xget_swverandbld { } {
    ::hsi::__internal::dep_msg xget_swverandbld get_sw_build_version
    return [::hsi::utils::get_sw_build_version]
}
proc xget_copyrightstr { } {
    ::hsi::__internal::dep_msg xget_copyrightstr get_copyright_msg
    return [::hsi::utils::get_copyright_msg]
}
proc xprint_generated_header {file_handle  desc} {
    ::hsi::__internal::dep_msg xprint_generated_header write_c_header
    return [::hsi::utils::write_c_header $file_handle  $desc]
}
proc xprint_generated_header_tcl {file_handle  desc} {
    ::hsi::__internal::dep_msg xprint_generated_header_tcl write_tcl_header $file_handle  $desc]
    return [::hsi::utils::write_tcl_header $file_handle  $desc]
}
proc xformat_addr_string {value param_name} {
    ::hsi::__internal::dep_msg xformat_addr_string format_addr_string $value $param_name
    return [::hsi::utils::format_addr_string $value $param_name]
}
proc xformat_address_string {value} {
    ::hsi::__internal::dep_msg xformat_address_string format_address_string $value
    return [::hsi::utils::format_address_string $value]
}
proc xconvert_binary_to_hex {value} {
    ::hsi::__internal::dep_msg xconvert_binary_to_hex convert_binary_to_hex $value]
    return [::hsi::utils::convert_binary_to_hex $value]
}
proc xconvert_binary_to_decimal { value } {
    ::hsi::__internal::dep_msg xconvert_binary_to_decimal convert_binary_to_decimal $value
    return [::hsi::utils::convert_binary_to_decimal $value]
}
proc xconvert_num_to_binary {value length} {
    ::hsi::__internal::dep_msg  xconvert_num_to_binary convert_num_to_binary $value $length
    return [::hsi::utils::convert_num_to_binary $value $length]
}
proc compare_unsigned_addr_strings {base_addr base_param high_addr high_param} {
    ::hsi::__internal::dep_msg compare_unsigned_addr_strings compare_unsigned_addresses $base_addr $base_param $high_addr $high_param
    return [::hsi::utils::compare_unsigned_addresses $base_addr $base_param $high_addr $high_param]
}
proc compare_unsigned_int_values {int_base int_high} {
    ::hsi::__internal::dep_msg  compare_unsigned_int_values compare_unsigned_int_values $int_base $int_high
    return [::hsi::utils::compare_unsigned_int_values $int_base $int_high]
}
proc xformat_tohex {value bitwidth direction} {
    ::hsi::__internal::dep_msg xformat_tohex format_to_hex $value $bitwidth $direction
    return [::hsi::utils::format_to_hex $value $bitwidth $direction]
}
proc xformat_tobin {value bitwidth direction} {
    ::hsi::__internal::dep_msg xformat_tobin format_to_bin $value $bitwidth $direction
    return [::hsi::utils::format_to_bin $value $bitwidth $direction]
}
proc xget_nameofexecutable { } {
    ::hsi::__internal::dep_msg xget_nameofexecutable get_nameofexecutable
    return [::hsi::utils::get_nameofexecutable]
}
proc xget_hostos_platform { } {
    ::hsi::__internal::dep_msg xget_hostos_platform get_hostos_platform
    return [::hsi::utils::get_hostos_platform]
}
proc xget_hostos_exec_suffix { } {
    ::hsi::__internal::dep_msg xget_hostos_exec_suffix get_hostos_exec_suffix
    return [::hsi::utils::get_hostos_exec_suffix]
}
proc xget_hostos_sharedlib_suffix { } {
    ::hsi::__internal::dep_msg xget_hostos_sharedlib_suffix get_hostos_sharedlib_suffix
    return [::hsi::utils::get_hostos_sharedlib_suffix]
}
proc xfind_file_in_dirs { dirlist relative_filepath } {
    ::hsi::__internal::dep_msg xfind_file_in_dirs find_file_in_dirs $dirlist $relative_filepath
    return [::hsi::utils::find_file_in_dirs $dirlist $relative_filepath]
}
proc xfind_file_in_xilinx_install { relative_filepath } {
    ::hsi::__internal::dep_msg xfind_file_in_xilinx_install find_file_in_xilinx_install $relative_filepath
    return [::hsi::utils::find_file_in_xilinx_install $relative_filepath]
}
proc xload_xilinx_library { libname } {
    ::hsi::__internal::dep_msg xload_xilinx_library load_xilinx_library $libname
    return [::hsi::utils::load_xilinx_library $libname]
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
