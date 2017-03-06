################################################################
# Support translating old commands to corresponding new 
# commands in log and journal files
#
# Add hdi:: commands when the corresponding implementation in this
# file echos new replacement commands

# create the hdi namespace if necessary
namespace eval hdi {
}

# Prevent global procs implementing deprecated commands from showing
# up in command completion
rdi::hide_commands \
 add_reconfig_module \
 update_reconfig_module 


rdi::command_translated hdi::command 
rdi::command_translated hdi::param 
rdi::command_translated hdi::drc 
rdi::command_translated hdi::port
rdi::command_translated hdi::pblock
rdi::command_translated hdi::pconst
rdi::command_translated hdi::chipscope
rdi::command_translated hdi::partition
rdi::command_translated hdi::pr
rdi::command_translated hdi::opt
rdi::command_translated hdi::run
rdi::command_translated hdi::floorplan
rdi::command_translated hdi::project
rdi::command_translated hdi::design
rdi::command_translated hdi::timing
rdi::command_translated hdi::netlist
rdi::command_translated hdi::bplace
rdi::command_translated hdi::place
rdi::command_translated hdi::rpm
rdi::command_translated hdi::report
rdi::command_translated hdi::ssn
rdi::command_translated hdi::sso
rdi::command_translated hdi::site
rdi::command_translated add_reconfig_module
rdi::command_translated update_reconfig_module

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
      rdi::record "ERROR: \'$cmd\' is deprecated, please use \'help\' for new commands."
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

proc rdi::is_design_open { name } {
  set design [get_designs -quiet $name]
  return [expr {![rdi::is_blank $design]}]
}

proc rdi::is_current_design { name } {
  set design [current_design -quiet]
  return [string equal $design $name]
}

proc rdi::ensure_design_open { name } {
  if {![is_design_open $name]} {
    error "ERROR: the design '$name' is not open"
  }
}

proc rdi::insert_project_if_required {lname} {
  upvar $lname lvar
  if { "-pro" ni $lvar && "-project" ni $lvar } {
    set lvar [linsert $lvar 0 -project [current_project]]
  }
}

proc rdi::save_design_if_open {} {
  set design [current_design -quiet]
  if { ![rdi::is_blank $design] } {
    rdi::record {save_design}
    save_design
  }
}

proc rdi::open_design_if_needed { { name "" } } {
  set designMode [get_property design_mode [current_fileset]]
  set isPinPlanning [string equal $designMode "PinPlanning"]
  set isGateLvl [string equal $designMode "GateLvl"]
  if {[rdi::is_blank $name]} {
    set design [current_design -quiet]
    if {[rdi::is_blank $design]} {
      if {$isPinPlanning} {
        rdi::record {open_io_design}
        open_io_design
      } elseif {$isGateLvl} {
        rdi::record {open_netlist_design}
        open_netlist_design
      } else {
        rdi::record {open_rtl_design}
        open_rtl_design
      }
    }
  } elseif {![is_design_open $name]} {
    if {$isPinPlanning} {
      rdi::record {open_io_design -name $name -constrset $name}
      open_io_design -name $name -constrset $name
    } elseif {$isGateLvl} {
      rdi::record {open_netlist_design -name $name -constrset $name}
      open_netlist_design -name $name -constrset $name
    } else {
      rdi::record {open_rtl_design -constrset $name}
      open_rtl_design -constrset $name
    }
  }
  if {![rdi::is_blank $name] && ![is_current_design $name]} {
    rdi::record {current_design $name}
    current_design $name
  }
}

proc rdi::open_floorplan_if_needed {args} {
  upvar $args lvar
  parse_options {-floorplan} lvar options
  get_option options -floorplan floorplan
  if {![is_blank $floorplan]} {
    open_design_if_needed $floorplan
  }
}

# Make sure the correct design is current. The current design 
# must have a constrset that matches the -floorplan option. 
proc rdi::open_corrected_floorplan_if_needed {varName} {
  upvar $varName args
  parse_options {-floorplan} args options
  get_option options -floorplan floorplan
  # Remove the floorplan argument to prevent multiple opens. 
  rdi::remove_options {-floorplan} args
  set currDesign [current_design -quiet]
  set currConstrset [current_fileset -constrset]
  if {![is_blank $currDesign]} {
    if {![string equal $floorplan $currDesign] && ![string equal $floorplan $currConstrset]} {
      set designs [get_designs -filter "constrset==$floorplan" -quiet]
      if {[llength $designs]} {
        current_design [lindex $designs 0]
      }
    }
  } else {
    open_design_if_needed $floorplan
  }
}

proc hdi::command {subcmd args} {
  if {[rdi::is_help hdi::command $subcmd args]} { return }
  # match partial subcmd names: 
  set match [rdi::match { startGroup endGroup undo redo exec help } $subcmd]
  switch $match {
    startGroup {
      rdi::record {startgroup $args}
      startgroup {*}$args
    }
    endGroup {
      rdi::record {endgroup $args}
      endgroup {*}$args
    }
    undo {
      rdi::record {undo $args}
      undo {*}$args
    }
    redo {
      rdi::record {redo $args}
      redo {*}$args
    }
    exec {
      rdi::record {exec $args}
      exec {*}$args
    }
    help {
      # disabled
    }
    default {
      error "ERROR: invalid command name \"hdi::command $subcmd\""
    }
  }
}

