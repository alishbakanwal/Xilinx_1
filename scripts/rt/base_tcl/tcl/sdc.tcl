# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2009
#                             All rights reserved.
# ****************************************************************************
namespace eval sdcrt {
    
    # "user" parameters
    set readSdcTcl 0

    # used in reporting source file name / line number
    variable cachedfname ""
    variable cachedlnum ""
    variable onetime true
    variable cmdname "" 

    # local variables (do not flip the default)
    set reportSummary 1
    set timeUnit   1000 ; # to convert to ps
    set capUnit       1 ; # to convert to pF
    set ign_done      0
    set verbose       0
    set useAllPins    1
    set maxLineLength 1024

    set currMod "NULL"  ; # current design for create_* (ECO) commands
    set currInst [list]

    proc readSdc {echo verbose mode file} {
        set file [rt::searchPath $file]
        if {$verbose} {
            set sdcrt::verbose $verbose
            set echo 1
        }
        if {$mode == ""} {
            # GEBRE should we reset the mode or leave it as is?
            # [rt::design] setTimingMode "common mode"
        } else {
            [rt::design] setTimingMode $mode
        }
        if {$sdcrt::readSdcTcl} {
            set sdcrt::reportSummary 0
            tcl_source $file
            set sdcrt::reportSummary 1
        } else {
            sdc::parse_file $echo $file
        }
		rt::current_instance
        report_summary
    }

    proc enableMsg {} {
      if {[info exists rt::inParallelWrap] && $rt::inParallelWrap && ![rt::UParam_get parallelDebug rc] && ![rt::UParam_get optVerbose rc]} {
        return false
      }
      return true
    }

    proc error {msg} {
        if {![enableMsg] } {
          return $msg
        }
        global sdcrt::cachedfname
        global sdcrt::cachedlnum
        if { ! ( $cachedfname eq "") } {
            #rt::UMsg_tclMessage CMD 120 $msg $cachedlnum $cachedfname
            rt::UMsg_tclMessageTrace CMD 120 $msg $cachedlnum $cachedfname
        } else {
            rt::UMsg_print "error: $msg"
        }
        if {[rt::UParam_get sdcContinueOnError rc] } {
            return $msg
        } else {
            return -code error $msg
        }
    }

    proc crit-warn {msg} {
        if {![enableMsg] } {
          return
        }
        # add in support for getting messages to Vivado
        global sdcrt::cachedfname
        global sdcrt::cachedlnum
        global sdcrt::cmdname
        if { ! ( $cachedfname eq "") } {
            #rt::UMsg_tclMessage CMD 122 $msg $cachedlnum $cachedfname
            if  { ($cachedlnum eq "") } {
              set newmsg "$msg command: \"$cmdname\""           
              rt::UMsg_tclMessage CMD 123 $newmsg
            } else { 
              rt::UMsg_tclMessageTrace CMD 122 $msg $cachedlnum $cachedfname
            } 
        } else {
            set newmsg "$msg command: \"$cmdname\"\n"           
            rt::UMsg_print "critical warning: $newmsg"
        }
    }

    proc warning {msg} {
        if {![enableMsg] } {
          return
        }
        # add in support for getting messages to Vivado
        global sdcrt::cachedfname
        global sdcrt::cachedlnum
        global sdcrt::cmdname
        if { ! ( $cachedfname eq "") } {
            #rt::UMsg_tclMessage CMD 121 $msg $cachedlnum $cachedfname
			rt::UMsg_tclMessageTrace CMD 121 $msg $cachedlnum $cachedfname
        } else {
            set newmsg "$msg command: \"$cmdname\"\n"           
            rt::UMsg_print "warning: $newmsg"
        }
    }

    proc msg {args} {
	if {[lindex $args 0] == "-nonewline"} {
	    rt::UMsg_print "[lindex $args 1]"
	} else {
	    rt::UMsg_print "[lindex $args 0]\n"
	}
    }

    proc time {t} {
	global sdcrt::timeUnit
        return [expr $t * $timeUnit]
    }

    proc getSdcTime {t} {
        set tUnit [rt::UParam_get time_units_for_sdc rc]
	switch -- $tUnit {
	    "ps" {
                return $t
	    }
	    "ns"     - 
	    "1000ps" { 
		return [expr ($t/1000)]
	    }
	    default  { 
		warning "unknown time_units_for_sdc"
                return $t
	    }
	}
    }

    proc cap {c} {
	global sdcrt::capUnit
        return [expr $c * $capUnit]
    }

    proc edgeTime {this that val} {
	if {$this == 1 || $that == 0} {
	    set t [time $val]
	} else {
	    set t "<ill>"
	}
	return $t
    }

    proc rfTime {rise fall val} {
	set r [edgeTime $rise $fall $val]
	set f [edgeTime $fall $rise $val]
	return "$r $f"
    }

    proc release {args} {
	set parm [rt::UParam_get dontReleaseObjects rc]
	if {$parm == true} {
	    return
	}
	foreach obj [utils::flatList $args] {
	    switch -- [rt::typeOf $obj] {
		"NDesS" {
		    $obj release
		}
		"NPinS" -
		"NNetS" -
		"NInstS" {
		    [$obj design] release
		}
	    }
	}
    }

    proc objectName {arg} {
        global rt::UNM_sdc
	switch -- [rt::typeOf $arg] {
	    "NPinS" -
	    "NNetS" -
	    "NInstS" {
		set name [$arg fullName $rt::UNM_sdc]
	    }
            "NPort" -
	    "NGenS" -
	    "NRealModS" -
	    "NBaseModS" {
                set name [$arg name $rt::UNM_sdc]
            }
            "NLibS" -
	    "TClock" -
	    "NCellS" {
		set name [$arg name]
	    }
	    default {
		set name $arg
	    }
	}
	return $name
    }

    proc acquire {objs} {
	foreach obj [utils::flatList $objs] {
	    if {[rt::typeOf $obj] != "NULL"} {
		set des [$obj design]
		set gInst [$des genomeInstance]
		if {$gInst != "NULL"} {
		    set genome [$gInst isGenome]
		    $genome acquireDesignForInstance $gInst false
		}
	    }
	}
    }

	# acquire the genomes of objs, with constraint info loaded
	proc acquireWithConstraints {objs} {
		#puts "acquiring $objs with const"
		foreach obj [utils::flatList $objs] {
			if {[rt::typeOf $obj] != "NULL"} {
				set des [$obj design]
				set gInst [$des genomeInstance]
				if {$gInst != "NULL"} {
					set genome [$gInst isGenome]
					#puts "$obj is genome, design is $des, inst is $gInst, genome is $genome"
					$genome acquireDesignForInstance $gInst true
				}
			}
		}
    }
	
    proc addToPinList {pinArrayRef pinsRef pin} {
	upvar $pinsRef pins
	upvar $pinArrayRef pinArray
	if { ![info exists pinArray($pin)] } {
	    lappend pins $pin
	    set pinArray($pin) 1;
	} else {
	    release $pin
	}
    }

    proc flatPins {pin {upGenome true}} {
	set fPins {}
	foreach fPin [$pin flatPins] {
	    set inst [$fPin ownerInstance]
	    if {$inst != "NULL"} {
		set gen [$inst isGenome]
		if {$gen != "NULL"} {
		    set gDes [$gen acquireDesignForInstance $inst false]
		    set gPin [[$gDes topModule] pin [$fPin index]]
		    lappend fPins [flatPins $gPin false]
		} else {
		    acquire $fPin
		    lappend fPins $fPin
		}
	    } else {
		set des  [$fPin design]
		set inst [$des genomeInstance]
		if {$inst != "NULL"} {
		    if {$upGenome} {
			set tPin [$inst pin [$fPin index]]
			# restart traversal upGenome
			release $fPins
			release $pin
			return [flatPins $tPin]
		    }
		} else {
		    acquire $fPin
		    lappend fPins $fPin
		}
	    }
	}
	release $pin
	return [utils::flatList $fPins]
    }

    proc flatLoadPins {pin genomesToo {upGenome true}} {
	set lPins {}
	if {!$genomesToo} {
	    foreach lPin [$pin flatLoadPins NULL true] {
		acquire $lPin
		lappend lPins $lPin
	    }
	    release $pin
	    return $lPins
	}
	foreach lPin [$pin flatLoadPins NULL true] {
	    set inst [$lPin ownerInstance]
	    if {$inst != "NULL"} {
		set gen [$inst isGenome]
		if {$gen != "NULL"} {
		    set gDes [$gen acquireDesignForInstance $inst false]
		    set gPin [[$gDes topModule] pin [$lPin index]]
		    lappend lPins [flatLoadPins $gPin $genomesToo false]
		} else {
		    acquire $lPin
		    lappend lPins $lPin
		}
	    } else {
		set des  [$lPin design]
		set inst [$des genomeInstance]
		if {$inst != "NULL"} {
		    if {$upGenome} {
			set tPin [$inst pin [$lPin index]]
			lappend lPins [flatLoadPins $tPin $genomesToo]
		    }
		} else {
		    acquire $lPin
		    lappend lPins $lPin
		}
	    }
	}
	release $pin
	return [utils::flatList $lPins]
    }

    proc removeFromPinList {pinArrayRef pinsRef pin} {
	upvar $pinsRef pins
	upvar $pinArrayRef pinArray
	set idx [lsearch $pins $pin]
	if {$idx < 0} {
	    warning "Could not find pin '$pin' in '$pins'"
	} else {
	    set pins [lreplace $pins $idx $idx]
	    unset pinArray($pin)
	}
	release $pin
    }

    proc otherSide {lpin genomesToo} {
	# This procedure assumes the design is uniquified.
	set pin [$lpin otherSide]
	if {($pin == "NULL") && $genomesToo} {
	    set pInst [$lpin ownerInstance]
	    if {$pInst == "NULL"} {
		set inst [[$lpin design] genomeInstance]
		if {$inst != "NULL"} {
		    set pin [$inst pin [$lpin index]]
		}
	    } else {
		set pGen [$pInst isGenome]
		if {$pGen != "NULL" && [$lpin index] < [$pGen pinCount]} {
		    set mod [[$pGen acquireDesignForInstance $pInst false] topModule]
		    set pin [$mod pin [$lpin index]]
		}
	    }
	}
	if {$pin != "NULL"} {
	    acquire $pin
	}
	return $pin
    }

    proc flatDriverPins {lpin otherLoads pinArrayRef pinListRef hier_pins_ref pushToDrivers} {
	# This procedure assumes the design is uniquified.
	upvar $otherLoads otherL
	upvar $pinArrayRef pinArray
	upvar $pinListRef pinList
	upvar $hier_pins_ref hier_pins_to
	set cflatPins [rt::UParam_get pcr3713 rc]
	if {$cflatPins} {
	    set noFlatLoad false
	    if {$pushToDrivers < 2} {
		set noFlatLoad true
	    }
	    set pins [$lpin leafDrivePins $noFlatLoad true true]
	    set otherL true
	    foreach pin $pins {
		set otherL false
		lappend hier_pins_to [$pin fullName $rt::UNM_none false]
		addToPinList pinArray pinList $pin
	    }
	    release $lpin
	    return
	}
	if {[$lpin direction] != "input"} {
	    # always go inside genomes to find the driver
	    set genomesToo "true"
            set inst [$lpin ownerInstance]
            set gen "NULL"
            if {$inst ne "NULL"} {
                set gen [$inst isGenome]
            }
            if {$gen ne "NULL" && [$lpin index] >= [$gen pinCount]} {
                return
            }
	    set pin [otherSide $lpin $genomesToo]
	    if {$pin == "NULL"} {
		lappend hier_pins_to [$lpin fullName $rt::UNM_none false]
		addToPinList pinArray pinList $lpin
		return
	    }
	    acquire $pin
	    release $lpin
	    set lpin $pin
	}
	if {[$lpin hasFlatLoad]} {
	    set otherL true
	    if {$pushToDrivers < 2} {
		release $lpin
		return
	    }
	}
	foreach fPin [$lpin flatDrivePins] {
	    acquire $fPin
	    flatDriverPins $fPin otherL pinArray pinList hier_pins_to $pushToDrivers
	}
    }

    proc driverPins {lpin otherLoads} {
	global sdcrt::hier_pins
	upvar $otherLoads otherL
	set des [$lpin design]
	if {![info exist uniquified([$des name])]} {
	    $des uniquify false true
	    set uniquified([$des name]) 1
	    # no need to find srcPin again
	    # after uniquify because
	    # UParam::findUniquifies() == true
	}
	set pinList {}
	set hier_pins_to {}
	array set pinArray {}
	# collect all the pins
	set pushToDrivers 2
	flatDriverPins $lpin otherL pinArray pinList hier_pins_to pushToDrivers
	unset hier_pins_to
	array unset pinArray
	return $pinList
    }

    proc flatLPins {lpin genomesToo pinArrayRef pinListRef hier_pins_ref} {
	# This procedure assumes the design is uniquified.
	upvar $pinArrayRef pinArray
	upvar $pinListRef pinList
	upvar $hier_pins_ref hier_pins_to

	set cflatPins [rt::UParam_get pcr3713 rc]
	if {$cflatPins} {
	    set pinSideOnly "true"
	    set pins [$lpin leafLoadPins $pinSideOnly $genomesToo true]
	    foreach pin $pins {
		acquire $pin
		lappend hier_pins_to [$pin fullName $rt::UNM_none false]
		addToPinList pinArray pinList $pin
	    }
	    release $lpin
	    return
	}

	if {[$lpin direction] == "input"} {
	    set pin [otherSide $lpin $genomesToo]
	    if {$pin == "NULL"} {
		lappend hier_pins_to [$lpin fullName $rt::UNM_none false]
		addToPinList pinArray pinList $lpin
		return
	    }
	    if {$genomesToo} {
		set pin [otherSide $lpin "false"]
	    }
	    if {$pin != "NULL"} {
		release $lpin
		set lpin $pin
	    }
	}
	foreach loadPin [flatLoadPins $lpin $genomesToo] {
#	    msg -nonewline " '[$loadPin fullName]'"
	    lappend hier_pins_to [$loadPin fullName $rt::UNM_none false]
	    addToPinList pinArray pinList $loadPin
	}
    }

    proc loadPins {lpin genomesToo} {
	global sdcrt::hier_pins
	set des [$lpin design]
	if {![info exist uniquified([$des name])]} {
	    $des uniquify false true
	    set uniquified([$des name]) 1
	    # no need to find srcPin again
	    # after uniquify because
	    # UParam::findUniquifies() == true
	}
	set pinList {}
	set hier_pins_to {}
	array set pinArray {}
	flatLPins $lpin $genomesToo pinArray pinList hier_pins_to
	unset hier_pins_to
	array unset pinArray
	return $pinList
    }

    proc moveConstraintInfo { hier_pins_ref  pinNm  hier_pins_to_ref } {
        upvar $hier_pins_ref hier_pins
        upvar $hier_pins_to_ref hier_pins_to
        if {![info exists hier_pins($pinNm)]} {
           set nameList {}
           foreach tmpName $hier_pins_to {
              lappend nameList $tmpName
           }
           rt::UMsg_tclMessageTrace CMD 124 $pinNm $nameList
           rt::UParam_set writeParallelTimingXdc true
        }
    }

    proc pinList {pins {plopt {}} {genomesToo 0} {pushToDrivers 0} {otherLoads "false"}} {
	global sdcrt::not_found_objects
	global sdcrt::hier_pins
	upvar $otherLoads otherL
	set otherL "false"

	array set pinArray {}

        set des [$rt::db topDesign]
	if {$des == "NULL"} {
	    set not_found_objects($pins) 1
	    return {}
	}
        set mod [$des topModule]
	if {$mod == "NULL"} {
	    set not_found_objects($pins) 1
	    return {}
	}
        set list {}
        set mode add
        foreach pin [utils::flatList $pins] {
	    if {$pin == "all_inputs()"} {
                for {set pi [[$mod loadPins] begin]} {[$pi count]} {$pi incr} {
		    addToPinList pinArray list [$mod pin $pi]
                }
                set mode sdc
            } elseif {$pin == "all_outputs()"} {
                for {set pi [[$mod driverPins] begin]} {[$pi count]} {$pi incr} {
                    addToPinList pinArray list [$mod pin $pi]
                }
                set mode sdc
            } elseif {$pin == "-"} {
                set mode sub
            } elseif {$pin == "+"} {
                set mode add
            } elseif {$mode == "sdc"} {
                msg "error: expected '+' or '-'"
		return
            } else {
		global rt::UNM_sdc
		set foundPins {}
		switch -- [rt::typeOf $pin] {
		    "NInstS" {
			set inst $pin
			set pinNm [$inst fullName $rt::UNM_none false]
			set foundPins [$inst findPins $plopt]
                        rt::UParam_set writeParallelTimingXdc true
			release $inst
		    }
		    "NNetS" {
			set net $pin
			set pinNm [$net fullName $rt::UNM_none false]
			set driverPins [[$net firstPin] flatDrivePins]
			foreach pin $driverPins {
			    lappend foundPins $pin
			}
			acquire $foundPins
                        rt::UParam_set writeParallelTimingXdc true
			release $net
		    }
		    "NPinS" {
			set pinNm [$pin fullName $rt::UNM_none false]
			set foundPins $pin
		    }
		    default {
			set hier 0
			set pinNm $pin
			set foundPins [$mod findPins $pin $rt::UNM_sdc $hier $plopt 0 0 ""]
		    }
		}
		if {$foundPins != {}} {
		    foreach pinP $foundPins {
			if {$mode == "add"} {
			    if {[$pinP isHierPin $genomesToo]} {
				# Need to move the constraint to all flat load or driver pins.
				# Need to make sure the whole design is now uniquified
				# otherwise the NPin::floatLoadPins/flatDrivePins API will not work
				set des [$pinP design]
				if {![info exist uniquified([$des name])]} {
				    $des uniquify false true
				    set uniquified([$des name]) 1
				    # no need to find srcPin again
				    # after uniquify because
				    # UParam::findUniquifies() == true
				}
#				msg -nonewline "info: Moving constraint from hierarchical pin '[$pinP fullName]' to"
				if {$pushToDrivers > 0} {
				    set hier_pins_to {}
				    set pinList {}
				    flatDriverPins $pinP otherL pinArray pinList hier_pins_to $pushToDrivers
				    
					#if driver pin empty, use original load pin instead. CR 708689
					if {$pinList eq "NULL" || $pinList eq {}} {
						set pinList $pinP
						set otherL "false"
					}

					if {$pushToDrivers <= 1 && $otherL} {
					foreach pin $pinList {
					    unset pinArray($pin)
					}
					release pinList
					set hier_pins_to {}
					flatLPins $pinP $genomesToo pinArray list hier_pins_to
				    } else {
					foreach pin $pinList {
					    lappend list $pin
					}
				    }
				} else {
				    set hier_pins_to {}
				    flatLPins $pinP $genomesToo pinArray list hier_pins_to
				}
				#				msg ""
				if { [llength $hier_pins_to] ne 0 } {
					moveConstraintInfo hier_pins  $pinNm  hier_pins_to 
					set hier_pins($pinNm) $hier_pins_to
				}
			    } else {
				if {![$pinP isHierPin "true"]} {
				    addToPinList pinArray list $pinP
				    continue
				}
				if {$pushToDrivers > 0} {
				    set hier_pins_to {}
				    set pinList {}
				    flatDriverPins $pinP otherL pinArray pinList hier_pins_to $pushToDrivers

					#if driver pin empty, use original load pin instead. CR 708689
					if {$pinList eq "NULL" || $pinList eq {}} {
						set pinList $pinP
						set otherL "false"
					}

				    if {$pushToDrivers > 1 || $otherL == "false"} {
						foreach pin $pinList {
							lappend list $pin
						}
						if { [llength $hier_pins_to] ne 0 } {
							moveConstraintInfo hier_pins  $pinNm  hier_pins_to 
							set hier_pins($pinNm) $hier_pins_to
						}
						continue;
				    }
				    foreach pin $pinList {
					unset pinArray($pin)
				    }
				    release pinList
				}

				addToPinList pinArray list $pinP
				if {$genomesToo == 0} {
				    set inst [$pinP ownerInstance]
				    if {$inst != "NULL"} {
					set gen [$inst isGenome]
					if {$gen != "NULL"} {
					    set eqArr [$gen assertedEquivalencies]
					    set idx   [$pinP index]
					    set eqPin [$eqArr pin $idx]
					    set isLdr [$eqPin isLeader]
					    if {$isLdr} {
						for {set pi [[$gen outPins] begin]} {[$pi ok]} {[$pi incr]} {
						    set oPin [$eqArr pin [$pi current]]
						    if {[$oPin isEquiv isInv] == $idx} {
							if {$isInv == 0} {
							    set fPin [$inst pin $pi]
							    set hier_pins_to {}
							    flatLPins $fPin $genomesToo pinArray list hier_pins_to
								#	  msg ""
								if { [llength $hier_pins_to] ne 0 } {
									moveConstraintInfo hier_pins  $pinNm  hier_pins_to 
									set hier_pins($pinNm) $hier_pins_to
								}
							}
						    }
						}
					    }
					}
				    }
				}
			    }
			} else {
			    removeFromPinList pinArray list $pinP
			}
		    }
                } else {
					#warning "Couldn't find object $pinNm"
					set not_found_objects($pinNm) 1
                }
            }
        }
	array unset pinArray
        return $list
    }

