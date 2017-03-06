# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2009
#                             All rights reserved.
# ****************************************************************************

namespace eval ctlParse {

    # Basic CTL parser

    # Low-level tokenizing & parsing variables
    variable tkNone 0
    variable tkStr  1	; # string with double-quotes
    variable tkId   2	; # identifier
    variable tkNum  3	; # any number

    variable tokenVal
    variable tokenType

    variable fp
    variable ctlFile
    variable lineNum

    variable EOF

    variable line
    variable lineLen
    variable charIdx

    variable outFp
    variable indent
    variable needIndent

    variable debugMode
    variable reportIgnore


    # CTL structures returned by parser

    # ScanChainNames: array of scan chain names, to help with ScanChains array 
    variable ScanChainNames

    # ScanChains: name,attr -> value, e.g.,
    #     ScanChains("chain0","ScanLength") => 104
    #     ScanChains("chain0","ScanIn") => "TEST__SIN[0]"
    #     etc..
    variable ScanChains

    # CTLs
    variable CTLs

    # SignalProps: defines properties defined on signals
    #    SignalProps("TEST__CLOCK_DR","ActiveState") => "ForceUp"
    variable SignalProps

    proc init {} {
	set ctlParse::tokenVal ""
	set ctlParse::tokenType $ctlParse::tkNone

	set ctlParse::fp 0
	set ctlParse::ctlFile ""
	set ctlParse::lineNum 0
	
	set ctlParse::EOF false

	set ctlParse::line ""
	set ctlParse::lineLen 0
	set ctlParse::charIdx 0

	set ctlParse::outFp 0
	set ctlParse::indent 0
	set ctlParse::needIndent false

	set ctlParse::debugMode false
	set ctlParse::reportIgnore false

	array unset ctlParse::ScanChainNames *
	array unset ctlParse::ScanChains *
	array unset ctlParse::CTLs *
	array unset ctlParse::SignalProps *
    }
    
    proc getLine {} {
	set ctlParse::lineLen [gets $ctlParse::fp ctlParse::line]
	incr ctlParse::lineNum
	if {$ctlParse::lineLen == -1} {
	    set ctlParse::EOF true
	    return false
	}
	set ctlParse::charIdx 0
	return true
    }

    proc char {} {
	return [string index $ctlParse::line $ctlParse::charIdx]
    }

    proc skipWhite {} {
	while {$ctlParse::charIdx < $ctlParse::lineLen && [string is space [char]]} {
	    incr ctlParse::charIdx
	}
    }

    proc scanIdent {} {
	# set token to identifier text
	set ctlParse::tokenType $ctlParse::tkId
	while {true} {
	    set ch [char]
	    if {[string is alnum $ch] || $ch eq "_"} {
		append ctlParse::tokenVal $ch
		incr ctlParse::charIdx
	    } else {
		return true
	    }
	}
    }

    proc scanNumber {} {
	set ctlParse::tokenType $ctlParse::tkNum
	while {true} {
	    set ch [char]
	    if {[string is integer $ch] || $ch eq "." || $ch eq "e" || $ch eq "E" || $ch eq "-"} {
		append ctlParse::tokenVal $ch
		incr ctlParse::charIdx
	    } else {
		return true
	    }
	}
    }

    proc scanString {} {
	# set token to string text with surrouding \" characters stripped
	set ctlParse::tokenType $ctlParse::tkStr
	incr ctlParse::charIdx
	while {true} {
	    set ch [char]
	    incr ctlParse::charIdx
	    if {$ch eq "\""} {
		return true
	    }
	    append ctlParse::tokenVal $ch
	}
    }

    proc scanEscape {} {
	incr ctlParse::charIdx
	set ch [char]
	incr ctlParse::charIdx
	set ctlParse::tokenVal "\\$ch"
	return true
    }

    proc scanChar {} {
	set ch [char]
	incr ctlParse::charIdx
	set ctlParse::tokenVal $ch
	return true
    }

