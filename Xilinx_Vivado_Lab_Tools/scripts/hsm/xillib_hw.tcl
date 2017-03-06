##############################################################################
# Copyright 2013 Xilinx Inc. All rights reserved
##############################################################################
namespace eval ::hsi::utils {
}

#
# It will retrun the connected interface to and IP interface
#

proc ::hsi::utils::get_connected_intf { periph_name intf_name} {
    set ret ""
    set periph [::hsi::get_cells -hier "$periph_name"]
    if { [llength $periph] == 0} {
        return $ret
    }
    set intf_pin [::hsi::get_intf_pins -of_objects $periph  "$intf_name"]
    if { [llength $intf_pin] == 0} {
        return $ret
    }
    set intf_net [::hsi::get_intf_nets -of_objects $intf_pin]
    if { [llength $intf_net] == 0} {
        return $ret
    }
    set connected_intf [::hsi::get_intf_pins -of_objects $intf_net -filter "TYPE!=[common::get_property TYPE $intf_pin]"]
    return $connected_intf
}
# 
# it will return the net name connected to ip pin
#
proc ::hsi::utils::get_net_name {ip_inst ip_pin} {
    set ret ""
	if { [llength $ip_pin] != 0 } {
    set port [::hsi::get_pins -of_objects $ip_inst -filter "NAME==$ip_pin"]
    if { [llength $port] != 0 } {
        set pin [::hsi::get_nets -of_objects $port ] 
        set ret [common::get_property NAME $pin]
    }
	}
   return $ret
}

#
# It will return the interface net name connected to IP interface.
#
proc ::hsi::utils::get_intfnet_name {ip_inst ip_busif} {
    set ret ""
	if { [llength $ip_busif] != 0 } {
    set bus_if [::hsi::get_intf_pins -of_objects $ip_inst -filter "NAME==$ip_busif"]
    if { [llength $bus_if] != 0 } {
       set intf_net [::hsi::get_intf_nets -of_objects $bus_if]
       set ret [common::get_property NAME $intf_net]
    }
	}
    return $ret
}


# 
# It will return all the peripheral objects which are connected to processor
#
proc ::hsi::utils::get_proc_slave_periphs {proc_handle} {
   set periphlist [common::get_property slaves $proc_handle]
   if { $periphlist != "" } {
       foreach periph $periphlist {
   	    set periph1 [string trim $periph]
   	    set handle [::hsi::get_cells -hier $periph1]
   	    lappend retlist $handle
       }
   	return $retlist
   } else {
       return ""
   }
}
#
# It will return the clock frequency value of IP clock port.
# it will first check the requested pin should be be clock type.
#
proc ::hsi::utils::get_clk_pin_freq { cell_obj clk_port} {
    set clk_port_obj [::hsi::get_pins $clk_port -of_objects $cell_obj]
    if {$clk_port_obj ne "" } {
        set port_type [common::get_property TYPE $clk_port_obj]
        if { [string compare -nocase $port_type  "CLK"] == 0 } {
            return [common::get_property CLK_FREQ $clk_port_obj]
        } else {
            error "ERROR:Trying to access frequency value from non-clock port \"$clk_port\" of IP \"$cell_obj\""
        }
    } else {
        error "ERROR:\"$clk_port\" port does not exist in IP \"$cell_obj\""
    }
    return ""
}

# 
# It will check the pin object is external or not. If pin_object is 
# associated to a cell then it is internal otherise it is external
#
proc ::hsi::utils::is_external_pin { pin_obj } {
    set pin_class [common::get_property CLASS $pin_obj]
    if { [string compare -nocase "$pin_class" port] == 0 } {
        set ip [::hsi::get_cells -of_objects $pin_obj]
        if {[llength $ip]} {
            return 0
        } else {
            return 1
        }
    } else {
        error "ERROR:is_external_pin Tcl proc expects port class type object $pin_obj. Whereas $pin_class type object is passed."
    }
}
#
# Get the width of port object. It will return width equal to 1 when
# port does not have width property
#
proc ::hsi::utils::get_port_width { port_handle} {
    set left [common::get_property LEFT $port_handle]
    set right [common::get_property RIGHT $port_handle]
    if {[llength $left] == 0 && [llength $right] == 0} {
        return 1  
    }

    if {$left > $right} {
      set width [expr $left - $right + 1]
    } else {
      set width [expr $right - $left + 1]
    }
    return $width
}

