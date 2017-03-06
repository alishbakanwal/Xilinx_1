# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval rt {

    proc getLogFileNames {} {
	global env
	set logFileFmt "realTime.log.%02d"
	if [info exists env(RT_LOGFILE)] {
	    set logFileFmt $env(RT_LOGFILE)
	}
	set cmdFileFmt "realTime.cmd.%02d"
	if [info exists env(RT_CMDFILE)] {
	    set cmdFileFmt $env(RT_CMDFILE)
	}
	set maxIndex 99
	if [info exists env(RT_LOGFILE_MAXINDEX)] {
	    set maxIndex $env(RT_LOGFILE_MAXINDEX)
	}
	set oldestIdx ""
	if {[format $logFileFmt 0] != $logFileFmt} {
	    set idx 0
	    while { 1 } {
		if {$idx > $maxIndex} {
		    set logFile [format $logFileFmt $oldestIdx]
		    set cmdFile [format $cmdFileFmt $oldestIdx]
		    break;
		}
		set logFile [format $logFileFmt $idx]
		set cmdFile [format $cmdFileFmt $idx]
		if {![file exists $logFile]} {
		    break;
		}
		if {($oldestIdx == "") ||
		    ($oldestTime > [file mtime $logFile])} {
		    set oldestIdx $idx
		    set oldestTime [file mtime $logFile]
		}
		set idx [expr $idx + 1]
	    }
	} else {
	    set logFile $logFileFmt
	    set cmdFile $cmdFileFmt
	}
	return "$logFile $cmdFile"
    }
    
    set fileNames [getLogFileNames]

    if { [info exists env(XILINX_REALTIMEFPGA)] } { 
        rt::UMsg_print "("
        rt::UMsgHandler_openLogFile [lindex $fileNames 0]
        if {[file exists [lindex $fileNames 0]]} {
            rt::UMsg_print "$fileNames"
            set cmdFd [open [lindex $fileNames 1] "w"]
        }
        rt::UMsg_print ")"
    } else {
      # we do NOT want to set this when running from planAhead.
      # set rt::cmdFd [open [lindex $fileNames 1] "w"]
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
