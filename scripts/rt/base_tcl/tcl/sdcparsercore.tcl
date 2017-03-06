################################################################################
#                       >  COPYRIGHT NOTICE  <
#
#  Copyright 2000 (c) Synopsys.
#
#
################################################################################
#
# Title        : SDC-parser engine
#
# Project      : SDC-parser
#
# Authors      : A.Gratchev
#                Intrinsix Corp.
#                anso@intrinsix.com  
# Modified	: Ibna faruque
################################################################################
# 
# List of procedures
#
# API procedures
#
#-------------------------------------------------------------------------------
# Function       :  sdc::declare
# Description    :  Declares SDC file command (each SDC command should be
#                :  declared for particular SDC version)
#-------------------------------------------------------------------------------
# Function       :  sdc::parse_file
# Description    :  Runs sdc-parser for source of SDC file
#-------------------------------------------------------------------------------
# Function       :  sdc::parse_command
# Description    :  Runs sdc-parser for one SDC command
#-------------------------------------------------------------------------------
# Function       :  sdc::register_callback
# Description    :  Sets a callback
#-------------------------------------------------------------------------------
# Function       :  sdc::set_debug_level
# Description    :  Sets the level of debug messages
#-------------------------------------------------------------------------------
# Function       :  sdc::set_version
# Description    :  sets the sdcversion for use
#-------------------------------------------------------------------------------
#
# Internal rountines
#
#-------------------------------------------------------------------------------
# Function       :  sdc::proceesserror
# Description    :  Creates an error message from standart Tcl $errorInfo
#-------------------------------------------------------------------------------
# Function       :  sdc::setversion
# Description    :  Handler of setting of "sdc_version" variable
#-------------------------------------------------------------------------------
# Function       :  sdc::puterror
# Description    :  Puts some misc error messages
################################################################################
# ----------------------------------------------------------------------
# Revision History :
# ----------------------------------------------------------------------
# Date       By           Changes Description
# ----------------------------------------------------------------------
# 11/17/00   A.Gratchev  Initial coding and debugging
# 02/22/01   A.Sokhatski Simplified code which processes list of 
#                        parameters with defined type (by customer request)     

# 02/27/01   Ibna Faruque               

namespace eval sdc {
#     variable validsdcversions [list 1.4 1.3 1.2 1.1]   ;# list of valid sdc_versions
    variable validsdcversions [list 1.7]
    variable sdc_version        ;# current sdc_version
    variable lineno 0           ;# line number in processing file
    variable statement ""       ;# current read statement
    variable procdefs           ;# internal array of sdc commands declarations
    variable proccond           ;# internal array of sdc commands conditions
    variable callback ""        ;# name of callback procedure
    variable debuglevel 1       ;# debug level (can be 0,1,2)
    variable errors 0           ;# number of errors in one command
    variable errorstotal 0      ;# total errors which was found
    variable filename ""        ;# current processing file

#-------------------------------------------------------------------------------
# Function       :  sdc::declare
# Description    :  Declares SDC file command (each SDC command should be
#                :  declared for particular SDC version)
# Parameters     :  proc        - name of the command (Ex.: create_clock)
#                :  defargs     - list of descriptions of commands parameters
#                :  cond        - describing correct set of SDC-command's
#                :                arguments
# Return         :  Nothing
#-------------------------------------------------------------------------------
    proc declare {proc defargs {cond 1}} {
        variable procdefs
        variable proccond
        variable sdc_version 

        # checking for duplicate of declaration

        if {![info exists procdefs($sdc_version,$proc)]} {
            set procdefs($sdc_version,$proc) $defargs
            set proccond($sdc_version,$proc) $cond
        } else {
            rt::UMsg_print "FATAL ERROR: Procedure \"$proc\" of version \
                         $sdc_version already declared!"
            exit -1
        }

        # declarating sdc-command as procedure in slave Tcl-interp

        rt::sdc$sdc_version eval "
            __proc $proc {args} {
                __return \[parse_command $sdc_version $proc \$args\]
            } "

        # also declarating sdc-command as procedure in main Tcl-interp

	eval "
            proc ::rt::$proc {args} {
                return \[sdcrt::exec $proc \$args\]
            } "
    }

