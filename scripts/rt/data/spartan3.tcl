proc do_loadpart {synth_common} {
	global partid
        #pause_cpumem_stats
	if { [ info exists partid ] } {
		load_part $partid
	} else {
		load_part "xc6vlx75tff784-1"
	}
        #resume_cpumem_stats
        if { [ info exists ::env(SYNTH_NEWFLOW) ] } { 
		load_net_rules $synth_common/delay_new.rules
	} else {
		load_net_rules $synth_common/delay.rules
	}
}

proc do_write_reports {} {
	global reportTiming
	report_rtl_partitions
	report_blackboxes
	report_cells
	report_area
	report_design_metrics
	report_clocks
    if { $reportTiming } {
	    report_timing -net -max_paths 1
    }
}


proc do_insert_io { flatten } {
	global ioInsertion
	if { $flatten } {
		set_parameter maxDissolveSize 1000000
		set mod [[rt::design] topModule]
		puts "Top module $mod"
		set gen [$mod dissolveGenomes]
		puts "Gen Dissolve $gen"
		fpga_flatten
	}
    if { $ioInsertion } {
	    insert_io
    } else {
	    insert_io -cleanup_mode true
    }
}

proc do_reinfer {} {
	global writeStepNetlist
	global flattenHierarchy
	#report_fsm -detail
	reinfer -multi_insts
	if { $flattenHierarchy } {
		fpga_flatten -merge_partitions false
	}
	reinfer
    #check_dsp_resource
	if { $flattenHierarchy } {
        #dissolve everything to genome level
        #all user modules will dissolve, only inferred modules
        #present
		set_parameter maxDissolveSize 5000
		fpga_flatten -merge_partitions false
	}
	if { $writeStepNetlist } {
		write_verilog "after_reinfer.v"
	}
}


proc do_timing_merge {} {
	timing_merge
}


proc do_generic_area_opt {} {
	global writeStepNetlist
	undo_simple_enable
	constprop
	#cleanup_netlist "pre_map"
	set_parameter enableLutMapping false
    set_parameter disableAbc false
	optimize -area
    set_parameter disableAbc true
	if { $writeStepNetlist } {
		write_verilog "after_generic_area_opt.v"
	}
}

proc do_get_sdc { top } {
        set sdc_file [ get_parameter SDCFile ]
        if { ![file exists $sdc_file] } {
          set sdc_file "constraints\/$top.sdc"
        }
        if { [file exists $sdc_file] } {
                if { ! [ info exists ::env(SYNTH_IGNORESDC) ] } {
 			return $sdc_file
                }
        }
	return ""
}

proc do_sdc {top } {
        set sdc_file [ do_get_sdc $top ]
	if { [file exists $sdc_file] } {
                puts "Reading $sdc_file"
                read_sdc "$sdc_file"
        }
}

proc do_generic_timing_opt {top timing_merge_flow} {
	global writeStepNetlist
	set sdc_file [ do_get_sdc $top ]
	#puts "$sdc_file"
	if { [file exists $sdc_file] } {
                if { !$timing_merge_flow } {
  		  do_sdc $top
                }
  		set_parameter abcOptScript "fpga -K %d; sweep;"
  		set_parameter cleanupAfterRegenerate true
	        set_parameter mapFlowOption 4097
  		optimize -pre_placement
                if { $timing_merge_flow } {
		  timing_merge
  		  optimize -pre_placement
		  timing_merge
		  optimize -pre_placement
		}
	} else {
  		set_parameter abcOptScript "resyn2;fpga -K %d; sweep;"
	        set_parameter mapFlowOption 17
	}
	if { $writeStepNetlist } {
		write_verilog "after_generic_timing_opt.v"
	}
}

proc do_generic_timing_opt_new {top timing_merge_flow} {
	set_parameter mapInRegenerate true
	global writeStepNetlist
	set_parameter enableLutMapping true
	set sdc_file [ do_get_sdc $top ]
	#puts "$sdc_file"
	if { [file exists $sdc_file] } {
                if { !$timing_merge_flow } {
  		  do_sdc $top
                }
  		set_parameter abcOptScript "fpga -K %d; sweep;"
  		set_parameter cleanupAfterRegenerate true
	        set_parameter mapFlowOption 4097

	        # disable ABC LUT mapper and optimizer, need to evaluate runtime.
	        set_parameter useAbcMapping false
	        #set_parameter disableAbc false
  		optimize -pre_placement
	        #set_parameter disableAbc true

                if { $timing_merge_flow } {
	        #    set_parameter disableAbc false
  		  timing_merge
  		  optimize -pre_placement
  		  timing_merge
  		  optimize -pre_placement
	        #    set_parameter disableAbc true
		}
	} else {
  		set_parameter abcOptScript "resyn2;fpga -K %d; sweep;"
	        set_parameter mapFlowOption 17
	}
	if { $writeStepNetlist } {
		write_verilog "after_generic_timing_opt.v"
	}
	set_parameter enableLutMapping false
	set_parameter mapInRegenerate false
}

