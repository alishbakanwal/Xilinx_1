# % load_feature systembuilder
# 
# This file is sourced by load_feature after features.tcl
# libraries
rdi::load_library systembuilder librdi_rsbtasks

# don't autocomplete bd namespace
rdi::hide_namespaces bd::

rdi::hide_commands auto_bd_connect  generate_bd_design

# There are various helper utility provided to IP developers

# begin namespace bd
namespace eval bd {

   proc get_intf_obj { name } {
      set obj [get_bd_intf_pins $name]
      if {$obj == ""} {
         set obj [get_bd_intf_ports $name]
      }
      return $obj
   }


   proc get_intf_obj_mode { obj } {
      set intf [get_intf_obj $obj]
      if {[llength $intf] == 0} {
          return "unknown"
      }
      set t [get_property -quiet TYPE  [get_bd_cells -of_objects $intf]]
      set m [get_property MODE  $intf]
      set c [get_property CLASS $intf]
      if {$t != ""} {
         set r  [dict get {bd_intf_pin {Slave {hier src ip dest} Master {hier dest ip src}} bd_intf_port {Slave src Master dest}} $c $m $t]
      } else {
         set r  [dict get {bd_intf_pin {Slave {hier src ip dest} Master {hier dest ip src}} bd_intf_port {Slave src Master dest}} $c $m ]
      }
      return $r
   }


   proc mark_propagate_only { cell_name paramList } {
      set listParamVal ""
      foreach param $paramList {
         set suffix ".PERM"   
         set pName CONFIG.$param$suffix
         set pVal "BD"

         lappend listParamVal "$pName"
         lappend listParamVal "$pVal"
      }

      set_property -dict "$listParamVal" [get_bd_cells $cell_name] -quiet
   }

   proc mark_propagate_overrideable { cell_name paramList } {
      set listParamVal ""
      foreach param $paramList {
         set suffix ".PERM"   
         set pName CONFIG.$param$suffix
         set pVal "BD_AND_USER"

         lappend listParamVal "$pName"
         lappend listParamVal "$pVal"
      }
      set_property -dict "$listParamVal" [get_bd_cells $cell_name] -quiet
   }

   proc mark_user { cell_name paramList } {
      set listParamVal ""
      foreach param $paramList {
         set suffix ".PERM"   
         set pName CONFIG.$param$suffix
         set pVal "USER"

         lappend listParamVal "$pName"
         lappend listParamVal "$pVal"
      }
      set_property -dict "$listParamVal" [get_bd_cells $cell_name] -quiet
   }

   proc mark_constant { cell_name paramList } {
      set listParamVal ""
      foreach param $paramList {
         set suffix ".PERM"   
         set pName CONFIG.$param$suffix
         set pVal "NONE"

         lappend listParamVal "$pName"
         lappend listParamVal "$pVal"
      }
      set_property -dict "$listParamVal" [get_bd_cells $cell_name] -quiet
   }

   namespace eval utils {

