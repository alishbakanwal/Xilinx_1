# COPYRIGHT NOTICE
# Copyright 1986-1999, 2001-2009 Xilinx, Inc. All Rights Reserved.
#

# TODO - add namespace and test

proc getFileSystem {} {
   # tries to determine what the host platform is
   if {[info exists tcl_platform(host_platform)]} {
      # this is a jacl (planAhead-only) tcl var
      return $tcl_platform(host_platform)
   } elseif {[info exists tcl_platform(platform)]} {
      # this is a general tcl platform variable
      return $tcl_platform(platform)
   } else {
      # else try to determine from the PATH environment varaible
      set path $::env(PATH)
      if {[regexp {^[A-Za-z]:} $path]} { 
         return windows
      } else {
         return unix
      }
   }
}

proc getPACmd {} {
   # TODO -create a filesystem independent way to resolve the pa binary
   # exec which planAhead
   set xilinxHome $::env(XILINX)
   set planAheadHome ""
   set cmd ""
   if {[getFileSystem] == "windows"} {
      # handle windows installation
      foreach dir [split $::env(PATH) ;] {
         if {[file exists "$dir/planAhead.bat"]} {
	    set planAheadHome $dir
	    break
	 }
      }
      if {$planAheadHome == ""} {
	 # search the standard installation directories
	 # TODO - do a different sort to get latest installation
         foreach dir [lsort -dictionary [glob -type d -dir C:/HDI/ planAhead*]] {
            if {[regexp {_jvm$} $dir]} {
               # skip the _jvm directories
	       continue
            }
            if {[file exists "$dir/bin/planAhead.bat"]} {
	       set planAheadHome $dir
	       # TODO - remove this comment to take the first (oldest) installation
	       # break
	    }
         }
      }
      if {$planAheadHome == ""} {
         puts "ERROR:  PlanAhead is not installed in any of the default directories, nor on the PATH env variable:  $::env(PATH)"
         set planAheadHome "C:/HDI/planAhead9.1.4/bin"
      }
      set cmd "$planAheadHome/bin/planAhead.bat"
      # replace all back-slashes (windows file name conv) to forward slashes, which in tcl is compatible w/ windows
      regsub -all {\\} $cmd {/} cmd
      return $cmd
   } else {
      # handle linux/unix installation
      foreach dir [split $::env(PATH) :] {
         if {[file exists "$dir/planAhead"]} {
	    set planAheadHome $dir
	    break
	 }
      }
      if {$planAheadHome == ""} {
         puts "ERROR:  PlanAhead is not installed in any of the default PATH directories:  $::env(PATH)"
	 return "planAhead"
      }
      return "$planAheadHome/planAhead"
   }
}

proc regexpFile {expression fileIn} {
   # returns the first occurrence of regular expression matched in the file
   puts "INFO: Opening $fileIn for read operation"
   if {[catch "set FILEIN [open $fileIn r]"]} {
      puts "ERROR:  error opening $fileIn"
   }
   while {[gets $FILEIN line] >= 0} {
      if {[regexp $expression $line]} {
         close $FILEIN
         return $line
      }
   }
   close $FILEIN
   return ""
}

proc parseProjectFileISE {expression fileIn} {
   # parses a file and returns the line after the 
   # line that matches the expression
   puts "INFO: Opening $fileIn for read operation"
   if {[catch "set FILEIN [open $fileIn r]"]} {
      puts "ERROR:  error opening $fileIn"
   }
   while {[gets $FILEIN line] >= 0} {
      if {[regexp $expression $line]} {
         # get the next line:
	 if {[gets $FILEIN line] >= 0} {
            return $line
	 } else {
	    # there was no next line
	    return ""
	 }
      }
   }
   close $FILEIN
   puts "WARNING: Regular expression $expression did not match in $fileIn."
   return ""
}

proc parseFile {fileIn} {
   # returns the entire file in a tcl var
   puts "INFO: Opening $fileIn for read operation"
   if {[catch "set FILEIN [open $fileIn r]"]} {
      puts "ERROR:  error opening $fileIn"
   }
   set returnVar [read $FILEIN]
   close $FILEIN
   return $returnVar
}

