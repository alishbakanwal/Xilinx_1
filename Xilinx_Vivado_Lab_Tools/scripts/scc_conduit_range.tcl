##########################################################################
# COPYRIGHT NOTICE
# Copyright 1986-1999, 2001-2011 Xilinx, Inc. All Rights Reserved.
#
# This script will add the SCC_CONDUIT_RANGE attributes with the SLICE ranges 
# from the selected Pblock onto the selected nets.
#
# For support issues contact the PR/SCC developers.
#
# Usage:
#    From within a planAhead session, with a SCC partition project open, and 
# the netlist design loaded, run:
#
#   % source $rdi::approot/scripts/scc_conduit_range.tcl
#
# from the Tcl console.  This sources the script, making the command available.
# The user then selects the appropriate objects in the GUI and types
#
#   % scc::create_conduit
#
# This operates on the selected objects.  If no objects are selected, a 
# usage message is displayed.
#
##########################################################################

namespace eval scc {
  proc create_conduit {} {
  
    # get the objects selected in the GUI
    set sel [get_selected_objects -primary]
  
    # Call the internal function to do the work.
    create_conduit_int $sel
    return 0
  }
  
  proc create_conduit_int {objects} {
  
    # process the selected objects looking for nets and a pblock
    set nets ""
    set pblocks ""
    foreach obj $objects {
      set type [get_property CLASS $obj]
      if { $type == "net" } {
        lappend nets $obj 
      } elseif { $type == "pblock" } {
        lappend pblocks $obj 
      } else {
        puts "ERROR: illegal selection.  Please select 1 or more nets and exactly 1 Pblock."
        return 1
      }
    }
    
    if { [ llength $nets ] == 0 } {
      puts "ERROR: Did not find any selected nets.  Please select the nets to which the Pblock range will be added."
      return 1
    }
    
    if { [ llength $pblocks ] == 0 } {
      puts "ERROR: Did not find a selected Pblock.  Please select the Pblock whose range will be added to the selected nets."
      return 1
    }
    if { [ llength $pblocks ] > 1 } {
      puts "ERROR: Found multiple selected Pblocks.  Please select only one Pblock whose range will be added to the selected nets."
      return 1
    }
    
    set pblock [lindex $pblocks 0]
    
    # extract the pblock SLICE range
    set pb_grids [get_property GRID_RANGES $pblock]
    puts "Pblock $pblock grid ranges: $pb_grids"
    set slice_range ""
    foreach grid $pb_grids {
      if { [regexp {SLICE} $grid] } {
        if { [string length $slice_range] != 0 } {
          append slice_range " "
        }
        append slice_range $grid
      }
    }
    
    if { [string length $slice_range] == 0 } {
      puts "ERROR: no SLICE range found on Pblock $pblock with ranges '$pb_grids'.  Please add a SLICE range to the selected Pblock."
      return 1;
    }
    
    # add the SLICE range to each selected net
    foreach net $nets {
      puts " Adding range '$slice_range' to net $net..."
      set_property SCC_CONDUIT_RANGE $slice_range $net
    }
    
    # all done!
    puts "Successful completion"
  
    return 0
  }
  
  proc usage {} {
    puts "Usage:  This script will add the SCC_CONDUIT_RANGE attribute to all selected nets using the value of the SLICE range on the selected Pblock.  To use this feature"
    puts "  1. Select the Pblock from which the range will be extracted."
    puts "  2. Select the nets to which the property will be added."
    puts "  3. Type the Tcl command 'scc::create_conduit' at the Tcl command prompt."
  }
}

# When the user sources this script just generate a usage message and exit.
scc::usage

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
