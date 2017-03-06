set filepath [file dirname [file normalize [info script]]]
source ${filepath}/utils.tcl

#validate the value provided by user is in range or not
proc ::board::apply_board_connection { args }  {
  set id [::board::utils::get_board_interface_msg_id]
  set numArgs [llength $args]

  #Now create cell will be done by user. So ip_name is never required.
  #Currently this utility is going to work only for IPI( i.e not supported for native vivado ), restricting args to 3.
  #IPI does not need vlnv 
  if {$numArgs != 3 } {
    send_msg "${id}-100" ERROR "Unknown argument(s): <$args>!"
    return 1
  }

  set count 0
  set board_intf [lindex $args  $count ]
  set ipbusif    [lindex $args [incr $count] ]
  set bd_design  [lindex $args [incr $count] ]
  
  return [::board::apply_ipi_board_connection "$board_intf" "$ipbusif" "$bd_design"]
}

proc ::board::apply_native_vivado_board_connection { args }  {
  set id [::board::utils::get_board_interface_msg_id]
  set numArgs [llength $args]

  #for native flow minimum number of argument should be 4 and for IPI it should be 5
  if {$numArgs != 3 } {
    send_msg "${id}-100" ERROR "Unknown argument(s): <$args>!"
    return 1
  }

  set count 0
  set board_intf [lindex $args  $count ]
  set ip_vlnv    [lindex $args [incr $count] ]
  set ip_busif    [lindex $args [incr $count] ]


  #Native Vivado Flow
  set ip_name [file dir $ip_busif]
  set ipbusif [file tail $ip_busif]
  
  set ip [get_ips -quiet $ip_name] 
  if {$ip eq "" } {
    send_msg "${id}-100" ERROR "Unable to get ip '${ip_name}' of interface '${ip_busif}'."
    return 1
  }

  #get the ip interface and get its board associated parameter
  set ip_def [ipx::get_cores -all $ip_vlnv]
  set ip_busifs [ipx::get_bus_interfaces -of_objects $ip_def $ipbusif]
  set ip_busparam [ipx::get_bus_parameters -of_objects $ip_busifs BOARD.ASSOCIATED_PARAM]
  set boardParam [get_property VALUE $ip_busparam]

  #apply board connection automation
  if { $board_intf ne "" } {
    send_msg "${id}-100" INFO "set_property -dict [list CONFIG.USE_BOARD_FLOW {true} CONFIG.$boardParam \"$board_intf\"] [get_ips -quiet $ip_name]"
    set_property -dict [list CONFIG.USE_BOARD_FLOW {true} CONFIG.$boardParam "$board_intf"] [get_ips -quiet $ip_name]
  } 
  return 0
}

proc ::board::apply_ipi_board_connection { board_intf ip_busif bd_design } {

  set id [::board::utils::get_board_interface_msg_id]
  if { [get_bd_designs -quiet $bd_design] == "" } {
    #open the target bd design if it is not opened        
    set bd_file [get_files -quiet ${bd_design}.bd]
    if { $bd_file == "" } {
      send_msg "${id}-100" ERROR "bd design '${bd_design}' does not exist."
      return 1
    }
    send_msg "${id}-100" INFO "open_bd_design ${bd_file}"
    open_bd_design $bd_file
    send_msg "${id}-100" INFO "current_bd_design [get_bd_designs -quiet $bd_design]"
    current_bd_design [get_bd_designs -quiet $bd_design]
  } elseif {[current_bd_design] ne $bd_design} {
    #set as the target design as active bd design if it is not already set
    send_msg "${id}-100" INFO "current_bd_design [get_bd_designs -quiet $bd_design]"
    current_bd_design [get_bd_designs -quiet $bd_design]
  }

  #ip_name is cell-name with full hierarchical path. so no need to use -hierarchical option.
  set ip_name [file dir $ip_busif]
  set ipbusif [file tail $ip_busif]
  set ip [get_bd_cells -quiet $ip_name]
  if {$ip eq "" } {
    send_msg "${id}-100" ERROR "Unable to get bd cell '${ip_name}' of interface '${ip_busif}'."
    return 1
  }
  
  set ip_vlnv [get_property VLNV $ip]   
  
  if { [string match -nocase "xilinx.com:ip:mig_7series:*" $ip_vlnv ] == 1 } {
    if { [string equal -nocase "mig_ddr_interface" $ipbusif] == 1 } {
      return [::board::utils::apply_ipi_mig_board_connection $ip $board_intf]
    }
    set ip_busif_obj [get_bd_intf_pins -quiet $ip_busif]                
    if { $ip_busif_obj ne "" } {
      set ip_busif_vlnv [get_property VLNV $ip_busif_obj]
      #Special Handling for MIG.
      if { [string match -nocase "xilinx.com:interface:ddrx_rtl:*" $ip_busif_vlnv ] == 1  } {
        return [::board::utils::apply_ipi_mig_board_connection $ip $board_intf]
      }
    }
  }
  
  #get the ip interface and get its board associated parameter
  set boardParam ""
  
  #Remove this hard-code once you have tcl-parser for "bitab_appcoreips_info.xml"
  set vlnv1_match [string match -nocase "xilinx.com:ip:axi_ethernet:6*" $ip_vlnv ]
  #Starting 2015.3 HIP(e.g axi_ethernet:7.0) maintains static component.xml having all possible board supported interfaces.
  #So, rather than hard-coded info, we can directly get it from ipx commands.
  #set vlnv2_match [string match -nocase "xilinx.com:ip:axi_ethernet:7*" $ip_vlnv ]
  if { $vlnv1_match } {
    set buifdict [dict create "mii" "ETHERNET_BOARD_INTERFACE"]
    dict set buifdict "gmii" "ETHERNET_BOARD_INTERFACE"
    dict set buifdict "rgmii" "ETHERNET_BOARD_INTERFACE"
    dict set buifdict "sgmii" "ETHERNET_BOARD_INTERFACE"
    dict set buifdict "sfp" "ETHERNET_BOARD_INTERFACE"
    dict set buifdict "mdio" "MDIO_BOARD_INTERFACE"
    dict set buifdict "mdio_io" "MDIO_BOARD_INTERFACE"
    dict set buifdict "mgt_clk" "DIFFCLK_BOARD_INTERFACE"
    dict set buifdict "lvds_clk" "DIFFCLK_BOARD_INTERFACE"
    dict set buifdict "phy_rst_n" "PHYRST_BOARD_INTERFACE"
    if { [dict exists $buifdict $ipbusif] } {
      set boardParam [dict get $buifdict $ipbusif]
    }           
  } else {
    set ip_def [ipx::get_cores -all $ip_vlnv]
    set ip_busifs [ipx::get_bus_interfaces -of_objects $ip_def $ipbusif]
    set ip_busparam [ipx::get_bus_parameters -of_objects $ip_busifs BOARD.ASSOCIATED_PARAM]
    set boardParam [get_property VALUE $ip_busparam]
  }
  
  #apply board connection automation
  return [::board::apply_ipi_board_setting $ip $ipbusif $board_intf $boardParam ]
}