proc do_lutmap {} {
	set_parameter enableLutMapping true
    set_parameter useAbcMapping true
    set_parameter disableAbc false
	lut_map
    set_parameter disableAbc true
	set_parameter enableLutMapping false
}

proc do_techmap {} {
	global writeStepNetlist
	global flattenHierarchy

	set_parameter enableLutMapping true
	set_parameter flattenRemoveDfg true
	if { $flattenHierarchy } {
		fpga_flatten
	}
    set_parameter useAbcMapping true
    set_parameter disableAbc false
    set_parameter lutSize 4
	lut_map
    set_parameter disableAbc true
	cleanup_netlist "post_map"
	#srl_map
	#cleanup_netlist "final"
	if { $writeStepNetlist } {
		write_verilog "after_techmap.v"
	}
}

proc do_write_netlist { top } {
        #pause_cpumem_stats
        if { [ info exists ::env(SYNTH_WRITEVLOG) ] } { 
	    write_verilog ${top}_out.v
	}
	write_edif ${top}.edf
        #resume_cpumem_stats
}

proc do_run_ise { top } {
	puts "ngdbuild started"
	exec ngdbuild -sd cores -nt on $top $top.ngd
	puts "map started"
	exec map -o $top.ncd -detail -w -ol high $top.ngd
	puts "par started"
	exec par -w -ol high -nopad $top.ncd rtd_$top.ncd
	puts "trce started"
	exec trce -v 1000 -o $top rtd_$top.ncd $top.pcf
}

proc do_gen_pa_setup {} {
	global env
	global partid
	global top
	
	set fname [ open pa_env.tcl w ]
	puts $fname "set top $top"
	if { [ info exists partid ] } {
		puts $fname "set partid $partid"
	} else {
		puts $fname "set partid xc6vlx130tff1156-1"
	}
	close $fname
}

# proc do_run_pa { top } {
# 	global env
# 	puts "Rodin Placer started"
# 	set cmd "-mode batch -source $env(SYNTH_COMMON)/pa.tcl"
# 	if { [ catch { exec planAhead $cmd } ] } {
# 	    puts "Rodin Placer complete"
#     }
# 	puts "ISE Router started"
# 	exec par -w -ol high -nopad ${top}.map.ncd rtd_$top.ncd
# 	puts "trce started"
# 	exec trce -v 1000 -o $top rtd_$top.ncd ${top}.map.pcf
# 	puts "ISE Router complete"
# }

if {[get_parameter elaborateOnly] == true} {
set flattenHierarchy 0
do_techmap
set_parameter writeInferredModules true
} else {


#do_loadpart $env(SYNTH_COMMON)
print_cpu "after loading device timing info"

if { [ info exists ::env(SYNTH_COMPILE_ONLY) ] } { 
	write_verilog "compiler_out.v"
	return 0
}


if { $writeStepNetlist } {
	write_verilog "after_synthesis.v"
}

do_reinfer
if { [ info exists ::env(SYNTH_NEWFLOW) ] } {
  set timing_merge_flow 1
  set_parameter allowHillClimb true
  set_parameter areaOptDissolveIncremental true
} else {
  set timing_merge_flow 0
}
if { $timing_merge_flow } {
  do_sdc $top
  do_timing_merge
}

do_generic_area_opt 
print_cpu "after optimize area"

if { [ info exists ::env(SYNTH_NEWFLOW) ] } { 
  do_sdc $top
  do_lutmap	
  print_cpu "after lutmap"
  do_generic_timing_opt_new $top $timing_merge_flow
} else {
  do_generic_timing_opt $top $timing_merge_flow
}
print_cpu "after optimize timing 1"
#report_timing -net -max_paths 20

do_techmap
print_cpu "after techmap"

set flatten_before_io 0
if { $flattenHierarchy } {
	set flatten_before_io 1
}
do_write_reports
print_cpu "after report "

do_insert_io  $flatten_before_io

do_write_netlist $top
print_cpu "after netlist "

do_gen_pa_setup

if { [ info exists ::env(SYNTH_RUNPAR) ] } { 
	do_run_ise $top
}

#EXPERIMENTAL - DOES not work
#if { [ info exists ::env(SYNTH_RUNPA) ] } { 
#	do_run_pa $top
#}

}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