#
# Get handles for all ports driving the interrupt pin of a peripheral
#
proc ::hsi::utils::get_interrupt_sources {periph_handle } {
   lappend interrupt_sources
   lappend interrupt_pins
   set interrupt_pins [::hsi::get_pins -of_objects $periph_handle -filter {TYPE==INTERRUPT && DIRECTION==I}]
   foreach interrupt_pin $interrupt_pins {
       set source_pins [::hsi::utils::get_intr_src_pins $interrupt_pin]
       foreach source_pin $source_pins {
           lappend interrupt_sources $source_pin 
       }
   }
   return $interrupt_sources
}
#
# Get the interrupt source pins of a periph pin object
#
proc ::hsi::utils::get_intr_src_pins {interrupt_pin} {
    lappend interrupt_sources
    set source_pins [::hsi::utils::get_source_pins $interrupt_pin]
    foreach source_pin $source_pins {
        set source_cell [::hsi::get_cells -of_objects $source_pin]
        if { [llength $source_cell ] } {
            #For concat IP, we need to bring pin source for other end
            set ip_name [common::get_property IP_NAME $source_cell]
            if { [string match -nocase $ip_name "xlconcat" ] } {
                set pins [::hsi::__internal::get_concat_interrupt_sources $source_cell]
                foreach pin $pins {
                    lappend interrupt_sources $pin
                }
            } else {
                lappend interrupt_sources $source_pin 
            }
        } else {
            lappend interrupt_sources $source_pin 
        }
    }
    return $interrupt_sources
}
#
# Get the source pins of a periph pin object
#
proc ::hsi::utils::get_source_pins {periph_pin} {
   set net [::hsi::get_nets -of_objects $periph_pin]
   set cell [::hsi::get_cells -of_objects $periph_pin]
   if { [llength $net] == 0} {
       return [lappend return_value] 
   } else {
		set signals [split [common::get_property NAME $net] "&"]
	    lappend source_pins
	    if { [llength $signals] == 1 } {
	      foreach signal $signals {
			set signal [string trim $signal]
			set sig_net [::hsi::get_nets -of_objects $cell $signal]
			if { [llength $sig_net] == 0 } {
				continue
			}
			set source_pin [::hsi::get_pins -of_objects $sig_net -filter { DIRECTION==O}]
			if { [ llength $source_pin] != 0 } {
            	set source_pins [linsert $source_pins 0 $source_pin ]
           	}
           	set source_port [::hsi::get_ports -of_objects $sig_net -filter {DIRECTION==I}]
           	if { [llength $source_port] != 0 } {
            	set source_pins [linsert $source_pins 0 $source_port]
           	}
       	  }
	    	if { [ llength $source_pins] == 0 } {
        	  set all_pins [::hsi::get_pins -of_objects $net]
           	  foreach pin $all_pins {
           		set lower_net [get_nets -boundary_type lower -of_objects $pin]
           		set upper_net [get_nets -boundary_type upper -of_objects $pin]
	           	if { [ llength $lower_net] != 0  && [ llength $upper_net] != 0 } {
    	       		set source_port [::hsi::get_ports -of_objects $upper_net -filter {DIRECTION==I}]
        	   		if { [llength $source_port] != 0 } {
            	   		set source_pins [linsert $source_pins 0 $source_port]
           			}
           		}
			  }
			}
	    } else {
			foreach signal $signals {
				set signal [string trim $signal]
				set sig_nets [::hsi::get_nets $signal]
				set got_net [get_net_of_perifh_pin $periph_pin $sig_nets]
				set source_pin [::hsi::get_pins -of_objects $got_net -filter { DIRECTION==O}]
				if { [ llength $source_pin] != 0 } {
					set source_pins [linsert $source_pins 0 $source_pin ]
				}
				set source_port [::hsi::get_ports -of_objects $got_net -filter {DIRECTION==I}]
				if { [llength $source_port] != 0 } {
					set source_pins [linsert $source_pins 0 $source_port]
				}
			}
       	}
       	return $source_pins
	}
}


#
# Find net of a peripheral pin object
#
proc ::hsi::utils::get_net_of_perifh_pin {periph_pin sig_nets} {
    
    if { [ llength $sig_nets ] == 1 } {
        set got_net [lindex $sig_nets 0]
        return $got_net
    }

    set found 0
    set got_net ""
    set cell [::hsi::get_cells -of_objects $periph_pin]
    foreach sig_net $sig_nets {
		if {$sig_net != ""} {
			set both_cells [::hsi::get_cells -of_objects $sig_net]
			foreach single_cell $both_cells {
				if {$single_cell == $cell } {
					set got_net $sig_net
					set found 1
					break;
				}
			}
			if {$found} {
			break;
			}
		}
    }
    return $got_net
}


