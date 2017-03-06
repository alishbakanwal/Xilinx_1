
##
# Disconnect connections of cell1 and connect to cell2.
#
# Conditions:
#  - cell2 must have the same interface pins and regular pins as that of cell1
#    which are connected.
#  - cell1 and cell2 must be at the same hierarchy 
#
# Notes:
#  - If cell2's interface pins and regular pins that are replacing cell1's 
#    are also already connected, then those will be disconnected as well.
#
# @param cell1  Cell to be replaced/disconnected
# @param cell2  Cell to be connected 
#
# @return 0 if success, else non-zero

proc _replace_bd_cell { args } {

   set numArgs [llength $args]
   #puts "Num Args = $numArgs"
   #puts "Args = <$args>"

   # Check arguments for help
   if { [::bd::internal::replace_bd_cell_procs::is_help_flag $args] == 1 } {

      ::bd::internal::replace_bd_cell_procs::show_help
      return 0

   } elseif { $numArgs != 2 } {

      ::bd::internal::replace_bd_cell_procs::show_help

      puts ""
      puts "ERROR: Unknown argument(s): <$args>!"

      return 1

   }

   # CHECK IF DESIGN AVAILABLE
   set cur_design ""
   set cur_design [get_bd_designs]

   if { $cur_design eq "" } {
      puts "ERROR: Please open or create a design first."
      return 1
   }

   # GET CELL OBJECTS
   set cell1 [lindex $args 0]
   set cell2 [lindex $args 1]

   set cell1_obj [get_bd_cells $cell1]
   set cell2_obj [get_bd_cells $cell2]

   if { $cell1_obj eq "" } {
      puts "ERROR: Unable to find cell1 <$cell1>!"
      return 1
   } elseif { $cell2_obj eq "" } {
      puts "ERROR: Unable to find cell2 <$cell2>!"
      return 1
   } elseif { $cell1_obj == $cell2_obj } {
      puts "ERROR: Cannot call replace_bd_cells on the same object!"
      return 2
   }

   puts "INFO: Found cells <$cell1_obj> and <$cell2_obj>."
   puts ""

   # MAKE SURE IN SAME HIERARCHY!
   set path1 [get_property PATH $cell1_obj]
   set path2 [get_property PATH $cell2_obj]

   set str_basepath1 [::bd::internal::replace_bd_cell_procs::get_basepath $path1]
   set str_basepath2 [::bd::internal::replace_bd_cell_procs::get_basepath $path2]

   if { $str_basepath1 ne $str_basepath2 } {
      puts "ERROR: Please make sure the two cells are in the same hierarchy!"
      return 1
   }


   # MAKE SURE cell2 HAS SAME INTF PINS AND PINS THAT ARE CONNECTED ON cell1
   set list_connected [::bd::internal::replace_bd_cell_procs::get_connected_intfpins_regpins $cell1_obj]
   set list_same [::bd::internal::replace_bd_cell_procs::get_same_intfpins_regpins $cell2_obj $cell1_obj $list_connected]

   set len1 [llength $list_connected]
   set len2 [llength $list_same]

   if { $len1 == 0 } {

      puts "ERROR: <$cell1_obj> has no connections."
      return 1

   } elseif { $len1 != $len2 } {

      puts "ERROR: <$cell1_obj> and <$cell2_obj> do not have the same interface or regular pins."
      return 1

   }

   # START
   #startgroup
   set nRet1 [::bd::internal::replace_bd_cell_procs::replace_cell_intf_pins $cell1 $cell2]
   set nRet2 [::bd::internal::replace_bd_cell_procs::replace_cell_pins $cell1 $cell2]
   #endgroup

   set nRet [expr $nRet1 + $nRet2]
   return $nRet
}


##############################################################################
# HELPER PROCS
##############################################################################
# don't autocomplete bd namespace
rdi::hide_namespaces ::bd::internal::replace_bd_cell_procs

