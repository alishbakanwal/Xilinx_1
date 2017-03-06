# Labtools.tcl feature script
#
# Loaded during startup

#puts "DEBUG: ======= BEGIN VIVADO_LAB.TCL LOADER SCRIPT ==========="
namespace import common::*
load_features writecfgmem

set CMDHASH [dict create]

proc unregister {cmd} {
#  puts "DEBUG: unregister_task: $cmd"
  rdi::unregister_task $cmd
}


### BASE LIBRARY ###
# These are the base tcl commands for vivado we must have
#
load_features base
# Record a baseline set of good commands we will keep. 
# After loading the "core" library we will remove commands not in the
# "keeper" list but leave the baseline set intact.
foreach cmd [info commands] {
  dict set CMDHASH $cmd 1
}


### LABTOOLS LIBRARY
# This is the set of labtools (hw) commands. Loading this will also include
# common waveform support
#
load_features labtools

set_param labtools.standaloneMode true

rdi::load_library salt {librdi_standalonetasks}

rdi::load_library updatemem {librdi_updatememtasks}

# name of java entry and library
namespace eval rdi {
  set javajar planAhead.jar
  set javamainclass ui/PlanAhead
  set javamainmethod jswMain

  # Hide features
  hide_features core
  hide_features ipintegrator
  hide_features ipservices
  hide_features planahead
  hide_features updatemem
  hide_features vivado
}


namespace eval hw {
  # export all for now, we can be more selective if we chose
  # however, this will auto export all new commands for us
  namespace export *;
}

namespace import -force ::hw::*;


# tcl prompts
# NOTE: This does not stick - there must be another
# thing that is resetting the prompt...
#
set tcl_prompt1 {puts -nonewline {vivado_lab% }}
# start editline
rdi::start_editline vivado_lab

#puts "DEBUG: ======= END VIVADO_LAB.TCL LOADER SCRIPT ==========="


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