    proc scanToken {} {
	set ctlParse::tokenVal ""
	set ctlParse::tokenType $ctlParse::tkNone

	while {true} {
	    skipWhite
	    if {$ctlParse::charIdx >= $ctlParse::lineLen} {
		if {![getLine]} {
		    return false
		}
		skipWhite
	    }
	    if {$ctlParse::charIdx >= $ctlParse::lineLen} {
		continue
	    }

	    if {[string range $ctlParse::line $ctlParse::charIdx [expr {$ctlParse::charIdx + 1}]] eq "//"} {
		set ctlParse::charIdx $ctlParse::lineLen
		continue
	    }
	    set ch [char]
	    if {[string is alpha $ch] || $ch eq "_"} {
		return [scanIdent]
	    } elseif {[string is integer $ch]} {
		return [scanNumber]
	    } elseif {$ch eq "\""} {
		return [scanString]
	    } elseif {$ch eq "\\"} {
		return [scanEscape]
	    } else {
		return [scanChar]
	    }
	}
    }

    proc debug {msg} {
	if {$ctlParse::debugMode} {
	    puts "debug: $msg"
	}
    }

    proc msgPrefix {} {
	return "$ctlParse::ctlFile:$ctlParse::lineNum:"
    }

    proc infoMsg {msg} {
	puts "[msgPrefix] info: $msg"
    }

    proc warnMsg {msg} {
	puts "[msgPrefix] warning: $msg"
    }

    proc ignoring {msg} {
	if {$ctlParse::reportIgnore} {
	    warnMsg "ignoring $msg"
	}
    }

    proc errMsg {msg} {
	puts "[msgPrefix] error: $msg"
	return -code error
    }

    proc expected {msg} {
	errMsg "expected $msg, got [token]"
    }

    proc token {} {
	return $ctlParse::tokenVal
    }

    # Three basic procs:
    #   at <token>	are we looking at <token>?
    #   eat <token>	must be looking at <token>, eat it
    #   ate <token>     if looking at <token>, then eat & return true, else return false
    # plus special cases for Str, Id, and Num.

    proc at {tk} {
	return [expr {[token] eq $tk}]
    }
    proc atStr {} {
	return [expr {$ctlParse::tokenType eq $ctlParse::tkStr}]
    }
    proc atId {} {
	return [expr {$ctlParse::tokenType eq $ctlParse::tkId}]
    }
    proc atNum {} {
	return [expr {$ctlParse::tokenType eq $ctlParse::tkNum}]
    }

    proc eat {tk} {
	if {[at $tk]} {
	    scanToken
	    return true
	} else {
	    expected $tk
	}
    }

    proc eatNum {} {
	if {[atNum]} {
	    set rsl [token]
	    scanToken
	    return $rsl
	} else {
	    expected "number"
	}
    }

    proc eatId {} {
	if {[atId]} {
	    set rsl [token]
	    scanToken
	    return $rsl
	} else {
	    expected "identifier"
	}
    }

    proc eatStr {} {
	if {[atStr]} {
	    set rsl [token]
	    scanToken
	    return $rsl
	} else {
	    expected "string"
	}
    }


    proc ate {tk} {
	if {[at $tk]} {
	    scanToken
	    return true
	} else {
	    return false
	}
    }

    # must eat a "{"
    proc openBrace {} {
	eat "\{"
    }

    # optionally eat a "}", detects the end of a list
    proc closeBrace {} {
	return [ate "\}"]
    }

    proc parseName {} {
	debug "parseName"
	if {[atId]} {
	    return [eatId]
	} elseif {[atStr]} {
	    return [eatStr]
	} else {
	    errMsg "expected identifier or string, found [token]"
	}
    }

    proc parseOptName {} {
	if {[atId] || [atStr]} {
	    return [parseName]
	} else {
	    return ""
	}
    }

    proc ignoreStmt {} {
	# read up to ";"
	while {![ate ";"]} {
	    scanToken; # munch, munch
	}
    }

    proc parseList {} {
	set rsl {}
	openBrace
	while {![closeBrace]} {
	    if {[at "\{"]} {
		set val [parseList]
	    } else {
		set val [token]
		scanToken
	    }
	    lappend rsl $val
	}
	return $rsl
    }

    proc ignoreList {} {
	parseList
    }


    proc parseHistoryList {} {
	debug "parseHistoryList"
	ignoreList
    }

    proc parseHeaderList {} {
	debug "parseHeaderList: [token]"
	openBrace
	while {![closeBrace]} {
	    switch [token] {
		"Title" -
		"Date" -
		"Source" {
		    scanToken
		    eatStr
		    eat ";"
		}
		"History" {
		    parseHistoryList
		}
		default {
		    expected "header item: Title,Date,Source, etc."
		}
	    }
	}
    }

