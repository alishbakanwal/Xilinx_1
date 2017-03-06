# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************

#
# Command Line Interface (cli) provides an API that will register
# given commands to the tcl system
#
# Notes:
# '?' denotes optional, applicable to positional argument only (the isArg).
# '#' denotes hidden.
# *string is string type allowing multiple specification, only allowed for option.

namespace eval cli {
    namespace export addCommand

    # Structure of the commands data structure:
    # commandName { \
    #    optionOrder {0 {optional optionName typeStr} 1 {optional optionName typeStr} ...} \
    #    optionalOptions {optionName_0 {callback args}  optionName_1 {callback args} ..} \
    #    optionMults {optionName_0 isMult0 optionName_1 isMult1 ...} \
	#    reqdOptions {0 {{callback args} optionType [defaultVal]}  1 {{callback args} optionType [defaultVal]} ..} \
    #    returnVals {optionName_0 defaultVal optionName_1 defaultVal ...} \
    #    helpStr     $str \
    #    commandProc ProcName \
    # }
    variable dstruct
    array set dstruct {}

    variable commands
    array set commands {}

    # Create a array for fast access of various option Type details
    # optionType  Handler  default_val
    variable validOptionTypes
    array set validOptionTypes {
	enum             {enum         cli::setEnum          }
	boolean          {boolean      cli::genericSetFunc   }
	double           {double       cli::genericSetFunc   }
	integer          {integer      cli::genericSetFunc   }
	number           {number       cli::genericSetFunc   }
	string           {string       cli::genericSetFunc   }
	"*string"        {"*string"    cli::genericSetFunc   }
	"?enum"          {"?enum"      cli::setEnum          }
	"?boolean"       {"?boolean"   cli::genericSetFunc   }
	"?double"        {"?double"    cli::genericSetFunc   }
	"?integer"       {"?integer"   cli::genericSetFunc   }
	"?number"        {"?number"    cli::genericSetFunc   }
	"?string"        {"?string"    cli::genericSetFunc   }
	"#enum"          {"#enum"      cli::setEnum          }
	"#boolean"       {"#boolean"   cli::genericSetFunc   }
	"#double"        {"#double"    cli::genericSetFunc   }
	"#integer"       {"#integer"   cli::genericSetFunc   }
	"#number"        {"#number"    cli::genericSetFunc   }
	"#string"        {"#string"    cli::genericSetFunc   }
	"#*string"       {"#*string"   cli::genericSetFunc   }
	"#?enum"         {"#?enum"     cli::setEnum          }
	"#?boolean"      {"#?boolean"  cli::genericSetFunc   }
	"#?double"       {"#?double"   cli::genericSetFunc   }
	"#?integer"      {"#?integer"  cli::genericSetFunc   }
	"#?number"       {"#?number"   cli::genericSetFunc   }
	"#?string"       {"#?string"   cli::genericSetFunc   }
	file             {file         cli::setFile          }
	helpMessage      {}
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
#   cli::addCommand <commandName> <myNs::commandProcName>                        \
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
proc cli::addCommand {commandName commandProc args} {
    
    # sort of a hack, but maybe this will scope things right for both standalone
    # and in-process rodin synthesis?
    set commandName "$commandName"
    
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


    # If help is specified then display help
    # But dont search throught the options yet

    # check the commandName. SHouldnt be defined already
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
    set dstruct($cn,optionMults) {}
    set dstruct($cn,optionalOptions) {"help" "cli::displayHelp" "h" "cli::displayHelp"}
    set dstruct($cn,reqdOptions) {}
    set dstruct($cn,returnVals) {}
    # set lengths to 0
    set dstruct($cn,optionOrderLen) 0
    set dstruct($cn,optionalOptionsLen) 0
    set dstruct($cn,reqdOptionsLen) 0
    set dstruct($cn,returnValsLen) 0


    # Go through the remaining args (each of the remaining args must
    # be a list) and match them to known option types
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
	    # # Check if $option is an abbr of the valid option types
	    # # the list is sorted and I want to catch multiple matches
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
	set optionType  [lindex $validOptionTypes($option) 0]
	set callback_proc    [lindex $validOptionTypes($option) 1]
	
	# make options case insensitive - lower case all options
	set optionName [string tolower [lrange $optionLine 1 end]]
	if {$optionLineLen > 1} {
	    set cmd [concat $callback_proc $commandName $optionType $optionName]
	} else {
	    set cmd [list $callback_proc $commandName $optionType]
	}
	if {[catch $cmd ret]} {
	    error "\n$ret\nUnable to register option $option for command $commandName. Please check the usage."
	} else {
	    if {$ret != ""} {
		# Build the usage line...
		lappend dstruct($cn,helpStr) $ret
	    }
	}
    }
    
    # Register the command with tcl interpreter
    # by creating a new proc (in global namespace) with the same name as the
    # command name. The proc simply calls an options processing procedure (cli::processArgs) 
    # and will create an array out of the args and then call the actual command proc.
    proc ::$commandName args [format {	

	# echo command: keep insync with sdcrt::exec
	set cmdLine "%1$s [sdcrt::objNames $args]"
        # similar to code found in sdc.tcl
	if {([info exist rt::cmdFd]) && $rt::cmdFdEcho} {
	    tcl_puts $rt::cmdFd $cmdLine
	}
	if {([info script] != {}) && $rt::cmdEcho} {
	    rt::UMsg_print "> $cmdLine\n"
	} else {
	    rt::UMsg_log "> $cmdLine\n"
	}

	if {![info exists cli::commands(%1$s)]} {
	    # I wouldnt have reached here unless I went through addCommand.
	    # But then I should have an entry in the commands variable.
	    # Must be something funky going on.
	    error "\n%1$s is not registered. Possible corruption of NewCommads namespace."
	}

	cli::processArgs %1$s retList retFile retMode args
	set cmd [concat %2$s $retList]
	# puts "Invoking $cmd"
	if {$retFile ne ""} {
	    rt::UMsgHandler_redirect $retFile $retMode
	}
        set timeStart [clock seconds]
	set rv [catch {eval $cmd} msg]
	rt::UMsgHandler_reset
        set timeEnd [clock seconds]
        set wallTime [expr $timeEnd-$timeStart]
        if {[rt::UParam_get reportCommandRuntime rc] == "true"} {
            rt::UMsg_print "Command \"%1$s $args\" finished in $wallTime second(s)\n"
        }
	if {$retFile ne ""} {
	    rt::UMsgHandler_redirect -
	}
	if {$rv || [[$rt::db control] interrupted]} {
	    return -code $rv $msg
	}
	return $msg;
    } $commandName $commandProc]

    lappend dstruct($cn,helpStr) {[{>|>>} <stdoutFile>]}
    lappend dstruct($cn,helpStr) "\n---------------------------------------------------------------------"
    return "Command $cn added successfully"
}

#
# Since the call to processArgs is through a proc command that I have created above,
# I dont need to figure out if commandName is an abbr 
#
proc cli::processArgs {commandName retListName retFileName retModeName argsListName} {
    
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
    set helpStr [join $dstruct($cn,helpStr)]
    
    # Create an array of the option order list
    array set optionOrder $dstruct($cn,optionOrder)
    set optionOrderLen [llength [array names optionOrder]]

    array set optionMults $dstruct($cn,optionMults)
    array set optionalOpts $dstruct($cn,optionalOptions) 

    array set reqdOpts $dstruct($cn,reqdOptions)
    set numReqd [llength [array names reqdOpts]]
    
    # create an array of returnVals
    array set returnVals $dstruct($cn,returnVals)
    
    # List of optional options, derived from optionalOpts data
    # structure
    lappend optionalOptsList [lsort [array names optionalOpts]]
    
    # start processing
    set i 0
    set optionOrderIndex 0
    set reqdOptionsIndex 0
    set argsLen [llength $cmdargs]
    
    # Now go through the option line
    if {$argsLen} {
	while (1) {	
	    set arg [lindex $cmdargs [cli::postincr i]]
	    # Is it an option or a value
	    if {$arg != "-" && ([regsub -- {^--} $arg {} argOpt] ||
				([regsub -- {^-} $arg {} argOpt] &&
				 ![string is double $argOpt]
				 ))} {
		# optional option
		set arg $argOpt
		# Check if arg is an abbr
		set arg [cli::getabbr $arg 1 $optionalOptsList $helpStr]
		# Is it help?
		if {$arg eq "h" || $arg eq "help"} {
		    cli::displayHelp $cn
		    return -code return 
		}
		if {![info exists optionOrder($optionOrderIndex)]} {
		    error "\nExtra characters detected at the end of the command: [lrange $cmdargs $i end]\n$helpStr"
		}	
		set cmd $optionalOpts($arg)
		lappend cmd $commandName 1 $arg cmdargs i
		# puts "optional: $cmd"

		# ok now run the handler
		if {[catch $cmd ret]} {
		    error "\nError processing optional option \"$arg\"\n$ret\n$helpStr"
		}
		# if if it is a "multi" option
		set mult $optionMults($arg)
		if {$mult == 0} {
		    set returnVals($arg) $ret
		} else {
		    lappend returnVals($arg) $ret
		}
		set out $returnVals($arg)
	    } else {
		if {$arg == ">" || $arg == ">>"} {
		    set retFile [lindex $cmdargs [cli::postincr i]]
		    if {$arg == ">"} {
			set retMode "false"
		    } else {
			set retMode "true"
		    }
		    # puts "LogFile: $retFile: mode: $retMode"
		    if {$i < $argsLen} {
			error "\nError processing \"$arg\"\n$ret\n$helpStr"
		    }
		} else {
		    if {$reqdOptionsIndex == $numReqd} {
			error "\nDetected extra character(s) \"$arg\"\n$helpStr"
		    }
		    # Check the value
		    set cmd [concat [lindex $reqdOpts($reqdOptionsIndex) 0]]
		    lappend cmd $commandName 0 $arg cmdargs i
		    
		    if {[catch $cmd ret]} {
			# Check if required options are present
			if {$numReqd} {
			    error "\nError processing required [lindex $reqdOpts($reqdOptionsIndex) 1] option \"$arg\"\n$ret\n$helpStr"
			} else {
			    error "\nDetected extra characters \"$arg\"\n$helpStr"
			}
		    }
		    # Add this a list for now
		    set returnVals("reqd_%_[cli::postincr reqdOptionsIndex]") $ret
		}
	    }
	    # Check if we have exhausted all options
	    if {$i >= $argsLen} {
		break
	    }
	}
    }
    # Make sure all required options have been specified
    if {$reqdOptionsIndex != $numReqd &&
	[llength $reqdOpts($reqdOptionsIndex)] == 2} {
	set reqCnt $reqdOptionsIndex
	while {$reqCnt < $numReqd && [llength $reqdOpts($reqCnt)] == 2} {
	    incr reqCnt
	}
	error "\nMissing required argument(s). Expecting $reqCnt, got $reqdOptionsIndex \n$helpStr"
    }
    while {$reqdOptionsIndex != $numReqd} {
	set req $reqdOpts($reqdOptionsIndex)
	set cmd [lindex $req 0]
	set arg [lindex $req 2]
	lappend cmd $commandName 0 $arg cmdargs i
	if {[catch $cmd ret]} {
	    # Check if required options are present
	    error "\nError processing optional argument [lindex $reqdOpts($reqdOptionsIndex) 1] option \"$arg\"\n$ret\n$helpStr"
	}
	# Add this a list for now
	set returnVals("reqd_%_[cli::postincr reqdOptionsIndex]") $ret
    }
    
    # Now build the return list
    set optionOrderIndex 0    
    if {$optionOrderLen} {
	while (1) {
	    foreach {optional name type} $optionOrder([cli::postincr optionOrderIndex]) {}
	    #puts "Doing $name $returnVals($name)"
	    if {$optional} {
		if {[info exists returnVals($name)]} {
		    lappend retList $returnVals($name)
		} else {
		    if {[info exists returnVals("reqd_%_$name")]} {
			lappend retList $returnVals("reqd_%_$name")
		    } else {
			error "\noption $name should have existed in returnVals array\n. Something wrong!";
		    }
		}
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

# used to reproduce the commands that have been entered
proc cli::echoCommandArgs {commandName args} {
    variable dstruct
    set cn $commandName
    
    # Create an array of the option order list
    set optionOrder $dstruct($cn,optionOrder)
    #set optionOrderLen [llength [array names optionOrder]]

    set optionOrderIndex 0
    set echoCmd {}
    lappend echoCmd $cn

    foreach {index opt} $optionOrder arg $args {
	# puts "$opt $arg"
	set optional [lindex $opt 0]
	set name [lindex $opt 1]
	set type [lindex $opt 2]
	if {$type == "boolean"} {
	    if {$arg} {
		lappend echoCmd -$name
	    }
	} else {
	    if {$arg != {}} {
		if {$name != 0} {
		    lappend echoCmd -$name $arg
		} else {
		    lappend echoCmd $arg
		}
	    }
	} 
    }
    puts $echoCmd
}

proc cli::addHiddenCommand {commandName commandProc args} {
    eval "addCommand $commandName $commandProc $args"
    interp hide {} $commandName
}

proc cli::exposeCommand {commandName} {
    interp expose {} $commandName
}

proc cli::hideCommand {commandName} {
    interp hide {} $commandName
}

##################################################################################################
# set functions
# called by addCommands to set up the various different option types
##################################################################################################
proc cli::genericSetFunc {commandName optionType args} {
    
    set argsLen [llength $args]
    
    # Set some defaults
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    set thisNameSpace [namespace current]   
    
    variable dstruct
    set cn $commandName
    variable optionTypesDefaultVals
    
    ######################
    set helpStr "Usage: {[string tolower $optionType] \[optionName\]}"
    
    # args can only be an optionName (if specified)
    if { $argsLen > 2} {
	error "\nIncorrect number of arguments to $optionType option: $args\n$helpStr"
    }
    
    set isArg 0
    set optional 0
    set defaultVal ""
    set hidden 0
    set mult 0
    set optionHelpStr ""
    if {[regsub -- {^\#} $optionType {} type]} {
	set hidden 1
	set optionType $type
    }
    if {[regsub -- {^\?} $optionType {} type]} {
	set isArg 1
	set optional 1
	set optionType $type
	if {$argsLen} {
	    set defaultVal [lindex $args 0]
	} else {
	    set defaultVal $optionTypesDefaultVals($optionType)
	}
    } else {
	if {$argsLen} {	    
	    set optional 1
	    if {[regsub -- {^\*} $optionType {} type]} {
		set mult 1
		set optionType $type
	    }
	    if {$argsLen > 1} {
		set defaultVal [lindex $args 1]
	    } else {
		set defaultVal $optionTypesDefaultVals($optionType)
	    }
	} else {
	    set isArg 1
	}
    }

    # Is it an argument or an option
    if {$isArg} {
	# argument
	set optionName $dstruct($cn,reqdOptionsLen)
	
	if {$hidden == 0} {
	    if {$optional} {
		set optionHelpStr "\[<$optionType>\]"
	    } else {
		set optionHelpStr "<$optionType>"
	    }
	}
	# Add it to the necessady dstructs
	if {$optional} {
	    lappend dstruct($cn,reqdOptions) [cli::postincr dstruct($cn,reqdOptionsLen)] \
		                             [list "${thisNameSpace}::check$optionType" $optionType $defaultVal] 
	} else {
	    array set reqd $dstruct($cn,reqdOptions)
	    set idx [expr $dstruct($cn,reqdOptionsLen)-1]
	    if {$idx > 0 && [llength $reqd($idx)] == 3} {
		error "\n$cn - Cannot have optional arguments before required arguments."
	    }
	    lappend dstruct($cn,reqdOptions) [cli::postincr dstruct($cn,reqdOptionsLen)] \
		                             [list "${thisNameSpace}::check$optionType" $optionType]
	}
    } else {
	# option
	set optionName [lindex $args 0]
	if {$hidden == 0} {
	    if {$optionType != "boolean"} {
		if {$mult == 1} {
		    set optionHelpStr "\[-$optionName <$optionType>\]*"
		} else {
		    set optionHelpStr "\[-$optionName <$optionType>\]"
		}
	    } else {
		set optionHelpStr "\[-$optionName\]"
	    }
	}

	# Add flag for "multi" option
	lappend dstruct($cn,optionMults) $optionName $mult

	# Set up the default value
	lappend dstruct($cn,returnVals) $optionName $defaultVal
	
	# Add it to the necessady dstructs
	lappend dstruct($cn,optionalOptions) $optionName "${thisNameSpace}::check$optionType"
    }
    
    # Add this option to the optionOrder list
    lappend dstruct($cn,optionOrder) [cli::postincr dstruct($cn,optionOrderLen)] [list $optional $optionName $optionType]
    
    # puts "optionOrder $dstruct($cn,optionOrder)"
    
    # return the help section here
    return $optionHelpStr
}

# If it is an optional option, then defaultValue and optionName both need to be specified
# If it is a required option, then these are not defined
proc cli::setEnum {commandName optionType possibleVals args} {
    
    # Set some defaults
    set me [lindex [info level 1] 0]
    set fullMe [namespace origin $me]
    set thisNameSpace [namespace current]
    
    variable dstruct
    set cn $commandName
    variable optionTypesDefaultVals
    
    #####################
    set helpStr "Usage: { enum <{list of possible values}>  \[<optionName> <default_val\] }"
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
    
    set isArg 0
    set optional 0
    set defaultVal ""
    set hidden 0
    set mult 0
    set optionHelpStr ""
    if {[regsub -- {^\#} $optionType {} type]} {
	set hidden 1
	set optionType $type
    }
    if {[regsub -- {^\?} $optionType {} type]} {
	set isArg 1
	set optional 1
	set optionType $type
	set defaultVal [lindex $args 0]
    } else {
	if {$argsLen} {
	    set optional 1
	    if {[regsub -- {^\*} $optionType {} type]} {
		set mult 1
		set optionType $type
	    }
	    set defaultVal [lindex $args 1]
	} else {
	    set isArg 1
	}
    }

    if {$defaultVal != ""} {
    	# Create the help str
	# Here I am trying to create a string such as "fast|medium(default)|slow"
	set tmpArr($defaultVal\(default\)) 1
	unset tmpArr($defaultVal)
    }

    # Is it an argument or an option
    if {$isArg} {
	# argument
	set optionName $dstruct($cn,reqdOptionsLen)
	if {$hidden == 0} {
	    set optionHelpStr "<[join [array names tmpArr] {|}]>"
	}
	if {$optional} {
	    lappend dstruct($cn,reqdOptions) [cli::postincr dstruct($cn,reqdOptionsLen)] \
                                             [list [list cli::checkEnum $possibleVals] $optionType $defaultVal]
	} else {
	    array set reqd $dstruct($cn,reqdOptions)
	    set idx [expr $dstruct($cn,reqdOptionsLen)-1]
	    if {$idx > 0 && [llength $reqd($idx)] == 3} {
		error "\n$cn - Cannot have optional arguments before required arguments."
	    }
	    lappend dstruct($cn,reqdOptions) [cli::postincr dstruct($cn,reqdOptionsLen)] \
                                             [list [list cli::checkEnum $possibleVals] $optionType]
	}
    } else {
	# option
	set optionName [lindex $args 0]
	if {$hidden == 0} {
	    set optionHelpStr "\[-$optionName <[join [array names tmpArr] {|}]>\]"
	}

	# Add flag for "multi" option
	lappend dstruct($cn,optionMults) $optionName $mult

	# Set up the default value
	lappend dstruct($cn,returnVals) $optionName $defaultVal
	lappend dstruct($cn,optionalOptions) $optionName [list cli::checkEnum $possibleVals]
    }
    
    # Add this option to the optionOrder list
    lappend dstruct($cn,optionOrder) [cli::postincr dstruct($cn,optionOrderLen)] \
                                     [list $optional $optionName "enum: [join [array names tmpArr] {|}]"]
    # return the help section here
    return $optionHelpStr
}

# If it is an optional option, then optionName needs to be specified
# If it is a required option, then optionName is not defined
proc cli::setFile {commandName optionType mode args} {
    
    # Set some defaults
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
    array set validModes { r 1 r+ 1 w 1 w+ 1 a 1 a+ 1}
    if {![info exists validModes($mode)]} {
	error "\nMode $mode is not a valid open access mode ([join [array names validModes] {|}])"
    }
    
    # Is it a required or an optional option
    if {$argsLen} {
	# optional option
	set optional 1
	set _default [lindex $args 0] 
	set optionName [lindex $args 1]
	
	set optionHelpStr "\[-$optionName <fileName>\]"
	
	# Set up the default value
	lappend dstruct($cn,returnVals) $optionName $_default
	
	lappend dstruct($cn,optionalOptions) $optionName [list cli::checkFile $mode]
	
    } else {
	# required option
	set optional 0
	set optionName $dstruct($cn,reqdOptionsLen)
	set optionHelpStr "<fileName>"
	
	lappend dstruct($cn,reqdOptions) [cli::postincr dstruct($cn,reqdOptionsLen)] [list [list cli::checkFile $mode] $optionType]
    }
    
    lappend dstruct($cn,optionOrder) [cli::postincr dstruct($cn,optionOrderLen)] [list $optional $optionName "fileName"]
    
    # return the help section here
    return $optionHelpStr    
}

##################################################################################################
# These are the various check routines
##################################################################################################
proc cli::checkEnum {possibleVals commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [cli::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    
    # do a findabbr on optionVal against possibleVals
    if {[catch {cli::findabbr $possibleVals $val 1} ret]} {
	error "Muliple matches detected for \"$val\". Please qualify further"
    }
    
    if {$ret eq ""} {
	error "\"$val\" is not one of possible values $possibleVals"
    } else {
	set val $ret
    }
    
    return $val
}

proc cli::checkFile {mode commandName optional optionName argsName indexName} {
    
    #puts [info level 0]
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [cli::postincr i]]			
	
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

proc cli::checkboolean {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	
	# check the next arg to see if it is a valid bool value
	set possibleval [lindex $args $i]
	if {[catch {cli::findabbr {false true} $possibleval 1} ret]} {
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
	if {[catch {cli::findabbr {false true} $val 1} ret]} {
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

proc cli::checkstring {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # puts "$commandName $optionName $argsName $indexName"
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [cli::postincr i]]		
	
    } else {
	# required option
	# optionName is actually the value 
	set val $optionName
    }
    # Make sure it is a string
    # inluce white spaces?
#     if {! [string is ascii $val]} {
# 	error "\"$val\" is not a valid ascii string"
#     }
    
    return $val
}

proc cli::checknumber {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [cli::postincr i]]		
	
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


proc cli::checkdouble {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [cli::postincr i]]		
	
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


proc cli::checkinteger {commandName optional optionName argsName indexName} {
    
    # Link to the args list from the calling procedure
    upvar $argsName args
    upvar $indexName i
    
    # Is it an optional option or a required one
    if {$optional} {
	# optional option
	
	#extract the value of the option from the args 
	set val [lindex $args [cli::postincr i]]		
	
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
proc cli::getabbr {arg sorted possibleVals {helpStr 0}} {
    
    # Run findabbr on arg in case it is abbreviated
    set optionName [string tolower $arg]
    if {[catch [concat cli::findabbr $possibleVals $optionName] ret]} {
	puts "Muliple matches detected for $arg. Please qualify fully."
	if {$helpStr != 0} {
	    puts $helpStr
	}
	error "exiting..."
    }
    
    if {$ret ne ""} {
	# found an option that matches
	return $ret
    } else {
	puts "\"$arg\" is not a valid option."
	if {$helpStr != 0} {
	    puts "$helpStr"
	}
	error "exiting..."
    }
}

proc cli::displayHelp {cn args} {
    
    variable dstruct
    
    set helpStr [join $dstruct($cn,helpStr)]
    
    puts $helpStr
    
    if {$dstruct($cn,helpMessage) ne ""} {
	puts [join $dstruct($cn,helpMessage)]
    }
}

####################################################################################
# Implement i++ type functionality
#
proc cli::postincr {valName} {
    upvar $valName v
    set tmp $v
    incr v
    return $tmp
}

####################################################################################
# Given a list and a string, this proc will try to 
# first find the exact match(s) for the string in the list and 
# return the value(s) 
#
# If an exact match is not found, it will try to match for the glob 
# pattern "$string*" and return any matching value(s).
# 
# In case more than one match is found, if fatalIfNotUnique is true (default),
# it would be an error condition. If fatalIfNotUnique is false, and if returnList 
# is true, it will return the list of matches. If returnList is false (default) 
# it will return the first match only
#
# TBD If returnIndex is true, it will return the index(s) of the matching elements instead
# of the values.  You will need to keep a tab of the indexes before sorting list and then
# based on the selected value, return the index of the value in the original string
#
proc cli::findabbr { list val {sorted 0} {fatalIfNotUnique 1} {returnList 0} } {    

    
    # Sort if not sorted already
    # This will allow us to do faster searches (-sorted)
    if { ! $sorted }  {
	set list [ lsort $list ]
    }

    # Ok, now match the elements
    #
    #puts "[info level 0]"

    # First try the exact match. -all returns all matches and -sorted makes search faster
    #
    if {! [llength [set matchedVals [ lsearch -exact -all -inline -sorted $list $val ]]] } {
	#puts "Didnt find an exact match"
	
	# ok, now try the glob match
	if {! [llength [set matchedVals [ lsearch -glob -inline -all $list "$val*"]]] } {
	    # Not found. Return an empty string
	    #puts "Didnt find an glob match either"
	    return ""
	}
    } 
   

    # Cool, now we have one (or more) matched indexes.
    # First do fatalIfNotUnique thingy
    #
    if {$fatalIfNotUnique && [llength $matchedVals] > 1 } {
	error "cli::findabbr : Multiple matches found for $val"
    }


    # Now do returnList thingy
    if {$returnList} {
	return $matchedVals
    } else {
	return [lindex $matchedVals 0]
    }

    error "Should not reach here"
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
