
set filepath [file dirname [file normalize [info script]]]
source ${filepath}/utils.tcl

#validate the value provided by user is in range or not
proc ::board::is_associated_to_board { passed_port } {
    set result false
    set port_name [lindex [split $passed_port "/"] 1]
    if {$port_name != ""} {
      set port $port_name
    } else {
      set port $passed_port
    }
    set intf_port [get_bd_intf_ports -quiet $port]
    set non_intf_port ""
    if {$intf_port == ""} {
      set non_intf_port [get_bd_ports -quiet $port]
    }
    if {$intf_port == "" && $non_intf_port == ""} {
	  set id [::board::utils::get_board_interface_msg_id]
      send_msg "${id}-100" INFO "$passed_port does not exist"
    }

  if {$intf_port != "" } {
    set bd_cells_objs [get_bd_cells -quiet -of_objects [find_bd_objs -legacy_mode -relation connected_to -thru_hier $intf_port]]
    foreach bd_cells_obj $bd_cells_objs {
      set board_associated_intf [list_property $bd_cells_obj CONFIG.*BOARD_INTERFACE]
        foreach intf $board_associated_intf {
          set intf_net [get_property $intf $bd_cells_obj]
            if {$port == $intf_net} {
              set result true
            }
        }
    }
  } elseif {$non_intf_port != "" } {
    set bd_cells_objs [get_bd_cells -quiet -of_objects [find_bd_objs -legacy_mode -relation connected_to -thru_hier $non_intf_port]]
    foreach bd_cells_obj $bd_cells_objs {
      set board_associated_intf [list_property $bd_cells_obj CONFIG.*BOARD_INTERFACE]
        foreach intf $board_associated_intf {
          set intf_net [get_property $intf $bd_cells_obj]
            if {$port == $intf_net} {
              set result true
            }
        }
    }
  }
  return $result
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
