if { ![namespace exists ::math::bignum] } { package require math::bignum }

namespace eval ocl_block_utils {

proc get_max_kernels {} { return 16 }
proc get_max_axis {} { return 2 }

proc hip_update_boundary {} {
  #puts "DBG: hip_update_boundary START"
  #puts "DBG: current interfaces: {[get_bd_intf_ports -quiet]}"
  #puts "DBG: current ports: {[get_bd_ports -quiet]}"
  if { [llength [get_bd_intf_ports -quiet]] } {
    #puts "DBG: skipping port addition"
    return
  }
  delete_bd_objs -quiet [get_bd_ports -quiet]
  delete_bd_objs -quiet [get_bd_intf_ports -quiet]
  set obj [::ipxit::current_inst]
  set ocl_config_dict [get_ocl_config_dict $obj]
 
  #puts "DBG: ocl_config_dict=$ocl_config_dict"
  create_boundary $ocl_config_dict
}; # end hip_update_boundary

proc hip_update_contents {} {
  #puts "DBG: hip_update_contents START"
  set obj [::ipxit::current_inst]
  set ocl_config_dict [get_ocl_config_dict $obj]
  return [hip_build_contents $ocl_config_dict]
}; # end hip_update_contents

proc hip_build_contents {ocl_config_dict {kernels {}} {kernel_resources {}}} {
  if { [llength $kernels] == 0 } {
    set kernels [hip_get_kernels $ocl_config_dict]
  }
  set ocl_content_dict [create_contents $ocl_config_dict $kernels $kernel_resources]
  return [hip_extra_contents $ocl_config_dict $ocl_content_dict]
}; # end hip_build_contents

proc hip_get_kernels {ocl_config_dict} {
  set m_data_width     [dict get $ocl_config_dict M_DATA_WIDTH]
  set m_addr_width     [dict get $ocl_config_dict M_ADDR_WIDTH]
  set num_mi           [dict_get_default $ocl_config_dict NUM_MI 1]
  set user_width       [dict_get_default $ocl_config_dict USER_WIDTH 0]
  set num_kernels      [dict_get_default $ocl_config_dict NUM_KERNELS $num_mi]
  set kernel_type      [dict_get_default $ocl_config_dict KERNEL_TYPE "ADD_ONE"]
  set kernel_vlnv      [dict_get_default $ocl_config_dict KERNEL_VLNV {}]

  set k_id_width [get_kernel_id_width]
  set kernel_dict [dict create]
  set ip_config [list CONFIG.C_M_AXI_GMEM_DATA_WIDTH $m_data_width CONFIG.C_M_AXI_GMEM_ID_WIDTH $k_id_width]
  if { $m_addr_width > 32 } {
    lappend ip_config CONFIG.C_M_AXI_GMEM_ADDR_WIDTH $m_addr_width
  }
  set vlnv_prefix "xilinx.com:ip:"
  if { [string length $kernel_vlnv] && ![string equal -nocase "none" $kernel_vlnv] } {
    # Handle kernel_vlnv
    set vlnv_parts [llength [split [string trim $kernel_vlnv ":"] ":"]]
    if { $vlnv_parts == 1 } {
      set vlnv "${vlnv_prefix}$kernel_vlnv:*"
    } elseif { $vlnv_parts == 3 } {
      set vlnv "$kernel_vlnv:*"
    } elseif { $vlnv_parts < 4 } {
      xit::send_msg error 1000 "Unexpected kernel VLNV format: $kernel_vlnv"
      return
    } else {
      set vlnv $kernel_vlnv
    }

    # Make sure IP is avaiable
    set comps [ipx::get_cores -quiet -from catalog $vlnv]
    if { [llength $comps] == 0 } {
      send_msg error 1001 "No IP found that matched kernel VLNV: $vlnv"
      return
    } elseif { [llength $comps] > 1 } {
      send_msg error 1002 "More than one IP matched kernel VLNV: $vlnv"
      return
    }
    send_msg info 2000 "Using kernel IP [get_property vlnv $comps] [get_property xml_file_name $comps]"

    # Filter out unsupported properties
    set comp_ip_config {}
    foreach {pname pvalue} $ip_config {
      regsub -nocase "^CONFIG." $pname {} pname
      set param [ipx::get_user_parameters $pname -of $comps]
      if { [llength $param] != 1 } {
        continue
      }
      if { ![string equal -nocase "user" [get_property value_resolve_type $param]] } {
        continue
      }
      #send_msg info 9000 "$vlnv $pname: $param"
      lappend comp_ip_config CONFIG.$pname $pvalue
    }
    set ip_config $comp_ip_config
  } else {
    if { [string match -nocase "ADD_ONE" $kernel_type] } {
      set vlnv "${vlnv_prefix}ocl_axi_addone"
      if { $m_addr_width > 32 } {
        set vlnv_64 "${vlnv}64"
        set comps [ipx::get_cores -quiet -from catalog "$vlnv_64:*"]
        if { [llength $comps] } {
          send_msg info 2001 "Using 64-bit version of $kernel_type kernel"
          set vlnv $vlnv_64
        }
      }
    } elseif { [string match -nocase "FP_MMULT_256x256" $kernel_type] } {
      set vlnv "${vlnv_prefix}ocl_axi_fpmmult256x256"
    } elseif { [string match -nocase "SMITH_WATERMAN" $kernel_type] } {
      set vlnv "${vlnv_prefix}ocl_axi_smithwaterman"
    } else {
      error "Unsupported training kernel type: $kernel_type"
    }
  }
  dict set kernel_dict VLNV $vlnv
  dict set kernel_dict CONFIG $ip_config 
  dict set kernel_dict MASTER "m_axi_gmem"
  dict set kernel_dict SLAVE "s_axi_control"
  dict set kernel_dict CLK "ap_clk"
  dict set kernel_dict RST "ap_rst_n"

  set kernels {}
  for {set idx 0} {$idx < $num_kernels} {incr idx} {
    dict set kernel_dict NAME "kernel_$idx"
    lappend kernels $kernel_dict
  }
  return $kernels
}; # end hip_get_kernels

proc hip_extra_contents {ocl_config_dict ocl_content_dict} {
  set m_addr_width     [dict get $ocl_config_dict M_ADDR_WIDTH]
  set s_addr_width     [dict get $ocl_config_dict S_ADDR_WIDTH]
  set num_mi           [dict_get_default $ocl_config_dict NUM_MI 1]
  set num_kernels      [dict_get_default $ocl_config_dict NUM_KERNELS $num_mi]
  set enable_smartconnect [dict_get_default $ocl_config_dict ENABLE_SMARTCONNECT 0]

  set slvExt [get_bd_intf_ports [get_name_ext_si]]
  set vSS [lsort [get_bd_addr_segs -addressables -of_objects $slvExt]]
  set nSS [llength $vSS]
  if {$nSS < 1} {
    error "Did not find slave address segments for $slvExt"
  }
  if { $nSS != $num_kernels } {
    error "Expected number of slave address segments ($nSS) to match number of kernels ($num_kernels)"
  }

  set pretty_print false
  set addr_segs_pairs [addr::get_addr_seg_pairs $num_kernels $s_addr_width $pretty_print s_total_size]
  #puts "DBG: num_kernels=$num_kernels s_addr_width=$s_addr_width addr_segs_pairs=$addr_segs_pairs"
  set AS [get_bd_addr_spaces -of_objects $slvExt]
  for {set idx 0} {$idx < $nSS} {incr idx} {
    set SS [lindex $vSS $idx]
    lassign [lindex $addr_segs_pairs $idx] k_offset k_range
    set seg_name "ocl_slave_seg_$idx"
    #puts "!!! mapping $SS into $AS offset=$k_offset range=$k_range : $seg_name"
    create_bd_addr_seg -offset $k_offset -range $k_range $AS $SS $seg_name
  }

  if { $m_addr_width != 32 } {
    # Setup master addressing
    set bn_m_range [addr::pow [addr::fromdec 2] [addr::fromdec $m_addr_width]]
    #set bn_m_offset [addr:pow [addr:fromdec 2] [addr::fromdec [expr {max($s_addr_width, $m_addr_width)}]]]
    set bn_m_offset [addr::fromdec 0]
    set m_ext_names [get_names_ext_mi $num_mi]
    foreach m_ext_name $m_ext_names {
      set m_ext_ss_segs [get_bd_addr_segs -of_objects [get_bd_intf_ports $m_ext_name]]
      set m_offset [addr::tohex $bn_m_offset]
      set m_range  [addr::tohex $bn_m_range]

      #puts "INFO: assign_bd_address $m_ext_segs"
      #Assign this address as a master boundary address	
      #So it will not be modified to match the actual mappings into
      #the surface address space
      assign_bd_address $m_ext_ss_segs \
        -master_boundary    \
        -offset $m_offset   \
        -range  $m_range

      set m_excl_ms_segs [lsort [get_bd_addr_segs -excluded -of_objects $m_ext_ss_segs]]
      if { [llength $m_excl_ms_segs] } {
         #puts "INFO: include_bd_addr_seg $vEclMS"
         foreach excl_ms_seg $m_excl_ms_segs {
            include_bd_addr_seg $excl_ms_seg 
            set_property offset $m_offset $excl_ms_seg
            set_property range  $m_range  $excl_ms_seg
         }
      } 

      #set m_segs   [lsort [get_bd_addr_segs -of_objects $m_ext_segs]]
      #foreach seg $m_segs {
      #  set_property offset $m_offset $seg
      #  set_property range  $m_range  $seg
      #}
      #set bn_m_offset [addr::add $bn_m_offset $bn_m_range]
    }
  }

  set has_s_mem  [dict_get_default $ocl_config_dict HAS_S_MEM 0]
  if { $has_s_mem } {
    set s_mem_data_width [dict_get_default $ocl_config_dict S_MEM_DATA_WIDTH [dict get $ocl_config_dict S_DATA_WIDTH]]
    set clk_net [get_bd_net [dict get $ocl_content_dict clk_interconnect_net]]
    set rst_net [get_bd_net [dict get $ocl_content_dict rst_interconnect_sync_net]]
    set num_external_mems 1
    set s_mem_bridge_m_axi [create_mem_bridge $ocl_content_dict $ocl_config_dict $clk_net $rst_net $num_external_mems]

    # Create memory cells
    set mem_offset ""; set mem_range ""; set mem_ext_conns {}
    #set mem_range [addr::my_format [::math::bignum::pow [addr::fromdec 2] [addr::fromdec $s_mem_addr_width]]]
    #set mem_offset $s_total_size
    set s_mem_ctrl [connect_mem "s_mem" $clk_net $rst_net [list [get_bd_intf_pins $s_mem_bridge_m_axi]] $mem_offset $mem_range $s_mem_data_width $mem_ext_conns $enable_smartconnect]
    
    #show_all_addrs "DBG:BEFORE: "
    set s_mem_ctrl_seg [get_bd_addr_segs -of [get_bd_addr_spaces $s_mem_ctrl]]
    assign_bd_address $s_mem_ctrl_seg
    #show_all_addrs "DBG:AFTER: "
  }
  
  create_hip_pipes $ocl_config_dict "" $ocl_content_dict
}; # build_hip_contents

proc get_min_slave_addr_range {num_kernels addr_width pretty_print {total_size_name ""}} {
  if { $total_size_name ne "" } { upvar $total_size_name total_size }
  addr::get_addr_seg_pairs $num_kernels $addr_width $pretty_print total_size min_range
  return $min_range
}


proc get_name_intercon_si {idx} { return [format "S%.2d_AXI" $idx ] }
proc get_name_intercon_mi {idx} { return [format "M%.2d_AXI" $idx ] }

proc get_name_ext_interrupt_out {} { return "interrupts" }
proc get_name_ext_mi_num {idx} { return [format "M%.2d_AXI" $idx ] }
proc get_name_ext_mi {} { return "M_AXI" }
proc get_name_ext_si {} { return "S_AXI" }
proc get_name_ext_si2 {} { return "S_MEM" }

proc get_name_clk {} { return "ACLK" }
proc get_name_rst {} { return "ARESET" }
proc get_name_kernel_clk {} { return "KERNEL_CLK" }
proc get_name_kernel_rst {} { return "KERNEL_RESET" }
proc get_name_intercon_clk {} { return "INTERCONNECT_CLK" }
proc get_name_intercon_rst {} { return "INTERCONNECT_RESET" }

proc get_names_ext_mi {num_mi} {
  set res {}
  if { $num_mi <= 1 } {
   lappend res [get_name_ext_mi]
  } else {
    for {set idx 0} {$idx < $num_mi} {incr idx} {
      lappend res [get_name_ext_mi_num $idx]
    }
  }
  return $res
}

proc get_all_clock_names {ocl_config_dict} {
  set clk_names {}
  if { [dict get $ocl_config_dict HAS_KERNEL_CLOCK] } {
    lappend clk_names [get_name_kernel_clk] [get_name_intercon_clk]
  } else {
    lappend clk_names [get_name_clk]
  }
  foreach intf_name [get_axis_names $ocl_config_dict] {
    lappend clk_names [get_axis_clk_name $intf_name]
  }
  return $clk_names
}

proc create_interconnect {name props use_smart_connect has_second_clock} {
  set props_uc [string toupper $props]
  set new_props [filter_interconnect_props $use_smart_connect $props $has_second_clock]
  set vlnv [get_interconnect_vlnv $use_smart_connect]
  set intercon [create_bd_cell -type ip -vlnv $vlnv -name $name]
  set_property -dict $new_props $intercon
  return $intercon
}

proc get_interconnect_vlnv {use_smart_connect} {
  if { $use_smart_connect } {
    return "xilinx.com:ip:smartconnect"
  } else {
    return "xilinx.com:ip:axi_interconnect"
  }
}

proc filter_interconnect_props {use_smart_connect props has_second_clock} {
  if { !$use_smart_connect } {
    return $props
  }
  set res {}
  foreach {key val} $props {
    if { [string equal -nocase CONFIG.NUM_MI $key] || [string equal -nocase CONFIG.NUM_SI $key] } {
      lappend res $key $val
    }
  }
  if { $has_second_clock } {
    lappend res CONFIG.NUM_CLKS 2
  }
  return $res
}
proc use_smart_connect {use enable_smartconnect_param} {
  set val $enable_smartconnect_param

  set varname "SDACCEL_IP_SMARTCONNECT"
  if { [info exists ::env($varname)] } {
    set env_val $::env($varname)
    if { $env_val ne "" } {
      puts "INFO: using env($varname) value '$env_val' in place of smart connect enablement parameter value '$enable_smartconnect_param'"
      set val $env_val
    }
  }

  if { $val eq "1" || [string equal -nocase $val "true"] } {
    return true
  } elseif { $val eq "0" || [string equal -nocase $val "false"] } {
    return false  
  } elseif { ![regexp {^[01][01][01]*$} $val] } {
    error "Invalid value for smartconnect enablement: $val"
  }
  
  set numbits 4
  set use [string tolower $use]
  if {      $use eq "master" } {
    set right_index 0
  } elseif { $use eq "slave" } {
    set right_index 1
  } elseif { $use eq "mem" } {
    set right_index 2
  } elseif { $use eq "ext_mem" } {
    set right_index 3
  } else {
    puts "WARNING: unknown smart connect use: $use"
    return false
  }

  set vallen [string length $val]
  if { $vallen < $numbits } {
    set bits "[string repeat 0 [expr {$numbits - $vallen}]]$val"
  } elseif { $vallen > $numbits } {
    set bits [string range $val [expr {$vallen - $numbits}] end]
  } else {
    set bits $val
  }
  set left_index [expr {$numbits - 1 - $right_index}]
  set bit [string index $bits $left_index]
  return [expr {$bit eq 1}]
}; # end use_smart_connect

proc dict_get_default {adict key default} {
  if { [dict exists $adict $key] } {
    return [dict get $adict $key]
  }
  return $default
}

proc get_ocl_config_dict {obj} {
  set res [dict create]

  #set all_props {NUM_MI HAS_KERNEL_CLOCK SYNC_RESET M_DATA_WIDTH M_ADDR_WIDTH M_ID_WIDTH S_DATA_WIDTH S_ADDR_WIDTH USER_WIDTH HAS_INTERRUPT HAS_S_MEM S_MEM_ADDR_WIDTH S_MEM_DATA_WIDTH S_MEM_ID_WIDTH}
  set all_props [lsort -dictionary [lsearch -inline -nocase -all [list_property $obj] "CONFIG.*"]]
  foreach prop $all_props {
    if { ![string equal -nocase $prop "CONFIG.COMPONENT_NAME"] } {
      set value [get_property $prop $obj]
      regsub -nocase "^CONFIG." $prop {} prop
      dict set res $prop $value
    }
  }
  return $res
}

proc create_boundary {ocl_config_dict {all_ports_dict_name ""}} {
  if { $all_ports_dict_name ne "" } { upvar $all_ports_dict_name all_ports_dict }
  #puts "DBG: create_boundary START"
 
  set num_mi           [dict_get_default $ocl_config_dict NUM_MI 1]
  set has_kernel_clock [dict_get_default $ocl_config_dict HAS_KERNEL_CLOCK 0]
  set sync_reset       [dict_get_default $ocl_config_dict SYNC_RESET 0]
  set m_data_width     [dict get $ocl_config_dict M_DATA_WIDTH]
  set m_addr_width     [dict get $ocl_config_dict M_ADDR_WIDTH]
  set m_id_width       [dict_get_default $ocl_config_dict M_ID_WIDTH 0]
  set s_addr_width     [dict get $ocl_config_dict S_ADDR_WIDTH]
  set s_data_width     [dict_get_default $ocl_config_dict S_DATA_WIDTH $m_data_width]
  set user_width       [dict_get_default $ocl_config_dict USER_WIDTH 0]
  set has_s_mem           [dict_get_default $ocl_config_dict HAS_S_MEM 0]
  set has_interrupt       [dict_get_default $ocl_config_dict HAS_INTERRUPT 0]
  set s_mem_addr_width    [dict_get_default $ocl_config_dict S_MEM_ADDR_WIDTH $s_addr_width]
  set s_mem_data_width    [dict_get_default $ocl_config_dict S_MEM_DATA_WIDTH $s_data_width]
  set m_num_wr_outst 8
  set m_num_rd_outst 8

  set all_ports_dict [dict create]
  set mi_portnames [get_names_ext_mi $num_mi]
  foreach m_portname $mi_portnames {
    set m_intf [create_bd_intf_port -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode master $m_portname]
    set_property -dict [list CONFIG.PROTOCOL "AXI4" CONFIG.DATA_WIDTH $m_data_width CONFIG.ADDR_WIDTH $m_addr_width CONFIG.NUM_WRITE_OUTSTANDING $m_num_wr_outst CONFIG.NUM_READ_OUTSTANDING $m_num_rd_outst] $m_intf
    dict set all_ports_dict $m_portname $m_intf
  }
  set all_portnames $mi_portnames
  
  set s_name [get_name_ext_si]
  lappend all_portnames $s_name
  set s_intf [create_bd_intf_port -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode slave $s_name]
  set_property -dict [list CONFIG.PROTOCOL "AXI4LITE" CONFIG.DATA_WIDTH $s_data_width CONFIG.ADDR_WIDTH $s_addr_width] $s_intf
  dict set all_ports_dict $s_name $s_intf
 
  if { $has_s_mem } {
    set s_mem_name [get_name_ext_si2]
    lappend all_portnames $s_mem_name
    set s_mem_intf [create_bd_intf_port -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode slave $s_mem_name]
    set_property -dict [list CONFIG.PROTOCOL "AXI4" CONFIG.DATA_WIDTH $s_mem_data_width CONFIG.ADDR_WIDTH $s_mem_addr_width] $s_mem_intf
    dict set all_ports_dict $s_mem_name $s_mem_intf
  }

  if { $has_interrupt } {
    set upper [expr {[get_max_kernels] - 1}]
    set pin_name [get_name_ext_interrupt_out]
    set pin [create_bd_port -type intr -dir O -from $upper -to 0 $pin_name]
    dict set all_ports_dict $pin_name $pin
  }

  if { $has_kernel_clock } {
    set clk_name [get_name_intercon_clk]
    set rst_name [get_name_intercon_rst]
  } else { 
    set clk_name [get_name_clk]
    set rst_name [get_name_rst]
  }
  set clk [create_bd_port -type clk -dir I $clk_name]
  set rst [create_bd_port -type rst -dir I $rst_name]
  set_property CONFIG.ASSOCIATED_RESET $rst_name $clk
  dict set all_ports_dict $clk_name $clk 
  dict set all_ports_dict $rst_name $rst

  set_property CONFIG.ASSOCIATED_BUSIF [join $all_portnames :] $clk

  if { $has_kernel_clock } {
    set clk_name [get_name_kernel_clk]
    set rst_name [get_name_kernel_rst]
    set clk [create_bd_port -type clk -dir I $clk_name]
    set rst [create_bd_port -type rst -dir I $rst_name]
    set_property CONFIG.ASSOCIATED_RESET $rst_name $clk
    dict set all_ports_dict $clk_name $clk 
    dict set all_ports_dict $rst_name $rst
  }

  create_hip_pipes $ocl_config_dict all_ports_dict
  #puts "DBG: create_boundary END"
}; # create_boundary

proc get_bridge_vlnv {is_axi_lite boundary_version} {
  if { $boundary_version > 1 } {
    if { $is_axi_lite } {
      return "xilinx.com:ip:ocl_axilite_bridge:1.0"
    } else {
      return "xilinx.com:ip:ocl_axifull_bridge:1.0"
    } 
  } else {
    if { $is_axi_lite } {
      return "xilinx.com:ip:ocl_axi_slave_bridge:1.0"
    } else {
      return "xilinx.com:ip:ocl_axi_master_bridge:1.0"
    } 
  }
}; # end get_bridge_vlnv

proc create_contents {ocl_config_dict kernels {kernel_resources {}}} {
  set ocl_content_dict [dict create]
  #puts "DBG: create_contents START"

  set num_mi           [dict_get_default $ocl_config_dict NUM_MI 1]
  set has_kernel_clock [dict_get_default $ocl_config_dict HAS_KERNEL_CLOCK 0]
  set sync_reset       [dict_get_default $ocl_config_dict SYNC_RESET 0]
  set m_data_width     [dict get $ocl_config_dict M_DATA_WIDTH]
  set m_addr_width     [dict get $ocl_config_dict M_ADDR_WIDTH]
  set m_id_width       [dict_get_default $ocl_config_dict M_ID_WIDTH 0]
  set s_addr_width     [dict get $ocl_config_dict S_ADDR_WIDTH]
  set s_data_width     [dict_get_default $ocl_config_dict S_DATA_WIDTH $m_data_width]
  set user_width       [dict_get_default $ocl_config_dict USER_WIDTH 0]
  set has_s_mem        [dict_get_default $ocl_config_dict HAS_S_MEM 0]
  set has_interrupt    [dict_get_default $ocl_config_dict HAS_INTERRUPT 0]
  set boundary_version [dict_get_default $ocl_config_dict BOUNDARY_VERSION 0]
  set m_has_regslice   [dict_get_default $ocl_config_dict M_HAS_REGSLICE 4]; # default to 4 
  set s_has_regslice   [dict_get_default $ocl_config_dict S_HAS_REGSLICE 0]
  set has_burst        [dict_get_default $ocl_config_dict HAS_BURST 1]
  set enable_smartconnect [dict_get_default $ocl_config_dict ENABLE_SMARTCONNECT 0]
  set regslice_info_dict  [dict_get_default $ocl_config_dict REGSLICE_CONFIG_DICT {}]
  set tieoff_kernel_reset [dict_get_default $ocl_config_dict TIEOFF_KERNEL_RESET 0]
  if { $regslice_info_dict eq "none" } {
    set regslice_info_dict [dict create]
  }
 
  #puts "DBG: boundary_version=$boundary_version"

  # Create interconnects
  set m_intercon_prefix "m_axi_interconnect_"
  set mi_portnames [get_names_ext_mi $num_mi]
  #puts "DBG: m_intercon_props=$m_intercon_props mi_portnames=$mi_portnames"
  set m_use_sc [use_smart_connect "master" $enable_smartconnect]
  set m_conn_dict [get_master_conn_dict $mi_portnames $kernels [dict_get_default $kernel_resources CONNECTIONS {}] $m_intercon_prefix $m_data_width $m_has_regslice $m_use_sc $has_kernel_clock]
  set m_intercons [get_bd_cells ${m_intercon_prefix}*]
  #puts "DBG: found [llength $m_intercons] master interconnects: $m_intercons"
  set total_num_kernel_s_intfs 0
  foreach kernel_dict $kernels {
    set kernel_m_names [dict_get_default $kernel_dict MASTER {}]
    set kernel_s_names [dict_get_default $kernel_dict SLAVE {}]
    incr total_num_kernel_s_intfs [llength $kernel_s_names]
  }
  set s_intercon_props [list CONFIG.NUM_MI $total_num_kernel_s_intfs CONFIG.NUM_SI 1 CONFIG.XBAR_DATA_WIDTH $s_data_width]
  if { $s_has_regslice != 0 } {
    for {set idx 0} {$idx < $total_num_kernel_s_intfs} {incr idx} {
      lappend s_intercon_props CONFIG.[format "M%.2d" $idx]_HAS_REGSLICE $s_has_regslice
    }
  }
  #puts "DBG: s_intercon_props=$s_intercon_props"
  set s_use_sc [use_smart_connect "slave" $enable_smartconnect]
  set s_intercon [create_interconnect "s_axi_interconnect_0" $s_intercon_props $s_use_sc $has_kernel_clock]

  # Create clock and reset nets
  if { $has_kernel_clock } {
    set clk_intercon_name [get_name_intercon_clk]
    set rst_intercon_name [get_name_intercon_rst]
  } else {
    set clk_intercon_name [get_name_clk]
    set rst_intercon_name [get_name_rst]
  }
  if { $has_kernel_clock } {
    set clk_kernel_name [get_name_kernel_clk]
    set rst_kernel_name [get_name_kernel_rst]
    create_bd_net $clk_kernel_name
    create_bd_net $rst_kernel_name
  } else {
    set clk_kernel_name $clk_intercon_name 
    set rst_kernel_name $rst_intercon_name 
  }
  create_bd_net $clk_intercon_name
  create_bd_net $rst_intercon_name
  set clk_intercon [get_bd_ports $clk_intercon_name]
  set rst_intercon [get_bd_ports $rst_intercon_name]
  set clk_kernel [get_bd_ports $clk_kernel_name]
  set rst_kernel [get_bd_ports $rst_kernel_name]

  set intercon_sys_rst_name [expr {$has_kernel_clock ? "interconnect_sys_reset" : "sys_reset"}]
  set rst_intercon_sync_name $rst_intercon_name
  set rst_kernel_sync_name $rst_kernel_name

  # Create sys_reset cells and connect clocks and resets
  if { $sync_reset } {
    set intercon_sys_rst [create_bd_cell -name $intercon_sys_rst_name -vlnv xilinx.com:ip:proc_sys_reset:* -type ip]
    connect_bd_net -net $rst_intercon_name $rst_intercon [get_bd_pins $intercon_sys_rst/ext_reset_in]
    connect_bd_net -net $clk_intercon_name $clk_intercon [get_bd_pins $intercon_sys_rst/slowest_sync_clk]
    set rst_intercon [get_bd_pins $intercon_sys_rst/interconnect_aresetn]
    set rst_intercon_sync_name ${rst_intercon_name}_sync
    create_bd_net $rst_intercon_sync_name

    if { $has_kernel_clock } {
      set kernel_sys_rst [create_bd_cell -name kernel_sys_reset -vlnv xilinx.com:ip:proc_sys_reset:* -type ip]

      connect_bd_net -net $rst_kernel_name $rst_kernel [get_bd_pins $kernel_sys_rst/ext_reset_in]
      connect_bd_net -net $clk_kernel_name $clk_kernel [get_bd_pins $kernel_sys_rst/slowest_sync_clk]
      set rst_kernel [get_bd_pins $kernel_sys_rst/interconnect_aresetn]
      set rst_kernel_sync_name ${rst_kernel_name}_sync
      create_bd_net $rst_kernel_sync_name
    } else {
      set rst_kernel $rst_intercon
      set rst_kernel_sync_name $rst_intercon_sync_name
    }
  }

  dict set ocl_content_dict clk_kernel_net $clk_kernel_name
  dict set ocl_content_dict rst_kernel_net $rst_kernel_name
  dict set ocl_content_dict rst_kernel_sync_net $rst_kernel_sync_name
  dict set ocl_content_dict clk_interconnect_net $clk_intercon_name
  dict set ocl_content_dict rst_interconnect_net $rst_intercon_name
  dict set ocl_content_dict rst_interconnect_sync_net $rst_intercon_sync_name

  dict set ocl_content_dict clk_kernel $clk_kernel
  dict set ocl_content_dict rst_kernel $rst_kernel
  dict set ocl_content_dict clk_interconnect $clk_intercon
  dict set ocl_content_dict rst_interconnect $rst_intercon
  dict set ocl_content_dict slave_interconnect $s_intercon
  dict set ocl_content_dict master_interconnects $m_intercons

  # Connect interconnect clock(s) and reset(s)
  set k_reset_connected false
  if { $s_use_sc } {
    if { $s_intercon ne "" } {
      connect_bd_net -net $clk_intercon_name      $clk_intercon  [get_bd_pins $s_intercon/aclk] 
      connect_bd_net -net $rst_intercon_sync_name $rst_intercon  [get_bd_pins $s_intercon/aresetn]
      if { $has_kernel_clock } {
        connect_bd_net -net $clk_kernel_name        $clk_kernel    [get_bd_pins $s_intercon/aclk1] 
      }
    }
  } else {
    connect_bd_net -net $clk_intercon_name      $clk_intercon  [get_bd_pins $s_intercon/S*_ACLK] 
    connect_bd_net -net $rst_intercon_sync_name $rst_intercon  [get_bd_pins $s_intercon/S*_ARESETN]
    connect_bd_net -net $clk_kernel_name        $clk_kernel    [get_bd_pins $s_intercon/ACLK] [get_bd_pins $s_intercon/M*_ACLK] 
    connect_bd_net -net $rst_kernel_sync_name   $rst_kernel    [get_bd_pins $s_intercon/ARESETN] [get_bd_pins $s_intercon/M*_ARESETN]  
    set k_reset_connected true
  }
  set m_has_sc false
  foreach m_intercon $m_intercons {
    set m_inst_use_sc [string match -nocase "*smart*" [get_property vlnv $m_intercon]]
    if { $m_inst_use_sc } {
      set m_has_sc true
      connect_bd_net -net $clk_intercon_name      $clk_intercon  [get_bd_pins $m_intercon/aclk] 
      connect_bd_net -net $rst_intercon_sync_name $rst_intercon  [get_bd_pins $m_intercon/aresetn]  
      if { $has_kernel_clock } {
        connect_bd_net -net $clk_kernel_name        $clk_kernel    [get_bd_pins $m_intercon/aclk1]
      }
    } else {
      connect_bd_net -net $clk_intercon_name      $clk_intercon  [get_bd_pins $m_intercon/M*_ACLK]  
      connect_bd_net -net $rst_intercon_sync_name $rst_intercon  [get_bd_pins $m_intercon/M*_ARESETN] 
      connect_bd_net -net $clk_kernel_name        $clk_kernel    [get_bd_pins $m_intercon/ACLK]    [get_bd_pins $m_intercon/S*_ACLK]
      connect_bd_net -net $rst_kernel_sync_name   $rst_kernel    [get_bd_pins $m_intercon/ARESETN] [get_bd_pins $m_intercon/S*_ARESETN]   
      set k_reset_connected true
    }
  }
  if { $has_kernel_clock && !$k_reset_connected } {
    connect_bd_net -net $rst_kernel_sync_name   $rst_kernel
  }
  
  set kernel_rst_src $rst_kernel_sync_name
  if { $tieoff_kernel_reset } {
    set reset_tieoff_name "reset_tieoff_high"
    set reset_tieoff_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant $reset_tieoff_name]
    set_property -dict [list CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 1] $reset_tieoff_cell
    set kernel_rst_src "${reset_tieoff_name}_net"
    create_bd_net $kernel_rst_src
    connect_bd_net -net $kernel_rst_src [get_bd_pins -of $reset_tieoff_cell]
  }

