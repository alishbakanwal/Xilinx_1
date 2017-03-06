namespace eval ::board::utils {
  namespace export \
      is_custom_board  
}
proc ::board::utils::get_board_interface_msg_id { } {
  set id "board_interface 100"
  return $id
}
proc ::board::utils::get_clock_rtl_name { } {
  set clk_rtl "clock_rtl"
  return $clk_rtl
}
proc ::board::utils::get_reset_rtl_name { } {
  set clk_rtl "reset_rtl"
  return $clk_rtl
}
proc ::board::utils::get_custom_string { } {
  set Custom "Custom"
  return $Custom
}
proc ::board::utils::get_rst_polarity_key { } {
  set rst_polarity_key "rst_polarity"
  return $rst_polarity_key
}
proc ::board::utils::get_rst_active_high { } {
  set rst_active_high "ACTIVE_HIGH"
  return $rst_active_high
}
proc ::board::utils::get_active_low { } {
  set rst_active_low  "ACTIVE_LOW"
  return $rst_active_low
}
proc ::board::utils::get_clk_freq_key { } {
  set clk_freq_key "clock_freq"
  return $clk_freq_key
}
proc ::board::utils::get_diff_clk_vlnv { } {
  set diff_clk_vlnv "xilinx.com:interface:diff_clock_rtl:1.0"
  return $diff_clk_vlnv
}

# THis proc check is project is created with board or without board
proc ::board::utils::is_custom_board { } {
  set cur_board [get_property board_part [current_project] ]
  if { $cur_board ne "" } {
    return false
  }
  return true
}
#this proc will check the object is pin interface pin object or not 
proc ::board::utils::is_intf_pin { obj } {
  set ret 1
  set bd_intf_pin [get_bd_intf_pin -quiet $obj]
  if { [llength $bd_intf_pin] == 0 } {
    return 0
  }
  return $ret
}

#this proc will be called for custom board flow 
proc ::board::utils::generate_custom_flow_warning { obj } {
  set id [::board::utils::get_board_interface_msg_id]
  set isCustom [::board::utils::is_custom_board]
  if {$isCustom == false} {
    send_msg "${id}-100" WARNING "Board automation did not generate location constraint for $obj. Users may need to specify the location constraint manually."
  }
}

#get the corresponding busdef_name for a bd_pin type
proc ::board::utils::get_pin_busdef_name { bd_pin} {
  set clk_rtl [::board::utils::get_clock_rtl_name]
  set rst_rtl [::board::utils::get_reset_rtl_name]
  set busdef_name ""
  set type [get_property TYPE $bd_pin]
  if { $type == "clk"} {
    set busdef_name $clk_rtl
  } elseif {$type == "rst"} {
    set busdef_name $rst_rtl
  }
  return $busdef_name
}

#this proc checks that the obj (pin or intf_pin) is connected or not
proc ::board::utils::is_pin_connected { obj } {
  set isIf [::board::utils::is_intf_pin $obj]
  set nNets ""
  if { $isIf } {
    set fco [get_bd_intf_pins -quiet $obj]
    set nNets [get_bd_intf_nets -quiet -of_objects $fco]
  } else {
    set fco [get_bd_pins -quiet $obj]
    set nNets [get_bd_nets -quiet -of_objects $fco]
  }
  if {[llength $nNets] != 0 } {
    bd::utils::dbg " Board_Rules: Interface is already connected\n"
    set nNets [get_bd_nets -quiet -of_objects $fco]
    return true
  }
  return false
}
#check for board flow is enabled or disabled in project setting
proc ::board::utils::can_use_board_flow { } {
  return [get_param project.enableBoardFlow]
}

#validate the value provided by user is in range or not
proc ::board::utils::validate_config { id label_dict key param} {
  set config [dict get $param CONFIG ]
  set key_exists [dict exists $config $key]
  if { ! $key_exists } {
    send_msg "${id}" ERROR "Could not find expected configuration value \"$key\"."
    return 0
  } else {
    set value [dict get $config $key]
    set value_exists [dict exists $label_dict $value ]
    if { ! $value_exists } {
      send_msg "${id}" ERROR "Invalid Configuration value \"$value\" for \"$key\"."
      return 0
    }
  }
  return 1 
}

#check the selected vlnv interface is available in board or not
proc ::board::utils::is_intf_exist_in_board { vlnv } {
  bd::utils::dbg "vlnv = $vlnv"
  set label_dict ""
  set board_if [get_board_part_interfaces -filter "VLNV==$vlnv"]
  if { $board_if ne "" } {
    return true
  } else {
    return false
  } 
}

