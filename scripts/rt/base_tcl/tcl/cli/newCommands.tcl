# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
## newCommands.tcl
## Provides an API that will register given commands to the 
## tcl system
##
## Usage: 
## NewCommands::addCommand ... 
##  
##
##
## TBD:
##   - Should we add capability to add the command to a specified namespace
##   - Support callbacks for verifying options
##   - add double, integer, number, list0of, multiple type
##   - Should the enum option pass the default option if the value specified
##     doesnt match one of the possible option? Currently I error out if 
##     a value is specified and is not a valid value. 
##

package provide NewCommands 1.0

namespace eval NewCommands {
    namespace export addCommand

    # Structure of the commands data structure:
    # commandName { \
    #    optionOrder {0 {optional optionName typeStr} 1 {optional optionName typeStr} ...} \
    #    optionalOptions {optionName_0 {callback args}  optionName_1 {callback args} ..} \
    #    reqdOptions {0 {{callback args} optionType}  1 {{callback args} optionType} ..} \
    #    returnVals {optionName_0 defaultVal optionName_1 defaultVal ...} \
    #    helpStr     $str \
    #    commandProc ProcName \
    # }
    #
    variable dstruct
    array set dstruct {}

    variable commands
    array set commands {}

    # Create a array for fast access of various option Type details
    # optionType  Handler  default_val
    #
    variable validOptionTypes
    array set validOptionTypes {
	enum       {enum      NewCommands::setEnum          }
	boolean    {boolean   NewCommands::genericSetFunc   }
	double     {double    NewCommands::genericSetFunc   }
	integer    {integer   NewCommands::genericSetFunc   }
	number     {number    NewCommands::genericSetFunc   }
	string     {string    NewCommands::genericSetFunc   }
	file       {file      NewCommands::setFile          }
	helpMessage {}
    }

    # create an array of default values of various option types
    variable optionTypesDefaultVals
    array set optionTypesDefaultVals {
	enum       {}
	boolean    {false}
	double     {}
	integer    {}
	number     {}
	string     {}
	file       {}
	helpMessage {}
    }  
}


#
# Usage: <>:variable  []:optional   {}:list
#   NewCommands::addCommand <commandName> <myNs::commandProcName>                        \
#                [ {boolean [optionName]} ]                                              \
#                [ {string  [optionName]} ]                                              \
#                [ {double  [optionName]} ]                                              \ 
#                [ {integer [optionName]} ]                                              \
#                [ {number  [optionName]} ]                                              \
#                [ {file    mode  [optionName] } ]                                       \
#                [ {enum    <{list of possible values}>  <default_val>  <optionName>} ] 
#
# - Used to add commands to the global namespace of the tcl interpreter
# - This will be called by a number of commands at load time. So this needs 
#    to be really fast. As a result I have tried to be very miserly about creating
#    new variables and using procedures. 
# 
#  The order in which the options are specified will be the order assumed for the 
#  arguments of the core Tcl procedure <myNs>::<commandProcName> 
# 
#  For required options (that don't have optionName specified), the order in which they appear
#  in the addCommand argument list is preserved and is used to parse the command line in processArgs
#
#  <myNs>::<commandProcName> needs to be defined before calling this. Not applicable
#

