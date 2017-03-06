################################################################
# Support translating old commands to corresponding new 
# commands in log and journal files
#


# Prevent global procs implementing deprecated commands from showing
# up in command completion
rdi::hide_commands \
 write_edf \
 report_min_pulse_width \
 save_design \
 save_design_as \
 write_device_support_archive \
 get_drc_vios \
 check_ip_cache

rdi::command_translated report_min_pulse_width
rdi::command_translated save_design
rdi::command_translated save_design_as

# Log argument string to log and journal file
proc rdi::record {args}  {
    set subst_args [uplevel 1 subst -nocommands $args]
    rdi::echo $subst_args
}
################################################################


# Check whether a value (string, list, etc.) is empty. 
proc rdi::is_blank {v} {
  if {[string length $v] == 0} {
    return 1
  }
  return 0
}

proc rdi::is_help { cmd subcmd cmdargs } {
  upvar 1 $cmdargs cmdargs_var
  if {[string equal $subcmd ?] || "?" in $cmdargs_var} {
      error "ERROR: \'$cmd\' is deprecated, please use \'help\' for new commands."
      return 1;
  }
  return 0
}

# Check whether a value is true (for the hdi:: commands). 
proc rdi::is_true {v} {
  if {[string equal -nocase $v y] || 
      [string equal -nocase $v ye] || 
      [string equal -nocase $v yes] || 
      [string equal -nocase $v true] || 
      [string equal         $v 1]} {
    return 1
  }
  return 0
}

# Check whether a value is false (for the hdi:: commands). 
proc rdi::is_false {v} {
  if {[string equal -nocase $v n] || 
      [string equal -nocase $v no] || 
      [string equal -nocase $v false] || 
      [string equal         $v 0]} {
    return 1
  }
  return 0
}


# Return the matching value from a list. 
# This will search for an exact match first, but if that fails, 
# it will perform a glob search by appending '*' to the falue. 
proc rdi::match {vals v} {
  if {[rdi::is_blank $v]} {
    return ""
  }
  set pos [lsearch -nocase $vals $v]
  if {$pos < 0} {
    set pos [lsearch -nocase -glob $vals $v*]
  }
  if {$pos >= 0} {
    return [lindex $vals $pos]
  }
}

# Search for the position of an option in an argument list. 
proc rdi::find_option {start option args_var} {
  upvar $args_var args
  set result ""
  set count [llength $args]
  set pos -1
  # Loop through args looking for an exact match. 
  set i $start
  while {$i < $count} {
    set val [lindex $args $i]
    if {[string equal -length 1 - $val]} {
      if {[string equal $val $option]} {
        set pos $i
        break
      }
    }
    incr i
  }
  if {$pos == -1} {
    # Loop through args looking for a partial match. 
    set i $start
    while {$i < $count} {
      set val [lindex $args $i]
      if {[string equal -length 1 - $val]} {
        if {[string match $val* $option]} {
          set pos $i
          break
        }
      }
      incr i
    }
  }
  return $pos
}

# Remove one or more options and their values from an argument list. 
proc rdi::remove_options {options args_var} {
  upvar $args_var args
  foreach opt $options {
    set done 0
    while {$done == 0} {
      set pos [rdi::find_option 0 $opt args]
      if {$pos > -1} {
        set i $pos
        incr i
        catch { set val [lindex $args $i] }
        if {[string equal -length 1 - $val]} {
          set i $pos
        }
        set args [lreplace $args $pos $i ]
      } else {
        set done 1
      }
    }
  }
}

# Rename an option in an argument list. 
proc rdi::rename_option {option new_name args_var} {
  upvar $args_var args
  set pos [rdi::find_option 0 $option args]
  if {$pos > -1} {
    set args [lreplace $args $pos $pos $new_name]
  }
}

# Return whether the specified option is in the argument list. 
proc rdi::has_option {option args_var} {
  upvar $args_var args
  set result 0
  set pos [rdi::find_option 0 $option args]
  if {$pos > -1} {
    set result 1
  }
  return $result
}