    proc parseCellNameList {} {
	debug "parseCellNameList"
	set rsl {}
	while {![at ";"]} {
	    set cell ""
	    if {[ate "!"]} {
		append cell "!"
	    }
	    append cell [parseName]
	    lappend rsl $cell
	}
	return $rsl
    }

    proc parseScanStructItem {chain_name} {
	debug "parseScanStructItem"
	set kw [token]
	scanToken
	switch $kw {
	    "ScanLength" -
	    "ScanOutLength" {
		set val [eatNum]
	    }
	    "ScanCells" {
		ignoring "ScanCells cellname_list"
		parseCellNameList
	    }
	    "ScanIn" -
	    "ScanOut" -
	    "ScanEnable" -
	    "ScanMasterClock" -
	    "ScanSlaveClock" {
		set val [parseName]
	    }
	    "ScanInversion" {
		set val [token]
		if {$val ne "1" && $val ne "0"} {
		    expected "'0' or '1'"
		}
		scanToken
	    }
	    default {
		expected "scan struct item"
	    }
	}
	eat ";"
	if {[info exists val]} {
	    set ctlParse::ScanChains($chain_name,$kw) $val
	}
    }

    proc parseScanStructures {} {
	debug "parseScanStructures: [token]"
	eat "ScanStructures"
	set scan_name [parseName]
	openBrace
	while {![closeBrace]} {
	    eat "ScanChain"
	    set chain_name [parseName]
	    set ctlParse::ScanChainNames($chain_name) 1
	    openBrace
	    while {![closeBrace]} {
		parseScanStructItem $chain_name
	    }
	}
    }

    proc parseInternal_DataType {pin_name} {
	while {![at "\{"]} {
	    set kw [token]
	    scanToken
	    switch $kw {
		"Constant" -
		"ScanMasterClock" -
		"MasterClock" -
		"ScanEnable" -
		"ScanDataIn" -
		"ScanDataOut" -
		"Reset" {
		    set ctlParse::SignalProps($pin_name,$kw) 1
		}
		";" {
		    return
		}
		default {
		    expected "DataType modifier (Constant, ScanMasterClock, etc.)"
		}
	    }
	}
	openBrace
	while {![closeBrace]} {
	    set kw [token]
	    scanToken
	    set ctlParse::SignalProps($pin_name,$kw) [token]
	    scanToken
	    eat ";"
	}
    }

    proc parseCTL_Internal {ctl_name} {
	debug "parseCTL_Internal"
	set pin_name [parseName]
	openBrace
	while {![closeBrace]} {
	    set kw [token]
	    scanToken
	    switch $kw {
		"DataType" {
		    parseInternal_DataType $pin_name
		}
		"CaptureClock" -
		"LaunchClock" {
		    set sig [token]
		    set ctlParse::SignalProps($pin_name,$kw) $sig
		    scanToken
		    set attrs [parseList]
		    set ctlParse::SignalProps($sig,$kw) $attrs
		}
		"OutputProperty" {
		    set ctlParse::SignalProps($pin_name,[token]) 1
		    scanToken
		    eat ";"
		}
		"IsConnected" {
		    scanToken ; # ignore in/out
		    ignoreList
		}
		"InputProperty" -
		"ScanStyle" {
		    ignoreStmt
		}
		"StrobeRequirements" {
 		    ignoreList
 		}
		"CoreSelect" -
		"ClockEnable" -
		"InOutControl" -
		"Oscillator" -
		"OutDisable" -
		"OutEnable" -
		"MasterClock" -
		"MemoryRead" -
		"MemoryWrite" -
		"SlaveClock" -
		"Reset" -
		"ScanEnable" -
		"ScanMasterClock" -
		"ScanSlaveClock" -
		"TestAlgorithm" -
		"TestInterrupt" -
		"TestPortSelect" -
		"TestRun" -
		"TestWrapperControl" {
		    ignoring "CTL:Internal: $kw"
		}
		default {
		    expected "CTL Internal item"
		}
	    }
	}
    }