proc NewCommands::addCommand {commandName commandProc args} {
    
    # Set some defaults
    #
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    variable commands
    variable dstruct
    variable validOptionTypes

    set usage {
Usage:  
	$me <NS::commandName>                                                      \
	    <NS::commandProcName>                                                  \
	    [ {boolean [optionName]} ]                                             \
	    [ {string  [optionName]} ]                                             \
	    [ {double  [optionName]} ]                                             \
	    [ {integer [optionName]} ]                                             \
	    [ {number  [optionName]} ]                                             \
            [ {helpMessage  <messageStr>} ]                                         \
            [ {file    <mode:r|r+|w|w+|a|a+> [<default file handle> [optionName]] } ]      \
            [ {enum    <{list of possible values}>  [<default_val> <optionName>]} ] 
	    
	Key: <>:variable  []:optional   {}:list 
    };


    ## If help is specified then display help
    ## But dont search throught the options yet

    # check the commandName. SHouldnt be defined already
    #
    if {[info commands $commandName] eq $commandName} {
	error "\nCommand $commandName already exists. Please specify a new command name."
    }

    if {$commandName eq $commandProc} {
	error "\nCommand $commandName and command procedure $commandProc are the same."
    }

    # $::commandName is the same as $commandName in the global case. So clear that first.
    # Drop the namespace ::
    if {[namespace qualifiers $commandName] eq ""} {
	set commandName [namespace tail $commandName]  
    }

    set list_validOptionsTypes [lsort [array names validOptionTypes]]

    # this wouldn't have been caught in the case of $::commandName and $commandName
    if [info exists commands($commandName)] {
	error "\nCommand $commandName has already been added."
    }
    
    
    # Init the variables
    set cn $commandName
    set commands($cn) 1
    set dstruct($cn,commandProc) $commandProc
    set dstruct($cn,helpStr) {}
    lappend dstruct($cn,helpStr) "---------------------------------------------------------------------\nUsage:\n  $cn \[-help\]"
    set dstruct($cn,helpMessage) {}
    set dstruct($cn,optionOrder) {}
    set dstruct($cn,optionalOptions) {"help" "NewCommands::displayHelp" "h" "NewCommands::displayHelp"}
    set dstruct($cn,reqdOptions) {}
    set dstruct($cn,returnVals) {}
    # set lengths to 0
    set dstruct($cn,optionOrderLen) 0
    set dstruct($cn,optionalOptionsLen) 0
    set dstruct($cn,reqdOptionsLen) 0
    set dstruct($cn,returnValsLen) 0


    # Now we go through the remaining args (each of the remaining args must be a list) 
    # and match them to known option types
    #    
    set argsLength [llength $args]
    for {set i 0} {$i < $argsLength} {incr i} {

	# Get the option specification
	set optionLine [lindex $args $i]

	set optionLineLen [llength $optionLine]

	# Make sure it has a finite length
	if {! $optionLineLen } {
	    error "\nIncorrect argument $optionLine.\n$usage"
	}
    
	# Now look at the first arg. It must be one of validOptionTypes
	set option [lindex $optionLine 0]
	if {! [info exists validOptionTypes($option)]} {
	    
	    # To make this function faster, I am assuming user is not going to abbr
	    # option type while registering the command
	    ## # Check if $option is an abbr of the valid option types
	    ## # the list is sorted and I want to catch multiple matches
	    #
	    # set option [getabbr $option 1 $list_validOptionsTypes $helpStr]

	    error "\n$option is not a valid option type ([join $list_validOptionsTypes {|}])"
	}

	if {$option eq "helpMessage"} {
	    if {$optionLineLen < 2} {
		error "Usage: [{helpMessage <messageStr>}]"
	    }
	    set dstruct($cn,helpMessage) [lrange $optionLine 1 end]	   
	    continue
	}
	
	# ok, valid option type. Lets invoke its corresponding handling routine
	#
	set optionType  [lindex $validOptionTypes($option) 0]
	set callback_proc    [lindex $validOptionTypes($option) 1]
	
	# make options case insensitive - lower case all options
	set optionName [string tolower [lrange $optionLine 1 end]]

	if {$optionLineLen > 1} {
	    set cmd [concat $callback_proc $commandName $optionType $optionName]
	} else {
	    set cmd [list $callback_proc $commandName $optionType]
	}
	# puts "$cmd"

	if {[catch $cmd ret]} {
	    error "\n$ret\nUnable to register option $option for command $commandName. Please check the usage."
	} else {
	    # Build the usage line...
	    lappend dstruct($cn,helpStr) $ret
	}
    }
    
    # Register the command with tcl interpreter
    # by creating a new proc (in global namespace) with the same name as the
    # command name. The proc simply calls an options processing procedure (NewCommands::processArgs) 
    # and will create an array out of the args and then call the actual command proc.
    
    proc ::$commandName args [format {
	tcl_puts $rt::cmdFd "%1$s $args"
	if {[info script] != {}} {
	    rt::UMsg_print "> %1$s $args\n"
	}
	if {![info exists NewCommands::commands(%1$s)]} {
	    # I wouldnt have reached here unless I went through addCommand.
	    # But then I should have an entry in the commands variable.
	    # Must be something funky going on.
	    error "\n%1$s is not registered. Possible corruption of NewCommands namespace."
	}
	# processArgs commandName args
	#	if {[set f [catch {NewCommands::processArgs %1$s retList args} ret]]} {
	#	    set sinfo $::errorInfo
	#	    error $ret $sinfo
	#	} 
	#	puts $f

	NewCommands::processArgs %1$s retList retFile retMode args
	set cmd %2$s
	foreach a $retList {lappend cmd $a}
	# puts "Invoking $cmd"
	if {$retFile ne ""} {
	    rt::UMsg_redirect $retFile $retMode
	}
	set rv [eval $cmd]
	rt::UMsg_reset
	if {$retFile ne ""} {
	    rt::UMsg_redirect -
	}
	if {[[$rt::db control] interrupted]} {
	    return -code error $rv
	}
	return $rv;
    } $commandName $commandProc]

    lappend dstruct($cn,helpStr) "\n---------------------------------------------------------------------"
    return "Command $cn added successfully"
}

