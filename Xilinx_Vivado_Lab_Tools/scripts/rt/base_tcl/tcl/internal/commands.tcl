# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval rt {

    proc disableScanInTimingArcs {} {
	set cells [$rt::db findCells *]
	if {[$cells size] > 0} {
	    for {set i [$cells begin]} {[$i ok]} {$i incr} {
		set cell [[$i object] isCell]
		if {[$cell isScan]} {
		    set si [$cell scanInPinIndex]
		    if {$si >= 0} {
			puts "Disabling Arcs to [$cell name].$si" 
			$cell disableTiming -1 $si
		    }
		}
	    }
	}
    }

    #moved from ui/tcl/commands.tcl, subject to review/removal
    proc createFence {name inst left bottom right top site} {
	variable UNM_sdc

	if { $left == "" } {
	    set left 0
	}
	if { $bottom == "" } {
	    set bottom 0
	}
	if { $right == "" } {
	    set right 0
	}
	if { $top == "" } {
	    set top 0
	}

	set topDes [rt::design]
	set topMod [$topDes topModule]
	set region [$topDes createFence $name "" $left $bottom $right $top $site]
	foreach instNm $inst {
	    set instObjs [$topMod findInstances $instNm $UNM_sdc "false"]
	    foreach instObj $instObjs {
		$topDes assignToRegion $region $instObj 
	    }
	    release $instObjs
	}
    }
    
    proc addToTargetLib {nm targetLibNm} {
	set lib [$rt::db findLibrary $nm]
	if {$targetLibNm == ""} {
	    set targetLib [$rt::db findOrAddTargetLib "default"]
	} else {
	    set targetLib [$rt::db findOrAddTargetLib $targetLibNm]
	}
	$targetLib add $lib
    }

    proc checkTargetLibrary {autoDisable} {
	if {$autoDisable} {
	    set warnOnly false
	} else {
	    set warnOnly true
	}
	[$rt::db targetLib] removeSensitiveCells $warnOnly
    }

    proc pushParam {stack var val} {
	set oldVal [rt::getParam $var]
	set rc [rt::UParam_set $var $val]
	if {$rc != 1} {
	    return -code error
	}
	if {$stack != ""} {
	    upvar 2 $stack params
	    if {[info exist params($var)] == 0} {
		set params($var) $oldVal
	    }
	    return 
	}
	global pushedParams
	lappend pushedParams($var) $oldVal
    }

    proc popParam {stack var} {
	if {$stack == "true"} {
	    upvar 2 $var params
	    foreach var [array names params] {
		set oldVal $params($var)
		unset params($var)
		rt::UParam_set $var $oldVal
	    }
	    return
	}
	global pushedParams
	if {[info exist pushedParams($var)] == 0} {
	    return -code error "Parameter '$var' was not pushed"
	}
	set oldVal [lindex $pushedParams($var) end]
	if {[llength $pushedParams($var)] > 1} {
	    set pushedParams($var) [lrange $pushedParams($var) 0 end-1]
	    puts "new stack: \{$pushedParams($var)\}"
	} else {
	    unset pushedParams($var)
	}
	rt::UParam_set $var $oldVal
    }

    proc printStats {design module} {
	set des ""
	if {$design != ""} {
	    set des [$rt::db findDesign $design]
	    if {$des == ""} {
		return -code error
	    }
	}
	set mod ""
	if {$module != ""} {
	    if {$des != ""} {
		set mod [$des findModule $module]
	    } else {
		foreach des [$rt::db designs] {
		    set mod [$des findModule $module]
		    if {$mod != ""} {
			break
		    }
		}
	    }
	    if {$mod == ""} {
		return -code error
	    }
	}
	if {$mod != ""} {
	    $mod printStats
	} elseif {$des != ""} {
	    $des printStats
	} else {
          rt::UStatCpu_printStats
          rt::UMem_printStats 2
	}
    }

    proc printWorstSlacks {cnt stats ascii {genomes "false"} total {unconstrained false} {filename ""} } {
	set des [design]
	if {$stats == "false"} {
	    set totalSlack 0
	    if {$cnt == ""} {
		set cnt 10
	    }

            if {$filename != ""} {
              set fp [open $filename "w"]
            } else {
              set fp stdout
            }
	    set i 0
	    if {$genomes == "false"} {
		set j 1
		set sz [$des numPathGroups]
		for {} {$j < $sz} {incr j} {
		    set group [$des groupName $j]
		    set deps [$des detailedEndPoints $group "NULL"]
		    while {![$deps empty] && ($i < $cnt)} {
			set dep     [$deps pop]
			set slack   [$dep slack]
			set epNm    [$dep pin]
                        if {$unconstrained || [expr {$slack ne "<max>"} ] } {
                          puts $fp "      slack = $slack @ [incr i]th endpoint '$epNm'"
                        }
			set ws [string trimright $slack ps]
			if  [string is double $ws] {
			    set totalSlack [expr $totalSlack + $ws]
			}
		    }
		}
	    } else {
		foreach ep [$des endPoints $cnt] {
		    if {$i >= $cnt} {
			break
		    }
		    set slack [$ep endPointSlack]
		    set epNm  [$ep fullName]
                    if {$unconstrained || [expr {$slack ne "<max>"} ] } {
                      puts $fp "      slack = $slack @ [incr i]th endpoint '$epNm'"
                    }
		    set ws [string trimright $slack ps]
		    if  [string is double $ws] {
			set totalSlack [expr $totalSlack + $ws]
		    }
		}
	    }
	    if {$total == "true"} {
		puts $fp "Total Slack: $totalSlack"
	    }
            if {$filename != ""} {
              close $fp
            }
	} else {
	    set min   0
	    set max   0
	    set unc   0
	    foreach ep [$des endPoints 0] {
		set slack [string trimright [$ep endPointSlack] ps]
		if {$slack != "<max>"} {
		    if {$slack < $min} {set min $slack}
		    if {$slack > $max} {set max $slack}
		} else {
		    incr unc
		}
		if {$min < 0 && $max > [expr -$min/2]} {
		    set max [expr -$min/2]
		}
	    }
	    if {$min < 0 || $max > 0} {
		set unit   [expr ($max-$min)/40]
		set min    [expr floor($min/$unit)*$unit]
		set cmin   [expr $min+$unit]
		set peak   1
		set num    0
		set bar    0
		set maxbar 0
		foreach ep [$des endPoints 0] {
		    set slack [string trimright [$ep endPointSlack] ps]
		    if {$slack == "<max>"} {
			incr maxbar
		    } elseif {$slack <= $cmin} {
			incr bar
		    } else {
			if {$peak < $bar} {set peak $bar}
			set bars($num) $bar
			set range($num) $cmin
			while {$slack > $cmin} {
			    incr num
			    set bars($num) 0
			    set range($num) $cmin
			    set cmin [expr $cmin+$unit]
			}
			set bar 1
		    }
		}
		set bars($num) $bar
		set range($num) $cmin
		set neg 1
		if {$ascii == "false"} {
		    global env
		    set version 0.0
		    regexp {.\..} [exec gnuplot --version] version
		    set epFile $env(RT_REGRESS_TMP)/ep.data
		    set fp [open $epFile "w"]
		    puts $fp "set term x11"
		    puts $fp "set xrange \[$min:$range($num)+$unit\]"
		    puts $fp "set yrange \[0:$peak\]"
		    if {[expr $version >= 4.0]} {
			puts $fp "set style fill solid 1.0"
			puts $fp "set style fill solid border -1"
			puts $fp "plot '-' with boxes notitle, \\"
			puts $fp "     '-' with boxes notitle, \\"
			puts $fp "     '-' with boxes notitle"
		    } else {
			puts $fp "plot '-' with boxes, \\"
			puts $fp "     '-' with boxes, \\"
			puts $fp "     '-' with boxes"
		    }
		    for {set n 0} {$n <= $num} {incr n} {
			if {$neg && $range($n) > 0} {
			    set neg 0
			    if {$n == 0} {
				puts $fp "0 0 0"
			    }
			    puts $fp "end"
			}
			set x [expr $range($n) - $unit/2]
			puts $fp "$x $bars($n) $unit"
		    }
		    puts $fp "end"
		    set x [expr $range($num) + $unit/2]
		    puts $fp "$x $maxbar $unit"
		    puts $fp "end"
		    close $fp
		    exec gnuplot -persist -title "End Point Slack Histogram" $epFile
		} else {
		    set scale [expr $peak/80.0]
		    if {$scale < 1.0} {
			set scale 1
		    }
		    for {set n 0} {$n <= $num} {incr n} {
			if {$neg && $range($n) > 0} {
			    set neg 0
			    puts -nonewline "--------------:"
			    set sbar [expr $peak/$scale]
			    for {set b 0} {$b < $sbar} {incr b} {
				puts -nonewline "-"
			    }
			    puts ""
			}
			if {$n < $num} {
			    puts -nonewline "[format %7.0f $range($n)]"
			} else {
			    puts -nonewline "[format %7s "<unc>"]"
			}
			set bar $bars($n)
			puts -nonewline "[format %7s "($bar)"]:"
			set sbar [expr $bar/$scale]
			for {set b 0} {$b < $sbar} {incr b} {
			    puts -nonewline "#"
			}
			puts ""
		    }
		}
	    }
	}
    }

    proc reportTimingOld {stopAtGenomes fromPin thruPin toPin rise fall count} {
	if {$stopAtGenomes == "true"} {
	    set thruGenomes "false"
	} else {
	    set thruGenomes "true"
	}
	if {$fromPin != ""} {
	    set pinNm $fromPin
	    set thruPin true
	} elseif {$thruPin != ""} {
	    set pinNm $thruPin
	    set thruPin true
	} elseif {$toPin != ""} {
	    set pinNm $toPin
	    set thruPin false
	} else {
	    set pinNm ""
	}
	if {$pinNm != ""} {
	    set ti [TimingInfo]
	    if {$rise == "true"} {
		$ti fixEdge "rise"
	    } elseif {$fall == "true"} {
		$ti fixEdge "fall"
	    }
	    set pin [[[design] topModule] findPin $pinNm]
	    if {$pin != "NULL"} {
		if {$thruPin == "false"} {
		    $ti fixEndPoint "true"
		}
		$pin reportTiming $ti $thruGenomes true
		[$pin design] release
		# next stmtnt should be bogus!!
		$pin -delete
	    } else {
		rt::UMsg_print "Error: could not find pin '$pinNm'\n"
	    }
	} elseif {$count > 1} {
	    set i 0
	    foreach ep [[design] endPoints $count] {
		incr i
		if {$i <= $count} {
		    rt::UMsg_print "Path #: $i\n"
		    set ti [TimingInfo]
		    $ti fixEndPoint "true"
		    $ep reportTiming $ti $thruGenomes true
		}
	    }
	} else {
	    [design] reportTiming $thruGenomes
	}
    }

    proc orbSet {node list} {
	if {[llength $list] == 1} {
	    set idx    [lindex $list 0]
	    $tl setOrbNode $node $idx
	} else {
	    # list = {genLibCell params} elem elem ...
	    set cell   [$tl [lindex $list 0]]
	    set elems  [lrange $list 1 end]
	    $tl setOrbNode $node $cell
	    set i 0
	    foreach elem $elems {
		set child [$node child $i]
		orbSet $child $elem
		incr i
	    }
	    return node
	}
    }

    proc addRule {rule impl} {
	set tl 	    [[design] targetLib]
	set orbRule [$tl newORBNode]
	set orbImpl [$tl newORBNode]
	orbSet $orbRule $rule
	orbSet $orbImpl $impl
	$tl addOptRule $orbRule $orbImpl
    }

    proc dissolve_inferred_genormod {nm} {
	set gen [$rt::db findGenome $nm]
	if {$gen == "NULL"} {
	    set mod [[rt::design] findModule $nm]
	} else {
	    set des [$gen acquireDesign]
	    set mod [$des topModule]
	}
	set res false
	if {$mod != "NULL"} {
	    $mod dissolveInferredHierarchies false false
	    puts "info: Dissolved inferred hierarchies within $nm (mod=$mod,gen=$gen)"
	    [rt::design] setAreaOptimized false
	    if {$gen != "NULL"} {
		$des setAreaOptimized false
	    }
	    set res true
	}
	if {$gen != "NULL"} {
	    $gen releaseDesign true
	}
	return $res
    }

    proc dissolve_inferred {nm} {
	#tcl_puts stderr "info: Memory stats (before dissolve_inferred)"
	#UMem_printStats
	if {![dissolve_inferred_genormod $nm]} {
	    puts "info: dissolve_inferred{} Walking through genomes"
	    set des [rt::design]
	    $des setAreaOptimized false
	    for {set gi [[$rt::db genomes] begin]} {[$gi ok]} {$gi incr} {
		set gen [$gi object]
		if {[$gen parentCount] == 0} {
		    continue
		}
		set gen [$gi object]
		set des [$gen acquireDesign]
		set modified false
		for {set mi [[$des modules] begin]} {[$mi ok]} {$mi incr} {
		    set mod [$mi object]
		    if {[$mod rtlName] == $nm} {
			set modified true
			$mod dissolveInferredHierarchies false false
			#reset area opt flag
			$des setAreaOptimized false
			puts "info: Dissolved inferred hierarchies within $nm (mod [$mod name] in $gen)"
		    }
		}
		$gen releaseDesign $modified
	    }
	}
	#tcl_puts stderr "info: Memory stats (after dissolve_inferred)"
	#UMem_printStats
    }

    proc dissolve_modules_indesign {des nm ic iclb gname debug} {
	set modified false
	for {set mi [[$des modules] begin]} {[$mi ok]} {} {
	    set mod [$mi object]
	    $mi incr
	    set mname [$mod name]
	    set icnt [$mod instanceCount 1 1 1]
	    if [string match $nm [$mod rtlName]] {
		if {$debug} {
		    puts -nonewline "info: hierarchy $mname (icnt=$icnt$gname)"
		}
		if {$icnt < $ic && $icnt > $iclb} {
		    set modified true
		    $mod dissolve true true
		    if {!$debug} {
			puts -nonewline "info: hierarchy $mname (icnt=$icnt$gname)"
		    }
		    puts " <== DISSOLVED"
		} elseif {$debug} {
		    puts ""
		}
	    }
	}
	# reset area opt flag
	if {$modified} {
	    $des setAreaOptimized false
	}
	return $modified
    }

    # dissolve modules whose name matches nm, and has iclb < instance-count < ic
    proc dissolve_modules {nm ic {iclb 0} {debug 0}} {
	#tcl_puts stderr "info: Memory stats (before dissolve_inferred)"
	#UMem_printStats
	puts "info: dissolve_modules with name $nm AND $iclb < inst-count < $ic"
	set des [rt::design]
	$des setAreaOptimized false
	puts "info: dissolve_modules working above genomes"
	dissolve_modules_indesign $des $nm $ic $iclb "" $debug
	puts "info: dissolve_modules looking inside genomes"
	for {set gi [[$rt::db genomes] begin]} {[$gi ok]} {$gi incr} {
	    set gen [$gi object]
	    if {[$gen parentCount] == 0} {
		continue
	    }
	    set gen [$gi object]
	    set des [$gen acquireDesign]
	    set gname " gen=[$gen name]"
	    set modified [dissolve_modules_indesign $des $nm $ic $iclb $gname $debug]
	    $gen releaseDesign $modified
	}
	#tcl_puts stderr "info: Memory stats (after dissolve_inferred)"
	#UMem_printStats
    }

    proc elaborate {module extract dump_dfg gate_clock map_to_scan } {
        #should be obsoleted
	set_parameter extractGenomes $extract;
	set_parameter writeDot [expr $dump_dfg == true];
	set st [$rt::db synthesize $module $gate_clock $map_to_scan]
	if {$st != 0} {
	    return -code error "elaborate failed"
	}
        set sdcrt::currMod [[rt::design] topModule]
    }

    proc setZeroWireLoad {} {
	set_parameter topDesignAllowWLM         true
	set_parameter genomesAllowWLM           true
	set_parameter wlmCapRate                   0
	set_parameter wlmResRate                   0
    }

    proc tie_undriven_to {cval} {
	set des [rt::design]
	if {$cval != 0 && $cval != 1} {
	    puts "WARNING:  constant passed to tie undriven must be a 0 or 1"
	    return 1
	}
	if {$des != "NULL"} {
	    set res [[$des topModule] tieUndrivenPinsTo $cval]
	    puts "info:    tied $res input pins to constant-$cval"
	}
	return 0
    }

    proc resize {target buffer bufferOnly unsize markSize markUnsize} {
	if {$unsize || $markSize || $markUnsize} {
	    if {$target != "" || $buffer || $bufferOnly} {
		puts "ERROR: -unsize, -markSize, or -markUnsize should not be used with other options"
		return 1
	    } else {
		
		[rt::design] rebind $unsize [expr $markSize && !$markUnsize]
		[rt::design] resetTiming true
	    }
	} else {
	    if {$buffer && $bufferOnly} {
		error "incompatible option combination"
	    }

	    start_state "resize"
	    if {$target == ""} {
		set targetStr [[rt::design] worstSlack]
		regsub -- {ps$} $targetStr {} target
		puts "info:    setting target slack to $target"
	    }
	    set sizing true
	    set buffering false
	    if {$buffer || $bufferOnly} {
		set buffering true
	    }
	    if {$bufferOnly} {
		set sizing false
	    }

	    if {[rt::getParam resizeEffortHigh] == "leakage"} {
		set dampFactor [rt::getParam sizingDampingFactor]
		set lkCritW    [rt::getParam sizingCritLeakWeight]
		set lkNonCritW [rt::getParam sizingNonCritLeakWeight]

		rt::setParameter resizeRemainingPass 1
		rt::setParameter sizingDampingFactor [expr $dampFactor + 0.2]
		[rt::design] resize $target $sizing $buffering false

		rt::setParameter resizeRemainingPass 0
		rt::setParameter sizingDampingFactor [expr $dampFactor - 0.2]
		rt::setParameter sizingCritLeakWeight [expr $lkCritW * 4]
		rt::setParameter sizingNonCritLeakWeight [expr $lkNonCritW + 1.0]
		[rt::design] resize $target $sizing $buffering false

		rt::resetParameter sizingDampingFactor
		rt::resetParameter sizingCritLeakWeight
		rt::resetParameter sizingNonCritLeakWeight
	    } elseif {[rt::getParam resizeEffortHigh] == "area"} {
		set dampFactor [rt::getParam sizingDampingFactor]
		set areaW    [rt::getParam sizingAreaWeight]

		rt::setParameter resizeRemainingPass 1
		rt::setParameter sizingDampingFactor [expr $dampFactor + 0.2]
		[rt::design] resize $target $sizing $buffering false

		rt::setParameter resizeRemainingPass 0
		rt::setParameter sizingDampingFactor [expr $dampFactor - 0.2]
		rt::setParameter sizingAreaWeight [expr $areaW * 2.0 ]
		[rt::design] resize $target $sizing $buffering false

		rt::resetParameter sizingDampingFactor
		rt::resetParameter sizingAreaWeight
	    } else {
		[rt::design] resize $target $sizing $buffering false
	    }
	    stop_state "resize"
	}
    }

    proc reportPowerCalculation {inst} {
	variable UNM_sdc
	set topDes [rt::design]
	set topMod [$topDes topModule]

	foreach instNm $inst {
	    set instObjs [$topMod findInstances $instNm $UNM_sdc "false"]
	    foreach instObj $instObjs {
		$instObj reportPowerCalculation
		puts ""
	    }
	    release $instObjs
	}
    }

    proc splitGenome {timing name} {
        set val [rt::UParam_get findTransparentlyInsideGenomes old]
        if {$val == 0} {
            return -code error
        }
        rt::UParam_set findTransparentlyInsideGenomes false
        set insts [::find -obj -inst $name]
        if { [llength $insts] == 0} {
            puts "Cannot find genome $name, non splited."
            return
        }
        rt::UParam_set findTransparentlyInsideGenomes $old
        foreach i $insts {
            if { [$i isGenome] == "NULL" } {
                set fullName [$i fullName]
                release $i
                continue
            }
	    if {$timing} {
	        [rt::design] splitGenome $i true
	    } else {
	        [rt::design] splitGenome $i false
	    }
        }
    }

    proc splitGenomes {timing slack {mod ""}} {
        if {$mod == ""} {
            set mod [[rt::design] topModule]
        }
	set instList {}
        for {set ii [[$mod instances] begin]} {[$ii ok]} {$ii incr} {
	    lappend instList [$ii object]
	}
	foreach inst $instList {
            if {[$inst isCell] == "NULL"} {
		set gen [$inst isGenome]
		set mod [$inst isRealModule]
		if {$gen != "NULL"} {
		    if {$timing} {
			set ws [string trimright [$inst worstSlack false] ps]
			if {$slack > $ws} {
			    puts "slack = $ws \tSplitting genome [$gen name] for inst [$inst name]"
			    [rt::design] splitGenome $inst true
			} else {
			    puts "slack = $ws \tSkipping genome [$gen name] for inst [$inst name]"
			}
		    } else {
			puts "Splitting genome [$gen name] for inst [$inst name]"
			[rt::design] splitGenome $inst false
		    }
		} elseif {$mod != "NULL"} {
		    # go down the hierarchy
		    splitGenomes $timing $slack $mod
		}
	    }
        }
    }

    proc extractModule {mod criteria} {
	set cr 1
	if {[string equal $criteria congestion]} {
	    set cr 2
	}
	[rt::design] reExtractGenomes $mod $cr
    }

    proc reportFsm {{detail 0} {mod} {inst}} {
	if {$mod != ""} {
	    if {$inst != ""} {
		if {[[rt::design] reportFsm $detail $mod $inst] > 0} {
		    return -code error;
		}
	    } else {
		if {[[rt::design] reportFsm $detail $mod] > 0} {
		    return -code error;
		}
	    }
	} else {
	    if {$inst != ""} {
		return -code error "need to specify -module when -instance is specified"
	    } else {
		if {[[rt::design] reportFsm $detail] > 0} {
		    return -code error;
		}
	    }
	}
    }

    proc inferFsm {{value "true"}} {
	if {$value == "true"} {
	    rt::UParam_set eliminateRedundantReg true
	    rt::UParam_set inferFsm true
	    rt::UParam_set gFsmDebug 1
	    set_parameter extractSynchronousSetReset true
	    set_parameter extractLatchEnablesFirst true
	} elseif {$value == "false"} { 
	    rt::UParam_set eliminateRedundantReg false
	    rt::UParam_set inferFsm false
	    rt::UParam_set gFsmDebug 0
	    set_parameter extractSynchronousSetReset false
	    set_parameter extractLatchEnablesFirst false
	} else {
	    return -code error "invalid arument $value (allowed values are \"true\" or \"false\")"
	}
    }

    proc computeCellDelay { cell inPin outPin inSlew {load "-1"} {outSlew "-1"} {mvCorner "-2"}} {
	set cellObj [rt::getLibCell $cell]
puts "$cell $inPin $outPin $inSlew $load $outSlew $mvCorner"
	if { $cellObj == "NULL" } {
	    return -code error "Cell $cell not found in library"
	}
	set pCount [$cellObj logicalPinCount]
	set inPinIdx 0
	set inFound "false"
	set outPinIdx 0
	set outFound "false"
	for { [set i 0] } { $i < $pCount } { incr i } {
	    set pName [$cellObj pinName $i]
            if { $pName == $inPin } {
		set inPinIdx $i
		set inFound "true"
	    } 
	    if { $pName == $outPin } {
		set outPinIdx $i
		set outFound "true"
	    }
	    if { $inFound && $outFound } {
		break;
	    }
	}
	if { $inFound && $outFound && ( $load != "" ) } {
	    [rt::design] computeCellCombDelay $cellObj [sdcrt::time $inSlew] [sdcrt::cap $load] $inPinIdx $outPinIdx $mvCorner
	}
	if { $inFound && $outFound && ( $outSlew != "" ) } {
	    [rt::design] computeCellSetupDelay $cellObj [sdcrt::time $inSlew] [sdcrt::time $outSlew] $inPinIdx $outPinIdx
	}
    }

    proc createVoltageRegion {name domain left bottom right top} {
	variable UNM_sdc

	if { $left == "" } {
	    set left 0
	}
	if { $bottom == "" } {
	    set bottom 0
	}
	if { $right == "" } {
	    set right 0
	}
	if { $top == "" } {
	    set top 0
	}

	set topDes [rt::design]
	set pd     [$rt::db findPowerDomain $domain]
	if {$pd != "NULL"} {
	    set region [$topDes createVoltageRegion $name $pd $left $bottom $right $top]
	} else {
	    puts "WARNING: power domain '$domain' not found"
	    return -code error
	}
	return -code ok
    }

    proc getGenomes {{mod ""}} {
        if {$mod == ""} {
            set mod [[rt::design] topModule]
        }
	set instList {}
        for {set ii [[$mod instances] begin true false true]} {[$ii ok]} {$ii incr} {
            if {[[$ii object] isGenome] != "NULL"} {
	        lappend instList [$ii object]
            }
	}
        return $instList
    }

    proc getGenomeConnInfo {} {
        puts [[rt::design] collectGenomeConnInfo]
    }

    proc setWatchPin { inst index name nameOnly} {
	variable UNM_sdc
	set oldState [rt::UParam_get findTransparentlyInsideGenomes old]
	set_parameter findTransparentlyInsideGenomes false
	if { $nameOnly != "" } {
	    [rt::design] setWatchPin $nameOnly
	    return
	}
	if { $inst != "" && $name != "" } {
	    set pin "NULL"
	} else {
	    if { $name != ""} {
		set pin [[[design] topModule] findPin $name]
		if { [[$pin ownerInstance] isGenome] == "NULL" } {
		    puts "Pin $name is not a genome pin"
		    release $pin
		    set pin "NULL"
		}
	    }
	    if { $inst != "" && $index >= 0 } {
		set inst [[[design] topModule] findInstances $inst $UNM_sdc "false"]
		if { $inst != "NULL" } {
		    set pin [$inst pin $index]
		}
	    }
	}
	set_parameter findTransparentlyInsideGenomes $oldState
	if { $pin != "NULL" } {
	    [rt::design] setWatchPin [$pin fullName]
	} else {
	    puts "Usage set_debug_genome ( -inst <genome instance name> -index <pin index> | -name <genome input_pin name> )"
	}
    }

} 