#check the selected busdef_name is available in board or not
proc ::board::utils::is_busdef_exist_in_board { busdef_name } {
  bd::utils::dbg "busdef = $busdef_name"
  set label_dict ""
  set board_if [get_board_part_interfaces -filter "BUSDEF_NAME==$busdef_name"]
  if { $board_if ne "" } {
    return true
  } else {
    return false
  } 
}

#check that the object (pin or intf_pin) type is available in board
proc ::board::utils::is_available_on_board {obj} {
  set ret false
  set isIf [::board::utils::is_intf_pin $obj]
  set bd_pin [get_bd_pins -quiet $obj]
  if {$isIf} {
    set bd_pin [get_bd_intf_pins -quiet $obj]
    set vlnv [get_property VLNV $bd_pin]
    set ret [::board::utils::is_intf_exist_in_board $vlnv]
  } else {
    set busdef_name [::board::utils::get_pin_busdef_name $bd_pin]
    set ret [::board::utils::is_busdef_exist_in_board $busdef_name]
  }
  return $ret
}

proc ::board::utils::copy_pin_property_to_port { pin port } {
  set id [::board::utils::get_board_interface_msg_id]
  set rst_active_low [::board::utils::get_active_low]
  set rst_active_high [::board::utils::get_rst_active_high]
  set diff_clk_vlnv [::board::utils::get_diff_clk_vlnv]
  set isIf [::board::utils::is_intf_pin $pin]
  set bd_pin [get_bd_pins -quiet $pin]
  if {$isIf} {
    set bd_pin [get_bd_intf_pins -quiet $pin]
    set vlnv [get_property VLNV $bd_pin]
    if { $vlnv == $diff_clk_vlnv } {
      set freq [get_property CONFIG.FREQ_HZ $pin]
      if { $freq != "" } {
        set_property CONFIG.FREQ_HZ $freq $port  
        send_msg "${id}-100" INFO "set_property CONFIG.FREQ_HZ [get_property CONFIG.FREQ_HZ $pin] $port" 
      }
    } 
  } else {
    set type [get_property TYPE $bd_pin]
    if { $type == "clk" } {
      set_property CONFIG.FREQ_HZ [get_property CONFIG.FREQ_HZ $pin] $port
      send_msg "${id}-100" INFO "set_property CONFIG.FREQ_HZ [get_property CONFIG.FREQ_HZ $pin] $port"
      set_property CONFIG.PHASE [get_property CONFIG.PHASE $pin] $port
      send_msg "${id}-100" INFO "set_property CONFIG.PHASE [get_property CONFIG.PHASE $pin] $port"
    } else {
      set polarity [get_property CONFIG.RST_POLARITY $pin]
      set bd_port_polarity $rst_active_low
      if { $polarity == 1 } {
        set bd_port_polarity $rst_active_high
      }
      set_property CONFIG.POLARITY $bd_port_polarity $port
      send_msg "${id}-100" INFO "set_property CONFIG.POLARITY [get_property CONFIG.RST_POLARITY $pin] $port"
    }
  }
}

proc ::board::utils::create_external_if_connection { intf_pin board_if_name existing_intf_port } {
  set Custom [::board::utils::get_custom_string]
  set id [::board::utils::get_board_interface_msg_id]
  set new_intf_port ""
  set mode [get_property MODE $intf_pin]
  set busdef_vlnv [get_property VLNV $intf_pin]
  set splitted_vlnv [split $busdef_vlnv ":"]
  set bus_def_name [lindex $splitted_vlnv 2]
  if { $intf_pin ne "" && $board_if_name ne "" } {
    
    #name of port
    set if_port_name "${bus_def_name}"
    if {$board_if_name ne $Custom} {
      set if_port_name "${board_if_name}"
    }
    
    if { $existing_intf_port ne "" } {
      set if_port_name $existing_intf_port
    }

    #getting unique name if which is not exist in design
    set new_if_port_name $if_port_name
    for { set i 0 } { [get_bd_intf_ports -quiet /$new_if_port_name] ne "" } { incr i } {
      set new_if_port_name "${if_port_name}_${i}"
    }

    #creating new port 
    set new_intf_port [create_bd_intf_port -mode $mode -vlnv $busdef_vlnv $new_if_port_name]
    send_msg "${id}-100" INFO "create_bd_intf_port -mode $mode -vlnv $busdef_vlnv $new_if_port_name"
    ::board::utils::copy_pin_property_to_port $intf_pin $new_intf_port 
    connect_bd_intf_net $new_intf_port $intf_pin
    send_msg "${id}-100" INFO "connect_bd_intf_net $new_intf_port $intf_pin"
  }
  return $new_intf_port
}