#
# Get the sink pins of a peripheral pin object
#
proc ::hsi::utils::get_sink_pins {periph_pin} {
   set net [::hsi::get_nets -of_objects $periph_pin]
   set cell [::hsi::get_cells -of_objects $periph_pin]
   if { [llength $net] == 0} {
       return [lappend return_value] 
   } else {
       set signals [split [common::get_property NAME $net] "&"]
       lappend source_pins
       if { [llength $signals] == 1 } {
       foreach signal $signals {
           set signal [string trim $signal]
           if { $cell == "" } {
               set sig_net [::hsi::get_nets $signal]
           } else {
               set sig_net [::hsi::get_nets -of_objects $cell $signal]
           }
           set pins [::hsi::get_pins -of_objects $sig_net -filter { DIRECTION==I}]
           if { [ llength $pins] != 0 } {
               foreach source_pin $pins { 
                   set source_pins [linsert $source_pins 0 $source_pin ]
               }
           }
           set source_ports [::hsi::get_ports -of_objects $sig_net -filter {DIRECTION==O}]
           if { [llength $source_ports] != 0 } {
               foreach source_port $source_ports { 
                   set source_pins [linsert $source_pins 0 $source_port]
               }
           }
       }
       } else {
		foreach signal $signals {
			set signal [string trim $signal]
			set sig_nets [::hsi::get_nets $signal]
			set got_net [get_net_of_perifh_pin $periph_pin $sig_nets]
			set pins [::hsi::get_pins -of_objects $got_net -filter { DIRECTION==I}]
			if { [ llength $pins] != 0 } {
				foreach source_pin $pins { 
					set source_pins [linsert $source_pins 0 $source_pin ]
				}
			}
			set source_ports [::hsi::get_ports -of_objects $got_net -filter {DIRECTION==O}]
			if { [llength $source_ports] != 0 } {
				foreach source_port $source_ports { 
                   set source_pins [linsert $source_pins 0 $source_port]
				}
			}
		}
	   }
       return $source_pins
   }
}

#
# get the pin count which are connected to peripheral pin
#
proc ::hsi::utils::get_connected_pin_count { periph_pin } {
    set total_width 0
    set cell [::hsi::get_cells -of_objects $periph_pin]
    set connected_nets [::hsi::get_nets -of_objects $periph_pin]
    set signals [split $connected_nets "&"]
    if { [llength $signals] == 1 } {
     foreach signal $signals {
        set width 0
		set signal [string trim $signal]
      set sig_nets [::hsi::get_nets -of_object $cell $signal]
      if { [llength $sig_nets] == 0 } {
            continue
        }
      set signal [string trim $signal]
      set got_net [get_net_of_perifh_pin $periph_pin $sig_nets]
      set source_port [::hsi::get_ports -of_objects $got_net]
		if {[llength $source_port] != 0 } {
            set width [::hsi::utils::get_port_width $source_port]
		} else {
			set source_pin [::hsi::get_pins -of_objects $got_net -filter {DIRECTION==O}]
            if { [llength $source_pin] ==0 } {
                continue
            }
            set width [::hsi::utils::get_port_width $source_pin]
        }
        set total_width [expr {$total_width + $width}]
	 }
    } else {
	 foreach signal $signals {
        set width 0
		set signal [string trim $signal]
      set sig_nets [::hsi::get_nets $signal]
      if { [llength $sig_nets] == 0 } {
            continue
        }
      set signal [string trim $signal]
      set got_net [get_net_of_perifh_pin $periph_pin $sig_nets]
      set source_port [::hsi::get_ports -of_objects $got_net]
		if {[llength $source_port] != 0 } {
            set width [::hsi::utils::get_port_width $source_port]
		} else {
			set source_pin [::hsi::get_pins -of_objects $got_net -filter {DIRECTION==O}]
            if { [llength $source_pin] ==0 } {
                continue
            }
            set width [::hsi::utils::get_port_width $source_pin]
        }
        set total_width [expr {$total_width + $width}]
	 }
	}
    return $total_width
}

