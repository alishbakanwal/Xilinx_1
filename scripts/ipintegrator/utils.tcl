###########################################################################
# General utils

namespace eval ::bd::utils {
  variable auto_connect_clkrst
  set auto_connect_clkrst 1

  namespace export \
    get_short_name \
    get_parent \
    is_empty \
    not_empty \
    is_pin_port \
    is_intf_pin_port \
    get_intf_pin_port \
    is_sink \
    is_src \
    create_unique_port \
    create_unique_intf_port \
    create_unique_cell \
    is_connected \
    is_ipi_obj \
    is_driven \
    get_first \
    find_true_intf \
    is_intf_connected \
    find_axi_interconnect_connected_to \
    am_I_in_interconnect
}


# ------------------------------------------------------------------------
## 
# Get the short name of an object. Given an object e.g. /design/hier/myblock
# returns "myblock". Will also work on any string with the /a/b/c pattern
# @param obj A IPI object, e.g. cell, intf. (or string)
# @return The short name of the object (string)
proc ::bd::utils::get_short_name {obj} {
  #NB using regexp maybe faster... need to investigate
  #return [string range $obj [expr [string last / $obj] + 1 ] end]

  return [lindex [split $obj /] end]
}

##
# Given an object, return its parent. E.g. object /a/b/c/d has parent /a/b/c
# Will also work on any string with the /a/b/c/ pattern
# @param obj An IPI object: cell, intf, pin, port, address (or string)
# @return The parent cell object. Returns "" if obj is contained by root design
proc ::bd::utils::get_parent {obj} {
  #set c [string range $obj 0 [expr [string last / $obj] - 1]]
  #if { $c == "" || $c == "/" } {
  #  return ""
  #} 

  set c [join [lrange [split $obj /] 0 end-1] /]
  if { $c == "" || $c == "/" } {
    return ""
  }
  return [get_bd_cells -quiet $c]
}

##
# Split path will split a give string path into 2 portions
# Note that head and tail are actual variable names
# not values
# e.g. 
# set path a/b/c/d
# split_[path $path head tail
# returns head = a/b/c/
#         tail = d
# e.g. 
# set path  a
# split_path $a head tail
# returns head = 
#         tail a
# @param path The path you wish to split into parts
# @param head The name of the variable in caller scope to put 
#             the head part of the path
# @param tail The name of the variable in caller scope to put
#             the tail part of the path
proc ::bd::utils::split_path {path head tail} {
  upvar 1 $head hd $tail tl

  set last [string last / $path]
  set hd [string range $path 0 $last]
  set tl [string range $path [expr $last + 1] end]
  return
}

##
# Given a object, figure out if it is an IPI object 
# @param obj An object
# @return 0 if not an IPI object, 1 otherwise
proc ::bd::utils::is_ipi_obj {obj} {
  if { [catch { set class [get_property CLASS $obj] } ] } {
    set ::errorInfo ""
    return 0
  }
  return 1
}

##
# Given a tcl object return 1 if the object is an empty list or ""
# Same as calling "[llength $obj] == 0" but more declaratively 
# @param obj Any object, string, list etc
proc ::bd::utils::is_empty {obj} {
  if { [string equal $obj ""] } {
    return 1
  } else {
    return 0
  }
  # The above code is roughly 9-10x faster than below
  #  return [expr [llength $obj] == 0]
}

##
# Given a tcl object return if the object is not empty list or ""
# same as calling "[llength $obj]" but more decalrative
# @param obj Any object, string, list etc
proc ::bd::utils::not_empty {obj} {
  if { $obj != "" } {
    return 1
  } else {
    return 0
  }
}

##
# Commands like get_bd_cells may return a list of FCO, 1 FCO
# or nothing. get_first extracts out the first FCO regardless.
proc ::bd::utils::get_first {obj} {
  if {[llength $obj] > 1} {
    return [lindex $obj 0]
  } else {
    return $obj
  }
}

##
# 
proc ::bd::utils::return_list {obj} {
  if {[llength $obj] >0} {
    return $obj
  } else {
    return [list $obj]
  }
}

##
# Returns true if object is an IPI pin or port
proc ::bd::utils::is_pin_port {obj} {
  if { [catch {set class [get_property CLASS $obj]}] } {
    return 0
  } 
  if { [string equal $class "bd_pin"] } {
    return 1
  }
  if { [string equal $class "bd_port"] } {
    return 1
  }

  return 0
}

##
# Returns true if object is an IPI interface_pin or port
proc ::bd::utils::is_intf_pin_port {obj} {
  if { [catch {set class [get_property CLASS $obj]}] } {
    return 0
  } 
  if { [string equal $class "bd_intf_pin"] } {
    return 1
  }
  if { [string equal $class "bd_intf_port"] } {
    return 1
  }

  return 0
}

## 
# Returns trus if pin/port is a sink
proc ::bd::utils::is_sink {obj} {
  if { [catch {set class [get_property CLASS $obj]}] } {
    return 0
  } 
  if { [string equal $class "bd_pin"] } {
    set dir [get_property DIR $obj]
    if {[string equal $dir I]} {
      return 1
    }
  }
  if { [string equal $class "bd_port"] } {
    set dir [get_property DIR $obj]
    if {[string equal $dir O]} {
      return 1
    }
  }

  return 0
}