proc ::board::utils::get_existing_board_port { type dir board_if_name} {
  set bd_ports [get_bd_ports -quiet -filter "TYPE==$type && DIR==$dir" ]
  bd::utils::dbg " Board_Rules: Traversing bd_ports $bd_ports\n"
  if {$board_if_name == "Custom"} {
    return ""
  }
  foreach bd_port $bd_ports {
    if { [llength $bd_port]  == 0 } {
      continue
    }

    set bd_net [get_bd_nets -quiet -of_objects $bd_port]
    bd::utils::dbg " Board_Rules: net=$bd_net of port=$bd_port \n"
    if {[llength $bd_net] == 0} {
      continue
    }
    set bd_pins [get_bd_pins -quiet -of_objects $bd_net]
    bd::utils::dbg " Board_Rules: net=$bd_net Traversing bd_pin=$bd_pins \n"
    foreach bd_pin $bd_pins {
      if {[llength $bd_pin] == 0} {
        continue
      }
      set bd_cell [get_bd_cells -quiet -of_object $bd_pin]
      bd::utils::dbg " Board_Rules: cell=$bd_cell bd_pin=$bd_pin \n"
      if {[llength $bd_cell] == 0} {
        continue
      }
      set boardParamName [ get_property BOARD.ASSOCIATED_PARAM $bd_pin ]
      if {$boardParamName eq "" } {
        set boardParamName [ get_property CONFIG.ASSOCIATED_BOARD_PARAM $bd_pin ]
      }
      bd::utils::dbg " Board_Rules: cell=$bd_cell boardParamName=$boardParamName \n"
      if {[llength $boardParamName] == 0} {
        continue
      }
      set boardParamValue [get_property CONFIG.$boardParamName $bd_cell]
      bd::utils::dbg " Board_Rules: cell=$bd_cell $boardParamName=$boardParamValue \n"
      if {$boardParamValue eq $board_if_name} {
        return $bd_port
      }
    }
  }
  return ""
}
proc ::board::utils::create_external_port_connection { bd_pin board_if_name} {
  set Custom [::board::utils::get_custom_string]
  set id [::board::utils::get_board_interface_msg_id]
  set board_port ""
  set type [get_property TYPE $bd_pin]
  set dir  [get_property DIR  $bd_pin]
  set busdef_name [::board::utils::get_pin_busdef_name $bd_pin]

  if { $bd_pin ne "" && $board_if_name ne "" } {

    if {$dir eq "I" } {
      #when bd pin is input type, then it may connected to existing
      #board pin
      set board_port [::board::utils::get_existing_board_port $type $dir $board_if_name]
      bd::utils::dbg " Board_Rules: Existing board port is =$board_port\n"
    }

    if {[llength $board_port]  == 0} {
      #name of port
      set new_port_name "${busdef_name}"
      if {$board_if_name ne $Custom} {
        set new_port_name "${board_if_name}"
      }
      #getting unique name port which is not exist in design
      for { set i 0 } { [get_bd_ports -quiet /$new_port_name] ne "" } { incr i } {
        set new_port_name "${new_port_name}_${i}"
      }

      #creating new port 
      set board_port [create_bd_port -dir $dir $new_port_name -type $type]
      send_msg "${id}-100" INFO "create_bd_port -dir $dir $new_port_name -type $type"
      if { $dir eq "I" } {
        ::board::utils::copy_pin_property_to_port $bd_pin $board_port 
      }
    }
    connect_bd_net $board_port $bd_pin
    send_msg "${id}-100" INFO "connect_bd_net $board_port $bd_pin"
  }
  return $board_port 
}
proc ::board::utils::add_board_property_on_intf_port {new_port board_if_name} {
  set diff_clk_vlnv [::board::utils::get_diff_clk_vlnv]
  set id [::board::utils::get_board_interface_msg_id]
  set vlnv [get_property VLNV $new_port]
  if { $vlnv == $diff_clk_vlnv } {
    set board_if [get_board_part_interfaces -filter "NAME==$board_if_name"] 
    set freq [get_property PARAM.frequency $board_if]
    send_msg "${id}-100" INFO  "set_property CONFIG.FREQ_HZ $freq $new_port"
    set_property CONFIG.FREQ_HZ $freq $new_port
  }
}
proc ::board::utils::add_board_property_on_port {new_port board_if_name} {
  set rst_active_low [::board::utils::get_active_low]
  set rst_active_high [::board::utils::get_rst_active_high]
  set id [::board::utils::get_board_interface_msg_id]
  set board_if [get_board_part_interfaces -filter "NAME==$board_if_name"] 
  set type [get_property TYPE $new_port]
  set dir [get_property DIR $new_port]
  
  #Properties need to be propogated only for Input ports.
  if { $dir ne "I" } {
    return
  }
  
  if { $type == "clk"} {
    set freq [get_property PARAM.frequency $board_if]
    send_msg "${id}-100" INFO "set_property CONFIG.FREQ_HZ $freq $new_port"
    set_property CONFIG.FREQ_HZ $freq $new_port

  } elseif { $type == "rst"} {
    set bd_port_polarity $rst_active_low
    set polarity [get_property PARAM.RST_POLARITY $board_if]
    if { $polarity == 1 } {
      set bd_port_polarity $rst_active_high
    }
    send_msg "${id}-100" INFO "set_property CONFIG.POLARITY $bd_port_polarity $new_port"
    set_property CONFIG.POLARITY $bd_port_polarity $new_port
  }
}
proc ::board::utils::can_use_custom_flow { obj } {
  set isCustom [::board::utils::is_custom_board]
  if {$isCustom == true} {
    return true
  }
  set isAvailable [::board::utils::is_available_on_board $obj]
  if { $isAvailable == false } {
    return true
  }
  return false
}
proc ::board::utils::custom_get_rule_option { obj param } {
  set diff_clk_vlnv [::board::utils::get_diff_clk_vlnv]
  set clk_freq_key [::board::utils::get_clk_freq_key]
  set rst_polarity_key [::board::utils::get_rst_polarity_key] 
  set rst_active_low [::board::utils::get_active_low]
  set rst_active_high [::board::utils::get_rst_active_high]
  set widgets ""
  set isIf [::board::utils::is_intf_pin $obj]
  set bd_pin [get_bd_pins -quiet $obj]
  set rule_description "Make IP Port External: $obj"
  if {$isIf } {
    bd::utils::dbg "board_rules:custom_get_rule_options It is interface"
    set rule_description "Make IP Interface External: $obj"
    set bd_pin [get_bd_intf_pins -quiet $obj]
    set vlnv [get_property VLNV $bd_pin]
    #if {$vlnv == $diff_clk_vlnv } {
    #    set default [get_property CONFIG.FREQ_HZ $bd_pin]
    #    set clock_freq_option [dict create name $clk_freq_key\
        #        description "Provide clock frequency(in Hz)"\
        #        type "int"\
        #        value $default]
    #    set widgets [list $clock_freq_option]
    #}
  } else {
    set type [get_property TYPE $bd_pin]
    bd::utils::dbg "board_rules:custom_get_rule_options It is pin object=$obj type=$type"
    if {$type == "clk" } { 
      #   bd::utils::dbg "board_rules:custom_get_rule_options It is clock pin object"
      #   set default [get_property CONFIG.FREQ_HZ $bd_pin] 
      #   set clock_freq_option [dict create name $clk_freq_key\
                              #       description "Provide clock frequency(in Hz)"\
                              #       type "int"\
                              #       value $default]
      #   set widgets [list $clock_freq_option]
    } elseif {$type == "rst"} {
      bd::utils::dbg "board_rules:custom_get_rule_options It is reset pin object"
      set default [get_property CONFIG.POLARITY $bd_pin]
      set label_dict "$rst_active_low $rst_active_low  $rst_active_high $rst_active_high"
      set rst_polarity_range [dict keys $label_dict]
      set rst_polarity_option [dict create name $rst_polarity_key\
                                   description "Select Reset Polarity"\
                                   type "string"\
                                   value $default\
                                   discreteRange $rst_polarity_range]
      set widgets [list $rst_polarity_option]
    }
  }
  if {$widgets ne "" } {
    bd::utils::dbg "board_rules:custom_get_rule_options Adding Widget"
    set opts [dict create rule_description $rule_description widgets $widgets]
  } else {
    set opts [dict create rule_description $rule_description]
  }
  return $opts
}
proc ::board::utils::add_user_input_on_port { new_port param} {
  set clk_freq_key [::board::utils::get_clk_freq_key]
  set rst_polarity_key [::board::utils::get_rst_polarity_key]
  set id [::board::utils::get_board_interface_msg_id] 
  set type [get_property TYPE $new_port]
  set dir [get_property DIR $new_port]
  
  if { $dir ne "I" } {
    return
  }
  
  if {$type == "clk"} {
    #   set config [dict get $param CONFIG]
    #   set config_val [dict get $config $clk_freq_key]
    #   send_msg "${id}-100" INFO "set_property CONFIG.FREQ_HZ $config_val $new_port"
    #   set_property CONFIG.FREQ_HZ $config_val $new_port
  } elseif {$type == "rst"} {
    set config [dict get $param CONFIG]
    set config_val [dict get $config $rst_polarity_key]
    send_msg "${id}-100" INFO "set_property CONFIG.POLARITY $config_val $new_port"
    set_property CONFIG.POLARITY $config_val $new_port 
  }
}
proc ::board::utils::add_user_input_on_intf_port {new_intf_port param} {
  set diff_clk_vlnv [::board::utils::get_diff_clk_vlnv]
  set clk_freq_key [::board::utils::get_clk_freq_key]
  set vlnv [get_property VLNV $new_intf_port]
  #if {$vlnv == $diff_clk_vlnv} {
  #    set config [dict get $param CONFIG]
  #    set config_val [dict get $config $clk_freq_key]
  #    set_property CONFIG.FREQ_HZ $config_val $new_intf_port
  #}
}
proc ::board::utils::get_associated_board_param { ip_vlnv ipbusif } {
  #get the ip interface and get its board associated parameter
  set ip_def [ipx::get_cores $ip_vlnv]
  set ip_busifs [ipx::get_bus_interfaces -of_objects $ip_def $ipbusif]
  set ip_busparam [ipx::get_bus_parameters -of_objects $ip_busifs BOARD.ASSOCIATED_PARAM]
  set boardParam [get_property VALUE $ip_busparam]
  return $boardParam
}

