# COPYRIGHT NOTICE
# Copyright 2014 Xilinx, Inc. All Rights Reserved.
# 

namespace eval ::xilinx::synth_bd {

# proc: validate
# Summary:
#   Execute command to validate output is as expected
#
# Argument Usage: 
#:    validate cmd expected ?failMsg?
# 
# Parameters:
#     cmd            - Command to validate
#     expected       - Expected value of command
#     failMsg        - Message issued on failure to help user identify problem
#
# Return Value:
#     void           - An error is thrown if validation fails
# 
# Example:
#     
#:     # will validate value, in the case an error is thrown
#:     set three 3
#:     validate { eval 2 + 2 } $three "The output of the addition was expected to be '${three}'"
#
proc validate { cmd expected { failMsg {} } } {
  catch { uplevel $cmd } output
  if { $output != $expected } {
    error "\n${failMsg}\n"
  }
}

# proc: dirIsWritable
# Summary:
#   Returns true if directory exists and is writable
#
# Argument Usage: 
#:    dirIsWritable dir
# 
# Parameters:
#     dir            - The directory to test
#
# Return Value:
#     1              - If directory exists and is writable
#     0              - Otherwise
# 
# Example:
#     
#:     # checks if /tmp exists and is writable
#:     if { [ dirIsWritable "/tmp" ] } { ... }
#
proc dirIsWritable dir {
  if { [ file exists $dir ] && [ file writable $dir ] } { return 1 }
  return 0
}


# proc: mkTmpDir
# Summary:
#   Determine unique name in temp location and make dir
#
# Argument Usage: 
#:    mkTmpDir
# 
# Parameters:
#     void           - unused
#
# Return Value:
#     newTmpDir      - The newly created and unique temp dir, else error
# 
# Example:
#     
#:     # will attempt to identify a unique temporary directory and if 
#:     # possible then the directory will be created
#:     set tmpDir [ mkTmpDir ] 
#
proc mkTmpDir {} {

  set dirPrepend    "synth_bd_"
  set dirPostpend   ""
  set tmpDir        ""
  
  # try hard coded directories
  set testTmpDirs [ list [ pwd ] ]
  foreach testTmpDir $testTmpDirs {
    if { [ dirIsWritable $testTmpDir ] } { 
      set tmpDir [ file join $testTmpDir .Xil ]
      file mkdir $tmpDir
      break
    }
  }
  
  # if no temp was found as writable, give up and throw
  if { ( "${tmpDir}" == "" ) || ! [ dirIsWritable $tmpDir ] } {
    error "Failed to find a writable temporary directory!\n  Tried: '${testTmpDirs}'\n"
  }
  
  # we have found a writable temp...
  for { set i 1 } { $i <= 100 } { incr i } {
    set newTmpDir [ file join $tmpDir "${dirPrepend}${i}${dirPostpend}" ]
    if { [ file exists $newTmpDir ] } { continue }
    break
  }
  if { [ file exists $newTmpDir ] } { 
    error "Unable to create a unique temporary directory!\nRemove all temporary directories in: '[ file join ${tmpDir} ${dirPrepend}*${dirPostpend}']"
  }
  file mkdir $newTmpDir
  if { ! [ dirIsWritable $newTmpDir ] } {
    error "Failed to create a writable temporary directory!\nTried: $newTmpDir"
  }
  return $newTmpDir
}


# proc: synth_bd_
# Summary:
#   Used to synthesize an out-of-context (OOC) Block Design (BD)
#
# Argument Usage: 
#:    synth_bd_ sIPIDesign sTmpDir iJobs sLsf
# 
# Parameters:
#     sLsf           - command to be used with launch_runs -lsf
#                      this is mutually exclusive from localJobs!
#     iJobs          - number of jobs to be used on the local machine
#                      used with launch_runs -jobs
#     sTmpDir        - temporary directory to create project in
#     sIPIDesign     - Block Design object to run synthesis on
#
# Return Value:
#     void           - unused
# 
# Example:
#     
#:     # will synthesize all of the OOC BD's cores, using 4 local processes
#:     synth_bd_ [ get_files block_1.bd ] /tmp/user/unique 4 {}
#:    
#:     # will synthesize all of the OOC BD's cores, using lsf
#:     synth_bd_ [ get_files block_1.bd ] /tmp/user/unique 0 'short|3|-W 60'
#
proc synth_bd_ { sIPIDesign sTmpDir iJobs sLsf { verbose 0 } } {

  # 1. Create a disk project to perform OOC on the IPs 

  ## 1a. Record the properties of interest the "diskless" project
  set sPart               [ get_property PART                    [ current_project ] ]
  set sSimLanguage        [ get_property SIMULATOR_LANGUAGE      [ current_project ] ]
  set sTargetLanguage     [ get_property TARGET_LANGUAGE         [ current_project ] ]
  set sTargetSimulator    [ get_property TARGET_SIMULATOR        [ current_project ] ]
  set sBoardPartRepoPaths [ get_property BOARD_PART_REPO_PATHS   [ current_project ] ]
  set sBoardPart          [ get_property BOARD_PART              [ current_project ] ]

  ## 1b. Create the project
  set sProject "tmpSynthBd"
  set sProjectDir [ file join $sTmpDir $sProject ]
  if { $verbose } { puts "Creating temporary project '${sProject}' in dir: '${sProjectDir}'" }
  create_project $sProject $sProjectDir -part $sPart
  if { $verbose } { puts "Created temporary project at: '[ get_property DIRECTORY [ current_project ] ]'" }

  ## catch here to close project on failure
  set failed [ catch {

    ## 1c. Set the properties on the "disk" project that was just created
    # must support the use of the project property over the parameter for this project
    set_property SIMULATOR_LANGUAGE     $sSimLanguage        [ current_project ] 
    set_property TARGET_LANGUAGE        $sTargetLanguage     [ current_project ] 
    set_property TARGET_SIMULATOR       $sTargetSimulator    [ current_project ] 

    # Must enable editing to change BOARD_PART_REPO_PATHS 
    set bIsEditable [ get_param project.boardPartRepoPaths.editable ]
    set_param project.boardPartRepoPaths.editable 1
    set_property BOARD_PART_REPO_PATHS  $sBoardPartRepoPaths [ current_project ] 
    # Restore editable parameter for BOARD_PART_REPO_PATHS
    set_param project.boardPartRepoPaths.editable $bIsEditable

    set_property BOARD_PART             $sBoardPart          [ current_project ]

    if { $verbose } { puts "Adding BD file to temporary project: '${sIPIDesign}'" } 
    # sIPIDesign is a BD first-class object, we convert to string to add as a file path
    set sTmpIPIDesign [ add_file "${sIPIDesign}" ] 

    # Sanity check, should never encounter this
    validate { get_property GENERATE_SYNTH_CHECKPOINT $sTmpIPIDesign } "1" "Sanity check failed: The Block Design must have 'GENERATE_SYNTH_CHECKPOINT' set to '1' (true)"

    # 2. Create the OOC BD's IP Runs
    if { $verbose } { puts "Creating IP Runs for BD '${sTmpIPIDesign}' ..." }
    set sRuns [ create_ip_run [ get_files $sTmpIPIDesign ] ]
    if { $verbose } { puts "Done creating IP Runs for BD '${sTmpIPIDesign}'." }

    # 3. Build and invoke the launch_runs command
    set sLaunchOptions {}
    if { $iJobs > 0 } {
      lappend sLaunchOptions [ list -jobs $iJobs ]
    }
    if { "$sLsf" != "" } {
      lappend sLaunchOptions [ list -lsf $sLsf ]
    }
    lappend sLaunchOptions $sRuns
    if { $verbose } { puts "Using command to fire runs: launch_runs [ join $sLaunchOptions { } ]" }
    eval "launch_runs [ join $sLaunchOptions { } ]"

    # 4. Wait for all of the runs to complete
    #    TODO: If a run should error out, terminate the remaining running runs.
    foreach sRun $sRuns {
      catch { wait_on_run $sRun } returned
    }

  } returned ]

  # 5. Cleanup after ourselves
  # TODO: What do we do with the OOC synthesis log output (e.g. echo it out to the disk console)?
  close_project

  if { $failed } { error $returned }

}


# proc: synth_bd
# Summary:
#   Used to synthesize an out-of-context (OOC) Block Design (BD)
#
# Argument Usage: 
#:    synth_bd ( ?-lsf lsfCommand? | ?-jobs localJobs? ) ?-help? bdFileObject
# 
# Parameters:
#     lsfCommand     - command to be used with launch_runs -lsf
#                      this is mutually exclusive from localJobs!
#     localJobs      - number of jobs to be used on the local machine
#                      used with launch_runs -jobs
#     bdFileObject   - Block Design object to run synthesis on
#
# Return Value:
#     void           - unused
# 
# Example:
#     
#:     # Synthesize all IP within OOC BD 
#:     synth_bd [ get_files block_1.bd ]
#:   
#:     # Synthesize all IP within OOC BD, using 4 cores
#:     synth_bd -jobs 4 [ get_files block_1.bd ]
#:   
#
proc synth_bd args {

  # 0. Handle command line

  ## 0a. Help
  set helper {
synth_bd

Description: 
(User-written application)
Runs synthesis for an out-of-context (OOC) Block Design (BD).


Syntax: 
  synth_bd [-lsf <string> | -jobs <integer>] [-help] [-verbose] [-keep] <file>

Returns: 
true (0) if success, else an error will be thrown

Usage: 
  Name                  Description
  ---------------------------------
  [-lsf]                The LSF string to be used to submit synthesis runs to
                        the LSF queue.
                        Default: empty
  [-jobs]               Local processes to use while running the synthesis runs
                        Default: 0
  [-keep]               Keep the temporary directory and project
  [-verbose]            Print verbose messaging
  [-help]               Print this help
  <file>                The Block Design file object to run synthesis for

Categories: 
xilinxtclstore,projutils,user-written
Description:

  Runs synthesis for an out-of-context (OOC) Block Design (BD). This command 
  will create a project on disk that will add the BD design, import the needed
  project settings, and run all of the OOC BD child IP runs. 

  At the end of the OOC BD child IP runs, the project is destroyed and the 
  remote BD runs are completed.

Arguments:

  -help - (Optional) Print this help.

  -verbose - (Optional) Print verbose messaging.

  -keep - (Optional) Keep temporary directory and project after synth_bd has finished.

  -jobs - (Optional) Use number of local processes. Required argument should be
  an integer from 0 to n, where 'n' is the number of available processors. If 
  this value is set to 0, then the -jobs switch will not be set on the 
  corresponding launch_runs command. 
  Default: 0

  -lsf - (Optional) Use LSF to launch jobs. Required argument should be of the 
  form '<queue>|<max_concurrent_jobs>|<extra_bsub_options>'
  Default: empty

  Note: The -lsf and -jobs switches are mutually exclusive (one or neither)

  <file> - (Required) The Block Design file object to run synthesis for

Examples:
  
  # Synthesize all IP within OOC BD 
  synth_bd [ get_files block_1.bd ]

  # Synthesize all IP within OOC BD, using 4 cores
  synth_bd -jobs 4 [ get_files block_1.bd ]
  } 
## end of help


  ## 0b. Parse arguments
  set sLsf "" 
  set iJobs 0
  set verbose 0
  set clean 1
  set sIPIDesign {}
  for { set index 0 } { $index < [ llength $args ] } { incr index } {
    switch -exact -- [ lindex $args $index ] {
      {-lsf}       { set sLsf [ lindex $args [ incr index ] ] }
      {-jobs}      { set iJobs [ lindex $args [ incr index ] ] }
      {-help}      { puts $helper; return 0 }
      {-verbose}   { set verbose 1 }
      {-keep}      { set clean 0 }
      default      { lappend sIPIDesign [ lindex $args $index ] }
    }
  }

  ## 0c. Validate input 
  validate { llength $sIPIDesign } "1" "A single Block Design file object must be provided, received: ${sIPIDesign}"
  validate { get_property CLASS $sIPIDesign } "file" "Only 'file' objects are supported"
  validate { get_property FILE_TYPE $sIPIDesign } "Block Designs" "Only 'Block Design' file types are supported"
  validate { get_property GENERATE_SYNTH_CHECKPOINT $sIPIDesign } "1" "The Block Design must have 'GENERATE_SYNTH_CHECKPOINT' set to '1' (true)"
  validate { expr ( "{${sLsf}}" != "{}" ) && ( $iJobs > 0 ) } 0 "Switches '-lsf' and '-jobs' are mutually exclusive (only one or neither can be specified)"

  # 1. Get and create temporary directory
  set sTmpDir [ mkTmpDir ]
  if { $verbose } { puts "Using temporary directory: $sTmpDir" }

  # 2. Make sure that the IPI design is up-to-date
  #    TODO: Check to see if IPI is up-to-date before generating all of the targets
  generate_target all [ get_files $sIPIDesign ]

  # 3. Remove any IP instances from memory
  #    Note: This must be done since the IPI design is being modified out-of-process
  set_property REGISTERED_WITH_MANAGER 0 [ get_files $sIPIDesign ]

  # 4. Run and catch synth_bd 
  set failed [ catch { synth_bd_ $sIPIDesign $sTmpDir $iJobs $sLsf $verbose } returned ] 

  # 5. Re-register (if needed) and clean-up
  set_property REGISTERED_WITH_MANAGER 1 [ get_files $sIPIDesign ]

  # 6. Clean-up if keep was not specified
  if { $clean } {
    if { $verbose } { puts "Attempting to clean-up temporary directory: '${sTmpDir}'" }
    file delete -force $sTmpDir
    if { [ file exists $sTmpDir ] } { puts "Attempt to delete temporary directory failed: '${sTmpDir}'" }
  } else {
    puts "Output files will not be cleaned in directory: '${sTmpDir}'"
  }

  # 7. Re-throw if a failure occurred
  if { $failed } { error $returned }

  return 0

}

namespace export synth_bd;

}; # namespace ::xilinx::synth_bd

namespace import ::xilinx::synth_bd::synth_bd


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