  # Create & connect kernels
  set kernel_count 0
  set kernel_m_count -1
  set kernel_s_count -1
  set kernel_insts {}
  foreach kernel_dict $kernels {
    set vlnv [dict get $kernel_dict VLNV]
    set kernel_name [dict get $kernel_dict NAME]
    set config [dict_get_default $kernel_dict CONFIG {}]
    set kernel_s_names [dict_get_default $kernel_dict SLAVE {}]
    set kernel_clk_names [dict_get_default $kernel_dict CLK {}]
    set kernel_rst_names [dict_get_default $kernel_dict RST {}]

    set inst [create_bd_cell -name $kernel_name -vlnv $vlnv -type ip]
    set inst_dict $kernel_dict
    dict set inst_dict cell $inst
    lappend kernel_insts $inst_dict
    set config [get_burst_cell_config $has_burst $config $inst]
    if { [llength $config] } {
      set_property -dict $config $inst
    }

    # Connect s_intercon
    foreach kernel_s_name $kernel_s_names {
      set intercon_intf_name [get_name_intercon_mi [incr kernel_s_count]]
      #puts "connect_bd_intf_net [get_bd_intf_pins $s_intercon/$intercon_intf_name] [get_bd_intf_pins $inst/$kernel_s_name]  ; # kernel_s_count=$kernel_s_count"
      set k_slave_intf [get_bd_intf_pins -quiet $inst/$kernel_s_name]
      if { ![llength $k_slave_intf] } {
        error "ERROR: Missing expected kernel interface '$inst/$kernel_s_name'.  Current interfaces are: [get_bd_intf_pins $inst/*]"
      }
      if { $s_intercon ne "" } {
        connect_opt_regslice "s_kernel" "${kernel_name}_${kernel_s_name}" $regslice_info_dict [get_bd_intf_pins $s_intercon/$intercon_intf_name] $k_slave_intf $clk_kernel_name $rst_kernel_sync_name
      }
    }

    set kernel_m_names [dict_get_default $kernel_dict MASTER {}]
    foreach kernel_m_name $kernel_m_names {
      set m_conn_key [string toupper "KERNEL/$kernel_name/$kernel_m_name"]
      if { ![dict exists $m_conn_dict $m_conn_key] } {
        error "ERROR: missing connection to '$kernel_name' kernel port '$kernel_m_name'"
      }
      set intercon_pin [dict get $m_conn_dict $m_conn_key]
      set k_master_intf [get_bd_intf_pins -quiet $inst/$kernel_m_name]
      if { $intercon_pin ne "" } {
        #puts "DBG: kernel $inst intercon_pin=$intercon_pin k_master_intf=$k_master_intf get_bd_intf_pins: [get_bd_intf_pins $inst/*]"
        if { ![llength $k_master_intf] } {
          error "ERROR: Missing expected kernel interface '$inst/$kernel_m_name'.  Current interfaces are: [get_bd_intf_pins $inst/*]"
        }
        connect_opt_regslice "m_kernel" "${kernel_name}_${kernel_m_name}" $regslice_info_dict $k_master_intf [get_bd_intf_pins $intercon_pin] $clk_kernel_name $rst_kernel_sync_name
      }
    }

    set connected_clk false
    foreach pin_name $kernel_clk_names {
      set kernel_pin [get_bd_pins -quiet $inst/$pin_name]
      if { [llength $kernel_pin] } {
        set connected_clk true
        connect_bd_net -net $clk_kernel_name $clk_kernel $kernel_pin
      }
    }
    if { !$connected_clk } {
      set other_pin [get_bd_pins -quiet -of_objects $inst -filter {TYPE == clk}]
      if { [llength $other_pin] } {
        connect_bd_net -net $clk_kernel_name $other_pin
      } else {
        error "Cannot find clock pin on kernel $inst"
      }
    }

    set connected_rst false
    foreach pin_name $kernel_rst_names {
      set kernel_pin [get_bd_pins -quiet $inst/$pin_name]
      if { [llength $kernel_pin] } {
        set connected_rst true
        connect_bd_net -net $kernel_rst_src $kernel_pin
      }
    }
    if { !$connected_rst } {
      set other_pin [get_bd_pins -quiet -of_objects $inst -filter {TYPE == rst}]
      if { [llength $other_pin] } {
        connect_bd_net -net $kernel_rst_src $other_pin
      } else {
        error "Cannot find reset pin on kernel $inst"
      }
    }
  }; # end kernels loop
 
