##############################################################################
# Copyright 2011 Xilinx Inc. All rights reserved
##############################################################################

rdi::hide_namespaces bd::utils::dbg_pause

namespace eval ::bd::utils {
  namespace export \
    dbg \
    dbgsep \
    enable_dbg \
    disable_dbg

  # Use the ::bd::utils::dbg_set_indent_char fn to set
  set dbg_indent_char "  "

  # List of regexp strings to match full name of proc to allow
  # dbg print outs. e.g. 
  # set dbg_list [list "::xilinx.com_bd_rule_axi4::*"]
  # Empty dbg list allows all to be printed.
  # Use the ::bd::utils::dbg_print_scope
  # ::bd::utils::dbg_add_scope
  # ::bd::utils::dbg_rm_scope 
  # cmds to modify
  set dbg_list {}
}


## Print out debug statements if enable_dbg was called
## Indentation of dbg statements is according to stack level.
## dbg with stack level < 3 will not be indented.
## To increase indentation size use
##   set ::bd::utils::dbg_indent_char "----"
## default is "  "
proc ::bd::utils::dbg { str {extra_indent 0} } {
  return
}

## Used to control the char used for 1 indent.
## E.g. Can be " " or "--->" etc both considered as 1 indent
proc ::bd::utils::dbg_set_indent_char { c } {
  set ::bd::utils::dbg_indent_char $c
}

## Prints the regexps that will be used to identify what
## functions will allow dbg prints 
proc ::bd::utils::dbg_print_scope {} {
  puts $::bd::utils::dbg_list
}

## Appends a scope to allow dbg to print.
## e.g. dbg_add_scope "::xilinx.com_bd_rule_axi4::*"
## To allow all procs to be prints ensure scope is empty
proc ::bd::utils::dbg_add_scope {s} {
  lappend ::bd::utils::dbg_list $s
}

proc ::bd::utils::dbg_rm_scope {s} {
  set idx [lsearch -exact $::bd::utils::dbg_list $s]
  set ::bd::utils::dbg_list [lreplace $::bd::utils::dbg_list $idx $idx]
}

# info frame 1 = rdi::main ./project.xpr
# info frame 2 = apply_bd_automation
# info frame 3 = First automation callback 
proc ::bd::utils::dbg_skip {} {
  if {[::bd::utils::not_empty $::bd::utils::dbg_list]} {
    # check if need to skip
    set f [info frame 4]
    if {[dict exists $f proc]} {
      set proc_nm [dict get $f proc]
      foreach pattern $::bd::utils::dbg_list {
        if { [string match -nocase $pattern $proc_nm] } {
          return 0
        }
      }
      return 1
    } 
  }
  return 0
}



## Do not use directly, please use dbg {} instead.
# info frame 1 = rdi::main ./project.xpr
# info frame 2 = apply_bd_automation
# info frame 3 = First automation callback
proc ::bd::utils::dbg_helper {str extra_indent} {
  if { [bd::utils::dbg_skip] } {
    return
  }
  set l [expr [info level] - 3 + $extra_indent]
  if { $l > 0} {
    set indent [join [lrepeat $l $::bd::utils::dbg_indent_char] ""]
  } else {
    set indent ""
  }

  puts "${indent}${str}"
}



## Prints out a separator if enable_dbg was called
proc ::bd::utils::dbgsep { {str ""} } {
  dbg "-------------------------------------------------------------------" -1
  if {[llength $str]} {
    dbg $str -1
  }
}

## Enables debug printing
proc ::bd::utils::enable_dbg {} {
  eval {proc ::bd::utils::dbg {str {extra_indent 0}} {dbg_helper $str $extra_indent}}
}

## Disables debug printing
proc ::bd::utils::disable_dbg {} {
  eval {proc ::bd::utils::dbg {str {extra_indent 0}} {return}}
}





# ----------------------------------------------------------------------------


##
# Give a proc name and a line number, dumps out the line of code
# plus or minus some configurable number of lines of code
# @param procname Name of the procedure
# @param line The line number to show
# @param plusminus Show plus minus number of lines, Default is 5
proc ::bd::utils::list_code {procname line {plusminus 5} } {
  set lines [split [info body $procname] "\n"]
  
  set line0 [expr $line - 1]
  set min [expr $line0 - $plusminus]
  if { $min < 0 } {set min 0}
  set max [expr $line0 + $plusminus]
  if { $max > [llength $lines]} {set max [llength $lines]}
  set dump [lrange $lines $min $max]
  set lnum [expr $min + 1]
  foreach l $dump {
    if { $lnum == $line } {
      puts "\[${lnum}\]  $l"
    } else {
      puts " ${lnum}   $l"
    }
    incr lnum	
  }
}

# Allow Tcl script to pause so user can query project or design
proc ::bd::utils::dbg_pause { } {

   set valParam [get_param -quiet bd.dbg.enablePause]
   if { $valParam eq "" } {
      return
   } elseif { $valParam == 0 } {
      return
   }

   set frame [info frame 0];
   set proc_name [dict get $frame proc]

   set bContinue 1

   while { $bContinue == 1 } {

      puts ""
      puts ""
      puts ""
      puts "Enter command expression or Q to quit:"
      set sel [gets stdin]

      if { $sel eq "Q" || $sel eq "q" || $sel eq "exit" } {
         puts ""
         puts ""
         puts "Exiting $proc_name ..."
         puts ""
         set bContinue 0

      } else {
         puts ""
         puts ""
         puts ""

         # Prevent user from calling set commands
         if { [string match *set_* $sel] == 1 || [string match *create_* $sel] == 1 } {
            puts "CRITICAL WARNING: Please do not execute set/create/modify commands while in $proc_name!" 
            puts ""

            continue
         }

         if { [catch {set results [eval $sel] } errmsg ] } {
            puts "ERROR with command expression <$sel>:"
            puts ""
            puts "$errmsg"
         } else {
            puts "Executed: $sel"
            puts "Results: $results"
         }
      }
   }
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
