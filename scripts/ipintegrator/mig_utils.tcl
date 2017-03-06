###########################################################################
# MIG rule utils

namespace eval ::bd::mig_utils {

  variable MIG_INTF_VLNV
  set MIG_INTF_VLNV "xilinx.com:interface:ddrx_rtl:1.0"

  variable ENFORCE_ORDER
  set ENFORCE_ORDER 1

  namespace export \
    can_apply_mig_rule \
    get_mig_out_clklist
}

proc ::bd::mig_utils::can_apply_mig_rule { obj param } {
  if { [bd::mig_utils::can_use_board_flow]  == 0 } {
    return false
  }
  set bd_cell [get_bd_cell $obj]
  set mig_prj_param [ get_property CONFIG.XML_INPUT_FILE $bd_cell]
  set mig_prj_param [string map {" " ""} $mig_prj_param]
  if { $mig_prj_param ne "" } {
    bd::utils::dbg " Board_Rules: IP already configured with MIG PRJ FILE\n"
    return false
  }
 
  #check that the mig file exist in board
  if { [::bd::mig_utils::is_if_exist_in_board $::bd::mig_utils::MIG_INTF_VLNV] == false } {
    bd::utils::dbg " Board_Rules: Interface does not exist in board file\n"
    return false
  }

  if { [::bd::mig_utils::is_mig_file_exist_in_board] == false } {
    bd::utils::dbg " Board_Rules: MIG PRJ FILE does not exist in board file\n"
    return false
  }

  return true
}

proc ::bd::mig_utils::get_mig_out_clklist { mig } {
  set curr_board [ get_property board_part [current_project] ]
  set board_name [ lindex [split $curr_board :] 1]
  set migname [get_property PATH $mig]
  set retlist ""
  switch $board_name {
    ac701 {
      set retlist [list [list $migname/ui_clk 100] ]
    }
    kc705 {
      set retlist [list [list $migname/ui_clk 100] ]
    }
    vc707 {
      set retlist [list [list $migname/ui_clk 100] ]
    }
    vc709 {
      set retlist [list [list $migname/ui_clk 200] ]
      lappend retlist [list $migname/ui_addn_clk_0 100]
      lappend retlist [list $migname/c0_ui_clk 200]
      lappend retlist [list $migname/c0_ui_addn_clk_0 100]
      lappend retlist [list $migname/c1_ui_clk 233]
      lappend retlist [list $migname/c1_ui_addn_clk_0 100]
      lappend retlist [list $migname/ui_clk 233]
    }
    zc706 {
      set retlist [list [list $migname/ui_clk 100] ]
    }
    default {
      bd::utils::dbg "Block automation not supported for $mig fo board $board_name"
    }
  }

  return $retlist
}

proc ::bd::mig_utils::can_use_board_flow { } {
  set cur_board [ get_property board_part [current_project] ]
  if { $cur_board eq "" } {
    return 0
  } 
  return [get_param project.enableBoardFlow]
}

proc ::bd::mig_utils::is_if_exist_in_board { vlnv } {
  bd::utils::dbg "vlnv = $vlnv"
  set board_if [get_board_part_interfaces -filter "VLNV==$vlnv"]
  if { $board_if ne "" } {
    return true
  } else {
    return false
  }
}

proc ::bd::mig_utils::is_mig_file_exist_in_board { } {
  bd::utils::dbg "vlnv = $::bd::mig_utils::MIG_INTF_VLNV"
  set board_if [get_board_part_interfaces -filter "VLNV==$::bd::mig_utils::MIG_INTF_VLNV"]
  if { $board_if eq "" } {
    bd::utils::dbg "DDR Interface does not exist in board file"
    return false
  }

  set board_if [lindex $board_if 0]
#  set mig_file [get_board_intf_property $board_if PRESET_FILE]
  set mig_file [get_preset_file_path $board_if]
  if { $mig_file eq "" } {
    bd::utils::dbg "DDR Interface in board does not have MIG_PRJ File"
    return false
  }

  if { [file exists $mig_file] } {
    return true
  } else {
    bd::utils::dbg "Specified file in DDR Interface does not exist in board repository :$mig_file"
    return false
  }
}

proc ::bd::mig_utils::get_board_intf_property { board_intf_name property} {
 set board_if [get_board_part_interfaces -filter "NAME==$board_intf_name"]
 return [get_property $property $board_if]
}

###############################################################################
# Proc is used to get prj preset file on the board
# @interfaceOb - Interface Object
###############################################################################
proc ::bd::mig_utils::get_preset_file_path {interfaceOb} {
  set sv [get_property SCHEMA_VERSION [current_board_part]]
  set filePath ""
  if {$sv >= "2.0"} {
	    set presetOb [xilinx::board::get_board_presets  [get_property PRESETS $interfaceOb]] 
	    #In future, hard coded param name for preset will be generically set from IP XGUI similar to AXI_EMC core.
            set filePath [get_property CONFIG.XML_INPUT_FILE $presetOb]
    } else {
            set filePath [get_property PRESET_FILE $interfaceOb]
    }
  return $filePath
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
