################################################################
# Redefiniton of tcl list commands to work with collecitons 
################################################################
rename lassign  tcl::lassign
rename linsert  tcl::linsert
rename lrange   tcl::lrange
rename lreverse tcl::lreverse
rename lset     tcl::lset
rename lreplace tcl::lreplace
rename lsort    tcl::lsort
rename concat   tcl::concat

proc rdi::wrongnumargs {str} {
    return "wrong \# args: should be \"$str\""
}

################################################################
# The implementation of list commands for tcl collections
# return the follow codes:
#  9999: BUILTIN_ERROR:  An error when manipulation the collection
#  9998: BUILTIN_ERROR_NAC:  The argument is not a collection
#     0: TCL_OK:    Command succeded
#     1: TCL_ERROR: Some other error
#
# The list overwrites in this file, first pretend the argument
# list is a collection, but if the collection command returns
# BULTIN_ERROR_NAC then the overwrite calls the native tcl list 
# command directly.
################################################################

################################################################
# lassign
# Assign collection or list elements to variables.
# If argument list identifies a collection, then the collection
# is converted to a regular tcllist before calling tcl::lassign.
################################################################
proc rdi::xlassign {args} {
    set l [tcl::llength $args]
    if {$l<2} {
        return -code 1 \
        [rdi::wrongnumargs {lassign list varName ?varName ...?}]
    }

    # process list
    set list [tcl::lindex $args 0]
    set code [catch {rdi::col2list -list $list} tcllist]
#    puts "xlassign: code = $code, result = $tcllist"
    if {$code==0} {
      # conversion was okay
      tcl::lappend cmdarg $tcllist
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend cmdarg $list 
    } else {
      # error during conversion
      return -code error $tcllist
    }

    # process vars
    tcl::foreach var [tcl::lrange $args 1 end] {
        tcl::lappend cmdarg $var
    }

    # call builtin
    tcl::lappend cmd {tcl::lassign}
    uplevel 1 $cmd $cmdarg
}

################################################################
# linsert 
# Insert elements into a collection or a list
# If argument list identifies a collection, then the collection
# is converted to a regular tcllist before calling tcl::linsert
################################################################
proc rdi::xlinsert {args} {
    set l [tcl::llength $args]
    if {$l<3} {
        return -code 1 \
        [rdi::wrongnumargs {linsert list index element ?element ...?}]
    }

    # process list
    set list [tcl::lindex $args 0]
    set code [catch {rdi::col2list -list $list} tcllist]
#    puts "xlinsert: code = $code, result = $tcllist"
    if {$code==0} {
      # conversion okay
      tcl::lappend cmdarg $tcllist
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend cmdarg $list
    } else {
      # error during conversion
      return -code error $tcllist
    }
    
    # process index and vars
    tcl::foreach var [tcl::lrange $args 1 end] {
        tcl::lappend cmdarg $var
    }

    # call builtin
    tcl::lappend cmd {tcl::linsert}
    uplevel 1 $cmd $cmdarg
}

################################################################
# lrange
# Return one or more adjacent elements from a collection or a list
# The command operates directly on a collection
################################################################
proc rdi::xlrange {args} {
    set l [tcl::llength $args]
    if {$l!=3} {
        return -code 1 \
        [rdi::wrongnumargs {lrange list first last}]
    }

    # arguments
    set list [tcl::lindex $args 0]
    set first [tcl::lindex $args 1]
    set last [tcl::lindex $args 2]

    # commmand
    set code [catch {rdi::col_lrange -list $list -first $first -last $last} result]
#    puts "xlrange: code = $code, result = $result"
    if {$code==0} {
      # collection
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend cmd {tcl::lrange}
      tcl::lappend x $list $first $last
      set result [uplevel 1 $cmd $x]
    } else {
      # collection error
      return -code error $result
    }
    
    return $result
}

################################################################
# lreverse
# Reverse the order of a collection or a list
# The command operates directly on a collection
################################################################
proc rdi::xlreverse {args} {
    set l [tcl::llength $args]
    if {$l!=1} {
        return -code 1 \
        [rdi::wrongnumargs {lreverse list}]
    }

    set list [tcl::lindex $args 0]

    set code [catch {rdi::col_lreverse -list $list} result]
#    puts "xllength: code = $code, result = $result"
    if {$code==0} {
      # collection
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend cmd {tcl::lreverse}
      tcl::lappend x $list
      set result [uplevel 1 $cmd $x]
    } else {
      # collection error
      return -code error $result
    }

    return $result
}