proc hdi::drc {subcmd args} {
  if {[rdi::is_help hdi::drc $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  rdi::open_design_if_needed
  rdi::remove_options {-project -floorplan} args
  set match [rdi::match { run clear } $subcmd]
  switch $match {
    run {
      rdi::record {report_drc $args}
      report_drc {*}$args
    }
    clear {
      rdi::record {reset_drc $args}
      reset_drc {*}$args
    }
    default {
      error "ERROR: invalid command name \"hdi::drc $subcmd\""
    }
  }
}

proc hdi::param {subcmd args} {
  if {[rdi::is_help hdi::param $subcmd args]} { return }
  set match [rdi::match { set get show } $subcmd]
  switch $match {
    set {
      # rename one of the -*value options to -value: 
      rdi::rename_option -ivalue -value args
      rdi::rename_option -bvalue -value args
      rdi::rename_option -svalue -value args
      rdi::rename_option -fvalue -value args
      rdi::record {set_param $args}
      set_param {*}$args
    }
    get {
      rdi::record {get_param $args}
      get_param {*}$args
    }
    show {
      rdi::record {report_param}
      report_param
    }
    default {
      error "ERROR: invalid command name \"hdi::param $subcmd\""
    }
  }
}

proc hdi::port {subcmd args} {
  if {[rdi::is_help hdi::port $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  set match [rdi::match { configure place unplace new delete edit newBus 
                          deleteBus editBus newInterface deleteInterface 
                          editInterface assign unassign fix unfix autoplace 
                          export import makeDiffPair splitDiffPair } $subcmd]
  switch $match {
    configure {       rdi::port_configure args }
    place {           rdi::port_place args }
    unplace {         rdi::port_unplace args }
    new {             rdi::port_new args }
    delete {          rdi::port_delete args }
    edit {            rdi::port_edit args }
    newBus {          rdi::port_new args }
    deleteBus {       rdi::port_deletebus args }
    editBus {         rdi::port_editbus args }
    newInterface {    rdi::port_newinterface args }
    deleteInterface { rdi::port_deleteinterface args }
    editInterface {   rdi::port_editinterface args }
    assign {          rdi::port_assign 1 args }
    unassign {        rdi::port_assign 0 args }
    fix {             rdi::port_fix 1 args }
    unfix {           rdi::port_fix 0 args }
    autoplace {       rdi::port_autoplace args }
    export {          rdi::port_export args }
    import {          rdi::port_import args }
    makeDiffPair {    rdi::port_makediffpair 1 args }
    splitDiffPair {   rdi::port_makediffpair 0 args }
    default {
      return -code error "invalid command name 'hdi::port $subcmd'"
    }
  }
}

proc rdi::port_configure {args_var} {
  upvar $args_var args

  set driveStrength [rdi::scan_for_option -driveStrength args]
  set floorplan [rdi::scan_for_option -floorplan args]
  set ioStd [rdi::scan_for_option -ioStd args]
  set inTermType [rdi::scan_for_option -inTermType args]
  set outTermType [rdi::scan_for_option -outTermType args]
  set names [rdi::scan_for_option -names args]
  set pullType [rdi::scan_for_option -pullType args]
  set phase [rdi::scan_for_option -phase args]
  set project [rdi::scan_for_option -project args]
  set slewType [rdi::scan_for_option -slewType args]
  set defaultIoStd [rdi::scan_for_bool_option -defaultIoStd 0 args]
  set defaultDriveStrength [rdi::scan_for_bool_option -defaultDriveStrength 0 args]
  set defaultSlewType [rdi::scan_for_bool_option -defaultSlewType 0 args]
  set defaultPhase [rdi::scan_for_bool_option -defaultPhase 0 args]

  if {$defaultIoStd && ![rdi::is_blank $ioStd]} {
    error "Cannot specify both -ioStd and -defaultIoStd"
  }
  if {$defaultDriveStrength && ![rdi::is_blank $driveStrength]} {
    error "Cannot specify both -driveStrength and -defaultDriveStrength"
  }
  if {$defaultSlewType && ![rdi::is_blank $slewType]} {
    error "Cannot specify both -slewType and -defaultSlewType"
  }
  if {$defaultPhase && ![rdi::is_blank $phase]} {
    error "Cannot specify both -phase and -defaultPhase"
  }

  set group_started [startgroup -try]
  if { $group_started == 1} { rdi::record {startgroup} }
  set code [catch {
    if {![rdi::is_blank $ioStd]} {
      rdi::record {set_property iostandard $ioStd [get_ports -quiet $names]}
      set_property iostandard $ioStd [get_ports -quiet $names]
    }
    if {![rdi::is_blank $driveStrength]} {
      rdi::record {set_property drive $driveStrength [get_ports -quiet $names]}
      set_property drive $driveStrength [get_ports -quiet $names]
    }
    if {![rdi::is_blank $slewType]} {
      rdi::record {set_property slew $slewType [get_ports -quiet $names]}
      set_property slew $slewType [get_ports -quiet $names]
    }
    if {![rdi::is_blank $pullType]} {
      rdi::record {set_property pulltype $pullType [get_ports -quiet $names]}
      set_property pulltype $pullType [get_ports -quiet $names]
    }
    if {![rdi::is_blank $inTermType]} {
      rdi::record {set_property in_term $inTermType [get_ports -quiet $names]}
      set_property in_term $inTermType [get_ports -quiet $names]
    }
    if {![rdi::is_blank $outTermType]} {
      rdi::record {set_property out_term $outTermType [get_ports -quiet $names]}
      set_property out_term $outTermType [get_ports -quiet $names]
    }
    if {![rdi::is_blank $phase]} {
      rdi::record {set_property phase $phase [get_ports -quiet $names]}
      set_property phase $phase [get_ports -quiet $names]
    }
  } result]
  if { $group_started == 1} {
    rdi::record {endgroup}
    endgroup
  }
  if { $code != 0 } {
    undo
  }
  return -code $code $result
}

proc rdi::port_place {args_var} {
  upvar $args_var args

  set names [rdi::scan_for_option -names args]
  set sites [rdi::scan_for_option -sites args]

  if {[llength $sites] != [llength $names]} {
    error "-names and -sites arguments does not match"
  }

  # if more than one site, run in a group: 
  set group_started 0
  if {[llength $sites] > 1 } {
    set group_started [startgroup -try]
  }
  if { $group_started } { rdi::record {startgroup} }
  set code 0
  set result ""
  set code [catch {
    foreach site $sites port $names {
      rdi::record {set_property loc $site [get_ports $port]}
      set_property loc $site [get_ports -quiet $port]
    }
  } result]
  if { $group_started == 1} {
    rdi::record {endgroup}
    endgroup
    if { $code != 0 } {
      undo
    }
  }
  return -code $code $result
}

proc rdi::port_unplace {args_var} {
  upvar $args_var args

  set names [rdi::scan_for_option -names args]
  set keepFixed [rdi::scan_for_bool_option -keepFixed 0 args]

  set implicit_all 0
  if {[llength $names] == 0} {
    set implicit_all 1
    set names [get_ports -quiet]
    if {[llength $names] == 0} {
      error "There are no ports in this design"
    }
  }

  if {$keepFixed} {
    # filter out fixed ports
    set implicit_all 0
    set names [get_ports -quiet -filter is_fixed==false]
    if {[llength $names] == 0} {
      error "All given ports have fixed placement"
    }
  }

  if {$implicit_all} {
    rdi::record {set_property loc "" [get_ports]}
  } else {
    rdi::record {set_property loc "" [get_ports $names]}
  }
  set_property loc "" [get_ports -quiet $names]
}

proc rdi::port_new {args_var} {
  upvar $args_var args

  set name [rdi::scan_for_option -name args]
  set dir [rdi::scan_for_option -dir args]
  set from [rdi::scan_for_option -from args]
  set to [rdi::scan_for_option -to args]
  set diffPair [rdi::scan_for_bool_option -diffPair 0 args]
  set parent [rdi::scan_for_option -parent args]
  if {![rdi::is_blank $dir] && 
      ![string equal -nocase $dir input] &&
      ![string equal -nocase $dir output] &&
      ![string equal -nocase $dir inout]} {
    error "ERROR: Invalid -dir argument '$dir'"
  }
  switch $dir {
    input { set dir in }
    output { set dir out }
  }
  if {[rdi::has_option -dir args]} { lappend new_args -direction $dir }
  if {[rdi::has_option -from args]} { lappend new_args -from $from }
  if {[rdi::has_option -to args]} { lappend new_args -to $to }
  if {[rdi::has_option -parent args]} { lappend new_args -interface $parent }
  if {$diffPair} {
    lappend new_args -diff_pair
    set p_name $name
    append p_name _P
    lappend new_args $p_name
    set n_name $name
    append n_name _N
    lappend new_args $n_name
  } else { lappend new_args $name }

  rdi::record {create_port $new_args}
  create_port {*}$new_args
}

proc rdi::port_delete {args_var} {
  upvar $args_var args
  set names [rdi::scan_for_option -names args]
  rdi::record {delete_port $names}
  delete_port $names
}

proc rdi::port_deletebus {args_var} {
  upvar $args_var args
  set name [rdi::scan_for_option -name args]
  rdi::record {delete_port $name[*]}
  delete_port [get_ports $name[*]]
}

proc rdi::port_newinterface {args_var} {
  upvar $args_var args
  rdi::remove_options {-project} args
  rdi::record {create_interface $args}
  create_interface {*}$args
}

proc rdi::port_deleteinterface {args_var} {
  upvar $args_var args
  set name [rdi::scan_for_option -name args]
  set all [rdi::scan_for_bool_option -all 0 args]
  if {$all} {
    rdi::record {delete_interface -all $name}
    delete_interface -all $name
  } else {
    rdi::record {delete_interface $name}
    delete_interface $name
  }
}

proc rdi::port_export {args_var} {
  upvar $args_var args

  open_design_if_needed

  set file [rdi::scan_for_option -file args]
  set format [rdi::scan_for_option -format args]

  if {[rdi::is_blank $file]} {
    error "ERROR: -file argument missing"
  }
  if {[rdi::is_blank $format]} {
    error "ERROR: -format argument missing"
  }

  if {[string equal $format ucf]} {
    rdi::record {write_ucf -mode port $file}
    write_ucf -mode port $file
  } elseif {[string equal $format verilog]} {
    rdi::record {write_verilog -mode port $file}
    write_verilog -mode port $file
  } elseif {[string equal $format vhdl]} {
    rdi::record {write_vhdl -mode port $file}
    write_vhdl -mode port $file
  } elseif {[string equal $format csv]} {
    rdi::record {write_csv $file}
    write_csv $file
  } else {
    error "-format argument should be one of csv, vhdl, verilog , ucf."
  }
}

proc rdi::port_autoplace {args_var} {
  upvar $args_var args
  rdi::remove_options {-project -floorplan} args
  rdi::record {place_ports $args}
  place_ports {*}$args
}

proc rdi::port_import {args_var} {
  upvar $args_var args

  set csv [rdi::scan_for_option -csv args]
  set vhdl [rdi::scan_for_multi_list_option -vhdl args]
  set verilog [rdi::scan_for_multi_list_option -verilog args]

  if {[rdi::is_blank $csv] &&
      [rdi::is_blank $vhdl] &&
      [rdi::is_blank $verilog]} {
    error "Must specify one of -verilog , -vhdl or -csv" 
  }
  if {![rdi::is_blank $csv] &&
      ![rdi::is_blank $vhdl]} {
    error "Cannot specify both -csv and -vhdl"
  }
  if {![rdi::is_blank $csv] &&
      ![rdi::is_blank $verilog]} {
    error "Cannot specify both -csv and -verilog"
  }

  if {![rdi::is_blank $csv]} {
    read_csv $csv
  }

  # Add hdl files first and then set the library. 
  if {![rdi::is_blank $verilog]} {
    foreach pair $verilog {
      lassign $pair file lib
      if {[rdi::is_blank $lib]} {
        set lib work
      }
      rdi::record {set file [add_files -norecurse $file]}
      set file [add_files -norecurse $file]
      rdi::record {set_property library $lib \$file}
      set_property library $lib $file
    }
  }

  if {![rdi::is_blank $vhdl]} {
    foreach pair $vhdl {
      lassign $pair file lib
      if {[rdi::is_blank $lib]} {
        set lib work
      }
      rdi::record {set file [add_files -norecurse $file]}
      set file [add_files -norecurse $file]
      rdi::record {set_property library $lib \$file}
      set_property library $lib $file
    }
  }
}

proc rdi::port_makediffpair {create args_var} {
  upvar $args_var args
  set names [rdi::scan_for_option -names args]
  if {$create} {
    rdi::record {make_diff_pair_ports $names}
    make_diff_pair_ports $names
  } else {
    rdi::record {split_diff_pair_ports $names}
    split_diff_pair_ports $names
  }
}

proc rdi::port_edit {args_var} {
  upvar $args_var args

  set name [rdi::scan_for_option -name args]
  set newName [rdi::scan_for_option -newName args]
  set newDir [rdi::scan_for_option -newDir args]
  if {![rdi::is_blank $newDir] && 
      ![string equal -nocase $newDir input] &&
      ![string equal -nocase $newDir output] &&
      ![string equal -nocase $newDir inout]} {
    error "ERROR: Invalid -newDir argument '$newDir'"
  }
  if {[string equal $newDir input]} {
    set newDir in
  } elseif {[string equal $newDir output]} {
    set newDir out
  }

  if {[rdi::is_blank $name]} {
    error "missing -name argument"
  }
  if {[rdi::is_blank $newName] && [rdi::is_blank $newDir]} {
    error "Please specify 'newDir' or 'newName'"
  }

  set group_started [startgroup -try]
  if { $group_started } { rdi::record {startgroup} }
  set code [catch {
    if {![rdi::is_blank $newName]} {
      rdi::record {set_property name $newName [get_ports $name]}
      set_property name $newName [get_ports -quiet $name]
      set name $newName
    }
    if {![rdi::is_blank $newDir] } {
      rdi::record {set_property direction $newDir [get_ports $name]}
      set_property direction $newDir [get_ports -quiet $name]
    }
  } result]
  if { $group_started == 1} {
    rdi::record {endgroup}
    endgroup
    if { $code != 0 } {
      undo
    }
  }
  return -code $code $result
}

proc rdi::port_editbus {args_var} {
  upvar $args_var args
  set name [rdi::scan_for_option -name args]
  set newName [rdi::scan_for_option -newName args]
  if {[rdi::is_blank $name]} {
    error "missing -name argument"
  }
  if {[rdi::is_blank $newName]} {
    error "missing -newName argument"
  }
  rdi::record {set_property name $newName [get_ports $name[*]]}
  set_property name $newName [get_ports -quiet $name[*]]
}

proc rdi::port_editinterface {args_var} {
  upvar $args_var args
  set name [rdi::scan_for_option -name args]
  set newName [rdi::scan_for_option -newName args]
  if {[rdi::is_blank $name]} {
    error "missing -name argument"
  }
  if {[rdi::is_blank $newName]} {
    error "missing -newName argument"
  }
  rdi::record {set_property name $newName [get_interfaces $name]}
  set_property name $newName [get_interfaces -quiet $name]
}

proc rdi::port_assign {assign args_var} {
  upvar $args_var args

  set parent [rdi::scan_for_option -parent args]
  set ports [rdi::scan_for_option -ports args]
  set _buses [rdi::scan_for_option -buses args]
  set interfaces [rdi::scan_for_option -interfaces args]

  if {[rdi::is_blank $ports] && 
      [rdi::is_blank $_buses] && 
      [rdi::is_blank $interfaces]} {
    error "Must specify -ports, -interfaces or -buses"
  }

  set buses [list]
  foreach bus $_buses {
    lappend buses $bus[*]
  }

  if {$assign && [rdi::is_blank $parent]} {
    error "Must specify -parent."
  }

  set result ""
  set code 0
  set undo false
  set group_started [startgroup -try]
  if { $group_started } { rdi::record {startgroup} }
  if { $code == 0 && ![rdi::is_blank $ports] } {
    rdi::record {set_property interface $parent [get_ports $ports]}
    set code [catch {set_property interface $parent [get_ports -quiet $ports]} result]
    if {$code == 0} {
      set undo true;
    }
  }
  if { $code == 0 && ![rdi::is_blank $buses] } {
    rdi::record {set_property interface $parent [get_ports $buses]}
    set code [catch {set_property interface $parent [get_ports -quiet {*}$buses]} result]
    if {$code == 0} {
      set undo true;
    }
  }
  if { $code == 0 && ![rdi::is_blank $interfaces] } {
    rdi::record {set_property interface $parent [get_interfaces $interfaces]}
    set code [catch {set_property interface $parent [get_interfaces -quiet $interfaces]} result]
  }
  if { $group_started == 1} {
    rdi::record {endgroup}
    endgroup
  }
  if { $code != 0 } {
    if {$undo} {
      undo
    }
  }
  return -code $code $result
}

proc rdi::port_fix {fix args_var} {
  upvar $args_var args
  set names [rdi::scan_for_option -names args]
  if {[rdi::is_blank $names]} {
    error "-names argument missing."
  }
  rdi::record {set_property is_fixed $fix [get_ports $names]}
  set_property is_fixed $fix [get_ports -quiet $names]
}


proc rdi::trystartgroup {} {
  return [startgroup -try]
}

proc rdi::pblock_new {cmdargs_var} {
    set nameArg false
    set parentArg false
    set leftArg false
    set topArg false
    set rightArg false
    set bottomArg false
    set addArg false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set newName $arg
        set nameArg false
      } elseif {$parentArg} {
        set parent $arg
        set parentArg false
      } elseif {$leftArg} {
        set left $arg
        set leftArg false
      } elseif {$topArg} {
        set top $arg
        set topArg false
      } elseif {$rightArg} {
        set right $arg
        set rightArg false
      } elseif {$bottomArg} {
        set bottom $arg
        set bottomArg false
      } elseif {$addArg} {
        lappend addSites $arg
        set addArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 3  $arg -parent] == 0} {
        set parentArg true
      } elseif {[string compare -nocase -l 2  $arg -left] == 0} {
        set leftArg true
      } elseif {[string compare -nocase -l 2  $arg -top] == 0} {
        set topArg true
      } elseif {[string compare -nocase -l 2  $arg -right] == 0} {
        set rightArg true
      } elseif {[string compare -nocase -l 2  $arg -bottom] == 0} {
        set bottomArg true
      } elseif {[string compare -nocase -l 2  $arg -add] == 0} {
        set addArg true
      }
    }

    if {[info exists newName] == 0} {
      error "missing -name argument"
    }

    set result ""
    set code 0
    set undo false
    set group_started [trystartgroup]
    if {$group_started} { rdi::record {startgroup}}
    if { $code == 0 && [info exists newName] } {
      rdi::record {create_pblock $newName}
      set code [catch {create_pblock $newName} result]
      if {$code == 0} {
        set undo true;
      }
    }
    if { $code == 0 && [info exists parent] && [string compare -nocase -l 4  $parent "ROOT"] != 0} {
      rdi::record {set_property parent $parent [get_pblocks $newName]}
      set code [catch {set_property parent $parent [get_pblocks -quiet $newName]} result]
      if {$code == 0} {
        set undo true;
      }
    }
    if { $code == 0 && [info exists addSites] } {
      rdi::record {resize_pblock $newName -add $addSites -replace}
      set code [catch {resize_pblock $newName -add $addSites -replace} result]
      if {$code == 0} {
        set undo true;
      }
    }
    if { $code == 0 && [info exists left] } {
        lappend addRect $left
        lappend addRect $top
        lappend addRect $right
        lappend addRect $bottom
      rdi::record {resize_pblock $newName -add_rect $addRect}
      set code [catch {resize_pblock $newName -add_rect $addRect} result]
    }
    if { $group_started == 1} {
      rdi::record {endgroup}
      endgroup
    }
    if { $code != 0 } {
      if {$undo} {
      undo
      }
    }
    return -code $code $result
}

proc rdi::pblock_set {cmdargs_var} {
    set nameArg false
    set newNameArg false
    set parentArg false
    set gridTypesArg false
    set rectArg false
    set leftArg false
    set topArg false
    set rightArg false
    set bottomArg false
    set locs "keep_all"
    set wholeFloorplan false

    foreach arg $cmdargs_var {
      if {$newNameArg} {
        set newName $arg
        set newNameArg false
      } elseif {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$parentArg} {
        set parent $arg
        set parentArg false
      } elseif {$gridTypesArg} {
        set gridTypes $arg
        set gridTypesArg false
      } elseif {$rectArg} {
        set rect $arg
        set rectArg false
      } elseif {$leftArg} {
        set left $arg
        set leftArg false
      } elseif {$topArg} {
        set top $arg
        set topArg false
      } elseif {$rightArg} {
        set right $arg
        set rightArg false
      } elseif {$bottomArg} {
        set bottom $arg
        set bottomArg false
      } elseif {[string compare -nocase -l 3  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 3  $arg -newName] == 0} {
        set newNameArg true
      } elseif {[string compare -nocase -l 3  $arg -parent] == 0} {
        set parentArg true
      } elseif {[string compare -nocase -l 2  $arg -gridtypes] == 0} {
        set gridTypesArg true
      } elseif {[string compare -nocase -l 2  $arg -wholeFloorplan] == 0} {
        set wholeFloorplan true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set wholeFloorplan false
          }
        }
      } elseif {[string compare -nocase -l 2  $arg -clearLocs] == 0} {
        set locs trim
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set locs keep_all
          }
        }
      } elseif {[string compare -nocase -l 3  $arg -rect] == 0} {
        set rectArg true
      } elseif {[string compare -nocase -l 2  $arg -left] == 0} {
        set leftArg true
      } elseif {[string compare -nocase -l 2  $arg -top] == 0} {
        set topArg true
      } elseif {[string compare -nocase -l 3  $arg -right] == 0} {
        set rightArg true
      } elseif {[string compare -nocase -l 2  $arg -bottom] == 0} {
        set bottomArg true
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }
    set result ""
    set code 0
    set undo false
    set group_started [trystartgroup]
    if {$group_started} { rdi::record {startgroup} }
    if { $code == 0 && [info exists newName] } {
      rdi::record {set_property name $newName [get_pblocks $name]}
      set code [catch {set_property name $newName [get_pblocks -quiet $name]} result]
      set name $newName
      if {$code == 0} {
        set undo true;
      }
    }
    if { $code == 0 && $wholeFloorplan } {
      rdi::record {resize_pblock $name -wholefloorplan}
      set code [catch {resize_pblock $name -wholefloorplan } result]
      if {$code == 0} {
        set undo true;
      }
    } 
    if { $code == 0 && [info exists rect] } {
      rdi::record {resize_pblock $name -add_rect $rect -replace -locs $locs}
      set code [catch {resize_pblock $name -add_rect $rect -replace -locs $locs} result]
      if {$code == 0} {
        set undo true;
      }
    } 
    if { $code == 0 && ([info exists left] || [info exists right] || [info exists top] || [info exists bottom])} {
      if {[info exists left]} {
        lappend addRect $left
      } else {
        lappend addRect -1
      }
      if {[info exists top]} {
        lappend addRect $top
      } else {
        lappend addRect -1
      }
      if {[info exists right]} {
        lappend addRect $right
      } else {
        lappend addRect -1
      }
      if {[info exists bottom]} {
        lappend addRect $bottom
      } else {
        lappend addRect -1
      }
      if {[info exists gridTypes]} {
        if {[info exists rect]} {
          rdi::record {resize_pblock $name -rect $rect -gridtypes $gridTypes -add_rect $addRect -replace -locs $locs}
          set code [catch {resize_pblock $name -rect $rect -gridtypes $gridTypes -add_rect $addRect -replace -locs $locs} result]
        } else {
          rdi::record {resize_pblock $name -gridtypes $gridTypes -add_rect $addRect -replace -locs $locs}
          set code [catch {resize_pblock $name -gridtypes $gridTypes -add_rect $addRect -replace -locs $locs} result]
        }
      } else  {
        if {[info exists rect]} {
          rdi::record {resize_pblock $name -rect $rect -add_rect $addRect -replace -locs $locs}
          set code [catch {resize_pblock $name -rect $rect -add_rect $addRect -replace -locs $locs} result]
        } else {
          rdi::record {resize_pblock $name -add_rect $addRect -replace -locs $locs}
          set code [catch {resize_pblock $name -add_rect $addRect -replace -locs $locs} result]
        }
      }
      if {$code == 0} {
        set undo true;
      }
    }
    if { $code == 0 && (![info exists addRect]) && [info exists gridTypes] } {
      rdi::record {set_property gridtypes  $gridTypes  [get_pblocks $name]}
      set code [catch {set_property gridtypes  $gridTypes  [get_pblocks -quiet $name]} result]
      if {$code == 0} {
        set undo true;
      }
    } 
    if { $code == 0 && [info exists parent] } {
      rdi::record {set_property parent $parent [get_pblocks $name]}
      set code [catch {set_property parent $parent [get_pblocks -quiet $name]} result]
    }
    if { $group_started == 1} {
      rdi::record {endgroup}
      endgroup
    }
    if { $code != 0 } {
      if {$undo} {
        undo
      }
    }
    return -code $code $result
}

