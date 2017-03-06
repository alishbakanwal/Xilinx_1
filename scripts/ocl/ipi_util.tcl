# Copyright 2013 Xilinx, Inc. All rights reserved.
#
# This file contains confidential and proprietary information
# of Xilinx, Inc. and is protected under U.S. and
# international copyright and other intellectual property
# laws.
#
# DISCLAIMER
# This disclaimer is not a license and does not grant any
# rights to the materials distributed herewith. Except as
# otherwise provided in a valid license issued to you by
# Xilinx, and to the maximum extent permitted by applicable
# law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
# WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
# AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
# BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
# INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
# (2) Xilinx shall not be liable (whether in contract or tort,
# including negligence, or under any other theory of
# liability) for any loss or damage of any kind or nature
# related to, arising under or in connection with these
# materials, including for any direct, or any indirect,
# special, incidental, or consequential loss or damage
# (including loss of data, profits, goodwill, or any type of
# loss or damage suffered as a result of any action brought
# by a third party) even if such damage or loss was
# reasonably foreseeable or Xilinx had been advised of the
# possibility of the same.
#
# CRITICAL APPLICATIONS
# Xilinx products are not designed or intended to be fail-
# safe, or for use in any application requiring fail-safe
# performance, such as life-support or safety devices or
# systems, Class III medical devices, nuclear facilities,
# applications related to the deployment of airbags, or any
# other applications that could lead to death, personal
# injury, or severe property or environmental damage
# (individually and collectively, "Critical
# Applications"). Customer assumes the sole risk and
# liability of any use of Xilinx products in Critical
# Applications, subject only to applicable laws and
# regulations governing limitations on product liability.
#
# THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
# PART OF THIS FILE AT ALL TIMES.

# Globals
array unset gRegions
array unset gDebugNets
array unset gPerfMonPorts
set gPerfMonRegion ""
set gAddrSegs [dict create]

proc find_connected_intf_pin { start_pin } {
  set net [get_bd_intf_nets -of_objects $start_pin]
  set pins [get_bd_intf_pins -of_objects $net]
  set idx [lsearch $pins $start_pin]
  set pins [lreplace $pins $idx $idx]

  if { [llength $pins] != 1 } {
    puts "ERROR: find_connected_intf_pin : net is not point to point"
    return
  }
  return [lindex $pins 0]
}

################################################################################
# Collect properties of existing regions
################################################################################
proc probe_base_platform { } {
  global ::gRegions
  set regions  [get_bd_cells -hierarchical -filter {VLNV == xilinx.com:ip:xcl_region:1.0}]
  foreach region $regions {
    #region is marked by ocl_region core in OCL_REGION hierarhcy, ie /OCL_REGION/OCL_REGION
    array unset dregion
    set ports [get_bd_cells -of_objects $region]
    set hier_prefix [regexp -inline {.*/+} $region]
    set formatRegionName [string range $region [string length $hier_prefix] end]

    # Iterate over port terminators
    foreach port $ports {
      array unset dport
      set formatName [regexp -inline {[^/]*(?=_TERM$)} $port]

      # Determine the type of the port
      set is_master 2
      if {[get_property VLNV $port] == "xilinx.com:ip:axi_master_term:1.0"} {
        set is_master 1
        set dport("mode") "master"
      } elseif {[get_property VLNV $port] == "xilinx.com:ip:axi_slave_term:1.0"} {
        set is_master 0
        set dport("mode") "slave"
      } else {
        puts "ERROR! Invalid port"
      }

      # Get clock frequency
      set clkp [get_bd_pins -of_objects $port -filter {TYPE==clk}]
      set clkfreq [get_property CONFIG.FREQ_HZ $clkp]
      set dregion("clkfreq") $clkfreq

      # Get associated the port pin
      set port_pin [get_bd_intf_pins -of_objects $port]
      if { [llength $port_pin] != 1 } {
        puts "ERROR: more than one interface pin found"
      }

      # Get port properties
      set dataWidth [get_property CONFIG.DATA_WIDTH $port_pin]
      set dport("dataWidth") $dataWidth
      set protocol [get_property CONFIG.PROTOCOL $port_pin]
      set dport("protocol") $protocol
      set idWidth [get_property CONFIG.ID_WIDTH $port_pin]
      set dport("idWidth") $idWidth
      set addrWidth [get_property CONFIG.ADDR_WIDTH $port_pin]
      set dport("addrWidth") $addrWidth
      set userWidth [get_property CONFIG.ARUSER_WIDTH $port_pin]
      if { $userWidth != [get_property CONFIG.AWUSER_WIDTH $port_pin] ||
           $userWidth != [get_property CONFIG.BUSER_WIDTH $port_pin]  ||
           $userWidth != [get_property CONFIG.RUSER_WIDTH $port_pin]  ||
           $userWidth != [get_property CONFIG.WUSER_WIDTH $port_pin]  } {
             puts "ERROR: User widths must be the same!"
           }
      set dport("userWidth") $userWidth
      set maxBurstLength [get_property CONFIG.MAX_BURST_LENGTH $port_pin]
      set dport("maxBurstLength") $maxBurstLength

      # Get the connected interconnect
      set internal_connect [find_connected_intf_pin $port_pin]
      set external_connect [find_connected_intf_pin $internal_connect]
      set postfix [string range $external_connect [string length $hier_prefix] end]
      #set topmod [get_bd_cell [regexp -inline {^[^/]*} $postfix]]
      set topmod [get_bd_cell [regexp -inline {^/[^/]*/[^/]*} $external_connect]]
      if {$topmod != "" && [get_property VLNV $topmod] == "xilinx.com:ip:axi_interconnect:2.1"} {
      } else {
        # A direct connection
      }
      set dport("connection") $topmod

      # Get Address Ranges
      if {$is_master == 1} {
        set segs [get_bd_addr_segs -of_objects $port_pin]
        set slsegs [get_bd_addr_segs -of_objects $segs]
        set daddrsegs {}

        set i 0
        foreach slave $slsegs {
          set seg [lindex $segs $i]
          lappend daddrsegs [list name $slave baddr [get_property OFFSET $seg] range [get_property RANGE $seg]]
          set i [expr $i + 1]
        }
      # Slave Address Blocks
      } elseif {$is_master == 0} {
        set daddrsegs {}
        set segs [get_bd_addr_segs -of_objects $port_pin]
        set slsegs [get_bd_addr_segs -of_objects $segs]
        set daddrsegs {}

        foreach slave $slsegs {
          lappend daddrsegs [list name $slave baddr [get_property OFFSET $slave] range [get_property RANGE $slave]]
        }

        set masters [find_bd_objs -relation ADDRESSING_MASTER $port_pin]
        if {[llength $masters] > 1} {
          puts "ERROR: Only one master supported per slave port"
        }
        set class [get_property CLASS $masters]
        if {$class == "bd_intf_port"} {
          set dport("addrspace") $masters
        } else {
          set mstInst [string range $masters [string length $hier_prefix] end]
          set mstPort [regexp -inline {[^/]*$} $mstInst]
          set mstInst [regexp -inline {^[^/]*} $mstInst]
          set segname [get_bd_addr_spaces -of_objects $masters]
          set dport("addrspace") $segname
        }
      }
      set dport("addrsegs") $daddrsegs
      set dports($formatName) [array get dport]
    }

    # Get CLOCK/ARESETN pins
    set clkpin [get_bd_pins "$region/ACLK"]
    set clknet [get_bd_nets -of_objects $clkpin]
    set dregion("clk") $clknet

    set rstpin [get_bd_pins "$region/ARESETN"]
    set rstnet [get_bd_nets -of_objects $rstpin]
    set dregion("aresetn") $rstnet

    set dregion("ports") [array get dports]
    set gRegions($formatRegionName) [array get dregion]
  }

  # DEBUG OUTPUT
#  puts "PRINT ALL REGIONS"
#  foreach region [array names gRegions] {
#    array set properties $gRegions($region)
#    foreach property [array names properties] {
#      if { $property == "\"ports\"" } {
#        array set aports $properties($property)
#        foreach port [array names aports] {
#          puts " PORT: $port"
#          array set aportprop $aports($port)
#          foreach portp [array names aportprop] {
#            puts "  $portp is $aportprop($portp)"
#          }
#        }
#      } else {
#        puts " $property = $properties($property)"
#      }
#    }
#  }
#  puts "END PRINT ALL REGIONS"

}


proc get_region_clk_net {regionName} {
  global ::gRegions
  array set aregion $gRegions($regionName)
  return $aregion("clk")
}
proc get_region_rst_net {regionName} {
  global ::gRegions
  array set aregion $gRegions($regionName)
  return $aregion("aresetn")
}

proc disconnect_pin_by_name {name} {
  set pin [get_bd_pins $name]
  set pinnet [get_bd_nets -of_objects $pin]
  if {[llength $pinnet] != 0} {
    disconnect_bd_net $pinnet $pin
  }
}

