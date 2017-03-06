
##############################################################################
# Copyright 2013 Xilinx Inc. All rights reserved
##############################################################################
namespace eval ::hsi::utils {
}
namespace eval ::hsi::utils {
}

proc ::hsi::utils::get_exact_arg_list { args } {
    lappend argList
    foreach arg $args {
        set subargs [regexp -all -inline {\S+} "$arg"]
        foreach subarg $subargs {
            set newarg $subarg
            set newarg [string map { "\{" "" } $newarg]
            set newarg [string map { "\}" "" } $newarg]
            lappend argList $newarg
        }
    }
    return $argList
}
#
# Open file in the include directory
#
proc ::hsi::utils::open_include_file {file_name} {
    set filename [file join "../../include" $file_name]
    set config_inc [open $filename a]
    if {![file exists $filename]} {
        ::hsi::utils::write_c_header $config_inc "Driver parameters"
    }
    return $config_inc
}

#
# Create a parameter name based on the format of Xilinx device drivers
# Use peripheral name to form the parameter name
#
proc ::hsi::utils::get_ip_param_name {periph_handle param} {
   set name [common::get_property NAME $periph_handle ]
   set name [string toupper $name]
   set name [string map { "/" "_" } $name]
   set name [format "XPAR_%s_" $name]
   set param [string toupper $param]
   if {[string match C_* $param]} {
       set name [format "%s%s" $name [string range $param 2 end]]
   } else {
       set name [format "%s%s" $name $param]
   }
   return $name
}

#
# Create a parameter name based on the format of Xilinx device drivers.
# Use driver name to form the parameter name
#
proc ::hsi::utils::get_driver_param_name {driver_name param} {
   set name [string toupper $driver_name]
   set name [string map { "/" "_" } $name]
   set name [format "XPAR_%s_" $name]
   if {[string match C_* $param]} {
       set name [format "%s%s" $name [string range $param 2 end]]
   } else {
       set name [format "%s%s" $name $param]
   }
   return $name
}
    
#
# Given a list of arguments, define them all in an include file.
# Handles IP model/user parameters, as well as the special parameters NUM_INSTANCES,
# DEVICE_ID
# Will not work for a processor.
#
proc ::hsi::utils::define_include_file {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
    # Open include file
    set file_handle [::hsi::utils::open_include_file $file_name]

    # Get all peripherals connected to this driver
    set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 

    # Handle special cases
    set arg "NUM_INSTANCES"
    set posn [lsearch -exact $args $arg]
    if {$posn > -1} {
        puts $file_handle "/* Definitions for driver [string toupper [common::get_property name $drv_handle]] */"
        # Define NUM_INSTANCES
        puts $file_handle "#define [::hsi::utils::get_driver_param_name $drv_string $arg] [llength $periphs]"
        set args [lreplace $args $posn $posn]
    }

    # Check if it is a driver parameter
    lappend newargs 
    foreach arg $args {
        set value [common::get_property CONFIG.$arg $drv_handle]
        if {[llength $value] == 0} {
            lappend newargs $arg
        } else {
            puts $file_handle "#define [::hsi::utils::get_driver_param_name $drv_string $arg] [common::get_property $arg $drv_handle]"
        }
    }
    set args $newargs

    # Print all parameters for all peripherals
    set device_id 0
    foreach periph $periphs {
        puts $file_handle ""
        puts $file_handle "/* Definitions for peripheral [string toupper [common::get_property NAME $periph]] */"
        foreach arg $args {
            if {[string compare -nocase "DEVICE_ID" $arg] == 0} {
                set value $device_id
                incr device_id
            } else {
                set value [common::get_property CONFIG.$arg $periph]
            }
            if {[llength $value] == 0} {
                set value 0
            }
            set value [::hsi::utils::format_addr_string $value $arg]
            if {[string compare -nocase "HW_VER" $arg] == 0} {
                puts $file_handle "#define [::hsi::utils::get_ip_param_name $periph $arg] \"$value\""
            } else {
                puts $file_handle "#define [::hsi::utils::get_ip_param_name $periph $arg] $value"
            }
        }
        puts $file_handle ""
    }		
    puts $file_handle "\n/******************************************************************/\n"
    close $file_handle
}

#
# Given a list of arguments, define them all in an include file.
# Similar to proc define_include_file, except that uses regsub
# to replace "S_AXI_" with "".
#
proc hsi::utils::define_zynq_include_file {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 

   # Handle special cases
   set arg "NUM_INSTANCES"
   set posn [lsearch -exact $args $arg]
   if {$posn > -1} {
       puts $file_handle "/* Definitions for driver [string toupper [common::get_property name $drv_handle]] */"
       # Define NUM_INSTANCES
       puts $file_handle "#define [::hsi::utils::get_driver_param_name $drv_string $arg] [llength $periphs]"
       set args [lreplace $args $posn $posn]
   }

   # Check if it is a driver parameter
   lappend newargs 
   foreach arg $args {
       set value [common::get_property CONFIG.$arg $drv_handle ]
       if {[llength $value] == 0} {
           lappend newargs $arg
       } else {
           puts $file_handle "#define [::hsi::utils::get_driver_param_name $drv_string $arg] [common::get_property CONFIG.$arg $drv_handle ]"
       }
   }
   set args $newargs

   # Print all parameters for all peripherals
   set device_id 0
   foreach periph $periphs {
       puts $file_handle ""
       puts $file_handle "/* Definitions for peripheral [string toupper [common::get_property NAME $periph]] */"
       foreach arg $args {
           if {[string compare -nocase "DEVICE_ID" $arg] == 0} {
               set value $device_id
               incr device_id
           } else {
               set value [common::get_property CONFIG.$arg $periph]
           }
           if {[llength $value] == 0} {
               set value 0
           }
           set value [::hsi::utils::format_addr_string $value $arg]
           set arg_name [::hsi::utils::get_ip_param_name $periph $arg]
           regsub "S_AXI_" $arg_name "" arg_name
           if {[string compare -nocase "HW_VER" $arg] == 0} {
               puts $file_handle "#define $arg_name \"$value\""
           } else {
               puts $file_handle "#define $arg_name $value"
           }
       }
       puts $file_handle ""
   }		
   puts $file_handle "\n/******************************************************************/\n"
   close $file_handle
}

#
# Define parameter only if all peripherals have this parameter defined.
#
proc ::hsi::utils::define_if_all {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 

   # Check all parameters for all peripherals
   foreach arg $args {
       set value 1
       foreach periph $periphs {
           set thisvalue [::hsi::utils::get_param_value $periph $arg]
           if {$thisvalue != 1} {
               set value 0
               break
           }
       }
       if {$value == 1} {
           puts $file_handle "#define [::hsi::utils::get_driver_param_name $drv_string $arg] $value"
       }
   }		
   close $file_handle
}