proc parseFileRegexp {expression fileIn mode} {
   # parses a file and returns value based on mode requested
   # valid values for $mode are:  first (default), last, allLine, multiLineToBlank, lineAfterHit
   puts "INFO: Opening $fileIn for operation $mode using regular expression: \{$expression\}"
   if {[catch "set FILEIN [open $fileIn r]"]} {
      puts "ERROR:  error opening $fileIn"
   }
   set inHit 0
   set returnValue ""
   while {[gets $FILEIN line] >= 0} {
      if {[regexp $expression $line]} {
         set inHit 1
      }
      if {$inHit} {
         switch -exact $mode {
	    last {
	       # return the last line that matches
	       set returnVar $line
	    }
	    allLine {
	       # return all lines that match
               lappend returnValue $line
	    }
	    multiLineToBlank {
	       # return lines, starting w/ expression match until
	       # a blank line is reached
	       if {[regexp "^\s*$" $line]} {
	          set inHit 0
	       }
               lappend returnValue $line
	    }
	    lineAfterHit {
               # get the next line:
	       if {[gets $FILEIN line] >= 0} {
                  close $FILEIN
                  return $line
	       } else {
	          # there was no next line
                  close $FILEIN
	          return ""
	       }
	    }
	    first -
	    default { 
	       # the default mode (first) is to return the first line that matches
               close $FILEIN
	       return $line
	    }
	 }
      }
   }
   close $FILEIN
   return $returnValue
}

proc importUCF {ucf} {
   # TODO - document this
   set imported 0
   set ucfList [list]
   set sourceListPtr [search * -type file]
   # first test to see if this was a valid ucf
   if {![file exists $ucf]} {
      puts "ERROR:  File not found $ucf"
      return 0
   }
   collection foreach filePtr $sourceListPtr {
      set file [object name $filePtr]
      if {[regexp {\.ucf$} $file]} {
	 lappend ucfList $file
      }
   }
   if {[llength $ucfList] == 0} {
      puts "ERROR: There are no ucf sources added to the project.  Adding..."
      xfile add $ucf
      set imported 1
   } elseif {[llength $ucfList] == 1} {
      # this is the expected case, replace the single ucf file...
      set oldFile [lindex $ucfList 0]
      puts "INFO: Replacing $oldFile with $ucf"
      file copy -force $oldFile $oldFile.bak
      puts "INFO: $oldFile is now $oldFile.bak"
      file copy -force $ucf $oldFile
      set imported 1
   } else {
      # try to determine which ucf file is the one to replace
      puts "INFO: More than 1 ucf file found, searching for the top ucf..."
      set top [project get top]
      # TODO - this is ISE10.1 only, they started putting forward slashes in the root hierarchy
      regsub {^/} $top {} top
      foreach file $ucfList {
         if {[regexp "$top\.ucf" $file]} {
            puts "INFO: Replacing $oldFile with $ucf"
            set oldFile [lindex $ucfList 0]
            file copy -force $oldFile $oldFile.bak
            puts "INFO: $oldFile is now $oldFile.bak"
            file copy -force $ucf $oldFile
            set imported 1
	 }
      }
   }
   if {$imported} {
      puts "INFO:  Successfully imported $ucf"
      return 1 
   } else {
      puts "INFO:  Unable to import $ucf"
      return 0
   }
}

proc getTopEDIF {fileList topName} {
   # given a list of edif source files, try to determine which is the top-level
   foreach file $fileList {
      # edif syntax for top-level module is:
      # (design nbv5_virtex1_top_level
      # (design (rename virtex1 "nbv5_virtex1_top_level")
      set designRegexpString "\\\(design \(\\\(rename\\\s+\\\S+\\\s+\\\"\)\*${topName}\(\\\"\)*"
      if {[regexp {$topName\.\S+} $file]} {
	 # the first assumption is that if the base name of the file matches return it
         return $file
      } else {
         # search the edif file for a match of the edif design name
         set designLine [regexpFile $designRegexpString $file]
	 if {$designLine != ""} {
	    return $file
	 }
      }
   }
   return ""
}

proc getProjFile {} {
   # attempt to guess the ise project file name
   set name [project get name]
   if {![file exists $name]} {
      if {![regexp {\.ise$} $name]} {
         if {[file exists $name.ise]} {
            return $name.ise
         }
      }
   } else {
      return $name
   }
   return ""
}