    proc register_new_type {type body} {
        if {[info commands ::__user_type_handler_$type]==""} {
            eval "
                proc ::__user_type_handler_$type {value ext_list} \{
                    $body
                \}
            "
        } else {
            rt::UMsg_print "FATAL ERROR: Type \"$type\" already declared!"
            exit -1
        }
    }

    # create slave Tcl-interp for each sdc version

    foreach v $validsdcversions {

        interp create rt::sdc$v

        rt::sdc$v eval {

            # make trace handler on variable sdc_version
            # for checking of valid

            trace variable sdc_version w __set_v

            proc __set_v {name args} {
                __upvar    $name sdcv
                setversion $sdcv
            }

            # redefine procedure list which converting
            # hierarhical list to simple list

            proc list {args} {
                # same as utils::flatList
	        __while {1} {
	            set newargs [__join $args]
	            __if {$newargs == $args} {
		        __break
	            } else {
		        set args $newargs
                }
	        }
	        __return $args
            }

            # proc unknown {cmd_name args} {
            # puterror INVALID_COMMAND "$cmd_name"
            # __return ""
            # }

            proc unknown { args } {
                set name [__lindex $args 0]
                __if { [__llength $args] == 1 \
                         && ([__string is integer $name] || [__string equal $name "*"]) } {
                    __return "\[$args\]"
                }
                __if { [__llength $args] == 1 \
                         && ([__regexp -nocase {(\d)+\s*(:\s*(\d)+)?} $name]) } {
                    __return "\[$args\]"
                }

                puterror INVALID_COMMAND "$args"
                __return ""
            }
        }

        # disable all tcl commands

        foreach pr [rt::sdc$v eval info commands] {
            rt::sdc$v hide $pr
        }

        # enable and rename only needed procedures

        rt::sdc$v expose __set_v
        rt::sdc$v expose proc    __proc
        rt::sdc$v expose upvar   __upvar
        rt::sdc$v expose return  __return
        rt::sdc$v expose foreach __foreach
        rt::sdc$v expose concat  __concat
        rt::sdc$v expose while   __while
        rt::sdc$v expose join    __join
        rt::sdc$v expose if      __if
        rt::sdc$v expose break   __break
        rt::sdc$v expose lindex   __lindex
        rt::sdc$v expose llength  __llength
        rt::sdc$v expose string   __string
        rt::sdc$v expose regexp   __regexp

        rt::sdc$v expose list
        rt::sdc$v expose set
        rt::sdc$v expose expr
        rt::sdc$v expose unknown

        rt::sdc$v alias setversion sdc::setversion
        rt::sdc$v alias parse_command sdc::parse_command
        rt::sdc$v alias puterror sdc::puterror

        set sdc_version $v

        # include source file
        # which contains of describing of sdc commands

	if {$::rt_tool_name != "realTimeFpga"} {
	    set fileExt odb
	} else {
	    set fileExt tcl
	}

        if {[catch {source [file join [file dirname [info script]] \
          sdc$v.$fileExt]}]} {
            rt::UMsg_print "FATAL ERROR: Can't load file \"sdc$v.$fileExt\"!"
            exit -1
        }
        if {[catch {source [file join [file dirname [info script]] \
          sdc_commands.$fileExt]}]} {
            rt::UMsg_print "FATAL ERROR: Can't load file \"sdc_commands.$fileExt\"!"
            exit -1
        }
    }
    set sdc_version [lindex $validsdcversions 0]
}

