# COPYRIGHT NOTICE
# Copyright 1986-1999, 2001-2009, 2014 Xilinx, Inc. All Rights Reserved.
# 

proc printDeprecated {} {
  puts "*****************************************************************************"
  puts "* WARNING                                                                   *"
  puts "* This script has been deprecated and will be removed in a future release!! *"
  puts "* Script : bup.tcl                                                          *"
  puts "*****************************************************************************"
}
printDeprecated

#############################################################################
# Print usage message
#############################################################################
proc usage {prog_name} {
  printDeprecated
  puts "Usage: $prog_name <ip_file_path>"
}

#############################################################################
# Set the enable status on a list of files
#############################################################################
proc set_file_enable {val file_list} {
  ## TODO: use a for-loop instead of file list.  change to file list after CR
  ## 672192 is fixed...
  foreach a_file $file_list {
    set_property IS_ENABLED $val $a_file
  }
}

#############################################################################
# Generate a structural netlist for the specified IP file.  Disable the IP
# synthesis HDL and add the netlist to the project.
#############################################################################
proc bup {ip_file} {
  printDeprecated

  if { [get_files $ip_file -quiet] == "" } {
    puts "ERROR: file '$ip_file' does not exist.  Please specify the full path to an IP file in current project"
    usage [lindex [info level 0] 0]
    return 1
  }

  # get the IP name
  set file_tail [file tail $ip_file]
  set ip_name [file rootname $file_tail]

  # get the file extention to check if it is an IP
  set file_extn [file extension $file_tail]
  set file_extn [string tolower $file_extn]
  if { $file_extn == ".xci" } {
    # verify that the IP exists
    set ip [get_ips $ip_name -quiet]
    if { $ip == "" } {
      puts "ERROR: could not find IP for file '$ip_file'"
      usage [lindex [info level 0] 0]
      return 1
    }
  }

  puts "..Generating structural netlist for IP '$ip_name'..."

  # save current top so that it can be restored after synth_design
  set top_orig [get_property top [current_fileset]]

  # disable all XDC files but IP XDC
  set all_xdc [get_files -quiet -filter IS_ENABLED==true *.xdc]
  set ip_xdc [get_files -of_objects [get_files $ip_file -quiet] *.xdc -quiet]
  set non_ip_xdc ""
  foreach xdc_file $all_xdc {
    if { [lsearch $ip_xdc $xdc_file] == -1 } {
      lappend non_ip_xdc $xdc_file
    }
  }
  set_file_enable false $non_ip_xdc
  set_param synth.constraint.skipPostLoad 1

  # run synth_design...
  puts "..Running synth_design -top $ip_name -mode out_of_context..."
  set synth_design_fail 0
  if { [catch {synth_design -top $ip_name -mode out_of_context} ] } {
    set synth_design_fail 1
  }


  # restore top and disabled XDC files
  set_param synth.constraint.skipPostLoad 0
  set_property top $top_orig [current_fileset]
  set_file_enable true $non_ip_xdc

  if { $synth_design_fail == 1 } {
    puts "ERROR: synth_design failed with errors.  See the tcl console for error messages."
    return 1
  }

  # write the netlist to <ip_dir>/bup
  set ip_dir [file dirname [get_files $ip_file]] 
  set nl_dir [file join $ip_dir bup]
  file mkdir $nl_dir
  set netlist_file [file join $nl_dir $ip_name.v]
  rename_ref -prefix_all $ip_name
  write_verilog $netlist_file -force
  puts "..Writing netlist to $netlist_file..."

  close_design

  # mark the IP synthesis files so they don't participate in synthesis
  set ip_synth_files [get_files -all -of_objects [get_files $ip_file] -filter {USED_IN_SYNTHESIS==true && file_type!=XDC && file_type!=XCI}]
  # the filter above doesn't seem to remove the XCI.  remove it here
  set ip_nonsynth_files ""
  foreach ip_gen_file $ip_synth_files {
    if { $ip_gen_file != $ip_file && 
         [file extension $ip_gen_file] != ".xdc" } {
      lappend ip_nonsynth_files $ip_gen_file
    }
  }
  puts "..Set IP HDL files USED_IN_SYNTHESIS=false..."
  set_property USED_IN_SYNTHESIS false $ip_nonsynth_files

  # add the synthesized IP netlist to the project to replace the IP HDL files
  puts "..Add IP netlist file to project: '$netlist_file'..."
  add_files $netlist_file
  set_property USED_IN_SIMULATION false [get_files $netlist_file]

  return 0
}

#############################################################################
# Reverse a previous BUP
#############################################################################
proc unbup {ip_file} {
  if { [get_files $ip_file -quiet] == "" } {
    puts "ERROR: file '$ip_file' does not exist.  Please specify the full path to an IP file in current project"
    usage [lindex [info level 0] 0]
    return 1
  }

  # get the IP name
  set file_tail [file tail $ip_file]
  set ip_name [file rootname $file_tail]

  # get the file extention to check if it is an IP
  set file_extn [file extension $file_tail]
  set file_extn [string tolower $file_extn]
  set ip $file_tail
  if { $file_extn == ".xci" } {
    # verify that the IP exists
    set ip [get_ips $ip_name -quiet]
    if { $ip == "" } {
      puts "ERROR: could not find IP for file '$ip_file'"
      usage [lindex [info level 0] 0]
      return 1
    }
  }

  # verify that bup has been run on the IP
  set ip_netlist_root [file join "*" "bup" $ip_name.v]
  set ip_netlist_file [get_files $ip_netlist_root -quiet]
  if { $ip_netlist_file == "" } {
    puts "ERROR: BUP has not been run on file '$ip_file'"
    usage [lindex [info level 0] 0]
    return 1
  }

  puts "..Removing structural netlist for IP '$ip_name'..."

  # remove the structural verilog file
  file delete -force $ip_netlist_file
  remove_files $ip_netlist_file

  # reset and regenerate IP to re-enable IP synthesis HDL
  if { $file_extn == ".xci" } {
    reset_target synthesis $ip
    generate_target synthesis $ip
  } else {
    reset_target synthesis [get_files $ip]
    generate_target synthesis [get_files $ip]
  }

  return 0
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