#
# Define parameter as the maxm value for all connected peripherals
#
proc ::hsi::utils::define_max {drv_handle file_name define_name arg} {
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 

   # Check all parameters for all peripherals
   set value 0
   foreach periph $periphs {
       set thisvalue [::hsi::utils::get_param_value $periph $arg]
       if {$thisvalue > $value} {
           set value $thisvalue
       }
   }
   puts $file_handle "#define $define_name $value"
   close $file_handle
}
	
#
# Create configuration C file as required by Xilinx  drivers
#
proc ::hsi::utils::define_config_file {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
    set filename [file join "src" $file_name] 
    #Fix for CR 784758
    #file delete $filename
    set config_file [open $filename w]
    ::hsi::utils::write_c_header $config_file "Driver configuration"    
    puts $config_file "#include \"xparameters.h\""
    puts $config_file "#include \"[string tolower $drv_string].h\""
    puts $config_file "\n/*"
    puts $config_file "* The configuration table for devices"
    puts $config_file "*/\n"
    puts $config_file [format "%s_Config %s_ConfigTable\[\] =" $drv_string $drv_string]
    puts $config_file "\{"
    set periphs [::hsi::utils::get_common_driver_ips $drv_handle]     
    set start_comma ""
    foreach periph $periphs {
        puts $config_file [format "%s\t\{" $start_comma]
        set comma ""
        foreach arg $args {
            if {[string compare -nocase "DEVICE_ID" $arg] == 0} {
                puts -nonewline $config_file [format "%s\t\t%s,\n" $comma [::hsi::utils::get_ip_param_name $periph $arg]]
                continue
            }
            # Check if this is a driver parameter or a peripheral parameter
            set value [common::get_property CONFIG.$arg $drv_handle]
            if {[llength $value] == 0} {
                set local_value [common::get_property CONFIG.$arg $periph ]
                # If a parameter isn't found locally (in the current
                # peripheral), we will (for some obscure and ancient reason)
                # look in peripherals connected via point to point links
                if { [string compare -nocase $local_value ""] == 0} { 
                    set p2p_name [::hsi::utils::get_p2p_name $periph $arg]
                    if { [string compare -nocase $p2p_name ""] == 0} {
                        puts -nonewline $config_file [format "%s\t\t%s" $comma [::hsi::utils::get_ip_param_name $periph $arg]]
                    } else {
                        puts -nonewline $config_file [format "%s\t\t%s" $comma $p2p_name]
                    }
                } else {
                    puts -nonewline $config_file [format "%s\t\t%s" $comma [::hsi::utils::get_ip_param_name $periph $arg]]
                }
            } else {
                puts -nonewline $config_file [format "%s\t\t%s" $comma [::hsi::utils::get_driver_param_name $drv_string $arg]]
            }
            set comma ",\n"
        }
        puts -nonewline $config_file "\n\t\}"
        set start_comma ",\n"
    }
    puts $config_file "\n\};"

    puts $config_file "\n";

    close $config_file
}

#
# Create configuration C file as required by Xilinx Zynq drivers
# Similar to proc define_config_file, except that uses regsub
# to replace "S_AXI_" with ""
#
proc ::hsi::utils::define_zynq_config_file {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
   set filename [file join "src" $file_name] 
   #Fix for CR 784758
   #file delete $filename
   set config_file [open $filename w]
   ::hsi::utils::write_c_header $config_file "Driver configuration"    
   puts $config_file "#include \"xparameters.h\""
   puts $config_file "#include \"[string tolower $drv_string].h\""
   puts $config_file "\n/*"
   puts $config_file "* The configuration table for devices"
   puts $config_file "*/\n"
   puts $config_file [format "%s_Config %s_ConfigTable\[\] =" $drv_string $drv_string]
   puts $config_file "\{"
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle]     
   set start_comma ""
   foreach periph $periphs {
       puts $config_file [format "%s\t\{" $start_comma]
       set comma ""
       foreach arg $args {
           # Check if this is a driver parameter or a peripheral parameter
           set value [common::get_property CONFIG.$arg $drv_handle]
           if {[llength $value] == 0} {
            set local_value [common::get_property CONFIG.$arg $periph ]
            # If a parameter isn't found locally (in the current
            # peripheral), we will (for some obscure and ancient reason)
            # look in peripherals connected via point to point links
            if { [string compare -nocase $local_value ""] == 0} { 
               set p2p_name [::hsi::utils::get_p2p_name $periph $arg]
               if { [string compare -nocase $p2p_name ""] == 0} {
                   set arg_name [::hsi::utils::get_ip_param_name $periph $arg]
                   regsub "S_AXI_" $arg_name "" arg_name
                   puts -nonewline $config_file [format "%s\t\t%s" $comma $arg_name]
               } else {
                   regsub "S_AXI_" $p2p_name "" p2p_name
                   puts -nonewline $config_file [format "%s\t\t%s" $comma $p2p_name]
               }
           } else {
               set arg_name [::hsi::utils::get_ip_param_name $periph $arg]
               regsub "S_AXI_" $arg_name "" arg_name
               puts -nonewline $config_file [format "%s\t\t%s" $comma $arg_name]
                   }
           } else {
               set arg_name [::hsi::utils::get_driver_param_name $drv_string $arg]
               regsub "S_AXI_" $arg_name "" arg_name
               puts -nonewline $config_file [format "%s\t\t%s" $comma $arg_name]
           }
           set comma ",\n"
       }
       puts -nonewline $config_file "\n\t\}"
       set start_comma ",\n"
   }
   puts $config_file "\n\};"

   puts $config_file "\n";

   close $config_file
}

#
# Add definitions in an include file.  Args must be name value pairs
#
proc ::hsi::utils::define_with_names {drv_handle periph_handle file_name args} {
   set args [::hsi::utils::get_exact_arg_list $args]
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   foreach {lhs rhs} $args {
       set value [::hsi::utils::get_param_value $periph_handle $rhs]
       set value [::hsi::utils::format_addr_string $value $rhs]
       puts $file_handle "#define $lhs $value"
   }		
   close $file_handle
}

#
# Generate a C structure from an array
# "args" is variable no - fields of the array 
#
#proc ::hsi::utils::xadd_struct {file_handle lib_handle struct_type struct_name array_name args} { 
#
#   set arrhandle [xget_handle $lib_handle "ARRAY" $array_name] 
#   set elements [xget_handle $arrhandle "ELEMENTS" "*"] 
#   set count 0 
#   set max_count [llength $elements] 
#   puts $file_handle "struct $struct_type $struct_name\[$max_count\] = \{" 
#
#   foreach ele $elements { 
#   incr count 
#   puts -nonewline $file_handle "\t\{" 
#   foreach field $args { 
#       set field_value [common::get_property CONFIG.$field $ele] 
#       if { $field == [lindex $args end] } { 
#   	puts -nonewline $file_handle "$field_value" 
#       } else { 
#   	puts -nonewline $file_handle "$field_value," 
#       } 
#   } 
#   if {$count < $max_count} { 
#       puts $file_handle "\}," 
#   } else { 
#       puts $file_handle "\}" 
#   } 
#   } 
#   puts $file_handle "\}\;" 
#}

