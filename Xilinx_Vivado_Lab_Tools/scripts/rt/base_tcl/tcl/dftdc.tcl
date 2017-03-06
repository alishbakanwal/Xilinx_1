# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2011
#                             All rights reserved.
# ****************************************************************************
namespace eval rtdftdc {

    #
    # DFTC compatibility commands
    #

    proc setScanElement {value inst} {
	if {$value eq "false"} {
	    set cmd "set_dont_scan_instance $inst"
	    puts $cmd
	    eval $cmd
	    return -code ok
	} else {
	    rt::UMsg_tclMessage DFT 333 "set_scan_element $value" 
	    return -code error
	}
    }

    proc setDftSignal {view testMode type portList activeState timing period hookupPinList} {
	if {$hookupPinList eq ""} {
	    set hookupPinList $portList
	}
	if {$portList eq ""} {
	    set portList $hookupPinList
	}

	foreach port $portList hookupPin $hookupPinList {
	set cmd ""
	switch -- $type {
	    "ScanEnable" {
		set cmd "define_test_pin -pin $port -hookup $hookupPin -scan_mode $activeState -default_scan_enable"
	    }
	    "ScanClock" -
            "ScanMasterClock" -
	    "MasterClock" {
		if {[llength $timing] == 2} {
		    set rise [lindex $timing 0]
		    set fall [lindex $timing 1]
		} else {
		    set rise 25
		    set fall 75
		}
		set cmd "define_test_clock -pin $port -hookup $hookupPin -rise $rise -fall $fall"
	    }
	    "TestMode" -
	    "Constant" -
	    "constant" {
		set cmd "define_test_pin -pin $port -hookup $hookupPin -scan_mode $activeState -capture_mode $activeState"
	    }
	    "ScanDataIn" -
	    "ScanDataOut" {
	    }
            "TestData" -
	    "ScanSlaveClock" -
	    "Oscillator" -
	    "RefClock" -
            "pll_reset" -
            "pll_bypass" -
	    default {
		rt::UMsg_print "Ignoring 'set_dft_signal -type $type ... \n"
	    }
	}
	if {[llength $cmd]} {
	    puts $cmd
	    eval $cmd
	}
	}

	return -code ok
    }

    proc setScanPath {name orderedElements includeElements dedicatedScanOut complete exactLength     \
		      insertTerminalLockup scanMasterClock scanSlaveClock scanEnable \
		      scanDataIn scanDataOut view class hookup} {
	set elements ""
	set fixedOrder false
	if {[llength $orderedElements] > 0} {
	    set elements $orderedElements
	    set fixedOrder true
	} else if {[llength $includeElements] > 0} {
	    set elements $includeElements
	}

	if {[llength $elements] > 0} {
	    if {$complete eq "false"} {
		rt::UMsg_tclMessage DFT 333 "set_scan_path -ordered_elements <...> -complete false" 
		return -code error
	    }
	} 

	if {$view eq "existing_dft"} {
	    rt::UMsg_tclMessage DFT 333 "set_scan_path -view $view" 
	    return -code error
	}
	set cmd "define_scan_chain -scan_in $scanDataIn -scan_out $scanDataOut"
	if {$scanEnable ne ""} {
	    append cmd " -scan_enable $scanEnable"
	}
	if {[llength $elements] > 0} {
	    append cmd " -elements [list $elements]"
	}
	if {$exactLength ne ""} {
	    append cmd " -max_length $exactLength"
	}
	if {[llength $insertTerminalLockup] > 0} {
	    switch -- $insertTerminalLockup {
		"true" -
		"latch" {	
		    append cmd " -tail_lockup latch"
		}
		"flop" {
		    append cmd " -tail_lockup flop"
		}
		"auto" {
		    append cmd " -tail_lockup auto"
		}
		"false" {
		}
		default {
		    rt::UMsg_tclMessage DFT 333 "set_scan_path -insert_terminal_lockup $insertTerminalLockup"
		    return -code error
		}
	    }
	}

	if {$scanMasterClock ne ""} {
	    append cmd " -test_domain $scanMasterClock"
	}
	if {$fixedOrder} {
	    append cmd " -fixed_order"
	}

	puts $cmd
	eval $cmd
	return -code ok
    }