# 
# Returns trus if pin/port is a src
proc ::bd::utils::is_src {obj} {
  if { [catch {set class [get_property CLASS $obj]}] } {
    return 0
  } 
  if { [string equal $class "bd_pin"] } {
    set dir [get_property DIR $obj]
    if {[string equal $dir O]} {
      return 1
    }
  }
  if { [string equal $class "bd_port"] } {
    set dir [get_property DIR $obj]
    if {[string equal $dir I]} {
      return 1
    }
  }

  return 0
}


## 
# Create uniquely named ports 
# @param name The name that is to be used
# @param args All args will be passed verbatim to the create_bd_ports command
# @return The created object
proc ::bd::utils::create_unique_port {name args} {
  set obj [get_bd_ports -quiet $name]
  set num 0
  set name_stem $name
  set unq_name $name
  if {[string length $obj] != 0} {
    set underscore [string last _ $name]
    if { $underscore != -1 } {
      set endbit [string range $name [expr $underscore + 1] end]
      if { [string is integer $endbit] } {
        set num $endbit
        set name_stem [string range $name 0 [expr $underscore - 1]]
      }
    }

    incr num
    set unq_name ${name_stem}_${num}
    while { [string length [get_bd_ports -quiet $unq_name]] != 0 } {
      incr num
      set unq_name ${name_stem}_${num}
    }
  }

  set cmd "create_bd_port "
  foreach arg $args {
    set cmd "$cmd $arg"
  }
  set cmd "$cmd $unq_name"
  set obj [eval $cmd]
  return $obj
}

## 
# Create uniquely named intf_ports 
# @param name The name that is to be used
# @param args All args will be passed verbatim to the create_bd_intf_ports command
# @return The created object
proc ::bd::utils::create_unique_intf_port {name args} {
  set obj [get_bd_intf_port -quiet $name]
  set num 0
  set name_stem $name
  set unq_name $name
  if {[string length $obj] != 0} {
    set underscore [string last _ $name]
    if { $underscore != -1 } {
      set endbit [string range $name [expr $underscore + 1] end]
      if { [string is integer $endbit] } {
        set num $endbit
        set name_stem [string range $name 0 [expr $underscore - 1]]
      }
    }

    incr num
    set unq_name ${name_stem}_${num}
    while { [string length [get_bd_intf_port -quiet $unq_name]] != 0 } {
      incr num
      set unq_name ${name_stem}_${num}
    }
  }
  bd::utils::dbg "unq_name : $unq_name"

  set cmd "create_bd_intf_port "
  foreach arg $args {
    set cmd "$cmd $arg"
  }
  bd::utils::dbg "cmd : $cmd $unq_name"
  set cmd "$cmd $unq_name"
  set obj [eval $cmd]
  return $obj
}


##
# Create uniquely named cell
# special case for aximm interconnect since get_ipdefs doesn't
# @param ip The VLNV of the cell to create
# @param name The starting name
# @return The created cell
proc ::bd::utils::create_unique_cell {ip cellname} {
  set name [string map -nocase { processing_system7 ps7 zynq_ultra_ps_e ps8 } $cellname ]
  set obj [get_bd_cells -quiet $name]
  set num 0
  set name_stem $name
  set unq_name $name
  if {[string length $obj] != 0} {
    set underscore [string last _ $name]
    if { $underscore != -1 } {
      set endbit [string range $name [expr $underscore + 1] end]
      if { [string is integer $endbit] } {
        set num $endbit
        set name_stem [string range $name 0 [expr $underscore - 1]]
      }
    }

    incr num
    set unq_name ${name_stem}_${num}
    while { [string length [get_bd_cells -quiet $unq_name]] != 0 } {
      incr num
      set unq_name ${name_stem}_${num}
    }
  }

  if { [string compare $ip axi_interconnect] == 0 } {
    set obj  [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect -set_param { "CONFIG.NUM_MI" "1" } $unq_name]
    return $obj
  } elseif {[string compare $ip smartconnect] == 0} {
    set vlnv [get_ipdefs -filter "VLNV=~xilinx.com:ip:${ip}:*"]
    set obj  [create_bd_cell -type ip -vlnv $vlnv -set_param { "CONFIG.NUM_SI" "1" } $unq_name]
    return $obj
  } else {
    set vlnv [get_ipdefs -filter "VLNV=~xilinx.com:ip:${ip}:*"]
    set obj  [create_bd_cell -type ip -vlnv $vlnv $unq_name]
    return $obj
  }

}