#
#---------------------------------------------------------------------------------------------
# Given a list of memory bank arguments, define them all in an include file.
# The "args" is a base, high address pairs of the memory banks
# For example:
# define_include_file_membank $drv_handle "xparameters.h" "C_MEM0_BASEADDR" "C_MEM0_HIGHADDR"
# generates :
# XPAR_MYEMC_MEM0_BASEADDR, XPAR_MYEMC_MEM1_HIGHADDR definitions in xparameters.h file
# Handles MHS/MPD parameters 
#---------------------------------------------------------------------------------------------
proc ::hsi::utils::define_include_file_membank {drv_handle file_name args} {
   set args [::hsi::utils::get_exact_arg_list $args]

   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 
   
   foreach periph $periphs {
        
       lappend newargs

       set len [llength $args]

       for { set i 0 } { $i <  $len} { incr i 2} {
           set base [lindex $args $i]
           set high [lindex $args [expr $i+1]]
           set baseval [common::get_property CONFIG.$base $periph]
           set baseval [string map {_ ""} $baseval]
           # Check to see if value starts with 0b or 0x
           if {[string match -nocase 0b* $baseval]} {
            set baseval [::hsi::utils::convert_binary_to_hex $baseval]
           } else {
            set baseval [format "0x%08X" $baseval]
           }
           set highval [common::get_property CONFIG.$high $periph]
           set highval [string map {_ ""} $highval]
           # Check to see if value starts with 0b or 0x
           if {[string match -nocase 0b* $highval]} {
            set highval [::hsi::utils::convert_binary_to_hex $highval]
           } else {
            set highval [format "0x%08X" $highval]
           }
           set baseval [format "%x" $baseval]
           set highval [format "%x" $highval]
           if {$highval > $baseval} {
            lappend newargs $base
            lappend newargs $high
           }	
       }
       ::hsi::utils::define_membank $periph $file_name $newargs
       set newargs ""
   }
}

#---------------------------------------------------
# Generates the defn for a memory bank
# The prev fn takes in a list of memory bank args
#---------------------------------------------------
proc ::hsi::utils::define_membank { periph file_name args } {
   set args [::hsi::utils::get_exact_arg_list $args]
   set newargs [lindex $args 0]
   
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   puts $file_handle "/* Definitions for peripheral [string toupper [common::get_property NAME $periph]] */"
   
   foreach arg $newargs {
       set value [common::get_property CONFIG.$arg $periph]
       set value [::hsi::utils::format_addr_string $value $arg]
       puts $file_handle "#define [::hsi::utils::get_ip_param_name $periph $arg] $value"
   }

   puts $file_handle "\n/******************************************************************/\n"
   close $file_handle
}


#----------------------------------------------------
# Find all possible address params for the
# given peripheral "periph"
#----------------------------------------------------
proc ::hsi::utils::find_addr_params {periph} {
  
   set addr_params [list]

   #get the mem_ranges which belongs to this peripheral
   if { [llength $periph] != 0 } {
   set mem_ranges [::hsi::get_mem_ranges -filter "INSTANCE==$periph"]
   foreach mem_range $mem_ranges {
       set bparam_name [common::get_property BASE_NAME $mem_range]
       set bparam_value [common::get_property BASE_VALUE $mem_range]
       set hparam_name [common::get_property HIGH_NAME $mem_range]
       set hparam_value [common::get_property HIGH_VALUE $mem_range]

       # Check if already added
       set bposn [lsearch -exact $addr_params $bparam_name]
       set hposn [lsearch -exact $addr_params $hparam_name]
       if {$bposn > -1  || $hposn > -1 } {
           continue
       }
       lappend addr_params $bparam_name
       lappend addr_params $hparam_name
   }
   }
   return $addr_params
}

#----------------------------------------------------
# Defines all possible address params in the filename
# for all periphs that use this driver
#----------------------------------------------------
proc ::hsi::utils::define_addr_params {drv_handle file_name} {
   
   set addr_params [list]

   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 

   # Print all parameters for all peripherals
   foreach periph $periphs {
   puts $file_handle ""
   puts $file_handle "/* Definitions for peripheral [string toupper [common::get_property NAME $periph]] */"

   set addr_params ""
   set addr_params [::hsi::utils::find_addr_params $periph]

   foreach arg $addr_params {
       set value [::hsi::utils::get_param_value $periph $arg]
       if {$value != ""} {
           set value [::hsi::utils::format_addr_string $value $arg]
           puts $file_handle "#define [::hsi::utils::get_ip_param_name $periph $arg] $value"
       }
   }
   puts $file_handle ""
   }		
   puts $file_handle "\n/******************************************************************/\n"
   close $file_handle
}

#----------------------------------------------------
# Defines all non-reserved params in the filename
# for all periphs that use this driver
#----------------------------------------------------
proc ::hsi::utils::define_all_params {drv_handle file_name} {
   
   set params [list]
   lappend reserved_param_list "C_DEVICE" "C_PACKAGE" "C_SPEEDGRADE" "C_FAMILY" "C_INSTANCE" "C_KIND_OF_EDGE" "C_KIND_OF_LVL" "C_KIND_OF_INTR" "C_NUM_INTR_INPUTS" "C_MASK" "C_NUM_MASTERS" "C_NUM_SLAVES" "C_LMB_AWIDTH" "C_LMB_DWIDTH" "C_LMB_MASK" "C_LMB_NUM_SLAVES" "INSTANCE" "HW_VER"

   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 
  
   # Print all parameters for all peripherals
   foreach periph $periphs {
       puts $file_handle ""
       puts $file_handle "/* Definitions for peripheral [string toupper [common::get_property NAME $periph]] */"
       set params ""
       set params [common::list_property $periph CONFIG.*]
       foreach param $params {
           set param_name [string range $param [string length "CONFIG."] [string length $param]]
           set posn [lsearch -exact $reserved_param_list $param_name]
           if {$posn == -1 } {
               set param_value [common::get_property $param $periph]
                if {$param_value != ""} {
                    set param_value [::hsi::utils::format_addr_string $param_value $param_name]
                    puts $file_handle "#define [::hsi::utils::get_ip_param_name $periph $param_name] $param_value"
                }
           }
       }
       puts $file_handle "\n/******************************************************************/\n"
   }		
   close $file_handle
}