# Scan for the value of an option in an argument list. 
proc rdi::scan_for_option {option args_var} {
  upvar $args_var args
  set result ""
  set pos [rdi::find_option 0 $option args]
  if {$pos > -1} {
    set opt [lindex $args $pos]
    set i $pos
    incr i
    catch { set val [lindex $args $i] }
    if {![string equal -length 1 - $val]} {
      if {[rdi::is_blank $val]} {
        # lappend (hopefully) preserves blank strings
        lappend result $val
      } else {
        set result $val
      }
    }
  }
  if {[string equal $result "{}"]} { set result "" }
  return $result
}

# Scan for the value of a bool option in an argument list. 
proc rdi::scan_for_bool_option {option default args_var} {
  upvar $args_var args
  set result ""
  set pos [rdi::find_option 0 $option args]
  if {$pos > -1} {
    set opt [lindex $args $pos]
    set i $pos
    incr i
    catch { set val [lindex $args $i] }
    if {[string equal -length 1 - $val]} {
      set val ""
    }
    if {[rdi::is_blank $val] || [rdi::is_true $val]} {
      set result 1
    } elseif {[rdi::is_false $val]} {
      set result 0
    }
  } else {
    set result $default
  }
  return $result
}

proc rdi::flatten { argsVar } {
  upvar $argsVar args
  set flattened 0
  while {1} {
    set ch1 [string index $args 0]
    set che [string index $args end]
    set ok 0
    if { $ch1 == "\{" && $che == "\}" } {
      # The list has outer braces, but they can only be removed if they 
      # match each other. 
      set pos 1
      while {$pos < [string length $args]} {
        set ch [string index $args $pos]
        if { $ch == "\}" } {
          if { [expr { $pos + 1 }] == [string length $args]} {
            # this is the closing outer brace
            set ok 1
          }
          break
        }
        if { $ch == "\{" } {
          # the opening brace probably matches the closing brace.
          set ok 1
          break
        }
        incr pos
      }
    }
    if { $ok } {
      set args [string replace $args 0 0]
      set args [string replace $args end end]
      set flattened 1
    } else {
      break
    }
  }
  return $flattened
}

# Scan for the value of an option in an argument list. 
proc rdi::scan_for_file_option {option args_var} {
  upvar $args_var args
  set result ""
  set pos [rdi::find_option 0 $option args]
  if {$pos > -1} {
    set opt [lindex $args $pos]
    set i $pos
    incr i
    catch { set val [lindex $args $i] }
    if {![string equal -length 1 - $val]} {
      if {[rdi::is_blank $val]} {
        set result [list]
      } elseif {[regexp {[][${}\\ ]} $val]} {
        if {[flatten val]} {
          if {[regexp { } $val]} {
            #lappend result [list $val]
            lappend result $val
          } else {
            lappend result $val
          }
        } else {
          if {[regexp { } $val]} {
            set result $val
          } else {
            lappend result $val
          }
        }
      } else {
        set result $val
      }
    }
  }
  if {[string equal $result "{}"]} { set result "" }
  return $result
}

# Scan for the value of an option in an argument list. 
proc rdi::scan_for_multi_list_option {option args_var} {
  upvar $args_var args
  set result ""
  set done 0
  set pos -1
  while {$done == 0} {
    incr pos
    set pos [rdi::find_option $pos $option args]
    if {$pos > -1} {
      set opt [lindex $args $pos]
      set i $pos
      incr i
      catch { set val [lindex $args $i] }
      if {![string equal -length 1 - $val]} {
        if {[rdi::is_blank $result]} {
          if {[llength $val] > 1} {
            # to preserve the list-ness
            lappend result $val
          } else {
            set result $val
          }
        } else {
          lappend result $val
        }
      }
    } else {
      set done 1
    }
  }
  if {[string equal $result "{}"]} { set result "" }
  return $result
}

# Get the value of a bool (yes|no) option as a 1 or 0. 
# If the option is not present, the default will be returned. 
# If the option has no value, 1 will be returned. 
proc rdi::get_bool_option {options name { default 1 } } {
  upvar $options options_var
  if {![info exists options_var($name)]} {
    return $default
  }
  rdi::get_option options_var $name v
  if {[rdi::is_true $v]} {
    return 1
  } elseif {[rdi::is_false $v]} {
    return 0
  }
  return 1
}

