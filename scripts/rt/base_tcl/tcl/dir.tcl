# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval dir {

    set curInstPath {}
    set curInstMods {}

    proc curInstMod {} {
	if {$dir::curInstMods == {}} {
	    set topDes [$rt::db topDesign]
	    set topMod [$topDes topModule]
	    lappend dir::curInstMods $topMod
	}
	return [lindex $dir::curInstMods end]
    }

    if { [info exists ::env(XILINX_REALTIMEFPGA)] } {
        proc setPrompt {} {
            set ::tcl_prompt1_string {return "\[$rt_tool_name:/[join $dir::curInstPath /]\]$ "}
            return
        }
    }

}

if { [info exists ::env(XILINX_REALTIMEFPGA)] } {
    dir::setPrompt
}

#############################################################################
cli::addCommand rt::lsd              {dir::lsd} {boolean ptr}
#############################################################################

proc dir::lsd {ptr} {
    set result {}
    set topDes [$rt::db topDesign]
    foreach des [$rt::db designs] {
	set t " "
	if {$des == $topDes} {
	    set t "*"
	}
	if {$ptr == "false"} {
	    puts "$t[$des name]"
	} else {
	    lappend result $des
	}
    }
    return $result
}

#############################################################################
cli::addCommand rt::ccd              {dir::ccd} {string}
#############################################################################

proc dir::ccd {nm} {
    $rt::db topDesign  [$rt::db findDesign $nm]
}

#############################################################################
cli::addCommand rt::pcd              {dir::pcd}
#############################################################################

proc dir::pcd {} {
    return [[$rt::db topDesign] name]
}

#############################################################################
cli::addCommand rt::lsm              {dir::lsm} {boolean top} {boolean ptr}
#############################################################################

proc dir::lsm {top ptr} {
    set result {}
    set topDes [$rt::db topDesign]
    set topMod [$topDes topModule]
    for {set mi [[$topDes modules] begin]} {[$mi ok]} {$mi incr} {
	set mod [$mi object]
	if {$top == "false" || [$mod parentCount] == 0} {
	    set tm " "
	    if {$mod == $topMod} {
		set tm "*"
	    }
	    if {$ptr == "false"} {
		puts "$tm[$mod name]"
	    } else {
		lappend result $mod
	    }
	}
    }
    return $result
}

#############################################################################
cli::addCommand rt::ccm              {dir::ccm} {string}
#############################################################################

proc dir::ccm {nm} {
    set topDes [$rt::db topDesign]
    $topDes topModule [$topDes findModule $nm]
}

#############################################################################
cli::addCommand rt::pcm              {dir::pcm}
#############################################################################

proc dir::pcm {} {
    set topDes [$rt::db topDesign]
    set topMod [$topDes topModule]
    return [$topMod name]
}

#############################################################################
cli::addCommand rt::lsi              {dir::lsi}
#############################################################################

proc dir::lsi {} {
    for {set ii [[[dir::curInstMod] instances] begin]} {[$ii ok]} {$ii incr} {
	set inst [$ii object]
	set ref [$inst reference]
	if {[$ref isModule] != "NULL"} {
	    set rm "m"
	} elseif {[$ref isGenome] != "NULL"} {
	    set rm "g"
	} else {
	    set rm "c"
	}
	puts [format "%s %-30s%s" $rm [$ref name] [$inst name]]
    }
}

#############################################################################
cli::addCommand rt::cci              {dir::cci} {string}
#############################################################################

proc dir::cci {path} {
    set instPath [split $path /]
    foreach nm $instPath {
	if {$nm == ".."} {
	    set mod [dir::curInstMod]
	    if {[$mod isTop]} {
		set gen [[$mod design] genome]
		$gen releaseDesign
	    }
	    set dir::curInstPath [lrange $dir::curInstPath 0 end-1]
	    set dir::curInstMods [lrange $dir::curInstMods 0 end-1]
	} elseif {$nm == "."} {
	} else {
	    set inst [[dir::curInstMod] findInstance $nm]
	    if {$inst != "NULL"} {
		lappend dir::curInstPath $nm
		set ref [$inst reference]
		set gen [$ref isGenome]
		if {$gen == "NULL"} {
		    set mod [$ref isRealModule]
		} else {
		    set des [$gen acquireDesign]
		    set mod [$des topModule]
		}
		lappend dir::curInstMods $mod
	    } else {
		puts "Inst '$nm' not found"
		return -code error
	    }
	}
    }
    dir::setPrompt
}

#############################################################################
cli::addCommand rt::lsc              {dir::lsc}
#############################################################################

proc dir::lsc {} {
    set topDes [$rt::db topDesign]
    set cells [$topDes cellCount]
    foreach cellCount [lsort -dictionary $cells] {
	set cell  [lindex $cellCount 0]
	set count [lindex $cellCount 1]
	set type  [[$rt::db findCell $cell] sequentialType]
	puts [format "%-8s %8d %s" $type $count $cell]
    }
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