#
# define_canonical_xpars - Used to print out canonical defines for a driver. 
# Given a list of arguments, define each as a canonical constant name, using
# the driver name, in an include file.
#
proc ::hsi::utils::define_canonical_xpars {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all the peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle]

   # Get the names of all the peripherals connected to this driver
   foreach periph $periphs {
       set peripheral_name [string toupper [common::get_property NAME $periph]]
       lappend peripherals $peripheral_name
   }

   # Get possible canonical names for all the peripherals connected to this
   # driver
   set device_id 0
   foreach periph $periphs {
       set canonical_name [string toupper [format "%s_%s" $drv_string $device_id]]
       lappend canonicals $canonical_name
       
       # Create a list of IDs of the peripherals whose hardware instance name
       # doesn't match the canonical name. These IDs can be used later to
       # generate canonical definitions
       if { [lsearch $peripherals $canonical_name] < 0 } {
           lappend indices $device_id
       }
       incr device_id
   }

   set i 0
   foreach periph $periphs {
       set periph_name [string toupper [common::get_property NAME $periph]]

       # Generate canonical definitions only for the peripherals whose
       # canonical name is not the same as hardware instance name
       if { [lsearch $canonicals $periph_name] < 0 } {
           puts $file_handle "/* Canonical definitions for peripheral $periph_name */"
           set canonical_name [format "%s_%s" $drv_string [lindex $indices $i]]

           foreach arg $args {
               set lvalue [::hsi::utils::get_driver_param_name $canonical_name $arg]

               # The commented out rvalue is the name of the instance-specific constant
               # set rvalue [::hsi::utils::get_ip_param_name $periph $arg]
               # The rvalue set below is the actual value of the parameter
               set rvalue [::hsi::utils::get_param_value $periph $arg]
               if {[llength $rvalue] == 0} {
                   set rvalue 0
               }
               set rvalue [::hsi::utils::format_addr_string $rvalue $arg]
   
               puts $file_handle "#define $lvalue $rvalue"

           }
           puts $file_handle ""
           incr i
       }
   }

   puts $file_handle "\n/******************************************************************/\n"
   close $file_handle
}

#-----------------------------------------------------------------------------
# define_zynq_canonical_xpars - Used to print out canonical defines for a driver. 
# Similar to proc define_config_file, except that uses regsub to replace "S_AXI_"
# with "".
#-----------------------------------------------------------------------------
proc ::hsi::utils::define_zynq_canonical_xpars {drv_handle file_name drv_string args} {
    set args [::hsi::utils::get_exact_arg_list $args]
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]

   # Get all the peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle]

   # Get the names of all the peripherals connected to this driver
   foreach periph $periphs {
       set peripheral_name [string toupper [common::get_property NAME $periph]]
       lappend peripherals $peripheral_name
   }

   # Get possible canonical names for all the peripherals connected to this
   # driver
   set device_id 0
   foreach periph $periphs {
       set canonical_name [string toupper [format "%s_%s" $drv_string $device_id]]
       lappend canonicals $canonical_name
       
       # Create a list of IDs of the peripherals whose hardware instance name
       # doesn't match the canonical name. These IDs can be used later to
       # generate canonical definitions
       if { [lsearch $peripherals $canonical_name] < 0 } {
           lappend indices $device_id
       }
       incr device_id
   }

   set i 0
   foreach periph $periphs {
       set periph_name [string toupper [common::get_property NAME $periph]]

       # Generate canonical definitions only for the peripherals whose
       # canonical name is not the same as hardware instance name
       if { [lsearch $canonicals $periph_name] < 0 } {
           puts $file_handle "/* Canonical definitions for peripheral $periph_name */"
           set canonical_name [format "%s_%s" $drv_string [lindex $indices $i]]

           foreach arg $args {
               set lvalue [::hsi::utils::get_driver_param_name $canonical_name $arg]
               regsub "S_AXI_" $lvalue "" lvalue

               # The commented out rvalue is the name of the instance-specific constant
               # set rvalue [::hsi::utils::get_ip_param_name $periph $arg]
               # The rvalue set below is the actual value of the parameter
               set rvalue [::hsi::utils::get_param_value $periph $arg]
               if {[llength $rvalue] == 0} {
                   set rvalue 0
               }
               set rvalue [::hsi::utils::format_addr_string $rvalue $arg]
   
               puts $file_handle "#define $lvalue $rvalue"

           }
           puts $file_handle ""
           incr i
       }
   }

   puts $file_handle "\n/******************************************************************/\n"
   close $file_handle
}

#----------------------------------------------------
# Define processor params using IP type
#----------------------------------------------------
proc ::hsi::utils::define_processor_params {drv_handle file_name} {
   set sw_proc_handle [::hsi::get_sw_processor]
   set proc_name [common::get_property hw_instance $sw_proc_handle]
   set hw_proc_handle [::hsi::get_cells -hier $proc_name ]

   set lprocs [::hsi::get_cells -hier -filter {IP_TYPE==PROCESSOR}]

   set params [list]
   lappend reserved_param_list "C_DEVICE" "C_PACKAGE" "C_SPEEDGRADE" "C_FAMILY" "C_INSTANCE" "C_KIND_OF_EDGE" "C_KIND_OF_LVL" "C_KIND_OF_INTR" "C_NUM_INTR_INPUTS" "C_MASK" "C_NUM_MASTERS" "C_NUM_SLAVES" "C_DCR_AWIDTH" "C_DCR_DWIDTH" "C_DCR_NUM_SLAVES" "C_LMB_AWIDTH" "C_LMB_DWIDTH" "C_LMB_MASK" "C_LMB_NUM_SLAVES" "C_OPB_AWIDTH" "C_OPB_DWIDTH" "C_OPB_NUM_MASTERS" "C_OPB_NUM_SLAVES" "C_PLB_AWIDTH" "C_PLB_DWIDTH" "C_PLB_MID_WIDTH" "C_PLB_NUM_MASTERS" "C_PLB_NUM_SLAVES" "INSTANCE"
   
   # Open include file
   set file_handle [::hsi::utils::open_include_file $file_name]
   
   # Get all peripherals connected to this driver
   set periphs [::hsi::utils::get_common_driver_ips $drv_handle] 
   # Print all parameters for all peripherals
   foreach periph $periphs {
   
       set name [common::get_property IP_NAME $periph]
       set name [string toupper $name]
       set iname [common::get_property NAME $periph]
   #--------------------------------	
   # Set CPU ID & CORE_CLOCK_FREQ_HZ
   #--------------------------------		
   set id 0
   foreach processor $lprocs {
       if {[string compare -nocase $processor $iname] == 0} {
        set pname [format "XPAR_%s_ID" $name]
        puts $file_handle "#define XPAR_CPU_ID $id"
        puts $file_handle "#define $pname $id"
       }
       incr id
   }

   set params ""
   set params [common::list_property $periph CONFIG.*]

   foreach param $params {
       set param_name [string toupper [string range $param [string length "CONFIG."] [string length $param]]]
       set posn [lsearch -exact $reserved_param_list $param_name]
       if {$posn == -1 } {
        set param_value [common::get_property  $param $periph]
       
        if {$param_value != ""} {
            set param_value [::hsi::utils::format_addr_string $param_value $param_name]
            set name [common::get_property IP_NAME $periph]
            set name [string toupper $name]
            set name [format "XPAR_%s_" $name]
            set param [string toupper $param_name]
            if {[string match C_* $param_name]} {
                set name [format "%s%s" $name [string range $param_name 2 end]]
            } else {
                set name [format "%s%s" $name $param_name]
            }
            if {[string compare -nocase $param "HW_VER"] == 0} {
                puts $file_handle "#define [string toupper $name] \"$param_value\""
            } else {
                puts $file_handle "#define [string toupper $name] $param_value"
            }
        }
       }
   }
   
   puts $file_handle "\n/******************************************************************/\n"
   }		
   close $file_handle
}

