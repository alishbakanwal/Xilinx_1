#!/bin/sh
# COPYRIGHT NOTICE
# Copyright 1986-1999, 2001-2013 Xilinx, Inc. All Rights Reserved.
#
# FILE: runPar.tcl
#
# This script runs one or more jobs in parallel on multiple hosts using ssh.
#
#    Bootstrap trick \
exec vivado -mode batch -source "$0" -tclargs ${1+"$@"}

global slots
global jobs
global emailList
global emailEveryJob
global scriptName

set scriptName    $argv0
set version       "0.3"
set versionDate   "February 1, 2013"
set author        "Xilinx"
set authorContact "support.xilinx.com"

puts "$scriptName: Version $version, $versionDate.  Written by: $author ($authorContact)."
puts "Calling options: $argv"

set rootDir [pwd]
set jobCmd "ssh -o BatchMode=yes"
#set jobCmd "ssh"
set parallelCount 0
set emailList ""
set emailEveryJob ""
set preCmd ""
set postCmd ""
set scriptPostHook ""
set scriptPreHook ""

# initialze associative array for slot scheduling
if {[array exists slots]} {
   array unset slots
}
if {[array exists jobs]} {
   array unset jobs
}

if {[package vsatisfies [package provide Tcl] 8.3]} {
    set timeMilliSeconds 1
} else {
    set timeMilliSeconds 0
}

proc usage {} {
   global scriptName
   puts "USAGE: $scriptName \[options\] job1.sh \[job2.sh ...\]"
   puts "   where options are:"
   puts "   -hosts \"machineOne,4,machineTwo,2\""
   puts "      option is a string (must be wrapped in double quotes)"
   puts "      contains a list of hosts, and the number of jobs for each host separated by commas"
   puts "   -email \"you@foo.com,two@foo.com\""
   puts "      option is a string (must be wrapped in double quotes)"
   puts "      that contains a list of email addresses separated by commas"
   puts "   -emailEveryJob"
   puts "      option is a switch"
   puts "      when included on the command line issues email on completion of each individual job, in addition to final summary email"
   puts "   -sourcePreHook script"
   puts "      option is a string"
   puts "      that contains a script to source before execution of every job on each host"
   puts "      used to setup environment variable."
   puts "      This script needs to be written in the same sh script language (csh,bash,ksh) as the job script"
   puts "   -sourcePostHook script"
   puts "      option is a string"
   puts "      that contains a script to source after execution of every job on each host"
   puts "      used to setup environment variable"
   puts "      This script needs to be written in the same sh script language (csh,bash,ksh) as the job script"
   puts "   -jobCmd cmd"
   puts "      option is a string"
   puts "      that contains a job submission command (such as ssh or qsub) which is visible in the executable path"
   puts "      default is ssh"
   puts "   -rootDir dir"
   puts "      option is a string"
   puts "      that contains a directory path in which to run the jobs"
   puts "      default is pwd"
   puts "   -help"
   puts "      option is a switch - prints this message"
   exit 1
}

if {$argc < 2} {
   puts "ERROR:  Incorrect number of arguments."
   usage
}

proc mailTo {subject to} {
   # TODO - mail is linux-only - investigate win32 MSA 
   if {[catch {exec mail -s "$subject" $to < /dev/null}]} {
      puts "ERROR: mail send failed!"
   }
}

proc readTest { id chan } {
   global slots
   global jobs
   global doneCount
   global emailList
   global emailEveryJob
   global scriptName
   if {[eof $chan]} {
      if {[catch {close $chan} errCode]} {
         # This job died!
         puts [format "ERROR %2d: $errCode" $id]
         set host $jobs($id)
         set slots($host) [expr $slots($host) + 1]
	 if {$emailList != ""} {
	    # TODO - mail is linux-only - investigate win32 MSA 
	    mailTo "FAILED $scriptName job $id on host ${host}" $emailList
	 }
      } else {
         # This job completed!
	 # TODO - final returncode value nonzero does not give an error code
         puts [format "%3d END" $id]
         set host $jobs($id)
         set slots($host) [expr $slots($host) + 1]
	 if {$emailList != "" && $emailEveryJob != ""} {
	    mailTo "COMPLETED $scriptName job $id on host ${host}" $emailList
	 }
      }
      incr doneCount
   } else {
      while {[gets $chan text]>=0} {
         puts [format "%3d-> $text" $id]
      }
   }
}

