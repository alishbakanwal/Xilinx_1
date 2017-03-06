# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************
namespace eval atop {

    set errorCnt 0

    proc skip_unknown {cmd args} {
	incr atop::errorCnt
	puts "ERROR: Un-supported command \"$cmd $args\""
    }

    proc check_list_of_numbers {numbers} {
	foreach n $numbers {
	    if {[string is double -strict $n] || [string is integer -strict $n]} {
	    } else {
		error "\"$n\" is not a valid number"
	    }
	}
    }

proc setCapTable {name rlc_model width spacing cap} {
	set num_width [llength $width]
	set num_spacing [llength $spacing]
	set num_cap [llength $cap]
	if {[expr $num_width * $num_spacing] != $num_cap} {
	    error "Incorrect size of cap table: expecting [expr $num_width * $num_spacing], but get $num_cap"
	}
	check_list_of_numbers $width
	check_list_of_numbers $spacing
	check_list_of_numbers $cap

	$rt::db setCapTable $name $rlc_model $width $spacing $cap
    }

    proc setLinearUnitRlc {rlc_model layer resistance} {
	$rt::db setLinearUnitRlc $rlc_model $layer $resistance
    }

    proc setViaResistance {rlc_model layer area_list resistance_list} {
        # puts "setViaResistance $rlc_model $layer $area_list $resistance_list
        
        if {[llength $area_list] > 0} {
          set area [lindex $area_list 0]
        } else {
          error " empty area"
        }
        if {[llength $resistance_list] > 0} {
          set resistance [lindex $resistance_list 0]
        } else {
          error " empty resistance"
        }

        $rt::db setViaResistance $rlc_model $layer $area $resistance
    }

    proc setResistanceTable {rlc_model layer thickness {res_unit "kohm_per_sq"} width_type width spacing res} {
	set num_width [llength $width]
	set num_spacing [llength $spacing]
	set num_res [llength $res]
	if {[expr $num_width * $num_spacing] != $num_res} {
	    error "Incorrect size of resistance table: expecting [expr $num_width * $num_spacing], but get $num_res"
	}
	check_list_of_numbers $width
	check_list_of_numbers $spacing
	check_list_of_numbers $res
	
	$rt::db setResistanceTable $rlc_model $layer $thickness $res_unit $width_type $width $spacing $res

    }

    proc setCapConfig {name rlc_model layer layer_below layer_above bottom_table top_table side_table} {
	$rt::db setCapConfig $name $rlc_model $layer $layer_below $layer_above $bottom_table $top_table $side_table
    }
       

    proc setRlcModel {model_name scale} {
        #puts "$rt::db setRlcModel $model_name $scale"
	$rt::db setRlcModel $model_name $scale
    }

    proc removeRlcModel {model_name} {
	$rt::db removeRlcModel $model_name
    }

    proc updateRlcModel {} {
	$rt::db updateRlcModel
    }

    proc readCapTable {file} {
        #puts "readCapTable $file"
	if [file exists $file] {
	    set cmds {set_cap_table set_linear_unit_rlc set_via_resistance set_resistance_table \
	        set_cap_config set_rlc_model remove_rlc_model update_rlc_model }
	    foreach c $cmds {
		cli::exposeCommand $c
	    }

	    if {[info proc ::unknown] != ""} {
		rename ::unknown _original_unknown
	    }
	    rename skip_unknown ::unknown
	    set atop::errorCnt 0
	    rt::source -echo false $file
	    rename ::unknown skip_unknown
	    if {[info proc _original_unknown] != ""} {
		rename _original_unknown ::unknown
	    }

	    foreach c $cmds {
		cli::hideCommand $c
	    }
	    if {$atop::errorCnt > 0} {
		error "Error: $atop::errorCnt un-supported command(s) encountered in read_captable"
	    }
	} else {
	    error "$file does not exist"
	}
    
        #puts " end readCapTable $file"
    }
}

## add ATop commands as hidden ones
cli::addHiddenCommand set_cap_table \
  {atop::setCapTable} \
    {string name} \
    {string rlc_model} \
    {string width} \
    {string spacing} \
    {string cap}
cli::addHiddenCommand set_linear_unit_rlc   \
  {atop::setLinearUnitRlc} \
    {string rlc_model} \
    {string layer} \
    {double resistance}
cli::addHiddenCommand set_via_resistance   \
  {atop::setViaResistance} \
    {string rlc_model} \
    {string layer} \
    {string area} \
    {string resistance}
cli::addHiddenCommand set_resistance_table  \
  {atop::setResistanceTable} \
    {string rlc_model} \
    {string layer} \
    {double nom_thickness} \
    {enum {kohm_per_sq ohm_per_sq} resistance_unit kohm_per_sq} \
    {string width_type} \
    {string width} \
    {string spacing} \
    {string res}
cli::addHiddenCommand set_cap_config        \
  {atop::setCapConfig} \
    {string name} \
    {string rlc_model} \
    {string layer} \
    {string layer_below} \
    {string layer_above} \
    {string bottom_table} \
    {string top_table} \
    {string side_table}
cli::addHiddenCommand set_rlc_model         {atop::setRlcModel} {string rlc_model} {double half_node_scale}
cli::addHiddenCommand remove_rlc_model      {atop::removeRlcModel} {string}
cli::addHiddenCommand update_rlc_model      {atop::updateRlcModel} 



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