#
# Get the memory range of IP for current processor
#
proc ::hsi::utils::get_ip_mem_ranges {periph} {
    set sw_proc_handle [::hsi::get_sw_processor]
    set hw_proc_handle [::hsi::get_cells -hier [common::get_property hw_instance $sw_proc_handle]]
	if { [llength $periph] != 0 } {
    set mem_ranges [::hsi::get_mem_ranges -of_objects $hw_proc_handle -filter "INSTANCE==$periph"]
	}
    return $mem_ranges
}

#
# Handle the stdin parameter of a processor
#
proc ::hsi::utils::handle_stdin {drv_handle} {

   set stdin [common::get_property CONFIG.stdin $drv_handle]
   set sw_proc_handle [::hsi::get_sw_processor]
   set hw_proc_handle [::hsi::get_cells -hier [common::get_property hw_instance $sw_proc_handle]]

   set processor [common::get_property hw_instance $sw_proc_handle]
   if {[llength $stdin] == 1 && [string compare -nocase "none" $stdin] != 0} {
       set stdin_drv_handle [::hsi::get_drivers -filter "HW_INSTANCE==$stdin"]
       if {[llength $stdin_drv_handle] == 0} {
           error "No driver for stdin peripheral $stdin. Check the following reasons: \n 1. $stdin is not accessible from processor $processor.\n 2. No Driver block is defined for $stdin in MSS file." "" "hsi_error"
           return
       }

       set interface_handle [::hsi::get_sw_interfaces -of_objects $stdin_drv_handle -filter "NAME==stdin"]
       if {[llength $interface_handle] == 0} {
           error "No stdin interface available for driver for peripheral $stdin" "" "hsi_error"
       }

       set inbyte_name [common::get_property FUNCTION.inbyte $interface_handle ]
       if {[llength $inbyte_name] == 0} {
         error "No inbyte function available for driver for peripheral $stdin" "" "hsi_error"
       }
       set header [common::get_property PROPERTY.header $interface_handle]
       if {[llength $header] == 0} {
         error "No header property available in stdin interface for driver for peripheral $stdin" "" "hsi_error"
       }
       set config_file [open "src/inbyte.c" w]
       puts $config_file "\#include \"xparameters.h\"" 
       puts $config_file [format "\#include \"%s\"\n" $header]
       puts $config_file "\#ifdef __cplusplus"
       puts $config_file "extern \"C\" {"
       puts $config_file "\#endif"
       puts $config_file "char inbyte(void);"
       puts $config_file "\#ifdef __cplusplus"
       puts $config_file "}"
       puts $config_file "\#endif \n"
       puts $config_file "char inbyte(void) {"
       puts $config_file [format "\t return %s(STDIN_BASEADDRESS);" $inbyte_name]
       puts $config_file "}"
       close $config_file
       set config_file [::hsi::utils::open_include_file "xparameters.h"]
       set stdin_mem_range [::hsi::get_mem_ranges -of_objects $hw_proc_handle -filter "INSTANCE==$stdin && IS_DATA==1"]
       if { [llength $stdin_mem_range] > 1 } {
           set stdin_mem_range [::hsi::get_mem_ranges -of_objects $hw_proc_handle -filter "INSTANCE==$stdin&& (BASE_NAME==C_BASEADDR||BASE_NAME==C_S_AXI_BASEADDR)"]
       }
       set base_name [common::get_property BASE_NAME $stdin_mem_range]
       set base_value [common::get_property BASE_VALUE $stdin_mem_range]
       puts $config_file "\#define STDIN_BASEADDRESS [::hsi::utils::format_addr_string $base_value $base_name]"
       close $config_file
   }
}


#
# Handle the stdout parameter of a processor
#
proc ::hsi::utils::handle_stdout {drv_handle} {
   set stdout [common::get_property CONFIG.stdout $drv_handle]
   set sw_proc_handle [::hsi::get_sw_processor]
   set hw_proc_handle [::hsi::get_cells -hier [common::get_property hw_instance $sw_proc_handle]]
   set processor [common::get_property NAME $hw_proc_handle]

   if {[llength $stdout] == 1 && [string compare -nocase "none" $stdout] != 0} {
       set stdout_drv_handle [::hsi::get_drivers -filter "HW_INSTANCE==$stdout"]
       if {[llength $stdout_drv_handle] == 0} {
           error "No driver for stdout peripheral $stdout. Check the following reasons: \n 1. $stdout is not accessible from processor $processor.\n 2. No Driver block is defined for $stdout in MSS file." "" "hsi_error"
           return
       }
       
       set interface_handle [::hsi::get_sw_interfaces -of_objects $stdout_drv_handle -filter "NAME==stdout"]
       if {[llength $interface_handle] == 0} {
         error "No stdout interface available for driver for peripheral $stdout" "" "hsi_error"
       }
       set outbyte_name [common::get_property FUNCTION.outbyte $interface_handle]
       if {[llength $outbyte_name] == 0} {
         error "No outbyte function available for driver for peripheral $stdout" "" "hsi_error"
       }
       set header [common::get_property PROPERTY.header $interface_handle]
       if {[llength $header] == 0} {
         error "No header property available in stdout interface for driver for peripheral $stdout" "" "hsi_error"
       }
       set config_file [open "src/outbyte.c" w]
       puts $config_file "\#include \"xparameters.h\""
       puts $config_file [format "\#include \"%s\"\n" $header ]
       puts $config_file "\#ifdef __cplusplus"
       puts $config_file "extern \"C\" {"
       puts $config_file "\#endif"
       puts $config_file "void outbyte(char c); \n"
       puts $config_file "\#ifdef __cplusplus"
       puts $config_file "}"
       puts $config_file "\#endif \n"
       puts $config_file "void outbyte(char c) {"
       puts $config_file [format "\t %s(STDOUT_BASEADDRESS, c);" $outbyte_name]
       puts $config_file "}"
       close $config_file
       set config_file [::hsi::utils::open_include_file "xparameters.h"]
       set stdout_mem_range [::hsi::get_mem_ranges -of_objects $hw_proc_handle -filter "INSTANCE==$stdout && IS_DATA==1" ]
       if { [llength $stdout_mem_range] > 1 } {
           set stdout_mem_range [::hsi::get_mem_ranges -of_objects $hw_proc_handle -filter "INSTANCE==$stdout&& (BASE_NAME==C_BASEADDR||BASE_NAME==C_S_AXI_BASEADDR)"]
       }
       set base_name [common::get_property BASE_NAME $stdout_mem_range]
       set base_value [common::get_property BASE_VALUE $stdout_mem_range]
       puts $config_file "\#define STDOUT_BASEADDRESS [::hsi::utils::format_addr_string $base_value $base_name]"
       close $config_file
   }
}