#-------------------------------------------------------------------------------
# Function       :  sdc::parse_file
# Description    :  Runs sdc-parser for source of SDC file
# Parameters     :  filename    - file name of sdc source (SDC commands)
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::parse_file {echo file_name} {
    variable validsdcversions 
    variable sdc_version 
    variable lineno 1
    variable statement ""  
 
    if {[catch {set fname [::open $file_name]} msg] != 0} {
        rt::UMsg_print "Cannot open file: $file_name\n$msg\n"
	return -code error
    } else {
        variable filename $file_name
        set lines 1
        while {![eof $fname]} {
            append statement [gets $fname]

            set stlen [string length $statement]

            # read next line if statement is not complite

            if {[string index $statement [expr {$stlen - 1}]]=="\\" \
					|| ![info complete $statement]} {
                append statement "\n"
                incr lines
                if {![eof $fname]} {
                    continue
                }
            }
			if 0 {
				puts "filter sdc $statement"
				#filter set_property sdc	    
				if { $rt::in_pre_sdc == true && [string first set_property $statement] == -1 && $statement ne "" } {
					#not set_property sdc, do not process, just continue
					puts "in pre_sdc, cmd skipped $statement"
					set statement ""
					incr lineno $lines
					set  lines 1
					continue
				}
				if { $rt::in_pre_sdc == false && [string first set_property $statement] >= 0} {
					#set_property sdc, do not process, just continue
					puts "in sdc, cmd skipped $statement"
					set statement ""
					incr lineno $lines
					set  lines 1
					continue
				}
			}
            # run sdc command
			if {$echo} {
				puts "> $statement"
			}
			
            global sdcrt::cmdname
            set cmdname $statement 
            if {[catch {rt::sdc$sdc_version eval $statement}]} {
                processerror
            }
			if {$echo} {
				sdcrt::report_summary
			}
			
            set statement ""
            incr lineno $lines
            set  lines 1
        }
        catch {close $fname}
    }
    variable filename "" ;# reset the file name
}

#-------------------------------------------------------------------------------
# Function       :  sdc::proceesserror
# Description    :  Creates an error message from standart Tcl $errorInfo
# Parameters     :  None
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::processerror {} {
    variable lineno
    variable debuglevel 
    variable errors
    variable errorstotal
    variable filename
    global   errorCode errorInfo
    
    incr errors
    incr errorstotal
    
    set err     [split $errorInfo "\n"]
    set errMsg  [lindex $err 0]
    set errSt   [lindex $err 2]
    
#     set f 0
#     foreach errL [lrange $err 3 end] {
#         if {[string match {*line [0-9]*)} $errL]} {
#             set f 1
#             set errSt [join [lrange $err 2 [expr \
#                        {[lsearch -exact $err $errL] - 1}]] "\n"]
#             break
#         }
#     }

#     if {$f} {
#         set errLine ""

#         for {set i [expr {[string length $errL] - 2}]} \
#           {($i>=0) && ([set c [string index $errL $i]]!=" ")} {incr i -1} {
#             set errLine "$c$errLine"
#         }
#         set errLine [expr {$lineno + $errLine - 1}]
#     } else {
        set errLine $lineno
#     }

    switch -- $debuglevel {
        0 {
            set errmsg ""
        }

        2 {
            if {$filename ne ""} {
                set errmsg "$filename:$errLine: $errMsg\n while executing $errSt\n"
            } else {
                set script "[info script]"
                set errmsg "$script: $errMsg\n"
            }
        }

        1 -
        default {
            if {$filename ne ""} {
                set errmsg "$filename:$errLine: $errMsg\n"
            } else {
                set script "[info script]"
                set errmsg "$script: $errMsg\n"
            }
        }
    }
	#puts "in error handling, $errmsg"
	if { !($errmsg eq "") } {
		# add support for handling error messages in Vivado
		if { [ info exists ::env(BUILTIN_SYNTH) ] } {
			# in Vivado
			global sdcrt::cachedfname
			global sdcrt::cachedlnum
			#puts "in error msg, $cachedfname, $cachedlnum"
			if { ! ( $cachedfname eq "") } {
				rt::UMsg_print "$errMsg at line $cachedlnum of file $cachedfname\n" 
			} else {
				# still print the realTime message in absence of file location info
				rt::UMsg_print "warning: $errmsg"
			}
		} else {
			rt::UMsg_print $errmsg
		}
	}
}