proc rdi::pblock_resize {cmdargs_var} {
    set nameArg false
    set addArg false
    set removeArg false
    set fromArg false
    set toArg false
    set replaceArg false
    set locsArg false
    set leftArg false
    set replace false
    set locs "keep_all"

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$addArg} {
        lappend add $arg
        set addArg false
      } elseif {$removeArg} {
        lappend remove $arg
        set removeArg false
      } elseif {$fromArg} {
        lappend movefrom $arg
        set fromArg false
      } elseif {$toArg} {
        lappend moveto $arg
        set toArg false
      } elseif {$locsArg} {
        set locs $arg
        set locsArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -add] == 0} {
        set addArg true
      } elseif {[string compare -nocase -l 4  $arg -remove] == 0} {
        set removeArg true
      } elseif {[string compare -nocase -l 3  $arg -from] == 0} {
        set fromArg true
      } elseif {[string compare -nocase -l 2  $arg -to] == 0} {
        set toArg true
      } elseif {[string compare -nocase -l 4  $arg -replace] == 0} {
        set replace true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set replace false
          }
        }
      } elseif {[string compare -nocase -l 2  $arg -locs] == 0} {
        set locsArg true
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }

    lappend new_args $name
    if {[info exists add] } {
      lappend new_args -add
      lappend new_args $add
    }

    if {[info exists remove] } {
      lappend new_args -remove
      lappend new_args $remove
    }

    if {[info exists movefrom] } {
      foreach val $movefrom {
        lappend new_args -from
        lappend new_args $val
      }
    }

    if {[info exists moveto] } {
      foreach val $moveto {
        lappend new_args -to
        lappend new_args $val
      }
    }

    if {$replace} {
      lappend new_args -replace
    }
    lappend new_args -locs
    lappend new_args $locs

    rdi::record {resize_pblock $new_args}
    resize_pblock {*}$new_args
}

proc rdi::pblock_delete {cmdargs_var} {
    set nameArg false
    set childArg false
    set removeArg false
    set child false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -children] == 0} {
        set child true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set child false
          }
        }
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }

    lappend new_args $name
    if {$child } {
      lappend new_args -hier
    }
    rdi::record {delete_pblock $new_args}
    delete_pblock {*}$new_args
}

proc rdi::pblock_addInstance {cmdargs_var} {
    set nameArg false
    set instanceArg false
    set clearLocs false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$instanceArg} {
        lappend instances {*}$arg
        set instanceArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -instance] == 0} {
        set instanceArg true
      } elseif {[string compare -nocase -l 2  $arg -clearLocs] == 0} {
        set clearLocs true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set clearLocs false
          }
        }
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }

    if {$clearLocs} {
      rdi::record {add_cells_to_pblock $name [get_cells $instances] -clear_locs}
      add_cells_to_pblock $name [get_cells -quiet $instances] -clear_locs
    } else {
      rdi::record {add_cells_to_pblock $name [get_cells $instances]}
      add_cells_to_pblock $name [get_cells -quiet $instances]
    }
}

proc rdi::pblock_addPrimitives {cmdargs_var} {
    set nameArg false
    set instanceArg false
    set clearLocs false
    set instance "*"

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$instanceArg} {
        set instance "$arg/*"
        set instanceArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -instance] == 0} {
        set instanceArg true
      } elseif {[string compare -nocase -l 2  $arg -clearLocs] == 0} {
        set clearLocs true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set clearLocs false
          }
        }
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }

    if {$clearLocs} {
      rdi::record {add_cells_to_pblock $name [get_cells $instance] -add_primitives -clear_locs}
      add_cells_to_pblock $name [get_cells -quiet $instance] -add_primitives -clear_locs
    } else {
      rdi::record {add_cells_to_pblock $name [get_cells $instance] -add_primitives}
      add_cells_to_pblock $name [get_cells -quiet $instance] -add_primitives
    }
}

proc rdi::pblock_removeInstance {cmdargs_var} {
    set nameArg false
    set instanceArg false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$instanceArg} {
        set instance $arg
        set instanceArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -instance] == 0} {
        set instanceArg true
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }
    if {[info exists instance] == 0} {
      error "missing -instance argument"
    }
    rdi::record {remove_cells_from_pblock $name [get_cells $instance]}
    remove_cells_from_pblock $name [get_cells -quiet $instance]
}

proc rdi::pblock_addRect {cmdargs_var} {
    set nameArg false
    set leftArg false
    set topArg false
    set rightArg false
    set bottomArg false
    set locs "keep_all"

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set newName $arg
        set nameArg false
      } elseif {$leftArg} {
        set left $arg
        set leftArg false
      } elseif {$topArg} {
        set top $arg
        set topArg false
      } elseif {$rightArg} {
        set right $arg
        set rightArg false
      } elseif {$bottomArg} {
        set bottom $arg
        set bottomArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -left] == 0} {
        set leftArg true
      } elseif {[string compare -nocase -l 2  $arg -top] == 0} {
        set topArg true
      } elseif {[string compare -nocase -l 2  $arg -right] == 0} {
        set rightArg true
      } elseif {[string compare -nocase -l 2  $arg -bottom] == 0} {
        set bottomArg true
      } elseif {[string compare -nocase -l 2  $arg -clearLocs] == 0} {
        set locs "trim"
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set locs "keep_all"
          }
        }
      }
    }

    if {[info exists newName] == 0} {
      error "missing -name argument"
    }
    lappend addRect $left
    lappend addRect $top
    lappend addRect $right
    lappend addRect $bottom
    rdi::record {resize_pblock $newName -add_rect $addRect -locs $locs}
    resize_pblock $newName -add_rect $addRect -locs $locs
}

proc rdi::pblock_clearRect {cmdargs_var} {
    set nameArg false
    set rectArg false
    set locs "keep_all"

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set newName $arg
        set nameArg false
      } elseif {$rectArg} {
        set rect $arg
        set rectArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -rect] == 0} {
        set rectArg true
      } elseif {[string compare -nocase -l 2  $arg -clearLocs] == 0} {
        set locs "trim"
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set locs "keep_all"
          }
        }
      }
    }

    if {[info exists newName] == 0} {
      error "missing -name argument"
    }
    rdi::record {resize_pblock $newName -remove_rect $rect -locs $locs}
    resize_pblock $newName -remove_rect $rect -locs $locs
}

proc rdi::pblock_listNames {cmdargs_var} {
    set recurse false
    foreach arg $cmdargs_var {
      if {[string compare -nocase -l 2  $arg -recurse] == 0} {
        set recurse true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set recurse false
          }
        }
      }
    }

    rdi::record {\# hdi::pblock listNames --- not translated }
    set nohierresult ""
    set pblocks [get_pblocks -quiet *]
    if {!$recurse} {
      foreach item $pblocks {
        set parent [get_property parent $item]
        if {$parent == ""} {
          lappend nohierresult $item
        } 
      }
      return $nohierresult
    }
    return ""
}

proc rdi::pblock_addRPMs {cmdargs_var} {
    set nameArg false
    set rpmsArg false
    set clearLocs false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$rpmsArg} {
        set rpms $arg
        set instanceArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -rpms] == 0} {
        set rpmsArg true
      } elseif {[string compare -nocase -l 2  $arg -clearLocs] == 0} {
        set clearLocs true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set clearLocs false
          }
        }
      } 
    }

    if {[info exists name] == 0} {
      error "missing -name argument"
    }

    if {[info exists rpms] == 0} {
      error "missing -rpms argument"
    }
    set orOper ""
    foreach rpm $rpms {
      append filterArg $orOper
      append filterArg "rpm == \"$rpm\""
      set orOper " || "
    }

    set result ""
    set code 0
    if {$clearLocs} {
      rdi::record {add_cells_to_pblock $name [get_cells * -hier -filter $filterArg] -clear_locs}
      add_cells_to_pblock $name [get_cells -quiet * -hier -filter $filterArg] -clear_locs
    } else {
      rdi::record {add_cells_to_pblock $name [get_cells * -hier -filter $filterArg]}
      add_cells_to_pblock $name [get_cells -quiet * -hier -filter $filterArg]
    }
}

proc hdi::pblock {subcmd args} {
  if {[rdi::is_help hdi::pblock $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  if {[string compare -nocase -l 1 $subcmd "new"]==0} {
    set result [rdi::pblock_new $args]
  } elseif {[string compare -nocase -l 1 $subcmd "set"]==0} {
    set result [rdi::pblock_set $args]
  } elseif {[string compare -nocase -l 3 $subcmd "resize"]==0} {
    set result [rdi::pblock_resize $args]
  } elseif {[string compare -nocase -l 1 $subcmd "delete"]==0} {
    set result [rdi::pblock_delete $args]
  } elseif {[string compare -nocase -l 4 $subcmd "addInstance"]==0} {
    set result [rdi::pblock_addInstance $args]
  } elseif {[string compare -nocase -l 4 $subcmd "addPrimitives"]==0} {
    set result [rdi::pblock_addPrimitives $args]
  } elseif {[string compare -nocase -l 3 $subcmd "removeInstance"]==0} {
    set result [rdi::pblock_removeInstance $args]
  } elseif {[string compare -nocase -l 5 $subcmd "addRect"]==0} {
    set result [rdi::pblock_addRect $args]
  } elseif {[string compare -nocase -l 1 $subcmd "clearRect"]==0} {
    set result [rdi::pblock_clearRect $args]
  } elseif {[string compare -nocase -l 1 $subcmd "listNames"]==0} {
    set result [rdi::pblock_listNames $args]
  } elseif {[string compare -nocase -l 5 $subcmd "addRPMs"]==0} {
    set result [rdi::pblock_addRPMs $args]
  } else {
    error "ERROR: invalid command name 'hdi::pblock $subcmd'"
  }
  return $result
}

proc rdi::pconst_import {args} {
  set floorplan [rdi::scan_for_option -floorplan args]
  set file [rdi::scan_for_option -file args]
  set createPorts [rdi::scan_for_bool_option -createPorts 0 args]
  set instance [rdi::scan_for_option -instance args]
  if {![rdi::is_blank $instance]} {
    lappend new_args -cell $instance
  }
  if {$createPorts} {
    lappend new_args -create_ports
  }
  lappend new_args $file
  rdi::record {read_ucf $new_args}
  set fileobj [read_ucf {*}$new_args]
  if {![rdi::is_blank $fileobj]} {
    lappend import_args -force -fileset $floorplan $fileobj
    rdi::record {import_files -force -fileset $floorplan $fileobj}
    import_files -force -fileset $floorplan $fileobj
  }
}

proc rdi::pconst_newLoc {cmdargs_var} {
    set siteArg false
    set belArg false
    set instanceArg false
    set isFixed true

    foreach arg $cmdargs_var {
      if {$instanceArg} {
        set instance $arg
        set instanceArg false
      } elseif {$siteArg} {
        set site $arg
        set siteArg false
      } elseif {$belArg} {
        set bel $arg
        set belArg false
      } elseif {[string compare -nocase -l 2  $arg -instance] == 0} {
        set instanceArg true
      } elseif {[string compare -nocase -l 2  $arg -site] == 0} {
        set siteArg true
      } elseif {[string compare -nocase -l 2  $arg -bel] == 0} {
        set belArg true
      } elseif {[string compare -nocase -l 3 $arg -fixed] == 0} {
        set isFixed true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set isFixed false
          }
        }
      }
    }

    if {[info exists instance] == 0} {
      error "missing -instance argument"
    }
    if {[info exists site] == 0} {
      error "missing -site argument"
    }
    set result ""
    set code 0
    set undo false
    set empty ""
    set group_started [trystartgroup]
    if {$group_started} { rdi::record {startgroup} }
    if { [get_property loc [get_cells -quiet $instance] ] != "" } {
      rdi::record {set_property loc $empty [get_cells $instance]}
      set code [catch {set_property loc $empty [get_cells -quiet $instance]} result]
      if {$code == 0} {
        set undo true;
      }
    }

    if { $code == 0} {
      rdi::record {set_property loc $site [get_cells $instance]}
      set code [catch {set_property loc $site [get_cells -quiet $instance]} result]
      if {$code == 0} {
        set undo true;
      }
    }
    if { $code == 0 && [info exists bel] } {
      rdi::record {set_property bel $bel [get_cells $instance]}
      set code [catch {set_property bel $bel [get_cells -quiet $instance]} result]
      if {$code == 0} {
        set undo true;
      }
    }
    if { $group_started == 1} {
      rdi::record {endgroup}
      endgroup
    }
    if { $code != 0 } {
      if {$undo} {
        undo
      }
    }
    return -code $code $result
}

proc rdi::pconst_fix {isFixed cmdargs_var} {
    set pblocksArg false
    set instancesArg false
    set typesArg false

    foreach arg $cmdargs_var {
      if {$instancesArg} {
        set instances $arg
        set instancesArg false
      } elseif {$typesArg} {
        set types $arg
        set typesArg false
      } elseif {$pblocksArg} {
        set pblocks $arg
        set pblocksArg false
      } elseif {[string compare -nocase -l 2  $arg -instances] == 0} {
        set instancesArg true
      } elseif {[string compare -nocase -l 3  $arg -pblocks] == 0} {
        set pblocksArg true
      } elseif {[string compare -nocase -l 2  $arg -type] == 0} {
        set typesArg true
      }
    }

    if {([info exists instances]) && ([info exists pblocks]) } {
      error "specifiy either  -instances or -pblocks argument "
    }

    set orOper ""
    set typeFilter ""
    if {[info exists types]} {
      append typeFilter "("
      foreach type $types {
        append typeFilter $orOper
        append typeFilter "primitive_group ==  $type"
        set orOper " || "
      }
      append typeFilter ")"
    }
    lappend new_args -quiet
    if {[info exists pblocks]} {
      lappend new_args "*"
      lappend new_args -hier
      lappend new_args -filter
      append filterArg "(is_primitive==true && primitive_level!=\"INTERNAL\")  && loc != \"\" && ("
      set orOper ""
      foreach pblock $pblocks {
        append filterArg $orOper
        append filterArg "pblock ==  \"$pblock\""
        set orOper " || "
      }
      append filterArg ")"
      if {$typeFilter != "" } {
         append filterArg "&& ($typeFilter)"
      }
      lappend new_args $filterArg
    } elseif {[info exists instances]}  {
      lappend new_args $instances
      if {$typeFilter != ""} {
        lappend new_args -filter
        append filterArg $typeFilter
      }
      if {[info exists filterArg]} {
        lappend new_args $filterArg
      }
    } elseif {[info exists types]} {
      lappend new_args "*"
      lappend new_args -hier
      lappend new_args -filter
      append filterArg "(is_primitive==true && primitive_level!=\"INTERNAL\")  && loc != \"\" && "
      append filterArg $typeFilter
      lappend new_args $filterArg
    } else  {
      lappend new_args *
      lappend new_args -hier
      lappend new_args -filter
      append filterArg "(is_primitive==true && primitive_level!=\"INTERNAL\")  && loc != \"\""
      lappend new_args $filterArg
    }
    set cells [get_cells {*}$new_args]
    if {[llength $cells] > 0} {
      rdi::record {set_property is_fixed $isFixed [get_cells $new_args]}
      set_property is_fixed $isFixed $cells
    }
}

proc rdi::pconst_deleteLoc {cmdargs_var} {
    set instanceArg false

    foreach arg $cmdargs_var {
      if {$instanceArg} {
        set instance $arg
        set instanceArg false
      } elseif {[string compare -nocase -l 2  $arg -instance] == 0} {
        set instanceArg true
      }
    }

    if {[info exists instance] == 0} {
      error "missing -instance option"
    }
    set empty ""
    rdi::record {set_property loc $empty  [get_cells $instance]}
    set_property loc $empty  [get_cells -quiet $instance]
}