proc ::hsi::utils::get_common_driver_ips {driver_handle} {
  set retlist ""
  set drs { }
  set class [common::get_property CLASS $driver_handle]
  if { [string match -nocase $class "sw_proc"] } {
      set hw_instance [common::get_property HW_INSTANCE $driver_handle]
      lappend retlist [::hsi::get_cells -hier $hw_instance]
  } else {
      set driver_name [common::get_property NAME $driver_handle]
	  if { [llength $driver_name] != 0 } {
      set drs [::hsi::get_drivers -filter "NAME==$driver_name"]
      foreach driver $drs {
           set hw_instance [common::get_property hw_instance $driver]
           set cell [::hsi::get_cells -hier $hw_instance]
           lappend retlist $cell
      }
  }
  }
  return $retlist
}

#
# this API return true if it is interrupting the current processor
#
proc ::hsi::utils::is_pin_interrupting_current_proc { periph_name intr_pin_name} {
    set ret 0
    set periph [::hsi::get_cells -hier "$periph_name"] 
    if { [llength $periph] != 1 } {
        return $ret
    }
    #get the list of connected 
    set intr_cntrls [::hsi::utils::get_connected_intr_cntrl "$periph_name" "$intr_pin_name"]
    foreach intr_cntrl $intr_cntrls {
        if { [::hsi::utils::is_ip_interrupting_current_proc $intr_cntrl] == 1} {
            return 1
        }
    }
   return [::hsi::__internal::special_handling_for_ps7_interrupt $periph_name]
}

#
# this API return true if any interrupt controller is connected to processor 
#and is available processor memory map
#
proc ::hsi::utils::get_current_proc_intr_cntrl { } {
    set current_proc [common::get_property HW_INSTANCE [::hsi::get_sw_processor] ]
    set proc_handle [::hsi::get_cells -hier $current_proc]
    set proc_ips [::hsi::utils::get_proc_slave_periphs $proc_handle]
    foreach ip $proc_ips {
        if {  [::hsi::utils::is_intr_cntrl $ip] == 1  
            && [::hsi::utils::is_ip_interrupting_current_proc $ip]} {
            return $ip
        }
    }
    Return ""
}

#
# this API return true if any at least one interrupt port of IP is reaching 
# to current processor
#
proc ::hsi::utils::is_ip_interrupting_current_proc { periph_name} {
   set ret 0 
   set periph [::hsi::get_cells -hier "$periph_name"]
   if { [llength $periph] != 1}  {
       return $ret
   }
   if { [::hsi::utils::is_intr_cntrl $periph_name] == 1} {
        set cntrl_driver [::hsi::get_drivers -filter "HW_INSTANCE==$periph_name"]
        #Interrupt controller should have a driver for current sw design
        if { [llength $cntrl_driver] != 1} {
            return 0
        }
        set current_proc [common::get_property HW_INSTANCE [::hsi::get_sw_processor]]
        set intr_pin [::hsi::get_pins -of_objects $periph "Irq"]
        if { [llength $intr_pin] != 0} {
            set sink_pins [::hsi::utils::get_sink_pins $intr_pin]
            foreach sink_pin $sink_pins {
                set connected_ip [::hsi::get_cells -of_objects $sink_pin]
                #Connected interface should be IP Instance
                #Connected IP should be current_processor
                set ip_name [common::get_property NAME $connected_ip]
                if { [string match -nocase "$ip_name" "$current_proc"] } {
                    return 1
                }
            }
        } else {
            #special handling for iomodule interrupt as currently we do not have
            #vlnv property into interface object
            set connected_intf [::hsi::utils::get_connected_intf $periph "INTC_Irq"]
            if { [llength $connected_intf] != 0 } {
                set connected_ip [::hsi::get_cells -of_objects $connected_intf] 
                #Connected interface should be IP Instance
                #Connected IP should be current_processor
                set ip_name [common::get_property NAME $connected_ip]
                if { [string match -nocase "ip_name" "$current_proc"] == 0 } {
                    return 1
                }
            }
        }
        if { [llength $intr_pin] == 0 } {
	        set intr_pin [::hsi::get_pins -of_objects $periph -filter "TYPE==INTERRUPT&&DIRECTION==O"]
        }
        if { [llength $intr_pin] != 0} {
            set sink_pins [::hsi::utils::get_sink_pins $intr_pin]
            foreach sink_pin $sink_pins {
                set connected_ip [::hsi::get_cells -of_objects $sink_pin]
                #Connected interface should be IP Instance
                #Connected IP should be current_processor
                set ip_name [common::get_property NAME $connected_ip]
                if { [string match -nocase "$ip_name" "$current_proc"] } {
                    return 1
                }
            }
        }
   } else {
       set intrs [::hsi::get_pins -of_objects $periph -filter "TYPE==INTERRUPT&&DIRECTION==O"]
       foreach intr $intrs {
           set intr_name [common::get_property NAME $intr]
           set flag [::hsi::utils::is_pin_interrupting_current_proc "$periph_name" "$intr_name"]
           if { $flag } {
               return 1
           }
       }
   }
   #TODO: Special hard coding for ps7 internal
   return [::hsi::__internal::special_handling_for_ps7_interrupt $periph_name]
}

################################################################################
## DTS Related common utils
################################################################################

proc ::hsi::utils::add_new_child_node { parent node_name } {
    set node [::hsi::get_nodes -of_objects $parent $node_name]
    if { [llength $node] } {
        ::hsi::delete_objs $node
    }
    set node [::hsi::create_node  $node_name $parent]
    return $node
}
proc ::hsi::utils::add_new_property { node  property type value } {
    set prop [::hsi::create_comp_param $property $value $node]
    common::set_property CONFIG.TYPE $type $prop
    return $prop
}

