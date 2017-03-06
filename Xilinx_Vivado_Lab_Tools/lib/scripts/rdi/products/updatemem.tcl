# updatemem.tcl product boot strapping script
#
# Loaded during startup
namespace import common::*
load_feature base updatemem

namespace eval rdi {

  # List of tasks to filter out from updatemem
  variable updatemem_filter_tasks
  lappend updatemem_filter_tasks \
  ::common::start_gui \
  ::common::stop_gui

  ################################################################
  # Hide tasks from vivado
  ################################################################
  proc updatemem_filter {} {
    foreach task $rdi::updatemem_filter_tasks {
      if {[info commands $task] != ""} {
        rdi::unregister_task $task
      } else {
        puts "can't unregister unknown command '$task'"
      }
    }
  }
  
  updatemem_filter

}
# tcl prompt
set tcl_prompt1 {puts -nonewline {Updatemem% }}
# start editline
rdi::start_editline Updatemem

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