proc ::board::utils::get_platform { } {
  global tcl_platform
  set plat $tcl_platform(platform)$tcl_platform(pointerSize)
  switch $plat { 
    windows4         { return nt }
    windows8         { return nt64 }
    unix4            { return lin }
    unix8            { return lin64 }
    default          { dbg "Unknown platform : $plat" }
  }
}

proc ::board::utils::get_all_objs_conn_to_bd_intf_pin { intf_pin } {
  #Get all upper hier objects connected to IP interface pin - intf_pin
  set objs_to_delete [list]
  
  while { $intf_pin ne "" } {   
    set ip_intf_pin_obj [get_bd_intf_pins -quiet $intf_pin]
    if { $ip_intf_pin_obj eq "" } {
      break
    }
    set ip_intf_net_obj [get_bd_intf_nets -quiet -boundary_type upper -of_objects $ip_intf_pin_obj]
    if { $ip_intf_net_obj eq "" } {
      break
    }
    lappend objs_to_delete $ip_intf_net_obj
    set upper_pin [get_bd_intf_pins -quiet -of_objects $ip_intf_net_obj -filter "PATH != $ip_intf_pin_obj"]
    if { $upper_pin eq "" } {
      set connected_port [get_bd_intf_ports -quiet -of_objects $ip_intf_net_obj]
      if { $connected_port ne "" } {
        lappend objs_to_delete $connected_port
      }
      break
    }
    lappend objs_to_delete $upper_pin
    set intf_pin $upper_pin
  }     
  return $objs_to_delete
}