################################################################
# lreplace
################################################################
proc rdi::xlreplace {args} {
    set l [tcl::llength $args]
    if {$l<3} {
        return -code 1 \
        [rdi::wrongnumargs {lreplace list first last ?element element ...?}]
    }

    # extract list
    set list [tcl::lindex $args 0]
    set first [tcl::lindex $args 1]
    set last [tcl::lindex $args 2]

    # extract args
    tcl::lappend cmdarg
    tcl::foreach var [tcl::lrange $args 3 end] {
        tcl::lappend cmdarg $var
    }
    
    # call cmd
    set code [catch {rdi::col_lreplace -list $list -first $first -last $last -value $cmdarg} result]
#    puts "xlreplace: code = $code, result = $result"
    if {$code==0} {
      # collection
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend cmd {tcl::lreplace}
      tcl::lappend x $list
      set result [uplevel 1 $cmd $x $first $last $cmdarg]
    } else {
      # collection error
      return -code error $result
    }

    return $result
}


################################################################
# lset
# Change an element in a collection or a list
# The command operates directly on a collection, but only supports
# setting exactly one element in the collection. 
################################################################
proc rdi::xlset {args} {
    set l [tcl::llength $args]
    if {$l<2} {
        return -code 1 \
        [rdi::wrongnumargs {lset listVar ?index...? value}]
    }

    # list var name
    set lvar [tcl::lindex $args 0]
    upvar 1 $lvar lv

    # check if list argumet is shared
    set copy [rdi::col_isshared lv]

    # indeces
    tcl::lappend indeces
    tcl::foreach index [tcl::lrange $args 1 end-1] {
        tcl::lappend indeces $index
    }

    # value
    set value [tcl::lindex $args end]

    # execute
    set code 9998
    if {[info exists lv]} {

      # copy collection if necessary
      set code 0
      if {$copy != 0 } {
        set code [catch {rdi::col_copy -list $lv} result]
#        puts "xlset(col_copy): code = $code, result = $result"
        if {$code==0} {
          set lv $result
        }
      }

      # try col_lset
      if {$code==0} {
        set code [catch {rdi::col_lset -list $lv -index $indeces -newvalue $value} result]
#        puts "xlset(col_lset): code = $code, result = $result"
      }
    }

    if {$code==0} {
      # collection 
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend cmd {tcl::lset}
      tcl::lappend cmd $lvar 
      tcl::lappend indeces $value
      set result [uplevel 1 $cmd $indeces]
    } else {
      # collection error
      return -code error $result
    }
    return $result
}

################################################################
# lsort
# Sort the elements of a collection or a list
# If argument list identifies a collection, then the collection
# is converted to a regular tcllist before calling tcl::lsort
################################################################
proc rdi::xlsort {args} {
    set l [tcl::llength $args]
    if {$l<1} {
        return -code 1 \
        [rdi::wrongnumargs {lsort ?options? list}]
    }

    # options
    tcl::lappend options
    tcl::foreach option [tcl::lrange $args 0 end-1] {
        tcl::lappend options $option
    }
    if {[tcl::llength $options]==0} {
        tcl::lappend options -ascii
    }

    # list
    set prelist [tcl::lindex $args end]
    set code [catch {rdi::col2list -list $prelist} tcllist]
#    puts "xlsort: code = $code, result = $tcllist"
    if {$code==0} {
      # conversion okay
      tcl::lappend list $tcllist
    } elseif {$code==9998} {
      # tcllist
      tcl::lappend list $prelist
    } else {
      # error during conversion
      return -code error $tcllist
    }

    # command
    tcl::lappend cmd {tcl::lsort}
    uplevel 1 $cmd $options $list
}

################################################################
# concat
#
# If all the arguments are lists, this has the same effect as
# concatenating them into a single list. It permits any number of
# arguments; if no args are supplied, the result is an empty string.
#
# If any argument identifies a collection, then the collections 
# are converted to a regular tcllst before calling tcl::concat
#
# Concating a list a single typed object makes tcl::concat
# lose all type information.
################################################################
proc rdi::xconcat {args} {
    set l [tcl::llength $args]
    if {$l<0} {
        return -code 1 \
        [rdi::wrongnumargs {concat ?arg arg ...?}]
    }

    tcl::lappend x
    for {set i 0} {$i < $l} {incr i} {
        set code [catch {rdi::col2list -list [tcl::lindex $args $i]} result]
        if {$code==0} {
            # collection was converted successfully
            tcl::lappend x $result
        } elseif {$code==9998} {
            # argument was not a collection
            tcl::lappend x [tcl::lindex $args $i]
        } else {
            # error converting collection to list
            return -code error $result
        }
    }

    tcl::lappend cmd {tcl::concat}
    set ret [catch {uplevel 1 $cmd $x} result]
    return -code $ret $result
}

rename rdi::xlassign  lassign
rename rdi::xlinsert  linsert
rename rdi::xlrange   lrange
rename rdi::xlreverse lreverse
rename rdi::xlreplace lreplace
rename rdi::xlset     lset
rename rdi::xlsort    lsort
rename rdi::xconcat   concat
#
################################################################