##################################################################################################
##################################################################################################

# Since the call to processArgs is through a proc command that I have created above,
# I dont need to figure out if commandName is an abbr 
#
proc NewCommands::processArgs {commandName retListName retFileName retModeName argsListName} {
    
    # Set some defaults
    ##########################
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    
    upvar $retListName retList
    set retList ""
    upvar $retFileName retFile
    set retFile ""
    upvar $retModeName retMode
    set retMode ""
    upvar $argsListName cmdargs

    variable dstruct
    set cn $commandName

    
    # Derived variables
    ##########################
    #
    set helpStr [join $dstruct($cn,helpStr)]
    
    # Create an array of the option order list
    array set optionOrder $dstruct($cn,optionOrder)
    set optionOrderLen [llength [array names optionOrder]]

    array set optionalOpts $dstruct($cn,optionalOptions) 

    array set reqdOpts $dstruct($cn,reqdOptions)
    set numReqd [llength [array names reqdOpts]]
    
    # create an array of returnVals
    #
    array set returnVals $dstruct($cn,returnVals)
    
    # List of optional options
    # I derive this from optiinOpts data structure    
    #
    lappend optionalOptsList [lsort [array names optionalOpts]]
    
    
    #########################################################
    # ok now start processing
    #########
    set i 0
    set numReqdOptionFound 0
    set optionOrderIndex 0
    set reqdOptionsIndex 0
    set argsLen [llength $cmdargs]
    
    # Now go through the option line
    # Since I will be manipulating i myself, I go into a while loop
    #
    if {$argsLen} {
	while (1) {	
    
	    set arg [lindex $cmdargs [Utils::postincr i]]
	    
	    # Is it an option or a value
	    if {$arg != "-" && [regsub -- {^--?} $arg {} arg]} {
		
		# optional option
			
		# Check if arg is an abbr
		set arg [getabbr $arg 1 $optionalOptsList $helpStr]

		# Is it help?
		if {$arg eq "h" || $arg eq "help"} {
		    NewCommands::displayHelp $cn
		    return -code return 
		}

		if {![info exists optionOrder($optionOrderIndex)]} {
		    error "\nExtra characters detected at the end of the command: [lrange $cmdargs $i end]\n$helpStr"
		}	

		set cmd [concat $optionalOpts($arg)]
		lappend cmd $commandName 1 $arg cmdargs i
		# puts "optional: $cmd"

		# ok now run the handler
		if {[catch $cmd ret]} {
		    error "\nError processing optional option \"$arg\"\n$ret\n$helpStr"
		}
		
		set returnVals($arg) $ret
	    } else {
		if {$arg == ">" || $arg == ">>"} {
		    set retFile [lindex $cmdargs $i]
		    if {$arg == ">"} {
			set retMode "false"
		    } else {
			set retMode "true"
		    }
		    # puts "LogFile: $retFile: mode: $retMode"
		    incr i
		    if {$i < $argsLen} {
			error "\nError processing \"$arg\"\n$ret\n$helpStr"
		    }
		} else {
		    # reqdOptionsIndex is 0 to begin with. 
		    # it is incremented to 1 after the first reqd option is processed and 
		    # when I come here for the next non-optional argument it is 1. If there is only 
		    # one required option, then numReqd will also be 1. So I shouldnt really
		    # go further since this next arg is not a registered required option.
		    # 
		    if {! $numReqd || $reqdOptionsIndex == $numReqd} {
			error "\nDetected extra character(s) \"$arg\"\n$helpStr"
		    }
		    # Check the value
		    set cmd [concat [lindex $reqdOpts($reqdOptionsIndex) 0]]
		    lappend cmd $commandName 0 $arg cmdargs i
		    # puts "required: $cmd"
		    
		    if {[catch $cmd ret]} {
			# Check if required options are present
			if {$numReqd} {
			    error "\nError processing required [lindex $reqdOpts($reqdOptionsIndex) 1] option \"$arg\"\n$ret\n$helpStr"
			} else {
			    error "\nDetected extra characters \"$arg\"\n$helpStr"
			}
			
		    }
		    
		    # Add this a list for now
		    set returnVals("reqd_%_[Utils::postincr reqdOptionsIndex]") $ret
		    
		    incr numReqdOptionFound
		}
	    }
	    
	    # Check if we have exhausted all options
	    if {$i >= $argsLen} {
		break
	    }
	}
    }
    
    
    # Make sure all required options have been specified
    #
    if {$numReqdOptionFound != $numReqd} {
	error "\nMissing required option(s). Expecting $numReqd, got $numReqdOptionFound \n$helpStr"
    }
    
    # Now build the return list
    set optionOrderIndex 0    
    if {$optionOrderLen} {
	while (1) {
	    foreach {optional name type} $optionOrder([Utils::postincr optionOrderIndex]) {}
	    #puts "Doing $name $returnVals($name)"
	    if {$optional} {
		if {![info exists returnVals($name)]} {
		    error "\noption $name should have existed in returnVals array\n. Something wrong!";
		}
		lappend retList $returnVals($name)
	    } else {
		lappend retList $returnVals("reqd_%_$name")
	    }
	    if {$optionOrderIndex >= $optionOrderLen} {
		break
	    }
	}
    }
    
    
    return ""
}