  # Connect interrupts
  if { $has_interrupt } { 
    set max [get_max_kernels]
    set num_kernels [llength $kernel_insts]

    set intr_concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:* interrupt_concat]
    set_property -dict [list CONFIG.NUM_PORTS $max] $intr_concat

    set const_zero_cell ""
    for {set ii 0} {$ii < $max} {incr ii} {
      set k_intr_pin ""
      if { $ii < $num_kernels } {
        set k_dict [lindex $kernel_insts $ii]
        set k_cell [dict get $k_dict cell]
        set k_pins [get_bd_pins -quiet $k_cell/interrupt -filter {DIR==O}]
        if { [llength $k_pins] == 1 } {
          set k_intr_pin $k_pins
        } elseif { [llength $k_pins] == 0 } {
          puts "WARNING: no output interrupt pin on kernel $k_cell"
        } else {
          puts "WARNING: found more than one output interrupt pin on kernel $k_cell"
        }
      }
      if { $k_intr_pin eq "" } {
        if { $const_zero_cell eq "" } {
          set const_zero_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* constant_zero]
        }
        set k_intr_pin "$const_zero_cell/dout"
      }
      connect_bd_net [get_bd_pins $intr_concat/In$ii] [get_bd_pins $k_intr_pin]
    }
    connect_bd_net [get_bd_pins $intr_concat/dout] [get_bd_ports [get_name_ext_interrupt_out]]
  }

  # Create and connect slave bridge
  set lite_bridge_vlnv [get_bridge_vlnv true $boundary_version]
  set s_portname [get_name_ext_si]
  set s_bridge [create_bd_cell -name slave_bridge -vlnv $lite_bridge_vlnv -type ip]
  dont_touch $s_bridge
  dict set ocl_content_dict slave_bridge $s_bridge
  dict set ocl_content_dict $s_portname $s_bridge/s_axi
  
  set s_bridge_config [list CONFIG.ADDR_WIDTH $s_addr_width CONFIG.DATA_WIDTH $s_data_width]
  set s_bridge_config [get_burst_cell_config $has_burst $s_bridge_config $s_bridge]
  set_property -dict $s_bridge_config $s_bridge
  set m_axi_bridge [get_bd_intf_pins $s_bridge/m_axi]
  if { $s_intercon eq "" } {
    connect_bd_intf_net $m_axi_bridge [get_bd_intf_pins $k_slave_intf]
  } else {
    connect_opt_regslice "s_bridge" "s_bridge" $regslice_info_dict $m_axi_bridge [get_bd_intf_pins $s_intercon/[get_name_intercon_si 0]] $clk_intercon_name $rst_intercon_sync_name
  }
  set res [create_bd_intf_net $s_portname]
  connect_bd_intf_net -intf_net $s_portname [get_bd_intf_ports $s_portname] [get_bd_intf_pins $s_bridge/s_axi]
  connect_bd_net -net $clk_intercon_name [get_bd_pins $s_bridge/aclk] 
  connect_bd_net -net $rst_intercon_sync_name [get_bd_pins $s_bridge/aresetn]

  set s_mem_intf ""
  if { $has_s_mem } {
    set s_mem_intf [get_name_ext_si2]
  }
  dict set ocl_content_dict s_mem_intf $s_mem_intf


  # Create and connect master bridge(s) 
  set full_bridge_vlnv [get_bridge_vlnv false $boundary_version]
  set m_bridge_count 0
  set core_conn_count 0
  foreach mi_portname $mi_portnames {
    set cell_name "master_bridge_$m_bridge_count"
    set m_bridge [create_bd_cell -name $cell_name -vlnv $full_bridge_vlnv -type ip]
    dont_touch $m_bridge
    incr m_bridge_count
    set m_bridge_m_axi $m_bridge/m_axi
    dict set ocl_content_dict master_bridge $m_bridge
    dict set ocl_content_dict $mi_portname $m_bridge_m_axi
    set m_conn_key [string toupper "CORE/$mi_portname"]
    set num_conn 0
    if { [dict exists $m_conn_dict $m_conn_key] } {
      set m_conn_core_dict [dict get $m_conn_dict $m_conn_key]
      set num_conn [dict get $m_conn_core_dict NUM_CONN]
      incr core_conn_count $num_conn
    }
    set m_bridge_s_id_width 1
    if { $num_conn >= 1 } {
      set m_bridge_s_id_width [expr ([::tcl::mathfunc::int [::tcl::mathfunc::ceil [expr [::tcl::mathfunc::log $num_conn] / [::tcl::mathfunc::log 2]]]] + 1)]
    }
    
    set m_bridge_config [list CONFIG.ADDR_WIDTH $m_addr_width CONFIG.DATA_WIDTH $m_data_width CONFIG.M_ID_WIDTH $m_id_width CONFIG.S_ID_WIDTH $m_bridge_s_id_width CONFIG.HAS_SLAVE_ID 1]
    set m_bridge_config [get_burst_cell_config $has_burst $m_bridge_config $m_bridge]
    set_property -dict $m_bridge_config $m_bridge
    create_bd_intf_net $mi_portname
    connect_bd_intf_net -intf_net $mi_portname [get_bd_intf_ports $mi_portname] [get_bd_intf_pins $m_bridge_m_axi]
    connect_bd_net -net $clk_intercon_name [get_bd_pins $m_bridge/aclk] 
    connect_bd_net -net $rst_intercon_sync_name [get_bd_pins $m_bridge/aresetn] 
    if { $num_conn < 1 } {
      terminate_intf $m_bridge/s_axi
      #dont_touch [get_bd_nets /net_name]
    } else {
      set m_bridge_pin [dict get $m_conn_core_dict BRIDGE_PIN]
      connect_opt_regslice "m_bridge" $cell_name $regslice_info_dict [get_bd_intf_pins $m_bridge_pin] [get_bd_intf_pins $m_bridge/s_axi] $clk_intercon_name $rst_intercon_sync_name
    }
  }

  if { $core_conn_count == 0 } {
    puts "WARNING: no connections to core master ports were found: $mi_portnames"
  }
      
  #puts "DBG: create_contents DONE"
  
  dict set ocl_content_dict kernels $kernel_insts
  return $ocl_content_dict
}; # create_contents