# Walk through an argument list and store the options in an array. 
#  names - list of expected option names. 
#  args - name of the argument array to parse. 
#  options - name of the variable that will hold parsed options. 
proc rdi::parse_options { names args_var options } {
  upvar $args_var args
  upvar $options options_var
  set num_args [llength $args]
  set arg_index 0
  while {$arg_index < $num_args} {
    # see if the next argument is an option: 
    set name [lindex $args $arg_index]
    set name [rdi::match $names $name]
    if {![rdi::is_blank $name]} {
      # Fetch the option value, if it has one. 
      # If the next token is an option, set the value 
      # of the current option to '1'. 
      set value ""
      incr arg_index
      if {$arg_index < $num_args} {
        set value [lindex $args $arg_index]
        set next_name [rdi::match $names $value]
        if {![rdi::is_blank $next_name]} {
          set value 1
          incr arg_index -1
        }
      } else {
        set value 1
      }
      if {![info exists options_var($name)]} {
        set options_var($name) $value
      } else {
        lappend options_var($name) $value
      }
    }
    incr arg_index
  }
}

proc rdi::parse_multi_list_options { names args_var options } {
  upvar $args_var args
  upvar $options options_var
  set num_args [llength $args]
  set arg_index 0
  while {$arg_index < $num_args} {
    # see if the next argument is an option: 
    set name [lindex $args $arg_index]
    set name [rdi::match $names $name]
    if {![rdi::is_blank $name]} {
      # Fetch the option value, if it has one. 
      # If the next token is an option, set the value 
      # of the current option to '1'. 
      set value ""
      incr arg_index
      if {$arg_index < $num_args} {
        set value [lindex $args $arg_index]
        set next_name [rdi::match $names $value]
        if {![rdi::is_blank $next_name]} {
          set value 1
          incr arg_index -1
        }
      } else {
        set value 1
      }
      if {![info exists options_var($name)]} {
        if {[llength $value] > 1} {
          lappend options_var($name) $value
        } else {
          set options_var($name) $value
        }
      } else {
        lappend options_var($name) $value
      }
    }
    incr arg_index
  }
}

# Fetch an option value from an array. 
# This will return 1 if the option was found and had no value. 
#  options - name of the options array to search. 
#  name - name of the option to search for.
#  value - name of the variable to receive the option value. 
proc rdi::get_option { options name value } {
  upvar $options options_var
  upvar $value value_var
  if {![uplevel 1 info exists $value]} {
    # define the variable in the caller's scope:
    uplevel 1 [list set $value ""]
  }
  if {![uplevel 1 info exists $options]} {
    return
  }
  set pair [array get options_var $name]
  if {![rdi::is_blank $pair]} {
    lassign $pair name value_var
  }
}

# Check that required options were given. 
#  options_name - name of the options array. 
#  names - list of required option names. 
proc rdi::ensure_required_options { options_name names } {
  upvar $options_name options
  set missing ""
  if {![uplevel 1 info exists $options_name]} {
    set missing $names
  } else {
    foreach name $names {
      if {![info exists options($name)]} {
        lappend missing $name
      }
    }
  }
  if {![rdi::is_blank $missing]} {
    error "ERROR: required option(s) missing: '[join $missing]'"
  }
}

# deprecation layer to convert delete_port to remove_port
proc delete_port {args} {

  if { "?" in $args || "-help" in $args} {
    error "ERROR: \'delete_port\' is deprecated, please use \'remove_port\' instead."
    return 1;
  }

  set myArgs {}
  foreach arg $args {
    if {![rdi::is_blank $arg]} {
      lappend myArgs $arg
    }
  }

  # straight translation - args are identical
  rdi::record {remove_port $myArgs}
  remove_port {*}$myArgs
}

# Silently map write_edf to write_edif. 
proc write_edf {args} {
  puts "[write_edif {*}$args]"
}

proc write_device_support_archive {args} {
  puts "[write_dsa {*}$args]"
}

