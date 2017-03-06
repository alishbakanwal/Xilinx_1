package require math::bignum

namespace eval ocl_util {
  proc get_script_dir {} [list return [file dirname [info script]]]

  proc dict_get_default {adict key default} {
    if { [dict exists $adict $key] } {
      return [dict get $adict $key]
    }
    return $default
  }

  proc error2file {dir msg {catch_res ""}} {
    if { $catch_res ne "" } {
      puts "ERROR: caught error: $catch_res"
    }
    regsub -nocase {^\s*ERROR\s*:*\s*} $msg {} msg
    set fname [file join $dir "vivado_error.txt"]
    puts "Writing to file $fname: $msg"
    set fh [open $fname w]
    puts $fh $msg
    close $fh
    uplevel 1 error [list $msg]
    #error $msg
  }

  proc warning2file {dir msg } {
    regsub -nocase {^\s*WARNING\s*:*\s*} $msg {} msg
    set fname [file join $dir "vivado_warning.txt"]
    puts "Writing warnings to file $fname: $msg"
    set fh [open $fname w]
    puts $fh $msg
    close $fh
  }

  proc create_ocl_region_bd {dsa_name dsa_ports {kernels {}} {ocl_ip_dict {}} {kernel_resources_dict {}} {generate_bd true}} {
    set startdir [pwd]

    #set start_time [clock seconds]
    # Update input data to conform to expectations
    if { [catch {update_kernel_info kernels} catch_res] } {
      error2file $startdir "invalid kernel information" $catch_res
    }
    
    if { [catch {update_ocl_ip_info $ocl_ip_dict $dsa_ports} catch_res] } {
      error2file $startdir "invalid OCL region information" $catch_res
    } else {
      set ocl_ip_config $catch_res
    }
    dict set ocl_ip_dict CONFIG $ocl_ip_config

    # Source IP TCL script
    set ocl_ip_vlnv [dict get $ocl_ip_dict VLNV] 
    set ip_ns_prefix [source_ocl_ip_tcl_file $ocl_ip_vlnv]

    # Run IP TCL to re-create BD content
    puts "Creating BD external ports..."
    if { [catch {${ip_ns_prefix}create_boundary $ocl_ip_config created_ports_dict} catch_res] } {
      error2file $startdir "problem with OCL region boundary" $catch_res
    }

    puts "Creating BD contents..."
    if { [catch {${ip_ns_prefix}create_contents $ocl_ip_config $kernels $kernel_resources_dict} catch_res] } {
      error2file $startdir "problem with OCL region: $catch_res"
    } else {
      set ocl_content_dict $catch_res
    }
   
    puts "Updating BD port configurations..."
    if { [catch {update_port_config $dsa_ports $created_ports_dict} catch_res] } {
      error2file $startdir "problem with OCL region ports" $catch_res
    }

    puts "Updating kernel resources..."
    if { [catch {update_kernel_resources $kernel_resources_dict $ocl_content_dict $ip_ns_prefix $ocl_ip_config} catch_res] } {
      error2file $startdir "problem with OCL region kernel resources" $catch_res
    }
    
    if { [is_profiling_enabled $kernels] } {
      puts "Updating profiling resources..."
      save_bd_design
      set profiling [dict_get_default $kernel_resources_dict PROFILING {}]
      if { [catch {update_profiling_resources $ocl_content_dict $kernels $profiling} catch_res] } {
        error2file $startdir "problem with OCL region profiling" $catch_res
      }
    }

    puts "Updating addressing..."
    if { [catch {update_addressing $ip_ns_prefix $dsa_ports $ocl_content_dict} catch_res] } {
      error2file $startdir "problem with OCL region addressing" $catch_res
    }

    
    ### Following are manual work-arounds
    #if { [string match -nocase "vc690-admpcie7v3-1ddr-gen2" $dsa_name] } {
    #  assign_bd_address
    #  set addr_seg [get_bd_addr_segs {kernel_0/Data/SEG_M_AXI_Reg}]
    #  puts "old_offset=[get_property offset $addr_seg] old_range=[get_property range $addr_seg]"
    #  set_property offset 0x00000000 $addr_seg
    #  set_property range 4G $addr_seg
    #}

    if { [catch {
    save_bd_design 
    validate_bd_design
    save_bd_design 
    } catch_res] } {
      error2file $startdir "problem validating OCL region" $catch_res
    }

    
    if { $generate_bd } {
      if { [catch {
      set design_name [get_property name [current_bd_design]]
      set_property synth_checkpoint_mode Hierarchical [get_files ${design_name}.bd]
      generate_target {synthesis simulation implementation} [get_files ${design_name}.bd] 
      add_files -norecurse [make_wrapper -top -files [get_files ${design_name}.bd]]
      update_compile_order -fileset sources_1
      update_compile_order -fileset sim_1
      } catch_res] } {
        error2file $startdir "problem with OCL region generation" $catch_res
    }
    }

    #set run_time [expr [clock seconds] - $start_time]
    #puts "PROFILE:create_ocl_region_bd took $run_time seconds"

    # Return info
    # TODO: add debug, perf info that was added to BD
    return $ocl_content_dict
  }; # end create_ocl_region_bd

  proc is_profiling_enabled {kernels} {
    foreach kernel_inst $kernels {
      if { [dict get $kernel_inst DEBUG] >= 2 } {
        return true
      }
    }
    return false
  }
  
  proc update_profiling_resources {ocl_content_dict kernels profiling} {
    set clk_obj [get_bd_net [dict get $ocl_content_dict clk_kernel_net]]
    set rst_obj [get_bd_net [dict get $ocl_content_dict rst_kernel_sync_net]]
    set intercon_obj [dict get $ocl_content_dict slave_interconnect]
    
    foreach profiling_inst $profiling {
      set name         [dict get $profiling_inst NAME]
      set baseAddress  [dict get $profiling_inst ADDR_OFFSET]
      set kernel_cells [dict get $profiling_inst SLOTS]
      set useCounters  [dict get $profiling_inst USE_COUNTERS]
      set useTrace     [dict get $profiling_inst USE_TRACE]
      set offloadType  [dict get $profiling_inst OFFLOAD_TYPE]
      set profileType  [dict get $profiling_inst PROFILE_TYPE]
    
      # If monitoring pipes, then monitor all AXI streams found on kernels
      # Otherwise, only monitor kernel starts/dones (i.e., port list is empty)
      # NOTE: HLS does not use stream packets and creating them would be arbitrary (commented out on 7/13/16 by schuey)
      set perfMonPorts [list]
      #if {$profileType == 2} {
      #  foreach kernel_cell $kernel_cells {
      #    set kernel_axis_pins [get_bd_intf_pins -of_objects [get_bd_cells $kernel_cell] -filter {VLNV =~ "*axis*"} -quiet]
      #    foreach kernel_axis_pin $kernel_axis_pins {
      #      lappend perfMonPorts $kernel_axis_pin
      #    }
      #  }
      #}
      
      puts "Adding profiling $name - address: $baseAddress, counters: $useCounters, trace: $useTrace, offload: $offloadType, profile: $profileType, kernels: $kernel_cells" 
      add_profiling $intercon_obj $clk_obj $rst_obj ${baseAddress} ${useCounters} ${useTrace} ${offloadType} ${profileType} ${perfMonPorts} $kernel_cells
    }
  }; # end update_profiling_resources

