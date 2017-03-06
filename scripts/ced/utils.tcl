###########################################################################
# General utils

namespace eval ::ced::utils {

 proc init_utils {ns exampleDesign} {

   namespace eval ::$ns {

      set designObject ""
      proc EvalSubstituting {parameters procedure {numlevels 1}} {
        set paramlist {}
        if {[string index $numlevels 0]!="#"} {
         set numlevels [expr $numlevels+1]
        }
        foreach parameter $parameters {
         upvar 1 $parameter $parameter\_value
         tcl::lappend paramlist \$$parameter [set $parameter\_value]
        }
        uplevel $numlevels [string map $paramlist $procedure]
      }

      set validation_group_index 0
      set updation_group_index 0
      set updation_gui_group_index 0

      proc validater {parameters_used parameters_modified procedure_functionality } {
         variable validation_group_index
         variable designObject
         #1st arg - procedure type
         #2nd arg - procedure name
         #3rd arg - Input arguments
         #4th arg - Output arguments
         EvalSubstituting { validation_group_index parameters_used procedure_functionality parameters_modified} {
           proc validate_$validation_group_index {$parameters_used $parameters_modified} {
             $procedure_functionality
              #return of dict of parameters and their values
              foreach paramter [list $parameters_modified] {
                dict set paramList $paramter [set $paramter]
              }
              return $paramList
           }
         } 0   
         ced::register_procedure_information $designObject -procedure_type "validate" -procedure_name "validate_$validation_group_index" -input_args $parameters_used -output_args $parameters_modified
         #storing validation procedure name against each parameter
         incr validation_group_index
      }

      proc updater {parameters_used parameters_modified procedure_functionality } {
         variable updation_group_index
         variable designObject
         #1st arg - procedure type
         #2nd arg - procedure name
         #3rd arg - Input arguments
         #4th arg - Output arguments
         ced::register_procedure_information $designObject -procedure_type "update" -procedure_name "update_$updation_group_index" -input_args $parameters_used -output_args $parameters_modified
         EvalSubstituting { updation_group_index parameters_used procedure_functionality parameters_modified } {
           proc update_$updation_group_index {$parameters_used $parameters_modified} {
             $procedure_functionality
              #return of  dict of parameters and their values
              foreach paramter [list $parameters_modified] {
                dict set paramList $paramter [set $paramter]
              }
              return $paramList
           }
         } 0   
         #storing updation procedure name against each parameter and its arguments
         incr updation_group_index
      }

      proc gui_updater {parameters_used parameters_modified procedure_functionality } {
         variable updation_gui_group_index
         variable designObject
         #1st arg - procedure type
         #2nd arg - procedure name
         #3rd arg - Input arguments
         #4th arg - Output arguments
         ced::register_procedure_information $designObject -procedure_type "update_gui_for" -procedure_name "update_gui_for_$updation_gui_group_index" -input_args $parameters_used -output_args $parameters_modified
         EvalSubstituting { updation_gui_group_index parameters_used procedure_functionality parameters_modified } {
           proc update_gui_for_$updation_gui_group_index {$parameters_used $parameters_modified} {
             $procedure_functionality
              #return of  dict of parameters and their values
              foreach paramter [list $parameters_modified] {
                dict set paramList $paramter [set $paramter]
              }
              return $paramList
           }
         } 0   
         #storing updation procedure name against each parameter and its arguments
         incr updation_gui_group_index
      } 

      proc get_design_object {} {
        variable designObject
        return $designObject
      }
    }
    set ::${ns}::designObject $exampleDesign 
  }
}



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