    proc supported {options known command} {
	global sdcrt::not_supported_options
	upvar $options opt
	foreach arg [array names opt] {
	    if {[lsearch -exact $known $arg] < 0} {
		set val "$command $arg"
		if {[info exists not_supported_options($val)]} {
		    incr not_supported_options($val)
		} else {
		    set not_supported_options($val) 1
		}
	    }
	}
    }

    proc ignored_command {command} {
	global sdcrt::ignored_commands
	if {[info exists ignored_commands($command)]} {
	    incr ignored_commands($command)
	} else {
	    set ignored_commands($command) 1
	}
    }
    
    proc unsupported_command {command} {
	global sdcrt::unsupported_commands
	
	if {[info exists unsupported_commands($command)]} {
	    incr unsupported_commands($command)
	} else {
	    set unsupported_commands($command) 1
	}
    }
    
    proc report_summary {} {
	global sdcrt::ignored_commands
	global sdcrt::unsupported_commands
	global sdcrt::not_supported_options
	global sdcrt::not_found_objects
	global sdcrt::hier_pins

	foreach uc [array names unsupported_commands] {
	    warning "SDC (yet) unsupported command '$uc' ignored $unsupported_commands($uc) time(s)"
	}
	foreach uc [array names ignored_commands] {
	    msg "info: SDC command '$uc' ignored $ignored_commands($uc) time(s)"
	}

	foreach ns [array names not_supported_options] {
	    msg "info: SDC option '$ns' ignored $not_supported_options($ns) time(s)"
	}
		
		set nfp [array size not_found_objects]
		set max [rt::UParam_get message_suppress_limit rc]
		if {$nfp > 0} {
			# not found object message removed per CR 691583	  
			#msg -nonewline "warning: SDC could not find $nfp objects"
			if {$nfp > $max} {
				#	msg -nonewline ". Here's the first $max"
			}
			# msg ":"
			set i 0
			foreach p [lsort [array names not_found_objects]] {
				# msg "             $p"
				if {[incr i] == $max} {
					break
				}
			}
		}
	set nfp [array size hier_pins]
	if {$nfp > 0} {
#	    msg "INFO: Moved $nfp constraints on hierarchical pins to their respective driving/loading pins"
	    rt::UMsg_tclMessage CMD 126 $nfp
	    rt::UParam_set writeParallelTimingXdc true
#	    msg -nonewline "INFO: Moved $nfp constraints on hierarchical pins to their respective driving/loading pins"
# 	    if {$nfp > $max} {
# 		msg -nonewline ". Here's the first $max"
# 	    }
# 	    msg ":"
# 	    set i 0
# 	    foreach p [array names hier_pins] {
# 		msg "            FROM: $p TO: $hier_pins($p)"
# 		if {[incr i] == $max} {
# 		    break
# 		}
# 	    }
	}

	array unset ignored_commands
	array unset unsupported_commands
	array unset not_supported_options
	array unset not_found_objects
	array unset hier_pins
    }

    proc objNames {arg} {
        if {[lindex $arg 0] != $arg} {
            set result {}
            foreach argi $arg {
                lappend result [objNames $argi]
            }
        } else {
            set result [sdcrt::objectName $arg]
        }
        return $result
    }

    proc exec {cmd cmdargs} {

	# echo command: keep insync with cli::addCommand
        set logCmdLine 1
        if {$cmd eq "foreach_in_collection"} {
            set logCmdLine 0
            # do not try to evaluate -- set cmdLine "$cmd [objNames $cmdargs]"
            # as cmdargs would be a TCL procedure body
        }

        set logToCmdFile 1
        if {[regexp "_collection$" $cmd] || [regexp "^get_" $cmd] || [regexp "^all_" $cmd] || $cmd eq "group_path"} {
            # skip these commands as they could
            # generate a huge output text
            set logToCmdFile 0
        }

        if {$logCmdLine} {
            if {[info exists ::collection_result_display_limit] &&
                [regexp {_collection$} $cmd] && 
                $::collection_result_display_limit > 0} {
                set limitIndex [expr $::collection_result_display_limit - 1]
                set cmdLine "$cmd [objNames [lrange [utils::flatList $cmdargs] 0 $limitIndex]]"
            } else {
	    set cmdLine "$cmd [objNames $cmdargs]"
            }

            if {$logToCmdFile} {
              if {([info exist rt::cmdFd]) && $rt::cmdFdEcho} {
	        tcl_puts $rt::cmdFd $cmdLine
            }
            }
	    if {[info script] != {} && $rt::cmdEcho} {
	        rt::UMsg_print "> $cmdLine\n"
	    } else {
                if {[string length $cmdLine] > $sdcrt::maxLineLength} {
                    set maxIdx [expr {$sdcrt::maxLineLength - 1}]
                    set cmdLine [string range $cmdLine 0 $maxIdx]
                    set cmdLine "$cmdLine... (message truncated)"
                }
		rt::UMsg_log "> $cmdLine\n"
	    }
        }

	set args {}
	set num [llength $cmdargs]
	set i 0
	set retFile ""
	while {$i < $num} {
	    set arg [lindex $cmdargs $i]
	    if {$arg == ">" || $arg == ">>"} {
		incr i
		set retFile [lindex $cmdargs $i]
		if {$arg == ">"} {
		    set retMode "false"
		} else {
		    set retMode "true"
		}
	    } else {
		lappend args $arg
	    }
	    incr i
	}
	if {$retFile != ""} {
	    rt::UMsgHandler_redirect $retFile $retMode
	}
	set rc [sdc::parse_command 1.7 $cmd $args]
	if {$cmd == "report_timing"} {
	    global sdcrt::hier_pins
	    array unset hier_pins
	}
	if {$sdcrt::reportSummary} {
	    report_summary
	}
	rt::UMsgHandler_reset
	if {$retFile != ""} {
	    rt::UMsgHandler_redirect -
	}
	return $rc
    }

    proc getClockInCurrentMode {name} {
	if {[rt::typeOf $name] == "TClock"} {
	    set clk $name
	} else {
	    set des [rt::design]
	    set clk [$des findClockInCurrentMode [string trim $name " "]]
	    if {$clk == "NULL"} {
		if [rt::UParam_get getClockCreatesClock rc] {
		    if {$name != ""} {
			msg "info: Using clock '$name' before it has been defined"
			set clk [$des defineClock $name]
		    } else {
			warning "Creating clock without name"
			set clk [$des defineClock $name]
		    }
		}
	    }
	}
	return $clk
    }

    proc findClocks {expr} {
	if {[rt::typeOf $expr] == "TClock"} {
	    set clkList $expr
	} else {
	    set des [rt::design]
	    set clkList [$des findClocks $expr]
	    if {$clkList == {}} {
		set not_found_objects($expr) 1
	    }
	}
	return $clkList
    }

    proc findClocksInCurrentMode {expr} {
	if {[rt::typeOf $expr] == "TClock"} {
	    set clkList $expr
	} else {
	    set des [rt::design]
	    set clkList [$des findClocksInCurrentMode $expr]
	}
	return $clkList
    }

    proc isDerived {testClock refClk} {
	set masterClk [$testClock masterClock]
	if {$masterClk != "NULL"} {
	    if {$masterClk == $refClk} {
		return 1;
	    } else {
		return [isDerived $masterClk $refClk]
	    }
	}
	return 0;
    }

    proc setException {command optArray {emptyListFTT false}} {
	upvar $optArray opt
	upvar $emptyListFTT emptyList2

	set des [rt::design]
	set nr 0
	set frClocks {}
	set toClocks {}
	set frStage -1
	set toStage -1
	set genomesToo 0
	set pushToDrivers 1
	set alwaysPushToInputs [rt::getParam alwaysPushToInputs]
	if {$alwaysPushToInputs || ($command == "report_timing")} {
	    set genomesToo 0
	    set pushToDrivers 0
	}
	set edges {}
#	puts "exists [info exist opt(-from)] to [info exist opt(-to)]"
	set emptyList false
	if [info exist opt(-from)] {
	    set frStage $nr
	    set frPins {}
	    if { [llength [lindex [lindex $opt(-from) 0] 1] ] == 0 } {
		warning "$command : Empty from list";
		set emptyList true
	    }
		set needWarning false
	    foreach obj [utils::flatList [lindex [lindex $opt(-from) 0] 1]] {
			set clkList [findClocksInCurrentMode $obj]
			#		puts "obj $obj clkList $clkList"
			if {$clkList != {}} {
				lappend frClocks $clkList
			} else {
				set needWarning true
				lappend frPins $obj
			}
	    }
	    lappend edges [lindex [lindex $opt(-from) 0] 0]
	    set pins [pinList $frPins "-from" $genomesToo $pushToDrivers]
		if {$needWarning} {
			if {$pins == "" || $pins == "NULL" || $pins eq "NULL"} {
				warning "The argument for option -from is not a valid pin"
			}
		}
		lappend stages $pins
	    incr nr
	}
	if [info exist opt(-through)] {
	    if { [llength [lindex [lindex $opt(-through) 0] 1] ] == 0 } {
		warning "$command : Empty through list"
		set emptyList true
	    }
	    foreach through $opt(-through) {
		lappend edges [lindex $through 0]
		lappend stages [pinList [lindex $through 1] "-" $genomesToo $pushToDrivers]
		incr nr
	    }
	}
	if [info exist opt(-to)] {
	    set toStage $nr
	    set toPins {}
	    if { [llength [lindex [lindex $opt(-to) 0] 1] ] == 0 } {
		warning "Empty to list"
		set emptyList true
	    }
		set needWarning false
	    foreach obj [utils::flatList [lindex [lindex $opt(-to) 0] 1]] {
			set clkList [findClocksInCurrentMode $obj]
			if {$clkList != {}} {
				lappend toClocks $clkList
			} else {
				set needWarning true
				lappend toPins $obj
			}
	    }
	    lappend edges [lindex [lindex $opt(-to) 0] 0]
		set pins [pinList $toPins "-to" $genomesToo $pushToDrivers]
		if {$needWarning} {
			if {$pins == "" || $pins == "NULL" || $pins eq "NULL"} {
				warning "The argument for option -to is not a valid pin"
			}
		}
		lappend stages $pins
		incr nr
	}
#	puts "edges $edges"
	if { $emptyList } {
	    if [info exist emptyList2] {
		set emptyList2 true
	    }
	    release $stages
	    return "NULL"
	}

        set hold [info exist opt(-hold)]
        set setup [info exist opt(-setup)]

	if {$nr == 0 && $command != "group_path"} {
	    return "NULL"
	}
	set weight -1
	set crtRange -1
	if {[info exist opt(-weight)]} {
	    set weight $opt(-weight)
	}
	if {[info exist opt(-critical_range)]} {
	    set crtRange  [time $opt(-critical_range)]
	}
	switch -- $command {
	    "group_path" {
		set name "NULL"
		if {[info exist opt(-name)]} {
		    set name $opt(-name)
		} elseif {[info exist opt(-default)]} {
		    set name "default"
		}
		if {$name == "NULL"} {
		    return "NULL"
		}
		set exception [$des newGroupException $nr "userImpl" $name $weight $crtRange]
		if {$nr == 0} {
		    return $exception
		}
	    }
	    "report_timing" {
		set exception [$des newGroupException $nr "intAss" "report_timing" $weight $crtRange]
	    }
	    "set_false_path" {
			if {$hold && !$setup} {
				warning "set_false_path option -hold not supported, this set_false_path constraint is ignored"
				set exception "NULL"
				#set exception [$des newFalsePathException $nr "userIgnore" $setup $hold]
			} else {
				set exception [$des newFalsePathException $nr "userImpl" $setup $hold]
			}
	    }
	    "set_multicycle_path" {
                if {$hold && !$setup} {
		    set exception [$des newMultiCycleException $nr $opt(path_multiplier) [info exist opt(-start)] "userIgnore" $setup $hold]
                } else {
		    set exception [$des newMultiCycleException $nr $opt(path_multiplier) [info exist opt(-start)] "userImpl" $setup $hold]
                }
	    }
	    "set_max_delay" {
		set exception [$des newMaxDelayException $nr [time $opt(delay_value)] "userImpl"]
	    }
            "set_min_delay" {
		set exception [$des newMinDelayException $nr [time $opt(delay_value)] "userIgnore"]
            }
            "set_data_check" {
                set clkList ""
                if {[info exists opt(-clock)]} {
                    set clkList [getObjListRef $opt(-clock)]
                }
		set exception [$des newDataCheckException $nr [time $opt(value)] $clkList "userIgnore" $setup $hold]
            }
            "get_timing_paths" {
                #set exception [$des newTimingPathException $nr "intAss"]
                set exception [$des newMultiCycleException $nr 1 0 "intAss"]
                $exception setInternalException
            }
	    default {
		msg "error: Unknown Exception '$command'"
		return "NULL"
	    }
	}
	if {$sdcrt::verbose} { 
	    puts -nonewline "\# $command  $optArray"
	    set fcc [llength [utils::flatList $frClocks]]
	    if {$fcc > 0} {puts -nonewline " -from $fcc clocks"}
	    set st 0
	    foreach stPins $stages {
		if {$st == $frStage} {
		    set plopt "-from"
		} elseif {$st == $toStage} {
		    set plopt "-to"
		} else {
		    set plopt "-through"
		}
		puts -nonewline " $plopt [llength $stPins] pins"
		incr st
	    }
	    set tcc [llength [utils::flatList $toClocks]]
	    if {$tcc > 0} {puts -nonewline " -to $tcc clocks"}
	    puts ""
	}
	if {$exception != "NULL"} {
	    foreach clk [utils::flatList $frClocks] {
		#	    puts "From clock $clk edge [lindex $edges 0]"
		$exception addClock $clk 1 [lindex $edges 0]
	    }
	    foreach clk [utils::flatList $toClocks] {
		#	    puts "To clock $clk edge [lindex $edges [expr ($nr - 1)]]"
		$exception addClock $clk 0 [lindex $edges [expr ($nr - 1)]]
	    }
	}
	set st 0
	set gStages {}
	foreach stPins $stages {
	    if {$st == $frStage} {
		set plopt "-from"
		if {$exception != "NULL"} {
		    $exception setFromPin
		}
	    } elseif {$st == $toStage} {
		set plopt "-to"
		if {$exception != "NULL"} {
		    $exception setToPin
		}
	    } else {
		set plopt "-"
	    }
#	    puts "plopt $plopt edge [lindex $edges $st] stpins $stPins"
	    set gPins {}
	    foreach pin $stPins {
		if {[[$pin design] genome] == "NULL"} {
#		    puts "Adding pin $pin [lindex $edges $st]"
		    if {$exception != "NULL"} {
			$exception addPin $pin $st $plopt [lindex $edges $st]
		    }
		    release $pin
		} else {
		    lappend gPins $pin
		}
	    }
	    incr st
	    lappend gStages $gPins
	}
	set st 0
	foreach stPins $gStages {
	    if       {$st == $frStage} {set plopt "-from"
	    } elseif {$st == $toStage} {set plopt "-to"
	    } else                     {set plopt "-"
	    }
#	    puts "plopt $plopt edge [lindex $edges $st] stpins $stPins"
	    foreach pin $stPins {
		if {$exception != "NULL"} {
		    $exception addPin $pin $st $plopt [lindex $edges $st]
		}
		release $pin
	    }
	    incr st
	}
	if {[rt::UParam_get echoSDC rc] == "true"} {
	    if {$exception != "NULL"} {
		$exception write
	    }
	}
	return $exception
    }

    proc removeFromCollection {coll remo} {
        set sortedRemo [lsort [utils::flatList $remo]]

        set newList {}
        foreach elem [utils::flatList $coll] {
            if {[lsearch -exact -sorted $sortedRemo $elem] == -1} {
                lappend newList $elem
            }
        }
        return $newList
    }

    proc addToCollection {coll addList uniq} {
        set newList {}
        if {$uniq} {
	    foreach elem [utils::flatList $coll] {
                if {[lsearch -exact $newList $elem] == -1} {
                    lappend newList $elem
                }
            }
	    foreach elem [utils::flatList $addList] {
                if {[lsearch -exact $newList $elem] == -1} {
                    lappend newList $elem
                }
            }
        } else {
	    foreach elem [utils::flatList $coll] {
                lappend newList $elem
            }
            foreach elem [utils::flatList $addList] {
                lappend newList $elem
            }
        }
        return $newList
    }

    proc findLibrary {nm} {
	set libName [lindex [split $nm :] end]
	set lib [$rt::db findLibrary $libName]
	if {$lib == "NULL"} {
	    global sdcrt::not_found_objects
	    set not_found_objects($nm) 1
	    return -code error "No such library: '$nm'"
	}
	return $lib
    }