proc ::board::apply_ipi_board_setting { ip_inst_name ip_intf_name board_intf_name board_param } {
  set id [::board::utils::get_board_interface_msg_id]
  set Custom [::board::utils::get_custom_string]
  set msg_id [::board::utils::get_board_interface_msg_id]

  #get the bd cell object
  set src_cell [get_bd_cells -quiet $ip_inst_name]
  if { $src_cell eq "" } {
    send_msg "${msg_id}-100" ERROR "bd_cell does not exist $ip_inst_name"
    return 1
  }
  set ip_vlnv [get_property VLNV $src_cell]

  #enable board flow in bd cell
  set boardFlag [get_property CONFIG.USE_BOARD_FLOW $src_cell]
  if { $boardFlag == false } {
    send_msg "${msg_id}-100" INFO "set_property CONFIG.USE_BOARD_FLOW true \[get_bd_cells -quiet $ip_inst_name\]"
    set_property CONFIG.USE_BOARD_FLOW true $src_cell

  }

  if { $board_intf_name ne "" } {
    #Associate board interface with IP interface set board interface on IP
    set boardbif [get_board_part_interfaces $board_intf_name]
    if { $boardbif eq "" } {
      send_msg "${id}-100" ERROR "board_part_interface - ${board_intf_name} not found.."
      return 1
    }
    send_msg "${msg_id}-100" INFO "set_property CONFIG.$board_param $board_intf_name \[get_bd_cells -quiet $ip_inst_name\]"
    set_property CONFIG.$board_param $board_intf_name $src_cell
    
  } else {
    #Associate board interface with IP interface set board interface on IP
    #send_msg "${msg_id}-100" INFO "set_property CONFIG.$board_param Custom \[get_bd_cells -quiet $ip_inst_name\]"
    #set_property CONFIG.$board_param Custom $src_cell
  }

  set bd_pin_name "${src_cell}/${ip_intf_name}"
  set bd_pin [get_bd_intf_pins -quiet $bd_pin_name]
  set isIf 1
  set existing_port ""
  if { $bd_pin ne "" } {
    set existing_port [::board::utils::del_all_objs_conn_to_bd_intf_pin $bd_pin]
  } else {
    set isIf 0          
    #only two possible case when reset_pin and clock_pin is used otherwise it is always a error. this interface should always be enabled
    set ip_port_name ""         
    set vlnv1_match [string match -nocase "xilinx.com:ip:axi_ethernet:6*" $ip_vlnv ]
    set vlnv2_match [string match -nocase "xilinx.com:ip:axi_ethernet:7*" $ip_vlnv ]
    if {$vlnv1_match || $vlnv2_match} {
      if { $ip_intf_name eq "phy_rst_n" } {
        set ip_port_name "phy_rst_n"            
      }
    } else {
      set ip_def [ipx::get_cores -all $ip_vlnv]
      set ip_busif [ipx::get_bus_interfaces -of_objects $ip_def $ip_intf_name]
      set intf_typename [get_property ABSTRACTION_TYPE_NAME $ip_busif]

      set ip_port_map ""
      if {$intf_typename eq "reset_rtl"} {
        set ip_port_map [ipx::get_port_maps "RST" -of_objects $ip_busif ]
      } elseif {$intf_typename eq "clock_rtl" } {
        set ip_port_map [ipx::get_port_maps "CLK" -of_objects $ip_busif ]
      } else {
        send_msg "${msg_id}-100" ERROR "IP instance $ip_inst_name does not have expected interface $ip_intf_name in IPI design"
        return 1
      }
      set ip_port_name [get_property PHYSICAL_NAME $ip_port_map]
    }
    
    set bd_pin [get_bd_pins -quiet -filter "NAME==$ip_port_name" -of_objects $src_cell]
    set ip_pin_net [get_bd_nets -quiet -of_objects $bd_pin]
    if {$ip_pin_net ne "" } {
      set bd_port [get_bd_ports -quiet -of_objects $ip_pin_net]
      send_msg "${msg_id}-100" INFO "disconnect_bd_net $ip_pin_net $bd_pin"
      disconnect_bd_net $ip_pin_net $bd_pin
      #chances that net is part of two IP, e.g  reset(port) is connected to  proc_sys_reset & clock_wiz using net reset_1(net)
      set is_any_other_cell_connected [get_bd_cells -quiet -of_objects $ip_pin_net]
      if { $is_any_other_cell_connected eq "" } {
        send_msg "${msg_id}-100" INFO "delete_bd_objs -quiet $ip_pin_net $bd_port"
        delete_bd_objs -quiet $ip_pin_net $bd_port
      }
    }
  }

  if {$board_intf_name eq "" } {
    send_msg "${msg_id}-100" INFO "set_property CONFIG.$board_param Custom \[get_bd_cells -quiet $ip_inst_name\]"
    set_property CONFIG.$board_param Custom $src_cell
    return 0
  }
  
  if {$bd_pin eq "" } {
    send_msg "${msg_id}-100" ERROR "bd_pin does not exist $bd_pin_name"
    return 1
  }

  #       set intf_obj [get_bd_intf_pins -quiet $bd_pin_name]
  #       set ip_obj [get_bd_cells -quiet -of_objects [get_bd_intf_pins -quiet $bd_pin_name]]

  #       if {$intf_obj ne ""} {
  #         if {$ip_obj ne ""} {
  #        if {![::board::utils::is_custom_board]} {
  #             set preset_settings [::xilinx::board::get_board_presets -of_objects [get_board_part_interfaces -filter "VLNV==[get_property VLNV $intf_obj]"] -ip [get_property VLNV $ip_obj] -filter "IP_INTERFACE==$ip_intf_name"]
  #          if {[llength $preset_settings] == 0 } {
  #            set preset_settings [::xilinx::board::get_board_presets -of_objects [get_board_part_interfaces -filter "VLNV==[get_property VLNV $intf_obj]"] -ip [get_property VLNV $ip_obj]]
  #          }
  #             if { $preset_settings ne "" } {
  #            send_msg "${msg_id}-100" INFO "Applying Preset"
  #            set_property -quiet -dict [::board::return_preset_dict $preset_settings] $ip_obj
  #             }
  #           }
  #         }
  #       }    

  set useCustomFlow  [::board::utils::can_use_custom_flow $bd_pin]

  if { $isIf == 1 } {
    set new_intf_port [::board::utils::create_external_if_connection $bd_pin $board_intf_name $existing_port ]
    if {$useCustomFlow} {
      ::board::utils::add_user_input_on_intf_port $new_intf_port $param 
      ::board::utils::generate_custom_flow_warning $bd_pin
    } elseif {$board_intf_name ne $Custom} {
      ::board::utils::add_board_property_on_intf_port $new_intf_port $board_intf_name
    } else {
      ::board::utils::generate_custom_flow_warning $bd_pin
    }
  } else {
    set new_port [::board::utils::create_external_port_connection $bd_pin $board_intf_name ]
    if {$useCustomFlow} {
      ::board::utils::add_user_input_on_port $new_port $param 
      ::board::utils::generate_custom_flow_warning $bd_pin
    } elseif {$board_intf_name ne $Custom} {
      ::board::utils::add_board_property_on_port $new_port $board_intf_name                             
    } else {
      ::board::utils::generate_custom_flow_warning $bd_pin
    }
  }
  return 0
}

proc ::board::return_preset_dict {preset_obj} {
  set param_list [list_property $preset_obj CONFIG.*]
  if {$param_list == ""} {
    return ""
  }
  set return_val ""
  foreach prop $param_list {
    set val [get_property $prop $preset_obj]
    append return_val $prop " {" $val "} "
  }
  return $return_val
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
