# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
proc countUnconnectedPins {} {
    set modCount 0
    set portCount 0
    set portConnected 0
    set portUnConnected 0
    set des [$rt::db topDesign]
    set ml [$des modules]
    for {set mi [$ml begin]} {[$mi ok]} {$mi incr} {
	set mod [$mi object]
	incr modCount
	set pl [$mod ports]
	for {set pi [$pl begin]} {[$pi ok]} {$pi incr} {
	    set port [$pi object]
	    incr portCount
	    set as [$port pins]
	    set connected 0
	    for {set ai [$as begin]} {[$ai count]} {$ai incr} {
		set pin [$mod pin $ai]
		if {[$pin net] != "NULL"} {
		    set connected 1
		}
	    }
	    if {$connected} {
		incr portConnected
	    } else {
		incr portUnConnected
	    }
	    $ai -delete
	    $as -delete
	    $port -delete
	}
	$pi -delete
	$pl -delete
	if {$modCount % 1000 == 0} {
	    puts "modCount    : $modCount"
	    puts "portcount   : $portCount"
	    puts "connected   : $portConnected"
	    puts "unconnected : $portUnConnected"
	}
    }
    $mi -delete
    $ml -delete
    puts "modCount    : $modCount"
    puts "portcount   : $portCount"
    puts "connected   : $portConnected"
    puts "unconnected : $portUnConnected"
}

countUnconnectedPins

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
