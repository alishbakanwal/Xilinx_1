# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2011
#                             All rights reserved.
# ****************************************************************************
namespace eval rtbeta {
    
    set designEffort(area) 1
    set designEffort(timing) 1
    set designEffort(congestion) 1
    set designEffort(leakage) 0

    proc getDesignEffort {} {
	set res ""
	foreach key "area timing congestion leakage" {
	    set val $rtbeta::designEffort($key)
	    puts [format "%12s effort: %d" $key $val]
	    lappend res [list $key $val]
	}
	return $res
    }

    proc setDesignEffort {area timing congestion leakage verbose custom} {
	if {$area ne ""} {
	    if {$area < 1 || $area > 7} {
		puts "Error: use '-area 1-7'"
		return -code error
	    }
	}
	if {$timing ne ""} {
	    if {$timing < 1 || $timing > 4} {
		puts "Error: use '-timing 1-4'"
		return -code error
	    }
	}

	if {$congestion ne ""} {
	    if {$congestion < 1 || $congestion > 5} {
		puts "Error: use '-congestion 1-5'"
		return -code error
	    }
	}

	if {$leakage ne ""} {
	    if {$leakage < 0 || $leakage > 3} {
		puts "Error: use '-leakage 0-3'"
		return -code error
	    }
	}

	if {$area ne ""} {
	    setAreaEffort $area $verbose
	}

	if {$timing ne ""} {
	    setTimingEffort $timing $verbose
	}

	if {$congestion ne ""} {
	    setCongestionEffort $congestion $verbose
	}

	if {$leakage ne ""} {
	    setLeakageEffort $leakage $verbose
	}

	if {$custom ne "" &&
	    [info procs set_design_effort_custom] ne ""} {
	    set_design_effort_custom $custom
	}

	return 
    }


    proc leg {steps} {
	# remove L
	# replace *G* by *EG*, unless G already has E in front
	
	set res ""
	set last ""
	for {set i 0} { $i < [string length $steps]} {incr i} {
	    set c [string index $steps $i]
	    if {$c eq "G"} {
		if {$last ne "E"} {
		    append res "E"
		}
	    }
	    if {$c ne "L"} {
		append res $c
		set last $c
	    }
	}
	return $res
    }

    proc legOptimizeSteps {quiet} {
	UParam_reset optimizeSteps true
	set steps [UParam_get optimizeSteps true]
	set steps [leg $steps]
	UParam_set optimizeSteps $steps $quiet
    }

    proc setAreaEffort {level verbose} {
	if {$level < 1 || $level > 7} {
	    puts "Error: use level 1-7"
	    return -code error
	}

	set steps EGRmAVMUST;  # no shielding
	set steps EGXRmAVMUST; # with shielding

	set quiet [expr !$verbose]
	set rtbeta::designEffort(area) $level
	switch -- $level {
	    "1" { 
		UParam_reset abcOptComplexCellBias $quiet
		UParam_reset optimizeRegenTargetGenomeAreaMult $quiet
		UParam_reset optimizeRegenUseAreaMultForDatapath $quiet
	    }
	    "2" {
		UParam_set abcOptComplexCellBias 2 $quiet
		UParam_set optimizeRegenTargetGenomeAreaMult 0.5 $quiet
		UParam_reset optimizeRegenUseAreaMultForDatapath $quiet
	    }
	    "3" {
		UParam_set abcOptComplexCellBias 2 $quiet
		UParam_set optimizeRegenTargetGenomeAreaMult 0.25 $quiet
		UParam_set optimizeRegenUseAreaMultForDatapath false $quiet
	    }
	    "4" {
		UParam_set abcOptComplexCellBias 2 $quiet
		UParam_set optimizeRegenTargetGenomeAreaMult 0.12 $quiet
		UParam_set optimizeRegenUseAreaMultForDatapath false $quiet
	    }
	    "5" {
		UParam_set abcOptComplexCellBias 2 $quiet
		UParam_set optimizeRegenTargetGenomeAreaMult 0.08 $quiet
		UParam_set optimizeRegenUseAreaMultForDatapath false $quiet
	    }
	    "6" {
		UParam_set abcOptComplexCellBias 2 $quiet
		UParam_set optimizeRegenTargetGenomeAreaMult 0.04 $quiet
		UParam_set optimizeRegenUseAreaMultForDatapath false $quiet
	    }
	    "7" {
		UParam_set abcOptComplexCellBias 2 $quiet
		UParam_set optimizeRegenTargetGenomeAreaMult 0.02 $quiet
		UParam_set optimizeRegenUseAreaMultForDatapath false $quiet
	    }
	}
    }