## 
# Checks if 2 pins/ports or intf_pins/intf_ports are connected.
# Searches across hierarchy.
# returns 0 if p1 or p2 are empty, or are not pins or ports
# @param p1 pin or port object or fully qualified name
# @param p2 pin or port object
# @return 1 if connected, 0 otherwise
proc ::bd::utils::is_connected {p1 p2} {
  if { [is_empty $p1] || [is_empty $p2] } {
    return 0
  }
  # try as intf
  set intf [get_bd_intf_pins -quiet $p1]
  if {[is_empty $intf]} {
    set intf [get_bd_intf_ports -quiet $p1]
  }
  if {[not_empty $intf]} {
    set objs [find_bd_objs -quiet -legacy_mode -relation connected_to $intf]
    set f [filter  [find_bd_objs -quiet -legacy_mode -relation connected_to $intf] "NAME == $p2" ]
    if { [not_empty $f] } {
      return 1
    } 
    return 0
  }
  # try pin
  set pin [get_bd_pins -quiet $p1]
  if {[is_empty $pin]} {
    set pin [get_bd_ports -quiet $p1]
  }
  if {[not_empty $pin]} {
    set f [filter [find_bd_objs -quiet -legacy_mode -relation connected_to $pin] "NAME == $p2"]
    if { [not_empty $f] } {
      return 1
    } 
  }

  return 0
}


##
# Given a sink pin, returns 1 if it is driven by a net, 0 otherwise.
proc ::bd::utils::is_driven {p1} {
  #set net [get_bd_nets -quiet -of_objects $p1]
  set conn_obj [find_bd_objs -quiet -legacy_mode -relation connected_to $p1]
  if {[not_empty $conn_obj]} {
    #dbg "is_driven : object $p1 is driven by $conn_obj"
    return 1
  }
  return 0
}

# ---------------------------------------------------------------
# Higher order functions

## 
# Implements map functionality. Applies the lambda fn to the list
# of args
# e.g. Call the get_parent function on each item in a list.
# bd::utils::map {x {return [bd::utils::get_parent $x]}} [list $a $b $c]
#
# @param lambda An anonymous function to apply on the list
# @param larg List of args to apply lambda function on
proc ::bd::utils::map {lambda larg {cull_empty 0}} {
  set result {}
  foreach i $larg {
    set tmp [apply $lambda $i]
    if {$cull_empty} {
       if {[bd::utils::not_empty $tmp]} {
          lappend result $tmp
       }
    } else { 
      lappend result $tmp
    }
  }
  return $result
}

proc ::bd::utils::autoconn_clkrst {val} {
  if { ($val eq 1) || ($val eq "true") || ($val eq "yes") } {
    set ::bd::utils::auto_connect_clkrst 1
  } else {
    set ::bd::utils::auto_connect_clkrst 0
  }
  return
}

proc ::bd::utils::find_true_intf { intf } {
  set true_intf [find_bd_objs -quiet -legacy_mode -relation connected_to -boundary_type lower $intf]
  if { [::bd::utils::is_empty $true_intf] } {
    set true_intf $intf
  }
  return $true_intf
}

proc ::bd::utils::is_intf_connected { intf } {
  set nNets [get_bd_intf_nets -quiet -of_objects $intf]
  if { [::bd::utils::is_empty $nNets] } {
    return false
  }

  set class [get_property CLASS $intf]
  set intfPort 0
  if { $class == "bd_intf_port" } {
    set intfPort 1
  }
  set mode [get_property MODE $intf]
  # check if this object is already connected to a valid
  # interface (exclude monitor interfaces) of opposite mode
  set endBifs ""
  if { ( ($intfPort eq 1) && ($mode == "Slave") ) || ( ($intfPort eq 0) && ($mode == "Master") ) } {
    set endBifs [get_bd_intf_pins -quiet -of_objects $nNets \
                   -filter {MODE!="Monitor" && MODE=="Slave"}]
  } else {
    set endBifs [get_bd_intf_pins -quiet -of_objects $nNets \
                   -filter {MODE!="Monitor" && MODE=="Master"}]
  }

  if { [llength $endBifs] > 0 } {
    return true
  }

  return false
}

proc ::bd::utils::find_axi_interconnect_connected_to { intf } {
  set endIntf [bd::util_cmd -stop_on_appcore getEndIntf $intf]
  if { [::bd::utils::is_empty $endIntf] } {
    return ""   
  }

  set parent [::bd::utils::get_parent $endIntf]
  if { [::bd::utils::not_empty $parent] } {
    set isInterconnect [filter $parent {VLNV =~ "xilinx.com:ip:axi_interconnect:*" || VLNV =~ "xilinx.com:ip:smartconnect:*"}]
    if { [llength $isInterconnect] > 0 } {
      return $parent
    }
  }
  return ""   
}

proc ::bd::utils::am_I_in_interconnect { cell } {
  set isInterconnect [filter $cell {VLNV =~ "xilinx.com:ip:axi_interconnect:*" || VLNV =~ "xilinx.com:ip:smartconnect:*"}]
  if {[llength $isInterconnect] > 0 } {
    return $isInterconnect
  }

  set parent [::bd::utils::get_parent $cell]
  if {[llength $parent] ==0} {
    return ""
  }
  return [::bd::utils::am_I_in_interconnect $parent]
}

proc ::bd::utils::get_intf_pin_port { obj intfPort } {
  set fco ""
  if { $intfPort eq 1 } {
    set fco [get_bd_intf_ports -quiet $obj]
  } else {
    set fco [get_bd_intf_pins -quiet $obj]
  }

  return $fco
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
