###########################################################################
# Board rule utils

namespace eval ::bd::board_utils {

  variable DIFF_CLK_VLNV
  set DIFF_CLK_VLNV "xilinx.com:interface:diff_clock_rtl:1.0"
  variable CUSTOM
  set CUSTOM "Custom"
  variable CLK_RTL
  set CLK_RTL "clock_rtl"
  variable RST_RTL
  set RST_RTL "reset_rtl"

  namespace export \
    is_intf_pin \
    get_pin_busdef_name \
    make_board_labels
}

#this proc will check the object is pin interface pin object or not 
proc ::bd::board_utils::is_intf_pin { obj } {
  set ret 1
  set bd_intf_pin [get_bd_intf_pin $obj]
  if { [llength $bd_intf_pin] == 0 } {
    return 0
  }
  return $ret
}

#get the corresponding busdef_name for a bd_pin type
proc ::bd::board_utils::get_pin_busdef_name { bd_pin} {
  set busdef_name ""
  set type [get_property TYPE $bd_pin]
  if { $type == "clk"} {
    set busdef_name $::bd::board_utils::CLK_RTL
  } elseif {$type == "rst"} {
    set busdef_name $::bd::board_utils::RST_RTL
  }
  return $busdef_name
}

proc ::bd::board_utils::check_vln {ip_vlnv ip_intf ip_assoc_intf_obj} {
  set ip_vendor [lindex [split $ip_vlnv ":"] 0]
  set ip_library [lindex [split $ip_vlnv ":"] 1]
  set ip_name [lindex [split $ip_vlnv ":"] 2]
  set ip_version [lindex [split $ip_vlnv ":"] 3]
  set assoc_intf_ip_vendor [get_property IP_VENDOR $ip_assoc_intf_obj]
  set assoc_intf_ip_library [get_property IP_LIBRARY $ip_assoc_intf_obj]
  set assoc_intf_ip_name [get_property IP_NAME $ip_assoc_intf_obj]
  set assoc_intf_ip_version [get_property IP_VERSION $ip_assoc_intf_obj]
  set assoc_intf_ip_intf [get_property IP_INTERFACE $ip_assoc_intf_obj]

  if {$ip_vendor == $assoc_intf_ip_vendor && $ip_library == $assoc_intf_ip_library && $ip_name == $assoc_intf_ip_name && $ip_intf == $assoc_intf_ip_intf} {
    if {$assoc_intf_ip_version == $ip_version || $assoc_intf_ip_version == "*"} {
      return true
    } 
  }
  return false
}

proc ::bd::board_utils::getSortedAssocDict {ip_vlnv ip_intf} {
  set assoc_dict {}
  set ip_assoc_intfs [::xilinx::board::get_ip_associated_interfaces]
  foreach ip_a_intf $ip_assoc_intfs {
    set ret_val [::bd::board_utils::check_vln $ip_vlnv $ip_intf $ip_a_intf]
    if {$ret_val == true} {
      set b_ifs [get_property BOARD_INTERFACES $ip_a_intf]
      set i 0
      foreach bif $b_ifs {
        dict append assoc_dict $i $bif
        incr i
      }
      break
    }
  }
  return $assoc_dict
}

#creates the possible values range
proc ::bd::board_utils::make_board_if_labels { MODE PROP VALUE NEW_OR_OLD DEFAULT ip_vlnv ip_intf} {
  set label_dict ""
  set mode [string tolower $MODE]
  bd::utils::dbg "$PROP = $VALUE"
  set board_if [get_board_part_interfaces -filter "MODE==$mode && $PROP==$VALUE"]
  #set used_if [::xilinx::board::get_board_used_interfaces [current_bd_design]]
  set used_if ""
  set sorted_assoc_dict [getSortedAssocDict $ip_vlnv $ip_intf]
  set assoc_intf_list {}
  foreach item1 $sorted_assoc_dict {
    foreach item $board_if {
      set found [lsearch -exact $sorted_assoc_dict $item]
      if {$found != "-1" && $item1 == $item} {
        lappend assoc_intf_list $item
        break
      }
    }
  }


  if {[llength $assoc_intf_list]} {
    set board_if $assoc_intf_list
  }
  bd::utils::dbg "board_interfaces=$board_if"
  if { $board_if ne "" } {
    foreach item $board_if {
      set found [lsearch -exact $used_if $item]
      if {$found == "-1" || $DEFAULT == $item} {
        set item_str [get_property NAME $item]
        set of_comp [get_property OF_COMPONENT $item]
        set display_name ""
        if { $of_comp != "" } {
          set component_of_comp [get_board_components -all -filter "COMPONENT_NAME==$of_comp"]
          if { $component_of_comp != "" } {
            set display_name [get_property DISPLAY_NAME $component_of_comp ]
          }
        }
        append item_str " ( " $display_name " ) "
        set key ""
        if { $NEW_OR_OLD == "NEW" && $display_name != ""} {
          set key "${item_str}"  
        } else {
          set key "${item}"  
        }
        dict append label_dict $key "${item}"  
      }
    }
    bd::utils::dbg "Returning make_board_if_labels $label_dict"
  } 
  dict append label_dict $::bd::board_utils::CUSTOM $::bd::board_utils::CUSTOM
  return $label_dict
}

