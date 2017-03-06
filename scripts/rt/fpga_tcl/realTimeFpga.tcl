# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************

# rt::UMsg_print "Loading realTime.tcl:"
source $env(RT_TCL_PATH)/realTime.tcl

# rt::UMsg_print "Loading FPGA commands"
source $env(HRT_TCL_PATH)/commands.tcl

if { [info exists rt::impera_flow] && $rt::impera_flow == 1 } {
  source $env(HRT_TCL_PATH)/impera_commands.tcl
}

# Finished loading stuff
# rt::UMsg_print "\n"

# and if we're running planAhead, hide rt::db till we need it
if { ! [info exists ::env(XILINX_REALTIMEFPGA)] } {

  namespace eval rt {
    namespace eval donotuse {
      variable saved_db "rt-undefined"
    }
  }

  proc rt::_x_restore { } {

    if { [namespace current] == "::rt" } {
      if { $rt::donotuse::saved_db != "rt-undefined" && $rt::db == "rt-undefined" } {

        set rt::db $rt::donotuse::saved_db
        set rt::donotuse::saved_db "rt-undefined"
        rename donotuse::UStatCpu_printStats UStatCpu_printStats
        rename donotuse::UMsgHandler_printSummary UMsgHandler_printSummary
        rename donotuse::_x_save _x_save

        # restore other 'address named' tcl procs

      }
    }
  }

  proc rt::_x_save { } {
    if { [namespace current] == "::rt" } {
      if { $rt::donotuse::saved_db == "rt-undefined" && $rt::db != "rt-undefined" } {

        # swig exports a tcl variable named with the value of $db, rename that too...
        set rt::donotuse::saved_db $rt::db
        set rt::db "rt-undefined"
        rename UStatCpu_printStats donotuse::UStatCpu_printStats
        rename UMsgHandler_printSummary donotuse::UMsgHandler_printSummary
        rename _x_restore donotuse::_x_restore

        # clean up other 'address named' tcl procs

      }
    }
  }

  source $::env(HRT_TCL_PATH)/rtSynthCleanup.tcl

}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