################################################################################
# get_free_axi_ic_port:
#   Checks an AXI Interconnect for a free slave or master port. If one exists
#   it is returned. If one does not exist, the AXI Interconnect is expanded
#
#   Parameters:
#     axiic : AXI Interconnect Instance
#     type : (slave|master)
################################################################################
proc get_free_axi_ic_port {axiic type} {

  set prefix ""
  if {$type == "master"} {
    set prefix "M"
  } elseif {$type == "slave"} {
    set prefix "S"
  }

  set num_i [get_property "CONFIG.NUM_${prefix}I" $axiic]

  # Check all pins to see if they are used
  for {set i 0} {$i < $num_i} {incr i} {
    set pinname [format "$axiic/${prefix}%.2d_AXI" $i]
    set pin [get_bd_intf_pins $pinname]

    # Usage defined by "connected_to" relation
    set connection [find_bd_objs -relation CONNECTED_TO $pin]
    if {[llength $connection] == 0} {
      # Disconnect clk/reset if they are connected
      disconnect_pin_by_name [format "/$axiic/${prefix}%.2d_ACLK" $i]
      disconnect_pin_by_name [format "/$axiic/${prefix}%.2d_ARESETN" $i]
      return $pin
    }
  }

  # No unused pins found, create new one
  set_property "CONFIG.NUM_${prefix}I" [expr $num_i + 1] $axiic
  set pinname [format "$axiic/${prefix}%.2d_AXI" $num_i]
  set pin [get_bd_intf_pins $pinname]
  return $pin
}


################################################################################
# inst_kernel:
#   Instantiates a kernel of a given type and connects clock/reset. Expects HLS
#   core with one clock and reset pin
#
#   Parameters:
#     name : string
#     vlnv : string 
#     params : pairList
#     region : list of region properties
#
################################################################################
proc  inst_kernel {name vlnv {params []} lregion} {
  global ::gRegions

  # Create the cell
  if { ![llength [get_ipdefs -all $vlnv]] } {
    error "Cound not find kernel IP '$vlnv' in IP catalog"
  }
  set obj [create_bd_cell -vlnv $vlnv -type ip -name "${lregion}/${name}"]

  # Set properties
  if {[llength $params] > 1} {
    array set plparams $params
    foreach param [array names plparams] {
      set_property "CONFIG.$param" $plparams($param)  $obj
    }
  }

  # Create clk/reset
  array set aregion $gRegions($lregion)
  set instclkpin [get_bd_pins -of_objects $obj -filter {TYPE == clk}]
  connect_bd_net -net $aregion("clk") $instclkpin
  set instrstpin [get_bd_pins -of_objects $obj -filter {TYPE ==rst}]
  connect_bd_net -net $aregion("aresetn")  $instrstpin

  return "${lregion}/${name}"
}

################################################################################
# connect_kernel
#   Creates a connection between srcInst.srcPort to dstInst.dstPort
#
#   Parameters:
#     srcInst : string
#     srcPort : string
#     dstInst : string
#     dstPort : string
#     laddrsegs : pairList of (inst, addrseg)
################################################################################
proc connect_kernel {srcInst srcPort dstInst dstPort laddrsegs debug lregion} {
  global ::gRegions
  global ::gDebugNets
  global ::gPerfMonPorts
  global ::gPerfMonRegion
  global ::gAddrSegs

  set isSrcRegion 0
  set isDstRegion 0
  set isSrcMemory 0
  set isDstMemroy 0

  array set aregion $gRegions($lregion)

  set match [array names gRegions -exact $srcInst]
  # Src is region
  if {$match != ""} {
    set isSrcRegion 1
    set RegionClk [get_region_clk_net $srcInst]
    set srcProperties [connect_kernel_region $srcInst $srcPort "slave"]
    set SrcPortBD [lindex $srcProperties 0]
    set SrcAddrSpace [lindex $srcProperties 1]
  } else {
    # Src is memory
    if {[string compare -nocase -length 8 $srcPort "XCL_MEM_"] == 0} {
      set isSrcMemory 1
      set SrcPortBD [get_free_axi_ic_port [get_bd_cell $srcInst] "slave"]
      regsub {_AXI$} $SrcPortBD "" PortBDRoot
      set targetpin [get_bd_pins -of_objects $aregion("clk") -filter {DIR == O}]
      connect_bd_net -net $aregion("clk") [get_bd_pins "${PortBDRoot}_ACLK"] $targetpin
    } else {
      set SrcPortBD [get_bd_intf_pins "$srcInst/$srcPort"]
    }
    set SrcAddrSpace [get_bd_addr_spaces -of_objects $SrcPortBD]
  }

  # Dst is a region
  set match [array names gRegions -exact $dstInst]
  if {$match != ""} {
    set isDstRegion 1
    set RegionClk [get_region_clk_net $dstInst]
    set dstProperties [connect_kernel_region $dstInst $dstPort "master"]
    set DstPortBD [lindex $dstProperties 0]
    set DstAddrSpace [lindex $dstProperties 1]
  } else {
    if {[string compare -nocase -length 8 $dstPort "XCL_MEM_"] == 0} {
      set isDstMemory 1
      set DstPortBD [get_free_axi_ic_port [get_bd_cell $dstInst] "slave"]
      regsub {_AXI$} $DstPortBD "" PortBDRoot
      set targetpin [get_bd_pins -of_objects $aregion("clk") -filter {DIR == O}]
      connect_bd_net -net $aregion("clk") [get_bd_pins "${PortBDRoot}_ACLK"] $targetpin
      set targetpin [get_bd_pins -of_objects $aregion("aresetn") -filter {DIR == O}]
      connect_bd_net -net $aregion("aresetn") [get_bd_pins "${PortBDRoot}_ARESETN"] $targetpin
      set addrsegs [get_bd_addr_segs -of_objects [get_bd_addr_spaces "${dstInst}_ctrl/S_AXI"]]
    } else {
      set DstPortBD [get_bd_intf_pins "$dstInst/$dstPort"]
      set addrsegs [get_bd_addr_segs -of_objects $DstPortBD]
      set count_pin [get_bd_pins -quiet "${SrcPortBD}_count"]
      if { [llength $count_pin] } {
        if {[string compare -nocase $dstPort "S_AXIS"] == 0} {
          connect_bd_net [get_bd_pins $count_pin] [get_bd_pins "${dstInst}/axis_wr_data_count"]
        } elseif {[string compare -nocase $dstPort "M_AXIS"] == 0} {
          connect_bd_net [get_bd_pins $count_pin] [get_bd_pins "${dstInst}/axis_rd_data_count"]
        }
      }
    }

    # There should only be one segment if any
    if {[llength $addrsegs] == 1} {
      array set aaddrsegs $laddrsegs
      set DstAddrSpace [list [concat [list name $addrsegs] $aaddrsegs($dstInst)] ]
    }
  }

  puts "Connect $SrcPortBD -> $DstPortBD"
  connect_bd_intf_net $SrcPortBD $DstPortBD

  # Set debug and/or performance monitoring
  if { ($debug == 1 || $debug == 3) && ($isSrcRegion == 1 || $isDstRegion == 1) } {
    if { $isSrcRegion == 1 } {
      set debugNet [get_bd_intf_nets -of $DstPortBD]
      puts "Mark $debugNet as DEBUG"
      set_property HDL_ATTRIBUTE.MARK_DEBUG true $debugNet
      set hier_prefix [regexp -inline {.*/+} $debugNet]
      set formatName [string range $debugNet [string length $hier_prefix] end]
      set gDebugNets($formatName) [list $RegionClk ${dstInst}_${dstPort} $debug]
    } elseif { $isDstRegion == 1 } {
      set debugNet [get_bd_intf_nets -of $SrcPortBD]
      puts "Mark $debugNet as DEBUG"
      set_property HDL_ATTRIBUTE.MARK_DEBUG true $debugNet
      set hier_prefix [regexp -inline {.*/+} $debugNet]
      set formatName [string range $debugNet [string length $hier_prefix] end]
      set gDebugNets($formatName) [list $RegionClk ${srcInst}_${srcPort} $debug]
    }
  } elseif { $debug == 2 || $debug == 3 } {
    if {[get_property CONFIG.PROTOCOL $SrcPortBD] == "AXI4"} {
      puts "Adding port $SrcPortBD to device profiling..."
      lappend gPerfMonPorts $SrcPortBD
      set gPerfMonRegion $lregion
    }
  }

  puts "Creating address segments"
  # Create address segments
  if { [info exists DstAddrSpace] && [info exists SrcAddrSpace] } {
    set segcnt 0
    foreach seg $DstAddrSpace {
      puts "Segment $seg"
      array set asegd $seg
      set segn $asegd(name)
      set segend [regexp -inline {[^/]*$} "$segn"]
      # Avoid creating the same segment twice.  This can happen
      # when connecting multiple ports of the same kernel to the
      # same address space.
      set keyname "${SrcAddrSpace}_${segn}"
      if { [dict exists $gAddrSegs $keyname] } {
        continue
      } else {
        dict set gAddrSegs $keyname 1
      }
      set segname "${srcInst}_${srcPort}_${dstInst}_${dstPort}_${segend}_${segcnt}"
      set prange $asegd(range)
      set poffset $asegd(baddr)
      set pseg [get_bd_addr_segs $segn]
      puts "create_bd_addr_seg -range $prange -offset $poffset $SrcAddrSpace $pseg $segname"
      create_bd_addr_seg -range $asegd(range) -offset $asegd(baddr) $SrcAddrSpace [get_bd_addr_segs $segn] $segname
      set segcnt [expr $segcnt + 1]
    }
  }
}

################################################################################
################################################################################