#
# get the parameter value. It has special handling for DEVICE_ID parameter name
#
proc ::hsi::utils::get_param_value {periph_handle param_name} {
        if {[string compare -nocase "DEVICE_ID" $param_name] == 0} {
            # return the name pattern used in printing the device_id for the device_id parameter
            return [::hsi::utils::get_ip_param_name $periph_handle $param_name]
        } else {
            set value [common::get_property CONFIG.$param_name $periph_handle]
            set value [string map {_ ""} $value]
            return $value
    }
}

# 
# Returns name of the p2p peripheral if arg is present
# 
proc ::hsi::utils::get_p2p_name {periph arg} {
   
   set p2p_name ""
   
   # Get all point2point buses for periph 
   set p2p_busifs_i [::hsi::get_intf_pins -of_objects $periph -filter "TYPE==INITIATOR"]
   
   # Add p2p periphs 
   foreach p2p_busif $p2p_busifs_i {
       set intf_net [::hsi::get_intf_nets -of_objects $p2p_busif]
       if { $intf_net ne "" } {
           set conn_busif_handle [::hsi::get_intf_pins -of_objects $intf_net -filter "TYPE==TARGET"]
           if { [string compare -nocase $conn_busif_handle ""] != 0} { 
               set p2p_periph [::hsi::get_cells -of_objects $conn_busif_handle]
               if { $p2p_periph ne "" } {
                   set value [common::get_property $arg $p2p_periph]
                   if { [string compare -nocase $value ""] != 0} { 
                       return [::hsi::utils::get_ip_param_name $p2p_periph $arg]
                   }
               }
           }
       }
    }
   
   return $p2p_name
}

#
# it returns all the processor instance object in design
#
proc ::hsi::utils::get_procs { } {
   return [::hsi::get_cells  -hier -filter { IP_TYPE==PROCESSOR}]
}

#
# Get the interrupt ID of a peripheral interrupt port
#
proc ::hsi::utils::get_port_intr_id { periph_name intr_port_name } {
    return [::hsi::utils::get_interrupt_id $periph_name $intr_port_name]
}
#
# It will check the is peripheral is interrupt controller or not
#
proc ::hsi::utils::is_intr_cntrl { periph_name } {
    set ret 0
	if { [llength $periph_name] != 0 } {
    set periph [::hsi::get_cells -hier -filter "NAME==$periph_name"]
    if { [llength $periph] == 1 } {
        set special [common::get_property CONFIG.EDK_SPECIAL $periph]
        set ip_type [common::get_property IP_TYPE $periph]
        if {[string compare -nocase $special "interrupt_controller"] == 0  || 
            [string compare -nocase $special "INTR_CTRL"] == 0 || 
            [string compare -nocase $ip_type "INTERRUPT_CNTLR"] == 0 } {
                set ret 1
        }
    }
	}
    return $ret
}

#
# It needs IP name and interrupt port name and it will return the connected 
# interrupt controller
# for External interrupt port, IP name should be empty
#
proc ::hsi::utils::get_connected_intr_cntrl { periph_name intr_pin_name } {
    lappend intr_cntrl
    if { [llength $intr_pin_name] == 0 } {
        return $intr_cntrl
    }

    if { [llength $periph_name] != 0 } {
        #This is the case where IP pin is interrupting
        set periph [::hsi::get_cells -hier -filter "NAME==$periph_name"]
        if { [llength $periph] == 0 } {
            return $intr_cntrl
        }
        set intr_pin [::hsi::get_pins -of_objects $periph -filter "NAME==$intr_pin_name"]
        if { [llength $intr_pin] == 0 } {
            return $intr_cntrl
        }
        set pin_dir [common::get_property DIRECTION $intr_pin]
        if { [string match -nocase $pin_dir "I"] } {
          return $intr_cntrl
        }
    } else {
        #This is the case where External interrupt port is interrupting
        set intr_pin [::hsi::get_ports $intr_pin_name]
        if { [llength $intr_pin] == 0 } {
            return $intr_cntrl
        }
        set pin_dir [common::get_property DIRECTION $intr_pin]
        if { [string match -nocase $pin_dir "O"] } {
          return $intr_cntrl
        }
    }

    set intr_sink_pins [::hsi::utils::get_sink_pins $intr_pin]
    foreach intr_sink $intr_sink_pins {
        #changes made to fix CR 933826
        set sink_periph [lindex [::hsi::get_cells -of_objects $intr_sink] 0]
        if { [llength $sink_periph ] && [::hsi::utils::is_intr_cntrl $sink_periph] == 1 } {
            lappend intr_cntrl $sink_periph
        } elseif { [llength $sink_periph] && [string match -nocase [common::get_property IP_NAME $sink_periph] "xlconcat"] } {
            #this the case where interrupt port is connected to XLConcat IP.
            #changes made to fix CR 933826 
            set intr_ctrls [::hsi::utils::get_connected_intr_cntrl $sink_periph "dout"]
            foreach ctrl $intr_ctrls {
              lappend intr_cntrl $ctrl
            }
        }
    }
    return $intr_cntrl
}