proc createPAScriptFromXST {xstFile} {
   set cwd [pwd]
   set top [project get top]
   # TODO - this is ISE10.1 only, they started putting forward slashes in the root hierarchy
   regsub {^/} $top {} top
   set device [project get device]
   set package [project get package]
   set speed [project get speed]
   set netlist ""
   set part ""
   set sourceList [list]
   set ucfList [list]
   set edifList [list]
   set searchPath [list]
   set returnScript [list]
   if {![file exists $xstFile]} {
      # attempt to run xst:
      if {[regexp {Synthesize - XST} [project get_processes]]} {
         # TODO - test this - need to wait? - process command is non-blocking, and is not thread-safe!
	 process run "Synthesize - XST"
	 puts "INFO: Running XST process...  run planAhead again when finished..."
	 # I don't know what else to do but return.  XST or ngdbuild must run prior to invoking PA
	 return
      } else {
	  puts "ERROR: XST prcess is not available for the selected source.  Please manually run xst or ngdbuild"
	  return
      }
   }
   if {[file exists $xstFile]} {
      set xstLogFile [parseFile $xstFile]
      if {[regexp {\-ofmt\s+(\S+)} $xstLogFile match outFileType]} {
	  if {$outFileType == "NGC"} {
	     set netlist $top.ngc
	  } else {
	     puts "ERROR:  unknown netlist type in the xst project file $top.xst:  $outFileType"
	 }
      } else {
	  puts "ERROR: no -ofmt specified in the xst run script $top.xst"
      }
   } else {
      # finally, check to see if the top-level is edif source
      if {[llength $edifList] >= 0} {
         set netlist [getTopEDIF $edifList $top]   
      }
   }
   if {$netlist == ""} {
      puts "ERROR:  Unable to find a valid edif netlist to export to PlanAhead."
      puts "ERROR:  XST needs to run on this project prior to invoking planAhead  or"
      puts "ERROR:  the project needs valid edif sources"
      return
   }
   if {[llength $searchPath] < 1} {
      set searchPath "."
   }
   set part ${device}-${package}${speed}
   if {![file exists $netlist]} {
      puts "ERROR:  File not found $netlist"
      return
   }
   lappend returnScript "if {\[file exists $top.ppr\]} {"
   lappend returnScript "   if {\[ catch {hdi::project open -file $top.ppr} returnVar\]} {"
   lappend returnScript "      puts \"WARNING: \$returnVar\""
   lappend returnScript "      puts \"WARNING: Continuing...\""
   lappend returnScript "   }"
   lappend returnScript "} else {"
   lappend returnScript "   hdi::project new -name $top -dir . -netlist $netlist -search_path \{$searchPath\}"
   lappend returnScript "   if {\[catch {hdi::floorplan new -name floorplan_1 -part $part -project $top} returnVar\]} {"
   lappend returnScript "      puts \"WARNING:  \$returnVar\""
   lappend returnScript "      puts \"WARNING: Continuing...\""
   lappend returnScript "   }"
   foreach ucf $ucfList {
      lappend returnScript "   hdi::pconst import -project $top -floorplan floorplan_1 -file $ucf"
   }
   lappend returnScript "}"
   lappend returnScript "hdi::floorplan save -name floorplan_1 -project $top"
   return $returnScript
}