proc connect_opt_regslice {loc_key loc_name regslice_info_dict lhs_intf rhs_intf clk_net rst_net} {
  #puts "DBG: connect_opt_regslice $loc_key $loc_name lhs_intf=$lhs_intf rhs_intf=$rhs_intf"
  set regslice_configs [dict_get_default $regslice_info_dict $loc_key {}]
  set next_intf $lhs_intf
  set num 0
  foreach config $regslice_configs {
    set regslice [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice axi_register_slice_${loc_name}_$num]
    connect_bd_intf_net $next_intf [get_bd_intf_pins $regslice/S_AXI]
    if { [llength $config] } {
      set_property -dict $config $regslice
    }
    connect_bd_net -net $clk_net [get_bd_pins $regslice/aclk]
    connect_bd_net -net $rst_net [get_bd_pins $regslice/aresetn]
    set next_intf [get_bd_intf_pins $regslice/M_AXI]
    incr num
  }
  connect_bd_intf_net $next_intf $rhs_intf
}; # connect_opt_regslice

proc get_burst_cell_config {has_burst config cell_obj} {
  set param CONFIG.HAS_BURST
  if { $cell_obj ne "" } {
    if { ![llength [list_property $cell_obj $param]] } {
      #puts "DBG: get_burst_cell_config: object does not support $param: $cell_obj"
      return $config
    }
  }
  if { !$has_burst } {
    #puts "DBG: ocl_block get_burst_cell_config: has_burst=$has_burst $cell_obj"
    lappend config $param 0
  }
  return $config
}; # end get_burst_cell_config