    proc setTimingEffort {level verbose} {
	if {$level < 1 || $level > 4} {
	    puts "Error: use level 1-4"
	    return -code error
	}
	set quiet [expr !$verbose]
	set rtbeta::designEffort(timing) $level
	switch -- $level {
	    "1" { 
		UParam_reset dissolveTemplateModulesInElaborate $quiet
		UParam_reset mergeSmallDatapaths $quiet
		UParam_reset optimizeDissolveUserModules $quiet
		UParam_reset equalitiesInLogicPartition $quiet
		UParam_reset NPlaceTimingDrivenEffort $quiet
		UParam_reset pruneBitWidthsBeforeInferCSA $quiet
		UParam_reset flattenLogicAcrossBits $quiet
	    }
	    "2" {
		UParam_set dissolveTemplateModulesInElaborate true $quiet
		UParam_set mergeSmallDatapaths 2 $quiet

		UParam_reset optimizeDissolveUserModules $quiet
		UParam_reset equalitiesInLogicPartition $quiet
		UParam_reset NPlaceTimingDrivenEffort $quiet
		UParam_reset pruneBitWidthsBeforeInferCSA $quiet
		UParam_reset flattenLogicAcrossBits $quiet
	    }
	    "3" {
		UParam_set dissolveTemplateModulesInElaborate true $quiet
		UParam_set mergeSmallDatapaths 2 $quiet
		UParam_set optimizeDissolveUserModules 1 $quiet
		UParam_set equalitiesInLogicPartition 8 $quiet
		UParam_set NPlaceTimingDrivenEffort 2 $quiet

		UParam_reset pruneBitWidthsBeforeInferCSA $quiet
		UParam_reset flattenLogicAcrossBits $quiet
	    }
	    "4" {
		UParam_set dissolveTemplateModulesInElaborate true $quiet
		UParam_set mergeSmallDatapaths 2 $quiet
		UParam_set optimizeDissolveUserModules 1 $quiet
		UParam_set equalitiesInLogicPartition 16 $quiet
 		UParam_set NPlaceTimingDrivenEffort 2 $quiet
		UParam_set pruneBitWidthsBeforeInferCSA true $quiet
		UParam_set flattenLogicAcrossBits true $quiet
	    }
	}
    }

    proc setCongestionEffort {level verbose} {
	if {$level < 1 || $level > 5} {
	    puts "Error: use level 1-5"
	    return -code error
	}
	set quiet [expr !$verbose]
	set rtbeta::designEffort(congestion) $level
	switch -- $level {
	    "1" { 
		UParam_reset repartitionBeforeTimingOpt $quiet
		UParam_reset postOptimizeCongestionOpt $quiet
		UParam_reset bitSliceDfgWordSize $quiet
		UParam_reset bitSliceLogicNodes $quiet
		UParam_reset inferDecoderFromConstantEqOutSizeGr $quiet
 		UParam_reset repartitionGenomeEffort $quiet
	    }
	    "2" {
		UParam_set repartitionBeforeTimingOpt 1 $quiet
		UParam_set postOptimizeCongestionOpt 1 $quiet
		UParam_set bitSliceDfgWordSize 64 $quiet
		UParam_set bitSliceLogicNodes true $quiet

		UParam_reset inferDecoderFromConstantEqOutSizeGr $quiet
 		UParam_reset repartitionGenomeEffort $quiet
	    }
	    "3" {
		UParam_set repartitionBeforeTimingOpt 1 $quiet
		UParam_set postOptimizeCongestionOpt 1 $quiet
		UParam_set bitSliceDfgWordSize 32 $quiet
		UParam_set bitSliceLogicNodes true $quiet
		UParam_set inferDecoderFromConstantEqOutSizeGr 999999999 $quiet
 		UParam_set repartitionGenomeEffort 1 $quiet
	    }
	    "4" {
		UParam_set repartitionBeforeTimingOpt 1 $quiet
		UParam_set postOptimizeCongestionOpt 1 $quiet
		UParam_set bitSliceDfgWordSize 32 $quiet
		UParam_set bitSliceLogicNodes true $quiet
		UParam_set inferDecoderFromConstantEqOutSizeGr 999999999 $quiet
 		UParam_set repartitionGenomeEffort 2 $quiet
	    }
	    "5" {
		UParam_set repartitionBeforeTimingOpt 1 $quiet
		UParam_set postOptimizeCongestionOpt 1 $quiet
		UParam_set bitSliceDfgWordSize 16 $quiet
		UParam_set bitSliceLogicNodes true $quiet
		UParam_set inferDecoderFromConstantEqOutSizeGr 999999999 $quiet
 		UParam_set repartitionGenomeEffort 2 $quiet
	    }
	}
    }

    proc setLeakageEffort {level verbose} {
	if {$level < 0 || $level > 3} {
	    puts "Error: use level 0-3"
	    return -code error
	}
	set quiet [expr !$verbose]
	set rtbeta::designEffort(leakage) $level
	switch -- $level {
	    "0" { 
		UParam_reset optimizeLeakageEffort $quiet
		UParam_reset critPercentageLvt $quiet
		UParam_reset optimizeLeakageResetCritRange $quiet
	    }
	    "1" { 
		UParam_set optimizeLeakageEffort 1 $quiet
		UParam_set critPercentageLvt 20 $quiet
		UParam_set optimizeLeakageResetCritRange 150 $quiet
	    }
	    "2" { 
		UParam_set optimizeLeakageEffort 1 $quiet
		UParam_set critPercentageLvt 20 $quiet
		UParam_set optimizeLeakageResetCritRange 100 $quiet
	    }
	    "3" { 
		UParam_set optimizeLeakageEffort 1 $quiet
		UParam_set critPercentageLvt 10 $quiet
		UParam_set optimizeLeakageResetCritRange 100 $quiet
	    }
	}
    }
}

cli::addCommand set_design_effort  {rtbeta::setDesignEffort} {integer area} {integer timing} {integer congestion} {integer leakage} {#boolean verbose} {#string custom}
cli::addCommand get_design_effort  {rtbeta::getDesignEffort}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