#
# It will get the version information from IP VLNV property 
#
proc ::hsi::utils::get_ip_version { ip_name } {
    set version ""
    set ip_handle [::hsi::get_cells -hier $ip_name]
    if { [llength $ip_handle] == 0 } {
        error "ERROR:IP $ip_name does not exist in design"
        return ""
    }
    set vlnv [common::get_property VLNV $ip_handle]
    set splitted_vlnv [split $vlnv ":"]
    if { [llength $splitted_vlnv] == 4 } {
        set version [lindex $splitted_vlnv 3]
    } else {
        #TODO: Keeping older EDK xml support. It should be removed
        set version [common::get_property HW_VER $ip_handle]
    }
    return $version
}

#
# It will return IP param value
#
proc ::hsi::utils::get_ip_param_value { ip param} {
    set value [common::get_property $param $ip]
    if {[llength $value] != 0} {
        return $value
    }
    set value [common::get_property CONFIG.$param $ip] 
    if {[llength $value] != 0} {
        return $value
    }
}

#
# It will return board name
#
proc ::hsi::utils::get_board_name { } {
    global board_name
    set board_name [common::get_property BOARD [::hsi::current_hw_design] ]
     if { [llength $board_name] == 0 } {
        set board_name "."
    }
    return $board_name
}

proc ::hsi::utils::get_trimmed_param_name { param } {
    set param_name $param
    regsub -nocase ^CONFIG. $param_name "" param_name
    regsub -nocase ^C_ $param_name "" param_name
    return $param_name
}
#
# It returns the ip subtype. First its check for special type of EDK_SPECIAL parameter
#
proc ::hsi::utils::get_ip_sub_type { ip_inst_object} {
    if { [string compare -nocase cell [common::get_property CLASS $ip_inst_object]] != 0 } {
        error "get_mem_type API expect only mem_range type object whereas $class type object is passed"
    }

    set ip_type [common::get_property CONFIG.EDK_SPECIAL $ip_inst_object]
    if { [llength $ip_type] != 0 } {
        return $ip_type
    }

    set ip_name [common::get_property IP_NAME $ip_inst_object]
    if { [string compare -nocase "$ip_name"  "lmb_bram_if_cntlr"] == 0
        || [string compare -nocase "$ip_name" "isbram_if_cntlr"] == 0
        || [string compare -nocase "$ip_name" "axi_bram_ctrl"] == 0
        || [string compare -nocase "$ip_name" "dsbram_if_cntlr"] == 0
        || [string compare -nocase "$ip_name" "ps7_ram"] == 0 } {
            set ip_type "BRAM_CTRL"
    } elseif { [string match -nocase *ddr* "$ip_name" ] == 1 } {
         set ip_type "DDR_CTRL"
     } elseif { [string compare -nocase "$ip_name" "mpmc"] == 0 } {
         set ip_type "DRAM_CTRL"
     } elseif { [string compare -nocase "$ip_name" "axi_emc"] == 0 } {
         set ip_type "SRAM_FLASH_CTRL"
     } elseif { [string compare -nocase "$ip_name" "psu_ocm_ram_0"] == 0 
                || [string compare -nocase "$ip_name" "psu_ocm_ram_1"] == 0 } {
         set ip_type "OCM_CTRL"
     } else {
         set ip_type [common::get_property IP_TYPE $ip_inst_object]
     }
     return $ip_type
}

proc ::hsi::utils::generate_psinit { } {
    set obj [::hsi::get_cells -hier -filter {CONFIGURABLE == 1}]
    if { [llength $obj] == 0 } {
      set xmlpath [common::get_property PATH [::hsi::current_hw_design]]
      if { $xmlpath != "" } {
        set xmldir [file dirname $xmlpath]
        set file "$xmldir[file separator]ps7_init.c"
        if { [file exists $file] } {
          file copy -force $file .
        }
        
        set file "$xmldir[file separator]ps7_init.h"
        if { [file exists $file] } {
          file copy -force $file .
        }
      }
    } else {
      generate_target {psinit} $obj -dir .
    }
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