proc generate_debug_cores { } {
  global ::gDebugNets

  set i 0
  foreach debugnet [array names gDebugNets] {
    set ila_name u_ila_$i
    set probenum 0

    # Get clock net
    set clkregion [lindex $gDebugNets($debugnet) 0]
    set hier_prefix [regexp -inline {.*/+} $clkregion]
    set formatName [string range $clkregion [string length $hier_prefix] end]
    set clknet [get_nets -hierarchical -regexp .*\/${formatName}.*]
    puts $clknet

    # Generate ila
    set debugdepth [lindex $gDebugNets($debugnet) 2]
    create_debug_core $ila_name labtools_ila_v3
    set_property C_DATA_DEPTH $debugdepth [get_debug_cores $ila_name]
    set_property C_TRIGIN_EN false [get_debug_cores $ila_name]
    set_property C_TRIGOUT_EN false [get_debug_cores $ila_name]
    set_property port_width 1 [get_debug_ports $ila_name/clk]
    connect_debug_port $ila_name/clk $clknet

    # Group nets
    set allnets [get_nets -hierarchical -regexp .*${debugnet}.*]
    array unset intfcomponents
    foreach net $allnets {
      # Remove Hierarchy
      set hier_prefix [regexp -inline {.*/+} $net]
      set formatName [string range $net [string length $hier_prefix] end]
      # Remove Element Index
      set groupName [regexp -inline {.*(?=(\[))} $formatName]
      if { [string length $groupName] == 0 } {
        set groupName $formatName
      }

      # Find number of elements in the group
      if {[array names intfcomponents -exact $groupName] == ""} {
        set intfcomponents($groupName) [lsearch -all -inline -regexp $allnets .*${groupName}.*]
      }
    }
    # Create debug probes
    foreach intfcomp [array names intfcomponents] {
      if { $probenum != 0 } {
        create_debug_port $ila_name probe
      }
      set probeName [format "${ila_name}/probe%d" $probenum]
      set_property port_width [llength $intfcomponents($intfcomp)] [get_debug_ports $probeName]
      connect_debug_port $probeName [get_nets $intfcomponents($intfcomp)]

      set probenum [expr $probenum + 1]
    }
    set i [expr $i + 1]
  }

}

proc clean_debug_names { } {
  ::global gDebugNets

  set fname ipiprj.runs/impl_1/debug_nets.ltx
  if { ! [catch { open $fname r } fp]} {
    set probeFile [read $fp]
    close $fp

    foreach debugnet [array names gDebugNets] {
      set niceName [lindex $gDebugNets($debugnet) 1]
      regsub -all $debugnet $probeFile $niceName probeFile
    }

    catch { set fp [open ../debug_nets.ltx w]}
    puts $fp $probeFile
    close $fp
  }
}

################################################################################
# Helper function: connect_kernel_region
#   Used to resolve a port when a connection is made to the boundary of a
#   region.
#
#     Parameters:
#       inst : string : xcl_region
#       port : string : port of xcl_region
#       mode : (master|slave) : direction of the port for verification
#         slave mode means that the port is a slave looking towards the
#         boundary. In other words, the kernel is connecting to a slave (data)
#         port
################################################################################
proc connect_kernel_region {inst port mode} {
  global ::gRegions

  # Get endpoint of region port
  array set aregion $gRegions($inst)
  array set aports $aregion("ports")
  array set aport $aports($port)
  set ConnInst [get_bd_cell $aport("connection")]

  # Check that port mode matches
  if {$aport("mode") != $mode} {
    puts "ERROR: Specified mode $mode does not match region port mode"
    return
  }

  # Endpoint is AXI Interconnect
  if {[get_property VLNV $ConnInst] == "xilinx.com:ip:axi_interconnect:2.1"} {
    puts "Connection is axi interconnect"

    # If Region port is master, look for slave on interconnect
    set portMode ""
    if {$mode == "master"} {
      set portMode "slave"
    } else {
      set portMode "master"
    }
    set PortBD [get_free_axi_ic_port $ConnInst $portMode]

    # Set up the clock/reset
    set targetnet [get_region_clk_net $inst]
    set targetpin [get_bd_pins -of_objects $targetnet -filter {DIR == O}]
    if {[llength $targetpin] == 0} {
      set targetpin [get_bd_ports -of_objects $targetnet]
    }
    regsub {_AXI$} $PortBD "" PortBDRoot
    connect_bd_net -net $targetnet [get_bd_pins "${PortBDRoot}_ACLK"] $targetpin
    set targetnet [get_region_rst_net $inst]
    set targetpin [get_bd_pins -of_objects $targetnet -filter {DIR == O}]
    if {[llength $targetpin] == 0} {
      set targetpin [get_bd_ports -of_objects $targetnet]
    }
    connect_bd_net -net $targetnet [get_bd_pins "${PortBDRoot}_ARESETN"] $targetpin

    # Get address space or segments
    if {$mode == "slave"} {
      set AddrSpace $aport("addrspace")
    } else {
      set AddrSpace $aport("addrsegs")
    }
  } else {
    puts "Direct connection to not supported!"
  }
  return [list $PortBD $AddrSpace]
}

################################################################################
# inst_pipe
#  Instantiate a pipe
#
################################################################################
proc inst_pipe { name width depth lregion } {
  global ::gRegions

  # Create the cell
  set type xilinx.com:ip:axis_data_fifo:1.1
  set obj [create_bd_cell -type ip -vlnv $type -name "${lregion}/${name}"]

  # Set properties
  set_property CONFIG.FIFO_DEPTH $depth $obj

  # Create clk/reset
  array set aregion $gRegions($lregion)
  set instclkpin [get_bd_pins -of_objects $obj -filter {TYPE == clk}]
  connect_bd_net -net $aregion("clk") $instclkpin
  set instrstpin [get_bd_pins -of_objects $obj -filter {TYPE ==rst}]
  connect_bd_net -net $aregion("aresetn")  $instrstpin

  return "${lregion}/${name}"
}

################################################################################
# inst_global_mem
#   Instantiate on-chip global memory consisting of an axi bram controller,
#   a bram block, and an axi interconnect.
#
################################################################################
proc inst_global_mem { name size lregion } {
  global ::gRegions

  array set aregion $gRegions($lregion)

  # Create the bram
  set type xilinx.com:ip:blk_mem_gen:8.2
  set mem [create_bd_cell -type ip -vlnv $type -name "${lregion}/${name}_mem"]
  set_property -dict [ list CONFIG.Memory_Type {True_Dual_Port_RAM}  ] $mem

  # Create controller
  set type xilinx.com:ip:axi_bram_ctrl:4.0
  set ctrl [create_bd_cell -type ip -vlnv $type -name ${lregion}/${name}_ctrl]
  connect_bd_net -net $aregion("aresetn") [get_bd_pins ${lregion}/${name}_ctrl/S_AXI_ARESETN]
  connect_bd_net -net $aregion("clk") [get_bd_pins ${lregion}/${name}_ctrl/S_AXI_ACLK]

  # Create axi interconnect
  set type xilinx.com:ip:axi_interconnect:2.1
  set obj [ create_bd_cell -type ip -vlnv $type -name ${lregion}/${name}]
  set_property -dict [list CONFIG.NUM_MI {1}] [get_bd_cells /${lregion}/${name}]
  set instclkpin [get_bd_pins -of_objects $obj -filter {TYPE == clk}]
  set targetpin [get_bd_pins -of_objects $aregion("clk") -filter {DIR == O}]
  connect_bd_net -net $aregion("clk") $instclkpin $targetpin
  set targetpin [get_bd_pins -of_objects $aregion("aresetn") -filter {DIR == O}]
  set instrstpin [get_bd_pins -of_objects $obj -filter {TYPE ==rst}]
  connect_bd_net -net $aregion("aresetn") $instrstpin $targetpin

  # connect controller to bram
  connect_bd_intf_net -intf_net ${name}_bram_porta [get_bd_intf_pins ${lregion}/${name}_ctrl/BRAM_PORTA] [get_bd_intf_pins ${lregion}/${name}_mem/BRAM_PORTA]
  connect_bd_intf_net -intf_net ${name}_bram_portb [get_bd_intf_pins ${lregion}/${name}_ctrl/BRAM_PORTB] [get_bd_intf_pins ${lregion}/${name}_mem/BRAM_PORTB]

  # connect interconnect to controller
  connect_bd_intf_net -intf_net ${name}_axi_bram [get_bd_intf_pins ${lregion}/${name}/M00_AXI] [get_bd_intf_pins ${lregion}/${name}_ctrl/S_AXI]
#  connect_bd_net -net $aregion("aresetn") [get_bd_pins ${lregion}/${name}/M00_ARESETN]
#  connect_bd_net -net $aregion("clk") [get_bd_pins ${lregion}/${name}/M00_ACLK]

  return "${lregion}/${name}"
}


################################################################################
# promote_region_to_top
#  promote region to top level
#
################################################################################
proc promote_region_to_top {lregion } {
  #Functions :
  #(1) Promote region to top level
  #(2) Set internal AXI interconnects connected to AXI Master ports on OCL_REGION to register slice mode
  #    This cannot be done in the initial platform definition because the property cannot be applied
  #    to interconnects with 1 MASTER and 1 SLAVE

  #common

  ##remove top level ports
  delete_bd_objs [get_bd_intf_ports]
  delete_bd_objs [get_bd_ports]

  #remove intf nets
  #delete_bd_objs [get_bd_nets]

  #promote all region bd_intf pins to top level
  #create bd_intf_ports matching those of the IP block connected to the OCL_REGION hierarchy

  #Get internal and external segments
  set internaladdresssegs [get_bd_addr_segs -of_objects [get_bd_cells -of_objects [get_bd_cells $lregion]]]
  set alladdresssegs [get_bd_addr_segs]
  set externaladdresssegs [list]
  foreach addrseg $alladdresssegs {
    set internal 0
    foreach internaladdrseg $internaladdresssegs {
      if { "$internaladdrseg" == "$addrseg" } {
        set internal 1
      }
    }
    if { $internal == 0 } {
      lappend externaladdresssegs $addrseg
    }
  }

  set region_bd_intf_pins [get_bd_intf_pins -of_objects $lregion]
  foreach bd_intf_pin $region_bd_intf_pins {
    set valid_region_bd_intf_pin_type 0
    if { (([get_property MODE $bd_intf_pin ] == "Master") && ([get_property VLNV $bd_intf_pin] == "xilinx.com:interface:aximm_rtl:1.0")) ||
         (([get_property MODE $bd_intf_pin ] == "Slave") && ([get_property VLNV $bd_intf_pin] == "xilinx.com:interface:aximm_rtl:1.0")) } {

      set inner_bd_intf_net [get_bd_intf_nets -boundary_type lower -of_objects [get_bd_intf_pins $bd_intf_pin]]
      set valid_region_bd_intf_pin_type 1
      #Master intf_pin on region eg M00_AXI
      #create top level port
      set portname [get_property NAME $bd_intf_pin]
      #puts "Handling $portname"
      create_bd_intf_port -mode [get_property mode $bd_intf_pin] -vlnv [get_property vlnv $bd_intf_pin] $portname
      set port [get_bd_intf_ports /$portname]
      #Trace from intf_pin on region to external connection
      set externalconnectedpin [find_bd_objs -relation CONNECTED_TO $bd_intf_pin -boundary_type UPPER]
      #Trace from intf_pin on region into region to find CONFIG
      set internalconnectedpin [find_bd_objs -relation CONNECTED_TO $bd_intf_pin -boundary_type LOWER]
      set internalconnectedpinname [get_property NAME $internalconnectedpin]
      #Copy properties from internalconnected pin to port except name and MODE
      set externalconnectedproperties [list_property $externalconnectedpin]
      foreach property $externalconnectedproperties {
        if { ($property != "NAME") && ($property != "MODE") } {
          catch {set_property $property [get_property $property $externalconnectedpin] $port}
        }
      }

      if { ([get_property MODE $bd_intf_pin ] == "Master") && ([get_property VLNV $bd_intf_pin] == "xilinx.com:interface:aximm_rtl:1.0") } {
        set is_master 1
      } else {
        set is_master 0
      }
      set externalconnectedpinsegs [get_bd_addr_segs -of_objects $externalconnectedpin]

      set create_bd_addr_seg_range              [list]
      set create_bd_addr_seg_offset             [list]
      set create_bd_addr_seg_masteraddrspace    [list]
      set create_bd_addr_seg_slaveaddrseg       [list]
      set create_bd_addr_name                   [list]

      #puts "Gather address segs"
      # Address segments on boundary
      if { $is_master == 0 } {
        #AXI-LITE slave port on OCL_REGION
        #External connected pin has attached master slave address segment with slave in REGION
        foreach segexternal $externalconnectedpinsegs {
          set segexternalslaves [get_bd_addr_segs -of_objects $segexternal]
          foreach segexternalslave $segexternalslaves {
            set match [lsearch $internaladdresssegs $segexternalslave]
            if { $match != -1 } {
              set name [get_property NAME $segexternal]
              set newnameextension "_external"
              set newname $name$newnameextension
              set range [get_property RANGE $segexternal]
              set offset [get_property OFFSET $segexternal]
              #get address space of new port
              #fetching from port name. todo, should fetch from -of_objects
              set addrspace [get_bd_addr_spaces $port]
              #delete prior
              delete_bd_obj $segexternal
              #create address segment from external port to slave within OCL_REGION
              #range and offset matching prior
              #create_bd_addr_seg -range $range -offset $offset $addrspace $segexternalslave $newname
              lappend create_bd_addr_seg_range $range
              lappend create_bd_addr_seg_offset $offset
              lappend create_bd_addr_seg_masteraddrspace $addrspace
              lappend create_bd_addr_seg_slaveaddrseg $segexternalslave
              lappend create_bd_addr_name $newname
            }
          }
        }
      }
      if { $is_master == 1 } {
        #AXI-MM master port on OCL_REGION
        #external connected pin has attached slave address segment with master in OCL_REGION
        foreach segexternal $externalconnectedpinsegs {
          set segexternalmasters [get_bd_addr_segs -of_objects $segexternal]
          foreach segexternalmaster $segexternalmasters {
            set match [lsearch $internaladdresssegs $segexternalmaster]
            if { $match != -1 } {
              set name [get_property NAME $segexternalmaster]
              set newnameextension "_external"
              set newname $name$newnameextension
              set range [get_property RANGE $segexternalmaster]
              set offset [get_property OFFSET $segexternalmaster]
              #master address space
              set addrspace [get_bd_addr_spaces -of_objects $segexternalmaster]
              set slavesegnameextension "/Reg"
              set slavesegname $port$slavesegnameextension
              set slaveseg [get_bd_addr_segs $slavesegname]
              #delete prior
              delete_bd_obj $segexternalmaster
              #create address segment from external port to slave within OCL_REGION
              #range and offset matching prior
              #create_bd_addr_seg -range $range -offset $offset $addrspace $slaveseg $newname
              lappend create_bd_addr_seg_range $range
              lappend create_bd_addr_seg_offset $offset
              lappend create_bd_addr_seg_masteraddrspace $addrspace
              lappend create_bd_addr_seg_slaveaddrseg $slaveseg
              lappend create_bd_addr_name $newname
            }
          }
        }
      }

      #puts "Delete"
      #Delete existing intf net
      set del_intf_net [get_bd_intf_nets -of_objects $bd_intf_pin]
      delete_bd_objs $del_intf_net

      #Slave port
      # Connect intf_pin to top level port
      # Address segments
      if { ( $is_master == 0 ) } {
        #puts "Slave seg"
        connect_bd_intf_net $bd_intf_pin $port
        #Create new address segments
        for {set i 0} {$i < [llength $create_bd_addr_name] } {incr i} {
          create_bd_addr_seg -range [lindex $create_bd_addr_seg_range $i] -offset [lindex $create_bd_addr_seg_offset $i] [lindex $create_bd_addr_seg_masteraddrspace $i] [lindex $create_bd_addr_seg_slaveaddrseg $i] [lindex $create_bd_addr_name $i]
        }
        #puts "Slave seg done"
      }
      #Master port
      # Connect intf_pin through axi_master_idbridge or axi_master_idbridgenoslaveid
      # Address segments
      if { ( $is_master == 1) } {
        #puts "Master seg"
        ##Instantiate ID bridge
        set internalconnectedpin_id_width [get_property CONFIG.ID_WIDTH $internalconnectedpin]
        set idbridgestr "idbridge_"
        set idbridgename $lregion/$idbridgestr$internalconnectedpinname
        if { ( $internalconnectedpin_id_width == 0 ) } {
          create_bd_cell -type ip -vlnv xilinx.com:user:axi_master_idbridgenoslaveid:1.0 $idbridgename
          set idbridge [get_bd_cells $idbridgename]
          #master side ID WIDTH
          set_property CONFIG.M_ID_WIDTH [get_property CONFIG.ID_WIDTH $externalconnectedpin] $idbridge

        } else {
          create_bd_cell -type ip -vlnv xilinx.com:user:axi_master_idbridge:1.0 $idbridgename
          set idbridge [get_bd_cells $idbridgename]
         #slave side ID WIDTH
          set_property CONFIG.S_ID_WIDTH [get_property CONFIG.ID_WIDTH $internalconnectedpin] $idbridge
          #master side ID WIDTH
          set_property CONFIG.M_ID_WIDTH [get_property CONFIG.ID_WIDTH $externalconnectedpin] $idbridge
        }
        set_property CONFIG.ADDR_WIDTH [get_property CONFIG.ADDR_WIDTH $internalconnectedpin] $idbridge
        #set_property CONFIG.ARUSER_WIDTH [get_property CONFIG.ARUSER_WIDTH $internalconnectedpin] $idbridge
        #set_property CONFIG.AWUSER_WIDTH [get_property CONFIG.AWUSER_WIDTH $internalconnectedpin] $idbridge
        #set_property CONFIG.BUSER_WIDTH [get_property CONFIG.BUSER_WIDTH $internalconnectedpin] $idbridge
        set_property CONFIG.DATA_WIDTH [get_property CONFIG.DATA_WIDTH $internalconnectedpin] $idbridge
        #set_property CONFIG.RUSER_WIDTH [get_property CONFIG.RUSER_WIDTH $internalconnectedpin] $idbridge
        #set_property CONFIG.WUSER_WIDTH [get_property CONFIG.WUSER_WIDTH $internalconnectedpin] $idbridge

        #disconnect prior bd_intf_net to OCL REGION boundary
        disconnect_bd_intf_net $inner_bd_intf_net $bd_intf_pin
        set interconnect_intf_pin [get_bd_intf_pins -of_objects $inner_bd_intf_net]
        delete_bd_obj $inner_bd_intf_net
        #reconnect through bridge
        connect_bd_intf_net [get_bd_intf_pins $idbridgename/s_axi] $interconnect_intf_pin
        connect_bd_intf_net [get_bd_intf_pins $idbridgename/m_axi] $bd_intf_pin
        #bridge clock and reset
        connect_bd_net [get_bd_pins $lregion/ACLK] [get_bd_pins $idbridgename/aclk]
        connect_bd_net [get_bd_pins $lregion/ARESETN] [get_bd_pins $idbridgename/aresetn]
        #connect OCL_REGION to new top level port
        connect_bd_intf_net $bd_intf_pin $port
        #Create address segments
        #Track address range into bridge
        set maxaddress 0
        set maxaddressset 0
        set minaddress  0
        set minaddressset 0
        for {set i 0} {$i < [llength $create_bd_addr_name] } {incr i} {
          #Address segment to bridge
          set bridgeaddrsegname0 [lindex $create_bd_addr_name $i]
          set bridgeaddrsegname1 "_idbridge"
          set bridgeaddrsegname $bridgeaddrsegname0$bridgeaddrsegname1
          create_bd_addr_seg -range [lindex $create_bd_addr_seg_range $i] -offset [lindex $create_bd_addr_seg_offset $i] [lindex $create_bd_addr_seg_masteraddrspace $i] [get_bd_addr_segs $idbridgename/s_axi/reg0] $bridgeaddrsegname
          set upperaddress [expr {[lindex $create_bd_addr_seg_offset $i] +  [lindex $create_bd_addr_seg_range $i]}]
          set loweraddress [lindex $create_bd_addr_seg_offset $i]
          if { ($maxaddressset == 0) } {
            set maxaddress $upperaddress
          } else {
            if { ($upperaddress > $maxaddress) } {
              set maxaddress $upperaddress
            }
          }
          if { ($minaddressset == 0) } {
            set minaddress $loweraddress
          } else {
            if { ($loweraddress < $minaddress) } {
              set minaddress $loweraddress
            }
          }
        }
        #From bridge to top level port
        set bridge2boundaryrange [expr {$maxaddress - $minaddress}]
        set bridgeaddrsegname0 "_idbridge"
        set bridgeaddrsegname $portname$bridgeaddrsegname0
        create_bd_addr_seg -range $bridge2boundaryrange -offset $minaddress [get_bd_addr_spaces $idbridgename/m_axi] [lindex $create_bd_addr_seg_slaveaddrseg 0] $bridgeaddrsegname
        #puts "Master seg done"
      }

    }
    if { $valid_region_bd_intf_pin_type == 0 } {
      puts "error : invalid bd_intf_pin on region $lregion"
    }
  }

  #puts "remove"
  #remove all cells except region
  set topcells [get_bd_cells]
  foreach cell $topcells {
    if {$cell != $lregion } {
      delete_bd_objs $cell
    }
  }

  #puts "clk"
  #promote ACLK and RESETN
  create_bd_port -dir I ACLK
  connect_bd_net [get_bd_pins $lregion/ACLK] [get_bd_ports /ACLK]
  create_bd_port -dir I ARESETN
  connect_bd_net [get_bd_pins $lregion/ARESETN] [get_bd_ports /ARESETN]

  #puts "slice"
  #(2) Add register slice to AXI interconnects connected to AXI Master ports on OCL_REGION
  set region_bd_intf_pins [get_bd_intf_pins -of_objects $lregion]
  foreach bd_intf_pin $region_bd_intf_pins {
    if { ([get_property MODE $bd_intf_pin ] == "Master") && ([get_property VLNV $bd_intf_pin] == "xilinx.com:interface:aximm_rtl:1.0") } {
      set is_master 1
    } else {
      set is_master 0
    }
    #Trace from master port into OCL_REGION finding attached axi_interconnect
    if {  $is_master == 1 } {
      set inner_bd_intf_net [get_bd_intf_nets -boundary_type lower -of_objects [get_bd_intf_pins $bd_intf_pin]]
      set inner_connected_cell [get_bd_cells -of_objects $inner_bd_intf_net]
      if { [get_property VLNV $inner_connected_cell] == "xilinx.com:ip:axi_interconnect:2.1" } {
        #set_property CONFIG.STRATEGY 2 $inner_connected_cell
        set_property CONFIG.M00_HAS_REGSLICE 1 $inner_connected_cell
      }
    }
  }
  #puts "done"



}


#
# Work around for addressing bug when there are two
# different paths between a master and a slave
# Saves off addressing before an action and then
# attempts to recreate it afterwards
#
#   call save_assigment before the deleting a block in the
#   path between the master and slave
#
#   call restore_assignment afterwards to restore
#   the assignment for any of the peripherals that wo
#   were illegally unmapped by the action
#

set dSSxOR [dict create \
	       ]

proc save_assignment { } {
    variable dSSxOR

    set vMB [get_bd_intf_pins -of_objects [get_bd_cells *] \
		 -filter {Mode == "Master" && VLNV =~ "*aximm*"} \
		]

    set vMS [get_bd_addr_segs -of_objects $vMB]

    foreach MS $vMS {

	set AS [get_bd_addr_spaces -of_object $MS]
	set SS [get_bd_addr_segs   -of_object $MS]
	set O  [get_property offset $MS]
	set R  [get_property range  $MS]

	set sAS [format %s $AS]
	set sMS [get_property NAME $MS]
	set sSS [format %s $SS]

	puts "!!! ----------"
	puts "!!! SAVE AS $AS"
	puts "!!! SAVE MS $MS"
	puts "!!! SAVE SS $SS"
	puts "!!! SAVE O  $O"
	puts "!!! SAVE R  $R"
	puts "!!! ----------"
	puts ""

	dict set dSSxOR $sSS [list $sAS $sMS $O $R]
    }
}

proc restore_assignment { } {
    variable dSSxOR

    #::bd::util_cmd serialize design_1 after_del.xml

    dict for {sSS vASxMSxOR } $dSSxOR {

	set sAS [lindex $vASxMSxOR 0]
	set sMS [lindex $vASxMSxOR 1]
	set O   [lindex $vASxMSxOR 2]
	set R   [lindex $vASxMSxOR 3]

	set AS [get_bd_addr_space $sAS]
	set MS [get_bd_addr_seg   $sAS/$sMS]
	set SS [get_bd_addr_seg   $sSS]

	if {0 != [llength $MS]} {
	    #puts "!!! Not missing $MS"
	    continue
	}

	if {0 == [llength $AS]} {
	    #puts "!!! Missing $sAS"
	    continue
	}

	if {0 == [llength $SS]} {
	    #puts "!!! Missing $sSS"
	    continue
	}

	puts "!!! ----------"
	puts "!!! REST AS $sAS"
	puts "!!! REST SS $sSS"
	puts "!!! REST O  $O"
	puts "!!! REST R  $R"
	puts "!!! REST MS $sMS"
	puts "!!! ----------"
	puts ""
	create_bd_addr_seg \
	    -offset $O \
	    -range  $R \
	    $AS \
	    $SS \
	    $sMS
    }
}


proc apply_baseplatform_xdc {designTop platformPath} {
    package require fileutil
    if { [file exists $platformPath/ipi/bp.xdc] } {
        add_files -fileset constrs_1 -norecurse $platformPath/ipi/bp.xdc
    }
}

################################################################################
# add_profiling
#   Description:
#     Insert device profiling monitor framework into OCL region
#   Arguments:
#     region           name of region
#     clkName          clock net name
#     resetName        reset net name
#     baseAddress      base address used for APM
#     useCounters      0: do not include counters, 1: include APM counters
#     useTrace         0: do not include trace, 1: include APM trace
#     offloadType      0: AXI-Lite, 1: AXI-MM
#     monNameList      list of AXI intf ports to monitor [contained in {}]
#     axiInterconnect  name of AXI interconnect to use for control (optional) 
#
################################################################################
proc add_profiling {region clkName resetName baseAddress useCounters useTrace offloadType monNameList {axiInterconnect ""}} {
  # Constants
  set maxAXISlaves 16
  set maxAXIMasters 16
  set fifoDepth 4096
  set fifoOffset    0x010000
  set fifoIncrement 0x001000
  set logIds 0
  set logLengths 1
  set protocol "AXI4"
  set startName "event_start"
  set doneName "event_done"
  set apmName "${region}/xilmonitor_apm"
  set jtagMasterName "${region}/xilmonitor_master"
  set broadcastName "${region}/xilmonitor_broadcast"
  set subsetNames [list ${region}/xilmonitor_subset0 ${region}/xilmonitor_subset1 ${region}/xilmonitor_subset2 ${region}/xilmonitor_subset3 ${region}/xilmonitor_subset4 ${region}/xilmonitor_subset5 ${region}/xilmonitor_subset6 ${region}/xilmonitor_subset7]
  set fifoNames [list ${region}/xilmonitor_fifo0 ${region}/xilmonitor_fifo1 ${region}/xilmonitor_fifo2 ${region}/xilmonitor_fifo3 ${region}/xilmonitor_fifo4 ${region}/xilmonitor_fifo5 ${region}/xilmonitor_fifo6 ${region}/xilmonitor_fifo7]
  set broadcastPortNames [list M00_AXIS M01_AXIS M02_AXIS M03_AXIS M04_AXIS M05_AXIS M06_AXIS M07_AXIS M08_AXIS M09_AXIS M10_AXIS M11_AXIS M12_AXIS M13_AXIS M14_AXIS M15_AXIS]
  set addrSegNames [list XIL_SEG_FIFO0 XIL_SEG_FIFO1 XIL_SEG_FIFO2 XIL_SEG_FIFO3 XIL_SEG_FIFO4 XIL_SEG_FIFO5 XIL_SEG_FIFO6 XIL_SEG_FIFO7]
  set apmPorts [list SLOT_0_AXI SLOT_1_AXI SLOT_2_AXI SLOT_3_AXI SLOT_4_AXI SLOT_5_AXI SLOT_6_AXI SLOT_7_AXI]
  set apmPortClocks [list slot_0_axi_aclk slot_1_axi_aclk slot_2_axi_aclk slot_3_axi_aclk slot_4_axi_aclk slot_5_axi_aclk slot_6_axi_aclk slot_7_axi_aclk]
  set apmExtEventClocks [list ext_clk_0 ext_clk_1 ext_clk_2 ext_clk_3 ext_clk_4 ext_clk_5 ext_clk_6 ext_clk_7]
  set apmOtherClocks [list s_axi_aclk core_aclk]
  set apmPortResets [list slot_0_axi_aresetn slot_1_axi_aresetn slot_2_axi_aresetn slot_3_axi_aresetn slot_4_axi_aresetn slot_5_axi_aresetn slot_6_axi_aresetn slot_7_axi_aresetn]
  set apmExtEventResets [list ext_rstn_0 ext_rstn_1 ext_rstn_2 ext_rstn_3 ext_rstn_4 ext_rstn_5 ext_rstn_6 ext_rstn_7]
  set apmOtherResets [list s_axi_aresetn core_aresetn]
  set apmStartNames [list ext_event_0_cnt_start ext_event_1_cnt_start ext_event_2_cnt_start ext_event_3_cnt_start ext_event_4_cnt_start ext_event_5_cnt_start ext_event_6_cnt_start ext_event_7_cnt_start]
  set apmDoneNames [list ext_event_0_cnt_stop ext_event_1_cnt_stop ext_event_2_cnt_stop ext_event_3_cnt_stop ext_event_4_cnt_stop ext_event_5_cnt_stop ext_event_6_cnt_stop ext_event_7_cnt_stop]
  set interconSlaves [list S00_AXI S01_AXI S02_AXI S03_AXI S04_AXI S05_AXI S06_AXI S07_AXI S08_AXI S09_AXI S10_AXI S11_AXI S12_AXI S13_AXI S14_AXI S15_AXI]
  set interconMasters [list M00_AXI M01_AXI M02_AXI M03_AXI M04_AXI M05_AXI M06_AXI M07_AXI M08_AXI M09_AXI M10_AXI M11_AXI M12_AXI M13_AXI M14_AXI M15_AXI]
  set interconSlaveClocks [list S00_ACLK S01_ACLK S02_ACLK S03_ACLK S04_ACLK S05_ACLK S06_ACLK S07_ACLK S08_ACLK S09_ACLK S10_ACLK S11_ACLK S12_ACLK S13_ACLK S14_ACLK S15_ACLK]
  set interconSlaveResets [list S00_ARESETN S01_ARESETN S02_ARESETN S03_ARESETN S04_ARESETN S05_ARESETN S06_ARESETN S07_ARESETN S08_ARESETN S09_ARESETN S10_ARESETN S11_ARESETN S12_ARESETN S13_ARESETN S14_ARESETN S15_ARESETN]
  set interconMasterClocks [list M00_ACLK M01_ACLK M02_ACLK M03_ACLK M04_ACLK M05_ACLK M06_ACLK M07_ACLK M08_ACLK M09_ACLK M10_ACLK M11_ACLK M12_ACLK M13_ACLK M14_ACLK M15_ACLK]
  set interconMasterResets [list M00_ARESETN M01_ARESETN M02_ARESETN M03_ARESETN M04_ARESETN M05_ARESETN M06_ARESETN M07_ARESETN M08_ARESETN M09_ARESETN M10_ARESETN M11_ARESETN M12_ARESETN M13_ARESETN M14_ARESETN M15_ARESETN]
  set interconSlaveRegSlices [list S00_HAS_REGSLICE S01_HAS_REGSLICE S02_HAS_REGSLICE S03_HAS_REGSLICE S04_HAS_REGSLICE S05_HAS_REGSLICE S06_HAS_REGSLICE S07_HAS_REGSLICE S08_HAS_REGSLICE S09_HAS_REGSLICE S10_HAS_REGSLICE S11_HAS_REGSLICE S12_HAS_REGSLICE S13_HAS_REGSLICE S14_HAS_REGSLICE S15_HAS_REGSLICE]
  set interconMasterRegSlices [list M00_HAS_REGSLICE M01_HAS_REGSLICE M02_HAS_REGSLICE M03_HAS_REGSLICE M04_HAS_REGSLICE M05_HAS_REGSLICE M06_HAS_REGSLICE M07_HAS_REGSLICE M08_HAS_REGSLICE M09_HAS_REGSLICE M10_HAS_REGSLICE M11_HAS_REGSLICE M12_HAS_REGSLICE M13_HAS_REGSLICE M14_HAS_REGSLICE M15_HAS_REGSLICE]
  set broadcastRemap [list M00_TDATA_REMAP M01_TDATA_REMAP M02_TDATA_REMAP M03_TDATA_REMAP M04_TDATA_REMAP M05_TDATA_REMAP M06_TDATA_REMAP M07_TDATA_REMAP M08_TDATA_REMAP M09_TDATA_REMAP M10_TDATA_REMAP M11_TDATA_REMAP M12_TDATA_REMAP M13_TDATA_REMAP M14_TDATA_REMAP M15_TDATA_REMAP]
  set apmProtocols [list CONFIG.C_SLOT_0_AXI_PROTOCOL CONFIG.C_SLOT_1_AXI_PROTOCOL CONFIG.C_SLOT_2_AXI_PROTOCOL CONFIG.C_SLOT_3_AXI_PROTOCOL CONFIG.C_SLOT_4_AXI_PROTOCOL CONFIG.C_SLOT_5_AXI_PROTOCOL CONFIG.C_SLOT_6_AXI_PROTOCOL CONFIG.C_SLOT_7_AXI_PROTOCOL]
  
  #
  # Error Checking
  #
  
  # Ensure clkName and resetName are valid nets
  if { [get_bd_net $clkName] eq "" } {
    puts "WARNING: the net $clkName was not found in the current block diagram"
    return
  }
  if { [get_bd_net $resetName] eq "" } {
    puts "WARNING: the net $resetName was not found in the current block diagram"
    return
  }
  
  # Ensure correct amount of monitor ports (max of 8 supported by single APM)
  set numMonPorts [llength $monNameList]
  if {$numMonPorts < 0 || $numMonPorts > 8} {
    puts "WARNING: number of ports must be between 0 and 8."
    return
  }
  if {$numMonPorts == 0} {
    set logIds 0
    set logLengths 0
  }
  
  # Ensure monitor names are valid nets
  for { set i 0 } { $i < $numMonPorts } { incr i } {
    set pinName [lindex $monNameList $i]
	  if { [get_bd_intf_pins $pinName] eq "" } {
	    #error "ERROR: the interface pin $pinName was not found in the current block diagram"
      puts "WARNING: the interface pin $pinName was not found in the current block diagram"
      return
    }
  }
  
  # Get then validate AXI Interconnect
  set intercon_obj ""
  if { $axiInterconnect ne "" } {
    set intercon_obj [get_bd_cells -quiet $axiInterconnect]
  }
  if { $intercon_obj eq "" } {  
    set intercon_obj [get_axi_interconnect $region]
    if { $intercon_obj eq "" } {
      puts "WARNING: no valid AXI interconnects were found in the current block diagram"
      return
    }
  }

  #
  # Initialization
  #
  puts "Adding performance monitoring framework..."
  
  set kernelsList [get_bd_cells -quiet -hier -filter {VLNV=~"xilinx.com:hls:*"}]
  set numKernels [llength $kernelsList]
  #put "numKernels = $numKernels, kernelsList = $kernelsList"
  if {$numKernels > $numMonPorts} {
    set numPorts $numKernels
  } else {
    set numPorts $numMonPorts
  }
  
  # Calculate trace bits and number of masters required 
  if {$useTrace > 0} {
    # Calculate number of bits in trace output
    set bitsPerSlot [expr 10 + (6 * 4 * $logIds) + (16 * $logLengths)]
    set traceBits [expr int(ceil((18 + ($bitsPerSlot * $numPorts)) / 8.0) * 8)]
    if {$traceBits < 56} {
      set traceBits 56 
    }
    set traceBytesApm [expr int(ceil($traceBits/8.0))]
    
    # NOTE: the number of bytes is always a multiple of 4 since the
    # broacaster zero pads to an integer number of 32-bit words
    if {$offloadType == 0} {
      set traceWords [expr int(ceil($traceBits/32.0))]
    } else {
      set traceWords 1
    }
    set traceBytes [expr 4 * int($traceWords)]
    
    set numMasters [expr int([get_property [list CONFIG.NUM_MI] $intercon_obj] + $traceWords + 1)];
  } else {
    set numMasters [expr int([get_property [list CONFIG.NUM_MI] $intercon_obj] + 1)];
  }
  
  # Make sure there's enough masters
  if {$numMasters > $maxAXIMasters} {
    puts "WARNING: there are not enough masters left on the AXI interconnect"
    return
  }
  
  # Delete objects if they already exist (catch to ignore warnings) 
  if {[get_bd_cells $apmName -quiet] != {}} {delete_bd_objs [get_bd_cells $apmName]}
  if {[get_bd_cells $broadcastName -quiet] != {}} {delete_bd_objs [get_bd_cells $broadcastName]}
  if {[get_bd_cells $jtagMasterName -quiet] != {}} {delete_bd_objs [get_bd_cells $jtagMasterName]}
  
  for { set i 0 } { $i < [llength $fifoNames] } { incr i } {
    set subsetName [lindex $subsetNames $i]
    if {[get_bd_cells $subsetName -quiet] != {}} {delete_bd_objs [get_bd_cells $subsetName]}
    set fifoName [lindex $fifoNames $i]
    if {[get_bd_cells $fifoName -quiet] != {}} {delete_bd_objs [get_bd_cells $fifoName]}
  }
  
  puts "  APM monitored signals:"
  for { set i 0 } { $i < $numMonPorts } { incr i } {
    puts "    Port $i: [lindex $monNameList $i]"
  }
	
  #
  # Insert APM
  #
  puts "  Inserting AXI performance monitor: $apmName..."
  set apm_obj [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_perf_mon $apmName]
  
  # Use profile/trace configuration mode
  # NOTE: already defines # counters, etc.
  set_property CONFIG.C_NUM_MONITOR_SLOTS $numPorts $apm_obj
  set_property CONFIG.C_ENABLE_PROFILE $useCounters $apm_obj
  set_property CONFIG.C_ENABLE_TRACE $useTrace $apm_obj
  if {$useCounters > 0} {
    set_property CONFIG.C_HAVE_SAMPLED_METRIC_CNT 1 $apm_obj
  } 
  # Enable flags: write/read address, write/read last data, SW register write
  if {$useTrace > 0} {
    set_property CONFIG.C_FIFO_AXIS_DEPTH 16 $apm_obj
    set_property CONFIG.C_EN_WR_ADD_FLAG 1 $apm_obj 
    set_property CONFIG.C_EN_FIRST_WRITE_FLAG 0 $apm_obj 
    set_property CONFIG.C_EN_LAST_WRITE_FLAG 1 $apm_obj 
    set_property CONFIG.C_EN_RESPONSE_FLAG 0 $apm_obj 
    set_property CONFIG.C_EN_RD_ADD_FLAG 1 $apm_obj 
    set_property CONFIG.C_EN_FIRST_READ_FLAG 0 $apm_obj 
    set_property CONFIG.C_EN_LAST_READ_FLAG 1 $apm_obj 
    set_property CONFIG.C_EN_SW_REG_WR_FLAG 1 $apm_obj 
    set_property CONFIG.C_EN_EXT_EVENTS_FLAG 1 $apm_obj 
    set_property CONFIG.C_SHOW_AXI_IDS $logIds $apm_obj
    set_property CONFIG.C_SHOW_AXI_LEN $logLengths $apm_obj
  }
 
  # Connect all clock and reset pins on APM
  for { set i 0 } { $i < [llength $apmOtherClocks] } { incr i } {
    connect_bd_net -net [get_bd_net $clkName] [get_bd_pins $apmName/[lindex $apmOtherClocks $i]]
    connect_bd_net -net [get_bd_net $resetName] [get_bd_pins $apmName/[lindex $apmOtherResets $i]]
  }
  
  if {$useTrace > 0} {
    connect_bd_net -net [get_bd_net $clkName] [get_bd_pins $apmName/m_axis_aclk]
    connect_bd_net -net [get_bd_net $resetName] [get_bd_pins $apmName/m_axis_aresetn]
  }
  
  # NOTE: this assumes a single clock in the region since we are simply grabbing the APM clock (12/5/14, schuey)
  set clkNet [get_bd_nets $clkName]
  set rstNet [get_bd_nets $resetName]
    
  for { set i 0 } { $i < $numPorts } { incr i } {
    # Grab appropriate clock and reset
    #set pinName [lindex $monNameList $i]
    #set clkNet [find_axi_clk $pinName]
    #set rstNet [find_axi_rst $pinName]
    
    connect_bd_net -net [get_bd_net $clkNet] [get_bd_pins $apmName/[lindex $apmPortClocks $i]]
    connect_bd_net -net [get_bd_net $rstNet] [get_bd_pins $apmName/[lindex $apmPortResets $i]]
  }
  
  # Add trace infrastructure
  if {$useTrace > 0} {
    if {$offloadType == 0} {
      #
      # Insert AXI broadcaster
      #
      puts "  Inserting AXI broadcaster: $broadcastName..."
      set broadcast_obj [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster $broadcastName]
      
      set_property -dict [list CONFIG.NUM_MI [expr int($traceWords)]] $broadcast_obj
      set_property -dict [list CONFIG.S_TDATA_NUM_BYTES.VALUE_SRC USER] $broadcast_obj
      set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $traceBytesApm] $broadcast_obj
      set_property -dict [list CONFIG.M_TDATA_NUM_BYTES.VALUE_SRC USER] $broadcast_obj
      set_property -dict [list CONFIG.M_TDATA_NUM_BYTES $traceBytes] $broadcast_obj
    
      set zeroPadBits [expr int(32*$traceWords - $traceBits)]
      set zeroPadStr "$zeroPadBits'b"
      for { set i 0 } { $i < $zeroPadBits } { incr i } {
        append zeroPadStr "0"
      }
      #zero pad bits of the apm fifo
      for { set i 0 } { $i < $traceWords } { incr i } {  
        set remapParam [lindex $broadcastRemap $i]
        if {$zeroPadBits > 0} {
          set remapValue "$zeroPadStr,tdata[[expr $traceBits-1]:0]"
        } else {
          set remapValue "tdata[[expr $traceBits-1]:0]" 
        }
        set_property -dict [list CONFIG.$remapParam $remapValue] $broadcast_obj
      }
      
      set broadcastClkPins [get_bd_pins -of_objects $broadcast_obj -filter {DIR == I && TYPE == clk}]
      connect_bd_net -net [get_bd_net $clkName] $broadcastClkPins
      set broadcastRstPins [get_bd_pins -of_objects $broadcast_obj -filter {DIR == I && TYPE == rst}]
      connect_bd_net -net [get_bd_net $resetName] $broadcastRstPins
        
      #
      # Insert subset converters
      #
      puts "  Inserting $traceWords AXI subset converters..."
      for { set i 0 } { $i < $traceWords } { incr i } {
        set subsetName [lindex $subsetNames $i] 
        set subset_obj [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter $subsetName]
    
        set_property -dict [list CONFIG.S_TDATA_NUM_BYTES.VALUE_SRC USER CONFIG.M_TDATA_NUM_BYTES.VALUE_SRC USER] $subset_obj
        set_property -dict [list CONFIG.S_TDATA_NUM_BYTES [expr 4*int($traceWords)]] $subset_obj
        set_property -dict [list CONFIG.M_TDATA_NUM_BYTES {4}] $subset_obj
        set_property -dict [list CONFIG.TDATA_REMAP tdata[[expr ($i+1)*32-1]:[expr $i*32]]] $subset_obj
        
        set subsetClkPins [get_bd_pins -of_objects $subset_obj -filter {DIR == I && TYPE == clk}]
        connect_bd_net -net [get_bd_net $clkName] $subsetClkPins
        set subsetRstPins [get_bd_pins -of_objects $subset_obj -filter {DIR == I && TYPE == rst}]
        connect_bd_net -net [get_bd_net $resetName] $subsetRstPins
      }
      
      #
      # Insert AXI FIFOs
      #
      puts "  Inserting $traceWords AXI Stream FIFOs..."
      for { set i 0 } { $i < $traceWords } { incr i } {
        set fifoName [lindex $fifoNames $i] 
        set fifo_obj [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s $fifoName]
        
        set_property CONFIG.C_DATA_INTERFACE_TYPE 0 $fifo_obj
        set_property CONFIG.C_RX_FIFO_DEPTH $fifoDepth $fifo_obj
        set_property CONFIG.C_RX_FIFO_PF_THRESHOLD [expr $fifoDepth - 5] $fifo_obj
        set_property CONFIG.C_USE_RX_CUT_THROUGH true $fifo_obj
        set_property CONFIG.C_USE_TX_DATA 0 $fifo_obj
        
        set fifoClkPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == clk}]
        connect_bd_net -net [get_bd_net $clkName] $fifoClkPins
        set fifoRstPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == rst}]
        connect_bd_net -net [get_bd_net $resetName] $fifoRstPins
      }
    } else {
      #
      # Insert AXI FIFO
      #
      puts "  Inserting AXI Stream FIFO..."
      set fifoName [lindex $fifoNames 0] 
      set fifo_obj [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s $fifoName]
        
      set_property CONFIG.C_DATA_INTERFACE_TYPE 1 $fifo_obj
      set_property CONFIG.C_S_AXI4_DATA_WIDTH 512 $fifo_obj
      set_property CONFIG.C_RX_FIFO_DEPTH $fifoDepth $fifo_obj
      set_property CONFIG.C_RX_FIFO_PF_THRESHOLD [expr $fifoDepth - 5] $fifo_obj
      set_property CONFIG.C_USE_RX_CUT_THROUGH true $fifo_obj
      set_property CONFIG.C_USE_TX_DATA 0 $fifo_obj
        
      set fifoClkPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == clk}]
      connect_bd_net -net [get_bd_net $clkName] $fifoClkPins
      set fifoRstPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == rst}]
      connect_bd_net -net [get_bd_net $resetName] $fifoRstPins
    }
    
    #
    # Connect kernel start/stop 
    #
    if {$kernelsList ne {}} {
      puts "  Monitoring start/done on [llength $kernelsList] kernel(s)... "
    
      set ii 0
      foreach kernel ${kernelsList} {
        set startPinName $kernel/$startName
        set donePinName  $kernel/$doneName
        #puts "monitoring $startPinName and $donePinName..."
         
        if {$ii < $numPorts && [get_bd_pins -quiet $startPinName] ne "" && [get_bd_pins -quiet $donePinName] ne ""} {
          connect_bd_net [get_bd_pins $startPinName] [get_bd_pins $apm_obj/[lindex $apmStartNames $ii]]
          connect_bd_net [get_bd_pins $donePinName] [get_bd_pins $apm_obj/[lindex $apmDoneNames $ii]]
          
          # TODO: currently assumes same clock/reset
          connect_bd_net -net [get_bd_net $clkNet] [get_bd_pins $apmName/[lindex $apmExtEventClocks $ii]]
          connect_bd_net -net [get_bd_net $rstNet] [get_bd_pins $apmName/[lindex $apmExtEventResets $ii]]
          incr ii
        }
      }
    }
  }
  
  #
  # Make Connections
  #
  puts "  Connecting all blocks... "
  
  # Monitor ports on APM
  for { set i 0 } { $i < $numMonPorts } { incr i } {
    connect_bd_intf_net [get_bd_intf_pins $apmName/[lindex $apmPorts $i]] [get_bd_intf_pins [lindex $monNameList $i]]
    set_property -dict [list [lindex $apmProtocols $i] $protocol] $apm_obj
  }
	
	if {$useTrace > 0} {
	  if {$offloadType == 0} {
      # AXI-Stream from the APM to the broadcaster
      connect_bd_intf_net [get_bd_intf_pins $apmName/M_AXIS] [get_bd_intf_pins $broadcastName/S_AXIS]
    
      # AXI-Stream from the broadcaster to the subset converters and then to FIFOs
      for { set i 0 } { $i < $traceWords } { incr i } {
        set portName [lindex $broadcastPortNames $i]
        set subsetName [lindex $subsetNames $i]
        connect_bd_intf_net [get_bd_intf_pins $broadcastName/$portName] [get_bd_intf_pins $subsetName/S_AXIS]
        
        set fifoName [lindex $fifoNames $i]
        connect_bd_intf_net [get_bd_intf_pins $subsetName/M_AXIS] [get_bd_intf_pins $fifoName/AXI_STR_RXD]
      }
    } else {
      # AXI-Stream from the APM to the FIFO
      set fifoName [lindex $fifoNames 0]
      connect_bd_intf_net [get_bd_intf_pins $apmName/M_AXIS] [get_bd_intf_pins $fifoName/AXI_STR_RXD]
      
      #
      # TODO: Connect AXI-MM on FIFO!!
      #
      #connect_bd_intf_net ??? [get_bd_intf_pins $fifoName/S_AXI_FULL]
      #create_bd_addr_seg -offset ??? -range ??? ??? [get_bd_addr_segs $fifoName/S_AXI_FULL/Mem0] ???
    }
  }
  
  # Interconnect master to APM
  set_property -dict [list CONFIG.NUM_MI $numMasters] $intercon_obj
  set axiMasterName [lindex $interconMasters [expr $numMasters-1]]
  set axiClkName [lindex $interconMasterClocks [expr $numMasters-1]]
  set axiResetName [lindex $interconMasterResets [expr $numMasters-1]]
  set axiMasterRegSlice [lindex $interconMasterRegSlices [expr $numMasters-1]]
  set_property -dict [list CONFIG.$axiMasterRegSlice {1}] $intercon_obj
  connect_bd_intf_net [get_bd_intf_pins $intercon_obj/$axiMasterName] [get_bd_intf_pins $apmName/s_axi]
  
  # Connect clock and reset nets 
  connect_bd_net -net [get_bd_net $clkName] [get_bd_pins $intercon_obj/$axiClkName]
  connect_bd_net -net [get_bd_net $resetName] [get_bd_pins $intercon_obj/$axiResetName]
  
  # Assign address
  set ctrlAddrSpace [get_bd_addr_spaces -of_objects [get_bd_intf_pins $intercon_obj/S00_AXI]]
  create_bd_addr_seg -offset $baseAddress -range $fifoOffset $ctrlAddrSpace [get_bd_addr_segs $apmName/S_AXI/Reg] XIL_SEG_APM
  
  # Interconnect masters to AXI FIFOs
  if {$useTrace > 0} {
    for { set i 0 } { $i < $traceWords } { incr i } {
      set fifoName [lindex $fifoNames $i]
      set axiMasterName [lindex $interconMasters [expr $numMasters-2-$i]]
      set axiClkName [lindex $interconMasterClocks [expr $numMasters-2-$i]]
      set axiResetName [lindex $interconMasterResets [expr $numMasters-2-$i]]
      set axiMasterRegSlice [lindex $interconMasterRegSlices [expr $numMasters-2-$i]]
      set_property -dict [list CONFIG.$axiMasterRegSlice {1}] $intercon_obj
      connect_bd_intf_net [get_bd_intf_pins $intercon_obj/$axiMasterName] [get_bd_intf_pins $fifoName/S_AXI]
      
      connect_bd_net -net [get_bd_net $clkName] [get_bd_pins $intercon_obj/$axiClkName]
      connect_bd_net -net [get_bd_net $resetName] [get_bd_pins $intercon_obj/$axiResetName]
      
      # Assign address
      set fifoAddress [expr $baseAddress + $fifoOffset + ($i * $fifoIncrement)]
      set segName [lindex $addrSegNames $i]
      create_bd_addr_seg -offset $fifoAddress -range $fifoIncrement $ctrlAddrSpace [get_bd_addr_segs $fifoName/S_AXI/Mem0] $segName
    }
  }
   
  puts "  Completed marking for performance"
}