    proc getFilteredList {filterExpr isRegexp objList} {
        if {$objList == {} || $filterExpr eq ""} {
            return [utils::flatList $objList]
        }

        regsub -all {[[:space:]]+} $filterExpr "" iFilterExpr
    
        set exprList [list]
    
        set aList [join [split $iFilterExpr "&&"]]
        set oList [join [split [lindex $aList 0] "||"]]
        lappend exprList [lindex $oList 0]
        for {set j 1} {$j < [llength $oList]} {incr j} {
            lappend exprList "||"
            lappend exprList [lindex $oList $j]
        }
    
        for {set i 1} {$i < [llength $aList]} {incr i} {
            lappend exprList "&&"
            set oList [join [split [lindex $aList $i] "||"]]
            lappend exprList [lindex $oList 0]
            for {set j 1} {$j < [llength $oList]} {incr j} {
                lappend exprList "||"
                lappend exprList [lindex $oList $j]
            }
        }
    
        set evalExpr ""
        for {set i 0} {$i < [llength $exprList]} {incr i} {
            if {[expr $i%2] == 0} {
                set expression [lindex $exprList $i]
                if {[regexp {@?(.*)==(.*)} $expression match attr value]} {
                    set evalExpr "$evalExpr \[string equal \[rtdc::getAttribute 1 \"\" \$obj $attr\] $value\]"
                } elseif {[regexp {@?(.*)!=(.*)} $expression match attr value]} {
                    set evalExpr "$evalExpr !\[string equal \[rtdc::getAttribute 1 \"\" \$obj $attr\] $value\]"
                } elseif {[regexp {@?(.*)>(.*)} $expression match attr value]} {
                    set evalExpr "$evalExpr \[rtdc::getAttribute 1 \"\" \$obj $attr\] > $value"
                } elseif {[regexp {@?(.*)<(.*)} $expression match attr value]} {
                    set evalExpr "$evalExpr \[rtdc::getAttribute 1 \"\" \$obj $attr\] < $value"
                } elseif {[regexp {@?(.*)>=(.*)} $expression match attr value]} {
                    set evalExpr "$evalExpr \[rtdc::getAttribute 1 \"\" \$obj $attr\] >= $value"
                } elseif {[regexp {@?(.*)<=(.*)} $expression match attr value]} {
                    set evalExpr "$evalExpr \[rtdc::getAttribute 1 \"\" \$obj $attr\] <= $value"
                } elseif {[regexp {@?(.*)=~(.*)} $expression match attr value]} {
                    if {$isRegexp} {
                        set evalExpr "$evalExpr \[regexp \{$value\} \[rtdc::getAttribute 1 \"\" \$obj $attr\]\]"
                    } else {
                        set evalExpr "$evalExpr \[string match \{$value\} \[rtdc::getAttribute 1 \"\" \$obj $attr\]\]"
                    }
                } elseif {[regexp {@?(.*)!~(.*)} $expression match attr value]} {
                    if {$isRegexp} {
                        set evalExpr "$evalExpr !\[regexp \{$value\} \[rtdc::getAttribute 1 \"\" \$obj $attr\]\]"
                    } else {
                        set evalExpr "$evalExpr !\[string match \{$value\} \[rtdc::getAttribute 1 \"\" \$obj $attr\]\]"
                    }
                } else {
                    return -code error "Unknown operator in \'$expression\': $filterExpr"
                }
            } else {
    	        set evalExpr "$evalExpr [lindex $exprList $i]"
            }
        }

        set fList {}
        foreach obj [utils::flatList $objList] {
            set status [catch {eval expr $evalExpr} res]
	    if {$status} {
                return -code error "Invalid filter expression: $filterExpr"
            } elseif {$res} {
                lappend fList $obj
            }
        }
        return [utils::flatList $fList]
    }

    proc getObjListRef {argList} {

        set argList [utils::flatList $argList]
        set line ""
        if {[llength $argList] > 1} {
            set line "$line \[list "
        }
        foreach arg $argList {
            set objType [rt::typeOf $arg]
            switch -- $objType {
                "NRealModS" {
                    set currDesign [[rt::design] topModule]
                    if {$currDesign eq $arg} {
                        set line "$line \[current_design\]"
                    } else {
                        set line "$line \[get_designs \{[objectName $arg]\}\]"
                    }
                }
                "NInstS"   { set line "$line \[get_cells \{[objectName $arg]\}\]" }
                "NNetS"    { set line "$line \[get_nets \{[objectName $arg]\}\]" }
                "NPinS"    {
                    if {[$arg ownerInstance] eq "NULL"} {
                        set line "$line \[get_ports \{[objectName $arg]\}\]"
                    } else {
                        set line "$line \[get_pins \{[objectName $arg]\}\]"
                    }
                }
                "NCellS"   { set line "$line \[get_lib_cells \{[objectName $arg]\}\]" }
                "NPort"    {
                    set cellRef [$arg cell]
                    set line "$line \[get_lib_pins \{[objectName $cellRef]/[objectName $arg]\}\]"
                }
                "NLibS"    { set line "$line \[get_libs \{[objectName $arg]\}\]" }
                "TClock"   { set line "$line \[get_clocks \{[objectName $arg]\}\]" }
                default    { set line "$line $arg"}
            }
        }
        if {[llength $argList] > 1} {
            set line "$line \]"
        }
        return $line
    }

    proc getCurrMod {} {
        set des [rt::design] ;# to check for a design in memory
        if {$sdcrt::currMod eq "NULL"} {
            return -code error "No current module found"
        } else {
            return $sdcrt::currMod
        }
    }

