proc df_rpt {} {
    df::rpt
}

namespace eval df {

    variable debug_it  "xxx,gen-inv"
    variable partCnt
    variable partInst
    variable partArea
    variable instTypes
    variable genCnt
    variable genInterval
    
    proc rpt {} {

	variable partCnt
	variable partInst
	variable partArea
	variable instTypes
	variable genCnt
	variable genInterval
	variable sepSz     52

	set sep "----------------------------------------------------"
	puts $sep

	set des [rt::design]
	set mod [$des topModule]

	set genCnt 0
	set il [$mod instances]
	for {set ili [$il begin true false true]} {[$ili ok]} {$ili incr} {
	    set inst [$ili object]
	    set igen [$inst isGenome]
	    if {$igen != "NULL"} {
		incr genCnt
	    }
	}
	set genInterval [expr $genCnt / $sepSz]
	if {$genInterval == 0} {
	    set genInterval 1
	}
	set genCnt 0

	puts [format "%-20s %7s %7s %3s %7s %3s" \
		  "df-type" "#" "#inst" "%" "squm" "%"]

	rpt_mod $mod

	puts ""
	set totalInst 0
	set totalArea 0
	foreach mt [array names partCnt] {
	    foreach it [array names instTypes] {
		if [info exist partInst($mt,$it)] {
		    set totalInst [expr $totalInst + $partInst($mt,$it)]
		    set totalArea [expr $totalArea + $partArea($mt,$it)]
		}
	    }
	}

	foreach mt [lsort [array names partCnt]] {
	    if {$mt != ""} {
		set nr   $partCnt($mt)
		puts [format "%-20s %7d" $mt $nr]
		foreach it [lsort [array names instTypes]] {
		    if [info exist partInst($mt,$it)] {
			set cnt  $partInst($mt,$it)
			set sqm  $partArea($mt,$it)
			set cp [expr round($cnt / (.01 * $totalInst))]
			set ap [expr round($sqm / (.01 * $totalArea))]
			puts [format "    %-16s %7s %7d %3d %7d %3d" \
				  $it "" $cnt $cp [expr round($sqm)] $ap]
		    }
		}
	    }
	}
	puts $sep
	puts [format "%-20s %7s %7d 100 %7d 100" \
		  "TOTAL" "" $totalInst [expr round($totalArea)]]
	puts $sep
	unset partCnt
	unset partInst
	unset partArea
	unset instTypes
    }

    proc rpt_mod {mod} {
	variable debug_it
	variable partCnt
	variable partInst
	variable partArea
	variable instTypes
	variable genCnt
	variable genInterval

	set mt [$mod modType]
	if {[$mod isVirtualModule] != "NULL"} {
	    set mt "${mt}(v)"
	}
	if [info exist partCnt($mt)] {
	    incr partCnt($mt)
	} else {
	    set partCnt($mt)  1
	    set partInst($mt) 0
	    set partArea($mt) 0
	}
	set il [$mod instances]
	for {set ili [$il begin false true]} {[$ili ok]} {$ili incr} {
	    set inst [$ili object]
	    set igen [$inst isGenome]
	    if {$igen != "NULL"} {
		# puts "doing gen [$igen name]"
		if {[expr $genCnt % $genInterval] == 0} {
		    tcl_puts -nonewline "-"
		    flush stdout
		}
		incr genCnt
		set ides [$igen acquireDesign]
		rpt_mod [$ides topModule]
		$igen releaseDesign false
		continue
	    }
	    set imod [$inst isModule]
	    if {$imod != "NULL"} {
		rpt_mod $imod
		continue
	    }
	    set cell [$inst isCell]
	    set area [$rt::db squm [$cell instanceArea]]
	    if [$inst hasUserName] {
		set it "user"
		if {$mt == "sequential" && 
		    [$cell sequentialType] != "comb"} {
		    set it "gen"
		}
	    } else {
		set it "gen"
	    }
	    if [$cell isBuffer inv] {
		if {$inv == 0} {
		    if {[$inst isSized]} {
			set it "gen-shield"
		    } else {
			set it "$it-buf"
		    }
		} else {
		    set it "$it-inv"
		}
	    } elseif [$cell isClockGate] {
		set it "clockgate"		
	    } else {
		set it "$it-[$cell sequentialType]"
	    }
	    set instTypes($it) 1
	    set it "$mt,$it"
	    if {$it == $debug_it} {
		puts
		puts "$it [$inst fullName]"
	    }
	    if {[info exist partInst($it)] == 0} {
		set partInst($it) 1
		set partArea($it) $area
	    } else {
		incr partInst($it)
		set squm [expr $partArea($it) + $area]
		set partArea($it) $squm
	    }
	}
    }
}
# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
