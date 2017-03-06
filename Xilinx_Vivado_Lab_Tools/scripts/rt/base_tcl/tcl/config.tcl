# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval config {

    proc printConfig {inputArray} {
	upvar $inputArray input
	foreach arg [array names input] {
	    puts " $arg = '$input($arg)'"
	}
    }

    proc loadConfig {inputArray} {
	upvar $inputArray input

	set synthesizeOptions ""
	set optimizeOptions   ""
	set refineOptions     ""

	#
	# read rtl (verilog)
	#
	if [info exist input(verilog_files)] {
	    if {[info exist input(system_verilog)] && $input(system_verilog) == "true"} {
		set ret [catch {read_verilog -sv -I $input(verilog_dirs) -D $input(verilog_defs) $input(verilog_files)} msg]
	    } else {
		set ret [catch {read_verilog -I $input(verilog_dirs) -D $input(verilog_defs) $input(verilog_files)} msg]
	    }

	    if {$ret != 0} {
		return -code error "config::ERROR (read_verilog failed): $msg"
	    }
	} else {
	    return -code error "config::ERROR (no verilog files specified)"
	}

	#
	# read technology file (lef)
	#
	if [info exist input(tech_file)] {
	    set ret [catch {read_lef $input(tech_file)} msg]
	    if {$ret != 0} {
		return -code error "config::ERROR (read_lef failed): $msg"
	    }
	}

	#
	# read timing library (lib)
	#
	if [info exist input(lib_files)] {
	    # lib_files supports two formats:
	    # 1. default library:    {lib1 lib2 ...}
	    # 2. multiple libraries: { {default {lib1 lib2 ...}} {bar {libn ...}} }
	    foreach file $input(lib_files) {
		set len [llength $file]
		if {$len == 1} {
		    set ret [catch {read_library $file} msg]
		} elseif {$len == 2} {
		    set ret [catch {read_library [lindex $file 1] -target_library [lindex $file 0]} msg]
		} else {
		    set ret 1
		}
		if {$ret != 0} {
		    return -code error -code error "config::ERROR (read_library failed): $msg"
		}
	    }
	} else {
	    return -code error "config::ERROR (no library files specified)"
	}
	
	#
	# read physical library (lef)
	#
	if [info exist input(lef_files)] {
	    set ret [catch {read_lef $input(lef_files)} msg]
	    if {$ret != 0} {
		return -code error "config::ERROR (read_lef failed): $msg"
	    }
	}
	
	#
	# target library
	#
	if [info exist input(target_library)] {
	    if {$input(target_library) ne ""} {
		set ret [catch {set_target_library $input(target_library)} msg]
		if {$ret != 0} {
		    return -code error "config::ERROR (set_target_library failed): $msg"
		}
	    }
	}

	#
	# clock-gating option
	#
	set minWidth 0
	set seqCell ""
	set ctrlPort ""
	set ctrlPt ""
	set obsPt "false"
	if [info exist input(clock_gating_minimum_bitwidth)] {
	    set minWidth $input(clock_gating_minimum_bitwidth)
	}
	
	if [info exist input(clock_gating_sequential_cell)] {
	    set seqCell  $input(clock_gating_sequential_cell)
	}
	
	if {[info exist input(clock_gating_control_point)] && $input(clock_gating_control_point) != ""} {
	    set ctrlPt   $input(clock_gating_control_point)
	
	    if [info exist input(clock_gating_control_port)] {
		set ctrlPort $input(clock_gating_control_port)
	    }
	
	    if [info exist input(clock_gating_observation_point)] {
		set obsPt    $input(clock_gating_observation_point)
	    }
	}
	
	set ret [catch {set_clock_gating_options -sequential_cell $seqCell -control_port $ctrlPort \
			    -control_point $ctrlPt -observation_point $obsPt -minimum_bitwidth $minWidth} msg]
	if {$ret != 0} {
	    return -code error "config::ERROR (set_clock_gating_options failed): $msg"
	}

	#
	# read power constraints (upf/cpf)
	#
	set powerFmt ""
	if {[info exist input(power_files)] && $input(power_files) != ""}  {
	    foreach file $input(power_files) {
		if {[file extension $file] == ".cpf"} {
		    set powerFmt "cpf"
		    set ret [catch {uplevel 1 read_cpf $file} msg]
		} elseif {[file extension $file] == ".upf"} {
		    set powerFmt "upf"
		    set ret [catch {uplevel 1 load_upf $file} msg]
		} else {
		    return -code error "config::ERROR (unknown power format)"
		}
		if {$ret != 0} {
		    return -code error "config::ERROR (read_cpf/load_upf failed): $msg"
		}
	    }
	}

	#
	# synthesize
	#
	if {[info exist input(flow_synthesize)] && $input(flow_synthesize) == "false"} {
	    return -code return
	}

	if {[info exist input(synthesize_map_to_scan)] && $input(synthesize_map_to_scan) == "true"} {
	    lappend synthesizeOptions "-map_to_scan"
	}

	if {[info exist input(synthesize_gate_clock)] && $input(synthesize_gate_clock) == "true"} {
	    lappend synthesizeOptions "-gate_clock"
	}
	
	if {[info exist input(top_module)] && $input(top_module) != ""} {
	    lappend synthesizeOptions "-module"
	    lappend synthesizeOptions $input(top_module)
	}


	if {[info exist input(pre_synthesize)]} {
	    set file $input(pre_synthesize)
	    if {[llength $file]} {
		set ret [catch {source $file} msg]
	    }
	    if {$ret != 0} {
		return -code error "config::ERROR (pre-synthesize script '$file' failed): $msg"
	    }
	}

	set ret [catch {eval "synthesize $synthesizeOptions"} msg]
	if {$ret != 0} {
	    return -code error "config::ERROR (synthesize failed): $msg"
	}

	#
	# read floorplan (def)
	#
	if {[info exist input(def_files)] && $input(def_files) != ""} {
	    set ret [catch {read_def $input(def_files)} msg]
	    if {$ret != 0} {
		return -code error "config::ERROR (read_def failed): $msg"
	    }
	}

	#
	# read timing constraints (sdc/tcl)
	#
	if {[info exist input(sdc_files)] && $input(sdc_files) != ""}  {
	    foreach file $input(sdc_files) {
		if {[file extension $file] == ".sdc"} {
		    set ret [catch {read_sdc $file} msg]
		} else {
		    set ret [catch {source $file} msg]
		}
		if {$ret != 0} {
		    return -code error "config::ERROR (read_sdc failed): $msg"
		}
	    }
	}
	
	#
	# commit cpf/upf
	#
	if {$powerFmt != ""} {
	    if {![info exist input(flow_commit_pf)] || $input(flow_commit_pf) == "true"} {
		if {$powerFmt == "cpf"} {
		    set ret [catch {commit_cpf} msg]
		} else {
		    set ret [catch {commit_upf} msg]
		}
		if {$ret != 0} {
		    return -code error "config::ERROR (commit cpf/upf failed): $msg"
		}
	    }
	}

	#
	# optimize
	#
	if {[info exist input(flow_optimize)] && $input(flow_optimize) == "false"} {
	    return -code return
	}

	if {[info exist input(optimize_area)] && $input(optimize_area) == "true"} {
	    set ret [catch {eval optimize -area} msg]
	    if {$ret != 0} {
		return -code error "config::ERROR (optimize -area failed): $msg"
	    }
	}

	if {[info exist input(optimize_leakage)] && $input(optimize_leakage) == "true"} {
	    set ret [catch {eval set_design_effort -leakage 2} msg]
	    if {$ret != 0} {
		return -code error "config::ERROR (set_design_effort -leakage 2 failed): $msg"
	    }
	}

	if {[info exist input(pre_optimize)]} {
	    set file $input(pre_optimize)
	    if {[llength $file]} {
		set ret [catch {source $file} msg]
	    }
	    if {$ret != 0} {
		return -code error "config::ERROR (pre-optimize script '$file' failed): $msg"
	    }
	}

	set ret [catch {eval optimize $optimizeOptions} msg]
	if {$ret != 0} {
	    return -code error "config::ERROR (optimize failed): $msg"
	}

	#
	# refine
	#
	if {[info exist input(flow_refine)] && $input(flow_refine) == "false"} {
	    return -code return
	}
	
	set ret [catch {eval refine $optimizeOptions} msg]
	if {$ret != 0} {
	    return -code error "config::ERROR (refine failed): $msg"
	}
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