proc rdi::pconst_clearLocs {cmdargs_var} {
    set pblocksArg false
    set instancesArg false
    set typesArg false
    set keepFixed false

    foreach arg $cmdargs_var {
      if {$instancesArg} {
        set instances $arg
        set instancesArg false
      } elseif {$typesArg} {
        set types $arg
        set typesArg false
      } elseif {$pblocksArg} {
        set pblocks $arg
        set pblocksArg false
      } elseif {[string compare -nocase -l 2  $arg -instances] == 0} {
        set instancesArg true
      } elseif {[string compare -nocase -l 3  $arg -pblocks] == 0} {
        set pblocksArg true
      } elseif {[string compare -nocase -l 2  $arg -types] == 0} {
        set typesArg true
      } elseif {[string compare -nocase -l 2 $arg -keepFixed] == 0} {
        set keepFixed true
        set index [lsearch -exact $cmdargs_var $arg]
        if {[llength $cmdargs_var] > $index} {
          incr index
          set nextArg [lindex $cmdargs_var $index]
          if {$nextArg == "no"} {
            set keepFixed false
          }
        }
      }
    }

    if {([info exists instances]) && ([info exists pblocks]) } {
      error "specifiy either -instances or -pblocks argument "
    }

    lappend new_args -quiet
    set orOper ""
    set typeFilter ""
    if {[info exists types]} {
      append typeFilter "("
      foreach type $types {
        append typeFilter $orOper
        append typeFilter "primitive_group ==  $type"
        set orOper " || "
      }
      append typeFilter ")"
    }
    if {[info exists pblocks]} {
      lappend new_args *
      lappend new_args -hier
      lappend new_args -filter
      append filterArg "(is_primitive==true && primitive_level!=\"INTERNAL\")  && loc != \"\" && ("
      set orOper ""
      foreach pblock $pblocks {
        append filterArg $orOper
        append filterArg "pblock ==  \"$pblock\""
        set orOper " || "
      }
      append filterArg ")"
      if {$keepFixed} {
        append filterArg " && is_fixed == false"
      }
      if {$typeFilter != "" } {
         append filterArg " && ($typeFilter)"
      }
      lappend new_args $filterArg
    } elseif {[info exists instances]}  {
      lappend new_args $instances
      if {($typeFilter != "") || $keepFixed } {
        lappend new_args -filter
      }
      set andOper ""
      if {$typeFilter != ""} {
        append filterArg $typeFilter
        set andOper "&&"
      }
      if {$keepFixed} {
        append filterArg " $andOper is_fixed == false"
      }
      if {[info exists filterArg]} {
        lappend new_args $filterArg
      }
    } elseif {[info exists types]} {
      lappend new_args *
      lappend new_args -hier
      lappend new_args -filter
      append filterArg "(is_primitive==true && primitive_level!=\"INTERNAL\")  && loc != \"\" && "
      if {$keepFixed} {
        append filterArg " is_fixed == false && "
      }
      append filterArg $typeFilter
      lappend new_args $filterArg
    } else  {
      lappend new_args *
      lappend new_args -hier
      lappend new_args -filter
      append filterArg "(is_primitive==true && primitive_level!=\"INTERNAL\")  && loc != \"\""
      if {$keepFixed} {
        append filterArg " && is_fixed == false"
      }
      lappend new_args $filterArg
    }
    set cells [get_cells {*}$new_args]
    if {[llength $cells] > 0} {
      rdi::record {set_property loc "" [get_cells $new_args]}
      set_property loc "" $cells
    }
}

proc rdi::pconst_unload {args} {
  set file [rdi::scan_for_option -file args]
  set floorplan [rdi::scan_for_option -floorplan args]
  set dir [file dirname $file]
  if {![rdi::is_blank $dir] && ![string equal $dir .]} {
    error "Invalid value for '-file'; the file name must not include a directory"
  }
  set fileobj [get_files -of_objects [get_filesets $floorplan] *$file]
  rdi::record {remove_files -fileset $floorplan $fileobj}
  remove_files -fileset $floorplan $fileobj
  rdi::record {reset_ucf $file}
  reset_ucf $file
}

proc rdi::pconst_newDciCascade {cmdargs_var} {
    set masterArg false
    set slaveArg false

    foreach arg $cmdargs_var {
      if {$masterArg} {
        set master $arg
        set masterArg false
      } elseif {$slaveArg} {
        set slaves $arg
        set slaveArg false
      } elseif {[string compare -nocase -length 2  $arg -master] == 0} {
        set masterArg true
      } elseif {[string compare -nocase -length 2  $arg -slaves] == 0} {
        set slaveArg true
      }
    }

    if {[info exists master] == 0} {
      error "missing -master argument"
    }

    if {[info exists slaves] == 0} {
      error "missing -slaves argument"
    }

    set iobanks [get_iobanks -quiet $master]
    if {[llength $iobanks] > 0} {
      rdi::record {set_property slave_banks $slaves [get_iobanks $master]}
      set_property slave_banks $slaves $iobanks
    }
}

proc rdi::pconst_deleteDciCascade {cmdargs_var} {
    set masterArg false

    foreach arg $cmdargs_var {
      if {$masterArg} {
        set master $arg
        set masterArg false
      } elseif {[string compare -nocase -length 2  $arg -master] == 0} {
        set masterArg true
      }
    }

    if {[info exists master] == 0} {
      error "missing -master argument"
    }

    set iobanks [get_iobanks -quiet $master]
    if {[llength $iobanks] > 0} {
      set empty ""
      rdi::record {set_property slave_banks "" [get_iobanks $master]}
      set_property slave_banks $empty $iobanks
    }
}


proc hdi::pconst {subcmd args} {
  if {[rdi::is_help hdi::pconst $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  if {[string compare -nocase -l 1 $subcmd "import"]==0} {
    set result [uplevel 1 rdi::pconst_import $args]
  } elseif {[string compare -nocase -l 4 $subcmd "newLoc"]==0} {
    set result [rdi::pconst_newLoc $args]
  } elseif {[string compare -nocase -l 2 $subcmd "fix"]==0} {
    set result [rdi::pconst_fix true $args]
  } elseif {[string compare -nocase -l 3 $subcmd "unfix"]==0} {
    set result [rdi::pconst_fix false $args]
  } elseif {[string compare -nocase -l 7 $subcmd "deleteLoc"]==0} {
    set result [rdi::pconst_deleteLoc $args]
  } elseif {[string compare -nocase -l 1 $subcmd "clearLocs"]==0} {
    set result [rdi::pconst_clearLocs $args]
  } elseif {[string compare -nocase -l 3 $subcmd "unload"]==0} {
    set result [uplevel 1 rdi::pconst_unload $args]
  } elseif {[string compare -nocase -l 4 $subcmd "newDciCascade"]==0} {
    set result [rdi::pconst_newDciCascade $args]
  } elseif {[string compare -nocase -l 7 $subcmd "deleteDciCascade"]==0} {
    set result [rdi::pconst_deleteDciCascade $args]
  } else {
    error "ERROR: invalid command name 'hdi::pconst $subcmd'"
  }
  return $result
}

proc rdi::chipscope_create_debug_core {cmdargs_var} {
    set nameArg false
    set typeArg false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$typeArg} {
        set type $arg
        set typeArg false
      } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -type] == 0} {
        set typeArg true
      }
    }

    if {[info exists name] == 0} {
      error "missing -name option"
    }
    if {[info exists type] == 0} {
      error "missing -name option"
    }
    rdi::record {create_debug_core $name $type}
    create_debug_core $name $type
}

proc rdi::chipscope_remove_debug_core {cmdargs_var} {
  set namesArg false
  set all false

  foreach arg $cmdargs_var {
    if {$namesArg} {
      set names $arg
      set namesArg false
    } elseif {[string compare -nocase -l 2  $arg -names] == 0} {
      set namesArg true
    } elseif {[string compare -nocase -l 2  $arg -all] == 0} {
      set all true
    }
  }

  if {([info exists names] == 0) && ($all == false)} {
    error "specify either -names or -all option"
  }
  set code 0
  set result ""
  if {$all == true} {
    rdi::record {delete_debug_core [get_debug_cores -quiet]}
    delete_debug_core [get_debug_cores -quiet]
  } else {
    rdi::record {delete_debug_core $names}
    delete_debug_core $names
  }
}

proc rdi::chipscope_create_debug_port {cmdargs_var} {
    set nameArg false
    set typeArg false

    foreach arg $cmdargs_var {
      if {$nameArg} {
        set name $arg
        set nameArg false
      } elseif {$typeArg} {
        set type $arg
        set typeArg false
      } elseif {[string compare -nocase -l 2  $arg -core] == 0} {
        set nameArg true
      } elseif {[string compare -nocase -l 2  $arg -type] == 0} {
        set typeArg true
      }
    }

    if {[info exists name] == 0} {
      error "missing -name option"
    }
    if {[info exists type] == 0} {
      error "missing -type option"
    }
    rdi::record {create_debug_port $name $type}
    create_debug_port $name $type
}

proc rdi::chipscope_remove_debug_port {cmdargs_var} {
  set namesArg false

  foreach arg $cmdargs_var {
    if {$namesArg} {
      set names $arg
      set namesArg false
    } elseif {[string compare -nocase -l 2  $arg -names] == 0} {
      set namesArg true
    }
  }

  if {[info exists names] == 0} {
    error "missing -names option"
  }
  rdi::record {delete_debug_port $names}
  delete_debug_port $names
}

proc rdi::chipscope_implement_debug_core {cmdargs_var} {
  set namesArg false
  set all false

  foreach arg $cmdargs_var {
    if {$namesArg} {
      set names $arg
      set namesArg false
    } elseif {[string compare -nocase -l 2  $arg -names] == 0} {
      set nameArg true
    } elseif {[string compare -nocase -l 2  $arg -all] == 0} {
      set all true
    }
  }

  if {[info exists names] == 0 && ($all == false)} {
    error "specify either -names or -all option"
  }
  set code 0
  set result ""
  if {$all == true} {
    rdi::record {implement_debug_core [get_debug_cores -quiet]}
    implement_debug_core [get_debug_cores -quiet]
  } else {
    rdi::record {implement_debug_core $names}
    implement_debug_core $names
  }
}

proc rdi::chipscope_report_debug_core {cmdargs_var} {
  set fileArg false

  foreach arg $cmdargs_var {
    if {$fileArg} {
      set file $arg
      set fileArg false
    } elseif {[string compare -nocase -l 2  $arg -file] == 0} {
      set fileArg true
    }
  }

  if {[info exists file] == 0} {
    error "missing -file option"
  }
  rdi::record {report_debug_core -file $file}
  report_debug_core -file $file
}

proc rdi::chipscope_config_debug_core_port {isCore cmdargs_var} {
  set nameArg false
  set paramArg false

  foreach arg $cmdargs_var {
    if {$nameArg} {
      set name $arg
      set nameArg false
    } elseif {$paramArg} {
      set param $arg
      set paramArg false
    } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
      set nameArg true
    } elseif {[string compare -nocase -l 3  $arg -params] == 0} {
      set paramArg true
    }
  }

  if {[info exists name] == 0} {
    error "missing -name option"
  }

  if {[info exists paramArg] == 0} {
    error "missing -params option"
  }
  
  set group_started 0
  if {[llength $param] > 2} {
    set group_started [trystartgroup]
  }

  if {$group_started} { rdi::record {startgroup} }

  set code [catch {
    foreach {config value} $param {
      if {$isCore} {
        rdi::record {set_property $config $value [get_debug_cores $name]}
        set_property $config $value [get_debug_cores -quiet $name]
      } else {
        rdi::record {set_property $config $value [get_debug_ports $name]}
        set_property $config $value [get_debug_ports -quiet $name]
      }
    }
  } result]

  if { $group_started == 1} {
    rdi::record {endgroup}
    endgroup
  }

  return -code $code $result
}

proc rdi::chipscope_connect_debug_port {cmdargs_var} {
  set portArg false
  set channelArg false
  set netsArg false
  set pinsArg false
  set channel -1
  foreach arg $cmdargs_var {
    if {$portArg} {
      set port $arg
      set portArg false
    } elseif {$channelArg} {
      set channel $arg
      set channelArg false
    } elseif {$netsArg} {
      set nets $arg
      set netsArg false
    } elseif {$pinsArg} {
      set pins $arg
      set pinsArg false
    } elseif {[string compare -nocase -l 3  $arg -port] == 0} {
      set portArg true
    } elseif {[string compare -nocase -l 2  $arg -channel_start_index] == 0} {
      set channelArg true
    } elseif {[string compare -nocase -l 2  $arg -nets] == 0} {
      set netsArg true
    } elseif {[string compare -nocase -l 3  $arg -pins] == 0} {
      set pinsArg true
    }
  }

  if {[info exists port] == 0} {
    error "missing -port option"
  }

  if {([info exists nets] == 0) && ([info exists pins] == 0)} {
    error "specify -nets or -pins option"
  }

  if {[info exists nets] != 0} {
    set found [get_nets -quiet $nets]
    if {[llength $found] == 0} {
      set bus ""
      foreach net $nets {
        lappend bus $net[*]
      }
      set found [get_nets -quiet {*}$bus]
      if {[llength $found] > 1} {
        set found [lsort -increasing $found]
      }
    }
    if {[llength $found] > 0} {
      rdi::record {connect_debug_port $port $found -channel_start_index $channel}
      connect_debug_port $port $found -channel_start_index $channel
    }
  }
  if {[info exists pins]} {
    rdi::record {connect_debug_port $port $pins -channel_start_index $channel}
    connect_debug_port $port $pins -channel_start_index $channel
  }
}

proc rdi::chipscope_disconnect_debug_port {cmdargs_var} {
  set portArg false
  set channelArg false
  set channel -1
  foreach arg $cmdargs_var {
    if {$portArg} {
      set port $arg
      set portArg false
    } elseif {$channelArg} {
      set channel $arg
      set channelArg false
    } elseif {[string compare -nocase -l 3  $arg -port] == 0} {
      set portArg true
    } elseif {[string compare -nocase -l 2  $arg -channel_index] == 0} {
      set channelArg true
    }
  }

  if {[info exists port] == 0} {
    error "missing -port option"
  }

  rdi::record {disconnect_debug_port $port -channel_index $channel}
  disconnect_debug_port $port -channel_index $channel
}

proc rdi::chipscope_set_debug_port_width {cmdargs_var} {
  set nameArg false
  set widthArg false
  foreach arg $cmdargs_var {
    if {$nameArg} {
      set name $arg
      set nameArg false
    } elseif {$widthArg} {
      set width $arg
      set widthArg false
    } elseif {[string compare -nocase -l 2  $arg -name] == 0} {
      set nameArg true
    } elseif {[string compare -nocase -l 2  $arg -width] == 0} {
      set widthArg true
    }
  }

  if {[info exists name] == 0} {
    error "missing -name option"
  }
  if {[info exists width] == 0} {
    error "missing -width option"
  }

  rdi::record {set_property port_width $width [get_debug_ports $name]}
  set_property port_width $width [get_debug_ports -quiet $name]
}

proc rdi::chipscope_export_debug_net_names {cmdargs_var} {
  set fileArg false

  foreach arg $cmdargs_var {
    if {$fileArg} {
      set file $arg
      set fileArg false
    } elseif {[string compare -nocase -l 2  $arg -file] == 0} {
      set fileArg true
    }
  }

  if {[info exists file] == 0} {
    error "missing -file option"
  }
  rdi::record {write_chipscope_cdc $file}
  write_chipscope_cdc $file
}

