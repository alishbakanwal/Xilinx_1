# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
#!/home/scratch.cpatil01/dnload/tcl8.4.7/unix/tclsh

source utils.tcl
source newCommands.tcl
namespace import NewCommands::*

proc test_findabbr args {

    set t1list "abc defo fgt fptos lkgdo"
    
    # Test if it returns the correct abbr (exact match)
    if {[set ret [Utils::findabbr $t1list "fgt"]] ne "fgt"} {
	error "Error: Expected fgt. Got \"$ret\""
    } else {
	puts "Exact match test successfull: $ret (expecting fgt)"
    }
    
    # Multiple matches
    # Test if it returns the correct abbr (glob match)
    # fatalIfNotUnique is set to 0 here and returnList is set to 1
    set ret [Utils::findabbr $t1list "f" 0 0 1]
    # should have only two matches
    if {[llength $ret] == 2} {	
    } else {
	error "Error: Expected return to be list of 2 elements {fgt fptos}. Got \"$ret\""
    }

    if { [lsearch -exact $ret "fptos"] > -1  && [lsearch -exact $ret "fgt"] > -1 } {
	puts "Glob match (returnList true) test successfull: $ret (expecting fptos and fgt)"
    } else {
	error "Error: Expected {fgt fptos}. Got \"$ret\""
    }

    # Test if it returns the correct abbr (glob match)
    # fatalIfNotUnique is set to 0 here and returnList is set to 0
    set ret [Utils::findabbr $t1list "f" 0 0 0]
    # should have only one match
    if {$ret ne "fgt"} {
	error "Error: Expected fgt. Got \"$ret\""
    } else {
	puts "Glob match (returnList false) successfull: $ret (expecting only fgt)"
    }

    ## Test if it returns the index if returnIndex is set
    #set ret [Utils::findabbr $t1list "f" 0 0 0]
    ## should have only one match
    #if {! [llength $ret] == 2} {
    #	error "Error: Expected fgt and fptos. Got \"$ret\""
    #}
    #if { [lsearch -exact $ret "fptos"] > -1  && [lsearch -exact $ret "fgt"] > -1 } {
    #} else {
    #	error "Error: Expected fptos and fgt. Got \"$ret\""
    #}
    #
    ## Test if it returns the index if returnIndex is set
    #set ret [Utils::findabbr $t1list "f" 1 0 0 0]
    ## should have only one match
    #if {! [llength $ret] == 2} {
    #	error "Error: Expected fptos and fgt. Got \"$ret\""
    #}
    #if { [lsearch -exact $ret "fptos"] > -1  && [lsearch -exact $ret "fgt"] > -1 } {
    #} else {
    #	error "Error: Expected fptos and fgt. Got \"$ret\""
    #}
    

    # Test if it croaks when multiple matches and fatalIfNotUnique
    if { [catch { Utils::findabbr $t1list "f" } ret]} {
	puts "Glob match (fatalIfNotUnique set to default true) successfull: Failure: $ret (expecting Multiple matches found for f)"
    } else {
	error "Error: Should have croaked here since fatalIfUnique was true"
    }

    # Test if it returns muliple matches when returnList is true
    # Already checked above

    # Test if it returns muliple indexs when returnList is true and returnIndex is true
    # N/A

    # Test if it returns first of the muliple matches when returnList is false
    # Already checked above

    puts "All findabbr tests concluded successfully\n"
}