#-------------------------------------------------------------------------------
# Function       :  sdc::setversion
# Description    :  Handler of setting of "sdc_version" variable
# Parameters     :  sdcv        - a new sdc_version value
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::setversion {sdcv} {
    variable validsdcversions
    variable sdc_version

#     if {[lsearch -exact $validsdcversions $sdcv]==-1} {
#         puterror INCORRECT_SDC_VERSION
#     } else {
#         set sdc_version $sdcv
#     }
    set sdc_version 1.7
}

#-------------------------------------------------------------------------------
# Function       :  sdc::puterror
# Description    :  Puts some misc error messages
# Parameters     :  msg         - text of the message
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::puterror {msg_id args} {
    variable statement
    global   errorInfo

    switch -exact -- $msg_id {
        INCORRECT_SDC_VERSION   {
            set errorInfo "incorrect sdc_version"
        }
        
        INVALID_COMMAND   {
            set errorInfo "invalid command \"[lindex $args 0]\""
        }

        VALUE_NOT_SPECIFIED     {
            set errorInfo "value not specified for \"[lindex $args 0]\""

        }

        INCORRECT_ARGUMENT      {
            set errorInfo "incorrect argument \"[lindex $args 1]\"\
                           for \"[lindex $args 0]\""
        }
        
        INCORRECT_ARGUMENT_PRE  {
            set errorInfo "incorrect argument \"[lindex $args 1]\"\
                           for \"[lindex $args 0]\"\
                           Too many pretendents"
        }

        INCORRECT_ARGUMENT_DUP  {
            set errorInfo "duplicate arguments \"[lindex $args 0]\"\
                           for \"[lindex $args 1]\""
        }
        INCORRECT_ARGUMENT_MANY {
            set errorInfo "incorrect argument \"[lindex $args 1]\"\
                           for \"[lindex $args 0]\"\
                           (too many arguments?)"
        }

        INCORRECT_VALUE_RANGE   {
            set errorInfo "incorrect value for \"[lindex $args 0]\",\
                           must be [lindex $args 1]"
        }

        INCORRECT_TYPE      {
            set errorInfo "incorrect value for \"[lindex $args 0]\""
        }

        INCORRECT_TYPE_FLOAT    {
            set errorInfo "incorrect value for \"[lindex $args 0]\",\
                           must be float type"
        }

        INCORRECT_TYPE_INT      {
            set errorInfo "incorrect value for \"[lindex $args 0]\",\
                           must be integer type"
        }

        INCORRECT_TYPE_STRING   {
            set errorInfo "incorrect value for \"[lindex $args 0]\",\
                           must be string type"
        }

        INCORRECT_TYPE_LIST     {
            set errorInfo "incorrect value for \"[lindex $args 0]\",\
                           must be list type"
        }
        
        INCORRECT_TYPE_LIST_ELEM {
            set errorInfo "incorrect type of elements of list for\
                           \"[lindex $args 0]\",\
                           must be [lindex $args 1] type"
        }

        INCORRECT_TYPE_LIST_LENGTH {
            set errorInfo "incorrect length of list for \"[lindex $args 0]\""
        }

        INCORRECT_SET           {
            set errorInfo "incorrect set of required parameters for\
                           \"[lindex $args 0]\""
        }

        USER {
            set errorInfo "[lindex $args 0]"
        }

        default {
            set errorInfo "unknown error message $msg_id"
        }
    }

    append errorInfo "\nwhile executing\n\"$statement\"\n(line 1)"
    processerror
}

proc sdc::usage {cmd} {
    variable procdefs
    variable sdc_version 

    rt::UMsg_print "---------------------------------------------------------------------\n"
    rt::UMsg_print "Usage:\n"
    rt::UMsg_print "  $cmd\n"
    rt::UMsg_print "    \[-help\]\n"
    foreach arg $procdefs($sdc_version,$cmd) {
	set option [lindex $arg 0]
	set type   [lindex $arg 1]
	set dup    [lindex $arg 2]
	set item "$option"
	if {[string index $option 0] == "-"} {
	    if {$type != "Flag"} {
		append item " <$type>"
	    }
	    set item "\[$item\]"
	}
	if {$dup == "dup"} {
	    append item "*"
	}
	rt::UMsg_print "    $item\n"
    }
    rt::UMsg_print "    \[{>|>>} <stdoutFile>\]\n"
    rt::UMsg_print "---------------------------------------------------------------------\n"
}