##################################################################################################
# set functions
# called by addCommands to set up the various different option types
##################################################################################################

proc NewCommands::genericSetFunc {commandName optionType args} {
    
    set argsLen [llength $args]
    
    # Set some defaults
    #
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    set thisNameSpace [namespace current]   
    
    variable dstruct
    set cn $commandName
    variable optionTypesDefaultVals
    
    ######################
    set helpStr "Usage: {[string tolower $optionType] \[optionName\]}"
    
    
    # args can only be an optionName (if specified)
    if { $argsLen > 1} {
	error "\nIncorrect number of arguments to $optionType option: $args\n$helpStr"
    }
    
    
    # Is it a required or an optional option
    #
    if {$argsLen} {	
	# optional option
	set optional 1
	set optionName [lindex $args 0]
	if {$optionType != "boolean"} {
	    set optionHelpStr "\[-$optionName <$optionType>\]"
	} else {
	    set optionHelpStr "\[-$optionName\]"
	}

	# Set up the default value
	lappend dstruct($cn,returnVals) $optionName $optionTypesDefaultVals($optionType)
	
	# Add it to the necessady dstructs
	lappend dstruct($cn,optionalOptions) $optionName "${thisNameSpace}::check$optionType"
	
    } else {
	# required option
	set optional 0
	set optionName $dstruct($cn,reqdOptionsLen)
	set optionHelpStr "<$optionType>"
	
	# Add it to the necessady dstructs
	lappend dstruct($cn,reqdOptions) [Utils::postincr dstruct($cn,reqdOptionsLen)] [list "${thisNameSpace}::check$optionType" $optionType]
	
    }
    
    # Add this option to the optionOrder list
    lappend dstruct($cn,optionOrder) [Utils::postincr dstruct($cn,optionOrderLen)] [list $optional $optionName $optionType]
    
    # puts "optionOrder $dstruct($cn,optionOrder)"
    
    # return the help section here
    return $optionHelpStr
}