namespace eval ::bd::internal::replace_bd_cell_procs {

##############################################################################
# Replace the interface pins
##############################################################################
proc replace_cell_intf_pins { cell1 cell2 } {

   set cell1_obj [get_bd_cells $cell1]
   set cell2_obj [get_bd_cells $cell2]

   set list_intf_pins1 [get_bd_intf_pins -of_objects $cell1_obj]
   set list_intf_pins2 [get_bd_intf_pins -of_objects $cell2_obj]

   set list_intf_pins1_basename [create_list_basenames $list_intf_pins1]
   set list_intf_pins2_basename [create_list_basenames $list_intf_pins2]

   #puts "INFO: Interface pins of cell1 <$list_intf_pins1>."
   #puts "INFO:    <$list_intf_pins1_basename>."

   #puts "INFO: Interface pins of cell2 <$list_intf_pins2>."
   #puts "INFO:    <$list_intf_pins2_basename>."

   if { [has_item_in_lists $list_intf_pins1_basename $list_intf_pins2_basename] == 1 } {

      disconnect_intf_pins_and_reconnect $list_intf_pins1 $list_intf_pins2
   }

   return 0
}

##############################################################################
# Replace the regular pins
##############################################################################
proc replace_cell_pins { cell1 cell2 } {

   set cell1_obj [get_bd_cells $cell1]
   set cell2_obj [get_bd_cells $cell2]

   set list1 [get_bd_pins -of_objects $cell1_obj]
   set list2 [get_bd_pins -of_objects $cell2_obj]

   set list1_basename [create_list_basenames $list1]
   set list2_basename [create_list_basenames $list2]

   #puts "INFO: Pins of cell1 <$list1>."
   #puts "INFO:    <$list1_basename>."

   #puts "INFO: Pins of cell2 <$list2>."
   #puts "INFO:    <$list2_basename>."

   if { [has_item_in_lists $list1_basename $list2_basename] == 1 } {

      disconnect_pins_and_reconnect $list1 $list2
   }

   return 0
}


###############################################################################
# Using list of full names, create list of base name
###############################################################################
proc create_list_basenames { list_names } {

   set list_basenames ""
   foreach full_name $list_names {
      set basename [get_basename $full_name]
      lappend list_basenames $basename
   }

   return $list_basenames
}

###############################################################################
# Create a map between same pins in the two lists
###############################################################################
proc create_map_corresponding_pins { list_pins1 list_pins2 } {

   set map_pins ""

   foreach pin1 $list_pins1 {

      set basename1 [get_basename $pin1]

      foreach pin2 $list_pins2 {
         set basename2 [get_basename $pin2]

         if { $basename1 eq $basename2 } {

            # NOTE - dict append will convert pin2 to string!
            #dict append map_pins $pin1 $pin2
            dict set map_pins $pin1 $pin2

            break
         }
      }

   }

   return $map_pins
}

###############################################################################
# Disconnect pins in list1 and connect pins in list2
###############################################################################
proc disconnect_intf_pins_and_reconnect { list_intf_pins1 list_intf_pins2 } {

   set map_pins [create_map_corresponding_pins $list_intf_pins1 $list_intf_pins2]

   foreach pin1 $list_intf_pins1 {

      # DISCONNECT PIN1 FROM ITS CONNECTION
      set net ""
      set objs ""
      disconnect_intf_net_complete $pin1 net objs
      if { $net eq "" || $objs eq "" } {
         continue
      }

      # Check if pin1 is part of map
      if { [dict exists $map_pins $pin1] == 0 } {

         # SHOULD WE DELETE NET HERE!!!??

         continue
      }

      # Find corresponding pin in list2
      set pin2 [dict get $map_pins $pin1]
      if { $pin2 eq "" } {
         puts "ERROR: Expected a corresponding interface pin to <$pin1>, but did not find one in cell2!"
         continue
      }

      # DISCONNECT PIN2 FROM ITS CONNECTION TOO
      set net2 ""
      set objs2 ""
      disconnect_intf_net_complete $pin2 net2 objs2

      # Now reconnect net to pin2
      puts "INFO: Connecting interface pin <$pin2> to net <$net> and to <$objs>."
      set net_name [get_property NAME $net]
      connect_bd_intf_net -intf_net $net_name $pin2 $objs
   }

}

###############################################################################
# Disconnect pins in list1 and connect pins in list2
###############################################################################
proc disconnect_pins_and_reconnect { list1 list2 } {

   set map_pins [create_map_corresponding_pins $list1 $list2]

   foreach pin1 $list1 {

      # DISCONNECT PIN1 FROM ITS CONNECTIONS
      set net ""
      set objs ""
      disconnect_net_complete $pin1 net objs
      if { $net eq "" || $objs eq "" } {
         continue
      }


      # Check if pin1 is part of map
      if { [dict exists $map_pins $pin1] == 0 } {

         # SHOULD WE DELETE NET HERE!!!??

         continue
      }

      # Find corresponding pin in list2
      set pin2 [dict get $map_pins $pin1]
      if { $pin2 eq "" } {
         puts "ERROR: Expected a corresponding interface pin to <$pin1>, but did not find one in cell2!"
         continue
      }

      # DISCONNECT PIN2 ALSO
      set net2 ""
      set objs2 ""
      disconnect_net_complete $pin2 net2 objs2

      # Now reconnect net to pin2
      puts "INFO: Connecting pin <$pin2> to net <$net>."
      #report_property $pin2

      set net_name [get_property NAME $net]
      connect_bd_net -net $net_name $pin2
   }

}

###############################################################################
# Disconnect and delete net if needed
###############################################################################
proc disconnect_intf_net_complete { pin net objs } {

   upvar $net my_net
   upvar $objs my_objs

   set my_net ""
   set my_objs ""

   set my_net [get_bd_intf_nets -of_objects $pin]
   if { $my_net eq  "" } {
      return
   }

   # Disconnect pin from net
   puts "INFO: Disconnecting interface pin <$pin> from net <$my_net>."
   disconnect_bd_intf_net $my_net $pin

   # Get current connected end to net
   set objs1 [get_bd_intf_ports -of_objects $my_net]
   set objs2 [get_bd_intf_pins -of_objects $my_net]

   if { $objs1 ne "" } {
      set my_objs $objs1
   } elseif { $objs2 ne "" } {
      set my_objs $objs2
   } else {

      # No sink, so delete net
      delete_bd_objs $my_net 
   }

}

###############################################################################
# Disconnect and delete net if needed
###############################################################################
proc disconnect_net_complete { pin net objs } {

   upvar $net my_net
   upvar $objs my_objs

   set my_net ""
   set my_objs ""

   set my_net [get_bd_nets -of_objects $pin]
   if { $my_net eq  "" } {
      return
   }

   # Disconnect pin from net
   puts "INFO: Disconnecting pin <$pin> from net <$my_net>."
   disconnect_bd_net $my_net $pin

   # Get current connected end to net
   set objs1 [get_bd_ports -of_objects $my_net]
   set objs2 [get_bd_pins -of_objects $my_net]

   if { $objs1 eq "" && $objs2 eq "" } {

      # No sink, so delete net
      delete_bd_objs $my_net 
   }

   if { $objs1 ne "" } {
      lappend my_objs $objs1
   }
   if { $objs2 ne "" } {
      lappend my_objs $objs2
   }

}

###############################################################################
# Get base name of names in the design.
#
# 1) "/dds_1", returns "dds_1"
# 2) "/dds_1/dds_clk", returns "dds_clk"
# 3) "/mysub/dds_2/s_axis_a", returns "s_axis_a"
#
###############################################################################
proc get_basename { str_full_name } {
   set nIndex [string last "/" $str_full_name]

   if { $nIndex == -1 } {
      puts "Last Index of /: $nIndex"
      return $str_full_name
   }

   # Calculate starting index
   set nIndexStart [expr $nIndex + 1]

   # Calculate string len and ending index
   set nLen [string length $str_full_name]
   set nIndexEnd [expr $nLen - 1]


   # Get string after nIndex
   set str_basename [string range $str_full_name $nIndexStart $nIndexEnd]

   return $str_basename
}

###############################################################################
# Get base path of full path in the design.
#
# 1) "/dds_1", returns "/"
# 2) "/dds_1/dds_clk", returns "/dds_1"
# 3) "/mysub/dds_2/s_axis_a", returns "/mysub/dds_2"
#
###############################################################################
proc get_basepath { str_full_name } {
   set nIndex [string last "/" $str_full_name]

   if { $nIndex == -1 } {
      puts "Last Index of /: $nIndex"
      return ""
   }

   # Calculate starting index
   set nIndexStart 0
   set nIndexEnd [expr $nIndex - 1]

   # Get string after nIndex
   set str_basepath [string range $str_full_name $nIndexStart $nIndexEnd]

   return $str_basepath
}

##############################################################################
# Get list of interface pins and regular pins of cell which are connected.
##############################################################################
proc get_connected_intfpins_regpins { cell_obj } {

   set list_connected ""

   set list_intf_pins [get_bd_intf_pins -of_objects $cell_obj]
   set list_pins [get_bd_pins -of_objects $cell_obj]

   foreach intf_pin $list_intf_pins {
      set net [get_bd_intf_nets -of_objects $intf_pin]

      if { $net ne "" } {
         lappend list_connected $intf_pin
      }
   }

   foreach pin $list_pins {
      set net [get_bd_nets -of_objects $pin]

      if { $net ne "" } {
         lappend list_connected $pin
      }
   }

   return $list_connected
}

##############################################################################
# Get list of the same interface pins. Must be same name and VLNV.
##############################################################################
proc get_same_intfpins_regpins { cell2_obj cell1_obj list_connected } {

   set list_same ""

   foreach pin1 $list_connected {
      set class_type [get_property CLASS $pin1]
      set basename [get_basename "$pin1"]
      set cell2_pinname "${cell2_obj}/${basename}"

      set pin2 ""
      set pin_descr "pin"

      if { $class_type eq "bd_pin" } {
         set pin2 [get_bd_pins ${cell2_pinname}]


      } else {
         # Bus Interfaces

         set pin_descr "interface pin"

         set vlnv1 [get_property VLNV $pin1]
         set pin2 [get_bd_intf_pins ${cell2_pinname}]

         if { $pin2 ne "" } {
            set vlnv2 [get_property VLNV $pin2]

            if { $vlnv1 ne $vlnv2 } {
               puts ""
               puts "ERROR: Incompatible interfaces:"
               puts "ERROR: Interface pin <$pin1> has VLNV <$vlnv1>."
               puts "ERROR: Interface pin <$pin2> has VLNV <$vlnv2>."

               set pin2 ""
            }

         }
      }

      if { $pin2 ne "" } {
         lappend list_same $pin2
      } else {
         puts "ERROR: <$cell2_obj> does not have ${pin_descr} <${cell2_pinname}> which is present in <$cell1_obj>."
      }
   }

   return $list_same
}

##############################################################################
# Determine if the list1 has all items in list2
#
# @return 1 if true, else 0
##############################################################################
proc has_item_in_lists { list1 list2 } {

   foreach item2 $list2 {

      set nIndex [lsearch $list1 $item2]
      if { $nIndex != -1 } {
         return 1
      }
   }

   return 0
}


##############################################################################
# Determine if arguments list has help flag: -h, -help
#
# @return 1 if true, else 0
##############################################################################
proc is_help_flag { args } {

   if { [llength $args] != 1 } {
      return 0
   } elseif { $args eq "-h" || $args eq "-help" } {
      return 1
   }

   return 0
}

##############################################################################
# Print out help for replace_bd_cell
##############################################################################
proc show_help {} {

set str_help \
"\nreplace_bd_cell:\
\n\nDescription:\
\nReplace cell1 with cell2 by disconnecting connections to cell1 and\
\nconnecting those connections to cell2. The two cells must be in the same\
\nhierarchy.  Cell2 must have the same interface pins (name and VLNV) and \
\nsame regular pins (name) as cell1 that were used in the connections.\
\n\nExample:\
\ncell1 has interfaces: A, B (connected), C\
\ncell1 has pins: clk (connected), rst\
\n\ncell2 has interfaces: B, E, F\
\ncell2 has pins: clk, rst\
\n\nThe commmand will work for cell1 and cell2 in this case due to common\
\ninterface <B> and common pin <clk>.\
\n\nSyntax:\
\nreplace_bd_cells  <cell1> <cell2>\
\n\nReturns:\
\n0 if success.\
\n\nUsage:\
\n  Name             Description\
\n  ----------------------------\
\n  <cell1>          Cell with connections\
\n  <cell2>          Cell to replace cell1\
\n\nCategories:\
\nIPIntegrator"

puts $str_help

}

}
# END namespace replace_bd_cell_procs

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