proc scheduleNode {id} {
   # returns an open node
   global slots
   global jobs
   foreach host [array names slots] {
      if {$slots($host) > 0} {
         # allocate a slot on this host
         set slots($host) [expr $slots($host) - 1]
         set jobs($id) $host
         return $host
      }
   }
   # we should never get here if thread safe and events handled correctly
   puts "ERROR:  No available nodes for scheduling job $id"
   return ""
}

proc buildJobCmd {cmd scriptPreHook scriptPostHook} {
   # builds a job command, if comd is a script, insert the pre- and post-hook script inside
   set preCmd ""
   set postCmd ""
   set scriptFileType ""
   set fileOut $cmd.runParHook
   if {$scriptPreHook == "" && $scriptPostHook == ""} {
      # do nothing
      return "\\\"${cmd}\\\""
   }
   if {$scriptPreHook != ""} {
      # TODO - support BASH .
      set preCmd "source \\\"${scriptPreHook}\\\"; "
   }
   if {$scriptPostHook != ""} {
      # TODO - support BASH .
      set postCmd "; source \\\"${scriptPostHook}\\\""
   }
   # is cmd a script?
   if {[file exists $cmd] && [file readable $cmd] && [file executable $cmd]} {
      # TODO - need to handle remote scripts - copy to local dir rename for hook insertion
      if {[catch "set FILEIN [open $cmd r]"]} {
         puts "WARNING:  error opening $cmd"
	 # punt and return as not a script, but a command
         return ${preCmd}${cmd}${postCmd}
      }
      if {[catch "set FILEOUT [open $fileOut w]"]} {
         puts "WARNING:  error opening $fileOut"
	 # punt and return as not a script, but a command
         return ${preCmd}${cmd}${postCmd}
      }
      while {[gets $FILEIN line] >= 0} {
	 puts $FILEOUT $line
         if {[regexp {^#\!(\S+)$} $line matchVar shellName]} {
            # switch on the basename of the shell defined in #!
	    # TODO - double check this list of shell types and the "source" syntax
            switch -exact -- [lindex [split $shellName "/"] end] {
	       "bash" -
	       "bsh" -
	       "ksh" -
	       "sh" {
	          if {$scriptPreHook != ""} {
	             puts $FILEOUT ". \"${scriptPreHook}\""
		  }
		  set scriptFileType "bash"
	       }
	       "csh" -
	       "tcsh" -
	       "ash" -
	       "zsh" -
	       default {
	          if {$scriptPreHook != ""} {
	             puts $FILEOUT "source \"${scriptPreHook}\""
		  }
	       }
	    }
         }
      }
      close $FILEIN
      if {$scriptPostHook != ""} {
         if {$scriptFileType != ""} {
	    puts $FILEOUT ". \"${scriptPostHook}\""
	 } else {
	    puts $FILEOUT "source \"${scriptPostHook}\""
	 }
      }
      close $FILEOUT
      # set execute permission on the shell script
      file attributes $fileOut -permissions +x
      return "\\\"${fileOut}\\\""
   }
   # cmd is probably not a script
   return ${preCmd}${cmd}${postCmd}
}

# process the args
for {set currentArgNum 0} {$currentArgNum < $argc} {incr currentArgNum} {
   set currentArg [lindex $argv $currentArgNum]
   if {[expr $currentArgNum + 1] < $argc} {
      set currentArgValue [lindex $argv [expr $currentArgNum +1]]
   }
   switch -regexp -- $currentArg {
      "^-h$" -
      "^-help" { 
         usage
      }
      "^-host" {
         set nodeList [split $currentArgValue ,]
	 # skip this arg the next pass through
	 incr currentArgNum
      }
      "^-email$" {
         set emailList $currentArgValue
	 # skip this arg the next pass through
	 incr currentArgNum
      }
      "^-emailEveryJob$" {
         set emailEveryJob "true"
      }
      "^-sourcePreHook" {
         set scriptPreHook $currentArgValue
	 # skip this arg the next pass through
	 incr currentArgNum
      }
      "^-sourcePostHook" {
         set scriptPostHook $currentArgValue
	 # skip this arg the next pass through
	 incr currentArgNum
      }
      "^-jobCmd" {
         set jobCmd $currentArgValue
	 # skip this arg the next pass through
	 incr currentArgNum
      }
      "^-rootDir" {
         set rootDir $currentArgValue
	 # skip this arg the next pass through
	 incr currentArgNum
      }
      "^-" {
         puts "ERROR:  Unknown option!"
         usage
      }
      default {
         lappend jobList $currentArg
      }
   }
   if {$currentArgNum >= $argc} {
      puts "ERROR: missing option value"
      usage
   }
}

if {![info exists nodeList]} {
   if {[info exists ::env(_LAUNCH_PAR_HOST_LIST)] && $::env(_LAUNCH_PAR_HOST_LIST) != ""} {
      # take this list from the environment variable if it exists
      # setenv _LAUNCH_PAR_HOST_LIST "hostOne,4,hostTwo,2"
      set nodeList [split $::env(_LAUNCH_PAR_HOST_LIST) ,]
   } else {
      # edit the list of machines directly here
      # else assume 1 slot on the current machine
      set nodeList [list [info hostname] 1]
   }
}

foreach {hostName numCpu} $nodeList {
   # TODO - figure out if there's any way to query the host to automatically see how many cpus
   set slots($hostName) $numCpu
   set parallelCount [expr $parallelCount + $numCpu]
}

append preCmd "cd \\\"${rootDir}\\\";"
#set jobTemplate [list $jobCmd %s $preCmd %s]

set timeFmt "%a %b %d %H:%M:%S %Z %Y"
puts "JOB COUNT: [llength $jobList]"
puts "START TIME: [clock format [clock seconds] -format $timeFmt]"

if {$timeMilliSeconds} {
 set timeStart [clock clicks -milliseconds]
} else {
 set timeStart [clock seconds]
}

set launchCount 0
set doneCount 0
while {$launchCount<[llength $jobList]} {
    # work until all jobs have been submitted
    if {$launchCount-$doneCount>=$parallelCount} {
	# All compute threads busy
	vwait doneCount
    }
    set host [scheduleNode [expr $launchCount + 1]]
#    set job [format $jobTemplate $host [buildJobCmd [lindex $jobList $launchCount] $scriptPreHook $scriptPostHook]]
    set job "$jobCmd $host $preCmd [buildJobCmd [lindex $jobList $launchCount] $scriptPreHook $scriptPostHook]"
    incr launchCount
    # TODO - fix the format {} issue
    puts [format "CMD%3d: $job" $launchCount]
    set chan [open "| $job 2>@ stdout"]
    fconfigure $chan -blocking 0
    fileevent $chan readable [list readTest $launchCount $chan]
}

while {$doneCount<$launchCount} {
    vwait doneCount ;# Wait for all jobs to finish
}

if {$timeMilliSeconds} {
 set timeStop [clock clicks -milliseconds]
} else {
 set timeStop [clock seconds]
}
puts "STOP TIME: [clock format [clock seconds] -format $timeFmt]"
set elapsedTime ""
if {$timeMilliSeconds} {
   set timeDiff [expr {($timeStop-$timeStart)*0.001}]
   set elapsedTime [format "ELAPSED TIME: %.3f s" $timeDiff]
} else {
   set timeDiff [expr {($timeStop-$timeStart)}]
   set elapsedTime [format "ELAPSED TIME: %.0f s" $timeDiff]
}
puts $elapsedTime
if {$emailList != ""} {
   # TODO - mail is linux-only - investigate win32 MSA 
   mailTo "DONE $scriptName JOBS: [llength $jobList] $elapsedTime" $emailList
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
