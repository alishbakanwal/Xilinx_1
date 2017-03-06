namespace eval rtedit {
    proc createInst {instList reference_name} {
        set reference_name [lindex $reference_name 0]
        if {$sdcrt::currMod eq "NULL"} {
            puts "Error: Current design is not defined"
            return -code error
        }

        # get reference
        set des [rt::design]
        set ref "NULL"
        set modRefs [$des getModules $reference_name 1 0] ;# match exact name
        if {$modRefs ne "NULL" && [$modRefs size] > 0} {
            if {[$modRefs size] > 1} {
                puts "Error: Multiple references found for \'$reference_name\'. Please specify a unique reference name."
                rt::delete_NRealModList $modRefs
                return -code error
            }
            set ref [[$modRefs begin] object]
            rt::delete_NRealModList $modRefs
        }
        if {$ref eq "NULL"} {
            set ref [rt::getLibCell $reference_name]

            if {$ref eq "NULL"} {
                puts "Error: No design or library cell named \'$reference_name\' found"
                return -code error
            }

        }

        global UNM_sdc
        foreach instName $instList {
            if {[regexp {(.*)/([^/]+)} $instName match hierInst name]} {
                # check for unique instance name
                set checkInst [[sdcrt::getCurrMod] findInstance $instName $UNM_sdc]
                if {$checkInst ne "NULL"} {
                    puts "Error: Instance name \'$instName\' is not unique"
                    return -code error
                }

                # hierarchical instance name
                set inst [[sdcrt::getCurrMod] findInstance $hierInst $UNM_sdc]
                if {$inst eq "NULL"} {
                    puts "Error: Could not find instance \'$hierInst\'"
                    return -code error
                }

                # uniquify genome inst
                set ginst [[$inst design] genomeInstance]
                if {$ginst ne "NULL"} {
                    [rt::design] uniquifyGenomeInst $ginst
                }

                set mod [$inst isRealModule]
                if {$mod eq "NULL"} {
                    puts "Error: Instance \'[$inst fullName $UNM_sdc]\' is not hierarchical"
                    if {$ginst ne "NULL"} {
                        $ginst releaseDesign false
                    }
                    return -code error
                }

                set newInst [$mod newInstance $ref $name]

                if {$ginst ne "NULL"} {
                    [$ginst isGenome] releaseDesign true
                }

                if {$newInst eq "NULL"} {
                    puts "Error: Could not create cell \'$instName\'"
                    return -code error
                } else {
                    puts "Created instance \'$name\' in design \'[$mod name $UNM_sdc]'"
                }
            } else {
                # check for unique instance name
                set checkInst [[sdcrt::getCurrMod] findInstance $instName $UNM_sdc]
                if {$checkInst ne "NULL"} {
                    puts "Error: Instance name \'$instName\' is not unique"
                    return -code error
                }

                # instance in current design
                set newInst [[sdcrt::getCurrMod] newInstance $ref $instName]
                if {$newInst eq "NULL"} {
                    puts "Error: Could not create cell \'$instName\'"
                    return -code error
                } else {
                    puts "Created instance \'$instName\' in design \'[[sdcrt::getCurrMod] name $UNM_sdc]'"
                }
            }
        }
        return 0
    }

    proc createNet {netList} {
        if {$sdcrt::currMod eq "NULL"} {
            puts "Error: Current design is not defined"
            return -code error
        }

        global UNM_sdc
        foreach netName $netList {
            if {[regexp {(.*)/([^/]+)} $netName match hierInst name]} {
                # check for unique net name
                set checkNet [[sdcrt::getCurrMod] findNet $netName $UNM_sdc]
                if {$checkNet ne "NULL"} {
                    puts "Error: Net name \'$netName\' is not unique"
                    return -code error
                }

                # hierarchical net
                set inst [[sdcrt::getCurrMod] findInstance $hierInst $UNM_sdc]
                if {$inst eq "NULL"} {
                    puts "Error: Could not find instance \'$hierInst\'"
                    return -code error
                }

                # uniquify genome inst
                set ginst [[$inst design] genomeInstance]
                if {$ginst ne "NULL"} {
                    [rt::design] uniquifyGenomeInst $ginst
                }

                set mod [$inst isRealModule]
                if {$mod eq "NULL"} {
                    puts "Error: Instance \'[$inst fullName $UNM_sdc]\' is not hierarchical"
                    if {$ginst ne "NULL"} {
                        [$ginst isGenome] releaseDesign false
                    }
                    return -code error
                }

                if {[$mod parentCount] > 1} {
                    puts "Error: Parent instance \'[$inst fullName $UNM_sdc]\' is not unique"
                    if {$ginst ne "NULL"} {
                        [$ginst isGenome] releaseDesign false
                    }
                    return -code error
                }

                set newNet [$mod newNet $name]

                if {$ginst ne "NULL"} {
                    [$ginst isGenome] releaseDesign true
                }

                if {$newNet eq "NULL"} {
                    puts "Error: Could not create net \'$netName\'"
                    return -code error
                }
            } else {
                # check for unique net name
                set checkNet [[sdcrt::getCurrMod] findNet $netName $UNM_sdc]
                if {$checkNet ne "NULL"} {
                    puts "Error: Net name \'$netName\' is not unique"
                    return -code error
                }

                # net in current design
                set newNet [[sdcrt::getCurrMod] newNet $netName]
                if {$newNet eq "NULL"} {
                    puts "Error: Could not create net \'$netName\'"
                    return -code error
                }
            }
        }
        return 0
    }

    proc createPort {portList direction} {
        if {$sdcrt::currMod eq "NULL"} {
            puts "Error: Current design is not defined"
            return -code error
        }

        if {$direction eq "in"} {
            set portDir "NDirRawInput"
        } elseif {$direction eq "inout"} {
            set portDir "NDirRawBidir"
        } elseif {$direction eq "out"} {
            set portDir "NDirRawOutput"
        } else {
            puts "Error: Invalid direction \'$direction\'"
            return -code error
        }

        global UNM_sdc
        foreach portName $portList {
            if {[regexp {(.*)/([^/]+)} $portName match hierInst name]} {
                # hierarchical port
                set inst [[sdcrt::getCurrMod] findInstance $hierInst $UNM_sdc]
                if {$inst eq "NULL"} {
                    puts "Error: Could not find instance \'$hierInst\'"
                    return -code error
                }

                # uniquify genome inst
                set ginst [[$inst design] genomeInstance]
                if {$ginst ne "NULL"} {
                    [rt::design] uniquifyGenomeInst $ginst
                }

                set mod [$inst isRealModule]
                if {$mod eq "NULL"} {
                    puts "Error: Instance \'[$inst fullName $UNM_sdc]\' is not hierarchical"
                    if {$ginst ne "NULL"} {
                        [$ginst isGenome] releaseDesign false
                    }
                    return -code error
                }

                # check for unique port name
                set checkPort [$mod findPin $name $UNM_sdc]
                if {$checkPort ne "NULL"} {
                    puts "Error: Port name \'$portName\' is not unique"
                    if {$ginst ne "NULL"} {
                        [$ginst isGenome] releaseDesign false
                    }
                    return -code error
                }

                set newPortIter [$mod addPortIncr $name $portDir 0]

                if {$ginst ne "NULL"} {
                    [$ginst isGenome] releaseDesign true
                }

                if {$newPortIter eq "NULL"} {
                    puts "Error: Could not create port \'$portName\'"
                    return -code error
                } else {
                    puts "Created port \'$name\' in design \'[$mod name $UNM_sdc]'"
                }
            } else {
                # check for unique port name
                set checkPort [[sdcrt::getCurrMod] findPin $portName $UNM_sdc]
                if {$checkPort ne "NULL"} {
                    puts "Error: Port name \'$portName\' is not unique"
                    return -code error
                }

                # port in current design
                set newPortIter [[sdcrt::getCurrMod] addPortIncr $portName $portDir 0]
                if {$newPortIter eq "NULL"} {
                    puts "Error: Could not create port \'$portName\'"
                    return -code error
                } else {
                    puts "Created port \'$portName\' in design \'[[sdcrt::getCurrMod] name $UNM_sdc]'"
                }
            }
        }
        return 0
    }

    proc connectNet {netName portPinList} {
        set netName [lindex $netName 0]

        if {$sdcrt::currMod eq "NULL"} {
            puts "Error: Current design is not defined"
            return -code error
        }

        global UNM_sdc
        # find the net in current design
        set tNet [[sdcrt::getCurrMod] findNet $netName $UNM_sdc]
        if {$tNet eq "NULL"} {
            puts "Error: Could not find net \'$netName\' in current design"
            return -code error
        }

        set firstPin [$tNet firstPin]

        foreach obj $portPinList {

            if {[rt::typeOf $obj] eq "NULL"} {
                set pinName $obj
                set obj [[sdcrt::getCurrMod] findPin $pinName $UNM_sdc]
                if {$obj eq "NULL"} {
                    puts "Error: Could not find pin \'$pinName\' in connect_net"
                    return -code error
                }
            } elseif {[rt::typeOf $obj] ne "NPinS"} {
                puts "Error: Incorrect object type \'[rt::typeOf $obj]\' in connect_net"
                return -code error
            }

            set checkNet [$obj net]
            if {$checkNet ne "NULL"} {
                puts "Error: Object \'[$obj fullName $UNM_sdc]\' is already connected to net \'[$checkNet fullName $UNM_sdc]'"
                return -code error
            }

            # should be at the same hierarchical level as the net
            if {$firstPin ne "NULL"} {
                set thruGenome 0

                set inst1 [$firstPin ownerInstance]

                if {$inst1 ne "NULL"} {
                    set pin1UserMod [[$inst1 realModule] userModule]
                } else {
                    set pin1UserMod [[$firstPin ownerModule] userModule]
                }

                if {$inst1 ne "NULL"} {
                    set ginst [[$inst1 design] genomeInstance]
                    while {$ginst ne "NULL"} {
                        set thruGenome 1

                        set inst1 $ginst
                        if {$pin1UserMod eq "NULL"} {
                            set pin1UserMod [[$inst1 realModule] userModule]
                        }
                        set ginst [[$inst1 design] genomeInstance]
                    }
                }

		set inst2 [$obj ownerInstance]

                if {$inst2 ne "NULL"} {
                    set pin2UserMod [[$inst2 realModule] userModule]
                } else {
                    set pin2UserMod [[$obj ownerModule] userModule]
                }

                if {$inst2 ne "NULL"} {
                    set ginst [[$inst2 design] genomeInstance]
                    while {$ginst ne "NULL"} {
                        set thruGenome 1

                        set inst2 $ginst
                        if {$pin2UserMod eq "NULL"} {
                            set pin2UserMod [[$inst2 realModule] userModule]
                        }
                        set ginst [[$inst2 design] genomeInstance]
                    }
                }

                if {$pin1UserMod ne $pin2UserMod} {
                     puts "Error: Net '$netName' is not at the same hierarchical level as \'[$obj fullName $UNM_sdc]\'"
                     return -code error
                }

                if {$thruGenome == 1} {
                    # uniquify the genome instances before connecting
                    set inst1 [$firstPin ownerInstance]
                    if {$inst1 ne "NULL"} {
                        set ginst [[$inst1 design] genomeInstance]
                        while {$ginst ne "NULL"} {
                            [rt::design] uniquifyGenomeInst $ginst
                            set inst1 $ginst
                            set ginst [[$inst1 design] genomeInstance]
                        }
                    }
                    
                    set inst2 [$obj ownerInstance]
                    if {$inst2 ne "NULL"} {
                        set ginst [[$inst2 design] genomeInstance]
                        while {$ginst ne "NULL"} {
                            [rt::design] uniquifyGenomeInst $ginst
                            set inst2 $ginst
                            set ginst [[$inst2 design] genomeInstance]
                        }
                    }

                    #rt::connectPins $firstPin $obj 0 "" "" ;# default in/out port prefix
		    $firstPin connectHierSink $obj false "" ""

                } else {
                    $obj connect $tNet
                }
            } else {
                set des1 [[sdcrt::getCurrMod] design]
                set des2 [$obj design]
                if {$des1 ne $des2} {
                     puts "Error: Net '$netName' is not at the same hierarchical level as \'[$obj fullName $UNM_sdc]\'"
                     return -code error
                }

                set ginst [[$obj design] genomeInstance]
                if {$ginst ne "NULL"} {
                    [rt::design] uniquifyGenomeInst $ginst
                }

                $obj connect $tNet
                
                if {$ginst ne "NULL"} {
                    [$ginst isGenome] releaseDesign true
                }
            }

	    if {[$obj net] eq "NULL"} {
                puts "Error: Could not connect net \'$netName\'"
                return -code error
            }

            if {[$obj isConnected]} {
                # is not connected to constant/dangling
                set pin [$tNet firstPin]
                while {$pin ne "NULL"} {
                    set nextPin [$pin nextPinOnNet]

                    set ownerMod [$pin ownerModule]
                    if {$ownerMod ne "NULL"} {
                        set pinIdx [$pin index]
                        $ownerMod resetPinConstant $pinIdx
                        $ownerMod resetPinDontCare $pinIdx
                    }

                    set pin $nextPin
                }
            }
            set inst [$obj ownerInstance]
            if {$inst eq "NULL"} {
                set objName [$obj name $UNM_sdc]
            } else {
                set objName "[$inst name $UNM_sdc]/[$obj name $UNM_sdc]"
            }
            puts "Connected net \'[$tNet name $UNM_sdc]\' to \'$objName\'"
        }

        return 0
    }

    proc disconnectNet {netName all portPinList} {
        set netName [lindex $netName 0]

        if {$sdcrt::currMod eq "NULL"} {
            puts "Error: Current design is not defined"
            return -code error
        }

        global UNM_sdc
        # find the net in current design
        if {[rt::typeOf $netName] eq "NNetS"} {
            set tNet $netName
        } else {
            set tNet [[sdcrt::getCurrMod] findNet $netName $UNM_sdc]
        }
        if {$tNet eq "NULL"} {
            puts "Error: Could not find net \'$netName\' in current design"
            return -code error
        }

        if {$all} {
            set pin [$tNet firstPin]
            while {$pin ne "NULL"} {
                set nextPin [$pin nextPinOnNet]

                # get port/pin name
                set inst [$pin ownerInstance]
                if {$inst eq "NULL"} {
                    set objName [$pin name $UNM_sdc]
                } else {
		    set objName "[$inst name $UNM_sdc]/[$pin name $UNM_sdc]"
		}

                set ginst [[$pin design] genomeInstance]
                if {$ginst ne "NULL"} {
                    [rt::design] uniquifyGenomeInst $ginst
                }

		puts "Disconnected net \'[$tNet name $UNM_sdc]\' from \'$objName\'"
                $pin disconnect
                if {$ginst ne "NULL"} {
                    [$ginst isGenome] releaseDesign true
                }

                set pin $nextPin
	    }
	} else {
            if {[llength $portPinList] == 0} {
                puts "Error: No port/pin list or -all specified with disconnect_net"
                return -code error
            }
	    foreach obj $portPinList {
                if {[rt::typeOf $obj] eq "NULL"} {
                    set pinName $obj
                    set obj [[sdcrt::getCurrMod] findPin $pinName $UNM_sdc]
                    if {$obj eq "NULL"} {
                        puts "Error: Could not find pin \'$pinName\' in disconnect_net"
                        return -code error
                    }
                } elseif {[rt::typeOf $obj] ne "NPinS"} {
                    puts "Error: Incorrect object type \'[rt::typeOf $obj]\' in disconnect_net"
                    return -code error
                }
                # get port/pin name
		set inst [$obj ownerInstance]
		if {$inst eq "NULL"} {
		    set objName [$obj name $UNM_sdc]
		} else {
		    set objName "[$inst name $UNM_sdc]/[$obj name $UNM_sdc]"
		}
#               TODO: match tNet against all net segments of the pin
# 		if {[$obj net] ne $tNet} {
# 		    continue ;# not connected to specified net
# 		}

                set ginst [[$obj design] genomeInstance]
                if {$ginst ne "NULL"} {
                    [rt::design] uniquifyGenomeInst $ginst
                }

                $obj disconnect
		puts "Disconnected net \'[$tNet name $UNM_sdc]\' from \'$objName\'"
                if {$ginst ne "NULL"} {
                    [$ginst isGenome] releaseDesign true
                }
	    }
	}
    }

    proc deleteInst {instList} {
        global UNM_sdc
        set delList {}
        foreach inst $instList {
            if {[rt::typeOf $inst] eq "NInstS"} {
                lappend delList $inst
            } else {
		set matches [[sdcrt::getCurrMod] findInstances $inst $UNM_sdc]
		if {$matches == {}} {
                    puts "Error: no cell(s) found for \'$inst\'"
                    return 0
                } else {
                    lappend delList $matches
                }
            }
	}
        foreach inst [utils::flatList $delList] {
            [$inst baseModule] delInstance $inst
        }
        return 1
    }

    proc connectPins {from to invert inPrefix outPrefix portName verbose} {
	if {$from == "" || $to == ""} {
	    puts "Error: must specify -from and -to pin names"
	    return
	}

	if {$portName ne ""} {
	    if {[llength $inPrefix] || [llength $outPrefix]} {
		puts "Setting in_prefix and out_prefix to $portName"
	    }
	    set inPrefix $portName
	    set outPrefix $portName
	}

	set fCopy 0
	if {[rt::typeOf $from] == "NPinS"} {
	    set fromPin $from
	    set fCopy 1
	} else {
	    set fromPin [[[rt::design] topModule] findPin $from]
	}

	set tCopy 0
	if {[rt::typeOf $to] == "NPinS"} {
	    set toPin $to
	    set tCopy 1
	} else {
	    set toPin [[[rt::design] topModule] findPin $to]
	}

	if {$fromPin == "NULL"} {
	    puts "Error: could not find -from pin '$from'"
	    return
	}
	if {$toPin == "NULL"} {
	    puts "Error: could not find -to pin '$to'"
	    return
	}
	if {$inPrefix == ""} {
	    set inPrefix "iPin"
	}
	if {$outPrefix == ""} {
	    set outPrefix "oPin"
	}

	#puts "connecting $fromPin ($from) and $toPin ($to) with $invert $inPrefix $outPrefix"

	$fromPin connectHierSink $toPin $invert $inPrefix $outPrefix 
	if {!$fCopy} {
	    [$fromPin design] release
	}
	if {!$tCopy} {
	    [$toPin design] release
	}

	# next stmtnt should be bogus!!
	#$fromPin -delete
	#$toPin -delete
    }
}

# Edit commands
cli::addCommand create_cell           {rtedit::createInst}    {string} {string}
cli::addCommand create_net            {rtedit::createNet}     {string}
cli::addCommand create_port           {rtedit::createPort}    {string} {string direction "in"}
cli::addCommand connect_net           {rtedit::connectNet}    {string} {string}
cli::addCommand disconnect_net        {rtedit::disconnectNet} {string} {boolean all false} {?string}
cli::addCommand remove_cell           {rtedit::deleteInst}    {string}

# To be removed??
cli::addCommand connect_pin           {rtedit::connectPins}   {string from} {string to} {boolean invert} {string in_prefix} {string out_prefix} {string port_name} {#boolean verbose}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
