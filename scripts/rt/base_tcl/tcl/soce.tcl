# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval soce {

    proc readCapTable {capfile coupling} {
	if [file exists $capfile] {
	    set cmds {set_cap_table set_resistance_table set_cap_config update_rlc_model}
	    foreach c $cmds {
		cli::exposeCommand $c
	    }
	    set ok [catch {
		set f [open $capfile r]
		while {[gets $f line]>=0} {
		    if {[regexp -nocase {LAYER M([0-9]+)} [string trim $line] \
			     layerHead layerNum]} {
			parseResTable $f $layerNum
		    } elseif {[regexp -nocase {BASIC_CAP_TABLE} $line]} {
			#puts "basic cap table found"
			parseCapTable $f $coupling
		    }
		}
		#puts "update_rlc_model"
		eval "update_rlc_model"
	    } emsg]
	    if {!$ok} {
		puts $emsg
	    }
	    foreach c $cmds {
		cli::hideCommand $c
	    }
	} else {
	    error "$capfile does not exist"
	}
    }

    proc parseResTable {fd layerNum} {
	#puts "layer $layerNum"
	if {$layerNum <= 0 || $layerNum > [$rt::db countRouteLayer]} {
	    puts "Layer $layerNum does not exist in database, ignored."
	    while {[gets $fd line]>=0} {
		if {[regexp -nocase END $line]} {
		    break
		}
	    }
	    return
	}

	set layerName [$rt::db routeLayerName $layerNum]
	set wlist {}
	set slist {}
	array set val {}
	set thickness 0.1
	set minWidth 0.0001
	while {[gets $fd line]>=0} {
	    if {[regexp -nocase -indices {RhoWidths +([0-9.])} $line rhoW start]} {
		#puts [string range $line [lindex $start 0] end]
		set wlist [string range $line [lindex $start 0] end]
	    } elseif {[regexp -nocase -indices {RhoSpacings +([0-9.])} $line rhoW start]} {
		#puts [string range $line [lindex $start 0] end]
		set slist [string range $line [lindex $start 0] end]
	    } elseif {[regexp -nocase -indices {RhoValues +([0-9.])} $line rhoW start]} {
		set vlist [string range $line [lindex $start 0] end]
		set firstLine 1
		foreach s $slist {
		    if {$firstLine} {
			set firstLine 0
		    } else {
			gets $fd vlist
		    }
		    #puts $vlist
		    set fmt ""
		    set vars ""
		    foreach w $wlist {
			set fmt [format "fmt %s" $fmt]
			set vars [format "%s val($w,$s)" $vars] 
		    }
		    set a [format "%s \"%s\" %s" "scan \$vlist" $fmt $vars]
		    regsub -all -- fmt $a "\%f" cmd
		    eval $cmd
		}
	    } elseif {[regexp -nocase -indices {Thickness +([0-9.])} $line thick start]} {
		set thickness [string range $line [lindex $start 0] end]
	    } elseif {[regexp -nocase -indices {MinWidth +([0-9.])} $line minw start]} {
		set minWidth [string range $line [lindex $start 0] end]
	    } elseif {[regexp -nocase -indices {Resistance +([0-9.])} $line res start]} {
		#alternating resistance and width values
		set rw_list [string range $line [lindex $start 0] end]
		if {[llength $rw_list]==1} {
		    lappend rw_list $minWidth
		}
		set num [expr [llength $rw_list]/2]
		set s [lindex $rw_list 1]
		lappend slist $s
		for {set i 0} {$i < $num} {incr i} {
		    set r [lindex $rw_list [expr $i*2]]
		    set w [lindex $rw_list [expr $i*2+1]]
		    lappend wlist $w
		    set val($w,$s) $r
		}
		#no need to divide by thickness since these are resistance values already
		set thickness 1
	    } elseif {[regexp -nocase END $line]} {
		set cmd "set_resistance_table -rlc_model _model "
		set cmd [format "%s\\\n\t-layer {%s} " $cmd $layerName]
		set cmd [format "%s\\\n\t-nom_thickness {%s} " $cmd $thickness]
		set cmd [format "%s\\\n\t-resistance_unit kohm_per_sq " $cmd]
		set cmd [format "%s\\\n\t-width_type drawn " $cmd]
		set cmd [format "%s\\\n\t-width { %s } " $cmd $wlist]
		set cmd [format "%s\\\n\t-spacing { %s } " $cmd $slist]
		set cmd [format "%s\\\n\t-res { " $cmd]
		foreach w $wlist {
		    foreach s $slist {
			set cmd [format "%s %.10f " $cmd [expr $val($w,$s)/$thickness/1000.0]]
		    }
		}
		set cmd [format "%s} " $cmd]
		#puts $cmd
		eval $cmd
		return
	    }
	}
    }

    proc parseCapTable {fd coupling} {
	array set wlist {}
	array set slist {}
	array set areaCap {}
	array set sideCap {}
	while {[gets $fd line]>=0} {
	    if {[regexp -nocase {M([0-9]+)} [string trim $line] layerHead layerNum]} {
		if {[array size wlist] > 0} {
		    setCapTable $layer wlist slist areaCap sideCap
		}
		set layer $layerNum
	    } elseif {[scan $line "%f %f %f %f %f %f" width space ctot cc carea cfrg]>0} {
		set areaCap($width,$space) [expr $carea/1000.0]
		set sideCap($width,$space) [expr ($cfrg+$cc*$coupling)/500.0]
		if {![info exists wlist($width)]} {
		    set wlist($width) 1
		}
		if {![info exists slist($space)]} {
		    set slist($space) 1
		}
	    } elseif {[string length [string trim $line]]==0} {
		if {[array size wlist] > 0} {
		    setCapTable $layer wlist slist areaCap sideCap
		}
	    } elseif {[regexp -nocase END $line]} {
		if {[array size wlist] > 0} {
		    setCapTable $layer wlist slist areaCap sideCap
		}
		return
	    }
	}
    }

    proc setCapTable {layerNum wl sl ac sc} {
	upvar $wl wlist
	upvar $sl slist
	upvar $ac areaCap
	upvar $sc sideCap

	if {$layerNum <= 0 || $layerNum > [$rt::db countRouteLayer]} {
	    puts "Layer $layerNum does not exist in database, ignored."
	} else {

	    set layerName [$rt::db routeLayerName $layerNum]
	    set wlist_sorted [lsort -real -increasing [array names wlist]]
	    set slist_sorted [lsort -real -increasing [array names slist]]

	    set cmd "set_cap_table -name ct_${layerName}_area \\\n\t-rlc_model _model "
	    set cmd [format "%s\\\n\t-width { %s } " $cmd $wlist_sorted]
	    set cmd [format "%s\\\n\t-spacing { %s } " $cmd $slist_sorted] 
	    set cmd [format "%s\\\n\t-cap { " $cmd]
	    foreach w $wlist_sorted {
		foreach s $slist_sorted {
		    set cmd [format "%s %.10f " $cmd $areaCap($w,$s)]
		}
	    }
	    set cmd [format "%s} " $cmd]
	    #puts $cmd
	    eval $cmd

	    set cmd "set_cap_table -name ct_${layerName}_side \\\n\t-rlc_model _model "
	    set cmd [format "%s\\\n\t-width { %s } " $cmd $wlist_sorted]
	    set cmd [format "%s\\\n\t-spacing { %s } " $cmd $slist_sorted]
	    set cmd [format "%s\\\n\t-cap { " $cmd]
	    foreach w $wlist_sorted {
		foreach s $slist_sorted {
		    set cmd [format "%s %.10f " $cmd $sideCap($w,$s)]
		}
	    }
	    set cmd [format "%s} " $cmd]
	    #puts $cmd
	    eval $cmd

	    set cmd "set_cap_config -name _config_${layerName} \\\n\t-rlc_model _model "
	    set cmd [format "%s\\\n\t-layer {%s} -layer_below {} -layer_above {} " $cmd $layerName]
	    set cmd [format "%s\\\n\t-bottom_table {} " $cmd]
	    set cmd [format "%s\\\n\t-top_table {ct_%s_area} " $cmd $layerName]
	    set cmd [format "%s\\\n\t-side_table {ct_%s_side} " $cmd $layerName]
	    #puts $cmd
	    eval $cmd
	}

	array unset wlist
	array unset slist
	array unset areaCap
	array unset sideCap
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