    proc cmpName {a b} {
        set basename1 $a
        set basename2 $b

        regexp {([^\[\]]+)\[?} $a match basename1
        regexp {([^\[\]]+)\[?} $b match basename2

        set s1 [string compare $basename1 $basename2]
        if {$s1 != 0} {
            return $s1
        }

        set a_indexed 0
        set a_index1 0
        set a_index2 0
        if {[regexp {\[([0-9]+)\]\[([0-9]+\])$} $a m a_index1 a_index2]} {
            set a_indexed 2
        } elseif {[regexp {\[([0-9]+)\]$} $a m a_index1]} {
            set a_indexed 1
        } else {
            set a_indexed 0
        }

        set b_indexed 0
        set b_index1 0
        set b_index2 0
        if {[regexp {\[([0-9]+)\]\[([0-9]+\])$} $b m b_index1 b_index2]} {
            set b_indexed 2
        } elseif {[regexp {\[([0-9]+)\]$} $b m b_index1]} {
            set b_indexed 1
        } else {
            set b_indexed 0
        }

        if {$a_indexed != 0 && $b_indexed == 0} {
            return 1
        } elseif {$a_indexed == 0 && $b_indexed != 0} {
            return -1
        } elseif {$a_indexed == 2 && $b_indexed == 1} {
            return 1
	} elseif {$a_indexed == 1 && $b_indexed == 2} {
            return -1
        } elseif {$a_indexed == 1 && $b_indexed == 1} {
      	    if {$a_index1 > $b_index1} {
                return 1
	    } elseif {$a_index1 < $b_index1} {
                return -1
	    }
	} elseif {$a_indexed == 2 && $b_indexed == 2} {
	    if {$a_index1 > $b_index1} {
                return 1
      	    } elseif {$a_index1 < $b_index1} {
                return -1
	    } else {
	        if {$a_index2 > $b_index2} {
                    return 1
		} elseif {$a_index2 < $b_index2} {
                    return -1
      	        }
	    }
	}
        return 0
    }

    proc cmpObjByName {a b} {
        set a [sdcrt::objectName $a]
        set b [sdcrt::objectName $b]

        set hier1 0
        foreach c [split $a ""] {
            if {$c eq "/"} {
                incr hier1
            }
        }
        set hier2 0
        foreach c [split $b ""] {
            if {$c eq "/"} {
                incr hier2
            }
        }

        if {$hier1 < $hier2} {
            return -1
        } elseif {$hier1 > $hier2} {
            return 1
	}

        set hierPrefix1 ""
        set hierPrefix2 ""

        set baseName1 $a
        if {$hier1 > 0} {
            regexp {^(.*)/(.*)$} $a match hierPrefix1 baseName1
        }

        set baseName2 $b
        if {$hier2 > 0} {
            regexp {^(.*)/(.*)$} $b match hierPrefix2 baseName2
        }

        set s1 [sdcrt::cmpName $hierPrefix1 $hierPrefix2]
        if {$s1 != 0} {
            return $s1
        }

        set s1 [sdcrt::cmpName $baseName1 $baseName2]
        return $s1
    }

    proc uniqList {args} {
        set flist [utils::flatList $args]
        set retList {}
        foreach item $flist {
            if {![info exists hash($item)]} {
               lappend retList $item
               set hash($item) 1
            }
        }
        return $retList
    }

    proc printList {pins} {
	foreach pin $pins {
	    switch -- [rt::typeOf $pin] {
		"NInstS" -
		"NNetS" -
		"NPinS" -
		"TClock" {
		    puts -nonewline " [$pin name] "
		}
		default {
		    puts -nonewline " $pin " 
		}
	    }
	}
    }

    proc formatTime {milliseconds} {
        set seconds [expr $milliseconds / 1000.0]
        set intSeconds [expr int($seconds)]
        set diff [expr $seconds - $intSeconds]

        set secs [expr $intSeconds % 60]
        set h [expr $intSeconds / 60]
        set mins [format {%02d} [expr $h % 60]]
        set hrs [expr $h / 60]

        set secs [format {%05.2f} [expr $secs + $diff]]

        set rsl ""
        if {$hrs > 0} {
            set rsl "${hrs}:${mins}:"
        } elseif {$mins > 0} {
            set rsl "${mins}:"
        }
        set rsl "${rsl}${secs}"
        
        return $rsl
    }

    proc reportStats {} {
        if {![info exists ::env(RT_PROFILE_READ_SDC)]} {
            return
        }

        global sdcrt::command_count_array
        global sdcrt::command_stats_array

        puts "------------------------------------------------------------------------------------------"
        set stat [format {%-30s  %-7s  %15s  %15s  %15s} "Command" "Count" "Total runtime" "Avg runtime" "Max runtime"]
        puts $stat
        set stat [format {%-30s  %-7s  %15s  %15s  %15s} "" "" "(hh:mm:ss)" "(hh:mm:ss)" "(hh:mm:ss)"]
        puts $stat
        puts "------------------------------------------------------------------------------------------"
        set total 0
        set cmdCount 0
	foreach cmd [lsort [array names command_count_array]] {
            set max   $command_stats_array($cmd,max)
            set rtime $command_stats_array($cmd,runtime)

            incr total $rtime

            set count $command_count_array($cmd)
            incr cmdCount $count

            set avg  [expr $rtime / $count]

            set stat [format {%-30s  %-7d  %15s  %15s  %15s} $cmd $count [sdcrt::formatTime $rtime] [sdcrt::formatTime $avg] [sdcrt::formatTime $max]]
            puts $stat
     
            if {[regexp {^get_} $cmd]} {
                puts "  (objs: $command_stats_array($cmd,objs), max: $command_stats_array($cmd,maxobjs))"
            }
        }
        puts "------------------------------------------------------------------------------------------"
        set stat [format {%-30s  %-7d  %15s} "Total" $cmdCount [sdcrt::formatTime $total]]
        puts $stat
        puts "------------------------------------------------------------------------------------------"

        array unset command_count
        array unset command_runtime
    }

    proc printConstraintWarning { pat objclass command } {
        global sdcrt::cachedfname
        global sdcrt::cachedlnum
        global sdcrt::not_found_objects
        if { ! ( $cachedfname eq "") } {
            # msg "WARNING: no $objclass found for $pat referenced in $cachedfname, line $cachedlnum."
            # do nothing, warning handled in 'wrapping' constraint proc
        } else {
            set not_found_objects($pat) 1
        }
    }

} ; # end namespace eval sdcrt

proc sdcrt::profile_and_callback {cmd args} {
    upvar $args parsing_args

    if {![info exists ::env(RT_PROFILE_READ_SDC)]} {
        return [sdcrt::callback $cmd parsing_args]
    }

    global sdcrt::command_count_array
    global sdcrt::command_stats_array

    set start_t [clock clicks -milliseconds]

    set rsl [sdcrt::callback $cmd parsing_args]

    set end_t [clock clicks -milliseconds]

    # separate out the ones with -hier/-filter option
    set getCommand 0
    if {[regexp {^get_} $cmd]} {
        if {[info exists parsing_args(-hierarchical)]} {
            set cmd "$cmd -hier"
        }
        if {[info exists parsing_args(-filter)]} {
            set cmd "$cmd -filter"
        }
        set getCommand 1
    } 

    set rtime [expr $end_t - $start_t]
    UMsg_print "> -I- $rtime ms execution time\n"

    if {[info exists command_count_array($cmd)]} {
        incr command_count_array($cmd)

        incr command_stats_array($cmd,runtime) $rtime

        if {$command_stats_array($cmd,max) < $rtime} {
            set command_stats_array($cmd,max) $rtime
        }

        if {$getCommand} {
            set objs [llength $rsl]
            incr command_stats_array($cmd,objs) $objs

            if {$command_stats_array($cmd,maxobjs) < $objs} {
                set command_stats_array($cmd,maxobjs) $objs
            }
        }
    } else {
        set command_count_array($cmd) 1

        set command_stats_array($cmd,runtime) $rtime

        set command_stats_array($cmd,max) $rtime

        if {$getCommand} {
            set objs [llength $rsl]
            set command_stats_array($cmd,objs) $objs
            set command_stats_array($cmd,maxobjs) $objs
        }
    }

    return $rsl
}

proc sdcrt::callback {command parsing_args} {
    global rt::UNM_none
    global rt::UNM_sdc
    global sdcrt::ignored_commands
    global sdcrt::unsupported_commands
    upvar $parsing_args opt

#     puts -nonewline "Command: $command"
#     foreach arg [array names opt] {
# 	puts -nonewline " $arg='$opt($arg)'"
#     }
#     puts ""
    
    switch -- $command {
	all_clocks {
	    ################################################################
	    return [findClocksInCurrentMode *]
	}
        all_connected {
	    ################################################################
	    supported opt {-leaf object} $command

            set obj $opt(object)
            set leaf [info exists opt(-leaf)]

            if {[rt::typeOf $obj] eq "NULL"} {
                set objName $obj
                set obj [[sdcrt::getCurrMod] findPins $objName $rt::UNM_sdc 0 0 {} 0 0 ""]
		if {$obj eq "NULL" || $obj eq {}} {
                    set obj [[sdcrt::getCurrMod] findNets $objName $rt::UNM_sdc 0 0 ""]
                    if {$obj eq "NULL" || $obj eq {}} {
                        return -code error "object \'$objName\' not found"
                    }
                }          
            }

            switch -- [rt::typeOf $obj] {
                "NPinS" {
                    return [$obj net]
                }
                "NNetS" {
                    set const [$obj constant]
                    if {$const != -1} {
                        # db limitation, cannot get connected pins
                        return ""
                    }
                    set iPins {}
                    set pin [$obj firstPin]
		    while {$pin != "NULL"} {
			acquire $pin
			lappend iPins $pin
			set pin [$pin nextPinOnNet]
		    }
                    set pins {}
                    array unset pinAdded
                    foreach pin $iPins {
		        if {$leaf} {
			    foreach aPin [flatPins $pin] {
                                if {![info exist pinAdded($aPin)]} {
                                    set pinAdded($aPin) 1
                                    lappend pins $aPin
                                }
                            }
		        } else {
                            if {![info exist pinAdded($pin)]} {
                                set pinAdded($pin) 1
                                lappend pins $pin
                            }
                        }
                    }
                    return [utils::flatList $pins]
                }
                default {
                    warning "incorrect object type in $command"
                    release $obj
                    return
                }
            }
        }
        all_designs {
            set mods {}
            array unset addedMod

            set matches [[sdcrt::getCurrMod] findModules "*"]

	    if {$matches ne "NULL" && [$matches size] > 0} {
                for {set i [$matches begin]} {[$i ok]} {$i incr} {
                    set mod [$i object]
                    if {![info exists addedMod($mod)]} {
                        lappend mods $mod
                        set addedMod($mod) 1
                    }
                }
                rt::delete_NRealModList $matches
            }
            return $mods
        }
        all_fanin {
	    ################################################################
	    supported opt {toList -to -startpoints_only -only_cells -flat -levels -clock -port_only} $command
	    #toList and objects in -to are the same thing, we can only have one of them
		set des [rt::design]
	    #set mod [$des topModule]
		set mod [sdcrt::getCurrMod]
		# uniquify before search
            $mod uniquify 0

            set startPointsOnly [info exists opt(-startpoints_only)]
            set cellsOnly [info exists opt(-only_cells)]
            set flat [info exists opt(-flat)]
            set levels -1
	    set clock NULL
	    if [info exists opt(-clock)] {
		set clock $opt(-clock)
	    }
	    set portOnly [info exists opt(-port_only)]
            if {[info exists opt(-levels)]} {
                set levels $opt(-levels)
            }

            set fiList {}
            set toPins {}
	    if {[info exists opt(-to)] || [info exists opt(toList)]} {
			if {[info exists opt(toList)]} {
				set opt(-to) $opt(toList)
			}
		foreach obj $opt(-to) {
		    if {[rt::typeOf $obj] eq "NULL"} {
			# full name for pin/port/net
                        set matches [[sdcrt::getCurrMod] findPins $obj $rt::UNM_sdc 0 0 {} 0 0 ""]
			if {$matches eq "NULL" || $matches eq {}} {
                            set matches [[sdcrt::getCurrMod] findNets $obj $rt::UNM_sdc 0 0 ""]
			}

			if {$matches eq "NULL" || $matches eq {}} {
			    return -code error "error: \'$obj\' not found"
			} else {
			    set obj [lindex $matches 0]
			}
		    }

		    switch -- [rt::typeOf $obj] {
			"NNetS" {
			    set iPin [$obj firstPin]
			    while {$iPin != "NULL"} {
				if {[rtdc::getAttribute 1 "" $iPin direction] eq "input"} {
				    set iPin [$iPin nextPinOnNet]
				    continue
				}
				acquire $iPin
				lappend toPins $iPin
				set iPin [$iPin nextPinOnNet]
			    }
			    release $obj
			}
			"NPinS" {
			    lappend toPins $obj
			}
			default {
			    warning "object of unknown type in $command"
			}
		    }
		}
	    }
            if {[llength $toPins] > 0} {
                if {$cellsOnly} {
                    lappend fiList [$mod findFaninInstances $toPins $startPointsOnly $flat $levels]
                } else {
                    lappend fiList [$mod findFaninPins $toPins $startPointsOnly $flat $levels]
                }
            } else { # this is a call when the -clock is used #
		lappend fiList [$mod findClockFaninPins $clock $startPointsOnly $flat $levels $portOnly]
	    }

            return [utils::flatList $fiList]
        }
        all_fanout {
	    ################################################################
	    supported opt {-clock_tree -from -endpoints_only -only_cells -flat -levels} $command
	    set des [rt::design]
	    #set mod [$des topModule]
		set mod [sdcrt::getCurrMod]
            # uniquify before search
            $mod uniquify 0
        
            set endPointsOnly [info exists opt(-endpoints_only)]
            set cellsOnly [info exists opt(-only_cells)]
            set flat [info exists opt(-flat)]
            set levels -1
            if {[info exists opt(-levels)]} {
                set levels $opt(-levels)
            }

            set foList {}
            set fromPins {}
            if {[info exists opt(-clock_tree)]} {
                set all_clocks [findClocksInCurrentMode *]
                foreach iclock $all_clocks {
		    set srcPin [rtdc::getAttribute 1 "" $iclock sources]
		    if {$srcPin != {}} {
			lappend fromPins $srcPin
		    }
                }
            } else {
                foreach obj $opt(-from) {
                    if {[rt::typeOf $obj] eq "NULL"} {
                        # full name for pin/port/net
                        set matches [[sdcrt::getCurrMod] findPins $obj $rt::UNM_sdc 0 0 {} 0 0 ""]
			if {$matches eq "NULL" || $matches eq {}} {
                            set matches [[sdcrt::getCurrMod] findNets $obj $rt::UNM_sdc 0 0 ""]
                        }

			if {$matches eq "NULL" || $matches eq {}} {
			    return -code error "error: \'$obj\' not found"
                        } else {
			    set obj [lindex $matches 0]
                        }
                    }

                    switch -- [rt::typeOf $obj] {
                        "NNetS" {
                            set iPin [$obj firstPin]
		   	    while {$iPin != "NULL"} {
                                if {[rtdc::getAttribute 1 "" $iPin direction] eq "output"} {
                                    set iPin [$iPin nextPinOnNet]
                                    continue
                                }
				acquire $iPin
                                lappend fromPins $iPin
	   		        set iPin [$iPin nextPinOnNet]
			    }
			    release $obj
                        }
                        "NPinS" {
                            lappend fromPins $obj
                        }
                        default {
                            warning "object of unknown type in $command"
                        }
                    }
                }
            }
         
            if {[llength $fromPins] > 0} {
                if {$cellsOnly} {
                    lappend foList [$mod findFanoutInstances $fromPins $endPointsOnly $flat $levels]
                } else {
                    lappend foList [$mod findFanoutPins $fromPins $endPointsOnly $flat $levels]
                }
            }

            return [utils::flatList $foList]
        }
	all_inputs {
	    ################################################################
	    supported opt {} $command
	    set des [rt::design]
	    #set mod [$des topModule]
		set mod [sdcrt::getCurrMod]
	    set list {}
	    for {set pi [[$mod loadPins] begin]} {[$pi count]} {$pi incr} {
		set pin [$mod pin $pi]
		# should we filter out clock pins???
# 		if {[$pin onClockNet 0] == 0} {
		    lappend list $pin
# 		}
	    }
	    return $list
	}
	all_outputs {
	    ################################################################
	    set des [rt::design]
	    #set mod [$des topModule]
		set mod [sdcrt::getCurrMod]
	    set list {}
	    for {set pi [[$mod driverPins] begin]} {[$pi count]} {$pi incr} {
		lappend list [$mod pin $pi]
	    }
	    return $list
	}
        all_registers {
	    ################################################################
	    supported opt {-no_hierarchy -clock -edge_triggered -level_sensitive -cells -data_pins -clock_pins} $command
	    set des [rt::design]
	    set mod [$des topModule]
		# use current module as starting point, to support scoped XDC
		if {[sdcrt::getCurrMod] ne "NULL"} {
			set mod [sdcrt::getCurrMod]
		}
		
            set clockName ""
            if {[info exists opt(-clock)]} {
                set clockName $opt(-clock)
            }
            set hier 1
            if {[info exists opt(-no_hierarchy)]} {
                set hier 0
            }
            set edgeTrig [info exists opt(-edge_triggered)]
            set levelSens [info exists opt(-level_sensitive)]
            set dataPins [info exists opt(-data_pins)]
            set clockPins [info exists opt(-clock_pins)]

            set allList {}
            if {![info exists opt(-cells)]} {
                if {[info exists opt(-data_pins)] || [info exists opt(-clock_pins)]} {
                    set allList [$mod findRegisterPins $clockName $hier $edgeTrig $levelSens $dataPins $clockPins]
                } else {
                    set allList [$mod findRegisters $clockName $hier $edgeTrig $levelSens]
                }
            } elseif {[info exists opt(-data_pins)] || [info exists opt(-clock_pins)]} {
                set allList [$mod findRegisters $clockName $hier $edgeTrig $levelSens]
                lappend allList [$mod findRegisterPins $clockName $hier $edgeTrig $levelSens $dataPins $clockPins]
            } else {
                set allList [$mod findRegisters $clockName $hier $edgeTrig $levelSens]
            }

            return [utils::flatList $allList]
        }
        all_dsps  {
            return [rt::get_cells -hier -filter {ref_name == "DSP48E1"}]
        }
        all_rams  {
            return [rt::get_cells -hier -filter {ref_name =~ "*RAM*"}]
        }

        get_sblock {
	    ################################################################
	    supported opt {name} $command
            if [info exist opt(name)] {
              set nm $opt(name)
            } else {
              error "$command missing name option"
              return "NULL"
            }
            set foundSBlock [$rt::db findSBlock $nm]
            if {$foundSBlock == "NULL" || [rt::typeOf $foundSBlock] != "SBlock" } {
              error "$command could not find sblock"
              return "NULL"
            }
            return $foundSBlock
        }

        create_sblock {
	    ################################################################
            global ::rt::presdc::timing_is_disabled
            if { ! $timing_is_disabled } {
              # timing is not disabled, so create_sblock is disabled
              return
            }
	    supported opt {-name cell_list} $command
            if [info exist opt(-name)] {
              set nm $opt(-name)
            } else {
              error "$command missing -name option"
              return
            }
            if [info exist opt(cell_list)] {
              set cells $opt(cell_list)
            } else {
              error "$command missing instance list"
              return
            }
            if {[llength $cells] == 0} {
              error "$command missing instance list"
              return
            }
            $rt::db createSBlock $nm
            set newSBlock [$rt::db findSBlock $nm]
            if {$newSBlock == "NULL" || [rt::typeOf $newSBlock] != "SBlock" } {
              error "$command could not create sblock"
              return
            }
            foreach cell [utils::flatList $cells] {
                switch -- [rt::typeOf $cell] {
                    "NInstS" {
                      $newSBlock addInst $cell
                    }
		    default {
                      error "$command expects cell object, but different object found"
                      return
		    }
		}
            }
        }

	create_clock {
	    ################################################################
	    supported opt {-add -name -period -waveform port_pin_list} $command
	    set add [info exist opt(-add)]
	    set per [time $opt(-period)]
	    set genomesToo 0
	    set pushToDrivers 2
	    set pushToInputsToo [rt::getParam pushClocksToInputsToo]
	    set alwaysPushToInputs [rt::getParam alwaysPushToInputs]
	    if {$alwaysPushToInputs} {
		set pushToDrivers 0
	    } elseif {$pushToInputsToo == "true"} {
		set pushToDrivers 1
	    }
	    set otherLoads "false"

	    if [info exist opt(-name)] {
		set nm $opt(-name)
	    } else {
		set nm [[lindex $opt(port_pin_list) 0] fullName $rt::UNM_none]
	    }

            global sdcrt::cachedfname
            global sdcrt::cachedlnum

            # global ::rt::presdc::timing_is_disabled
            # global sdcrt::onetime
            # if { ! $timing_is_disabled && $onetime } {
            # }

	    if [info exist opt(port_pin_list)] {
		set pinList [pinList $opt(port_pin_list) {} $genomesToo $pushToDrivers otherLoads]
		if { $pinList == "" } {
		    if {[rt::UParam_get createClockErrorsOnUnknownPort rc] == "true"} {
			return -code error "error: $command attempting to set clock on an unknown port/pin"
                    } else {
			crit-warn "$command attempting to set clock on an unknown port/pin"
			return
		    }
		}
	    } else {
		set pinList {}
	    }
	    if {($otherLoads == "true") && ($pushToDrivers == 2)} {
		return -code error "error: $command pushing hierarchical assertion to driver but driver drives other loads"
	    }

	    if [info exist opt(-waveform)] {
		set rise [time [lindex $opt(-waveform) 0]]
		set fall [time [lindex $opt(-waveform) 1]]
	    } else {
		set rise 0
		set fall [expr $per / 2]
	    }
	    set des [rt::design]
            rt::UParam_set SdcFileName $cachedfname true
            rt::UParam_set SdcLineNum  $cachedlnum true
	    set clk [$des defineClock $nm $per $rise $fall]
	    if {[llength $pinList] < 2} {
		foreach pin $pinList {
		  $pin setClock $add $clk "userImpl"
		  release $pin
		}
	    } else {
                # process the first pin, other pin pointers may become 
                # invalid due to Genome, so cached pin names first, 
                # then process.
		set pinNameList {}
		foreach pin $pinList {
                  set pinName [$pin fullName $rt::UNM_none true] 
		  lappend pinNameList $pinName
		} 
		foreach pinName $pinNameList {
		  set pin [[$des topModule] findPin $pinName $rt::UNM_none false] 
		  $pin setClock $add $clk "userImpl"
		  release $pin
		} 
           }  
	  $clk -delete
	}
	create_generated_clock {
	    ################################################################
	    supported opt {-name -source -edges -divide_by -multiply_by
		-edge_shift -duty_cycle -invert -add -master_clock
		-combinational port_pin_list} $command
		if {[info exist opt(-name)] && ![info exist opt(-source)] && ![info exist opt(-master_clock)] && [info exist opt(port_pin_list)]} {
			# this is to support create_generated_clock commands that only modify existing generated clock names
			set cmd "rt::get_clocks -include_generated_clocks -of_object $opt(port_pin_list)"
			set existClks [eval $cmd]
			if {$existClks == "" || $existClks == "NULL"} {
			warning "create_generated_clock tries to rename an existing generated clock, but couldn't find the specified generated clock"
			return
			}
			foreach eClk $existClks {
				set origName [$eClk name]
				$eClk setName $opt(-name)
				#warning "create_generated_clock cmd only tries to rename an existing generated clock from $origName to $opt(-name)"
			}
			return
		}
	    set genomesToo 0
	    set pushToDrivers 1
	    set alwaysPushToInputs [rt::getParam alwaysPushToInputs]
	    if {$alwaysPushToInputs} {
		set pushToDrivers 0
	    }
	    set otherLoads "false"
	    if [info exist opt(port_pin_list)] {
		set pinList [pinList $opt(port_pin_list) {} $genomesToo $pushToDrivers otherLoads]
		if { $pinList == ""} {
		    if {[rt::UParam_get createClockErrorsOnUnknownPort rc] == "true"} {
			return -code error "error: $command attempting to set clock on an unknown port/pin"
		    } else {
                        global sdcrt::cachedlnum  
                        if { !( $cachedlnum eq "" ) }  { 
			  crit-warn "$command attempting to set clock on an unknown port/pin"
                        }  
			return
		    }
		}
	    } else {
		set pinList {}
	    }
	    if {$otherLoads == "true"} {
	       msg "info: $command attempted to push hier assertion to driver but driver drives other loads"
	    }
	    set des [rt::design]
		if {$opt(-source) == "NULL" || $opt(-source) == ""} {
			warning "$command : Empty source list"
			release $pinList
			return
	    }
	    set srcPin $opt(-source)
	    if {[rt::typeOf $srcPin] != "NPinS"} {
		set srcPin [[$des topModule] findPin $srcPin $rt::UNM_sdc]
	    }
	    if {$srcPin == "NULL"} {
		msg "error: Could not find source pin '$opt(-source)'"
		release $pinList
		return
	    }
	    if {[$srcPin isHierPin]} {
		set srcPinNm [$srcPin fullName $rt::UNM_none true]
		#msg "info: Source pin '$srcPinNm' of generated clock is hierarchical"
		# Need to make sure the whole design is now uniquified
		# otherwise the NPin::floatLoadPins API will not work
		set srcDes [$srcPin design]
		$srcDes uniquify false true
		# refind the pin to make sure we get the right one incase of multiple instances
		set srcPin [[$des topModule] findPin $srcPinNm $rt::UNM_none true]
		$srcDes release
		set srcLoadPin [lindex [$srcPin flatLoadPins] 0]

		set prevGenomePin "NULL" 
		# If there are no load pins move it to the driver pin.
		if {$srcLoadPin == "NULL" || $srcLoadPin == ""} {
		    set srcLoadPin [lindex [$srcPin flatDrivePins] 0]
		    while {$srcLoadPin ne "NULL" && $srcLoadPin != ""} { 
			set inst2 [$srcLoadPin ownerInstance] 
			if {$inst2 != "NULL"}  {
			   set gen [$inst2 isGenome] 
			   if {$gen == "NULL"} {
				break; 
			   }  
			}  
 
			set inst2 [[$srcLoadPin design] genomeInstance]	
			if {$inst2 == "NULL"} {
			   break;
			}			

			set tPin [$inst2 pin [$srcLoadPin index]]	 	
			if {$tPin == "NULL"} {
			   break
			}
			set srcLoadPin $tPin              
			set tPin [lindex [$srcLoadPin flatDrivePins] 0]
			if {$tPin == "NULL"} {
			   break
			}
			set srcLoadPin $tPin              
			set inst2 [$srcLoadPin ownerInstance]
			if {$inst2 == "NULL"} {
			  break
 			}
			set gen [$inst2 isGenome]
			if {$gen == "NULL"} {
			  break
 			}
			set tPin [otherSide $srcLoadPin true]
			if {$tPin == "NULL"} {
			  break
			}
			if {$prevGenomePin ne "NULL"} {
			  release $prevGenomePin
		          set prevGenomePin $srcLoadPin		
			}  

			set srcLoadPin $tPin              
			set tPin  [lindex [$srcLoadPin flatDrivePins] 0]
			if {$tPin == "NULL"} {
			  break;
			}
			set srcLoadPin $tPin              
		   }
		}
		if {$srcLoadPin == "NULL" || $srcLoadPin == ""} {
		    warning "Hierarchical source pin '$srcPinNm' does not fanout to anything"
		    release $pinList $srcPin
		    return
		}
		global sdcrt::hier_pins
		set hier_pins($srcPinNm) [$srcLoadPin fullName $rt::UNM_none false]
                rt::UMsg_tclMessageTrace CMD 125 [$srcPin fullName $rt::UNM_none false] [$srcLoadPin fullName $rt::UNM_none false]
                rt::UParam_set writeParallelTimingXdc true
		set srcPin $srcLoadPin
	    }
	    set add [info exist opt(-add)]
	    if [info exist opt(-name)] {
		set nm $opt(-name)
	    } else {
		set nm [[lindex $pinList 0] fullName $rt::UNM_none]
	    }
	    if [info exist opt(-edges)] {
		set doneEdges "edges"
		set e1 [lindex $opt(-edges) 0]
		set e2 [lindex $opt(-edges) 1]
		set e3 [lindex $opt(-edges) 2]
	    }
	    if [info exist opt(-duty_cycle)] {
		if [info exist doneEdges] {
		    msg "error: Cannot specify -duty_cycle together with -edges"
		    release $pinList $srcPin
		    return
		}
		set dc $opt(-duty_cycle)
	    } else {
		set dc 0.5
	    }
	    set factor 0
	    if {[info exist opt(-divide_by)] && ![info exist opt(-multiply_by)]} {
		if [info exist doneEdges] {
		    msg "error: Specify only one of -$doneEdges and -divide_by"
		    release $pinList $srcPin
		    return
		}
		set factor [expr 0 - $opt(-divide_by)]
		set doneEdges "divide_by"
		set e1 1
		set e2 [expr 1.0 + 2.0 * $opt(-divide_by) * $dc]
		set e3 [expr 1.0 + 2.0 * $opt(-divide_by)]
	    }
	    if {[info exist opt(-multiply_by)] && ![info exist opt(-divide_by)]} {
		if [info exist doneEdges] {
		    msg "error: Specify only one of -$doneEdges and -multiply_by"
		    release $pinList $srcPin
		    return
		}
		set factor $opt(-multiply_by)
		set doneEdges "multiply_by"
		set e1 1
		set e2 [expr 1.0 + 2.0 / $opt(-multiply_by) * $dc]
		set e3 [expr 1.0 + 2.0 / $opt(-multiply_by)]
	    }
		if {[info exist opt(-multiply_by)] && [info exist opt(-divide_by)]} {
			# handle the situation where both multiply and divide exist
			if [info exist doneEdges] {
				msg "error: Specify only one of -$doneEdges and -div_mult"
				release $pinList $srcPin
				return
			}
			set doneEdges "div_mult"
			set divVal $opt(-divide_by)
			set mulVal $opt(-multiply_by)
			if {$divVal == 0} {
				puts "WARNING: create_generated_clock has pin with 0 as a clock dividing factor.  Ignoring clock.\n"
				continue
			}
			if {$mulVal == 0} {
				puts "WARNING: create_generated_clock has pin with 0 as a clock mulitiplying factor.  Ignoring clock.\n"
				continue
			}
			# should figure out if integer multiple... then produce correct 
			set factor [expr 1.0*$mulVal/$divVal]
			if {$factor >= 1} {
				# Try to see if factor equals a whole number... then do regular create_generated_clock
				if {$factor == [expr int($factor)]} {
					set mulVal $factor
					set divVal 1
				}
			} else {
				# Try to see if factor equals a 1/whole number... then do regular create_generated_clock
				set recip [expr 1.0/$factor]
				if {$recip == [expr int($recip)]} {
					set mulVal 1
					set divVal $recip
				}
			}
			if {$mulVal == 1 || $divVal == 1} {
				if {$divVal == 1} {
					set mulVal [expr int($mulVal)]
					set e1 1
					set e2 [expr 1.0 + 2.0 / $mulVal * $dc]
					set e3 [expr 1.0 + 2.0 / $mulVal]
				} elseif {$mulVal == 1} {
					set divVal [expr int($divVal)]
					set e1 1
					set e2 [expr 1.0 + 2.0 * $divVal * $dc]
					set e3 [expr 1.0 + 2.0 * $divVal]
				} else {
					# null command!!! Should not get here...
				}
			} else {
				if {0} {
					# using closest integer...
					# Can't currently handle non-integer multiples...
					if { $factor >= 1 } {
						# round...
						set factor [expr int($factor+0.5)]
						set cmd "rt::create_generated_clock -name [$outNet name]  -multiply_by $factor -source $clkIn1Pin $outPin"
					} else {
						set factor [expr int(1/$factor+0.5)]
						set cmd "rt::create_generated_clock -name [$outNet name]  -source $clkIn1Pin -divide_by $factor $outPin"
					}
				} else {
					# using internal API for any non-integer factor...
					set e1 1
					set e3 [expr 2*(1/$factor)+1]
					set e2 [expr ($e3 - 1)*0.5 + 1]
					# factor is not used except for printing...   ? 
					if {$factor >= 1} {
						set factor 1
					} else {
						set factor -1
					}
				}
			}
	    }
	    if [info exist opt(-combinational)] {
		if {[info exist doneEdges] && (($e1 != 1) || ($e2 != 2) || ($e3 != 3))} {
		    msg "error: Specify only one of -$doneEdges and -combinational"
		    release $pinList $srcPin
		    return
		}
		set doneEdges "combinational"
		set e1 1
		set e2 2
		set e3 3
	    }
	    if {[info exist doneEdges] == 0}  {
		msg "error: Need to specify one of -edges, -combinational, -divide_by or -multiply_by"
		release $pinList $srcPin
		return
	    }
           #Aman. Sep 17, 2013. edge shift is added to clock after creation (below)
	    #if [info exist opt(-edge_shift)] {
		#set e1 [expr $e1 + [lindex $opt(-edge_shift) 0]]
		#set e2 [expr $e2 + [lindex $opt(-edge_shift) 1]]
		#set e3 [expr $e3 + [lindex $opt(-edge_shift) 2]]
	    #}
	    if [info exist opt(-invert)] {
		set e4 [expr $e3 + ($e2 - $e1)]
		set e1 $e2
		set e2 $e3
		set e3 $e4
	    }
	    if [info exist opt(-master_clock)] {
		set master [getClockInCurrentMode $opt(-master_clock)]
	    } else {
		set master "NULL"
	    }
	    set clk [$des generatedClock $nm $srcPin "userImpl" $e1 $e2 $e3 $factor $master]
	    if [info exist opt(-edge_shift)] {
		set se0 [lindex $opt(-edge_shift) 0]
		set se1 [lindex $opt(-edge_shift) 1]
		set se2 [lindex $opt(-edge_shift) 2]
		$clk setEdgeShift $se0 $se1 $se2
	    }
	    release $srcPin
	    foreach pin $pinList {
		$pin setClock $add $clk "userImpl"
		release $pin
	    }
	    if [$des genClockOwnMaster $nm] {
	    $clk -delete
		return -code error "$nm is its own master"
	}
	    $clk -delete
	}
	current_design {
	    ################################################################
            if {![info exists opt(design)] || $opt(design) eq "."} {
                return [sdcrt::getCurrMod]
            } else {
                if {[rt::typeOf $opt(design)] eq "NRealModS"} {
                    set sdcrt::currMod $opt(design)
                    return
                }

	        set des [rt::design]
		set mod "NULL"
                set modRefs [$des getModules $opt(design) 1 0] ;# match exact name
                if {$modRefs ne "NULL" && [$modRefs size] > 0} {
                    if {[$modRefs size] > 1} {
                        warning "Multiple designs found for \'$opt(design)\'. Please specify a unique design."
                        rt::delete_NRealModList $modRefs
                        return
                    }
                    set mod [[$modRefs begin] object]
                    rt::delete_NRealModList $modRefs
                }

		if {$mod eq "NULL"} {
                    warning "Design \'$opt(design)\' not found"
                    return
		} else {
                    set sdcrt::currMod $mod
		}
            }
	}
		
   current_instance {
	    ################################################################
	   # this command can change the current instance that we are working on
	   # can be useful in applying scoped xdc
	   # e.g. use current_instance instance_A/instance_B to set
	   # always use current_instance [empty] to reset it to the top module
	   set topMod [[rt::design] topModule]
	   
	   if {![info exists opt(instance)]} {
		   set sdcrt::currMod $topMod
		   set sdcrt::currInst [list]
                return ""
	   } elseif {$opt(instance) eq "."} {
		   if {[llength $sdcrt::currInst] > 0} {
                          rt::UParam_set writeParallelTimingXdc true
			   return [join $sdcrt::currInst "/"]
		   } else {
			   return ""
		   }
	   } else {
		   global rt::UNM_sdc
				
		   if {[string index $opt(instance) 0] eq "/"} {
			   if {[regexp {^/([^/]+)/} $opt(instance) match topModName] && $topModName eq [$topMod name]} {
				   regsub  "/$topModName/" $opt(instance) "" opt(instance)
				   set normalizedNameList [list]
			   } else {
				   crit-warn "No instance found in \'current_instance $opt(instance)\'"
				   return ""
			   }
		   } else {
			   set normalizedNameList $sdcrt::currInst
		   }
		   
		   set nameList [split $opt(instance) "/"]
		   for {set i 0} {$i < [llength $nameList]} {incr i} {
			   set elem [lindex $nameList $i]
                    if {$elem eq "."} {
                        continue
					} elseif {$elem eq ".."} {
						set normalizedNameList [lreplace $normalizedNameList end end]
					} else {
                        lappend normalizedNameList $elem
					}
		   }
		   
		   if {[llength $normalizedNameList] == 0} {
			   set sdcrt::currMod $topMod
			   set sdcrt::currInst [list]
			   return ""
		   }
		   
		   set instName [join $normalizedNameList "/"]
		   set inst [$topMod findInstance $instName $rt::UNM_sdc]
		   
		   set instMod "NULL"
		   if {$inst ne "NULL"} {
               set instMod [$inst isRealModule]
               if {$instMod ne "NULL"} {
                 $inst uniquify
               }
			   set instGen [$inst isGenome]
			   if {$instGen ne "NULL"} {
				   set des [$instGen acquireDesignForInstance $inst]
				   set instMod [$des topModule]
			   } else {
				   set instMod [$inst isRealModule]
			   }
		   }
		   
		   if {$instMod ne "NULL"} {
			   set des [$sdcrt::currMod design]
			   if {[$des genomeInstance] ne "NULL"} {
				   $des release
			   }
			   set sdcrt::currMod $instMod
			   set sdcrt::currInst $normalizedNameList

			   if {[llength $sdcrt::currInst] > 0} {
                                  rt::UParam_set writeParallelTimingXdc true
				   return [join $sdcrt::currInst "/"]
			   } else {
				   return ""
			   }
		   } else {
			  crit-warn "No instance found in \'current_instance $opt(instance)\'"
			  return ""
		   }
	   }
   }

	get_cell   -
	get_cells  {
	    ################################################################
	    supported opt {patterns -hierarchical -quiet -of_objects -filter -regexp -nocase} $command
	    global sdcrt::not_found_objects
 	    set hier [info exist opt(-hierarchical)]
	    set des  [rt::design]
	    set cells {}

            array unset addedInst
            if {[info exist opt(-of_objects)]} {
                foreach obj $opt(-of_objects) {
                    switch -- [rt::typeOf $obj] {
                        "NNetS" {
                            if {[$obj constant] != -1} {
                                continue
                            } else {
                                set pinRef [$obj firstPin]
                                while {$pinRef ne "NULL"} {
                                    set instRef [$pinRef ownerInstance]
									
                                    if {$instRef ne "NULL" && ![info exist addedInst($instRef)]} {
                                        lappend cells $instRef
                                        set addedInst($instRef) 1
                                    }
									
                                    set pinRef [$pinRef nextPinOnNet]
                                }
                            }
                        }
                        "NPinS" {
                            set instRef [$obj ownerInstance]
                            if {$instRef ne "NULL" && ![info exist addedInst($instRef)]} {
                                lappend cells $instRef
                                set addedInst($instRef) 1
                            }
                        }
                        "NRealModS" {
							set des [$obj design]
							set gen [$des genome]
							if {$gen ne "NULL" && [$des topModule] == $obj} {
								lappend cells [$gen instances]
							} else {
								for {set pi [$obj parents]} {[$pi ok]} {$pi incr} {
									set inst [$pi object]
									lappend cells $inst
								}
							}
                        }
						default {
							return -code error "object of unknown type"
						}
                    }
                }
                if {[info exists opt(-filter)] && [llength $cells] > 0} {
                    set isRegexp [info exists opt(-regexp)]
                    set cells [[sdcrt::getCurrMod] filterInstanceCollection [utils::flatList $cells] $isRegexp $opt(-filter)] 
                }
            } else {
                set ignoreCase [expr [info exists opt(-nocase)] && [info exists opt(-regexp)]]
				if {![info exist opt(patterns)]} {
					set opt(patterns) "*"
				}
				foreach pat $opt(patterns) {
					if {[rt::typeOf $pat] == "NInstS"} {
						lappend cells $pat
					} else {
                        set isRegexp [info exists opt(-regexp)]
                        set filterExpr ""
                        if {[info exists opt(-filter)]} {
                            set filterExpr $opt(-filter)
                        }
                        if {$ignoreCase} {
                            set origPat $pat
                            if {$filterExpr eq ""} {
                                set filterExpr "full_name =~ $pat"
                            } else {
                                set filterExpr "full_name =~ $pat && ($filterExpr)"
                            }
                            # ignore -hier and match all inst full names against the pattern
                            set hier 1
                            set pat "*"
                        }
						set matches [[sdcrt::getCurrMod] findInstances $pat $rt::UNM_sdc $hier $isRegexp $ignoreCase $filterExpr]
						if {$matches == {}} {
                            if {$ignoreCase} {
                                set pat $origPat
                            }
							if {![info exist opt(-quiet)]} {
                                printConstraintWarning $pat "cells" $command
							}
						} else {
							lappend cells $matches
						}
					}
				}
			}
	    return [sdcrt::uniqList $cells]
	}
	get_design   -
		get_designs  {
			################################################################
	    supported opt {patterns -hierarchical -quiet} $command
	    global sdcrt::not_found_objects
	    set des [rt::design]
            set hier [info exists opt(-hierarchical)]

	    set mods {}
		array unset addedMod
	    foreach pat $opt(patterns) {
		if {[rt::typeOf $pat] == "NRealModS"} {
		    lappend mods $pat
		} else {
                    if {$hier} {
                        set matches [[sdcrt::getCurrMod] findModules $pat]
                    } else {
		    set matches [$des getModules $pat]
                    }
		    if {$matches eq "NULL" || [$matches size] == 0} {
			if {![info exist opt(-quiet)]} {
			    set not_found_objects($pat) 1
			}
		    } else {
		        for {set i [$matches begin]} {[$i ok]} {$i incr} {
                            set mod [$i object]
                            if {![info exists addedMod($mod)]} {
			        lappend mods $mod
                                set addedMod($mod) 1
                            }
		        }
		        rt::delete_NRealModList $matches
                    }
		}
	    }
 	    return [sdcrt::uniqList $mods]
	}
	get_lib_cell  -
	get_lib_cells {
	    ################################################################
	    supported opt {patterns -of_objects -filter -regexp -quiet} $command
            array unset addedLibcell
	    set cells {}
            if {[info exist opt(-of_objects)]} {
                foreach obj $opt(-of_objects) {
                    switch -- [rt::typeOf $obj] {
                        "NPort" {
                            set cellRef [$obj cell]
                            if {$cellRef ne "NULL" && ![info exist addedLibcell($cellRef)]} {
                                lappend cells $cellRef
                                set addedLibcell($cellRef) 1
                            }
                        }
                        "NInstS" {
                            set cellRef [$obj isCell]
                            if {$cellRef ne "NULL" && ![info exist addedLibcell($cellRef)]} {
                                lappend cells $cellRef
                                set addedLibcell($cellRef) 1
                            }
                        }
	    		default {
	    		    return -code error "object of unknown type"
	    		}
                    }
                }
            } else {
                if {[info exists opt(-quiet)]} {
                    set verbose 0
                } else {
                    set verbose 1
                }
		foreach pat $opt(patterns) {
		    if {[rt::typeOf $pat] == "NCellS"} {
			lappend cells $pat
		    } else {
			set matches [rt::getLibCells $pat $verbose]
			if {$matches == {}} {
			    if {![info exist opt(-quiet)]} {
				set not_found_objects($pat) 1
			    }
			} else {
			    lappend cells $matches
			}
		    }
		}
            }
            if {[info exist opt(-filter)]} {
                set isRegexp false
                if {[info exist opt(-regexp)]} {
                    set isRegexp true
                }
                return [getFilteredList $opt(-filter) $isRegexp [utils::flatList $cells]] 
            }
            return [sdcrt::uniqList $cells]
	}
	get_lib_pin -
	get_lib_pins {
	    ################################################################
	    supported opt {patterns -of_objects -filter -regexp -quiet} $command
	    global sdcrt::not_found_objects

            set libpins {}
            if {[info exist opt(-of_objects)]} {
                if {$rt::libFiles eq {}} {
                    return {}
                }

                foreach obj $opt(-of_objects) {
                    switch -- [rt::typeOf $obj] {
                        "NCellS" {
                            set iterRef [$obj ports]
                            for {set portIter [$iterRef begin]} {[$portIter ok]} {$portIter incr} {
                                set port [$portIter object]
                                lappend libpins $port
                            }
                        }
                        "NPinS" {
                            set instRef [$obj ownerInstance]
                            if {[$instRef isCell] ne "NULL"} {
                                set pinIdx [$obj index]
                                lappend libpins [$obj port $pinIdx]
                            }
                        }
                        default {
                            return -code error "object of unknown type"
                        }
                    }
		}
            } else {
                foreach pat $opt(patterns) {
		    if {[rt::typeOf $pat] == "NPort"} {
			lappend libpins $pat
		    } elseif {[regexp (.*)\/(.*) $pat match cell pin]} {
			set cells [rt::getLibCells $cell]
                        foreach cell $cells {
                            if {$pin eq "*"} {
                                set iterRef [$cell ports]
                                for {set portIter [$iterRef begin]} {[$portIter ok]} {$portIter incr} {
                                    set port [$portIter object]
                                    lappend libpins $port
                                }
                            } else {
                                set iterRef [$cell ports]
                                set found 0
                                for {set portIter [$iterRef begin]} {[$portIter ok]} {$portIter incr} {
                                    set port [$portIter object]
                                    if {[string match $pin [$port name]]} {
                                        lappend libpins $port
                                        set found 1
                                    }
                                }
                                if {!$found && ![info exist opt(-quiet)]} {
                                        set not_found_objects($pat) 1
                                    }
                            }
                        }
                    }
                }
            }
            if {[info exist opt(-filter)]} {
                set isRegexp false
                if {[info exist opt(-regexp)]} {
                    set isRegexp true
                }
                return [getFilteredList $opt(-filter) $isRegexp [utils::flatList $libpins]] 
            }
            return [sdcrt::uniqList $libpins]
	}
	get_libs {
	    ################################################################
	    supported opt {patterns -of_objects -filter -regexp -quiet} $command
	    global sdcrt::not_found_objects
	    set libList {}
            array unset libAdded
            if {[info exist opt(-of_objects)]} {
                foreach obj $opt(-of_objects) {
                    switch -- [rt::typeOf $obj] {
                        "NCellS" {
                            set corner [[rt::design] mvCorner]
                            set libRef [$obj library $corner]
                            if {$libRef ne "NULL" && ![info exist libAdded($libRef)]} {
                                set libAdded($libRef) 1
                                lappend libList $libRef
                            }
                        }
                        default {
                            return -code error "object of unknown type"
                        }
                    }
		}
            } else {
		if {![info exist opt(patterns)]} {
		    set opt(patterns) "*"
		}
	        foreach pat [utils::flatList $opt(patterns)] {
		    if {[rt::typeOf $pat] == "NLibS"} {
			lappend libList $pat
		    } else {
			set matches [$rt::db findLibraries $pat]
			if {$matches == {} || [$matches size] == 0} {
			    if {![info exist opt(-quiet)]} {
				set not_found_objects($pat) 1
			    }
			} else {
			    for {set mi [$matches begin]} {[$mi ok]} {$mi incr} {
				lappend libList [$mi object]
			    }
			}
			rt::delete_NLibList $matches
		    }
		}
            }
            if {[info exist opt(-filter)]} {
                set isRegexp false
                if {[info exist opt(-regexp)]} {
                    set isRegexp true
                }
                return [getFilteredList $opt(-filter) $isRegexp [utils::flatList $liblist]] 
            }
	    return [sdcrt::uniqList $libList]
	}
		get_net   -
		get_nets  {
	    ################################################################
	    supported opt {patterns -of_objects -leaf -hierarchical -filter -regexp -nocase -quiet} $command
	    global sdcrt::not_found_objects
	    set nets {}
		array unset pinAdded
	    if {[info exist opt(-of_objects)]} {
			set leaf [info exist opt(-leaf)]
			set iPins [list]
			foreach obj $opt(-of_objects) {
				switch -- [rt::typeOf $obj] {
					"NPinS" {
						if {![info exist pinAdded($obj)]} {
							set pinAdded($obj) 1
							lappend iPins $obj
                            }
					}
					"NInstS" {
						set pinCount 0
						set cellRef [$obj isCell]
						set modRef [$obj isRealModule]
						if {$cellRef ne "NULL"} {
							set pinCount [$cellRef pinCount]
						} elseif {$modRef ne "NULL"} {
							set pinCount [$modRef pinCount]
						}
                            for {set i 0} {$i < $pinCount} {incr i} {
                                set objPin [$obj pin $i]
                                if {![info exist pinAdded($objPin)]} {
                                    set pinAdded($objPin) 1
									lappend iPins $objPin
                                }
                            }
					}
					default {
						return -code error "object of unknown type"
					}
				}
			}
			array unset netAdded
		    foreach pin $iPins {
				set net [$pin net]
				if {$net != "NULL" && ![info exist netAdded($net)]} {
					if {[$net constant] == -1} {
						acquire $net
					}
					lappend nets $net
					set netAdded($net) 1
				}
			}
			if {[info exists opt(-filter)] && [llength $nets] > 0} {
				set isRegexp [info exists opt(-regexp)]
                    set nets [[sdcrt::getCurrMod] filterNetCollection [utils::flatList $nets] $isRegexp $opt(-filter)]
			}
	    } else {
			set ignoreCase [expr [info exists opt(-nocase)] && [info exists opt(-regexp)]]
	        set hier [info exist opt(-hierarchical)]
	        set des  [rt::design]
			if {![info exist opt(patterns)]} {
				set opt(patterns) "*"
			}
	        foreach pat $opt(patterns) {
				if {[rt::typeOf $pat] == "NNetS"} {
					lappend nets $pat
				} else {
					set isRegexp [info exists opt(-regexp)]
					set filterExpr ""
					if {[info exists opt(-filter)]} {
                            set filterExpr $opt(-filter)
					}
					# add support for -nocase option
					if {$ignoreCase} {
						set origPat $pat
						if {$filterExpr eq ""} {
							set filterExpr "full_name =~ $pat"
						} else {
							set filterExpr "full_name =~ $pat && ($filterExpr)"
						}
						# ignore -hier and match all inst full names against the pattern
						set hier 1
						set pat "*"
					}
					set matches [[sdcrt::getCurrMod] findNets $pat $rt::UNM_sdc $hier $isRegexp $ignoreCase $filterExpr]
					if {$matches == {}} {
						if {$ignoreCase} {
							set pat $origPat
						}
						if {![info exist opt(-quiet)]} {
							printConstraintWarning $pat "nets" $command
						}
					} else {
						foreach match $matches {
							lappend nets $match
						}
					}
				}
	        }
		}
 	    return [sdcrt::uniqList $nets]
	}
		get_pin    -
		get_pins   -
		get_port   -
		get_ports
		{
	    ################################################################
	    supported opt {patterns -of_objects -leaf -hierarchical -filter -regexp -nocase -quiet -scoped_to_current_instance -prop_thru_buffers} $command
	    global sdcrt::not_found_objects

	    set pins {}
	    if {[info exist opt(-of_objects)]} {
		set leaf [info exist opt(-leaf)]
                set iPins [list]
                array unset pinAdded
		foreach obj $opt(-of_objects) {
		    switch -- [rt::typeOf $obj] {
			"NNetS" {
                            set iPin [$obj firstPin]
			    while {$iPin != "NULL"} {
				acquire $iPin
				lappend iPins $iPin
				set iPin [$iPin nextPinOnNet]
			    }
			}
			"NInstS" {
			    if {[info exist sdcrt::useAllPins] && 
				$sdcrt::useAllPins == 1} {
				# This should be faster for large pin counts
				lappend iPins [$obj allPins]
			    } else {
				set pinCount 0
				set cellRef [$obj isCell]
				set modRef [$obj isRealModule]
				if {$cellRef ne "NULL"} {
				    set pinCount [$cellRef pinCount]
				} elseif {$modRef ne "NULL"} {
				    set pinCount [$modRef pinCount]
				}
				for {set i 0} {$i < $pinCount} {incr i} {
				    lappend iPins [$obj pin $i]
				}
			    }
			}
			default {
			    return -code error "object of unknown type"
			}
		    }
		}
	        set iPins [utils::flatList $iPins]
		foreach pin $iPins {
		    if {$leaf} {
			foreach aPin [flatPins $pin] {
                            if {![info exist pinAdded($aPin)]} {
                                set pinAdded($aPin) 1
                                lappend pins $aPin
                            }
                        }
		    } else {
                        if {![info exist pinAdded($pin)]} {
                            set pinAdded($pin) 1
                            lappend pins $pin
                        }
                    }
	        }
                if {[info exists opt(-filter)] && [llength $pins] > 0} {
                    set isRegexp [info exists opt(-regexp)]
                    set isIgnoreCase [info exists opt(-nocase)]
                    set pins [[sdcrt::getCurrMod] filterPinCollection [utils::flatList $pins] $isRegexp $isIgnoreCase $opt(-filter)]
                }
	    } else {
		set hier [info exist opt(-hierarchical)]
	        set des  [rt::design]
		if {![info exist opt(patterns)]} {
		    set opt(patterns) "*"
		}
		foreach pat $opt(patterns) {
		    if {[rt::typeOf $pat] == "NPinS"} {
			lappend pins $pat
		    } else {
				set isRegexp [info exists opt(-regexp)]
                                set isIgnoreCase [info exists opt(-nocase)]
				set filterExpr ""
				if {[info exists opt(-filter)]} {
					set filterExpr $opt(-filter)
				}
			        if {$command == "get_pins" || $command == "get_pin" || [info exist opt(-scoped_to_current_instance)]} {
					set matches [[sdcrt::getCurrMod] findPins $pat $rt::UNM_sdc $hier {} $isRegexp $isIgnoreCase $filterExpr]
				} else {				
					set matches [[[rt::design] topModule] findPins $pat $rt::UNM_sdc $hier {} $isRegexp $isIgnoreCase $filterExpr]
				}
				if {$matches == {}} {
			    if {![info exist opt(-quiet)]} {
                                if { $command == "get_ports" || $command == "get_port" } {
                                    printConstraintWarning $pat "ports" $command
                                } else {
                                    printConstraintWarning $pat "pins" $command
                                }
			    }
			} else {
                            foreach mpin $matches {
                                lappend pins $mpin
                            }
			}
		    }
		}
	    }

# patch so get_ports doesn't include genome pins
            if {$command == "get_ports" ||
		$command == "get_port"} {
		set ports {}
		foreach p $pins {
		    if {[$p ownerModule] != "NULL"} {
			set pinname [$p hierName]
			if {[info exist opt(-prop_thru_buffers)]} {
			    # First... this would only work for uniquified modules...
			    set upPin [otherSide $p true]
			    if {$upPin != "NULL"} {
				# this means we're in a submodule (and uniquified...)

				if {[$upPin direction] eq "input"} {
				    set drv [driverPins $upPin false]
#				    rt::UMsg_print "Driver $drv\n"
				    foreach d $drv {
#					rt::UMsg_print "Found driver [$d hierName]\n"
					set inst [$d ownerInstance]
					if {$inst != "NULL" && ([[$inst reference] name] eq "IBUF")} {
					    set p [$inst findPin "I"]
					    set p [driverPins $p false]
					    rt::UMsg_print "Went through IBUF, found [$p hierName]\n"
					}
				    }
				} elseif {[$upPin direction] eq "output"} {
				    set ld [loadPins $upPin false]
#				    rt::UMsg_print "Load $ld\n"
				    foreach l $ld {
#					rt::UMsg_print "Found load [$l hierName]\n"
					set inst [$l ownerInstance]
					if {$inst != "NULL" && ([[$inst reference] name] eq "OBUF")} {
					    set p [$inst findPin "O"]
					    set p [loadPins $p false]
					    rt::UMsg_print "Went through OBUF, found [$p hierName]\n"
					}
				    }
				}

			    }
			}
#			rt::UMsg_print "Port [$p hierName]\n"
			lappend ports $p
		    }
		}
		set pins $ports
	    }
# end patch
		
	    return [sdcrt::uniqList $pins]
	}

	get_clock  -
	get_clocks {
	    if {($command == "get_clock") &&
		[rt::UParam_get getClockCreatesClock rc]}  {
		supported opt {patterns -filter -regexp} $command
                if {[info exist opt(-filter)]} {
                    set isRegexp false
                    if {[info exist opt(-regexp)]} {
                        set isRegexp true
                    }
                    return [getFilteredList $opt(-filter) $isRegexp [utils::flatList $opt(patterns)]] 
                }
		return [getClockInCurrentMode $opt(patterns)]
	    }
	    supported opt {patterns -of_objects -filter -regexp -quiet -include_generated_clocks} $command
	    global sdcrt::not_found_objects
	    set clks {}
	    set des [rt::design]
	    if {![info exist opt(patterns)]} {
		set opt(patterns) "*"
	    }
	    foreach pat $opt(patterns) {
		if {[rt::typeOf $pat] == "TClock"} {
		    lappend clks $pat
		} else {
		    set matches [findClocksInCurrentMode $pat]
		    if {$matches == {}} {
			if {![info exist opt(-quiet)]} {
                            printConstraintWarning $pat "clocks" $command
			}
		    } else {
			lappend clks $matches
		    }
		}
	    }
            if {[info exist opt(-of_objects)]} {
                set clks {}
                set objs $opt(-of_objects)
                if { [llength $objs] != 0 } {
                    foreach obj $objs {
                        set objType [rt::typeOf $obj]
                        set pin $obj
                        if { $objType == "NNetS" } {
                            # get a pin from this net
                            set pin [ $obj firstPin ]
                            set objType [rt::typeOf $pin]
                        }
                        if {$objType != "NPinS"} {
                            crit-warn "-of_objects only supports objects of type Pin or Net (found $objType)"
                        }
						#get the constraint info on the pin
						acquireWithConstraints $pin
                        set clock [$pin getClock false]
                        if {$clock != "NULL"} {
                          lappend clks $clock
                        }
						release $pin
                    }
                    if { [ llength $clks ] == 0 } {
                        crit-warn "no clocks found"
                    }
                }
            }

	    if {[info exists opt(-include_generated_clocks)]} {
		set allClks [findClocksInCurrentMode *]
		set clkList $clks
		foreach refClk $clkList {
		    foreach testClk $allClks {
			if {$testClk != $refClk} {
			    if {[isDerived $testClk $refClk] == 1} {
				lappend clks $testClk
			    }
			}
		    }
		}
	    }

            if {[info exist opt(-filter)]} {
                set isRegexp false
                if {[info exist opt(-regexp)]} {
                    set isRegexp true
                }
                return [getFilteredList $opt(-filter) $isRegexp [utils::flatList $clks]] 
            }
	    return [sdcrt::uniqList $clks]
	}
	group_path {
	    if {[info exist opt(-help)]} {
		puts {  group_path [-help] -name <group_name> | -default}
		puts {       [-weight <float>] [-critical_range <float>]}
		puts {       [-from | -rise_from | -fall_from <list>]} 
		puts {       [-through | -rise_through | -fall_through <list>]*} 
		puts {       [-to | -rise_to | -fall_to  <list>]}
		return
	    }
	    setException $command opt
	}
        get_references {
            supported opt {patterns} $command
	    set insts {}
            array unset addedInst
	    foreach pat $opt(patterns) {
		set matches [[sdcrt::getCurrMod] findInstances "*" $rt::UNM_sdc 1 0 "ref_name=~$pat"]
                foreach inst $matches {
                    if {![info exists addedInst($inst)]} {
                        lappend insts $inst
                        set addedInst($inst) 1
		    }
                }
            }
            return $insts
        }
	remove_clock_uncertainty {
	    ################################################################
	    supported opt {-from -to -rise_to -fall_to
		-rise_from -fall_from -setup -hold object_list} $command
	    set toObjs {}
	    set toEdge "x"
	    if [info exist opt(-to)] {
		set toObjs [lindex [lindex $opt(-to) 0] 1]
		if {[lindex [lindex $opt(-to) 0] 0]=="rise"} {
		    set toEdge "r"
		} elseif {[lindex [lindex $opt(-to) 0] 0]=="fall"} {
		    set toEdge "f"
		}
	    }
	    set frObjs {}
	    set frEdge "x"
	    if [info exist opt(-from)] {
		set frObjs [lindex [lindex $opt(-from) 0] 1]
		if {[lindex [lindex $opt(-from) 0] 0]=="rise"} {
		    set frEdge "r"
		} elseif {[lindex [lindex $opt(-from) 0] 0]=="fall"} {
		    set frEdge "f"
		}
	    }
	    if {$toObjs != {}} {
		set objs $toObjs
		set frClks {}
		foreach frObj [utils::flatList $frObjs] {
		    foreach frClk [findClocksInCurrentMode $frObj] {
			lappend frClks $frClk
		    }
		}
	    } else {
		set objs {}
		if [info exist opt(object_list)] {
		    set objs $opt(object_list)
		}
		set frClks "NULL"
	    }
            set setup [info exist opt(-setup)]
            set hold  [info exist opt(-hold)]
	    if { [llength $objs] != 0 } {
		foreach obj [utils::flatList $objs] {
		    set objType [rt::typeOf $obj]
		    if {$objType == "NPinS"} {
			ignored_command "$command <pin>"
			release $obj
		    } else {
			foreach clk [findClocksInCurrentMode $obj] {
			    foreach frClk $frClks {
				$clk removeUncertainty $frClk $frEdge $toEdge $setup $hold
			    }
			}
		    }
		}
	    } else {
                set all_clocks [findClocksInCurrentMode *]
		foreach clk $all_clocks {
		    $clk clearUncertainty
		}
	    }
	}
	report_timing {
	    ################################################################
	    if {[info exist opt(-help)]} {
		puts {---------------------------------------------------------------------}
		puts {Usage:}
		puts {  report_timing [-help] [-hierarchical] [-net] [-rise] [-fall]}
		puts {       [-from | -rise_from | -fall_from <list>]} 
		puts {       [-through | -rise_through | -fall_through <list>]*} 
		puts {       [-to | -rise_to | -fall_to  <list>]}
		puts {       [-mode <mode_name>]}
		puts {       [-max_paths <cnt>] [{>|>>} <stdoutFile>]}
		puts {       [-group <group_name> | -combined]}
		puts {       [-format <list>] }
		puts {  list is a tcl list containing any combination of the following:}
		puts {       cell slew net_delay arc_delay delay arrival }
		puts {       edge net_load load fanout location power_domain }
		puts {---------------------------------------------------------------------}
		return
	    }
	    set hier [info exist opt(-hierarchical)]
	    set net  [info exist opt(-net)]
	    if {[info exist opt(-stop_at_genomes)]} {
		set thruGenomes "false"
	    } else {
		set thruGenomes "true"
	    }
	    if {[info exist opt(-nworst)]} {
		set count $opt(-nworst)
	    } elseif {[info exist opt(-max_paths)]} {
                set count $opt(-max_paths)
            } else {
		set count 1
	    }
	    if {[info exist opt(-group)]} {
		set group $opt(-group)
	    } elseif {[info exist opt(-default)]} {
		set group "default"
	    } else {
		set group ""
	    }
	    set des [rt::design]
	    if {[info exist opt(-mode)]} {
		$des changeTimingMode $opt(-mode)
	    } else {
		$des changeTimingMode "common_mode"
	    }
	    set emptyList false
	    set exception [setException $command opt emptyList]
	    if {$emptyList} {
		return
	    }
	    if {$exception != "NULL" || $group != ""} {
		set i -1
		set sz [expr $i + 1]
	    } else {
		set i 1
		set sz [$des numPathGroups]
	    }
	    if {[info exist opt(-combined)]} {
		set i 0
		set sz 1
	    }
	    for {} { $i < $sz } {incr i} {
		if {$i > 0} {
		    set group [$des groupName $i]
		    if {$sz > 2} {
			rt::UMsg_print "Report for group $group\n"
		    }
		}
		set nth 0
		set ti [rt::TimingInfo]
		set endPoints [$des detailedEndPoints $group $exception]
		while {$nth < $count} {
		    set ti [rt::TimingInfo]
		    if {[info exist opt(-rise)]} {
			#		    puts {$ti fixEdge "rise"}
			$ti fixEdge "rise"
		    } elseif {[info exist opt(-fall)]} {
			$ti fixEdge "fall"
		    }
		    set epw [$endPoints pop]
		    set mod [$des topModule]
		    set ep [$mod findPin [$epw pin] $rt::UNM_sdc]
		    if {$ep == "NULL" || $ep == ""} {
			break
		    }
		    if {$exception == "NULL" && $group == ""} {
			$ti fixEndPoint "true"
		    } else {
			if {[$epw domain] != "NULL"} {
			    $ti fixDomain [$epw domain]
			}
		    }
		    if {$count > 1} {
			rt::UMsg_print "Path #: [expr $nth + 1]\n"
		    }
		    if {[info exists opt(-format)]} {
			$ep reportTiming $ti $exception $thruGenomes $hier $net false $opt(-format)
		    } else {
			$ep reportTiming $ti $exception $thruGenomes $hier $net false
		    }
		    incr nth
		    release $ep
		}
		if {$exception != "NULL"} {
		    $exception remove
		}
		if {$i == 1} {
		    set sz [$des numPathGroups]
		}
	    }
	}
	set_case_analysis {
	    ################################################################
	    switch -- $opt(value) {
		"0"    - "zero"    {set cmd setConstantForTiming ; set v 0}
		"1"    - "one"     {set cmd setConstantForTiming ; set v 1}
		"rise" - "rising"  {set cmd setConstantEdge ; set v "rise"}
		"fall" - "falling" {set cmd setConstantEdge ; set v "fall"}
		default   {ignored_command "$command $opt(value)" ; return}
	    }
	    foreach pin [pinList $opt(port_pin_list)] {
		$pin $cmd $v "userImpl"
		release $pin
	    }
	}
        set_clock_gating_check {
            ignored_command $command

            set commandOpts ""
            set flagOpts [list {-rise} {-fall} {-high} {-low}]
            foreach flag $flagOpts {
                if {[info exists opt($flag)]} {
                    set commandOpts "$commandOpts $flag"
                }
            }
            if {[info exists opt(-setup)]} {
                set commandOpts "$commandOpts -setup [getSdcTime [time $opt(-setup)]]"
            }
            if {[info exists opt(-hold)]} {
                set commandOpts "$commandOpts -hold [getSdcTime [time $opt(-hold)]]"
            }

            # OBJS = cells/pins/clock objects           
            if {[info exists opt(object_list)]} {
                foreach obj $opt(object_list) {
                    switch -- [rt::typeOf $obj] {
                        "NPinS" {
                            foreach pin [pinList $obj] {
                                $pin saveGenericAssertion $command $commandOpts
                                release $pin
                            }
                            release $obj
                        }
                        "NInstS" {
                            set pin0 [$obj pin 0]
                            if {[rt::typeOf $pin0] eq "NPinS"} {
                                $pin0 saveGenericAssertionOnInst $command $commandOpts
                            }
                            release $obj
                        }
                        default {
                            set sdcCommand "$command $commandOpts [getObjListRef $obj]"
                            $rt::db saveConstraint $sdcCommand
                            release $obj
                        }
                    }
                }
            } else {
                set sdcCommand "$command $commandOpts"
                $rt::db saveConstraint $sdcCommand
	    }
        }
	set_clock_group -
	set_clock_groups {
	    ################################################################
	    # -allow_paths is silently ignored (PCR: 2316)
	    set allClks {}
	    set grpNr 0
	    foreach group $opt(-group) {
		set clks {}
		foreach pat [lindex $group 1] {
		    set matches [findClocksInCurrentMode $pat]
		    if {$matches == {}} {
			if {![info exist opt(-quiet)]} {
			    set not_found_objects($pat) 1
			}
		    } else {
			foreach clk $matches {
			    if [info exist clkGrp($clk)] {
					set clkNm [$clk name]
					return -code error "$clkNm in more then one group"
			    }
			    set clkGrp($clk) $grpNr
			    lappend clks $clk
			    lappend allClks $clk
			}
		    }
		}
		lappend groups $clks
		incr grpNr
	    }
	    if {$grpNr == 1} {
		set clks {}
		foreach clk [findClocksInCurrentMode *] {
		    if {![info exist clkGrp($clk)]} {
			set clkGrp($clk) $grpNr
			lappend clks $clk
			lappend allClks $clk
		    }
		}
		lappend groups $clks
		incr grpNr
	    }
	    set des [rt::design]
	    for {set nr 0} {$nr < $grpNr} {incr nr} {
		set frClks {}
		set toClks {}
		foreach clk $allClks {
		    if {$clkGrp($clk) == $nr} {
			lappend frClks $clk
		    } else {
			lappend toClks $clk
		    }
		}
		if {$frClks != {} && $toClks != {}} {
		    set exception [$des newFalsePathException 2 "intAss"]
		    foreach clk $frClks {
			$exception addClock $clk 1
		    }
		    foreach clk $toClks {
			$exception addClock $clk 0
		    }
		}
	    }
            set flagOpts [list {-physically_exclusive} {-logically_exclusive} {-asynchronous} {-allow_paths}]
            set commandOpts ""
            foreach arg $flagOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg"
                }
            }
            if {[info exists opt(-name)]} {
                set commandOpts "$commandOpts -name $opt(-name)"
            }
            foreach group $opt(-group) {
                set clkList [utils::flatList [lindex $group 1]]
                if {[llength $clkList] == 1} {
                    set clkList "\[list [getObjListRef $clkList]\]"
                } else {
                    set clkList [getObjListRef $clkList]
	}
                set commandOpts "$commandOpts -group $clkList"
            }
            set sdcCommand "$command $commandOpts"
            $rt::db saveConstraint $sdcCommand
	}
        set_clock_sense {
            ignored_command $command

            set flagOpts [list {-positive} {-negative} {-stop_propagation}]
            set commandOpts ""
            foreach arg $flagOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg"
                }
            }
            if {[info exists opt(-pulse)]} {
                set commandOpts "$commandOpts -pulse $opt(-pulse)"
            }
            if {[info exists opt(-clocks)]} {
                set commandOpts "$commandOpts -clocks [getObjListRef $opt(-clocks)]"
            }

