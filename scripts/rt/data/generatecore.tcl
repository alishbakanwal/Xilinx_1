##rt::set_parameter synVerbose 1
#
#namespace eval rt {
#    # leave this here - we need the namespace defined so that
#    # we can push variables into it to hide them from the global namespace.
#    variable core
#    variable file_data
#    variable line
#    variable core_data
#    variable ipf
#}
#proc rt::buildDependencyList {dirSearchPath primaryCores} {
##    puts "Search Path: $dirSearchPath"
#    set currentCores $primaryCores
#    set visited(NULL) 1
#    set flattenedCores {}
#    while {[llength $currentCores] > 0} {
#	set newCores {}
#	foreach rt::core $currentCores {	    
#	    # search for ip though each directory...
#	    set foundCore 0
#	    foreach xilinxDir $dirSearchPath {
#		if {$foundCore == 0} {
#		    set testIpDir $xilinxDir/$rt::core
##		    puts "Test IP Dir: $testIpDir"
#		    if {[file exists $testIpDir]} {
##			puts "Found $rt::core in $testIpDir"
#			if {[info exists visited($rt::core)] == 0} {
#			    set visited($rt::core) 1
#			    lappend flattenedCores $rt::core
#			    # create dependency list...
#			    
#			    if { [rt::get_parameter synVerbose] == 1 } {
#				puts "Reading dependencies for core $rt::core"
#			    }
#			    if {[file exists $testIpDir/$rt::core.dependencies]} {
#				set f [open $testIpDir/$rt::core.dependencies]
#				set rt::file_data [read $f]
#				#puts "Done reading... >$rt::file_data<"
#				set rt::core_data [split $rt::file_data "\n"]
#				#puts "Data: >$rt::core_data<"
#				foreach rt::line $rt::core_data {
#				    if {[string length $rt::line] > 0} {
#					# do some line processing here
#					if { [rt::get_parameter synVerbose] == 1 } {
#					    puts "Adding dependency $rt::line"
#					}
#					
#					lappend newCores $rt::line
#				    }
#				}
#				close $f
#				set foundCore 1
#			    }
#			}
#		    }
#		}
#	    }
#	    if {$foundCore == 0} {
#		if { [rt::get_parameter synVerbose] == 1 } {
#		    puts "WARNING: Could not find dependency information for $rt::core"
#		}
#	    }
#	}
#	set currentCores $newCores
#    }
#    return $flattenedCores
#}
#
#
## Parses analyze_order.txt and reads IP
#proc rt::readIP {dirSearchPath ipname} {
#    # search for ipane though each directory...
#    foreach xilinxDir $dirSearchPath {
#	set testIpDir $xilinxDir/$ipname
##	puts "Testing $testIpDir testIpDir for IP $ipname"
#	if {[file exists $testIpDir]} {
#	    set directory $xilinxDir
#
##	    puts "Reading $directory for IP $ipname"
#	    if {[file exists $directory/$ipname/analyze_order.txt]} {
#		set rt::ipf [open $directory/$ipname/analyze_order.txt]
#		set rt::file_data [read $rt::ipf]
#		#puts "Done reading... >$rt::file_data<"
#		set rt::core_data [split $rt::file_data "\n"]
#		#puts "Data: >$rt::core_data<"
#		foreach rt::line $rt::core_data {
#		    if {[string length $rt::line] > 0} {
#			# do some line processing here
#			#puts "Command: rt::read_vhdl -lib $rt::core $directory/$ipname/$rt::line"
#			rt::read_vhdl -lib $rt::core $directory/$ipname/$rt::line
#		    }
#		}
#		close $rt::ipf
#	    }
#	    return
#	}
#    }
#}
#
#proc rt::buildIPSearchPath {pathStr dir} {
#    #puts "Building search path for ($pathStr, $dir)"
#    set searchPath {}
#
#    # try splitting XILINX into substrings
#    set xilinxDirs [concat [split $pathStr ":"] [split $pathStr ";"]]
#    #puts "Test Dirs: $xilinxDirs"
#
#    foreach xilinxDir $xilinxDirs {
#	set testIpDir $xilinxDir/$dir
#	if {[file exists $testIpDir]} {
#	    lappend searchPath $testIpDir
#	}
#    }
#
#    return $searchPath
#}
#
#proc rt::buildCoregenSearchPath {} {
#    set searchPath {}
#
#    # try splitting XILINX into substrings
#    if {[info exists ::env(RDI_DATADIR)]} {
#	set searchPath [concat $searchPath [buildIPSearchPath $::env(RDI_DATADIR) ip/xilinx]]
#    }
#
#    if {[info exists ::env(XILINX)]} {	
#	set searchPath [concat $searchPath [buildIPSearchPath $::env(XILINX) coregen/ip/xilinx/primary/com/xilinx/ip]]
#    }
#    return $searchPath
#}
#
#
#proc rt::buildPlSearchPath {} {
#    set searchPath {}
#
#    # try splitting XILINX into substrings
#    if {[info exists ::env(RDI_DATADIR)]} {
#	set searchPath [concat $searchPath [buildIPSearchPath $::env(RDI_DATADIR) ip/xilinx]]
#    }
#
#    if {[info exists ::env(XILINX)]} {
#	set searchPath [concat $searchPath [buildIPSearchPath $::env(XILINX) ip/xilinx]]
#    }
#    return $searchPath
#}
#
## Disabling hard coded parameter because -lpm auto set now (CR 699074)
## Force generatecore to true to help support EDK cores in RB4.  Requested from IP group
##rt::set_parameter enableGenerateCore true
#
## Setting used by SPRITE
##if {[info exists ::env(SUITE_NAME)] && $::env(SUITE_NAME) == "EDK"} {
##  rt::set_parameter enableGenerateCore true
##}
#
#
#if {[rt::get_parameter enableGenerateCore] == true} {
#    rt::set_parameter freeMemoryInElaborate 0
#
#
#    # This is problematic and scheduled for replacement, as new versions
#    # of cores or new IP-XACT cores entirely don't show up automatically...
#    if {[info exists primaryCores] == 0} {
#	# List of cores required for EDK Suite
#	# Current list of IP that has the IP-XACT wrapper
#	set primaryCores {
#			      blk_mem_gen_v6_2 
#			      blk_mem_gen_v7_1 
#			      blk_mem_gen_v7_2 
#			      blk_mem_gen_v7_3 
#			      blk_mem_gen_v8_0 
#			      blk_mem_gen_v8_1
#			      fifo_generator_v8_2 
#			      fifo_generator_v9_1 
#			      fifo_generator_v9_2 
#			      fifo_generator_v9_3 
#			      fifo_generator_v10_0 
#			      dist_mem_gen_v6_3 
#			      dist_mem_gen_v6_4 
#			      dist_mem_gen_v7_1 
#			      dist_mem_gen_v7_2 
#			      dist_mem_gen_v8_0 
#			  }
#    }
#
#   if {[info exists primaryPlCores] == 0} {
#       set primaryPlCores {
#	   uw_dist_mem
#	   uw_sync_fifo
#	   uw_async_fifo
#	   pl_sync_fifo
#	   pl_async_fifo
#	   pl_spram
#       }
#   }
#    
#
#    # directory for IP...
#    set rt::COREGEN_IP [rt::buildCoregenSearchPath]
#    set rt::XILINX_IP  [rt::buildPlSearchPath]
#
#    if {[rt::get_parameter synVerbose] == 1} {
#	puts "GenerateCore IP: $rt::COREGEN_IP"
#	puts "PLCore       IP: $rt::XILINX_IP"
#    }
#
#
#    #puts "Using Xilinx IP Search Path: $rt::COREGEN_IP"
#    
#    if { [rt::get_parameter synVerbose] == 1 } {
#	puts "Registering the following generatecore IP:\n$primaryCores"
#	puts "Registering the following plcore IP      :\n$primaryPlCores"
#    }
#    
#    set rt::flattenedCores [rt::buildDependencyList $rt::COREGEN_IP $primaryCores]
#    # only primary cores require the IP-XACT wrapper
#    
#    foreach rt::core $rt::flattenedCores {
#	if { [rt::get_parameter synVerbose] == 1 } {
#	    puts "\# Reading core $rt::core..."
#	}
#	rt::readIP $rt::COREGEN_IP $rt::core
#    }
#    
#    foreach rt::core $primaryPlCores {
#	if { [rt::get_parameter synVerbose] == 1 } {
#	    puts "\# Reading core $rt::core..."
#	}
#        rt::readIP $rt::XILINX_IP $rt::core
#    }
#    # need to unset primaryCores so that we can
#    # call this again and possibly get different behavior.
#    unset primaryCores
#    unset primaryPlCores
#} else {
#    if {[rt::get_parameter synVerbose] == 1} {
#      puts "Xilinx IP preload is disabled"
#    }
#}
#
#if {[info exists ::env(VSS_SYN_PARTITION_FLOW)]} {
#  rt::read_verilog $::env(SYNTH_COMMON)/io_ports_mux_demux.v
#}
#
#set __dw_bbox_location ""
#if { [info exists ::env(DW_INSTALL_PATH)] } {
#  set __dw_bbox_location $::env(DW_INSTALL_PATH) 
#  # Check file existence
#}
#if { [info exists rt::bbox_dw_flow] && [string length $__dw_bbox_location] > 0} {
#  foreach __dw_file [glob $::env(DW_INSTALL_PATH)/dw/*/src_ver/*.v] {
#    rt::read_verilog -include $::env(DW_INSTALL_PATH)/dw/sim_ver $__dw_file
#  }
#}
#
# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