proc ::hsi::utils::add_new_dts_param { node  param_name param_value param_type {param_decription ""} } {
	if { $param_type != "boolean" && [llength $param_value] == 0 } {
		error "param_value can only be empty if the param_type is boolean, value is must for other data types"
	}
	if { $param_type == "boolean" && [llength $param_value] != 0 } {
                error "param_value can only be empty if the param_type is boolean"
        }
	common::set_property $param_name $param_value $node
	set param [common::get_property CONFIG.$param_name $node]
	common::set_property TYPE $param_type $param
	common::set_property DESC $param_decription $param
    return $param
}

proc ::hsi::utils::add_driver_properties { node driver } {
	set props [::hsi::get_comp_params -of_objects $driver]
	foreach prop $props {
	    set name [common::get_property NAME $prop]
	    set value [common::get_property VALUE $prop]
	    set type [common::get_property CONFIG.TYPE $prop]
	    ::hsi::utils::add_new_dts_param $node "$name" "$value" "$type"
	}
}

proc ::hsi::utils::get_os_parameter_value { param_name } {
    set value ""
    set global_params_node [::hsi::get_nodes -of_objects [::hsi::get_os] "global_params"]
    if { [llength $global_params_node] } {
        set value [common::get_property CONFIG.$param_name $global_params_node]
    }
    return $value
}
proc ::hsi::utils::set_os_parameter_value { param_name param_value } {
    set global_params_node [::hsi::get_nodes -of_objects [::hsi::get_os] "global_params"]
    if { [llength $global_params_node] == 0 } {
        set global_params_node [hsi::utils::add_new_child_node [::hsi::get_os] "global_params"]
    }
    common::set_property CONFIG.$param_name "$param_value" $global_params_node
}
proc ::hsi::utils::get_or_create_child_node { parent node_name } {
    set node [::hsi::get_nodes -of_objects $parent $node_name]
    if { [llength $node] == 0 } {
        set node [::hsi::create_node $node_name $parent]
    }
    return $node
}

proc ::hsi::utils::get_dtg_interrupt_info { ip_name intr_port_name } {
    set intr_info ""
    set ip [::hsi::get_cells -hier $ip_name]
    if { [llength $ip] == 0} {
        return $intr_info
    }
    if { [::hsi::utils::is_pin_interrupting_current_proc $ip_name "$intr_port_name" ] != 1 }  {
        return $intr_info
    }
    set intr_id [hsi::utils::get_interrupt_id $ip_name $intr_port_name]
    if { $intr_id  == -1 } {
        return $intr_info
    }
    set intc [::hsi::utils::get_connected_intr_cntrl $ip_name $intr_port_name]
    set intr_type [hsi::utils::get_dtg_interrupt_type $intc $ip $intr_port_name] 
    if { [string match "[common::get_property IP_NAME $intc]" "ps7_scugic"] } {
        if { $intr_id > 32 } {
            set intr_id [expr $intr_id -32]
        }
        set intr_info "0 $intr_id $intr_type"
    } else {
        set intr_info "0 $intr_id $intr_type"
    }
    return $intr_info
}

proc ::hsi::utils::get_dtg_interrupt_type { intc_name ip_name port_name } {
    set intc [::hsi::get_cells -hier $intc_name]
    set ip [::hsi::get_cells -hier $ip_name]
    if {[llength $intc] == 0 && [llength $ip] == 0} {
        return -1
    }
    set intr_pin [::hsi::get_pins -of_objects $ip $port_name]
    set sensitivity ""
    if { [llength $intr_pin] } {
        set sensitivity [common::get_property SENSITIVITY $intr_pin]
    }
    set intc_type [common::get_property IP_NAME $intc ]
    if { [string match -nocase $intc_type "ps7_scugic"] } {
		# Follow the openpic specification
		if { [string match -nocase $sensitivity "EDGE_FALLING"] } {
			return 2;
		} elseif { [string match -nocase $sensitivity "EDGE_RISING"] } {
			return 1;
		} elseif { [string match -nocase $sensitivity "LEVEL_HIGH"] } {
			return 4;
		} elseif { [string match -nocase $sensitivity "LEVEL_LOW"] } {
			return 8;
		}
	} else {
		# Follow the openpic specification
		if { [string match -nocase $sensitivity "EDGE_FALLING"] } {
			return 3;
		} elseif { [string match -nocase $sensitivity "EDGE_RISING"]  } {
			return 0;
		} elseif { [string match -nocase $sensitivity "LEVEL_HIGH"]  } {
			return 2;
		} elseif { [string match -nocase $sensitivity "LEVEL_LOW"]  } {
			return 1;
		}
	}
    return -1
}
proc ::hsi::utils::get_interrupt_parent {  ip_name port_name } {
    set intc [::hsi::utils::get_connected_intr_cntrl $ip_name $port_name]
    return $intc
}

proc ::hsi::utils::get_connected_stream_ip { ip_name intf_name } {
    set ip [::hsi::get_cells -hier $ip_name]
    if { [llength $ip] == 0 } {
        return ""
    }
    set intf [::hsi::get_intf_pins -of_objects $ip "$intf_name"] 
    if { [llength $intf] == 0 } {
        return ""
    }
    set intf_type [common::get_property TYPE $intf]

    set intf_net [::hsi::get_intf_nets -of_objects $intf]
    if { [llength $intf_net] == 0 } {
        return ""
    }
    set connected_intf_pin [lindex [::hsi::get_intf_pins -of_objects $intf_net -filter "TYPE!=$intf_type"] 0] 
    if { [llength $connected_intf_pin] } {
        set connected_ip [::hsi::get_cells -of_objects $connected_intf_pin]
        return $connected_ip
    }
    return ""
}

