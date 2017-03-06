# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************

# quit is already defined as a core tcl alias in vivado. Comment this definition to avoid conflicts.
#proc quit {} exit

if { [info exists ::env(XILINX_REALTIMEFPGA)] } {

  rename puts tcl_puts

  proc puts {args} {
    set argc [llength $args]
    if {[lindex $args 0] == "-nonewline"} {
	incr argc -1
	set string "[lindex $args 1]"
    } else {
	set string "[lindex $args 0]\n"
    }
    if {$argc > 1} {
	eval tcl_puts $args
    } else {
	rt::UMsg_print $string
    }
  }

} else {
    proc tcl_puts {args} {
        eval puts $args
    }
}

namespace eval utils {
    proc flatList {args} {
	while {1} {
	    set newargs [join $args]
	    if {$newargs == $args} {
		break
	    } else {
		set args $newargs
	    }
	}
	return $args
    }

    proc flushAll {} {
	rt::UMsgHandler_flush
	flush stdout
	flush stderr
    }
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
