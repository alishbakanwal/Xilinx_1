namespace eval rt {
    proc elaborate {module gate_clock map_to_scan {params {}}} {
        start_state "Elaborate"

        # normalize param list: {x 2} -> { {x 2} }
        if {[llength $params] == 2 &&
            [llength [lindex $params 0]] == 1} {
            set params [list $params]
        }

        set st [$rt::db elaborate $module $gate_clock $map_to_scan $params]
        stop_state "Elaborate"
        if {$st != 0} {
            return -code error "elaborate failed"
        }
        set sdcrt::currMod [[rt::design] topModule]
        return
    }


  proc runOneSpin {} {
    set outdir ./formal_[pid]
    exec mkdir -p $outdir
    puts ""
    puts "Running OneSpin in $outdir"
  
    #call write verilog first
    set revised $outdir/output_[pid].v
    write_verilog $revised

    global top
    if {[info exists rt::top]} {
      set ttop $rt::top
    } elseif {[info exists top]} {
      set ttop $top
    } else {
      puts "Top not set??"
      return 0
    }

    # now create onespin script
    set sfile [file normalize $outdir/formal.tcl]
    set fp [open $sfile "w"]
    if {$fp eq ""} {
      puts "could not open file"
      return 0
    }
  
    puts $fp "load_settings ec_fpga_xilinx_rtf"
  
    foreach line $::rt::rtlData {
      set language [lindex $line 0]
      #Need to handle incl Dirs and defines...
      set library  [lindex $line 3]
      set files [lindex $line 4]
   
      switch $language {
        "vlog" {
          puts $fp "read_verilog -golden $files"
        }
        "sv" {
          puts $fp "read_verilog -golden -version sv2009 $files"
        }
        "vhdl" {
          if {$library eq "" || $library eq "default" || $library eq "work"} {
            set library "work"
          }
          puts $fp "read_vhdl -golden -library $library $files"
        }
        "vhdl2008" {
          if {$library eq "" || $library eq "default" || $library eq "work"} {
            set library "work"
          }
          puts $fp "read_vhdl -golden -library $library -version 2008 $files"
        }
      }
    }

    puts $fp "read_verilog -revised $revised"
    puts $fp "set_elaborate_option -both -black_box {*RAMB* *DSP* *SRL*}"
    puts $fp "elaborate -both -top $ttop" 
    puts $fp "set_mode ec"
    puts $fp "map"
    puts $fp "compare"
    puts $fp "save_result_file -force $outdir/onespin.result.log"
    close $fp
  
    set logfile [file normalize $outdir/onespin.run.log]
    set status [catch {exec onespin --gui=no $sfile >& $logfile}]
  
    if {$status} {
      puts "Failed to run OneSpin"
      return 0
    }
  
    if {![catch {exec grep "The designs are not equivalent" $logfile}]} {
      puts "### Formal Failed! Log is in $outdir/onespin.run.log ###"
    }

    if {![catch {exec grep "The designs are equivalent" $logfile}]} {
      puts "###   Formal Passed  ###"
    }
  }
}


cli::addCommand rt::elab       {rt::elaborate} \
                                {string module} {boolean gate_clock} {boolean map_to_scan} {string parameters}

cli::addCommand rt::map        {"$rt::db map"}