proc ::board::utils::get_all_objs_conn_to_bd_pin { intf_pin } {
  #Get all upper hier objects connected to IP pin - intf_pin
  set objs_to_delete [list]
  
  while { $intf_pin ne "" } {   
    set ip_pin_obj [get_bd_pins -quiet $intf_pin]
    if { $ip_pin_obj eq "" } {
      break
    }
    set ip_net_obj [get_bd_nets -quiet -boundary_type upper -of_objects $ip_pin_obj]
    if { $ip_net_obj eq "" } {
      break
    }
    lappend objs_to_delete $ip_net_obj
    set upper_pin [get_bd_pins -quiet -of_objects $ip_net_obj -filter "PATH != $ip_pin_obj"]
    if { $upper_pin eq "" } {
      set connected_port [get_bd_ports -quiet -of_objects $ip_net_obj]
      if { $connected_port ne "" } {
        lappend objs_to_delete $connected_port
      }
      break
    }
    lappend objs_to_delete $upper_pin
    set intf_pin $upper_pin
  }     
  return $objs_to_delete
}

proc ::board::utils::del_all_objs_conn_to_bd_intf_pin { intf_pin } {
  set id [::board::utils::get_board_interface_msg_id]
  #is anything already connected. return its name
  set existing_port_name ""
  set existing_port_obj [get_bd_intf_ports -quiet -of_objects [lindex [get_bd_intf_nets -quiet -hierarchical -boundary_type upper -of_objects [get_bd_intf_pins -quiet $intf_pin]] 0]]
  if { $existing_port_obj ne "" } {
    set existing_port_name [get_property NAME $existing_port_obj]
  }
  set obj_to_del [::board::utils::get_all_objs_conn_to_bd_intf_pin $intf_pin]
  if { $obj_to_del ne "" } {
    send_msg "${id}-100" INFO "delete_bd_objs -quiet $obj_to_del"
    delete_bd_objs -quiet $obj_to_del
  }
  return $existing_port_name
}