proc match_conn {match_type match_name match_port curr_type curr_name curr_port} {
  if { $match_type ne "" && $curr_type ne "" && ![string match -nocase $match_type $curr_type] } {
    #puts "DBG: match_conn fail: $match_type != $curr_type"
    return false
  }
  if { $match_name ne "" && ![string match -nocase $match_name $curr_name] } {
    #puts "DBG: match_conn fail: $match_name != $curr_name"
    return false
  }
  if { $match_port ne "" && ![string match -nocase $match_port $curr_port] } {
    #puts "DBG: match_conn fail: $match_port != $curr_port"
    return false
  }
  return true
}; # match_conn

proc show_dict {adict {prefix "  "}} {
  foreach key [lsort -dictionary [dict keys $adict]] {
    puts "${prefix}$key = [dict get $adict $key]"
  }
}

proc __get_conns {user_conns return_value_mode match_type match_name match_port} {
  if { ![llength $user_conns] } {
    return {}
  }
  set match_sides {DST SRC}
  if { [lsearch -glob [dict keys [lindex $user_conns 0]] "SRC_*"] < 0 } {
    set match_sides {MATCH OTHER}
  }
  set matched_conns {}
  set all_keys {TYPE NAME PORT}
  set other_side_dict [dict create DST SRC   SRC DST   MATCH OTHER   OTHER MATCH]
  foreach conn_dict $user_conns {
    set SRC_TYPE ""
    set DST_TYPE ""
    dict with conn_dict {
      foreach match_side $match_sides {
        set other_side [dict get $other_side_dict $match_side]
        set match_dict [dict create SIDE $match_side]
        set other_dict [dict create SIDE $other_side]
        set both_dict  [dict create]
        foreach key $all_keys {
          set match_val [set ${match_side}_$key]
          set other_val [set ${other_side}_$key]
          dict set match_dict $key $match_val
          dict set other_dict $key $other_val
          set CURR_$key $match_val; # set variable for comparison
          dict set both_dict MATCH_$key $match_val
          dict set both_dict OTHER_$key $other_val
        }
        if { [match_conn $match_type $match_name $match_port $CURR_TYPE $CURR_NAME $CURR_PORT] } {
          if { $return_value_mode == 0 } {
            # Return original conn_dict
            dict set conn_dict MATCH_SIDE $match_side
            dict set conn_dict OTHER_SIDE $other_side
            lappend matched_conns $conn_dict
          } elseif { $return_value_mode == 1 } {
            # Return other side
            lappend matched_conns $other_dict
          } elseif { $return_value_mode == 2 } {
            # Return match side
            lappend matched_conns $match_dict
          } elseif { $return_value_mode == 3 } {
            # Return both sides
            lappend matched_conns $both_dict
          } else {
            error "Unknown return_value_mode: $return_value_mode"
          }
          break
        }
      }
    }
  }
  return $matched_conns
}; # end __get_conns

proc filter_conns {user_conns match_type {match_name ""} {match_port ""}} {
  # Return same structure as input user_conns but filtered
  set return_value_mode 0
  return [__get_conns $user_conns $return_value_mode $match_type $match_name $match_port]
}; # end filter_conns

proc get_conn_other_sides {user_conns match_type {match_name ""} {match_port ""}} {
  # Return list of other side
  set return_value_mode 1
  return [__get_conns $user_conns $return_value_mode $match_type $match_name $match_port]
}

proc get_conn_match_sides {user_conns match_type {match_name ""} {match_port ""}} {
  # Return list of matched side
  set return_value_mode 2
  return [__get_conns $user_conns $return_value_mode $match_type $match_name $match_port]
}

proc get_conn_matches {user_conns match_type {match_name ""} {match_port ""}} {
  # Return list of conns but instead of SRC and DST prefix it has MATCH and OTHER
  set return_value_mode 3
  return [__get_conns $user_conns $return_value_mode $match_type $match_name $match_port]
}

proc get_conn_side {conn side} {
  if { ![string equal -nocase "SRC" $side] && ![string equal -nocase "DST" $side] && ![string equal -nocase "MATCH" $side] && ![string equal -nocase "OTHER" $side] } {
    error "Illegal get_conn_side side '$side' should be SRC, DST, MATCH or OTHER"
  }
  set side [string toupper $side]
  set res [dict create SIDE $side]
  dict for {key val} $conn {
    if { [regsub "^${side}_" $key {} bare_key] } {
      dict set res $bare_key $val
    }
  }
  return $res
}; # end get_conn_side

proc filter_conn_sides {conns match_type {match_name ""} {match_port ""} {match_side ""}} {
  # filter list of sides 
  set matched_conns {}
  foreach conn_dict $conns {
    dict with conn_dict {
      if { [match_conn $match_type $match_name $match_port $TYPE $NAME $PORT] } {
        if { $match_side eq "" || [string match -nocase $match_side $SIDE] } {
          lappend matched_conns $conn_dict
        }
      }
    }
  }
  return $matched_conns
}; # end filter_conn_sides

proc get_master_conn_dict {mi_portnames kernels user_conns m_intercon_prefix m_data_width m_has_regslice m_use_sc has_kernel_clock} {
  #puts "DBG: all connections: $user_conns"
  set m_conn_dict [dict create]
  set num_mi_portnames [llength $mi_portnames]
  set mi_portnames_uc [string toupper $mi_portnames]  

  # Create variables to store assigned and unassigned kernel to master connections
  set unassigned_k_ports {}
  set assigned_k_ports {}
  foreach mi_portname $mi_portnames_uc {
    set assigned_k_ports_$mi_portname {}
  }

  set kernel_key_prefix "KERNEL/"

  # Go through all kernels and put all user connections between kernels and core masters into assigned list
  set k_port_count 0
  foreach kernel_dict $kernels {
    set kernel_name [dict get $kernel_dict NAME]
    set kernel_m_names [dict_get_default $kernel_dict MASTER {}]
    foreach kernel_m_name $kernel_m_names {
      set m_conn_key [string toupper "$kernel_key_prefix$kernel_name/$kernel_m_name"]
      if { [dict exists $m_conn_dict $m_conn_key] } {
        #puts "DBG: SKIPPING kernel master port '$kernel_name/$kernel_m_name' connections: [get_conn_other_sides $user_conns "kernel" $kernel_name $kernel_m_name]"
        continue
      }
      set k_conn_sides [get_conn_other_sides $user_conns "kernel" $kernel_name $kernel_m_name]
      set k_core_sides [filter_conn_sides $k_conn_sides "core"]
      set k_mi_portname ""
      if { [llength $k_core_sides] } {
        #puts "DBG: kernel master port '$kernel_name/$kernel_m_name' connections: $k_conn_sides"
        foreach mi_portname $mi_portnames {
          if { [llength [filter_conn_sides $k_core_sides "core" "" $mi_portname]] } {
            if { $k_mi_portname ne "" } {
              error "Found connection from kernel '$kernel_name/$kernel_m_name' to multiple master interfaces"
            }
            set k_mi_portname $mi_portname
          }
        }
        if { $k_mi_portname eq "" } {
          error "Unknown core port name for '$k_name' kernel connection: $k_core_sides"
        }
      }
      if { $k_mi_portname eq "" } {
        lappend unassigned_k_ports $m_conn_key
      } else {
        lappend assigned_k_ports_[string toupper $k_mi_portname] $m_conn_key
      }
    }
  }

  # Go through unassigned kernel ports and assign to port with fewest connections
  foreach m_conn_key $unassigned_k_ports {
    set min_conn_portname ""
    set min_assigned {}
    foreach mi_portname $mi_portnames_uc {
      set curr_assigned [set assigned_k_ports_$mi_portname]
      if { $min_conn_portname eq "" || [llength $curr_assigned] < [llength $min_assigned] } {
        set min_conn_portname $mi_portname
        set min_assigned $curr_assigned 
      }
    }
    lappend assigned_k_ports_$min_conn_portname $m_conn_key
  }
  set unassigned_k_ports {}; # should now be empty


  # Go through all master ports and create interconnects for assigned connections
  foreach mi_portname $mi_portnames {
    set mi_portname_uc [string toupper $mi_portname]
    set k_conn_keys [set assigned_k_ports_$mi_portname_uc]
    set num_conn [llength $k_conn_keys]
    #puts "DBG: master port '$mi_portname' $num_conn connections: $k_conn_keys"
    set bridge_pin ""
    if { $num_conn > 0 } {
      set m_intercon_vlnv [get_interconnect_vlnv $m_use_sc]
      set m_intercon [create_bd_cell -type ip -vlnv $m_intercon_vlnv ${m_intercon_prefix}$mi_portname]
      set m_intercon_props [list CONFIG.NUM_SI $num_conn CONFIG.NUM_MI 1 CONFIG.XBAR_DATA_WIDTH $m_data_width]
      for {set idx 0} {$idx < $num_conn} {incr idx} {
        if { $m_has_regslice != 0 } {
          lappend m_intercon_props CONFIG.[format "S%.2d" $idx]_HAS_REGSLICE $m_has_regslice
        } 
        set k_conn_key [lindex $k_conn_keys $idx]
        set intercon_pin [get_name_intercon_si $idx]
        #puts "DBG: get_master_conn_dict kernel $kernel_name/$kernel_m_name <-> $m_intercon/$intercon_pin"
        dict set m_conn_dict $k_conn_key $m_intercon/$intercon_pin; # add dict entry for: KERNEL/<k_name>/<k_port> 
      }
      set m_intercon_props [filter_interconnect_props $m_use_sc $m_intercon_props $has_kernel_clock]
      #puts "DBG: get_master_conn_dict master port $mi_portname interconnect $m_intercon num_conn=$num_conn"
      set_property -dict $m_intercon_props $m_intercon
      set bridge_pin "$m_intercon/[get_name_intercon_mi 0]"
    }
    dict set m_conn_dict "CORE/$mi_portname_uc" [dict create NUM_CONN $num_conn BRIDGE_PIN $bridge_pin]
  }

  return $m_conn_dict
}; # end get_master_conn_dict