#-------------------------------------------------------------------------------
# Function       :  sdc::check_type
# Description    :  Check type of argument
# Parameters     :  type        - type of argument
#                :  value       - value to be cheked
# Return         :  True or false
#-------------------------------------------------------------------------------
proc sdc::check_type {type value args} {
    variable errors

    switch -- $type {
        float -
        Float {
            # for checking that it is Float add 1 and catch exception
            if {![catch {expr {$value + 1}}]} {
                return 1
            } else {
                return 0
            }
        }

        int -
        Int {
            if {![catch {expr {$value + 1}}] \
              && [expr {int($value) == $value}]} {
                return 1
            } else {
                return 0
            }
        }

        string -
        String {
                return 1
        }

        enum -
        Enum {
            foreach val [lindex $args 0] {
                if {$val==$value} {
                    return 1
                }
            }
            return 0
        }

        list -
        List {
            if {![catch {llength $value}]} {
                return 1
            } else {
                return 0
            }
        }

        unknown -
        Unknown {
            return 1
        }

        default {
            if {[info commands ::__user_type_handler_$type]==""} {
                puterror USER "INTERNAL: unknown type of param:\
                         \"$type\", ignored"
                incr errors -1
                return 1
            } else {
                if {![catch {set res [eval {::__user_type_handler_$type $value\
                  [lindex $args 0]}]}]} {
                    if {$res} {
                        return 1
                    } else {
                        return 0
                    }
                } else {
                    puterror USER "INTERNAL: error while executing\
                             user's checking procedure for type:\
                             \"$type\", ignored"
                    incr errors -1
                    return 0
                }
            }
        }
    } ;#switch
}