    proc parseCTL {} {
	debug "parseCTL"
	eat "CTL"
	set ctl_name [parseOptName]
	openBrace
	while {![closeBrace]} {
	    set kw [token]
	    scanToken
	    switch $kw {
		"TestMode" -
		"Inherit" {
		    set ctlParse::CTLs($ctl_name,$kw) [token]
		    scanToken
		    eat ";"
		}
		"Internal" {
		    openBrace
		    while {![closeBrace]} {
			parseCTL_Internal $ctl_name
		    }
		}
		"DomainReferences" {
		    ignoreList
		}
		"Focus" {
		    if {![ate "Top"]} {
			eat "CoreInstance"
			while {[atStr]} {
			    eatStr
			}
		    }
		    ignoreList
		}
		default {
		    expected "CTL item"
		}
	    }
	}
    }

    proc parseInclude {} {
	ignoring "Include"
	scanToken
	ignoreStmt
    }

    proc parseHeader {} {
	ignoring "Header"
	scanToken
	ignoreStmt
    }

    proc parseUserKeywords {} {
	ignoring "UserKeywords"
	scanToken
	ignoreStmt
    }

    proc parseUserFunctions {} {
	ignoring "UserFunctions"
	scanToken
	ignoreStmt
    }

    proc parseSignals {} {
	ignoring "Signals"
	scanToken
	ignoreList
    }

    proc parseSignalGroups {} {
	ignoring "SignalGroups"
	scanToken
	parseOptName
	ignoreList
    }

    proc parsePatternExec {} {
	ignoring "PatternExec"
	scanToken
	parseOptName
	ignoreList
    }

    proc parsePatternBurst {} {
	ignoring "PatternBurst"
	scanToken
	parseOptName
	ignoreList
    }

    proc parseTiming {} {
	ignoring "Timing"
	scanToken
	parseOptName
	ignoreList
    }

    proc parseSpec {} {
	ignoring "Spec"
	scanToken
	parseOptName
	ignoreList
    }

    proc parseSelector {} {
	ignoring "Selector"
	scanToken
	parseOptName
	ignoreList
    }

    proc parsePattern {} {
	ignoring "Pattern"
	scanToken
	parseOptName
	ignoreList
    }

    proc parseProcedures {} {
	ignoring "Procedures"
	scanToken
	parseOptName
	ignoreList
    }

    proc parseMacroDefs {} {
	ignoring "MacroDefs"
	scanToken
	parseOptName
	ignoreList
    }

    proc parseAnn {} {
	ignoring "Ann"
	scanToken
	ignoreList
    }


    proc parseEnvironment {} {
	debug "parseEnvironment"
	scanToken
	parseName
	openBrace
	while {![closeBrace]} {
	    parseCTL
	}
    }

    proc parseBlock {} {
	debug "parseBlock: [token]"
	switch [token] {
	    "Include" {
		parseInclude
	    }
	    "Header" {
		parseHeader
	    }
	    "UserKeywords" {
		parseUserKeywords
	    }
	    "UserFunctions" {
		parseUserFunctions
	    }
	    "Signals" {
		parseSignals
	    }
	    "SignalGroups" {
		parseSignalGroups
	    }
	    "PatternExec" {
		parsePatternExec
	    }
	    "PatternBurst" {
		parsePatternBurst
	    }
	    "Timing" {
		parseTiming
	    }
	    "Spec" {
		parseSpec
	    }
	    "Selector" {
		parseSelector
	    }
	    "ScanStructures" {
		parseScanStructures
	    }
	    "Pattern" {
		parsePattern
	    }
	    "Procedures" {
		parseProcedures
	    }
	    "MacroDefs" {
		parseMacroDefs
	    }
	    "Ann" {
		parseAnn
	    }
	    "Environment" {
		parseEnvironment
	    }
	}
    }

    proc parseSession {} {
	while {!$ctlParse::EOF} {
	    parseBlock
	}
    }


    proc parseSTIL {} {
	debug "parseSTIL"
	scanToken	; # scan to initialize the token routines
	eat "STIL"
	eatNum
	ignoreList

	if {[ate "Header"]} {
	    parseHeaderList
	}

	parseSession
    }


    proc nl {} {
	puts $ctlParse::outFp ""
	set ctlParse::needIndent true
    }

