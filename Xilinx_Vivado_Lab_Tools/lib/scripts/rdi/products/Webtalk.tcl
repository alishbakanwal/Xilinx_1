# Webtalk.tcl feature script
#
# Loaded during startup

# Provide Webtalk 2012.3 so that Tcl scripts can check
# This must come first so that features can check.
package provide Webtalk 1.2015.1

namespace import common::*

#load_features base core

# name of java entry and library
namespace eval rdi {
#  set javajar planAhead.jar
#  set javamainclass ui/PlanAhead
#  set javamainmethod jswMain

  # List 'core' tasks to filter out from Webtalk.  Until
  # core tasks are in proper task libraries, the ones to filter out 
  # must be explicitly listed here.
  variable webtalk_filter_tasks
  lappend webtalk_filter_tasks \
  ::common::start_gui \
  ::common::stop_gui \
  ::common::endgroup \
  ::common::startgroup \
  ::common::undo \
  ::common::redo \
  ::common::load_features \
  ::common::list_features

  ################################################################
  # Hide tasks from webtalk
  ################################################################
  proc webtalk_filter {} {
    foreach task $rdi::webtalk_filter_tasks {
      if {[info commands $task] != ""} {
        rdi::unregister_task $task
      } else {
        puts "can't unregister unknown command '$task'"
      }
    }
  }

  # Hide features
  hide_features planahead
}

#[catch {::tclapp::create_tclstore}]
#
## set auto_path to Tcl App User Repo
#if {[file exist [set tclstore [file join [rdi::get_app_data_release] XilinxTclStore]]]} {
#    lappend auto_path $tclstore
#} else {
#    # Webtalk static repo
#    lappend auto_path [file join [rdi::get_data_dir -datafile XilinxTclStore] XilinxTclStore]
#}

#[catch {::tclapp::register_persist_apps}]
#[catch {::tclapp::load_app xilinx::projutils}]

# tcl prompt
set tcl_prompt1 {puts -nonewline {Webtalk% }}
# start editline
rdi::start_editline Webtalk

# start placer performance monitor
#debug::placer_monitor -start

rdi::webtalk_filter


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