proc test_addCommand {args} {
    
    set testnum 0
    
    ############################
    proc goo12 args {
	puts $args
	return $args
    }
    puts "######################################################"
    puts "TEST: add a command  (no options)"
    puts "######################################################"
    if {[mycatch {addCommand noOptCmd goo12} ret]} {
	error "Failed to add a command with no options.\n$::errorInfo"
    }   
    
    puts "\nTEST: execute the command"
    if {[mycatch {noOptCmd} ret]} {
	error "failed to execute commmand.\n$::errorInfo"
    } else {
	if {[join $ret] ne ""} {
	    error "Error: Expected {}. Got \"$ret\""
	}
    }

    puts "\nTEST: with extra chars - should fail"
    if {![mycatch {noOptCmd fosdf} ret]} {
	error "Failed to detect extra chars."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    ###########################
    namespace eval foo_1 {
	proc goo12 {args} {puts $args; return "$args"}
    }

    puts "######################################################"
    puts "TEST: add a command  (no options) from another namespace"
    puts "######################################################"
    if {[mycatch {addCommand noOptCmd1 foo_1::goo12} ret]} {
	error "failed to add a commandProc in another with no options.\n$::errorInfo"
    } 
    
    puts "\nTEST: execute the command"
    if {[mycatch {noOptCmd1} ret]} {
	error "failed to execute command.\n$::errorInfo"
    } else {
	if {[join $ret] ne ""} {
	    error "Error: Expected {}. Got \"$ret\""
	}
    } 

    puts "\nTEST: with extra chars - should fail"
    if {![mycatch {noOptCmd1 ffoo} ret]} {
	error "failed to detect extra chars"
    } else {
	puts "Detected +ve error:\n$ret"
    } 

    ##########################
    proc cmdproc1 {args} {
	foreach a $args {puts $a}
	return [join $args]
    }
    puts "######################################################"
    puts "TEST: add another command with args (say boolean and string) (ordered)"
    puts "######################################################"
    if {[mycatch {addCommand cmd1 cmdproc1 {boolean fooBool} {string fooStr}} ret]} {
	error "failed to add a command with ordered list.\n$::errorInfo"
    }
    
    puts "\nTEST: execute the command (no args) - should not fail since no required args"
    if {[mycatch {cmd1} ret]} {
	error "failed to detect default values.\n$::errorInfo"
    } else {
	if {$ret ne "false "} {
	    error "Error: Expected \"false \". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with only the string option - should not fail since boolean is optional"
    if {[mycatch {cmd1 -fooStr {foo goo}} ret]} {
	error "failed to detect default values.\n$::errorInfo"
    } else {
	if {$ret ne "false foo goo"} {
	    error "Error: Expected \"false foo goo\". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with correct args -boolean -string  -  confirm the order"
    if {[mycatch {cmd1 -fooStr {foo fpp} -fooBool } ret]} {
	error "failed to execute with correct args.\n$::errorInfo"
    } else {
	if {$ret ne "true foo fpp"} {
	    error "Error: Expected \"true foo fpp\". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with extra char in b/w"
    if {![mycatch {cmd1 -fooStr {foo fpp} foo -fooBool } ret]} {
	error "failed to detect extra chars foo"
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: execute the command with correct arguments"
    if {[mycatch {cmd1 -fooBool false  -fooStr foo } ret]} {
	error "2. failed to execute with correct args.\n$::errorInfo"
    } else {
	if {$ret ne "false foo"} {
	    error "Error: Expected \"false foo\". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with correct args  -string -boolean "
    if {[mycatch {cmd1 -fooStr foo -fooBool} ret]} {
	error "failed to detect order test.\n$::errorInfo"
    } else {
	if {$ret ne "true foo"} {
	    error "Error: Expected \"true foo\". Got \"$ret\""
	}
    }

    puts "\nTEST: exeucte the command with string option only - should use false for the boolean"
    if {[mycatch {cmd1 -fooStr foo} ret]} {
	error "failed to detect default value for bool.\n$::errorInfo"
    } else {
	if {$ret ne "false foo"} {
	    error "Error: Expected \"false foo\". Got \"$ret\""
	}
    }   

    puts "\nTEST: execute the command with incorrect args -enum -  should fail"
    if {![mycatch {cmd1 -boolean true -enum foo} ret]} {
	error "failed to detect incorrect args"
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: failed to detect invalid value for bool"
    if {![mycatch {cmd1 -boolean 1 -string foo} ret]} {
	error "failed to detect 1 for boolean."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: failed to detect missing string option"
    if {![mycatch {cmd1 -boolean -string } ret]} {
	error "failed to detect missing string option"
    } else {
	puts "Detected +ve error:\n$ret"
    }
   

    puts "\nTEST: execute the command with extra args at the end of command  - should fail"
    if {![mycatch {cmd1 -string foo ffl} ret]} {
	error "failed to detect extra chars at the end."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: execute the command with the boolean at the end and an extra arg (not true or false) - should fail"
    if {![mycatch {cmd1 -fooBool foo} ret]} {
	error "failed to detect missing string option and extra chars."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: execute the command with multiple matches for option names -foo- should fail"
    if {![mycatch {cmd1 -foo foo} ret]} {
	error "failed to detect multiple matches for option."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST: execute the command with abbr for option names -fooS -fooB"
    if {[mycatch {cmd1 -fooB -fooS foo} ret]} {
	error "[incr testnum]. failed to detect abbr for option names .\n$errorInfo"
    } else {
	if {$ret ne "true foo"} {
	    error "Error: Expected \"true foo\". Got \"$ret\""
	}
    } 

    ####################
    # add another command with args (say boolean and string) 
    namespace eval foo23 {
	proc cmdproc3 {args} {
	    puts $args
	    return [join $args]
	}
	proc cmdproc4 {args} {
	    puts $args
	    return [join $args]
	}

    }

    puts "\n######################################################----------"
    puts "\nTEST: command with -boolean and -number"

    if {[mycatch {addCommand foo23::cmd1 foo23::cmdproc3 {boolean fooBool} {number fooNum}} ret]} {
	error "Failed to create cmd in another namespace.\n$::errorInfo"
    }

    puts "\nTEST: command with -boolean and -string"
    if {[mycatch {addCommand foo23::cmd2 foo23::cmdproc4 {boolean fooBool} {string fooStr} } ret]} {
	error "Failed to create command."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: create command with incorrect option type Boolean - should fail"
    if {![mycatch {addCommand foo23::cmd3 foo23::cmdproc1 {Boolean fooBool} {string fooStr} } ret]} {
	error "failed to detect Boolean."
    } else {
	puts "Detected +ve error:\n$ret"
    }
    
    puts "\nTEST: Execute the command (no args) should use default values"
    if {[mycatch {foo23::cmd1} ret]} {
	error "failed to detect no args .\n$::errorInfo"
    } else {
	if {$ret ne "false "} {
	    error "Error: Expected \"false \". Got \"$ret\""
	}
    }


    puts "\nTEST:  execute the command with correct args  -boolean -num"
    # print the args from the commandProc
    # confirm the order 
    if {[mycatch {foo23::cmd1 -fooBool -fooN 2.3} ret]} {
	error "failed to execute command .\n$::errorInfo"
    } else {
	if {$ret ne "true 2.3"} {
	    error "Error: Expected \"false 2.3\". Got \"$ret\""
	}
    }

    puts "\nTEST:  execute the command with incorrect option value for num"
    if {! [mycatch {foo23::cmd1 -fooBool -fooN foo} ret]} {
	error "Failed to detect string for number "
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST: execute the command with correct args  -string -boolean"
    if {[mycatch {foo23::cmd2 -fooStr {foo foo {goo gpp}} -fooBoo} ret]} {
	error "Failed to execute correctly.\n$::errorInfo"
    } else {
	if {$ret ne "true foo foo {goo gpp}"} {
	    error "Error: Expected \"false foo foo {goo gpp}\". Got \"$ret\""
	}
    }
    

    puts "\nTEST: Execute the command with string option only - should use false for the boolean"
    if {[mycatch {foo23::cmd2 -fooS foo} ret]} {
	error "failed to detect default vals.\n$::errorInfo"
    } else {
	if {$ret ne "false foo"} {
	    error "Error: Expected \"false foo\". Got \"$ret\""
	}
    }
    
    puts "\nTEST: Execute the command with incorrect args -enum - should fail"
    if {![mycatch {foo23::cmd2 -enum foo} ret]} {
	error "failed to detect incorrect args."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST: execute the command with extra args at the end of command - should fail"
    if {![mycatch {foo23::cmd2 -string foo sdflsdf} ret]} {
	error "failed to detect extra args at the end."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST:  execute the command with the boolean at the end and an extra arg (not true or false) -  should fail"
    if {![mycatch {foo23::cmd1 -fooBo foo} ret]} {
	error "failed to detect incorrect boolean value."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    ######################
    proc cmdproc4 {args} {
	puts $args
	return [join $args]	
    }

    puts "\nTEST: add a command with enum, boolean etc and required args"
    if {[mycatch {addCommand cmd4 cmdproc4 {boolean} {boolean fooBool} {enum {fast medium slow} {slow} "effort"} {string}} ret]} {
	error "failed to add command.\n$::errorInfo"
    }

    
    puts "\nTEST: execute the command with no args - should fail"
    if {![mycatch {cmd4} ret]} {
	error "Failed to detect no reqd args in cmd4."
    } else {
	puts "Detected +ve error:\n$ret"
    }
   

    puts "\nTEST: Execute the command with only reqd option - should work"
    if {[mycatch {cmd4 true foo} ret]} {
	error "failed to detect correct args cmd4.\n$::errorInfo"
    } else {
	if {$ret ne "true false slow foo"} {
	    error "Expected \"true false slow foo\". Got \"$ret\""
	}
    }

    
    puts "\nTEST: Execute the command with incorrect arg for boolean - should fail"
    if {![mycatch {cmd4 foo -fooB slow -effort slow} ret]} {
	error "failed to detect bad value for boolean."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST: Missing string reqd arg and mix and match the options"
    if {![mycatch {cmd4 true -effort fast -fooB true} ret]} {
	error "failed to detect missing string argument."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: Jumble up the args - correct args = check the order"
    if {[mycatch {cmd4 -effort slow -fooBo false true {foo foo {goo gpp}} } ret]} {
	error "failed to work with unrodered args.\n$::errorInfo"	
    } else {
	if {$ret ne "true false slow foo foo {goo gpp}"} {
	    error "Expected \"true false slow foo foo {goo gpp}\". Got \"$ret\""
	}
    }

    
    puts "\nTEST: execute the command with no required options -  should fail"
    if {![mycatch {cmd4 -effort slow -fooBool  } ret]} {
	error "failed to detect missing reqd arg."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: execute the command with incorrect options -  should fail"
    if {![mycatch {cmd4 true -ffort slow -fooBool foo  } ret]} {
	error "failed to detect missing reqd arg."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: execute the command with jumbled up args -  should work"
    if {[mycatch {cmd4 -effort fast true -fooBool false goo  } ret]} {
	error "failed to detect missing reqd arg.\n$::errorInfo"
    } else {
	if {$ret ne "true false fast goo"} {
	    error "Expected \"true false fast goo\". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with bool eating first required arg -  should fail"
    if {![mycatch {cmd4 -effort slow -fooBool goo true } ret]} {
	error "failed to detect missing reqd arg."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST: execute the command with extra args at the end of command = should fail"
    if {![mycatch {cmd4 true -effort slow -fooBool foo goo loo  } ret]} {
	error "failed to detect extra chars arg."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    ####################
    proc cmd5proc {args} {
	puts [info level 0]
	puts "args: $args"
	# if {[llength $args] == 1} { set args [lindex $args 0]}
	set f [lindex $args 3]
	puts [read $f]
	return [join $args]
    }

    puts "\nTEST: add a command with the same name as the command proc - should fail"
    if {![mycatch {addCommand cmd5 cmd5 {boolean} {boolean fooBool} {enum {fast medium slow} {slow} "effort"} {string}} ret]} {
	error "Failed to detect same name for command and commandproc.\n"
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: try to add an existing command - should fail"
    if {![mycatch {addCommand cmd4 cmdproc4 {boolean} {boolean fooBool} {enum {fast medium slow} {slow} "effort"} {string}} ret]} {
	error "Failed to detect existing command \n"
    } else {
	puts "Detected +ve error:\n$ret"
    }

    set f [open stdout w]
    puts "\nTEST: add a command with a file required option (mode read) and a string requried option"
    if {[mycatch {addCommand cmd5 cmd5proc {boolean} {string "str"} {enum {fast medium slow} {slow} "effort"} {file r} {file w $f "rpt"}} ret]} {
	error "failed to add command.\n$::errorInfo"
    }
	

    puts "\nTEST: execute the command with no args -  should fail"
    if {![mycatch {cmd5} ret]} {
	error "Failed to detect no reqd args in cmd5."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    puts "\nTEST: execute the command with correct args and confirm the order"
    if {[mycatch {cmd5 true /home/cpatil/.cshrc -rpt /home/cpatil/.cshrc_bad -eff fast } ret]} {
	error "failed to detect correct args cmd5.\n$::errorInfo"
    } else {
	if {$ret ne "true  fast file4 file5"} {
	    puts "WARNING: This may not work for you. file4 and file5 are fileids"
	    error "Expected \"true  fast file4 file5\". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with non-existant file for reading - should fail"
    if {![mycatch {cmd5 true /home/cpatil/.cshrc_ff  -eff fast } ret]} {
	error "failed to detect nonexistant file to read"
    } else {
	puts "Detected +ve error:\n$ret"
    }

    # execute the command and then try to write to the file (had opened it with r mode)
    # should not be able to write to the file

    #########################
    ####################
    proc cmd6proc {args} {
	puts [info level 0]
	puts "args: $args"
	return [join $args]
    }

    puts "\nTEST: add a command with the double integer and number"
    if {[mycatch {addCommand cmd6 cmd6proc {integer} {integer "int"} {enum {fast medium slow} {slow} "inty"} {double} {double "doublei"} {number} {number "numberi"}} ret]} {
	error "Failed to create command to check integer double and number.\n$::errorInfo\n"
    }

    puts "\nTEST: execute the command with only the required options"
    if {[mycatch {cmd6 1 2.2 4} ret]} {
	error "failed to execute properly..\n$::errorInfo"
    } else {
	if {$ret ne "1  slow 2.2  4 "} {
	    error "Expected \"1  slow 2.2  4 \". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with abbr option i - should fail"
    if {![mycatch {cmd6 1 4.4 2.3 -i 4 } ret]} {
	error "failed to detect abbr option i."
    } else {
	puts "Detected +ve error:\n$ret"
    }

    puts "\nTEST: execute the command with all options but jumbled up"
    if {[mycatch {cmd6 -int 1 -inty medium -doublei 2 -number 3.4 1 2.2 4} ret]} {
	error "failed to execute properly..\n$::errorInfo"
    } else {
	if {$ret ne "1 1 medium 2.2 2 4 3.4"} {
	    error "Expected \"1 1 medium 2.2 2 4 3.4\". Got \"$ret\""
	}
    }

    puts "\nTEST: execute the command with a double value for integer option - should fail"
    if {![mycatch {cmd6 1 4.4 2.3 -int 4.2 } ret]} {
	error "failed to detect double value for integer option."
    } else {
	puts "Detected +ve error:\n$ret"
    }


    ## add a command with -number and -double  and -integer

    # execute the command with double for integer
    # should fail

    # execute the command with a string for the number
    # should fail

    #######################
    # try to add a command in another namespace

    # execute the command
}

proc mycatch args {
    puts "Executing: [lindex $args 0]"
    upvar [lindex $args 1] ret
    set f [catch [lindex $args 0] ret]
    return $f
}


test_findabbr

test_addCommand

puts ""
puts "All tests completed successfully"


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