#creates the possible values range
proc ::bd::board_utils::make_specific_type_board_labels { MODE PROP VALUE TYPE NEW_OR_OLD DEFAULT ip_vlnv ip_intf} {
  variable Custom
  set label_dict ""
  set mode [string tolower $MODE]
  bd::utils::dbg "$PROP = $VALUE"
  set board_if [get_board_part_interfaces -filter "MODE==$mode && $PROP==$VALUE"]
  set used_if [::xilinx::board::get_board_used_interfaces [current_bd_design]]
# set used_if ""
  set sorted_assoc_dict [getSortedAssocDict $ip_vlnv $ip_intf]
  set val {}
  foreach item [dict keys $sorted_assoc_dict] {
    lappend val [dict get $sorted_assoc_dict $item]
  }
  set assoc_intf_list {}
  foreach item1 $val {
    foreach item $board_if {
      set found [lsearch -exact $sorted_assoc_dict $item]
      if {$found != "-1" && $item1 == $item} {
        lappend assoc_intf_list $item
        break
      }
    }
  }

  if {[llength $assoc_intf_list]} {
    set board_if $assoc_intf_list
  }
  bd::utils::dbg "board_interfaces=$board_if"
  if { $board_if ne "" } {
    foreach item $board_if {
      set found [lsearch -exact $used_if $item]
      if {$found == "-1" || $DEFAULT == $item} {
        set item_str [get_property NAME $item]
        set type [get_property PARAM.TYPE $item]
        if {[llength $assoc_intf_list] || $type eq $TYPE} {
          set of_comp [get_property OF_COMPONENT $item]
          set display_name ""
          if { $of_comp != "" } {
            set component_of_comp [get_board_components -all -filter "COMPONENT_NAME==$of_comp"]
            if { $component_of_comp != "" } {
              set display_name [get_property DISPLAY_NAME $component_of_comp ]
            }
          }
          append item_str " ( " $display_name " ) "
          set key ""
          if { $NEW_OR_OLD == "NEW" && $display_name != ""} {
            set key "${item_str}"  
          } else {
            set key "${item}"  
          }
          dict append label_dict $key "${item}"  
        }
      }
    }
    bd::utils::dbg "Returning make_specific_type_board_labels $label_dict"
  } 
  dict append label_dict $::bd::board_utils::CUSTOM $::bd::board_utils::CUSTOM
  return $label_dict
}

#create the label for an obj (pin or intf_pin)
proc ::bd::board_utils::make_board_labels { obj new_or_old default_val} {
  set mode ""
  set prop ""
  set prop_value ""
  set type ""
  set isIf [::bd::board_utils::is_intf_pin $obj]

  set ip_vlnv ""
  set ip_intf ""
  if { $isIf } {
    set prop "vlnv"
    set src_bd_pin [get_bd_intf_pin $obj]
    set prop_value [get_property VLNV $src_bd_pin]
    set mode       [get_property MODE $src_bd_pin]
    set type [get_property CONFIG.TYPE $src_bd_pin]
    set ip_obj [get_bd_cells -quiet -of_objects [get_bd_intf_pins -quiet $obj]]
    set ip_vlnv [get_property VLNV $ip_obj]
    set ip_intf [get_property NAME [get_bd_intf_pins -quiet $obj]]
  } else {
    set src_bd_pin [get_bd_pin $obj]
    set dir        [get_property DIR $src_bd_pin]
    set busdef_name [::bd::board_utils::get_pin_busdef_name $src_bd_pin]
    set prop "BUSDEF_NAME"
    set prop_value $busdef_name
    set mode "MASTER"
    if { [string equal $dir I] } {
      set mode "SLAVE"
    }
    set type [get_property CONFIG.TYPE $src_bd_pin]
    set ip_obj [get_bd_cells -quiet -of_objects [get_bd_pins -quiet $obj]]
    set ip_vlnv [get_property VLNV $ip_obj]
    set ip_intf [bd::util_cmd get_intf_name_of_pin [get_bd_pins -quiet $obj]]
  }

  if { [string equal -nocase $prop_value $::bd::board_utils::DIFF_CLK_VLNV] == 1 || [string equal -nocase $prop_value $::bd::board_utils::RST_RTL] == 1 } {
    set label_dict [make_specific_type_board_labels $mode $prop $prop_value $type $new_or_old $default_val $ip_vlnv $ip_intf]
  } else {
    set label_dict [make_board_if_labels $mode $prop $prop_value $new_or_old $default_val $ip_vlnv $ip_intf]
  }
  return $label_dict  
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