################################################################
# history.tcl --
#
# Modified from distribution history.tcl.
#
#    # RCS: @(#) $Id: history.tcl,v 1.7 2005/07/23 04:12:49 dgp Exp $
#    #
#    # Copyright (c) 1997 Sun Microsystems, Inc.
#    #
#    # See the file "license.terms" for information on usage and redistribution
#    # of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

# history --
#
#       This is the main history command.  See the man page for its interface.
#       This does argument checking and calls helper procedures in the
#       history namespace.

proc rdi::history {args} {
    set len [llength $args]
    if {$len == 0} {
        return [rdi::HistInfo]
    }
    set key [lindex $args 0]
    set options "add, change, clear, event, info, keep, nextid, or redo"
    switch -glob -- $key {
        a* { # history add

            if {$len > 3} {
                return -code error "wrong # args: should be \"history add event ?exec?\""
            }
            if {![string match $key* add]} {
                return -code error "bad option \"$key\": must be $options"
            }
            if {$len == 3} {
                set arg [lindex $args 2]
                if {! ([string match e* $arg] && [string match $arg* exec])} {
                    return -code error "bad argument \"$arg\": should be \"exec\""
                }
            }
            return [rdi::HistAdd -command [lindex $args 1] -exec [lindex $args 2]]
        }
        ch* { # history change

            if {($len > 3) || ($len < 2)} {
                return -code error "wrong # args: should be \"history change newValue ?event?\""
            }
            if {![string match $key* change]} {
                return -code error "bad option \"$key\": must be $options"
            }
            if {$len == 2} {
                set event 0
            } else {
                set event [lindex $args 2]
            }

            return [rdi::HistChange -newvalue [lindex $args 1] -event $event]
        }
        cl* { # history clear

            if {($len > 1)} {
                return -code error "wrong # args: should be \"history clear\""
            }
            if {![string match $key* clear]} {
                return -code error "bad option \"$key\": must be $options"
            }
            return [rdi::HistClear]
        }
        e* { # history event

            if {$len > 2} {
                return -code error "wrong # args: should be \"history event ?event?\""
            }
            if {![string match $key* event]} {
                return -code error "bad option \"$key\": must be $options"
            }
            if {$len == 1} {
                set event -1
            } else {
                set event [lindex $args 1]
            }
            return [rdi::HistEvent -event $event]
        }
        i* { # history info

            if {$len > 2} {
                return -code error "wrong # args: should be \"history info ?count?\""
            }
            if {![string match $key* info]} {
                return -code error "bad option \"$key\": must be $options"
            }
            if {$len == 1} {
                return [rdi::HistInfo]
            } else {
                return [rdi::HistInfo -count [lindex $args 1]]
            }
        }
        k* { # history keep

            if {$len > 2} {
                return -code error "wrong # args: should be \"history keep ?count?\""
            }
            if {$len == 1} {
                return [rdi::HistKeep]
            } else {
                set limit [lindex $args 1]
                if {[catch {expr {~$limit}}] || ($limit < 0)} {
                    return -code error "illegal keep count \"$limit\""
                }
                return [rdi::HistKeep -count $limit]
            }
        }
        n* { # history nextid

            if {$len > 1} {
                return -code error "wrong # args: should be \"history nextid\""
            }
            if {![string match $key* nextid]} {
                return -code error "bad option \"$key\": must be $options"
            }
            return [rdi::HistNextId]
        }
        r* { # history redo

            if {$len > 2} {
                return -code error "wrong # args: should be \"history redo ?event?\""
            }
            if {![string match $key* redo]} {
                return -code error "bad option \"$key\": must be $options"
            }
            if {$len == 1} {
                return [rdi::HistRedo]
            } else {
                return [rdi::HistRedo -event [lindex $args 1]]
            }
        }
        default {
            return -code error "bad option \"$key\": must be $options"
        }
    }
}


# history.tcl is auto loaded when running tclsh so during rodin
# startup it does not yet exists, but if starting from tclsh and
# loading libraries manually at the prompt then it does exist.
if {[string equal [info commands history] history]} {
    rename history tcl::history
}
rename rdi::history history
################################################################

################################################################
# rdi::source
# Redefinition of the source command to allow tracing of commands
# within a script.  Script commands are then echoed to log and
# journal file.
rename source tcl::source
rename rdi::source source
################################################################

################################################################
# rdi::catch
# Redefinition of the catch command to prevent it from masking
# ctrl-c interrupts.
rename catch tcl::catch
rename rdi::catch catch
################################################################

################################################################
# rdi::foreach
# Redefinition of the foreach command to handle collections w/o
# conversion to tcl lists
rename foreach tcl::foreach
rename rdi::foreach foreach
################################################################

################################################################
# rdi::lappend
# Redefinition of the lappend command to handle collections
rename lappend tcl::lappend
rename rdi::lappend lappend
################################################################

