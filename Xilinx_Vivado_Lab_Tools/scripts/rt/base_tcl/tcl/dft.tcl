# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval rtdft {

    proc objName {itemList} {
	set res ""
	foreach item $itemList {
	    set objType [rt::typeOf $item]
	    switch -- $objType {
		"NULL" {  }
		"NRefS"  -
		"NCellS" -
		"NInstS" -
		"NNetS"  -
		"NPort"  -
		"NPinS"  -
		"TClock" -
		default  { 
		   set item [$item fullName $::UNM_sdc] 
		}
	    }
	    if {[llength $res] > 0} {
		set res "$res $item"
	    } else {
		set res $item
	    }
	}
	return $res
    }

    proc setDontScan {list val} {
	foreach item $list {
	    $rt::db setDontScan $item
	}
    }

    proc setDontScanInstance {list} {
	foreach item $list {
	    $rt::db setDontScanInstance $item
	}
    }

    proc setExcludeScanInstance {list} {
	set des [rt::design]
	set dft [$des dft]
	foreach item $list {
	    set obj $item
	    if {[rt::typeOf $item] == "NULL"} {
		set obj [get_cell -hier $item]
	    }
	    $dft setExcludeScan $obj
	}
    }

    proc defineTestPin {name pin hookup scan_mode capture_mode function_mode create_port default_scan_enable} {
	set des [rt::design]
	set mod [$des topModule]
	set dft [$des dft]
	set pin [objName $pin]
	set hookup [objName $hookup]

	if {$scan_mode == 2} {
	    puts "Error: use -scan_mode option to set its scan_mode value"
	    return -code error ""
	}

	set tp  [$dft defineTestPin $name $pin $hookup $scan_mode $capture_mode $function_mode $create_port $default_scan_enable]
        if {$tp ne "NULL"} {
	    set res [$tp name]
	} else {
	    set res ""
	    return -code error $res
	}
 	return -code ok $res
    }

    proc defineTestClock {name pin hookup test_domain derived rise fall} {
	set des [rt::design]
	set mod [$des topModule]
	set dft [$des dft]
	set pin [objName $pin]
	set hookup [objName $hookup]

	set autoDefined false
	set tc [$dft defineTestClock $name $pin $hookup $test_domain $rise $fall $derived $autoDefined]
        if {$tc ne "NULL"} {
	    set res [$tc name]
	} else {
	    set res ""
	    return -code error $res
	}
 	return -code ok $res
    }

    proc defineScanChain {name scan_in scan_out scan_enable max_length elements head tail test_domain 
			  partition create_port fixed_order boundary_instance} {
	if {$scan_in eq ""} {
	    rt::UMsg_print "Must specify a valid -scan_in \n"
	    return -code error ""
	}
	if {$scan_out eq ""} {
	    rt::UMsg_print "Must specify a valid -scan_out \n"
	    return -code error ""
	}
	set scan_in [objName $scan_in]
	set scan_out [objName $scan_out]
	set scan_enable [objName $scan_enable]
	set elements [objName $elements]

	set des [rt::design]
	set mod [$des topModule]
	set dft [$des dft]

	set headLU $::LOCKUP_NONE
	if {$head ne ""} {
	    if {$head eq "latch"} {
		set headLU $::LOCKUP_LATCH
	    } elseif {$head eq "flop"} {
		set headLU $::LOCKUP_FLOP
	    } else {
		rt::UMsg_print "-head must be one of 'latch', or 'flop' \n"
		return -code error ""
	    }
	}

	set tailLU $::LOCKUP_NONE
	if {$tail ne ""} {
	    if {$tail eq "latch"} {
		set tailLU $::LOCKUP_LATCH
	    } elseif {$tail eq "flop"} {
		set tailLU $::LOCKUP_FLOP
	    } elseif {$tail eq "auto"} {
		set tailLU $::LOCKUP_AUTO
	    } else {
		rt::UMsg_print "-tail must be one of 'latch', 'flop' or 'auto' \n"
		return -code error ""
	    }
	}
	set chain [$dft defineScanChain $name $scan_in $scan_out $scan_enable $max_length $headLU \
		   $tailLU $test_domain $partition $create_port $elements $fixed_order $boundary_instance]
        if {$chain ne "NULL"} {
	    set res [$chain name]
	    return -code ok $res
	} else {
	    return -code error ""
	}
    }

    proc defineScanModel {name cell instance si so se seActive cck cckEdge lck lckEdge len tailLockupLatch tailLockupFlop} {

	set instance [objName $instance]
	set cell [objName $cell]

	set items [list "scan_in $si" "scan_out $so" "scan_enable $se" "scan_enable_active $seActive" "capture_clock $cck" "capture_edge $cckEdge" "launch_clock $lck" "launch_edge $lckEdge" "length $len"]
	foreach item $items {
	    set nm [lindex $item 0]
	    set val [lindex $item 1]
	    #puts "$nm: '$val'"
	    if {$val eq ""} {
		rt::UMsg_print "Must specify -$nm \n"
		return -code error ""
	    }
	}
	if {$cell eq "" && $instance eq ""} {
	    rt::UMsg_print "Must specify one of -lib_cell or -instance \n"
	    return -code error ""
	}
	if {$cell ne "" && $instance ne ""} {
	    rt::UMsg_print "Must specify only one of -lib_cell or -instance \n"
	    return -code error ""
	}
 	set des [rt::design]
	set mod [$des topModule]
	set dft [$des dft]
	if {$seActive > 0} {
	    set seA true
	} else {
	    set seA false
	}
	if {$cckEdge > 0} {
	    set cckE true
	} else {
	    set cckE false
	}
	if {$lckEdge > 0} {
	    set lckE true
	} else {
	    set lckE false
	}
	set subName $name
	if {$cell ne ""} {
	    set instance [get_cell * -filter "ref_name == $cell" -hier]

	    if {0} {
	    set module $cell
	    set mod [::find -obj -module $module]
	    if {$mod ne ""} {
		set mod [[lindex [lindex $mod 0] 0] isRealModule]
puts ".. $mod"
		set d_objs $mod
		set itr [$mod parents]
		while {$itr ne ""} {
		    set i [$itr object]
puts ".. $i"
		    lappend instance [$i fullName $::UNM_sdc]
puts "..$instance"
		    set itr [$itr incr]
		    lappend d_objs $i
		}
		rt::release $d_objs
	    } else {
	    set objs ""
	    set topDes [rt::design]
	    set mods [$topDes findModules $module]
	    if {[llength $mods]} {
	    for {set i [$mods begin]} {[$i ok]} {$i incr} {
		# append {<genomeObj> <moduleName>}
		set modRef [$i value]
		set mod [$modRef isRealModule]
		set itr [$mod parents]
		while {$itr ne ""} {
		    set k [$itr object]
		    lappend instance [$k fullName $::UNM_sdc]
		    set itr [$itr incr]
		    lappend objs $k
		}
	    }
	    rt::delete_NRefMap $mods
	    rt::release $objs
	    } else {
		set mods [$topDes findCells $module]
		# ...
	    }
	    }
	  }
	}

	set sm ""
	set count 0
	set res ""
	foreach inst $instance {
	    set inst [objName $inst]
	    set sm  [$dft defineScanModel $name $subName $inst $si $so $se $seA $cck $cckE $lck $lckE $len]
	    if {$sm ne "NULL"} {
		incr count
		lappend res [$sm name]
	    }
	}
	if {$cell ne ""} {
	    rt::release $instance
	}
	rt::UMsg_print "Defined $count scan-model instance(s) \n"
 	return -code ok $res
    }

    proc checkDft {items auto_test_clocks auto_test_pins ignore_clock_gating verbose ignore_scan_map_status} {
	rt::start_state "check_dft"
	set des [rt::design]
	set mod [$des topModule]
	rt::UMsg_print "Checking DFT rules for '[$mod name]'\n"

        set ena [rt::UMsgHandler_isEnabled PARAM 104]
        rt::UMsgHandler_disable PARAM 104

	set atc [rt::checkParam _checkDftAutoTestClocks]
	set atp [rt::checkParam _checkDftAutoTestPins]
	set icg [rt::checkParam _checkDftIgnoreClockGating]
        set ism [rt::checkParam _checkDftIgnoreScanMapStatus]
	rt::setParameter _checkDftAutoTestClocks $auto_test_clocks
	rt::setParameter _checkDftAutoTestPins $auto_test_pins
	rt::setParameter _checkDftIgnoreClockGating [expr {$ignore_clock_gating || $icg}]
	rt::setParameter _checkDftIgnoreScanMapStatus [expr {$ignore_scan_map_status || $ism}]
	rt::setParameter _checkDftViolationCount -1
	#set v [$des checkDft $items $auto_test_clocks $auto_test_pins $verbosity]
	$des checkDft $items $verbose
	set v [rt::getParam _checkDftViolationCount]
        rt::UMsg_print "Design has $v DFT violation(s)\n"
	rt::setParameter _checkDftAutoTestClocks $atc
	rt::setParameter _checkDftAutoTestPins $atp
	rt::setParameter _checkDftIgnoreClockGating $icg
	rt::setParameter _checkDftIgnoreScanMapStatus $ism

        if {$ena} {
            rt::UMsgHandler_enable PARAM 104
        }

	rt::stop_state "check_dft"
	return -code ok $v
    }

    proc reportScanChains {detail physical} {
	set des [rt::design]
	$des reportScanChains $detail $physical
    }

    proc connectScanChains {inst chain incremental skipSE physical verbose skipCheckDft} {
	rt::start_state "connect_scan_chains"
	set des [rt::design]
	set mod [$des topModule]
	if {[llength $inst] > 0} {
	    puts "-instance not yet supported"
	    return -code error
	}
	if {[llength $chain] > 0} {
	    puts "-chain not yet supported"
	    return -code error
	}
	if {$incremental} {
	    puts "-incremental not yet supported"
	    return -code error
	}

        set ena [rt::UMsgHandler_isEnabled PARAM 104]
        rt::UMsgHandler_disable PARAM 104

	set inst [objName $inst]
	rt::UMsg_print "Connecting Scan Chains for '[$mod name]'\n"
        set v [$des connectScanChains $inst $chain $incremental $skipSE $physical $verbose $skipCheckDft]
        rt::UMsg_print "Connected $v scan chain(s)\n"
        rt::UMsg_print "Resetting timing\n"
        [rt::design] resetTiming

        if {$ena} {
            rt::UMsgHandler_enable PARAM 104
        }
	if {$v > 0} {
	    report_scan_chains
	}
	rt::stop_state "connect_scan_chains"
 	return -code ok $v
    }

    proc setEquivalentTestClocks {clocks} {
 	set des [rt::design]
	set dft [$des dft]

	set mc ""
	set ok 1
	foreach ck $clocks {
	    if {$mc eq ""} {
		set mc $ck
	    } else {
		set res [$dft setEquivalentClocks $mc $ck]
		if {!$res} {
		    set ok 0
		}
	    }
	}

	if {$ok} {
	    return -code ok $ok
	} else {
	    return -code error $ok
	}
    }

    proc defineDftPartition {name instances clocks} {
 	set des [rt::design]
	set dft [$des dft]
	if {$name eq ""} {
	    puts "error: partition being defined must have a name"
	    return -code error
	}
	if {$instances eq ""} {
	    puts "error: must specify -instances"
	    return -code error
	}
	if {$clocks ne ""} {
	    puts "error: -clocks not supported"
	    return -code error
	}

	set instances [objName $instances]
	set res [$dft defineDftPartition $name $instances $clocks]
	return -code ok
    }


    proc removeTestClock {name} {
	set des [rt::design]
	set dft [$des dft]
	set tck [$dft findTestClock $name true]

	if {$tck ne "NULL"} {
	    puts "removing test clock '$name'"
	    $dft removeTestClock $name
	    # TBD - check any chain referring to this clock
	} else {
	    puts "error - did not find any test clock named '$name'"
	    return -code error
	}
	return -code ok
    }

    proc removeTestPin {name} {
	set des [rt::design]
	set dft [$des dft]
	set tp [$dft findTestPin $name true]

	if {$tp ne "NULL"} {
	    puts "removing test pin '$name'"
	    $dft removeTestPin $name
	    # TBD - check any chain referring to this test pin
	} else {
	    puts "error - did not find any test pin named '$name'"
	    return -code error
	}
	return -code ok
    }

    proc removeScanChain {name} {
	set des [rt::design]
	set dft [$des dft]
	set chain [$dft findScanChain $name]

	if {$chain ne "NULL"} {
	    puts "removing scan chain '$name'"
	    $dft removeScanChain $name
	} else {
	    puts "error - did not find any scan chain named '$name'"
	    return -code error
	}
	return -code ok
    }

    proc removeDftPartition {name} {
	set des [rt::design]
	set dft [$des dft]
	set dp [$dft findDftPartition $name]

	if {$dp ne "NULL"} {
	    puts "removing DFT partition '$name'"
	    $dft removeDftPartition $name
	    # TBD - check any chain referring to this partition
	} else {
	    puts "error - did not find any DFT partition named '$name'"
	    return -code error
	}
	return -code ok
    }

    proc reportTestPins {detail old} {
	set des [rt::design]
	set dft [$des dft]
	if {$old} {
	    $dft reportTestPins
	} else {
	    $des reportTestPins $detail
	}
    }

    proc reportTestClocks {detail old} {
	set des [rt::design]
	set dft [$des dft]
	if {$old} {
	    $dft reportTestClocks
	} else {
	    $des reportTestClocks $detail
	}
    }

    proc reportDftViolations {detail old} {
	set des [rt::design]
	set dft [$des dft]
	if {$old} {
	    $dft reportViolations
	} else {
	    $des reportDftViolations $detail
	}
    }

    proc reportDftRegisters {detail old} {
	puts "This cmd is not yet supported in production"
	set des [rt::design]
	set mod [$des topModule]
	set dft [$des dft]
	set old true
	if {$old} {
	    $dft reportFF
	}
    }

    proc testPins {} {
	set des [rt::design]
	set dft [$des dft]
	set d_testPins [$dft testPins]

	set res ""
	for {set i [$d_testPins begin]} {[$i ok]} {$i incr} {
	    set d_ref [$i object]
	    lappend res $d_ref
	}

 	return -code ok $res
    }

    proc connectCGTestPin {testPin skipPreConnected instance exclude} {
	set instance [objName $instance]
	set exclude [objName $exclude]
	set testPin [objName $testPin]

	[rt::design] connectCGTestPin $testPin $skipPreConnected $instance $exclude
    }

    proc writeScandef {fName} {
	set des [rt::design]
	#no need to reestablish TDRC data - incase design was flattened
	#set items ""
	#set verbose false
	#$des checkDft $items $verbose

	$des writeScandef $fName
    }

    proc writeCtl {fName} {
	set des [rt::design]
	$des writeCtl $fName
    }

}

