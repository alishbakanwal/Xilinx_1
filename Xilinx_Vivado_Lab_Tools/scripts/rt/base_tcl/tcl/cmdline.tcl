# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2011
#                             All rights reserved.
# ****************************************************************************
namespace eval rt {
    proc usage {} {
	set sp {          }
	puts {usage:   realTime [<options>] [<files>]}
	puts "$sp -32         : run 32-bit executable even on 64-bit platform"
        puts "$sp -gui        : launch graphical user interface"
        puts "$sp -nogui      : run non-graphical executable (disables graphical user interface)"
	puts "$sp -designer   : invoke RealTime Designer"
	puts "$sp -explorer   : invoke RealTime Explorer"
	puts "$sp -queue      : queue for a license if one is not immediately available"
	puts "$sp -log <name> : create log/cmd files with the given <name> prefix"
	puts "$sp -e <script> : execute <script> first"
	puts "$sp -noinit     : do not load init files (~/.oasys/realTime.tcl and ./realTime.tcl)"
	puts "$sp -noexit     : do not exit after loading <files>"
	puts "$sp -echo       : echo commands while loading <files>"
	puts "$sp -help       : print this message"
	MRealTime_forceExit -1
    }

    proc getopt {_argv name {_var ""} {default ""}} {
	upvar 1 $_argv argv $_var var
	set pos [lsearch -regexp $argv ^$name$]
	if {$pos>=0} {
	    set to $pos
	    if {$_var ne ""} {
		set var [lindex $argv [incr to]]
	    }
	    set argv [lreplace $argv $pos $to]
	    return 1
	} else {
	    if {[llength [info level 0]] == 5} {set var $default}
	    return 0
	}
    }
    
    #puts "Initial argv: $argv"
    
    # -- : strip wrapper seperator
    getopt argv --
    
    # -noinit
    set cmd_line_no_init [getopt argv -noinit]
    # -noexit
    set cmd_line_no_exit [getopt argv -noexit]

    # -e : eval the specified string
    getopt argv -e cmd_line_eval ""
    
    # -echo : echo sourcing 
    set cmd_line_echo ""
    if [getopt argv -echo] {
	set cmd_line_echo "-echo"
    }
    
    if [getopt argv -h.*] {
	usage
    }

    set pos [lsearch -regexp $argv ^-.*]
    if {$pos>=0} {
	puts "error:   unknown option: [lindex $argv $pos]"
	usage
    }

    if {$argv != ""} {
	set cmd_line_sources $argv
    }
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