# This API returns the interrupt ID of a IP Pin
# Usecase: to get the ID of a top level interrupt port, provide empty string for ip_name
# Usecase: If port width port than 1 bit, then it will return multiple interrupts ID with ":" seperated
proc ::hsi::utils::get_interrupt_id { ip_name port_name } {
    set ret -1
    set periph ""
    set intr_pin ""
    if { [llength $port_name] == 0 } {
        return $ret
    }

    if { [llength $ip_name] != 0 } {
        #This is the case where IP pin is interrupting
        set periph [::hsi::get_cells -hier -filter "NAME==$ip_name"]
        if { [llength $periph] == 0 } {
            return $ret
        }
        set intr_pin [::hsi::get_pins -of_objects $periph -filter "NAME==$port_name"]
        if { [llength $intr_pin] == 0 } {
            return $ret
        }
        set pin_dir [common::get_property DIRECTION $intr_pin]
        if { [string match -nocase $pin_dir "I"] } {
          return $ret
        }
    } else {
        #This is the case where External interrupt port is interrupting
        set intr_pin [::hsi::get_ports $port_name]
        if { [llength $intr_pin] == 0 } {
            return $ret
        }
        set pin_dir [common::get_property DIRECTION $intr_pin]
        if { [string match -nocase $pin_dir "O"] } {
          return $ret
        }
    }

    set intc_periph [::hsi::utils::get_connected_intr_cntrl $ip_name $port_name]
    if { [llength $intc_periph]  ==  0 } {
        return $ret
    }

    set intc_type [common::get_property IP_NAME $intc_periph]
    set irqid [common::get_property IRQID $intr_pin]
    if { [llength $irqid] != 0 && [string match -nocase $intc_type "ps7_scugic"] } {
        set irqid [split $irqid ":"]
        return $irqid
    }

    # For zynq the intc_src_ports are in reverse order
    if { [string match -nocase "$intc_type" "ps7_scugic"]  } {
        set ip_param [common::get_property CONFIG.C_IRQ_F2P_MODE $intc_periph]
        set ip_intr_pin [::hsi::get_pins -of_objects $intc_periph "IRQ_F2P"]
        if { [string match -nocase "$ip_param" "REVERSE"] } {
            set intc_src_ports [lreverse [::hsi::utils::get_intr_src_pins $ip_intr_pin]]
        } else {
            set intc_src_ports [::hsi::utils::get_intr_src_pins $ip_intr_pin]
        }
        set total_intr_count -1
        foreach intc_src_port $intc_src_ports {
            set intr_periph [::hsi::get_cells -of_objects $intc_src_port]
            set intr_width [::hsi::utils::get_port_width $intc_src_port]
            if { [llength $intr_periph] } {
                #case where an a pin of IP is interrupt
                if {[common::get_property IS_PL $intr_periph] == 0} {
                    continue
                }
            }
            set total_intr_count [expr $total_intr_count + $intr_width]
        }
    } else  {
        set intc_src_ports [::hsi::utils::get_interrupt_sources $intc_periph]
    }

    #Special Handling for cascading case of axi_intc Interrupt controller
    set cascade_id 0
    if { [string match -nocase "$intc_type" "axi_intc"] } {
        set cascade_id [::hsi::__internal::get_intc_cascade_id_offset $intc_periph]
    }

    set i $cascade_id
    set found 0
    foreach intc_src_port $intc_src_ports {
        if { [llength $intc_src_port] == 0 } {
            incr i
            continue
        }
        set intr_width [::hsi::utils::get_port_width $intc_src_port]
        set intr_periph [::hsi::get_cells -of_objects $intc_src_port]
        if { [string match -nocase $intc_type "ps7_scugic"] && [llength $intr_periph]} {
            if {[common::get_property IS_PL $intr_periph] == 0 } {
                continue
            }
        }
        if { [string compare -nocase "$port_name"  "$intc_src_port" ] == 0 } {
            if { [string compare -nocase "$intr_periph" "$periph"] == 0 } {
                set ret $i
                set found 1
                break
            }
        }
        set i [expr $i + $intr_width]
    }

    if { [string match -nocase $intc_type "ps7_scugic"] && $found == 1  } {
        set ip_param [common::get_property CONFIG.C_IRQ_F2P_MODE $intc_periph]
        if { [string compare -nocase "$ip_param" "DIRECT"]} {
            set ret [expr $total_intr_count -$ret]
            if { $ret < 8 } {
                set ret [expr 91 - $ret]
            } elseif { $ret < 16} {
                set ret [expr 68 - ${ret} + 8 ]
            }
        } else {
            if { $ret < 8 } {
                set ret [expr $ret + 61]
            } elseif { $i  < 16} {
                set ret [expr $ret + 84 - 8]
            }
        }
    }
    # interrupt source not found, this could be case where IP interrupt is connected
    # to core0/core1 nFIQ nIRQ of scugic 
    if { $found == 0 && [string match -nocase $intc_type "ps7_scugic"]} {
        set sink_pins [::hsi::utils::get_sink_pins $intr_pin]
        lappend intr_pin_name;
        foreach sink_pin $sink_pins {
            set connected_ip [::hsi::get_cells -of_objects $sink_pin]
            set ip_name [common::get_property NAME $connected_ip]
            if { [string match -nocase "$ip_name" "ps7_scugic"] == 0 } {
                set intr_pin_name $sink_pin
            }
        }
        if {[string match -nocase "Core1_nIRQ" $sink_pin] || [string match -nocase "Core0_nIRQ" $sink_pin] } {
            set ret 31
        } elseif {[string match -nocase "Core0_nFIQ" $sink_pin] || [string match -nocase "Core1_nFIQ" $sink_pin] } {
           set ret 28
        }
    }

    set port_width [get_port_width $intr_pin]
    set id $ret
    for {set i 1 } { $i < $port_width } { incr i } {
       lappend ret [expr $id + 1]
       incr $id
    }
    return $ret
}

proc ::hsi::utils::get_connected_bus { periph_name intfs_pin} {
	set bus ""
	if { [llength [::hsi::get_cells -hier $periph_name]] == 0 } {
		return ""
	}
	set pin [::hsi::get_intf_pins -of_objects [::hsi::get_cells -hier $periph_name] $intfs_pin]
	if { $pin == "" } {
		return ""
	}
	
	set version [common::get_property VIVADO_VERSION [::hsi::current_hw_design]]
	if { [llength $version] <= 0 } {
		return ""
	}
	set is_pl [common::get_property IS_PL [::hsi::get_cells -hier $periph_name]]
	set is_ps true
	if { [string match -nocase $is_pl "true"] || [string match -nocase $is_pl "1"]} {
		set is_ps false
	}
	if { $version < 2014.4 || $is_ps} {
		#for old type of designs.
		set intf_pins [::hsi::get_intf_nets -of_objects $pin]
		if { [llength $intf_pins] == 0} {
			return ""
		}
		if { [llength [::hsi::get_cells -hier $intf_pins]] == 0} {
			return ""
		}
		set type [common::get_property IP_TYPE [::hsi::get_cells -hier $intf_pins]]
		if { $type == "BUS" } {
			set bus $intf_pins
			return $bus
		}
	} elseif { [llength $version] > 0 && $version >= 2014.4 } {
		#for new type of designs.
		set intf_pins [::hsi::get_intf_nets -of_objects $pin]
		if { [llength $intf_pins] == 0} {
			return ""
		}
		set ::hsi::get_pins [::hsi::get_intf_pins -of_objects $intf_pins]
		if { [llength $::hsi::get_pins] == 0} {
			return ""
		}
		set second_pin [lindex $::hsi::get_pins 0]
		if { [string match -nocase $second_pin $intfs_pin] } {
			set second_pin [lindex $::hsi::get_pins 1]
		}
		set type [common::get_property IP_TYPE [::hsi::get_cells -of_objects $second_pin]]
		if { $type == "BUS" } {
			set bus [::hsi::get_cells -of_objects $second_pin]
			return $bus
		}
	}
	return $bus
}



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