cli::addCommand rt::write_edif              {"$rt::db writeEdif"} {string}
cli::addCommand rt::write_debug             {"$rt::db writeDebug"} {string}
cli::addCommand rt::lut_map                 {"$rt::db mapToLut"} 
cli::addCommand rt::srl_map                 {"$rt::db mapToSrl"} 
cli::addCommand rt::srl_map_bram            {"$rt::db mapSrlToBram"}
cli::addCommand rt::constprop               {"$rt::db constProp"} 
cli::addCommand rt::jitter_remove            {"$rt::db processJitterRemove"} 
cli::addCommand rt::process_seep            {"$rt::db processSeep"} 
cli::addCommand rt::insert_io               {"$rt::db insertIO"} {boolean cleanup_mode false}
cli::addCommand rt::fpga_flatten            {"$rt::db autoDissolve"} {boolean merge_partitions true} {boolean dissolve_hier true} {boolean dissolve_genome false}
cli::addCommand rt::reinfer                 {"$rt::db reSynthReInfer"} {boolean multi_insts false}
cli::addCommand rt::check_resource          {"$rt::db checkResource"} {boolean checkForDSP false} {boolean checkForRAM false} {boolean checkForURAM false}
cli::addCommand rt::timing_merge            {"$rt::db timingMerge"}
cli::addCommand rt::load_net_rules          {"$rt::db readNetRules"}  {string}
cli::addCommand rt::load_part               {"$rt::db loadPart"}  {string}
cli::addCommand rt::load_arcs               {"$rt::db loadArcs"}
cli::addCommand rt::undo_simple_enable      {"$rt::db undoSimpleEnable"}
cli::addCommand rt::cleanup_netlist         {"$rt::db cleanupNetlist"} {string}
cli::addCommand rt::reset_globals           {"$rt::db resetGlobals"}
cli::addCommand rt::reset_nlopt_globals     {"$rt::db resetNLOptGlobals"}
cli::addCommand rt::report_partition_timing {"$rt::db reportPartitionTiming"}
cli::addCommand rt::test_command            {"$rt::db testCommand"}
cli::addCommand rt::parallel_open           {"$rt::db parallelOpen"} {integer}
cli::addCommand rt::parallel_close          {"$rt::db parallelClose"}
cli::addCommand rt::is_parallel_open        {"$rt::db isParallelOpen"}
cli::addCommand rt::parallel_map            {"$rt::db parallelMap"} {string} {boolean} {string} {string}
cli::addCommand rt::parallel_reduce         {"$rt::db parallelReduce"} {boolean}
cli::addCommand rt::parallel_listen         {"$rt::db parallelListen"} {string} {string} {string}
cli::addCommand rt::async_launch            {"$rt::db asyncLaunch"} {string} {integer} {string}
cli::addCommand rt::async_wait              {"$rt::db asyncWait"} {string}
cli::addCommand rt::write_standalone_task   {"$rt::db writeStandaloneTask"} {string}
cli::addCommand rt::load_completed_standalone_optimized_tasks {"$rt::db loadCompletedStandaloneOptimizedGenomes"}
cli::addCommand rt::spawn_helper_lsf_processes {"$rt::db spawnHelperLSFProcesses"} {integer}
cli::addCommand rt::write_global_name_straps      {"$rt::db writeGlobalNamesStraps"}
cli::addCommand rt::process_genomes_sequentially  {"$rt::db processGenomesSequentially"} {boolean} {string} {string}
cli::addCommand rt::open_message_file       {"$rt::db openMessageFile"} {string}
cli::addCommand rt::close_message_file      {"$rt::db closeMessageFile"}
cli::addCommand rt::ipc_wait {"$rt::db ipcWait" } {string}
cli::addCommand rt::ipc_launch {"$rt::db ipcLaunch"} {integer}


cli::addCommand rt::convert_gated_clocks    {"$rt::db convertGatedClocks"} {integer flattenHierarchy 4}
cli::addCommand rt::insert_bufg_gated_clock {"$rt::db insertBufgGatedClock"}
cli::addCommand rt::gated_clock_pre_check   {"$rt::db gatedClockPreCheck"} {string sdcFileList ""} 
cli::addCommand rt::retargetForClockGating {"$rt::db retargetForClockGating"}
cli::addCommand rt::removeUserInstAttribute {"$rt::db removeUserInstAttribute"}
cli::addCommand rt::regenerate_gate         {"$rt::db regenerateGates"} {boolean timing_driven true}
cli::addCommand rt::tristate_to_mux         {"$rt::db tristateToMux"} {boolean gate_impl true} 
cli::addCommand rt::rebuild_hierarchy       {"$rt::db rebuildHierarchy"} {boolean init_only false} 
cli::addCommand rt::comp_stats              {"$rt::db compStatistics"}  
cli::addCommand rt::nl_opt                  {"$rt::db nlOptimize"} {string}
cli::addCommand rt::has_submod_tricell      {"$rt::db hasSubmodTricell"}
cli::addCommand rt::print_attributes         {"$rt::db printAttributes"}
cli::addCommand rt::link_customMod          {"$rt::db linkCustomMod"}  {string}
cli::addCommand rt::report_synth            {"$rt::db reportSynth"}
cli::addCommand rt::extract_genomes         {"$rt::db extractGenomes"}
cli::addCommand rt::distribute_genome_jobs            {"$rt::db distributeGenomeJobs"}
cli::addCommand rt::regenerate_rams         {"$rt::db regenerateRamBlocks"} {boolean timing false} 
cli::addCommand rt::get_instance_count      {"$rt::db getInstanceCount"} {boolean comb_gate true} {boolean flipflop false}  
cli::addCommand rt::propagate_structural_netlist         {"$rt::db propagateStructuralNetlist"}
cli::addCommand rt::print_instances_name_attributes      {"$rt::db printNameAttributes"}
cli::addCommand rt::rename_generated_instances           {"$rt::db renameGeneratedInstances"}
cli::addCommand rt::rename_generated_nets           {"$rt::db renameGeneratedNets"}
cli::addCommand rt::comp_stats_hier         {"$rt::db compStatisticsHier"}
cli::addCommand rt::propagate_module_level_attributes         {"$rt::db propagateModuleLevelAttributes"}
cli::addCommand rt::new_mux_part_flow       {"$rt::db newMuxPartFlow"}
cli::addCommand rt::merge_user_instances    {"$rt::db mergeUserInstances"}
cli::addCommand rt::propagate_dont_merge_info_bottom_up    {"$rt::db propagateDontMergeInfoBottomUp"}
cli::addCommand rt::control_sets_opt    {"$rt::db controlSetsOpt"} {boolean postMap false} {boolean timingDriven false}
cli::addCommand rt::report_control_sets    {"$rt::db reportControlSets"} {integer verbosity 1}
cli::addCommand rt::assign_srl_bus_name {"$rt::db assignSrlBusName"}
cli::addCommand rt::set_fanout_attr_for_muxpart {"$rt::db addFanoutAttrOnMuxSel"}
cli::addCommand rt::merge_clones {"$rt::db mergeClones"}
cli::addCommand rt::fold_instances {"$rt::db foldInstances"}
cli::addCommand rt::retiming {"$rt::db retiming"}