proc ::board::utils::apply_ipi_mig_board_connection { mig_ip board_intf } {

  set id [::board::utils::get_board_interface_msg_id]
  set mig_board_param "BOARD_MIG_PARAM"
  set ip_obj [get_bd_cells -quiet $mig_ip]
  if { $ip_obj eq "" } {
    send_msg "${id}-100" ERROR "Unable to get bd cell '${mig_ip}'."
    return 1
  }
  
  set connect_flow 0
  if { $board_intf ne "" } {
    #Connect flow
    set connect_flow 1
    set board_intf_obj [get_board_part_interfaces -quiet $board_intf]
    if { $board_intf_obj eq "" } {
      send_msg "${id}-100" ERROR "board_part_interface - ${board_intf} not found.."
      return 1
    }
    send_msg "${id}-100" INFO "set_property CONFIG.${mig_board_param} ${board_intf} \[get_bd_cells -quiet $mig_ip\]" 
    set_property CONFIG.${mig_board_param} $board_intf $ip_obj          
  } else {
    send_msg "${id}-100" INFO "set_property CONFIG.${mig_board_param} \"Custom\" \[get_bd_cells -quiet $mig_ip\]" 
    set_property CONFIG.${mig_board_param} "Custom" $ip_obj             
  }
  
  set ddr_ifs [get_bd_intf_pins -of_objects $ip_obj]
  foreach intf $ddr_ifs {
    set intf_vlnv [get_property VLNV $intf ]
    set existing_port ""                
    if { [string match -nocase "xilinx.com:interface:ddrx_rtl:*" $intf_vlnv ] == 1 } { 
      set existing_port [::board::utils::del_all_objs_conn_to_bd_intf_pin $intf]
      if { $connect_flow == 1 } {                               
        ::board::utils::create_external_if_connection $intf $board_intf $existing_port
      }
      continue
    }
    if { [string match -nocase "xilinx.com:interface:diff_clock_rtl:*" $intf_vlnv ] == 1 } {
      set board_clk_if "sys_diff_clock"
      set existing_port [::board::utils::del_all_objs_conn_to_bd_intf_pin $intf]
      if { $connect_flow == 1 } {                               
        ::board::utils::create_external_if_connection $intf $board_clk_if $existing_port
      }
      continue
    }
  }
  
  set bd_pins [get_bd_pins -of_objects $ip_obj]
  foreach bd_pin $bd_pins {
    set bd_pin_vlnv [get_property VLNV $bd_pin]
    set mode [get_property MODE $bd_pin]        
    set type [get_property TYPE $bd_pin]
    set dir [get_property DIR $bd_pin]
    set bd_pin_name [get_property NAME $bd_pin]
    
    if { $dir != "I" } {
      continue
    }
    
    if { $type ne "clk" } {
      continue
    }
    
    set new_port_name "${bd_pin_name}"
    for { set i 0 } { [get_bd_ports /$new_port_name] ne "" } { incr i } {
      set new_port_name "${bd_pin_name}_${i}"
    } 
    
    send_msg "${id}-100" INFO "create_bd_port -dir I $new_port_name -type $type"
    set new_port [create_bd_port -dir I $new_port_name -type $type] 
    send_msg "${id}-100" INFO "connect_bd_net $new_port $bd_pin"
    connect_bd_net $new_port $bd_pin            
  }     
  
  return 0
}



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