################################################################################
# get_axi_interconnect
#   Description:
#     Get the AXI interconnect to use for connecting to profiling cores
#   Arguments:
#     region           name of region
################################################################################

proc get_axi_interconnect { region } {
  if {$region eq ""} {
    return [get_bd_cells axi_interconnect_0]
  }
  
  # Get all interconnects in specified region
  set interconnects [get_bd_cells -hier -of_objects [get_bd_cells $region] -filter {VLNV=~"*axi_interconnect*"}]
  
  # Find the one connected to the specified control interface
  foreach intercon ${interconnects} {
    set intf_pins [get_bd_intf_pins -quiet -hier -of_objects [get_bd_cells $intercon] -filter {NAME=~"*S00_AXI*"}]
    #puts "intf_pins = $intf_pins"
    set intf_nets [get_bd_intf_nets -quiet -of $intf_pins]
    #puts "intf_nets = $intf_nets"
    set intf_ports [get_bd_intf_ports -quiet -of $intf_nets]
    #puts "intf_ports = $intf_ports"
    if {$intf_ports != ""} {
      return $intercon       
    }
  }
  return ""
}

################################################################################
# generate_profiling_cores
#   Description:
#     Add APM and supporting IP to all nets marked for profiling
#   Arguments:
#     none
################################################################################