proc createPAScriptFromBLD {ngdBldFile} {
   # This proc parses the ngdbuild .bld file and creates a planAhead tcl script to impor the sources
   # returns a tcl list of planAhead commands
   set netlist ""
   set part ""
   set device ""
   set package ""
   set speed ""
   set returnScript [list]
   set ucfList [list]
   set searchPath [list]
   set ngdBuildCmd [join [parseFileRegexp "^Command Line:" $ngdBldFile multiLineToBlank]]
   regsub -all {\s+} $ngdBuildCmd " " ngdBuildCmd
   # now create the pa run script
   set top [file rootname [file tail $ngdBldFile]]
   set netlist [lindex $ngdBuildCmd end-1]
   set tokenList [split $ngdBuildCmd]
   for {set x 0} {$x < [llength $tokenList]} {incr x} {
      set token [lindex $tokenList $x]
      switch -exact -- $token {
         -sd {
	    # assign the next token to the search path list
            lappend searchPath [lindex $tokenList [expr $x +1]]
         }
	 -uc {
	    # assign the next token to the ucf list
            lappend ucfList [lindex $tokenList [expr $x +1]]
	 }
	 -p {
	    # assign the next token to the ucf list
            set part [lindex $tokenList [expr $x +1]]
	 }
      }
   }
   if {$part == ""} {
      # this means that no -p was specified for part in the .bld file
      # try to get it from the requisite map report file .mrp
      puts "WARNING:  -p was not specified in the ngdbuild file $ngdBldFile"
      set mrpFile [regsub {\.bld$} $ngdBldFile {.mrp}]
      puts "WARNING:     searching for map report file $mrpFile"
      if {![file exists $mrpFile]} {
         puts "WARNING:     File not found: $mrpFile"
         set mrpFile [regsub {\.bld$} $ngdBldFile {_map.mrp}]
         puts "WARNING:     searching for another map report file $mrpFile"
      }
      if {[file exists $mrpFile]} {
         set device [lindex [regsub -all {\s+} [parseFileRegexp "^Target Device\\s+:" $mrpFile first] " "] 3]
	 if {$device == ""} {
	    puts "ERROR: Unable to get valid device from $mrpFile"
	    return ""
	 }
         set package [lindex [regsub -all {\s+} [parseFileRegexp "^Target Package\\s+:" $mrpFile first] " "] 3]
	 if {$package == ""} {
	    puts "ERROR: Unable to get valid package from $mrpFile"
	    return ""
	 }
         set speed [lindex [regsub -all {\s+} [parseFileRegexp "^Target Speed\\s+:" $mrpFile first] " "] 3]
	 if {$speed == ""} {
	    puts "ERROR: Unable to get valid speed from $mrpFile"
	    return ""
	 }
         set part ${device}-${package}${speed}
      } else {
         # cound not find a valid part - aborting
	 puts "ERROR:  Could not find a valid part.  Try running createPAScriptFromISE or createPAScriptFromXST"
         return ""
      }
   }
   if {[llength $searchPath] < 1} {
      set searchPath "."
   }
   lappend returnScript "if {\[file exists $top.ppr\]} {"
   lappend returnScript "   if {\[ catch {hdi::project open -file $top.ppr} returnVar\]} {"
   lappend returnScript "      puts \"WARNING: \$returnVar\""
   lappend returnScript "      puts \"WARNING: Continuing...\""
   lappend returnScript "   }"
   lappend returnScript "} else {"
   lappend returnScript "   hdi::project new -name $top -dir . -netlist $netlist -search_path \{$searchPath\}"
   lappend returnScript "   if {\[catch {hdi::floorplan new -name floorplan_1 -part $part -project $top} returnVar\]} {"
   lappend returnScript "      puts \"WARNING:  \$returnVar\""
   lappend returnScript "      puts \"WARNING: Continuing...\""
   lappend returnScript "   }"
   foreach ucf $ucfList {
      lappend returnScript "   hdi::pconst import -project $top -floorplan floorplan_1 -file $ucf"
   }
   lappend returnScript "}"
   lappend returnScript "hdi::floorplan save -name floorplan_1 -project $top"
   return $returnScript
}

proc createPAScriptFromISE {projectFile} {
   set cwd [pwd]
   set top [project get top]
   # TODO - this is ISE10.1 only, they started putting forward slashes in the root hierarchy
   regsub {^/} $top {} top
   set device [project get device]
   set package [project get package]
   set speed [project get speed]
   set netlist ""
   set returnScript [list]
   set ucfList [list]
   set searchPath [list]
   set ngdBuildCmd [join [parseFileRegexp "^CommandLine-Ngdbuild" $projectFile lineAfterHit]]
   if {$ngdBuildCmd != ""} {
      # remove all extra whitespace
      regsub -all {\s+} $ngdBuildCmd " " ngdBuildCmd
      set netlist [lindex $ngdBuildCmd end-1]
      set tokenList [split $ngdBuildCmd]
      for {set x 0} {$x < [llength $tokenList]} {incr x} {
         set token [lindex $tokenList $x]
         switch -exact -- $token {
            -sd {
	       # assign the next token to the search path list
               lappend searchPath [lindex $tokenList [expr $x +1]]
            }
            -uc {
	       # assign the next token to the ucf list
               lappend ucfList [lindex $tokenList [expr $x +1]]
	    }
         }
      }
   }
   if {$netlist == ""} {
      puts "ERROR:  Unable to find a valid edif netlist to export to PlanAhead."
      puts "ERROR:  XST needs to run on this project prior to invoking planAhead  or"
      puts "ERROR:  the project needs valid edif sources"
   }
   if {[llength $searchPath] < 1} {
      set searchPath "."
   }
   set part ${device}-${package}${speed}
   if {![file exists $netlist]} {
      puts "ERROR:  File not found $netlist"
   }
   lappend returnScript "if {\[file exists $top.ppr\]} {"
   lappend returnScript "   if {\[ catch {hdi::project open -file $top.ppr} returnVar\]} {"
   lappend returnScript "      puts \"WARNING: \$returnVar\""
   lappend returnScript "      puts \"WARNING: Continuing...\""
   lappend returnScript "   }"
   lappend returnScript "} else {"
   lappend returnScript "   hdi::project new -name $top -dir . -netlist $netlist -search_path \{$searchPath\}"
   lappend returnScript "   if {\[catch {hdi::floorplan new -name floorplan_1 -part $part -project $top} returnVar\]} {"
   lappend returnScript "      puts \"WARNING:  \$returnVar\""
   lappend returnScript "      puts \"WARNING: Continuing...\""
   lappend returnScript "   }"
   foreach ucf $ucfList {
      lappend returnScript "   hdi::pconst import -project $top -floorplan floorplan_1 -file $ucf"
   }
   lappend returnScript "}"
   lappend returnScript "hdi::floorplan save -name floorplan_1 -project $top"
   return $returnScript
}