cli::addCommand rt::add_to_target_library {rt::addToTargetLib} {string} {string target_library}
cli::addCommand rt::manual_place          {"[rt::design] placeInst"} {string} {integer x} {integer y}
cli::addCommand rt::die_size              {"[rt::design] dieSize"} {double} {double}
cli::addCommand rt::dissolve_all_genomes  {"[rt::design] dissolveAllGenomes"} {boolean keep_partitions}
cli::addCommand rt::dplace                {"[rt::design] dplace"}
cli::addCommand rt::dplace_genome         {"[rt::design] dplaceGenome"} {string}
cli::addCommand rt::run_elaborate         {rt::elaborate} {string module} {boolean extract} {boolean dump_dfg} {boolean gate_clock} {boolean map_to_scan}
cli::addCommand rt::extract_genome        {"[rt::design] phyExtractGenomes"}
cli::addCommand rt::extract_module        {rt::extractModule} {string} {enum {timing congestion} criteria congestion}
cli::addCommand rt::extract_opt           {"[rt::design] reExtractGenomes"}
cli::addCommand rt::extract_empty_module  {"[rt::design] extractEmptyModule"} {string module} {double width} {double height} {boolean soft}
cli::addCommand rt::floorplan             {"[rt::design] floorplan"}
cli::addCommand rt::build_partitions      {"[rt::design] buildPartitions"}
cli::addCommand rt::place                 {"[rt::design] nplace"} {boolean incremental} {boolean no_global} {boolean no_legalize} {boolean no_congestion_reduction} {boolean always_place_genome}
cli::addCommand rt::print_stats           {rt::printStats} {string design} {string module}
cli::addCommand rt::print_worst_slacks    {rt::printWorstSlacks} {integer count} {boolean stats} {boolean ascii} {boolean genomes} {boolean total} {boolean unconstrained} {string filename}
cli::addCommand rt::report_genomes        {"[rt::design] reportGenomes"}
cli::addCommand rt::write_pins            {"[rt::design] writePins"} {string}
cli::addCommand rt::write_test_verilog    {"$rt::db writeTestVerilog"} {string clock} {string sr} {string} {string}
cli::addCommand rt::write_lef             {"[rt::design] writeModuleLef"} {string}
cli::addCommand rt::write_lib             {"[rt::design] writeModuleLib"} {string}
cli::addCommand rt::write_script          {rt::writeScript} {string}
cli::addCommand rt::pop_parameter         {rt::popParam} {boolean stack} {string}
cli::addCommand rt::push_parameter        {rt::pushParam} {string stack} {string} {string}
cli::addCommand rt::run_resize            {rt::resize} {double target} {boolean buffer} {boolean buffer_only} {#boolean unsize} {#boolean markSize} {#boolean markUnsize}
cli::addCommand rt::split_genome          {rt::splitGenome} {boolean timing} {string}
cli::addCommand rt::split_genomes         {rt::splitGenomes} {boolean timing} {integer slack} {string module}
cli::addCommand rt::top_design            {rt::topDesign} {string set}
cli::addCommand rt::report_timing_old     {rt::reportTimingOld} {boolean stop_at_genomes} {string from} {string through} {string to} {boolean rise} {boolean fall} {integer count}
cli::addCommand rt::run_tie_undriven_to   {rt::tie_undriven_to} {integer}
cli::addCommand rt::report_fsm            {rt::reportFsm} {boolean detail} {string module} {string instance}
cli::addCommand rt::infer_fsm             {rt::inferFsm} {string value} 
cli::addCommand rt::report_families       {"[rt::design] reportFamilies"}

cli::addCommand rt::check_target_library  {rt::checkTargetLibrary} {boolean auto_disable}
cli::addCommand rt::compute_cell_delay    {rt::computeCellDelay} {string cell} {string inPin} {string outPin} {double inSlew} {double load} {double outSlew} {integer mvCorner 0}
cli::addCommand rt::create_voltage_region \
    {rt::createVoltageRegion} {string name} {string domain} {double left} {double bottom} {double right} {double top}
cli::addCommand rt::report_power_calculation {rt::reportPowerCalculation} {string}
cli::addCommand rt::get_genomes           {rt::getGenomes} {string mod}
cli::addCommand rt::get_genome_conn_info  {rt::getGenomeConnInfo}

cli::addCommand rt::set_watch_pin         {rt::setWatchPin} {string inst} {string index} {string name} {string nameOnly}
cli::addCommand rt::run_dump_vias             {rt::dump_vias}  { string fname }

cli::addCommand rt::verify_hierarchical   {verify::hierVerify}\
                                      {boolean noclean} {boolean max_hier} {string lib_dir} {string base_dir}\
                                      {string job_cmd} {integer num_lic} {string mach_list} {#string dir_suffix}\
                                      {#string execute_cache} {#boolean write_only} {#integer dissolve_cellcount} {#string ignore_modules}\
                                      {#string fpopt_main} {#string fpopt_blackbox} {#string fpopt_common} {#string fpopt_rtl}\
                                      {#string sub_module} {#string include_files} {#integer num_parts} {#boolean exclude_cf}\
                                      {#boolean lec} {#boolean use_formalpro} {#boolean use_onespin} {#boolean allowFT}\
                                      {#integer time_limit} {#boolean auto_rtl_name} {#boolean redo_onespin} {#string rtl_cg_cells}\
                                      {#boolean no_crc_striplib}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