   proc list_all_property { ipi_obj } {

      # VALID CLASSES FOR ATTRIBUTE TYPE
      set LIST_VALID_CLASSES_BD "bd_cell bd_port bd_pin bd_intf_port bd_intf_pin diagram"
      set LIST_VALID_CLASSES_HDL "bd_cell bd_net bd_intf_net"

      # VALID ATTRIBS
      set list_attribs_apfcc "APFCC_PFM_CLOCK APFCC_PFM_CLOCK_ID APFCC_PFM_UIO APFCC_PFM_VERSION APFCC_PFM_NAME APFCC_PFM_DESCRIPTION APFCC_FCNMAPS MARK_APFCC" 
      set LIST_VALID_ATTRIBS_BD "TYPE FUNCTION IGNORE_IN_HDLGEN SKIP_BUFFER LATENCY SG_MIN_TOGGLE_PERIOD SG_USE_FOR_THROTTLE ASSOCIATED_BOARD_PARAM $list_attribs_apfcc"
      set LIST_VALID_ATTRIBS_HDL "MARK_DEBUG KEEP_HIERARCHY"

      set list_attribs ""
      set list_all_props ""
      set list_skip_props ""
  
      if { $ipi_obj eq "" || $ipi_obj == 0 } {
         return $list_all_props
      } elseif { $ipi_obj eq "-help" || $ipi_obj eq "--help" } {
         puts ""
         puts "Description:"
         puts "List properties of BD object along with hidden properties like CONFIG.\$prop.VALUE_SRC or PERM, BD_ATTRIBUTES and/or HDL_ATTRIBUTEs where applicable." 
         puts ""
         puts "Syntax:"
         puts "bd::utils::list_all_property  <bd_object>"
         puts ""
         puts "Returns:" 
         puts "list of property names"
         puts ""
         puts "BD objects below have BD_ATTRIBUTES:"
         puts "   cells, diagrams, pins, ports, interface pins, and interface ports"
         puts ""
         puts "BD objects below have HDL_ATTRIBUTES:"
         puts "   cells, nets, and interface nets"
         puts ""

         return $list_all_props
      }

      # Check if is an IPI object
      set class_type [get_property -quiet CLASS $ipi_obj]
      if { [string first "bd" "$class_type"] != 0 && $class_type ne "diagram" } {
         return $list_all_props
      }

      lappend list_attribs "PERM"
      lappend list_attribs "VALUE_SRC"

      # Skip properties if needed
      lappend list_skip_props "CLASS"
      lappend list_skip_props "LOCATION"
      lappend list_skip_props "NAME"
      lappend list_skip_props "PATH"
      lappend list_skip_props "SCREENSIZE"
      lappend list_skip_props "TYPE"
      lappend list_skip_props "VLNV"

      # Get BD/HDL_ATTRIBUTES
      set list_bd_props ""
      set list_hdl_props ""


      # Get default property list
      set list_props [list_property $ipi_obj]

      # 2015.3 - For some reason in customer release builds the BRIDGES info
      # is not part of list_property. Gets returned if in internal builds.
      if { [string first "BRIDGES" "$list_props"] < 0 } {
         set bridges [get_property BRIDGES $ipi_obj]

         # Only add if not empty
         if { "$bridges" ne "" } {
            set list_props "BRIDGES $list_props"
         } 
      }
 
      # Loop thru and skip props and check for props that have attributes
      foreach prop $list_props {

         # Make sure to save BD/HDL attribs so we can put them together 
         if { [string first "BD_ATTRIBUTE" "$prop"] == 0 } {
            lappend list_bd_props $prop
            continue
         } elseif { [string first "HDL_ATTRIBUTE" "$prop"] == 0 } {
            lappend list_hdl_props $prop
            continue
         }

         # Include into all list
         lappend list_all_props $prop

         # Skip the attributes portion
         if { [lsearch $list_skip_props $prop] != -1 } {
            continue
         } elseif { [string first "CONFIG" "$prop"] != 0 } {
            #puts "Skipping prop <$prop>..."
            continue
         }

         # Include attributes
         foreach attrib $list_attribs {

            set prop_attrib "${prop}.${attrib}"
            set val [get_property -quiet $prop_attrib $ipi_obj]

            # Skip if undefined attribute
            if { $val eq "" || $val eq "UNDEFINED" } {
               continue
            }

            # If has value, add to list
            lappend list_all_props $prop_attrib
         }
      }

      # ADD BD
      set list_temp "$list_bd_props"

      # Only add if valid
      set attr_type "BD_ATTRIBUTE"
      set list_valid_attribs "$LIST_VALID_ATTRIBS_BD"
      set list_valid_classes "$LIST_VALID_CLASSES_BD"

      if { [lsearch $list_valid_classes $class_type] != -1 } {
         foreach attr $list_valid_attribs {
            set prop "${attr_type}.${attr}"

            if { [lsearch $list_temp $prop] != -1 } {
               continue
            }
            lappend list_temp $prop
         }
      }

      # Now add to main list
      set list_bd_props [lsort $list_temp]
      foreach prop $list_bd_props {
         lappend list_all_props $prop
      }


      # ADD HDL
      set list_temp "$list_hdl_props"

      # Only add if valid
      set attr_type "HDL_ATTRIBUTE"
      set list_valid_attribs "$LIST_VALID_ATTRIBS_HDL"
      set list_valid_classes "$LIST_VALID_CLASSES_HDL"

      if { [lsearch $list_valid_classes $class_type] != -1 } {
         foreach attr $list_valid_attribs {
            set prop "${attr_type}.${attr}"

            if { [lsearch $list_temp $prop] != -1 } {
               continue
            }
            lappend list_temp $prop
         }
      }

      # Now add to main list
      set list_hdl_props [lsort $list_temp]
      foreach prop $list_hdl_props {
         lappend list_all_props $prop
      }

      return $list_all_props
   }
   # End of proc list_all_property()


   ##################################################################################
   # This will use the old find_bd_objs implementation until scripts are updated
   # to new implementation.
   ##################################################################################
   proc old_find_bd_objs { args } {

      #puts "oldfind_bd_objs: $args"
      if { $args eq "" } {
         return ""
      }

      set c "find_bd_objs"

      set x 0
      foreach arg $args {
         set c "$c \[lindex \$args $x\]"

         incr x
      }

      #puts "Modified proc: $c"

      # Get old flag of bd.useOldFindObjs
      set old_flag [get_param bd.useOldFindObjs]
      #puts "Old flag: $old_flag"

      # Turn on OLD find_bd_objs implementation
      set_param bd.useOldFindObjs 1

      # Evaluate the old find_bd_objs implementation
      if { [catch {set ret [eval $c]} errmsg] } {

         puts "$errmsg"

         # Restore old flag of bd.useOldFindObjs
         set_param bd.useOldFindObjs $old_flag

         return ""
      }

      # Restore old flag of bd.useOldFindObjs
      set_param bd.useOldFindObjs $old_flag

      return $ret

   }
   # End of old_find_bd_objs()

   }
   # End of namespace utils
   
}
# end namespace bd


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