proc connect_pipe_fifo {fifo_name s_conn_intf m_conn_intf clk_net rst_net fifo_config {m_clk_net ""} {m_rst_net ""}} {
  if { $s_conn_intf eq "" && $m_conn_intf eq "" } {
    return {}
  }

  set is_async false
  if { $m_clk_net ne "" && $m_clk_net ne $clk_net } {
    set is_async true
    dict set fifo_config CONFIG.IS_ACLK_ASYNC 1
    #dict set fifo_config CONFIG.SYNCHRONIZATION_STAGES 6
  }

  if { $m_clk_net eq "" } {
    set m_clk_net $clk_net
  }

  if { $m_rst_net eq "" } {
    set m_rst_net $rst_net
  }

  # Get info about each side of the pipe
  set s_bytes 0
  set s_count_pin {}
  set s_is_port false
  if { [llength $s_conn_intf] } {
    set s_count_pin [get_bd_pins -quiet ${s_conn_intf}_count]
    set s_bytes [get_property CONFIG.TDATA_NUM_BYTES $s_conn_intf]
    set s_is_port [string equal -nocase "bd_intf_port" [get_property CLASS $s_conn_intf]]
  }
  set m_bytes 0
  set m_count_pin {}
  set m_is_port false
  if { [llength $m_conn_intf] } {
    set m_count_pin [get_bd_pins -quiet ${m_conn_intf}_count]
    set m_is_port [string equal -nocase "bd_intf_port" [get_property CLASS $m_conn_intf]]
    if { $m_is_port } {
      set m_bytes [dict get $fifo_config CONFIG.TDATA_NUM_BYTES]
    } else {
      set m_bytes [get_property CONFIG.TDATA_NUM_BYTES $m_conn_intf]
    }
  }

  # Create datawidth converter if needed
  if { $s_bytes > 0 && $m_bytes > 0 && $s_bytes != $m_bytes } {
    #puts "ETP: connect_pipe_fifo $fifo_name m_is_port=$m_is_port s_bytes=$s_bytes m_bytes=$m_bytes s=$s_conn_intf m=$m_conn_intf s_class=[get_property class $s_conn_intf] m_class=[get_property class $m_conn_intf]"
    set dwidth_converter [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:* ${fifo_name}_datawidth_converter]
    set_property -dict [list CONFIG.M_TDATA_NUM_BYTES $m_bytes] $dwidth_converter
    set m_dwidth_converter   [get_bd_intf_pins $dwidth_converter/M_AXIS]
    set s_dwidth_converter   [get_bd_intf_pins $dwidth_converter/S_AXIS]
    set clk_dwidth_converter [get_bd_pins      $dwidth_converter/aclk]
    set rst_dwidth_converter [get_bd_pins      $dwidth_converter/aresetn]
    # Important: Ensure fifo is connected directly to ports
    if { $s_is_port || (!$m_is_port && $m_bytes > $s_bytes) } {
      connect_bd_intf_net $m_dwidth_converter $m_conn_intf 
      connect_bd_net -net $m_clk_net $clk_dwidth_converter
      connect_bd_net -net $m_rst_net $rst_dwidth_converter
      set m_conn_intf $s_dwidth_converter
      dict set fifo_config CONFIG.TDATA_NUM_BYTES $s_bytes
    } else {
      connect_bd_intf_net $s_conn_intf $s_dwidth_converter 
      connect_bd_net -net $clk_net $clk_dwidth_converter
      connect_bd_net -net $rst_net $rst_dwidth_converter
      set s_conn_intf $m_dwidth_converter
      if { !$m_is_port } {
        dict set fifo_config CONFIG.TDATA_NUM_BYTES $m_bytes
      }
    }
  }
 
  # Create the fifo
  set obj [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:* -name $fifo_name]
  if { [llength $fifo_config] } {
    set_property -dict $fifo_config $obj
  }
  dont_touch $obj
 
  # Connect interfaces
  if { [llength $s_conn_intf] } {
    connect_bd_intf_net $s_conn_intf [get_bd_intf_pins $obj/S_AXIS]
  }
  if { [llength $m_conn_intf] } {
    connect_bd_intf_net $m_conn_intf [get_bd_intf_pins $obj/M_AXIS]
  }

  # Connect count pins
  if { [llength $s_count_pin] } {
    connect_bd_net [get_bd_pins $s_count_pin] [get_bd_pins ${obj}/axis_wr_data_count]
  }
  if { [llength $m_count_pin] } {
    connect_bd_net [get_bd_pins $m_count_pin] [get_bd_pins ${obj}/axis_rd_data_count]
  }
  
  # Connect clock and reset
  connect_bd_net -net [get_bd_net $clk_net] [get_bd_pins $obj/s_axis_aclk]
  connect_bd_net -net [get_bd_net $rst_net] [get_bd_pins $obj/s_axis_aresetn]
  if { $is_async } {
    connect_bd_net -net [get_bd_net $m_clk_net] [get_bd_pins $obj/m_axis_aclk]
    connect_bd_net -net [get_bd_net $m_rst_net] [get_bd_pins $obj/m_axis_aresetn]
  }

  return $obj
}; # end connect_pipe_fifo



proc is_axis_slave {name} {
  return [string match -nocase "S*" $name]
}

proc get_axis_clk_name {intf_name} {
  return "${intf_name}_CLK"
}
proc get_axis_rst_name {intf_name} {
  return "${intf_name}_RESET_N"
}

proc get_axis_names {ocl_config_dict} {
  set res {}
  foreach {mode_letter txrx} {M RX  S TX} {
    set num [dict_get_default $ocl_config_dict "NUM_${mode_letter}_AXIS_$txrx" 0]
    for {set ii 0} {$ii < $num} {incr ii} {
      lappend res "${mode_letter}[format %.2d $ii]_AXIS_$txrx"
    }
  }
  return $res
}

proc get_axis_config {TUSER_WIDTH TDATA_NUM_BYTES cell_type} {
  set config {}
  lappend config CONFIG.HAS_TLAST 1
  lappend config CONFIG.HAS_TKEEP 1
  lappend config CONFIG.HAS_TSTRB 0
  lappend config CONFIG.TID_WIDTH 0
  lappend config CONFIG.TDEST_WIDTH 0
  lappend config CONFIG.TUSER_WIDTH $TUSER_WIDTH
  lappend config CONFIG.TDATA_NUM_BYTES $TDATA_NUM_BYTES
  if { $cell_type eq "" } {
    lappend config CONFIG.HAS_TREADY 1
  } else {
    if { [string equal -nocase "fifo" $cell_type] } {
      lappend CONFIG.FIFO_DEPTH 512
    } else {
      lappend config CONFIG.HAS_TREADY 1
    }
    set keys [dict keys $config]
    foreach key $keys {
      lappend config ${key}.VALUE_SRC USER
    }
  }
  return $config
}; # end get_axis_config

proc create_hip_pipes {ocl_config_dict all_ports_dict_name {ocl_content_dict {}}} {
  #if { !$create_boundary } {
  #  set clk_net [dict get $ocl_content_dict clk_kernel_net]
  #  set rst_net [dict get $ocl_content_dict rst_kernel_sync_net]
  #}
  set create_boundary false
  if { $all_ports_dict_name ne "" } {
    upvar $all_ports_dict_name all_ports_dict
    set create_boundary true
  }

  set s_fifos {}
  set m_fifos {}

  foreach intf_name [get_axis_names $ocl_config_dict] {
    set is_slave [is_axis_slave $intf_name]
    set mode [expr {$is_slave ? "slave" : "master"}]
    set TDATA_NUM_BYTES [dict get $ocl_config_dict ${intf_name}_TDATA_NUM_BYTES]
    set TUSER_WIDTH [dict get $ocl_config_dict ${intf_name}_TUSER_WIDTH]
    set clk_name [get_axis_clk_name $intf_name]
    set rst_name [get_axis_rst_name $intf_name]
    if { $create_boundary } {
      set intf_port [create_bd_intf_port -mode $mode -vlnv xilinx.com:interface:axis_rtl:1.0 $intf_name]
      if { $is_slave } {
        set config [get_axis_config $TUSER_WIDTH $TDATA_NUM_BYTES ""]
        set_property -dict $config $intf_port
      }
      set clk [create_bd_port -type clk -dir I $clk_name]
      set rst [create_bd_port -type rst -dir I $rst_name]
      set_property CONFIG.ASSOCIATED_RESET $rst_name $clk
      set_property CONFIG.ASSOCIATED_BUSIF $intf_name $clk
      dict set all_ports_dict $intf_name $intf_port
      dict set all_ports_dict $clk_name $clk
      dict set all_ports_dict $rst_name $rst
    } else {
      set clk_net [create_bd_net "${clk_name}_net"]
      set rst_net [create_bd_net "${rst_name}_net"]
      connect_bd_net -net $clk_net [get_bd_ports $clk_name]
      connect_bd_net -net $rst_net [get_bd_ports $rst_name]
      set intf_port [get_bd_intf_port $intf_name]
      if { $is_slave } {
        set s_conn_intf $intf_port
        set m_conn_intf ""
      } else {
        set s_conn_intf ""
        set m_conn_intf $intf_port
      }
      set config [get_axis_config $TUSER_WIDTH $TDATA_NUM_BYTES "fifo"]
      set fifo [connect_pipe_fifo "${intf_name}_fifo" $s_conn_intf $m_conn_intf $clk_net $rst_net $config]
      if { $is_slave } {
        lappend s_fifos $fifo
      } else {
        lappend m_fifos $fifo
      }
    }
  }; # end for

  if { !$create_boundary } {
    set num_pairs [tcl::mathfunc::min [llength $s_fifos] [llength $m_fifos]]
    for {set idx 0} {$idx < $num_pairs} {incr idx} {
      set s_fifo [lindex $s_fifos $idx]
      set m_fifo [lindex $m_fifos $idx]
      connect_bd_intf_net [get_bd_intf_pins $s_fifo/M_AXIS] [get_bd_intf_pins $m_fifo/S_AXIS]
    }
  }
}; # end create_hip_pipes