#-------------------------------------------------------------
#  netlist change tcl cmds migragion (no longer in ::debug namespace) so old scripts will work
#-------------------------------------------------------------
# first hide them from 'help'
rdi::hide_commands debug::create_cell debug::create_net debug::create_port \
    debug::remove_cell debug::remove_net debug::remove_port debug::connect_net  debug::disconnect_net
#
#export/import these commands
namespace export create_cell create_net remove_cell remove_net connect_net disconnect_net
namespace eval debug { namespace import ::create_cell ::create_net ::remove_cell ::remove_net ::connect_net ::disconnect_net}
#
# these two commands were renamed in addition to losing the ::debug:: namespace
# and they have an option name changed, so define a proc
namespace eval debug { 
    proc create_port {args} { 
  set filteredArgs ""
  foreach arg $args {
      if {$arg ne "-ports"} { lappend filteredArgs $arg }
  }
  create_pin {*}$filteredArgs
} }
namespace eval debug {
    proc remove_port {args} {
  set filteredArgs ""
  foreach arg $args {
      if {$arg ne "-ports"} { lappend filteredArgs $arg }
  }
  remove_pin {*}$filteredArgs
} }


#-------------------------------------------------------------
# deprecation layer to convert report_min_pulse_width to report_pulse_width
#-------------------------------------------------------------
proc report_min_pulse_width {args} {
  if {"?" in $args || "-help" in $args} {
    error "ERROR: \'report_min_pulse_width\' is deprecated, please use \'report_pulse_width\' instead."
    return 1;
  }

  set myArgs {}
  foreach arg $args {
    if {![rdi::is_blank $arg]} {
      lappend myArgs $arg
    }
  }

  # straight translation - only change is new switches
  # that didn't exist on old command
  rdi::record {report_pulse_width $myArgs}
  report_pulse_width {*}$myArgs
}

proc save_design {args} {
  if {"?" in $args || "-help" in $args} {
    error "ERROR: \'save_design\' is deprecated, please use \'save_constraints\' instead."
    return 1;
  }

  rdi::record {save_constraints $args}
  save_constraints {*}$args
}

proc save_design_as {args} {
  if {"?" in $args || "-help" in $args} {
    error "ERROR: \'save_design_as\' is deprecated, please use \'save_constraints_as\' instead."
    return 1;
  }

  rdi::record {save_constraints_as $args}
  save_constraints_as {*}$args
}

proc write_chipscope_cdc {args} {
  error "ERROR: \'write_chipscope_cdc\' is deprecated.  Instead, please use the ILA and VIO cores in the Vivado IP Catalog in conjunction with the \'write_debug_probes\' command."
  return 1;
}

proc write_ncd {args} {
  error "ERROR: \'write_ncd\' is deprecated, please use either \'write_checkpoint\' or \'write_bitstream\' instead."
  return 1;
}

proc write_pcf {args} {
  error "ERROR: \'write_pcf\' is deprecated, please use either \'write_checkpoint\' or \'write_bitstream\' instead."
  return 1;
}

# deprecation layer to convert get_drc_vios to get_drc_violations
proc get_drc_vios {args} {

  if { "?" in $args || "-h" in $args || "-help" in $args} {
    error "ERROR: \'get_drc_vios\' is deprecated, please use \'get_drc_violations\' instead."
    return 1;
  }

  set myArgs {}
  foreach arg $args {
    if {![rdi::is_blank $arg]} {
      lappend myArgs $arg
    }
  }

  # straight translation - args are identical
  rdi::record {get_drc_violations $myArgs}
  get_drc_violations {*}$myArgs
}

# deprecation layer to convert check_ip_cache to config_ip_cache
proc check_ip_cache {args} {

  if { "?" in $args || "-h" in $args || "-help" in $args} {
    error "ERROR: \'check_ip_cache\' is deprecated, please use \'config_ip_cache\' instead."
    return 1;
  }

  set myArgs {}
  foreach arg $args {
    if {![rdi::is_blank $arg]} {
      lappend myArgs $arg
    }
  }

  # straight translation - args are identical
  rdi::record {config_ip_cache $myArgs}
  config_ip_cache {*}$myArgs
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