    proc dftDrc {verbose} {
	set cmd "check_dft"
	if {$verbose} {
	    append cmd " -verbose"
	}
	puts $cmd
	set res [eval $cmd]
	return -code ok $res
    }

    proc insertDft {} {
	set cmd "connect_scan_chains"
	puts $cmd
	set res [eval $cmd]
	return -code ok $res
    }

    proc readTestModel {format design fname} {
	if {$format ne "ctl"} {
	    rt::UMsg_tclMessage DFT 333 "read_test_model -formal $format"
	    return -code error 
	}
	set cmd "read_ctl -lib_cell $design $fname"
	puts $cmd
	set res [eval $cmd]
	return -code ok $res
    }

    proc setDftDrcConfiguration {internalPins} {
	if {[llength $internalPins] > 0} {
	    if {$internalPins ne "enable"} {
		rt::UMsg_tclMessage DFT 333 "set_dft_drc_configuration -internal_pins $internalPins"
		return -code error
	    }
	}
	return -code ok
    }

    proc setScanConfiguration {excludeElements createDedicatedScanOutPorts clockMixing addLockup chainCount 
			       replace terminalLockup lockupType style internalClocks} {
	set ok true
	set des [rt::design]
	set dft [$des dft]
	if {[llength $excludeElements]} {
	    foreach item $excludeElements {
		set cmd "set_exclude_scan_instance $item"
		puts $cmd
		set res [eval $cmd]
	    }
	}
	if {$createDedicatedScanOutPorts eq "false"} {
	    # true/false
	    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -create_dedicated_scan_out_ports false" 
	    set ok false
	}
	
	if {$replace eq "true"} {
	    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -replace true" 
	    rt::UMsg_print "Use 'synthesize -map_to_scan' \n"
	    set ok false
	}

	if {$style ne "" && $style ne "multiplexed_flip_flop"} {
	    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -style $style" 
	    set ok false
	}

	if {$internalClocks ne "" && $internalClocks ne "false"} {
	    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -internal_clocks $internalClocks" 
	    set ok false
	}

	if {$terminalLockup ne ""} {
	    switch -- $terminalLockup {
		"true" {
		    if {$lockupType eq "latch"} {
			set tailLU $LOCKUP_LATCH
		    } elseif {$lockupType eq "flop"} {
			set tailLU $LOCKUP_FLOP
		    } else {
			set tailLU $LOCKUP_AUTO
		    }
		    $dft setTerminalLockup $tailLU
		}
		"false" {
		    set tailLU $LOCKUP_NONE
		    $dft setTerminalLockup $tailLU
		}
	    }
	}
	if {$clockMixing ne ""} {
	    # no_mix/mix_edges/mix_clocks/mix_clock_not_edges
	    switch -- $clockMixing {
		"mix_clocks" {
		    #set_parameter mixTestDomains true
		    $dft setMixDomains true
		    $dft setMixEdges true
		}
		"mix_edges" {
		    #set_parameter mixTestDomains false
		    $dft setMixDomains false
		    $dft setMixEdges true
		}
		"mix_clocks_not_edges" {
		    $dft setMixDomains true
		    $dft setMixEdges false
		}
		"no_mix" {
		    $dft setMixDomains false
		    $dft setMixEdges false
		}
		default {
		    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -clock_mixing $clockMixing" 
		    set ok false
		}
	    }
	}
	if {$addLockup eq "false"} {
	    # true/false
	    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -add_lockup false" 
	}

	if {$chainCount != ""} {
	    rt::UMsg_tclMessage DFT 333 "set_scan_configuration -chain_count <..>" 
	    rt::UMsg_print "Each scan chain must be defined using 'set_scan_path' or 'define_scan_chain' \n"
	}

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc setDftInsertionConfiguration {routeScanEnable routeScanClock routeScanSerial 
				       synthesisOptimization preserveDesignName unscan mapEffort} {
	set ok true
	set des [rt::design]
	set dft [$des dft]
	switch -- $routeScanEnable {
	    "true" {
		$dft setRouteScanEnable 1
	    } 
	    "false" {
		$dft setRouteScanEnable 0
	    }
	    "" {}
	    default {
		rt::UMsg_tclMessage DFT 333 "set_dft_insertion_configuration -route_scan_enable $routeScanEnable" 
		set ok false
	    }
	}

	if {$routeScanClock ne ""} {
	    rt::UMsg_print "Ignoring 'set_dft_insertion_configuration -route_scan_clock $routeScanClock' \n"
	}

	if {[llength $routeScanSerial] && $routeScanSerial ne "true"} {
	    rt::UMsg_tclMessage DFT 333 "set_dft_insertion_configuration -route_scan_serial $routeScanSerial" 
	    set ok false
	}

	if {$synthesisOptimization eq "all"} {
	    rt::UMsg_tclMessage DFT 333 "set_dft_insertion_configuration -synthesis_optimization all" 
	    set ok false
	}

	if {[llength $preserveDesignName] && $preserveDesignName ne "true"} {
	    # rt::UMsg_print "Ignoring 'set_dft_insertion_configuration -preserve_design_name $preserveDesignName' \n"
	}

	if {$unscan eq "true"} {
	    rt::UMsg_tclMessage DFT 333 "set_dft_insertion_configuration -unscan true" 
	    set ok false
	}

	if {[llength $mapEffort]} {
	    rt::UMsg_print "Ignoring 'set_dft_insertion_configuration -map_effort $mapEffort' \n"
	}

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc writeScanDef {output} {
	set cmd "write_scandef $output"
	puts $cmd
	set res [eval $cmd]
	return -code ok $res
    }

    proc setDftEquivalentSignals {clocks} {
	set cmd "set_equivalent_test_clocks $clocks"
	puts $cmd
	set res [eval $cmd]
	return -code ok $res
    }

    proc reportScanPath {chain view cell testMode detail} {
	if {$view ne ""} {
	    rt::UMsg_print "Ignoring 'report_scan_path -view $view' \n"
	}
	if {$cell ne ""} {
	    rt::UMsg_print "Ignoring 'report_scan_path -cell $cell' \n"
	}
	if {$testMode ne ""} {
	    rt::UMsg_print "Ignoring 'report_scan_path -test_mode $testMode' \n"
	}

	if {$chain eq "all"} {
	    set chain ""
	}

	set des [rt::design]
	set dft [$des dft]
	$dft reportScanChain $chain $detail
    }


}


#
# DFTC compatible cmds
#
cli::addCommand set_scan_element {rtdftdc::setScanElement} {string} {string}
cli::addCommand set_dft_signal   {rtdftdc::setDftSignal} {string view} {string test_mode} {string type} \
    {string port} {string active_state} {string timing} {string period}  \
    {string hookup_pin} 

cli::addCommand set_dft_equivalent_signals {rtdftdc::setDftEquivalentSignals} {string}
cli::addCommand set_scan_path {rtdftdc::setScanPath} {string} {string ordered_elements} {string include_elements} \
    {string dedicated_scan_out} {string complete} {integer exact_length} \
    {string insert_terminal_lockup} {string scan_master_clock}           \
    {string scan_slave_clock} {string scan_enable} {string scan_data_in} \
    {string scan_data_out} {string view} {string class} {string hookup}  

cli::addCommand dft_drc         {rtdftdc::dftDrc} {boolean verbose}
cli::addCommand insert_dft      {rtdftdc::insertDft}
cli::addCommand write_scan_def  {rtdftdc::writeScanDef} {string output}
cli::addCommand read_test_model {rtdftdc::readTestModel} {string format} {string design} {string}
cli::addCommand set_dft_drc_configuration {rtdftdc::setDftDrcConfiguration} {string internal_pins} 
cli::addCommand set_scan_configuration {rtdftdc::setScanConfiguration} {string exclude_elements} \
    {string create_dedicated_scan_out_ports} {string clock_mixing} \
    {string add_lockup} {string chain_count} {string replace} {string insert_terminal_lockup} \
    {string lockup_type} {string style} {string internal_clocks}

cli::addCommand set_dft_insertion_configuration {rtdftdc::setDftInsertionConfiguration} {string route_scan_enable}     \
    {string route_scan_clock} {string route_scan_serial} {string synthesis_optimization} {string preserve_design_name} \
    {string unscan} {string map_effort}


cli::addCommand report_scan_path {rtdftdc::reportScanPath} {string chain} {string view} {string cell} \
    {string test_mode} {boolean detail}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