proc create_mem_bridge {ocl_content_dict ocl_config_dict clk_net rst_net num_external_mems} {
  set s_mem_portname   [dict get $ocl_content_dict s_mem_intf]
  set s_mem_addr_width [dict_get_default $ocl_config_dict S_MEM_ADDR_WIDTH [dict get $ocl_config_dict S_ADDR_WIDTH]]
  set s_mem_data_width [dict_get_default $ocl_config_dict S_MEM_DATA_WIDTH [dict get $ocl_config_dict S_DATA_WIDTH]] 
  set s_mem_id_width   [dict_get_default $ocl_config_dict S_MEM_ID_WIDTH 1]
  set boundary_version [dict_get_default $ocl_config_dict BOUNDARY_VERSION 0]
  set has_burst        [dict_get_default $ocl_config_dict HAS_BURST 1]
 
  # Create bridge
  set s_mem_bridge [create_bd_cell -name s_mem_bridge -vlnv [get_bridge_vlnv false $boundary_version] -type ip]
  set s_mem_bridge_config [list CONFIG.ADDR_WIDTH $s_mem_addr_width CONFIG.DATA_WIDTH $s_mem_data_width CONFIG.M_ID_WIDTH $s_mem_id_width CONFIG.S_ID_WIDTH $s_mem_id_width CONFIG.HAS_SLAVE_ID 1]
  set s_mem_bridge_config [get_burst_cell_config $has_burst $s_mem_bridge_config $s_mem_bridge]
  set_property -dict $s_mem_bridge_config $s_mem_bridge
  connect_bd_intf_net [get_bd_intf_ports $s_mem_portname] [get_bd_intf_pins $s_mem_bridge/s_axi]
  connect_bd_net -net $clk_net [get_bd_pins $s_mem_bridge/aclk] 
  connect_bd_net -net $rst_net [get_bd_pins $s_mem_bridge/aresetn]
  dont_touch_intf [get_bd_intf_ports $s_mem_portname]
  dont_touch $s_mem_bridge
  set res_intf $s_mem_bridge/m_axi
  if { $num_external_mems < 1 } {
    terminate_intf $res_intf
  }
  return $res_intf
}; # end create_mem_bridge

proc connect_mem {name clk_obj rst_obj connections offset range data_width ext_conn enable_smartconnect} {
  set all_conns $connections
  if { $ext_conn ne "" } {
    lappend all_conns $ext_conn
  }
  set total_conns [llength $all_conns]
  #puts "DBG: connect_mem $name: data_width=$data_width total_conns=$total_conns"
  set max_data_width $data_width
  foreach conn $all_conns {
    set conn_data_width [get_property -quiet CONFIG.DATA_WIDTH $conn]
    if { $conn_data_width ne "" && $conn_data_width > 0 && $conn_data_width > $max_data_width } {
      set max_data_width $conn_data_width
      #puts "DBG: connect_mem $name: using connect data_width $conn_data_width from: $conn"
    }
  }

  # Create BRAM
  set mem [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:* -name ${name}_dpram]
  set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM}] $mem

  # Create controller
  set ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:* -name ${name}_ctrl]
  if { $max_data_width > 0 } {
    puts "INFO: connect_mem $name: BRAM controller DATA_WIDTH set to $max_data_width"
    set_property -dict [list CONFIG.DATA_WIDTH $max_data_width] $ctrl
  }
  set ctrl_si [get_bd_intf_pins $ctrl/S_AXI]


  set use_intercon [expr {$total_conns > 1}]
  set cells [list $mem $ctrl]
  if { $use_intercon } {
    # Create interconnect
    set mem_use_sc [use_smart_connect "mem" $enable_smartconnect]
    set intercon [create_interconnect $name [list CONFIG.NUM_MI 1 CONFIG.NUM_SI $total_conns] $mem_use_sc false]
    
    # Connect interconnect to controller
    connect_bd_intf_net [get_bd_intf_pins $intercon/M00_AXI] $ctrl_si
    lappend cells $intercon
  }

  # Connect controller to bram
  connect_bd_intf_net [get_bd_intf_pins $ctrl/BRAM_PORTA] [get_bd_intf_pins $mem/BRAM_PORTA]
  connect_bd_intf_net [get_bd_intf_pins $ctrl/BRAM_PORTB] [get_bd_intf_pins $mem/BRAM_PORTB]

  # Connect to kernel, handle addressing
  set create_addr_seg [expr {$offset ne "" && $range ne ""}]
  if { $create_addr_seg } {
    set slave_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces $ctrl_si]]
  }
  
  set pin_num 0
  foreach conn_pin $connections {
    if { $use_intercon } {
      connect_bd_intf_net $conn_pin [get_bd_intf_pins $intercon/[get_name_intercon_si $pin_num]]
    } else {
      connect_bd_intf_net $conn_pin $ctrl_si
    }
    if { $create_addr_seg } {
      set addr_space [get_bd_addr_spaces -of_objects $conn_pin]
      #puts "DBG: connect_mem $name <-> $conn_pin: create_bd_addr_seg -range $range -offset $offset $addr_space $slave_seg ${addr_space}_${slave_seg}"
      create_bd_addr_seg -range $range -offset $offset $addr_space $slave_seg ${addr_space}_${slave_seg}
    }
    incr pin_num
  }

  if { $ext_conn ne "" } {
    if { $use_intercon } {
      connect_bd_intf_net $ext_conn [get_bd_intf_pins $intercon/[get_name_intercon_si $pin_num]]
    } else {
      connect_bd_intf_net $ext_conn $ctrl_si
    }
    if { $create_addr_seg } {
      set addr_space [get_bd_addr_spaces -of_objects $ext_conn]
      #puts "DBG: connect_mem $name <-> $ext_conn (ext): create_bd_addr_seg -range $range -offset $offset $addr_space $slave_seg ext_mem_$name"
      create_bd_addr_seg -range $range -offset $offset $addr_space $slave_seg ext_mem_$name
    }
  }

  # Connect clock and reset
  connect_clk $clk_obj {*}$cells
  connect_rst $rst_obj {*}$cells
  return $ctrl_si
}; # end connect_mem

proc connect_clk {obj args} {
  connect_cell_to_clkrst $obj "clk" {*}$args
}

proc connect_rst {obj args} {
  connect_cell_to_clkrst $obj "rst" {*}$args
}

proc connect_cell_to_clkrst {obj type args} {
  set is_net [expr {[get_property -quiet class $obj] eq "bd_net"}]
  foreach cell $args {
    set pins [get_bd_pins -quiet -of_objects $cell -filter [list "TYPE==$type"]]
    if { [llength $pins] } { 
      if { $is_net } {
        connect_bd_net -net $obj $pins 
      } else {
        connect_bd_net $obj $pins 
      }
    }
  }
}

proc terminate_intf {name} {
  set intf [get_bd_intf_pins ${name}]
  if { ![llength $intf] } {
    error "Cannot find interface to terminate: $name"
  }
  set pins [get_bd_pins -of $intf -filter {DIR==I}]
  foreach pin $pins {
    set tie_off [get_pin_tie_off $pin]
    connect_bd_net -quiet $pin [get_bd_pin $tie_off]
  }
}; # end terminate_intf

proc dont_touch {args} {
  set_property HDL_ATTRIBUTE.DONT_TOUCH true $args
}

proc dont_touch_intf {intfs} {
  set intf_nets [get_bd_intf_nets -of $intfs]
  if { ![llength $intf_nets] } {
    error "Cannot find interface to apply dont_touch: $intfs"
  }
  dont_touch $intf_nets
}; # end dont_touch_intf


proc get_pin_tie_off {pin} {
  set size_l [get_property LEFT $pin]
  set size_r [get_property RIGHT $pin]
  if { $size_l eq $size_r } {
    set size 0
  } elseif { $size_l < $size_r } {
    set size [expr {$size_r - $size_l}]
  } else {
    set size [expr {$size_l - $size_r}]
  }
  incr size
  set name "xlconstant_zero_$size"
  set cell [get_bd_cell -quiet $name]
  if { ![llength $cell] } {
    set cell [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant $name]
    set_property -dict [list CONFIG.CONST_WIDTH $size CONFIG.CONST_VAL 0] $cell
  }
  return [get_bd_pins -of $cell]
}; # end get_pin_tie_off

proc get_kernel_id_width {} { return 1 }

proc show_all_addrs {{prefix ""}} {
  addr::show_all_addrs $prefix
}

namespace eval addr {
  foreach p {div divqr pow add mul sub bits gt lt eq ne iszero} { proc $p args "::math::bignum::$p {*}\$args" }
 
  proc fromhexordec {val} {
    set radix 10
    if { [regsub -nocase "^0x" $val {} val] } {
      set radix 16
    }
    return [::math::bignum::fromstr $val $radix]
  } 
  proc fromhex {val} {
    regsub -nocase "^0x" $val {} val
    return [::math::bignum::fromstr $val 16]
  } 
  proc tohex {bn_val} {
    return 0x[::math::bignum::tostr $bn_val 16]
  }
  proc fromdec {val} {
    return [::math::bignum::fromstr $val 10]
  }
  proc todec {bn_val} {
    return [::math::bignum::tostr $bn_val 10]
  }
  proc frombin {val} {
    return [::math::bignum::fromstr $val 2]
  }
  proc tobin {bn_val} {
    return [::math::bignum::tostr $bn_val 2]
  }
 
  proc get_all_units {} {
    set bnKB [fromdec 1024]
    set bnMB [fromdec 1048576]
    set bnGB [fromdec 1073741824]
    return [list $bnGB "GB" $bnMB "MB" $bnKB "KB"]
  }

  proc get_format_unit {bn_val} {
    foreach {bn_scale suffix} [get_all_units] {
      if { [gt $bn_val $bn_scale] || [eq $bn_val $bn_scale] } {
        return $suffix
      }
    }
    return ""
  }

  proc my_format {bn_val {format_unit ""} {used_format_unit_name ""}} {
    if { $used_format_unit_name ne "" } { upvar $used_format_unit_name used_format_unit }
    if { [string match -nocase "HEX" $format_unit] } {
      set used_format_unit "HEX"
      return "0x[::math::bignum::tostr $bn_val 16]"
    }
    set used_format_unit ""
    foreach {bn_scale suffix} [get_all_units] {
      if { $format_unit ne "" && ![string match -nocase $format_unit $suffix] } {
        continue
      }
      if { [gt $bn_val $bn_scale] || [eq $bn_val $bn_scale] } {
        set used_format_unit $suffix
        set val [todec [div $bn_val $bn_scale]]
        return "${val}${suffix}"
      }
    }
    return "[todec $bn_val]B"
  }

  proc pow2 {exp} {
    set bn [pow [fromdec 2] [fromdec $exp]]
    return [todec $bn]
  }

  proc is_power_of_2 {bn_val} {
    set bitstr [math::bignum::tostr $bn_val 2]
    set msb [string index $bitstr 0]
    set others [string range $bitstr 1 end]
    return [expr {$msb == 1 && $others == 0}]
  }

