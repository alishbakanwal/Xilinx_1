# Main procs:
#----------------------------
# enable_autoIncrCompile  --> sets auto-incr-scheme && swaps launch_runs proc with incr_launch_runs
# disable_autoIncrCompile --> resets auto-incr-scheme && undo the swap of launch_runs procs
# 
# Debug/Helper procs:
#---------------------------
# isAutoIncrFlowEnabled
# getAutoIncrCompileSelectedScheme
# getAutoIncrCompileSelectedSchemeCheckpoint
#
# Trick:
#---------------------------
# launch_runs             --> if auto-incr-is-enabled will run incr_launch_runs, passing all the arguments to _real_launch_runs.
#                         --> before calling _real_launch_runs appropriate INCREMENTAL_CHECKPOINT is set on the impl-runs
#
#

proc isAutoIncrFlowEnabled {} {
  global autoIncrCompileScheme
  if {![info exists autoIncrCompileScheme] || [ string length $autoIncrCompileScheme ] == 0} {
  return 0
  }
  return 1
}

proc getAutoIncrCompileSelectedScheme {} {
  global autoIncrCompileScheme;
  if { [isAutoIncrFlowEnabled] } {
    return $autoIncrCompileScheme
  } else {
    return ""
  }
}

#TODO: remove the duplication from incr_launch_runs
proc getAutoIncrCompileSelectedSchemeCheckpoint {} {
  set schemeName [getAutoIncrCompileSelectedScheme]
  if {[string length $schemeName]==0} {
    return ""
  }

	set all_impl_runs 									[get_runs -filter IS_IMPLEMENTATION]
	set all_impl_runs_placed_or_routed 	[get_impl_runs_placed_or_routed $all_impl_runs]
	switch $schemeName {
	LastRun {
	  set refRun [ lindex [ lsort -command compare_runs_dcp_time $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
	Fixed {
	   set refRun [ get_runs $autoIncrCompileScheme_RunName ]  
  } 	 
  BestWNS {
		 set refRun [ lindex [ lsort -command compare_runs_wns $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
	BestTNS {
	  set refRun [ lindex [ lsort -command compare_runs_tns $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
  }
	set guideFile [ get_placed_or_routed_dcp $refRun ]
  if {[file exists $guideFile]} {
    return $guideFile
  } else {
    return ""
  }
}

proc lshift listVar {
    upvar 1 $listVar l
    set r [lindex $l 0]
    set l [lreplace $l [set l 0] 0]
    return $r
}

proc is_run_routed { run } {
			return [ string match "route_design Complete*" [ get_property STATUS $run ]  ]
}

proc is_run_placed_but_not_routed { run } {
			return [ string match "place_design Complete*" [ get_property STATUS $run ]  ]
}

# pre-condition: assumes the convention impl_dir/top_routed.dcp
proc get_placed_or_routed_dcp { run } {
			set dcpFile ""
			set is_impl_run [ get_property  IS_IMPLEMENTATION $run ] 

			if {!$is_impl_run} {
				return $dcpFile
			}
			#set top 			[ get_property TOP [ get_designs $run] ]
			set impl_dir 	[ get_property DIRECTORY $run ]

			if {[is_run_routed $run]} {
				set dcpFile [ glob -directory $impl_dir *_routed.dcp ]
			} elseif {[is_run_placed_but_not_routed $run]} {
				set dcpFile [glob -directory $impl_dir *_placed.dcp ]
			}
			
	return $dcpFile
}


proc get_impl_runs_placed_or_routed { impl_runs } {
	set runs_placed_or_routed [ list  ]
	foreach run $impl_runs {
			if {[is_run_routed $run] || [is_run_placed_but_not_routed $run] } { 
				lappend runs_placed_or_routed $run
			}
	}
	return $runs_placed_or_routed
}

proc compare_runs_wns {run_a run_b} {
				set wns_a  [ get_property STATS.WNS $run_a]
				set wns_b  [ get_property STATS.WNS $run_b]
				return [ expr {$wns_a < $wns_b} ]
}

proc compare_runs_tns {run_a run_b} {
				set tns_a  [ get_property STATS.TNS $run_a]
				set tns_b  [ get_property STATS.TNS $run_b]
				return [ expr {$tns_a < $tns_b} ]
}

proc compare_runs_dcp_time {run_a run_b} {
				set dcp_a [ get_placed_or_routed_dcp $run_a ]
				set dcp_b [ get_placed_or_routed_dcp $run_b ]
				return [ expr {[file mtime $dcp_a] < [file mtime $dcp_b]} ]
}

proc configure_incr_flow { run_name } {
  global autoIncrCompileScheme 
  global autoIncrCompileScheme_RunName

  set run [get_runs $run_name ]

	set all_impl_runs 									[get_runs -filter IS_IMPLEMENTATION]
	set all_impl_runs_placed_or_routed 	[get_impl_runs_placed_or_routed $all_impl_runs]

  puts "AutoIncrementalCompile: Scheme Enabled: $autoIncrCompileScheme "
	switch $autoIncrCompileScheme {
	LastRun {
	  set refRun [ lindex [ lsort -command compare_runs_dcp_time $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
	Fixed {
	   set refRun [ get_runs $autoIncrCompileScheme_RunName ]  
  } 	 
  BestWNS {
		 set refRun [ lindex [ lsort -command compare_runs_wns $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
	BestTNS {
	  set refRun [ lindex [ lsort -command compare_runs_tns $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
  }
	# set the guide file if it exists
	set guideFile [ get_placed_or_routed_dcp $refRun ]
	if {![ file exists $guideFile]} {
		puts "AutoIncrementalCompile: Incremental Flow not enabled as $guideFile for scheme $autoIncrCompileScheme does not exist"
		return;
		} else {
			puts "AutoIncrementalCompile: Incremental Flow enabled for $run with $refRun 's  $guideFile as the reference checkpoint"
			set_property INCREMENTAL_CHECKPOINT $guideFile $run
		}
}

				
proc incr_launch_runs { args } {
  set orig_args $args
	# takes all arguments of launch_runs
	# parse args to filter out args with switches
	# remaining args are of runs ; set INCREMENTAL_CHECKPOINT property for those runs
	# real_launch_runs with modified INCREMENTAL_CHECKPOINT properties for applicable runs


  while {[llength $args]} {
    set name [lshift args]
		# launch_runs  [-jobs <arg>] [-scripts_only] [-lsf <arg>] [-sge <arg>]
     #        [-dir <arg>] [-to_step <arg>] [-next_step] [-host <args>]
     #        [-remote_cmd <arg>] [-email_to <args>] [-email_all]
     #        [-pre_launch_script <arg>] [-post_launch_script <arg>] [-force]
     #        [-quiet] [-verbose] <runs>...

    switch $name {
      -jobs -
      -lsf -
      -sge -
      -dir -
      -to_step -
      -host -
      -remote_cmd -
      -email_to -
      -pre_launch_script -
      -post_launch_script { lshift args; }
			-scripts_only -
      -next_step -
      -email_all -
      -force -
      -quiet -
      -help  -
      -verbose { }
		default {
      configure_incr_flow $name 
      }
    }
		# processing all args ends
   }
	eval _real_launch_runs $orig_args 
}

proc swapLaunchRunsWithIncrLaunchRuns {} {
  global swapRuns
	rename launch_runs 			_real_launch_runs
	rename incr_launch_runs launch_runs
  set swapRuns 1
}

proc isLaunchRunsSwappedWithIncr {} {
  global swapRuns
  if {![info exists swapRuns] || $swapRuns==0} {
    return 0
  } else {
    return 1
  }
}

proc swapIncrLaunchRunsWithLaunchRuns {} {
  global swapRuns
	rename launch_runs 				incr_launch_runs 
	rename _real_launch_runs 	launch_runs 
  set swapRuns 0
}

# see -help for arguments
proc enable_autoIncrCompile { args } {

  global autoIncrCompileScheme 
  global autoIncrCompileScheme_RunName
  global swapRuns

  set err 0
  set help 0
  set schemeName ""

  if { 0 == [llength $args] } {
   puts "enable_autoIncrCompile: missing schemeName" 
   puts "Try `enable_autoIncrCompile -help' for more information" 
   return {}
  }

  while {[llength $args]} {
    set name [lshift args]
    if {[string length $schemeName] != 0} { 
      puts "enable_autoIncrCompile: Incorrect arguments"
      puts "Try `enable_autoIncrCompile -help' for more information" 
      set schemeName ""
      set autoIncrCompileScheme_RunName ""
      return {}
   }
    switch -regexp -- $name {
      -help - {^-h(e(lp?)?)?$} {
           set help 1
      }
      -fixed - {^-f(i(x(ed?)?)?)?$} {
         set schemeName "Fixed"
         set runname [lshift args ]
         if {[ string length [ get_runs $runname] ] == 0 } {
          incr err
         } elseif {[string length [ get_placed_or_routed_dcp [get_runs $runname ] ]] } {
           set autoIncrCompileScheme_RunName $runname
         } else {
            puts "AutoIncrementalCompile: $runname provided for -fixed scheme does not have a placed or routed checkpoint to use for incremetnal flow"
            incr err
         }
      }
      -lastRun - {^-l(a(s(t(R(un?)?)?)?)?)?$} {
         set schemeName "LastRun"
      }
      -bestWNS - {^-b(e(s(t(W(NS?)?)?)?)?)?$} {
         set schemeName "BestWNS"
      }
      -bestTNS - {^-b(e(s(t(T(NS?)?)?)?)?)?$} {
         set schemeName "BestTNS"
      }
      default {
              puts " '$name' is not a valid option. Use the -help option for more details"
              incr err
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: enable_autoIncrCompile: Enables the auto detection and enablement of incremental flow. 
				 Reference checkpoint for incrmental flow is configured based on the argument provided to enable_autoIncrCompile
         [-lastRun]          	        - Last Modified Run
         [-fixed]  <run_name>		- <run_names> 
         [-bestWNS]          		- Run with the best WNS.
         [-bestTNS]             	- Run with the best TNS.
         [-help|-h]          		- This help message

  Description: Enables Auto Detection and Enablement of Incremental Compile Flow.
  Examples:
     	enable_autoIncrCompile -lastRun
     	enable_autoIncrCompile -fixed impl_1
     	enable_autoIncrCompile -bestWNS
     	enable_autoIncrCompile -bestTNS

  Also See:
			disable_autoIncrCompile
	
} ]
    # HELP -->
    return {}
  }
  if {$err} {
    puts "Try `enable_autoIncrCompile -help' for more information" 
    set autoIncrCompileScheme ""
    error " Error(s) : Cannot continue"
    return {}
  }

# if help or err should return before this
 set autoIncrCompileScheme $schemeName
 puts "AutoIncrementalCompile: Enabled with scheme $autoIncrCompileScheme " 
 if {![isLaunchRunsSwappedWithIncr]} {
   swapLaunchRunsWithIncrLaunchRuns
 }
}

proc disable_autoIncrCompile {args} {
  set help 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      -help - {^-h(e(lp?)?)?$} {
           set help 1
	 		}
		 default {
		 }
    }
  }

 if {$help} {
  puts [format {
  Usage: disable_autoIncrCompile: Disables the auto detection and enablement of incremental flow. 
         [-help|-h]          	- This help message

  Description: Disables Auto Detection and Enablement of Incremental Compile Flow.
  Examples:
     	disable_autoIncrCompile
     	disable_autoIncrCompile -h
  Also See:
			enable_autoIncrCompile
	
   } ]
   return  {}
 }

 if {[isLaunchRunsSwappedWithIncr]} {
   swapIncrLaunchRunsWithLaunchRuns
   global autoIncrCompileScheme 
   global autoIncrCompileScheme_RunName
   puts "AutoIncrementalCompile: Disabled " 
   set autoIncrCompileScheme  ""
   set autoIncrCompileScheme_RunName ""
 } else {
   puts "AutoIncrementalCompile: Is Already Disabled"
 }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