#-------------------------------------------------------------------------------
# Function       :  sdc::parse_command
# Description    :  Runs sdc-parser for one SDC command 
# Parameters     :  ver         - version number of SDC (Ex.: 1.1)
#                :  proc        - name of the command (Ex.: create_clock)
#                :  arguments   - list of command's arguments
# Return         :  Callback result or empty
#-------------------------------------------------------------------------------
proc sdc::parse_command {ver proc arguments} {
    variable procdefs
    variable proccond
    variable errors 0
    variable callback

    # local variables for parameters presentation
    #
    # procpars       - matching parameter lists from command declaration
    # procpar        - matching parameter list 
    # parexpect      - matching parameter list (for -name parameter) or empty 
    # param_array    - internal array for parsed command
    # data_structure - result data structure for EDA procedure

    set i 0
    set num [llength $arguments]
    set parexpect ""

    while {$i<$num} {
        set par [lindex $arguments $i]

        if {[string match {-[a-zA-Z]*} $par]} {

            # if here, par is key param

            incr i
            if {$parexpect!=""} {
                puterror VALUE_NOT_SPECIFIED "$proc [lindex $parexpect 0]"
            }

            # finding descriptions of matching parameters

            set procpars ""
            foreach procpar $procdefs($ver,$proc) {
                if {[string match "$par*" [lindex $procpar 0]]} {
                    if {[lindex $procpar 0]==$par} {
                        set procpars [list $procpar]
                        break
                    } else {
                        lappend procpars $procpar
                    }
                }
            }

            # how many matchings found?

            switch -- [llength $procpars] {
                0 {
		    if {[string match "$par*" "-help"]} {
			usage $proc
			return ""
		    }
                    puterror INCORRECT_ARGUMENT $proc $par
                    continue
                }

                1 {
                    set procpar [join $procpars]
                    if {([lindex $procpar 1]=="List" &&
                      [lsearch -exact [lindex $procpar 2] dup]!=-1) ||
                      ![info exists param_array([lindex $procpar 0],key)]} {
                        set param_array([lindex $procpar 0],key) 1
                    } else {
                        puterror INCORRECT_ARGUMENT_DUP \
                                 [lindex $procpar 0] $proc
                    }
                    set parexpect $procpar
                }

                default {
                    puterror INCORRECT_ARGUMENT_PRE $proc $par
                    continue
                }
            }

            # if argument is "Flag", go to analyze the next argument

            if {[lindex $parexpect 1]=="Flag"} {
                set parexpect ""
                set param_array([lindex $procpar 0],value) yes
                continue
            }
            if {$i>=$num} {
                puterror VALUE_NOT_SPECIFIED "$proc [lindex $parexpect 0]"
                break
            }
            set par [lindex $arguments $i]
        }

        if {$parexpect==""} {

            # positional argument, find the first empty

            set f 0
            foreach procpar $procdefs($ver,$proc) {
                if {[string index [lindex $procpar 0] 0]!="-"} {
                    if {![info exists param_array([lindex $procpar 0],value)]} {
                        set f 1
                        set parexpect $procpar
                        break
                    } else {
                        continue
                    }
                }
            }
            if {!$f} {
                puterror INCORRECT_ARGUMENT_MANY $proc $par
            }
        } else {
            set f 1
        }

        # value of argument, check format

        if {$f} {
            switch -- [lindex $parexpect 1] {
                float -
                Float { 
                    # for checking that it is Float add 1 and catch exception
                    if {[check_type Float $par]} {
                        if {![catch {set f [expr [lindex $parexpect 2]]}] \
                          && $f} {
                            set param_array([lindex $parexpect 0],value) $par
                        } else {
                            regsub -all -- {\$par} [lindex $parexpect 2] {} cond
                            puterror INCORRECT_VALUE_RANGE "$proc [lindex \
                                     $parexpect 0]" $cond
                            catch {unset param_array([lindex $parexpect 0],key)}
                        }
                    } else {
                        puterror INCORRECT_TYPE_FLOAT \
                                 "$proc [lindex $parexpect 0]"
                        catch {unset param_array([lindex $parexpect 0],key)}
                    }
                }

                int -
                Int {
                    if {[check_type Int $par]} {
                        if {![catch {set f [expr [lindex $parexpect 2]]}] \
                          && $f} {
                            set param_array([lindex $parexpect 0],value) $par
                        } else {
                            regsub -all -- {\$par} [lindex $parexpect 2] {} cond
                            puterror INCORRECT_VALUE_RANGE "$proc [lindex \
                                     $parexpect 0]" $cond
                            catch {unset param_array([lindex $parexpect 0],key)}
                        }
                    } else {
                        puterror INCORRECT_TYPE_INT \
                                 "$proc [lindex $parexpect 0]"
                        catch {unset param_array([lindex $parexpect 0],key)}
                    }
                }

                string -
                String {
                    if {[check_type String $par]} {
                        set param_array([lindex $parexpect 0],value) $par
                    } else {
                        puterror INCORRECT_TYPE_STRING \
                                 "$proc [lindex $parexpect 0]"
                        catch {unset param_array([lindex $parexpect 0],key)}
                    }
                }

                enum -
                Enum {
                    if {[check_type Enum $par [lindex $parexpect 2]]} {
                        set param_array([lindex $parexpect 0],value) $par
                    } else {
                        puterror INCORRECT_TYPE \
                                 "$proc [lindex $parexpect 0]"
                        catch {unset param_array([lindex $parexpect 0],key)}
                    }
                }

                list -
                List {
                    if {[check_type List $par]} {
                        if {[set type_id [lsearch -glob [set attr [lindex \
                          $parexpect 2]] {length(*)}]]!=-1} {
                            set length [llength $par]
                            if {[catch {set res [expr "[string range [lindex \
                              $attr $type_id] 6 end]"]}] || !$res} {
                                puterror INCORRECT_TYPE_LIST_LENGTH \
                                         "$proc [lindex $parexpect 0]"
                                catch {unset param_array([lindex \
                                                         $parexpect 0],key)}
                                break
                            }
                        }
                        if {[set type_id [lsearch -glob $attr {type_*}]]!=-1} {
                            foreach par_elem $par {
                                if {[check_type [set type_elem [string range \
                                  [lindex $attr $type_id] 5 end]] $par_elem]} {
                                    catch {lappend param_array([lindex \
                                                    $parexpect 0],value)\
                                                    $par_elem}
                                } else {
                                    puterror INCORRECT_TYPE_LIST_ELEM \
                                             "$proc [lindex $parexpect 0]" \
                                              $type_elem
                                    catch {unset param_array([lindex \
                                                             $parexpect 0],key)}
                                    break
                                }
                            }
                        } elseif {[lsearch -exact [lindex $procpar 2] dup]!=-1 ||
				  [lsearch -exact [lindex $procpar 2] junk]!=-1} {
			    set entryLength [llength $procpar]
			    list parPrepend {}
			    if {$entryLength>3} {
				set parindex [lindex $procpar 3]
				if {[string first rise [lindex $procpar 0]]!=-1} {
				    set parPrepend "rise"
				} else {
				    set parPrepend "fall"
				}
			    } else {
				set parindex [lindex $procpar 0]
				set parPrepend "both"
			    }
			    lappend parPrepend $par
                            lappend param_array($parindex,value) $parPrepend
                        } else {
                            if {[catch {set param_array([lindex \
                                                        $parexpect 0],value)\
                              [list $param_array([lindex $parexpect 0],value) \
                                    $par]}]} {
                                set param_array([lindex $parexpect 0],value) \
                                    $par
                            }
			}
                    } else {
                        puterror INCORRECT_TYPE_LIST \
                                 "$proc [lindex $parexpect 0]"
                        catch {unset param_array([lindex $parexpect 0],key)}
                    }
                }

                unknown -
                Unknown {
                    set param_array([lindex $parexpect 0],value) $par
                }

                default {
                    if {[check_type [lindex $parexpect 1] $par [lrange $parexpect 2 end]]} {
                        set param_array([lindex $parexpect 0],value) $par
                    } else {
                        puterror INCORRECT_TYPE \
                                 "$proc [lindex $parexpect 0]"
                        catch {unset param_array([lindex $parexpect 0],key)}
                    }
                }
            } ;#switch
        }
        set parexpect ""

        incr i
    } ;#while

    # check whether set of SDC-command's arguments is correct

    set cond $proccond($ver,$proc)
    foreach procpar $procdefs($ver,$proc) {
        set par [lindex $procpar 0]
        regsub -all -- "param\\\($par\\\)" $cond \
                       [info exists param_array($par,value)] cond
    }
    if {[catch {set ok [expr $cond]}]} {
        puterror USER "INTERNAL: error in expression: \"$proccond($ver,$proc)\" \
                  ($cond), ignored"
        incr errors -1
    } else {
        if {!$ok} {
            puterror INCORRECT_SET $proc
        }
    }

    # create result data structure

    set result ""
    foreach procpar $procdefs($ver,$proc) {
        if {[info exists param_array([lindex $procpar 0],value)]} {
            set data_structure([lindex $procpar 0]) \
                $param_array([lindex $procpar 0],value)
        }
    }

    # call "callback" procedure

    if {$callback!="" && !$errors} {
        return [$callback $proc data_structure]
    } else {
	if {$errors} {
	    usage $proc
	}
        return ""
    }
}

#-------------------------------------------------------------------------------
# Function       :  sdc::register_callback
# Description    :  Sets a callback
# Parameters     :  proc_name   - name of "callback" procedure (if proc_name
#                :  is empty callback will be disabled)
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::register_callback {proc_name} {
    variable callback $proc_name
}

#-------------------------------------------------------------------------------
# Function       :  sdc::set_debug_level
# Description    :  Sets the level of debug messages
# Parameters     :  level       - lovel of debug
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::set_debug_level {level} {
    variable debuglevel $level
}

#-------------------------------------------------------------------------------
# Function       :  sdc::set_version
# Description    :  sets the sdcversion for use
# Parameters     :  ver         - version number of SDC 
# Return         :  Nothing
#-------------------------------------------------------------------------------
proc sdc::set_version {ver} {
    setversion $ver
}




# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