################################################################
# rdi::lindex
# Redefinition of the lindex command to handle collections
rename lindex tcl::lindex
rename rdi::lindex lindex
################################################################

################################################################
# rdi::llength
# Redefinition of the llength command to handle collections
rename llength tcl::llength
rename rdi::llength llength
################################################################

################################################################
# rdi::lsearch
# Redefinition of the lsearch command to handle collections
rename lsearch tcl::lsearch
rename rdi::lsearch lsearch
################################################################

################################################################
# rdi::join
# Redefinition of the join command to handle collections
rename join tcl::join
rename rdi::join join
################################################################

################################################################
# rdi::package
# CR590773
# Redefinition of the package command to prevent 'package' from
# tracing commands when sourcing.
rename package rdi::tcl::package
proc rdi::package {args} {
  # prevent source from tracing commands
  set notrace [common::get_param tcl.notrace]
  common::set_param tcl.notrace true
  
  # restore rdi::tcl::package to prevent recursive calls to rdi::package
  rename package rdi::package
  rename rdi::tcl::package package

  set code [catch {uplevel 1 package $args} result]

  # restore rdi::package
  rename package rdi::tcl::package
  rename rdi::package package

  # restore trace
  common::set_param tcl.notrace $notrace

  return -code $code $result
}
rename rdi::package package
################################################################

################################################################
# rdi::auto_load
# Redefinition of the auto_load command to prevent 'auto_load' from
# tracing commands when sourcing.
rename auto_load rdi::tcl::auto_load
proc rdi::auto_load {args} {
  # prevent source from tracing commands
  set notrace [common::get_param tcl.notrace]
  common::set_param tcl.notrace true
  
  # restore rdi::tcl::auto_load to prevent recursive calls to rdi::auto_load
  rename auto_load rdi::auto_load
  rename rdi::tcl::auto_load auto_load

  set code [catch {uplevel 1 auto_load $args} result]

  # restore rdi::auto_load
  rename auto_load rdi::tcl::auto_load
  rename rdi::auto_load auto_load

  # restore trace
  common::set_param tcl.notrace $notrace

  return -code $code $result
}
rename rdi::auto_load auto_load
################################################################

################################################################
# launch interactive shell commands (CR558445)
#
# Define procs to launch interactive shell commands in separate 
# processes.
namespace eval common {
if {[string equal $::tcl_platform(platform) "windows"]} {
  proc cmd { args } {
    rdi::warn_if_shell_cmd cmd
    eval exec [auto_execok start] cmd {*}$args &
  }
}
if {[string equal $::tcl_platform(platform) "unix"]} {
  proc xterm { args } {
    rdi::warn_if_shell_cmd xterm
    eval exec xterm {*}$args &
  }
}
}
################################################################

################################################################
# unknown
# Numeric expressions eval to themselves so braces aren't required
# around bus names like foo[2] or foo[*].
# save original unknown to rdi::tcl:: as tcl:: would match tcl::
# namespace scoped commands (e.g. C -> CopyDirectory)
rename unknown rdi::tcl::unknown
proc unknown { args } {
  set name [tcl::lindex $args 0]
  if { [tcl::llength $args] == 1 \
         && ([string is integer $name] || [string equal $name "*"]) } {
    return "\[$args\]"
  }
  if { [tcl::llength $args] == 1 \
	   && ([regexp -nocase {^(\d)+\s*(:\s*(\d)+)?} $name]) } {
    return "\[$args\]"
  }

  if { [regexp {rt::undefined} $name] } {
    puts "ERROR: the rt:: command set is not currently available."
    return 0
  }

  # auto expand command (CR576119)
  set command [info commands [tcl::lindex $args 0]*]
  if {[tcl::llength $command] == 1} {
      # found a match
      set command [lindex $command 0]
      set ret [catch {uplevel 1 [list $command {*}[tcl::lrange $args 1 end]]} result]
  } elseif {[tcl::llength $command]} {
      # more than one match
      # still call rdi::tcl::unknown in case this is an system command
      rdi::warn_if_shell_cmd {*}$args
      set ret [catch {uplevel 1 [list rdi::tcl::unknown {*}$args]} result]
      if {$ret!=0} {
          # if this was a system command and if it failed, then prepend
          # the system error to the ambiguous error. checking for system
          # comamnd is to much, just check if error is different from 
          # the standard ambiguous error (cr619468)
          set system_error ""
          if {[string first "ambiguous" $result] == -1} {
              set system_error "$result\n"
          }
          return -code error "${system_error}ambiguous command name \"$name\": [lsort $command]"
      }
  } else {
      # call rdi::tcl::unknown
      rdi::warn_if_shell_cmd {*}$args
      set ret [catch {uplevel 1 [list rdi::tcl::unknown {*}$args]} result]
  }
  return -code $ret $result
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