proc rdi::chipscope_mark_debug_net {isMark cmdargs_var} {
  set namesArg false

  foreach arg $cmdargs_var {
    if {$namesArg} {
      set names $arg
      set namesArg false
    } elseif {[string compare -nocase -l 2  $arg -names] == 0} {
      set namesArg true
    }
  }

  if {[info exists names] == 0} {
    error "missing -names option"
  }
  rdi::record {set_property mark_debug $isMark [get_nets $names]}
  set_property mark_debug $isMark [get_nets -quiet $names]
}

proc rdi::chipscope_launch_analyzer {cmdargs_var} {
  set runArg false
  set csprojectArg false
  foreach arg $cmdargs_var {
    if {$runArg} {
      set run $arg
      set runArg false
    } elseif {$csprojectArg} {
      set csproject $arg
      set csprojectArg false
    } elseif {[string compare -nocase -l 2  $arg -run] == 0} {
      set runArg true
    } elseif {[string compare -nocase -l 2  $arg -csproject] == 0} {
      set csprojectArg true
    }
  }

  if {[info exists run] == 0} {
    error "missing -run option"
  }
  lappend new_args $run
  if {[info exists csproject] } {
    lappend new_args -csproject
    lappend new_args $csproject
  }
  rdi::record {launch_chipscope_analyzer $new_args}
  launch_chipscope_analyzer {*}$new_args
}