# If it is an optional option, then defaultValue and optionName both need to be specified
# If it is a required option, then these are not defined
#
proc NewCommands::setEnum {commandName optionType possibleVals args} {
    
    # Set some defaults
    #
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    set thisNameSpace [namespace current]
    
    variable dstruct
    set cn $commandName
    variable optionTypesDefaultVals
    
    #####################
    set helpStr "Usage: { enum <{list of possible values}>  \[<default_val> <optionName>\] }"
    set argsLen [llength $args]
    
    # Sort the list of possibleVals
    set possibleVals [lsort $possibleVals]
    
    # args can only be a defaultValue and optionName (if specified)
    if { $argsLen && $argsLen !=  2} {
	error "\nIncorrect number of arguments to enum option: $args\n$helpStr"
    }
    
    foreach value $possibleVals {
	set tmpArr($value) 1
    }
    
    # Is it a required or an optional option
    #
    if {$argsLen} {
	# optional option
	set optional 1
	set _default [lindex $args 0] 
	set optionName [lindex $args 1]
	
	# Create the help str
	# Here I am trying to create a string such as "fast|medium(default)|slow"
	#
	
	set tmpArr($_default\(default\)) 1
	unset tmpArr($_default)
	
	set optionHelpStr "\[-$optionName <[join [array names tmpArr] {|}]>\]"
	
	# Set up the default value
	lappend dstruct($cn,returnVals) $optionName $_default
	
	lappend dstruct($cn,optionalOptions) $optionName [list NewCommands::checkEnum $possibleVals]
	
	
    } else {
	# required option
	set optional 0
	set optionName $dstruct($cn,reqdOptionsLen)
	set optionHelpStr "<[join [array names tmpArr] {|}]>"
	
	lappend dstruct($cn,reqdOptions) [Utils::postincr dstruct($cn,reqdOptionsLen)] [list [list NewCommands::checkEnum $possibleVals] $optionType]
	
    }
    
    # Add this option to the optionOrder list
    lappend dstruct($cn,optionOrder) [Utils::postincr dstruct($cn,optionOrderLen)] [list $optional $optionName "enum: [join [array names tmpArr] {|}]"]
    
    # return the help section here
    return $optionHelpStr
}


# If it is an optional option, then optionName needs to be specified
# If it is a required option, then optionName is not defined

proc NewCommands::setFile {commandName optionType mode args} {
    
    # Set some defaults
    #
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    set thisNameSpace [namespace current]
    
    
    variable dstruct
    set cn $commandName
    variable optionTypesDefaultVals
    
    ###################
    set helpStr "Usage: { file <mode:r|r+|w|w+|a|a+> \[<default file handle> <optionName>\] }"
    set argsLen [llength $args]
    
    # args can only be a defaultValue and optionName (if specified)
    if { $argsLen && $argsLen != 2} {
	error "\nIncorrect number of arguments: $args\n$helpStr"
    }
    
    # Make sure mode is one of the valid open access arguments
    #
    array set validModes { r 1 r+ 1 w 1 w+ 1 a 1 a+ 1}
    if {![info exists validModes($mode)]} {
	error "\nMode $mode is not a valid open access mode ([join [array names validModes] {|}])"
    }
    
    # Is it a required or an optional option
    #
    if {$argsLen} {
	# optional option
	set optional 1
	set _default [lindex $args 0] 
	set optionName [lindex $args 1]
	
	set optionHelpStr "\[-$optionName <fileName>\]"
	
	# Set up the default value
	lappend dstruct($cn,returnVals) $optionName $_default
	
	lappend dstruct($cn,optionalOptions) $optionName [list NewCommands::checkFile $mode]
	
    } else {
	# required option
	set optional 0
	set optionName $dstruct($cn,reqdOptionsLen)
	set optionHelpStr "<fileName>"
	
	lappend dstruct($cn,reqdOptions) [Utils::postincr dstruct($cn,reqdOptionsLen)] [list [list NewCommands::checkFile $mode] $optionType]
    }
    
    lappend dstruct($cn,optionOrder) [Utils::postincr dstruct($cn,optionOrderLen)] [list $optional $optionName "fileName"]
    
    # return the help section here
    return $optionHelpStr    
}