proc generate_profiling_cores { } {
  global ::gPerfMonRegion
  global ::gPerfMonPorts

  # Get clock, reset, and AXI interconnect to connect to APM
  if {$gPerfMonRegion == ""} {
    set gPerfMonRegion "OCL_REGION_0"
    puts "WARNING: Region undefined when generating profiling. Using default $gPerfMonRegion."
    set apm_clk $gPerfMonRegion/ACLK_1
    set apm_rst $gPerfMonRegion/ARESETN_1
  } else {
    puts "INFO: Generating profiling cores for region $gPerfMonRegion..."
    set apm_clk [get_region_clk_net $gPerfMonRegion]
    set apm_rst [get_region_rst_net $gPerfMonRegion] 
  }
  
  set useCounters 0
  set useTrace 1
  set offloadType 0
  set baseAddress 0x200000
  
  # Uncomment to test flow
  #if {[llength $gPerfMonPorts] == 0} {
  #  set gPerfMonPorts [list $gPerfMonRegion/axi_interconnect_0/S00_AXI]
  #}
  
  # For now, let's only monitor kernel start/stop
  set gPerfMonPorts [list]
   
  set add_profiling_cmd "add_profiling ${gPerfMonRegion} ${apm_clk} ${apm_rst} ${baseAddress} ${useCounters} ${useTrace} ${offloadType} {${gPerfMonPorts}}"
  puts $add_profiling_cmd
  eval $add_profiling_cmd
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