  ################################################################################
  # add_profiling
  #   Description:
  #     Insert device profiling monitor framework into OCL region
  #   Arguments:
  #     intercon_obj interconnect cell to use
  #     clk_obj      clock object to use
  #     rst_obj      reset object to use
  #     baseAddress  base address used for APM
  #     useCounters  false: do not include counters, true: include APM counters
  #     useTrace     false: do not include trace,    true: include APM trace
  #     offloadType  false: AXI-Lite,                true: AXI-MM
  #     profileType  1: kernel stalls, 2: pipes/streams, 3: external memory, 4: kernel starts/stops
  #     monNameList  list of AXI intf ports to monitor
  #     kernel_cells list of kernel cells
  #
  ################################################################################
  proc add_profiling {intercon_obj clk_obj rst_obj baseAddress useCounters useTrace offloadType profileType monNameList kernel_cells} {
    # Constants
    set maxAXISlaves 16
    set maxAXIMasters 16
    set fifoDepth 4096
    # NOTE: this provides 64K range for APM and 4K range for stream FIFOs
    # This is a limitation on the APM core (see CR 871245)
    set apmRange      0x10000
    set fifoBaseAddress [expr $baseAddress - 0x3000]
    set fifoRange 0x1000
    set logIds 0
    set logLengths 1
    set protocol "AXI4"
    set protocol2 "AXI4S"
    # Internal blocking signals
    set startNameInt "stall_start_int"
    set doneNameInt "stall_done_int"
    # External stream port blocking signals
    set startNameStr "stall_start_str"
    set doneNameStr "stall_done_str"
    # External memory port blocking signals
    set startNameExt "stall_start_ext"
    set doneNameExt "stall_done_ext"
    # Kernel operation signals
    set startNameKernel "event_start"
    set doneNameKernel "event_done"
    set apmName "xilmonitor_apm"
    set jtagMasterName "xilmonitor_master"
    set broadcastName "xilmonitor_broadcast"
    set subsetNames [list xilmonitor_subset0 xilmonitor_subset1 xilmonitor_subset2 xilmonitor_subset3]
    set fifoNames [list xilmonitor_fifo0 xilmonitor_fifo1 xilmonitor_fifo2 xilmonitor_fifo3]
    set broadcastPortNames [list M00_AXIS M01_AXIS M02_AXIS M03_AXIS M04_AXIS M05_AXIS M06_AXIS M07_AXIS M08_AXIS M09_AXIS M10_AXIS M11_AXIS M12_AXIS M13_AXIS M14_AXIS M15_AXIS]
    set addrSegNames [list XIL_SEG_FIFO0 XIL_SEG_FIFO1 XIL_SEG_FIFO2 XIL_SEG_FIFO3 XIL_SEG_FIFO4 XIL_SEG_FIFO5 XIL_SEG_FIFO6 XIL_SEG_FIFO7]
    # AXI-MM ports
    set apmPorts [list SLOT_0_AXI SLOT_1_AXI SLOT_2_AXI SLOT_3_AXI SLOT_4_AXI SLOT_5_AXI SLOT_6_AXI SLOT_7_AXI]
    set apmPortClocks [list slot_0_axi_aclk slot_1_axi_aclk slot_2_axi_aclk slot_3_axi_aclk slot_4_axi_aclk slot_5_axi_aclk slot_6_axi_aclk slot_7_axi_aclk]
    set apmPortResets [list slot_0_axi_aresetn slot_1_axi_aresetn slot_2_axi_aresetn slot_3_axi_aresetn slot_4_axi_aresetn slot_5_axi_aresetn slot_6_axi_aresetn slot_7_axi_aresetn]
    # AXI-Stream ports
    set apmStreamPorts [list SLOT_0_AXIS SLOT_1_AXIS SLOT_2_AXIS SLOT_3_AXIS SLOT_4_AXIS SLOT_5_AXIS SLOT_6_AXIS SLOT_7_AXIS]
    set apmStreamPortClocks [list slot_0_axis_aclk slot_1_axis_aclk slot_2_axis_aclk slot_3_axis_aclk slot_4_axis_aclk slot_5_axis_aclk slot_6_axis_aclk slot_7_axis_aclk]
    set apmStreamPortResets [list slot_0_axis_aresetn slot_1_axis_aresetn slot_2_axis_aresetn slot_3_axis_aresetn slot_4_axis_aresetn slot_5_axis_aresetn slot_6_axis_aresetn slot_7_axis_aresetn]
    # Other ports
    set apmExtEventClocks [list ext_clk_0 ext_clk_1 ext_clk_2 ext_clk_3 ext_clk_4 ext_clk_5 ext_clk_6 ext_clk_7]
    set apmOtherClocks [list s_axi_aclk core_aclk]
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
   
    # Ensure correct amount of monitor ports (max of 8 supported by single APM)
    set numMonPorts [llength $monNameList]
    if {$numMonPorts < 0 || $numMonPorts > 8} {
      puts "WARNING: number of ports must be between 0 and 8."
      return
    }
    if {$numMonPorts == 0} {
      set logIds 0
      set logLengths 0
    } else {
      # Ensure monitor names are valid nets
      foreach pinName $monNameList {
        if { [get_bd_intf_pins $pinName] eq "" } {
          puts "WARNING: the interface pin $pinName was not found in the current block diagram"
          return
        }
      }
    }
   
    if {[llength $kernel_cells] == 0} {
      puts "WARNING: no kernels found to monitor in add_profiling"
      return 
    }

    #
    # Initialization
    #
    puts "Adding performance monitoring framework..."

    set numKernels [llength $kernel_cells]
    put "numKernels = $numKernels, kernel_cells = $kernel_cells"
    if {$numKernels > $numMonPorts} {
      set numPorts $numKernels
    } else {
      set numPorts $numMonPorts
    }
    
    set currNumMasters [get_property CONFIG.NUM_MI $intercon_obj]
    set numMasters [expr {$currNumMasters + 1}];
    
    # Calculate trace bits and number of masters required 
    if {$useTrace} {
      # Calculate number of bits in trace output
      #if {$profileType == 2} {
      #  set bitsPerSlot 5
      #} else {
        set bitsPerSlot [expr 10 + (6 * 4 * $logIds) + (16 * $logLengths)]
      #}
        set traceBits [expr int(ceil((18 + ($bitsPerSlot * $numPorts)) / 8.0) * 8)]
      if {$traceBits < 56} {
        set traceBits 56 
      }
      
      # Limit bit width of corner case w/ 8 kernels to 3 FIFOs
      # NOTE: this ignores the upper two bits of the 98-bit trace word
      if {$numMonPorts == 0 && $numKernels == 8} {
        set traceBits 96
      }
        
      # NOTE: the number of bytes is always a multiple of 4 since the
      # broacaster zero pads to an integer number of 32-bit words
      set traceWords [expr int(ceil($traceBits/32.0))]
      set traceBytes [expr 4 * int($traceWords)]
      set traceBytesApm [expr int(ceil($traceBits/8.0))]
      incr numMasters $traceWords
    }
    
    # Make sure there's enough masters
    if {$numMasters > $maxAXIMasters} {
      puts "WARNING: cannot monitor kernel performance, there are not enough masters left on the AXI interconnect"
      return
    }
    
    set_property -dict [list CONFIG.NUM_MI $numMasters] $intercon_obj
    
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
    
    # Use advanced mode to monitor AXI streams
    #if {$profileType == 2} {
    #  set_property CONFIG.C_NUM_MONITOR_SLOTS $numPorts $apm_obj
    #  if {$useCounters} {
    #    set_property CONFIG.C_ENABLE_EVENT_COUNT 1 $apm_obj
    #  }
    #  if {$useTrace} {
    #    set_property CONFIG.C_ENABLE_EVENT_LOG 1 $apm_obj
    #    set_property CONFIG.C_FIFO_AXIS_DEPTH 16 $apm_obj
    #    # TODO: do we want to monitor any of these?
    #    set_property CONFIG.C_SHOW_AXIS_TID 0 $apm_obj
    #    set_property CONFIG.C_SHOW_AXIS_TDEST 0 $apm_obj
    #    set_property CONFIG.C_SHOW_AXIS_TUSER 0 $apm_obj
    #    set_property CONFIG.ENABLE_EXT_EVENTS 1 $apm_obj
    #  }
    #  
    #  # Set interface protocols (NOTE: must be done here before connecting to clocks/resets below)
    #  for { set i 0 } { $i < $numPorts } { incr i } {
    #    set_property -dict [list [lindex $apmProtocols $i] $protocol2] $apm_obj
    #  }
    #} else {
      # Otherwise, use profile/trace configuration mode
      # NOTE: already defines number of counters, etc.
      set_property CONFIG.C_NUM_MONITOR_SLOTS $numPorts $apm_obj
      set_property CONFIG.C_ENABLE_PROFILE $useCounters $apm_obj
      set_property CONFIG.C_ENABLE_TRACE [expr {$useTrace?1:0}] $apm_obj 
      if {$useCounters} {
        set_property CONFIG.C_HAVE_SAMPLED_METRIC_CNT 1 $apm_obj
      } 
      # Enable flags: write/read address, write/read last data, SW register write
      if {$useTrace} {
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
      
      for { set i 0 } { $i < $numPorts } { incr i } {
        set_property -dict [list [lindex $apmProtocols $i] $protocol] $apm_obj
      }
    #}
   
    # Connect all clock and reset pins on APM
    for { set i 0 } { $i < [llength $apmOtherClocks] } { incr i } {
      connect_bd_net -net $clk_obj [get_bd_pins $apmName/[lindex $apmOtherClocks $i]]
      connect_bd_net -net $rst_obj [get_bd_pins $apmName/[lindex $apmOtherResets $i]]
    }
    
    if {$useTrace} {
      connect_bd_net -net $clk_obj [get_bd_pins $apmName/m_axis_aclk]
      connect_bd_net -net $rst_obj [get_bd_pins $apmName/m_axis_aresetn]
    }
    
    for { set i 0 } { $i < $numPorts } { incr i } {
      #if {$profileType == 2} {
      #  connect_bd_net -net $clk_obj [get_bd_pins $apmName/[lindex $apmStreamPortClocks $i]]
      #  connect_bd_net -net $rst_obj [get_bd_pins $apmName/[lindex $apmStreamPortResets $i]]
      #} else {
        connect_bd_net -net $clk_obj [get_bd_pins $apmName/[lindex $apmPortClocks $i]]
        connect_bd_net -net $rst_obj [get_bd_pins $apmName/[lindex $apmPortResets $i]]
      #}
    }
    
    # Add trace infrastructure
    if {$useTrace} {
      if {!$offloadType} {
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
        
        connect_bd_net -net $clk_obj [get_bd_pins -of_objects $broadcast_obj -filter {DIR == I && TYPE == clk}]
        connect_bd_net -net $rst_obj [get_bd_pins -of_objects $broadcast_obj -filter {DIR == I && TYPE == rst}]
          
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
          connect_bd_net -net $clk_obj $subsetClkPins
          set subsetRstPins [get_bd_pins -of_objects $subset_obj -filter {DIR == I && TYPE == rst}]
          connect_bd_net -net $rst_obj $subsetRstPins
        }
        
        #
        # Insert AXI FIFOs
        #
        puts "  Inserting $traceWords AXI FIFOs..."
        for { set i 0 } { $i < $traceWords } { incr i } {
          set fifoName [lindex $fifoNames $i] 
          set fifo_obj [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s $fifoName]
          
          set_property CONFIG.C_DATA_INTERFACE_TYPE 0 $fifo_obj
          set_property CONFIG.C_RX_FIFO_DEPTH $fifoDepth $fifo_obj
          #set_property CONFIG.C_S_AXI4_DATA_WIDTH 32 $fifo_obj
          set_property CONFIG.C_USE_RX_CUT_THROUGH true $fifo_obj
          set_property CONFIG.C_USE_TX_DATA 0 $fifo_obj
          
          set fifoClkPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == clk}]
          connect_bd_net -net $clk_obj $fifoClkPins
          set fifoRstPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == rst}]
          connect_bd_net -net $rst_obj $fifoRstPins
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
         connect_bd_net -net $clk_obj $fifoClkPins
         set fifoRstPins [get_bd_pins -of_objects $fifo_obj -filter {DIR == I && TYPE == rst}]
         connect_bd_net -net $rst_obj $fifoRstPins
      }
      
      #
      # Connect kernel start/stop 
      #
      set ii 0
      foreach kernel_cell $kernel_cells {
        if { $ii >= $numPorts } {
          break
        }

        # Get pin names of what we want to monitor
        # profileType  1: kernel stalls, 2: pipes/streams, 3: external memory, 4: kernel starts/stops
        if {$profileType == 1} {
          set startPin [get_bd_pins -quiet $kernel_cell/$startNameInt]
          set donePin [get_bd_pins -quiet $kernel_cell/$doneNameInt]
        } elseif {$profileType == 2} {
          set startPin [get_bd_pins -quiet $kernel_cell/$startNameStr]
          set donePin [get_bd_pins -quiet $kernel_cell/$doneNameStr]
        } elseif {$profileType == 3} {
          set startPin [get_bd_pins -quiet $kernel_cell/$startNameExt]
          set donePin [get_bd_pins -quiet $kernel_cell/$doneNameExt]
        } elseif {$profileType == 4} {
          set startPin [get_bd_pins -quiet $kernel_cell/$startNameKernel]
          set donePin [get_bd_pins -quiet $kernel_cell/$doneNameKernel]
        } else {
          set startPin ""
          set donePin ""
        }
        
        if {$startPin ne "" && $donePin ne ""} {
          puts "  Monitoring start/done on kernel $kernel_cell... "
          connect_bd_net $startPin [get_bd_pins $apm_obj/[lindex $apmStartNames $ii]]
          connect_bd_net $donePin [get_bd_pins $apm_obj/[lindex $apmDoneNames $ii]]
          incr ii
        } else {
          puts "  Not monitoring start/done on kernel $kernel_cell, no start/done ports found... "
        }
      }
    }
    
    # Connect external event clocks/resets
    for { set i 0 } { $i < $numPorts } { incr i } {
      connect_bd_net -net $clk_obj [get_bd_pins $apmName/[lindex $apmExtEventClocks $i]]
      connect_bd_net -net $rst_obj [get_bd_pins $apmName/[lindex $apmExtEventResets $i]]
    }
    
    #
    # Make Connections
    #
    puts "  Connecting all blocks... "
    
    # Monitor ports on APM
    for { set i 0 } { $i < $numMonPorts } { incr i } {
      #if {$profileType == 2} {
      #  connect_bd_intf_net [get_bd_intf_pins $apmName/[lindex $apmStreamPorts $i]] [get_bd_intf_pins [lindex $monNameList $i]]
      #} else {
        connect_bd_intf_net [get_bd_intf_pins $apmName/[lindex $apmPorts $i]] [get_bd_intf_pins [lindex $monNameList $i]]
      #}
    }
    
    if {$useTrace} {
      if {!$offloadType} {
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
    set interconIndex [expr $numMasters-1]
    set axiMasterName [lindex $interconMasters $interconIndex]
    set axiClkName [lindex $interconMasterClocks $interconIndex]
    set axiResetName [lindex $interconMasterResets $interconIndex]
    set axiMasterRegSlice [lindex $interconMasterRegSlices $interconIndex]
    connect_bd_intf_net [get_bd_intf_pins $intercon_obj/$axiMasterName] [get_bd_intf_pins $apmName/s_axi]
    set interconProps [list CONFIG.NUM_MI $numMasters CONFIG.$axiMasterRegSlice {1}]
    
    # Connect clock and reset nets
    # NOTE: for SmartConnect, these pins don't exist
    if {[get_bd_pins $intercon_obj/$axiClkName -quiet] != {}} {
      connect_bd_net -net $clk_obj [get_bd_pins $intercon_obj/$axiClkName]
    }
    if {[get_bd_pins $intercon_obj/$axiResetName -quiet] != {}} {
      connect_bd_net -net $rst_obj [get_bd_pins $intercon_obj/$axiResetName]
    }
    
    # Assign address
    set ctrlAddrSpace [get_bd_addr_spaces -of_objects [get_bd_intf_pins $intercon_obj/S00_AXI]]
    create_bd_addr_seg -offset $baseAddress -range $apmRange $ctrlAddrSpace [get_bd_addr_segs $apmName/S_AXI/Reg] XIL_SEG_APM
    
    # Interconnect masters to AXI FIFOs
    if {$useTrace} {
      for { set i 0 } { $i < $traceWords } { incr i } {
        set fifoName [lindex $fifoNames $i]
        set interconIndex [expr $numMasters-2-$i]
        set axiMasterName [lindex $interconMasters $interconIndex]
        set axiClkName [lindex $interconMasterClocks $interconIndex]
        set axiResetName [lindex $interconMasterResets $interconIndex]
        set axiMasterRegSlice [lindex $interconMasterRegSlices $interconIndex]
        lappend interconProps CONFIG.$axiMasterRegSlice {1}
        connect_bd_intf_net [get_bd_intf_pins $intercon_obj/$axiMasterName] [get_bd_intf_pins $fifoName/S_AXI]
        
        # Connect clock and reset nets
        # NOTE: for SmartConnect, these pins don't exist
        if {[get_bd_pins $intercon_obj/$axiClkName -quiet] != {}} {
          connect_bd_net -net $clk_obj [get_bd_pins $intercon_obj/$axiClkName]
        }
        if {[get_bd_pins $intercon_obj/$axiResetName -quiet] != {}} {
          connect_bd_net -net $rst_obj [get_bd_pins $intercon_obj/$axiResetName]
        }
        
        # Assign address
        set fifoAddress [expr $fifoBaseAddress + ($i * $fifoRange)]
        set segName [lindex $addrSegNames $i]
        create_bd_addr_seg -offset $fifoAddress -range $fifoRange $ctrlAddrSpace [get_bd_addr_segs $fifoName/S_AXI/Mem0] $segName
      }
    }
    set_property -dict $interconProps $intercon_obj
     
    puts "  Completed marking for performance"
  }; # end add_profiling

  proc update_addr_seg_info {port_dict} {
    # Set ADDR_OFFSET and ADDR_RANGE if missing based off ADDR_SEGS info
    #puts "DBG: addr_seg info: $port_dict"
    if { ![dict exists $port_dict ADDR_SEGS] } {
      return $port_dict
    }
    set segs [dict get $port_dict ADDR_SEGS]
    set num_segs [llength $segs]
    set offset 0x0
    set range 0x0
    if { $num_segs == 1 } {
      set seg_dict [lindex $segs 0]
      set offset [dict get $seg_dict OFFSET]
      set range [dict get $seg_dict RANGE]
      #puts "DBG: updated addr_seg info (1) offset=$offset range=$range"
    } elseif { $num_segs > 1 } {
      set bn_offset [hex2bignum $offset]
      set bn_range [hex2bignum $range]
      set seg_name_dict [dict create]
      foreach seg_dict $segs {
        set seg_name [dict get $seg_dict NAME]
        set bn_curr_offset [hex2bignum [dict get $seg_dict OFFSET]]
        set bn_curr_range  [hex2bignum [dict get $seg_dict RANGE]]
        if { 0 } {
          if { [dict exists $seg_name_dict $seg_name] } {
            set bn_prev_offset [dict get $seg_name_dict $seg_name OFFSET]
            set bn_prev_range  [dict get $seg_name_dict $seg_name RANGE]
            if { $bn_curr_offset < $bn_prev_offset } {
              dict set seg_name_dict $seg_name OFFSET $bn_curr_offset
            }
            dict set seg_name_dict $seg_name RANGE [math::bignum::add $bn_prev_range $bn_curr_range]
          } else {
            dict set seg_name_dict $seg_name OFFSET $bn_curr_offset
            dict set seg_name_dict $seg_name RANGE $bn_curr_range
          }
        }
        set bn_range [math::bignum::add $bn_range $bn_curr_range]
        if { $bn_curr_offset < $bn_offset } {
          set bn_offset $bn_curr_offset
        }
      }
      set offset [bignum2hex $bn_offset]
      set range [bignum2hex $bn_range]
      #puts "DBG: updated addr_seg info (2) offset=$offset range=$range"
    } else {
      set offset [dict_get_default $port_dict ADDR_OFFSET $offset]
      set range  [dict_get_default $port_dict ADDR_RANGE $range]
      #puts "DBG: updated addr_seg info (3) offset=$offset range=$range"
    }
    dict set port_dict ADDR_OFFSET $offset
    dict set port_dict ADDR_RANGE $range
    return $port_dict
  }; # end update_addr_seg_info

  proc update_addressing {ip_ns_prefix dsa_ports ocl_content_dict} {
    set s_port_name [${ip_ns_prefix}get_name_ext_si]
    set s_dict {}
    set m_ports {}
    foreach port_dict $dsa_ports {
      set name [dict get $port_dict NAME]
      set mode [string toupper [dict get $port_dict MODE]]
      set type [string toupper [dict_get_default $port_dict TYPE $mode]]
      if { $type eq "STREAM" } { continue }
      if { $mode eq "SLAVE" } {
        if { [string equal -nocase $s_port_name $name] } {
          set s_dict [update_addr_seg_info $port_dict]
        }
      } elseif { $mode eq "MASTER" } {
        lappend m_ports [update_addr_seg_info $port_dict]
      }
    }

    #assign address for slave address

    set slvExt  [get_bd_intf_ports $s_port_name]
    #Get slave segments associated with this external slave interface
    set vSS [lsort [get_bd_addr_segs -addressables -of_objects $slvExt]]
    set nSS [llength $vSS]
    #Get master address spaces associated with this external slave interface
    set AS [get_bd_addr_spaces -of_objects $slvExt]
    if {$nSS < 1} {
       error "Did not find slave address segments for $slvExt"
    }
    set kernel_insts [dict get $ocl_content_dict kernels]
    # NOTE: this check is not valid if profiling was added
    #set nKernels [llength $kernel_insts]
    #if { $nSS != $nKernels } {
    #   error "Expected number of slave address segments ($nSS) to match number of kernels ($nKernels)"
    #}

    set kernel_dict [dict create]
    foreach kernel_inst $kernel_insts {
      set ss_key "[dict get $kernel_inst cell]/[dict get $kernel_inst SLAVE]"
      dict set kernel_dict [string toupper $ss_key] $kernel_inst
    }

    set use_zero_offset false
    #set use_zero_offset true; # set to true to override map.tcl offset values and use 0x0000 instead (temporary fix)
    set s_offset [dict get $s_dict ADDR_OFFSET] 
    if { !$use_zero_offset && $s_offset > 0 } {
      set s_offset_bn [hex2bignum $s_offset]
    }
    foreach SS $vSS {
      # Addressing for APM and trace FIFOs is done in add_profiling
      if {[string first xilmonitor $SS] >= 0} {
        continue
      }
      
      set ss_key [string toupper [file dirname $SS]]
      if { ![dict exists $kernel_dict $ss_key] } {
        error "Could not find kernel for slave address segment: $ss_key\nKnown kernel paths: [dict keys $kernel_dict]"
      }
      set kernel_inst [dict get $kernel_dict $ss_key]
      if { [dict exists $kernel_inst FOUND_SS] } {
        error "Expected one slave segment per kernel: $ss_key"
      }
      dict set kernel_dict $ss_key FOUND_SS true
      set k_cell [dict get $kernel_inst cell]
      set k_offset [dict get $kernel_inst ADDR_OFFSET]
      set k_range [dict get $kernel_inst ADDR_RANGE]
      set seg_name "ocl_slave_seg_[string range ${k_cell} 1 end]"
      if { $use_zero_offset } {
        if { ![info exists curr_offset] } {
          set curr_offset [hex2bignum 0]
        }
        set k_offset [bignum2hex $curr_offset]
        set curr_offset [math::bignum::add $curr_offset [hex2bignum $k_range]]
      } elseif { $s_offset > 0 } {
        set curr_offset [math::bignum::sub [hex2bignum $k_offset] $s_offset_bn]
        set k_offset [bignum2hex $curr_offset]
      }
      puts "INFO: mapping $SS into $AS offset=$k_offset range=$k_range : $seg_name"
      create_bd_addr_seg -offset $k_offset -range $k_range $AS $SS $seg_name
    }

   
    #assign address for master address
    foreach m_port_dict $m_ports {
      set m_port_name  [dict get $m_port_dict NAME]
      set m_offset     [dict get $m_port_dict ADDR_OFFSET]
      set m_range      [dict get $m_port_dict ADDR_RANGE]
      set m_addr_width [dict get $m_port_dict ADDR_WIDTH]
      set ExtSS        [get_bd_addr_segs -of_objects [get_bd_intf_ports $m_port_name]]
      assign_bd_address $ExtSS
           
      set vEclMS [lsort [get_bd_addr_segs -excluded -of_objects $ExtSS]]
      if { [llength $vEclMS] } {
        puts "INFO: include_bd_addr_seg $vEclMS"
        include_bd_addr_seg $vEclMS 
      } 
        
      set vExtMS [lsort [get_bd_addr_segs -of_objects $ExtSS]]
      foreach ExtMS $vExtMS {
        #puts "ETP: updating $ExtMS offset=$m_offset range=$m_range"
        set_property offset $m_offset $ExtMS
        set_property range  $m_range  $ExtMS
      }
    }; # end m_ports loop

    if { [is_sdaccel_debug] } { 
      ${ip_ns_prefix}show_all_addrs "DBG: "
    }
  }; # end update_addressing

  proc hex2bignum {val} {
    regsub -nocase {^0x} $val {} val
    return [math::bignum::fromstr [string tolower $val] 16]
  }
  proc bignum2hex {bn} {
    return "0x[math::bignum::tostr $bn 16]"
  }

  proc is_sdaccel_debug {} {
    set is_dbg false
    if { [info exists ::env(SDACCEL_DEBUG)] } {
      set is_dbg [expr bool($::env(SDACCEL_DEBUG))]
    }
    return $is_dbg
  }; # end is_sdaccel_debug


  proc update_port_config {dsa_ports created_ports_dict} {
    set missing_ports {}
    foreach port_dict $dsa_ports {
      set name [dict get $port_dict NAME]
      set mode [string toupper [dict get $port_dict MODE]]
      set type [string toupper [dict_get_default $port_dict TYPE $mode]]
      set config {}
      if { $type eq "RESET" || $type eq "RST" || $type eq "CLK" || $type eq "CLOCK" || $type eq "INTERRUPT" } {
        if { [dict exists $port_dict CONFIG] } {
          set config [dict get $port_dict CONFIG]
        }
      } elseif { $type eq "STREAM" } {
        if { [dict exists $port_dict CONFIG] } {
          set config [dict get $port_dict CONFIG]
        }
      } elseif { $mode eq "MASTER" } {
        set config [get_intf_config $port_dict true]
      } elseif { $mode eq "SLAVE" } {
        set config [get_intf_config $port_dict false]
      }

      if { [dict exists $created_ports_dict $name] } {
        if { [llength $config] } {
          set port_obj [dict get $created_ports_dict $name]
          set_property -dict $config $port_obj
        }
      } else {
        lappend missing_ports $name
      }
    }

    if { [llength $missing_ports] } {
      set all_ports [lsort -dictionary [dict keys $created_ports_dict]]
      error "Did not create [llength $missing_ports] expected port(s): $missing_ports\nCreated ports: $all_ports"
    }
  }; # end update_port_config

  
  proc update_kernel_resources {kernel_resources ocl_content_dict ip_ns_prefix ocl_config_dict} {
    set mems  [dict_get_default $kernel_resources MEMORIES {}]
    set pipes [dict_get_default $kernel_resources PIPES {}]
    if { [llength $mems] == 0 && [llength $pipes] == 0 } {
      # Must run always this proc to handle tieing off unused AXI interfaces
      # return
    }

    set rsrc_names {}
    set all_rsrcs_dict [dict create]
    set conns [dict_get_default $kernel_resources CONNECTIONS {}]
    set kern_dict [dict create]
    set kernel_insts [dict get $ocl_content_dict kernels]
    foreach inst_dict $kernel_insts {
      dict set kern_dict [dict get $inst_dict NAME] $inst_dict
    }

    set mem_conns [${ip_ns_prefix}filter_conns $conns "memory"]
    set external_mem_names {}
    foreach rsrc_dict $mems {
      set name [dict get $rsrc_dict NAME]
      if { [dict exists $all_rsrcs_dict $name] } {
        puts "WARNING: memory name is not unique, using only first instance: $name"
        continue
      }
      lappend rsrc_names $name
      set rsrc_conns [${ip_ns_prefix}get_conn_matches $mem_conns "memory" $name]
      set is_external [string equal -nocase "external" [dict_get_default $rsrc_dict LINKAGE ""]]
      if { $is_external } {
        lappend external_mem_names $name
      }
      dict set rsrc_dict IS_PIPE false
      dict set rsrc_dict CONNECTIONS $rsrc_conns
      dict set all_rsrcs_dict $name $rsrc_dict
    }

    set pipe_conns [${ip_ns_prefix}filter_conns $conns "pipe"]
    set external_pipe_names {}
    set external_pipe_core_ports [dict create]
    foreach rsrc_dict $pipes {
      set name [dict get $rsrc_dict NAME]
      if { [dict exists $all_rsrcs_dict $name] } {
        puts "WARNING: pipe name is not unique, using only first instance: $name"
        continue
      }
      lappend rsrc_names $name
      set is_external [string equal -nocase "external" [dict_get_default $rsrc_dict LINKAGE ""]]
      if { $is_external } {
        lappend external_pipe_names $name
      }
      set rsrc_conns [${ip_ns_prefix}get_conn_matches $pipe_conns "pipe" $name]
      set core_port ""
      foreach conn_dict $rsrc_conns {
        if { [string equal -nocase [dict get $conn_dict OTHER_TYPE] "CORE"] } {
          if { $core_port ne "" } {
            error "Multiple connections to same core port '$core_port' for pipe '$name'"
          }
          set core_port [dict get $conn_dict OTHER_PORT]
        }
      }
      if { !$is_external && $core_port ne "" } {
        puts "WARNING: Found non-external pipe connection to core: pipe $name, core port '$core_port'"
        lappend external_pipe_names $name
        set is_external true
        dict set rsrc_dict LINKAGE "external"
      }
      
      if { $is_external } {
        if { $core_port eq "" } {
          error "External pipe core port is not set: $conn_dict"
        }
        if { [dict exists $external_pipe_core_ports $core_port] } {
          error "Too many connections to external pipe core port: $port"
        }
        dict set rsrc_dict EXTERNAL_PORT_NAME $core_port
        dict set external_pipe_core_ports $core_port true
        set TDATA_NUM_BYTES [dict get $ocl_config_dict ${core_port}_TDATA_NUM_BYTES]
        set TUSER_WIDTH [dict get $ocl_config_dict ${core_port}_TUSER_WIDTH]
        set fifo_config [${ip_ns_prefix}get_axis_config $TUSER_WIDTH $TDATA_NUM_BYTES "fifo"]
        dict set rsrc_dict CONFIG $fifo_config
      }
      dict set rsrc_dict IS_PIPE true
      dict set rsrc_dict CONNECTIONS $rsrc_conns
      dict set all_rsrcs_dict $name $rsrc_dict
    }

    # Get shared clock/reset nets
    set i_clk_net [get_bd_net [dict get $ocl_content_dict clk_interconnect_net]]
    set i_rst_net [get_bd_net [dict get $ocl_content_dict rst_interconnect_sync_net]]
    set k_clk_net [get_bd_net [dict get $ocl_content_dict clk_kernel_net]]
    set k_rst_net [get_bd_net [dict get $ocl_content_dict rst_kernel_sync_net]]

    # Create external memory bridge
    set has_s_mem [dict_get_default $ocl_config_dict HAS_S_MEM 0]
    set num_external_mems [llength $external_mem_names]
    if { $has_s_mem } {
      set s_mem_bridge_m_axi [${ip_ns_prefix}create_mem_bridge $ocl_content_dict $ocl_config_dict $i_clk_net $i_rst_net $num_external_mems]
    } elseif { $num_external_mems } {
      error "DSA does not support S_MEM interface"
    }

    # Create external memory interconnect
    set enable_smartconnect [dict_get_default $ocl_config_dict ENABLE_SMARTCONNECT 0]
    if { $num_external_mems && $has_s_mem } {
      if { $num_external_mems == 1 } {
        dict set all_rsrcs_dict [lindex $external_mem_names 0] EXTERNAL_CONNECTION $s_mem_bridge_m_axi
      } else {
        set s_mem_use_sc [${ip_ns_prefix}use_smart_connect "ext_mem" $enable_smartconnect]
        set s_mem_has_second_clock [expr {![string equal -nocase $k_clk_net $i_clk_net]}]
        set s_mem_intercon [${ip_ns_prefix}create_interconnect "s_mem_intercon" [list CONFIG.NUM_MI $num_external_mems CONFIG.NUM_SI 1] $s_mem_use_sc $s_mem_has_second_clock]
        connect_bd_intf_net $s_mem_bridge_m_axi [get_bd_intf_pins $s_mem_intercon/[${ip_ns_prefix}get_name_intercon_si 0]]
        if { $s_mem_use_sc } {
          connect_bd_net -net $i_clk_net [get_bd_pins $s_mem_intercon/aclk]
          connect_bd_net -net $i_rst_net [get_bd_pins $s_mem_intercon/aresetn]
          set clk2 [get_bd_pins -quiet $s_mem_intercon/aclk1]
          if { $clk2 ne "" } {
            connect_bd_net -net $k_clk_net $clk2
            #connect_bd_net -net $k_rst_net [get_bd_pins $s_mem_intercon/aresetn1]
          }
        } else {
          connect_bd_net -net $i_clk_net [get_bd_pins $s_mem_intercon/ACLK]
          connect_bd_net -net $i_rst_net [get_bd_pins $s_mem_intercon/ARESETN]
          connect_bd_net -net $i_clk_net [get_bd_pins $s_mem_intercon/S*_ACLK]
          connect_bd_net -net $i_rst_net [get_bd_pins $s_mem_intercon/S*_ARESETN]
          connect_bd_net -net $k_clk_net [get_bd_pins $s_mem_intercon/M*_ACLK]
          connect_bd_net -net $k_rst_net [get_bd_pins $s_mem_intercon/M*_ARESETN]
        }
        for {set idx 0} {$idx < $num_external_mems} {incr idx} {
          set name [lindex $external_mem_names $idx]
          dict set all_rsrcs_dict $name EXTERNAL_CONNECTION [get_bd_intf_pins $s_mem_intercon/[${ip_ns_prefix}get_name_intercon_mi $idx]]
        }
      }
    }

    # DRC for external pipe connections
    set pipe_ext_intf_names [${ip_ns_prefix}get_axis_names $ocl_config_dict]
    set missing_pipes {}
    foreach intf_name [lsort -dictionary [dict keys $external_pipe_core_ports]] {
      if { [lsearch -exact $pipe_ext_intf_names $intf_name] < 0 } {
        lappend missing_pipes $intf_name
      }
    }
    if { [llength $missing_pipes] } {
      error "DSA does not support requested external pipes: $missing_pipes"
    }

    # Terminate unused external pipe ports
    foreach intf_name $pipe_ext_intf_names {
      if { [dict exists $external_pipe_core_ports $intf_name] } {
        continue
      }
      set intf_port [get_bd_intf_ports /$intf_name]
      set conn "M_AXIS"
      set term "S_AXIS"
      if { [string equal -nocase "Slave" [get_property MODE $intf_port]] } {
        set conn "S_AXIS"
        set term "M_AXIS"
      }
      set TDATA_NUM_BYTES [dict get $ocl_config_dict ${intf_name}_TDATA_NUM_BYTES]
      set TUSER_WIDTH [dict get $ocl_config_dict ${intf_name}_TUSER_WIDTH]
      set axis_reg [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:* ${intf_name}_tieoff_reg_slice]
      set axis_config [${ip_ns_prefix}get_axis_config $TUSER_WIDTH $TDATA_NUM_BYTES "regslice"]
      set_property -dict $axis_config $axis_reg
      ${ip_ns_prefix}terminate_intf $axis_reg/$term
      connect_bd_intf_net $intf_port [get_bd_intf_pins $axis_reg/$conn]
      #puts "ETP: get_bd_intf_pins $axis_reg: [get_bd_intf_pins $axis_reg/*]"
      #puts "ETP: get_bd_ports: [get_bd_ports]"
      connect_bd_net [get_bd_ports [${ip_ns_prefix}get_axis_clk_name $intf_name]] [get_bd_pins $axis_reg/aclk]
      connect_bd_net [get_bd_ports [${ip_ns_prefix}get_axis_rst_name $intf_name]] [get_bd_pins $axis_reg/aresetn]
      ${ip_ns_prefix}dont_touch $axis_reg
      ${ip_ns_prefix}dont_touch_intf $intf_port
    }

    set res_dict [dict create]
    foreach r_name $rsrc_names {
      set rsrc_dict [dict get $all_rsrcs_dict $r_name]
      connect_resource $rsrc_dict $k_clk_net $k_rst_net $ip_ns_prefix $enable_smartconnect
    }
    return $res_dict
  }; # end update_kernel_resources

  proc connect_resource {rsrc_dict clk_net rst_net ip_ns_prefix enable_smartconnect} {
    set rsrc_name [dict get $rsrc_dict NAME]
    if {![dict exists $rsrc_dict CONNECTIONS] } {
      puts "WARNING: Expected memory/pipe '$rsrc_name' in connection"
      return
    }
    set conn_dict [dict get $rsrc_dict CONNECTIONS]

    if { [dict get $rsrc_dict IS_PIPE] } {
      # Handle pipe
      set core_side ""
      foreach pipe_side {S M} {
        set pipe_port "${pipe_side}_AXIS"
        set pipe_conn_side [${ip_ns_prefix}get_conn_other_sides $conn_dict "PIPE" "" $pipe_port]
        if { [llength $pipe_conn_side] != 1 } {
          error "Expected one pipe connection for $rsrc_name $pipe_port but got [llength $pipe_conn_side]: $pipe_conn_side"
        }
        set pipe_conn_side [lindex $pipe_conn_side 0]
        set conn_type [dict get $pipe_conn_side TYPE]
        set conn_port [dict get $pipe_conn_side PORT]
        if { [string equal -nocase $conn_type "CORE"] } {
          set core_side $pipe_side
          set pin [get_bd_intf_port -quiet $conn_port]
          if { $pin eq "" } {
            error "Could not find pipe external port for $rsrc_name $pipe_port: $conn_port"
          }
        } elseif { [string equal -nocase $conn_type "KERNEL"] } {
          set conn_inst [dict get $pipe_conn_side NAME]
          set pin [get_bd_intf_pins -quiet /$conn_inst/$conn_port]
          if { $pin eq "" } {
            error "Could not find pipe connection for $rsrc_name $pipe_port: $conn_inst/$conn_port"
          }
        } else {
          error "Unexpected pipe connection type '$conn_type' for $rsrc_name $pipe_port: $pipe_conn_side"
        }
        set ${pipe_side}_PIN $pin
      }; # end pipe_side loop

      set fifo_config [dict create]
      if { [dict exists $rsrc_dict CONFIG] } {
        set fifo_config [dict get $rsrc_dict CONFIG]
      }
      dict set fifo_config CONFIG.FIFO_DEPTH [dict get $rsrc_dict DEPTH]
      #puts "DBG: fifo config: $fifo_config"

      if { [dict exists $rsrc_dict EXTERNAL_PORT_NAME] } {
        set core_port [dict get $rsrc_dict EXTERNAL_PORT_NAME]
        set clk_name [${ip_ns_prefix}get_axis_clk_name $core_port]
        set rst_name [${ip_ns_prefix}get_axis_rst_name $core_port]
        set clk_port [get_bd_ports $clk_name -filter {DIR == I && TYPE == clk}]
        set ext_clk_net [create_bd_net "${clk_name}_net"]
        connect_bd_net -net $ext_clk_net $clk_port
        set rst_port [get_bd_ports $rst_name -filter {DIR == I && TYPE == rst}]
        set ext_rst_net [create_bd_net "${rst_name}_net"]
        connect_bd_net -net $ext_rst_net $rst_port

        if { $core_side eq "M" } {
          set s_clk_net $clk_net
          set s_rst_net $rst_net
          set m_clk_net $ext_clk_net
          set m_rst_net $ext_rst_net
        } else {
          set s_clk_net $ext_clk_net
          set s_rst_net $ext_rst_net
          set m_clk_net $clk_net
          set m_rst_net $rst_net
        }
      } else {
        set s_clk_net $clk_net
        set s_rst_net $rst_net
        set m_clk_net ""
        set m_rst_net ""
      }
      
      ${ip_ns_prefix}connect_pipe_fifo $rsrc_name $S_PIN $M_PIN $s_clk_net $s_rst_net $fifo_config $m_clk_net $m_rst_net

    } else { 
      # Handle memory
      set connections {}
      set mem_conn_sides [${ip_ns_prefix}get_conn_other_sides $conn_dict "MEMORY"]
      foreach mem_conn_side $mem_conn_sides {
        set conn_type [dict get $mem_conn_side TYPE]
        if { [string equal -nocase $conn_type "CORE"] } {
          # These are handled by $rsrc_dict EXTERNAL_CONNECTION 
          continue
        }
        set conn_port [dict get $mem_conn_side PORT]
        set conn_inst [dict get $mem_conn_side NAME]
        set pin [get_bd_intf_pins -quiet "/$conn_inst/$conn_port"]
        if { $pin eq "" } {
          error "Could not find memory connection for $rsrc_name to $conn_type $conn_inst/$conn_port"
        }
        lappend connections $pin
      }
      set addr_offset [dict get $rsrc_dict ADDR_OFFSET]
      set addr_range  [dict get $rsrc_dict ADDR_RANGE]
      set data_width  [dict_get_default $rsrc_dict DATA_WIDTH 0]
      set ext_conn    [dict_get_default $rsrc_dict EXTERNAL_CONNECTION {}]
      ${ip_ns_prefix}connect_mem $rsrc_name $clk_net $rst_net $connections $addr_offset $addr_range $data_width $ext_conn $enable_smartconnect
    }
  }; # end connect_resource

  proc get_implicit_ocl_ip_config {dsa_ports ocl_ip_vlnv} {
    set num_clks 0
    set found_modes [dict create]
    set implicit_ip_config [dict create]
    foreach port_dict $dsa_ports {
      set mode [string toupper [dict get $port_dict MODE]]
      set type [string toupper [dict_get_default $port_dict TYPE $mode]]
      if { $type eq "CLOCK" || $type eq "CLK"} {
        incr num_clks
      }
      
      if { $mode ne "MASTER" && $mode ne "SLAVE" } {
        continue
      }
      set name [dict get $port_dict NAME]
      if { $name ne "S_AXI" && $name ne "M_AXI" } {
        continue
      }

      set is_master [expr {$mode eq "MASTER"}]

      set ip_props [list USER_WIDTH]
      if { $is_master } {
        set prefix "M_"
        lappend ip_props M_DATA_WIDTH M_ADDR_WIDTH M_ID_WIDTH
      } else {
        set prefix "S_"
        lappend ip_props S_DATA_WIDTH S_ADDR_WIDTH
      }

      set count 1
      if { [dict exists $found_modes $mode] } {
        incr count [dict get $found_modes $mode]
      }
      dict set found_modes $mode $count
      foreach ip_prop $ip_props {
        set port_prop $ip_prop
        regsub "^${prefix}" $port_prop {} port_prop
        if { ![dict exists $port_dict $port_prop] } {
          puts "WARNING: did not find '$port_prop' value in '$name' $mode platform port dict"
          continue
        }
        set new_val [dict get $port_dict $port_prop]
        if { $count == 1 } {
          dict set implicit_ip_config $ip_prop $new_val
        } else {
          set curr_val [dict get $implicit_ip_config $ip_prop]
          if { $curr_val != $new_val } {
            set mode_desc ""
            if { $port_prop ne $ip_prop } {
              set " $mode"
            }
            error "Value of '$port_prop' must be the same in all$mode_desc platform interfaces, found '$curr_val' and '$new_val'"
          }
        }
      }
      if { $is_master } {
        dict set implicit_ip_config "NUM_MI" $count
      }
    }; # end ports loop
    #if { $num_clks > 2 || $num_clks < 1 } {
    #  error "Expected 1 or 2 platform clocks but found $num_clks"
    #}
    #dict set implicit_ip_config HAS_KERNEL_CLOCK [expr {$num_clks == 2}]
    return $implicit_ip_config
  }; # end get_implicit_ocl_ip_config

  proc update_kernel_info {kernels_name} {
    upvar $kernels_name kernels
    if { [llength $kernels] == 0 } {
      set default_vlnv "xilinx.com:ip:ocl_axi_addone:*"
      puts "Using default kernel(s): 1x $default_vlnv"
      lappend kernels [dict create VLNV $default_vlnv]
    }

    set default_kernel [dict create \
      MASTER      m_axi_gmem \
      SLAVE       s_axi_control \
      CLK         ap_clk \
      RST         ap_rst_n \
      ADDR_OFFSET 0x00000000 \
      ADDR_RANGE  0x1000 \
      CONFIG      {} \
      DEBUG       0 \
    ];
    
    set new_kernels {}
    foreach k_dict $kernels {
      if { ![dict exists $k_dict VLNV] } {
        error "Kernel must specify a VLNV: $k_dict"
      }
      set new_k_dict [dict merge $default_kernel $k_dict]
      dict set new_k_dict MASTER [lsort -unique [dict get $new_k_dict MASTER]]
      lappend new_kernels $new_k_dict
    }
    set kernels $new_kernels
  }; # end update_kernel_info

  proc update_ocl_ip_info {ocl_ip_dict dsa_ports} {
    if { [dict exists $ocl_ip_dict VLNV] } {
      set ocl_ip_vlnv [dict get $ocl_ip_dict VLNV] 
    } else {
      set ocl_ip_vlnv "xilinx.com:ip:ocl_block:1.0"
      dict set ocl_ip_dict VLNV $ocl_ip_vlnv
    }
    
    # Derive HIP congfig from DSA port parameters then check that the actual HIP config values match 
    set implicit_ip_config [get_implicit_ocl_ip_config $dsa_ports $ocl_ip_vlnv]

    set res_config $implicit_ip_config
    if { [dict exists $ocl_ip_dict CONFIG] } {
      foreach {name value} [dict get $ocl_ip_dict CONFIG] {
        regsub -nocase {^CONFIG\.} $name {} name
        set name [string toupper $name]
        if { [dict exists $implicit_ip_config $name] } {
          set implicit_value [dict get $implicit_ip_config $name]
          if { $value != $implicit_value } {
            error "OCL IP value for '$name' derived from boundary information ($implicit_value) does not match explicit value ($value)" 
          }
        } else {
          dict set res_config $name $value
        }
      }
    }
    if { ![dict exists $res_config SYNC_RESET] } {
      # Use synq-reset if not specified
      dict set res_config SYNC_RESET 1
    }
    set varname "SDACCEL_OCL_BLOCK_CONFIG"
    if { [info exists ::env($varname)] } {
      set varval $::env($varname)
      puts "INFO: Using env($varname) value: $varval"
      # last dict passed to dict merge takes precedence
      set res_config [dict merge $res_config $varval]
    }
    puts "INFO: Updated OCL block configuration: $res_config"
    return $res_config
  }; # end update_ocl_ip_info

  proc get_idbridge_ip { idbridges ext_mst_name} {
      foreach idbridge $idbridges {
          set EXT_MST_NAME [dict get $idbridge EXT_PORT_NAME ]
          if {[string match -nocase $ext_mst_name $EXT_MST_NAME]} {
              return [dict get $idbridge NAME]
          }
      }
  }

  proc get_intf_addr_seg { intf } {
      set addr_space [lindex [get_bd_addr_spaces -of_objects $intf] 0 ]
      set addr_seg   [lindex [get_bd_addr_segs -of_objects $addr_space] 0 ]
      return $addr_seg
  }

  proc set_port_config {config port} {
    if { [llength $config] } {
      set_property -dict $config $port
    }
  }

  proc get_intf_config {port_dict is_master} {
    set props [list PROTOCOL ADDR_WIDTH DATA_WIDTH]
    #if { !$is_master } {
    #  lappend props MAX_BURST_LENGTH
    #}
    set config {}
    foreach prop $props {
      if { [dict exists $port_dict $prop] } {
        lappend config CONFIG.$prop [dict get $port_dict $prop]
      }
    }
    if { 0 } {
      # TODO: set user widths
      # Set all the user widths to the same value
      set user_width [dict get $port_dict USER_WIDTH]
      foreach prop [list ARUSER_WIDTH AWUSER_WIDTH BUSER_WIDTH RUSER_WIDTH WUSER_WIDTH] {
        lappend config CONFIG.$prop $user_width
      }
    }
    return $config
  }

  proc get_idbridge_config {port_dict} {
    set config {}
    foreach prop [list PROTOCOL ADDR_WIDTH DATA_WIDTH] {
      lappend config CONFIG.$prop [dict get $port_dict $prop]
    }
    return $config
  }

  proc source_ocl_ip_tcl_file {vlnv {ipdir ""}} {
    set ns "ocl_block_utils"
    set ns_prefix "${ns}::" 
    if { [namespace exists ::$ns] } {
      return $ns_prefix
    }

    set varname "SDACCEL_OCL_BLOCK_UTILS"
    if { [info exists ::env($varname)] && $::env($varname) ne "" } {
      set path $::env($varname)
      puts "INFO: Using env($varname) value: $path"
    } else {
      set path [file join [get_script_dir] ${ns}.tcl]
    }
    if { [file exists $path] } {
      puts "Sourcing file: $path"
      namespace eval :: [list source -notrace $path]
      return $ns_prefix
    }

    error "Could not find file: $path"

    if { $ipdir eq "" } {
      set ips [get_ipdefs -all $vlnv]
      if { [llength $ips] > 1 } {
        set files {}
        foreach ip $ips {
          lappend files [get_property XML_FILE_NAME $ip]
        }
        error "Found multiple '$vlnv' IP in catalog: $files"
      } elseif { [llength $ips] == 0 } {
        error "Could not find IP in catalog: $vlnv"
      }
      set ip [lindex $ips 0]
      set path [get_property XML_FILE_NAME $ip]
      set ipdir [file dirname $path]
    }
    if { ![file exists $ipdir] } {
      error "Could not find '$vlnv' IP root: $ipdir"
    }
    
    set path [file join $ipdir bd ${ns}.tcl]
    if { [file exists $path] } {
      puts "Sourcing $vlnv IP file: $path"
      namespace eval :: [list source -notrace $path]
      return $ns_prefix
    }
    set first_path [file join $ipdir bd ${ns}.tcl]
    error "Could not find '$vlnv' file: $path"
  }; # end source_ocl_ip_tcl_file

  proc init_ocl_project {design_name {kernel_ip_dirs {}}} {
    if { $kernel_ip_dirs ne "" } {
      puts "Setting ip_repo_paths: $kernel_ip_dirs"
      set_property ip_repo_paths $kernel_ip_dirs [current_project] 
      update_ip_catalog
    }
    set_msg_config -id "Timing 38-282" -new_severity ERROR 
    create_bd_design $design_name -bdsource SDACCEL
    current_bd_design $design_name 
  }; # end init_ocl_project

  proc create_ocl_dcp {ocl_dcp {num_jobs 1}} {
    #set start_time [clock seconds]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]; # TODO: remove this work-around
    launch_runs synth_1 -jobs $num_jobs
    wait_on_run synth_1

    # check for any run failure
    # and write the "cookie file" for Dennis' messaging support
    set any_run_fail false
    set runs [get_runs -filter {IS_SYNTHESIS == 1}]
    foreach _run $runs {
      set run_status [get_property STATUS [get_runs $_run]]
      set run_dir [get_property DIRECTORY [get_runs $_run]]
      set run_name [get_property NAME [get_runs $_run]]
      set cookie_file $run_dir/.xocc_runmsg.txt

      set outfile [open $cookie_file w]
      if { [string equal $run_name "synth_1"] } {
        puts $outfile "Creating synthesis checkpoint for OCL region"
      } else {
        puts $outfile "Creating synthesis checkpoint for kernel/ip"
      }
      close $outfile

      # puts "DEBUG: run '$_run' has status '$run_status'"
      if { [string equal $run_status "synth_design ERROR"] } {
        puts "ERROR: run '$_run' failed, please look at the log file for more information"
        set any_run_fail true
      }
      if { [string equal $run_status "Scripts Generated"] } {
        puts "ERROR: run '$_run' couldn't start because one or more of the prerequisite runs failed"
        set any_run_fail true
      }
    }

    if { $any_run_fail } {
      set startdir [pwd]
      error2file $startdir "One or more synthesis runs failed during ocl dcp generation" 
    }

    open_run synth_1 -name synth_1
    write_checkpoint $ocl_dcp -force

    #set run_time [expr [clock seconds] - $start_time]
    #puts "PROFILE:create_ocl_dcp took $run_time seconds"
    
  }; # end create_ocl_dcp

  proc create_bitstreams_with_run {dsa_part dsa_uses_pr ocl_inst_path
                                   dsa_uses_pr_shell_dcp dsa_full_dcp pr_shell_dcp 
                                   out_ocl_bitstream out_platform_bitstream 
                                   worst_negative_slack clock_name clock_freq 
                                   vivado_user_tcl 
                                   dsa_uses_static_synth_dcp ocl_dcp 
                                   disableLockAndUpdateDesign
                                   ocl_region_uses_user_clock_freq} {
    set startdir [pwd]
    set start_time [clock seconds]

    if {$disableLockAndUpdateDesign} {
      set_param hd.useStaticResourceForRMRouting 1
    }
    # puts "--- DEBUG: create_project ipiimpl ipiimpl -part $dsa_part -force"
    create_project ipiimpl ipiimpl -part $dsa_part -force
    set_property coreContainer.enable 1 [current_project]
    set_property design_mode GateLvl [current_fileset]

    ### Open the platform DCP or the PR shell checkpoint
    ### For pr shell dcp, the design is already blackboxed
    if { !$dsa_uses_pr_shell_dcp } {
      if { [catch {
      # puts "--- DEBUG: add_file $dsa_full_dcp"
      add_files $dsa_full_dcp
        # puts "--- DEBUG: link_design"
        link_design
      } catch_res] } {
        error2file $startdir "problem reading DSA checkpoint" $catch_res
      }

      # puts "--- DEBUG: update_design -black_box -cell [get_cells $ocl_inst_path]"
      if { [catch {update_design -black_box -cell [get_cells $ocl_inst_path]} catch_res] } {
        error2file $startdir "problem updating DSA design" $catch_res
      }

    } else {
      if { [catch {
        # puts "--- DEBUG: add_file $pr_shell_dcp"
      add_files $pr_shell_dcp
        # puts "--- DEBUG: link_design"
        link_design
      } catch_res] } {
        error2file $startdir "problem reading DSA checkpoint" $catch_res
      }
    }

    if { !$dsa_uses_static_synth_dcp } {
      # puts "--- DEBUG: lock_design -level routing"
      if { [catch {lock_design -level routing} catch_res] } {
        error2file $startdir "problem locking DSA design" $catch_res
      }
    }

    ### Read in the ocl region DCP
    # puts "--- DEBUG: read_checkpoint -cell $ocl_inst_path $ocl_dcp"
    if { [catch {read_checkpoint -cell $ocl_inst_path $ocl_dcp} catch_res] } {
      error2file $startdir "problem reading OCL region checkpoint" $catch_res
    }

    # by default, turn off intermediate dcp file generation in impl run to reduce runtime, 
    # user can overwrite this by setting xp_vivado_params in sdaccel script
    set_param project.writeIntermediateCheckpoints 0

    # Note: this must be after set_param project.writeIntermediateCheckpoints
    source $vivado_user_tcl
    
    ### Complete the flow
    # Note: this must be after source $vivado_user_tcl
    if {!$disableLockAndUpdateDesign} {
      # puts "--- DEBUG: Disable Lock and Update Design is false"
      set_property STEPS.INIT_DESIGN.TCL.POST "../../../post_init.tcl" [get_runs impl_1]
    }
    # puts "--- DEBUG: source the vivado user tcl for xp_vivado_params and xp_vivado_props"

    # create a user clock constraint if set
    if {$ocl_region_uses_user_clock_freq} {
       write_user_clock_constraint $ocl_inst_path $clock_name $clock_freq
    }

    launch_runs impl_1
    if { [catch {wait_on_run impl_1} catch_res] } {
      error2file $startdir "problem implementing OCL region" $catch_res
    }

    # write the "cookie file" for Dennis' messaging support
    set run_dir [get_property DIRECTORY [get_runs impl_1]]
    set cookie_file $run_dir/.xocc_runmsg.txt
    set outfile [open $cookie_file w]
    puts $outfile "Creating the bitstream for opencl binary"
    close $outfile

    # open the implemented design here
    open_run impl_1

    set timingFailedPaths [ get_timing_paths -quiet -slack_lesser_than $worst_negative_slack ]
    set isPostRouteDcpGenerated false
    if { [ llength $timingFailedPaths ] > 0 } {
      # if there are timing paths that do not meet specified WNS, try frequency scaling
      write_checkpoint opencldesign_routed.dcp
      set isPostRouteDcpGenerated true
      report_timing_summary -slack_lesser_than $worst_negative_slack -file opencldesign_timing_summary.rpt
    } 

    # Added hold violation check per Steven's request
    # puts "Check for hold violation"
    set hold [ get_property SLACK [get_timing_paths -hold -quiet] ] 
    # The command above will return the worst hold slack. If it's negative, we error out.
    if { $hold < 0 } {
      if { !$isPostRouteDcpGenerated } {
        write_checkpoint opencldesign_routed.dcp
      }
      report_timing_summary -hold -file opencldesign_timing_summary_hold.rpt
      puts "ERROR: Design failed to meet timing - hold violation."
      error2file $startdir "design did not meet timing - hold violation"
      return false
    }

    # Based on Steven's request
    # Even if timing was met for given WNS, use the freq scaling proc to write the final freq in the xclbin
    # In case where kernel clk frequency is overwritten by user(parameter/pre-hook),this will ensure that the scaled 
    # frequency is written out instead of the frequency from the DSA.
    if { [write_new_ocl_freq $worst_negative_slack $ocl_inst_path $clock_name $clock_freq] == "0" } {
      # if frequency scaling fails, issue timing failed error and abort
      puts "ERROR: Design failed to meet timing."
      puts "ERROR: Failed timing checks (paths):\n\t[ join $timingFailedPaths \n\t ]\n\n"
      puts "ERROR: Please check the routed checkpoint(opencldesign_routed.dcp) and timing summary report(opencldesign_timing_summary.rpt) for more information."
      error2file $startdir "design did not meet timing"
      return false
    }

    ### Write out the bitstreams
    if { [catch {
    if { $dsa_uses_pr } {
      if ($disableLockAndUpdateDesign) {
        write_bitstream -cell OpenCL_static_i/reconfigurable_partition $out_ocl_bitstream -force
      } else {
        write_bitstream -cell $ocl_inst_path $out_ocl_bitstream -force
      }
    } else {
      write_bitstream $out_platform_bitstream -force
    }
    } catch_res] } {
      error2file $startdir "problem writing OCL region bitstream" $catch_res
    }
    
    # set run_time [expr [clock seconds] - $start_time]
    # puts "PROFILE: create_bitstreams_with_run took $run_time seconds"
    
  }; # create_bitstreams_with_run

proc create_bitstreams_with_runs_for_expanded_pr {dsa_full_dcp ocl_dcp dsa_static_xdef 
                                                  ocl_inst_path parent_rm_instance_path
                                                  out_ocl_bitstream dsa_part 
                                                  worst_negative_slack clock_name clock_freq 
                                                  vivado_user_tcl ocl_region_uses_user_clock_freq} {
    set startdir [pwd]
    set start_time [clock seconds]
   
    set_param hd.useStaticResourceForRMRouting 1
    catch {set_param hd.checkIllegalUpdateDesignBlackbox false}

    if { [catch {open_checkpoint -skip_xdef $dsa_full_dcp} catch_res] } {
      error2file $startdir "problem reading DSA full checkpoint" $catch_res
    }
    if { [catch {read_xdef -no_clear $dsa_static_xdef} catch_res] } {
      error2file $startdir "problem reading static xdef" $catch_res
    }
    if { [catch {update_design -black_box -cell [get_cells $ocl_inst_path]} catch_res] } {
      error2file $startdir "problem black-boxing OCL region design" $catch_res
    }
    if { [catch {lock_design -level routing -static} catch_res] } {
      error2file $startdir "problem locking static region" $catch_res
    }
    if { [catch {read_checkpoint -cell $ocl_inst_path $ocl_dcp} catch_res] } {
      error2file $startdir "problem reading OCL region checkpoint" $catch_res
    }

    # create a user clock constraint if set
    if {$ocl_region_uses_user_clock_freq} {
       write_user_clock_constraint $ocl_inst_path $clock_name $clock_freq
    }

    set updated_full_dcp "updated_full_design.dcp"
    if { [catch {write_checkpoint $updated_full_dcp} catch_res] } {
      error2file $startdir "problem writing out an updated full checkpoint" $catch_res
    }
    if { [catch {close_project} catch_res] } {
      error2file $startdir "problem closing diskless project" $catch_res
    }
    
    create_project ipiimpl ipiimpl -part $dsa_part -force
    set_property coreContainer.enable 1 [current_project]
    set_property design_mode GateLvl [current_fileset]

    add_files $updated_full_dcp
    set_property STEPS.INIT_DESIGN.TCL.POST "../../../post_init.tcl" [get_runs impl_1]
    if { [file exists "pre_place.tcl"] } {
      set_property STEPS.PLACE_DESIGN.TCL.PRE "../../../pre_place.tcl" [get_runs impl_1]
    }
    source $vivado_user_tcl

    launch_runs impl_1
    if { [catch {wait_on_run impl_1} catch_res] } {
      error2file $startdir "problem implementing OCL region" $catch_res
    }

    # open the implemented design here
    open_run impl_1

    set timingFailedPaths [ get_timing_paths -quiet -slack_lesser_than $worst_negative_slack ]
    set isPostRouteDcpGenerated false
    if { [ llength $timingFailedPaths ] > 0 } {
      # if there are timing paths that do not meet specified WNS, try frequency scaling
      write_checkpoint opencldesign_routed.dcp
      set isPostRouteDcpGenerated true
      report_timing_summary -slack_lesser_than $worst_negative_slack -file opencldesign_timing_summary.rpt
    } 

    # Added hold violation check per Steven's request
    set hold [ get_property SLACK [get_timing_paths -hold -quiet] ] 
    # The command above will return the worst hold slack. If it's negative, we error out.
    if { $hold < 0 } {
      if { !$isPostRouteDcpGenerated } {
        write_checkpoint opencldesign_routed.dcp
      }
      report_timing_summary -hold -file opencldesign_timing_summary_hold.rpt
      puts "ERROR: Design failed to meet timing - hold violation."
      error2file $startdir "design did not meet timing - hold violation"
      return false
    }

    # Based on Steven's request
    # Even if timing was met for given WNS, use the freq scaling proc to write the final freq in the xclbin
    # In case where kernel clk frequency is overwritten by user(parameter/pre-hook),this will ensure that the scaled 
    # frequency is written out instead of the frequency from the DSA.
    if { [write_new_ocl_freq $worst_negative_slack $ocl_inst_path $clock_name $clock_freq] == "0" } {
      # if frequency scaling fails, issue timing failed error and abort
      puts "ERROR: Design failed to meet timing."
      puts "ERROR: Failed timing checks (paths):\n\t[ join $timingFailedPaths \n\t ]\n\n"
      puts "ERROR: Please check the routed checkpoint(opencldesign_routed.dcp) and timing summary report(opencldesign_timing_summary.rpt) for more information."
      error2file $startdir "design did not meet timing"
      return false
    }


    ### Write out the bitstreams
    if { [catch {
      write_bitstream -cell $parent_rm_instance_path $out_ocl_bitstream -force
    } catch_res] } {
      error2file $startdir "problem writing OCL region bitstream" $catch_res
    }
    
    # set run_time [expr [clock seconds] - $start_time]
    # puts "PROFILE: create_bitstreams_with_run took $run_time seconds"
    
  }; # create_bitstreams_with_run_for_exapnded_pr

  proc create_bitstreams {dsa_uses_pr dsa_uses_static_synth_dcp dsa_uses_pr_shell_dcp 
                          dsa_full_dcp pr_shell_dcp ocl_dcp dsa_static_xdef
                          ocl_inst_path parent_rm_instance_path
                          out_ocl_bitstream out_platform_bitstream 
                          gen_extra_run_data worst_negative_slack clock_name clock_freq ocl_region_uses_user_clock_freq} {
    set startdir [pwd]    
    set start_time [clock seconds]
    ### Open the platform DCP or the PR shell checkpoint
    ### For pr shell dcp, the design is already blackboxed
    if { !$dsa_uses_pr_shell_dcp } {
      if { $dsa_static_xdef != "" } {
        # expanded PR support
        set_param hd.useStaticResourceForRMRouting 1
        catch {set_param hd.checkIllegalUpdateDesignBlackbox false}

        if { [catch {open_checkpoint -skip_xdef $dsa_full_dcp} catch_res] } {
          error2file $startdir "problem reading DSA checkpoint" $catch_res
        }
        if { [catch {read_xdef -no_clear $dsa_static_xdef} catch_res] } {
          error2file $startdir "problem reading DSA xdef" $catch_res
        }
      } else {
        if { [catch {open_checkpoint $dsa_full_dcp} catch_res] } {
          error2file $startdir "problem reading DSA checkpoint" $catch_res
        }
      }
      if { [catch {update_design -black_box -cell [get_cells $ocl_inst_path]} catch_res] } {
        error2file $startdir "problem updating DSA design" $catch_res
      }
    } else {
      #Temp hack to disable MLO when opening dcp created with older vivado version
      set_param logicopt.enableMandatoryLopt 0
      if { [catch {open_checkpoint $pr_shell_dcp} catch_res] } {
        error2file $startdir "problem reading DSA shell checkpoint" $catch_res
      }
      set_param logicopt.enableMandatoryLopt 1
    }

    if { [catch {
    if { !$dsa_uses_static_synth_dcp } {
      if { $dsa_static_xdef != "" } {
        lock_design -level routing -static
      } else {
        lock_design -level routing
      }
    }
    } catch_res] } {
      error2file $startdir "problem locking DSA design" $catch_res
    }

    ### Read in the ocl region DCP
    if { [catch {read_checkpoint -cell $ocl_inst_path $ocl_dcp} catch_res] } {
      error2file $startdir "problem reading OCL region checkpoint" $catch_res
    }

    # create a user clock constraint if set
    if {$ocl_region_uses_user_clock_freq} {
       write_user_clock_constraint $ocl_inst_path $clock_name $clock_freq
    }

    ### Complete the flow
    if { [catch {opt_design} catch_res] } {
      error2file $startdir "problem optimizing design" $catch_res
    }
    set_property SEVERITY {Warning} [get_drc_checks HDPR-5]
    if { [catch {place_design} catch_res] } {
      error2file $startdir "problem placing design" $catch_res
    }
    if { [catch {route_design} catch_res] } {
      error2file $startdir "problem routing design" $catch_res
    }
    
    set timingFailedPaths [ get_timing_paths -quiet -slack_lesser_than $worst_negative_slack ]
    set isPostRouteDcpGenerated false
    if { [ llength $timingFailedPaths ] > 0 } {
      # if there are timing paths that do not meet specified WNS, try frequency scaling
      write_checkpoint opencldesign_routed.dcp
      set isPostRouteDcpGenerated true
      report_timing_summary -slack_lesser_than $worst_negative_slack -file opencldesign_timing_summary.rpt
    } 

    # Added hold violation check per Steven's request
    set hold [ get_property SLACK [get_timing_paths -hold -quiet] ] 
    # The command above will return the worst hold slack. If it's negative, we error out.
    if { $hold < 0 } {
      if { !$isPostRouteDcpGenerated } {
        write_checkpoint opencldesign_routed.dcp
      }
      report_timing_summary -hold -file opencldesign_timing_summary_hold.rpt
      puts "ERROR: Design failed to meet timing - hold violation."
      error2file $startdir "design did not meet timing - hold violation"
      return false
    }

    # Based on Steven's request
    # Even if timing was met for given WNS, use the freq scaling proc to write the final freq in the xclbin
    # In case where kernel clk frequency is overwritten by user(parameter/pre-hook),this will ensure that the scaled 
    # frequency is written out instead of the frequency from the DSA.
    if { [write_new_ocl_freq $worst_negative_slack $ocl_inst_path $clock_name $clock_freq] == "0" } {
      # if frequency scaling fails, issue timing failed error and abort
      puts "ERROR: Design failed to meet timing."
      puts "ERROR: Failed timing checks (paths):\n\t[ join $timingFailedPaths \n\t ]\n\n"
      puts "ERROR: Please check the routed checkpoint(opencldesign_routed.dcp) and timing summary report(opencldesign_timing_summary.rpt) for more information."
      error2file $startdir "design did not meet timing"
      return false
    }
 
    # generate timing summary and utilization reports
    if { $gen_extra_run_data } {
      set rootname [file rootname $ocl_dcp]
      write_checkpoint ${rootname}_routed.dcp
      report_utilization -file ${rootname}_utilization_routed.rpt
      report_timing_summary -max_paths 10 -file ${rootname}_timing_summary_routed.rpt
    }

    ### Write out the bitstreams
    if { [catch {
    if { $dsa_uses_pr } {
      set rm_inst_path $ocl_inst_path
      if { $parent_rm_instance_path != "" } {
        set rm_inst_path $parent_rm_instance_path
      } 
      write_bitstream -cell $rm_inst_path $out_ocl_bitstream -force
    } else {
      write_bitstream $out_platform_bitstream -force
    }
    } catch_res] } {
      error2file $startdir "problem writing design bitstream" $catch_res
    }
    
    # set run_time [expr [clock seconds] - $start_time]
    # puts "PROFILE:create_bitstreams took $run_time seconds"
    
  }; # create_bitstreams

# this proc returns 0 if it fails to find a scaled down frequency.
# if it succeeds, the scaled down freq is returned
  proc write_new_ocl_freq {worst_negative_slack ocl_inst_path clock_name clock_freq} {
    set startdir [pwd]
    if { [string equal $clock_name ""] } {
      return 0;
    }

    set clock_pin_path "$ocl_inst_path/$clock_name"
    # puts "--- DEBUG: Clock pin full path is $clock_pin_path"

    set new_ocl_freq [get_achievable_kernel_freq $clock_pin_path $worst_negative_slack]
    # get_achievable_kernel_freq returns 0 if some other clock is negative
    # we can only auto scale kernel clock; for other clocks, we should just error out
    if { [string equal $new_ocl_freq "0"] } {
      return 0
    }

    # Sonal has updated the frequency scaling on the driver side so that the hardware now runs at 
    # every 10MHz interval, , rather than 20MHz interval before
    # example: int(173.1)=173; 173/20=8;  173/20*20=8*20 = 160    (before)
    #          int(173.1)=173; 173/10=17; 173/10*10=17*10 = 170   (current)
    # puts "new_ocl_freq is $new_ocl_freq"
    set snapped_ocl_freq [expr {int($new_ocl_freq)/10*10}]
    if { $snapped_ocl_freq < $clock_freq } {
      puts "WARNING: One or more timing paths failed timing targeting $clock_freq MHz. This design may not work properly on the board with this target frequency. The frequency is being automatically changed to $snapped_ocl_freq MHz"
      warning2file $startdir "WARNING: One or more timing paths failed timing targeting $clock_freq MHz. This design may not work properly on the board with this target frequency. The frequency is being automatically changed to $snapped_ocl_freq MHz"

      # write the new ocl frequency to the file "_new_ocl_freq"
      # puts "--- DEBUG: Writing new value \'$new_ocl_freq\' to file _new_ocl_freq"
      set outfile [open "_new_ocl_freq" w]
      puts $outfile "$new_ocl_freq"
      close $outfile
    }
    return $new_ocl_freq;

  }

  proc get_dsa_info {dsa_name dsa_file_name dsa_dcp_name ocl_region_name build_flow_name use_pr_name} {
    upvar $dsa_file_name dsa_file $dsa_dcp_name dsa_dcp $ocl_region_name ocl_region $build_flow_name build_flow $use_pr_name use_pr
    set dsa_path $env(RDI_ROOT)/data/sdaccel/board_support/$dsa_name/
    if { ![file exists $dsa_path] } {
      error "Could not find '$dsa_name' at $dsa_path"
    }
    set dsa_file [glob -nocomplain $dsa_path/*.dsa]
    if { [llength $dsa_file] != 1 } {
      error "Could not find single .dsa file in $dsa_path"
    }
    set cwd [pwd]
    set unzip_dir "$cwd/dsa_unzip/$dsa_name"
    file mkdir $unzip_dir
    cd $unzip_dir
    if { [catch {upzip $dsa_file} res] } {
      cd $cwd
      error "Problem unzipping dsa: $res"
    }
    cd $cwd

    set dsa_xml_file $unzip_dir/dsa.xml
    if { ![file exists $dsa_xml_file] } {
      set dsa_xml_file [glob -nocomplain $unzip_dir/*.xml]
      if { [llength $dsa_xml_file] != 1 } {
        error "Could not find DSA xml file in $unzip_dir"
      }
    }
    set dsa_dcp [glob -nocomplain $unzip_dir/*.dcp]
    if { [llength $dsa_dcp] != 1 } {
      error "Could not find DSA dcp file in $unzip_dir"
    }

    set fp [open "somefile" r]
    set file_data [read $fp]
    close $fp
    
    set data [split $file_data "\n"]
    set build_flow ""
    set ocl_region ""
    set use_pr ""
    foreach line $data {
      regexp {Build Flow="([^"]*)"} $line {} build_flow; #])" <-- fix vim syntax highlighting
      regexp {InstancePath="([^"]*)"} $line {} ocl_region; #])"
      regexp {Param Name="USE_PR" Value="([^"]*)"} $line {} use_pr; #])"
    }
  }; # end get_dsa_info

  # Compute the acheivable kernel frequency
  # Authur: Steven Li 
  # Input: kernelClockPin - the clock pin name of the kernel clock.
  #        sysClkWnsThreshold - the threshold in which we consider the system clocks as 
  #                             meeting timing, typical value 0ns or -0.1ns. 
  #
  # Return: achievable kernel frequency in MHz unit with 1 decimal point
  #         If kernel slack is >= sysClkWnsThreshold, return the target kernel frequency.
  #         0 if kernel clock not found, or any system clock slack < sysClkWnsThreshold
  proc get_achievable_kernel_freq { kernelClockPin sysClkWnsThreshold} {
    set kernelClk [get_clocks -of_objects [get_pins $kernelClockPin]]

    # puts "Kernel clock: $kernelClk"

    set freq 0

    set tps [get_timing_paths -max_paths 1 -sort_by group]

    # tps is already sorted from worst clock to best clock
    # loop through each clock until slack >= sysClkWnsThreshold and the kernel freq is computed
    foreach tp $tps {
      set slk [get_property SLACK $tp]
      set grp [get_property GROUP $tp]
      # puts "Path: Group=$grp Slack=$slk"
      # report_property $tp

      if {$slk < $sysClkWnsThreshold} {
        if {[string compare $grp $kernelClk] == 0} {
          set period [get_property PERIOD [get_clocks [get_property ENDPOINT_CLOCK $tp]]]
          set freq [expr int(10000.0 / ($period - $slk)) / 10.0]
        } else {
          # negative WNS for other clock
          return 0
        }
      } else {
        # slack is +ve
        if {[string compare $grp $kernelClk] == 0} {
          set period [get_property PERIOD [get_clocks [get_property ENDPOINT_CLOCK $tp]]]
          set freq [expr int(10000.0 / $period) / 10.0]
          return $freq
        } else {
          if {$freq != 0} {
            # +ve clock on other clock, if freq is set, we can return now
            return $freq
          }
        }
      }
    }

    return $freq
  }

  # convert frequency in MHz to period in ns
  proc convert_freq_to_period {freq} {
    return [expr {1000.000 / $freq}]
  }; # end convert_freq_to_period

  # create a clock on the output pin of mmcm, overwriting a generated clock
  proc write_user_clock_constraint {inst clk_name freq} {
    set clock_period [convert_freq_to_period $freq]
    set source_pin [get_pins [get_property SOURCE_PINS [get_clocks -of_objects [get_pins $inst/$clk_name]]]]
    create_clock -name USER_KERNEL_CLK -period $clock_period $source_pin
  }; # end write_user_clock_constraint

}; # end namespace

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