##################################################################################################
# THese are the various check routines
##################################################################################################

proc NewCommands::checkEnum {possibleVals commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [Utils::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    
    # do a findabbr on optionVal against possibleVals
    if {[catch {Utils::findabbr $possibleVals $val 1} ret]} {
	error "Muliple matches detected for \"$val\". Please qualify further"
    }
    
    if {$ret eq ""} {
	error "\"$val\" is not one of possible values $possibleVals"
    } else {
	set val $ret
    }
    
    return $val
}

proc NewCommands::checkFile {mode commandName optional optionName argsName indexName} {
    
    #puts [info level 0]
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [Utils::postincr i]]			
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    
    # Try to open the file with the mode specified
    if {[catch {open $val $mode} fileId]} {
	error "Error \[open $val $mode\]: $fileId"
    }
    
    return $fileId
}

proc NewCommands::checkboolean {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	
	# check the next arg to see if it is a valid bool value
	set possibleval [lindex $args $i]
	if {[catch {Utils::findabbr {false true} $possibleval 1} ret]} {
	    # that is ok, we will assume true here and continue
	    set val "true"
	} else {
	    if {$ret eq ""} {
		set val "true"
	    } else {
		set val $ret
		incr i
	    }
	}
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
	
	# if {[string is true -strict $val] || [string is false -strict $val]} 
	
	# do a findabbr on optionVal against possibleVals
	if {[catch {Utils::findabbr {false true} $val 1} ret]} {
	    error "Muliple matches detected for \"$val\". Valid values: $possibleVals"
	}
	
	if {$ret eq ""} {
	    error "\"$val\" is not one of possible values {true|false}"
	} else {
	    set val $ret
	}
	
    }
    
    return $val
}

proc NewCommands::checkstring {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # puts "$commandName $optionName $argsName $indexName"
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [Utils::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    # Make sure it is a string
    # inluce white spaces?
    if {! [string is ascii $val]} {
	error "\"$val\" is not a valid ascii string"
    }
    
    return $val
}

proc NewCommands::checknumber {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [Utils::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    
    # Make sure it is a number
    if {[string is double -strict $val] || [string is integer -strict $val]} {
    } else {
	error "\"$val\" is not a valid number"
    }    
    
    return $val
}


proc NewCommands::checkdouble {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [Utils::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    
    # Make sure it is a number
    if {! [string is double -strict $val]} {
	error "\"$val\" is not a valid double"
    }    
    
    return $val
}


proc NewCommands::checkinteger {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [Utils::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    
    # Make sure it is a number
    if {! [string is integer -strict $val]} {
	error "\"$val\" is not a valid integer"
    }    
    
    return $val
}

# Util fuction
proc getabbr {arg sorted possibleVals {helpStr 0}} {
    
    #if {$callerName eq ""} {
    #	set callerName [lindex [info level 1] 0]
    #}   
    
    
    # Run findabbr on arg in case it is abbreviated
    set optionName [string tolower $arg]
    if {[catch [concat Utils::findabbr $possibleVals $optionName] ret]} {
	puts "Muliple matches detected for $arg. Please qualify fully."
	if {$helpStr != 0} {
	    puts $helpStr
	}
	error "exiting..."
    }
    
    if {$ret ne ""} {
	# Ah found an option that matches
	return $ret
    } else {
	puts "\"$arg\" is not a valid option."
	if {$helpStr != 0} {
	    puts "$helpStr"
	}
	error "exiting..."
    }
}

proc NewCommands::displayHelp {cn args} {
    
    variable dstruct
    
    set helpStr [join $dstruct($cn,helpStr)]
    
    puts $helpStr
    
    if {$dstruct($cn,helpMessage) ne ""} {
	puts [join $dstruct($cn,helpMessage)]
    }
}

##################################################################################################
##################################################################################################

##Testing
# optional option with a default value, last before required options...
# proc Test::tester args { puts $args }
# NewCommands::addCommand tester Test::tester {enum {foo goo loo} loo "-foobar"} {enum {123 456 789}}

proc mycatch args {
    puts "Executing: [lindex $args 0]"
    upvar [lindex $args 1] ret
    set f [catch [lindex $args 0] ret]
    return $f
}



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