proc writeToFile {fileName stuffToWrite} {
   # This proc expects a tcl list $stuffToWrite and writes each 
   # item in the list to the given file
   if {[llength $stuffToWrite] < 1} {
      puts "ERROR:  empty list passed to writeToFile for $fileName"
   }
   puts "INFO: Opening $fileName for write operation"
   if {[catch "set FILEOUT [open $fileName w]"]} {
      puts "ERROR:  error opening $fileName"
   }
   foreach line $stuffToWrite {
      puts $FILEOUT $line
   }
   close $FILEOUT
   puts "INFO: Done writing $fileName"
}

proc planAhead {{projectFile ""}} {
   set cwd [pwd]
   set top [project get top]
   # TODO - this is ISE10.1 only, they started putting forward slashes in the root hierarchy
   regsub {^/} $top {} top
   set device [project get device]
   set package [project get package]
   set speed [project get speed]
   set netlist ""
   set sourceList [list]
   set ucfList [list]
   set edifList [list]
   puts "INFO:  Exporting project for planAhead...."
   # make sure we have a valid ise project file
   if {$projectFile == ""} {
      set projectFile [getProjFile]
      if {$projectFile == ""} {
         puts "ERROR: Unable to find a valid ise project file!"
         puts "        Try planAhead <projFileName>"
	 return 0
      } 
   } elseif {![file exists $projectFile]} {
      puts "ERROR: Unable to find a valid ise project file!"
      puts "        Try planAhead <projFileName>"
      return 0
   }
   # search the sources added to the project file
   set sourceListPtr [search * -type file]
   collection foreach filePtr $sourceListPtr {
      set file [object name $filePtr]
      if {[regexp {\.ucf$} $file]} {
#         puts "DEBUG: Found a ucf file!:  $file"
	 lappend ucfList $file
      } elseif {[regexp {\.edn$} $file]} {
#         puts "DEBUG: Found an edn file!:  $file"
	 lappend edifList $file
      } elseif {[regexp {\.edf$} $file]} {
#         puts "DEBUG: Found an edf file!:  $file"
	 lappend edifList $file
      } elseif {[regexp {\.ngc$} $file]} {
#         puts "DEBUG: Found a ngc file!:  $file"
	 lappend edifList $file
      } else {
#         puts "DEBUG: Found a source file!:  $file"
         lappend sourceList $file
      }
   }
   # TODO - refactoring....
   # try first to parse the .bld file for valid ngdbuild syntax and sources...
#   set ngdBuildCmd [join [parseFileRegexp "^Command Line:" $top.bld multiLineToBlank]]
   # try first to get a ngc file from the ise project file PAR run
   set ngdBuildCmd [join [parseFileRegexp "^CommandLine-Ngdbuild" $projectFile lineAfterHit]]
   if {$ngdBuildCmd != ""} {
      # TODO -refactoring - remove these lines when tested
      # regexp {\s+(\S+\.ngc)} $ngdBuildCmd match netlist
      # TODO -probably should handle -sd for netlists
      #regexp {\-sd\s+(\S+)} $ngdBuildCmd match searchPath
      # TODO - remove to here
      # remove all extra whitespace
      regsub -all {\s+} $ngdBuildCmd " " ngdBuildCmd
      # now create the pa run script
      set netlist [lindex $ngdBuildCmd end-1]
      set tokenList [split $ngdBuildCmd]
      for {set x 0} {$x < [llength $tokenList]} {incr x} {
         set token [lindex $tokenList $x]
         switch -exact -- $token {
            -sd {
	       # assign the next token to the search path list
               lappend searchPath [lindex $tokenList [expr $x +1]]
            }
            -uc {
	       # assign the next token to the ucf list
               lappend ucfList [lindex $tokenList [expr $x +1]]
	    }
         }
      }
   } else {
      # TODO - convert this to ngdbuild process...
      # process run "Translate"
      # next try and get the ngc file from the xst report
      if {![file exists $top.xst]} {
         # attempt to run xst:
	 if {[regexp {Synthesize - XST} [project get_processes]]} {
	    # TODO - test this - need to wait? - process command is non-blocking, and is not thread-safe!
	    process run "Translate"
	    puts "INFO: Running NGDBUILD process...  run planAhead again when finished..."
#	    process run "Synthesize - XST"
#	    puts "INFO: Running XST process...  run planAhead again when finished..."
	    # I don't know what else to do but return.  XST or ngdbuild must run prior to invoking PA
	    return
	 } else {
	    puts "ERROR: XST prcess is not available for the selected source.  Please manually run xst or ngdbuild"
	    return
	 }
      }
      if {[file exists $top.xst]} {
         set xstLogFile [parseFile $top.xst]
         if {[regexp {\-ofmt\s+(\S+)} $xstLogFile match outFileType]} {
	    if {$outFileType == "NGC"} {
	       set netlist $top.ngc
	    } else {
	       puts "ERROR:  unknown netlist type in the xst project file $top.xst:  $outFileType"
	    }
	 } else {
	    puts "ERROR: no -ofmt specified in the xst run script $top.xst"
	 }
      } else {
	 # finally, check to see if the top-level is edif source
	 if {[llength $edifList] >= 0} {
            set netlist [getTopEDIF $edifList $top]   
         }
      }
   }
   if {$netlist == ""} {
      puts "ERROR:  Unable to find a valid edif netlist to export to PlanAhead."
      puts "ERROR:  XST needs to run on this project prior to invoking planAhead  or"
      puts "ERROR:  the project needs valid edif sources"
      return 0
   }
   if {![info exists searchPath]} {
      set searchPath "\".\""
   }
   set part ${device}-${package}${speed}
   if {![file exists $netlist]} {
      puts "ERROR:  File not found $netlist"
      return 0
   }
   # now create the pa run script
   set runScript $top.planAhead.tcl
   puts "INFO: Opening $runScript for write operation"
   if {[catch "set FILEOUT [open $runScript w]"]} {
      puts "ERROR:  error opening $runScript"
   }
   puts $FILEOUT "if {\[file exists $top.ppr\]} {"
   puts $FILEOUT "   if {\[ catch {hdi::project open -file $top.ppr} returnVar\]} {"
   puts $FILEOUT "      puts \"WARNING: \$returnVar\""
   puts $FILEOUT "      puts \"WARNING: Continuing...\""
   puts $FILEOUT "   }"
   puts $FILEOUT "} else {"
   puts $FILEOUT "   hdi::project new -name $top -dir . -netlist $netlist -search_path \{$searchPath\}"
   puts $FILEOUT "   if {\[catch {hdi::floorplan new -name floorplan_1 -part $part -project $top} returnVar\]} {"
   puts $FILEOUT "      puts \"WARNING:  \$returnVar\""
   puts $FILEOUT "      puts \"WARNING: Continuing...\""
   puts $FILEOUT "   }"
   foreach ucf $ucfList {
      puts $FILEOUT "   hdi::pconst import -project $top -floorplan floorplan_1 -file $ucf"
   }
   puts $FILEOUT "}"
   puts $FILEOUT "hdi::floorplan save -name floorplan_1 -project $top"
   close $FILEOUT
   # if the pa project exists, delete it to avoid issues w/ updating and syncing the projects:
   if {[file exists $top.ppr]} {
      # TODO - do we want to rename this data for some reason rather than deleting?
      puts "INFO:  found a previous planAhead project named $top.ppr, deleting and re-creating..."
      file delete -force -- $top.ppr
      if {[file exists $top.data]} {
         file delete -force -- $top.data
      }
      if {[file exists $top.runs]} {
         file delete -force -- $top.runs
      }
   }
   puts "INFO:  Invoking planAhead on $top"
   # shell out and execute the planAhead binary
   # using pipes in non-blocking mode allows forking of child process
   set paCmd "[getPACmd] -source $runScript"
   set paPipe [open "| $paCmd 2>@ stdout" "w"]
   # TODO - non-local pa launch takes a very long time - need to implement messaging scheme to indicate when it's loaded
   fconfigure $paPipe -blocking 0
   close $paPipe
   puts "INFO:  Done exporting $top for planAhead."
   puts "INFO:  Use importUCF to import any ucf exported from PlanAhead back in to Project Navigator."
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
