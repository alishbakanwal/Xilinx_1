# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
## These are general purpose utils
##

namespace eval Utils {
    namespace export postincr .. push pop unshift shift findabbr export
}

####################################################################################
# Implement i++ type functionality
#
proc Utils::postincr {valName} {
    upvar $valName v
    set tmp $v
    incr v
    return $tmp
}


####################################################################################
# Implement range operator functionality
# Usage: numRange min max {include_min 1} {include_max 1}
#    min and max are included in the range by default. Can override by passing a 0
#
proc Utils::numRange { min max {include_min 1} {include_max 1}} { 
    set f ""
    if {! $include_min} {
	incr min
    }
    
    if {! $include_max} {
	incr max -1
    }
    
    for {set i $min} {$i <= $max} {incr i} {
	lappend $f $i
    }
    return $f
}


####################################################################################
# Implement a perl type array with necessary functions NOT YET IMPLEMENTED
# newArray 
# push arrName value(s)
# pop arrName
# unshift arrName value(s)
# shift   arrName

proc Utils::newArray args {
    upvar [lindex $args 0] A
    set size 0
    foreach val [lrange $args 1 end] {
	set A($size) $val
	incr size
    }
    set A(_size) $size
}

proc Utils::push args {
    upvar [lindex $args 0] A    
    set size $A(_size)    
    foreach val [lrange $args 1 end] {
	set A([postincr size]) $val
    }
}

#proc Utils::unshift {arrayName args} {
#    puts "Not yet implemented"
#    upvar $arrayName A    
#    
#    set i 0
#    foreach v [lrange $args 1 end] {
#	set newA
#	
#	array set newA [foreach val [lrange $args 1 end] {
#	    
#	    foreach val [lrange $args 1 end]
#	    set newA([array size A]) $val
#	}
#		    }
#}

proc Utils::shift { listname } {
    upvar $listname list
    set ret [ lindex $list 0 ]
    set list [ lrange $list 1 end ]
    return $ret
}



####################################################################################
# perl like map function  (unfinished)
proc Utils::map {fun args} {
    set cmd "foreach "
    set fargs {}
    for {set i 0} {$i<[llength $args]} {incr i} {
	append cmd "$i [string map [list @ $i] {[lindex $args @]}] "
        lappend fargs $$i
    }
    append cmd [string map [list @f $fun @a [join $fargs]] {{
	lappend res [@f @a]
    }}]
    set res {}
    eval $cmd
    set res
}

####################################################################################
# Given a list and variable names, set the variables to the corresponding list 
# elements and return the remaining list elments.
#

proc Utils::extract { list args } {
    foreach arg $args {
	upvar $arg var
	set var [ shift list ]
    }
    return $list
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
proc Utils::findabbr { list val {sorted 0} {fatalIfNotUnique 1} {returnList 0} } {    

    
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
	error "Utils::findabbr : Multiple matches found for $val"
    }


    # Now do returnList thingy
    if {$returnList} {
	return $matchedVals
    } else {
	return [lindex $matchedVals 0]
    }

    error "Should not reach here"
}



proc Utils::test_findabbr args {

    set t1list "abc defo fgt fptos lkgdo"
    
    # Test if it returns the correct abbr (exact match)
    if {[set ret [findabbr $t1list "fgt"]] ne "fgt"} {
	error "Error: Expected fgt. Got $ret"
    } else {
	puts "Exact match test successfull: $ret (expecting fgt)"
    }
    
    # Multiple matches
    # Test if it returns the correct abbr (glob match)
    # fatalIfNotUnique is set to 0 here and returnList is set to 1
    set ret [findabbr $t1list "f" 0 0 1]
    # should have only two matches
    if {[llength $ret] == 2} {	
    } else {
	error "Error: Expected return to be list of 2 elements {fgt fptos}. Got $ret"
    }

    if { [lsearch -exact $ret "fptos"] > -1  && [lsearch -exact $ret "fgt"] > -1 } {
	puts "Glob match (returnList true) test successfull: $ret (expecting fptos and fgt)"
    } else {
	error "Error: Expected {fgt fptos}. Got $ret"
    }

    # Test if it returns the correct abbr (glob match)
    # fatalIfNotUnique is set to 0 here and returnList is set to 0
    set ret [findabbr $t1list "f" 0 0 0]
    # should have only one match
    if {$ret ne "fgt"} {
	error "Error: Expected fgt. Got $ret"
    } else {
	puts "Glob match (returnList false) successfull: $ret (expecting only fgt)"
    }

    ## Test if it returns the index if returnIndex is set
    #set ret [findabbr $t1list "f" 0 0 0]
    ## should have only one match
    #if {! [llength $ret] == 2} {
    #	error "Error: Expected fgt and fptos. Got $ret"
    #}
    #if { [lsearch -exact $ret "fptos"] > -1  && [lsearch -exact $ret "fgt"] > -1 } {
    #} else {
    #	error "Error: Expected fptos and fgt. Got $ret"
    #}
    #
    ## Test if it returns the index if returnIndex is set
    #set ret [findabbr $t1list "f" 1 0 0 0]
    ## should have only one match
    #if {! [llength $ret] == 2} {
    #	error "Error: Expected fptos and fgt. Got $ret"
    #}
    #if { [lsearch -exact $ret "fptos"] > -1  && [lsearch -exact $ret "fgt"] > -1 } {
    #} else {
    #	error "Error: Expected fptos and fgt. Got $ret"
    #}
    

    # Test if it croaks when multiple matches and fatalIfNotUnique
    if { [catch { findabbr $t1list "f" } ret]} {
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

    puts "All tests concluded successfully"
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