proc hdi::chipscope {subcmd args} {
  if {[rdi::is_help hdi::chipscope $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  rdi::open_design_if_needed
  if {[string compare -nocase -l 14 $subcmd "create_debug_core"]==0} {
    set result [rdi::chipscope_create_debug_core $args]
  } elseif {[string compare -nocase -l 14 $subcmd "remove_debug_core"]==0} {
    set result [rdi::chipscope_remove_debug_core $args]
  } elseif {[string compare -nocase -l 14 $subcmd "create_debug_port"]==0} {
    set result [rdi::chipscope_create_debug_port $args]
  } elseif {[string compare -nocase -l 14 $subcmd "remove_debug_port"]==0} {
    set result [rdi::chipscope_remove_debug_port $args]
  } elseif {[string compare -nocase -l 1 $subcmd "implement_debug_core"]==0} {
    set result [rdi::chipscope_implement_debug_core $args]
  } elseif {[string compare -nocase -l 3 $subcmd "report_debug_core"]==0} {
    set result [rdi::chipscope_report_debug_core $args]
  } elseif {[string compare -nocase -l 14 $subcmd "config_debug_core"]==0} {
    set result [rdi::chipscope_config_debug_core_port true $args]
  } elseif {[string compare -nocase -l 14 $subcmd "config_debug_port"]==0} {
    set result [rdi::chipscope_config_debug_core_port false $args]
  } elseif {[string compare -nocase -l 4 $subcmd "connect_debug_port"]==0} {
    set result [rdi::chipscope_connect_debug_port $args]
  } elseif {[string compare -nocase -l 1 $subcmd "disconnect_debug_port"]==0} {
    set result [rdi::chipscope_disconnect_debug_port $args]
  } elseif {[string compare -nocase -l 1 $subcmd "set_debug_port_width"]==0} {
    set result [rdi::chipscope_set_debug_port_width $args]
  } elseif {[string compare -nocase -l 1 $subcmd "export_debug_net_names"]==0} {
    set result [rdi::chipscope_export_debug_net_names $args]
  } elseif {[string compare -nocase -l 1 $subcmd "mark_debug_net"]==0} {
    set result [rdi::chipscope_mark_debug_net true $args]
  } elseif {[string compare -nocase -l 1 $subcmd "unmark_debug_net"]==0} {
    set result [rdi::chipscope_mark_debug_net false $args]
  } elseif {[string compare -nocase -l 1 $subcmd "launch_analyzer"]==0} {
    set result [rdi::chipscope_launch_analyzer $args]
  } else {
    error "ERROR: invalid command name 'hdi::chipscope $subcmd'"
  }
  return $result
}

proc hdi::partition {subcmd args} {
  if {[rdi::is_help hdi::partition $subcmd args]} { return }

  rdi::parse_options {-name -names -partitionNames -path -all -partitionsOnly -instance -module -top -implement -import -importLocation} args options
  rdi::get_option options -name           name
  rdi::get_option options -names          names
  rdi::get_option options -partitionNames partition_names
  rdi::get_option options -path           promote_dir
  rdi::get_option options -all            all
  rdi::get_option options -partitionsOnly partitions_only
  rdi::get_option options -instance       instance
  rdi::get_option options -module         module
  rdi::get_option options -top            top
  rdi::get_option options -implement      implement
  rdi::get_option options -import         import
  rdi::get_option options -importLocation import_dir

  set new_cmd ""
  set new_args ""
  switch -nocase $subcmd {
    setPartition {
      set new_cmd set_property
    }
    clearPartition {
      set new_cmd set_property
    }
    promote {
      set new_cmd promote_run
    }
    unpromote {
      set new_cmd demote_run
    }
    setConfig {
      set new_cmd config_partition
    }
  }

  rdi::open_design_if_needed

  switch -nocase $subcmd {
    setPartition {
      rdi::ensure_required_options options -name
      rdi::record {set_property is_partition 1 [get_cells $name]}
      return [set_property is_partition 1 [get_cells -quiet $name]]
    }
    clearPartition {
      rdi::ensure_required_options options -name
      rdi::record {set_property is_partition 0 [get_cells $name]}
      return [set_property is_partition 0 [get_cells -quiet $name]]
    }
    promote {
      # hdi::partition promote [-names <list of names>] [-partitionNames <list of names>] [-path <name>] [-all [yes | no]] [-partitionsOnly [yes | no]]
      # promote_run     [-run <run>] [-partition_names <partition_names>] [-promote_dir <dirname>]
      if {[rdi::is_blank $names] && ![rdi::get_bool_option options -all 0] || 
          ![rdi::is_blank $names] && [rdi::get_bool_option options -all 0]} {
        error "ERROR: Please specify one of 'names' or 'all'"
      }
      set result 0
      foreach run $names {
        set new_args [list -run $run]
        if {![rdi::is_blank $partition_names]} {
          lappend new_args -partition_names
          foreach partition $partition_names {
            lappend new_args $partition
          }
        }
        if {![rdi::is_blank $promote_dir]} { lappend new_args -promote_dir $promote_dir }
        rdi::record {$new_cmd $new_args}
        set result [$new_cmd {*}$new_args]
      }
      return $result
    }
    unpromote {
      # hdi::partition unpromote [-names <list of names>] [-all [yes | no]] [-partitionNames <list of names>] [-path <name>]
      # demote_run -run <run> [-partition_names <names>] [-promote_dir <dirname>]
      if {[rdi::is_blank $names] && ![rdi::get_bool_option options -all 0] || 
          ![rdi::is_blank $names] && [rdi::get_bool_option options -all 0]} {
        error "ERROR: Please specify one of 'names' or 'all'"
      }
      set result 0
      foreach run $names {
        set new_args [list -run $run]
        if {![rdi::is_blank $partition_names]} {
          lappend new_args -partition_names
          foreach partition $partition_names {
            lappend new_args $partition
          }
        }
        if {![rdi::is_blank $promote_dir]} { lappend new_args -promote_dir $promote_dir }
        rdi::record {$new_cmd $new_args}
        set result [$new_cmd {*}$new_args]
      }
      return $result
    }
    setConfig {
      # hdi::partition setConfig -name <name> [-instance <name>] [-module <name>] [-top [yes | no]] [-implement [yes | no]] [-import [yes | no]] [-importLocation <name>]
      # config_partition      -run <run> [-cell <cell>] [-reconfig_module <reconfig_module>] -implement|-import [-import_dir <dirname>]
      rdi::ensure_required_options options -name
      set new_args [list -run $name]
      if {![rdi::is_blank $instance]} { lappend new_args -cell $instance }
      if {![rdi::is_blank $module]} { lappend new_args -reconfig_module $module }
      if {[rdi::get_bool_option options -implement 0]} {
        lappend new_args -implement
      } elseif {[rdi::get_bool_option options -import 0]} {
        lappend new_args -import
      }
      if {![rdi::is_blank $import_dir]} { lappend new_args -import_dir $import_dir }
    }
  }

  rdi::record {$new_cmd $new_args}
  $new_cmd {*}$new_args
}

proc hdi::pr {subcmd args} {
  if {[rdi::is_help hdi::pr $subcmd args]} { return }

  rdi::parse_options {-name -names -all -moduleName -instance -file -search_path -blackbox -verbose} args options
  rdi::get_option options -name           name
  rdi::get_option options -names          names
  rdi::get_option options -all            all
  rdi::get_option options -moduleName     moduleName
  rdi::get_option options -instance       instance
  rdi::get_option options -file           file
  rdi::get_option options -search_path    search_path
  rdi::get_option options -blackbox       blackbox
  rdi::get_option options -verbose        verbose

  set new_cmd ""
  set new_args ""
  set loses_constraints false

  switch -nocase $subcmd {
    setProject {
      set new_cmd set_property
    }
    setInstance {
      error "OBSOLETE - use create_reconfig_module"
    }
    clearInstance {
      set new_cmd set_property
    }
    addModule {
      error "OBSOLETE - use create_reconfig_module"
    }
    deleteModule {
      set new_cmd delete_reconfig_module
    }
    loadModule -
    loadConfig {
      set new_cmd load_reconfig_modules
      set loses_constraints true
    }
    verify {
      set new_cmd verify_config
    }
    promoteConfig {
      error "OBSOLETE - use promote_run"
    }
    unpromoteConfig {
      error "OBSOLETE - use demote_run"
    }
    setConfig {
      error "OBSOLETE - use config_partition"
    }
  }

  if { $loses_constraints } {
    rdi::save_design_if_open
  }
  rdi::open_design_if_needed

  switch -nocase $subcmd {
    setProject {
      # hdi::pr setProject -name <name>
      # set_property is_partial_reconfig true <project>
      rdi::record {set_property is_partial_reconfig 1 [current_project]}
      return [set_property is_partial_reconfig 1 [current_project]]
    }
    clearInstance {
      # hdi::pr clearInstance -project <name> -name <name>
      # set_property is_partition false <cell>
      rdi::ensure_required_options options -name
      rdi::record {set_property is_partition 0 [get_cells $name]}
      return [set_property is_partition 0 [get_cells -quiet $name]]
    }
    deleteModule {
      # hdi::pr deleteModule -project <name> -name <name> -instance <name>
      # delete_reconfig_module               -reconfig_module <reconfig_module>
      rdi::ensure_required_options options { -name -instance }
      set rm [ get_reconfig_modules $name -of_objects $instance ]
      lappend new_args -reconfig_module $rm
    }
    loadModule {
      # hdi::pr loadModule -project <name> -name <name> -instance <name>
      # load_reconfig_modules              -reconfig_modules <reconfig_modules>|-run <run>
      rdi::ensure_required_options options { -name -instance }
      set rm [ get_reconfig_modules $name -of_objects $instance ]
      lappend new_args -reconfig_modules $rm
    }
    loadConfig {
      # hdi::pr loadConfig -project <name> -name <name>
      # load_reconfig_modules              -reconfig_modules <reconfig_modules>|-run <run>
      rdi::ensure_required_options options -name
      lappend new_args -run $name
    }
    verify {
      # hdi::pr verify [-names <list of names>] [-all [yes | no]] [-file <name>] [-verbose [yes | no]]
      # verify_config [-runs <runs>] [-file <filename>] [-verbose]
      if {[rdi::is_blank $names] && ![rdi::get_bool_option options -all 0] || 
          ![rdi::is_blank $names] && [rdi::get_bool_option options -all 0]} {
        error "ERROR: Please specify one of 'names' or 'all'"
      }
      lappend new_args -runs $names
      if {![rdi::is_blank $file]} { lappend new_args -file $file }
      if {[rdi::get_bool_option options -verbose 0]} { lappend new_args -verbose }
    }
  }

  rdi::record {$new_cmd $new_args}
  $new_cmd {*}$new_args
}

proc hdi::opt {subcmd args} {
  if {[rdi::is_help hdi::opt $subcmd args]} { return }
  rdi::open_floorplan_if_needed args

  rdi::parse_options {-topcell -recursively} args options
  rdi::get_option options -topcell        topcell
  rdi::get_option options -recursively    recursively

  set new_args ""

  switch -nocase $subcmd {
    sweep {
      lappend new_args -sweep
      if {![rdi::is_blank $topcell]} { lappend new_args -cell $topcell }
      if {![rdi::get_bool_option options -recursively 1]} { lappend new_args -norecurse }
    }
    retarget {
      lappend new_args -retarget
      if {![rdi::is_blank $topcell]} { lappend new_args -cell $topcell }
    }
    propc {
      lappend new_args -propconst
      if {![rdi::is_blank $topcell]} { lappend new_args -cell $topcell }
      if {![rdi::get_bool_option options -recursively 1]} { lappend new_args -norecurse }
    }
    pinswap {
      lappend new_args -pinswap
      error "'-pinswap' is not supported."
    }
    pack {
      lappend new_args -remap
      if {![rdi::is_blank $topcell]} { lappend new_args -cell $topcell }
    }
  }

  rdi::record {opt_design $new_args}
  opt_design {*}$new_args
}

proc rdi::run_add {args} {
  #hdi::run add -name <name> [-floorplan <name>] [-parentRun <name>] [-part <name>] -flow <name> [-pblock <name>] [-strategy <name>]
  #create_run -name <name> -constrset <fileset> [-parent_run <run>] [-part <name>] -flow <name> [-pblock <pblock>] [-strategy <name>]
  parse_options {-name -parentRun -part -flow -floorplan -pblock -strategy} args options
  ensure_required_options options {-name -flow}
  rdi::get_option options -name      name
  rdi::get_option options -parentRun parentRun
  rdi::get_option options -part      part
  rdi::get_option options -pblock    pblock
  rdi::get_option options -strategy  strategy
  rdi::get_option options -floorplan floorplan
  rdi::get_option options -flow      flow

  # If the following criteria is met, we don't create a new run, 
  # but instead reuse a default run (synth_1 or impl_1) by setting 
  # its properties to match the specifications. 
  #   - The default run must exist, be the only one of its type, and 
  #     have not been run. 
  #   - In HD projects, the run part must match the specified part 
  #     (changing run parts prohibited in HD projects). 
  #   - -pblock must not have been specified. 

  set default_run ""
  if {[rdi::is_blank $pblock]} {
    if {[string match -nocase "xst*" $flow] || [string match -nocase "vivado synthesis*" $flow]} {
      set synth_runs [get_runs -filter {is_synthesis==true}]
      if {[llength $synth_runs] == 1} {
        set default_run [get_runs synth_1]
      }
    } else {
      set impl_runs [get_runs -filter {is_implementation==true}]
      if {[llength $impl_runs] == 1} {
        set default_run [get_runs impl_1]
      }
    }
  }

  if {![rdi::is_blank $default_run]} {
    set status [get_property status [get_runs $default_run]]
    if {![string equal -nocase $status "Not Started"]} {
      set default_run ""
    } 
  }

  if {![rdi::is_blank $default_run]} {
    set old_flow [get_property flow [get_runs $default_run]]
    if {![string equal -nocase $old_flow $flow]} {
      rdi::record {set_property flow $flow [get_runs $default_run]}
      set_property flow $flow [get_runs $default_run]
    }
    if {![rdi::is_blank $strategy]} {
      set old_strategy [get_property strategy [get_runs $default_run]]
      if {![string equal -nocase $old_strategy $strategy]} {
        rdi::record {set_property strategy $strategy [get_runs $default_run]}
        set_property strategy $strategy [get_runs $default_run]
      }
        
    }
    if {![rdi::is_blank $part]} {
      set old_part [get_property part [get_runs $default_run]]
      if {![string equal -nocase $old_part $part]} {
        rdi::record {set_property part $part [get_runs $default_run]}
        set_property part $part [get_runs $default_run]
      }
    }
    if {![rdi::is_blank $parentRun]} {
      set old_parent [get_property parent [get_runs $default_run]]
      if {![string equal -nocase $old_parent $parentRun]} {
        rdi::record {set_property parent $parentRun [get_runs $default_run]}
        set_property parent $parentRun [get_runs $default_run]
      }
    }
    if {![rdi::is_blank $floorplan]} {
      set old_constrset [current_fileset -constrset]
      if {![string equal -nocase $old_constrset $floorplan]} {
        rdi::record {set_property constrset $floorplan [get_runs $default_run]}
        set_property constrset $floorplan [get_runs $default_run]
      }
    }
    set old_name [get_property name [get_runs $default_run]]
    if {![string equal -nocase $old_name $name]} {
      rdi::record {set_property name $name [get_runs $default_run]}
      set_property name $name [get_runs $default_run]
    }
    set run $default_run
  } else {
    lappend new_args -name $name -flow $flow
    if {![rdi::is_blank $parentRun]}  { lappend new_args -parent_run $parentRun }
    if {![rdi::is_blank $part]}       { lappend new_args -part $part }
    if {![rdi::is_blank $pblock]}     { lappend new_args -pblock $pblock }
    if {![rdi::is_blank $strategy]}   { lappend new_args -strategy $strategy }
    if {![rdi::is_blank $floorplan]}  { lappend new_args -constrset $floorplan }
    rdi::record {create_run $new_args}
    set run [create_run {*}$new_args]
  }
  return $run
}

proc rdi::run_delete {args} {
  #hdi::run delete -name <name> -project <name> [-cleanDir [yes | no]]
  #delete_run -run <run> [-clean_dir]
  parse_options {-name -cleanDir} args options
  rdi::get_option options -name     name
  rdi::get_option options -cleanDir cleanDir
  lappend new_args -run $name
  if {![get_bool_option options -cleanDir 1]} { lappend new_args -noclean_dir }
  rdi::record {delete_run $new_args}
  delete_run {*}$new_args
}

proc rdi::run_reset {args} {
  #hdi::run reset -name <name> -project <name> [-cleanDir [yes | no]]
  #reset_run -run <run> [-clean_dir]
  parse_options {-name -cleanDir} args options
  ensure_required_options options {-name}
  rdi::get_option options -name     name
  rdi::get_option options -cleanDir cleanDir
  lappend new_args -run $name
  if {![get_bool_option options -cleanDir 1]} { lappend new_args -noclean_dir }
  rdi::record {reset_run $new_args}
  reset_run {*}$new_args
}

proc rdi::run_launch {args} {
  #hdi::run launch -project <name> -runs <list of names> [-jobs <integer>] 
  #                [-scriptsOnly [yes | no]] [-allPlacement [yes | no]] [-dir <string>] 
  #                [-host <lists of strings>] [-remoteCmd <name>] [-emailTo <list of names>] 
  #                [-emailAll [yes | no]] [-preLaunchScript <string>] [-postLaunchScript <string>]
  #launch_runs -runs <runs> [-jobs <integer>] [-scripts_only] [-all_placement] [-dir <string>] 
  #                  [-host <strings>] [-remote_cmd <name>] [-email_to <names>] [-email_all] 
  #                  [-pre_launch_script <string>] [-post_launch_script <string>]
  rdi::parse_options {-runs -jobs -scriptsOnly -allPlacement 
                      -dir -remoteCmd -emailTo -emailAll 
                      -preLaunchScript -postLaunchScript} args options
  parse_multi_list_options {-host} args options
  ensure_required_options options {-runs}
  rdi::get_option options -runs             runs
  rdi::get_option options -jobs             jobs
  rdi::get_option options -remoteCmd        remoteCmd
  rdi::get_option options -scriptsOnly      scriptsOnly
  rdi::get_option options -allPlacement     allPlacement
  rdi::get_option options -dir              dir
  rdi::get_option options -emailTo          emailTo
  rdi::get_option options -emailAll         emailAll
  rdi::get_option options -preLaunchScript  preLaunchScript
  rdi::get_option options -postLaunchScript postLaunchScript
  rdi::get_option options -host             host

  lappend new_args -runs $runs
  if {![rdi::is_blank $jobs]}              { lappend new_args -jobs $jobs }
  if {[get_bool_option options -scriptsOnly 0]}                   { lappend new_args -scripts_only }
  if {[get_bool_option options -allPlacement 0]}                  { lappend new_args -all_placement }
  if {![rdi::is_blank $dir]}               { lappend new_args -dir $dir }
  if {![rdi::is_blank $remoteCmd]}         { lappend new_args -remote_cmd $remoteCmd }
  if {![rdi::is_blank $emailTo]}           { lappend new_args -email_to $emailTo }
  if {[get_bool_option options -emailAll 0]}                      { lappend new_args -email_all }
  if {![rdi::is_blank $preLaunchScript]}   { lappend new_args -pre_launch_script $preLaunchScript }
  if {![rdi::is_blank $postLaunchScript]}  { lappend new_args -post_launch_script $postLaunchScript }
  if {![rdi::is_blank $host]} {
    foreach host $host {
      lappend new_args -host $host
    }
  }

  # In PR designs launch_runs may lose constraints if not saved.
  if { [get_property is_partial_reconfig [current_project]] } {
    save_design_if_open
  }
  
  foreach run $runs {
    rdi::record {reset_run $run}
    reset_run $run
  }
  rdi::record {launch_runs $new_args}
  launch_runs {*}$new_args
}

proc rdi::run_config {args} {
  #hdi::run config -name <name> [-project <name>] -program <name> -option <name> -value <name>
  #config_run -run <run> -program <name> -option <name> -value <name>
  parse_options {-name -program -option -value} args options
  ensure_required_options options {-name -program -option -value}
  rdi::get_option options -name     name
  rdi::get_option options -program  program
  rdi::get_option options -option   option
  rdi::get_option options -value    value
  rdi::record {config_run -run $name -program $program -option $option -value $value}
  config_run -run $name -program $program -option $option -value $value
}

proc rdi::run_wait {args} {
  #hdi::run wait -name <name> -project <name> [-timeout <integer>]
  #wait_on_run -run <run> [-timeout <integer>]
  parse_options {-name -timeout} args options
  ensure_required_options options {-name}
  rdi::get_option options -name     name
  rdi::get_option options -timeout  timeout
  lappend new_args -run $name
  if {![rdi::is_blank $timeout]} { lappend new_args -timeout $timeout }
  rdi::record {wait_on_run $new_args}
  wait_on_run {*}$new_args
}

proc rdi::run_import {args} {
  #hdi::run import -name <name> -project <name> [-placement [yes | no]]
  #open_impl_design -name <name> [-placement]
  parse_options {-name -placement} args options
  ensure_required_options options {-name}
  rdi::get_option options -name name
  set run [get_runs $name]
  if {[rdi::is_blank $run]} {
    error "ERROR: Could not get run $run"
  }
  if {[get_property is_synthesis [get_runs $name]]} {
    rdi::record {open_netlist_design -run $name}
    open_netlist_design -run $name
  } else {
    rdi::record {open_impl_design $name}
    open_impl_design $name
  }
}

proc rdi::run_set {args} {
  #hdi::run set -name <name> -project <name> [-newName <name>] 
  #             [-description <name>] [-flow <name>] [-strategy <name>] 
  #             [-addStep <string>] [-ucf <string>] [-part <name>]
  parse_options {-name -project -newName -description -flow -strategy -addStep -ucf -part} args options
  ensure_required_options options {-name}
  rdi::get_option options -name        name
  rdi::get_option options -project     project
  rdi::get_option options -newName     newName
  rdi::get_option options -description description
  rdi::get_option options -flow        flow
  rdi::get_option options -strategy    strategy
  rdi::get_option options -addStep     addStep
  rdi::get_option options -ucf         ucf
  rdi::get_option options -part        part

  if {![rdi::is_blank $ucf]} { puts "WARN: -ucf is not supported." }

  set run [get_runs $name]
  if {[rdi::is_blank $run]} {
    error "ERROR: Could not get run $run"
  }

  # Note that name must go last!
  # Note that description must go after flow and strategy, 
  # since either will overwrite the newly set description. 
  if {![rdi::is_blank $flow]}        { 
    rdi::record {set_property flow $flow [get_runs $name]}
    set_property flow $flow [get_runs $name] 
  }
  if {![rdi::is_blank $strategy]}    { 
    rdi::record {set_property strategy $strategy [get_runs $name]}
    set_property strategy $strategy [get_runs $name] 
  }
  if {![rdi::is_blank $addStep]}     { 
    rdi::record {set_property add_step $addStep [get_runs $name]}
    set_property add_step $addStep [get_runs $name] 
  }
  if {![rdi::is_blank $part]}        { 
    rdi::record {set_property part $part [get_runs $name]}
    set_property part $part [get_runs $name] 
  }
  if {![rdi::is_blank $description]} { 
    rdi::record {set_property description $description [get_runs $name]}
    set_property description $description [get_runs $name] 
  }
  if {![rdi::is_blank $newName]}     { 
    rdi::record {set_property name $newName [get_runs $name]}
    set_property name $newName [get_runs $name] 
  }
}

proc hdi::run {subcmd args} {
  if {[rdi::is_help hdi::run $subcmd args]} { return }

  switch -nocase $subcmd {
    add {
      rdi::open_floorplan_if_needed args
      return [uplevel 1 rdi::run_add $args]
    }
    delete {
      return [uplevel 1 rdi::run_delete $args]
    }
    reset {
      return [uplevel 1 rdi::run_reset $args]
    }
    launch {
      return [uplevel 1 rdi::run_launch $args]
    }
    config {
      return [uplevel 1 rdi::run_config $args]
    }
    wait {
      return [uplevel 1 rdi::run_wait $args]
    }
    import {
      return [uplevel 1 rdi::run_import $args]
    }
    set {
      return [uplevel 1 rdi::run_set $args]
    }
  }
  error "ERROR: invalid command name 'hdi::run $subcmd'"
}

proc rdi::floorplan_new {args} {
  set name [rdi::scan_for_option -name args]
  set part [rdi::scan_for_option -part args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }

  # story: old Tcl scripts used to create a project, then create an fp.
  # when we do the same thing in today's system we get a project with 2 fps -
  # the default fp (constrs_1) and the new fp.
  # to maintain backwards compatibility with old Tcl, just rename the default
  # constraint set to match the new fp
  set fileset [get_filesets -quiet $name]
  if {[rdi::is_blank $fileset]} {
    set filesets [get_filesets -quiet -filter {fileset_type==Constrs}]
    if {[llength $filesets] == 1} {
      set filesets [get_filesets -quiet constrs_1]
      if {![rdi::is_blank $filesets]} {
        # check for no sources added
        set src_files [get_files -quiet -of_objects $filesets]
        if {[rdi::is_blank $src_files]} {
          rdi::record {set_property name $name [get_filesets constrs_1]}
          set_property name $name $filesets
          set fileset [lindex $filesets 0]
          if {![rdi::is_blank $part]} {
            # change the part on the default run
            set defRun [get_runs]
            if {[llength $defRun] == 1} {
              rdi::record {set_property part $part [get_runs]}
              set_property part $part [get_runs]
            }
          }
        }
      }
    }
  }
  if {[rdi::is_blank $fileset]} {
    rdi::record {set fileset [create_fileset -constrset -name $name]}
    set fileset [create_fileset -constrset -name $name]
  }
  if {![rdi::is_blank $part]} {
    rdi::record {set_property target_part $part [get_filesets $name]}
    set_property target_part $part [get_filesets -quiet $name]
  }
  lappend new_args -constrset $fileset -name $name
  if {![rdi::is_blank $part]} {
    lappend new_args -part $part
  } else {
    lappend new_args -edif_part
  }
  set designMode [get_property design_mode [current_fileset]]
  if {[string equal $designMode "PinPlanning"]} {
    rdi::record {open_io_design $new_args}
    open_io_design {*}$new_args
  } else {
    rdi::record {open_netlist_design $new_args}
    open_netlist_design {*}$new_args
  }
}

proc rdi::floorplan_set {args} {
  set name [rdi::scan_for_option -name args]
  set newName [rdi::scan_for_option -newName args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }
  if {[rdi::is_blank $newName]} {
    error "ERROR: required option 'newName' is missing"
  }
  set fileset [get_filesets $name]
  if {[rdi::is_blank $fileset]} {
    error "ERROR: Could not get fileset $fileset"
  }
  rdi::record {set_property name $newName [get_filesets $name]}
  set_property name $newName [ get_filesets $name ]
}

proc rdi::floorplan_delete {args} {
  set name [rdi::scan_for_option -name args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }

  # save this off in case $name gets clobbered???
  set fpname $name

  # if the design is open, close it...
  if {[is_design_open $name]} {
    rdi::record {current_design $name}
    current_design $name
    rdi::record {close_design}
    close_design
  }

  # don't delete the fileset if it is active:
  if {![string equal $fpname [current_fileset -constrs]]} {
    rdi::record {delete_fileset $fpname}
    delete_fileset $fpname
  }
}

proc rdi::floorplan_close {args} {
  set name [rdi::scan_for_option -name args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }
  ensure_design_open $name
  rdi::record {current_design $name}
  current_design $name
  rdi::record {close_design}
  close_design
}

proc rdi::floorplan_save {args} {
  set name [rdi::scan_for_option -name args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }
  ensure_design_open $name
  rdi::record {current_design $name}
  current_design $name
  rdi::record {save_design}
  save_design
}

proc rdi::floorplan_open {args} {
  set name [rdi::scan_for_option -name args]
  set file [rdi::scan_for_option -file args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }
  if {![rdi::is_blank $file]} {
    error "ERROR: hdi::floorplan open no longer supports fdb files."
  }
  if {[is_design_open $name]} {
    error "ERROR: the floorplan $name is already open"
  }
  rdi::record {open_netlist_design -name $name -constrset $name}
  open_netlist_design -name $name -constrset $name
  rdi::record {current_design $name}
  current_design $name  
}

proc rdi::floorplan_save_as {args} {
  set name [rdi::scan_for_option -name args]
  set newName [rdi::scan_for_option -newName args]
  set file [rdi::scan_for_option -file args]
  if {[rdi::is_blank $name]} {
    error "ERROR: required option 'name' is missing"
  }
  if {[rdi::is_blank $newName]} {
    error "ERROR: required option 'newName' is missing"
  }
  if {![rdi::is_blank $file]} {
    error "ERROR: hdi::floorplan saveAs no longer supports fdb files."
  }
  ensure_design_open $name
  rdi::record {current_design $name}
  current_design $name
  rdi::record {save_design_as $newName}
  save_design_as $newName
}

proc rdi::floorplan_importPlacement {args} {
  set floorplan [rdi::scan_for_option -floorplan args]
  set file [rdi::scan_for_option -file args]
  set pblock [rdi::scan_for_option -pblock args]
  set instance [rdi::scan_for_option -instance args]
  open_design_if_needed $floorplan
  if {[rdi::has_option -pblock args]} { lappend new_args -pblock $pblock }
  if {[rdi::has_option -instance args]} { lappend new_args -cell $instance }
  lappend new_args $file
  rdi::record {read_xdl $new_args}
  read_xdl {*}$new_args
}

proc rdi::floorplan_exportUCF {args} {
  set floorplan [rdi::scan_for_option -floorplan args]
  set file [rdi::scan_for_option -file args]
  set fixedOnly [rdi::scan_for_bool_option -fixedOnly 0 args]
  open_design_if_needed $floorplan
  if {$fixedOnly == 0} { lappend new_args -no_fixed_only }
  lappend new_args $file
  rdi::record {write_ucf $new_args}
  write_ucf {*}$new_args
}

proc rdi::floorplan_export {args} {
  set name [rdi::scan_for_option -name args]
  if {![rdi::is_blank $name]} {
    rdi::open_design_if_needed $name
  }

  set dir [rdi::scan_for_option -dir args]
  set pblocks [rdi::scan_for_option -pblocks args]
  set instance [rdi::scan_for_option -instance args]
  set genNetlist [rdi::scan_for_bool_option -genNetlist 1 args]
  set genConst [rdi::scan_for_bool_option -genConst 1 args]
  set genTop [rdi::scan_for_bool_option -genTop 0 args]
  set allPlacement [rdi::scan_for_bool_option -allPlacement 0 args]
  if {$genTop} {
    if {[lsearch -exact $pblocks ROOT] < 0} {
      lappend pblocks ROOT
    }
  }

  if {![rdi::is_blank $instance]} {
    lappend ucf_args -cell $instance
    lappend edf_args -cell $instance
  }
  if {![rdi::is_blank $pblocks]} {
    lappend ucf_args -pblocks $pblocks
    lappend edf_args -pblocks $pblocks
  }
  if {$allPlacement} {
    lappend ucf_args -no_fixed_only
  }
  lappend ucf_args $dir
  lappend edf_args $dir
  if {$genConst} {
    rdi::record {write_ucf $ucf_args}
    write_ucf {*}$ucf_args
  }
  if {$genNetlist} {
    rdi::record {write_edif $edf_args}
    write_edif {*}$edf_args
  }
}

proc rdi::floorplan_exportAsRPM {args} {
  rdi::open_floorplan_if_needed args
  set floorplan [rdi::scan_for_option -floorplan args]
  set instance [rdi::scan_for_option -instance args]
  set file [rdi::scan_for_option -file args]
  if {[rdi::has_option -instance args]} { lappend new_args -cell $instance }
  lappend new_args -mode RPM $file
  rdi::record {write_ucf $new_args}
  write_ucf {*}$new_args
}


#----------------------------------------------
#deprecation layer for hdi::floorplan commands
#----------------------------------------------
proc hdi::floorplan {subcmd args} {
  if {[rdi::is_help hdi::floorplan $subcmd args]} { return }
  set match [rdi::match { close copy delete exportUCF 
                          import importPlacement new open set save saveAs 
                          exportAsRPM export } $subcmd]
  switch $match {
    close {
      uplevel 1 rdi::floorplan_close $args
    }
    copy {
      error "ERROR: hdi::floorplan copy is no longer supported. Please use save_design_as instead."
    }
    delete {
      uplevel 1 rdi::floorplan_delete $args
    }
    exportUCF {
      uplevel 1 rdi::floorplan_exportUCF $args
    }
    importPlacement {
      uplevel 1 rdi::floorplan_importPlacement $args
    }
    import {
      error "ERROR: hdi::floorplan import is no longer supported."
    }
    new {
      uplevel 1 rdi::floorplan_new $args
    }
    open {
      uplevel 1 rdi::floorplan_open $args
    }
    set {
      uplevel 1 rdi::floorplan_set $args
    }
    save {
      uplevel 1 rdi::floorplan_save $args
    }
    saveAs {
      uplevel 1 rdi::floorplan_save_as $args
    }
    export {
      uplevel 1 rdi::floorplan_export $args
    }
    exportAsRPM {
      uplevel 1 rdi::floorplan_exportAsRPM $args
    }
    default {
      error "ERROR: invalid command name 'hdi::floorplan $subcmd'"
    }
  }
}

#--------------------------------------------------------
#hdi::project commands group
#--------------------------------------------------------
proc rdi::project_create {args} {
  set name [rdi::scan_for_option -name args]
  set rtl [rdi::scan_for_bool_option -rtl 0 args]
  set force [rdi::scan_for_bool_option -w 0 args]
  set dir [rdi::scan_for_option -dir args]
  set netlist [rdi::scan_for_option -netlist args]
  set search_path [rdi::scan_for_file_option -search_path args]

  if {$force} {
    lappend new_args -force
  }
  lappend new_args $name
  lappend new_args $dir

  rdi::record {create_project $new_args}
  set project [create_project {*}$new_args]

  if {$rtl == 0} {
    if {[rdi::has_option -netlist args]} {
      rdi::record {set_property design_mode GateLvl [current_fileset]}
      set_property design_mode GateLvl [current_fileset]
    } else {
      rdi::record {set_property design_mode PinPlanning [current_fileset]}
      set_property design_mode PinPlanning [current_fileset]
    }
  }

  if {[rdi::has_option -netlist args]} {
    rdi::record {set_property edif_top_file $netlist [current_fileset]}
    set_property edif_top_file $netlist [current_fileset]
  }

  if {[rdi::has_option -search_path args]} {
    rdi::record {set_property EDIF_EXTRA_SEARCH_PATHS $search_path [current_fileset]}
    set_property EDIF_EXTRA_SEARCH_PATHS $search_path [current_fileset]
#    rdi::record {add_files $search_path}
#    add_files $search_path
  }

  return $project
}

proc rdi::project_open {args} {
  rdi::parse_options {-file -quick -read_only} args options
  rdi::ensure_required_options options {-file}
  rdi::get_option options -file file
  if {[rdi::get_bool_option options -read_only 0]} {
    lappend new_args -read_only
  }
  if {![rdi::is_blank $file]} {
    lappend new_args $file
  }
  rdi::record {open_project $new_args}
  open_project {*}$new_args
}

proc rdi::project_close {args} {
  rdi::parse_options {-name -delete} args options
  rdi::ensure_required_options options {-name}
  rdi::get_option options -name name

  if {![rdi::is_blank $name]} {
    current_project $name
  }

  if {[rdi::get_bool_option options -delete 0]==1} {
    lappend new_args -delete
  } else {
    set new_args [list]
  }

  rdi::record {close_project $new_args}
  close_project {*}$new_args
}

proc rdi::project_saveAs {args} {
  rdi::parse_options {-name -newName -dir} args options
  rdi::ensure_required_options options {-name -newName -dir}
  rdi::get_option options -name name
  rdi::get_option options -newName newName
  rdi::get_option options -dir dir

  rdi::open_design_if_needed

  if {![rdi::is_blank $name]} {
    current_project $name
  }

  if {![rdi::is_blank $newName]} {
    lappend new_args -name $newName
  }

  if {![rdi::is_blank $dir]} {
    lappend new_args -dir $dir
  }
  rdi::record {save_project_as $new_args}
  save_project_as {*}$new_args
}

proc rdi::project_setPart {args} {
  parse_options {-name -part} args options
  ensure_required_options options {-part}
  rdi::get_option options -part part
  set_property part $part [current_project]  
  set run [get_runs -quiet synth_1]
  if {![rdi::is_blank $run]} {
    rdi::record {set_property part $part [get_runs synth_1]}
    set_property part $part $run
  }
  set run [get_runs -quiet impl_1]
  if {![rdi::is_blank $run]} {
    rdi::record {set_property part $part [get_runs impl_1]}
    set_property part $part $run
  }
  set fileset [get_filesets -quiet constrs_1]
  if {![rdi::is_blank $fileset]} {
    rdi::record {set_property target_part $part [get_filesets constrs_1]}
    set_property target_part $part $fileset
  }
}

proc rdi::project_setArch {args} {
  parse_options {-name -arch} args options
  ensure_required_options options {-arch}
  rdi::get_option options -arch arch
  set parts [get_parts -filter "architecture==$arch"]
  set part ""
  if {[llength $parts] > 0} {
    rdi::project_setPart -part [lindex $parts 0]
  }
}

proc hdi::project {subcmd args} {
  if {[rdi::is_help hdi::project $subcmd args]} { return }
  if {[string compare -nocase -l 1 $subcmd new]==0} {
    return [uplevel 1 rdi::project_create $args]
  }
  if {[string compare -nocase -l 1 $subcmd open]==0} {
    return [uplevel 1 rdi::project_open $args]
  }
  if {[string compare -nocase -l 2 $subcmd close]==0} {
    return [uplevel 1 rdi::project_close $args]
  }
  if {[string compare -nocase -l 2 $subcmd saveAs]==0} {
    return [uplevel 1 rdi::project_saveAs $args]
  }
  if {[string compare -nocase -l 4 $subcmd setPart]==0} {
    return [uplevel 1 rdi::project_setPart $args]
  }
  if {[string compare -nocase -l 4 $subcmd setArch]==0} {
    return [uplevel 1 rdi::project_setArch $args]
  }
  if {[string compare -nocase -l 2 $subcmd startUpdate]==0} {
    error "ERROR: hdi::project startUpdate is no longer supported"
  }
  if {[string compare -nocase -l 2 $subcmd cancelUpdate]==0} {
    error "ERROR: hdi::project cancelUpdate is no longer supported"
  }
  if {[string compare -nocase -l 2 $subcmd commitUpdate]==0} {
    error "ERROR: hdi::project commitUpdate is no longer supported"
  }
  return -code error "invalid command name 'hdi::project $subcmd'"
}

#--------------------------------------------
#deprecation layer for hdi::design commands
#--------------------------------------------
proc hdi::design {subcmd args} {
  if {[rdi::is_help hdi::design $subcmd args]} { return }
  if {[string compare -nocase -l 4 $subcmd addSources]==0} {
    return [uplevel 1 rdi::design_addSources $args]
  }
  if {[string compare -nocase -l 1 $subcmd disable]==0} {
    return [uplevel 1 rdi::design_enable false $args]
  }
  if {[string compare -nocase -l 2 $subcmd enable]==0} {
    return [uplevel 1 rdi::design_enable true $args]
  }
  if {[string compare -nocase -l 2 $subcmd elaborate]==0} {
    return [uplevel 1 rdi::design_elaborate $args]
  }
  if {[string compare -nocase -l 4 $subcmd setLibrary]==0} {
    return [uplevel 1 rdi::design_setLibrary $args]
  }
  if {[string compare -nocase -l 1 $subcmd importSources]==0} {
    return [uplevel 1 rdi::design_importSources $args]
  }
  if {[string compare -nocase -l 7 $subcmd removeSources]==0} {
    return [uplevel 1 rdi::design_removeSources $args]
  }
  if {[string compare -nocase -l 4 $subcmd addExclusion]==0} {
    error "ERROR: hdi::design addExclusion is no longer supported"
  }
  if {[string compare -nocase -l 7 $subcmd removeExclusions]==0} {
    error "ERROR: hdi::design removeExclusions is no longer supported"
  }
  if {[string compare -nocase -l 4 $subcmd setOptions]==0} {
    return [uplevel 1 rdi::design_setOptions $args]
  }
  return -code error "invalid command name 'hdi::design $subcmd'"
}

proc rdi::design_addSources {args} {
  set library [rdi::scan_for_option -library args]
  set srcset [rdi::scan_for_option -srcset args]
  set sources [rdi::scan_for_file_option -sources args]

  if {[rdi::has_option -srcset args]} {
    rdi::record {add_files -fileset $srcset $sources}
    set files [add_files -fileset $srcset $sources]
  } else {
    rdi::record {add_files $sources}
    set files [add_files $sources]
  }
  if {[llength $files] > 0 && [rdi::has_option -library args]} {
    rdi::record {set_property library $library [get_files $files]}
    set_property library $library $files
  }
}

proc rdi::design_removeSources {args} {
  set srcset [rdi::scan_for_option -srcset args]
  set sources [rdi::scan_for_file_option -sources args]
  if {[rdi::has_option -srcset args]} {
    rdi::record {remove_files -fileset $srcset $sources}
    set files [remove_files -fileset $srcset $sources]
  } else {
    rdi::record {remove_files $sources}
    set files [remove_files $sources]
  }
}

proc rdi::design_importSources {args} {
  set srcset [rdi::scan_for_option -srcset args]
  set sources [rdi::scan_for_file_option -sources args]
  set overwrite [rdi::scan_for_bool_option -overwrite 0 args]
  set new_args ""
  if {$overwrite} {
    lappend new_args -force
  }
  if {[rdi::has_option -srcset args]} {
    lappend new_args -fileset $srcset
  }
  if {![rdi::is_blank $new_args]} {
    rdi::record {import_files $new_args $sources}
    import_files {*}$new_args $sources
  } else {
    rdi::record {import_files $sources}
    import_files $sources
  }
}

proc rdi::design_setLibrary {args} {
  set library [rdi::scan_for_option -libName args]
  set files [rdi::scan_for_file_option -files args]
  rdi::record {set_property library $library [get_files -of_objects [current_fileset] $files]}
  set_property library $library [get_files -of_objects [current_fileset] -quiet $files]
}

proc rdi::design_elaborate {args} {
  # Force verific elaboration in old hdi::-based scripts
  set old [get_param synth.elab.tool]
  set_param synth.elab.tool verific
  rdi::record {open_rtl_design}
  open_rtl_design
  rdi::record {report_resources}
  report_resources
  set_param synth.elab.tool $old
}

proc rdi::design_enable {enable args} {
  set files [rdi::scan_for_file_option -sourceFiles args]
  rdi::record {set_property is_enabled $enable [get_files -of_objects [current_fileset] $files]}
  set_property is_enabled $enable [get_files -of_objects [current_fileset] -quiet $files]
}

proc rdi::design_setOptions {args} {
  set generic [rdi::scan_for_multi_list_option -generic args]
  set define [rdi::scan_for_multi_list_option -define args]
  set top [rdi::scan_for_option -top args]
  set has_top [rdi::has_option -top args]
  # Remove -top so we can read -toplib if it is there. 
  rdi::remove_options -top args
  set toplib [rdi::scan_for_option -toplib args]
  set verilogDir [rdi::scan_for_option -verilogDir args]
  set libMapFile [rdi::scan_for_option -libMapFile args]
  set loopCount [rdi::scan_for_option -loopCount args]
  if {[rdi::is_blank $loopCount]} { set loopCount 1000 }
  set verilogUpperCase [rdi::scan_for_bool_option -verilogUpperCase 0 args]
  set verilog2001 [rdi::scan_for_bool_option -verilog2001 1 args]

  set srcset [current_fileset]

  if {$has_top} {
    rdi::record {set_property top $top [current_fileset]}
    set_property top $top $srcset
  }

  if {[rdi::has_option -toplib args]} {
    rdi::record {set_property top_lib $toplib [current_fileset]}
    set_property top_lib $toplib $srcset
  }

  if {[rdi::has_option -verilogDir args]} {
    rdi::record {set_property verilog_dir $verilogDir [current_fileset]}
    set_property verilog_dir $verilogDir $srcset
  }

  if {[rdi::has_option -define args]} {
    foreach val $define {
      set s [lindex $val 0]
      if {[llength $val] == 2} {
        append s "=[lindex $val 1]"
      }
      lappend defines $s
    }
    rdi::record {set_property verilog_define $defines [current_fileset]}
    set_property verilog_define $defines $srcset
  }

  set val [get_property verilog_uppercase [current_fileset]]
  if {$val != $verilogUpperCase} {
    rdi::record {set_property verilog_uppercase $verilogUpperCase [current_fileset]}
    set_property verilog_uppercase $verilogUpperCase $srcset
  }

  set val [get_property verilog_version [current_fileset]]
  if {$verilog2001 && ![string equal $val verilog_2001]} {
    rdi::record {set_property verilog_version verilog_2001 [current_fileset]}
    set_property verilog_version verilog_2001 $srcset
  } elseif {$verilog2001 == 0 && [string equal $val verilog_2001]} {
    rdi::record {set_property verilog_version verilog_95 [current_fileset]}
    set_property verilog_version verilog_95 $srcset
  }

  if {[rdi::has_option -generic args]} {
    foreach val $generic {
      set s [lindex $val 0]
      if {[llength $val] == 2} {
        append s "=[lindex $val 1]"
      }
      lappend generics $s
    }
    rdi::record {set_property generic $generics [current_fileset]}
    set_property generic $generics $srcset
  }

  if {[rdi::has_option -libMapFile args]} {
    rdi::record {set_property lib_map_file $libMapFile [current_fileset]}
    set_property lib_map_file $libMapFile $srcset
  }

  set val [get_property loop_count [current_fileset]]
  if {$val != $loopCount} {
    rdi::record {set_property loop_count $loopCount [current_fileset]}
    set_property loop_count $loopCount $srcset
  }
}


#--------------------------------------------
#deprecation layer for hdi::timing commands
#--------------------------------------------
proc hdi::timing {subcmd args} {
  if {[rdi::is_help hdi::timing $subcmd args]} { return }
  if {[string compare -nocase -l 1 $subcmd run]==0} {
    rdi::open_corrected_floorplan_if_needed args
  }

  rdi::open_floorplan_if_needed args
  rdi::remove_options {-project -floorplan} args
  if {[string compare -nocase -l 1 $subcmd run]==0} {
    rdi::record {report_ucf_timing $args}
    report_ucf_timing {*}$args
  } elseif {[string compare -nocase -l 2 $subcmd import]==0} {
    rdi::rename_option -instance -cell args
    rdi::record {read_twx $args}
    read_twx {*}$args
  } elseif {[string compare -nocase -l 2 $subcmd clear]==0} {
    rdi::record {delete_timing_results $args}
    delete_timing_results {*}$args
  } elseif {[string compare -nocase -l 1 $subcmd export]==0} {
    rdi::record {write_timing $args}
    write_timing {*}$args
  } elseif {[string compare -nocase -l 1 $subcmd sta]==0} {
    rdi::record {::debug::set_debug_sta}
    ::debug::set_debug_sta
  } elseif {[string compare -nocase -l 2 $subcmd info]==0} {
    rdi::record {::debug::report_timing_info $args}
    ::debug::report_timing_info {*}$args
  } else {
    error "ERROR: invalid command name 'hdi::timing $subcmd'"
  }
}

#--------------------------------------------
#deprecation layer for hdi::netlist commands
#--------------------------------------------
proc hdi::netlist {subcmd args} {
  if {[rdi::is_help hdi::netlist $subcmd args]} { return }
  if {[string compare -nocase -l 2 $subcmd new]==0} {
    return [uplevel 1 rdi::netlist_new $args]
  }
  if {[string compare -nocase -l 2 $subcmd delete]==0} {
    # netlist delete shouldn't actually delete the project...
    rdi::record {close_project}
    return [close_project]
  }
  if {[string compare -nocase -l 2 $subcmd export]==0} {
    rdi::parse_options {-rtl -file} args options
    rdi::ensure_required_options options -file
    rdi::get_option options -file file
    if {![rdi::get_bool_option options -rtl 0]} {
      set design [current_design -quiet]
      if {[rdi::is_blank $design]} {
        rdi::record {open_netlist_design -edif_part}
        open_netlist_design -edif_part
      }
    }
    rdi::record {write_edif $file}
    return [write_edif $file]
  }
}

#------------------
#hdi::netlist new
#------------------
proc rdi::netlist_new {args} {
  set name [rdi::scan_for_option -name args]
  set file [rdi::scan_for_option -file args]
  set dirs [rdi::scan_for_file_option -dirs args]

  rdi::record {create_project -force $name -dir .}
  set project [create_project -force $name -dir .]
  rdi::record {set_property design_mode GateLvl [current_fileset]}
  set_property design_mode GateLvl [current_fileset]

  if {[rdi::has_option -dirs args]} {
    rdi::record {set_property EDIF_EXTRA_SEARCH_PATHS $dirs [current_fileset]}
    set_property EDIF_EXTRA_SEARCH_PATHS $dirs [current_fileset]
#    old way, Richard, Jun'11.
#    rdi::record {add_files $dirs}
#    add_files $dirs
  }

  if {[rdi::has_option -file args]} {
    rdi::record {set_property edif_top_file $file [current_fileset]}
    set_property edif_top_file $file [current_fileset]
  }
}

#--------------------------------------------
#deprecation layer for hdi::place commands
#--------------------------------------------
proc hdi::place {subcmd args} {
  if {[rdi::is_help hdi::place $subcmd args]} {return}
  rdi::open_floorplan_if_needed args
  if {[string compare -nocase -l 2 $subcmd run]==0} {
    set timing_driven [rdi::scan_for_bool_option -timing_driven 0 args]
    set fast [rdi::scan_for_bool_option -fast 0 args]
    set new_args ""
    if {$timing_driven == 0} {
      lappend new_args -no_timing_driven
    }
    if {$fast} {
      lappend new_args -fast
    }
    rdi::record {place_design $new_args}
    place_design {*}$new_args
  } else {
    return -code error "invalid command name 'hdi::place $subcmd'"
  }
}

#--------------------------------------------
#deprecation layer for hdi::bplace commands
#--------------------------------------------
proc hdi::bplace {subcmd args} {
  if {[rdi::is_help hdi::bplace $subcmd args]} { return }
  if {[string compare -nocase -l 2 $subcmd clearPblocks]==0} {
    error "ERROR: hdi::pblock clearPblocks is no longer supported. Please use place_pblocks instead."
  } elseif {[string compare -nocase -l 2 $subcmd addPblock]==0} {
    error "ERROR: hdi::pblock addPblock is no longer supported. Please use place_pblocks instead."
  } elseif {[string compare -nocase -l 2 $subcmd run]==0} {
    error "ERROR: hdi::pblock run is no longer supported. Please use place_pblocks instead."
  }
  error "ERROR: Unrecognized command 'hdi::pblock $subcmd'"
}

#--------------------------------------------
#deprecation layer for hdi::report commands
#--------------------------------------------
proc hdi::report {subcmd args} {
  if {[rdi::is_help hdi::report $subcmd args]} { return }
  set match [rdi::match { stats new_stats } $subcmd]
  switch $match {
    stats {
      rdi::open_floorplan_if_needed args
      set rtl [rdi::scan_for_bool_option -rtl 0 args]
      set format [rdi::scan_for_option -format args]
      set instance [rdi::scan_for_option -instance args]
      set pblock [rdi::scan_for_option -pblock args]
      set clockRegion [rdi::scan_for_option -clockRegion args]
      set fileName [rdi::scan_for_option -fileName args]
      set tables [rdi::scan_for_option -tables args]
      set level [rdi::scan_for_option -level args]

      if {![rdi::has_option -rtl args]} {
        foreach table $tables {
          if {[string match rtl* $table]} {
            set rtl 1
            break
          }
        }
      }
      if {$rtl} {
        set design [current_design -quiet]
        if {[rdi::is_blank $design]} {
          rdi::record {open_rtl_design}
          open_rtl_design
        }
      } else {
        rdi::open_design_if_needed
      }

      if {[string equal -nocase $format xls]} {
        puts "WARN: xls output is no longer supported. The output format will be changed to csv."
        set format csv
      }

      if {[rdi::has_option -instance args]} { lappend new_args -cell $instance }
      if {[rdi::has_option -clockRegion args]} { lappend new_args -clock_region $clockRegion }
      if {[rdi::has_option -pblock args]} { lappend new_args -pblock $pblock }
      if {[rdi::has_option -tables args]} { lappend new_args -tables $tables }
      if {[rdi::has_option -format args]} { lappend new_args -format $format }
      if {[rdi::has_option -level args]} { lappend new_args -level $level }

      lappend new_args -file $fileName

      rdi::record {report_stats $new_args}
      report_stats {*}$new_args
    }
    default {
      error "ERROR: invalid command name 'hdi::report $subcmd'"
    }
  }
}

#--------------------------------------------
#deprecation layer for hdi::ssn commands
#--------------------------------------------
proc hdi::ssn {subcmd args} {
  if {[rdi::is_help hdi::ssn $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  rdi::remove_options {-project -floorplan} args
  if {[string compare -nocase -l 1 $subcmd run]==0} {
    rdi::rename_option -fileName -file args
    rdi::record {report_ssn $args}
    report_ssn {*}$args
  } elseif {[string compare -nocase -l 1 $subcmd clear]==0} {
    rdi::record {reset_ssn $args}
    reset_ssn {*}$args
  } else {
    error "invalid command name 'hdi::ssn $subcmd'"
  }
}

#--------------------------------------------
#deprecation layer for hdi::sso commands
#--------------------------------------------
proc hdi::sso {subcmd args} {
  if {[rdi::is_help hdi::sso $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  if {[string compare -nocase -l 1 $subcmd run]==0} {
    rdi::remove_options {-project -floorplan} args
    rdi::rename_option -fileName -file args
    rdi::record {report_sso $args}
    report_sso {*}$args
  } elseif {[string compare -nocase -l 1 $subcmd clear]==0} {
    rdi::remove_options {-project -floorplan} args
    rdi::record {reset_sso $args}
    reset_sso {*}$args
  } else {
    error "invalid command name 'hdi::sso $subcmd'"
  }
}


#--------------------------------------------
#deprecation layer for hdi::site commands
#--------------------------------------------
proc hdi::site {subcmd args} {
  if {[rdi::is_help hdi::site $subcmd args]} { return }
  rdi::open_floorplan_if_needed args
  set match [rdi::match { makeCompatible removeCompatibility set } $subcmd]
  switch $match {
    makeCompatible {
      set device [rdi::scan_for_option -device args]
      set parts [lappend [get_property keep_compatible [current_design]] $device]
      rdi::record {set_property keep_compatible $parts [current_design]}
      set_property keep_compatible $parts [current_design]
    }
    removeCompatibility {
      set device [rdi::scan_for_option -device args]
      set parts [get_property keep_compatible [current_design]]
      set found 0
      set idx 0
      set num_parts [llength $parts]
      while { $idx < $num_parts } {
        set part [lindex $parts $idx]
        if {[string match -nocase $part* $device]} {
          set found 1
          set parts [lreplace $parts $idx $idx]
          break
        }
        incr idx
      }
      if {$found == 0} {
        error "The current floorplan was not previously made compatible with the specified part"
      }
      if {[llength $parts] == 0} {
        rdi::record {set_property keep_compatible "" [current_design]}
      } else {
        rdi::record {set_property keep_compatible $parts [current_design]}
      }
      set_property keep_compatible $parts [current_design]
    }
    set {
      rdi::remove_options {-project -floorplan} args
      set prohibit [rdi::scan_for_option -prohibit args]
      if {![rdi::is_blank $prohibit]} {
        set names [rdi::scan_for_option -names args]
        rdi::record {set_property prohibit $prohibit [get_sites $names]}
        set_property prohibit $prohibit [get_sites $names]
      } else {
        rdi::rename_option -names -package_pins args
        rdi::record {set_package_pin_val $args}
        set_package_pin_val {*}$args
      }
    }
    default {
      return -code error "invalid command name 'hdi::site $subcmd'"
    }
  }
}

#--------------------------------------------
#deprecation layer for hdi::rpm commands
#--------------------------------------------
proc hdi::rpm {subcmd args} {
  if {[rdi::is_help hdi::rpm $subcmd args]} {return}
  set name [rdi::scan_for_option -name args]
  if {[string compare -nocase -l 2 $subcmd delete]==0} {
    rdi::record {delete_rpm $name}
    delete_rpm $name
  } else {
    return -code error "invalid command name 'hdi::rpm $subcmd'"
  }
}

#--------------------------------------------
#deprecation layer for hdi::?
#--------------------------------------------
proc hdi::? {args} {
  rdi::record "ERROR: \'hdi::?\' is deprecated, please use \'help\' for new commands."
}

#--------------------------------------------
#deprecation layer to convert to the new RM command.
#--------------------------------------------
proc add_reconfig_module {args} {
  if {"?" in $args || "-help" in $args} {
      rdi::record "ERROR: \'add_reconfig_module\' is deprecated, please use \'create_reconfig_module\' instead."
      return 1;
  }

  # Old command:
  # add_reconfig_module -name <rm_name> -cell <cell> -file <filename>|-blackbox [-search_path <dir_list>] [-force]

  set create_args ""

  rdi::parse_options {-name -cell -file -search_path -blackbox -force -ucf} args options
  rdi::ensure_required_options options {-name -cell}
  rdi::get_option options -name           name
  rdi::get_option options -cell           cell
  rdi::get_option options -file           file
  rdi::get_option options -search_path    search_path
  rdi::get_option options -blackbox       blackbox
  rdi::get_option options -force          force

  if {[rdi::get_bool_option options -blackbox 0]} {
    if { ![rdi::is_blank $file] } {
      error "ERROR:  Cannot specify 'file' with 'blackbox'."
    }  
    if { ![rdi::is_blank $search_path] } {
      error "ERROR:  Cannot specify 'file' with 'search_path."
    }  
    lappend create_args -blackbox 
  }
  if {[rdi::get_bool_option options -force 0]} {
    lappend create_args -force
  }
  if { [rdi::is_blank $cell] } {
    error "ERROR:  The value of 'cell' is empty."
  }
  lappend create_args -name $name -cell $cell

  # Create the RM
  rdi::record {create_reconfig_module $create_args}
  create_reconfig_module {*}$create_args

  # Save the design
  set needs_save [get_property needs_save [current_design]]
  if { $needs_save } {
    rdi::record {save_design}
    save_design
  }

  # Get the instance name from the cell, by removing any backslashes.
  regsub -all {[\\]+} $cell {} instName

  # Make the fileset name by replacing '/' with '~', etc.
  regsub -all {/} $instName {~} temp
  regsub -all {:} $temp {=} partName

  set fileset $partName#$name

  if { ![rdi::is_blank $file] } {
    rdi::record {add_files -fileset $fileset $file }
    add_files -fileset $fileset $file
    rdi::record {import_files -fileset $fileset $file}
    import_files -fileset $fileset $file
  }

  # Deal with the search path as a property on the fileset.
  if {![rdi::is_blank $search_path]} {
    rdi::record {set_property edif_extra_search_paths {$search_path} [get_filesets $fileset]}
    set_property edif_extra_search_paths \{$search_path\} [get_filesets $fileset]
  }

  set rmname $instName:$name
  rdi::record {load_reconfig_modules -reconfig_modules $rmname}
  load_reconfig_modules -reconfig_modules $rmname
}

proc update_reconfig_module {args} {
  error "The command 'update_reconfig_module' is obsolete.  Use add_files/import_files and refresh_design to update the source files for a Reconfigurable Module."
}



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
