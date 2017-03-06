##############################################################################
# Copyright 2011 Xilinx Inc. All rights reserved
##############################################################################
# Clocking and Reset Utilities used by rules
#
# 

namespace eval ::bd::clkrst {
  variable NEW_CLK_WIZ
  variable NEW_CLK_PORT
  variable NEW_PROC_SYS_RST
  set NEW_CLK_WIZ "New Clocking Wizard (100 MHz)"
  set NEW_CLK_PORT "New External Port (100 MHz)"
  set NEW_PROC_SYS_RST "New Processor System Reset"
  set NEW_MIG "New Memory Interface Generator"

  variable ACTIVE_HIGH
  variable ACTIVE_LOW
  set ACTIVE_HIGH "ACTIVE_HIGH"
  set ACTIVE_LOW "ACTIVE_LOW"

  variable PROC_SYS_RST_PATTERN
  variable CLK_WIZ_PATTERN
  variable PS7_PATTERN
  variable MPSOC_PATTERN
  variable ZYNQ_PATTERN
  variable MIG_7SERIES_PATTERN
  variable MIG_ULTRASCALE_PATTERN
  variable MIG_PATTERN
  set PROC_SYS_RST_PATTERN "xilinx.com:ip:proc_sys_reset*"
  set CLK_WIZ_PATTERN "xilinx.com:ip:clk_wiz*"
  set PS7_PATTERN "xilinx.com:ip:processing_system7*"
  set MPSOC_PATTERN "xilinx.com:ip:zynq_ultra_ps_e:*"
  set ZYNQ_PATTERN "xilinx\.com:ip:(processing_system7|processing_system8|zynq_ultra_ps_e):*"
  set MIG_7SERIES_PATTERN "xilinx.com:ip:mig_7series:*"
  set MIG_ULTRASCALE_PATTERN "xilinx.com:ip:mig:*"
  set MIG_PATTERN "xilinx\.com:ip:(mig_7series|mig|ddr3|ddr4):*"


  variable DEFAULT_CLK_SRC_PRIORITY
  set DEFAULT_CLK_SRC_PRIORITY [list ZYNQ CLK_WIZ  MIG PORT]

  # Use this tpo specify a particular clk pin
  # e.g. /ps7/FCLK_CLK3
  variable DEFAULT_CLK_SRC
  set DEFAULT_CLK_SRC ""

  variable PSR_CLK_IN
  variable PSR_RST_IN
  variable PSR_DCM_LOCKED
  set PSR_CLK_IN "clk_in"
  set PSR_RST_IN "ext_rst_in"
  set PSR_DCM_LOCKED "dcm_locked"

  variable AUTO_CONNECT_CLKRST
  set AUTO_CONNECT_CLKRST "Auto"

  # Exported functions
  namespace export \
    search_clk_src \
    get_clk_choices \
    get_clk_src_from_choices \
    trim_freq_hz_from_clk_choices \
    get_sink_clk \
    get_src_clk \
    is_clksrc_compatible \
    get_sink_rst \
    get_src_rst \
    get_default_rst \
    get_rst_polarity \
    get_rst_type \
    get_rst_pin_from_proc_sys_rst \
    get_clksrc_for_intf \
    find_clk_choices_for_intf \
    connect_clks \
    connect_rsts \
    connect_rsts_default \
    connect_aximm_clk_rst \
    connect_axis_clk_rst
  
  namespace import ::bd::utils::*
  namespace import ::bd::mig_utils::*

}

# ----------------------------------------------------------------------------
# -- Functions to get a list of possible clk sources

## Search entire design for clock sources with a particular frequency
# @param requested_freq_hz e.g. 125000000
# @param filter_vlnv filter results against a VLNV e.g. xilinx.com:ip:clk_wiz:*
# @return returns a list of clocks
proc ::bd::clkrst::search_clk_src {requested_freq_hz {filter_vlnv {} } } {
  # look for other clk pin sources
  set curr_inst [current_bd_instance .]
  current_bd_instance /
  set clk_pins [get_bd_pins -quiet -filter "TYPE==clk && DIR==O && CONFIG.FREQ_HZ==$requested_freq_hz" -hierarchical *]
  current_bd_instance $curr_inst

  if {[bd::utils::not_empty $filter_vlnv]} {
    #set clk_pins [bd::utils::map { x {filter [bd::utils::get_parent $x] -filter {vlnv =~ $filter_vlnv}}} $clk_pins 1]
    set clk_pins [bd::utils::map { x { if { [bd::utils::not_empty [filter [bd::utils::get_parent $x] {vlnv =~ xilinx.com:ip:clk_wiz:*}]] } {return $x}  } }  $clk_pins 1]
  }
 
  return $clk_pins
}

