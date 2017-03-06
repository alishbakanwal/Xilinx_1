package require tcf
package require control
package require fileutil 1.13
package require uuid
package require json

control::control assert enabled 1

if { [string first "xsdb" [file tail [info nameofexecutable]]] != -1 } {
    set tcl_prompt1 {puts -nonewline "xsdb% "}
} else {
    set tcl_prompt1 {puts -nonewline "xsct% "}
    namespace eval xsdb {namespace ensemble create -command ::xsdb}
}

# Add package information to tcfinterp for xsdb specific packages that
# may not be found via auto_path
::tcf::sync_eval [list source [file join [file dirname [info script]] pkgIndex2.tcl]]

::tcf::sync_eval {
    package require control
    control::control assert enabled 1

    package require xsdb::tcfinterp
    package require xsdb::elf
    package require xsdb::bitfile
    package require xsdb::jtag::sequence
    package require xsdb::gprof

    # General purpose cache wait object, not specific to any
    # particular piece of data
    ::tcf::cache_create cache
    variable [namespace current]::xsdb_src_dir
    variable [namespace current]::expr_table [dict create]
    variable [namespace current]::expr_list [dict create]
    proc set_xsdb_src_dir {dir} {
	set srcvar "[namespace current]::xsdb_src_dir"
        set $srcvar $dir
    }

    proc set_arg {arg} {
	set argvar "[namespace current]::arg"
	control::assert {![info exists $argvar]}
	set $argvar $arg
	return $argvar
    }

    proc i2bin {i bits} {
	set l {}
	while { $bits >= 8 } {
	    lappend l [expr $i & 255]
	    set i [expr $i >> 8]
	    incr bits -8
	}
	if { $bits > 0 } {
	    lappend l [expr $i & ((1 << $bits) - 1)]
	}
	return [binary format c* $l]
    }

    proc connect_tcf_callback {url type data} {
	switch $type {
	    error {eval_error $data}
	    connect {
		if { [catch {add_channel $data $url} msg] } {
		    eval_error $msg
		} else {
		    eval_done $data
		}
	    }
	    redirect {
		if { [catch {redirect_channel $data $url} msg] } {
		    eval_error $msg
		} else {
		    eval_done
		}
	    }
	}
    }

    proc connect_tcf {url force} {
        if { !$force && [namespace exists ::channels] } {
	    foreach ns [namespace children ::channels] {
		if { $url == [lindex [set [set ns]::url] 0] } {
		    # use existing connection
		    eval_done [set [set ns]::chan]
		    return
		}
	    }
	}

	::tcf::connect $url [list connect_tcf_callback $url]
    }

    proc connect_redirect_callback {chan url err} {
	if { [string length $err] > 0 } {
	    eval_error $err
	}
	lappend ::channels::[set chan]::url $url
    }

    proc connect_redirect {chan url force} {
        if { !$force && [lsearch -exact [set ::channels::[set chan]::url] $url] >= 0 } {
	    # chan is already redirected to the url
	    eval_done
	    return
	}

	::tcf::redirect $chan $url [list connect_redirect_callback $chan $url]
    }

    proc sdk_command_callback {err} {
	variable sdk_cmd_arg
	set arg $sdk_cmd_arg
	unset sdk_cmd_arg
	if { [string length $err] > 0 } {
	    set data [dict create err $err data {}]
	} elseif { [catch {::tcf::read [dict get $arg chan] [dict get $arg resfmt]} data] } {
	    set err $data
	    set data [dict create err $err data {}]
	}
	if { [string length $err] == 0 } {
	    set data [dict create err {} data $data]
	}
	eval_event [list ::sdk::sdk_command_handler $data]
    }

    proc sdk_command_eval_client {arg} {
	variable sdk_cmd_arg
	if { [info exists sdk_cmd_arg] } {
	    error "sdk command already in progress"
	}
	set chan [dict get $arg chan]
	set service [dict get $arg service]
	set cmd [dict get $arg cmd]
	set argfmt [dict get $arg argfmt]
	set arglist [dict get $arg arglist]
	if { [catch {
	    ::tcf::send_command $chan $service $cmd [list sdk_command_callback]
	    ::tcf::write $chan $argfmt $arglist
	} msg opt] } {
	    puts [list $msg $opt]
	    dict set arg err $msg
	}
	set sdk_cmd_arg $arg
    }

    proc find_reg_by_role {targets parent role} {
	if { ![dict exists $targets $parent] } {
	    return ""
	}

	foreach ctx [dict get $targets $parent children] {
	    if { ![dict exists $targets $ctx] } {
		continue
	    }
	    set reg [dict get $targets $ctx Registers:context]
	    if { [dict exists [lindex $reg 1] Role] &&
		 [dict get [lindex $reg 1] Role] == $role } {
		return $reg
	    }
	    set reg [find_reg_by_role $targets $ctx $role]
	    if { $reg != "" } {
		return $reg
	    }
	}
	return ""
    }

    proc get_elf_sections { elf } {
	set f [::xsdb::elf::open $elf]
	set shl [$f get_shlist]
	$f close
	return $shl
    }

    proc get_elf_exec_sections { elf } {
	set f [::xsdb::elf::open $elf]
	set eshl [$f get_exec_sections]
	$f close
	return $eshl
    }

    proc get_elf_start_address { elf } {
	set f [::xsdb::elf::open $elf]
	set hdr [$f get_hdr]
	$f close
	return [dict get $hdr entry]
    }

    proc verify_data_callback {argvar addr offset size err} {
	upvar $argvar arg
	set ts [clock milliseconds]
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "Bea{o{msg o{} A}}"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    if { ![dict get $arg data] } {
		if { [catch {set fdata [[dict get $arg f] read_at $offset $size]} msg] } {
		    dict set arg err $msg
		}
	    } else {
		if { [catch {set fdata [read [dict get $arg f] $size]} msg] } {
		    dict set arg err $msg
		}
	    }
	    if { [string compare [lindex $data 0] $fdata] != 0 } {
		if { [dict get $arg be] } {
		    set fmt Cu*
		} else {
		    set fmt cu*
		}
		set val_list {}
		binary scan [lindex $data 0] $fmt val_list
		set fval_list {}
		binary scan $fdata $fmt fval_list
		if { [llength $val_list] != [llength $fval_list] } {
		    dict set arg err "elf verify failed at address [format 0x%lx $addr]"
		}
		for {set i 0} {$i < [llength $val_list]} {incr i} {
		    if { [lindex $val_list $i] != [lindex $fval_list $i] } {
			dict set arg err "elf verify failed at address [format 0x%lx [expr $addr + $i]]"
			break
		    }
		}
	    }

	    set current_bytes [expr [dict get $arg current_bytes] + $size]
	    dict set arg current_bytes $current_bytes
	    set progress_delta [expr {$ts - [dict get $arg progress_time]}]
	    set complete [expr {100 * $current_bytes / [dict get $arg total_bytes]}]
	    set remaining_bytes [expr {[dict get $arg total_bytes] - $current_bytes}]
	    if { $progress_delta > 500 || $remaining_bytes == 0 } {
		dict set arg progress_time $ts
		set total_time [expr {$ts - [dict get $arg start_time]}]
		set throughput [expr {$current_bytes / ($total_time / 1000.0)}]
		if { $remaining_bytes == 0 } {
		    set eta [format "%02u:%02u    " [expr {$total_time / 1000 / 60}] [expr {$total_time / 1000 % 60}]]
		} elseif { $total_time > 3000 && $throughput > 0 } {
		    set remaining_time [expr {int($remaining_bytes / $throughput)}]
		    set eta [format "%02u:%02u ETA" [expr {$remaining_time / 60}] [expr {$remaining_time % 60}]]
		} else {
		    set eta [format "??:?? ETA" ]
		}
		if { [catch {eval_progress [list info [format "%3u%% %4uMB %5.1fMB/s  %s" $complete [expr {$current_bytes / 1048576}] [expr {$throughput / 1048576}] $eta]]} msg] } {
		    dict set arg err $msg
		}
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc download_data_callback {argvar size err} {
	upvar $argvar arg
	set ts [clock milliseconds]
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "ea{o{msg o{}}}"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    set current_bytes [expr [dict get $arg current_bytes] + $size]
	    dict set arg current_bytes $current_bytes
	    set progress_delta [expr {$ts - [dict get $arg progress_time]}]
	    set complete [expr {100 * $current_bytes / [dict get $arg total_bytes]}]
	    set remaining_bytes [expr {[dict get $arg total_bytes] - $current_bytes}]
	    if { $progress_delta > 500 || $remaining_bytes == 0 } {
		dict set arg progress_time $ts
		set total_time [expr {$ts - [dict get $arg start_time]}]
		set throughput [expr {$current_bytes / ($total_time / 1000.0)}]
		if { $remaining_bytes == 0 } {
		    set eta [format "%02u:%02u    " [expr {$total_time / 1000 / 60}] [expr {$total_time / 1000 % 60}]]
		} elseif { $total_time > 3000 && $throughput > 0 } {
		    set remaining_time [expr {int($remaining_bytes / $throughput)}]
		    set eta [format "%02u:%02u ETA" [expr {$remaining_time / 60}] [expr {$remaining_time % 60}]]
		} else {
		    set eta [format "??:?? ETA" ]
		}
		if { [catch {eval_progress [list info [format "%3u%% %4uMB %5.1fMB/s  %s" $complete [expr {$current_bytes / 1048576}] [expr {$throughput / 1048576}] $eta]]} msg] } {
		    dict set arg err $msg
		}
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc download_suspend_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {
	    set err [lindex [::tcf::read [dict get $arg chan] "o{}"] 0]
	    if { $err != "" && [dict get $err Format] != "Already stopped" } {
		error [dict get $err Format]
	    }
	} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc download_reg_set_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "e"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc write_pc_cache_client {argvar} {
	upvar $argvar arg
	dict with arg {
	    if { [catch {
		if { $pending == 0 } {
		    set cache_misses [get_context_datatypes targets $chan {} {RunControl:context RunControl:state} $ctx 1]
		    incr cache_misses [get_context_datatypes targets $chan {Registers:children} {Registers:context} $ctx 2]
		    if { $cache_misses > 0 } {
			error $::cache_miss_err
		    }

		    set pcreg [lindex [find_reg_by_role $targets $ctx PC] 1]
		    if { $pcreg == "" } {
			error "cannot update program counter"
		    }
		    set regid [dict get $pcreg ID]
		    set size [dict get $pcreg Size]
		    set regval ""
		    if { [dict exists $pcreg BigEndian] &&
			 [dict get $pcreg BigEndian] != 0 } {
			if { $size == 4 } {
			    set regval [binary format I $addr]
			} elseif { $size == 8 } {
			    set regval [binary format W $addr]
			}
		    } else {
			if { $size == 4 } {
			    set regval [binary format i $addr]
			} elseif { $size == 8 } {
			    set regval [binary format w $addr]
			}
		    }

		    if { $regval != "" } {
			::tcf::send_command $chan Registers set [list download_reg_set_callback $argvar]
			::tcf::write $chan "sB" [list $regid $regval]
			incr numreq
			set pending 1
		    } else {
			error "unsupported PC register size: $size"
		    }
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    if { $numreq > 0 } {
		cache wait
	    }

	    ::tcf::cache_exit
	    set errstr $err
	}

	unset $argvar
	if { $errstr != "" } {
	    error $errstr
	}
    }

    proc download_cache_client {argvar} {
	upvar $argvar arg
	dict with arg {
	    if { [catch {
		while { $err == "" && $numreq < 16 && $curaction < [llength $actions] } {
		    switch -- [lindex $actions $curaction 0] {
			"init" {
			    if { $curpos == 0 } {
				incr curpos
			    }
			    set cache_misses [get_context_datatypes targets $chan {} {RunControl:context RunControl:state} $ctx 1]
			    if { ${set-entry} } {
				incr cache_misses [get_context_datatypes targets $chan {Registers:children} {Registers:context} $ctx 2]
			    }
			    if { $cache_misses > 0 } {
				error $::cache_miss_err
			    }

			    set rc [dict get $targets $ctx RunControl:context]
			    if { ${auto-stop} } {
				set state [dict get $targets $ctx RunControl:state]
				if { [lindex $state 0] != "" } {
				    error [lindex $state 0]
				}
				if { ![lindex $state 1] } {
				    ::tcf::send_command $chan RunControl suspend [list download_suspend_callback $argvar]
				    ::tcf::write $chan "s" [list $ctx]
				    incr numreq
				    cache wait
				}
			    }

			    if { ${set-entry} } {
				set pcreg [lindex [find_reg_by_role $targets $ctx PC] 1]
				dict set arg pcreg $pcreg
				if { $pcreg == "" } {
				    error "cannot find program counter register"
				}
			    }

			    if { [dict exists $rc ProcessID] } {
				set memctx [dict get $rc ProcessID]
			    } else {
				set memctx $ctx
			    }
			    dict set arg memctx $memctx

			    incr curaction
			    set curpos 0
			}

			"open" {
			    set total_bytes 0
			    set shl {}
			    if { !$data } {
				# Open ELF file
				set f [::xsdb::elf::open $file]
				dict set arg f $f
				set sh_info "Downloading Program -- $file\n"
				set shl [$f get_shlist]
				foreach sh $shl {
				    if { [expr {[dict get $sh flags] & 0x7}] } {
					set saddr [dict get $sh addr]
					set ssize [dict get $sh size]
					append sh_info "\tsection, [dict get $sh name]: [format 0x%08x $saddr] - [format 0x%08x [expr {$saddr + $ssize - 1}]]\n"
				    }
				}
				eval_progress [list info $sh_info]

				foreach ph [$f get_phlist] {
				    dict with ph {
					if { $type == 1 } {
					    if { $filesz > 0 } {
						lappend actions [list copy $offset $paddr $filesz]
						incr total_bytes $filesz
					    }
					    if { $clear && $filesz < $memsz } {
						set clearsz [expr $memsz - $filesz]
						lappend actions [list clear [expr $paddr + $filesz] $clearsz]
						incr total_bytes $clearsz
					    }
					}
				    }
				}

				# If profiling is already configured, then only profile action is added
				if { [dict exists $profile_config scratchaddr] && [dict exists $profile_config sampfreq] } {
				    if { [::xsdb::gprof::is_elf_prof_enabled $f] } {
					lappend actions [list profile $file]
				    }
				}

				if { ${set-entry} } {
				    set hdr [$f get_hdr]
				    lappend actions [list setpc [dict get $hdr entry]]
				}
			    } else {
				# Open data file
				set f [::open $file rb]
				dict set arg f $f
				seek $f 0 end
				lappend actions [list copy 0 $address [tell $f]]
				incr total_bytes [tell $f]
				seek $f 0
			    }
			    dict set arg sh_list $shl
			    incr curaction
			    set curpos 0
			}

			"progress" {
			    if { $numreq > 0 } {
				cache wait
			    }
			    set ts [clock milliseconds]
			    dict set arg start_time $ts
			    dict set arg progress_time $ts
			    if { [catch {eval_progress [list info [format "%3u%% %4uMB %5.1fMB/s  %s" 0 0 0 "??:?? ETA"]]} msg] } {
				dict set arg err $msg
				break
			    }
			    incr curaction
			}

			"copy" {
			    set offset [expr [lindex $actions $curaction 1] + $curpos]
			    set addr [expr [lindex $actions $curaction 2] + $curpos]
			    set endpos [lindex $actions $curaction 3]
			    set size $chunksize
			    if { $endpos != "" && $size > $endpos - $curpos } {
				set size [expr $endpos - $curpos]
			    }

			    if { !$data } {
				set bindata [$f read_at $offset $size]
			    } else {
				set bindata [read $f $size]
			    }


			    if { [string length $bindata] < $size } {
				set size [string length $bindata]
				if { $size == 0 } {
				    if { $endpos != "" } {
					set err "unexpected end of file"
				    }
				    incr curaction
				    set curpos 0
				    continue
				}
			    }
			    set mode 3
			    if { $force } {
				set mode [expr $mode | 4]
			    }
			    ::tcf::send_command $chan Memory set [list download_data_callback $argvar $size]
			    ::tcf::write $chan "siiiiB" [list $memctx $addr 1 $size $mode $bindata]
			    incr numreq
			    incr curpos $size
			    if { $curpos == $endpos } {
				incr curaction
				set curpos 0
			    }
			}

			"clear" {
			    set addr [expr [lindex $actions $curaction 1] + $curpos]
			    set size [expr [lindex $actions $curaction 2] - $curpos]
			    if { $size == 0 } {
				incr curaction
				set curpos 0
			    }
			    if { $size > $chunksize } {
				set size $chunksize
			    }

			    ::tcf::send_command $chan Memory fill [list download_data_callback $argvar $size]
			    ::tcf::write $chan "siiiia{i}" [list $memctx $addr 1 $size 0 { 0 }]
			    incr numreq
			    incr curpos $size
			}

			"profile" {
			    set elffile [lindex $actions $curaction 1]
			    set big_endian 0
			    set fmt i*
			    set size 4

			    if { [dict exists $pcreg BigEndian] && [dict get $pcreg BigEndian] != 0 } {
				set big_endian 1
				set fmt I*
			    }

			    set cputype [dict get [lindex $rc 1] CPUType]
			    if { $cputype == "ARM"} {
				set cputype [dict get [lindex $rc 1] ARMType]
			    }

			    set gmonparamsize [dict get [::xsdb::gprof::get_gmonparam_offsets] GPARAM_SIZE]

			    ::xsdb::gprof::set_profile_elf $elffile
			    ::xsdb::gprof::set_prof_endianness $big_endian

			    # Check if profile version is proper
			    if { [::xsdb::gprof::get_prof_version] != 1} {
				error "Profile version not supported"
			    }

			    # Get the addresses & cpu freq from elf
			    set profaddr [::xsdb::gprof::get_prof_addresses]
			    set cpufreq [::xsdb::gprof::get_prof_cpufreq]

			    # Extract & sort sections
			    set execsecs [::xsdb::gprof::get_sorted_exec_sections]
			    set ngsecs [::xsdb::gprof::get_no_of_gmon_sections]

			    set scratchaddr [dict get $profile_config scratchaddr]
			    set pmemstartaddr $scratchaddr
			    set pmemstartaddr [expr $pmemstartaddr + [expr $ngsecs * $gmonparamsize]]

			    for {set i 0} {$i < $ngsecs} {incr i} {
				set secdict [lindex $execsecs $i]
				set secdict [::xsdb::gprof::get_prof_cg_hist_details $secdict $cputype]
				# Starting address of profiling data
				set baseaddr [expr $scratchaddr + [expr $i * $gmonparamsize]]

				set bindata [binary format $fmt 0]
				# Hist Address (GPARAM_HIST_O 4)
				append bindata [binary format $fmt $pmemstartaddr]
				# Hist Size (GPARAM_HISTSIZE_O 8)
				append bindata [binary format $fmt [dict get $secdict histcount]]
				# CG From (GPARAM_CG_FROM_O 12)
				append bindata [binary format $fmt [expr $pmemstartaddr + [dict get $secdict histsize]]]
				# CG From Size (GPARAM_CG_FROMSIZE_O 16)
				append bindata [binary format $fmt 0]
				# CG To (GPARAM_CG_TO_O 20)
				append bindata [binary format $fmt [expr $pmemstartaddr + [dict get $secdict histsize] + [dict get $secdict cgsize]]]
				# CG To Size (GPARAM_CG_TOSIZE_O 24)
				append bindata [binary format $fmt 0]
				# Low PC (GPARAM_LOWPC_O 28)
				append bindata [binary format $fmt [dict get $secdict lowpc]]
				# High PC (GPARAM_HIGHPC_O 32)
				append bindata [binary format $fmt [dict get $secdict highpc]]
				# Text Size (GPARAM_TEXTSIZE_O 36)
				append bindata [binary format $fmt [expr [dict get $secdict highpc] - [dict get $secdict lowpc]]]

				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $baseaddr $size $gmonparamsize 3 $bindata]
				incr numreq

				# Update pmem start addr to end addr of scratch mem
				set pmemstartaddr [expr $pmemstartaddr + [dict get $secdict histsize] + [dict get $secdict cgsize]]

				# Initialize profile memory
				set tmemsize [expr $pmemstartaddr - $scratchaddr + [expr $ngsecs * $gmonparamsize]]
				set bindata ""
				for {set j 0} {$j < $tmemsize} {incr j} {
				    append bindata [binary format c* 0]
				}
				set tempaddr [expr $scratchaddr + [expr $ngsecs * $gmonparamsize]]
				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $tempaddr 1 $tmemsize 3 $bindata]
				incr numreq

				# Initialize the variables
				# No. of gmon sections
				set tempaddr [dict get $profaddr ngmonsecs]
				set bindata [binary format $fmt $ngsecs]
				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $tempaddr $size $size 3 $bindata]
				incr numreq

				# gmonparams address location
				set tempaddr [dict get $profaddr gmonparam]
				set bindata [binary format $fmt $scratchaddr]
				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $tempaddr $size $size 3 $bindata]
				incr numreq

				# Sample freq
				set tempaddr [dict get $profaddr sampfreq]
				set bindata [binary format $fmt [dict get $profile_config sampfreq]]
				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $tempaddr $size $size 3 $bindata]
				incr numreq

				# Bin Size
				set tempaddr [dict get $profaddr binsize]
				set bindata [binary format $fmt 4]
				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $tempaddr $size $size 3 $bindata]
				incr numreq

				# Timer ticks
				set tempaddr [dict get $profaddr timerticks]
				set bindata [binary format $fmt [expr $cpufreq / [dict get $profile_config sampfreq]]]
				::tcf::send_command $chan Memory set [list gprof_data_callback $argvar $size]
				::tcf::write $chan "siiiiB" [list $memctx $tempaddr $size $size 3 $bindata]
				incr numreq

				# Enable the profiling
				::xsdb::gprof::enable_profiling
			    }
			    incr curaction
			}

			"setpc" {
			    if { $numreq > 0 } break
			    set regid [dict get $pcreg ID]
			    set size [dict get $pcreg Size]
			    set addr [lindex $actions $curaction 1]
			    set regval ""
			    if { [dict exists $pcreg BigEndian] &&
				 [dict get $pcreg BigEndian] != 0 } {
				if { $size == 4 } {
				    set regval [binary format I $addr]
				} elseif { $size == 8 } {
				    set regval [binary format W $addr]
				}
			    } else {
				if { $size == 4 } {
				    set regval [binary format i $addr]
				} elseif { $size == 8 } {
				    set regval [binary format w $addr]
				}
			    }

			    if { $regval != "" } {
				eval_progress [list info "\nSetting PC to Program Start Address [format 0x%08x $addr]"]
				::tcf::send_command $chan Registers set [list download_reg_set_callback $argvar]
				::tcf::write $chan "sB" [list $regid $regval]
				incr numreq
			    } else {
				eval_progress [list warning "unsupported PC register size: $size"]
			    }
			    incr curaction
			}
		    }
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    if { $numreq > 0 } {
		if { $err != "" } {
		    catch {eval_progress [list info "aborting, $numreq pending requests... "]}
		}
		cache wait
	    }

	    ::tcf::cache_exit

	    if { $err != "" } {
		catch {eval_progress [list done "Failed to download $file"]}
	    } else {
		catch {eval_progress [list done "Successfully downloaded $file"]}
	    }

	    if { [dict exists $arg sh_list] } {
		set shl $sh_list
	    } else {
		set shl {}
	    }
	    if { [dict exists $arg f] } {
		if { !$data } {
		    $f close
		} else {
		    close $f
		}
		dict unset arg f
	    }
	    set errstr $err
	}
	unset $argvar
	if { $errstr != "" } {
	    error $errstr
	}
	return $shl
    }

    proc gprof_data_callback {argvar size err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "ea{o{msg o{} A}}"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc gprof_read_data_callback {argvar secidx param fmt err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "Bea{o{msg o{} A}}"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    if { $fmt != "" } {
		binary scan [lindex $data 0] $fmt data
	    } else {
		set data [lindex $data 0]
	    }
	    if { $secidx != "" } {
		dict set arg profdata sec$secidx $param $data
	    } else {
		dict set arg profdata $param $data
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc reg_read_callback {argvar ctx err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "o{}B"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    dict set arg regs $ctx Registers:value $data
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc register_read_cache_client {argvar} {
	upvar $argvar arg
	dict with arg {
	    if { [catch {
		while { $err == "" && $numreq < 256 && $curaction < [llength $actions] } {
		    switch -- [lindex $actions $curaction 0] {
			"meta" {
			    set cache_misses 0
			    if { ![catch {
				foreach name [dict get $flags regpath] {
				    incr cache_misses [get_context_datatypes regs $chan {Registers:children} {Registers:context} $parent 2]
				    foreach ctx [dict get $regs $parent children] {
					set reg [dict get $regs $ctx Registers:context]
					if { [dict get [lindex $reg 1] Name] == $name } {
					    set parent $ctx
					    break
					}
				    }
				}
			    }]} {
				incr cache_misses [get_context_datatypes regs $chan {Registers:children} {Registers:context} $parent 2]
			    }
			    if { $cache_misses > 0 } {
				error $::cache_miss_err
			    }

			    set parent $orig_ctx
			    foreach name [dict get $flags regpath] {
				set match 0
				if { [dict exists $regs $parent children] } {
				    foreach ctx [dict get $regs $parent children] {
					if { [dict exists $regs $ctx Registers:context] } {
					    set reg [dict get $regs $ctx Registers:context]
					    if { [dict exists [lindex $reg 1] Name] &&
						 [dict get [lindex $reg 1] Name] == $name } {
						set parent $ctx
						set match 1
						break
					    }
					}
				    }
				}
				if { !$match } {
				    error "no register match: $name"
				}
			    }

			    incr curaction
			    set curpos 0
			}

			"data" {
			    if { [dict get $flags defs] } {
				incr curaction
				continue
			    }

			    set ctxs {}
			    if { [dict exists $regs $parent children] } {
			        set ctxs [dict get $regs $parent children]
			    }
			    if { $parent != "" } {
				while { [dict exists [lindex [dict get $regs $parent Registers:context] 1] Bits] } {
				    set parent [dict get [lindex [dict get $regs $parent Registers:context] 1] ParentID]
				}
				if { $parent != "" } { set ctxs [linsert $ctxs 0 $parent] }
			    }
			    set numregs [llength $ctxs]
			    while { $curpos < $numregs && $numreq < 256 } {
				set ctx [lindex $ctxs $curpos]
				set reg [lindex [dict get $regs $ctx Registers:context] 1]
				incr curpos
				if { ![dict exists $reg Readable] || ![dict get $reg Readable] || [dict exists $reg Bits] } {
				    continue
				}
				::tcf::send_command $chan Registers get [list reg_read_callback $argvar $ctx]
				::tcf::write $chan "s" [list [dict get $reg ID]]
				incr numreq
			    }
			    if { $curpos == $numregs } {
				incr curaction
				set curpos 0
			    }
			}
		    }
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    if { $numreq > 0 } {
		cache wait
	    }

	    ::tcf::cache_exit

	    set errstr $err
	}

	set regs [dict get $arg regs]
	dict set regs ctx_match $parent
	unset $argvar
	if { $errstr != "" } {
	    error $errstr
	}
	return $regs
    }

    proc config_init_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "eA"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    set init_status [lindex $data 1]
	    dict set arg init_status $init_status
	    if { $init_status != 1 } {
		dict set arg err "fpga initialization failed"
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc config_shift_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "ei"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    set done_status [lindex $data 1]
	    dict set arg done_status $done_status
	    if { $done_status != 1 } {
		dict set arg err "fpga configuration failed"
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpga_config_progress {argvar} {
	upvar $argvar arg
	if { ![catch {::tcf::read [dict get $arg chan] "ei"} data] } {
	    if { [catch {eval_progress [list percent [lindex $data 1]]}] } {
		# TODO: generate cancel command
	    }
	}
    }

    proc fpga_config_cache_client {argvar} {
	upvar $argvar arg
	dict with arg {
	    control::assert {[dict get $arg numreq] == 0}
	    if { [catch {
		if { $err == "" } {
		    if { ![dict exists $arg f] } {
			set f [::open $file rb]
			dict set arg f $f
			seek $f 0 end
			set size [tell $f]
			dict set arg size $size
			seek $f 0
		    }

		    if { ![dict exists $arg node] } {
			set cache_misses [get_context_datatypes targets $chan {RunControl:children Memory:children} {RunControl:context Memory:context} "" -1]
			incr cache_misses [get_context_datatypes nodes $chan {Jtag:children} {Jtag:context} "" -1]
			if { $cache_misses > 0 } {
			    error $::cache_miss_err
			}

			set rc [dict get $targets $ctx RunControl:context]
			set jtaggroup [dict get [lindex $rc 1] JtagGroup]
			set rc [dict get $targets $jtaggroup RunControl:context]
			set node [dict get [lindex $rc 1] JtagNodeID]
			dict set arg node $node
		    }

		    if { !$partial && ![dict exists $arg init_status] } {
			eval_progress [list info "initializing"]
			::tcf::send_command $chan Xicom_v1.00 config_init [list config_init_callback $argvar]
			::tcf::write $chan "s" [list $node]
			incr numreq
			cache wait
		    }

		    if { ![dict exists $arg done_status] } {
			::tcf::send_command -progress [list fpga_config_progress $argvar] $chan Xicom_v1.00 config_shift [list config_shift_callback $argvar]
			::tcf::write $chan "siiB" [list $node 0 $size [read $f $size]]
			incr numreq
			cache wait
		    }
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    ::tcf::cache_exit

	    catch {eval_progress [list done]}

	    if { [dict exists $arg f] } {
		close $f
		dict unset arg f
	    }
	    set errstr $err
	}
	unset $argvar
	if { $errstr != "" } {
	    error $errstr
	}
    }

    proc fpgatest_dev_prop_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "eo{}"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} elseif { [catch {
	    set devprop [lindex $data 1]
	    dict set arg devprop $devprop
	    if { ![dict exists $arg jprogram] } {
		dict set arg jprogram [dict get $devprop reg.jprogram]
	    }
	    if { ![dict exists $arg jstart] } {
		dict set arg jstart [dict get $devprop reg.jstart]
	    }
	    if { ![dict exists $arg noop] } {
		dict set arg noop [dict get $devprop reg.isc_noop]
	    }
	    if { ![dict exists $arg slr_count] } {
		dict set arg slr_count [dict get $devprop reg.slr_count]
	    }
	    if { ![dict exists $arg jconfig] } {
		set jconfig {}
		set count [dict get $arg slr_count]
		for {set index 0} {$index < $count} {incr index} {
		    lappend jconfig [dict get $devprop reg.cfg_in_slr$index]
		}
		dict set arg jconfig $jconfig
	    }
	    if { ![dict exists $arg slr_index] } {
		dict set arg slr_index ""
	    }
	} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err "device properties error: $data"
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpgatest_init_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "eB"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    binary scan [lindex $data 1] b[dict get $arg irlen] status
	    if { [string range $status end-1 end-1] != 1 && [dict get $arg err] == "" } {
		dict set arg err "fpga initialization failed, status [string reverse $status]"
	    } elseif { [dict get $arg err] == "" &&
		       [catch {eval_progress [list data [dict get $arg current_bytes] [dict get $arg total_bytes]]} msg] } {
		dict set arg err $msg
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpgatest_data_callback {argvar size err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "eB"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    dict incr arg current_bytes $size
	    if { [dict get $arg err] == "" &&
		 [catch {eval_progress [list data [dict get $arg current_bytes] [dict get $arg total_bytes]]} msg] } {
		dict set arg err $msg
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpgatest_status_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "eB"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    binary scan [lindex $data 1] b[dict get $arg irlen] status
	    if { [string range $status end end] != 1 && [dict get $arg err] == "" } {
		dict set arg err "fpga configuration failed, status [string reverse $status]"
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpgatest_lock_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "e"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    dict set arg has_lock 1
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpgatest_unlock_callback {argvar err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "e"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    dict set arg has_lock 0
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc fpgatest_config_cache_client {argvar} {
	upvar $argvar arg
	dict with arg {
	    if { [catch {
		while { $err == "" && $numreq < $maxreq && $curaction < [llength $actions] } {
		    switch -- [lindex $actions $curaction 0] {
			"init" {
			    set cache_misses [get_context_datatypes targets $chan {RunControl:children Memory:children} {RunControl:context Memory:context} "" -1]
			    incr cache_misses [get_context_datatypes nodes $chan {Jtag:children} {Jtag:context} "" -1]
			    if { $cache_misses > 0 } {
				error $::cache_miss_err
			    }

			    set rc [dict get $targets $ctx RunControl:context]
			    set jtaggroup [dict get [lindex $rc 1] JtagGroup]
			    set rc [dict get $targets $jtaggroup RunControl:context]
			    set node [dict get [lindex $rc 1] JtagNodeID]
			    dict set arg node $node

			    set nc [dict get $nodes $node Jtag:context]
			    set irlen [dict get [lindex $nc 1] irLen]
			    dict set arg irlen $irlen
			    incr curaction

			    ::tcf::send_command $chan JtagDevice getProperties [list fpgatest_dev_prop_callback $argvar]
			    ::tcf::write $chan "i" [list [dict get [lindex $nc 1] idCode]]
			    incr numreq
			    cache wait
			}

			"open" {
			    set f [::xsdb::bitfile::open $file]
			    dict set arg f $f
			    set total_bytes [::file size $file]
			    incr curaction
			}

			"lock" {
			    incr curaction
			    ::tcf::send_command $chan Jtag lock [list fpgatest_lock_callback $argvar]
			    ::tcf::write $chan "s" [list $node]
			    incr numreq
			    cache wait
			}

			"fpga_init" {
			    eval_progress [list info "initializing"]
			    set seq [::xsdb::jtag::sequence::create]
			    ::xsdb::jtag::sequence::state seq RESET 0
			    ::xsdb::jtag::sequence::shift seq 1 0 $irlen {state IDLE} [i2bin $jprogram $irlen]
			    ::xsdb::jtag::sequence::shift seq 1 0 $irlen {state IDLE} [i2bin $noop $irlen]
			    #::xsdb::jtag::sequence::state seq RESET 5
			    ::xsdb::jtag::sequence::state seq IDLE 100000
			    ::xsdb::jtag::sequence::shift seq 1 1 $irlen {state IDLE} [i2bin $noop $irlen]
			    incr curaction

			    foreach {fmt cmds data} [::xsdb::jtag::sequence::fmt_cmds_data seq] break
			    ::tcf::send_command $chan Jtag sequence [list fpgatest_init_callback $argvar]
			    ::tcf::write $chan $fmt [list $node {} $cmds $data]
			    incr numreq
			    cache wait
			}

			"fpga_config" {
			    foreach {type prop bindata} [::xsdb::bitfile::read $f $chunksize] break
			    set len [string length $bindata]
			    if { $type != "bitstream" } {
				if { $type == "eof" } {
				    incr curaction
				} else {
				    incr current_bytes $len
				}
				continue
			    }
			    if { $len == 0 } {
				continue
			    }
			    set seq [::xsdb::jtag::sequence::create]
			    if { $slr_index != [dict get $prop slr] } {
				set slr_index [dict get $prop slr]
				if { $slr_index >= [llength $jconfig] } {
				    dict set arg err "bitfile does not match FPGA, slr_index $slr_index jconfig registers $jconfig"
				    continue
				}
				::xsdb::jtag::sequence::shift seq 1 0 $irlen {state IDLE} [i2bin [lindex $jconfig $slr_index] $irlen]
			    }
			    ::xsdb::jtag::sequence::shift seq 0 0 [expr $len * 8] {state DRPAUSE bitswap 1} $bindata

			    foreach {fmt cmds data} [::xsdb::jtag::sequence::fmt_cmds_data seq] break
			    ::tcf::send_command $chan Jtag sequence [list fpgatest_data_callback $argvar $len]
			    ::tcf::write $chan $fmt [list $node {} $cmds $data]
			    incr numreq
			}

			"fpga_status" {
			    set seq [::xsdb::jtag::sequence::create]
			    ::xsdb::jtag::sequence::state seq IDLE 100000
			    ::xsdb::jtag::sequence::shift seq 1 0 $irlen {state IDLE} [i2bin $jstart $irlen]
			    ::xsdb::jtag::sequence::state seq IDLE 20000
			    ::xsdb::jtag::sequence::state seq RESET 0
			    ::xsdb::jtag::sequence::shift seq 1 1 $irlen {state IDLE value 1}
			    incr curaction

			    foreach {fmt cmds data} [::xsdb::jtag::sequence::fmt_cmds_data seq] break
			    ::tcf::send_command $chan Jtag sequence [list fpgatest_status_callback $argvar]
			    ::tcf::write $chan $fmt [list $node {detect 1} $cmds $data]
			    incr numreq
			    cache wait
			}
		    }
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    if { $numreq > 0 } {
		if { $err != "" } {
		    catch {eval_progress [list info "aborting, $numreq pending requests... "]}
		}
		cache wait
	    }

	    if { $has_lock && [catch {
		::tcf::send_command $chan Jtag unlock [list fpgatest_unlock_callback $argvar]
		::tcf::write $chan "s" [list $node]
		incr numreq
		cache wait
	    } msg opt] && $err == "" } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		set err $msg
	    }

	    ::tcf::cache_exit

	    if { $err == "" } {
		catch {eval_progress [list data $current_bytes $total_bytes]}
	    }
	    catch {eval_progress [list done]}

	    if { [dict exists $arg f] } {
		catch {::xsdb::bitfile::close $f}
		dict unset arg f
	    }
	    set errstr $err
	}
	unset $argvar
	if { $errstr != "" } {
	    error $errstr
	}
    }

    proc update_expr_list { exprs } {
	global [namespace current]::expr_list
	set expr_list $exprs
    }

    proc get_expr_ids {chan ctx name scope} {
	global [namespace current]::expr_table

	if { ![dict exists $expr_table $chan $ctx] } return
	set ids {}
	set exprs [dict get $expr_table $chan $ctx]
	dict for {id expr_data} $exprs {
	    if { $scope == "all" } {
		lappend ids [dict get [lindex [dict get $expr_data data] 1] ID]
		dict unset expr_table $chan $ctx $id
	    } elseif { [dict get $expr_data scope] == $scope } {
		if { $name == "" || [dict get $expr_data root] == $name } {
		    lappend ids [dict get [lindex [dict get $expr_data data] 1] ID]
		    dict unset expr_table $chan $ctx $id
		}
	    }
	}
	return $ids
    }

    proc expr_dispose_cache_client {argvar} {
	upvar $argvar expr_arg
	dict with expr_arg {
	    if { [catch {
		while { $curpos < [llength $ids] && $numreq < $maxreq } {
		    set id [lindex $ids $curpos]
		    incr curpos
		    ::tcf::send_command $chan Expressions dispose [list apply [list {argvar err} {
			upvar $argvar expr_arg
			if { [string length $err] > 0 } {
			    if { [dict get $expr_arg err] == "" } {
				dict set expr_arg err $err
			    }
			} elseif { [catch {::tcf::read [dict get $expr_arg chan] e} data] } {
			    if { [dict get $expr_arg err] == "" } {
				dict set expr_arg err $data
			    }
			}
			control::assert {[dict get $expr_arg numreq] > 0}
			dict incr expr_arg numreq -1
			cache notify
		    } [namespace current]] $argvar]
		    ::tcf::write $chan s [list $id]
		    incr numreq
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    if { $numreq > 0 } {
		if { $err != "" } {
		    catch {eval_progress [list info "aborting, $numreq pending requests... "]}
		}
		cache wait
	    }

	    ::tcf::cache_exit

	    set errstr $err
	}
	unset expr_arg
	if { $errstr != "" } {
	    error $errstr
	}
    }

    proc expr_eval_callback {argvar e err} {
	upvar $argvar arg

	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] "BeA"} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    dict set arg expr_data $e Value $data
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc expr_create_callback {chan ctx id err} {
	global [namespace current]::expr_table

	if { $err != "" } {
	    set data [list $err]
	} elseif { [catch {::tcf::read $chan "eA"} data] } {
	    if { $data == "" } {
		set data "unknown read error"
	    }
	    set data [list $data]
	}

	dict set expr_table $chan $ctx $id data $data

	control::assert {[dict exists $expr_table $chan $ctx $id pending]}
	dict unset expr_table $chan $ctx $id pending
	cache notify
    }

    proc expr_create {chan ctx id} {
	global [namespace current]::expr_table

	if { ![dict exists $expr_table $chan $ctx $id pending] } {
	    ::tcf::send_command $chan Expressions create [list expr_create_callback $chan $ctx $id]
	    ::tcf::write $chan sss [list $ctx "" $id]
	    dict set expr_table $chan $ctx $id pending 1
	}
	if { [dict get $expr_table $chan $ctx $id pending] } {
	    cache wait
	}
    }

    proc get_expression_cache_client { argvar data id {root ""} {parent ""} {sctx ""} {level 0} } {
	upvar $argvar arg
	upvar $data exprs
	global [namespace current]::expr_table

	dict with arg {
	    if { ![dict exists $expr_table $chan $ctx $id data] } {
		expr_create $chan $ctx $id
	    }
	    set e [dict get $expr_table $chan $ctx $id data]
	    if { [lindex $e 0] != "" } {
		dict unset expr_table $chan $ctx $id
		dict set exprs $id [dict create err [lindex $e 0]  level $level]
		return
	    }
	    if { $root == "" } { set root $id }
	    dict set expr_table $chan $ctx $id root $root
	    if { [lsearch $expr_list $root] != -1 } {dict set expr_table $chan $ctx $id scope "auto_expr"
	    } else { dict set expr_table $chan $ctx $id scope "local" }
	    set e [dict get [lindex $e 1] ID]

	    set ec [lindex [get_ctx_data $chan $e Expressions:context] 1]
	    if { ![dict exists $ec Type] } {
		dict set exprs $id [dict create Context $ec Type {} Symbol {} Parent $parent level $level]
		return
	    }
	    set sc ""
	    if { [dict exists $ec SymbolID] } {
		set sc [lindex [get_ctx_data $chan [dict get $ec SymbolID] Symbols:context] 1]
	    } else {
		set sc $sctx
	    }
	    set tc [lindex [get_ctx_data $chan [dict get $ec Type] Symbols:context] 1]
	    set tid ""
	    if { [dict exists $tc TypeID] } {
		set tid [lindex [get_ctx_data $chan [dict get $tc TypeID] Symbols:context] 1]
	    }
	    dict set exprs $id [dict create Context $ec Type $tc TypeID $tid Symbol $sc Parent $parent level $level]
	    if { [dict get $tc TypeClass] == 4 || [dict get $tc TypeClass] == 5 } {
		set btc [lindex [get_ctx_data $chan [dict get $tc BaseTypeID] Symbols:context] 1]
		dict set exprs $id BaseType $btc
		if { [dict exists $btc BaseTypeID] } {
		    set btid [lindex [get_ctx_data $chan [dict get $btc BaseTypeID] Symbols:context] 1]
		    dict set exprs $id BaseTypeID $btid
		}
	    } elseif { [dict get $tc TypeClass] == 6 } {
		set ch [lindex [get_ctx_data $chan [dict get $ec Type] Symbols:children] 1]
		set cids {}
		foreach c $ch {
		    lappend cids "$id.\${$c}"
		}
		dict set exprs $id Children $cids
		foreach c $ch {
		    set csc [lindex [get_ctx_data $chan $c Symbols:context] 1]
		    get_expression_cache_client $argvar exprs "$id.\${$c}" $root $id $csc [expr {$level+1}]
		}
	    }
	}
    }

    proc get_variable_cache_client { argvar data e {parent ""} {sctx ""} {level 0} } {
	upvar $argvar arg
	upvar $data exprs
	global [namespace current]::expr_table

	dict with arg {
	    set ec [lindex [get_ctx_data $chan $e Expressions:context] 1]
	    if { [dict exists $ec SymbolID] } {
		set sc [lindex [get_ctx_data $chan [dict get $ec SymbolID] Symbols:context] 1]
	    } else {
		set sc $sctx
	    }
	    set tc [lindex [get_ctx_data $chan [dict get $ec Type] Symbols:context] 1]
	    set tid ""
	    if { [dict exists $tc TypeID] } {
		set tid [lindex [get_ctx_data $chan [dict get $tc TypeID] Symbols:context] 1]
	    }
	    dict set exprs $e [dict create Context $ec Type $tc TypeID $tid Symbol $sc Parent $parent Children {} level $level]
	    if { [dict get $tc TypeClass] == 5 } {
		set btc [lindex [get_ctx_data $chan [dict get $tc BaseTypeID] Symbols:context] 1]
		dict set exprs $e BaseType $btc
		if { [dict exists $btc BaseTypeID] } {
		    set btid [lindex [get_ctx_data $chan [dict get $btc BaseTypeID] Symbols:context] 1]
		    dict set exprs $id BaseTypeID $btid
		}
	    } elseif { [dict get $tc TypeClass] == 6 } {
		set ch [lindex [get_ctx_data $chan [dict get $ec Type] Symbols:children] 1]
		foreach c $ch {
		    set csc [lindex [get_ctx_data $chan $c Symbols:context] 1]
		    set cid "[dict get $ec Expression].\${$c}"

		    if { ![dict exists $expr_table $chan $ctx $cid data] } {
			expr_create $chan $ctx $cid
		    }
		    set ce [dict get $expr_table $chan $ctx $cid data]
		    dict set expr_table $chan $ctx $cid scope "local"

		    if { [lindex $ce 0] != "" } {
			dict set exprs $cid [dict create err [lindex $ce 0] Parent $parent level $level]
			continue
		    }
		    set id [dict get [lindex $ce 1] ID]
		    set id_list [dict get $exprs $e Children]
		    lappend id_list $id
		    dict set exprs $e Children $id_list
		    get_variable_cache_client $argvar exprs $id $e $csc [expr {$level+1}]
		}
	    }
	}
    }

    proc get_action_reply {argvar fmt script err} {
	upvar $argvar arg
	if { [string length $err] > 0 } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $err
	    }
	} elseif { [catch {::tcf::read [dict get $arg chan] $fmt} data] } {
	    if { [dict get $arg err] == "" } {
		dict set arg err $data
	    }
	} else {
	    if { [catch {eval $script} msg opt] } {
		puts stderr $opt
	    }
	}
	control::assert {[dict get $arg numreq] > 0}
	dict incr arg numreq -1
	cache notify
    }

    proc send_action_command {argvar service name argfmt resfmt arglist {script {}}} {
	upvar $argvar arg
	set chan [dict get $arg chan]
	::tcf::send_command $chan $service $name [list get_action_reply $argvar $resfmt $script]
	::tcf::write $chan $argfmt $arglist
    }

    proc process_tcf_actions_cache_client {argvar} {
	upvar $argvar arg
	dict with arg {
	    if { [catch {
		while { $err == "" && $numreq < $maxreq && $curaction < [llength $actions] } {
		    eval [lindex $actions $curaction]
		}
	    } msg opt] } {
		if { $msg == $::cache_miss_err } {
		    return -options $opt $msg
		}
		if { $err == "" } {
		    set err $msg
		}
	    }

	    if { $numreq > 0 } {
		if { $err != "" } {
		    catch {eval_progress [list info "aborting, $numreq pending requests... "]}
		}
		cache wait
	    }

	    ::tcf::cache_exit

	    catch {eval_progress [list done]}

	    if { [catch {set retval [eval $result]} msg opt] } {
		set retval {}
		if { $err == "" } {
		    set err $msg
		}
	    }
	    set errstr $err
	}
	unset arg
	if { $errstr != "" } {
	    error $errstr
	}
	return $retval
    }
}

namespace eval ::xsdb {
    variable version 0.1
    variable curchan {}
    variable curtarget ""
    variable xsdb_src_dir
    variable command_metadata {}
    variable bptable [dict create]
    variable bpfmttable [dict create]
    variable streamtable [dict create]
    variable streamreader_bufs [dict create]
    variable memmaptable [dict create]
    variable memmap_ctxs [dict create]
    variable designtable [dict create]
    variable swdesignmaps [dict create]
    variable info_messages 0
    variable force_mem_accesses 0
    variable sdk_launch_timeout 60000
    variable profile_config [dict create]
    variable expr_fmt_dict [dict create]
    variable mask_write_warnings 1
    variable enable_source_line_view 1
    variable source_line_info [dict create]
    variable mb_profile_config [dict create]

    dict set expr_fmt_dict 1 [dict create 1 cu 2 su 4 iu 8 wu]
    dict set expr_fmt_dict 4 [dict create 1 cu 2 su 4 iu 8 wu]
    dict set expr_fmt_dict 2 [dict create 1 c 2 s 4 i 8 w]
    dict set expr_fmt_dict 7 [dict create 1 c 2 s 4 i 8 w]
    dict set expr_fmt_dict 3 [dict create 4 r 8 q]

    proc checkbool {b} {
	if { ![string is boolean -strict $b] } {
	    error "expected boolean but got \"$b\" instead"
	}
    }

    proc checkint {i} {
	if { ![string is double -strict $i] || [catch {expr $i >> 8}] } {
	    error "expected integer but got \"$i\" instead"
	}
    }

    proc i2bin {i bits} {
	set l {}
	while { $bits >= 8 } {
	    lappend l [expr $i & 255]
	    set i [expr $i >> 8]
	    incr bits -8
	}
	if { $bits > 0 } {
	    lappend l [expr $i & ((1 << $bits) - 1)]
	}
	return [binary format c* $l]
    }

    proc getcurchan {} {
	variable curchan
	if { $curchan == "" } {
	    error "Invalid target. Use \"connect\" command to connect to hw_server/TCF agent"
	}
	return $curchan
    }

    proc setcurchan {chan} {
	variable curchan
	set curchan $chan
    }

    proc getcurtarget {} {
	variable curtarget
	if { $curtarget == "" } {
	    error "Invalid target. Use \"targets\" command to select a target"
	}
	return $curtarget
    }

    proc setcurtarget {target} {
	variable curtarget
	set curtarget $target
    }

    proc getcmdmeta {cmd type args} {
	variable command_metadata

	if { [llength $args] > 1 } {
	    error "wrong # of args: should be \"getcmdmeta $cmd $type \[default-value\]\""
	}
	if { ![dict exists $command_metadata $cmd $type] } {
	    if { [llength $args] == 1 } {
		return [lindex $args 0]
	    }
	}
	return [dict get $command_metadata $cmd $type]
    }

    proc setcmdmeta {cmd type data {cmd_prefix ""}} {
	variable command_metadata

	dict set command_metadata "$cmd_prefix$cmd" $type $data

	if { $type == "categories" } {
	    if { $data == "sdk" && [string first "xsct" [file tail [info nameofexecutable]]] == -1 } {
		return
	    }
	    dict set command_metadata commands category_commands "$cmd_prefix$cmd" 1
	    foreach category $data {
		dict set command_metadata $category category_commands "$cmd_prefix$cmd" 1
		dict set command_metadata commands categories $category 1
		dict set command_metadata categories categories $category 1
	    }
	}
    }

    # Help categories.  The order in which help categories are
    # declared is the order in which the are displayed to the user.
    setcmdmeta categories brief {List Help Categories}
    setcmdmeta commands brief {List all Commands}
    setcmdmeta connections brief {Target Connection Management}
    setcmdmeta breakpoints brief {Target Breakpoints/Watchpoints}
    setcmdmeta download brief {Target Download FPGA/BINARY}
    setcmdmeta memory brief {Target Memory}
    setcmdmeta registers brief {Target Registers}
    setcmdmeta running brief {Program Execution}
    setcmdmeta reset brief {Target Reset}
    setcmdmeta streams brief {Jtag UART}
    setcmdmeta sdk brief {SDK Projects}
    setcmdmeta petalinux brief {Petalinux commands}
    setcmdmeta {hsi} brief {HSI commands}
    setcmdmeta miscellaneous brief {Miscellaneous}

    proc get_options {argListVar optList {strict 1}} {
	upvar 1 $argListVar arglist

	set result [dict create]
	foreach opt $optList {
	    set flags [lindex $opt 2]
	    if { [dict exists $flags default] } {
		dict set result [lindex $opt 0] [dict get $flags default]
	    } elseif { ![dict exists $flags args] || [dict get $flags args] == 0 } {
		dict set result [lindex $opt 0] 0
	    }
	}

	while { [string index [set arg [lindex $arglist 0]] 0] == "-" } {
	    if { $arg == "--" } {
		set arglist [lrange $arglist 1 end]
		break;
	    }

	    set matchnames {}
	    set matchopt {}
	    set arglen [string length $arg]
	    foreach opt $optList {
		set name -[lindex $opt 0]
		set flags [lindex $opt 2]
		if { [string equal -length $arglen $arg $name] } {
		    if { [dict exists $flags deprecated] && [dict get $flags deprecated] == 1} {
			puts "warning: $name is deprecated as it is not required, it will be removed in future"
		    }
		    set matchopt $opt
		    lappend matchnames $name
		}
	    }

	    set matchcount [llength $matchnames]
	    if { $matchcount != 1 } {
		if { $matchcount == 0 } {
		    set optnames {}
		    foreach opt $optList {
			set flags [lindex $opt 2]
			if { ![dict exists $flags deprecated] || [expr [dict exists $flags deprecated] && [dict get $flags deprecated] != 1] } {
			    lappend optnames -[lindex $opt 0]
			}
		    }
		    error "bad option '$arg': [join $optnames]"
		} else {
		    error "ambiguous option '$arg': [join $matchnames]"
		}
	    }

	    set nargs 0
	    set flags [lindex $matchopt 2]
	    if { [dict exists $flags args] } {
		set nargs [dict get $flags args]
	    }
	    if { $nargs == 0 } {
		set value 1
	    } elseif { [llength $arglist] <= $nargs } {
		error "option [lindex $arglist 0] require $nargs arguments"
	    } elseif { $nargs == 1 } {
		set value [lindex $arglist 1]
	    } else {
		set value [lrange $arglist 1 $nargs]
	    }
	    dict set result [lindex $matchopt 0] $value
	    set arglist [lrange $arglist 1+$nargs end]
	}
	if { $strict && [llength $arglist] } {
	    error "unexpected arguments: $arglist"
	}
	return $result
    }

    proc tid2ctx {chan id} {
	set arg [array get params]
	dict set arg chan $chan
	dict set arg id $id
	dict set arg ctx {}
	dict lappend arg actions {
	    global ::channels::[set chan]::target_ctx_map
	    if { ![dict exists $target_ctx_map $id] } {
		lassign [get_debug_targets_cache_client $chan] targets cache_misses
		if { $cache_misses > 0 } {
		    error $::cache_miss_err
		}
		if { $numreq > 0 } {
		    cache wait
		}
		if { ![dict exists $target_ctx_map $id] } {
		    error "no target with id: $id"
		}
	    }
	    set ctx [dict get $target_ctx_map $id]
	    set rc [get_ctx_data $chan $ctx RunControl:context]
	    set err [lindex $rc 0]
	    if { $err != {} } {
		error $err
	    }
	    incr curaction
	}
	dict set arg result {
	    set ctx
	}
	return [process_tcf_actions $arg]
    }

    proc rewrite_filter_ast {ast filter level} {
	switch -- [lindex $ast 0] {
	    PropName {
		return [list PropName [string range $filter [lindex $ast 1] [lindex $ast 2]]]
	    }
	    Variable -
	    String -
	    Number {
		variable parse_filter_string [string range $filter [lindex $ast 1] [lindex $ast 2]]
		return [list Value [uplevel $level {expr $::xsdb::parse_filter_string}]]
	    }
	    Paren {
		return [rewrite_filter_ast [lindex $ast 4] $filter [expr {$level + 1}]]
	    }
	    default {
		set lhs [rewrite_filter_ast [lindex $ast 3] $filter [expr {$level + 1}]]
		foreach {op rhs} [lrange $ast 4 end] {
		    set rhs [rewrite_filter_ast $rhs $filter [expr {$level + 1}]]
		    set lhs [list [lindex $op 0] $lhs $rhs]
		}
		return $lhs
	    }
	}
    }

    proc parse_filter_token {} {
	variable parse_filter_string
	variable parse_filter_pos

	incr parse_filter_pos
	set c [string index $parse_filter_string $parse_filter_pos]
	if { $c == {} } return
	return [list $c {} $parse_filter_pos 0]
    }

    proc parse_filter {filter {level 1}} {
	variable parse_filter_string $filter
	variable parse_filter_pos -1
	variable filter_peg

	if { ![info exists filter_peg] } {
	    package require grammar::peg
	    package require grammar::peg::interp

	    variable filter_peg [grammar::peg filter_grammar]
	    $filter_peg nonterminal add wsp {+ {/ {t \ } {t \t}}}
	    $filter_peg nonterminal add owsp {? {n wsp}}
	    $filter_peg nonterminal add EQ {x {t =} {t =}}
	    $filter_peg nonterminal add NE {x {t !} {t =}}
	    $filter_peg nonterminal add MA {x {t =} {t ~}}
	    $filter_peg nonterminal add NM {x {t !} {t ~}}
	    $filter_peg nonterminal add LE {x {t <} {t =}}
	    $filter_peg nonterminal add GE {x {t >} {t =}}
	    $filter_peg nonterminal add LT {t <}
	    $filter_peg nonterminal add GT {t >}
	    $filter_peg nonterminal add AND {x {t &} {t &}}
	    $filter_peg nonterminal add OR {x {t |} {t |}}
	    $filter_peg nonterminal add Sign {/ {t +} {t -}}
	    $filter_peg nonterminal add Digit {/ {t 0} {t 1} {t 2} {t 3} {t 4} {t 5} {t 6} {t 7} {t 8} {t 9}}
	    $filter_peg nonterminal add Number {x {? {n Sign}} {+ {n Digit}}}
	    $filter_peg nonterminal add EscChar {x {t //} dot}
	    $filter_peg nonterminal add BSpecial {/ {t //} {t \{} {t \}} {t \"}}
	    $filter_peg nonterminal add BToken {/ {x {! {n BSpecial}} dot} {n EscChar} {n BString} {n QString}}
	    $filter_peg nonterminal add BString {x {t \{} {* {n BToken}} {t \}}}
	    $filter_peg nonterminal add QSpecial {/ {t //} {t \"} {t \[}}
	    $filter_peg nonterminal add QToken {/ {x {! {n QSpecial}} dot} {n EscChar} {n QString}}
	    $filter_peg nonterminal add QString {x {t \"} {* {n QToken}} {t \"}}
	    $filter_peg nonterminal add SSpecial {/ {t //} {t \"} {t \{} {t \[} {t \]}}
	    $filter_peg nonterminal add SToken {/ {x {! {n SSpecial}} dot} {n EscChar} {n String}}
	    $filter_peg nonterminal add SString {x {t \[} {* {n SToken}} {t \]}}
	    $filter_peg nonterminal add String {/ {n QString} {n BString} {n SString}}
	    $filter_peg nonterminal add VarName {+ {/ alnum {t _}}}
	    $filter_peg nonterminal add Variable {x {t $} {/ {n VarName} {n QString}}}
	    $filter_peg nonterminal add PropName {x alpha {* {/ alnum {t _}}}}
	    $filter_peg nonterminal add Paren {x {t (} {n Orexp} {t )}}
	    $filter_peg nonterminal add Atom {x {n owsp} {/ {n Paren} {n PropName} {n Variable} {n String} {n Number}} {n owsp}}
	    $filter_peg nonterminal add Relexp {x {n Atom} {* {x {/ {n EQ} {n NE} {n MA} {n NM} {n LE} {n GE} {n LT} {n GT}} {n Atom}}}}
	    $filter_peg nonterminal add Andexp {x {n Relexp} {* {x {n AND} {n Relexp}}}}
	    $filter_peg nonterminal add Orexp {x {n Andexp} {* {x {n OR} {n Andexp}}}}
	    $filter_peg nonterminal add Filter {x {n Orexp} {! dot}}
	    $filter_peg start {n Filter}
	    $filter_peg nonterminal mode owsp discard
	    $filter_peg nonterminal mode PropName leaf
	    $filter_peg nonterminal mode Variable leaf
	    $filter_peg nonterminal mode String leaf
	    $filter_peg nonterminal mode Number leaf
	}

	set err {}
	set ast {}
	grammar::peg::interp::setup $filter_peg
	grammar::peg::interp::parse [namespace current]::parse_filter_token err ast
	if { [llength $err] != 0 } {
	    error "filter syntax error near column [lindex [lindex $err 0] 0]"
	}
	return [rewrite_filter_ast $ast $filter [expr {$level + 1}]]
    }

    proc match_pattern {pattern string {regexp 0} {nocase 0}} {
	if { $regexp } {
	    if { $nocase } {
		return [regexp -nocase "\\A$pattern\\Z" $string]
	    } else {
		return [regexp "\\A$pattern\\Z" $string]
	    }
	} else {
	    if { $nocase } {
		return [string match -nocase $pattern $string]
	    } else {
		return [string match $pattern $string]
	    }
	}
    }

    proc match_filter {filter props {regexp 0} {nocase 0}} {
	switch -- [lindex $filter 0] {
	    PropName {
		set name [lindex $filter 1]
		if { [dict exists $props $name] } {
		    return [dict get $props $name]
		} else {
		    return ""
		}
	    }
	    Value {
		return [lindex $filter 1]
	    }
	    default {
		set lhs [match_filter [lindex $filter 1] $props $regexp $nocase]
		set rhs [match_filter [lindex $filter 2] $props $regexp $nocase]
		switch -- [lindex $filter 0] {
		    EQ { return [expr {$lhs == $rhs}]}
		    NE { return [expr {$lhs != $rhs}]}
		    MA { return [expr {[match_pattern $rhs $lhs $regexp $nocase] != 0}]}
		    NM { return [expr {[match_pattern $rhs $lhs $regexp $nocase] == 0}]}
		    LE { return [expr {$lhs <= $rhs}]}
		    GE { return [expr {$lhs >= $rhs}]}
		    LT { return [expr {$lhs < $rhs}]}
		    GT { return [expr {$lhs > $rhs}]}
		    AND { return [expr {$lhs && $rhs}]}
		    OR { return [expr {$lhs || $rhs}]}
		    default { error "unhandled filter opcode [lindex $filter 0]" }
		}
	    }
	}
    }

    proc no_print_progress {info} {
	abort_check
    }

    proc print_progress {info} {
	switch -- [lindex $info 0] {
	    "info" {
		puts -nonewline "\r[lindex $info 1]"
	    }
	    "warning" {
		puts "\r[lindex $info 1]"
	    }
	    "done" {
		puts ""
	    }
	}
	flush stdout
	abort_check
    }

    proc process_tcf_actions { arg { progress ::xsdb::no_print_progress } } {
	if { ![dict exists $arg chan] } {
	    dict set arg chan [getcurchan]
	}
	set arg [dict merge {curaction 0 maxreq 16 numreq 0 result {} err ""} $arg]
	set argvar [::tcf::sync_eval [list set_arg $arg]]
	if { [catch {::tcf::cache_eval_with_progress [dict get $arg chan] \
			 [list process_tcf_actions_cache_client $argvar] $progress} msg opt] } {
	    ::tcf::sync_eval [list catch [list unset $argvar]]
	}
	return -options $opt $msg
    }

    proc current_target_jtag_context {} {
	set arg {}
	dict set arg chan [getcurchan]
	dict set arg ctx [getcurtarget]
	dict set arg jc {}
	dict lappend arg actions {
	    set rc [lindex [get_ctx_data $chan $ctx RunControl:context] 1]
	    if { [dict exists $rc JtagGroup] } {
		set jtaggroup [dict get $rc JtagGroup]
		set rc [lindex [get_ctx_data $chan $jtaggroup RunControl:context] 1]
	    }
	    if { [dict exists $rc JtagNodeID] } {
		set node [dict get $rc JtagNodeID]
		set jc [lindex [get_ctx_data $chan $node Jtag:context] 1]
	    }
	    incr curaction
	}
	dict set arg result {
	    set jc
	}
	return [process_tcf_actions $arg]
    }

    proc get_target_jtag_context { chan ctx {type Jtag:context} } {
	set arg {}
	dict set arg chan $chan
	dict set arg ctx $ctx
	dict set arg type $type
	dict set arg jc {}
	dict lappend arg actions {
	    set rc [lindex [get_ctx_data $chan $ctx RunControl:context] 1]
	    if { [dict exists $rc JtagGroup] } {
		set jtaggroup [dict get $rc JtagGroup]
		set rc [lindex [get_ctx_data $chan $jtaggroup RunControl:context] 1]
	    }
	    if { [dict exists $rc JtagNodeID] } {
		set node [dict get $rc JtagNodeID]
		set jc [lindex [get_ctx_data $chan $node $type] 1]
	    }
	    incr curaction
	}
	dict set arg result {
	    set jc
	}
	return [process_tcf_actions $arg]
    }

    proc get_debug_targets {chan} {
	return [::tcf::eval "::tcf::cache_enter {$chan} { eval_done \[get_debug_targets {$chan} \] }"]
    }

    proc dict_get_safe {dict args} {
	if { [dict exists $dict {*}$args] } {
	    return [dict get $dict {*}$args]
	}
	return {}
    }

    proc get_device_indices { nodes {parent ""} {index 0} {level 0} } {
	if { ![dict exists $nodes $parent] } {
	    return
	}

	foreach ctx [dict get $nodes $parent children] {
	    set jc [lindex [dict_get_safe $nodes $ctx Jtag:context] 1]
	    if { [dict_get_safe $jc ParentID] == "" } {
		set index 0
	    }
	    if { $level == 1 } {
		dict set nodes $ctx index $index
		incr index
	    }
	    set nodes [get_device_indices $nodes $ctx $index [expr $level + 1]]
	}
	return $nodes
    }

    proc get_debug_targets_properties {data {parent ""} {level 0} {parentprops {}}} {
	variable curtarget
	if { ![dict exists $data targets $parent] } {
	    return
	}

	set result {}
	set prevprops {}
	foreach ctx [dict get $data targets $parent children] {
	    set props $parentprops
	    dict set props target_ctx $ctx
	    dict set props target_id [dict get $data targets $ctx target_id]
	    dict set props level $level

	    set rc [lindex [dict get $data targets $ctx RunControl:context] 1]
	    set mem [lindex [dict get $data targets $ctx Memory:context] 1]
	    if { [dict exists $rc Name] } {
		set name [dict get $rc Name]
	    } elseif { [dict exists $mem Name] } {
		set name [dict get $mem Name]
	    } else {
		set name $ctx
	    }
	    if { [dict exists $rc AdditionalInfo] } {
		append name [dict get $rc AdditionalInfo]
	    }
	    dict set props name $name

	    if { [dict exists $rc HasState] } {
		set state [dict get $data targets $ctx RunControl:state]
		if { [lindex $state 0] == "" } {
		    dict set props suspended [lindex $state 1]
		    if { ![lindex $state 1] } {
			set state_data [lindex $state 4]
			if { [dict exists $state_data StateName] } {
			    set reason "[dict get $state_data StateName]"
			} else {
			    set reason "Running"
			}
		    } elseif { [lindex $state 3] != "" } {
			set reason "[lindex $state 3]"
			if { [lindex $state 4] != "" && [dict exists [lindex $state 4] Context] } {
			    append reason ", [dict get [lindex $state 4] Context]"
			}
		    } else {
			set reason "Stopped"
		    }
		} else {
		    set reason "state error: [lindex $state 0]"
		}
	    } else {
		set reason ""
	    }
	    dict set props state_reason $reason
	    dict set props is_current [expr {$curtarget == $ctx}]
	    dict set props bscan [dict_get_safe $rc JtagChain]

	    catch {
		set jtaggroup [dict get $rc JtagGroup]
		set jtagrc [lindex [dict get $data targets $jtaggroup RunControl:context] 1]
		set node [dict get $jtagrc JtagNodeID]
		set nc [lindex [dict get $data nodes $node Jtag:context] 1]
		dict set props jtag_device_id [dict get $data nodes $node node_id]
		dict set props jtag_device_ctx [dict get $nc ID]
		set device_index [dict get $data nodes $node index]

		#Find node for scan chain and check capabilities
		while { [dict_get_safe $nc ParentID] != "" } {
		    set node [dict_get_safe $nc ParentID]
		    set nc [lindex [dict get $data nodes $node Jtag:context] 1]
		}
		dict set props jtag_cable_id [dict get $data nodes $node node_id]
		dict set props jtag_cable_ctx [dict get $nc ID]
		dict set props jtag_cable_name [dict_get_safe $nc Name]
		dict set props jtag_device_index $device_index

		foreach port [dict get $data ports] {
		    if { [dict get $port NodeID] == $node } {
			dict set props jtag_cable_manufacturer [dict_get_safe $port Manufacturer]
			dict set props jtag_cable_product [dict_get_safe $port ProductID]
			dict set props jtag_cable_serial [dict_get_safe $port Serial]
			set name ""
			if { ([dict exists $port Description] && [dict get $port Description] != "") &&
			     !([dict exists $port isError] && [dict get $port isError]) &&
			     !([dict exists $port isInitializing] && [dict get $port isInitializing]) } {
			    set name [dict get $port Description]
			    if { [dict exists $port Serial] && [dict get $port Serial] != "" } {
				append name " [dict get $port Serial]"
			    }
			} else {
			    if { [dict exists $port Manufacturer] && [dict get $port Manufacturer] != "" } {
				set name [dict get $port Manufacturer]
				if { [dict exists $port ProductID] && [dict get $port ProductID] != "" } {
				    append name " [dict get $port ProductID]"
				} else {
				    append name " cable"
				}
				if { [dict exists $port Serial] && [dict get $port Serial] != "" } {
				    append name " [dict get $port Serial]"
				}
			    } elseif { [dict exists $port ProductID] && [dict get $port ProductID] != "" } {
				set name [dict get $port ProductID]
			    }
			}
			dict set props jtag_cable_name $name
			break
		    }
		}
	    } msg opt

	    lappend result $props
	    lappend result {*}[get_debug_targets_properties $data $ctx [expr {$level+1}] $props]
	    set prevprops $props
	}
	return $result
    }

    proc print_debug_targets {targets} {
	set result ""
	foreach target $targets {
	    if { $result != "" } {
		append result "\n"
	    }

	    set target_id [dict get $target target_id]
	    set level [dict get $target level]
	    append result [format "%*d" [expr {$level*3+3}] $target_id]
	    if { [dict get $target is_current] } {
		append result "*"
	    } else {
		append result " "
	    }

	    append result " " [dict get $target name]
	    set reason [dict get $target state_reason]
	    if { $reason != "" } {
		append result " (" $reason ")"
	    }
	}
	return $result
    }

    proc print_processes {processes} {
	if { ![dict exists $processes ""] } {
	    return
	}

	foreach ctx [dict get $processes "" children] {
	    if { [dict exists $processes $ctx ProcessesV1:context] } {
		set process [dict get $processes $ctx ProcessesV1:context]
	    } else {
		set process [dict get $processes $ctx Processes:context]
	    }
	    set pid [dict get $processes $ctx process_id]
	    if { [dict exists [lindex $process 1] Name] } {
		set name [dict get [lindex $process 1] Name]
	    } else {
		set name $ctx
	    }
	    if { [dict exists [lindex $process 1] Attached] &&
		 [dict get [lindex $process 1] Attached] } {
		set attached 1
	    } else {
		set attached 0
	    }
	    puts [format "%3d %s" $pid $name]
	}
    }

    proc get_regs {chan ctx flags} {
	return [::tcf::eval "::tcf::cache_enter {$chan} { eval_done \[get_regs {$chan} {$ctx} {$flags} \] }"]
    }

    proc print_name_value_list { values nvlist level flags } {
	upvar $values reg_values
	set has_children 0
	set namemax 0
	set valuemax 0
	dict for {name regdata} $nvlist {
	    if { [dict exists $regdata children] } {
		set has_children 1
	    }
	    set value [dict get $regdata value]
	    set namelen [string length $name]
	    set valuelen [string length $value]
	    if { $namelen > $namemax } {
		set namemax $namelen
	    }
	    if { $valuelen > $valuemax } {
		set valuemax $valuelen
	    }
	}
	if { $has_children ||
	     ([dict exists $flags print_list] &&
	      [dict get $flags print_list]) } {
	    set print_list 1
	} else {
	    set print_list 0
	}
	if { $valuemax > 0 } {
	    set sepmax 2
	} else {
	    set sepmax 0
	}

	set indent [expr {$level*3}]
	set format_data [dict_get_safe $flags format_data]
	if { $format_data == 1 || $print_list || (80 - $indent) / ($namemax + $sepmax + $valuemax + 2) <= 1 } {
	    dict for {name regdata} $nvlist {
		set value [dict get $regdata value]
		set namelen [string length $name]
		set valuelen [string length $value]

		if { $valuelen > 0 } {
		    if { $format_data == 1 } {
			set sep "\t"
			set value "0x$value"
		    } else {
			set sep ": "
		    }
		} elseif { $sepmax > 0 } {
		    if { $format_data == 1 } {
			set sep "\t"
		    } else {
			set sep "  "
		    }
		} else {
		    set sep ""
		}
		if { $format_data == 1 && [dict exists $regdata addr]} {
		    set addr [format 0x%x [dict get $regdata addr]]
		    append reg_values "[format "%*s%*s%s%s%s%s%s" $indent "" [expr {$namemax - $namelen}] "" $name $sep $addr $sep $value]\n"
		} else {
		    append reg_values "[format "%*s%*s%s%s%s" $indent "" [expr {$namemax - $namelen}] "" $name $sep $value]\n"
		}
		print_name_value_list reg_values [dict_get_safe $regdata children] [expr { $level + 1}] $flags
	    }
	} else {
	    # can fit multiple columns
	    set pos 0
	    dict for {name regdata} $nvlist {
		set value [dict get $regdata value]
		set namelen [string length $name]
		set valuelen [string length $value]

		if { $valuelen > 0 } {
		    set sep ": "
		} elseif { $sepmax > 0 } {
		    set sep "  "
		} else {
		    set sep ""
		}

		if { $pos > 0 && $pos + $namemax + $sepmax + $valuemax + 2 >= 80 } {
		    set pos 0
		    append reg_values "\n"
		}
		if { $pos == 0 } {
		    append reg_values [format "%*s" $indent ""]
		    incr pos $indent
		} else {
		    append reg_values "  "
		    incr pos 2
		}
		append reg_values [format "%*s%s%s%*s" [expr {$namemax - $namelen}] "" $name $sep $valuemax $value]
		incr pos [expr { $namemax + $sepmax + $valuemax }]
	    }
	    if { $pos > 0 } {
		append reg_values "\n"
	    }
	}
    }

    proc get_reg_def { reg } {
		if { [dict exists $reg Description] } {
		    set value [dict get $reg Description]
		} else {
		    set value ""
		}

		set props ""
		if { [dict exists $reg Readable] &&
		     [dict get $reg Readable] != 0 } {
		    append props "R"
		    if { [dict exists $reg ReadOnce] &&
			 [dict get $reg ReadOnce] != 0 } {
			append props "O"
		    }
		}
		if { [dict exists $reg Writeable] &&
		     [dict get $reg Writeable] != 0 } {
		    append props "W"
		    if { [dict exists $reg WriteOnce] &&
			 [dict get $reg WriteOnce] != 0 } {
			append props "O"
		    }
		}
		if { [dict exists $reg Volatile] &&
		     [dict get $reg Volatile] != 0 } {
		    append props "V"
		}
		if { $props != "" } {
		    if { $value != "" } {
			append value " "
		    }
		    append value "($props)"
		}
		return $value
    }

    proc print_regs { values regs ctxlist flags } {
	upvar $values reg_values
	set nvlist {}
	foreach ctx $ctxlist {
	    if { ![dict exists $regs $ctx Registers:context] } {
		continue
	    }

	    set reg [lindex [dict get $regs $ctx Registers:context] 1]
	    if { [dict exists $reg Name] } {
		set name [dict get $reg Name]
	    } else {
		set name $ctx
	    }
	    if { [dict exists $reg MemoryAddress] } {
		dict set nvlist $name addr [dict get $reg MemoryAddress]
	    }

	    if { [dict get $flags defs] } {
		if { [dict exists $reg Bits] } {
		    set ctx [dict get $reg ParentID]
		    set parent [lindex [dict get $regs $ctx Registers:context] 1]
		    set parent_name [dict_get_safe $parent Name]
		    if { [dict_get_safe $flags parent] == 1 && ![dict exists $nvlist $parent_name] } {
			dict set nvlist $parent_name value [get_reg_def $parent]
			set children {}
		    }
		    set value [get_reg_def $reg]
		    if { [dict_get_safe $flags parent] == 1 } {
			dict set children $name value $value
			dict set nvlist $parent_name children $children
			continue
		    }
		} else {
		    set value [get_reg_def $reg]
		}
	    } elseif { [dict exists $regs $ctx Registers:value] || [dict exists $reg Bits] } {
		set bits ""
		if { [dict exists $reg Bits] } {
		    set bits [dict get $reg Bits]
		    set ctx [dict get $reg ParentID]
		    set reg [lindex [dict get $regs $ctx Registers:context] 1]
		    set parent_name [dict_get_safe $reg Name]
		}
		set value "N/A"
		if { [dict exists $regs $ctx Registers:value] } { set value [dict get $regs $ctx Registers:value] }
		if { [lindex $value 0] != "" } {
		    set value "N/A"
		} elseif { [dict exists $reg BigEndian] &&
			   [dict get $reg BigEndian] != 0 } {
		    binary scan [lindex $value 1] H* value
		} else {
		    set value [string reverse [lindex $value 1]]
		    binary scan $value H* value
		}
		if { $bits != "" } {
		    if { [dict_get_safe $flags parent] == 1 && ![dict exists $nvlist $parent_name] } {
			set children {}
			dict set nvlist $parent_name value $value
			if { [dict exists $reg MemoryAddress] } {
			    dict set nvlist $parent_name addr [dict get $reg MemoryAddress]
			}
		    }

		    if { [dict get $flags no_bits] && [dict_get_safe $flags parent] == 1 } continue;
		    if { $value != "N/A" } {
			if { [llength $bits] == 1 } {
			    set bit_value [expr 1 << [lindex $bits 0]]
			    if { [dict_get_safe $flags parent] == 1 } { append name " (Bits \[[lindex $bits 0]\])" }
			} else {
			    set bit_value 0
			    foreach b $bits {
				set bit_value [expr (1 << $b) | $bit_value]
			    }
			    if { [dict_get_safe $flags parent] == 1 } { append name " (Bits \[[lindex $bits end]:[lindex $bits 0]\])" }
			}
			set value [format %x [expr ("0x$value" & $bit_value) >> [lindex $bits 0]]]
		    }
		    if { [dict_get_safe $flags parent] == 1 } {
			dict set children $name value $value
			dict set nvlist $parent_name children $children
			continue
		    }
		}
	    } else {
		set value ""
	    }
	    dict set nvlist $name value $value
	}
	if { [dict get $flags nvlist] } {
	    set nvdict [dict create]
	    dict for {name regdata} $nvlist {
		dict set nvdict $name [dict get $regdata value]
	    }
	    set reg_values $nvdict
	    return
	}
	print_name_value_list reg_values $nvlist 0 $flags
    }

    proc add_saved_breakpoints { chan } {
	variable bptable
	variable bpfmttable

	set services [::tcf::sync_eval [list ::tcf::get_services $chan]]
	if { [dict size $bptable] && [lsearch $services "Breakpoints"] != -1 } {
	    # if the bptable is not empty and if the connection supports Breakpoints,
	    # set the breakpoints to agent/server
	    dict for {key data} $bptable {
		set fmt [dict get $bpfmttable $key]
		if { [catch {::tcf::send_command $chan Breakpoints add "o{$fmt}" e [list $data]} msg] } {
		    puts "Failed to set Breakpoint $key. Deleting.."
		    set bptable [dict remove $bptable $key]
		    set bpfmttable [dict remove $bpfmttable $key]
		}
	    }
	}
    }

    proc connect {args} {
	set options {
	    {host "host name or ip address" {default "127.0.0.1" args 1}}
	    {port "port number" {default "3121" args 1}}
	    {url "connect to url" {args 1}}
	    {path "connect to url path" {args 1}}
	    {set "set default connection" {args 1}}
	    {list "list connections"}
	    {peers "list discovered peers"}
	    {redirect "redirect connection"}
	    {new "create new connection even if one exist to the same url"}
	    {xvc-url "open xvc connection" {args 1}}
	    {server "program to launch if not able to connect" {default hw_server args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { $params(peers) } {
	    set res ""
	    foreach peer [::tcf::sync_eval [list ::tcf::get_peers]] {
		dict with peer {
		    catch {
			set url "$TransportName:$Host:$Port"
			if { ![dict exists $peer Name] } {
			    set Name ""
			}
			append res "[format "  %-30s %s" $url $Name]\n"
		    }
		}
	    }
	    return $res
	}

	if { $params(list) } {
	    variable curchan
	    set connections [::tcf::sync_eval {
		set connections {}
		if { [namespace exists ::channels] } {
		    foreach ns [namespace children ::channels] {
			lappend connections [list [set [set ns]::chan] [set [set ns]::url]]
		    }
		}
		set connections
	    }]
	    set ret {}
	    foreach tuple [lsort -dictionary -index 0 $connections] {
		foreach {chan url} $tuple break
		if { $curchan == $chan } {
		    set iscur "*"
		} else {
		    set iscur " "
		}
		lappend ret "  $iscur$chan [join $url { -> }]"
	    }
	    return [join $ret "\n"]
	}

	if { [info exists params(set)] } {
	    setcurchan $params(set)
	    return
	}

	if { [info exists params(path)] } {
	    variable curchan
	    if { [llength $params(path)] == 0 } {
		error "invalid -path argument, must be non-empty list of URLs"
	    }
	    if { !$params(new) } {
		set connections [::tcf::sync_eval {
		    set connections {}
		    if { [namespace exists ::channels] } {
			foreach ns [namespace children ::channels] {
			    lappend connections [list [set [set ns]::chan] [set [set ns]::url]]
			}
		    }
		    set connections
		}]
		foreach tuple [lsort -dictionary -index 0 $connections] {
		    foreach {chan url} $tuple break
		    if { $url == $params(path) } {
			setcurchan $chan
			return $chan
		    }
		}
	    }

	    set curchansave curchan
	    set chan [connect -new -url [lindex $params(path) 0]]
	    if { [catch {
		foreach url [lrange $params(path) 1 end] {
		    connect -new -redirect -url $url
		}
	    } msg opt] } {
		if { $curchan != "" } {
		    disconnect $curchan
		}
		set curchan curchansave
		return -options $opt $msg
	    }
	    add_saved_breakpoints $chan
	    return $chan
	}

	if { [info exists params(url)] } {
	    set url "$params(url)"
	} else {
	    set url "tcp:$params(host):$params(port)"
	}

	if { $params(redirect) } {
	    set chan [getcurchan]
	    return [::tcf::eval [list connect_redirect $chan $url $params(new)]]
	}

	if { [catch {set chan [::tcf::eval [list connect_tcf $url $params(new)]]} message] } {
	    if { $url != "tcp:127.0.0.1:0" && $url != "tcp:127.0.0.1:3121" } {
		error $message
	    }
	    if { [catch {
		set server $params(server)
		if { 0 && [file tail $server] == $server } {
		    # Relative server file name, first look in our
		    # executables directory and if not found there use
		    # the regular search path.
		    set abspath [file join [file dirname [info nameofexecutable]] $server]
		    if { [file executable $abspath] } {
			set server $abspath
		    } elseif { [file extension $server] == "" &&
			       $::tcl_platform(platform) == "windows"} {
			foreach ext {.com .exe .bat} {
			    if { [file executable $abspath] } {
				set server $abspath
				break
			    }
			}
		    }
		}
		puts "attempting to launch $params(server)"
		set infile [::fileutil::tempfile "tcf"]
		set outfile [::fileutil::tempfile "tcf"]
		set errfile [::fileutil::tempfile "tcf"]
		exec $server -S -d -I10 -s $url <$infile >$outfile 2>$errfile
		set file [open $outfile]
		set props {}
		while { [gets $file l] >= 0 } {
		    if { [string compare -length 19 $l "Server-Properties: "] == 0 } {
			set props [::json::json2dict [string range $l 19 end]]
			continue
		    }
		    puts $l
		}
		close $file
		if { $url == "tcp:127.0.0.1:0" } {
		    set url "tcp:127.0.0.1:[dict get $props Port]"
		}
		set file [open $errfile]
		puts -nonewline [read $file]
		close $file
		file delete $infile $outfile $errfile} message] } {
		puts $message
	    }
	    set chan [::tcf::eval [list connect_tcf $url $params(new)]]
	}

	setcurchan $chan
	add_saved_breakpoints $chan

	if { [info exists params(xvc-url)] } {
	    set fields [split $params(xvc-url) :]
	    if { [string compare -nocase tcp [lindex $fields 0]] == 0 } {
		set fields [lrange $fields 1 end]
	    }
	    if { [llength $fields] > 2 } {
		error "invalid xvc url, expected format tcp:host:port, got $params(xvc-url)"
	    }
	    set host [lindex $fields 0]
	    set port [lindex $fields 1]
	    if { $host == "" } {
		set host "127.0.0.1"
	    }
	    if { $port == "" } {
		set port 10200
	    }
	    ::tcf::send_command $chan JtagCable openServer "so{host s port s}" es [list xilinx-xvc [dict create host $host port $port]]
	}

	return $chan
    }
    namespace export connect
    setcmdmeta connect categories {connections}
    setcmdmeta connect brief {Connect to hw_server/TCF agent}
    setcmdmeta connect description {
SYNOPSIS {
    connect [options]
        Connect to a hw_server or TCF agent
}
OPTIONS {
    -host <host name/ip>
        Name/IP address of the host machine

    -port <port num>
        TCP port number

    -url <url>
        URL description of hw_server/TCF agent

    -list
        List open connections

    -set <channel-id>
        Set active connection

    -new
        Create a new connection, even one exist to the same url

    -xvc-url <url>
        Open Xilinx Virtual Cable connection
}
RETURNS {
    The return value depends on the options used.

    -port, -host, -url, -new
        <channel-id> of the new connection or or error if the connection fails

    -list
        list of open channels or nothing when there are no open channels

    -set
        nothing
}
EXAMPLE {
    connect -host localhost -port 3121
        Connect to hw_server/TCF agent on host localhost and port 3121

    connect -url tcp:localhost:3121
        Identical to previous example
}
}

    proc disconnect {args} {
	variable curchan
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] == 0 } {
	    set chan $curchan
	    if { $chan == "" } {
		error "no channel specified"
	    }
	} elseif { [llength $args] == 1 } {
	    set chan [lindex $args 0]
	} else {
	    error "wrong # of args: should be \"disconnect \[channel\]\""
	}

	::tcf::disconnect $chan
	if { $chan == $curchan } {
	    setcurchan ""
	}
	return
    }
    namespace export disconnect
    setcmdmeta disconnect categories {connections}
    setcmdmeta disconnect brief {Disconnect from hw_server/TCF agent}
    setcmdmeta disconnect description {
SYNOPSIS {
    disconnect
        Disconnect from active channel

    disconnect <channel-id>
        Disconnect from specified channel
}
RETURNS {
    Nothing, if the connection is closed.
    Error string, if invalid channel-id is specified.
}
}

    proc targets {args} {
	set options {
	    {set "set active target"}
	    {regexp "match using regexp"}
	    {nocase "case insensitive match"}
	    {filter "filter targets based on properties" {args 1}}
	    {index "jtag device index" {args 1}}
	    {target-properties "return properties for each target"}
	    {timeout "timeout for polling when filter option is used" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [info exists params(filter)] && ![info exists params(timeout)] } {
	    set params(timeout) 3
	}
	if { ![info exists params(filter)] && [info exists params(timeout)] } {
	    error "timeout option is valid only with filter option"
	}

	set chan [getcurchan]
	set nargs [llength $args]
	if { $nargs == 1 &&
	     ![info exists params(filter)] &&
	     ![info exists params(index)] } {
	    setcurtarget [tid2ctx $chan [lindex $args 0]]
	    return
	}
	set arg [array get params]
	dict set arg chan $chan
	dict set arg services {}
	dict set arg servers {}
	dict set arg ports {}
	dict lappend arg actions {
	    set services [::tcf::get_services $chan]
	    incr curaction
	}
	dict lappend arg actions {
	    if { [lsearch $services JtagCable] >= 0 } {
		# TODO: improve performance by changing JtagCable service to
		# allow caching and retrieval of all ports in a single command.
		::tcf::send_command $chan JtagCable getOpenServers [list apply [list {argvar err} {
		    upvar $argvar arg
		    if { [string length $err] > 0 } {
			if { [dict get $arg err] == "" } {
			    dict set arg err $err
			}
		    } elseif { [catch {::tcf::read [dict get $arg chan] "ea{s}"} data] } {
			if { [dict get $arg err] == "" } {
			    dict set arg err $data
			}
		    } else {
			dict set arg servers [lindex $data 1]
		    }
		    control::assert {[dict get $arg numreq] > 0}
		    dict incr arg curaction
		    dict incr arg numreq -1
		    cache notify
		} [namespace current]] $argvar]
		::tcf::write $chan "" {}
		incr numreq
		cache wait
	    } else {
		incr curaction
	    }
	}
	dict lappend arg actions {
	    foreach server $servers {
		::tcf::send_command $chan JtagCable getPortDescriptions [list apply [list {argvar err} {
		    upvar $argvar arg
		    if { [string length $err] > 0 } {
			if { [dict get $arg err] == "" } {
			    dict set arg err $err
			}
		    } elseif { [catch {::tcf::read [dict get $arg chan] "ea{o{}}"} data] } {
			if { [dict get $arg err] == "" } {
			    dict set arg err $data
			}
		    } else {
			dict lappend arg ports {*}[lindex $data 1]
		    }
		    control::assert {[dict get $arg numreq] > 0}
		    dict incr arg numreq -1
		    if { [dict get $arg numreq] == 0 } {
			cache notify
		    }
		} [namespace current]] $argvar]
		::tcf::write $chan "s" [list $server]
		incr numreq
	    }
	    incr curaction
	}
	dict lappend arg actions {
	    lassign [get_debug_targets_cache_client $chan] targets cache_misses
	    set nodes {}
	    if { [lsearch $services Jtag] >= 0 } {
		incr cache_misses [get_context_datatypes nodes $chan {Jtag:children} {Jtag:context} "" -1]
	    }
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    if { $numreq > 0 } {
		cache wait
	    }
	    incr curaction
	}
	dict set arg result {
	    set_jtag_node_id $chan nodes
	    dict create targets $targets nodes $nodes ports $ports
	}
	set data [process_tcf_actions $arg]
	set nodes [get_device_indices [dict get $data nodes]]
	dict set data nodes $nodes
	set targets [get_debug_targets_properties $data]
	set target_list $targets
	if { [info exists params(filter)] } {
	    set filter [parse_filter $params(filter) 2]
	    set new_targets {}
	    foreach target $targets {
		if { [match_filter $filter $target $params(regexp) $params(nocase)] } {
		    lappend new_targets $target
		}
	    }
	    set targets $new_targets
	    if { [llength $targets] == 0 } {
		if { [llength [dict get $data nodes]] } {
		    set start [clock milliseconds]
		    set end $start
		    set params(timeout) [expr $params(timeout) * 1000]
		    while { [expr $end - $start ] < $params(timeout) } {
			dict set data targets [get_run_state $chan ""]
			set targets [get_debug_targets_properties $data]
			set target_list $targets
			    set new_targets {}
			    foreach target $targets {
				if { [match_filter $filter $target $params(regexp) $params(nocase)] } {
				    lappend new_targets $target
				}
			    }
			    set targets $new_targets
			if { [llength $targets] } break
			set end [clock milliseconds]
		    }
		}
	    }
	}

	if { [info exists params(index)] } {
	    set new_targets {}
	    foreach target $targets {
		if { [dict exists $target jtag_device_index] && [dict get $target jtag_device_index] == $params(index) } {
		    lappend new_targets $target
		}
	    }
	    set targets $new_targets
        }

	if { $nargs == 0 && !$params(set) } {
	    if { $params(target-properties) } {
		return $targets
	    }
	    return [::xsdb::print_debug_targets $targets]
	} elseif { $nargs <= 1 } {
	    if { $nargs == 1 } {
		set new_target_id [lindex $args 0]
	    } else {
		if { [llength $targets] == 0 } {
		    if { [llength $target_list] == 0 } {
			set target_list " none"
		    } else {
			set target_list "\n[::xsdb::print_debug_targets $target_list]"
		    }
		    error "no targets found with \"$params(filter)\". available targets:$target_list"
		}
		if { [llength $targets] != 1 } {
		    error "more than one targets found with \"$params(filter)\":\n[::xsdb::print_debug_targets $targets]"
		}
		set new_target_id [dict get [lindex $targets 0] target_id]
	    }
	    set found 0
	    foreach target $targets {
		if { [dict get $target target_id] == $new_target_id } {
		    setcurtarget [dict get $target target_ctx]
		    set found 1
		    break
		}
	    }
	    if { !$found } {
		error "no target with id: $new_target_id"
	    }
	} else {
	    error "wrong # of args: should be \"targets \[target_id\]\""
	}
    }
    namespace export targets
    setcmdmeta targets categories {connections}
    setcmdmeta targets brief {List targets or switch between targets}
    setcmdmeta targets description {
SYNOPSIS {
    targets [options]
        List available targets

    targets <target id>
        Select <target id> as active target
}
OPTIONS {
    -set
        Set current target to entry single entry in list.  This is
        useful in comibination with -filter option.  An error will be
        generate if list is empty or contains more than one entry.
    -regexp
        Use regexp for filter matching
    -nocase
        Use case insensitive filter matching
    -filter <filter-expression>
        Specify filter expression to control which targets are
        included in list based on its properties.  Filter expressions
        are similar to Tcl expr syntax.  Target properties are
        references by name, while Tcl variables are accessed using the
        $ syntax, string must be quoted.  Operators ==, !=, <=, >=, <,
        >, && and || are supported as well as ().  There operators
        behave like Tcl expr operators.  String matching operator =~
        and !~ match lhs string with rhs pattern using either regexp
        or string match.
    -target-properties
        Returns a Tcl list of dict's containing target properties.
    -index <index>
        Include targets based on jtag scan chain position.  This is
        identical to specifying -filter {jtag_device_index==<index>}.
    -timeout <sec>
        Poll until the targets specified by filter option are found
        on the scan chain, or until timeout. This option is valid only
        with filter option.
        The timeout value is in seconds. Default timeout is 3 seconds

}
RETURNS {
    The return value depends on the options used.

    <none>
        Targets list when no options are used

    -filter
        Filtered targets list

    -target-properties
        Tcl list consisting of target properties

    An error is returned when target selection fails.
}
EXAMPLE {
    targets
        List all targets

    targets -filter {name =~ "ARM*#1"}
        List targets with name starting with "ARM" and ending with "#1"

    targets 2
        Set target with id 2 as the current target

    targets -set -filter {name =~ "ARM*#1"}
        Set current target to target with name starting with "ARM" and
        ending with "#1"

    targets -set -filter {name =~ "MicroBlaze*"} -index 0
        Set current target to target with name starting with "MicroBlaze"
        and which is on 1st Jtag Device
}
}

    proc get_access_modes {chan ctx} {
	set access_modes {}

	set arg {}
	dict set arg chan $chan
	dict set arg ctx $ctx
	dict set arg targets {}
	dict lappend arg actions {
	    set targets {}
	    set cache_misses [get_context_datatypes targets $chan {RunControl:children} {RunControl:children RunControl:context} $ctx 2]
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    incr curaction
	}
	dict set arg result {
	    set targets
	}
	set targets [::xsdb::process_tcf_actions $arg]

	set rc [lindex [dict get $targets $ctx RunControl:context] 1]
	if { [dict exists $rc HasState] } {
	    foreach child [lindex [dict get $targets $ctx RunControl:children] 1] {
		set crc [lindex [dict get $targets $child RunControl:context] 1]
		if { [dict exists $crc Name] } {
		    dict set access_modes [dict get $crc Name] $child
		}
	    }
	}

	return $access_modes
    }

    proc rrd {args} {
	set options {
	    {target-id "use specified target-id" {args 1}}
	    {defs "show register definitions"}
	    {nvlist "return register name-value list"}
	    {format-result "format the result"}
	    {no-bits "don't show bit fields along with register values"}
	    {access-mode "access-mode use to access register" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}
	if { $params(defs) + $params(nvlist) + $params(format-result) > 1 } {
	    error "conflicting options specified, use only one of -defs, -format-result, or -nvlist"
	}
	set flags [dict create regpath $args defs $params(defs) no_bits $params(no-bits)]

	set chan [getcurchan]
	if { [info exists params(target-id)] } {
	    set ctx [tid2ctx $chan $params(target-id)]
	} else {
	    set ctx [getcurtarget]
	}
	if { [info exists params(access-mode)] } {
	    set access_modes [get_access_modes $chan $ctx]
	    set name [lsearch -all -inline -glob [dict keys $access_modes] "$params(access-mode)*"]
	    if { [llength $name] != 1 } {
		error "unknown or ambiguous access mode \"$params(access-mode)\": must be [join [dict keys $access_modes] {, }]"
	    }
	    set ctx [dict get $access_modes $name]
	}

	set params(chan) $chan
	set params(parent) $ctx
	set arg [array get params]
	dict set arg err ""
	dict set arg numreq 0
	dict set arg curpos 0
	dict set arg curaction 0
	dict set arg actions [list [list meta] [list data]]
	dict set arg numregs 0
	dict set arg flags $flags
	dict set arg regs {}
	dict set arg orig_ctx $ctx
	set argvar [::tcf::sync_eval [list set_arg $arg]]
	set regs [::tcf::cache_eval $params(chan) [list register_read_cache_client $argvar]]
	if { ![llength [dict get $regs $params(parent) children]] } {
	    error "Target has no registers"
	}

	dict set flags nvlist $params(nvlist)
	dict set flags format_data $params(format-result)
	set ctx_match [dict get $regs ctx_match]
	set reg_values ""
	set regpath [dict get $flags regpath]
	set regname [dict_get_safe [lindex [dict get $regs $ctx_match Registers:context] 1] Name]
	set childpath {}
	if { [lindex $regpath end] != $regname } {
	    for {set i 0} {$i < [llength $regpath]} {incr i} {
		if { [lindex $regpath $i] == $regname } {
		    set childpath [lrange $regpath [expr $i + 1] end]
		    break
		}
	    }
	}
	if { [dict exists $regs $ctx_match children] &&
	     [llength [dict get $regs $ctx_match children]] > 0 } {
	    if { $childpath == {} } {
		dict set flags parent 1
		set ctxs [dict get $regs $ctx_match children] ;#[list $ctx_match]
	    } else {
		set ctxs {}
		set children [dict get $regs $ctx_match children]
		foreach child $children {
		    foreach name $childpath {
			if { $name == [dict get [lindex [dict get $regs $child Registers:context] 1] Name] } {
			    lappend ctxs $child
			}
		    }
		}
	    }
	} else {
	    set ctxs [list $ctx_match]
	}
	::xsdb::print_regs reg_values $regs $ctxs $flags
	return $reg_values
    }
    namespace export rrd
    setcmdmeta rrd categories {registers}
    setcmdmeta rrd brief {Register Read}
    setcmdmeta rrd description {
SYNOPSIS {
    rrd [options] [reg]
        Read registers for active target
}
OPTIONS {
    -defs
        Read register definitions instead of values

    -no-bits
        Don't show bit fields along with register values. By default,
	bit fields are shown, when available
}
EXAMPLE {
    rrd
        Read top level registers or groups

    rrd r0
        Read register r0

    rrd usr r8
        Read register r8 in group usr
}
RETURNS {
    Register names and values, or register definitions if successful.
    Error string, if the registers can't be read or if an invalid register is
    specified.
}
}

    proc rwr {args} {
	set options {
	    {target-id "use specified target-id" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
	if { [info exists params(target-id)] } {
	    set parent [tid2ctx $chan $params(target-id)]
	} else {
	    set parent [getcurtarget]
	}

	if { [llength $args] < 2 } {
	    error "wrong # of args: should be \"rwr reg_path value"
	}

	set reg_val [lindex $args end]
	checkint $reg_val

	set args [lreplace $args end end]
	set flags [dict create regpath $args defs 1] ; # Don't read the register values

	set regs [::tcf::cache_eval $chan [list get_regs $chan $parent $flags]]

	foreach name [dict get $flags regpath] {
	    set match 0
	    if { [dict exists $regs $parent children] } {
		foreach ctx [dict get $regs $parent children] {
		    if { [dict exists $regs $ctx Registers:context] } {
			set reg [dict get $regs $ctx Registers:context]
			if { [dict exists [lindex $reg 1] Name] &&
			     [dict get [lindex $reg 1] Name] == $name } {
			    set parent $ctx
			    set match 1
			    break
			}
		    }
		}
	    }
	    if { !$match } {
		error "no register match: $name"
	    }
	}

	set reg [lindex $reg 1]
	if { ![dict exists $reg Writeable] || ![dict get $reg Writeable] } {
	    error "Register $args is not Writeable"
	}

	set reg_val [i2bin $reg_val [expr {[dict get $reg Size] * 8}]]
	if { [dict exists $reg BigEndian] && [dict get $reg BigEndian] } {
	    set reg_val [string reverse $reg_val]
	}
	::tcf::send_command $chan Registers set sB e [list [dict get $reg ID] $reg_val]
	return
    }
    namespace export rwr
    setcmdmeta rwr categories {registers}
    setcmdmeta rwr brief {Register Write}
    setcmdmeta rwr description {
SYNOPSIS {
    rwr <reg> <value>
        Write the <value> to active target register specified by <reg>
}
RETURNS {
    Nothing, if successful.
    Error string, if an invalid register is specified or the register can't be
    written.
}

EXAMPLE {
    rwr r8 0x0
        Write 0x0 to register r8

    rwr usr r8 0x0
        Write 0x0 to register r8 in group usr
}
}

    proc get_event_table {} {
	set et [::tcf::sync_eval {
	    variable event_table
	    if { ![info exists event_table] } {
		return ""
	    }
	    set ret $event_table
	    unset event_table
	    return $ret
	}]
	return $et
    }

    proc enable_info_messages {} {
	variable info_messages
	set info_messages 1
	return
    }
    namespace export enable_info_messages

    proc print_targets_state { et {prompt ""} } {
	variable curchan
	variable info_messages
	variable designtable
	variable bptable
	variable source_line_info

	if { $::tcl_interactive == 0 && $info_messages == 0 } {
	    #suppress event notifications in non-interactive mode
	    return
	}
	# Print any channel related messages and return if curchan is closed
	set tcfchans ""
	set breakpoints ""
	set ctxs ""
	dict for {key info} $et {
	    switch -- [lindex $info 0] {
		"breakpoint" {
		    dict set breakpoints $key [lindex $info 1]
		}
		"channel" {
		    dict set tcfchans $key [lindex $info 1]
		}
		"target" {
		    dict set ctxs $key [lindex $info 1]
		}
	    }
	}
	dict for {chan state} $tcfchans {
	    puts "Info: $chan $state"
	    puts -nonewline $prompt
	    if { $state == "closed" } {
		dict for {hw hwdata} $designtable {
		    set channels [dict get $hwdata channels]
		    set id [lsearch -exact $channels $chan]
		    set channels [lreplace $channels $id $id]
		    if { ![llength $channels] } {
			::hsi::close_hw_design [dict get $hwdata design]
			set designtable [dict remove $designtable $hw]
		    } else {
			dict set designtable $hw channels $channels
		    }
		}
		if { $chan == $curchan } {
		    set curchan ""
		}
		if { [dict exists $source_line_info $chan] } {
		    set source_line_info [dict remove $source_line_info $chan]
		}
	    }
	}
	if { $curchan == "" || ![dict size $et] } {
	    flush stdout
	    return
	}

	set targets [::xsdb::get_debug_targets $curchan]
	foreach key [dict keys $ctxs] {
	    set tid [dict_get_safe $targets $key target_id]
	    set state [dict_get_safe $targets $key RunControl:state]
	    if { $tid == "" || [lindex $state 0] != "" } continue

	    set rc [lindex [dict_get_safe $targets $key RunControl:context] 1]
	    if { [dict exists $rc Name] } {
		set name [dict get $rc Name]
	    } else {
		set name "unknown"
	    }

	    if { [lindex $state 1] == 1 } {
		if { [lindex $state 3] != "" } {
		    set reason " ([lindex $state 3])"
		} else {
		    set reason ""
		}
		puts "Info: $name (target $tid) Stopped at [format 0x%lx [lindex $state 2]]$reason"
		set res [get_source_line_info]
		if { $res != "" } { puts $res }
	    } else {
		set state_data [lindex $state 4]
		if { [dict exists $state_data StateName] } {
		    set reason " ([dict get $state_data StateName])"
		} else {
		    set reason ""
		}
		puts "Info: $name (target $tid) Running$reason"
	    }
	    puts -nonewline $prompt
	}

	set ids [dict keys $bptable]
	dict for {key bpdata} $breakpoints {
	    set bpid ""
	    foreach id $ids {
		if { [dict get $bptable $id ID] == $key } {
		    set bpid $id
		    break
		}
	    }
	    if { $bpid == "" } continue
	    if { [dict_get_safe $bptable $id show_status] != 1 } continue
	    dict set bptable $id show_status 0
	    if { [dict exists $bpdata Error] } {
		puts "Info: Breakpoint $bpid status: Error {[dict get $bpdata Error]}"
	    }
	    if { ![dict exists $bpdata Instances] } {
		puts "Info: Breakpoint $bpid status: {$bpdata}"
		continue
	    }
	    set bp_status [dict get $bpdata Instances]
	    puts "Info: Breakpoint $bpid status:"
	    foreach sinfo $bp_status {
		if { [dict exists $sinfo LocationContext] } {
		    set tid ""
		    set bp_ctx [dict get $sinfo LocationContext]
		    set targets [::xsdb::get_debug_targets $curchan]
		    dict for {ctx ctxdata} $targets {
			if { $ctx ==  $bp_ctx } {
			    set tid [dict get $ctxdata target_id]
			}
		    }
		    if { $tid == "" } continue
		    set status ""
		    if { [dict exists $sinfo Error] } {
			append status [dict get $sinfo Error]
		    } else {
			if { [dict exists $sinfo Address] } {
			    append status "Address: [format 0x%lx [dict get $sinfo Address]] "
			}
			if { [dict exists $sinfo BreakpointType] } {
			    append status "Type: [dict get $sinfo BreakpointType]"
			}
		    }
		    puts "   target $tid: [list $status]"
		}
	    }
	    puts -nonewline $prompt
	}
	flush stdout
    }

    # Handler for events from TCF interp. Uses sync_eval to obtain
    # the event table from TCF interp and prints the status based
    # on the contents of the table
    proc event_table_handler {} {
	set et [get_event_table]
	if { $et == "" } {
	    return
	}
	print_targets_state $et "xsdb% "
    }

    proc get_run_state {chan ctx} {
	set arg {}
	dict set arg chan $chan
	dict set arg ctx $ctx
	dict set arg targets {}
	dict lappend arg actions {
	    lassign [get_debug_targets_cache_client $chan $ctx] targets cache_misses
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    if { $numreq > 0 } {
		cache wait
	    }
	    incr curaction
	}
	dict set arg result {
	    set targets
	}
	return [process_tcf_actions $arg]
    }

    proc wait_for_event { chan ctx end_state {max_time 100} } {
	set start [clock milliseconds]
	set end $start

	while { $max_time < 0 || [expr $end - $start] < $max_time } {
	    set targets [get_run_state $chan $ctx]
	    set found_state 0
	    set match_state 0
	    dict for {ctx2 ctxdata} $targets {
		dict for {type data} $ctxdata {
		    if { $type != "RunControl:state" } continue
		    if { [lindex $data 0] != {} } continue
		    incr found_state
		    set state [lindex $data 1]
		    if { $state == $end_state } {
			incr match_state
		    }
		}
	    }
	    if { $found_state > 0 && $found_state == $match_state } {
		# all the ctxs are in end state. print any state change messages
		set et [get_event_table]
		if { $et != "" } {
		    print_targets_state $et
		}
		break
	    }
	    after 1
	    set end [clock milliseconds]
	}
    }

    proc ctx_added_handler {} {
	set chan_ctx_list [::tcf::sync_eval {
	    variable newctxs_chanlist
	    if { ![info exists newctxs_chanlist] } {
		return ""
	    }
	    set ret $newctxs_chanlist
	    unset newctxs_chanlist
	    return $ret
	}]

	variable designtable
	dict for {chan chandata} $chan_ctx_list {
	    foreach ctx $chandata {
		dict for {hw hwdata} $designtable {
		    if { [lsearch [dict get $hwdata channels] $chan] == -1 } {
			return
		    }
		    set targets [dict get $hwdata targets]
		    set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
		    set parent [dict_get_safe $rc ParentID]
		    if { [lsearch $targets $ctx] != -1 || [lsearch $targets $parent] != -1} {
			set_memmap $chan $ctx $hw
		    }
		}
	    }
	}
    }

    proc state {args} {
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
	set s [::tcf::send_command $chan RunControl getState s o{}biso{} [list [getcurtarget]]]
	if { [lindex $s 0] == "" } {
	    if { ![lindex $s 1] } {
		if { [dict exists [lindex $s 4] StateName] } {
		    set info [dict get [lindex $s 4] StateName]
		} else {
		    set info "Running"
		}
	    } elseif { [lindex $s 3] != "" } {
		set info "Stopped: ([lindex $s 3])"
	    } else {
		set info "Stopped"
	    }
	} else {
	    set info "state error: ([lindex $s 0])"
	}

	return $info
    }
    namespace export state
    setcmdmeta state categories {running}
    setcmdmeta state brief {Display the current state of the target}
    setcmdmeta state description {
SYNOPSIS {
    state
        Return the current execution state of target
}
}

    proc stop { args } {
	set options {
	    {timeout "timeout for blocking" {default 100 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
        set ctx [getcurtarget]
	::tcf::send_command $chan RunControl suspend s e [list $ctx]
        wait_for_event $chan $ctx 1 $params(timeout)
	return
    }
    namespace export stop
    setcmdmeta stop categories {running}
    setcmdmeta stop brief {Stop active target}
    setcmdmeta stop description {
SYNOPSIS {
    stop
        Suspend execution of active target
}
RETURNS {
    Nothing, if the target is suspended.
    Error string, if the target is already stopped or can't be stopped.

    An info message is printed on the console when the target is suspended.
}
}

    proc con { args } {
	set options {
	    {addr "address to resume from" {args 1}}
	    {block "block until stopped"}
	    {timeout "timeout for blocking" {default 0 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}
	set ctx [getcurtarget]
	set chan [getcurchan]
	if { [info exists params(addr)] } {
	    checkint $params(addr)
	    dict set arg ctx $ctx
	    dict set arg chan $chan
	    dict set arg numreq 0
	    dict set arg pending 0
	    dict set arg err ""
	    dict set arg addr $params(addr)
	    set argvar [::tcf::sync_eval [list set_arg $arg]]
	    ::tcf::cache_eval $chan [list write_pc_cache_client $argvar]
	}

	resume -mode 0
	if { $params(block) } {
	    set status  0
	    set timeout $params(timeout)
	    set state [::tcf::send_command $chan RunControl getState s o{}biso{} [list $ctx]]
	    if { [lindex $state 0] == "" } {
		if { [lindex $state 1] } {
		    return
		}
	    }
	    while { $status == 0 } {
		after 1000
		set state [::tcf::send_command $chan RunControl getState s o{}biso{} [list $ctx]]
		if { [lindex $state 0] == "" } {
		    if { [lindex $state 1] } {
			break
		    }
		}
		# If User Set a Timeout for Blocking, Get Out on Blocking
		if { $timeout } {
		    incr timeout -1
		    if { !$timeout } {
			error "timeout: target has not halted"
		    }
		}
	    }
	}
    }
    namespace export con
    setcmdmeta con categories {running}
    setcmdmeta con brief {Resume active target}
    setcmdmeta con description {
SYNOPSIS {
    con [options]
        Resume execution of active target
}
OPTIONS {
    -addr <address>
        Resume execution from address specified by <address>

    -block
        Block until the target stops or a timeout is reached

    -timeout <sec>
        Timeout value in seconds
}
RETURNS {
    Nothing, if the target is resumed.
    Error string, if the target is already running or can't be resumed or does
    not halt within timeout, after being resumed.

    An info message is printed on the console when the target is resumed.
}
EXAMPLE {
    con -addr 0x100000
        Resume execution of the active target from address 0x100000

    con -block
        Resume execution of the active target and wait until the target stops

    con -block -timeout 5
        Resume execution of the active target and wait until the target stops
        or until the 5 sec timeout is reached
}
}

    proc read_line_from_file {filename num} {
	if { [catch {set f [open $filename]} msg] } { return $msg }
	set line ""
	while {$num > 0} {
	    if {[gets $f line] < 0} {
		close $f
		return "cannot read line $n from file $filename"
	    }
	    incr num -1
	}
	close $f
	return $line
    }

    proc get_source_line_info {} {
	variable enable_source_line_view
	variable source_line_info

	if { !$enable_source_line_view } { return }
	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	set arg [array get params]
	dict set arg stack {}
	dict lappend arg actions {
	    set stack {}
	    set cache_misses 0
	    set ret [get_ctx_data $chan $ctx StackTrace:children]
	    if { [lindex $ret 0] != "" } {
		error [lindex $ret 0]
	    }
	    foreach child [lindex $ret 1] {
		set entry {}
		set ip ""
		set pid {}
		set top 0
		if { [catch {
		    set entry [get_ctx_data $chan $child StackTrace:context]
		    set ec [lindex $entry 0 0]
		    if { [dict exists $ec IP] } {
			set ip [dict get $ec IP]
		    }
		    if { [dict exists $ec ProcessID] } {
			set pid [dict get $ec ProcessID]
		    }
		    if { [dict exists $ec TopFrame] && [dict get $ec TopFrame] } {
			set top 1
		    }
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
		if { !$top } { continue }
		set m2s {}
		if { $ip != "" && [catch {
		    set ipl $ip
		    set iph $ip
		    incr iph 1
		    set m2s [get_ctx_data $chan [list $pid $ipl $iph] LineNumbers:mapToSource]
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
		set sym {}
		if { $ip != "" && [catch {
		    set sid [get_ctx_data $chan [list $pid $ip] Symbols:findByAddr]
		    if { [lindex $sid 0] == "" } {
			set sym [get_ctx_data $chan [lindex $sid 1] Symbols:context]
		    }
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
		set stack [list $entry $m2s $sym]; break
	    }
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    if { $numreq > 0 } {
		cache wait
	    }
	    incr curaction
	}
	dict set arg result {
	    set stack
	}
	set stack [process_tcf_actions $arg]
	set result ""
	set entry [lindex $stack 0]
	set m2s [lindex $stack 1 1 0]
	set sym [lindex $stack 2 1]
	if { [lindex $entry 1] == "" } {
	    if { [dict exists $sym Name] && [dict exists $m2s Dir] && [dict exists $m2s File] && [dict exists $m2s SLine] } {
		set name [dict get $sym Name]
		set function [dict_get_safe $source_line_info $params(chan) $params(ctx) function]
		set file_name [dict_get_safe $source_line_info $params(chan) $params(ctx) file_name]
		set fname [dict get $m2s File]
		if { $function != $name || $file_name != $fname } {
		    dict set source_line_info $params(chan) $params(ctx) function $name
		    dict set source_line_info $params(chan) $params(ctx) file_name $fname
		    append result "$name\(\) at $fname: [dict get $m2s SLine]\n"
		}
		append result "[dict get $m2s SLine]: [read_line_from_file [file join [dict get $m2s Dir] [dict get $m2s File]] [dict get $m2s SLine]]"
	    }
	} else {
	    append result "error: [lindex $entry 1]"
	}
	return $result
    }

    # Internal - resume the target based on mode
    #	0 - resume normal execution
    #	1 - step over a machine instruction
    #	2 - Execute a machine instruction
    #	3 - step over a line of source code
    #	4 - step into a line of source code
    #	5 - step out from current function
    proc resume { args } {
	set options {
	    {mode "step mode" {default 1 args 1}}
	    {count "step count" {args 1}}
	    {timeout "timeout for blocking" {default 100 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	set r [catch {lindex [info level [expr [info level] - 1]] 0} pname]
	if { $params(help) } {
	    return [help $pname]
	}
	if { ![info exists params(count)] } {
	    if { [llength $args] == 0 } {
		set params(count) 1
	    } else {
		set params(count) [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	}
	if { [llength $args] != 0 } {
	    error "wrong # args: should be \"$pname ?options?\""
	}

	checkint $params(mode)
	checkint $params(count)
	set chan [getcurchan]
	set ctx [getcurtarget]
	::tcf::send_command $chan RunControl resume sii e [list $ctx $params(mode) $params(count)]

        if { $params(mode) == 0 } {
            set state 0
        } else {
            set state 1
        }
        wait_for_event $chan $ctx $state $params(timeout)
	return
    }

    proc stp { args } {
	return [resume -mode 4 {*}$args]
    }
    namespace export stp
    setcmdmeta stp categories {running}
    setcmdmeta stp brief {step into a line of source code}
    setcmdmeta stp description {
SYNOPSIS {
    stp [count]
        resume execution of the active target until control reaches instruction
	that belongs to different line of source code. If a function is called,
	stop at first line of the function code.
	Error is returned if line number information not available.
	If <count> is greater than 1, repeat <count> times.
	Default value of count is 1.
}
RETURNS {
    Nothing, if the target has single stepped.
    Error string, if the target is already running or can't be resumed.

    An info message is printed on the console when the target stops at the next
    address.
}
}

    proc nxt { args } {
	return [resume -mode 3 {*}$args]
    }
    namespace export nxt
    setcmdmeta nxt categories {running}
    setcmdmeta nxt brief {step over a line of source code}
    setcmdmeta nxt description {
SYNOPSIS {
    nxt [count]
        resume execution of the active target until control reaches instruction
	that belongs to a different line of source code, but runs any functions
	called at full speed.
	Error is returned if line number information not available.
	If <count> is greater than 1, repeat <count> times.
	Default value of count is 1.
}
RETURNS {
    Nothing, if the target has stepped to the next source line.
    Error string, if the target is already running or can't be resumed.

    An info message is printed on the console when the target stops at the next
    address.
}
}

    proc stpi { args } {
	return [resume -mode 2 {*}$args]
    }
    namespace export stpi
    setcmdmeta stpi categories {running}
    setcmdmeta stpi brief {Execute a machine instruction}
    setcmdmeta stpi description {
SYNOPSIS {
    stpi [count]
        execute a single machine instruction. If instruction is function call,
	stop at first instruction of the function code
	If <count> is greater than 1, repeat <count> times.
	Default value of count is 1.
}
RETURNS {
    Nothing, if the target has single stepped.
    Error if the target is already running or can't be resumed.

    An info message is printed on the console when the target stops at the next
    address.
}
}

    proc nxti { args } {
	return [resume -mode 1 {*}$args]
    }
    namespace export nxti
    setcmdmeta nxti categories {running}
    setcmdmeta nxti brief {step over a machine instruction}
    setcmdmeta nxti description {
SYNOPSIS {
    nxti [count]
        step over a single machine instruction. If instruction is function call,
	execution continues until control returns from the function.
	If <count> is greater than 1, repeat <count> times.
	Default value of count is 1.
}
RETURNS {
    Nothing, if the target has stepped to the next address.
    Error string, if the target is already running or can't be resumed.

    An info message is printed on the console when the target stops at the next
    address.
}
}

    proc stpout { args } {
	return [resume -mode 5 {*}$args]
    }
    namespace export stpout
    setcmdmeta stpout categories {running}
    setcmdmeta stpout brief {step out from current function}
    setcmdmeta stpout description {
SYNOPSIS {
    stpout [count]
        resume execution of current target until control returns from current
	function.
	If <count> is greater than 1, repeat <count> times.
	Default value of count is 1.
}
RETURNS {
    Nothing, if the target has stepped out of the current function.
    Error if the target is already running or can't be resumed.

    An info message is printed on the console when the target stops at the next
    address.
}
}

    proc dis { args } {
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] > 2 } {
	    error "wrong # of args: should be \"dis \[address\] \[count\]\""
	}
	if { [llength $args] == 0 } {
	    set addr "pc"
	    set num 1
	} else {
	    set addr [lindex $args 0]
	    if { [llength $args] > 1 } {
		set num [lindex $args 1]
	    } else {
		set num 1
	    }
	}

	set chan [getcurchan]
	set ctx [getcurtarget]
	if { $addr == "pc" } {
	    set state [::tcf::send_command $chan RunControl getState s o{}biso{} [list $ctx]]
	    if { [lindex $state 0] == "" } {
		if { ![lindex $state 1] } {
		    error "cannot read PC. current target state is \"Running\""
		}
	    }
	    set addr "0x[dict get [rrd -nvlist pc] pc]"
	}

	checkint $addr
	checkint $num
	set instrns [lindex [::tcf::send_command $chan Disassembly disassemble siio{[dict create Simplified b]} ea{o{}} \
		[list $ctx $addr [expr $num * 4] [dict create Simplified 1]]] 1]
	set dis ""
	foreach instr $instrns {
	    set data [lindex [dict get $instr Instruction] 0]
	    set addr [format %08x [dict get $instr Address]]
	    append dis "$addr: [dict get $data Text]\n"
	}
	return $dis
    }
    namespace export dis
    setcmdmeta dis categories {running}
    setcmdmeta dis brief {Disassemble Instructions}
    setcmdmeta dis description {
SYNOPSIS {
    dis <address> [num]
	Disassemble <num> instructions at address specified by <address>
	The keyword "pc" can be used to disassemble instructions at current PC
	Default value for <num> is 1
}
RETURNS {
    Disassembled instructions if successful.
    Error string, if the target instructions can't be read.
}
EXAMPLE {
    dis
        Disassemble an instruction at the current PC value

    dis pc 2
	Disassemble two instructions at the current PC value

    dis 0x0 2
	Disassemble two instructions at address 0x0
}
}

    proc get_address_spaces {chan ctx} {
	set address_spaces {}

	# This is deprecated in favor of AddressSpaces Memory context
	set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
	if { [dict exists $rc DAPMemID] } {
	    dict set address_spaces APR [dict get $rc DAPMemID]
	}
	if { [dict exists $rc APMemIDs] } {
	    set index 0
	    foreach ctx1 [dict get $rc APMemIDs] {
		if { $ctx1 == "" } continue
		dict set address_spaces AP$index $ctx1
		incr index
	    }
	}

	set mc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx Memory:context]] 1]
	if { [dict exists $mc AddressSpaces] } {
	    set address_spaces [dict merge $address_spaces [dict get $mc AddressSpaces]]
	}

	return $address_spaces
    }

    proc mrd {args} {
	variable force_mem_accesses

	set options {
	    {target-id "use specified target-id" {args 1}}
	    {force "override access protection"}
	    {size "access size" {default w args 1}}
	    {value "return a list of values"}
	    {bin "read binary data and store it in a file"}
	    {file "binary file" {args 1}}
	    {arm-dap "access ARM DAP address space"}
	    {arm-ap "access ARM MEM-AP address space" {args 1}}
	    {address-space "access given address space" {args 1}}
	    {unaligned-access "do not align address to access size"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
	if { [info exists params(target-id)] } {
	    set ctx [tid2ctx $chan $params(target-id)]
	} else {
	    set ctx [getcurtarget]
	}

	if { [llength $args] != 1 && [llength $args] != 2 } {
	    error "wrong # of args: should be \"mrd \[options\] address \[count\]\""
	}
	set addr [lindex $args 0]
	if { [llength $args] > 1 } {
	    set num [lindex $args 1]
	} else {
	    set num 1
	}
	checkint $addr
	checkint $num

	if { $params(arm-dap) || [info exists params(arm-ap)] || [info exists params(address-space)] } {
	    if { $params(arm-dap) + [info exists params(arm-ap)] + [info exists params(address-space)] > 1 } {
		error "only one of -arm-dap, -arm-ap and -address-space should be specifed"
	    }
	    if { $params(arm-dap) } {
		set params(address-space) APR
	    }
	    if { [info exists params(arm-ap)] } {
		checkint $params(arm-ap)
		set params(address-space) [format "AP%u" $params(arm-ap)]
	    }

	    set address_spaces [get_address_spaces $chan $ctx]
	    set name [lsearch -all -inline -glob [dict keys $address_spaces] "$params(address-space)*"]
	    if { [llength $name] != 1 } {
		error "unknown or ambiguous address space \"$params(address-space)\": must be [join [dict keys $address_spaces] {, }]"
	    }
	    set ctx [dict get $address_spaces $name]
	}

	set size 4
	set fmt iu*
	if { $params(size) == "h" } {
	    set size 2
	    set fmt su*
	} elseif { $params(size) == "b" } {
	    set size 1
	    set fmt cu*
	} elseif { $params(size) != "w" } {
	    error "illegal access size $params(size). must be w/h/b"
	}

	if { $params(unaligned-access) } {
	    set start_addr $addr
	} else {
	    set start_addr [expr $addr & ~($size - 1)]
	}
	set nbytes [expr $num * $size]
	set mode 3
	if { $params(force) || $force_mem_accesses } {
	    set mode [expr $mode | 4]
	}

	set value [lindex [::tcf::send_command $chan Memory get "siiii" "Bea{o{msg o{} A}}" [list $ctx $start_addr $size $nbytes $mode]] 0]
	if { $params(bin) } {
	    if { ![info exists params(file) ] } {
		return $value
	    }
	    set fp [open $params(file) wb]
	    puts -nonewline $fp $value
	    close $fp
	    return
	}

	# Get Endianness from the context data
	set mc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx Memory:context]] 1]
	if { $size != 1 && [dict exists $mc BigEndian] && [dict get $mc BigEndian] != 0 } {
	    set fmt [string toupper $fmt 0 0]
	}

	set val_list {}
	binary scan $value $fmt val_list
	if { $params(value) } {
	    return $val_list
	}

	set outstr ""
	set fmt "%8X"
	if { [expr $start_addr + $nbytes] >= 0x100000000 } {
	    set fmt "%16lX"
	}
	for {set i 0} {$i < $num} {incr i} {
	    append outstr [format "$fmt:   [format "%0[expr $size * 2]X" [lindex $val_list $i]]\n" $start_addr]
	    incr start_addr $size
	}

	return $outstr
    }
    namespace export mrd
    setcmdmeta mrd categories {memory}
    setcmdmeta mrd brief {Memory Read}
    setcmdmeta mrd description {
SYNOPSIS {
    mrd [options] <address> [num]
        Read <num> words from the active target's memory address specified by
	<address>
}
OPTIONS {
    -force
        Overwrite access protection. By default accesses to reserved and invalid
        address ranges are blocked

    -size <access-size>
        <access-size> can be one of the values below:
        b = Bytes accesses
        h = Half-word accesses
        w = Word accesses
        Default access size is w
        Address will be aligned to access-size before reading memory

    -value
        Return a Tcl list of values, instead of displaying the result on console

    -bin
        Return data read from the target in binary format

    -file <file-name>
        Write binary data read from the target to <file-name>

    -address-space <name>
        Access specified memory space instead default memory space of
        current target.

        For ARM DAP targets, address spaces DPR, APR and AP<n> can be
        used to access DP Registers, AP Registers and MEM-AP
        addresses, respectively.  For backwards compatibility -arm-dap
        and -arm-ap options can be used as shorthand for
        "-address-space APR" and "-address-space AP<n>", respectively.
        The APR address range is 0x0 - 0xfffc, where the higher 8 bits
        select an AP and lower 8 bits are the register address for
        that AP

    -unaligned-access
        Memory address is not aligned to access size, before performing
        a read operation. Support for unaligned accesses is target
        architecture dependent. If this option is not specified, addresses
        are automatically aligned to access size
}
NOTE {
    Select a APU target to access ARM DAP and MEM-AP address space
}
RETURNS {
    Memory addresses and data in requested format, if successful.
    Error string, if the target memory can't be read.
}
EXAMPLE {
    mrd 0x0
        Read a word at 0x0

    mrd 0x0 10
        Read 10 words at 0x0

    mrd -value 0x0 10
        Read 10 words at 0x0 and return a Tcl list of values

    mrd -size b 0x1 3
        Read 3 bytes at address 0x1

    mrd -size h 0x2 2
        Read 2 half-words at address 0x2

    mrd -bin -file mem.bin 0 100
        Read 100 words at address 0x0 and write the binary data to mem.bin

    mrd -address-space APR 0x100
        Read APB-AP CSW on Zynq
        The higher 8 bits (0x1) select the APB-AP and lower 8 bits (0x0)
        is the address of CSW

    mrd -address-space APR 0x04
        Read AHB-AP TAR on Zynq
        The higher 8 bits (0x0) select the AHB-AP and lower 8 bits (0x4)
        is the address of TAR

    mrd -address-space AP1 0x80090088
        Read address 0x80090088 on DAP APB-AP
        0x80090088 corresponds to DBGDSCR register of Cortex-A9#0, on Zynq
        AP 1 selects the APB-AP

    mrd -address-space AP0 0xe000d000
        Read address 0xe000d000 on DAP AHB-AP
        0xe000d000 corresponds to QSPI device on Zynq
        AP 0 selects the AHB-AP
}
}

    proc mwr {args} {
	variable force_mem_accesses

	set options {
	    {target-id "use specified target-id" {args 1}}
	    {force "override access protection"}
	    {size "access size" {default w args 1}}
	    {bin "write binary data from a file"}
	    {file "binary file" {args 1}}
	    {arm-dap "access ARM DAP address space"}
	    {arm-ap "access ARM MEM-AP address space" {args 1}}
	    {address-space "access given address space" {args 1}}
	    {unaligned-access "do not align address to access size"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
	if { [info exists params(target-id)] } {
	    set ctx [tid2ctx $chan $params(target-id)]
	} else {
	    set ctx [getcurtarget]
	}

	if { [llength $args] < 2 || [llength $args] > 3 } {
	    error "wrong # of args: should be \"mwr \[options\] address values \[num\]\""
	}
	set addr [lindex $args 0]
	if { $params(bin) } {
	    if { ![info exists params(file)] } {
		error "binary data file not specified"
	    }
	    if { [llength $args] > 1 } {
		set num [lindex $args 1]
	    } else {
		# use the file size when length is not specified by user
		set fp [open $params(file) rb]
		set num [tell $fp]
		close $fp
	    }
	} else {
	    set data [lindex $args 1]
	    if { [llength $args] > 2 } {
		set num [lindex $args 2]
	    } else {
		# use the data list length when the length is not specified by the user
		set num [llength $data]
	    }
	}
	checkint $addr
	checkint $num

	set size 4
	set fmt i*
	if { $params(size) == "h" } {
	    set size 2
	    set fmt s*
	} elseif { $params(size) == "b" } {
	    set size 1
	    set fmt c*
	} elseif { $params(size) != "w" } {
	    error "illegal access size $params(size). must be w/h/b"
	}
	set mode 3
	if { $params(force) || $force_mem_accesses } {
	    set mode [expr $mode | 4]
	}

	if { $params(arm-dap) || [info exists params(arm-ap)] || [info exists params(address-space)] } {
	    if { $params(arm-dap) + [info exists params(arm-ap)] + [info exists params(address-space)] > 1 } {
		error "only one of -arm-dap, -arm-ap and -address-space should be specifed"
 	    }
	    if { $params(arm-dap) } {
		set params(address-space) APR
	    }
	    if { [info exists params(arm-ap)] } {
		checkint $params(arm-ap)
		set params(address-space) [format "AP%u" $params(arm-ap)]
	    }

	    set address_spaces [get_address_spaces $chan $ctx]
	    set name [lsearch -all -inline -glob [dict keys $address_spaces] "$params(address-space)*"]
	    if { [llength $name] != 1 } {
		error "unknown or ambiguous address space \"$params(address-space)\": must be [join [dict keys $address_spaces] {, }]"
	    }
	    set ctx [dict get $address_spaces $name]
	}

	if { $params(unaligned-access) } {
	    set start_addr $addr
	} else {
	    set start_addr [expr $addr & ~($size - 1)]
	}
	set nbytes [expr $num * $size]
	if { $params(bin) } {
	    set fp [open $params(file) rb]
	    set bindata [read $fp $nbytes]
	    close $fp
	    ::tcf::send_command $chan Memory set "siiiiB" "ea{o{msg o{} A}}" [list $ctx $start_addr $size $nbytes $mode $bindata]
	    return
	}

	# Get Endianness from the context data
	set mc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx Memory:context]] 1]
	if { $size != 1 && [dict exists $mc BigEndian] && [dict get $mc BigEndian] != 0 } {
	    set fmt [string toupper $fmt]
	}

	if { [llength $data] == 1 && $num > 1 } {
	    set darray [binary format $fmt $data]
	    binary scan $darray cu* darray
	    ::tcf::send_command $chan Memory fill "siiiia{i}" "ea{o{msg o{} A}}" [list $ctx $start_addr $size $nbytes $mode $darray]
	    return
	}

	set bindata ""
	set i 0
	set len [llength $data]
	foreach d $data {
	    checkint $d
	    set d [binary format $fmt $d]
	    append bindata $d

	    incr i
	    if { $i == $num || $i == $len } {
		break
	    }
	}
	::tcf::send_command $chan Memory set "siiiiB" "ea{o{msg o{} A}}" [list $ctx $start_addr $size $nbytes $mode $bindata]

	# if data size < num, fill the last word in remaining addr locations
	if { $i < $num } {
	    set darray [binary format $fmt [lindex $data [expr $i - 1]]]
	    binary scan $darray cu* darray
	    ::tcf::send_command $chan Memory fill "siiiia{i}" "ea{o{msg o{} A}}" [list $ctx [expr $start_addr + [expr $i * $size]] \
										  $size [expr [expr $num - $i] * $size] $mode $darray]
	}

	return
    }
    namespace export mwr
    setcmdmeta mwr categories {memory}
    setcmdmeta mwr brief {Memory Write}
    setcmdmeta mwr description {
SYNOPSIS {
    mwr [options] <address> <values> [num]
        Write <num> words from list of <values> to active target memory
        address specified by <address>.
        If <num> words is not specified, all the <values> from the list
        are written sequentially from the address specifed by <address>
        If <num> is greater than the size of the <values> list, the last
        word in the list is filled at the remaining address locations

    mwr [options] -bin -file <file-name> <address> [num]
        Read <num> values from a binary file and write to active target
        memory address specified by <address>.
        If <num> words is not specified, all the data from the file is
        written sequentially from the address specifed by <address>
}
OPTIONS {
    -force
        Overwrite access protection. By default accesses to reserved and invalid
        address ranges are blocked

    -size <access-size>
        <access-size> can be one of the values below:
        b = Bytes accesses
        h = Half-word accesses
        w = Word accesses
        Default access size is w
        Address will be aligned to access-size before writing to memory

    -bin
        Read binary data from a file and write it to target address space

    -file <file-name>
        File from which binary data is read to write to target address space

    -address-space <name>
        Access specified memory space instead default memory space of
        current target.

        For ARM DAP targets, address spaces DPR, APR and AP<n> can be
        used to access DP Registers, AP Registers and MEM-AP
        addresses, respectively.  For backwards compatibility -arm-dap
        and -arm-ap options can be used as shorthand for
        "-address-space APR" and "-address-space AP<n>", respectively.
        The APR address range is 0x0 - 0xfffc, where the higher 8 bits
        select an AP and lower 8 bits are the register address for
        that AP

    -unaligned-accesses
        Memory address is not aligned to access size, before performing
        a write operation. Support for unaligned accesses is target
        architecture dependent. If this option is not specified, addresses
        are automatically aligned to access size
}
NOTE {
    Select a APU target to access ARM DAP and MEM-AP address space
}
RETURNS {
    Nothing, if successful.
    Error string, if the target memory can't be written.
}
EXAMPLE {
    mwr 0x0 0x1234
        Write 0x1234 to address 0x0

    mwr 0x0 {0x12 0x23 0x34 0x45}
        Write 4 words from the list of values to address 0x0

    mwr 0x0 {0x12 0x23 0x34 0x45} 10
        Write 4 words from the list of values to address 0x0
        and fill the last word from the list at remaining 6
        address locations

    mwr -size b 0x1 {0x1 0x2 0x3} 3
        write 3 bytes from the list at address 0x1

    mwr -size h 0x2 {0x1234 0x5678} 2
        write 2 half-words from the list at address 0x2

    mwr -bin -file mem.bin 0 100
        Read 100 words from binary file mem.bin and write the data at
        target address 0x0

    mwr -arm-dap 0x100 0x80000042
        Write 0x80000042 to APB-AP CSW on Zynq
        The higher 8 bits (0x1) select the APB-AP and lower 8 bits (0x0)
        is the address of CSW

    mwr -arm-dap 0x04 0xf8000120
        Write 0xf8000120 to AHB-AP TAR on Zynq
        The higher 8 bits (0x0) select the AHB-AP and lower 8 bits (0x4)
        is the address of TAR

    mwr -arm-ap 1 0x80090088 0x03186003
        Write 0x03186003 to address 0x80090088 on DAP APB-AP
        0x80090088 corresponds to DBGDSCR register of Cortex-A9#0, on Zynq
        AP 1 selects the APB-AP

    mwr -arm-ap 0 0xe000d000 0x80020001
        Write 0x80020001 to address 0xe000d000 on DAP AHB-AP
        0xe000d000 corresponds to QSPI device on Zynq
        AP 0 selects the AHB-AP
}
}

    proc update_memory_map {chan ctx} {
	variable memmaptable
	set map_list {}
	dict for {id maps} [dict_get_safe $memmaptable $chan $ctx] {
	    foreach map $maps {
		if { [dict exists $map FileName] } {
		    set data [dict create Addr [dict get $map Addr] Size [dict get $map  Size] \
			      Flags [dict get $map Flags] FileName [dict get $map FileName] \
		    Offs [dict get $map Offs] ID $id]
		    if {[dict exists $map SectionName]} {
			dict set data SectionName [dict get $map SectionName]
		    }
		    if {[dict exists $map OSA]} {
			dict set data OSA [dict create Mode [dict get $map OSA]]
		    }
		} else {
		    set data [dict create Addr [dict get $map Addr] Size [dict get $map Size] Flags [dict get $map Flags] ID $id]
		}
		lappend map_list [list {*}$data]
	    }
	}
	::tcf::send_command $chan MemoryMap set sa{o{[dict create Addr i Size i Flags i FileName s \
						      Offs i SectionName s ID s OSA o{[dict create Mode i]}]}} \
						e [list $ctx [list {*}$map_list]]
    }

    proc osa { args } {
	variable memmaptable
	set options {
	    {file "symbol file" {args 1}}
	    {disable "disable OS awareness"}
	    {fast-step "enable fast stepping"}
	    {fast-exec "enable fast process start"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { ![info exists params(file)] } {
	    if { [llength $args] > 0 } {
		set params(file) [lindex $args 0]
		set args [lrange $args 1 end]
	    }
	}
	if { [llength $args] != 0 } {
	    error "unexpected arguments: $args"
	}
	if { [expr $params(disable) + ($params(fast-step) | $params(fast-exec))] > 1 } {
	    error "conflicting args, -fast-exec and -fast-step are not valid when -disable is used"
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	if { [info exists params(file)] } {
	    set params(file) [file normalize $params(file)]
	}

	set match 0
	set file_match ""
	set map_table [dict_get_safe $memmaptable $params(chan) $params(ctx)]
	dict for {id map_list} $map_table {
	    for {set i 0} {$i < [llength $map_list]} {incr i} {
		set map [lindex $map_list $i]
		if { [dict exists $map FileName] } {
		    if { [info exists params(file)] && [dict get $map FileName] != $params(file) } {
			break
		    }
		    if { $match && $file_match != [dict get $map FileName] } {
			error "Cannot configure OSA: Multiple symbol files found in target's memory map. Specify a symbol file"
		    }
		    if { $params(disable) } {
			set map [dict remove $map OSA]
		    } else {
			dict set map OSA [expr ($params(fast-step) << 1) + $params(fast-exec)]
		    }
		    set map_list [lreplace $map_list $i $i $map]
		    dict set map_table $id $map_list
		    if { $file_match == "" } {
			set file_match [dict get $map FileName]
		    }
		    set match 1
		}
	    }
	}
	if { $match } {
	    dict set memmaptable $params(chan) $params(ctx) $map_table
	    update_memory_map $params(chan) $params(ctx)
	    return
	}

	if { $params(disable) } {
	    error "Cannot disable OSA: Symbol file found in target's memory map"
	}
	if { ![info exists params(file)] } {
	    error "Cannot enable OSA: No symbol file found in target's memory map. Specify a symbol file"
	}

	set data [dict create Addr 0 Size 0 Flags 0 FileName $params(file) Offs 0 ID $params(file) \
		  OSA [expr ($params(fast-step) << 1) + $params(fast-exec)]]
	dict lappend maps $params(file) $data
	dict set memmaptable $params(chan) $params(ctx) $maps
	update_memory_map $params(chan) $params(ctx)
	return
    }
    namespace export osa
    setcmdmeta osa categories {memory}
    setcmdmeta osa brief {Configure OS awareness for a symbol file}
    setcmdmeta osa description {
SYNOPSIS {
    osa -file <file-name> [options]
        Configure OS awareness for the symbol file <file-name> specified.
        If no symbol file is specifed and only one symbol file exists in
        target's memory map, then that symbol file is used.
        If no symbol file is specifed and multiple symbol files exist in
        target's memory map, then an error is thrown.
}
OPTIONS {
    -disable
        Disable OS awareness for a symbol file. If this option is not specified,
        OS awareness is enabled.

    -fast-exec
        Enable fast process start. New processes will not be tracked for debug
        and are not visible in the debug targets view.

    -fast-step
        Enable fast stepping. Only the current process will be re-synced after
        stepping. All other processes will not be re-synced when this flag is
	turned on.
}
NOTE {
    fast-exec and fast-step options are not valid with disable option
}
RETURNS {
    Nothing, if OSA is configured successfully.
    Error, if ambiguous options are specified.
}
EXAMPLE {
    osa -file <symbol-file> -fast-step -fast-exec
        Enable OSA for <symbole-file> and turn on fast-exec and fast-step modes

    osa -disable -file <symbol-file>
        Disable OSA for <symbol-file>
}
}

    proc memmap { args } {
	variable memmaptable

	set options {
	    {file "symbol file" {args 1}}
	    {addr "memory address" {args 1}}
	    {size "memory size" {default 0 args 1}}
	    {offset "offset in file" {default 0 args 1}}
	    {section "object file section name" {args 1}}
	    {flags "protection flags" {default 3 args 1}}
	    {osa "enable OS awareness" {default 0}}
	    {clear "clear the entry from memory map"}
	    {list "list the target memory map" }
	    {relocate-section-map "relocate program section map" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}
	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]

	if { $params(list) } {
	    if { [info exists params(addr)] || $params(clear) } {
		error "extra args with -list option"
	    }
	    set map_list ""
	    if { [dict exists $memmaptable $params(chan) $params(ctx)] } {
		set header [format "%-20s%-10s%-10s%-8s%-20s" "Address" "Size" "Offset" "Flags" "FileName"]
		append header "\n[format "%-20s%-10s%-10s%-8s%-20s" "=======" "====" "======" "=====" "========"]"
		dict for {id map} [dict get $memmaptable $params(chan) $params(ctx)] {
		    if { $map_list == "" } { append map_list $header }
		    set map [lindex $map 0]
		    set addr [dict_get_safe $map Addr]
		    if { $addr != "" } { set addr [format "0x%lx" $addr] }
		    set size [dict_get_safe $map Size]
		    if { $size != "" } { set size [format "0x%lx" $size] }
		    set offs [dict_get_safe $map Offs]
		    if { $offs != "" } { set addr [format "0x%lx" $offs] }
		    set flags [dict_get_safe $map Flags]
		    set filename [file tail [dict_get_safe $map FileName]]
		    append map_list "\n[format "%-20s%-10s%-10s%-8s%-20s" $addr $size $offs $flags $filename]"
		}
	    }

	    if { $map_list == "" } {
		set map_list "No memory regions currently set for the active target during this session\n\n"
	    }

	    return $map_list
	}

	set id ""
	if { [info exists params(file)] } {
	    set params(file) [file normalize $params(file)]
	    set connections [::tcf::sync_eval {
		set connections {}
		if { [namespace exists ::channels] } {
		    foreach ns [namespace children ::channels] {
			lappend connections [list [set [set ns]::chan] [set [set ns]::url]]
		    }
		}
		set connections
	    }]

	    set is_local 0
	    foreach conn $connections {
		foreach {chan url} $conn break
		if { $params(chan) == $chan && $url == "tcp:127.0.0.1:3121" } {
		    set is_local 1
		}
	    }
	    if { $is_local } {
		if { [catch {file readable $params(file)} msg] } {
		    puts $msg
		}
		if { !$msg } { puts "WARNING: $params(file) is not readable" }
	    }

	    set id $params(file)
	    if { ![info exists params(addr)] } {
		set params(addr) 0
	    }
	} elseif { ![info exists params(addr)] } {
	    error "address of the memory region not specified"
	} elseif { !$params(size) && !$params(clear) } {
	    error "size of the memory region not specified"
	}
	if { $id == "" } {
	    set id $params(addr)
	}
	checkint $params(addr)
	checkint $params(size)
	checkint $params(flags)
	checkint $params(offset)

        set data [dict create]
	set map {}
	if { [dict exists $memmaptable $params(chan) $params(ctx)] } {
	    set map [dict get $memmaptable $params(chan) $params(ctx)]
	}

	if { $params(clear) } {
	    if { ![dict exists $map $id] } {
		error "$id was not added to target's memory map"
	    }
	    set map [dict remove $map $id]
	} else {
	    if { [info exists params(relocate-section-map)] } {
		checkint $params(relocate-section-map)
		set data_list {}
		foreach data [dict_get_safe $map $params(file)] {
		    if { [dict_get_safe $data auto_sec] != 1 } {
			lappend data_list $data
		    }
		}
		dict set map $params(file) $data_list
		set data [dict create Addr 0 Size 0 Flags 0 FileName $params(file) Offs 0 ID $params(file)]
		if { $params(osa) } {
		    dict set data OSA 0
		}
		dict lappend map $params(file) $data
		set sh_list [::tcf::sync_eval [list get_elf_sections $params(file)]]
		foreach sh $sh_list {
		    set flags [dict get $sh flags]
		    set size [dict get $sh size]
		    if { [expr {$flags & 0x7}] && $size } {
		        set addr [expr [dict get $sh addr] + $params(relocate-section-map)]
		        set name [dict get $sh name]
		        set data [dict create FileName $params(file) SectionName $name Addr $addr Size $size Offs $params(offset) Flags $flags auto_sec 1]
		        dict lappend map $params(file) $data
		    }
		}
	    } else {
		if { [info exists params(file)] } {
		    dict set data FileName $params(file)
		}
		if { [info exists params(section)] } {
		    dict set data SectionName $params(section)
		}
		if { [info exists params(addr)] } {
		    dict set data Addr $params(addr)
		}
		dict set data Size $params(size)
		dict set data Offs $params(offset)
		dict set data Flags $params(flags)
		if { $params(osa) } {
		    dict set data OSA 0
		}
		dict lappend map $id $data
	    }
	}
	dict set memmaptable $params(chan) $params(ctx) $map
	update_memory_map $params(chan) $params(ctx)
	return
    }
    namespace export memmap
    setcmdmeta memmap categories {memory}
    setcmdmeta memmap brief {Modify Memory Map}
    setcmdmeta memmap description {
SYNOPSIS {
    memmap <options>
        Add/remove a memory map entry for the active target
}
OPTIONS {
    -addr <memory-address>
        Address of the memory region that should be added/removed from
        the target's memory map

    -size <memory-size>
        Size of the memory region

    -flags <protection-flags>
        Protection flags for the memory region.
        <protection-flags> can be a bitwise OR of the values below:
        0x1  = Read access is allowed
        0x2  = Write access is allowed
        0x4  = Instruction fetch access is allowed
    Default value of <protection-flags> is 0x3 (Read/Write Access)

    -list
        List the memory regions added to the active target's memory map

    -clear
        Specify whether the memory region should be removed from the target's
        memory map

    -relocate-section-map <addr>
        Relocate the address map of the program sections to <addr>. This option
        should be used when the code is self-relocating, so that the debugger
        can find the debug symbol info for the code. <addr> is the relative
        address, to which all the program sections are relocated

    -osa
        Enable OS awareness for the symbol file.
        Fast process start and fast stepping options are turned off by default.
        These options can be enabled using the osa command. See "help osa" for
        more details.
}
NOTE {
    Only the memory regions previously added through memmap command can
    be removed
}
RETURNS {
    Nothing, while setting the memory map, or list of memory maps when -list
    option is used.
}
EXAMPLE {
    memmap -addr 0xfc000000 -size 0x1000 -flags 3
        Add the memory region 0xfc000000 - 0xfc000fff to target's memory map
        Read/Write accesses are allowed to this region

    memmap -addr 0xfc000000 -clear
        Remove the previously added memory region at 0xfc000000 from target's
        memory map
}
}

    proc dow {args} {
	variable memmaptable
	variable force_mem_accesses
	variable profile_config
	variable mb_profile_config

	set options {
	    {data "download binary file"}
	    {clear "clear uninitialized data (bss)"}
	    {keepsym "keep old symbol files" {default 0}}
	    {chunksize "chuck size" {default 0x4000 args 1}}
	    {force "override access protection"}
	    {set-entry "set PC register to entry point" {args 1}}
	    {auto-stop "automatically stop before download" {args 1}}
	    {relocate-section-map "relocate program section map" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] == 0 || [llength $args] > 2 } {
	    error "wrong # args: should be \"dow ?options? file ?address?\""
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	set params(file) [file normalize [lindex $args 0]]
	if { [llength $args] > 1 } {
	    if { !$params(data) } {
		error "address is only applicable with -data option"
	    }
	    set params(address) [lindex $args 1]
	    checkint $params(address)
	}

	if { ![info exists params(set-entry)] } {
	    if { $params(data) } {
		set params(set-entry) 0
	    } else {
		set params(set-entry) 1
	    }
	}

	if { ![info exists params(auto-stop)] } {
	    if { $params(data) } {
		set params(auto-stop) 0
	    } else {
		set params(auto-stop) 1
	    }
	}

	set arg [array get params]
	dict set arg err ""
	dict set arg numreq 0
	dict set arg curpos 0
	dict set arg curaction 0
	dict set arg actions [list [list init] [list open] [list progress]]
	dict set arg current_bytes 0
	dict set arg total_bytes 0
	dict set arg force [expr $params(force) | $force_mem_accesses]
	dict set arg profile_config $profile_config
	set argvar [::tcf::sync_eval [list set_arg $arg]]

	set sh_list [::tcf::cache_eval_with_progress $params(chan) [list download_cache_client $argvar] {
	    apply {{info} {
		switch -- [lindex $info 0] {
		    "info" {
			puts -nonewline "\r[lindex $info 1]"
		    }
		    "warning" {
			puts "\n[lindex $info 1]"
		    }
		    "data" {
			puts -nonewline "\r[lindex $info 1] of [lindex $info 2] complete"
		    }
		    "done" {
			puts "\n[lindex $info 1]"
		    }
		}
		flush stdout
		::xsdb::abort_check
	    }}}]
	if { !$params(data) } {
	    set map_table {}
	    if { [dict exists $memmaptable $params(chan) $params(ctx)] } {
	        set map_table [dict get $memmaptable $params(chan) $params(ctx)]
	    }

	    set data_list {}
	    foreach data [dict_get_safe $map_table $params(file)] {
		if { [dict_get_safe $data auto_sym] != 1 && [dict_get_safe $data auto_sec] != 1 } {
		    lappend data_list $data
		}
	    }
	    dict set map_table $params(file) $data_list
	    if { [info exists params(relocate-section-map)] } {
		foreach sh $sh_list  {
		    set flags [dict get $sh flags]
		    set size [dict get $sh size]
		    if { [expr {$flags & 0x7}] && $size } {
			set addr [expr [dict get $sh addr] + $params(relocate-section-map)]
			set name [dict get $sh name]
			set data [dict create Addr $addr Size $size Flags $flags FileName $params(file) SectionName $name Offs 0 ID $params(file) auto_sec 1]
			dict lappend map_table $params(file) $data
		    }
		}
	    }
	    set data [dict create Addr 0 Size 0 Flags 0 FileName $params(file) Offs 0 ID $params(file) auto_sym 1]
	    dict lappend map_table $params(file) $data
	    dict for {id maps} $map_table {
		if { $params(file) == $id } continue;
		set data_list {}
		foreach data $maps {
		    if { $params(keepsym) || [dict_get_safe $data auto_sym] != 1 } {
			lappend data_list $data
		    }
		}
		if { [llength $data_list] == 0 } {
		    set map_table [dict remove $map_table $id]
		} else {
		    dict set map_table $id $data_list
		}
	    }
	    dict set memmaptable $params(chan) $params(ctx) $map_table
	    update_memory_map $params(chan) $params(ctx)
	}
	# Set the elf file for MB profiling
	dict set mb_profile_config elf $params(file)
	return
    }
    namespace export dow
    setcmdmeta dow categories {download}
    setcmdmeta dow brief {Download ELF and binary file to target}
    setcmdmeta dow description {
SYNOPSIS {
    dow [options] <file>
        Download ELF file <file> to active target

    dow -data <file> <addr>
        Download binary file <file> to active target address
        specified by <addr>
}
OPTIONS {
    -clear
        Clear uninitialized data (bss)

    -keepsym
        Keep previously downloaded elfs in the list of symbol files. Default
        behavior is to clear the old symbol files while downloading an elf

    -force
        Overwrite access protection. By default accesses to reserved and invalid
        address ranges are blocked

    -relocate-section-map <addr>
        Relocate the address map of the program sections to <addr>. This option
        should be used when the code is self-relocating, so that the debugger
        can find debug symbol info for the code. <addr> is the relative address,
        to which all the program sections are relocated
}
RETURNS {
    Nothing
}
}

    proc elfverify {args} {
	puts "\nNote:: \"elfverify\" command is Deprecated. Use \"verify\" command"
	return [verify {*}$args]
    }
    namespace export elfverify

    proc verify {args} {
	variable memmaptable
	variable force_mem_accesses

	set options {
	    {chunksize "chuck size" {default 0x4000 args 1}}
	    {data "verify binary data file"}
	    {force "override access protection"}
	    {auto-stop "automatically stop before download" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] == 0 || [llength $args] > 2 } {
	    error "wrong # args: should be \"dow ?options? file ?address?\""
	}

	if { [llength $args] > 1 } {
	    if { !$params(data) } {
		error "address is only applicable with -data option"
	    }
	    set params(address) [lindex $args 1]
	    checkint $params(address)
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	set params(file) [file normalize [lindex $args 0]]

	if { ![info exists params(auto-stop)] } {
	    set params(auto-stop) 1
	}

	set arg [array get params]
	dict set arg err ""
	dict set arg numreq 0
	dict set arg curpos 0
	dict set arg curaction 0
	dict set arg sections {}
	dict set arg cursection 0
	dict set arg current_bytes 0
	dict set arg total_bytes 0
	dict set arg be 0
	dict set arg force [expr $params(force) | $force_mem_accesses]

	dict lappend arg actions {
	    if { $curpos == 0 } {
		incr curpos
	    }
	    set cache_misses [get_context_datatypes targets $chan {} {RunControl:context RunControl:state Memory:context} $ctx 1]
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }

	    set rc [dict get $targets $ctx RunControl:context]
	    set mc [dict get $targets $ctx Memory:context]
	    if { [dict exists $mc BigEndian] && [dict get $mc BigEndian] != 0 } {
		dict set arg be 1
	    }
	    if { ${auto-stop} } {
		set state [dict get $targets $ctx RunControl:state]
		if { [lindex $state 0] != "" } {
		    error [lindex $state 0]
		}
		if { ![lindex $state 1] } {
		    ::tcf::send_command $chan RunControl suspend [list download_suspend_callback $argvar]
		    ::tcf::write $chan "s" [list $ctx]
		    incr numreq
		    cache wait
		}
	    }

	    if { [dict exists $rc ProcessID] } {
		set memctx [dict get $rc ProcessID]
	    } else {
		set memctx $ctx
	    }
	    dict set arg memctx $memctx

	    incr curaction
	    set curpos 0
	}

	dict lappend arg actions {
	    set total_bytes 0
	    if { !$data } {
		# Open ELF file
		set f [::xsdb::elf::open $file]
		dict set arg f $f

		foreach ph [$f get_phlist] {
		    dict with ph {
			if { $type == 1 } {
			    if { $filesz > 0 } {
				lappend sections [list $offset $paddr $filesz]
				incr total_bytes $filesz
			    }
			}
		    }
		}
	    } else {
		# Open data file
		set f [::open $file rb]
		dict set arg f $f
		seek $f 0 end
		lappend sections [list 0 $address [tell $f]]
		incr total_bytes [tell $f]
		seek $f 0
	    }
	    incr curaction
	    set curpos 0
	}

	dict lappend arg actions {
	    if { $numreq > 0 } {
		cache wait
	    }
	    set ts [clock milliseconds]
	    dict set arg start_time $ts
	    dict set arg progress_time $ts
	    if { [catch {eval_progress [list info [format "%3u%% %4uMB %5.1fMB/s  %s" 0 0 0 "??:?? ETA"]]} msg] } {
		dict set arg err $msg
		break
	    }
	    incr curaction
	}

	dict lappend arg actions {
	    set offset [expr [lindex $sections $cursection 0] + $curpos]
	    set addr [expr [lindex $sections $cursection 1] + $curpos]
	    set endpos [lindex $sections $cursection 2]
	    set size $chunksize
	    if { $endpos != "" && $size > $endpos - $curpos } {
		set size [expr $endpos - $curpos]
	    }

	    set mode 3
	    if { $force } {
		set mode [expr $mode | 4]
	    }
	    ::tcf::send_command $chan Memory get [list verify_data_callback $argvar $addr $offset $size]
	    ::tcf::write $chan "siiii" [list $memctx $addr 1 $size $mode]
	    incr numreq
	    incr curpos $size
	    if { $curpos == $endpos } {
		incr cursection
		set curpos 0
	    }
	    if { $cursection >= [llength $sections] } {
		incr curaction
	    }
	}

	dict set arg result {
	    if { [dict exists $arg f] } {
		if { !$data } {
		    $f close
		} else {
		    close $f
		}
	    }
	}

	process_tcf_actions $arg ::xsdb::print_progress
    }
    namespace export verify
    setcmdmeta verify categories {download}
    setcmdmeta verify brief {Verify if ELF/binary file is downloaded correctly to target}
    setcmdmeta verify description {
SYNOPSIS {
    verify [options] <file>
        Verify if the ELF file <file> is downloaded correctly to active target

    verify -data <file> <addr>
        Verify if the binary file <file> is downloaded correctly to active
        target address specified by <addr>
}
OPTIONS {
    -force
        Overwrite access protection. By default accesses to reserved and invalid
        address ranges are blocked
}
RETURNS {
    Nothing, if successful.
    Error string, if the memory address can't be accessed or if there is a mismatch
}
}

    proc mask_poll {addr mask {expected ""} {sleep 0} {timeout 10000}} {
	set count 1
	checkint $sleep
	checkint $timeout
	while { $count < $timeout } {
	    set curval [mrd -value $addr]
	    set maskedval [expr {$curval & $mask}]
	    if { $expected == "" } {
		if { $maskedval != 0 } {
		    return
		}
	    } else {
		checkint $expected
		if { $maskedval == $expected } {
		    return
		}
		if { $sleep } after $sleep;
	    }
	    incr count
	}
	error "Timeout Reached. Mask poll failed at ADDRESS: $addr MASK: $mask"
    }
    namespace export mask_poll
    setcmdmeta mask_poll categories {memory}
    setcmdmeta mask_poll brief {Read an address and poll the bit specified by mask}
    setcmdmeta mask_poll description {
SYNOPSIS {
    mask_poll <addr> <mask>
        Read the address specified by addr and poll until the bit specified by
        mask is set to 1 or until timeout. timeout is set to 10000 iterations
        and is not user configutable
}
NOTE {
    This is an helper command for initializing the PS through ps*_init.tcl and
    is not recommended for external usage
}
RETURNS {
    Nothing, if successful.
    Error on timeout or if the memory address can't be accessed.
}
}

    proc mask_write {addr mask data} {
	variable mask_write_warnings
	set addr [expr $addr & ~0x3]
	if { [catch {set curval [mrd -value $addr]} msg] } {
	    if { [string first "Cannot read write-only register" $msg] != -1 } {
		if { $mask_write_warnings == 1 } {
		    set mask_write_warnings 0
		    append msg "\n\t Reading write-only registers can lead to unpredictable behavior."
		    append msg "\n\t Use mwr instead of mask_write to write to write-only registers."
		    append msg "\n\t Further warnings will be suppressed"
		    puts "WARNING: $msg"
		}
		set curval [mrd -force -value $addr]
	    } else {
		error $msg
	    }
	}
	set newval [expr {($curval & ~$mask) | ($data & $mask)}]
	mwr $addr $newval
    }
    namespace export mask_write
    setcmdmeta mask_write categories {memory}
    setcmdmeta mask_write brief {Read, modify and write an address}
    setcmdmeta mask_write description {
SYNOPSIS {
    mask_write <addr> <mask>
        Read the address specified by addr, clear the bits specified by mask,
        set the bits specified by data and write back the result to addr
}
NOTE {
    This is an helper command for initializing the PS through ps*_init.tcl and
    is not recommended for external usage
}
RETURNS {
    Nothing, if successful.
    Error string, if the memory address can't be accessed.
}
}

    proc init_ps { init_data } {
	variable force_mem_accesses

	set saved_mode $force_mem_accesses
	set force_mem_accesses 1
	foreach action [split $init_data "\n"] {
	    set cmd [lindex $action 0]
	    switch -- $cmd {
		"mask_write" -
		"mask_poll" {
		    set args [lreplace $action 0 0]
		    eval $cmd {*}$args
		}
		"mask_delay" {
		    after [lindex $action 2]
		}
	    }
	}
	set force_mem_accesses $saved_mode
	return
    }
    namespace export init_ps
    setcmdmeta init_ps categories {memory}
    setcmdmeta init_ps brief {Run PS initialization sequence}
    setcmdmeta init_ps description {
SYNOPSIS {
    init_ps <init_data>
        Initialize PS by running initalization sequence specified by init_data.
        The init_data contains mask_write, mask_poll and mask_delay commands in
        meta data format. mask_delay adds delay in milli seconds
}
EXAMPLE {
    set init_data {
        mask_write 0 0x00001FFF 0x00000001
        mask_delay 1
        mask_poll 4 1 1
    }
    init_ps [subst {$init_data}]
}
NOTE {
    This is an helper command for initializing the PS through ps*_init.tcl and
    is not recommended for external usage
}
RETURNS {
    Nothing, if successful.
    Error string, if the memory address can't be accessed.
}
}

    proc rst { args } {
	set options {
	    {processor "processor reset"}
	    {cores "processor group reset"}
	    {dap "dap reset"}
	    {system "system reset"}
	    {srst "system reset through jtag cable"}
	    {jtag-timeout "timeout for blocking on JTAG device" {default 30000 args 1}}
	    {timeout "timeout for blocking" {default 100 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { $params(processor) + $params(cores) + $params(dap) + $params(system) + $params(srst) > 1 } {
	    error "conflicting reset type, use only one of -processor, -cores, -dap, -system or -srst"
	}

	set chan [getcurchan]
	set ctx [getcurtarget]

	if { $params(srst) } {
	    if { [catch {
		set targets [::xsdb::get_debug_targets $chan]
		set rc [dict get $targets $ctx RunControl:context]
		set jtaggroup [dict get [lindex $rc 1] JtagGroup]
		set rc [dict get $targets $jtaggroup RunControl:context]
		set node [dict get [lindex $rc 1] JtagNodeID]

		#Find node for scan chain and check capabilities
		set nodes [::tcf::cache_eval $chan [list get_jtag_nodes $chan]]
		set nc [dict get $nodes $node Jtag:context]
		while { [dict exists [lindex $nc 1] ParentID] } {
		    set node [dict get [lindex $nc 1] ParentID]
		    set nc [dict get $nodes $node Jtag:context]
		}
		set cap [dict get $nodes $node Jtag:capabilities]
		if { [dict exists [lindex $cap 1] Pins] } {
		    set pins [dict get [lindex $cap 1] Pins]
		} else {
		    set pins {}
		}
		if { [lsearch $pins SRST] < 0 } {
		    error "Jtag scan chain does not support SRST pin"
		}
		::tcf::send_command $chan Jtag sequence "so{}a{a{ssi}a{si}a{ssi}}B" eB [list $node {} {{setPin SRST 0} {delay 10000} {setPin SRST 1}} {}]
	    } msg opt] } {
		error "srst not supported for target"
	    }
	} else {
	    if { $params(processor) } {
		set type "core"
	    } elseif { $params(cores) } {
		set type "cpu"
	    } elseif { $params(dap) } {
		set type "dap"
	    } else {
		set type "system"
	    }
	    # get supported reset types
	    set rst_types [dict get [lindex [::tcf::send_command $chan XilinxReset getCapabilities s eo{} [list ""]] 1] "Types"]
	    if { [lsearch $rst_types $type] == -1 } {
		error "$args not supported for target. supported reset types : $rst_types"
	    }
	    if { [catch {set jc [get_target_jtag_context $chan $ctx]}] } {
		set jc {}
	    }
	    ::tcf::send_command $chan XilinxReset reset sso{[dict create suspend b]} e [list $ctx $type [dict create suspend 1]]

	    # Wait for JTAG device to become active incase reset
	    # caused it to be temporarily disabled.
	    if { [dict exists $jc ID] } {
		set jtagid [dict get $jc ID]
		set start [clock milliseconds]
		set end $start
		while { [expr $end - $start] < $params(jtag-timeout) } {
		    set jc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $jtagid Jtag:context]] 1]
		    if { [dict exists $jc isActive] && [dict get $jc isActive] } break
		    after 10
		    set end [clock milliseconds]
		}
	    }

	    # Wait for contexts to stop
	    wait_for_event $chan $ctx 1 $params(timeout)
	}
	return
    }
    namespace export rst
    setcmdmeta rst categories {reset}
    setcmdmeta rst brief {Target Reset}
    setcmdmeta rst description {
SYNOPSIS {
    rst [options]
        Reset the active target
}
OPTIONS {
    -processor
        Reset the active processor target.

    -cores
        Reset the active processor group. This reset type is supported
        only on Zynq. A processor group is defined as a set of processors
        and on-chip peripherals like OCM.

    -system
        Reset the active System.

    -srst
        Generate system reset for active target. With JTAG, this is done by
        generating an active low pulse on the designated output pin (SRST pin)
        of supported JTAG cables and modules, associated with the active target.
        For Digilent JTAG-SMT2 modules the GPIO2 pin is used for SRST.
        For Xilinx Platform USB II, HALT pin is used for SRST.
}
RETURNS {
    Nothing, if reset if successful.
    Error string, if reset is unsupported.
}
}

    proc process {args} {
	if { [llength $args] == 0 } {
	    error "wrong # of args: should be \"process \[sub command\]\""
	}
	set subcmds {list attach detach start}
	set chan [getcurchan]

	set subcmd [lsearch -all -inline -glob $subcmds "[lindex $args 0]*"]
	switch -- $subcmd {
	    "list" {
		if { [llength $args] != 1 } {
		    error "wrong # of args: should be \"process list\""
		}
		set procs [::tcf::cache_eval $chan [list get_processes $chan]]
		::xsdb::print_processes $procs
	    }

	    "attach" {
		if { [llength $args] != 2 } {
		    error "wrong # of args: should be \"process attach \[id\]\""
		}
		set procs [::tcf::cache_eval $chan [list get_processes $chan]]
		if { ![dict exists $procs process_ctx_map [lindex $args 1]] } {
		    error "unknown id \"[lindex $args 1]\""
		}
		set ctx [dict get $procs process_ctx_map [lindex $args 1]]
		if { [dict exists $procs $ctx ProcessesV1:context] } {
		    ::tcf::send_command $chan ProcessesV1 attach s e [list $ctx]
		} else {
		    ::tcf::send_command $chan Processes attach s e [list $ctx]
		}
	    }

	    "detach" {
		if { [llength $args] != 2 } {
		    error "wrong # of args: should be \"process detach \[id\]\""
		}
		set procs [::tcf::cache_eval $chan [list get_processes $chan]]
		if { ![dict exists $procs process_ctx_map [lindex $args 1]] } {
		    error "unknown id \"[lindex $args 1]\""
		}
		set ctx [dict get $procs process_ctx_map [lindex $args 1]]
		if { [dict exists $procs $ctx ProcessesV1:context] } {
		    ::tcf::send_command $chan ProcessesV1 detach s e [list $ctx]
		} else {
		    ::tcf::send_command $chan Processes detach s e [list $ctx]
		}
	    }

	    "start" {
		set args [lrange $args 1 end]
		set options {
		    {dir "working directory" {default "" args 1}}
		    {env "environment variables" {default {} args 1}}
		    {exe "executable" {args 1}}
		    {attach-children "attach to children"}
		    {stop-at-entry "stop at entry"}
		    {stop-at-main "stop at main"}
		}
		array set params [::xsdb::get_options args $options 0]

		if { ![info exists params(exe)] } {
		    set params(exe) [lindex $args 0]
		}

		set services [::tcf::sync_eval [list ::tcf::get_services $chan]]
		if { [lsearch $services ProcessesV1] >= 0 } {
		    set start_params {}
		    if { $params(attach-children) || $params(stop-at-entry) || $params(stop-at-main) } {
			dict set start_params Attach 1
			dict set start_params AttachChildren $params(attach-children)
			dict set start_params StopAtEntry $params(stop-at-entry)
			dict set start_params StopAtMain $params(stop-at-main)
		    }
		    ::tcf::send_command $chan ProcessesV1 start "ssa{s}a{s}o{Attach b AttachChildren b StopAtEntry b StopAtMain b UseTerminal b SigDontStop a{i} SigDontPass a{i}}" "eo{}" \
			[list $params(dir) $params(exe) $args $params(env) $start_params]
		} else {
		    if { $params(attach-children) || $params(stop-at-main) } {
			error "options -attach-children and -stop-at-main not supported for this target"
		    }
		    ::tcf::send_command $chan Processes start "ssa{s}a{s}b" "eo{}" \
			[list $params(dir) $params(exe) $args $params(env) $params(stop-at-entry)]
		}
	    }

	    default {
		if { $subcmd == "" } {
		    set subcmd $subcmds
		}
		error "bad option \"[lindex $args 0]\": must be [join $subcmd {, }]"
	    }
	}
    }
    namespace export process

    proc fpgaold {args} {
	set options {
	    {file "bit file" {args 1}}
	    {partial "partial config"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { ![info exists params(file)] } {
	    if { [llength $args] > 0 } {
		set params(file) [lindex $args 0]
		set args [lrange $args 1 end]
	    } else {
		error "no bit file specified"
	    }
	}

	if { [llength $args] != 0 } {
	    error "wrong # args: should be \"fpga ?options?\""
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]

	set arg [array get params]
	dict set arg err ""
	dict set arg numreq 0
	set argvar [::tcf::sync_eval [list set_arg $arg]]

	::tcf::cache_eval_with_progress $params(chan) [list fpga_config_cache_client $argvar] {
	    apply {{info} {
		switch -- [lindex $info 0] {
		    "info" {
			puts -nonewline "\r[lindex $info 1]"
		    }
		    "warning" {
			puts "\r[lindex $info 1]"
		    }
		    "percent" {
			puts -nonewline "\r[lindex $info 1]% complete"
		    }
		    "done" {
			puts ""
		    }
		}
		flush stdout
		::xsdb::abort_check
	    }}}
    }

    proc fpga {args} {
	variable curtarget

	set options {
	    {file "bit file" {args 1}}
	    {partial "partial config"}
	    {maxreq "max number pending requests" {default 16 args 1}}
	    {chunksize "chuck size" {default 0x4000 args 1}}
	    {state "return done status"}
	    {config-status "return config status"}
	    {ir-status "return IR capture status"}
	    {boot-status "return boot history status"}
	    {timer-status "return watchdog timer status"}
	    {cor0-status "return configuration option 0 status"}
	    {cor1-status "return configuration option 1 status"}
	    {wbstar-status "return warm boot start address status"}
	    {no-revision-check "don't check bitstream vs silicon revision"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set optcnt [expr { $params(state) + $params(config-status) +
			   $params(ir-status) + $params(boot-status) +
			   $params(timer-status) + $params(cor0-status) +
			   $params(cor1-status) + $params(wbstar-status) }]
	if { $optcnt > 1 } {
	    error "conflicting options specified"
	}

	if { ![info exists params(file)] && $optcnt == 0 } {
	    if { [llength $args] > 0 } {
		set params(file) [lindex $args 0]
		set args [lrange $args 1 end]
	    } else {
		error "no bit file specified"
	    }
	}

	if { [llength $args] != 0 } {
	    error "wrong # args: should be \"fpga ?options?\""
	}

	set arg [array get params]
	dict set arg chan [getcurchan]
	dict set arg ctx $curtarget
	dict set arg current_bytes 0
	dict set arg total_bytes 0
	dict set arg transfers {}
	dict set arg aborting ""
	dict set arg cancelled 0
	dict set arg state ""

	# Find the 1st FPGA, if the current context is not FPGA and
	# map target context to jtag context
	dict lappend arg actions {
	    lassign [get_debug_targets_cache_client $chan] targets cache_misses
	    dict for {ctx2 ctx2data} $targets {
		if { [catch {
		    set rc [lindex [dict get $ctx2data RunControl:context] 1]
		    if { [dict exists $rc JtagDeviceID] } {
			dict set targets $ctx2 JtagDevice:properties [lindex [get_ctx_data $chan [dict get $rc JtagDeviceID] JtagDevice:properties] 1]
		    }
		} msg] } {
		    if { $msg == $::cache_miss_err } {
			incr cache_misses
		    }
		}
	    }
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }

	    if { ![dict exists $targets $ctx JtagDevice:properties] ||
		 ![dict exists [dict get $targets $ctx JtagDevice:properties] reg.jprogram] } {
		set fpgas {}
		dict for {ctx2 ctx2data} $targets {
		    if { [dict exists $ctx2data JtagDevice:properties] &&
			 [dict exists [dict get $ctx2data JtagDevice:properties] reg.jprogram] } {
			lappend fpgas $ctx2
		    }
		}
		if { [llength $fpgas] == 1 } {
		    set ctx [lindex $fpgas 0]
		} else {
		    if { [llength $fpgas] == 0 } {
			set err "No supported FPGA device found"
		    } else {
			set ids {}
			foreach ctx2 $fpgas {
			    lappend ids [dict get $targets $ctx2 target_id]
			}
			set ids [lsort $ids]
			set err "Multiple FPGA devices found, please use targets command to select one of: [join $ids {, }]"
		    }
		    break
		}
	    }

	    set rc [lindex [dict get $targets $ctx RunControl:context] 1]
	    set jtaggroup [dict get $rc JtagGroup]
	    set rc [lindex [dict get $targets $jtaggroup RunControl:context] 1]
	    set node [dict get $rc JtagNodeID]
	    dict set arg node $node
	    incr curaction
	}

	if { $params(state) } {
	    dict lappend arg actions {
		send_action_command $argvar Xicom_v1.00 getConfigStatus s * [list $node] {
		    if { [lindex $data 0] != "" } {
			error [lindex $data 0]
		    }
		    if { [llength $data] != 4 } {
			error [list "unexpected config status reply:" $data]
		    }
		    set status [lindex $data 2]
		    set names [split [lindex $data 3] ,]
		    set index [lsearch -exact $names {END OF STARTUP (EOS) STATUS}]
                    set res "FPGA is not configured"
		    if { $index >= 0 && [expr $status & (1 << $index)] != 0 } {
			set res "FPGA is configured"
                    }
		    dict set arg state $res
		}
		incr numreq 1
		incr curaction
	    }

	    dict set arg result {
		set state
	    }
	    return [process_tcf_actions $arg]
	}

	if { $optcnt > 0 } {
	    dict lappend arg actions {
		if { ${config-status} } {
		    set cmd getConfigStatus
		} elseif { ${ir-status} } {
		    set cmd getIRStatus
		} elseif { ${boot-status} } {
		    set cmd getBootStatus
		} elseif { ${timer-status} } {
		    set cmd getTimerReg
		} elseif { ${cor0-status} } {
		    set cmd getCOR0
		} elseif { ${cor1-status} } {
		    set cmd getCOR1
		} elseif { ${wbstar-status} } {
		    set cmd getWBSTAR
		} else {
		    error "unknown status option"
		}
		send_action_command $argvar Xicom_v1.00 $cmd s * [list $node] {
		    if { [lindex $data 0] != "" } {
			error [lindex $data 0]
		    }
		    if { [dict get $arg ir-status] } {
			set data [lrange $data 0 end-1]
			set len [expr {([lindex $data 1]+7)/8 }]
			for {set i 1} {$i < $len} {incr i} {
			    set status [lindex $data 2]
			    set status [expr {([lindex $data 3] << ($i*8)) + $status}]
			    set data [lreplace $data 2 3 $status]
			}
		    }
		    if { [llength $data] != 4 } {
			error [list "unexpected config status reply:" $data]
		    }
		    set bits [lindex $data 1]
		    set status [lindex $data 2]
		    if { [dict get $arg config-status] } {
			set regname "CONFIG STATUS"
		    } elseif { [dict get $arg ir-status] } {
			set regname "IR STATUS"
		    } elseif { [dict get $arg boot-status] } {
			set regname "BOOT STATUS"
		    } elseif { [dict get $arg timer-status] } {
			set regname "TIMER STATUS"
		    } elseif { [dict get $arg cor0-status] } {
			set regname "COR0 STATUS"
		    } elseif { [dict get $arg cor1-status] } {
			set regname "COR1 STATUS"
		    } elseif { [dict get $arg wbstar-status] } {
			set regname "WBSTAR STATUS"
		    } else {
			error "unknown status option"
		    }
		    set res "$regname: $status"
		    set names [split [lindex $data 3] ,]
		    set props {}
		    set bitno 0
		    set mask 1
		    set value 0
		    set startbit $bitno
		    set last_name {}
		    foreach name $names {
			set name [string trim $name]
			if { $mask > 1 && $last_name != $name } {
			    set endbit [expr {$bitno - 1}]
			    if { $startbit == $endbit } {
				dict set props "$last_name (Bits \[$startbit\])" $value
			    } else {
				dict set props "$last_name (Bits \[$endbit:$startbit\])" $value
			    }
			    set mask 1
			    set value 0
			    set startbit $bitno
			}
			if { $status & 1 } {
			    set value [expr {$value | $mask}]
			}
			incr bitno
			set status [expr {$status >> 1}]
			set mask [expr {$mask * 2}]
			set last_name $name
		    }
		    if { $mask > 1 } {
			set endbit [expr {$bitno - 1}]
			if { $startbit == $endbit } {
			    dict set props "$name (Bits \[$startbit\])" $value
			} else {
			    dict set props "$name (Bits \[$endbit:$startbit\])" $value
			}
		    }
		    set max_len 0
		    dict for {name value} $props {
			if { $max_len < [string length $name] } {
			    set max_len [string length $name]
			}
		    }
		    dict for {name value} $props {
			if { $res != "" } {
			    append res "\n"
			}
			append res [format "  %*s: %d" $max_len $name $value]
		    }
		    dict set arg status $res
		}
		incr numreq 1
		incr curaction
	    }
	    dict set arg result {
		set status
	    }
	    return [process_tcf_actions $arg]
	}

	# Open bit file
	dict lappend arg actions {
	    set f [::open $file rb]
	    dict set arg f $f
	    set total_bytes [::file size $file]
	    if { $total_bytes == 0 } {
		set err "empty bitstream file"
	    }
	    incr curaction
	}

	# Read the bitstream properties
	dict lappend arg actions {
	    set len 1024
	    if { $total_bytes < 1024 } {
		set len $total_bytes
	    }
	    set data [::read $f $len]
	    set len [string length $data]
	    seek $f 0

	    send_action_command $argvar Xicom_v1.00 getBitfileProperties siB eA [list $node $len $data] {
		set props [lindex $data 1]
		if { [dict get $props ISBITFILE] } {
		    if { [dict get $props IS_PARTIAL] } {
			dict set arg partial 1
		    }
		    if { ![dict get $props ISCOMPATIBLE] } {
			dict set arg err "bitstream is not compatible with the target"
		    }
		    if { ![dict get $arg {no-revision-check}] && [dict exists $props IS_REVISION_COMPATIBLE] && ![dict get $props IS_REVISION_COMPATIBLE] } {
			dict set arg err "bitstream is not compatible with the target revision"
		    }
		} elseif { [catch {eval_progress [list warning "unable to parse bitstream header. cannot determine if the\n\
                \rbitstream is partial or compatible with the jtag device\n"]} msg] } {
		    dict set arg err $msg
		    break
		}
	    }
	    incr numreq 1
	    incr curaction
	}

	# Initialize fpga for programming
	dict lappend arg actions {
	    if { $numreq > 0 } {
		cache wait
	    }
	    if { !$partial } {
		if { [catch {eval_progress [list info "initializing"]} msg] } {
		    dict set arg err $msg
		    break
		}

		send_action_command $argvar Xicom_v1.00 configProg s ei [list $node] {
		    if { [lindex $data 1] != 1 } {
			dict set arg err "fpga initialization failed"
		    }
		}
		incr numreq 1
	    }
	    incr curaction
	}

	# Start progress
	dict lappend arg actions {
	    if { $numreq > 0 } {
		cache wait
	    }
	    set ts [clock milliseconds]
	    dict set arg start_time $ts
	    dict set arg progress_time $ts
	    if { [catch {eval_progress [list info [format "%3u%% %4uMB %5.1fMB/s  %s" 0 0 0 "??:?? ETA"]]} msg] } {
		dict set arg err $msg
		break
	    }
	    incr curaction
	}

	# Configure fpga
	dict lappend arg actions {
	    if { $aborting != "" } {
		if { !$cancelled } {
		    set cancelled 1
		    send_action_command $argvar Xicom_v1.00 cancel s ei [list $node]
		    incr numreq 1
		}
		if { $numreq > 0 } {
		    cache wait
		}
		set err $aborting
		break
	    }
	    set data [::read $f $chunksize]
	    set len [string length $data]
	    if { $len == 0 } {
		set err "premature end of file"
		incr curaction
		break
	    }
	    send_action_command $argvar Xicom_v1.00 configIn siiiB ei [list $node $current_bytes $total_bytes $len $data] {
		if { [lindex $data 1] == 1 } {
		    set transfers [dict get $arg transfers]
		    foreach {cb len ts} [lindex $transfers 0] break
		    dict set arg transfers [lrange $transfers 1 end]

		    set progress_delta [expr {$ts - [dict get $arg progress_time]}]
		    set complete [expr {100 * $cb / [dict get $arg total_bytes]}]
		    set remaining_bytes [expr {[dict get $arg total_bytes] - $cb}]
		    if { $progress_delta > 500 || $remaining_bytes == 0 } {
			dict set arg progress_time $ts
			set total_time [expr {$ts - [dict get $arg start_time]}]
			set throughput [expr {$cb / ($total_time / 1000.0)}]
			if { $remaining_bytes == 0 } {
			    set eta [format "%02u:%02u    " [expr {$total_time / 1000 / 60}] [expr {$total_time / 1000 % 60}]]
			} elseif { $total_time > 3000 && $throughput > 0 } {
			    set remaining_time [expr {int($remaining_bytes / $throughput)}]
			    set eta [format "%02u:%02u ETA" [expr {$remaining_time / 60}] [expr {$remaining_time % 60}]]
			} else {
			    set eta [format "??:?? ETA" ]
			}
			if { [catch {eval_progress [list info [format "%3u%% %4uMB %5.1fMB/s  %s" $complete [expr {$cb / 1048576}] [expr {$throughput / 1048576}] $eta]]} msg] } {
			    dict set arg aborting $msg
			}
		    }
		}
	    }
	    incr numreq 1
	    incr current_bytes $len
	    lappend transfers [list $current_bytes $len [clock milliseconds]]
	    if { $total_bytes == $current_bytes } {
		incr curaction
	    }
	}

	# Start the configuration
	dict lappend arg actions {
	    send_action_command $argvar Xicom_v1.00 configStart s ei [list $node] {
		if { [lindex $data 0] != "" } {
		    error [lindex $data 0]
		}
                dict set arg init_status [lindex $data 1]
            }
	    incr numreq 1
	    incr curaction
	}

	# Check the DONE PIN
	dict lappend arg actions {
	    send_action_command $argvar Xicom_v1.00 getConfigStatus s * [list $node] {
		if { [lindex $data 0] != "" } {
		    error [lindex $data 0]
		}
		if { [llength $data] != 4 } {
		    error [list "unexpected config status reply:" $data]
		}
		set status [lindex $data 2]
		set names [split [lindex $data 3] ,]
		set index [lsearch -exact $names {END OF STARTUP (EOS) STATUS}]
		if { $index >= 0 } {
		    if { [expr $status & (1 << $index)] == 0 } {
			dict set arg err "fpga configuration failed. DONE PIN is not HIGH"
		    }
		} elseif { [dict get $arg init_status] != 1 } {
		    dict set arg err "fpga configuration failed. INIT PIN is not HIGH"
		}
	    }
	    incr numreq 1
	    incr curaction
	}

	dict set arg result {
	    if { [info exist f] } {
		::close $f
	    }
	}

	process_tcf_actions $arg ::xsdb::print_progress
    }
    namespace export fpga
    setcmdmeta fpga categories {download}
    setcmdmeta fpga brief {Configure FPGA}
    setcmdmeta fpga description {
SYNOPSIS {
    fpga <bitstream-file>
        Configure FPGA with given bitstream

    fpga [options]
        Configure FPGA with bitstream specified options, or
        read FPGA state
}
NOTE {
    If no target is selected or if the current target is not a
    supported FPGA device, and only one supported FPGA device is found
    in the targets list, then this device will be configured.
}
OPTIONS {
    -file <bitstream-file>
        Specify file containing bitstream

    -partial
        Configure FPGA without first clearing current configuration.
        This options should be used while configuring partial bitstreams
        created before 2014.3 or any partial bitstreams in binary format

    -state
        Return whether the FPGA is configured

    -config-status
        Return configuration status

    -ir-status
        Return IR capture status

    -boot-status
        Return boot history status

    -timer-status
        Return watchdog timer status

    -cor0-status
        Return configuration option 0 status

    -cor1-status
        Return configuration option 1 status

    -wbstar-status
        Return warm boot start address status
}
RETURNS {
    Depends on options used.

    -file, -partial
        Nothing, if fpga is configured, or an error if the configuration failed.

    One of the other options
        Configutation value.
}
}

    proc fpgatest {args} {
	set options {
	    {file "bit file" {args 1}}
	    {partial "partial config"}
	    {maxreq "max number pending requests" {default 16 args 1}}
	    {chunksize "chuck size" {default 0x4000 args 1}}
	}
	array set params [::xsdb::get_options args $options 0]

	if { ![info exists params(file)] } {
	    if { [llength $args] > 0 } {
		set params(file) [lindex $args 0]
		set args [lrange $args 1 end]
	    } else {
		error "no bit file specified"
	    }
	}

	if { [llength $args] != 0 } {
	    error "wrong # args: should be \"fpga ?options?\""
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]

	set actions {}
	lappend actions [list init]
	lappend actions [list open]
	lappend actions [list lock]
	if { !$params(partial) } {
	    lappend actions [list fpga_init]
	}
	lappend actions [list fpga_config]
	lappend actions [list fpga_status]

	set arg [array get params]
	dict set arg err ""
	dict set arg numreq 0
	dict set arg curpos 0
	dict set arg curaction 0
	dict set arg actions $actions
	dict set arg current_bytes 0
	dict set arg total_bytes 0
	dict set arg has_lock 0
	set argvar [::tcf::sync_eval [list set_arg $arg]]

	::tcf::cache_eval_with_progress $params(chan) [list fpgatest_config_cache_client $argvar] {
	    apply {{info} {
		switch -- [lindex $info 0] {
		    "info" {
			puts -nonewline "\r[lindex $info 1]"
		    }
		    "warning" {
			puts "\r[lindex $info 1]"
		    }
		    "data" {
			puts -nonewline "\r[lindex $info 1] of [lindex $info 2] complete"
		    }
		    "done" {
			puts ""
		    }
		}
		flush stdout
		::xsdb::abort_check
	    }}}
    }

    proc bpadd {args} {
	variable bptable
	variable bpfmttable
	variable curchan
	variable curtarget

	set options {
	    {addr "breakpoint address" {args 1}}
	    {file "source file" {args 1}}
	    {line "line number" {args 1}}
	    {type "breakpoint type" {default auto args 1}}
	    {mode "access mode" {args 1}}
	    {enable "enable breakpoint" {default 1 args 1}}
	    {ct-input "cross trigger input" {args 1}}
	    {ct-output "cross trigger output" {args 1}}
	    {properties "advanced properties" {default {} args 1}}
	    {meta-data "meta data for advanced properties" {default {} args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set fmt [dict merge [dict create ID s Enabled b BreakpointType s ContextIds a{s} ContextNames a{s} Location s \
			     AccessMode i Size i File s Line i Column i MaskValue i Mask i Condition s IgnoreCount i \
			     StopGroup a{s} Temporary b CrossTriggerInp a{i} CrossTriggerOut a{i}] $params(meta-data)]
	set data [dict merge [dict create ID [::uuid::uuid generate] Enabled $params(enable)] $params(properties)]

	if { [info exists params(addr)] } {
	    dict set data Location $params(addr)
	}
	if { [info exists params(file)] } {
	    dict set data File $params(file)
	}
	if { [info exists params(line)] } {
	    checkint $params(line)
	    dict set data Line $params(line)
	}
	if { $params(type) == "hw" } {
	    dict set data BreakpointType "Hardware"
	} elseif { $params(type) == "sw" } {
	    dict set data BreakpointType "Software"
	} elseif { $params(type) != "auto" } {
	    error "unknown breakpoint type $params(type): should be auto, hw or sw"
	}
	if { [info exists params(mode)] } {
	    checkint $params(mode)
	    dict set data AccessMode [expr $params(mode) & 0xf]
	}
	if { [info exists params(ct-input)] } {
	    foreach ct $params(ct-input) {
		checkint $ct
	    }
	    dict set data CrossTriggerInp $params(ct-input)
	}
	if { [info exists params(ct-output)] } {
	    foreach ct $params(ct-output) {
		checkint $ct
	    }
	    dict set data CrossTriggerOut $params(ct-output)
	}

	# bpfmt table will contain the BPs which have been deleted,
	# so we don't re-use the BP IDs
	set ids [dict keys $bpfmttable]
	if { [llength $ids] == 0 } {
	    set id 0
	} else {
	    # incremental ids
	    set id [expr [lindex $ids end] + 1]
	}

	if { $curchan != "" } {
	    if { $curtarget != "" &&
		 ([dict exists $data Location] || [dict exists $data File]) } {
		# Get the target name and add it to the BP data
		set targets [::xsdb::get_debug_targets $curchan]
		dict for {ctx ctxdata} $targets {
		    if { $ctx ==  $curtarget } {
			set name [dict get [lindex [lindex $ctxdata 1] 1] Name]
		    }
		}
		dict set data ContextNames [list $name]
	    }
	    ::tcf::send_command $curchan Breakpoints add "o{$fmt}" e [list $data]
	}
	dict set bpfmttable $id [dict get $fmt]
	dict set bptable $id [dict get $data]
	dict set bptable $id show_status 1
	return $id
    }
    namespace export bpadd
    setcmdmeta bpadd categories {breakpoints}
    setcmdmeta bpadd brief {Set a Breakpoint/Watchpoint}
    setcmdmeta bpadd description {
SYNOPSIS {
    bpadd <options>
        Set a SW/HW breakpoint at addr, function or file:line, or set a
        read/write watchpoint
}

NOTE {
    Breakpoints can be set in XSDB before connecting to hw_server/TCF agent.
    If there is an active target when a Breakpoint is set, the Breakpoint
    will be enabled only for that active target. If there is no active target,
    the Breakpoint will be enabled for all the targets.
}
OPTIONS {
    -addr <breakpoint-address>
        Specify the address at which the Breakpoint should be set

    -file <file-name>
        Specify the <file-name> in which the Breakpoint should be set

    -line <line-number>
        Specify the <line-number> within the file, where Breakpoint should be
        set

    -type <breakpoint-type>
        Specify the Breakpoint type
        <breakpoint-type> can be one of the values below:
        auto = Auto - Breakpoint type is chosen by hw_server/TCF agent.
               This is the default type
        hw   = Hardware Breakpoint
        sw   = Software Breakpoint

    -mode <breakpoint-mode>
        Specify the access mode that will trigger the breakpoint.
        <breakpoint-mode> can be a bitwise OR of the values below:
        0x1  = Triggered by a read from the breakpoint location
        0x2  = Triggered by a write to the breakpoint location
        0x4  = Triggered by an instruction execution at the breakpoint location
               This is the default for Line and Address breakpoints
        0x8  = Triggered by a data change (not an explicit write) at the
               breakpoint location

    -enable <mode>
        Specify initial enablement state of breakpoint.  When <mode>
        is 0 the breakpoint is disabled, otherwise the breakpoint is
        enabled.  The default is enabled.

    -ct-input <list> -ct-output <list>
        Specify input and output cross triggers.  <list> is a list of
        numbers identifying the cross trigger pin.  For Zynq 0-7 is
        CTI for core 0, 8-15 is CTI for core 1, 16-23 is CTI ETB and
        TPIU, and 24-31 is CTI for FTM.

    -properties <dict>
        Specify advances breakpoint properties.

    -meta-data <dict>
        Specify meta-data of advances breakpoint properties.
}
RETURNS {
    Breakpoint id
}
EXAMPLE {
    bpadd -addr 0x100000
        Set a Breakpoint at address 0x100000
        Breakpoint type is chosen by hw_server/TCF agent

    bpadd -addr &main
        Set a function Breakpoint at main
        Breakpoint type is chosen by hw_server/TCF agent

    bpadd -file test.c -line 23 -type hw
        Set a Hardware Breakpoint at test.c:23

    bpadd -addr &fooVar -type hw -mode 0x3
        Set a Read_Write Watchpoint on variable fooVar

    bpadd -ct-input 0 -ct-output 8
        Set a cross trigger to stop Zynq core 1 when core 0 stops.
}
}

    # Get uuids from the bptable and modify the entries in bptable.
    # If a connection exists, modify the BPs in agent
    proc bpmodify {args} {
	variable bptable
	variable bpfmttable
	variable curchan

	set options {
	    {all "modify all breakpoints"}
	    {help "command help"}
	}
	set op [lindex $args 0]
	set args [lindex $args 1]
	# obtain the calling proc and use it with error
	set r [catch {lindex [info level [expr [info level] - 1]] 0} pname]
	if { [llength $args] == 0 } {
	    error "wrong # args: should be \"$pname ?id-list? | -all\""
	}

	set ids [dict keys $bptable]
	array set params [::xsdb::get_options args $options 0]
	if { $params(help) } {
	    return [help $pname]
	}
	if { $params(all) } {
	    if { [llength $args] != 0 } {
		error "wrong # args: should be \"$pname ?id-list? | -all\""
	    }
	    set args $ids
	}

	if { [llength $ids] == 0 } {
	    return "no breakpoints set"
	}
	set uuids {}
	foreach id $args {
	    if { [lsearch $ids $id] != -1 } {
		# append the uuid to the list and modify the BP table
		lappend uuids [dict get $bptable $id ID]
		if { $op == "remove" } {
		    set bptable [dict remove $bptable $id]
		} elseif { $op == "enable" } {
		    dict set bptable $id "Enabled" 1
		} elseif { $op == "disable" } {
		    dict set bptable $id "Enabled" 0
		}
	    } else {
		puts "warning: unknown breakpoint id $id"
	    }
	}

	if { [llength $uuids] == 0 || $curchan == "" } {
	    return
	}
	::tcf::send_command $curchan Breakpoints $op a{s} e [list $uuids]
	return
    }

    proc bpremove {args} {
	return [bpmodify "remove" $args]
    }
    namespace export bpremove
    setcmdmeta bpremove categories {breakpoints}
    setcmdmeta bpremove brief {Remove Breakpoints/Watchpoints}
    setcmdmeta bpremove description {
SYNOPSIS {
    bpremove <id-list> | -all
        Remove the Breakpoints/Watchpoints specified by <id-list> or
        remove all the breakpoints when \"-all\" option is used
}
OPTIONS {
    -all
        Remove all breakpoints
}
RETURNS {
    Nothing, if the breakpoint is removed successfully.
    Error string, if the breakpoint specified by <id> is not set.
}
EXAMPLE {
    bpremove 0
        Remove Breakpoint 0

    bpremove 1 2
        Remove Breakpoints 1 and 2

    bpremove -all
        Remove all Breakpoints
}
}

    proc bpenable {args} {
	return [bpmodify "enable" $args]
    }
    namespace export bpenable
    setcmdmeta bpenable categories {breakpoints}
    setcmdmeta bpenable brief {Enable Breakpoints/Watchpoints}
    setcmdmeta bpenable description {
SYNOPSIS {
    bpenable <id-list> | -all
        Enable the Breakpoints/Watchpoints specified by <id-list> or
	enable all the breakpoints when \"-all\" option is used
}
OPTIONS {
    -all
        Enable all breakpoints
}
RETURNS {
    Nothing, if the breakpoint is enabled successfully.
    Error string, if the breakpoint specified by <id> is not set.
}
EXAMPLE {
    bpenable 0
        Enable Breakpoint 0

    bpenable 1 2
        Enable Breakpoints 1 and 2

    bpenable -all
        Enable all Breakpoints
}
}

    proc bpdisable {args} {
	return [bpmodify "disable" $args]
    }
    namespace export bpdisable
    setcmdmeta bpdisable categories {breakpoints}
    setcmdmeta bpdisable brief {Disable Breakpoints/Watchpoints}
    setcmdmeta bpdisable description {
SYNOPSIS {
    bpdisable <id-list> | -all
        Disable the Breakpoints/Watchpoints specified by <id-list>  or
	disable all the breakpoints when \"-all\" option is used
}
OPTIONS {
    -all
        Disable all breakpoints
}
RETURNS {
    Nothing, if the breakpoint is disabled successfully.
    Error string, if the breakpoint specified by <id> is not set.
}
EXAMPLE {
    bpdisable 0
        Disable Breakpoint 0

    bpdisable 1 2
        Disable Breakpoints 1 and 2

    bpdisable -all
        Disable all Breakpoints
}
}

    proc get_bp_status { uuid { level "brief"} } {
	variable curchan

	set bp_status [lindex [lindex [::tcf::send_command $curchan Breakpoints getStatus s eo{} [list $uuid]] 1] 1]
	if { ![llength $bp_status] } {
	    return ""
	}

	set status {}
	foreach sinfo $bp_status {
	    set tid "unknown"
	    if { [dict exists $sinfo LocationContext] } {
		set bp_ctx [dict get $sinfo LocationContext]
		# Get the target id from BP status info
		set targets [::xsdb::get_debug_targets $curchan]
		dict for {ctx ctxdata} $targets {
		    if { $ctx ==  $bp_ctx } {
			set tid [dict get $ctxdata target_id]
		    }
		}
		# Skip unknown targets
		if { $tid == "unknown" } continue
		if { $level == "brief" } {
		    set tinfo {}
		    if { [dict exists $sinfo Error] } {
			dict set tinfo Error [dict get $sinfo Error]
		    } else {
			if { [dict exists $sinfo Address] } {
			    dict set tinfo Address [dict get $sinfo Address]
			}
			if { [dict exists $sinfo HitCount] } {
			    dict set tinfo HitCount [dict get $sinfo HitCount]
			}
		    }
		    set sinfo $tinfo
		} else {
		    set sinfo [dict remove $sinfo LocationContext]
		}
	    }
	    if { [dict exists $sinfo Address] } {
		dict set sinfo Address [format "0x%lx" [dict get $sinfo Address]]
	    }
	    dict lappend status $tid [dict get $sinfo]
	}
	return $status
    }

    proc bplist { args } {
	variable bptable
	variable curchan

	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	# If there is no connection, print the local table.
	# Otherwise, print local breakpoints and  breakpoints
	# set from other debug clients, separately
	set bpl ""
	set uuids {}
	set header [format "%-10s%-10s%-20s%-20s" "ID" "Enabled" "Location" "Status"]
	append header "\n[format "%-10s%-10s%-20s%-20s" "==" "=======" "========" "======"]"
	dict for {key bpdata} $bptable {
	    if { $bpl == "" } {	append bpl $header }
	    set uuid [dict get $bptable $key ID]
	    lappend uuids $uuid
	    set enabled [dict_get_safe $bpdata Enabled]
	    set loc [dict_get_safe $bpdata Location]
	    if { $loc == "" && [dict exists $bpdata CrossTriggerInp] && [dict exists $bpdata CrossTriggerOut] } {
		set loc "ct-in: [dict get $bpdata CrossTriggerInp], ct-out: [dict get $bpdata CrossTriggerOut]"
	    }
	    append bpl "\n[format "%-10s%-10s%-20s" $key $enabled $loc]"
	    if { $curchan == "" } {
		continue
	    }

	    # add brief status to the BP list
	    set status [get_bp_status $uuid]
	    if { $status == "" } {
		continue
	    }
	    set sinfo ""
	    dict for {ctx ctxdata} $status {
		if { $sinfo == "" && [string length $loc] < 18 } {
		    append sinfo "[format "%-20s" "target $ctx: [string range $ctxdata 0 26]"]"
		} else {
		    append sinfo "\n[format "%40s%-20s" "" "target $ctx: [string range $ctxdata 0 26]"]"
		}
		set len [string length $ctxdata]
		set pos 27
		while { $len - $pos > 0 } {
		    append sinfo "\n[format "%40s%-20s" "" [string range $ctxdata $pos [expr $pos + 40]]]"
		    incr pos 41
		}
	    }
	    append bpl "$sinfo"
	}

	if { [dict size $bptable] == 0 } {
	    set bpl "\nNo breakpoints currently set from this session\n"
	}

	if { $curchan == "" } {
	    return $bpl
	}

	set ids [lindex [::tcf::send_command $curchan Breakpoints getIDs "" ea{} [list]] 1]
	if { [llength $uuids] < [llength $ids] } {
	    append bpl "\n[string repeat "-" 48]\n"
	    append bpl "Breakpoints set from other Debug clients\n"
	    append bpl "[string repeat "-" 48]\n"
	    if { [dict size $bptable] == 0 } {	append bpl $header }
	    foreach id $ids {
		if { [lsearch $uuids $id] == -1 } {
		    # If not a local breakpoint, get the properties from agent
		    set desc [lindex [::tcf::send_command $curchan Breakpoints getProperties s eo{} [list $id]] 1]
		    set enabled [dict_get_safe $desc Enabled]
		    set loc [dict_get_safe $desc Location]
		    append bpl "\n[format "%-10s%-10s%-20s" "-" $enabled $loc]"
		    # add brief status to the BP list
		    set status [get_bp_status $id]
		    if { $status == "" } {
			continue
		    }
		    set sinfo ""
		    dict for {ctx ctxdata} $status {
			if { $sinfo == "" } {
			    append sinfo "[format "%-20s" "target $ctx: [string range $ctxdata 0 26]"]"
			} else {
			    append sinfo "\n[format "%40s%-20s" "" "target $ctx: [string range $ctxdata 0 26]"]"
			}
			set len [string length $ctxdata]
			set pos 27
			while { $len - $pos > 0 } {
			    append sinfo "\n[format "%40s%-20s" "" [string range $ctxdata $pos [expr $pos + 40]]]"
			    incr pos 41
			}
		    }
		    append bpl $sinfo
		}
	    }
	}
	return $bpl
    }
    namespace export bplist
    setcmdmeta bplist categories {breakpoints}
    setcmdmeta bplist brief {List Breakpoints/Watchpoints}
    setcmdmeta bplist description {
SYNOPSIS {
    bplist
        List all the Beakpoints/Watchpoints along with brief status
        for each Breakpoint and the target on which it is set
}
RETURNS {
    List of breakpoints
}
}

    proc bpstatus { args } {
	variable bptable

	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] == 1 } {
	    set id [lindex $args 0]
	} else {
	    error "wrong # args: should be \"bpstatus id\""
	}
	set chan [getcurchan]
	set ids [dict keys $bptable]
	if { [llength $ids] == 0 } {
	    error "no breakpoints set"
	}

	set bpl ""
	if { [lsearch $ids $id] != -1 } {
	    set uuid [dict get $bptable $id ID]
	    set status [get_bp_status $uuid "full"]
	    dict for {ctx ctxdata} $status {
		append bpl "target $ctx: "
		set sinfo ""
		foreach data $ctxdata {
		    if { $sinfo == "" } {
			append sinfo "$data\n"
		    } else {
			append sinfo [format "%10s%s" "" "$data\n"]
		    }
		}
		append bpl $sinfo
	    }
	} else {
	    error "unknown breakpoint id $id"
	}
	return $bpl
    }
    namespace export bpstatus
    setcmdmeta bpstatus categories {breakpoints}
    setcmdmeta bpstatus brief {Print Breakpoint/Watchpoint status}
    setcmdmeta bpstatus description {
SYNOPSIS {
    bpstatus <id>
        Print the status of a Breakpoint/Watchpoint specified by <id>.
        Status includes the target info for which the Breakpoint is active
        and also Breakpoint hitcount or error message.
}
OPTIONS {
    None
}
RETURNS {
    Breakpoint status, if the breakpoint exists.
    Error string, if the breakpoint specified by <id> is not set.
}
}

    proc jtagterminal { args } {
	global env tcl_platform
	variable xsdb_src_dir
	variable streamtable
	set options {
	    {start "start jtag based hyper-terminal"}
	    {stop "stop jtag based hyper-terminal"}
	    {socket "create socket instead of starting terminal"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { $params(start) == 0 && $params(stop) == 0 } {
	    set $params(start) 1
	}

	# Check if the Target supports UART
	set chan [getcurchan]
	set ctx [getcurtarget]
	if { ![dict exists [lindex [::tcf::send_command $chan RunControl getContext s eo{} [list $ctx]] 1] UART] } {
	    error "Target doesn't support Jtag Uart"
	}

	set UartStream [dict get [lindex [::tcf::send_command $chan RunControl getContext s eo{} [list $ctx]] 1] UART]
	set TXStreamID [dict get $UartStream TXStreamID]
	set RXStreamID [dict get $UartStream RXStreamID]
	if { $params(stop) == 1 } {
	    ::tcf::send_command $chan Streams disconnect s e [list $TXStreamID]
	    ::tcf::send_command $chan Streams disconnect s e [list $RXStreamID]
	    ::tcf::sync_eval [list ::streamsock::delete [dict get $streamtable $ctx]]
	    set streamtable [dict remove $streamtable $ctx]
	    return
	}

	::tcf::send_command $chan Streams connect s e [list $RXStreamID]
	::tcf::send_command $chan Streams connect s e [list $TXStreamID]

	# Start the Terminal Server
	set nplist [::tcf::sync_eval [list ::streamsock::create $chan $TXStreamID $RXStreamID]]
	set terminal_portno [lindex $nplist 1]

	if { $params(socket) == 0 } {
	    # Open a Jtag Uart terminal
	    set uart_script $xsdb_src_dir/jtag_uart_terminal.tcl
	    if { ![file exists $uart_script] } {
		error "ERROR: Unable to find JTAG-based Hyperterminal script: $uart_script"
	    }
	    after 1000
	    set id ""
	    set xsdb_exec_path [file dirname [info nameofexecutable]]
	    switch -glob $tcl_platform(os) {
		"Windows*" {
		    set id [exec cmd /c start $xsdb_exec_path/tclsh85t $uart_script $terminal_portno &]
		}

		"Linux" {
		    set id [exec xterm -e $xsdb_exec_path/tclsh8.5 $uart_script $terminal_portno &]
		}

		default {
		    error "ERROR: JTAG-based Hyperterminal not supported on $tcl_platform(os) platform"
		}
	    }
	}
	dict set streamtable $ctx [lindex $nplist 0]
	return $terminal_portno
    }
    namespace export jtagterminal
    setcmdmeta jtagterminal categories {streams}
    setcmdmeta jtagterminal brief {Start/Stop Jtag based hyper-terminal}
    setcmdmeta jtagterminal description {
SYNOPSIS {
    jtagterminal [options]
        Start/Stop a Jtag based hyper-terminal to communicate with
        ARM DCC or MDM UART interface.
}
NOTE {
    Select a MDM or ARM processor target before runnning this command.
}
OPTIONS {
    -start
        Start the Jtag Uart terminal. This is the default option

    -stop
        Stop the Jtag Uart terminal

    -socket
        Return the socket port number, instead of starting the terminal.
        External terminal programs can be used to connect to this port
}
RETURNS {
    Socket port number
}
}

    proc sock_writer { sock } {
	variable streamreader_bufs

	foreach buf [dict get $streamreader_bufs $sock] {
	    puts -nonewline $sock $buf
	}
	fileevent $sock writable {}
	set streamreader_bufs [dict remove $streamreader_bufs $sock]
	if { $sock != "stdout" } {
	    flush $sock
	}
	puts -nonewline "xsdb% "
	flush stdout
    }

    # Handler for streamreader events from TCF interp. Uses sync_eval to obtain
    # the streamreader table from TCF interp and prints the messages from Tx
    # streamer on stdout or a file-handle
    proc streamreader_handler { streamreader_name } {
	variable streamreader_bufs

	set stream_table [::tcf::sync_eval [list ::streamreader::get_streamreader_table $streamreader_name]]
	set sock [dict get $stream_table sock]
	set sock_bufs [dict get $stream_table sock_bufs]
	if { [dict exists streamreader_bufs $sock] } {
	    dict with streamreader_bufs $sock {lappend sock_bufs $buf}
	} else {
	    dict set streamreader_bufs $sock $sock_bufs
	}

	fileevent $sock writable [list ::xsdb::sock_writer $sock]
    }

    proc readjtaguart { args } {
	variable streamtable
	set options {
	    {start "start jtag uart reads"}
	    {stop "stop jtag uart reads"}
	    {handle "file handle" {default stdout args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { $params(start) == 0 && $params(stop) == 0 } {
	    set $params(start) 1
	}
	if { [file channels $params(handle)] == {} } {
	    error "Invalid file handle argument : $params(handle)"
	}
	# Check if the Target supports UART
	set chan [getcurchan]
	set ctx [getcurtarget]
	if { ![dict exists [lindex [::tcf::send_command $chan RunControl getContext s eo{} [list $ctx]] 1] UART] } {
	    error "Target doesn't support Jtag Uart"
	}

	set UartStream [dict get [lindex [::tcf::send_command $chan RunControl getContext s eo{} [list $ctx]] 1] UART]
	set TXStreamID [dict get $UartStream TXStreamID]
	if { $params(stop) == 1 } {
	    if { ![dict exists $streamtable $ctx] } {
		error "no active Jtag Uart connection"
	    }
	    # Flush any pending events
	    set name [lindex [dict get $streamtable $ctx] 0]
	    set sock [lindex [dict get $streamtable $ctx] 1]
	    puts "stopping Jtag Uart reads"
	    ::tcf::sync_eval [list ::streamreader::set_disconnecting $name]
	    ::tcf::send_command $chan Streams disconnect s e [list $TXStreamID]
	    streamreader_handler $name
	    set err [::tcf::sync_eval [list ::streamreader::delete $name]]
	    set streamtable [dict remove $streamtable $ctx]
	    sock_writer $sock
	    if { $err != "" } {
		error $err
	    }
	    return
	}

	if { [dict exists $streamtable $ctx] } {
	    error "Jtag Uart connection already exists"
	}
	::tcf::send_command $chan Streams connect s e [list $TXStreamID]
	if { [catch { set ns [::tcf::sync_eval {
	    return [namespace current]
	}] } message] } {
	    set ns $message
	}

	set name [::tcf::sync_eval [list ::streamreader::create $ns $chan $TXStreamID $params(handle)]]
	dict set streamtable $ctx [list $name $params(handle)]
	return
    }
    namespace export readjtaguart
    setcmdmeta readjtaguart categories {streams}
    setcmdmeta readjtaguart brief {Start/Stop reading from Jtag Uart}
    setcmdmeta readjtaguart description {
SYNOPSIS {
    readjtaguart [options]
        Start/Stop reading from the ARM DCC or MDM Uart Tx interface.
        Jtag Uart output can be printed on stdout or redirected to a file.
}
NOTE {
    Select a MDM or ARM processor target before runnning this command.

    While running a script in non-interactive mode, output from Jtag uart
    may not be written to the log, until "readjtaguart -stop" is used.
}
OPTIONS {
    -start
        Start reading the Jtag Uart output

    -stop
        Stop reading the Jtag Uart output

    -handle <file-handle>
        Specify the file handle to which the data should be redirected.
        If no file handle is given, data is printed on stdout
}
EXAMPLE {
    readjtaguart
        Start reading from the Jtag Uart and print the output on stdout

    set fp [open test.log w]; readjtaguart -start -handle $fp
        Start reading from the Jtag Uart and print the output to test.log

    readjtaguart -stop
        Stop reading from the Jtag Uart
}
RETURNS {
    Nothing, if successful.
    Error string, if data can't be read from the Jtag Uart.
}
}

    proc get_all_children { chan ctx } {
	set ctxs {}
	set children [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:children]] 1]
	foreach child $children {
	    if { $child == "" } continue
	    lappend ctxs $child
	    lappend ctxs {*}[get_all_children $chan $child]
	}
	return $ctxs
    }

    proc set_memmap { chan tgt hw } {
	variable designtable
	variable memmaptable
	variable memmap_ctxs

	set design_map [dict create]
	set mb_proc_index 0
	set a9_proc_index 0
	set r5_proc_index 0
	set a53_proc_index 0

	if { [dict exists $designtable $hw map] } {
	    set design_map [dict get $designtable $hw map]
	} else {
	    set mdm_list [::hsi::get_cells -filter {IP_TYPE == "DEBUG"}]
	    set proc_list [::hsi::get_cells -filter {IP_TYPE == "PROCESSOR"}]
	    foreach p $proc_list {
		set type [::common::get_property IP_NAME [::hsi::get_cells $p]]
		set mmap [::hsi::utils::get_addr_ranges -dict $hw $p]
		switch -- $type {
		    "microblaze" {
			foreach mdm $mdm_list {
			    set ports [::common::get_property CONFIG.C_MB_DBG_PORTS [::hsi::get_cells $mdm]]
			    set bscan [::common::get_property CONFIG.C_JTAG_CHAIN [::hsi::get_cells $mdm]]
			    for { set i 0 } { $i < $ports } { incr i } {
				set net_ips [::hsi::get_cells -of_objects [::hsi::get_intf_nets -of_objects \
									  [::hsi::get_intf_pins -of_objects $mdm \
									   -filter "NAME==[format "MBDEBUG_%d" $i]"]]]

				foreach ip $net_ips {
				    if { $ip == $p } {
					set mb_proc_index $i
					dict set design_map [::common::get_property NAME $p] [dict create mmap $mmap type "MicroBlaze" bscan $bscan index $mb_proc_index]
					break
				    }
				}
			    }
			}
		    }
		    "ps7_cortexa9" {
			dict set design_map [::common::get_property NAME $p] [dict create mmap $mmap type "ARM-Cortex-A9" bscan "" index $a9_proc_index]
			incr a9_proc_index
		    }
		    "ps8_cortexr5" -
		    "psu_cortexr5" {
			dict set design_map [::common::get_property NAME $p] [dict create mmap $mmap type "ARM-Cortex-R5" bscan "" index $r5_proc_index]
			incr r5_proc_index
		    }
		    "ps8_cortexa53" -
		    "psu_cortexa53" {
			dict set design_map [::common::get_property NAME $p] [dict create mmap $mmap type "ARM-Cortex-A53" bscan "" index $a53_proc_index]
			incr a53_proc_index
		    }
		}
	    }
	    dict set designtable $hw map $design_map
	}

	set ctxs [get_all_children $chan $tgt]
	lappend ctxs $tgt
	foreach ctx $ctxs {
	    if { $ctx == "" || [dict exists $memmap_ctxs $chan $ctx] } {
		continue
	    }
	    set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
	    if { ![dict exists $rc CPUType] } {
		continue
	    }

	    set type [dict get $rc CPUType]
	    set cpu_type $type
	    if { [dict exists $rc ARMType] } {
		append type "-[dict get $rc ARMType]"
	    }

	    if { [dict exists $rc CoreNo] } {
		set index [dict get $rc CoreNo]
	    } elseif { [dict exists $rc XMDCPort] } {
		set index [dict get $rc XMDCPort]
	    }
	    set bscan ""
	    if { [dict exists $rc JtagChain] } {
		set bscan "[string range [dict get $rc JtagChain] 4 end]"
	    }

	    dict for {p pdata} $design_map {
		if { [dict get $pdata type] == $type && [dict get $pdata bscan] == $bscan &&
		     [dict get $pdata index] == $index } {
		    # in case of ARM processors, set the memory map for top level parent
		    if { $cpu_type == "ARM" } {
			while { [dict_get_safe $rc ParentID] != "" } {
			    set ctx [dict get $rc ParentID]
			    set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
			}
			if { [dict exists $memmap_ctxs $chan $ctx] } {
			    continue
			}
		    }
		    set map {}
		    if { [dict exists $memmaptable $chan $ctx] } {
			set map [dict get $memmaptable $chan $ctx]
		    }

		    set mmap [dict get $pdata mmap]
		    dict for {key map_data} $mmap {
			dict lappend map [dict get $map_data base] [dict create Addr [dict get $map_data base] Size \
								 [dict get $map_data size] Flags [dict get $map_data flags]]
		    }
		    dict lappend memmaptable $chan $ctx $map
		    dict set memmap_ctxs $chan $ctx $mmap
		    update_memory_map $chan $ctx
		}
	    }
	}
    }

    proc loadhw { args } {
	variable designtable

	set options {
	    {hw "HW design" {args 1}}
	    {list "list open HW designs"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}
	set chan [getcurchan]
	set ctx [getcurtarget]

	if { $params(list) } {
	    if { [info exists params(hw)] || [llength $args] > 0 } {
		error "extra args with list option"
	    }
	    if { ![dict size $designtable] } {
		return "No HW designs currently open"
	    }
	    set res "[format "%-20s%-40s" "Targets" "DesignFile"]\n"
	    append res "[format "%-20s%-40s" "=======" "=========="]\n"
	    set targets [::xsdb::get_debug_targets $chan]
	    dict for {hw hwdata} $designtable {
		set ids {}
		set design [dict get $hwdata design]
		foreach target [dict get $hwdata targets] {
		    dict for {ctx ctxdata} $targets {
			if { $ctx ==  $target } {
			    lappend ids [dict get $ctxdata target_id]
			    break
			}
		    }
		}
		append res "[format "%-20s%-60s" [join $ids ", "] [string range $hw 0 59]]"
		set len [string length $hw]
		set pos 60
		while { $len - $pos > 0 } {
		    append res "\n[format "%20s%-60s" "" [string range $hw $pos [expr $pos + 60]]]"
		    incr pos 61
		}
	    }
	    return $res
	}

	if { ![info exists params(hw)] } {
	    if { [llength $args] > 0 } {
		set params(hw) [lindex $args 0]
		set args [lrange $args 1 end]
	    } else {
		error "no hw design specified"
	    }
	}
	set params(hw) [file normalize $params(hw)]
	if { [llength $args] != 0 } {
	    error "wrong # args: should be \"loadhw ?options?\""
	}

	if { ![dict exists $designtable $params(hw) design] } {
	    set design [::hsi::open_hw_design $params(hw)]
	    dict set designtable $params(hw) design $design
	} else {
	    set design [dict get $designtable $params(hw) design]
	    ::hsi::current_hw_design $design
	}

	# set the memory map for top level parent
	set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
	while { [dict_get_safe $rc ParentID] != "" } {
	    set ctx [dict get $rc ParentID]
	    set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
	}
	set channels {}
	if { [dict exists $designtable $params(hw) channels] } {
	    set channels [dict get $designtable $params(hw) channels]
	    if { [lsearch $channels $chan] == -1 } {
		lappend channels $chan
	    }
	} else {
	    lappend channels $chan
	}
	dict set designtable $params(hw) channels $channels

	set targets {}
	if { [dict exists $designtable $params(hw) targets] } {
	    set targets [dict get $designtable $params(hw) targets]
	    if { [lsearch $targets $ctx] == -1 } {
		lappend targets $ctx
	    }
	} else {
	    lappend targets $ctx
	}
	dict set designtable $params(hw) targets $targets
	set_memmap $chan $ctx $params(hw)
	return $design
    }
    namespace export loadhw
    setcmdmeta loadhw categories {miscellaneous}
    setcmdmeta loadhw brief {Load a Vivado HW design}
    setcmdmeta loadhw description {
SYNOPSIS {
    loadhw [options]
        Load a Vivado HW design, and set the memory map for the current target.
        If the current target is a parent for a group of processors, memory map
        is set for all its child processors. If current target is a processor,
        memory map is set for all the child processors of it's parent.
        This command returns the HW design object.
}
OPTIONS {
    -hw
        HW design file

    -list
        Return a list of open designs for the targets
}
RETURNS {
    Design object, if the HW design is loaded and memory map is set successfully.
    Error string, if the HW design can't be opened.
}
EXAMPLE {
    targets -filter {name =~ "APU"}; loadhw design.hdf
        Load the HW design named design.hdf and set memory map for all the
        child processors of APU target.

    targets -filter {name =~ "xc7z045"}; loadhw design.hdf
        Load the HW design named design.hdf and set memory map for all the
        child processors for which xc7z045 is the parent.
}
}

    proc clear_memmap { chan tgt } {
	variable memmaptable
	variable memmap_ctxs

	set ctxs [get_all_children $chan $tgt]
	lappend ctxs $tgt
	foreach ctx $ctxs {
	    if { $ctx == "" || ![dict exists $memmap_ctxs $chan $ctx] } {
		continue
	    }
	    set mmap [dict get $memmap_ctxs $chan $ctx]
	    set map [dict get $memmaptable $chan $ctx]
	    dict for {mem map_data} $mmap {
		set base [dict get $map_data base]
		set size [dict get $map_data size]
		dict for {id mlist} $map {
		    for {set i 0} {$i < [llength $mlist]} {incr i} {
			set m [lindex $mlist $i]
			if { ![dict exists $m FileName] && [dict get $m Addr] == $base && [dict get $m Size] == $size } {
			    set mlist [lreplace $mlist $i $i]
			    if { [llength $mlist] == 0 } {
				set map [dict remove $map $id]
			    } else {
				dict set map $id $mlist
			    }
			    break
			}
		    }
		}
	    }
	    if { $map == "" } {
		dict set memmaptable $chan [dict remove [dict get $memmaptable $chan] $ctx]
		dict set memmap_ctxs $chan [dict remove [dict get $memmap_ctxs $chan] $ctx]
		update_memory_map $chan $ctx
		continue
	    }
	    dict lappend memmaptable $chan $ctx $map
	    update_memory_map $chan $ctx
	}
    }

    proc unloadhw { args } {
	variable designtable
	variable memmap_ctxs

	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
	set ctx [getcurtarget]

	# find the top level parent and unset memory map for all its children
	set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
	while { [dict_get_safe $rc ParentID] != "" } {
	    set ctx [dict get $rc ParentID]
	    set rc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx RunControl:context]] 1]
	}
	if { ![dict exists $memmap_ctxs $chan] } {
	    return
	}
	dict for {hw hwdata} $designtable {
	    if { [dict exists $hwdata targets] } {
		set targets [dict get $hwdata targets]
		if { [lsearch $targets $ctx] != -1 } {
		    clear_memmap $chan $ctx
		    set id [lsearch -exact $targets $ctx]
		    set targets [lreplace $targets $id $id]
		    if { ![llength $targets] } {
			::hsi::close_hw_design [dict get $hwdata design]
			set designtable [dict remove $designtable $hw]
		    } else {
			dict set designtable $hw targets $targets
		    }
		    break
		}
	    }
	}
    }
    namespace export unloadhw
    setcmdmeta unloadhw categories {miscellaneous}
    setcmdmeta unloadhw brief {Unload a Vivado HW design}
    setcmdmeta unloadhw description {
SYNOPSIS {
    unloadhw
        Close the Vivado HW design which was opened during loadhw command, and
	clear the memory map for the current target.
        If the current target is a parent for a group of processors, memory map
        is cleared for all its child processors. If the current target is a
        processor, memory map is cleared for all the child processors of it's
        parent. This command doesn't clear memory map explicitly set by users.
}
RETURNS {
    Nothing
}
}

    proc show_brief {result names} {
	variable command_metadata
	upvar $result res

	set maxlen 0
	foreach name $names {
	    set len [string length $name]
	    if { $maxlen < $len } {
		set maxlen $len
	    }
	}

	foreach name $names {
	    set brief {}
	    if { [dict exists $command_metadata $name brief] } {
		set brief [dict get $command_metadata $name brief]
	    }
	    set pad [string repeat " " [expr $maxlen - [string length $name]]]
	    append res "$name$pad - $brief\n"
	}
    }

    proc help {args} {
	variable command_metadata
	if { [llength $args] > 0 } {
	    set option [join $args]
	} else {
	    set option categories
	}
	set matches [lsearch -all -inline -glob [dict keys $command_metadata] "$option*"]
	if { [llength $matches] == 0 } {
	    error "unknown command or category \"$option\": must be [join [dict keys $command_metadata] {, }]"
	}

	set result ""
	if { [llength $matches] == 1 } {
	    set name [lindex $matches 0]
	} else {
	    set match [lsearch $matches $option]
	    if { $match < 0 } {
		append result "Matching commands and categories\n\n"
		show_brief result $matches
		return $result
	    }
	    set name [lindex $matches $match]
	}
	if { $name == "categories" } {
	    append result "Available Help Categories\n\n"
	    set categories [dict keys [dict get $command_metadata commands categories]]
	    if { [string first "xsct" [file tail [info nameofexecutable]]] == -1 } {
		set id [lsearch -exact $categories "sdk"]
		set categories [lreplace $categories $id $id]
	    }
	    show_brief result $categories
	    append result "\nType \"help\" followed by above \"category\" for more details or\n"
	    append result "help\" followed by the keyword \"commands\" to list all the commands\n"
	} elseif { [dict exists $command_metadata $name category_commands] } {
	    append result "Category commands\n\n"
	    show_brief result "[dict keys [dict get $command_metadata $name category_commands]]\n"
	    append result "\nType \"help\" followed by above \"command\", or the above \"command\" followed by\n\"-help\" for more details\n"
	} else {
	    append result "NAME\n    "
	    show_brief result "[list $name]\n"
	    if { [dict exists $command_metadata $name description] } {
		if { [dict exists $command_metadata $name description SYNOPSIS] } {
		    append result "\nSYNOPSIS"
		    append result "[dict get $command_metadata $name description SYNOPSIS]\n"
		} else {
		    append result "[dict get $command_metadata $name description]\n"
		}
		if { [dict exists $command_metadata $name description OPTIONS] } {
		    append result "OPTIONS"
		    append result "[dict get $command_metadata $name description OPTIONS]\n"
		}
		if { [dict exists $command_metadata $name description NOTE] } {
		    append result "NOTE"
		    append result "[dict get $command_metadata $name description NOTE]\n"
		}
		if { [dict exists $command_metadata $name description EXAMPLE] } {
		    append result "EXAMPLE"
		    append result "[dict get $command_metadata $name description EXAMPLE]\n"
		}
		if { [dict exists $command_metadata $name description RETURNS] } {
		    append result "RETURNS"
		    append result "[dict get $command_metadata $name description RETURNS]\n"
		}
	    }
	}
	return $result
    }
    namespace export help

    proc cache { args } {
	set options {
	    {invalidate "invalidate cache"}
	}
	array set params [::xsdb::get_options args $options 0]
	set chan [getcurchan]
	if { $params(invalidate) } {
	    if { [llength $args] == 0 } {
		::tcf::sync_eval [list set ::channels::[set chan]::ctxs {"" {children {}}}]
	    } else {
		::tcf::sync_eval [list ::channels::[set chan]::invalidate_datatypes {*}$args]
	    }
	    return ""
	}
	set ctxs [::tcf::sync_eval [list set ::channels::[set chan]::ctxs]]
    }

    proc to_bits { value len } {
	binary scan [i2bin $value $len] b${len} bitval
	return [string reverse $bitval]
    }

    # Convert binary string value to hexadecimal with prefix "0x"
    proc to_hex { value len } {
	set binlen      [string length $value]
	set hexlen      [expr ($len + 3) / 4]
	set extralen    [expr $hexlen * 4 - $len]
	set extra       [string repeat "0" $extralen]
	set binextralen [expr $binlen + $extralen]
	binary scan [binary format B${binextralen} ${extra}${value}] H${hexlen} hexval
	return "0x$hexval"
    }

    proc mdm_drwr { args } {
	set options {
	    {user "bscan user port" {default 2 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] != 3 } {
	    error "wrong # args: should be \"mdm_drwr command len\""
	}
	set command [lindex $args 0]
	set data [lindex $args 1]
	set len [lindex $args 2]

	set seqname [jtag sequence]
	$seqname irshift -state IDLE -register bypass
	$seqname irshift -state IDLE -register user$params(user)
	$seqname drshift -state IDLE -int 4 1
	$seqname drshift -state IDLE -int 8 $command
	$seqname drshift -state IDLE -int $len $data
	$seqname run -current-target
	$seqname delete
    }
    namespace export mdm_drwr
    setcmdmeta mdm_drwr categories {miscellaneous}
    setcmdmeta mdm_drwr brief {Write to MDM Debug Register}
    setcmdmeta mdm_drwr description {
SYNOPSIS {
    mdm_drwr [options] <cmd> <data> <bitlen>
        Write to MDM Debug Register.  cmd is 8-bit MDM command to
        access a Debug Register.  data is the register value and
        bitlen is the register width
}
OPTIONS {
    -user <bscan number>
        Specify user bscan port number.  Default is 2.
}
RETURNS {
    Nothing, if successful.
    Error string, if BSCAN port is invalid.
}
EXAMPLE {
    mdm_drwr 8 0x40 8
        Write to MDM Break/Reset Control Reg
}
}

    proc mb_drwr { args } {
	set options {
	    {user "bscan user port" {default 2 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] != 3 } {
	    error "wrong # args: should be \"mb_drwr command len\""
	}
	set command [lindex $args 0]
	set data [lindex $args 1]
	set len [lindex $args 2]

	set seqname [jtag sequence]
	$seqname irshift -state IDLE -register bypass
	$seqname irshift -state IDLE -register user$params(user)
	$seqname drshift -state IDLE -int 4 1
	$seqname drshift -state IDLE -int 8 $command
	set res [to_bits $data $len]
	$seqname drshift -state IDLE -bits $len $res
	$seqname run -current-target
	$seqname delete
    }
    namespace export mb_drwr
    setcmdmeta mb_drwr categories {miscellaneous}
    setcmdmeta mb_drwr brief {Write to MicroBlaze Debug Register}
    setcmdmeta mb_drwr description {
SYNOPSIS {
    mb_drwr [options] <cmd> <data> <bitlen>
        Write to MicroBlaze Debug Register available on MDM. cmd is
        8-bit MDM command to access a Debug Register.  data is the
        register value and bitlen is the register width
}
OPTIONS {
    -user <bscan number>
        Specify user bscan port number.  Default is 2.
}
RETURNS {
    Nothing, if successful.
    Error string, if BSCAN port is invalid.
}
EXAMPLE {
    mb_drwr 1 0x282 10
        Write to MB Control Reg
}
}

    proc mdm_drrd { args } {
	set options {
	    {user "bscan user port" {default 2 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] != 2 } {
	    error "wrong # args: should be \"mdm_drrd command len\""
	}
	set command [lindex $args 0]
	set len [lindex $args 1]

	set seqname [jtag sequence]
	$seqname irshift -state IDLE -register bypass
	$seqname irshift -state IDLE -register user$params(user)
	$seqname drshift -state IDLE -int 4 1
	$seqname drshift -state IDLE -int 8 $command
	$seqname drshift -state IDLE -tdi 0 -capture $len
	set res [$seqname run -current-target -bits]
	$seqname delete
	set res [to_hex [string reverse $res] $len]
	return $res
    }
    namespace export mdm_drrd
    setcmdmeta mdm_drrd categories {miscellaneous}
    setcmdmeta mdm_drrd brief {Read from MDM Debug Register}
    setcmdmeta mdm_drrd description {
SYNOPSIS {
    mdm_drrd [options] <cmd> <bitlen>
        Read a MDM Debug Register.  cmd is 8-bit MDM command to access
        a Debug Register and bitlen is the register width.  Returns
        hex register value
}
OPTIONS {
    -user <bscan number>
        Specify user bscan port number.  Default is 2.
}
RETURNS {
    Register value, if successful.
    Error string, if BSCAN port is invalid.
}
EXAMPLE {
    mdm_drrd 0 32
        Read XMDC ID Reg
}
}

    proc mb_drrd { args } {
	set options {
	    {user "bscan user port" {default 2 args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] != 2 } {
	    error "wrong # args: should be \"mb_drrd command len\""
	}
	set command [lindex $args 0]
	set len [lindex $args 1]

	set seqname [jtag sequence]
	$seqname irshift -state IDLE -register bypass
	$seqname irshift -state IDLE -register user$params(user)
	$seqname drshift -state IDLE -int 4 1
	$seqname drshift -state IDLE -int 8 $command
	$seqname drshift -state IDLE -tdi 0 -capture $len
	set res [$seqname run -current-target -bits]
	$seqname delete
	set res [to_hex $res $len]
	return $res
    }
    namespace export mb_drrd
    setcmdmeta mb_drrd categories {miscellaneous}
    setcmdmeta mb_drrd brief {Read from MicroBlaze Debug Register}
    setcmdmeta mb_drrd description {
SYNOPSIS {
    mb_drrd [options] <cmd> <bitlen>
        Read a MicroBlaze Debug Register available on MDM. cmd is
        8-bit MDM command to access a Debug Register.  bitlen is the
        register width.  Returns hex register value
}
OPTIONS {
    -user <bscan number>
        Specify user bscan port number.  Default is 2.
}
RETURNS {
    Register value, if successful.
    Error string, if BSCAN port is invalid.
}
EXAMPLE {
    mb_drrd 3 28
        Read MB Status Reg
}
}

    proc get_expr_type { exprs id } {
	if { ![dict exists $exprs $id Context Class] } {
	    return "N/A"
	}
	set class [dict get $exprs $id Context Class]
	if { $class == 4 } {
	    set type [dict_get_safe $exprs $id BaseType Name]
	    if { $type == "" } { set type [dict_get_safe $exprs $id BaseTypeID Name] }
	    append type " *"
	} elseif { $class == 5 } {
	    set type [dict_get_safe $exprs $id BaseType Name]
	    if { $type == "" } { set type [dict_get_safe $exprs $id BaseTypeID Name] }
	    if { [dict_get_safe $exprs $id BaseType TypeClass] == 4 } { append type " *" }
	    append type "\[[dict get $exprs $id Type Length]\]"
	} else {
	    set type [dict_get_safe $exprs $id Type Name]
	    if { $type == "" } { set type [dict_get_safe $exprs $id TypeID Name] }
	    if { $type == "" && $class == 6 } { set type "<Structure>" }
	}
	return $type
    }

    proc get_expr_value { chan ctx exprs id } {
	variable expr_fmt_dict

	set value ""
	if { [dict exists $exprs $id err] } {
	    return [dict get $exprs $id err]
	} else {
	    if { ![dict exists $exprs $id Context Class] } {
		return "N/A"
	    }
	    set class [dict get $exprs $id Context Class]
	    if { $class == 5 } {
		set value [dict_get_safe $exprs $id BaseType Name]
		if { $value == "" } { set value [dict_get_safe $exprs $id BaseTypeID Name] }
		if { [dict_get_safe $exprs $id BaseType TypeClass] == 4 } { append value " *" }
		append value "\[[dict get $exprs $id Type Length]\]"
		return "$value"
	    } elseif { $class == 6 } {
		set value [dict_get_safe $exprs $id Type Name]
		if { $value == "" } { set value "<Structure>" }
		return $value
	    } else {
		set size [dict get $exprs $id Context Size]
		set bin [lindex [dict get $exprs $id Value] 0]

		if { ![dict exists $expr_fmt_dict $class $size] } {
		    set fmt c*
		} else {
		    set fmt [dict get $expr_fmt_dict $class $size]
		}
		set mc [lindex [::tcf::cache_eval $chan [list get_context_cache_client $chan $ctx Memory:context]] 1]
		if { [dict exists $mc BigEndian] && [dict get $mc BigEndian] != 0 } {
		    set fmt [string toupper $fmt 0 0]
		}
		set value "N/A"
		binary scan $bin $fmt value
		return $value
	    }
	}
    }

    proc value2bin { exprs id value } {
	variable expr_fmt_dict

	set bin ""
	if { [dict_get_safe $exprs $id Context CanAssign] != 1 } {
	    error "Expression cannot be modified"
	}
	if { [dict exists $exprs $id err] } {
	    error [dict get $exprs $id err]
	} else {
	    set class [dict_get_safe $exprs $id Context Class]
	    if { $class == 5 } {
		error "cannot set the value of an array. specify array index"
	    } else {
		set size [dict get $exprs $id Context Size]
		if { ![dict exists $expr_fmt_dict $class $size] } {
		    set fmt c*
		} else {
		    set fmt [dict get $expr_fmt_dict $class $size]
		}
		set bin [binary format $fmt $value]
		return $bin
	    }
	}
    }

    proc get_child_variables { exprs ids parent } {
	upvar id_list $ids
	lappend id_list $parent
	foreach id [dict_get_safe $exprs $parent Children] {
	    get_child_variables $exprs id_list $id
	}
    }

    proc is_array { var_name } {
	set index [string last "\]" $var_name]
	if { $index != -1 } {
	    return [dict create index $index name [string range $var_name 0 $index]]
	}
	return [dict create index 0 name {}]
    }

    proc dispose_exprs { arg } {
	dict lappend arg actions {
	    update_expr_list $expr_list
	    set ids [get_expr_ids $chan $ctx $name $scope]
	    foreach id $ids {
		send_action_command $argvar Expressions dispose s e [list $id] {
		    if { [lindex $data 0] != "" } {
			error [lindex $data 0]
		    }
		}
		incr numreq 1
	    }
	    incr curaction
	}

	dict set arg result {}
	return [process_tcf_actions $arg]
    }

    proc process_expressions { chan ctx exprs options args } {
	set id_list {}
	set parent ""
	if { [llength $args] && [lindex $args 0] != "" } {
	    if { [dict get $options local] } {
		set name [lindex $args 0]
		set index [dict get [is_array $name] index]
		if { $index } {
		    set names [dict get [is_array $name] name]
		    if { [expr $index + 1] < [string length $name] } {
			lappend names {*}[split [string range $name [expr $index + 2] end] .]
		    }
		} else {
		    set names [split $name .]
		}
	    } else {
		set names [list [lindex $args 0]]
	    }

	    set root [lindex $names 0]
	    dict for {id expr_data} $exprs {
		set var_name $id
		if { [dict exists $expr_data Symbol Name] } { set var_name [dict get $expr_data Symbol Name] }
		if { $root == $var_name && [dict get $expr_data level] == 0 } {
		    set parent $id
		    break
		}
	    }
	    if { $parent == "" } { error "no variable match $root" }

	    if { [llength $names] != 1 } {
		foreach name [lrange $names 1 end] {
		    set match 0
		    if { [dict exists $exprs $parent Children] } {
			foreach id [dict get $exprs $parent Children] {
			    set var_name $id
			    if { [dict exists $exprs $id Symbol Name] } { set var_name [dict get $exprs $id Symbol Name] }
			    if { $var_name == $name } {
				set parent $id
				set match 1
				break
			    }
			}
		    }
		    if { $match == 0 } {
			error "no variable match: $name"
		    }
		}
	    }

	    get_child_variables $exprs id_list $parent
	}

	set maxlen 0
	set maxlevel 0
	set result ""
	dict for {id expr_data} $exprs {
	    set name $id
	    if { [dict exists $expr_data Symbol Name] } { set name [dict get $expr_data Symbol Name] }
	    if { [string length $name] > $maxlen } { set maxlen [string length $name]}
	    if { [dict exists $expr_data level] && [dict get $expr_data level] > $maxlevel } { set maxlevel [dict get $expr_data level]}
	}
	if { $maxlen < 8 } { set maxlen 8 }
	set len [expr {$maxlen + ($maxlevel * 3) + 2}]
	if { ![dict get $options dict] && [dict get $options defs] } {
	    append result [format "%-[set len]s%-20s%-20s%-10s%-10s" "Name" "Type" "Address" "Size" "Flags"]
	    append result "\n[format "%-[set len]s%-20s%-20s%-10s%-10s" "========" "========" "===========" "====" "====="]"
	}

	set start_level -1
	set hier_name ""
	if { [lindex $args 1] == "" } {
	    dict for {id expr_data} $exprs {
		if { [llength $id_list] && [lsearch -exact $id_list $id] == -1 } { continue }
		set name $id
		if { [dict exists $expr_data Symbol Name] } { set name [dict get $expr_data Symbol Name] }

		if { $start_level == -1 || $start_level > [dict get $expr_data level] } { set start_level [dict get $expr_data level] }
		set indent [expr {([dict get $expr_data level] - $start_level) * 3}]
		set len [expr {$maxlen - $indent + ($maxlevel * 3) + 2}]
		if { ![dict get $options dict] && $result != "" } {
		    append result "\n"
		}

		if { [dict get $expr_data level] == 0 } { set hier_name "" }
		if { [dict get $options defs] } {
		    if { [dict exists $expr_data err] } {
			set value [dict get $expr_data err]
			if { [dict get $options dict] } {
			    dict set result $name $value
			} else {
			    append result [format "%*s%s%s%s" $indent "" $name ": " $value]
			}
			continue
		    }

		    set flags [dict_get_safe $expr_data Context CanAssign]
		    if { $flags == 1 } { set flags RW
		    } elseif { $flags == 0 } { set flags R
		    } else { set flags N/A }

		    set addr N/A
		    if { [dict exists $expr_data Value] && [dict exists [lindex [dict get $expr_data Value] 2] Address] } {
			set addr [format 0x%x [dict get [lindex [dict get $expr_data Value] 2] Address]]
		    }
		    set size [dict_get_safe $expr_data Type Size]
		    if { $size == "" } { set size [dict_get_safe $expr_data Context Size] }
		    set type [get_expr_type $exprs $id]
		    if { [dict get $options dict] } {
			if { $hier_name == "" } { set hier_name $name
			} else {
			    set hier_name [join [lrange [split $hier_name .] 0 [dict get $expr_data level]] .]
			    append hier_name ".$name"
			}
			dict set result $hier_name [dict create type $type addr $addr size $size flags $flags]
		    } else {
			append result [format "%*s%-[set len]s%-20s%-20s%-10s%-10s" $indent "" \
				       $name $type $addr $size $flags]
		    }
		} else {
		    set value [get_expr_value $chan $ctx $exprs $id]
		    if { [dict get $options dict] } {
			if { $hier_name == "" } { set hier_name $name
			} else {
			    set hier_name [join [lrange [split $hier_name .] 0 [dict get $expr_data level]] .]
			    append hier_name ".$name"
			}
			dict set result $hier_name $value
		    } else {
			append result [format "%*s%-[set len]s%s%s" $indent "" $name ": " $value]
		    }
		}
	    }
	    return $result
	} elseif { [llength $args] == 2 } {
	    if { [llength $id_list] > 1 } {
		error "cannot modify the value of a complex data type.\n\
		       \rspecify a child element to be modified"
	    }
	    set params(val) [lindex $args 1]
	    dict for {id expr_data} $exprs {
		if { [lsearch -exact $id_list $id] == -1 } continue
		set params(val) [value2bin $exprs $id $params(val)]
		tcf::send_command $chan Expressions assign sB e [list [dict get $expr_data Context ID] $params(val)]
		return
	    }
	}
    }

    proc print { args } {
	set options {
	    {add "add to auto expression list"}
	    {remove "remove from auto expression list"}
	    {defs "show expression definitions"}
	    {set "set the expression value"}
	    {dict "return result in dict format"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	set exprs {}
	set expr_list [::tcf::sync_eval {return [set [namespace current]::expr_list]}]
	if { [dict exists $expr_list $params(chan) $params(ctx)] } {
	    set exprs [dict get $expr_list $params(chan) $params(ctx)]
	}

	if { [llength $args] == 0 } {
	    if { [llength $exprs] == 0 || $params(add) + $params(set) != 0 } {
	        error "specify an expression"
	    }
	    if { $params(defs) + $params(remove) > 1 } {
		error "conflicting options specified, use only one of -defs, or -remove"
	    }
	    set params(name) ""
	    set params(value) ""
	    if { $params(remove) } {
		dict set expr_list $params(chan) $params(ctx) {}
		set arg [array get params]
		dict set arg scope "auto_expr"
		dict set arg expr_list $expr_list
		return [dispose_exprs $arg]
	    }
	} else {
	    if { $params(defs) + $params(add) + $params(remove) + $params(set) > 1 } {
		error "conflicting options specified, use only one of -add, -defs, -remove, or -set"
	    }

	    if { $params(set) } {
		if { [llength $args] < 2 } {
		    error {wrong # args: should be "print [options] [name [value]]"}
		}
		set params(name) [lrange $args 0 end-1]
		set params(value) [lindex $args end]
	    } else {
		set params(name) [lrange $args 0 end]
		set params(value) ""
	    }
	    if { [llength $params(name)] == 1 } {
		set params(name) [lindex $params(name) 0]
	    }
	    set id [lsearch -exact $exprs $params(name)]
	    if { $params(remove) } {
		if { $id == -1 } {
		    error "unknown expression $params(name)"
		}
		set exprs [lreplace $exprs $id $id]
		dict set expr_list $params(chan) $params(ctx) $exprs

		set arg [array get params]
		dict set arg scope "auto_expr"
		dict set arg expr_list $expr_list
		return [dispose_exprs $arg]
	    }
	    if { $id == -1 && $params(add)} {
		lappend exprs $params(name)
	    }
	}

	dict set expr_list $params(chan) $params(ctx) $exprs
	::tcf::sync_eval [list update_expr_list $expr_list]
	set arg [array get params]
	set ids {}
	if { $params(name) == "" } {
	    foreach id $exprs {
		if { [lsearch $ids $id] == -1 } { lappend ids $id }
	    }
	} else {
	    lappend ids $params(name)
	}
	dict set arg ids $ids
	dict set arg expr_list $exprs
	dict set arg expr_data {}

	dict lappend arg actions {
	    set cache_misses 0
	    set exprs {}
	    foreach id $ids {
		if { [catch {
		    get_expression_cache_client $argvar exprs $id
		    set expr_data $exprs
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
	    }

	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    if { $numreq > 0 } {
		cache wait
	    }
	    incr curaction
	}
	dict lappend arg actions {
	    dict for {id data} $expr_data {
		if { [dict exists $data  err] } continue
		if { ![dict exists $data Value] } {
		    ::tcf::send_command $chan Expressions evaluate [list expr_eval_callback $argvar $id]
		    ::tcf::write $chan "s" [list [dict get $expr_data $id Context ID]]
		    incr numreq 1
		}
	    }
	    incr curaction
	}
	dict set arg result {
	    set expr_data
	}
	set exprs [process_tcf_actions $arg]

	return [process_expressions $params(chan) $params(ctx) $exprs [dict create local 0 defs $params(defs) dict $params(dict)] $params(name) $params(value)]
    }
    namespace export print
    setcmdmeta print categories {running}
    setcmdmeta print brief {Get or set the value of an expression}
    setcmdmeta print description {
SYNOPSIS {
    print [options] [expression]
        Get or set the value of an expression specified by <expression>.
        The <expression> can include constants, local/global variables,
        CPU registers, or any operator, but pre-processor macros defined
        through #define are not supported. CPU registers can be specified
        in the format {$r1}, where r1 is the register name.
        Elements of a complex data types like a structure can be accessed
        through '.' operator. For example, var1.int_type refers to int_type
        element in var1 struct.
        Array elements can be accessed through their indices. For example,
        array1[0] refers to the element at index 0 in array1.
}
OPTIONS {
    -add <expression>
        Add the <expression> to auto expression list. The values or definitions
        of the expressions in auto expression list are displayed when expression
        name is not specified. Frequently used expressions should be added to
        the auto expression list

    -defs [expression]
        Return the expression definitions like address, type, size and RW flags.
        Not all definitions are available for all the expressions. For example,
        address is available only for variables and not when the expression
        includes an operator

    -dict [expression]
        Return the result in Tcl dict format, with variable names as dict keys
        and variable values as dict values. For complex data like structures,
        names are in the form of parent.child

    -remove [expression]
        Remove the expression from auto expression list. Only expressions
        previously added to the list through -add option can be removed. When
        the expression name is not specified, all the expressions in the
        auto expression list are removed

    -set <expression>
        Set the value of a variable. It is not possible to set the value of an
        expression which includes constants or operators
}
RETURNS {
    The return value depends on the options used.

    <none> or -add
        Expression value(s)

    -defs
        Expression definition(s)

    -remove or -set
        Nothing

    Error string, if expression value  can't be read or set.
}
EXAMPLE {
    print Int_Glob
        Return the value of variable Int_Glob

    print -a Microseconds
        Add the variable Microseconds to auto expression list and return
        its value

    print -a Int_Glob*2 + 1
        Add the expression (Int_Glob*2 + 1) to auto expression list and
        return its value

    print tmp_var.var1.int_type
        Return the value of int_type element in var1 struct, where var1
        is a member of tmp_var struct

    print tmp_var.var1.array1[0]
        Return the value of the element at index 0 in array array1. array1 is
        a member of var1 struct, which is in turn a member of tmp_var struct

    print
        Return the values of all the expressions in auto expression list

    print -defs
        Return the definitions of all the expressions in auto expression list

    print -set Int_Glob 23
        Set the value of the variable Int_Glob to 23

    print -remove Microseconds
        Remove the expression Microseconds from auto expression list

    print {r1}
        Return the value of CPU register r1
}
}

    proc locals { args } {
	set options {
	    {defs "show variable definitions"}
	    {dict "return result in dict format"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [llength $args] } {
	    set name [lindex $args 0]
	    if { [dict get [is_array $name] index] } {
		set args [list $name {*}[lrange $args 1 end]]
		if { $params(defs) } { set args [linsert $args 0 "-defs"] }
		return [print {*}$args]
	    }
	}
	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	if { [llength $args] > 2 } {
	    error {wrong # args: should be "locals [options] [name [value]]"}
	}
	set arg [array get params]
	dict set arg expr_data {}

	dict lappend arg actions {
	    set cache_misses 0
	    set exprs {}
	    set ret [get_ctx_data $chan $ctx Expressions:children]
	    if { [lindex $ret 0] != "" } {
		error [lindex $ret 0]
	    }
	    foreach e [lindex $ret 1] {
		if { [catch {
		    get_variable_cache_client $argvar exprs $e
		    set expr_data $exprs
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
	    }

	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    if { $numreq > 0 } {
		cache wait
	    }
	    incr curaction
	}
	dict lappend arg actions {
	    dict for {id data} $expr_data {
		if { [dict exists $data  err] } continue
		if { ![dict exists $data Value] } {
		    ::tcf::send_command $chan Expressions evaluate [list expr_eval_callback $argvar $id]
		    ::tcf::write $chan "s" [list [dict get $expr_data $id Context ID]]
		    incr numreq 1
		}
	    }
	    incr curaction
	}
	dict set arg result {
	    set expr_data
	}
	set exprs [process_tcf_actions $arg]

	return [process_expressions $params(chan) $params(ctx) $exprs [dict create local 0 defs $params(defs) dict $params(dict)] {*}$args]
    }
    namespace export locals
    setcmdmeta locals categories {running}
    setcmdmeta locals brief {Get or set the value of a local variable}
    setcmdmeta locals description {
SYNOPSIS {
    locals [options] [variable-name [variable-value]]
        Get or set the value of a variable specified by <variable-name>.
        When variable name and value are not specified, values of all the
        local variables are returned.
        Elements of a complex data types like a structure can be accessed
        through '.' operator. For example, var1.int_type refers to int_type
        element in var1 struct.
        Array elements can be accessed through their indices. For example,
        array1[0] refers to the element at index 0 in array1.
}
OPTIONS {
    -defs
        Return the variable definitions like address, type, size and RW flags.

    -dict [expression]
        Return the result in Tcl dict format, with variable names as dict keys
        and variable values as dict values. For complex data like structures,
        names are in the form of parent.child
}
RETURNS {
    The return value depends on the options used.

    <none>
        Variable value(s)

    -defs
        Variable definition(s)

    Nothing, when variable value is set.
    Error string, if variable value  can't be read or set.
}
EXAMPLE {
    locals Int_Loc
        Return the value of the local variable Int_Loc

    locals
        Return the values of all the local variables in the current stack frame

    locals -defs
        Return definitions of all the local variables in the current stack frame

    locals Int_Loc 23
        Set the value of the local variable Int_Loc to 23

    locals tmp_var.var1.int_type
        Return the value of int_type element in var1 struct, where var1
        is a member of tmp_var struct

    locals tmp_var.var1.array1[0]
        Return the value of the element at index 0 in array array1. array1 is
        a member of var1 struct, which is in turn a member of tmp_var struct
}
}

    proc backtrace {args} {
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set params(chan) [getcurchan]
	set params(ctx) [getcurtarget]
	set arg [array get params]
	dict set arg stack {}
	dict lappend arg actions {
	    set stack {}
	    set cache_misses 0
	    set ret [get_ctx_data $chan $ctx StackTrace:children]
	    if { [lindex $ret 0] != "" } {
		error [lindex $ret 0]
	    }
	    foreach child [lindex $ret 1] {
		set entry {}
		set ip ""
		set pid {}
		set top 0
		if { [catch {
		    set entry [get_ctx_data $chan $child StackTrace:context]
		    set ec [lindex $entry 0 0]
		    if { [dict exists $ec IP] } {
			set ip [dict get $ec IP]
		    }
		    if { [dict exists $ec ProcessID] } {
			set pid [dict get $ec ProcessID]
		    }
		    if { [dict exists $ec TopFrame] && [dict get $ec TopFrame] } {
			set top 1
		    }
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
		set m2s {}
		if { $ip != "" && [catch {
		    set ipl $ip
		    set iph $ip
		    if { $top } {
			incr iph 1
		    } elseif { $ipl > 0 } {
			incr ipl -1
		    }
		    set m2s [get_ctx_data $chan [list $pid $ipl $iph] LineNumbers:mapToSource]
		    dict set data $ctx LineNumbers:mapToSource $m2s
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
		set sym {}
		if { $ip != "" && [catch {
		    set sid [get_ctx_data $chan [list $pid $ip] Symbols:findByAddr]
		    if { [lindex $sid 0] == "" } {
			set sym [get_ctx_data $chan [lindex $sid 1] Symbols:context]
		    }
		} message] } {
		    if { $message == $::cache_miss_err } {
			incr cache_misses
		    } else {
			puts $message
		    }
		}
		lappend stack [list $entry $m2s $sym]
	    }
	    if { $cache_misses > 0 } {
		error $::cache_miss_err
	    }
	    if { $numreq > 0 } {
		cache wait
	    }
	    incr curaction
	}
	dict set arg result {
	    set stack
	}
	set stack [process_tcf_actions $arg]
	set result ""
	foreach level [lreverse $stack] {
	    set entry [lindex $level 0]
	    set m2s [lindex $level 1 1 0]
	    set sym [lindex $level 2 1]
	    set index ""
	    set info {}
	    set ip ""
	    if { [lindex $entry 1] == "" } {
		set entry [lindex $entry 0 0]
		if { [dict exists $entry Index] } {
		    set index [dict get $entry Index]
		}
		if { [dict exists $entry IP] } {
		    set ip [dict get $entry IP]
		    set loc [format 0x%lx $ip]
		} else {
		    set loc unknown-pc
		}
		if { [dict exists $sym Name] } {
		    set name [dict get $sym Name]
		    append name "()"
		    if { $ip != "" && [dict exists $sym Address] } {
			set offset [expr {$ip - [dict get $sym Address]}]
			if { $offset != 0 } {
			    append name [format "%+d" $offset]
			}
		    }
		    append loc " $name"
		}
		if { [dict exists $m2s File] } {
		    set name [dict get $m2s File]
		    if { [dict exists $m2s SLine] } {
			append name ", line [dict get $m2s SLine]"
		    }
		    append loc ": $name"
		}
		lappend info $loc
	    } else {
		lappend info "error: [lindex $entry 1]"
	    }
	    if { $result != "" } {
		append result "\n"
	    }
	    append result [format "%5s  %s" $index [join $info]]
	}
	return $result
    }
    namespace export backtrace
    interp alias {} bt {} backtrace
    namespace export bt
    setcmdmeta backtrace categories {running}
    setcmdmeta backtrace brief {Stack back trace}
    setcmdmeta backtrace description {
SYNOPSIS {
    backtrace
        Return stack trace for current target.  Target must be
        stopped.  Use debug information for best result.
}
RETURNS {
    Stack Trace, if successful.
    Error string, if Stack Trace can't be read from the target.
}
}

    proc get_force_mem_accesses {} {
	variable force_mem_accesses
	return $force_mem_accesses
    }

    proc set_force_mem_accesses {val} {
	variable force_mem_accesses [expr {!!$val}]
    }

    proc get_sdk_launch_timeout {} {
	variable sdk_launch_timeout
	expr {$sdk_launch_timeout / 1000}
    }

    proc set_sdk_launch_timeout {val} {
	variable sdk_launch_timeout [expr {$val * 1000}]
    }

    proc get_source_line_view {} {
	variable enable_source_line_view
	return $enable_source_line_view
    }

    proc set_source_line_view {val} {
	variable source_line_info
	variable enable_source_line_view [expr {!!$val}]
	set chan [getcurchan]
	if { [dict exists $source_line_info $chan] } {
	    set source_line_info [dict remove $source_line_info $chan]
	}
    }

    proc configparams { args } {
	set options {
	    {all "include all contexts"}
	    {context "specify context" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { $params(all) + [info exists params(context)] > 1 } {
	    error "conflicting options specified"
	}

	set defs {
	    force-mem-accesses {
		description "overwrite access proctection for all memory accesses performed from xsdb"
		type boolean
		getter get_force_mem_accesses
		setter set_force_mem_accesses
	    }
	    sdk-launch-timeout {
		description "sdk launch timeout used for running sdk batch mode commands"
		type integer
		minimum 0
		getter get_sdk_launch_timeout
		setter set_sdk_launch_timeout
	    }
	    source-line-view {
		description "enable source line view while debugging an elf"
		type boolean
		getter get_source_line_view
		setter set_source_line_view
	    }
	}

	set chan $::xsdb::curchan
	if { $chan != "" } {
	    catch {set defs [dict merge $defs [lindex [tcf::send_command $chan ContextParams getDefinitions "" "eo{o{}}" {}] 1]]}
	}

	set names [lsort [dict keys $defs]]
	if { [llength $args] == 0 } {
	    if { $params(all) + [info exists params(context)] > 0 } {
		error "conflicting options specified"
	    }
	    set result ""
	    foreach name $names {
		if { $result != "" } {
		    append result "\n"
		}
		append result [format "  %-30s %s" $name [dict_get_safe $defs $name description]]
	    }
	    return $result
	}

	if { ![info exists params(context)] } {
	    set params(context) ""
	}

	set name [lsearch -all -inline -glob $names "[lindex $args 0]*"]
	if { [llength $name] != 1 } {
	    if { [llength $name] == 0 } {
		set name $names
	    }
	    error "unknown or ambiguous parameter \"[lindex $args 0]\": must be [join $name {, }]"
	}
	set name [lindex $name 0]

	if { [llength $args] == 2 } {
	    if { $params(all) } {
		error "conflicting options specified"
	    }

	    set value [lindex $args 1]
	    set type [dict_get_safe $defs $name type]
	    switch -- $type {
		string {
		    set fmt s
		}
		integer {
		    checkint $value
		    if { [dict exists $defs $name minimum] } {
			set minimum [dict get $defs $name minimum]
			if { $value < $minimum } {
			    error "value must be greater than $minimum"
			}
		    }
		    set fmt i
		}
		boolean {
		    checkbool $value
		    set fmt b
		}
		default {
		    error "unsupported parameter type \"$type\""
		}
	    }

	    if { [dict exists $defs $name setter] } {
		eval [list [dict get $defs $name setter] $value]
	    } else {
		tcf::send_command $chan ContextParams set ss$fmt e [list $params(context) $name $value]
	    }
	    return
	}

	if { [llength $args] != 1 } {
	    error {wrong # args: should be "configparams [options] [name [value]]"}
	}

	if { [dict exists $defs $name getter] } {
	    set result [eval [list [dict get $defs $name getter]]]
	    if { $params(all) } {
		set result [dict create "" $result]
	    }
	} else {
	    if { $params(all) } {
		set result [lindex [tcf::send_command $chan ContextParams getValues s eA [list $name]] 1]
	    } else {
		set result [lindex [tcf::send_command $chan ContextParams get ss eA [list $params(context) $name]] 1]
	    }
	}
	return $result
    }
    namespace export configparams
    setcmdmeta configparams categories {miscellaneous}
    setcmdmeta configparams brief {List, get or set configuration parameters}
    setcmdmeta configparams description {
SYNOPSIS {
    configparams <options>
        List name and description for available configuration
        parameters.  Configuration parameters can be global or
        connection specific, therefore the list of available
        configuration parameters and their value may change
        depending on current connection.

    configparams <options> <name>
        Get configuration parameter value(s).

    configparams <options> <name> <value>
        Set configuration parameter value.
}
OPTIONS {
    -all
        Include values for all contexts in result.

    -context [context]
        Specify context of value to get or set.  The default context
	is "" which represet the global default.  Not all options
	support context specific values.
}
RETURNS {
    Depends on the arguments specified.

    <none>
        List of paramters and description of each parameter

    <parameter name>
        Parameter value or error, if unsupported paramter is specified

    <parameter name> <paramater value>
        Nothing if the value is set, or error, if unsupported paramter is
        specified
}
EXAMPLE {
    configparams force-mem-accesses 1
        Disable access protection for dow, mrd, and mwr commands.

    configparams sdk-launch-timeout 100
        Change the SDK launch timeout to 100 second, used for running
        SDK batch mode commands.
}
}

    proc version { args } {
	set options {
	    {help "command help"}
	    {server "get the server version"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { $params(server) } {
	    set chan [getcurchan]
	    set services [::tcf::sync_eval [list ::tcf::get_services $chan]]
	    if { [lsearch $services "Xicom_v1.00"] == -1 } {
		return "Server version not available"
	    }
	    return [lindex [tcf send_command $chan Xicom_v1.00 getHwServerBuildInfo "" ess [list]] 1]
	} else {
	    return [::xsdb::get_version]
	}
    }
    namespace export version
    setcmdmeta version categories {miscellaneous}
    setcmdmeta version brief {Get SDK or TCF server version}
    setcmdmeta version description {
SYNOPSIS {
    version [options]
        Get SDK or TCF server version. When no option is specified,
        SDK build version is returned.
}
OPTIONS {
    -server
        Get the TCF server build version, for the active connection.
}
RETURNS {
    SDK or TCF Server version, on success.
    Error string, if server verison is requested when there is no connection.
}
}

    proc profile {args} {
	set options {
	    {help "command help"}
	    {freq "sampling frequency" {args 1}}
	    {scratchaddr "scratch address" {args 1}}
	    {out "output file" {args 1}}
	}
	variable profile_config
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	set chan [getcurchan]
	set ctx [getcurtarget]

	if { [info exists params(out)] } {
	    if { ([info exists params(freq)] || [info exists params(scratchaddr)]) } {
		error "conflicting options, use only one of -out or (-freq and -scratchaddr)"
	    }
	} else {
	    if { !([info exists params(freq)] && [info exists params(scratchaddr)]) } {
		error "invalid arguments, specify -freq and -scratchaddr"
	    }
	}

	if { [info exists params(freq)] } {
	    dict set profile_config sampfreq $params(freq)
	}
	if { [info exists params(scratchaddr)] } {
	    dict set profile_config scratchaddr $params(scratchaddr)
	}
	if { [info exists params(out)] } {
	    dict set profile_config outfile $params(out)
	    set prof_enable [::tcf::sync_eval [list xsdb::gprof::is_profiling_enabled]]
	    if { $prof_enable == 1 } {
		return [write_gprof_output $chan $ctx $params(out)]
	    } else {
		error "profiling not enabled"
	    }
	}
    }
    namespace export profile
    setcmdmeta profile categories {running}
    setcmdmeta profile brief {Configure and run the GNU profiler}
    setcmdmeta profile description {
SYNOPSIS {
    profile [options]
        Configure and run the GNU profiler. The profiling needs to enabled while
        building bsp and application to be profiled.
}
OPTIONS {
    -freq <sampling-freq>
        Sampling frequency.

    -scratchaddr <addr>
        Scratch memory for storing the profiling related data. It needs to be
        assigned carefully, as it should not overlap with the program sections.

    -out <file-name>
        Name of the output file for writing the profiling data. This option also
        runs the profiler and collects the data.
        If file name is not specified, profiling data is written to gmon.out
}
RETURNS {
    Depends on options used.

    -scratchaddr, -freq
        Returns nothing on successful configuration.
        Error string, in case of error.

    -out
        Returns nothing, and generates a file.
        Error string, in case of error.
}
EXAMPLE {
    profile -freq 10000 -scratchaddr 0
        Configure the profiler with a sampling frequency of 10000
        and scratch memory at 0x0

    profile -out testgmon.out
        Output the profile data in testgmon.out
}
}

    proc write_gprof_output { chan ctx filename } {
	set outfile ""

	# Read the histogram data from the target
	set data [read_hist_from_target $chan $ctx]

	set data [read_cg_from_target $chan $ctx $data]

	if { $filename != "" } {
	    set outfile $filename
	} else {
	    set outfile "gmon.out"
	}
	# Open file for writing the output
	set f [::open $outfile wb]

	# Write gprof header
	set fmt iu*

	# Gmon magic string
	set ghdr_cookie "gmon"
	puts -nonewline $f $ghdr_cookie

	# Version
	set ghdr_version 1
	set bindata [binary format $fmt $ghdr_version]

	# Spare 0s
	for {set j 0} {$j < 3} {incr j} {
	    append bindata [binary format $fmt 0]
	}
	puts -nonewline $f $bindata

	# Write gprof histogram data to file
	write_gprof_hist_data $f $data

	# Write gprof call graph data to file
	write_gprof_cg_data $f $data
	close $f
    }

    proc write_gprof_hist_data { fd data } {
	variable profile_config
	variable gmonparam
	set fmt iu*
	set fmtc cu*

	# Get no of gmon sections
	set ngsecs [dict get $data ngmonsecs]
	set bigendian [dict get $data bigendian]

	if { $bigendian == 1 } {
	    set fmt [string toupper $fmt 0 0]
	    set fmtc [string toupper $fmtc 0 0]
	}

	set lowpc [dict get $data sec0 lowpc]
	set secnr sec[expr {$ngsecs - 1}]
	set highpc [dict get $data $secnr highpc]
	set countsize [expr [expr $highpc - $lowpc] / 16]

	# Write gprof header
	# Write gmon tag
	set GMON_TAG_TIME_HIST 0
	set bindata [binary format $fmtc $GMON_TAG_TIME_HIST]
	puts -nonewline $fd $bindata

	# Write lowpc, highpc, size and sampling freq in header
	set bindata [binary format $fmt $lowpc]
	append bindata [binary format $fmt $highpc]
	append bindata [binary format $fmt $countsize]
	append bindata [binary format $fmt [dict get $profile_config sampfreq]]
	puts -nonewline $fd $bindata

	# Write units and abbreviations
	set hist_dimension "seconds"

	# Spare 0s
	set bindata ""
	for {set j 0} {$j < 8} {incr j} {
	    append bindata [binary format $fmtc 0]
	}

	set hist_abbrev "s"
	puts -nonewline $fd $hist_dimension
	puts -nonewline $fd $bindata
	puts -nonewline $fd $hist_abbrev

	# Write actual histogram data
	set secidx 0
	while {1} {
	    set secnr sec$secidx
	    set kcountsize [dict get $data $secnr kcountsize]

	    set gmonhist [dict get $data $secnr gmonhist]
	    binary scan $gmonhist $fmtc gmonhist

	    for {set histidx 0} {$histidx < [expr $kcountsize * 2]} {incr histidx} {
		set count [binary format $fmtc [lindex $gmonhist $histidx]]
		puts -nonewline $fd $count
	    }
	    set countsize [expr $countsize - $kcountsize]
	    incr secidx
	    if { $secidx == $ngsecs } {
		break
	    }

	    # current section's lowpc - last section's highpc
	    set d_lowpc [dict get $data $secnr lowpc]
	    set lastsecnr sec[expr {$ngsecs - 1}]
	    set d_highpc [dict get $data $lastsecnr highpc]
	    set d_kcountsize [expr [expr $d_highpc - $d_lowpc] / 16]

	    # Dummy Data fill
	    for {set i 0} {$i < [expr $d_kcountsize*2]} {incr i} {
		puts -nonewline $fd [binary format $fmt 0]
	    }

	    set countsize [expr $countsize - $d_kcountsize]

	    while { $kcountsize != 0 } {
		puts -nonewline $fd [binary format $fmtc 0]
		incr kcountsize -1
	    }
	}
    }

    proc write_gprof_cg_data { fd data } {
	variable profile_config
	variable gmonparam
	set fmt iu*
	set fmtc cu*
	set GMON_TAG_CG_ARC 1

	# Get no of gmon sections
	set ngsecs [dict get $data ngmonsecs]
	set bigendian [dict get $data bigendian]
	if { $bigendian == 1 } {
	    set fmt [string toupper $fmt 0 0]
	    set fmtc [string toupper $fmtc 0 0]
	}

	for {set secidx 0} {$secidx < $ngsecs} {incr secidx} {
	    set secnr sec$secidx
	    set tosz [dict get $data $secnr tosz]
	    set cgdata [dict get $data $secnr cgdata]
	    for {set i 0} {$i < $tosz} {incr i} {
		set rawfrompc [dict get [lindex $cgdata $i] raw_frompc]
		set rawselfpc [dict get [lindex $cgdata $i] raw_selfpc]
		set rawcnt [dict get [lindex $cgdata $i] raw_count]

		# Write GMON tag
		set bindata [binary format $fmtc $GMON_TAG_CG_ARC]

		append bindata [binary format $fmt $rawfrompc]
		append bindata [binary format $fmt $rawselfpc]
		append bindata [binary format $fmt $rawcnt]
		puts -nonewline $fd $bindata
	    }
	}
    }

    proc read_hist_from_target {chan ctx} {
	variable profile_config

	set arg [array get params]
	dict set arg chan $chan
	dict set arg ctx $ctx
	dict set arg profconfig $profile_config
	dict set arg profdata ""

	# Read gprof values from gprof variables (addresses)
	dict lappend arg actions {
	    set fmt iu
	    set profaddrs [::xsdb::gprof::get_prof_addresses]
	    set bigendian [::xsdb::gprof::get_prof_endianness]
	    dict set profdata bigendian $bigendian
	    set paramlist { cpufreq sampfreq binsize ngmonsecs gmonparam }
	    if { $bigendian == 1 } {
		set fmt [string toupper $fmt 0 0]
	    }

	    foreach parameter $paramlist {
		set tempaddr [dict get $profaddrs $parameter]
		::tcf::send_command $chan Memory get [list gprof_read_data_callback $argvar "" $parameter $fmt]
		::tcf::write $chan "siiii" [list $ctx $tempaddr 4 4 3]
		incr numreq
	    }
	    incr curaction
	}

	# Compare the values read from memory with values in elf
	# Read the gmon structure from memory
	dict lappend arg actions {
	    if { $numreq } {cache wait}

	    set cpufrqelf [::xsdb::gprof::get_prof_cpufreq]
	    if { $cpufrqelf != [dict get $profdata "cpufreq"] } {
		error "Profiling Data Memory Corrupted"
	    }

	    set sampfrqconf [dict get $profconfig sampfreq]
	    if { $sampfrqconf != [dict get $profdata "sampfreq"] } {
		error "Profiling Data Memory Corrupted"
	    }

	    if { [dict get $profdata "binsize"] != 4 } {
		error "Profiling Data Memory Corrupted"
	    }

	    set ngsecself [::xsdb::gprof::get_no_of_gmon_sections]
	    if { $ngsecself != [dict get $profdata "ngmonsecs"] } {
		error "Profiling Data Memory Corrupted"
	    }

	    set scratchaddr [dict get $profconfig scratchaddr]
	    if { $scratchaddr != [dict get $profdata "gmonparam"] } {
		error "Profiling Data Memory Corrupted"
	    }

	    # Read the gmon structure from memory
	    set gmondatasize [dict get [::xsdb::gprof::get_gmonparam_offsets] GPARAM_SIZE]
	    set profaddrs [::xsdb::gprof::get_prof_addresses]
	    for {set i 0} {$i < $ngsecself} {incr i} {
		set tempaddr [expr $scratchaddr + [expr $i * $gmondatasize]]
		::tcf::send_command $chan Memory get [list gprof_read_data_callback $argvar $i "gmondata" ""]
		::tcf::write $chan "siiii" [list $ctx $tempaddr 4 $gmondatasize 3]
		incr numreq
	    }
	    incr curaction
	}

	# Validate the values from gmon structure
	# Read the histogram data for each section
	dict lappend arg actions {
	    if { $numreq } {cache wait}

	    set fmt iuiuiuiuiuiuiuiuiuiu
	    set bigendian [::xsdb::gprof::get_prof_endianness]
	    if { $bigendian == 1 } {
		set fmt IuIuIuIuIuIuIuIuIuIu
	    }
	    set gmonarray [::xsdb::gprof::get_gmonparamstruct]
	    set ngsecs [dict get $profdata "ngmonsecs"]

	    for {set i 0} {$i < $ngsecs} {incr i} {
		set name sec$i
		set value [dict get $profdata $name gmondata]
		binary scan $value $fmt g_start g_hist g_histsz g_cg_from g_cg_fromsz g_cg_to g_cg_tosz g_lowpc g_highpc g_textsz

		set gmonsec [lindex $gmonarray $i]

		dict set profdata $name kcountsize $g_histsz
		dict set profdata $name lowpc $g_lowpc
		dict set profdata $name highpc $g_highpc
		dict set profdata $name textsize [expr $g_highpc - $g_lowpc]
		dict set profdata $name section_name [dict get $gmonsec secname]

		# Compare lowpc/highpc values, to check if data is not corrupted
		if { $g_lowpc != [dict get $gmonsec lowpc] } {
		    error "Profiling Data Memory Corrupted"
		}
		if { $g_highpc != [dict get $gmonsec highpc] } {
		    error "Profiling Data Memory Corrupted"
		}

		set fmt cu*
		if { $bigendian == 1 } {
		    set fmt [string toupper $fmt 0 0]
		}

		# Read the histogram data for each section
		set tempaddr $g_hist
		set nbytes [expr $g_histsz * 2]
		::tcf::send_command $chan Memory get [list gprof_read_data_callback $argvar $i "gmonhist" ""]
		::tcf::write $chan "siiii" [list $ctx $tempaddr 1 $nbytes 3]
		incr numreq
	    }
	    incr curaction
	}

	dict set arg result {
	    set profdata
	}
	return [process_tcf_actions $arg]
    }

    proc read_cg_from_target {chan ctx profdata} {
	variable profile_config

	set arg [array get params]
	dict set arg chan $chan
	dict set arg ctx $ctx
	dict set arg profconfig $profile_config
	dict set arg profdata $profdata

	# Read the histogram data for each section
	dict lappend arg actions {
	    set fmt iu*
	    set fmtarray iuiuiuiuiuiuiuiuiuiu
	    set bigendian [::xsdb::gprof::get_prof_endianness]
	    if { $bigendian == 1 } {
		set fmt [string toupper $fmt 0 0]
		set fmtarray IuIuIuIuIuIuIuIuIuIu
	    }

	    set gmonarray [::xsdb::gprof::get_gmonparamstruct]
	    set ngsecs [dict get $profdata "ngmonsecs"]

	    for {set i 0} {$i < $ngsecs} {incr i} {
		set name sec$i
		set value [dict get $profdata $name gmondata]
		binary scan $value $fmtarray g_start g_hist g_histsz g_cg_from g_cg_fromsz g_cg_to g_cg_tosz g_lowpc g_highpc g_textsz

		set gmonsec [lindex $gmonarray $i]

		# Compare size values, to check if data is not corrupted
		if { $g_cg_fromsz <= 0 } {
		    error "Profiling Data Memory Corrupted !!!\nEnsure program does not overwrite profiling data memory"
		}
		if { $g_cg_tosz <= 0 } {
		    error "Profiling Data Memory Corrupted !!!\nEnsure program does not overwrite profiling data memory"
		}

		# Large data, could be corrupted
		if { $g_cg_tosz > 0x1000000 } {
		    error "Profiling Data Memory Corrupted !!!\nEnsure program does not overwrite profiling data memory"
		}

		# Read gmon data from memory
		set fromstructsize 8
		set fromaddr $g_cg_from
		set fromsize [expr $g_cg_fromsz * $fromstructsize]
		::tcf::send_command $chan Memory get [list gprof_read_data_callback $argvar "" "frombin" ""]
		::tcf::write $chan "siiii" [list $ctx $fromaddr 4 $fromsize 3]
		incr numreq

		set tostructsize 12
		set toaddr $g_cg_to
		set tosize [expr $g_cg_tosz * $tostructsize]
		::tcf::send_command $chan Memory get [list gprof_read_data_callback $argvar "" "tobin" ""]
		::tcf::write $chan "siiii" [list $ctx $toaddr 4 $tosize 3]
		incr numreq
	    }
	    incr curaction
	}

	# Read the cg data for each section
	dict lappend arg actions {
	    if { $numreq } {cache wait}

	    set fmt iu*
	    set fmtarray iuiuiuiuiuiuiuiuiuiu
	    set bigendian [::xsdb::gprof::get_prof_endianness]
	    if { $bigendian == 1 } {
		set fmt [string toupper $fmt 0 0]
		set fmtarray IuIuIuIuIuIuIuIuIuIu
	    }

	    set gmonarray [::xsdb::gprof::get_gmonparamstruct]
	    set ngsecs [dict get $profdata "ngmonsecs"]

	    for {set i 0} {$i < $ngsecs} {incr i} {
		set name sec$i
		set value [dict get $profdata $name gmondata]
		binary scan $value $fmtarray g_start g_hist g_histsz g_cg_from g_cg_fromsz g_cg_to g_cg_tosz g_lowpc g_highpc g_textsz

		set k 0
		set cgfunclist {}

		set frombin [dict get $profdata frombin]
		binary scan $frombin $fmt frombin
		set profdata [dict remove $profdata frombin]

		set tobin [dict get $profdata tobin]
		binary scan $tobin $fmt tobin
		set profdata [dict remove $profdata tobin]

		for {set frmidx 0} {$frmidx < $g_cg_fromsz} {incr frmidx} {
		    set frompc [lindex $frombin [expr 2*$frmidx]]
		    set toidx [lindex $frombin [expr [expr 2*$frmidx] + 1]]

		    while { $toidx != 0xFFFF } {
			set cgdict {}
			# Start to index backwards
			set toidx [expr $g_cg_tosz - $toidx - 1]
			set selfpc [lindex $tobin [expr 3*$toidx]]
			set rawcnt [lindex $tobin [expr [expr 3*$toidx] + 1]]
			if { $rawcnt <= 0 } {
			    error "Invalid Profiling Data on Target"
			}
			lappend cgfunclist [dict create raw_frompc $frompc raw_selfpc $selfpc raw_count $rawcnt]
			set toidx [lindex $tobin [expr [expr 3*$toidx] + 2]]
		    }
		}
		dict set profdata sec$i fromsz $g_cg_fromsz
		dict set profdata sec$i tosz $g_cg_tosz
		dict set profdata sec$i cgdata $cgfunclist
	    }
	    incr curaction
	}

	dict set arg result {
	    set profdata
	}
	return [process_tcf_actions $arg]
    }

    proc mbprofile {args} {
	set options {
	    {help "command help"}
	    {low "low address" {args 1}}
	    {high "high address" {args 1}}
	    {freq "mb clk frequency" {args 1}}
	    {count-instr "count instructions"}
	    {start "enable/start profing"}
	    {cumulate "cumulative data"}
	    {stop "disable/stop profiling"}
	    {out "output file" {default "gmon.out" args 1}}
	}
	variable mb_profile_config
	array set params [::xsdb::get_options args $options]
	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { [dict_get_safe $mb_profile_config mbprof_loaded] != 1 } {
	    package require xsdb::mbprofiler
	    dict set mb_profile_config mbprof_loaded 1
	}

	if { $params(start) || $params(stop) } {
	    if { $params(start) && $params(stop) } {
		error "conflicting options, use only one of -start or -stop"
	    }
	    if { $params(count-instr) || $params(cumulate) || [info exists params(low)] || [info exists params(high)] || [info exists params(freq)] } {
		error "conflicting options, use only one of -start or -stop or (-low, -high, freq, -count-instr and/or -cumulate)"
	    }
	    if { [dict_get_safe $mb_profile_config cfg_done] == 1 } {
		if { $params(start) } {
		    xsdb::mbprofiler::mbprof_start
		    dict set mb_profile_config prof_started 1
		}
		if { $params(stop) } {
		    if { [dict_get_safe $mb_profile_config prof_started] == 1 } {
			xsdb::mbprofiler::mbprof_gmonout $params(out)
			if { [dict get $mb_profile_config cnt_instr] == 0 } {
			    xsdb::mbprofiler::mbprof_disassembly_annotate "[file rootname $params(out)].asm"
			}
		    } else {
			error "Profiler not started, please start the profiler using mbprofile -start command"
		    }
		}
	    } else {
		error "Profiling not configured, please configure before starting or stopping the profiling"
	    }
	} else {
	    dict set mb_profile_config bscan [get_jtag_bscan]
	    set elf [dict get $mb_profile_config elf]
	    set elf_text_addr [get_elf_text_addrs $elf]
	    if { ([info exists params(high)] == 1 && $params(high) == "high") || [info exists params(high)] != 1 } {
		set params(high) [dict get $elf_text_addr high_addr]
	    }
	    if { ([info exists params(low)] == 1 && $params(low) == "low") || [info exists params(low)] != 1 } {
		set params(low) [dict get $elf_text_addr low_addr]
	    }
	    if { $params(high) <= $params(low) } {
		error "High address can't be same or smaller than low address"
	    }
	    if { [info exists params(freq)] != 1 } {
		set params(freq) 100000000
	    }
	    dict set mb_profile_config low_addr $params(low)
	    dict set mb_profile_config high_addr $params(high)
	    dict set mb_profile_config freq $params(freq)
	    dict set mb_profile_config cumulate $params(cumulate)
	    dict set mb_profile_config cnt_instr $params(count-instr)

	    xsdb::mbprofiler::mbprof_set_config $mb_profile_config
	    xsdb::mbprofiler::mbprof_init
	    dict set mb_profile_config cfg_done 1
	    dict set mb_profile_config prof_started 0
	}
    }
    namespace export mbprofile
    setcmdmeta mbprofile categories {running}
    setcmdmeta mbprofile brief {Configure and run the MB profiler}
    setcmdmeta mbprofile description {
SYNOPSIS {
    mbprofile [options]
        Configure and run the MB profiler, a non-intrusive profiler
        for profiling the application running on MB. The output file is
        generated in gmon.out format. The results can be viewed using
        gprof editor. In case of cycle count, an annotated disassembly
        file is also generated clearly marking time taken for execution
        of instructions.
}
OPTIONS {
    -low <addr>
        Low address of the profiling address range.

    -high <addr>
        High address of the profiling address range.

    -freq <value>
        Microblaze clock frequency.
        Default is 100MHz.

    -count-instr
        Count no. of executed instructions.
        By default no. of clock cycles of executed instructions are counted.

    -cumulate
        Cumulative profiling.
        Profiling without clearing the profiling buffers.

    -start
        Enable and start profiling.

    -stop
        Disable/stop profiling

    -out <filename>
        Output profiling data to file.
        <filename> Name of the output file for writing the profiling data.
        If file name is not specified, profiling data is written to gmon.out
}
RETURNS {
    Depends on options used.
    -low, -high, -freq, -count-instr, -start, -cumulate
        Returns nothing on successful configuration.
        Error string, in case of error.

    -stop
        Returns nothing, and generates a file.
        Error string, in case of error.
}
EXAMPLE {
    mbprofile -low 0x0 -high 0x3FFF
        Configure the mb-profiler with address range 0x0 to 0x3FFF for
        profiling to count the clock cycles of executed instructions.

    mbprofile -start
        Enable and start profiling.

    mbprofile -stop -out testgmon.out
        Output the profile data in testgmon.out

    mbprofile -count-instr
        Configure the mb-profiler to profile for entire program address
        range to count no. of instructions executed.
}
}

    proc get_jtag_bscan { } {
	set arg [array get params]
	dict set arg chan [getcurchan]
	dict set arg ctx [getcurtarget]
	dict lappend arg actions {
	    set rc1 [lindex [get_ctx_data $chan $ctx RunControl:context] 1]
	    set bscan "[string range [dict get $rc1 JtagChain] 4 end]"
	    incr curaction
	}
	dict set arg result {
	    set bscan
	}
	return [process_tcf_actions $arg]
    }

    proc get_elf_text_addrs { elf } {
	set esh_list [::tcf::sync_eval [list get_elf_exec_sections $elf]]
	foreach esh $esh_list {
	    if { [dict get $esh name] == ".text" } {
		set low_addr [dict get $esh addr]
		set high_addr [expr $low_addr + [dict get $esh size]]
		return [dict create low_addr $low_addr high_addr $high_addr]
	    }
	}
	error "cannot find addresses for .text section"
    }
}

set xsdb_src_dir [file dirname [info script]]
source $xsdb_src_dir/profiler.tcl
set ::xsdb::xsdb_src_dir $xsdb_src_dir
::tcf::sync_eval [list set_xsdb_src_dir $xsdb_src_dir]
unset xsdb_src_dir

::tcf::sync_eval {
    set srcvar "[namespace current]::xsdb_src_dir"
    source [set $srcvar]/streamsock.tcl
    source [set $srcvar]/streamreader.tcl
}

package provide xsdb $::xsdb::version

package require xsdb::jtag
package require xsdb::tfile
package require xsdb::server
package require xsdb::gdbremote

catch {
    package require hsi
    package require hsi::utils
    namespace eval hsi {namespace import ::common::*}
    namespace eval hsi {namespace export *}
    namespace eval hsi {namespace ensemble create -command ::hsi}
    if { [string first "xsct" [file tail [info nameofexecutable]]] != -1 } {
	namespace import ::hsi::utils::*
    }
}


if { [info commands tcl::concat] == "" } {
    interp alias {} tcl::concat {} ::concat
}
if { [info commands tcl::llength] == "" } {
    interp alias {} tcl::llength {} ::llength
}

# unknown proc from rdi to support partial commands in non-interactive mode
rename unknown xsdb::tcl::unknown
proc unknown { args } {
    # auto expand command (CR576119)
    set commands {}
    set name [lindex $args 0]
    if { ![catch {set candidates [info commands $name*]}] } {
	foreach candidate $candidates {
	    if { [string first $name $candidate] == 0 } {
		lappend commands $candidate
	    }
	}
    }
    if {[tcl::llength $commands] == 1} {
	# found a match
	set ret [catch {uplevel 1 [lreplace $args 0 0 [lindex $commands 0]]} result]
    } elseif {[tcl::llength $commands]} {
	# more than one match
	# still call xsdb::tcl::unknown in case this is an system command
	set ret [catch {uplevel 1 [list xsdb::tcl::unknown {*}$args]} result]
	if {$ret!=0} {
	    # if this was a system command and if it failed, then prepend
	    # the system error to the ambiguous error. checking for system
	    # comamnd is too much, just check if error is different from
	    # the standard ambiguous error (cr619468)
	    set system_error ""
	    if {[string first "ambiguous" $result] == -1} {
		set system_error "$result\n"
	    }
	    return -code error "${system_error}ambiguous command name \"$name\": [lsort $commands]"
	}
    } else {
	# call xsdb::tcl::unknown
	set ret [catch {uplevel 1 [list xsdb::tcl::unknown {*}$args]} result]
    }
    return -code $ret $result
}

if { [info command ::xsdb::abort_check] != "" } {
    rename ::while ::xsdb::_while
    proc ::while {test command} {
	set code [uplevel 1 [list catch [list ::xsdb::_while $test [tcl::concat ::xsdb::abort_check ";" $command]] _xsdb_loop_result _xsdb_loop_options]]
	upvar _xsdb_loop_result result
	upvar _xsdb_loop_options options
	return -options $options -code $code $result
    }

    rename ::for ::xsdb::_for
    proc ::for {start test next body} {
	set code [uplevel 1 [list catch [list ::xsdb::_for $start $test $next [tcl::concat ::xsdb::abort_check ";" $body]] _xsdb_loop_result _xsdb_loop_options]]
	upvar _xsdb_loop_result result
	upvar _xsdb_loop_options options
	return -options $options -code $code $result
    }
} else {
    proc ::xsdb::abort_check {} {}
    proc ::xsdb::abort_clear {} {}
}