  proc get_addr_seg_pairs {num_kernels addr_width {pretty_print false} {total_size_name ""} {min_range_name ""}} {
    if { $min_range_name ne "" } { upvar $min_range_name min_range }
    if { $total_size_name ne "" } { upvar $total_size_name total_size }
    set min_range 0
    set total_size 0
    set bn2 [fromdec 2]
    if { $num_kernels < 1 } {
      error "illegal number of kernels: $num_kernels"
    }
    set bn_addr_width [fromdec $addr_width]
    set bn_max_addr_space [pow $bn2 $bn_addr_width]
    if { [gt [fromdec $num_kernels] $bn_max_addr_space] } {
      error "Cannot address $num_kernels kernels with slave address width of $addr_width"
    }

    set total_size [my_format $bn_max_addr_space]
    set bn_ranges {}
    set bn_last_range [pow $bn2 $bn_addr_width]
    set format_unit ""
    if { !$pretty_print } {
      set format_unit "HEX"
    }
    if { $num_kernels == 1 } {
      lappend bn_ranges $bn_last_range
    } else {
      set bn_num_kernels [fromdec $num_kernels]
      #puts "# DBG: max_addr_space=[my_format $bn_max_addr_space]"
      lassign [divqr $bn_max_addr_space $bn_num_kernels] bn_range bn_rem_range
      
      if { [iszero $bn_rem_range] } {
        for {set idx 0} {$idx < $num_kernels} {incr idx} {
          lappend bn_ranges $bn_range 
        }
      } else {
        #puts "# DBG: bn_range1=[todec $bn_range] bn_rem_range1=[todec $bn_rem_range]"

        set bits [expr {[bits $bn_range] -1 }]
        #puts "# DBG: bits=$bits"
        set bn_range [pow $bn2 [fromdec $bits]]
        #puts "# DBG: bn_range=[todec $bn_range]"
        set bn_rem_range [sub $bn_max_addr_space [mul $bn_num_kernels $bn_range]]
        #puts "# DBG: bn_rem_range=[todec $bn_rem_range] mul=[todec [mul $bn_num_kernels $bn_range]]"
        if { [lt $bn_rem_range 0] } {
          error "Unexpected condition! bn_rem_range < 0: [todec $bn_rem_range]"
        }
        set bn_last_range [add $bn_range $bn_rem_range]
        #if { [gt $bn_last_range [mul [fromdec 2] $bn_range]] } {
        #  error "Unexpected condition! last_range > (2 * range) : [todec $bn_last_range] > (2 * [todec $bn_range])"
        #}


        set last_range_bits [expr {[bits $bn_last_range]-1}]
        set last_range_from_bits [pow $bn2 [fromdec $last_range_bits]]
        if { [eq $bn_last_range $last_range_from_bits] } {
          for {set idx 0} {$idx < [expr {$num_kernels - 1}]} {incr idx} {
            lappend bn_ranges $bn_range 
          }
          #puts "# DBG: Last range EQ a power of 2: [my_format $bn_last_range $format_unit] ([my_format $last_range_from_bits $format_unit])"
        } else {
          if { [lt $bn_last_range $last_range_from_bits] } {
            error "Unexpected condition:  Last range LT a power of 2: [my_format $bn_last_range $format_unit] ([my_format $last_range_from_bits $format_unit])"
          }
         
          set bn_to_fill [sub $bn_last_range $last_range_from_bits]
          #puts "# DBG: Last range not a power of 2: [my_format $bn_last_range $format_unit] ([my_format $last_range_from_bits $format_unit]) need to fill [my_format $bn_to_fill $format_unit] (bn_range=[my_format $bn_range $format_unit])"
          
          for {set idx 0} {$idx < [expr {$num_kernels - 1}]} {incr idx} {
            lappend bn_ranges [fill_range $bn_range bn_to_fill]
          }
        } 
        lappend bn_ranges $last_range_from_bits
      }

      if { $format_unit eq "" } {
        set format_unit [get_format_unit $bn_range]
      }
    }
    
    if { [llength $bn_ranges] != $num_kernels } {
      error "Unexpected condition!  get_addr_seg_pairs llength of result should match number of kernels ($num_kernels) but was [llength $bn_ranges]"
    }

    set addr_segs {}
    set bn_offset [fromdec 0]
    foreach bn_range $bn_ranges {
      if { $format_unit eq "" } {
        set str_range [my_format $bn_range $format_unit format_unit]
      } else {
        set str_range [my_format $bn_range $format_unit]
      }
      set str_offset [my_format $bn_offset $format_unit]
      lappend addr_segs [list $str_offset $str_range]
      set bn_offset [add $bn_offset $bn_range]
    }

    if { [ne $bn_max_addr_space $bn_offset] } {
      error "Unexpected condition! max_addr_space ([my_format $bn_max_addr_space]) was not filled by kernel ranges ([my_format $bn_offset])"
    }

    return $addr_segs
  }; # end get_addr_seg_pairs

  proc fill_range {bn_range bn_to_fill_var} {
    upvar $bn_to_fill_var bn_to_fill
    if { [iszero $bn_to_fill] } {
      return $bn_range
    }
    set bn_to_fill [add $bn_to_fill $bn_range]
    while {1} {
      set bn_new_range [mul [fromdec 2] $bn_range]
      if { [eq $bn_new_range $bn_to_fill] } {
        set bn_to_fill [fromdec 0]
        return $bn_new_range
      } elseif { [gt $bn_new_range $bn_to_fill] } {
        set bn_to_fill [sub $bn_to_fill $bn_range]
        return $bn_range
      }
      set bn_range $bn_new_range
    }
  }; # end fill_range

  proc show_segs {obj {prefix ""} {parents {}} {fmt "%-8s"}} {
    if { [catch {get_bd_addr_segs -of $obj} segs] } {
      return
    }
    if { ![llength $segs] } {
      return
    }
    set segs [lsort -dictionary $segs]
    puts "${prefix}[format $fmt SEGS] [llength $segs]"
    foreach seg $segs {
      if { [lsearch -exact $parents $seg] == -1 } {
        set name "[get_property NAME $seg]    $seg"
        show_seg $seg $name $prefix $parents
      }
    }
  }; # end show_segs

  proc show_seg {obj name {prefix ""} {parents {}}} {
    puts "${prefix}ADDR_SEG   $name"
    set prefix "${prefix}  "
    puts "${prefix}ACCESS   [get_property ACCESS $obj]"
    puts "${prefix}OFFSET   [get_property OFFSET $obj]"
    puts "${prefix}RANGE    [get_property RANGE $obj]"
    puts "${prefix}USAGE    [get_property USAGE $obj]"
    puts "${prefix}MEMTYPE  [get_property MEMTYPE $obj]"
    lappend parents $obj
    show_segs $obj $prefix $parents
  }; # end show_seg

  proc show_space {obj name {prefix ""}} {
    puts "${prefix}ADDR_SPACE $name"
    set prefix "${prefix}  "
    puts "${prefix}OFFSET   [get_property OFFSET $obj]"
    puts "${prefix}RANGE    [get_property RANGE $obj]"
    puts "${prefix}TYPE     [get_property MEMTYPE $obj]"
    show_segs $obj $prefix
  }; # end show_space

  proc show_port {obj {prefix ""}} {
    puts "${prefix}PORT $obj"
    set prefix "${prefix}  "
    set fmt "%-30s"
    foreach prop [lsort -dictionary [list_property $obj]] {
      if { $prop ne "CLASS" && $prop ne "PATH" } {
        puts "${prefix}[format $fmt $prop] [get_property $prop $obj]"
      }
    }

    if { ![catch {get_bd_addr_spaces -quiet -of $obj} spaces] && [llength $spaces]} {
      puts "${prefix}[format $fmt SPACES] [llength $spaces]"
      foreach space [lsort -dictionary $spaces] {
        set name "[get_property NAME $space]    $space"
        show_space $space $name $prefix
      }
    }
    show_segs $obj $prefix {} $fmt
  }; # end show_port

  proc show_all_addrs {{prefix ""}} {
    puts "All segments:"
    foreach seg [lsort -dictionary [get_bd_addr_segs *]] {
      show_seg $seg $seg $prefix
    }
    puts "All address spaces"
    foreach space [lsort -dictionary [get_bd_addr_spaces *]] {
      show_space $space $space $prefix
    }
    puts "All ports"
    foreach port [lsort -dictionary [get_bd_intf_ports *]] {
      show_port $port $prefix
    }
  }; # end show_all_addrs

  proc test_get_addr_seg_pairs {num_kernels addr_width} {
    puts "TEST: num_kernels=$num_kernels, addr_width=$addr_width"
    set pretty_print true
    if { [catch {get_addr_seg_pairs $num_kernels $addr_width $pretty_print} addr_segs_pairs] } {
      #puts $::errorInfo
      puts $addr_segs_pairs
      puts ""
      return
    }
    set num 0
    set found_error false
    foreach pair $addr_segs_pairs {
      lassign $pair offset range
      puts "  kernel[format %-2s $num] : [format %8s $offset] \[$range\]"
      if { $range < 1 || $offset < 0 } {
        set found_error true
      }
      incr num
    }
    puts ""
    if { $found_error } {
      error "ERROR: found bad addr seg info"
    }
  }


  proc testall_sel {} {
    puts "======================================================================================"
    test_get_addr_seg_pairs 1 16
    test_get_addr_seg_pairs 6 16
    test_get_addr_seg_pairs 11 16
    test_get_addr_seg_pairs 14 16
  }
  proc testall_16 {} {
    puts "======================================================================================"
    set num_bits 16
    for {set num_kernels 1} {$num_kernels <= 16} {incr num_kernels} {
      test_get_addr_seg_pairs $num_kernels $num_bits
    }
  }
  proc testall {} {
    puts "======================================================================================"
    for {set num_bits 12} {$num_bits <= 32} {incr num_bits} {
      for {set num_kernels 1} {$num_kernels <= 16} {incr num_kernels} {
        test_get_addr_seg_pairs $num_kernels $num_bits
      }
    }
  }

  proc testall_get_addr_seg_pairs {} {
    # run tests, arguments are: num_kernels addr_width
    test_get_addr_seg_pairs 1 2
    test_get_addr_seg_pairs 1 4
    test_get_addr_seg_pairs 2 4
    test_get_addr_seg_pairs 6 16
    test_get_addr_seg_pairs 2 16
    test_get_addr_seg_pairs 3 16
    test_get_addr_seg_pairs 1 17
    test_get_addr_seg_pairs 2 17
    test_get_addr_seg_pairs 4 17
    test_get_addr_seg_pairs 5 17
    test_get_addr_seg_pairs 13 31
    test_get_addr_seg_pairs 13 32
    test_get_addr_seg_pairs 1 32
  }

}; # end addr namespace

}; # end ocl_block_utils namespace 

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