    proc write {} {
	if {$ctlParse::needIndent} {
	    for {set i 0} {$i < $ctlParse::indent} {incr i} {
		puts -nonewline $ctlParse::outFp "    "
	    }
	    set ctlParse::needIndent false
	} else {
	    puts -nonewline $ctlParse::outFp " "
	}
	if {$ctlParse::tokenType == $ctlParse::tkStr} {
	    puts -nonewline $ctlParse::outFp "\"[token]\""
	} else {
	    puts -nonewline $ctlParse::outFp [token]
	}

	if {[token] eq ";"} {
	    nl
	} elseif {[token] eq "\{"} {
	    nl
	    incr ctlParse::indent
	} elseif {[token] eq "\}"} {
	    nl
	    incr ctlParse::indent -1
	}
    }

    proc reportScanChains {verbose} {
	set res {} 
	foreach scan_chain [lsort [array names ctlParse::ScanChainNames]] {
	    set opts ""
	    append opts " -name $scan_chain"
	    foreach idx [lsort [array names ctlParse::ScanChains]] {
		set indices [split $idx ","]
		if {$scan_chain eq [lindex $indices 0]} {
		    set kw  [lindex $indices 1]
		    set sig $ctlParse::ScanChains($idx)
		    switch $kw {
			"ScanIn" {
			    append opts " -scan_in $sig"
			    if {[info exists ctlParse::SignalProps($sig,CaptureClock)]} {
				set val $ctlParse::SignalProps($sig,CaptureClock)
				append opts " -capture_clock $val"
				if {[info exists ctlParse::SignalProps($val,CaptureClock)]} {
				    set val2 $ctlParse::SignalProps($val,CaptureClock)
				    if {-1 != [lsearch $val2 "LeadingEdge"]} {
					append opts " -capture_edge 1"
				    } elseif {-1 != [lsearch $val2 "TrailingEdge"]} {
					append opts " -capture_edge 0"
				    }
				}
			    }
			}

			"ScanOut" {
			    append opts " -scan_out $sig"
			    if {[info exists ctlParse::SignalProps($sig,LaunchClock)]} {
				set val $ctlParse::SignalProps($sig,LaunchClock)
				append opts " -launch_clock $val"
				if {[info exists ctlParse::SignalProps($val,LaunchClock)]} {
				    set val2 $ctlParse::SignalProps($val,LaunchClock)
				    if {-1 != [lsearch $val2 "LeadingEdge"]} {
					append opts " -launch_edge 1"
				    } elseif {-1 != [lsearch $val2 "TrailingEdge"]} {
					append opts " -launch_edge 0"
				    }
				}
			    }
			    if {[info exists ctlParse::SignalProps($sig,SynchLatch)]} {
				append opts " -tail_lockup_latch"
			    } elseif {[info exists ctlParse::SignalProps($sig,SynchFF)]} {
				append opts " -tail_lockup_ff"
			    }
			}

			"ScanLength" {
			    append opts " -length $sig"
			}
			"ScanEnable" {
			    append opts " -scan_enable $sig"
			    if {[info exists ctlParse::SignalProps($sig,ActiveState)]} {
				set state $ctlParse::SignalProps($sig,ActiveState)
				if {$state eq "ForceUp" || $state eq "F"} {
				    set state "1"
				} else {
				    set state "0"
				}
				append opts " -scan_enable_active $state"
			    }
			}
			"ScanMasterClock" {
			    # ignore for now ??
			}
			default {
			    errMsg "unknown keyword: $kw"
			}
		    }
		}
	    }
	    lappend res $opts
	    if {$verbose} {
		puts "scan_model: $opts"
	    }
	}
	return $res
    }


    proc parse {file} {
	init
	set ctlParse::ctlFile $file
	set ctlParse::fp [open $ctlParse::ctlFile "r"]
	if {$ctlParse::fp eq ""} {
	    errMsg "could not open $file"
	} 
	set status [catch parseSTIL rsl]
	puts $rsl
	close $ctlParse::fp
    }

    proc readCtl {cell instance verbose file} {
	parse $file
	set chains [reportScanChains $verbose]
	if {$cell != ""} {
	    foreach chain $chains {
		set cmd "define_scan_model -lib_cell $cell $chain"
		eval $cmd
	    }
	} elseif {$instance != ""} {
	    foreach chain $chains {
		set cmd "define_scan_model -instance $instance $chain"
		eval $cmd
	    }
	}
    }

}


cli::addCommand read_ctl {ctlParse::readCtl} {string lib_cell} {*string instance} {boolean verbose} {string}
# For testing a ctl file - do 
#    read_ctl -verbose file.ctl




# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