            # OBJS = pins/libpins
	    foreach pin $opt(pins) {
                switch -- [rt::typeOf $pin] {
                    "NPinS" {
                        foreach ipin [pinList $pin] {
                            $ipin saveGenericAssertion $command $commandOpts
                            release $ipin
                        }
                    }
                    "NPort" {
                        set sdcCommand "$command $commandOpts [getObjListRef $pin]"
                        $rt::db saveConstraint $sdcCommand
                    }
                    default {
                        warning "incorrect object type in \'$command\'"
                        release $pin
                    } 
                }
	    }
        }
	set_clock_latency {
	    ################################################################
	    supported opt {delay object_list -rise -fall -min -max -source -early -late} $command
	    set srce [info exist opt(-source)]
	    set rise [info exist opt(-rise)]
	    set fall [info exist opt(-fall)]
            set min  [info exist opt(-min)]
            set max  [info exist opt(-max)]
            set early [info exist opt(-early)]
            set late  [info exist opt(-late)]
	    set lat  [rfTime $rise $fall $opt(delay)]
	    set des  [rt::design]
	    set pins {}
	    foreach obj [utils::flatList $opt(object_list)] {
		set clkList [findClocksInCurrentMode $obj]
		if {$clkList != {}} {
		    foreach clk $clkList {
			$clk setLatency $lat $srce $min $max $early $late
		    }
		} else {
		    lappend pins $obj
		}
	    }
	    foreach pin [pinList $pins] {
		$pin setClockLatency $lat $srce "userImpl" $min $max $early $late
		release $pin
	    }
	}
        set_ideal_latency {
            ignored_command $command

            set flagOpts [list {-rise} {-fall} {-min} {-max}]
            set commandOpts ""
            foreach arg $flagOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg"
                }
            }
            # OBJS = pins/ports
	    foreach pin [pinList $opt(object_list)] {
                $pin saveTimingAssertion $command $commandOpts [time $opt(value)]
                release $pin
	    }
        }
        set_ideal_network {
            ignored_command $command

            set commandOpts ""
            if {[info exists opt(-no_propagate)]} {
                set commandOpts "$commandOpts -no_propagate"
            }

            # OBJS = ports/pins/nets
	    set genomesToo 1
	    set pushToDrivers 2
	    foreach obj [pinList $opt(object_list) {} $genomesToo $pushToDrivers] {
                $obj saveGenericAssertion $command $commandOpts
                release $obj
	    }
        }
        set_ideal_net {
            ignored_command $command

            # OBJS = nets
	    foreach obj [pinList $opt(object_list)] {
                $obj saveGenericAssertion "set_ideal_network" "-no_propagate"
                release $obj
	    }
            foreach obj $opt(object_list) {
                release $obj
            }
        }
        set_ideal_transition {
            ignored_command $command

            set flagOpts [list {-rise} {-fall} {-min} {-max}]
            set commandOpts ""
            foreach arg $flagOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg"
                }
            }

            # OBJS = pins/ports
	    foreach pin [pinList $opt(object_list)] {
                $pin saveTimingAssertion $command $commandOpts [time $opt(value)]
                release $pin
	    }
        }
	set_clock_transition {
	    ################################################################
	    supported opt {transition clock_list -rise -fall -min -max } $command
	    set rise [info exist opt(-rise)]
	    set fall [info exist opt(-fall)]
            set min  [info exist opt(-min)]
            set max  [info exist opt(-max)]
	    set slw [rfTime $rise $fall $opt(transition)]
	    foreach obj [utils::flatList $opt(clock_list)] {
		foreach clk [findClocksInCurrentMode $obj] {
		    $clk setInputSlew $slw $min $max
		    $clk -delete
		}
	    }
	}
	set_clock_uncertainty {
	    ################################################################
	    supported opt {uncertainty -from -to -rise_to -fall_to
		-rise_from -fall_from -setup -hold object_list} $command
	    set toObjs {}
	    set toEdge "x"
	    if [info exist opt(-to)] {
		set toObjs [lindex [lindex $opt(-to) 0] 1]
		if {[lindex [lindex $opt(-to) 0] 0]=="rise"} {
		    set toEdge "r"
		} elseif {[lindex [lindex $opt(-to) 0] 0]=="fall"} {
		    set toEdge "f"
		}
	    }
	    set frObjs {}
	    set frEdge "x"
	    if [info exist opt(-from)] {
		set frObjs [lindex [lindex $opt(-from) 0] 1]
		if {[lindex [lindex $opt(-from) 0] 0]=="rise"} {
		    set frEdge "r"
		} elseif {[lindex [lindex $opt(-from) 0] 0]=="fall"} {
		    set frEdge "f"
		}
	    }
	    if {$toObjs != {}} {
		set objs $toObjs
		set frClks {}
		foreach frObj [utils::flatList $frObjs] {
		    foreach frClk [findClocksInCurrentMode $frObj] {
			lappend frClks $frClk
		    }
		}
	    } else {
		set objs $opt(object_list)
		set frClks "NULL"
	    }
            set setup [info exist opt(-setup)]
            set hold  [info exist opt(-hold)]
	    foreach obj [utils::flatList $objs] {
		set objType [rt::typeOf $obj]
		if {$objType == "NPinS"} {
		    ignored_command "$command <pin>"
		    release $obj
		} else {
		    foreach clk [findClocksInCurrentMode $obj] {
			foreach frClk $frClks {
			    $clk setUncertainty [time $opt(uncertainty)] $frClk $frEdge $toEdge $setup $hold
			}
		    }
		}
	    }
	}
	set_disable_timing {
	    ################################################################
	    global sdcrt::not_found_objects
	    supported opt {-from -to object_list} $command
	    foreach obj [utils::flatList $opt(object_list)] {
		set cell "NULL"
		set inst "NULL"
		set objType [rt::typeOf $obj]
		if {$objType == "NCellS"} {
		    set cell $obj
		} elseif {$objType == "NInstS"} {
		    set inst $obj
		} elseif {$objType == "NPinS"} {
		    set fpOpt(-through) [list [list "both" $obj]]
		    setException "set_false_path" fpOpt
		    continue
		} else {
		    set cell [rt::getLibCell $obj]
		    if {$cell == "NULL"} {
			set des  [rt::design]
			set inst [[$des topModule] findInstance $obj]
			if {$inst == "NULL"} {
			    set not_found_objects($obj) 1
			}
		    }
		}
		if {$inst == "NULL"} {
		    set inst $cell
		} else {
		    set cell [[$inst reference] isCell]
		    if {$cell == "NULL"} {
			ignored_command "$command <hierInst>"
			release $inst
			continue
		    }
		}
		if {$cell != "NULL"} {
		    if [info exist opt(-from)] {
			set frs ""
			set pinList [$cell findPins $opt(-from) $rt::UNM_sdc]
			for {set pi [$pinList begin]} {[$pi ok]} {$pi incr} {
			    lappend frs [$pi object]
			}
			rt::delete_NPinIndexList $pinList
			if {$frs == ""} {
			    set not_found_objects($obj/$opt(-from)) 1
			}
		    } else {
			set frs -1
		    }
		    if [info exist opt(-to)] {
			set tos ""
			set pinList [$cell findPins $opt(-to) $rt::UNM_sdc]
			for {set pi [$pinList begin]} {[$pi ok]} {$pi incr} {
			    lappend tos [$pi object]
			}
			rt::delete_NPinIndexList $pinList
			if {$tos == ""} {
			    set not_found_objects($obj/$opt(-to)) 1
			}
		    } else {
			set tos -1
		    }
		    foreach fr $frs {
			foreach to $tos {
			    # GEBRE  No category for disables on library cells yet NEED to FIX 
			    if {$inst == $cell} {
				$inst disableTiming $fr $to
			    } else {
				$inst disableTiming "userImpl" $fr $to
			    }
			}
		    }
		    if {$inst != $cell} {
			release $inst
		    }
		} else {
		    set not_found_objects($obj) 1
		}
	    }
	}
        set_drive {
            ignored_command $command

            set flagOpts [list {-rise} {-fall} {-min} {-max}]
            set commandOpts ""
            foreach arg $flagOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg"
                }
            }

            # OBJS = input/inout ports
	    foreach pin [pinList $opt(port_list)] {
                $pin saveGenericAssertion $command $commandOpts $opt(resistance)
                release $pin
	    }
            foreach obj $opt(port_list) {
                release $obj
            }
        }
	set_driving_cell {
	    ################################################################
	    supported opt {-lib_cell -library -pin port_list -min -max} $command
	    if [info exist opt(-library)] {
		set lib  [findLibrary $opt(-library)]
		set cell [$lib findCell $opt(-lib_cell)]
	    } else {
		set cell [$rt::db findCell $opt(-lib_cell)]
	    }
	    if {$cell == "NULL"} {
		global sdcrt::not_found_objects
		set not_found_objects($opt(-lib_cell)) 1
		return -code error "No such cell: '$opt(-lib_cell)'"
	    }
	    if {[info exist opt(-pin)]} {
		set to_pin [$cell findPin $opt(-pin) $rt::UNM_sdc]
	    } else {
		set to_pin 0
	    }
            
            set min [info exist opt(-min)]
            set max [info exist opt(-max)]

            set assCat "userImpl"
            if {$min && !$max} {
                set assCat "userIgnore"
            }
	    foreach pin [pinList $opt(port_list)] {
		$pin setDriveCell $cell $assCat 1 $to_pin $min $max
		release $pin
	    }
	    }
	set_false_path {
	    ################################################################
	    supported opt {-from -rise_from -fall_from
		-through -rise_through -fall_through
		-to -rise_to -fall_to -setup -hold} $command
	    setException $command opt
	}
        set_fanout_load {
            ignored_command $command

            # OBJS = ports
	    foreach pin [pinList $opt(port_list)] {
                $pin saveGenericAssertion $command "" $opt(value)
                release $pin
	    }
            foreach obj $opt(port_list) {
                release $obj
            }
        }
        set_hierarchy_separator {
            ignored_command $command

            # OBJS = none
            set sdcCommand "set_hierarchy_separator \{$opt(hchar)\}"
            $rt::db saveConstraint $sdcCommand
        }
	set_max_delay {
	    ################################################################
	    supported opt {-from -rise_from -fall_from
		-through -rise_through -fall_through
		-to -rise_to -fall_to -datapath_only delay_value} $command	
	    if {[rt::UParam_get enableSetMaxDelay rc] == true} {
		setException $command opt
	    }
	}
	set_multicycle_path {
	    ################################################################
	    supported opt {-from -rise_from -fall_from
		-through -rise_through -fall_through
		-to -rise_to -fall_to -setup -hold -start -end path_multiplier} $command
	    setException $command opt
	}
	set_input_delay  { 
	    ################################################################
	    supported opt {
		-clock -clock_fall
		-rise -fall -min -max -add_delay
		delay_value port_pin_list
		-network_latency_included
		-source_latency_included
	    } $command
	    set add  [info exist opt(-add_delay)]
	    if [info exist opt(-clock)] {
		set clk  [getClockInCurrentMode $opt(-clock)]
		if {$clk == "NULL"} {
		    return -code error "Clock $opt(-clock) not yet defined"
		}
	    } else {
		set clk [[rt::design] getDefaultClock]
		if [info exist opt(-clock_fall)] {
		    msg "info: -clock_fall needs -clock ignoring this option"
		}
	    }
	    set clkf [info exist opt(-clock_fall)]
	    set rise [info exist opt(-rise)]
	    set fall [info exist opt(-fall)]
	    set dly  [rfTime $rise $fall $opt(delay_value)]
	    set nli  [info exist opt(-network_latency_included)]
	    set sli  [info exist opt(-source_latency_included)]
            set min [info exist opt(-min)]
            set max [info exist opt(-max)]
            set assCat "userImpl"
            if {$min && !$max} {
                set assCat "userIgnore"
            }
	    foreach pin [pinList $opt(port_pin_list)] {
		$pin setInputDelay $add $clk $clkf $sli $nli $dly $assCat $min $max
		release $pin
	    }
	    $clk -delete
	}
	set_input_transition {
	    ################################################################
	    supported opt {-rise -fall -min -max transition port_list} $command
	    set rise [info exist opt(-rise)]
	    set fall [info exist opt(-fall)]
	    set slw [rfTime $rise $fall $opt(transition)]
            set min [info exist opt(-min)]
            set max [info exist opt(-max)]
            set assCat "userImpl"
            if {$min && !$max} {
                set assCat "userIgnore"
            }
	    foreach pin [pinList $opt(port_list)] {
# 		puts "$pin setInputSlew $slw"
		$pin setInputSlew $slw $assCat $min $max
		release $pin
	    }
	}
	set_load {
	    ################################################################
	    supported opt {-min -max value objects} $command
            set min [info exist opt(-min)]
            set max [info exist opt(-max)]
            set assCat "userImpl"
            if {$min && !$max} {
                set assCat "userIgnore"
            }
	    foreach pin [pinList $opt(objects)] {
# 		puts "$pin setExternalCap $opt(value)"
		if {([$pin ownerInstance] != "NULL") || ([$pin design] != [rt::design])} {
		    warning "Set load is supported only on top level ports, [$pin fullName] is not one."
		} else {
		    $pin setExternalCap [cap $opt(value)] $assCat $min $max
		}
		release $pin
	    }    
	}
        set_logic_dc {
            ignored_command $command

	    foreach pin $opt(port_list) {
                $pin setLogic 2 "userIgnore"
                release $pin
	    }
        }
	set_logic_one  -
	set_logic_zero {
	    ################################################################
	    set lVal [expr {"$command" == "set_logic_one"}]
	    foreach pin [pinList $opt(port_list)] {
		set net [$pin net]
		while {$net != "NULL"} {
		    set currPin [$net firstPin]
		    set net [$currPin disconnect]
		    if {[$currPin direction] != "output" } {
			$currPin connect $lVal
		    }
		}
	    }
            foreach pin [pinList $opt(port_list)] {
                $pin setLogic $lVal "userImpl"
            }
	}
        set_max_area {
            ignored_command $command

            # OBJS = none
            set sdcCommand "set_max_area $opt(area_value)"
            $rt::db saveConstraint $sdcCommand
        }
        set_max_capacitance {
            ignored_command $command

            # OBJS = ports/designs
	    foreach obj $opt(object_list) {
                switch -- [rt::typeOf $obj] {
                    "NPinS" {
                        $obj saveCapAssertion $command "" [cap $opt(capacitance_value)]
                        release $obj
                    }
                    "NRealModS" {
                        set sdcCommand "$command [cap $opt(capacitance_value)] [getObjListRef $obj]"
                        $rt::db saveConstraint $sdcCommand
                        release $obj
                    }
                    default {
                        warning "incorrect object type in \'$command\'"
                        release $obj
                    }
                }
	    }
        }
        set_max_fanout {
            ignored_command $command

            # OBJS = ports/designs
	    foreach obj $opt(object_list) {
                switch -- [rt::typeOf $obj] {
                    "NPinS" {
                        $obj saveGenericAssertion $command "" $opt(fanout_value)
                        release $obj
                    }
                    "NRealModS" {
                        set sdcCommand "$command $opt(fanout_value) [getObjListRef $obj]"
                        $rt::db saveConstraint $sdcCommand
                        release $obj
                    }
                    default {
                        warning "incorrect object type in \'$command\'"
                        release $obj
                    }
                }
	    }
        }
        set_max_transition {
            ignored_command $command

            set flagOpts [list {-clock_path} {-data_path} {-rise} {-fall}]
            set commandOpts ""
            foreach flag $flagOpts {
                if {[info exists opt($flag)]} {
                    set commandOpts "$commandOpts $flag"
                }
            }

            # OBJS = ports/designs/clock groups
	    foreach obj $opt(object_list) {
                switch -- [rt::typeOf $obj] {
                    "NPinS" {
                        $obj saveTimingAssertion $command $commandOpts [time $opt(transition_value)]
                        release $obj
                    }
                    default {
                        set sdcCommand "$command [getSdcTime [time $opt(transition_value)]] $commandOpts [getObjListRef $obj]"
                        $rt::db saveConstraint $sdcCommand
                        release $obj
                    }
                }
	    }
        }
        set_min_capacitance {
            ignored_command $command

            # OBJS = input-inout ports
	    foreach pin [pinList $opt(object_list)] {
                $pin saveCapAssertion $command "" [cap $opt(capacitance_value)]
                release $pin
	    }
        }
        set_min_delay {
            ignored_command $command

            setException $command opt
	    foreach nm [array names opt] {
		foreach obj [utils::flatList $opt($nm)] {
		    release $obj
		}
	    }
        }
	set_operating_conditions {
	    ################################################################
	    supported opt {-min -max -library condition} $command
	    set cond ""
	    if [info exist opt(-max)] {
		set cond $opt(-max)
	    } elseif [info exist opt(condition)] {
		set cond $opt(condition)
	    }
	    if [info exist opt(-library)] {
		$rt::db setOperatingCondition $cond $opt(-library)
	    } else {
		$rt::db setOperatingCondition $cond
	    }

            set commandOpts ""
            set foundObjects 0
            foreach arg [array names opt] {
                if {$arg eq "-object_list"} {
                    set foundObjects 1
                } elseif {$arg eq "condition"} {
                    set commandOpts "$commandOpts $opt($arg)"
                } else {
                    set commandOpts "$commandOpts $arg $opt($arg)"
                }
            }
            if {$foundObjects} {
                foreach obj $opt(-object_list) {
                    # OBJS = cells/ports
                    switch -- [rt::typeOf $obj] {
                        "NPinS" {
                            foreach pin [pinList $obj] {
                                $pin saveGenericAssertion $command "$commandOpts -object_list"
                                release $pin
                            }
                        }
                        "NInstS" {
                            set pin0 [$obj pin 0]
                            if {[rt::typeOf $pin0] eq "NPinS"} {
                                $pin0 saveGenericAssertionOnInst $command "$commandOpts -object_list"
                            }
                            release $obj
                        }
                        "default" {
                            set sdcCommand "$command $commandOpts -object_list [getObjListRef $obj]"
                            $rt::db saveConstraint $sdcCommand
                        }
                    }
                    release $obj
                }
            } else {
                set sdcCommand "$command $commandOpts"
                $rt::db saveConstraint $sdcCommand
            }
	}
	set_output_delay  { 
	    ################################################################
	    supported opt {
		-clock -clock_fall
		-rise -fall -min -max -add_delay
		delay_value port_pin_list
		-network_latency_included
		-source_latency_included
	    } $command
	    set add  [info exist opt(-add_delay)]
	    if [info exist opt(-clock)] {
		set clk  [getClockInCurrentMode $opt(-clock)]
		if {$clk == "NULL"} {
		    return -code error "Clock $opt(-clock) not yet defined"
		}
	    } else {
		set clk [[rt::design] getDefaultClock]
		if [info exist opt(-clock_fall)] {
		    msg "info: -clock_fall needs -clock ignoring this option"
		}
	    }
	    set clkf [info exist opt(-clock_fall)]
	    set rise [info exist opt(-rise)]
	    set fall [info exist opt(-fall)]
	    set dly  [rfTime $rise $fall $opt(delay_value)]
	    set nli  [info exist opt(-network_latency_included)]
	    set sli  [info exist opt(-source_latency_included)]
            set min [info exist opt(-min)]
            set max [info exist opt(-max)]
            set assCat "userImpl"
            if {$min && !$max} {
                set assCat "userIgnore"
            }
	    foreach pin [pinList $opt(port_pin_list)] {
		$pin setOutputDelay $add $clk $clkf $sli $nli $dly $assCat $min $max
		release $pin
	    }
	    $clk -delete
	}
        set_port_fanout_number {
            ignored_command $command

            # OBJS = ports
	    foreach pin [pinList $opt(port_list)] {
                $pin saveGenericAssertion $command "" $opt(fanout_number)
                release $pin
	    }
        }
        set_propagated_clock {
            ignored_command $command

            # OBJS = ports/pins/clocks/cells
	    foreach obj $opt(object_list) {
                switch -- [rt::typeOf $obj] {
                    "NPinS" {
                        foreach pin [pinList $obj] {
                            $pin saveGenericAssertion $command ""
                            release $pin
                        }
                        release $obj
                    }
                    "NInstS" {
                        set pin0 [$obj pin 0]
                        if {[rt::typeOf $pin0] eq "NPinS"} {
                            $pin0 saveGenericAssertionOnInst $command ""
                        }
                        release $obj
                    }
                    default {
                        set sdcCommand "$command [getObjListRef $obj]"
                        $rt::db saveConstraint $sdcCommand
                        release $obj
                    }
                }
	    }
        }
	set_required_time  { 
	    ####################### an SDC extension #######################
	    supported opt {-add_delay -clock -clock_fall -rise -fall -min -max delay_value port_pin_list} $command
	    set add  [info exist opt(-add_delay)]
	    set clk  [getClockInCurrentMode $opt(-clock)]
	    if {$clk == "NULL"} {
		return -code error "Clock $opt(-clock) not yet defined"
	    }
	    set clkf [info exist opt(-clock_fall)]
	    set rise [info exist opt(-rise)]
	    set fall [info exist opt(-fall)]
	    set dly  [rfTime $rise $fall $opt(delay_value)]
            set min [info exist opt(-min)]
            set max [info exist opt(-max)]
            set assCat "userImpl"
            if {$min && !$max} {
                set assCat "userIgnore"
            }
	    foreach pin [pinList $opt(port_pin_list)] {
# 		puts "$pin setRequiredTime $clk $dly"
		$pin setRequiredTime $add $clk $clkf $dly $assCat $min $max
		release $pin
	    }
	    $clk -delete
	}
	set_route_layer  { 
	    ################################################################
	    supported opt {
		-layer
		port_pin_list
	    } $command
	    if [info exist opt(-layer)] {
		set layer $opt(-layer)
	    } else {
		return
	    }
            set assCat "intAss"
	    set genomesToo 0
	    set pushToDrivers 2
	    set otherLoads false
	    set pinList [pinList $opt(port_pin_list) {} $genomesToo $pushToDrivers otherLoads]
	    foreach pin $pinList {
		$pin setRouteLayer $layer
		release $pin
	    }
	}
	set_timing_derate {
	    ################################################################
	    supported opt {-cell_delay -net_delay -clock -data -early -late -min -max -cell_check derate_value object_list} $command
	    set cell  [info exist opt(-cell_delay)]
	    set net   [info exist opt(-net_delay)]

            set flagOpts [list {-min} {-max} {-early} {-late} {-clock} {-data} {-net_delay} {-cell_delay} {-cell_check}]
            set commandOpts ""
            foreach arg $flagOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg"
                }
            }

            if {[info exists opt(object_list)]} {
                # OBJS = cells/insts 
                foreach obj $opt(object_list) {
                    switch -- [rt::typeOf $obj] {
                        "NInstS" {
                            set pin0 [$obj pin 0]
                            if {[rt::typeOf $pin0] eq "NPinS"} {
                                $pin0 saveGenericAssertionOnInst $command $commandOpts $opt(derate_value)
                            }
                            release $obj
                        }
                        default {
                            set sdcCommand "$command $commandOpts $opt(derate_value) [getObjListRef $obj]"
                            $rt::db saveConstraint $sdcCommand
                        }
                    }
                }
            } else {
                set sdcCommand "$command $commandOpts $opt(derate_value)"
                $rt::db saveConstraint $sdcCommand
            }
            set ignoredOptions ""
            if {[info exists opt(-min)]} {
                set ignoredOptions "$ignoredOptions -min"
            }
            if {[info exists opt(-clock)]} {
                set ignoredOptions "$ignoredOptions -clock"
            }
            if {[info exists opt(-early)]} {
                set ignoredOptions "$ignoredOptions -early"
            }
            if {[info exists opt(-cell_check)]} {
                set ignoredOptions "$ignoredOptions -cell_check"
            }
            if {[info exists opt(object_list)]} {
                set notSupported 1

                set numObjs [llength [utils::flatList $opt(object_list)]]
                if {$numObjs == 1} {
                    set obj [lindex [utils::flatList $opt(object_list)] 0]
                    if {[rt::typeOf $obj] eq "NRealModS" && $obj eq [[rt::design] topModule]} {
                        set notSupported 0
                    }
                }

                if {$notSupported} {                
                    set ignoredOptions "$ignoredOptions object_list"
                }
            }
            if {$ignoredOptions ne ""} {
                ignored_command "$command $ignoredOptions"
                return
            }
	    $rt::db setTimingDerate $cell $net $opt(derate_value)
	    if { ($cell != "NULL" || $net == "NULL") && [$rt::db topDesign] != "NULL" } {
		[rt::design] resetTiming
	    }
	}
	set_timing_mode {
	    ################################################################
	    supported opt {value} $command
	    rt::design setTimingMode $opt(value)
	}
	set_max_time_borrow {
	    ################ not supported yet #############################
            ignored_command $command

            # OBJS = pins/clocks/latch cells
            foreach obj $opt(object_list) {
                switch -- [rt::typeOf $obj] {
                    "NPinS" {
                        foreach pin [pinList $obj] {
                            $pin saveTimingAssertion $command "" [time $opt(delay_value)]
                            release $pin
                        }
                        release $obj
                    }
                    "NInstS" {
                        set pin0 [$obj pin 0]
                        if {[rt::typeOf $pin0] eq "NPinS"} {
                            $pin0 saveTimingAssertionOnInst $command "" [time $opt(delay_value)]
                        }
                        release $obj
                    }
                    default {
                        set sdcCommand "$command [getSdcTime [time $opt(delay_value)]] [getObjListRef $obj]"
                        $rt::db saveConstraint $sdcCommand
                        release $obj
                    }
                }
            }
	}
	set_unit  -
	set_units {
	    ################################################################
	    if [info exist opt(-capacitance)] {
		global sdcrt::capUnit
		switch -- $opt(-capacitance) {
		    "fF"     - 
		    "ff"     { 
			set capUnit 0.001 
		    }
		    "pF"     - 
		    "pf"     - 
		    "1000fF" -
		    "1000ff" { 
			set capUnit 1 
		    }
		    default  { 
			warning "unknown value '$opt(-capacitance)' for '$command -capacitance'"
			ignored_command "$command -capacitance $opt(-capacitance)" 
		    }
		}
	    }
	    if [info exist opt(-time)] {
		global sdcrt::timeUnit
		switch -- $opt(-time) {
		    "ps"     {
			set timeUnit 1 
                        rt::UParam_set time_units_for_sdc "ps"
		    }
		    "ns"     - 
		    "1000ps" { 
			set timeUnit 1000 
		    }
		    default  { 
			warning "unknown value '$opt(-time)' for '$command -time'"
			ignored_command "$command -time $opt(-time)" 
		    }
		}
	    }
            set sdcCommand "set_units -time [rt::UParam_get time_units_for_sdc rc] -capacitance pf" ;# defaults
            foreach arg [array names opt] {
                if {$arg eq "-time" || $arg eq "-capacitance"} {
                    continue
                }
                set sdcCommand "$sdcCommand $arg $opt($arg)"
            }
            # OBJS = NONE
            $rt::db saveConstraint $sdcCommand
	}
        set_resistance -
        set_wire_load_min_block_size -
        set_wire_load_mode -
        set_wire_load_model -
        set_wire_load_selection_group {
            ignored_command $command

	    foreach nm [array names opt] {
		foreach obj [utils::flatList $opt($nm)] {
		    release $obj
		}
	    }
            # not needed post synthesis
        }
        set_data_check {
            ignored_command $command

            setException $command opt
	    foreach nm [array names opt] {
		foreach obj [utils::flatList $opt($nm)] {
		    release $obj
		}
	    }
        }
        set_max_dynamic_power {
            ignored_command $command

            set sdcCommand "set_max_dynamic_power $opt(power_value)"
	    if {[info exists opt(-unit)]} {
                set sdcCommand "$sdcCommand -unit $opt(-unit)"
            }
            # OBJS = none
            $rt::db saveConstraint $sdcCommand
        }
        set_max_leakage_power {
            ignored_command $command

            set sdcCommand "set_max_leakage_power $opt(power_value)"
	    if {[info exists opt(-unit)]} {
                set sdcCommand "$sdcCommand -unit $opt(-unit)"
            }
            # OBJS = none
            $rt::db saveConstraint $sdcCommand
        }
        create_voltage_area {
            ignored_command $command

            set commandOpts "-name $opt(-name)"
            set listOpts [list {-coordinate} {-guard_band_x} {-guard_band_y}]
            foreach arg $listOpts {
                if {[info exists opt($arg)]} {
                    set commandOpts "$commandOpts $arg \{$opt($arg)\}"
                }
            }
            # OBJS = cells
            foreach obj $opt(cell_list) {
                switch -- [rt::typeOf $obj] {
                    "NInstS" {
                        set pin0 [$obj pin 0]
                        if {[rt::typeOf $pin0] eq "NPinS"} {
                            $pin0 saveGenericAssertionOnInst $command $commandOpts
                        }
                        release $obj
                    }
                    default {
                        set commandOpts "$commandOpts [getObjListRef $obj]"
                        set sdcCommand "$command $commandOpts"
                        $rt::db saveConstraint $sdcCommand
                    }
                }
            }
        }
        set_level_shifter_strategy {
            ignored_command $command

            # OBJS = none
            set sdcCommand "set_level_shifter_strategy -rule $opt(-rule)"
            $rt::db saveConstraint $sdcCommand
        }
        set_level_shifter_threshold {
            ignored_command $command

            set sdcCommand "set_level_shifter_threshold -voltage $opt(-voltage)"
            if {[info exists opt(-percent)]} {
                set sdcCommand "$sdcCommand -percent $opt(-percent)"
            }
            # OBJS = none
            $rt::db saveConstraint $sdcCommand
        }
        set_min_porosity {
            ignored_command $command

            # OBJS = designs
            set sdcCommand "set_min_porosity $opt(porosity_value) [getObjListRef $opt(object_list)]"
            $rt::db saveConstraint $sdcCommand

            foreach obj $opt(object_list) {
                release $obj
            }
        }
	foreach_in_collection {
	    ################ foreach_in_collection #########################
	    upvar 4 $opt(var) v
	    foreach v $opt(coll_list) {uplevel 4 $opt(commands)}
	}
	remove_from_collection {
	    ################ remove_from_collection ########################
	    return [sdcrt::removeFromCollection  $opt(coll_list) $opt(remo_list)]
	}
	sizeof_collection {
	    ################ sizeof_collection #############################
	    return [llength $opt(coll_list)]
	}
	index_collection {
	    ################ index_collection ##############################
	    return [lindex $opt(coll_list) $opt(index)]
	}
        add_to_collection {
            ################ add_to_collection #############################
            set uniq [info exists opt(-unique)]
            return [sdcrt::addToCollection $opt(coll_list) $opt(obj_list) $uniq]
        }
        append_to_collection {
            ################ append_to_collection ##########################
            upvar 4 $opt(var) v
            foreach el [utils::flatList $opt(obj_list)] {
                lappend v $el
            }
        }
        copy_collection {
            ################ copy_to_collection ############################
            return [utils::flatList $opt(coll_list)]
	}
        compare_collections {
            ################ compare_collections ############################
            if {[info exists opt(-order_dependent)]} {
                set l1 [utils::flatList $opt(coll_list1)]
                set l2 [utils::flatList $opt(coll_list2)]
            } else {
                set l1 [lsort [utils::flatList $opt(coll_list1)]]
		set l2 [lsort [utils::flatList $opt(coll_list2)]]
            }

            set len1 [llength $l1]
            set len2 [llength $l2]
            if {$len1 != $len2} {
                return -1
            } else {
                for {set i 0} {$i < $len1} {incr i} {
                    if {[lindex $l1 $i] != [lindex $l2 $i]} {
                        return -1
                    }
                }
	    }
            return 0
        }
	sort_collection {
            ################ sort_collection ##############################
            supported opt {coll_list -descending} $command
            if {[info exists opt(-descending)]} {
	        return [lsort -decreasing -command sdcrt::cmpObjByName $opt(coll_list)]
            } else {
                return [lsort -command sdcrt::cmpObjByName $opt(coll_list)]
            }
	}
        sizeof {
	    ################ sizeof ########################################
	    return [llength $opt(coll_list)]
        }
	get_attribute {
	    ################ get_attribute #################################
            set quiet 0
            if {[info exists opt(-quiet)]} {
                set quiet 1
            }
            set objClass ""
            if {[info exists opt(-class)]} {
                set objClass $opt(-class)
            }
	    return [rtdc::getAttribute $quiet $objClass $opt(object) $opt(attribute)]
	}
	set_attribute {
	    ################ set_attribute #################################
            set quiet 0
            if {[info exists opt(-quiet)]} {
                set quiet 1
            }
            set objClass ""
            if {[info exists opt(-class)]} {
                set objClass $opt(-class)
            }
	    return [rtdc::setAttribute $quiet $objClass $opt(object) $opt(attribute) $opt(value)]
	}
        set_property { 
            ################ alias to set_attribute ########################
            set quiet 0
            if { [info exists opt(-quiet)]} {
                set quiet 1
            }
            return [rtdc::setProperty $quiet $opt(attribute) $opt(value) $opt(object)]
        }
        get_property { 
            ################ alias to get_attribute ########################
            set quiet 0
            if {[info exists opt(-quiet)]} {
                set quiet 1
            }
            set objClass ""
            if {[info exists opt(-class)]} {
                set objClass $opt(-class)
            }
	    return [rtdc::getAttribute $quiet $objClass $opt(object) $opt(attribute)]
        }
        filter {
	    ################ filter_collection #############################
            set isRegexp [info exist opt(-regexp)]
            set objList  [utils::flatList $opt(coll_list)]

            set objType "NULL"
            if {[llength $objList] > 0} {
                set objType [rt::typeOf [lindex $objList 0]]
            }

            set filteredList {}
            switch -- $objType {
		# TODO Add -nocase to all filter APIs
                "NInstS" {
                    set filteredList [[sdcrt::getCurrMod] filterInstanceCollection $objList $isRegexp $opt(expression)]
                }
                "NPinS" {
                    set filteredList [[sdcrt::getCurrMod] filterPinCollection $objList $isRegexp 0 $opt(expression)]
                }
                "NNetS" {
                    set filteredList [[sdcrt::getCurrMod] filterNetCollection $objList $isRegexp $opt(expression)]
                }
                default {
                    set filteredList [getFilteredList $opt(expression) $isRegexp $objList]
                }
            }
            return $filteredList
        }
	remove_input_delay {
	    if {[info exists opt(-clock)] || [info exists opt(-clock_fall)] ||
		[info exists opt(-level_sensitive)] ||
		[info exists opt(-rise)] || [info exists opt(-fall)] ||
		[info exists opt(-max)] || [info exists opt(-min)]} {
		ignored_command $command opt
		return
	    }
	    return [rtdc::removeInputDelay $opt(pin_list)]
	}
	remove_input_transition {
	    return [rtdc::removeInputTransition $opt(pin_list)]
	}
	remove_driving_cell {
	    return [rtdc::removeDrivingCell $opt(pin_list)]
	}
	remove_output_delay {
	    if {[info exists opt(-clock)] || [info exists opt(-clock_fall)] ||
		[info exists opt(-level_sensitive)] ||
		[info exists opt(-rise)] || [info exists opt(-fall)] ||
		[info exists opt(-max)] || [info exists opt(-min)]} {
		ignored_command $command opt
		return
	    }
	    return [rtdc::removeOutputDelay $opt(pin_list)]
	}
	remove_load {
	    return [rtdc::removeLoad $opt(pin_list)]
	}
        get_timing_paths {
            supported opt {-from -rise_from -fall_from 
                           -through -rise_through -fall_through
                           -to -rise_to -fall_to -group -max_paths} $command

	    set emptyList false
            set exception [setException $command opt emptyList]
	    if {$emptyList} {
		return
	    }

            set groupName ""
            if {[info exists opt(-group)]} {
                set groupName $opt(-group)
            }

            set maxPaths 1
            if {[info exists opt(-max_paths)]} {
                set maxPaths $opt(-max_paths)
            }

            return [[rt::design] getTimingPaths $groupName $exception $maxPaths]
        }
        all_dsps  {
            return [rt::get_cells -hier -filter {ref_name == "DSP48E1"}]
        }
        all_rams  {
            return [rt::get_cells -hier -filter {ref_name =~ "*RAM*"}]
        }

 	default {
	    ################ unknown command ###############################
            ignored_command $command

	    foreach nm [array names opt] {
		foreach obj [utils::flatList $opt($nm)] {
		    release $obj
		}
	    }
 	}
    }
}

if {[info exist sdcrt::coreparsed] == 0} {

    if {$::rt_tool_name != "realTimeFpga"} {
	set rt::fname $env(RT_LIBPATH)/share/tcl/sdcparsercore.odb
    } else {
	set rt::fname $env(RT_TCL_PATH)/sdcparsercore.tcl 
    }

    source $rt::fname
    set sdcrt::coreparsed 1
}

sdc::register_callback sdcrt::profile_and_callback

# some not so SDC commands ...
namespace eval rt {
proc get_object_name {args} {
    get_object_names $args
}

proc get_object_names {args} {
    set names {}
    foreach obj [utils::flatList $args] {
	lappend names [sdcrt::objectName $obj]
    }
    if {[llength $names] == 1} {
        return [lindex $names 0]
    } else {
    return $names
    }
}

proc getenv                 {arg }      {global env; return $env($arg)}
proc set_mode               {args}      {puts "WARNING: SDC (yet) unsupported command 'set_mode' ignored"}
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