cli::addCommand set_dont_scan             {rtdft::setDontScan} {string} {?boolean true}
cli::addCommand set_dont_scan_instance    {rtdft::setDontScanInstance} {string}
cli::addCommand set_exclude_scan_instance {rtdft::setExcludeScanInstance} {string}

cli::addCommand check_dft              {rtdft::checkDft} {string items} {boolean auto_test_clocks} \
                                       {boolean auto_test_pins} {boolean ignore_clock_gating} {boolean verbose} \
    {#boolean ignore_scan_map_status}

cli::addCommand connect_scan_chains    {rtdft::connectScanChains} {#string instance} {#string chain} {#boolean incremental} \
				       {boolean skip_scan_enable} {boolean physical} {#boolean verbose} \
                                       {#boolean zskip_check_dft}

cli::addCommand write_scandef         {rtdft::writeScandef} {string}
cli::addCommand write_ctl             {rtdft::writeCtl} {string}

cli::addCommand define_test_pin       {rtdft::defineTestPin} {#string name} {string pin} {#string hookup}        \
				      {integer scan_mode 2} {#integer capture_mode 2} {#integer function_mode 2} \
                                      {boolean create_port} {boolean default_scan_enable} 

cli::addCommand define_test_clock     {rtdft::defineTestClock} {string name} {string pin} {#string hookup} \
			   {string test_domain} {boolean derived} {#integer rise 25} {#integer fall 75} 

cli::addCommand define_scan_chain     {rtdft::defineScanChain} {string name} {string scan_in} {string scan_out} \
    {string scan_enable} {integer max_length 0} {string elements} {string head_lockup} \
    {string tail_lockup} \
    {string test_domain} {string partition} {boolean create_port} {boolean fixed_order} \
    {#string boundary_instance}

cli::addCommand define_scan_model     {rtdft::defineScanModel} {string name} {string lib_cell} {*string instance} \
    {string scan_in} {string scan_out} {string scan_enable} {integer scan_enable_active}      \
    {string capture_clock} {integer capture_edge} {string launch_clock} {integer launch_edge} \
    {integer length} {boolean tail_lockup_latch} {boolean tail_lockup_flop}

cli::addCommand set_equivalent_test_clocks {rtdft::setEquivalentTestClocks} {string} 
cli::addCommand report_scan_chains         {rtdft::reportScanChains} {boolean detail} {boolean physical}

cli::addCommand define_dft_partition {rtdft::defineDftPartition} {string} {string instances} {#string clocks}
cli::addCommand connect_clock_gating_test_pin {rtdft::connectCGTestPin} {string test_pin} \
    {boolean skip_pre_connected} {string instance} {string exclude}

cli::addCommand remove_test_clock     {rtdft::removeTestClock} {string}
cli::addCommand remove_scan_chain     {rtdft::removeScanChain} {string}
cli::addCommand remove_test_pin       {rtdft::removeTestPin} {string}
cli::addCommand remove_dft_partition  {rtdft::removeDftPartition} {string}

cli::addCommand report_test_clocks    {rtdft::reportTestClocks} {boolean detail} {#boolean old}
cli::addCommand report_test_pins      {rtdft::reportTestPins} {boolean detail} {#boolean old}
cli::addCommand report_dft_violations {rtdft::reportDftViolations} {boolean detail} {#boolean old}
cli::addCommand report_dft_registers  {rtdft::reportDftRegisters}  {boolean detail} {#boolean old}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