## 
# Get a list of clock sources, and determine the default choice. If the ref_clk
# is connected to one of the choices, that choice marked as the default. Otherwise the
# default is determined with the following precedence:
#  - The source of ref_clk 
#  - First clk output of the first found clock wizard
#  - Clock sources from other cells like Mig, Zynq
#  - Clock sources from existing Clk ports
#  - New Clocking Wizard
#  - New Clock port
# @param ref_clk A clock pin, whose clock src is set to default. May be "".
# @param default_choice Variable is set with the default choice
# @return A string list of choices, either fullpath to clks or string.
proc ::bd::clkrst::get_clk_choices {ref_clk default_choice {add_none 1} {add_auto 0} {add_migs 0} {prefer_mig_addn_clk 0} } {
  dbg "\[get_clk_choices\]"
  upvar $default_choice clk_default
  set clk_default ""
  set clk_choices [list]
  if { $add_none eq 1 } {
    lappend clk_choices "None"
  }
  if { $add_auto eq 1 } {
    lappend clk_choices $::bd::clkrst::AUTO_CONNECT_CLKRST
  }
  set first_src_clkwiz ""
  set first_src_zynq ""
  set first_src_mig ""
  set first_src_port ""


  # look for clk wizards
  set clkwizes [get_bd_cells -quiet -filter "VLNV=~ $::bd::clkrst::CLK_WIZ_PATTERN" /*]
  foreach clkwiz $clkwizes {
    for {set index 1} {$index <= 7} {incr index} {
      if {$index > 1 && ! [get_property CONFIG.Clkout${index}_Used $clkwiz]} { break }
      set clkfreq [get_property CONFIG.Clkout${index}_Requested_Out_Freq $clkwiz]
      set choice "$clkwiz/clk_out${index} ([expr int($clkfreq)] MHz)"
      lappend clk_choices $choice
      if { [is_connected $ref_clk $clkwiz/clk_out${index}] } {
        set clk_default $choice
      }
      if { [is_empty $first_src_clkwiz] } {
        set first_src_clkwiz $choice
      }
      if { [not_empty $::bd::clkrst::DEFAULT_CLK_SRC] && [is_empty $clk_default] } {
        if { $::bd::clkrst::DEFAULT_CLK_SRC == "$clkwiz/clk_out${index}" } {
          set clk_default $choice
        }
      }
    }
  }
  
  # look for other clk pin sources
  set curr_inst [current_bd_instance .]
  current_bd_instance /
  set clk_pins [get_bd_pins -quiet -filter {TYPE==clk && DIR==O} -hierarchical *]
  current_bd_instance $curr_inst
  set mig_clks [list]
  # filter away clock wiz since we already captured it above
  foreach pin $clk_pins {
    set parent [get_parent $pin]
    if {[not_empty [filter $parent "VLNV =~ $::bd::clkrst::CLK_WIZ_PATTERN"]]} {
      # filter away clock wiz since we already captured it above
      continue;
    }
    set clkfreq [get_property CONFIG.FREQ_HZ $pin]
    if {[is_empty $clkfreq]} {
       # $pin doesn't have FREQ_HZ set
      continue;
    }
    set choice "$pin ([expr int($clkfreq / 1000000)] MHz)"
    lappend clk_choices $choice
    if { [is_connected $ref_clk $pin] } {
      set clk_default $choice
    }

    set vlnv [get_property VLNV $parent]
    if { [is_empty $first_src_zynq] && [regexp $::bd::clkrst::ZYNQ_PATTERN $vlnv] } {
      set first_src_zynq $choice
    } 
    if { [is_empty $first_src_mig] && [regexp $::bd::clkrst::MIG_PATTERN $vlnv] } {
      # If prefer_mig_addn_clk is 1 (e.g. Microblaze block automation),
      # then MIG's addn_clkout will have higher preference than other regular
      # output clocks. For e.g. DDR4's addn_ui_clkout1 will have
      # higher precedence over its c0_ddr4_ui_clk.
      set pinname [get_short_name $pin]
      if { [regexp (.*)addn_(.*) $pin] == 1 } {
        if { $prefer_mig_addn_clk eq 1 } {
          set first_src_mig $choice
        } else {
          lappend mig_clks $choice
        }
      } else {
        if { $prefer_mig_addn_clk eq 1 } {
          lappend mig_clks $choice
        } else {
          set first_src_mig $choice
        }
      }
    }  
    if { [not_empty $::bd::clkrst::DEFAULT_CLK_SRC] && [is_empty $clk_default] } {
      if { $::bd::clkrst::DEFAULT_CLK_SRC == $pin } {
        set clk_default $choice
      }
    }
  }

  if { [is_empty $first_src_mig] && [not_empty $mig_clks] } {
    set first_src_mig [lindex $mig_clks 0]
  }
  
  # look for clk ports
  set clkports [get_bd_port -quiet -filter {TYPE=~clk} /*]
  foreach clkport $clkports {
    set clkfreq [get_property CONFIG.FREQ_HZ $clkport]
    if {[is_empty $clkfreq]} {
      # $pin doesn't have FREQ_HZ set
      continue;
    }
    set choice "$clkport ([expr int($clkfreq / 1000000)] MHz)"
    lappend clk_choices $choice
    if {[is_connected $ref_clk $clkport]} {
      set clk_default $choice
    }

    if {[is_empty $first_src_port]} {
      set first_src_port $choice
    }
    if { [not_empty $::bd::clkrst::DEFAULT_CLK_SRC] && [is_empty $clk_default] } {
      if { $::bd::clkrst::DEFAULT_CLK_SRC == $clkport } {
        set clk_default $choice
      }
    }
  }

  if { $add_migs eq 1 && $::bd::mig_utils::ENFORCE_ORDER eq 1 } {
    set migs [get_bd_cells -quiet -filter "VLNV=~ $::bd::clkrst::MIG_7SERIES_PATTERN || VLNV =~ $::bd::clkrst::MIG_ULTRASCALE_PATTERN" /*]
    foreach mig $migs {
      # Only consider those MIG blocks which are yet to be configured and could be
      # configured via Block-automation
      if { [::bd::mig_utils::can_apply_mig_rule $mig ""] == false } {
        continue
      }

      set migclklist [::bd::mig_utils::get_mig_out_clklist $mig]
      if { [::bd::utils::is_empty $migclklist] } {
        continue
      }

      foreach migclk $migclklist {
        set clkname [lindex $migclk 0]
        set clkfreq [lindex $migclk 1]
        set choice "$clkname ($clkfreq MHz)"
        lappend clk_choices $choice

        if { [is_empty $first_src_mig] } {
          set first_src_mig $choice
        }
      }
    }
  }

  # Add the 2 standard strings
  lappend clk_choices $::bd::clkrst::NEW_CLK_WIZ
  lappend clk_choices $::bd::clkrst::NEW_CLK_PORT
  # Removing for 2014.3. TODO: will come back...
  # if { $add_migs eq 1 && $::bd::mig_utils::ENFORCE_ORDER eq 1 } {
  #   lappend clk_choices $::bd::clkrst::NEW_MIG
  # }
  
  if {[is_empty $clk_default]} {
    # Try check if clk_wiz, ps7 or mig should be default
    # Otherwise Make NEW_CLK_WIZ the default
    foreach default_clk_priority $::bd::clkrst::DEFAULT_CLK_SRC_PRIORITY {
      switch -exact $default_clk_priority {
        CLK_WIZ {
          if { [not_empty $first_src_clkwiz] } {
            set clk_default $first_src_clkwiz
            break;
          }
        }
        ZYNQ {
          if { [not_empty $first_src_zynq] } {
            set clk_default $first_src_zynq
            break;
          }
        }
        MIG {
          if { [not_empty $first_src_mig] } {
            set clk_default $first_src_mig
            break;
          }
        }
        PORT {
          if { [not_empty $first_src_port] } {
            set clk_default $first_src_port
            break;
          }
        }
        default {
          puts "Unknown default clk priority $default_clk_priority given."
        }
      }
    }

    if {[is_empty $clk_default]} {
      set clk_default $::bd::clkrst::NEW_CLK_WIZ
    }
  }
  return $clk_choices
}


##
# Given a choice string (as returned from get_clocking_widget or get_clk_choices)
# return a source clk pin. If the choice is "New Clocking Wizard" or 
# "New External Port", also create those objects. 
# @param choice A Choice string as returned from get_clk_choices
# @return a Source clk pin, or "" if "None" is the choice
proc ::bd::clkrst::get_clk_src_from_choices {choice} {
  if { [is_empty $choice] || [string equal -nocase $choice "None"] || [string equal -nocase $choice $::bd::clkrst::AUTO_CONNECT_CLKRST]} {
    return ""
  }

  set clk ""

  if {[string equal $choice  ${bd::clkrst::NEW_CLK_WIZ}]} {
    set clk_wiz [bd::clkrst::Create_clk_wiz]
    set clk [get_bd_pins -quiet ${clk_wiz}/CLK_OUT1]
  } elseif {[string equal $choice ${bd::clkrst::NEW_CLK_PORT}]} {
    set curr_instance [current_bd_instance .]
    current_bd_instance /
    set clk [bd::utils::create_unique_port clk_100MHz -dir I -type clk]
    current_bd_instance $curr_instance
    set_property CONFIG.FREQ_HZ 100000000 $clk
  } else {
    # string will be of the form
    # "/a/b/c (### MHz)"
    set index [string last "(" $choice]
    set name [string range $choice 0 [expr $index - 2]]
    set clk [get_bd_pins -quiet $name]
    if {[is_empty $clk]} {
      set clk [get_bd_ports -quiet $name]
    } 
  }

  return $clk
}

proc ::bd::clkrst::trim_freq_hz_from_clk_choices { clk_choices } {
  upvar $clk_choices clks_list

  set numClks [llength $clks_list]
  for { set i 0 } { $i < $numClks } { incr i } {
    set clk_choice [lindex $clks_list $i]
    # string will be of the form
    # "/a/b/c (### MHz)"
    set index [string last "(" $clk_choice]
    if { $index eq -1 } continue

    set name [string range $clk_choice 0 [expr $index - 2]]
    lset clks_list $i $name
  }

  return
}

## \private
# Create a clocking wiz ip and return the object
# Clock wiz's input clks should be connected by board automation rules.
proc ::bd::clkrst::Create_clk_wiz {} {
  set curr_instance [current_bd_instance .]

  current_bd_instance /
  set clk_wiz [bd::utils::create_unique_cell clk_wiz clk_wiz]
  #set clk_port  [bd::utils::create_unique_port CLK_IN1 -dir I -type clk]
  current_bd_instance $curr_instance

  #set_property CONFIG.FREQ_HZ 100000000 $clk_port

  #connect_bd_net $clk_port [get_bd_pins ${clk_wiz}/CLK_IN1]

  return $clk_wiz
}

## \private
# given a clkwiz, returns the slowest clk 
proc ::bd::clkrst::Get_slowest_clk_on_clkwiz {clkwiz} {
  set slowest_clk 0
  set clk_src {}
  for {set index 1} {$index <= 7} {incr index} {
    if {$index > 1 && ! [get_property CONFIG.Clkout${index}_Used $clkwiz]} { break }
    set pin [get_bd_pins -quiet ${clkwiz}/CLK_OUT${index}]
    set clkfreq [get_property CONFIG.FREQ_HZ $pin]
    if { $slowest_clk == 0 } {
      set slowest_clk $clkfreq
      set clk_src $pin
      set dcm_lock [get_bd_pins -quiet ${clkwiz}/LOCKED]
    } else {
      if { $clkfreq < $slowest_clk } {
        set slowest_clk $clkfreq
        set clk_src $pin
        set dcm_lock [get_bd_pins -quiet ${clkwiz}/LOCKED]
      }
    }
  }

  return $clk_src
}


## \private
# given a ps7, returns the slowest clk
# returns "" or a number for the numbered FCLK-clk##
# that way can use for reset too.
proc ::bd::clkrst::Get_slowest_clk_on_ps7 {ps7} {
  set slowest_clk 0
  set clk_idx {}
  foreach n [list 0 1 2 3] {
    set pin [get_bd_pins -quiet ${ps7}/FCLK_CLK${n}]
    if {[not_empty $pin]} {
      set clkfreq [get_property CONFIG.FREQ_HZ $pin]
      if { $slowest_clk == 0 } {
        set slowest_clk $clkfreq
        set clk_idx $n
      } else {
        if { $clkfreq < $slowest_clk } {
          set slowest_clk $clkfreq
          set clk_idx $n
        }
      }
    }
  }
  return $clk_idx
}

## \private
# given a ps7 and clk_idx, returns suitable rst_src generated
# by the PS7. Returns "", if no suitable rst-src could be found
proc ::bd::clkrst::Get_rst_on_ps7 {ps7 clk_idx} {
  # prefer rst-src, with same index as clk_idx, if available
  set rst_src [get_bd_pins -quiet ${ps7}/FCLK_RESET${clk_idx}_N]
  if {[not_empty $rst_src]} {
     return $rst_src
  }

  # if a rst_src with same $clk_idx not available, then check if
  # any rst-src is available, starting from index "0"
  set rst_idx 0
  # Zynq can generate upto 4 PS reset outputs to the PL
  set max_rst_idx 3
  while {$rst_idx<$max_rst_idx} {
    set rst_src [get_bd_pins -quiet ${ps7}/FCLK_RESET${rst_idx}_N]
    if {[not_empty $rst_src]} {
      return $rst_src
    }
    incr rst_idx
  }

  return ""
}

## \private
# given a mpsoc and clk_idx, returns suitable rst_src generated
# by the mpsoc. Returns "", if no suitable rst-src could be found
proc ::bd::clkrst::Get_rst_on_mpsoc {mpsoc clk_idx} {
  # prefer rst-src, with same index as clk_idx, if available
  set rst_src [get_bd_pins -quiet ${mpsoc}/pl_resetn${clk_idx}]
  if {[not_empty $rst_src]} {
     return $rst_src
  }

  # if a rst_src with same $clk_idx not available, then check if
  # any rst-src is available, starting from index "0"
  set rst_idx 0
  # Zynq can generate upto 4 PS reset outputs to the PL
  set max_rst_idx 3
  while {$rst_idx<$max_rst_idx} {
    set rst_src [get_bd_pins -quiet ${mpsoc}/pl_resetn${rst_idx}]
    if {[not_empty $rst_src]} {
      return $rst_src
    }
    incr rst_idx
  }

  return ""
}


proc ::bd::clkrst::wire_psr_inputs { psr psr_ip_dict } {
  dbg "\[wire_psr_inputs\]"

  # Connect clk / rst / dcm_locked to psr
  set clk_src [dict get $psr_ip_dict $::bd::clkrst::PSR_CLK_IN]
  if {[not_empty $clk_src]} {
    set psr_slowest_sync_clk [get_bd_pins -quiet ${psr}/Slowest_sync_clk]
    if { ![is_driven $psr_slowest_sync_clk] } {
      #dbg "wire_psr_inputs: connecting $clk_src to $psr_slowest_sync_clk"
      connect_bd_net $clk_src $psr_slowest_sync_clk
    }

    set dcm_locked [dict get $psr_ip_dict $::bd::clkrst::PSR_DCM_LOCKED]
    if {[not_empty $dcm_locked]} {
      set psr_dcm_locked [get_bd_pins -quiet ${psr}/Dcm_locked]
      if { ![is_driven $psr_dcm_locked] } {
        #dbg "wire_psr_inputs: connecting $dcm_locked to $psr_dcm_locked"
        connect_bd_net $dcm_locked $psr_dcm_locked
      }
    }

    set rst_src [dict get $psr_ip_dict $::bd::clkrst::PSR_RST_IN]
    if {[not_empty $rst_src]} {
      # PSR will update ext_reset_in's polarity based on rst_src during parameter propagation
      set psr_ext_rst_in [get_bd_pins -quiet ${psr}/Ext_Reset_In]
      if { ![is_driven $psr_ext_rst_in] } {
        #dbg "wire_psr_inputs: connecting $rst_src to $psr_ext_rst_in"
        connect_bd_net $rst_src $psr_ext_rst_in
      }
    }
  }
 
}

proc ::bd::clkrst::find_psr_inputs_for_slowest_clk { psr_ip_dict } {
  dbg "\[find_psr_inputs_for_slowest_clk\]"

  upvar $psr_ip_dict psr_inputs
  set clk_src ""
  set dcm_locked ""
  set rst_src ""

  # look for slowest clock - giving preference to clocking wizards
  set slowest_clk 0
  set clkwizes [get_bd_cells -quiet -filter "VLNV=~ $::bd::clkrst::CLK_WIZ_PATTERN" /*]
  # Look for a clksrc and rst src for psr
  foreach clkwiz $clkwizes {
    set pin [Get_slowest_clk_on_clkwiz $clkwiz]
    if {[not_empty $pin]} {
      set clkfreq [get_property CONFIG.FREQ_HZ $pin]
      if { $slowest_clk == 0 } {
        set slowest_clk $clkfreq
        set clk_src $pin
        set dcm_locked [get_bd_pins -quiet ${clkwiz}/LOCKED]
      } else {
        if { $clkfreq < $slowest_clk } {
          set slowest_clk $clkfreq
          set clk_src $pin
          set dcm_locked [get_bd_pins -quiet ${clkwiz}/LOCKED]
        }
      }
    }
  }

  # If no clocking wizard blk found, look for other clk sources
  if {[is_empty $clk_src]} {
    set curr_inst [current_bd_instance .]
    current_bd_instance /
    set clk_pins [get_bd_pins -quiet -filter {TYPE==clk && DIR==O} -hierarchical *]
    current_bd_instance $curr_inst
    # filter away clock wiz since we already captured it above
    foreach pin $clk_pins {
      set parent [get_parent $pin]
      if {[not_empty [filter $parent "VLNV =~ $::bd::clkrst::CLK_WIZ_PATTERN"]]} {
        # filter away clock wiz since we already captured it above
        continue;
      }
      set clkfreq [get_property CONFIG.FREQ_HZ $pin]
      if { $slowest_clk == 0 } {
        set slowest_clk $clkfreq
        set clk_src $pin
      } else {
        if { $clkfreq < $slowest_clk } {
          set slowest_clk $clkfreq
          set clk_src $pin
        }
      }
    }
  } 

  # If clk_src is on MIG, find associated rst_src, dcm_locked inputs as well
  if {[not_empty $clk_src]} {
    # Check to see if clk_src has an associated rst output and if it is Mig
    set parent_blk [get_parent $clk_src]
    set is_mig [regexp $::bd::clkrst::MIG_PATTERN [get_property VLNV $parent_blk] ]
    if { $is_mig } {
      bd::clkrst::get_rst_for_mig_clk $clk_src rst_src dcm_locked
    }
  }

  dict set psr_inputs $::bd::clkrst::PSR_CLK_IN $clk_src
  dict set psr_inputs $::bd::clkrst::PSR_RST_IN $rst_src
  dict set psr_inputs $::bd::clkrst::PSR_DCM_LOCKED $dcm_locked

  return
}

proc ::bd::clkrst::find_psr_inputs_for_clk { psr_clk_hint psr_ip_dict } {
  dbg "\[find_psr_inputs_for_clk\]"

  upvar $psr_ip_dict psr_inputs
  set clk_src ""
  set dcm_locked ""
  set rst_src ""

  dbg "psr_clk_hint: $psr_clk_hint"
  # psr_clk_hint may come from Clocking Wizard or PS7 or MIG or external clk-port
  set hint_blk [get_parent $psr_clk_hint]
  if {[not_empty $hint_blk]} {
    # if hint_blk is a clkwiz
    set is_clkwiz [filter $hint_blk "VLNV=~ $::bd::clkrst::CLK_WIZ_PATTERN"]
    if {[not_empty $is_clkwiz]} {
      # set clk_src [Get_slowest_clk_on_clkwiz $hint_blk]
      set clk_src $psr_clk_hint
      set dcm_locked [get_bd_pins -quiet ${hint_blk}/LOCKED]
    } else {
      # if hint_blk is ps7
      set is_ps7 [regexp $::bd::clkrst::PS7_PATTERN [get_property VLNV $hint_blk] ]
      set is_mpsoc [regexp $::bd::clkrst::MPSOC_PATTERN  [get_property VLNV $hint_blk] ]
      if { $is_ps7 } {
        # set clk_idx [Get_slowest_clk_on_ps7 $hint_blk]
        set clk_idx ""
        eval [regexp $hint_blk/FCLK_CLK(.*) $psr_clk_hint matched clk_idx]
        dbg "clk_idx = $clk_idx "
        if {[not_empty $clk_idx]} {
          set clk_src [get_bd_pins -quiet ${hint_blk}/FCLK_CLK${clk_idx}]
          set rst_src [bd::clkrst::Get_rst_on_ps7 $hint_blk $clk_idx]
        }
      } elseif { $is_mpsoc } {
        # set clk_idx [Get_slowest_clk_on_ps7 $hint_blk]
        set clk_idx ""
        eval [regexp $hint_blk/pl_clk(.*) $psr_clk_hint matched clk_idx]
        dbg "clk_idx = $clk_idx "
        if {[not_empty $clk_idx]} {
          set clk_src [get_bd_pins -quiet ${hint_blk}/pl_clk${clk_idx}]
          set rst_src [bd::clkrst::Get_rst_on_mpsoc $hint_blk $clk_idx]
        }
      } else {
        # if hint_blk is mig
        set is_mig [regexp $::bd::clkrst::MIG_PATTERN [get_property VLNV $hint_blk] ]
        if { $is_mig } {
          set clk_src $psr_clk_hint
          bd::clkrst::get_rst_for_mig_clk $clk_src rst_src dcm_locked
        } else {
          # psr_clk_hint comes from something other than clk_wiz/PS7/MIG - just pick up that given source
          set clk_src $psr_clk_hint
          set rst_src [get_src_rst $clk_src]
        }
      }
    }
  } else {
    # psr_clk_hint does not have a parent => psr_clk_hint is an external clk-port
    set clk_src $psr_clk_hint
  }

  dict set psr_inputs $::bd::clkrst::PSR_CLK_IN $clk_src
  dict set psr_inputs $::bd::clkrst::PSR_RST_IN $rst_src
  dict set psr_inputs $::bd::clkrst::PSR_DCM_LOCKED $dcm_locked

  return
}

# TODO: After MIG's component.xml is updated to specify correct ASSOCIATED_RESET,
# ASSOCIATED_ASYNC_RESET and ASSOCIATED_MMCM_LOCK, remove following hardcoded
# clk/rst/mmcm retrieval for MIG
proc ::bd::clkrst::get_rst_for_mig_clk { clk_src rst_src dcm_locked } {
  dbg "\[get_rst_for_mig_clk\]"

  upvar $rst_src rst_in
  upvar $dcm_locked dcm_locked_in

  set clk_name [get_property NAME $clk_src]
  set mig_blk [get_parent $clk_src]

  set rst_in [get_src_rst $clk_src]

  if {[string match ui_clk $clk_name] || [string match ui_addn_clk_0 $clk_name]} {
    # set rst_in [get_bd_pins ${mig_blk}/ui_clk_sync_rst]
    set dcm_locked_in [get_bd_pins ${mig_blk}/mmcm_locked]
  }

  if {[string match c[0-7]_ui_clk $clk_name] || [string match c[0-7]_ui_addn_clk_0 $clk_name]} {
    set rst_prefix [string range $clk_name 0 2]
    # set rst_in [get_bd_pins ${mig_blk}/${rst_prefix}ui_clk_sync_rst]
    set dcm_locked_in [get_bd_pins ${mig_blk}/${rst_prefix}mmcm_locked]
  }

  return
}

## \private
# Create a proc sys rst
# Connect up clock of psr and dcm lock
# If a hint blk is provided, try to drive the Proc_sys_rst's clk and ext_reset
# from the hint_blk -- usually ps7 or clk_wiz
proc ::bd::clkrst::Create_proc_sys_rst { {psr_clk_hint ""} } {
  dbg "\[Create_proc_sys_rst\]"
  set curr_instance [current_bd_instance .]
  current_bd_instance /

  set psr_ip_dict [dict create]
  if {[not_empty $psr_clk_hint]} {
    dbg "psr_clk_hint provided as $psr_clk_hint"
    bd::clkrst::find_psr_inputs_for_clk $psr_clk_hint psr_ip_dict
  } else {
    bd::clkrst::find_psr_inputs_for_slowest_clk psr_ip_dict
  }

  # TODO: move this name-generation into a separate proc
  set clk_src [dict get $psr_ip_dict $::bd::clkrst::PSR_CLK_IN]
  set clk_freq [get_property CONFIG.FREQ_HZ $clk_src]
  set short_name ""
  set clk_parent [::bd::utils::get_parent $clk_src]
  if {[::bd::utils::not_empty $clk_parent]} {
    set short_name [::bd::utils::get_short_name $clk_parent]
    #dbg "Create_proc_sys_rst: found parent block $short_name for $clk_src"
  } else {
    set short_name [::bd::utils::get_short_name $clk_src]
    #dbg "Create_proc_sys_rst: found external clk-port $short_name for $clk_src"
  }

  # If clock-frequency is not yet set, then generate PSR name w/o freq MHz suffix
  set psr_name "rst_${short_name}"
  if { [not_empty $clk_freq] } {
    set clk_mhz [expr int($clk_freq / 1000000)]
    set psr_name "rst_${short_name}_${clk_mhz}M"
  }
  #dbg "Create_proc_sys_rst: going to create pro_sys_reset block with name $psr_name"

  set psr [bd::utils::create_unique_cell proc_sys_reset $psr_name]
  dbg "Create_proc_sys_rst: created $psr"

  # make connection
  set success [::bd::clkrst::wire_psr_inputs $psr $psr_ip_dict]

  current_bd_instance $curr_instance

  return $psr
}


# --------------------------------------------------------------------------
## Given an interface, returns a sink clk pin for the interface
proc ::bd::clkrst::get_sink_clk { intf } {
  return [Get_associated_clk $intf 1]
}

## Given an interface, returns a clk src (producer) pin for the interface
proc ::bd::clkrst::get_src_clk { intf } {
  return [Get_associated_clk $intf 0]
}

## Given an interface, returns the clk src that is driving the clk for that
# interface. e.g. if the interface is a S_AXI_0 on interconnect, will find
# the associated S_AXI_0_ACLK, and trance to find the drive of that clock.
proc ::bd::clkrst::search_src_clk { intf } {
  set clk [get_src_clk $intf]

  if { [bd::utils::not_empty $clk] } {
    return $clk
  }

  set clk [get_sink_clk $intf]
  if { [bd::utils::is_empty $clk] } {
    return ""
  }

  set clk [ find_bd_objs -quiet -legacy_mode -relation connected_to $clk]
  if { [bd::utils::not_empty $clk] } {
    return $clk
  }
  return ""
}

## \private Private function.  Mark as private to not display in doxygen
# @param intf The interface to look 
# @param sink 0==return only DIR=O or IO, 1== return only DIR=I, 2==return all
proc ::bd::clkrst::Get_associated_clk {intf sink} {
  dbg "\[Get_associated_clk\] $intf"
  set clk ""
  
  set intf_name [bd::utils::get_short_name $intf]
  set intfPort [expr { [get_property CLASS $intf] == "bd_intf_port" } ]
  
  # CONFIG.ASSOCIATED_BUSIF could be a : separated list, e.g. LMB_1:LMB_2:LMB_3 
  # this is why need to match with .*<xxx>.*
  #set clk [filter [get_bd_pins -quiet -of_objects $ip] -nocase -regexp "(INTF == FALSE) && (TYPE == clk ) && (CONFIG.ASSOCIATED_BUSIF =~ .*${intf_name}.*) ${dir}"]
  # we need an exact match: the intf_name may be the only element/occuring at the beginning/middle/end of the ":" separated list
  set assoc_busif "((CONFIG.ASSOCIATED_BUSIF =~ ${intf_name}) || (CONFIG.ASSOCIATED_BUSIF =~ ${intf_name}:.*) || (CONFIG.ASSOCIATED_BUSIF =~ .*:${intf_name}:.*) || (CONFIG.ASSOCIATED_BUSIF =~ .*:${intf_name}))"
  
  if { $intfPort eq 1 } {
    # For external ports, direction is reversed
    switch $sink {
      1 {set dir "&& (DIR =~ .*O)" }
      0 {set dir "&& (DIR == I)" }
      default {set dir ""}
    }

    # If it is an external intf-port, then look for suitable clock-port among external ports at root design level
    set ext_ports [ get_bd_ports -quiet -of_objects [current_bd_design] ]
    set clk [filter $ext_ports -nocase -regexp "(INTF == FALSE) && (TYPE == clk ) && ${assoc_busif} ${dir}"]
  } else {
    switch $sink {
      1 {set dir "&& (DIR == I)" }
      0 {set dir "&& (DIR =~ .*O)" }
      default {set dir ""}
    }

    # If it is a block intf-port, then look for suitable clock-port among parent cell's pins
    set ip [get_bd_cells -quiet -of_objects $intf]
    set clk [filter [get_bd_pins -quiet -of_objects $ip] -nocase -regexp "(INTF == FALSE) && (TYPE == clk ) && ${assoc_busif} ${dir}"]
  }

  dbg "get_associated_clk: of $intf --> Found clock: ($clk)"
  if { [llength $clk] > 1 } {
    set clk [get_first $clk]
  }

  if {[bd::utils::is_empty $clk]} {
    if { [get_property type $intf] == "hier" } {
      dbg "there"
      set clk [::bd::clkrst::Get_associated_clk_from_hier_boundary $intf $sink]
    }
  }

  return $clk
}

## \private Private function.  Mark as private to not display in doxygen
## (1) Look at an intf on a level of hier. Dive down the hier to find the true intf 
## that is connected to this hier_intf. 
## (2) Look for the associated clock on that interface
## (3) Trace that clock up to the top level and see if any clk pins on the hier is
##     connected to it. If so return it.
## Helper function of Get_associated_clk
proc ::bd::clkrst::Get_associated_clk_from_hier_boundary {intf sink} {
  set type [get_property type $intf] 
  if {$type != "hier"} { 
    return ""
  }

  set true_intf [find_bd_objs -quiet -legacy_mode -relation connected_to -boundary_type lower $intf]

  if { [::bd::utils::is_empty $true_intf] } {
    return ""
  }

  set true_ip [get_bd_cells -quiet -of_objects $true_intf]
  set true_clk [::bd::clkrst::Get_associated_clk $true_intf $sink]
  if { [::bd::utils::is_empty $true_clk] } {
    return ""
  }

  # if intf was on a level of hier, new we need to look at all "clk" ports 
  # on that level of hi
  set ip [get_bd_cells -quiet -of_objects $intf]
  set allclks [filter [get_bd_pins -quiet -of_objects $ip] -nocase "(TYPE == clk)"]
  
  ### Trace the clk pin from the true_clk #####
  foreach c $allclks {
    set potential_true_clks [find_bd_objs -quiet -legacy_mode -relation connected_to -boundary_type lower $c]
    foreach ptc $potential_true_clks {
      if {[string equal $ptc $true_clk]} {
        dbg "get_associated_clk_from_hier: of $intf --> Found clock: ($c)"
        return $c
      }
    }
  }
  
  return ""
}


# --------------------------------------------------------------------------

##
# Given a "rst" source. finds out associated clock-source(if any), which
# this rst should be in-sync with

proc ::bd::clkrst::get_assoc_clk_for_rst { rst } {
  dbg "\[get_assoc_clk_for_rst\]"

  if {[is_empty $rst]} {
    return ""
  }

  set ip [get_bd_cells -quiet -of_objects $rst]
  set rst_name [bd::utils::get_short_name $rst]

  # TODO: right now assuming ASSOCIATED_RESET to containing a single reset - look for exact match
  # could CONFIG.ASSOCIATED_RESET could be a : separated list, e.g. rst_1:rst_2 etc.?
  # set clk [filter [get_bd_pins -quiet -of_objects $ip] -nocase -regexp "(INTF == FALSE) && (TYPE == clk ) && (CONFIG.ASSOCIATED_RESET =~ ${rst_name})"]
  set assoc_sync_reset "((CONFIG.ASSOCIATED_RESET =~ ${rst_name}) || (CONFIG.ASSOCIATED_RESET =~ ${rst_name}:.*) || (CONFIG.ASSOCIATED_RESET =~ .*:${rst_name}:.*) || (CONFIG.ASSOCIATED_RESET =~ .*:${rst_name}))"
  set clk [filter [get_bd_pins -quiet -of_objects $ip] -nocase -regexp "(INTF == FALSE) && (TYPE == clk ) && $assoc_sync_reset"]
  dbg "get_assoc_clk_for_rst: of $rst --> Found clock: ($clk)"

  return $clk
}

proc ::bd::clkrst::is_clksrc_compatible { clk1 clk2 } {
  dbg "\[is_clksrc_compatible\]"

  if {[is_empty $clk1] || [is_empty $clk2]} {
    return 0
  }

  if {![is_src $clk1] || ![is_src $clk2]} {
    return 0
  }

  set clk2_type [get_property TYPE $clk2]
  set clk1_type [get_property TYPE $clk1]
  if { $clk2_type != "clk" || $clk1_type != "clk" } {
    # If either of the clock-sources' type is not set to 'clk'
    # yet, bail out (since we cannnot know that clock's frequency
    # etc. unless parameter propagation is run).
    return 0
  }

  set clkdomain_1 [get_property CONFIG.CLK_DOMAIN $clk1]
  set clkdomain_2 [get_property CONFIG.CLK_DOMAIN $clk2]

  if {[not_empty $clkdomain_1] && [not_empty $clkdomain_2]} {
    if {![string equal $clkdomain_1 $clkdomain_2]} {
      dbg "Clock-domain mismatch: $clk1 has $clkdomain_1 and $clk2 has $clkdomain_2 as respective domains"
      return 0
    }
  }
  # TODO: what if one or both domains not set?

  set clkfreq_1 [get_property CONFIG.FREQ_HZ $clk1]
  set clkfreq_2 [get_property CONFIG.FREQ_HZ $clk2]

  if {[not_empty $clkfreq_1] && [not_empty $clkfreq_2]} {
    if {![string equal $clkfreq_1 $clkfreq_2]} {
      dbg "Clock frequency mismatch: $clk1 has $clkfreq_1 and $clk2 has $clkfreq_2 as respective frequencies"
      return 0
    }
  }
  # TODO: what if one or both frequencies not set?

  set clkphase_1 [get_property CONFIG.PHASE $clk1]
  set clkphase_2 [get_property CONFIG.PHASE $clk2]

  if {[not_empty $clkphase_1] && [not_empty $clkphase_2]} {
    if {![string equal $clkphase_1 $clkphase_2]} {
      dbg "Clock phase mismatch: $clk1 has $clkphase_1 and $clk2 has $clkphase_2 as respective frequencies"
      return 0
    }
  }
  # TODO: what if one or both frequencies not set?

  return 1
}

proc ::bd::clkrst::is_rst_sinkclk_compatible { sink_clk ref_clk_src } {
  dbg "\[is_rst_sinkclk_compatible\]"

  set clk_valid 0
  set other_end_of_clk [find_bd_objs -quiet -legacy_mode -relation connected_to $sink_clk]
  if {[not_empty $other_end_of_clk]} {
    # TODO: this other end of clk can be ext clk input or clk-output of clk-generator repos blk
    # or clk-output at a hierarchical (non-appcore) boundary. Will they have their FREQ_HZ, PHASE
    # and CLK_DOMAIN resolved by now?
    set clk_valid [::bd::clkrst::is_clksrc_compatible $other_end_of_clk $ref_clk_src]
  } else {
    # If associated sink_clk is yet to be connected, return this as an acceptable connection.
    # CR 824459: If input rst_src is coming from proc_sys_reset and associated slowest_sync_clk
    # is already connected to a sourceless net, then do not return it as a valid-src, since
    # user may want to connect this net later to a source.
    set parent [filter [get_parent $sink_clk] "VLNV=~ $::bd::clkrst::PROC_SYS_RST_PATTERN"]
    if { [bd::utils::not_empty $parent] } {
      set net [get_bd_nets -quiet -of_objects $sink_clk]
      if { [bd::utils::is_empty $net] } {
        dbg "$sink_clk of Proc Sys Reset block $parent is not yet connected to any net - will treat as a compatible clock."
        set clk_valid 1
      } else {
        dbg "$sink_clk of Proc Sys Reset block $parent is already connected to net $net - will *not* treat it as compatible clock."
      }
    } else {
      # sink_clk is not on Proc Sys Reset block
      set clk_valid 1
    }
  }

  return $clk_valid
}

##
##
proc ::bd::clkrst::can_sync_rst_with_clk { rst_src clk_src } {
  dbg "\[can_sync_rst_with_clk\]"

  if {![is_src $rst_src]} {
    dbg "can_sync_rst_with_clk : rst_src $rst_src is not a SRC"
    return 0
  }

  if {![is_src $clk_src]} {
    dbg "can_sync_rst_with_clk : clk_src $clk_src is not a SRC"
    return 0
  }

  set rst_assoc_clk [get_assoc_clk_for_rst $rst_src]

  set clk_valid 0
  if { [not_empty $rst_assoc_clk] } {
    if { [is_sink $rst_assoc_clk] } {
      set clk_valid [::bd::clkrst::is_rst_sinkclk_compatible $rst_assoc_clk $clk_src]
    } else {
      set clk_valid [::bd::clkrst::is_clksrc_compatible $rst_assoc_clk $clk_src]
    }
  } else {
    # TODO: no associated clk found for the potential rst_src...weird...what do we do - return true for now
    dbg "Probable rst_src $rst_src is not obligated to be sync-ed with any associated clk"
    set clk_valid 1
  }

  return $clk_valid
}

proc ::bd::clkrst::find_compatible_psr { clk_src chk_hier } {
  dbg "\[find_compatible_psr\]"

  set psrs ""
  if {$chk_hier} {
    dbg "find_compatible_psr : Looking at all hierarchy levels"
    set psrs [get_bd_cells -quiet -hierarchical -filter "VLNV=~ $::bd::clkrst::PROC_SYS_RST_PATTERN" *]
  } else {
    dbg "find_compatible_psr : Looking only at same hierarchy level"
    set psrs [get_bd_cells -quiet -filter "VLNV=~ $::bd::clkrst::PROC_SYS_RST_PATTERN" /*]
  }

  if {[not_empty $psrs]} {
    dbg "find_compatible_psr : checking available proc_sys_rst blocks"
    foreach psr $psrs {
      set pinName slowest_sync_clk
      set psr_clk_in [get_bd_pins -quiet ${psr}/${pinName}]
      # check if this proc_sys_reset's slowest_sync_clk is compatible - if yes, we will be
      # using this pro_sys_reset block as default
      set clk_valid [::bd::clkrst::is_rst_sinkclk_compatible $psr_clk_in $clk_src]

      if {$clk_valid} {
        # dbg "find_compatible_psr : found comaptible psr block $psr"
        return $psr
      }
    }
  }

  return ""
}

##
# If a proc_sys_reset already exists, returns that as a viable rst src.
# If multiple exist, returns the first found, unless ref_rst is provided,
# in which case look to see which psr is connected to ref_rst and return that 
# guy. 
# If no psr exists, returns a string. "New Processor System Reset"
# The returned value may be passed directly to connect_rsts. If a string 
# is returned, connect_rsts will create a new proc sys rst.
# @param ref_rst A rst pin, whoice src is set to default (if it is a psr)
# @return A proc_sys_rst or "New Processor System Reset"
proc ::bd::clkrst::get_default_rst { clk_src ref_rst} {
  dbg "\[get_default_rst\]"
  dbg "get_default_rst : w.r.t. clk_src => $clk_src and reference rst => $ref_rst"

  if {[is_empty $clk_src]} {
      return -code error -errorinfo "Expected a clock source to be provided, w.r.t which default rst_src was to be found."
  }

  if { [not_empty $ref_rst] } {
    set src_rst_pin [find_bd_objs -quiet -legacy_mode -relation connected_to [$ref_rst]]
    if { [bd::utils::not_empty $src_rst_pin] } {
      set parent [filter [get_parent $src_rst_pin] "VLNV=~ $::bd::clkrst::PROC_SYS_RST_PATTERN"]
      if { [bd::utils::not_empty $parent] } {
        # dbg "get_default_rst : found $parent for ref_rst $ref_rst"
        if {[::bd::clkrst::can_sync_rst_with_clk $src_rst_pin $clk_src]} {
          # dbg "get_default_rst : parent proc_sys_rst $parent compatible with given clk_src $clk_src"
          return $parent
        }
      }
    }
  }

  # Look for PSR at same hier level first
  set default_psr [::bd::clkrst::find_compatible_psr $clk_src 0]
  
  # If no comatible proc_sys_reset found at same level, Look in all levels of hier
  if {[bd::utils::is_empty $default_psr]} {
    set default_psr [::bd::clkrst::find_compatible_psr $clk_src 1]
  }

  if { [bd::utils::not_empty $default_psr] } {
    return $default_psr
  }

  # None found
  dbg "get_default_rst : New Processor System Reset"
  return "New Processor System Reset"
  
}

## Given a clock, returns a sink rst pin associated with the clock
# In most cases, we are interested only in associated resets which
# should be synchronous with the given clock. However, during AXIMM
# connection automation, associated clock of an interface may have
# an associated sink reset which is not obligated to be in-sync with
# this clock. Even in that case we need to connect up such associated
# asynchronous sink-resets, fo completeness (and backward-compatibility)
# of AXIMM connection automation
proc ::bd::clkrst::get_sink_rst {clk {find_async_rst 0} } {
  return [Get_associated_rst $clk 1 $find_async_rst]
}

## Given a clock, return a src rst pin asociated with the clk
proc ::bd::clkrst::get_src_rst {clk} {
  # find_async_rst parameter is 0 always while finding associated src-reset
  return [Get_associated_rst $clk 0 0]
}

## \private
proc ::bd::clkrst::Get_associated_rst {clk sink find_async_rst } {
  dbg "\[Get_associated_rst $clk $sink\]"
  if {[is_empty $clk]} {
    return ""
  }

  # If this is an external clock-port, then look for associated
  # reset port among external ports of the design.
  set extPort [expr { [get_property CLASS $clk] == "bd_port" } ]
  if { $extPort eq 1 } {
    # For external ports, direction is reversed
    switch $sink {
      1 {set dir "&& (DIR =~ .*O)" }
      0 {set dir "&& (DIR == I)" }
      default {set dir ""}
    }

    set sync_rsts [get_property CONFIG.ASSOCIATED_RESET $clk]
    if { [not_empty $sync_rsts] } {
      # If it is an external clock-port, then look for suitable reset-port among external ports at root design level
      set ext_ports [ get_bd_ports -quiet -of_objects [current_bd_design] ]
      set sync_rst_list [split $sync_rsts ":"]
      foreach sync_rst_name $sync_rst_list {
        set rst [filter $ext_ports -nocase -regexp "(INTF == FALSE) && (TYPE == rst ) && PATH =~ .*${sync_rst_name} $dir"]
        if { [not_empty $rst] } {
          return $rst
        }
      }
    }

    # If nothing could be found, return empty string
    return ""
  }

  # If this is clock-port on a cell, then look for associated reset
  # on the same cell.
  switch $sink {
    1 {set dir "&& (DIR == I)" }
    0 {set dir "&& (DIR =~ .*O)" }
    default {set dir ""}
  }

  set sync_rsts [get_property CONFIG.ASSOCIATED_RESET $clk]
  set parent_cell [get_parent $clk]

  set clk_has_assoc_rst 0
  if { [not_empty $sync_rsts] } {
    set clk_has_assoc_rst 1
    set sync_rst_list [split $sync_rsts ":"]
    foreach sync_rst_name $sync_rst_list {
      set rst [filter [get_bd_pin -quiet -of_objects [get_bd_cells -quiet -of_objects $clk]] -regexp -nocase "PATH =~ .*${parent_cell}/${sync_rst_name} $dir"]
      if { [not_empty $rst] } {
        return $rst
      }
    }
  }

  # If asynchronous resets are to be connected, find that
  if { $find_async_rst == 1 } {
    set async_rsts [get_property CONFIG.ASSOCIATED_ASYNC_RESET $clk]
    if { [not_empty $async_rsts] } {
      set clk_has_assoc_rst 1
      set async_rst_list [split $async_rsts ":"]
      foreach async_rst_name $async_rst_list {
        set rst [filter [get_bd_pin -quiet -of_objects [get_bd_cells -quiet -of_objects $clk]] -regexp -nocase "PATH =~ .*${parent_cell}/${async_rst_name} $dir"]
        if { [not_empty $rst] } {
          return $rst
        }
      }
    }
  }

  if { $clk_has_assoc_rst == 0 && $parent_cell != "" && [get_property type $parent_cell] == "hier" } {
    # Check if clk is on hier boundary. if so search down
    set rst [::bd::clkrst::Get_associated_rst_from_hier_boundary $clk $sink $find_async_rst]
    return $rst
  }

  # if { [not_empty $rst_name] } {
  #   # clk is packaged with associated reset
  #   set rst [filter [get_bd_pin -quiet -of_objects [get_bd_cells -quiet -of_objects $clk]] -regexp -nocase "PATH =~ .*${parent_cell}/${rst_name} $dir"]
  #   return $rst
  # } else {
  #   if {  $parent_cell != "" && [get_property type $parent_cell] == "hier" } {
  #     # Check if clk is on hier boundary. if so search down
  #     set rst [::bd::clkrst::Get_associated_rst_from_hier_boundary $clk $sink]
  #     return $rst
  #   }
  # }
  return ""
}


## \private
proc ::bd::clkrst::Get_associated_rst_from_hier_boundary {clk sink find_async_rst} {
  set parent_cell [get_parent $clk]
  set type [get_property type $parent_cell] 
  if {$type != "hier"} { 
    return ""
  } 
  set allrsts [filter [get_bd_pins -quiet -of_objects $parent_cell] -nocase "(TYPE == rst)"]
  set true_clks [find_bd_objs -quiet -legacy_mode -relation connected_to -boundary lower $clk]
  foreach true_clk $true_clks {
    set true_rst [::bd::clkrst::Get_associated_rst $true_clk $sink $find_async_rst]
    if {[::bd::utils::not_empty $true_rst]} {
      # found a true_rst, now see if there is a rst pin on the same level 
      # as clk that is connected to this true_rst
      foreach r $allrsts {
        set potential_true_rsts [find_bd_objs -quiet -legacy_mode -relation connected_to -boundary_type lower $r]
        foreach ptr $potential_true_rsts {
          if {[string equal $ptr $true_rst]} {
            dbg "get_associated_rst_from_hier: of $clk --> Found rst: ($r)"
            return $r
          }
        }
      }
    }
  }
  return ""
}


##
# Given a rst pin return the polarity of reset it accepts
# @param pin/port
# @return String ACTIVE_LOW,  ACTIVE_HIGH
proc ::bd::clkrst::get_rst_polarity {obj} {
  set src_rst_polarity [get_property CONFIG.POLARITY $obj]
  if {[llength $src_rst_polarity]==0} {
    # No CONFIG.POLARITY property, just look at name if end in n or N 
    # set to ACTIVE_LOW
    if {[string equal -nocase [string index $obj end] "n"]} {
      set src_rst_polarity ACTIVE_LOW
    } else {
      set src_rst_polarity ACTIVE_HIGH
    }
  }
  return $src_rst_polarity
}

##
# Given a rst pin, return the type of reset: 
# PROCESSOR, INTERCONNECT or PERIPHERAL
# Will not push in hier. Just looks at surface
# Hard-coding to detect interconnect and return relevant type.
proc ::bd::clkrst::get_rst_type {obj} {
  set type [get_property CONFIG.TYPE $obj]
  if {[is_empty $type]} {
    set parent [get_parent $obj]
    if {[not_empty $parent]} {
      if {[not_empty [filter $parent {VLNV=~xilinx.com:ip:axi_interconnect*}]]} {
        set shortName [get_short_name $obj]
        if {[string equal $shortName ARESETN]} {
          set type "INTERCONNECT"
        } else {
          set type "PERIPHERAL"
        }
      }
    }
  }
  return $type
}

##
# Given a proc_sys_rst, rsttype and polrity, returns the relevant 
# proc sys rst pin.
# @param psr A proc_sys_rst cell object
# @param rsttype String: PERIPHERAL, INTERCONNECT or PROCESSOR [default is peripheral]
# @param polarity String: ACTIVE_HIGH or ACTIVE_LOW [default is ACTIVE_HIGH]
# @return pin name string
proc ::bd::clkrst::get_rst_pin_from_proc_sys_rst {psr rsttype polarity} {
  if {[string equal -nocase $polarity ACTIVE_LOW]} {
    if {[string equal -nocase $rsttype INTERCONNECT]} {
      set pin Interconnect_aresetn
    } else {
      if {[string equal -nocase $rsttype PROCESSOR]} {
        set pin ""
      } else {
        set pin Peripheral_aresetn
      }
    }
  } else {
    if {[string equal -nocase $rsttype INTERCONNECT]} {
      set pin Bus_Struct_Reset
    } else {
      if {[string equal -nocase $rsttype PROCESSOR]} {
        set pin MB_Reset
      } else {
        set pin Peripheral_Reset
      }
    }
  }
  
  return $pin
}

proc ::bd::clkrst::get_clksrc_for_intf { intf } {
  dbg "\[get_clksrc_for_intf\] input intf : $intf"

  if {[is_empty $intf]} {
    dbg "No reference intf provided to find associated clk"
    return ""
  }

  # check if it really is an intf
  set class [get_property CLASS $intf]
  if {![string equal $class "bd_intf_pin"]} {
    dbg "Input $intf is not an interface"
    return ""
  }

  set src_clk [get_src_clk $intf]
  if {[is_empty $src_clk]} {
    # If ref interface does not proffer a clock,
    # look for sink clk and find its source
    set sink_clk [get_sink_clk $intf]
    if {[is_empty $sink_clk]} {
      #Can't find sink or src clk from intf, just return
      dbg "Unable to find sink or src clks from reference interface $intf"
      return ""
    }
    set src_clk [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $sink_clk]
  }

  if {[is_empty $src_clk]} {
    dbg "Unable to find sink or src clks from reference interface $intf"
    return ""
  }

  return $src_clk
}

# ---------------------------------------------------------------------------
# -- Functions to connect clk sources to clk sinks

##
# Connect up the associated clocks of the given list of interfaces or
# sink-clk pins. All clks will be connected to the same
# clk src.
# 
# - Foreach intf/pin
#   - Pins must be clk sinks. Connect Pins directly to clk_src
#   - If interface 
#      - Look for associated clk and if associated_clk is sink, 
#        connect directly to clk_src
#     
# @param pins_intf_l A list of pin, ports, intf_pins, intf_port objects
#                    whose clks and rst need connecting
# @param clk_src     Clk src to use. Or a reference interface. If reference
#                    interface is provided, find associated clk and use that.
#                    If the ref's assocaited clk is not connected, do nothing.

proc ::bd::clkrst::connect_clks {pins_intf_l clk_src } {
  dbg "\[connect_clks\] $pins_intf_l to clk_src $clk_src"
 
  if {[is_empty $clk_src]} {
      return -code error -errorinfo "Expected a clock source to be provided."
  }

  dbg "Using clk_src: $clk_src"

  foreach obj $pins_intf_l {
    if { [is_sink $obj] } { 
      if { [string equal [get_property type $obj] clk] } {
        dbg "$obj is a clk pin/port connecting directly to $clk_src"
        # Check that obj is not already connected.
        set net [get_bd_nets -quiet -of_object $obj]
        if { [is_empty $net] } {
          # Connect directly
          dbg "connect_bd_net $clk_src $obj"
          connect_bd_net $clk_src $obj
        } else {
          # if this clock is connected to a source-less net, connect it to
          # given $clk_src
          set src_to_obj [find_bd_objs -quiet -legacy_mode -relation connected_to $obj]
          if { [is_empty $src_to_obj] } {
            dbg "$obj is connected to a source-less net - connect it to $clk_src"
            dbg "connect_bd_net $clk_src $obj"
            connect_bd_net $clk_src $obj
          }
          # $obj is already connected, should this be an error or warning
          # right now just ignore.
        }
      } 
    } else {
      # should be an interface
      if { ![is_intf_pin_port $obj] } {
        # Unexpected object
        return -code error -errorinfo "Unexpected object $obj encountered in call to bd::clkrst::connect_clk"
      }
      set obj_parent [bd::utils::get_parent $obj]
      set parentIsSC [filter $obj_parent {VLNV =~ "xilinx.com:ip:smartconnect:*"}]
      if { [bd::utils::is_empty $parentIsSC] } {
         set sink_clk [get_sink_clk $obj]
      } else {
         set sink_clk [get_sink_clk_SC $obj_parent $clk_src]
      }
      
      if {[not_empty $sink_clk]} {
        # Check that obj is not already connected.
        set net [get_bd_nets -quiet -of_object $sink_clk]
        if { [is_empty $net] } {
          # Connect directly
          dbg "connect_bd_net $clk_src $sink_clk"
          connect_bd_net $clk_src $sink_clk
        } else {
          # if this clock is connected to a source-less net, connect it to
          # given $clk_src
          set src_to_obj [find_bd_objs -quiet -legacy_mode -relation connected_to $sink_clk]
          if { [is_empty $src_to_obj] } {
            dbg "$sink_clk is connected to a source-less net - connect it to $clk_src"
            dbg "connect_bd_net $clk_src $obj"
            connect_bd_net $clk_src $sink_clk
          }
          # $obj is already connected, should this be an error or warning
          # right now just ignore.
        }
      }
    }             
  }
}

proc get_sink_clk_SC {sc clk_src} {
  set l_sc_clks [get_bd_pins -of [get_bd_cells $sc] -filter {TYPE == clk}]
  bd::utils::dbg "get_sink_clk_SC - sc = $sc | clk_src = $clk_src"

  set num_of_clks [llength $l_sc_clks]
  set sink_clk ""
  foreach sc_clk $l_sc_clks {
     set clk [ find_bd_objs -quiet -legacy_mode -relation connected_to $sc_clk]
     if { $clk == $clk_src } {
        return ""
     }
     if { [bd::utils::is_empty $sink_clk] && [bd::utils::is_empty $clk] } {
         set sink_clk $sc_clk
     }
  }
  if { [bd::utils::not_empty $sink_clk] } {
      return $sink_clk
  }
  set new_number [expr $num_of_clks + 1]
  set_property -dict [list CONFIG.NUM_CLKS $new_number] [get_bd_cells $sc]


  set sink_clk_name aclk$num_of_clks
  return [get_bd_pins $sc/$sink_clk_name]
}
##
# Connect up the associated rst of the given list of interfaces or
# sink-rst pins. Tries to match reset polarity and type before connecting 
# to rst source.
# If more than 1 rst_src is provided, the first reset source is usually 
# a single reset source like a reset pin on the ps7 e.g. If all pins_intf_l
# provided are all of the same polarity and type as the rst_src, it will
# be connected. However if polarity or type mismatches, and rst_src contains
# a second src -- which is usually a proc_sys_rst, use that as fall back.
# If the rst_src list contains a "New Processor System Reset" string, a new
# proc_sys_rst will be created first before using.
#
# Note! Will not make use of bus_struct_reset on PSR. To connect to the 
#       bus_struct_reset, connect directly.
#
# Note! If the rst_src_l_p varaible contains a string "New Processor System
#       Reset" and an new processor system reset is created, the variable
#       in the callee's scope will be changed. This allows the same rst_src_l_p
#       to be used in consecutive calls to connect_rst.
#
# e.g.
# set rst_src [list $peri_resetN $proc_reset "New Processor System Reset"]
# connect_rst [list $peri1 $peri2 $proc2 $someother] $rst_src      
# puts $rst_src
#  /peri_resetN /proc_reset /proc_sys_rst_1
# connect_rst [list $p1 $p2 $p3] $rst_src
#
# In this case only 1 new proc_sys_rest will get instanced
#
# @param pins_intf_l A list of pin, ports, intf_pins, intf_port objects
#                    whose rst need connecting
# @param rst_src_l_p The rst source to use. Rst source can be a 
#                    reset source pin, a proc_sys_reset cell, an interface
#                    if an interface is provided, that interface must contain
#                    an associated reset. If the associated rst is a src, use 
#                    it, otherwise trace it to its source and if the src is 
#                    proc_sys_rst, use that, otherwise use the src.
#                    rst_src can be a list. If the
#                    first rst src is not a proc_sys_rst, the second rst
#                    source should be.
# @param psr_hint    If the rst_Src_l_p contains string to instruct for a new
#                    psr to be create, the psr_hint param can optionally
#                    give hints on how to connect the clk and rst driving
#                    the psr. psr_hint should be a ps7,clkwiz, mig7 blk.
#                 
proc ::bd::clkrst::connect_rsts {pins_intf_l rst_src_l_p {clk_src {}}} {
  upvar $rst_src_l_p rst_src_l
  dbg "\[connect_rsts\] $pins_intf_l to rst_src_l_p $rst_src_l with clk_src as $clk_src"
  if {[is_empty $rst_src_l]} {
    return -code error -errorinfo "Expected a rst source to be provided."
  }

  set dst_rst ""
  foreach obj $pins_intf_l {
    dbg "connect_rsts: Connecting $obj"
    if { [is_sink $obj] } {
      # check that it is not already connected
      # dbg "connect_rsts: $obj rst is a sink pin/port."
      if {[bd::utils::is_driven $obj]} {
        dbg "connect_rsts: $obj rst is already driven."
        continue;
      }
      set dst_rst $obj
    } else {
      # obj is an interface
      set clk [Get_associated_clk $obj 2]
      if { [not_empty $clk] } {
        # We need to connect both synchronous and asynchronous sink-reset
        # if any, found to be associated with this interface
        set rst [get_sink_rst $clk 1]
        if { [not_empty $rst] } {
          set dst_rst $rst
          if {[bd::utils::is_driven $dst_rst]} {
            dbg "connect_rsts: $dst_rst rst is already driven."
            continue;
          }
        } else {
          dbg "connect_rsts: $obj rst is a src, nothing to do"
          continue;
        }
      } else {
        dbg "connect_rsts: can't find a rst for $obj, nothing to do."
        continue;
      }
    }
    
    dbg "connect_rsts: Trying to connect rst pin $dst_rst"
    
    # foreach rst src try to connect.
    set idx 0
   
    foreach rst_src $rst_src_l {
      dbg "connect_rsts: Using rst_src=$rst_src"
      incr idx
      set isPSR 0
      if { [is_ipi_obj $rst_src] } {
        set hasPSR [filter $rst_src "VLNV =~ $::bd::clkrst::PROC_SYS_RST_PATTERN"]
        if {[llength $hasPSR] > 0} {
          set isPSR 1
          set psr $rst_src
          dbg "connect_rsts: Proc sys reset found - $rst_src"
        } else {
          # rst_src is not a PSR, but check to see if it is an interface.
          set isIntf [filter $rst_src "CLASS == bd_intf_pin"]
          if { [not_empty $isIntf] } {
            set associated_clk [::bd::clkrst::Get_associated_clk $rst_src 2]
            set src_rst [bd::clkrst::get_src_rst $associated_clk]
            if {[not_empty $src_rst]} {
              dbg "connect_rsts: rst_src is a pin $rst_src"
              set rst_src $src_rst
            } else {
              # search to see if rst is connected to something
              set sink_rst [bd::clkrst::get_sink_rst $associated_clk]
              set other_end_of_rst [find_bd_objs -quiet -legacy_mode -relation connected_to $sink_rst]
              if {[not_empty $other_end_of_rst]} {
                # check to see if it is a PSR
                set parent [bd::utils::get_parent $other_end_of_rst]
                set hasPSR [filter $parent "VLNV =~ $::bd::clkrst::PROC_SYS_RST_PATTERN"]
                if {[llength $hasPSR] > 0} {
                  set isPSR 1
                  set psr $parent
                  dbg "connect_rsts: Proc sys reset found - $parent"
                } else {
                  # not a PSR, just return the source
                  dbg "connect_rsts: rst_src connects to a src rst: $other_end_of_rst"
                  set rst_src $other_end_of_rst
                }
              } else {
                # The provided intf does not have rst connected
                dbg "connect_rsts: provided intf $rst_src does not have rst connected"
                continue
              }
            }
          }
        }
      } else {
        dbg "connect_rsts: rst_src is not an IPI object"
        # is a string. Perhaps need to create 
        if {[string equal $rst_src $::bd::clkrst::NEW_PROC_SYS_RST]} {
          # create a new PSR and inject the new PSR into rst_src_l
          # while creating new PSR, provide clk_src as hint to wire psr's
          # slowest_sync_clk/ext_reset_in/dcm_locked etc.
          set psr [Create_proc_sys_rst $clk_src]
          set pos [expr $idx - 1]
          #set rst_src_l [lreplace $rst_src_l $pos $pos $psr]
          lset rst_src_l $pos $psr
          set isPSR 1
        } else {
          # unknown string ... just ignore
          dbg "connect_rsts: Unknown string provided as reset source: $rst_src"
          continue
        }
      }
      
   
      set success 0
      if {$isPSR} {
        dbg "connect_rsts: Trying to connect to psr $psr $dst_rst"
        # while making rst connections with the psr, provide clk_src
        # as hint to wire (if not already done) psr's slowest_sync_clk/
        # ext_reset_in/dcm_locked etc.
        set success [Connect_to_psr $psr $dst_rst $clk_src]
      } else {
        dbg "connect_rsts: Trying to connect to pin $rst_src $dst_rst"
        set success [Connect_to_rstpin $rst_src $dst_rst]
      }
      if {$success} {
        dbg "connect_rsts: Connection succeeded"
        break;
      }
    }
    # end of foreach rst_src
  } 
  # end of foreach obj
}

proc ::bd::clkrst::connect_rsts_default { rst_pins clk_src } {
  dbg "\[connect_rsts_default\]"
  dbg "connect_rsts_default : Reset pins $rst_pins w.r.t clk_src $clk_src"

  if {[is_empty $rst_pins]} {
    #dbg "connect_rsts_default: No rst_pin specified for connection"
    return ""
  }
  if {[is_empty $clk_src]} {
    #dbg "connect_rsts_default: No clk_src specifed for connection"
    return ""
  }

  set default_rst [bd::clkrst::get_default_rst $clk_src ""]
  dbg "connect_rsts_default: default rst is $default_rst"
  set rst_src_l [list]
  lappend rst_src_l $default_rst
  connect_rsts $rst_pins rst_src_l $clk_src

  set rst_src [lindex $rst_src_l 0]

  return $rst_src
}

## \private
# if rst_src and obj have the same TYPE and POLARITY
# connect them and return 1, otherwise return 0 
proc ::bd::clkrst::Connect_to_rstpin { rst_src obj {skip_polarity_and_type_check 0}  } {
  dbg "\[Connect_to_rstpin\]"
  # Check rst_src is a src
  if {![is_src $rst_src]} {
    dbg "connect_to_rstpin: rst_src $rst_src is not a Source"
    return 0
  }

  # Check that obj is a sink
  if {![is_sink $obj]} {
    dbg "connect_to_rstpin: obj $obj is not a SINK"
    return 0
  }

  # Check that $obj is not already connected
  if { [is_driven $obj] } {
    dbg "connect_to_rstpin: obj $obj is already being driven by a src"
    return 0
  }

  if {! $skip_polarity_and_type_check } {
    set rst_src_polarity [get_rst_polarity $rst_src]
    set obj_polarity [get_rst_polarity $obj]
    if {! [string equal -nocase $rst_src_polarity $obj_polarity]} {
      dbg "connect_to_rstpin: rst_src(${rst_src_polarity}) and obj (${obj_polarity}) polarity mismatch."
      return 0
    }
    set rst_src_type [get_rst_type $rst_src]
    if {[not_empty $rst_src_type]} {
      set obj_type [get_rst_type $obj]
      if {! [string equal -nocase $rst_src_type $obj_type] } {
        dbg "connect_to_rstpin: rst_src(${rst_src_type}) and obj (${obj_type}) type mismatch."
        return 0
      }
    } else {
      dbg "connect_to_rstpin: rst_src does not have TYPE specified. Will consider to connect it to any type of sink-reset pin."
    }
  }

  # CR 854278 : Temporary fix, till the root-cause is fixed in 'connect_bd_net'
  # If this reset-sink is connected to a source-less net, then connect
  # in the following way:
  # 1. Note all other connected sink-pins
  # 2. Delete the source-less net
  # 3. Connect rst_src to each sink-pins which were connected via this net earlier.
  set conn_net [get_bd_nets -of_objects $obj]
  if { [not_empty $conn_net] } {
    if { [is_driven $obj] } {
      dbg "connect_to_rstpin: reset-pin $obj is already connected to another source"
      return 0
    } else {
      set l_rst_sinks [get_bd_pins -of_objects $conn_net]
      dbg "connect_to_rstpin: multiple sink reset pins connected to source-less net $conn_net. These are $l_rst_sinks. These pins will be re-connected to source reset pin $rst_src."
      delete_bd_objs $conn_net
      foreach sink_rst $l_rst_sinks {
        connect_bd_net $rst_src $sink_rst
      }
    }
  } else {
    if { [catch {connect_bd_net $rst_src $obj} err]} {
      dbg "connect_to_rstpin: $err"
      return 0
    }
  }
  return 1
}

## \private
proc ::bd::clkrst::Connect_to_psr {psr obj psr_clk_hint} {
  dbg "\[Connect_to_psr\]"
  set obj_type [get_rst_type $obj]
  set obj_polarity [get_rst_polarity $obj]

  set pinName [get_rst_pin_from_proc_sys_rst $psr $obj_type $obj_polarity]
  if {[is_empty $pinName]} {
    dbg "connect_to_psr: Unable to find rst pin from psr: $psr type: $obj_type polarity: $polarity"
    return 0
  }
  dbg "connect_to_psr: Using pin on PSR: $pinName"
  set pin [get_bd_pins -quiet ${psr}/${pinName}]
  if {[is_empty $pin]} {
    dbg "connect_to_psr: Unable to get_bd_pins ${psr}/${pinName}"
    return 0
  }

  set success [Connect_to_rstpin $pin $obj 1]

  if {$success} {
    set psr_slowest_sync_clk [get_bd_pins -quiet ${psr}/Slowest_sync_clk]
    # Check that psr's slowest_sync_clk is not already connected
    if { ![is_driven $psr_slowest_sync_clk] } {
      #dbg "Connect_to_psr: $psr_slowest_sync_clk is not connected"
      if {[not_empty $psr_clk_hint]} {
        dbg "Connect_to_psr: will try to wire up inputs of $psr based on clk_hint $psr_clk_hint"
        set psr_ip_dict [dict create]
        ::bd::clkrst::find_psr_inputs_for_clk $psr_clk_hint psr_ip_dict
        ::bd::clkrst::wire_psr_inputs $psr $psr_ip_dict
      }
    }

  }

  return $success
}

proc ::bd::clkrst::find_rst_choices { clk_src ref_sink_clk } {
  dbg "\[find_rst_choices\]"

  set rst_srcs [list]
  if {[not_empty $clk_src]} {
    set rst [get_src_rst $clk_src]
    if {[not_empty $rst]} {
      # if clk_src has an associated src_rst already, then we
      # assume this rst_src is synchronized w.r.t.t clk_domain/freq/phase
      dbg "rst src $rst found w.r.t given clk_src $clk_src"
      lappend rst_srcs $rst
    }
  }

  # If ref exists it takes next precedence 
  if {[not_empty $ref_sink_clk]} {
    set ref_rst [get_sink_rst $ref_sink_clk]
    if { [not_empty $ref_rst] } {
      set ref_rst_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $ref_rst]
      if { [not_empty $ref_rst_src] } {
        # check if clk_src's clk-domain/freq/phase are compatible w.r.t this ref_rst_src
        dbg "ref_rst_src $ref_rst_src found w.r.t given ref_sink_clk $ref_sink_clk"
        set rst_valid [::bd::clkrst::can_sync_rst_with_clk $ref_rst_src $clk_src]
        if {$rst_valid} {
          lappend rst_srcs $ref_rst_src
        }
      }
    }
  }

  if {[is_empty $rst_srcs]} {
    dbg "No rst src found yet, looking for defaults"
  }

  # We need to add a default proc_sys_rst to the rst_src list. Becasue we don't know
  # if the rst_src (if any found till now) is capable of resetting all the provided resets.
  set default_rst [get_default_rst $clk_src ""]
  lappend rst_srcs $default_rst

  return $rst_srcs
}

##
# Traverses through the entire BD-design looking for
# source clks and determines a default choice (may be
# existing src clk-pin or may be request for new clocking
# Wizard block) and finally returns the default clksrc pin
# (if new clocking wizard is determined as default choice,
# creates new clkwiz blk as well)
##
proc ::bd::clkrst::get_default_clksrc {} {
  dbg "\[get_default_clksrc\]"

  # First get all possible clk-choices in current bd-design and
  # determine a default choice
  set def_choice ""
  set choices [::bd::clkrst::get_clk_choices "" def_choice]
  dbg "choices: $choices"
  dbg "default: $def_choice"

  # Now depending on the def_choice, either pick up existing clk_src or
  # create a new clocking wizard or an external clock-port
  set clk_src [bd::clkrst::get_clk_src_from_choices $def_choice]

  return $clk_src
}

##
# Checks if all clock-pins on the intc_intf's parent AXI Interconnect
# are driven by same clk_src and if yes, then returns that clksrc as
# valid driving_clk to the Interconnect.
# @param intc_intf intc_intf on the AXIMM interconnect.
##
proc ::bd::clkrst::find_intc_driving_clk { intc_intf } {
  dbg "\[find_intc_driving_clk\]"
  set intc_clk_src ""

  set intercon [filter [bd::utils::get_parent $intc_intf] {VLNV =~ xilinx.com:ip:axi_interconnect*}]
  if {[not_empty $intercon]} {
    dbg "Checking out interconnect $intercon"
    set allclks [get_bd_pins -of_objects $intercon -quiet -filter {TYPE==clk}]
    set driving_clk ""
    set driving_clk_valid 1

    foreach c $allclks {
      set tmp_driving_clk [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $c]
      if {[is_empty $driving_clk]} {
        if {[not_empty $tmp_driving_clk]} {
          dbg "-- found driving_clk $tmp_driving_clk"
          set driving_clk $tmp_driving_clk
        }
      } else {
        if {[not_empty $tmp_driving_clk] && $driving_clk != $tmp_driving_clk } {
          dbg "-- invalidating driving clk because found another driver clk $tmp_driving_clk"
          set driving_clk_valid 0
          break
        }
      }
    }

    if {$driving_clk_valid && [not_empty $driving_clk]} {
      dbg "Found that all driven interconnect clks are driven by same source: $driving_clk"
      set intc_clk_src $driving_clk
    }
  }

  return $intc_clk_src
}

##
# Determine a suitable clksrc for AXI connection automation. intf was just
# connected to intc_intf on the interconnect.We need to wire up the clock
# and rst pins assocaited with both intf and intf_intf.
# For Slave to Master automation, it may get called:
#   1. After connecting root master interface with a newly created AXI Interconnect's
#      slave interface. There intf => root master-intf; intf_intf => slave-intf on newly
#      created interconnect; ref_intf => src slave intf, w.r.t which automation was
#      initiated. Use this ref_intf to determine clksrc, if we can.
#   2. After connecting src Slave interface with root Master interface via an AXI
#      Interconnect. There intf => src slave intf from where automation was initiated;
#      intc_intf => master-intf on AXI interconnect via which src slave-intf was connected
#      to root master-interface; ref_intf => reference slave-intf, if found while connecting
#      the interfaces (which "smells" like src slave-intf and is connected via the same
#      interconnect)
# For Master to Slave automation, it may get called:
#   1. After connecting master-intf (from which automation was initiated) with slave-intf on
#      on the Interconnect (via which destination slave-intf is connected).
#      There intf => src master-intf from where automation initiated; intc_intf => slave-intf on
#      interconnect, via which src master-intf has been connected to the destination slave-intf;
#      ref_intf => NULL; no ref_intf is provided today for this case.
#
# Precedence of detrmining clksrc:
# <TODO> fill up later
#
# @param intf interface that was just connected (note that addr
#             assignment might not have occured for this connection).
# @param intc_intf The previous intf is connected to this intc_intf
#                  on the AXI interconnect. 
# @param ref_intf  If a reference interface was used, it would be provided 
#                  here. otherwise {}
# @param ref_clk If clksrc is picked up from reference intf, then return
#                the associated clkpin for this ref_intf. This information is to be
#                used later to determine the reset src.
##
proc ::bd::clkrst::find_clksrc { intf intc_intf ref_intf ref_sink_clk clk_hint} {
  dbg "\[find_clksrc\]"

  upvar $ref_sink_clk ref_clk
  set ref_clk ""

  # Step 1: (Always give priority to $intf)
  # Attempt to trace a clk-source for $intf
  # 1. If it has any associated src-clk (i.e. dir Output)
  # 2. If no associated src-clock found, try to find an associated
  #    sink-clk (i.e. dir Input), which is already being driven by some clock-source
  set clk_src [get_src_clk $intf]
  if {[not_empty $clk_src]} {
    if { [not_empty $clk_hint] && [expr {$clk_src ne $clk_hint} ] } {
      set src_cell [get_bd_cells -quiet -of_object $intf]
      ::bd::send_msg -of $src_cell \
            -type INFO \
            -msg_id 1 \
            -text "<$intf> already has associated source clock <$clk_src>. Specified clock <$clk_hint> will not be used to connect associated sink clock pins of <$intf> and <$intc_intf> (if not connected already); <$clk_src> will be used instead."
    }
    return $clk_src
  }

  set sink_clk [get_sink_clk $intf]
  if {[not_empty $sink_clk]} {
    #dbg "Found sink_clk $sink_clk for intf $intf"
    set clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $sink_clk]
    if {[not_empty $clk_src]} {
      dbg "Found src clk: $clk_src"
      if { [not_empty $clk_hint] && [expr {$clk_src ne $clk_hint} ] } {
        set src_cell [get_bd_cells -quiet -of_object $intf]
        ::bd::send_msg -of $src_cell \
            -type INFO \
            -msg_id 1 \
            -text "<$intf> already has associated sink clock <$sink_clk> driven by clock source <$clk_src>. Specified clock <$clk_hint> will not be used to connect associated sink clock pin of <$intc_intf> (if not connected already); <$clk_src> will be used instead."
      }
      return $clk_src
    }
  }

  # Step 2:
  # If a clk_hint is specified by user via GUI, then use that
  if {[not_empty $clk_hint]} {
    set clk_src $clk_hint
    if {[not_empty $ref_intf]} {
      set ref_clk [get_sink_clk $ref_intf]
    }
    return $clk_src
  }

  # Step 3:
  # If no clk_src could be found from $intf, check to see if a ref_intf was
  # provided and we can extract clk and rst info from it
  if {[not_empty $ref_intf]} {
    dbg "reference slave intf provided: $ref_intf"

    # First try to find out the associated sink-clk for ref_intf
    set ref_clk [get_sink_clk $ref_intf]
    if { [not_empty $ref_clk] } {
      # Trace ref_clk to see if I can find the clk_src
      set clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $ref_clk]
      if { [not_empty $clk_src] } {
        dbg "Found sink clk for the ref_intf: $clk_src"
        return $clk_src
      }
    }

    # CR 727537: MIG generates its own clock ui_clk which has its S_AXI as 
    # associated busif. For such case, pick up this ui_clk as the clksrc
    if { ( [get_property MODE $ref_intf] == "Slave") } {
      set clk_src [get_src_clk $ref_intf]
      if { [not_empty $clk_src] } {
        dbg "Found src clk for the ref_intf: $clk_src"
        return $clk_src
      }
    }
  }

  # Step 4:
  # If no clk_src could be found from intf or ref_intf(if any provided), look at
  # the Master intf on the interconnect and trace back to the peripheral's slave intf,
  # and see if that clock has been connected.
  dbg "No clk src found yet, Looking at master intf $intc_intf"
  if {[get_property MODE $intc_intf] == "Master"} {
    #dbg "Checking master intf $intc_intf"
    set master_clk [get_sink_clk $intc_intf]
    if {[not_empty $master_clk]} {
      #dbg "Found master_clk $master_clk"
      set clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $master_clk]
      if {[not_empty $clk_src]} {
        dbg "Found src clk: $clk_src"
        return $clk_src
      }
    }
  }

  # Step 5:
  # If Master intf is not clocked, look at interconnect and see if aclk
  # is connected and if all connected clocks on interconnect are the same.
  dbg "No clk src found yet, looking at clks on interconnect"
  set clk_src [::bd::clkrst::find_intc_driving_clk $intc_intf]
  if {[not_empty $clk_src]} {
    return $clk_src
  }

  # Step 6:
  # If clk_src is still empty try to look for a default clk source
  dbg "No clk src found yet, looking for defaults"
  set clk_src [::bd::clkrst::get_default_clksrc]

  return $clk_src
}

# For existing clk-pin, in $clk_choices, available choices will be
# of the form "/a/b/c (### MHz)". $clk_src will be of form "/a/b/c".
# Need to translate $clk_src, to available choice, as present in $clk_choices
proc ::bd::clkrst::translate_clk_src { clk_choices clk_src } {
  foreach choice $clk_choices {
    if { [regexp ^${clk_src} $choice] } {
      return $choice
    }
  }
}

proc ::bd::clkrst::find_clk_choices_for_intf { src_intf intc_intf ref_intf clk_default} {
  dbg "\[find_clk_choices_for_intf\]"

  upvar $clk_default def_clk_src

  # First find the list of available clk-srcs and a probabale default-clk.
  # This default-clk may not be the best default choice w.r.t ref_intf and
  # intc_intf provided. Best default need to be determined after this step.
  set default_choice ""
  set clk_choices [bd::clkrst::get_clk_choices "" default_choice 0 1]

  if { $::bd::utils::auto_connect_clkrst eq 1 } {
    set def_clk_src $::bd::clkrst::AUTO_CONNECT_CLKRST
    return $clk_choices
  }

  # Now try to find the best default clk_choice
  set def_clk_src ""
  set clk_src ""

  # Step 1:
  # if src_intf is provided, check if it has an
  #   i) associated sink-clk, that is driven by a clk-src or
  #  ii) associated src-clk
  if {[not_empty $src_intf]} {
    dbg "src intf provided: $src_intf"

    set sink_clk [get_sink_clk $src_intf]
    if {[not_empty $sink_clk]} {
      # Trace sink_clk to see if I can find the clk_src
      set clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $sink_clk]
      dbg "Found sink clk for the src_intf: $clk_src"
    }

    if {[is_empty $clk_src]} {
      set clk_src [get_src_clk $src_intf]
      dbg "Found src clk for the src_intf: $clk_src"
    }

    if {[not_empty $clk_src]} {
      set def_clk_src [bd::clkrst::translate_clk_src $clk_choices $clk_src]
      return $clk_choices
    }
  }

  # Step 2:
  # If no clk_src could be found from $intf, check to see if a ref_intf was
  # provided and we can extract clk and rst info from it
  if {[not_empty $ref_intf]} {
    dbg "reference slave intf provided: $ref_intf"

    # First try to find out the associated sink-clk for ref_intf
    set ref_clk [get_sink_clk $ref_intf]
    if {[not_empty $ref_clk]} {
      # Trace ref_clk to see if I can find the clk_src
      set ref_clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $ref_clk]
      if {[not_empty $ref_clk_src]} {
        dbg "Found sink clk for the ref_intf: $ref_clk_src"
        set clk_src $ref_clk_src
        set def_clk_src [bd::clkrst::translate_clk_src $clk_choices $clk_src]
        return $clk_choices
      }
    }

    # CR 727537: MIG generates its own clock ui_clk which has its S_AXI as 
    # associated busif. For such case, pick up this ui_clk as the clksrc
    if { [is_empty $clk_src] && ( [get_property MODE $ref_intf] == "Slave") } {
      set ref_clk_src [get_src_clk $ref_intf]
      if {[not_empty $ref_clk_src]} {
        dbg "Found src clk for the ref_intf: $ref_clk_src"
        set clk_src $ref_clk_src
        set def_clk_src [bd::clkrst::translate_clk_src $clk_choices $clk_src]
        return $clk_choices
      }
    }

  }

  # Step 3:
  # No suitable default clk-src could be found from  src_intf and ref_intf(if any).
  # check if a suitable default could be found from the interconnect interface
  if {[not_empty $intc_intf]} {
    # Look at interconnect and see if aclk is connected and if all connected clocks
    # on interconnect are the same.
    dbg "No default clk src found yet, looking at clks on interconnect"
    set clk_src [::bd::clkrst::find_intc_driving_clk $intc_intf]
    if {[not_empty $clk_src]} {
      set def_clk_src [bd::clkrst::translate_clk_src $clk_choices $clk_src]
      return $clk_choices
    }
  }

  # Step 4:
  # If no default could be found at this point pick up the default provided by get_clk_choices method
  set def_clk_src $default_choice
  return $clk_choices

}

##
# Special functions to connect aximm
# intf was just connected to intc_intf on the interconnect. So we need to
# wire up the clock and rst assocaited with both intf and intf_intf. However
# a ref_intf could have been used, and if it was, we need to use it as a 
# reference on how to wire ip intf and intc_intf. 
# @param intf The  AXI MM that was just connected (note that addr
#             assignment might not have occured for this connection).
# @param intc_intf The previous intf is connected to this intc_intf which
#                  is an interface on the AXIMM interconnect. 
# @param ref_intf  If a reference interface was used, it would be provided 
#                  here. otherwise {}
proc ::bd::clkrst::connect_aximm_clk_rst {intf intc_intf ref_intf clk_hint} {
  dbg "\[Connecting aximm clk and rsts\]"

  # First determine the clksrc
  set clk_src ""
  set ref_sink_clk ""
  set clk_src [::bd::clkrst::find_clksrc $intf $intc_intf $ref_intf ref_sink_clk $clk_hint]

  dbg "Using clk_src $clk_src *****"

  # Do clock connections
  connect_clks [list $intf $intc_intf] $clk_src

  # -------------------------------------------------
  # Check to see if intf has src rst
  dbg "Looking for rst connections"
  set rst_choices [::bd::clkrst::find_rst_choices $clk_src $ref_sink_clk]
  
  # Do rst connections
  dbg "Making rst connection with rst_src: $rst_choices"
  connect_rsts [list $intf $intc_intf] rst_choices $clk_src

}

# ---------------------------------------------------------------------------

proc ::bd::clkrst::find_stream_clksrc { intf clk_hint ref_intf } {
  dbg "\[find_stream_clksrc\]"

  # Step 1: (Always give priority to $intf)
  # Attempt to trace a clk-source for $intf
  # 1. If it has any associated src-clk (i.e. dir Output)
  # 2. If no associated src-clock found, try to find an associated
  #    sink-clk (i.e. dir Input), which is already being driven by some clock-source
  set clk_src [get_src_clk $intf]
  if {[not_empty $clk_src]} {
    if { [not_empty $clk_hint] && [expr {$clk_src ne $clk_hint} ] } {
      set src_cell [get_bd_cells -quiet -of_object $intf]
      ::bd::send_msg -of $src_cell \
          -type INFO \
          -msg_id 1 \
          -text "<$intf> already has associated source clock <$clk_src>. Specified clock <$clk_hint> will not be used to connect associated sink clock pins of <$intf> and <$intc_intf> (if not connected already); <$clk_src> will be used instead."
    }
    return $clk_src
  }

  set sink_clk [get_sink_clk $intf]
  if {[not_empty $sink_clk]} {
    #dbg "Found sink_clk $sink_clk for intf $intf"
    set clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $sink_clk]
    if {[not_empty $clk_src]} {
      dbg "Found src clk: $clk_src"
      if { [not_empty $clk_hint] && [expr {$clk_src ne $clk_hint} ] } {
        set src_cell [get_bd_cells -quiet -of_object $intf]
        ::bd::send_msg -of $src_cell \
            -type INFO \
            -msg_id 1 \
            -text "<$intf> already has associated sink clock <$sink_clk> driven by clock source <$clk_src>. Specified clock <$clk_hint> will not be used to connect associated sink clock pin of <$intc_intf> (if not connected already); <$clk_src> will be used instead."
      }
      return $clk_src
    }
  }

  # Step 2:
  # If a clk_hint is specified by user via GUI, then use that
  if {[not_empty $clk_hint]} {
    set clk_src $clk_hint
    return $clk_src
  }

  # Step 3:
  # If no clk_src could be found from $intf, check to see if a ref_intf was
  # provided and we can extract clk and rst info from it
  if {[not_empty $ref_intf]} {
    dbg "reference intf provided: $ref_intf"

    # First try to find out the associated sink-clk for ref_intf
    set ref_clk [get_sink_clk $ref_intf]
    if { [not_empty $ref_clk] } {
      # Trace ref_clk to see if I can find the clk_src
      set clk_src [find_bd_objs -quiet -legacy_mode -relation CONNECTED_TO $ref_clk]
      if { [not_empty $clk_src] } {
        dbg "Found sink clk for the ref_intf: $clk_src"
        return $clk_src
      }
    }

    # CR 727537: MIG generates its own clock ui_clk which has its S_AXI as 
    # associated busif. For such case, pick up this ui_clk as the clksrc
    if { ( [get_property MODE $ref_intf] == "Slave") } {
      set clk_src [get_src_clk $ref_intf]
      if { [not_empty $clk_src] } {
        dbg "Found src clk for the ref_intf: $clk_src"
        return $clk_src
      }
    }
  }

  # Step 4:
  # If clk_src is still empty try to look for a default clk source
  dbg "No clk src found yet, looking for defaults"
  set clk_src [::bd::clkrst::get_default_clksrc]

  return $clk_src
}

proc ::bd::clkrst::connect_axis_clk_rst { intf clk_hint ref_intf str_intf_l } {
  dbg "\[Connecting axis clk and rsts\]"

  # First determine the clksrc
  set clk_src ""
  set clk_src [::bd::clkrst::find_stream_clksrc $intf $clk_hint $ref_intf]

  dbg "Using clk_src $clk_src *****"

  # Do clock connections
  connect_clks $str_intf_l $clk_src

  # -------------------------------------------------
  # Check to see if intf has src rst
  dbg "Looking for rst connections"
  set rst_choices [::bd::clkrst::find_rst_choices $clk_src ""]
  
  # Do rst connections
  dbg "Making rst connection with rst_src: $rst_choices"
  connect_rsts $str_intf_l rst_choices $clk_src

}

proc ::bd::clkrst::connect_sg_clk_rst { intf ref_intf { clk_hint {} } } {
  dbg "\[Connecting sysgen clk and rsts\]"

  # First determine the clksrc
  set clk_src ""
  set clk_src [::bd::clkrst::find_stream_clksrc $intf $clk_hint $ref_intf]

  dbg "Using clk_src $clk_src *****"

  # Do clock connections
  connect_clks [list $intf] $clk_src

  # -------------------------------------------------
  # Check to see if intf has src rst
  dbg "Looking for rst connections"
  set rst_choices [::bd::clkrst::find_rst_choices $clk_src ""]
  
  # Do rst connections
  dbg "Making rst connection with rst_src: $rst_choices"
  connect_rsts [list $intf] rst_choices $clk_src

}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