cli::addCommand rt::run_formal  {rt::runOneSpin} 
if { ! $rt::runningPA_ } {
  cli::addCommand run_formal   {rt::run_formal}
}

cli::addCommand rt::do_hm_partition {"$rt::db doHMPartition"}
cli::addCommand rt::report_fpga_partitions {"$rt::db reportFPGAPartitions"}
cli::addCommand rt::install_oasys_sighandlers {"$rt::db installOasysSigHandlers"}
cli::addCommand rt::check_for_mark_debug_on_clock_path {"$rt::db checkForMarkDebugOnClockPaths"}
cli::addCommand rt::estimate_resources {"$rt::db estimateResources"}
cli::addCommand rt::report_designware {"$rt::db reportDesignware"}
cli::addCommand rt::identify_gated_clock_logic_partitions {$rt::db reportGatedClockLogicParititions}
cli::addCommand rt::handle_hyper_source_and_connect {$rt::db handleHyperSourceAndConnect}
cli::addCommand rt::handle_dollar_root {$rt::db handleDollarRoot}
cli::addCommand rt::load_fake_part {$rt::db loadFakePart}
cli::addCommand rt::renameGeneratedPorts {$rt::db renameGeneratedPorts}
cli::addCommand rt::parallel_synth_helper_wrapper {$rt::db parallelSynthHelperWrapper} {string} {string} {string}
cli::addCommand rt::my_readxdc {rt::read_sdc} {string} 
cli::addCommand rt::writeGenomeInstanceXDCs {$rt::db writeGenomeInstanceXDCs} 
cli::addCommand rt::handleCustomAttributes {$rt::db handleCustomAttributes}

# Incremental synthesis changes begin:
cli::addCommand rt::incr_syn_write_debug                       {"$rt::db writeDebug"} {string}
cli::addCommand rt::incr_syn_extract_genomes                   {"$rt::db createIncrementalGenomes"}
cli::addCommand rt::incr_syn_prepare_guide_design              {"$rt::db prepareGuideDesignForIncrementalSynthesis"} 
cli::addCommand rt::incr_syn_mimic_original_skeleton           {"$rt::db mimicOriginalSkeletonForIncrementalSynthesis"} 
cli::addCommand rt::incr_syn_dump_elab_rtd                     {"$rt::db dumpElabRtd"}
cli::addCommand rt::incr_syn_dump_unoptimized_cache            {"$rt::db dumpUnoptimizedCache"}
cli::addCommand rt::incr_syn_dump_optimized_cache              {"$rt::db dumpOptimizedCache"}
cli::addCommand rt::incr_syn_dump_top_skeleton                 {"$rt::db dumpTopSkeleton"} 
cli::addCommand rt::incr_syn_undump_top_skeleton               {"$rt::db undumpTopSkeleton"}
# cli::addCommand rt::incr_syn_dump_genome_checkpoints           {"$rt::db dumpGenomeCheckpoints"} 
# cli::addCommand rt::incr_syn_write_genome_verilog              {"$rt::db writeGenomeVerilog"} 
# cli::addCommand rt::incr_syn_dump_genome_mod_map               {"$rt::db dumpGenomeModuleMap"} 
cli::addCommand rt::incr_syn_set_dont_touch_genomes            {"$rt::db setDontTouchGenomeInstances"} 
cli::addCommand rt::incr_syn_revert_dont_touch_genomes         {"$rt::db revertDontTouchGenomeInstances"} 
cli::addCommand rt::incr_syn_find_changed_genomes              {"$rt::db findChangedGenomes"} 
cli::addCommand rt::incr_syn_blackbox_unchanged_genomes        {"$rt::db blackboxUnchangedGenomes"} 
cli::addCommand rt::incr_syn_stitch_original_genomes           {"$rt::db stitchUnchangedGenomesFromOriginalCache"} 
cli::addCommand rt::reportGenomeStatusIncremental               {"$rt::db reportGenomeStatusIncremental"} 
# Incremental synthesis changes end

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
