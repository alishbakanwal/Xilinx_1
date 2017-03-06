# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval rt {
    set db [getNDb "main"]
    set cmdEcho 0
    set cmdFdEcho 1
    set rtlData {}
    set ptnLibs {}
    set lefFiles {}

    variable checksumFileList

    proc flattenList {l} {
	# removes one level of nesting from a list:
	# [flatten {a b c {d e} {f {g h}}}] -> {ca b c d e f {g h}}
	set rsl {}
	foreach e1 $l {
	    foreach e2 $e1 {
		lappend rsl $e2
	    }
	}
	return $rsl
    }

    proc getParam {var} {
	set val [rt::UParam_get $var rc]
	if {$rc == 0} {
	    return -code error
	}
	return $val
    }

    proc checkParam {var} {
        # safe and silent check of boolean param
        set ena [rt::UMsgHandler_isEnabled PARAM 100]
        rt::UMsgHandler_disable PARAM 100
        set val [rt::UParam_get $var rc]
        if {$ena} {
            rt::UMsgHandler_enable PARAM 100
        }
        if {$rc == 0} {
            return false
        }
        return $val
    }

    proc setParameter {var val} {
	set rc [rt::UParam_set $var $val]
	if {$rc != 1} {
	    return -code error
	}
    }

    proc resetParameter {var} {
	set rc [rt::UParam_reset $var]
	if {$rc != 1} {
	    return -code error
	}
    }

    proc encrypt {in out} {
	set rc [UFile_encrypt $in $out]
    }

    proc searchPath {file} {
	global search_path
	if [info exist search_path] {
	    foreach path ${search_path} {
		foreach ext {"" ".zip" ".bz2" ".gz" ".gpg" ".odb"} {
		    if [file exist ${path}/${file}${ext}] {
			return ${path}/${file}${ext}
		    }
		}
	    }
	}
	return $file
    }

    proc readLef {files} {
        set tmp read_lef 
        lappend tmp $files
        lappend rt::ptnLibs $tmp

	foreach file $files {
	    set lefFile [searchPath $file]
	    if {[$rt::db readLef $lefFile] > 0} {
		return -code error "Failed to read lef '$lefFile'"
	    }
	}

        lappend rt::lefFiles $files
    }

    proc readDef {files all flattened matchUnknown} {
	foreach file $files {
	    set defFile [searchPath $file]
	    if {[$rt::db readDef $defFile $all $flattened $matchUnknown] > 0} {
		return -code error "Failed to read def '$defFile'"
	    }
	}
    }

    proc readLibrary {files targetLibList} {
        set tmp read_library
        lappend tmp $files
        if {$targetLibList != ""} {
          lappend tmp -target_library
          lappend $targetLibList
        }
        lappend rt::ptnLibs $tmp
	set files [string map {"\\" "/"} $files]

	set libName ""
	foreach file $files {
	    set libFile [searchPath $file]
	    set libFileNorm [file normalize $libFile]
	    set lib [$rt::db readLibrary $libFileNorm]
	    if {$lib == "NULL"} {
		return -code error "Failed to read library '$libFileNorm'"
	    }
	    set libName [$lib name]
	    if {$targetLibList == ""} {
		set targetLib [$rt::db findOrAddTargetLib "default"]
		$targetLib add $lib
	    } else {
		foreach targetLibNm $targetLibList {
		    set targetLib [$rt::db findOrAddTargetLib $targetLibNm]
		    $targetLib add $lib
		}
	    }
	}
	return $libName
    }

    proc getTargetLib {} {
	return [[$rt::db targetLib] name]
    }

    proc setTargetLib {targetLibNm instances} {
	set lib [$rt::db findTargetLib $targetLibNm]
	set des [$rt::db topDesign]
	set ok true
	if {$des != "NULL"} {
	    rt::UMsg_tclMessage NL 167
	    set ok false
	    #set oldLib [$rt::db targetLib]
	    #if {$lib != $oldLib} {
	    #	$des resetTiming
	    #}
	}
	if {$ok} {
	    if {$lib == "NULL"} {
		rt::UMsg_tclMessage NL 137 $targetLibNm
		set ok false
	    }
	}
	if {$ok} {
	    set instList {}
	    foreach inst $instances {
		lappend instList $inst
	    }
	    $rt::db setTargetLib $lib $instList
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc readVerilog {dirs defs lib sv files} {
	set defs [flattenList $defs]
	set dirs [flattenList $dirs]

	$rt::db clearIncludeDirs
	$rt::db clearDefines
	$rt::db clearVerilogParse
	set files [string map {"\\" "/"} $files]
	set dirs [string map {"\\" "/"} $dirs]

	foreach dir $dirs {
	    $rt::db addIncludeDir $dir
	}

        set language [expr {$sv ? "sv" : "vlog"}]
        lappend rt::rtlData [list $language $dirs $defs $lib $files]

	global search_path
	if [info exist search_path] {
	    foreach path ${search_path} {
		$rt::db addIncludeDir $path
	    }
	}
	foreach def $defs {
	    set nv [split $def =]
	    set len [llength $nv]
	    if {$len == 1} {
		$rt::db addDefine [lindex $nv 0] ""
	    } elseif {$len == 2} {
		$rt::db addDefine [lindex $nv 0] [lindex $nv 1]
	    } else {
		$rt::db clearDefines
		return -code error "Invalid define '$def'"
	    }
	}
	set ctrl [$rt::db control]
	set key [$ctrl lock "Reading Verilog" [llength $files]]
	foreach file $files {
	    $key incrProgress 1
	    set vlogFile [searchPath $file]
	    set nerrs [$rt::db readVerilog $sv $vlogFile $lib] 
	    lappend rt::checksumFileList $vlogFile
	    if {$nerrs > 0} {
		rt::delete_UTask $key
		$rt::db clearDefines
		return -code error "Failed to read verilog '$vlogFile'"
	    }
	}
	rt::delete_UTask $key
	$rt::db clearDefines
    }

    proc resetHdlParse {} {
	$rt::db resetHdlParse
    }

    proc readVhdl {vhdl87 vhdl2008 library files} {
	$rt::db setVhdl87 $vhdl87
	$rt::db setVhdl2008 $vhdl2008
	$rt::db setVhdlLibrary $library 
	set files [string map {"\\" "/"} $files]

        set language [expr {$vhdl2008 ? "vhdl2008" : "vhdl"}]
	set dirs {}
	set defs {}
        lappend rt::rtlData [list $language $dirs $defs $library $files]

	foreach file $files {
	    set vhdlFile [searchPath $file]
	    $rt::db registerVhdlFile $vhdlFile
	    lappend rt::checksumFileList $vhdlFile
	}
	set nerrs [$rt::db readVhdlFiles]
	$rt::db clearVhdlLibrary 
	if {$nerrs > 0} {
	    return -code error "Failed to read vhdl '$vhdlFile'"
	}
    }


    proc readConfig {file} {
	uplevel 2 tcl_source $file
	if [info exist config::input] {
	    uplevel 2 config::loadConfig config::input
	}
    }

    proc topModule {{mod {}}} {
	if {$mod == ""} {
	    set mod [[design] topModule]
	} else {
	    [design] topModule $mod
	}
	return [$mod name]
    }

    proc topDesign {des} {
	if {$des == ""} {
	    set des [design]
	} else {
	    $rt::db topDesign $des
	}
	return [$des name]
    }

    proc design {} {
	set des [$rt::db topDesign]
	if {$des == "NULL"} {
	    return -code error "No design loaded"
	}
	return $des
    }

    proc delDesign {} {
	set des [$rt::db topDesign]
	if {$des == "NULL"} {
	    return -code ok "No design loaded"
	}
	set rt::rtlData {}
	if {[info exists rt::rtlData]} {
	    set rt::rtlData {}
	}
	$rt::db delDesign $des
        set sdcrt::currMod "NULL"
    }

    proc instanceArea {noMacros} {
	set area [[design] instanceArea NULL $noMacros]
	return [format "%.0f" [$rt::db squm $area]]
    }

    proc instanceLeakage {noMacros} {
	set leakage [[design] instanceLeakagePower $noMacros]
	set leakage [string trimright $leakage "nw"]
	return $leakage
    }

    proc percentageLvt {} {
	global env
	set repFile $env(RT_TMP)/lk.rpt
	report_leakage > $repFile
	set fp [open $repFile r]
	set file_data [read $fp]
	close $fp
	set data [split $file_data "\n"]
	set found 0
	set cellsLine ""
	foreach line $data {
	    set found [regexp Cells $line matchResult]
	    if {$found == 1} {
		set cellsLine $line
		break
	    }
	}
	set plvt 0
	if {$found == 1} {
	    regsub -all {[ \r\t\n]+} $line "" result
	    set vtList [split $result "|"]
	    set len [llength $vtList]
	    set plvt [lindex $vtList [expr $len -2]]
	}
	return $plvt
    }

    proc setClockGatingOptions {seqCell ctrlPort ctrlPoint obs minWidth numStages} {
	if {$minWidth == ""} {
	    set minWidth 0
	}
	if {$numStages == ""} {
	    set numStages 0
	}
	if {$obs == "false"} {
	    set obs 0
	} else {
	    set obs 1
	}
	return [$rt::db setClockGateParam $seqCell $ctrlPort $ctrlPoint $obs $minWidth $numStages]
    }

    proc askPassphrase {} {
	UFile_passPhrase [exec zenity --entry --hide-text {--text=Type passphrase}]
    }

    proc setPassphrase {passphrase} {
        UFile_passPhrase $passphrase
    }

    proc tns {} {
        set tns 0
        set i 0
        set des [design]
	set j 1
	set sz [$des numPathGroups]
	for {} {$j < $sz} {incr j} {
	    set group [$des groupName $j]
	set deps [$des detailedEndPoints $group]
	while {![$deps empty]} {
	    set dep     [$deps pop]
	    set slack   [$dep slack]
	    set ps      [string trimright $slack "ps"]
	    if {$ps >= 0} {
		break
	    }
	    set tns [expr $tns - $ps]
	    incr i
	}
	}
	rt::UMsg_print "tns = ${tns}ps (${i} critical endpoints)\n"
        return [expr round(${tns})]
    }

    proc tmfmt {s} {
	set m  [expr $s / 60]
	set s  [expr $s % 60]
	set h  [expr $m / 60]
	set m  [expr $m % 60]
	return [format "%d:%02d:%02d" $h $m $s]
    }

    if {[info exist tcl_platform(platform)] && ($tcl_platform(platform) == "windows")} {
	
	proc print_cpu {state} {
	    set cpu   0
	    # 	set wall  [exec ps -o etime= -p [pid]]
	    # 	set vsz   [exec ps -o   vsz= -p [pid]]
	    # 	set cpu   [string trimleft $cpu " "]
	    # 	set wall  [string trimleft $wall " "]
	    # 	set vsz   [expr $vsz / 1024]
	
	    set dt   [UStatCpu_getCurrent]
	    #	set cpu  [tmfmt [$dt cget -cpu ]]
	    set wall [tmfmt [$dt cget -wall]]
	    set vsz         [$dt cget -vsz ]
	    $dt -delete
	    
	    puts "${state} at ${cpu}(cpu)/${wall}(wall) ${vsz}MB(vsz)"
	    ::utils::flushAll
	}
	
    } else {
	
	proc print_cpu {state} {
	    set cpu   [exec ps -o  time= -p [pid]]
	    # 	set wall  [exec ps -o etime= -p [pid]]
	    # 	set vsz   [exec ps -o   vsz= -p [pid]]
	    # 	set cpu   [string trimleft $cpu " "]
	    # 	set wall  [string trimleft $wall " "]
	    # 	set vsz   [expr $vsz / 1024]
	    
	    set dt   [UStatCpu_getCurrent]
	    #	set cpu  [tmfmt [$dt cget -cpu ]]
	    set wall [tmfmt [$dt cget -wall]]
	    set vsz         [$dt cget -vsz ]
	    $dt -delete
	    
	    puts "${state} at ${cpu}(cpu)/${wall}(wall) ${vsz}MB(vsz)"
	    ::utils::flushAll
	}
    }

    proc start_state {state} {
      puts "---------------------------------------------------------------------------------"
	print_cpu "Starting $state"
      puts "---------------------------------------------------------------------------------"
    }

    proc stop_state {state} {
      puts "---------------------------------------------------------------------------------"
	print_cpu "Finished $state"
      puts "---------------------------------------------------------------------------------"
    }

    proc optimize {place_only virtual pre_placement incremental 
		   reclaim_area area
		   critical_ratio critical_offset
		   propagate_only dont_propagate} {
	if {$critical_ratio == {}} {
	    set critical_ratio 0
	}
	if {$critical_offset == {}} {
	    set critical_offset 0
	}
	if {$virtual} {
	    set pre_placement true
	}

	if { [rt::get_parameter synVerbose] >= 1 } {
		start_state "Optimize"
	}

	[design] optimize \
	    $place_only $pre_placement $incremental \
	    $reclaim_area $area \
	    $critical_ratio [sdcrt::time $critical_offset] \
	    $propagate_only $dont_propagate
	
	if { [rt::get_parameter synVerbose] >= 1 } {
		stop_state "Optimize"
	}

    }

    proc createHalo {inst lib_cell cell left bottom right top} {
	if { $left == "" } {
	    set left 10
	}
	if { $bottom == "" } {
	    set bottom 10
	}
	if { $right == "" } {
	    set right 10
	}
	if { $top == "" } {
	    set top 10
	}
	
	if {$cell ne ""} {
	    rt::UMsg_tclMessage CMD 113 -cell create_halo -lib_cell
	    if {$lib_cell eq ""} {
		set lib_cell $cell
	    }
	}

	set result [[design] createHalos $inst $lib_cell $left $bottom $right $top]
        if {$result > 0} {
            return -code error
        }
    }

    proc createRegion {name type inst left bottom right top} {
	global rt::UNM_sdc
        global rt::PRegion_PR_DEFAULT
        global rt::PRegion_PR_GUIDE
        global rt::PRegion_PR_FENCE

	if { $left == "" } {
	    set left 0
	}
	if { $bottom == "" } {
	    set bottom 0
	}
	if { $right == "" } {
	    set right 0
	}
	if { $top == "" } {
	    set top 0
	}

        set t $rt::PRegion_PR_DEFAULT
        if { $type == "guide" } {
            set t $rt::PRegion_PR_GUIDE
        } 
        if { $type == "fence" } {
            set t $rt::PRegion_PR_FENCE
        }

	set topDes [rt::design]
	set topMod [$topDes topModule]
	set region [$topDes createRegion $name $t $left $bottom $right $top]
        if {$region == "NULL"} {
            return -code error
        }
	foreach instNm $inst {
	    set instObjs [$topMod findInstances $instNm $rt::UNM_sdc "false"]
	    foreach instObj $instObjs {
		$topDes assignToRegion $region $instObj
	    }
	    release $instObjs
	}
    }

    proc assignToRegion {region domain instance} {
	global rt::UNM_sdc

	set topDes [rt::design]
	set topMod [$topDes topModule]
 
	set regObj [$topDes findRegion $region]

	if {$regObj == "NULL"} {
	    #puts "warning: region '$region' not found"
	    rt::UMsg_tclMessage FP 116 $region
	    return -code error
	}

	if {$domain != ""} {
	    set pd     [$rt::db findPowerDomain $domain]
	    if {$pd != "NULL"} {
		set numInst [$topDes assignToRegion $regObj $pd ]
		if {$numInst < 0} {
		    return -code error
		}
	    } else {
		#puts "warning: power domain '$domain' not found"
		rt::UMsg_tclMessage NL 136 $domain
		return -code error
	    }
	}

	if {$instance != ""} {
	    foreach instNm $instance {
                set type [rt::typeOf $instNm]
                if {$type == "NULL"} {
		    set instObjs [$topMod findInstances $instNm $rt::UNM_sdc "false"]
                    if {[llength $instObjs] == 0} {
			release $instObjs
			return -code error
                    }
		    foreach instObj $instObjs {
		        set numInst [$topDes assignToRegion $regObj $instObj]
		        if {$numInst < 0} {
			    release $instObjs
			    return -code error
		        }
		    }
		    release $instObjs
                } elseif {$type == "NInstS"} {
		    set numInst [$topDes assignToRegion $regObj $instNm]
		    if {$numInst < 0} {
		        return -code error
		    }
		} else {
		    puts "wrong argument '$instNm', must be an instance or name of an instance."
		    return -code error
                }
	    }
	}
    }

    proc removeRegion {name} {
        [rt::design] removeRegion $name
    }

    proc removeFromRegion {region domain instance} {
	global rt::UNM_sdc

	set topDes [rt::design]
	set topMod [$topDes topModule]

	set regObj [$topDes findRegion $region]
	if {$regObj == "NULL"} {
	    #puts "warning: region '$region' not found"
	    rt::UMsg_tclMessage FP 116 $region
	    return -code error
	}

	if {$domain != ""} {
	    set pd     [$rt::db findPowerDomain $domain]
	    if {$pd != "NULL"} {
		set numInst [$topDes removeFromRegion $regObj $pd ]
		if {$numInst == 0} {
		    return -code error
		}
	    } else {
		#puts "warning: power domain '$domain' not found"
		rt::UMsg_tclMessage NL 136 $domain
		return -code error
	    }
	}

	if {$instance != ""} {
	    foreach instNm $instance {
		set instObjs [$topMod findInstances $instNm $rt::UNM_sdc "false"]
		foreach instObj $instObjs {
		    set numInst [$topDes removeInstFromRegion $regObj $instObj] 
		    if {$numInst == 0} {
			release $instObjs
			return -code error
		    }
		}
		release $instObjs
	    }
	}
    }

    proc addPowerGuides {domain guides} {
	set topDes [rt::design]

	set pd     [$rt::db findPowerDomain $domain]
	if {$pd == "NULL"} {
	    #puts "warning: power domain '$domain' not found"
	    rt::UMsg_tclMessage NL 136 $domain
	    return -code error
	}

	foreach reg $guides {
	    set regObj [$topDes findRegion $reg]
	    if {$regObj == "NULL"} {
		#puts "warning: region '$reg' not found"
		rt::UMsg_tclMessage FP 116 $reg
		return -code error
	    } else {
		$pd addPowerGuide $regObj
		#puts "info: region '$reg' added as a power guide for power domain '$domain'"
		rt::UMsg_tclMessage FP 150 $reg $domain
	    }
	}
    }

    proc updateVoltageRegions {} {
	set ok [[rt::design] updateVoltageRegions]
    }

    proc set_fence_partition {fence instance all} {
      #puts "info: entering set_fence_partition"

      global rt::UNM_sdc
      global PRegion_PR_FENCE
      set topDes [rt::design]
      set topMod [$topDes topModule]
      if {$all == "true" } {
        $topDes setFencePartitionFlag
        return
      }

        set regObj [$topDes findRegion $fence]
        if {$regObj == "NULL"} {
            puts "warning: fence '$fence' not found"
            UMsg_tclMessage FP 116 $fence
            return -code error 
        } else {
            #puts " regObj = $regObj"
            
            set regType [$regObj getType]
            if {$regType != $PRegion_PR_FENCE} {
              puts "warning: region '$fence' is not a fence"
              ##UMsg_tclMessage FP 116 $fence
              return -code error "region is not a fence"
            } 

            #puts " regType = $regType"
        }
        if {$instance != ""} {
            set type [rt::typeOf $instance]
            if {$type == "NULL"} {
                set instObjs [$topMod findInstances $instance $rt::UNM_sdc "false"]
                if {[llength $instObjs] == 0} {
                    release $instObjs
                    return -code error "No object found."
                }
                if {[llength $instObjs] > 1} {
                    release $instObjs
                    return -code error "More than one object found."
                }
            } else {
                return -code error "$type != NULL"
            }

            foreach instObj $instObjs {
              #puts "$topDes setPartition $regObj $instObj"
              $topDes setPartition $regObj $instObj  
            }
        } else {
          #puts "$regObj setPartition "
          $regObj setPartition 
        }
    }

    proc place_port {name x y layer rect} {
        set pin [get_pin $name]
        if {$pin == "NULL"} {
          error "Port $name is not found."
        } else {
          if { $x != "" && $y != "" } { 
            set_attribute $pin location "$x $y"
          } else {
            puts "Invalid location $x $y. Please privode location with both x and y values"
            return -code error
          }
          if {$layer != ""} {
            set dblList {}
            set cnt 0
            if {$rect != ""} {
              set ii 0
              set isy 0
              foreach nn $rect {
                if { [string is integer $nn] } { 
                  incr ii 
                  if { $isy == 0 } {
                    lappend dblList $nn
                    incr isy
                  } else {
                    lappend dblList $nn
                    incr isy -1           
                    incr cnt
                  }
                } else { 
                  puts "Wrong rect points $nn, please use integer value."
                  return -code error
                }
              }
              if { $cnt != 2 } {
                puts "Wrong number of points in -rect { $rect }, please use rect box."
                return -code error
              }
            }
            if {[llength $dblList]==0} {
              lappend dblList  -1 -1 1 1 
            }
    
            if {[llength $dblList]>0} {
              set layerApp { 1 } 
              lappend layerApp $layer
              foreach nn $dblList {
                lappend layerApp $nn
              }
              set_attribute $pin layer $layerApp
            } 
          } else {
            if { $rect != ""} {
              puts " rect { $rect } is ignored, please provide layer."
            }
          }
          $pin setPlaced 1
        }
    }

    proc create_anchor {instance port clearance} {
        set topDes [rt::design]
        if {$topDes == "NULL"} {
          rt::UMsg_tclMessage NL 173
          return -code error
        }
        set clearan 0
        if {$clearance != ""} {
          set clearan $clearance
        }
        if {$instance != ""} {
          set pinst [get_cells $instance]
          if {$pinst != "NULL"} { 
            if {$clearan != 0} {
              [rt::design] createAnchorForMacroWClearance $pinst $clearan true 
            } else {
              [rt::design] createAnchorForMacro $pinst true
            }
            #puts "Anchor to instance $instance is created."
          } else {
            puts "No instance matches $instance."
          }
        } else {
          if { $port != ""} {
            set pport [get_pin $port]
            if {$pport != "NULL"} {
              if {$clearan != 0} {
                [rt::design] createAnchorForPortWClearance $pport $clearan true 
              } else {
                [rt::design] createAnchorForPort $pport true
              }
              #puts "Anchor to port $port is created."
            } else {
              puts "No port matches $port."
            }
          }
        }
    }

    proc remove_anchor { instance port } {
        set topDes [rt::design]
        if {$topDes == "NULL"} {
          rt::UMsg_tclMessage NL 173
          return -code error
        }
        set instPortFound 0
        if {$instance != ""} {
          set pinst [get_cells $instance]
          if {$pinst != "NULL"} {
            set instPortFound 1
            [rt::design] removeAnchor $pinst 1 
            puts "Anchor to instance $instance is removed."
          } else {
            puts "No instance matches $instance."
          }
        } else {
          if { $port != ""} {
            set pport [get_pin $port]
            if {$pport != "NULL"} {
              set instPortFound 2
              [rt::design] removeAnchor $pport 1
              puts "Anchor to port $port is removed."
            } else {
              puts "No port matches $port."
            }
          }
        }
    }

    proc dump_vias { fname } {
      if { $fname != ""} {
        # puts " $rt::db dumpVias $fname  "
        [ $rt::db  dumpVias $fname ] 
      } else {
        # puts " $rt::db dumpVias] tmp.via  "
        [ $rt::db  dumpVias tmp.via ] 
      }
    }


    proc reportNet {physical nm} {
	global rt::UNM_sdc
	set hier 0
	set mod [[design] topModule]
	set net [$mod findNet $nm $rt::UNM_sdc $hier]
	if {$net != "NULL"} {
	    set pin [$net firstPin]
	} else {
	    set pin [$mod findPin $nm]
	}
	if {$pin == "NULL"} {
	    return -code error "Could not find net/pin '$nm'"
	}
	$pin reportNet $physical
    }

    proc reportInstances {nm} {
	global rt::UNM_sdc
	set hier 0
	set topDes [rt::design]

	if {$topDes == "NULL"} {
	    return -code error
	}

	set mod [[design] topModule]

	if {$nm != ""} {
	    set instObjs [$mod findInstances $nm $rt::UNM_sdc $hier]
	    if {[llength $instObjs] != 0} {
		$topDes reportInstances $instObjs
		release $instObjs
	    } else {
		puts "No instances match pattern $nm"
		return -code error
	    }
	} else {
	    $topDes reportInstances
	}
    }

    proc reportHierarchy {{leaf 0} {all 0} {dp 0} {name}} {
      
      	if {$name == ""} {
            [rt::design] reportModules $leaf $all $dp
        } else {
	    [rt::design] reportModules $leaf $all $dp $name
        }
    }

    proc reportPowerDomains {domain regions} {
	set ok true
	if {$domain != ""} {
	    set pd     [$rt::db findPowerDomain $domain]
	    if {$pd != "NULL"} {
		if {$ok} {
		    [rt::design] reportPowerDomains $pd $regions
		}
	    } else {
		rt::UMsg_tclMessage PF 104 $domain
		set ok false
	    }	    
	} else {
	    [rt::design] reportPowerDomains "NULL" false
	}

	if {$ok != true} {
	    return -code error
	}
    }

    proc reportPowerModes {} {
	[rt::design] reportPowerModes
	    }

    proc reportElecVio {domain showVioOnly} {
	if {$domain != ""} {
	    set pd     [$rt::db findPowerDomain $domain]
	    if {$pd != "NULL"} {
		[rt::design] reportElecVio $pd $showVioOnly
	    } else {
		rt::UMsg_tclMessage PF 104 $domain
		return -code error
	    }	    
	} else {
	    puts "warning: -domain option must be specified."
	    return -code error
	}
    }

    proc reportPower {} {
	[rt::design] reportPower
    }

    proc reportAttributes {obj type} {
	set objRef [rtdc::getObjRef $obj $type false]

            if {$objRef eq "NULL" || $objRef eq "" || [llength $objRef] == 0} {
            puts "warning: could not find an object for \'$obj\'."
            return
        }

        if {[llength $objRef] > 1} {
            puts "warning: more than one object specified in \'$obj\'"
            return
            }

            set objType [rt::typeOf $objRef]
            switch -- $objType {
                "NRefS" -
            "NCellS"   { return [$objRef reportAttributes] }
            "NInstS"   { return [$objRef reportAttributes] }
            "NNetS"    { return [$objRef reportAttributes] }
            "NPort"    { return [$objRef reportAttributes] }
	    "NPowerDomainS" { return [$objRef reportAttributes] }
            "NPinS"    { return -code error "unsupported type of object \'$objType\'" }
            "TClock"   { return -code error "unsupported type of object \'$objType\'" }
	    default    { return -code error "unknown type of object \'$objType\' for \'[$objRef name]\'" }
        }
    }

    proc reportEndpoints {cnt critical combined file} {
        if {$cnt == "" && !$critical} {
            set cnt 10
        }
	set j 1
	set des [design]
	set sz 2
        if { $file ne "" } {
          set fileID [open $file "w"]  
        } 
	for {} {$j < $sz} {incr j} {
	    set group [$des groupName $j]
	    if {$combined} {
		set group ""
	    }
            if { ![info exists fileID] } {
	      rt::UMsg_print "Endpoints for group $group\n\n"
              rt::UMsg_print  "Endpoint                       Path Delay     Requirement    Clock Skew     Slack\n"
              rt::UMsg_print  "---------------------------------------------------------------------------------\n" 
            } else {
	      puts $fileID "Endpoints for group $group\n"
              puts $fileID  "Endpoint                       Path Delay     Requirement    Clock Skew     Slack"
              puts $fileID  "---------------------------------------------------------------------------------" 
            }  
	    set i 0
	    set deps [$des detailedEndPoints $group]
	    while {![$deps empty] && (($i < $cnt) || ($cnt < 1))} {
		set dep     [$deps pop]
		set slack   [$dep slack]
		set ps      [string trimright $slack "ps"]
		if {$critical && $ps >= 0} {
		    break
		}
                set validSlack [$dep validSlack]
                if {!$validSlack} {
                  break; 
                }  
                set detailedInfo [$dep detailedInfo]
                if { ![info exists fileID] } {
	  	  rt::UMsg_print "${detailedInfo} \n"
                } else {
	  	  puts $fileID "${detailedInfo}"
                }  
		incr i
	    }
	    if {$j == 1 && !$combined} {
		set sz [$des numPathGroups]
	    }
	}
        if { [ info exists fileID] } {
          close $fileID   
        }  
    }

    proc typeOf {obj} {
	set comp [split $obj "_"]
	if {([llength $comp] < 4) ||
	    ([lindex $comp 0] != "") ||
	    ([lindex $comp 2] != "p") ||
	    ([string is xdigit -strict [lindex $comp 1]] != 1)} {
	    return NULL
	} else {
	    return [join [lrange $comp 3 end] _]
	}
    }

    proc getLibCell {nm} {
	set libCell [split $nm '/']
	if {[llength $libCell] == 2} {
	    set lib  [$rt::db findLibrary [lindex $libCell 0]]
	    if {$lib != "NULL"} {
		set cell [$lib findCell [lindex $libCell 1]]
	    } else {
		set cell "NULL"
	    }
	} else {
	    set cell [$rt::db findCell [lindex $libCell 0]]
	}
	return $cell
    }

    proc getLibCells {list {verbose 1}} {
	set cellList {}
	foreach pattern [utils::flatList $list] {
	    set objType [rt::typeOf $pattern]
	    if {$objType == "NCellS"} {
		lappend cellList $pattern
	    } else {
		set libCell [split $pattern '/']
		if {[llength $libCell] == 2} {
		    set libs  [$rt::db findLibraries [lindex $libCell 0]]
		    set cells "NULL"
		    if {[$libs size] > 0} {
			for {set i [$libs begin]} {[$i ok]} {$i incr} {
			    set lib [$i object]
			    set tmpCells [$lib findCells [lindex $libCell 1]]
			    if {$cells == "NULL"} {
				set cells $tmpCells
			    } else {
				$cells splice [$cells begin] $tmpCells
				rt::delete_NRefList $tmpCells
			    }
			}
			rt::delete_NLibList $libs
		    } else {
			if {$verbose != 0} {
			    puts "Cannot find library '[lindex $libCell 0]'"
			}
			rt::delete_NLibList $libs
			continue
		    }
		} else {
		    set cells [$rt::db findCells [lindex $libCell 0]]
		}
		if {[$cells size] > 0} {
		    for {set i [$cells begin]} {[$i ok]} {$i incr} {
			set cell [[$i object] isCell]
			lappend cellList $cell
		    }
		} elseif {$verbose != 0} {
		    puts "Cannot find any cell '$pattern'"
		}
		rt::delete_NRefList $cells
	    }
	}
	return [utils::flatList $cellList]
    }

    proc _setDirective {hier flat args directive v {um 0}} {
 	if {$v == "true"} {
	    set v 1
	} else {
	    set v 0
	}
	set des [$rt::db topDesign]
	if {$des == "NULL"} {
	    set cellList [getLibCells $args 0]
	    if {[llength $cellList] > 0} {
		foreach cell $cellList {
		    $cell setDontTouch $v
		}
	    } else {
		foreach obj [utils::flatList $args] {
		    $rt::db $directive $obj
		}
	    }
	} else {
	    set cnt 0
	    global rt::UNM_sdc
	    set topMod [$des topModule]
	    foreach obj [utils::flatList $args] {
		set objType [rt::typeOf $obj]
		if {$objType == "NULL"} {
		    set d_objs ""
		    set d_objs [$topMod findInstances $obj $rt::UNM_sdc $hier]
                    if {$d_objs == ""} {
			set d_objs [$topMod findNets $obj $rt::UNM_sdc $hier]
		    }
                    if {$d_objs == ""} {
		    set d_mods [$des getModules $obj]
		    for {set i [$d_mods begin]} {[$i ok]} {$i incr} {
			lappend d_objs [$i object]
		    }
		    rt::delete_NRealModList $d_mods
		    }
		    if {$d_objs == ""} {
			set d_objs [$topMod findInstances $obj $rt::UNM_sdc $hier]
		    }
                    if {$d_objs == ""} {
			set d_objs [$topMod findNets $obj $rt::UNM_sdc $hier]
		        set cellList [getLibCells $obj 0]
		        if {[llength $cellList] > 0} {
		            foreach cell $cellList {
			        $cell setDontTouch $v
			        incr cnt 1
 		            }
		            continue
                        }
			set d_objs [$topMod findNets $obj $rt::UNM_sdc $hier]
		    }
		} elseif {$objType == "NRealModS"} {
		    set d_objs $obj
		} elseif {$objType == "NInstS"} {
		    set d_objs $obj
		} elseif {$objType == "NNetS"} {
		    set d_objs $obj
                } elseif {$objType == "NCellS"} {
                    $obj setDontTouch $v
                    incr cnt 1
                    continue
		} else {
		    puts "warning: set_dont_touch not supported for object type $objType"
		    continue
		}
		foreach obj $d_objs {
		    if {[rt::typeOf $obj] == "NNetS"} {
			incr cnt [$obj $directive $v $flat]
		    } else {
			## must be an instance or module
			if {$directive == "setDontRemove"} {
			    incr cnt [$obj setDontRemove $v $um]
			} else {
			    incr cnt [$obj $directive $v]
			}
			release $obj
		    }
		}
	    }
	    if {$cnt} { set msgT "info" } else { set msgT "warning" }
	    puts "$msgT: applied '$directive=$v' to $cnt objects"
	}
    }

    proc setDontTouch {hier flat args val} {
	_setDirective $hier $flat $args setDontTouch $val
    }

    proc setDontRemove {hier flat args val} {
	_setDirective $hier $flat $args setDontRemove $val
    }
    
    proc setPreserveBoundary {hier up down args val} {
	if {$up == "false" || $down == "true"} {
	    _setDirective $hier false $args setPreserveBoundaryDown $val
	}
	if {$down == "false" || $up == "true"} {
	    _setDirective $hier false $args setPreserveBoundaryUp $val
	}
    }

    proc setDontGateClock {list val} {
	set des [$rt::db topDesign]
	if {$des == "NULL"} {
	    foreach item $list {
		$rt::db setDontGateClock $item
	    }
	} else {
	    _setDirective false false $list setDontGateClock $val
	}
    }

    proc setDontUngroup {hier flat args val} {
	_setDirective $hier $flat $args setDontRemove $val true
    }
    
    proc _setDontUse {family targetLib cells val} {
	if {$val == "true"} {
	    set val 1
	} else {
	    set val 0
	}
	set tlibs {}
	if {$targetLib == ""} {
	    foreach pat [utils::flatList $cells] {
                set type [rt::typeOf $pat]
                if {$type ne "NULL" && $type ne "NCellS"} {
                    puts "warning: set_dont_use can only take libcell name or libcells as argument"
                    continue
                }
                foreach cell [getLibCells $pat] {
		$cell setDontUse $val
	    }
	    }
	} else {
	    foreach libnm $targetLib {
		set tlib [$rt::db findTargetLib $libnm]
		if {$tlib == "NULL"} {
		    return -code error "Cannot find target library '$libnm'"
		}
		lappend tlibs $tlib
	    }
	    foreach tlib $tlibs {
		foreach cell [getLibCells $cells] {
		    if {$family} {
			set fam [$tlib findRefFamily $cell]
			for {set ri [[$fam references] begin]} {[$ri ok]} {$ri incr} {
			    lappend refs [$ri object]
			}
			foreach ref $refs {
			    set cell [$ref isCell]
			    $cell setDontUse $val $tlib
			}
		    } else {
			$cell setDontUse $val $tlib
		    }
		}
	    }
	}
    }

    proc setDontUse {family tlib cells val} {
	return [_setDontUse $family $tlib $cells $val];
    }

    proc createVthGroup {name lib_cells cells} {
	if {$cells ne ""} {
	    rt::UMsg_tclMessage CMD 113 -cells create_threshold_voltage_group -lib_cells
	    if {$lib_cells eq ""} {
		set lib_cells $cells
	    }
	}

	set cellList [getLibCells $lib_cells]
	set refList [$rt::db createVthGroup $name]
	if {$refList != "NULL"} {
	    foreach ref $cellList {
		$rt::db addCellToVthGroup $name $ref
	    }
	} else {
	    return -code error
	}
    }

    proc removeVthGroup {name} {
	set ok [$rt::db removeVthGroup $name]
	if {!$ok} {
	    return -code error
	}
    }

    proc renameVthGroup {from to} {
	set ok [$rt::db renameVthGroup $from $to]
	if {!$ok} {
	    return -code error
	}
    }

    proc release {args} {
	set parm [rt::UParam_get dontReleaseObjects rc]
	if {$parm == true} {
	    return
	}
	foreach obj [utils::flatList $args] {
	    if {[rt::typeOf $obj] != "NULL"} {
		if {[rt::typeOf $obj] == "NDesS"} {
		    $obj release
		} else {
		    [$obj design] release
		}
	    }
	}
    }

    proc find {inst net pin lib_cell cell mod power_domain 
	       hier in_module {get_objs 0} d_name} {
	global rt::UNM_sdc
	set modGen "NULL"
	set do_release 1

	if {$cell} {
	    rt::UMsg_tclMessage CMD 113 -cell find -lib_cell
	    set lib_cell $cell
	}

	if {$inst || $net || $pin || $mod} {
	    set topDes [rt::design]
	    if {$in_module == ""} {
		set topMod [$topDes topModule]
	    } else {
		if {!($inst || $net || $pin)} {
		    puts "error: Can only use -in_module with -pin, -net or -inst"
		    return -code error
		}
		if {$get_objs} {
		    puts "error: Cannot use both -obj and -in_module"
		    return -code error
		}
		set d_refs [$topDes findModules $in_module]
		set rc [$d_refs size]
		if {$rc == 0} {
		    puts "error: Cannot find module \"$in_module\""
		    return -code error
		}
		if {$rc > 1} {
		    puts "error: Found more then one module matching \"$in_module\""
		    return -code error
		}
		set ri [$d_refs begin]
		set inModRef [$ri value]
		set inModNm  [$ri object]
		puts "inMod = $inModRef $inModNm"
		rt::delete_NRefMap $d_refs
		set topMod [$inModRef isRealModule]
		if {$topMod == "NULL"} {
		    set modGen [$inModRef isGenome]
		    set modDes [$modGen acquireDesign]
		    set topMod [$modDes findModule $inModNm]
		    set do_release 0
		}
		puts "topMod = $topMod"
	    }
	}

	set nmt 1
	if {$inst} {
	    set d_objs [$topMod findInstances $d_name $rt::UNM_sdc $hier]
	} elseif {$net} {
	    set d_objs [$topMod findNets $d_name $rt::UNM_sdc $hier]
	} elseif {$pin} {
	    set d_objs [$topMod findPins $d_name $rt::UNM_sdc $hier]
	} elseif {$power_domain} {
	    set nmt 2
	    set d_pds [$rt::db findPowerDomains $d_name]
	    for {set i [$d_pds begin]} {[$i ok]} {$i incr} {
		set d_pd [$i object]
		lappend d_objs $d_pd
	    }
	    rt::delete_NPowerDomainList $d_pds
	} elseif {$lib_cell || $mod} {
	    set do_release 0
	    set d_objs {}
	    if {$lib_cell} {
		set nmt 2
		set d_refs [$rt::db findCells $d_name]
		for {set i [$d_refs begin]} {[$i ok]} {$i incr} {
		    set d_ref [$i object]
		    lappend d_objs $d_ref
		}
		rt::delete_NRefList $d_refs
	    } else {
		set nmt 3
		set d_refs [$topDes findModules $d_name]
		for {set i [$d_refs begin]} {[$i ok]} {$i incr} {
		    # append {<genomeObj> <moduleName>}
		    lappend d_objs [list [$i value] [$i object]]
		}
		rt::delete_NRefMap $d_refs
	    }
	} else {
	    puts "error: Must specify one of the find options"
	    ::find -help
	    return -code error
	}
	if {$d_objs == {}} {
	    puts "warning: No objects found"
	}
	if {$get_objs} {
	    return $d_objs
	}
	set d_list {}
	foreach obj $d_objs {
	    switch $nmt {
		1 { set d_name [$obj fullName] }
		2 { set d_name [$obj name] }
		3 { set d_name [lindex $obj 1] }
	    }
	    lappend d_list $d_name
        }
	if {$do_release} {
	    release $d_objs
	} elseif {$modGen != "NULL"} {
	    $modGen releaseDesign "false"
	}
	return $d_list
    }

    proc reportClocks {detail} {
	[rt::design] reportClocks $detail
    }

    proc reportClockGating {{detail 0} {type} {mod} {inst}} {
	if {$mod != ""} {
	    if {$inst != ""} {
		if {[[rt::design] reportClockGating $type $detail $mod $inst] > 0} {
		    return -code error;
		}
	    } else {
		if {[[rt::design] reportClockGating $type $detail $mod] > 0} {
		    return -code error;
		}
	    }
	} else {
	    if {$inst != ""} {
		return -code error "need to specify -module when -instance is specified"
	    } else {
		if {[[rt::design] reportClockGating $type $detail] > 0} {
		    return -code error;
		}
	    }
	}
    }

    proc runRtlElab {module gate_clock map_to_scan {params {}}} {
	start_state "RTL Elaboration"

	# normalize param list: {x 2} -> { {x 2} }
	if {[llength $params] == 2 &&
	    [llength [lindex $params 0]] == 1} {
	    set params [list $params]
	}
	
	set st [$rt::db synthesize $module $gate_clock $map_to_scan $params]
	stop_state "RTL Elaboration"
	if {$st != 0} {
	    return -code error "RTL Elaboration failed"
	}
        set sdcrt::currMod [[rt::design] topModule]
	return
    }


    # This requires rt::checksumFileList to be populated
    proc filesetChecksum {} {
	set doChecksum 0 
	if { $rt::runningPA_ } {
	    if {[get_param netlist.allowChecksum]} {
		set doChecksum 1
	    }
	}
	if {[info exists ::env(FILESET_CHECKSUM)]} {
	    set doChecksum 1
	}
	if {$doChecksum} {
	    if {[info exists rt::checksumFileList]} {
		foreach fname $rt::checksumFileList {
		    $rt::db fileCrc $fname
		}
	    }
#	    if {[info exists rt::SDCFileList]} {
#		foreach fname $rt::SDCFileList {
#		    rt::crcPrepSdc $fname $::env(RT_TMP)/sdcSettings
#		    $rt::db fileCrc $::env(RT_TMP)/sdcSettings
#		    file delete $::env(RT_TMP)/sdcSettings
#		}
#	    }
	    set driverScript [info script]
	    if {[file exists $driverScript]} {
		rt::crcPrepDriver $driverScript $::env(RT_TMP)/driverSettings
		$rt::db fileCrc $::env(RT_TMP)/driverSettings
		file delete $::env(RT_TMP)/driverSettings
	    }
	    puts "Phase 0 Synthesis_fileset | Checksum: [format %x [$rt::db endFileCrc]]"
	}
	set rt::checksumFileList {}
    }

    proc sdcChecksum {} {
	set doChecksum 0 
	if { $rt::runningPA_ } {
	    if {[get_param netlist.allowChecksum]} {
		set doChecksum 1
	    }
	}
	if {[info exists ::env(FILESET_CHECKSUM)]} {
	    set doChecksum 1
	}
	if {$doChecksum} {
	    if {[info exists rt::SDCFileList]} {
		set fcount 0
		foreach fname $rt::SDCFileList {
		    # keep these lines - need to debug repeatability issues
		    # incr fcount
		    # rt::crcPrepSdc $fname sdcSettings_$fcount
		    # $rt::db fileCrc sdcSettings_$fcount
		    rt::crcPrepSdc $fname $::env(RT_TMP)/sdcSettings_$fcount
		    $rt::db fileCrc $::env(RT_TMP)/sdcSettings_$fcount
		    file delete $::env(RT_TMP)/sdcSettings
		}
	    }
	    puts "Phase 0 Synthesis_xdc | Checksum: [format %x [$rt::db endFileCrc]]"
	}
    }

    proc synthesize {module gate_clock map_to_scan {params {}}} {
	start_state "Synthesize"

	# normalize param list: {x 2} -> { {x 2} }
	if {[llength $params] == 2 &&
	    [llength [lindex $params 0]] == 1} {
	    set params [list $params]
	}
	
	set st [$rt::db synthesize $module $gate_clock $map_to_scan $params]
	stop_state "Synthesize"
	if {$st != 0} {
	    return -code error "synthesize failed"
	}
        set sdcrt::currMod [[rt::design] topModule]
	return
    }

	proc readDiskDesign {} {
		if {[rt::get_parameter enableSplitFlowXDC] == true && [rt::get_parameter enableSplitFlow] == true} {
                        set tmpRtlData $rt::rtlData
			rt::delete_design
                        set rt::rtlData $tmpRtlData
			$rt::db splitFlow2ndPassPreprocessing
		}
		
		if {[[$rt::db topDesign] topModule] == "NULL"} {
			return 1
		} else {
			# load the design, and set sdcrt::currMod
			if {[rt::get_parameter enableSplitFlowXDC] == true && [rt::get_parameter enableSplitFlow] == true} {
				set topMod [[rt::design] topModule]
				#puts "topMod is $topMod"
				set sdcrt::currMod $topMod
				#puts "set currMod to $sdcrt::currMod"
			}
		}
	}

    proc createPowerDomain {name inst def} {
		set pd [$rt::db newPowerDomain $name]
	if {$pd == "NULL"} {
	    puts "warning: 'create_power_domain' command ignored"
	    return
	}
	foreach i $inst {
	    $rt::db setPowerDomain $i $pd
	}
	if {$def} {
	    $rt::db setPowerDomain $pd
	}
    }

    proc updatePowerDomain {name libnm} {
	set pd [$rt::db findPowerDomain $name]
	if {$pd == "NULL"} {
	    #puts "warning: power domain '$name' not found"
	    rt::UMsg_tclMessage NL 136 $name
	    puts "warning: 'update_power_domain' command ignored"
	    return
	}
	set lib [$rt::db findTargetLib $libnm]
	if {$lib == "NULL"} {
	    #puts "warning: target library '$libnm' not found"
	    rt::UMsg_tclMessage NL 137 $libnm
	    puts "warning: 'update_power_domain' command ignored"
	    return
	}
	$pd setTargetLib $lib
    }

    proc ungroup {all flatten start_level small names} {
	set topMod [[rt::design] topModule]
	if {$all == "true" ||
	    $start_level > 0 ||
	    $small > 0} {
	    return [[sdcrt::getCurrMod] flatten $start_level $small $force]
	}
	global rt::UNM_sdc
	foreach nm $names {
	    set type [rt::typeOf $nm]
	    if {$type == "NULL"} {
		set ins [[sdcrt::getCurrMod] findInstances $nm rt::$UNM_sdc "false"]
		if {$ins == ""} {
		    puts "Could not find instance '$nm'"
		    continue
		}
	    } elseif {$type == "NInstS"} {
		set ins $nm
	    } else {
		puts "wrong argument '$nm', must be an instance."
		return -code error
	    }

	    foreach in $ins {
		set ds [$in design]
		set fn [$in fullName]
		set gn [$in isGenome]
		if {$gn != "NULL"} {
		    if {![$gn isUserModule]} {
			# presumably multiply instantiated and already
			# dissolved previously in this loop
			continue
		    }
		    set release 1
		    set ds [$gn acquireDesignForInstance $in]
		    set rm [$ds topModule]
		} else {
		    set release 0
		    set rm [$in isRealModule]
		}
		if {[$ds genome] != "NULL"} {
		    set release 1
		}
		if {[$in isCell] != "NULL"} {
		    puts "Cannot ungroup leaf instance '$fn'"
		} elseif {($rm != "NULL") && ([$rm dfGraph] != "NULL")} {
		    puts "Cannot ungroup DF-partition '$fn'"
		} elseif {[$in isDontRemove]} {
		    puts "Cannot ungroup 'dont_remove' instance '$fn'"
		} else {
		    if {$flatten == "true"} {
			puts "Flattening instance '$fn' of module '[[$in reference] name]'"
			$rm flatten 0 0
		    } else {
			puts "Ungrouping instance '$fn' of module '[[$in reference] name]'"
		    }
		    [$in ungroup 0]
		    set release 0
		}
		if {$release} {
		    release $ds
		}
	    }
	}
    }

    proc flatten {level count} {
        if {$level == ""} { set level 0 }
        if {$count  == ""} { set count 0 }
        [sdcrt::getCurrMod] flatten $level $count 0
    }

    proc reportCongestion {style} {
	set sty 1
	if {[string equal $style numeric_map]} {
	    set sty 2
	} elseif {[string equal $style symbolic_map]} {
	    set sty 3
	}
	[rt::design] reportCongestion $sty
    }

    proc reportLeakEfficiency {detail instance module} {
	set ok true
	set topDes [rt::design]
	set topMod [$topDes topModule]

	if {$instance ne "" && $module ne ""} {
	    rt::UMsg_tclMessage CMD 100 "-instance" "-module"
	    set ok false
	}

	set mod "NULL"
	if {$ok} {
	    if {$module ne ""} {
		set d_refs [$topDes findModules $module]
		set rc [$d_refs size]
		if {$rc == 0} {
		    rt::UMsg_tclMessage CMD 102 $module
		    set ok false
		}
		if {$rc > 1} {
		    rt::UMsg_tclMessage CMD 119 module $module
		    set ok false
		}
		if {$ok} {
		    set ri [$d_refs begin]
		    set inModRef [$ri value]
		    set mod [$inModRef isRealModule]
		}
		rt::delete_NRefMap $d_refs
	    } elseif {$instance ne ""} {
		global rt::UNM_sdc
		set d_insts [$topMod findInstances $instance $rt::UNM_sdc false]
		set ic [llength $d_insts]
		puts $ic
		if {$ic == 0} {
		    rt::UMsg_tclMessage CMD 105 $instance instance
		    set ok false
		}
		if {$ic > 1} {
		    rt::UMsg_tclMessage CMD 119 instance $instance
		    set ok false
		}
		if {$ok} {
		    foreach inst $d_insts {
			set mod [$inst isRealModule]
			if {$mod == "NULL"} {
			    rt::UMsg_tclMessage POWER 120 $instance
			    set ok false
			}
		    }
		}
		release $d_insts
	    } else {
		set mod $topMod
	    }
	}

	if {$ok} {
	    $mod reportLeakEfficiency $detail
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc reportPathgroups {detail} {
	[rt::design] reportPathgroups $detail
    }

    proc reportLibCells {targetLibNm 
			 standard level_shifter isolation retention
			 dump pattern pinCount} {
	#puts "1. $targetLibNm 2. $standard 3. $level_shifter 4. $dump 5. $pattern"
	set ok true

	if {$pinCount == ""} {
	    set pinCount 0
	}

	if {$pattern == ""} {
	    set pattern "*"
	}
	set refList [$rt::db findCells $pattern]

	if {$dump == "true"} {
	    if {$targetLibNm != "" ||
		$standard == true ||
		$level_shifter == true ||
		$isolation == true ||
		$retention == true} {
		#puts "-target_library, -standard, -level_shifter, -isolation or -retention options are ignored with -dump"
		rt::UMsg_tclMessage CMD 100 "-dump" "-target_library, -standard, -level_shifter, or -isolation"
		set ok false
	    }

	    if {$ok} {
		## ############################
		## this is used internally only
		## ############################
		if {[$refList size] > 0} {
		    for {set i [$refList begin]} {[$i ok]} {$i incr} {
			set ref [[$i object] isCell]
			set refPinCount [$ref pinCount]
			if {$pinCount == 0 || $refPinCount == $pinCount} {
			    $ref _print
			}
		    }
		} else {
		    #puts "Cannot find any cell '$pattern'"
		    rt::UMsg_tclMessage CMD 105 $pattern "cell"
		    set ok false
		}
	    }
	} else {
	    if {$targetLibNm == ""} {
		set targetLib [$rt::db findOrAddTargetLib "default"]
	    } else {
		set targetLib [$rt::db findOrAddTargetLib $targetLibNm]
	    }

	    set visited("") 1
	    set famList {}
	    for {set i [$refList begin]} {[$i ok]} {$i incr} {
		set ref [$i object]
		set refPinCount [$ref pinCount]
		if {$pinCount == 0 || $refPinCount == $pinCount} {
		    set fam [$targetLib findRefFamily $ref]
		    if {$fam != "NULL"} {
			if {![info exists visited($fam)]} {
			    lappend famList $fam
			    set visited($fam) 1
			} 
		    }
		}
	    }

	    $rt::db reportLibCells $targetLib $standard $level_shifter $isolation $retention $famList
	}

	rt::delete_NRefList $refList

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc setUnitsPerMicron {units} {
	if {[llength [history]] != 3} {
	    error "Cannot apply this command because it is not the first command."
	} elseif {$units <= 0} {
	    error "Argument has to be positive integer."
	}
	$rt::db setUnitsPerMicron $units
    }

    proc apply_with_rect {cmd left bottom right top} {
	if {$left=="" && $bottom=="" && $right=="" && $top==""} {
	    error "Please specify at lease one coordinate"
	}
	if {$left==""} {set left 0}
	if {$bottom==""} {set bottom 0}
	if {$right==""} {set right 0}
	if {$top==""} {set top 0}
	set result [[rt::design] $cmd $left $bottom $right $top]
        return $result
    }

    proc createDie {rectPts} {
        # now need to process the inputs and make a list of double's, to pass on to createDie
        set dblList {}
        set cnt 0
        while {[regexp {\(\s?([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)\s?,\s?([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)\s?\)} $rectPts matched x xExp y yExp]} {
            regsub {\(\s?([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)\s?,\s?([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)\s?\)} $rectPts {} rectPts
            #puts $matched
            lappend dblList $x
            lappend dblList $y
            incr cnt
        }
        #puts "$cnt coordinates recognized."
        if { ($cnt < 4 && $cnt != 2) || ($cnt >= 4 && $cnt / 4 * 4 != $cnt) } {
            puts "Wrong number of die corners recognized: $cnt, please user proper format and data value."
            return -code error
        }
	set result [[rt::design] createDie $dblList]
        if {$result > 0} {
            return -code error
        }
    }

    proc createClearance {left bottom right top} {
	set result [apply_with_rect createClearance $left $bottom $right $top]
        if {$result > 0} {
            return -code error
        }
    }

    proc createCore {left bottom right top} {
	set result [apply_with_rect createCore $left $bottom $right $top]
        if {$result > 0} {
            return -code error
        }
    }

    proc createObstruct {obs left bottom right top} {
	if {$left=="" && $bottom=="" && $right=="" && $top==""} {
	    error "Please specify at lease one coordinate"
	}
	if {$left==""} {set left 0}
	if {$bottom==""} {set bottom 0}
	if {$right==""} {set right 0}
	if {$top==""} {set top 0}
	set blockage [[rt::design] createObstruct $obs $left $bottom $right $top]
        if {$blockage == "NULL"} {
            return -code error
        }
    }

    proc refineMacro {inst fix unfix orient} {
	set opt 0
	if {$fix} { incr opt }
	if {$unfix} { incr opt }
	if {$orient!=""} { incr opt }
	if {$opt > 1} {
	    error "Can only specify one of the options: -fix, -unfix, -orient"
	}
	[rt::design] refineMacro $inst $fix $unfix $orient
    }

    proc refine {} {
	start_state "Refine"
	[rt::design] dplace
	[rt::design] resetTiming
	stop_state "Refine"
    }

    proc readCapTable {ctfile atop soce coupling} {
        global rt::cmdEcho
        global rt::cmdFdEcho
        set cmdEchoRestore $cmdEcho
        set cmdFdEchoRestore $cmdFdEcho

        set isEncryptedFile [UFile_isEncrypted $ctfile]

	if {$atop && $soce} {
	    error "Can only specify one of these options: -atop or -soce"
	} elseif {![file exists $ctfile]} {
	    error "$ctfile does not exist"
	} elseif {$soce} {
	    if {$coupling < 0} {
		set coupling 0.0
	    } elseif {$coupling > 1.0} {
		set coupling 1.0
	    }

            # suppress cmd/cmdfile echo
            if {$isEncryptedFile} {
                set cmdEcho 0
                set cmdFdEcho 0
            }        

	    $rt::db invalidateRC
            $rt::db readCapTable $ctfile "soce" $coupling

            # restore cmd/cmdfile echo
            if {$isEncryptedFile} {
                set cmdEcho $cmdEchoRestore
                set cmdFdEcho $cmdFdEchoRestore
            }        
	} else {
            # suppress cmd/cmdfile echo
            if {$isEncryptedFile} {
                set cmdEcho 0
                set cmdFdEcho 0
            }        

	    $rt::db invalidateRC
            $rt::db readCapTable $ctfile "atop"

            # restore cmd/cmdfile echo
            if {$isEncryptedFile} {
                set cmdEcho $cmdEchoRestore
                set cmdFdEcho $cmdFdEchoRestore
            }        
	}
    }

    proc readCPF {cpfFile} {
	if {$rtupf::upfON} {
	    rt::UMsg_tclMessage PF 169 CPF UPF
	    return -code error
	}
	set des [$rt::db topDesign]
	if {$des != "NULL"} {
	    rt::UMsg_tclMessage PF 215
	    return -code error
	}
	set file [rt::searchPath $cpfFile]
	if [file exists $file] {
	    rtcpf::pushFileDir $file
	    set prevExposed [rtcpf::exposeCPF]
	    if {[catch {uplevel 2 tcl_source $file} emsg]} {
	    	puts $emsg
	    }
	    if {$prevExposed == false} {
		rtcpf::hideCPF
	    }
	    rtcpf::popFileDir
	} else {
	    error "$file does not exist"
	}
    }

    proc splitMsg {mod idx} {
	if {$idx == ""} {
	    set arr [split $mod  -]
	    set mod [lindex $arr 0]
	    set idx [lindex $arr 1]
	    set idx [string trimleft $idx "0"]
	}
	return "$mod $idx"
    }

    proc messageEnable {mod idx} {
	eval rt::UMsgHandler_enable [splitMsg $mod $idx]
    }

    proc messageDisable {mod idx} {
	eval rt::UMsgHandler_disable [splitMsg $mod $idx]
    }

    proc messageCount {mod idx} {
	eval rt::UMsgHandler_count [splitMsg $mod $idx]
    }

    proc unsupported {cmd} {
	puts "warning: command \"$cmd\" is not supported"
    }

    proc sourceFile {echo verbose mode file} {
	set file [string map {"\\" "/"} $file]
	if {$mode != ""} {
	    [rt::design] setTimingMode $mode
	}
	global rt::cmdEcho
        set isEncryptedFile [UFile_isEncrypted $file]
        if {! $isEncryptedFile} {
            set cmdEchoRestore $cmdEcho
            if {$echo == "true"} {
                set cmdEcho 1
            }
            if {$verbose == "true"} {
                set cmdEcho 1
            }
        }
	set rc [uplevel 2 tcl_source \"$file\"]
        if {! $isEncryptedFile} {
            set cmdEcho $cmdEchoRestore
        }
	return $rc
     }

    proc delPhysical {all} {
	if {$all == "true"} {
	    [rt::design] initPhysical true true
	} else {
	    [rt::design] initPhysical true false
	}
    }

    proc getViaResistance {viaName} {
        puts " $rt::db getViaResistance $viaName "
        return [$rt::db] getViaResistance $viaName
    }

    proc setViaResistance {viaName resistance} {
        puts " $rt::db setViaResistance $viaName resistance true"
        [$rt::db] setViaResistance $viaName $resistance true
    }

    proc setMaxRouteLayer {maxLayer} {
	$rt::db maxRouteLayer $maxLayer
	set des [$rt::db topDesign]
	if {$des != "NULL"} {
	    $des removeCongGrid
	    $des resetPinCapacityPerUnit
	}
    }

    proc setRoutingUsage {layerName usage} {
	if {$usage < 0} {
	    set usage 0
	}
        if {$usage > 1} {
            set usage 1
        }
	if {[$rt::db setRouteUsage $layerName $usage]} {
	    puts "Max available routing resource for layer $layerName has been set to [expr $usage * 100.0]%"
	} else {
	    error "Unknown layer name $layerName"
	}

	set des [$rt::db topDesign]
	if {$des != "NULL"} {
	    $des removeCongGrid
	    $des resetPinCapacityPerUnit
	}
    }

    proc setLayerSpacing {layerName spacing} {
	if {$spacing < 0} {
	    error "Cannot specify negative value for spacing."
	}
	$rt::db setLayerSpacing $layerName $spacing
	set des [$rt::db topDesign]
	if {$des != "NULL"} {
	    $des removeCongGrid
	    $des resetPinCapacityPerUnit
	}
    }

    proc tempLinkPF {} {
	set pfcom [PFSynCom comhandler $rt::db]
	return [$pfcom tempLinkPF] 
    }

    proc writeDesign {comment fileNm} {
	set tmpDir [UFile_tmpDir]
	if {[file extension ${fileNm}] != ".odb"} {
	    set fileNm "${fileNm}.odb"
	}
	set fileNm [file normalize $fileNm]
	set des [rt::design]
	$des dump $comment
	if {[$des isPlaced] || [[$des bbox] isValid]} {
	    set write101 [rt::UMsgHandler_isEnabled WRITE 101]
	    set write120 [rt::UMsgHandler_isEnabled WRITE 130]
	    rt::UMsgHandler_disable WRITE 101
	    rt::UMsgHandler_disable WRITE 130
	    rt::UParam_set WriteDefGenomeRegions 0 true
	    $des writeDef true ${tmpDir}def
	    rt::UParam_set WriteDefGenomeRegions $writeGR true
	    if {$write101} {rt::UMsgHandler_enable WRITE 101}
	    if {$write120} {rt::UMsgHandler_enable WRITE 120}
	    exec echo def >> ${tmpDir}files.rtd
	}

        # dump Tcl settings for this session
        set f [open ${tmpDir}rt_session.tcl w]
        if {[info exists rt::rtlData]} {
            puts $f "set rt::rtlData \"$rt::rtlData\""
        }
	puts $f "return";    # prevents returning the last "set" value
        close $f
        exec echo rt_session.tcl >> ${tmpDir}files.rtd

	exec sh -c "cd ${tmpDir};tar -zcf ${fileNm} -T files.rtd"
    }

    proc readDesign {header_only fileNm verbose} {
	if {$verbose == "true"} {
	    set verbose 1
	} else {
	    set verbose 0
	}
	set tmpDir [UFile_tmpDir]
	if {[file extension ${fileNm}] != ".odb"} {
	    set fileNm "${fileNm}.odb"
	}
	set fileNm [file normalize ${fileNm}]
	if {![file exist ${fileNm}]} {
	    return -code error "No such file '${fileNm}'"
	}
	exec sh -c "test -d ${tmpDir} || mkdir ${tmpDir}"
	if {$verbose} { puts "Extracting odb ..." }
	set rc [catch {exec sh -c "cd ${tmpDir};tar -zxf ${fileNm}"} msg]
	if {$rc} {
	    return -code error "Not a proper odb file '${fileNm}'"
	}
	set headerOnly [string equal $header_only "true"]
	if {!$headerOnly} {
	    set headerOnly 0
	    set tlibOk [$rt::db targetLibsOkay false]
	    if {!$tlibOk} {
		return -code error "Can not read odb without a proper target library"
	    }
	    set rc [rt::tempLinkPF]
	    if {!$rc} {
		return -code error "Could not read odb without proper power format"
	    }
	}
	# read back Tcl variables and parameters
	if {!$headerOnly} {
	    if {[file exist ${tmpDir}rt_session.tcl]} {
		if {$verbose} { puts "Sourcing env ..." }
		set param104 [rt::UMsgHandler_isEnabled PARAM 104]
		rt::UMsgHandler_disable PARAM 104
		global rt::cmdEcho
		set cmdEchoRestore $cmdEcho
		set cmdEcho 0
		tcl_source ${tmpDir}rt_session.tcl
		set cmdEcho $cmdEchoRestore
		if {$param104} {rt::UMsgHandler_enable PARAM 104}
	    }
	}
	set rc [$rt::db undump $headerOnly $verbose]
	if {$rc} {
	    return -code error "Failed to read odb file '${fileNm}' (error $rc)"
	}
	if {!$headerOnly} {
	    if {[file exist ${tmpDir}def]} {
		if {$verbose} { puts "Loading def ..." }
		$rt::db readDef ${tmpDir}def false false true true
		[rt::design] floorplan
	    }
	    if {[file exist ${tmpDir}rt_session.tcl]} {
		if {$verbose} { puts "Sourcing env ..." }
		tcl_source ${tmpDir}rt_session.tcl
	    }
	}
	if {$verbose} { puts "Done" }
        set sdcrt::currMod [[rt::design] topModule]
	return
    }

    proc writePartition {floorplan prefix} {
      if {[info exists rt::ptnLibs]} {
        set fname "RTConfigLoadLibrarys.tcl"
        if {[catch {open $fname w} fp]} {
          error "Error \[open $fname w\]: $fp"
        } else {
          foreach value $rt::ptnLibs {
            puts $fp $value
          }
          close $fp
        }
        #puts "ptnLibs = "
        #puts $rt::ptnLibs
      }

      if {$prefix == ""} {
        [rt::design] writePartition $floorplan
      } else {
        [rt::design] writePartition $floorplan $prefix
      }
    }

    proc writeSdc {includeInternal fileNm inst} {
	if {$inst == ""} {
	[rt::design] writeSdc $includeInternal $fileNm
	} else {
	    set instObj [get_cell $inst]
	    $instObj writeSdc $fileNm
    }
    }

    proc configReport {name format} {
	$rt::db configReport $name $format
    }

    proc getMacros {} {
	set macros {}
	for {set ii [[[[rt::design] topModule] instances] begin true false true]} {[$ii ok]} {$ii incr} { 
	    set i [$ii object]
	    set c [[$i reference] isCell]
	    if {$c != "NULL"} {
		if {[$c sequentialType] == "macro"} {
		    llapend macros $i
		}
	    }
	}
	return $macros
    }

    proc getTiming {mode rise fall launch_clock bidir type pinObj} {
	global rt::UNM_sdc
	set topDes [rt::design]
	if {[rt::typeOf $pinObj] == "NULL"} {
	    set pin [[$topDes topModule] findPin $pinObj $rt::UNM_sdc]
	} else {
	    set pin $pinObj
	}
	if {$pin == "NULL"} {
	    puts "error: could not find pin '$pinObj'"
	    return -code error
	}
	set pinDes [$pin design]
	if {[$pinDes genome] != "NULL"} {
	    $pinDes deriveConstraints
	}
	set ti [rt::TimingInfo]
	if {$rise == "true"} {
	    $ti fixEdge "rise"
	}
	if {$fall == "true"} {
	    $ti fixEdge "fall"
	}
	set biIn "no"
	switch -- $bidir {
	    "in"  { $ti fixBiIn "yes" ; set biIn "yes" }
	    "out" { $ti fixBiIn "no"  ; set biIn "no"  }
	}
	if {$launch_clock != ""} {
	    if {[rt::typeOf $launch_clock] == "NULL"} {
		set launch_clock [$topdes findClockInCurrentMode $launch_clock]
	    }
	    if {[rt::typeOf $launch_clock] != "TClock"} {
	    }
	    $ti fixClock $launch_clock
	}
	set currMode [$topDes getTimingMode false]
	# do not return without resetting to currMode
	if {$mode != ""} {
	    set mode [$topDes findMode $mode]
	    set rc [$topDes changeTimingMode $mode]
	} else {
	    set mode $currMode
	}

	# keep types list insync with next switch
	lappend types "arrival"
	lappend types "cap"
	lappend types "clocks"
	lappend types "constant"
	lappend types "end_point_slack"
	lappend types "fanout"
	lappend types "pin_cap"
	lappend types "required"
	lappend types "slack"
	lappend types "tag_count"
	lappend types "transition"
	lappend types "wire_cap"
	lappend types "wire_delay"

	# keep cases insync with prev types list
	switch -- $type {
	    "arrival" {
		set rtn [$pin worstArrivalTime $ti]
	    }
	    "cap" {
		set rtn [$pin totalCap]
	    }
	    "clocks" {
		$pin worstArrivalTime $ti
		if {[$pin hasViews] == 0} {
		    puts "error: pin must be a driver or an endpoint"
		    set rtn "-code error"
		}
		set clocks {}
		$pin views cnt
		for {set c 0} {$c < $cnt} {incr c} {
		    set vw [$pin getView $c]
		    if {[$vw isEndPoint] == 0} {
			lappend clocks [[$vw clock] name]
		    }
		}
		set rtn \{$clocks\}
	    }
	    "constant" {
		set rtn [$pin getCFT $mode]
		if {$rtn < 0} {
		    set rtn ""
		}
	    }
	    "end_point_slack" {
		$ti fixEndPoint true
		set rtn [$pin worstSlack $ti]
	    }
	    "fanout" {
		set rtn [expr [$pin flatPinCount true] - 1]
	    }
	    "pin_cap" {
		set rtn [$pin pinCap]
	    }
	    "required" {
		set rtn [$pin worstRequiredTime $ti]
	    }
	    "slack" {
		set rtn [$pin worstSlack $ti]
	    }
            "tag_count" {
		$pin worstArrivalTime $ti
		if {[$pin hasViews] == 0} {
		    puts "error: pin must be a driver or an endpoint"
		    set rtn "-code error"
		}
		$pin views cnt
		set rtn $cnt
	    }
	    "transition" {
		set rtn [$pin slew $biIn]
	    }
	    "wire_cap" {
		set rtn [$pin netCap]
	    }
	    "wire_delay" {
		if {[$pin direction] == "output" } {
		    puts "error: pin cannot be an output pin"
		    set rtn "-code error"
		}
		set rtn [$pin netDelay]
	    }
	    default {
		puts "error: -type must be one of: $types"
		set rtn "-code error"
	    }
	}
	if {$mode != $currMode} {
	    set rc [$topDes changeTimingMode $currMode]
	}
	eval return $rtn
    }

    proc setFixMultiPortNets {feedthroughs outputs buffer_constants} {
	$rt::db setFixMultiPortNets $feedthroughs $outputs $buffer_constants
    }

    proc group {designName instanceName children} {
	set cInsts {}
	set parent ""
	set res ""
	foreach child $children {
	    if {[rt::typeOf $child] == "NULL"} {
		set c [get_cell $child]
		if {![llength $c]} {
		    puts "Error: cannot find instance $child"
		    return -code error
		}
	    } else {
		set c $child
	    }

	    if {![llength $parent]} {
		set parent [$c realModule]
	    }
	    if {$parent ne [$c realModule]} {
		puts "Error: Parent module of $child is different from that of other instances"
		return -code error
	    }
	    lappend cInsts $c
	}

	if {[llength $parent] && [llength $cInsts]} {
	    # TBD: check for unique designName name
	    set res [$parent createHierarchy $cInsts $designName 0 1 0 1]
	    if {$instanceName ne ""} {
		# TBD: check for unique name
		$res setUserName $instanceName
	    }
	}
	return $res
    }

    proc redirect {appnd fileNm command} {
	UMsgHandler_redirect $fileNm $appnd
	set rc [catch {uplevel 2 $command} msg]
	UMsgHandler_redirect -
	if {$rc} {
	    puts $msg
	    return -code error "redirect terminated because of error"
    }
    }

    proc getLefFiles {} {
        return [utils::flatList $rt::lefFiles]
    }

    proc getLibFiles {} {
        return [utils::flatList $rt::libFiles]
    }

    proc getLogFile {} {
        return [lindex $rt::fileNames 0]
    }

    proc getCmdFile {} {
        return [lindex $rt::fileNames 1]
    }

    proc configTiming {zeroDelay} {
        set quiet 1
        if {$zeroDelay eq "true"} {
            UParam_set topDesignAllowWLM true $quiet
            UParam_set genomesAllowWLM   true $quiet
            UParam_set wlmCapRate        0    $quiet
            UParam_set wlmResRate        0    $quiet
        } elseif {$zeroDelay eq "false"} {
            UParam_reset topDesignAllowWLM $quiet
            UParam_reset genomesAllowWLM   $quiet
            UParam_reset wlmCapRate        $quiet
            UParam_reset wlmResRate        $quiet
        }
    }
}

# TODO: change this to be handled in cli::addCommand, or not be necessary at all.
set rt::runningPA_ true
if { [info exists env(XILINX_REALTIMEFPGA)] } { set rt::runningPA_ false }

if { ! $rt::runningPA_ } {
  rename source tcl_source
} else {
  proc tcl_source { args } {
    uplevel #0 source $args
  }
}
#rename exit tcl_exit

interp alias {} sh {} exec

################################################################################
# exported commands
################################################################################

#
# Accepted but unsupported commands
#
if { ! $rt::runningPA_ } {
  proc set_dont_touch_network {args} {rt::unsupported set_dont_touch_network}
}

#
# Read commands
#
cli::addCommand rt::read_config           {rt::readConfig} {string}
cli::addCommand rt::read_def              {rt::readDef} {string} {boolean all false} {boolean flattened false} {boolean match_component true}
cli::addCommand rt::read_lef              {rt::readLef} {string}
cli::addCommand rt::read_library          {rt::readLibrary} {string} {string target_library}

if { ! $rt::runningPA_ } {
  cli::addCommand read_sdc         {sdcrt::readSdc} {boolean echo} {boolean verbose} {string mode} {string}
}
cli::addCommand rt::read_sdc       {sdcrt::readSdc} {boolean echo} {boolean verbose} {string mode} {string}

if { ! $rt::runningPA_ } {
  cli::addCommand read_verilog     {rt::readVerilog} {*string include} {*string define} {string library} {boolean sv false} {string}
}
cli::addCommand rt::read_verilog   {rt::readVerilog} {*string include} {*string define} {string library} {boolean sv false} {string}

if { ! $rt::runningPA_ } {
  cli::addCommand read_vhdl        {rt::readVhdl} {boolean vhdl87 false} {boolean vhdl2008 false} {string library} {string}
}
cli::addCommand rt::read_vhdl      {rt::readVhdl} {boolean vhdl87 false} {boolean vhdl2008 false} {string library} {string}

cli::addCommand rt::read_design    {rt::readDesign} {boolean header_only} {string} {boolean verbose}
cli::addHiddenCommand write_obfuscated_rtl \
                                      {"$rt::db writeObfuscatedRtl"} {string mapfile} {string}

#
# Flow commands
#
cli::addCommand rt::run_rtlelab    {rt::runRtlElab} \
                                   {string module} {boolean gate_clock} {boolean map_to_scan} {string parameters}
cli::addCommand rt::run_synthesis  {rt::synthesize} \
                                   {string module} {boolean gate_clock} {boolean map_to_scan} {string parameters}
if { ! $rt::runningPA_ } {
  cli::addCommand synthesize       {rt::synthesize} \
                                   {string module} {boolean gate_clock} {boolean map_to_scan} {string parameters}
}

cli::addCommand rt::run_optimize   {rt::optimize} \
                                      {boolean place_only} {boolean virtual} \
                                      {#boolean pre_placement} {#boolean incremental} \
                                      {#boolean reclaim_area} {#boolean area} {double critical_ratio} \
                                      {#double critical_offset} {#boolean propagate_only} {#boolean dont_propagate}
cli::addCommand rt::run_refine     {rt::refine} 
cli::addCommand rt::read_disk_design     {rt::readDiskDesign} 

#
# Floorplan commands
#
cli::addCommand rt::create_die            {rt::createDie} {string}
cli::addCommand rt::create_clearance      {rt::createClearance} {double left} {double bottom} {double right} {double top}
cli::addCommand rt::create_core_area      {rt::createCore} {double left} {double bottom} {double right} {double top}
cli::addCommand rt::create_halo           {rt::createHalo} {string instance} {string lib_cell} {#string cell} {double left} {double bottom} {double right} {double top}
cli::addCommand rt::create_blockage       {rt::createObstruct} {string name} {double left} {double bottom} {double right} {double top}
cli::addCommand rt::create_region         {rt::createRegion} {string} {string type} {string instance} {double left} {double bottom} {double right} {double top}
cli::addCommand rt::assign_to_region      {rt::assignToRegion} {string} {#string domain} {string instance}
cli::addCommand rt::assign_pins           {rt::assignPins} {enum {left right bottom top} side left} {string pins}
cli::addCommand rt::remove_from_region    {rt::removeFromRegion} {string} {#string domain} {string instance}
cli::addCommand rt::refine_macro          {rt::refineMacro} {string instance} {boolean fix} {boolean unfix} {string orient}
cli::addCommand rt::remove_blockage       {"[rt::design] removeObstruct"} {string name}
cli::addCommand rt::remove_region         {rt::removeRegion} {string}
cli::addCommand rt::add_power_guides      {rt::addPowerGuides} {string} {string guides}
cli::addHiddenCommand update_voltage_regions \
                                      {rt::updateVoltageRegions}
cli::addCommand rt::run_place_port            {rt::place_port} {string name} {double x} {double y} {string layer} {string rect}
cli::addCommand rt::run_create_anchor         {rt::create_anchor} {string instance} {string pin} {double clearance}  
cli::addCommand rt::run_remove_anchor         {rt::remove_anchor} {string instance} {string pin} 

cli::addCommand rt::run_set_fence_partition   {rt::set_fence_partition} {string fence} {string instance} {boolean all}

#
# Report commands
#
cli::addCommand rt::report_area           {"[rt::design] reportArea"} {boolean no_macros}
cli::addCommand rt::report_blackboxes     {"[rt::design] reportBlackBoxes"}
cli::addCommand rt::report_cells          {"[rt::design] reportCells"}
cli::addCommand rt::report_clocks         {rt::reportClocks} {boolean detail}
cli::addCommand rt::report_clock_gating   {rt::reportClockGating} {boolean detail} {enum {all gated ungated} type all} {string module} {string instance}
cli::addCommand rt::report_clock_gating_cell \
                                      {"[$rt::db targetLib] reportClockGates"}
cli::addCommand rt::report_clock_gating_options \
                                      {"$rt::db reportClockGateParam"}
cli::addCommand rt::report_congestion     {rt::reportCongestion} {enum {histogram numeric_map symbolic_map} style histogram}
cli::addCommand rt::report_design_metrics {"[rt::design] reportMetrics"}
cli::addCommand rt::report_leakage        {rt::reportLeakEfficiency} {boolean detail} {string instance} {string module}
cli::addCommand rt::report_path_groups    {rt::reportPathgroups} {boolean detail}
cli::addCommand rt::report_power          {rt::reportPower}
cli::addCommand rt::report_endpoints      {rt::reportEndpoints} {integer count} {boolean critical} {boolean combined} {string file ""}
cli::addCommand rt::report_instances      {rt::reportInstances} {?string}
cli::addCommand rt::report_power_domains  {rt::reportPowerDomains} {string domain} {#boolean regions}
cli::addCommand rt::report_power_modes    {rt::reportPowerModes}
cli::addCommand rt::report_pst            {rt::reportPST} {?string} 
cli::addCommand rt::report_electrical_violations \
    {rt::reportElecVio} {string domain} {boolean show_violation_only}
cli::addCommand rt::report_hierarchy      {"rt::reportHierarchy"} {boolean leaf} {boolean all} {boolean dp } {string name}
cli::addCommand rt::report_net            {rt::reportNet} {boolean physical} {string}
cli::addCommand rt::report_parameters     {"$rt::db reportParameters"} {boolean modified} {string group}
cli::addCommand rt::report_attributes     {rt::reportAttributes} {string} {string type}
cli::addCommand rt::report_rtl_partitions {"[rt::design] reportGenomes"}
cli::addCommand rt::report_route_layers   {"[rt::design] reportLayerUsage"}
cli::addCommand rt::report_library_cells  {rt::reportLibCells} {string target_library} \
    {boolean standard} {boolean level_shifter} {boolean isolation} {boolean retention} \
    {#boolean dump} {?string} {integer pin_count}

#
# Check commands
#
cli::addCommand rt::check_library         {"$rt::db checkLibraries"} {string items} {boolean verbose}
cli::addCommand rt::check_mv              {"$rt::db checkMV"} {string items} {boolean verbose}
cli::addCommand rt::check_netlist         {"[rt::design] checkNetlist"} {string items} {boolean verbose} {boolean elaborateRtl}
cli::addCommand rt::check_placement       {"[rt::design] checkPlace"} {string items} {boolean verbose}
cli::addCommand rt::check_timing          {"[rt::design] checkTiming"} {string items} {boolean verbose}

#
# Write commands
#
cli::addCommand rt::write_def             {"[rt::design] writeDef"} {boolean floorplan} {boolean partition} {string}
if { ! $rt::runningPA_ } {
  cli::addCommand write_verilog         {"$rt::db writeVerilog"} {boolean no_hierarchical} {string module} {string}
}
cli::addCommand rt::write_verilog         {"$rt::db writeVerilog"} {boolean no_hierarchical} {string module} {string}
cli::addCommand rt::write_design          {rt::writeDesign} {string comment} {string}
cli::addCommand rt::write_sdc             {rt::writeSdc} {#boolean includeInternal} {string} {string inst}
cli::addCommand rt::write_partition       {rt::writePartition} {boolean floorplan} {string prefix} 

#
# Misc commands
#
cli::addCommand rt::ask_passphrase        {rt::askPassphrase}
cli::addCommand rt::set_passphrase        {rt::setPassphrase} {string}
cli::addCommand rt::count_route_layer     {$rt::db countRouteLayer}
cli::addCommand rt::create_macro_model    {"$rt::db addProtoType"} {string} {double width} {double height} {boolean soft}
cli::addCommand rt::create_threshold_voltage_group \
                                      {rt::createVthGroup} {string} {string lib_cells} {#string cells}
cli::addCommand rt::delete_design         {rt::delDesign}
cli::addCommand rt::delete_libs           {"$rt::db delLibs"}
cli::addCommand rt::delete_placement      {rt::delPhysical} {boolean all}
cli::addCommand rt::delete_timing         {"[rt::design] deleteTiming"}
cli::addCommand rt::disable_message       {rt::messageDisable} {string} {#?string}
cli::addCommand rt::enable_message        {rt::messageEnable} {string} {#?string}

cli::addCommand rt::run_encrypt           {rt::encrypt} {string} {string}
cli::addCommand rt::run_find              {rt::find} {boolean instance} {boolean net} \
                                             {boolean pin} {boolean lib_cell} {#boolean cell} {boolean module} \
                                             {boolean power_domain} {boolean hierarchical} {string in_module} \
                                             {#boolean obj} {string}
cli::addCommand rt::run_flatten           {rt::flatten} {integer level} {integer count}

cli::addCommand rt::get_macros            {rt::getMacros}
cli::addCommand rt::get_max_route_layer   {$rt::db maxRouteLayer}
cli::addCommand rt::get_via_resistance_value  {$rt::db getViaResistance} { string viaName}
cli::addCommand rt::set_via_resistance_value  {$rt::db setViaResistance} { string viaName} { double resistance}
cli::addCommand rt::get_parameter         {rt::getParam} {string}
cli::addCommand rt::get_target_library    {rt::getTargetLib}
cli::addCommand rt::get_timing            {rt::getTiming} {string mode}  {boolean rise} {boolean fall} {string launch_clock} {string bidir} {string} {string}
cli::addCommand rt::instance_area         {rt::instanceArea} {boolean no_macros}
cli::addCommand rt::instance_leakage      {rt::instanceLeakage} {boolean no_macros}
cli::addCommand rt::percentage_lvt        {rt::percentageLvt}
cli::addCommand rt::message_count         {rt::messageCount} {string} {#?string}
cli::addCommand rt::read_captable         {rt::readCapTable} {string} {boolean atop} {boolean soce} {#double coupling_effect}
cli::addCommand rt::read_cpf              {rt::readCPF} {string}
cli::addCommand rt::remove_threshold_voltage_group {rt::removeVthGroup} {string}
cli::addCommand rt::rename_threshold_voltage_group {rt::renameVthGroup} {string} {string}
cli::addCommand rt::reset_parameter       {rt::resetParameter} {string}
cli::addCommand rt::reset_timing          {[rt::design] resetTiming}
cli::addCommand rt::set_clock_gating_options \
                                      {rt::setClockGatingOptions} {string sequential_cell} {string control_port} \
                                             {string control_point} {boolean observation_point} \
                                             {integer minimum_bitwidth} {integer num_stages}
cli::addCommand rt::set_dont_gate_clock   {rt::setDontGateClock} {string} {?boolean true}
cli::addCommand rt::set_dont_remove       {rt::setDontRemove} {boolean hierarchical} {boolean flat} {string} {?boolean true}
cli::addCommand rt::set_size_only         {rt::setDontRemove} {boolean hierarchical} {boolean flat} {string} {?boolean true}
cli::addCommand rt::set_dont_ungroup      {rt::setDontUngroup} {boolean hierarchical} {boolean flat} {string} {?boolean true}
cli::addCommand rt::set_dont_touch        {rt::setDontTouch} {boolean hierarchical} {boolean flat} {string} {?boolean true}
cli::addCommand rt::set_dont_use          {rt::setDontUse} {#boolean family} {string target_library} {string} {?boolean true}

# old, obsolete
# cli::addCommand rt::set_max_route_layer   {"$rt::db maxRouteLayer"} {integer}
# new..
cli::addCommand rt::set_max_route_layer   {rt::setMaxRouteLayer} {integer}

cli::addCommand rt::set_route_length_limits {"$rt::db setRouteLengthLimit"} {integer short} {integer medium} {integer long}
cli::addCommand rt::get_route_length_limits {"$rt::db dumpRouteLengthLimit"}

cli::addCommand rt::set_parameter         {rt::setParameter} {string} {string}
# now obsolete except when running 'standalone' synthesis
if { ! $rt::runningPA_ } {
    cli::addCommand set_parameter         {rt::setParameter} {string} {string}
}

cli::addCommand rt::set_preserve_boundary {rt::setPreserveBoundary} {boolean hierarchical} \
                                      {boolean up} {boolean down} {string} {?boolean true}
cli::addCommand rt::set_route_layer_max_usage \
                                      {rt::setRoutingUsage} {string} {double}
cli::addCommand rt::set_route_layer_spacing \
                                      {rt::setLayerSpacing} {string} {double}
cli::addCommand rt::set_target_library    {rt::setTargetLib} {string}  {string instances}
cli::addCommand rt::set_timing_mode       {"[rt::design] setTimingMode"} {string}
cli::addCommand rt::set_units_per_micron  {rt::setUnitsPerMicron} {integer}
cli::addCommand rt::source                {rt::sourceFile} {boolean echo} {boolean verbose} {string mode} {string}
if { ! $rt::runningPA_ } {
    cli::addCommand source                {rt::sourceFile} {boolean echo} {boolean verbose} {string mode} {string}
}

cli::addCommand rt::top_module            {rt::topModule} {string set}
cli::addCommand rt::total_negative_slack  {rt::tns}

cli::addCommand rt::run_ungroup           {rt::ungroup} {boolean all} {boolean flatten} \
                                             {integer start_level 0} {integer small 0} {?string}
cli::addCommand rt::run_group             {rt::group} {string design_name} {string instance_name} {string}

cli::addCommand rt::uniquify              {"[rt::design] uniquify"} {boolean all}
cli::addCommand rt::update_congestion     {"[rt::design] congestionEst"} {integer detail -1} 
cli::addCommand rt::worst_slack           {"[rt::design] worstSlack"}
cli::addCommand rt::config_report         {rt::configReport} {string} {string format}
cli::addCommand rt::set_fix_multiple_port_nets \
                                      {rt::setFixMultiPortNets} {boolean feedthroughs} {boolean outputs} {boolean buffer_constants}

cli::addCommand rt::cleanup_inverters     {"[rt::design] cleanupInverters"}
cli::addCommand rt::get_lef_files         {rt::getLefFiles}
cli::addCommand rt::get_lib_files         {rt::getLibFiles}
cli::addCommand rt::get_log_file          {rt::getLogFile}
cli::addCommand rt::get_cmd_file          {rt::getCmdFile}
cli::addCommand rt::config_timing         {rt::configTiming} {string zero_rc_delay}
cli::addCommand rt::start_gui             {uplevel MRealTime_startGui}
cli::addCommand rt::stop_gui              {MRealTime_stopGui}
cli::addCommand rt::get_selection         {MRealTime_getSelection}
cli::addCommand rt::set_selection         {MRealTime_setSelection} {string}
#cli::addCommand rt::exit                  {MRealTime_forceExit} {?string 0}

cli::addCommand rt::run_redirect          {rt::redirect} {boolean append} {string} {string}

cli::addCommand rt::verify                {verify::mainVerify}\
                                      {boolean noclean} {boolean max_hier} {string lib_dir} {string base_dir}\
                                      {string job_cmd} {integer num_lic} {string mach_list}\
                                      {string dir_suffix} {string execute_cache} {boolean write_only}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
