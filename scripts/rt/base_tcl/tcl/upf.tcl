# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2009
#                             All rights reserved.
# ****************************************************************************
namespace eval rtupf {
    set pfcom [PFSynCom upfcomhandler $rt::db]
    #return

    set pass 0
    set debug false
    set upfScope ""
    set atIndex 1
    array set scope2Index {};# e.g. scope2Index(a/b/c) = 1
    array set net2port {}   ;# e.g. net2port(VDDn) = VDDp, net2port(a/b/c,VDDn) = VDDp (within scope a/b/c)
    array set port2net {}   ;# e.g. port2net(VDDp) = VDDn; port2net(a/b/c,VDDp) = VDDn (within same scope)
                             #      port2net(a/b/c/VDDp) = global_VDDn (global net)
    array set net2net {}    ;# e.g. net2net(a/b/c,vddn) = global_vddn

    proc descopeName {name} {
	if {[llength $rtupf::upfScope]} {
	    set res scope$rtupf::scope2index($rtupf::upfScope) 
	    set res ${res}_$name
	} else {
	    set res $name
	}
	return $res
    }

    proc descopeNet {net} {
	set res $net
	if {[llength $rtupf::upfScope] && [llength $net]} {
	    set res $rtupf::net2net($rtupf::upfScope,$net)
	}
	return $res
    }

    proc descopeObject {obj} {
	set res $obj
	if {[llength $rtupf::upfScope] & [llength $obj]} {
	    set res ""
	    foreach item $obj {
		lappend res $rtupf::upfScope/$item
	    }
	}
	return $res
    }

    proc dirName {name} {
	set res ""
	set k [string last "/" $name]
	if {$k >= 0} {
	    incr k -1
	    set res [string range $name 0 $k]
	}
	return $res
    }

    proc baseName {name} {
	set res $name
	set k [string last "/" $name]
	if {$k >= 0} {
	    incr k
	    set res [string range $name $k [string length $name]]
	}
	return $res
    }

    proc checkNoScope {cmd} {
	if {[llength $rtupf::upfScope]} {
	    puts "Error - command $cmd is not supported at lower scope $rtupf::upfScope"
	    return false
	}
	return true
    }

    set upfCmds1 {
	add_domain_elements
	add_port_state
	add_pst_state
	bind_checker
	connect_supply_net
	create_hdl2upf_vct
	create_power_domain
	create_power_switch
	create_pst
	create_supply_net
	create_supply_port
	create_upf2hdl_vct
	load_upf
	map_isolation_cell
	map_level_shifter_cell
	map_power_switch
	map_retention_cell
	merge_power_domains
	name_format
	save_upf
	set_design_top
	set_domain_supply_net
	set_isolation
	set_isolation_control
	set_level_shifter
	set_pin_related_supply
	set_retention
	set_retention_control
	set_scope
	upf_version
    }

    set upfCmds2 {
	add_domain_elements
	add_port_state
	add_power_state
	add_pst_state
	associate_supply_set
	bind_checker
	connect_logic_net
	connect_supply_net
	connect_supply_set
	create_composite_domain
	create_hdl2upf_vct
	create_logic_net
	create_logic_port
	create_power_domain
	create_power_switch
	create_pst
	create_supply_net
	create_supply_port
	create_supply_set
	create_upf2hdl_vct
	describe_state_transition
	load_simstate_behavior
	load_upf
	load_upf_protected
	map_isolation_cell
	map_level_shifter_cell
	map_power_switch
	map_retention_cell
	merge_power_domains
	name_format
	save_upf
	set_design_attributes
	set_design_top
	set_domain_supply_net
	set_isolation
	set_isolation_control
	set_level_shifter
	set_partial_on_translation
	set_pin_related_supply
	set_port_attributes
	set_power_switch
	set_retention
	set_retention_control
	set_retention_elements
	set_scope
	set_simstate_behavior
	upf_version
	use_interface_cell
    }

    set upfCmds {}

    set exportedUPFCmds {load_upf save_upf}
    set upfON false
    set upfExposed false

    proc addCommonCommands {} {
	cli::addHiddenCommand create_power_domain \
	    {rtupf::createPowerDomain} \
	    {string} \
	    {boolean simulation_only} \
	    {string elements} \
	    {string exclude_elements} \
	    {boolean include_scope} \
	    {*string supply} \
	    {string scope} \
	    {*string define_func_type} \
	    {boolean update}
    }

    proc exposeUPF {} {
	set prevState $rtupf::upfExposed

	if {$rtcpf::cpfON} {
	    UMsg_tclMessage PF 169 UPF CPF
	    return $prevState
	}

	if {!$rtupf::upfON} {
	    rtupf::addCommonCommands
	}

	if {!$rtupf::upfExposed} {
	    foreach c $rtupf::exportedUPFCmds {
		cli::hideCommand $c
	    }

	    set toolUPFVersion [rt::getParam toolUPFVersion]
	    set rtupf::upfCmds {}
	    if {$toolUPFVersion == "1.0"} {
		set rtupf::upfCmds $rtupf::upfCmds1
	    } elseif {$toolUPFVersion == "2.0"} {
		set rtupf::upfCmds $rtupf::upfCmds2
	    }
	    foreach c $rtupf::upfCmds {
		cli::exposeCommand $c
	    }
	    set rtupf::upfExposed true
	}

	if {!$rtupf::upfON} {
	    cli::exposeCommand update_voltage_regions
	    cli::exposeCommand reset_upf
	    cli::exposeCommand commit_upf
	    cli::exposeCommand set_power_state
	    set rtupf::upfON true
	}
	return $prevState
    }

    proc hideUPF {} {
	if {$rtupf::upfExposed} {
	    foreach c $rtupf::upfCmds {
		cli::hideCommand $c
	    }
	    set rtupf::upfExposed false

	    foreach c $rtupf::exportedUPFCmds {
		cli::exposeCommand $c
	    }

	}
    }

    proc writeUPF {fileNm scope version} {
	set ok true
	puts "warning: save_upf is a BETA feature only!"
	if {$scope ne ""} {
	    UMsg_tclMessage PF 154 -scope save_upf
	}

	set scopeInst "NULL"
	if {$scope ne ""} {
	    if {[catch {set scopeInst [find -inst -obj $scope]} fmsg]} {
		puts $fmsg
		set ok false
	    }
	}

	set retStat [ [rt::design] writeUpf $fileNm $scopeInst $version]
	if {$retStat < 0} {
	    set ok false
	}
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}	
    }

    proc commitUPF {} {
	rt::start_state "commit_upf"
	set ok [$rtcpf::pfcom commitPF]
	rt::stop_state "commit_upf"

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc resetUPF {} {
	set ok [$rtcpf::pfcom resetPFDb]
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc setPowerState {state} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	if {![checkNoScope set_power_state]} {
	    return -code error
	}
	set ok [$rtcpf::pfcom setPowerState $state]
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc addDomainElements {domain elements} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope add_domain_elements]} {
	    return -code error
	}

	UMsg_tclMessage PF 153 add_domain_elements
	return -code ok
    }

    proc addPortState {port states} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope add_port_state]} {
	    return -code error
	}

	set ok true
	if {$ok} {
	    set ok [$rtcpf::pfcom addPortStates $port $states]
	}
	if {$ok} {
	    return -code ok $port
	} else {
	    return -code error
	}
    }

    proc addPowerState {object states simstate legal illegal update} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope add_power_state]} {
	    return -code error
	}
	UMsg_tclMessage PF 153 add_power_state
	return -code ok
    }

    proc addPSTState {name pst state} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope add_pst_state]} {
	    return -code error
	}
	set ok true
	if {$pst == ""} {
	    UMsg_tclMessage CMD 109 -pst
	    set ok false
	}
	if {$state == ""} {
	    UMsg_tclMessage CMD 109 -state
	    set ok false
	}
	if {$ok} {
	    set ok [$rtcpf::pfcom addPSTState $name $pst $state]
	}
	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}
    }

    proc associateSupplySet {supply_set_ref handle} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	set ok true
	if {$handle == ""} {
	    UMsg_tclMessage CMD 109 -handle
	    set ok false
	}
	if {$ok} {
	    set ok [$rtcpf::pfcom associateSupplySet $supply_set_ref $handle]
	}
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc bindChecker {instance_name module elements bind_to arch ports} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 162 bind_checker
	return -code ok
	if {![checkNoScope bind_checker]} {
	    return -code error
	}
    }

    proc connectLogicNet {net_name ports} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope connect_logic_net]} {
	    return -code error
	}
	UMsg_tclMessage PF 153 connect_logic_net
	return -code ok
    }

    proc connectSupplyNet {net_name ports pg_types vct pins cells domain rail_connection} {
	global array rtupf::port2net
	global array rtupf::net2port
	global array rtupf::net2net

	if {$rtupf::pass == 1} {
	    if {[llength $rtupf::upfScope]} {
		foreach p $ports {
		    set rtupf::port2net($rtupf::upfScope,$p) $net_name
		    if {[info exists rtupf::net2port($rtupf::upfScope,$net_name)]} {
			set n2p "$rtupf::net2port($rtupf::upfScope,$net_name) $p"
		    } else {
			set n2p $p
		    }
		    set rtupf::net2port($rtupf::upfScope,$net_name) $n2p
		}
	    } else {
		foreach p $ports {
		    set rtupf::port2net($p) $net_name
		    if {[info exists rtupf::net2port($net_name)]} {
			set n2p "$rtupf::net2port($net_name) $p"
		    } else {
			set n2p $p
		    }
		    set rtupf::net2port($net_name) $n2p

		    set sp [dirName $p]
		    if {[llength $sp]} {
			if {[info exists rtupf::scope2index($sp)]} {
			    set lPort [baseName $p]
			    set lNet $rtupf::port2net($sp,$lPort)
			    set rtupf::net2net($sp,$lNet) $net_name
			}
		    }
		}
	    }

	    return -code ok 1
	}

	# pass == 2
	if {$pg_types ne ""} {
	    UMsg_tclMessage PF 154 -pg_types connect_supply_net
	}
	if {$vct ne ""} {
	    UMsg_tclMessage PF 154 -vct connect_supply_net
	}
	if {$pins ne ""} {
	    #UMsg_tclMessage PF 154 -pins connect_supply_net
	}
	if {$cells ne ""} {
	    #UMsg_tclMessage PF 154 -cells connect_supply_net
	}
	if {$domain ne ""} {
	    #UMsg_tclMessage PF 154 -domain connect_supply_net
	}
	if {$rail_connection ne ""} {
	    UMsg_tclMessage PF 154 -rail_connection connect_supply_net
	}

	set ok true
	# ignore connection in lower scope
	if {[llength $rtupf::upfScope]} {
	    return -code ok 1
	}

	# ignore hier ports
	set tPorts ""
	foreach p $ports {
	    if {![llength [dirName $p]]} {
		set tPorts "$tPorts $p"
	    }
	}
	    
	if {$ok && [llength $tPorts]} {
	    if {$rtupf::debug} {
		puts "  # connectSupplyNet $net_name $tPorts"
	    }
	    set ok [$rtupf::pfcom connectSupplyNet $net_name $tPorts ]
	}

	if {$ok && [llength $cells] && [llength $pins]} {
	    if {$rtupf::debug} {
		puts "  # connectSupplyNet <CellPins> $net_name $cells $pins"
	    }
	    foreach c $cells {
		set ok [$rtupf::pfcom connectSupplyNetCellPins $net_name $domain $c $pins ]
	    }
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}
    }

    proc connectSupplySet {set_name connects elements exclude_elements transitive} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope connect_supply_set]} {
	    return -code error
	}
	UMsg_tclMessage PF 153 connect_supply_set
	return -code ok
    }

    proc createCompositeDomain {name subdomains supplies update} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_composition_domain]} {
	    return -code error
	}
	UMsg_tclMessage PF 153 create_composite_domain
	return -code ok
    }

    proc createHdl2UpfVct {name hdl_type table} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_hdl2upf_vct]} {
	    return -code error
	}
	UMsg_tclMessage PF 162 create_hdl2upf_vct
	return -code ok
    }

    proc createLogicNet {name} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_logic_net]} {
	    return -code error
	}
	UMsg_tclMessage PF 153 create_logic_net
	return -code ok
    }

    proc createLogicPort {name direction} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_logic_port]} {
	    return -code error
	}
	set ok [$rtupf::pfcom createLogicPort $name $direction]
	return -code ok
    }

    proc createPowerDomain {name simulation_only elements exclude_elements
			    include_scope supplies scope
			    define_func_types update} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	set ok true
	if {$name == ""} {
	    UMsg_tclMessage PF 125 <name> create_power_domain
	    set ok false
	}
	if {$simulation_only} {
	    return -code ok
	}
	if {$exclude_elements ne ""} {
	    # we don't want to support this at all
	    UMsg_tclMessage PF 154 -exclude_elements create_power_domain
	    set ok false
	}
	if {$scope ne ""} {
	    UMsg_tclMessage PF 154 -scope create_power_domain
	}
	if {$define_func_types ne ""} {
	    UMsg_tclMessage PF 154 -define_func_type create_power_domain
	}

	if {$rtupf::upfScope ne ""} {
	    set name [descopeName $name]

	    set tmp ""
	    foreach e $elements {
		set tmp "$tmp $rtupf::upfScope/$e"
	    }
	    set elements $tmp
	    if {$include_scope} {
		set elements "$rtupf::upfScope"
		set include_scope false
	    } 
	}

	if {$ok} {

	    if {$rtupf::debug} {
		puts "  # createPowerDomain $name $elements $include_scope $supplies $scope $define_func_types $update"
	    }

	    set ok [$rtupf::pfcom createPowerDomain $name $elements $include_scope $supplies $scope $define_func_types $update]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createPowerSwitch {name output_supply_port
			    input_supply_ports
			    control_ports
			    on_states
			    off_states
			    supply_set
			    on_partial_states
			    ack_ports
			    ack_delays
			    error_states
			    domain} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_power_switch]} {
	    return -code error
	}
	set ok true
	if {$name == ""} {
	    UMsg_tclMessage PF 125 name create_power_switch
	    set ok false
	}
	if {$output_supply_port == ""} {
	    UMsg_tclMessage CMD 109 -output_supply_port
	    set ok false
	}
	if {$input_supply_ports == ""} {
	    UMsg_tclMessage CMD 109 -input_supply_port
	    set ok false
	}
	if {$control_ports == ""} {
	    UMsg_tclMessage CMD 109 -control_port
	    set ok false
	}
	if {$on_states == ""} {
	    UMsg_tclMessage CMD 109 -on_state
	    set ok false
	}
	if {$ok} {
	    set ok [$rtupf::pfcom createPowerSwitch $name $output_supply_port \
		       $input_supply_ports $control_ports $ack_ports $ack_delays \
		       $on_states $off_states $on_partial_states $error_states \
		       $supply_set $domain ]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createPST {name supplies} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_pst]} {
	    return -code error
	}
	set ok true
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 name
	    set ok false
	}
	if {$supplies == ""} {
	    UMsg_tclMessage CMD 109 -supplies
	    set ok false
	}

	if {$ok} {
	    set ok [$rtupf::pfcom createPST $name $supplies]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
	return -code ok
    }

    proc createSupplyNet {name domain reuse resolve} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	set ok true
	if {$resolve ne "unresolved"} {
	    UMsg_tclMessage PF 154 -resolve create_supply_net
	}

	if {$reuse} {
	    if {$domain == ""} {
		UMsg_tclMessage CMD 107 -reuse -domain
		set ok false
	    }
	}

	set gDomain [descopeName $domain]
	set gNet [descopeNet $name]
	if {[llength $rtupf::upfScope]} {
	    set reuse true
	}

	if {$ok} {
	    if {$rtupf::debug} {
		puts "  # createSupplyNet $gNet $gDomain $reuse $resolve"
	    }
	    set ok [$rtupf::pfcom createSupplyNet $gNet $gDomain $reuse $resolve]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createSupplyPort {name domain direction} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	set ok true
	if {![llength $rtupf::upfScope]} {
	    set ok [$rtupf::pfcom createSupplyPort $name $domain $direction]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createSupplySet {name functions reference_gnd update} {
	# functions is a list, for multiple strings
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	set ok true
	if {$reference_gnd ne ""} {
	    UMsg_tclMessage PF 154 -reference_gnd create_supply_set
	}

	if {$ok} {
	    set ok [$rtupf::pfcom createSupplySet $name $functions $reference_gnd $update]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createUpf2HdlVct {name hdl_type table} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope create_upf2hdl_vct]} {
	    return -code error
	}
	UMsg_tclMessage PF 162 create_upf2hdl_vct
	return -code ok
    }

    proc describeStateTransition {name object from to paired legal illegal} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope describe_state_transition]} {
	    return -code error
	}
	UMsg_tclMessage PF 162 describe_state_transition
	return -code ok
    }

    proc loadSimstateBehavior {lib_name files} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {![checkNoScope load_simulator_behavior]} {
	    return -code error
	}
	UMsg_tclMessage PF 162 load_simstate_behavior
	return -code ok
    }

    proc loadUpf {upfFile scope version debug} {
	if {$rtcpf::cpfON} {
	    UMsg_tclMessage PF 169 UPF CPF
	    return -code error
	}
	set des [$rt::db topDesign]
	if {$des != "NULL"} {
	    UMsg_tclMessage PF 215
	    return -code error
	}

	if {$scope ne ""} {
	    UMsg_tclMessage PF 154 -scope load_upf
	}
	if {$version ne ""} {
	    UMsg_tclMessage PF 154 -version load_upf
	}
	set file [rt::searchPath $upfFile]
	if [file exists $file] {
	    set prevExposed [rtupf::exposeUPF]

	    if {$rtupf::pass == 0} {
		set rtupf::debug $debug
		set rtupf::pass 1
		set rtupf::upfScope ""
		if {[catch {uplevel 2 source $file} emsg]} {
		    puts $emsg
		}
		set rtupf::pass 2
		set rtupf::upfScope ""
		if {[catch {uplevel 2 source $file} emsg]} {
		    puts $emsg
		}
		set rtupf::pass 0
		set rtupf::debug false
	    } else {
		if {[catch {uplevel 2 source $file} emsg]} {
		    puts $emsg
		}
	    }

	    if {$prevExposed == false} {
		rtupf::hideUPF
	    }
	} else {
	    error "$file does not exist"
	}
	return -code ok
    }

    proc loadUpfProtected {name hide_globals scope version params} {
	UMsg_tclMessage PF 153 load_upf_protected
	return -code ok
    }

    proc mapIsolationCell {name domain elements lib_cells lib_cell_type lib_model_name} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 map_isolation_cell
	return -code ok
    }

    proc mapLevelShifterCell {name domain lib_cells elements} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 map_level_shifter_cell
	return -code ok
    }

    proc mapPowerSwitch {name domain lib_cells port_map} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 163 map_power_switch
	return -code ok
    }

    proc mapRetentionCell {name domain elements exclude_elements lib_cells
			   lib_cell_type lib_model_name} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 map_retention_cell
	return -code ok
    }

    proc mergePowerDomains {name power_domains scope all_equivalents} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 merge_power_domains
	return -code ok
    }

    proc nameFormat {isolation_prefix isolation_suffix
		     level_shift_prefix
		     implicit_supply_suffix
		     implicit_logic_prefix
		     implicit_logic_suffix} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	if {$implicit_supply_suffix ne ""} {
	    UMsg_tclMessage PF 154 -implicit_supply_suffix name_format
	}
	if {$implicit_logic_prefix ne ""} {
	    UMsg_tclMessage PF 154 -implicit_logic_prefix name_format
	}
	if {$implicit_logic_suffix ne ""} {
	    UMsg_tclMessage PF 154 -implicit_logic_suffix name_format
	}

	if {$isolation_prefix ne ""} {
	    UParam_set UPFIsolationPrefix $isolation_prefix true
	}
	if {$isolation_suffix ne ""} {
	    UParam_set UPFIsolationSuffix $isolation_suffix true
	}
	if {$level_shift_prefix ne ""} {
	    UParam_set UPFLevelShiftPrefix $level_shift_prefix true
	}
	return -code ok
    }

    proc saveUpf {filename scope version} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	if {$version eq ""} {
	    set version "1.0"
	}
	return [rtupf::writeUPF $filename $scope $version]
    }

    proc setDesignAttributes {elements models exclude_elements attribute} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 set_design_attributes
	return -code ok
    }

    proc setDesignTop {name} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 set_design_top
	return -code ok		
    }

    proc setDomainSupplyNet {domain primary_power_net primary_ground_net} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	set ok true
	if {$primary_power_net ne "" &&
	    $primary_ground_net ne ""} {

	    set gDomain [descopeName $domain] 
	    set gPowerNet [descopeNet $primary_power_net]
	    set gGroundNet [descopeNet $primary_ground_net]
	    
	    # error checking only
	    if {$rtupf::debug} {
		puts "  # setDomainSupplyNet $gDomain $gPowerNet $gGroundNet"
	    }
	    set ok [$rtupf::pfcom setDomainSupplyNet $gDomain $gPowerNet $gGroundNet]

	    if {$ok} {
		set tmp $rtupf::upfScope
		set rtupf::upfScope ""

		# should always succeed from here on
		set subCmd "create_supply_set ${gDomain}_primary -function \{power $gPowerNet\} -function \{ground $gGroundNet\}"
		if {[catch {uplevel 2 $subCmd} emsg]} {
		    puts $emsg
		    set ok false
		} else {
		    set subCmd "associate_supply_set ${gDomain}_primary -handle ${gDomain}.primary"
		    if {[catch {uplevel 2 $subCmd} emsg]} {
			puts $emsg
			set ok false
		    }
		}
		#restore scope
		set rtupf::upfScope $tmp
	    }
	} else {
	    if {$primary_power_net == ""} {
		UMsg_tclMessage CMD 109 -primary_power_net
	    }
	    if {$primary_ground_net == ""} {
		UMsg_tclMessage CMD 109 -primary_ground_net
	    }
	    set ok false
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}		
    }

    proc setIsolation {name domain elements src sink
		       applies_to applies_to_clamp
		       applies_to_sink_off_clamp applies_to_source_off_clamp
		       isolation_power_net isolation_ground_net
		       no_isolation
		       isolation_supply_set
		       isolation_signal isolation_sense
		       name_prefix name_suffix
		       clamp_value
		       sink_off_clamp source_off_clamp
		       location
		       force_isolation
		       instance
		       diff_supply_only
		       transitive
		       update} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	if {$src ne ""} {
	    UMsg_tclMessage PF 154 -source set_isolation
	}
	if {$sink ne ""} {
	    UMsg_tclMessage PF 154 -sink set_isolation
	}
	if {$applies_to_clamp ne ""} {
	    UMsg_tclMessage PF 154 -applies_to_clamp set_isolation
	}
	if {$applies_to_sink_off_clamp ne ""} {
	    UMsg_tclMessage PF 154 -applies_to_sink_off_clamp set_isolation
	}
	if {$applies_to_source_off_clamp ne ""} {
	    UMsg_tclMessage PF 154 -applies_to_source_off_clamp set_isolation
	}
	if {$sink_off_clamp ne ""} {
	    UMsg_tclMessage PF 154 -sink_off_clamp set_isolation
	}
	if {$source_off_clamp ne ""} {
	    UMsg_tclMessage PF 154 -source_off_clamp set_isolation
	}
	if {$force_isolation} {
	    UMsg_tclMessage PF 154 -force_isolation set_isolation
	}
	if {$instance ne ""} {
	    UMsg_tclMessage PF 154 -instance set_isolation
	}
	if {$diff_supply_only} {
	    UMsg_tclMessage PF 154 -diff_supply_only set_isolation
	}
	if {!$transitive} {
	    UMsg_tclMessage PF 154 -transitive set_isolation
	}

	set ok true
	# check require options
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 name
	    set ok false
	}

	if {$domain == ""} {
	    UMsg_tclMessage CMD 109 -domain
	    set ok false
	}

	if {$name_prefix eq ""} {
	    set name_prefix [rt::getParam UPFIsolationPrefix] 
	}
	if {$name_suffix eq ""} {
	    set name_suffix [rt::getParam UPFIsolationSuffix] 
	}

	set gDomain [descopeName $domain]
	set gName   [descopeName $name]

	set gPowerNet  [descopeNet $isolation_power_net]
	set gGroundNet [descopeNet $isolation_ground_net]

	set gIsolationSignal [descopeObject $isolation_signal]
	set gElements        [descopeObject $elements]

	if {$ok} {
	    if {$rtupf::debug} {
		puts "  # setIsolation $gName $gDomain $gElements $gPowerNet $gGroundNet $gIsolationSignal"
	    }
	    
	    set ok [$rtupf::pfcom setIsolation $gName $gDomain $gElements \
			$applies_to $no_isolation \
			$gPowerNet $gGroundNet \
			$isolation_supply_set \
			$gIsolationSignal $isolation_sense \
			$clamp_value $location \
			$name_prefix $name_suffix \
			$update ]
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}	
    }

    proc setIsolationControl {name domain 
			      isolation_signal isolation_sense
			      location} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	set ok true
	# check require options
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 name
	    set ok false
	}

	if {$domain == ""} {
	    UMsg_tclMessage CMD 109 -domain
	    set ok false
	}

	if {$isolation_signal == ""} {
	    UMsg_tclMessage CMD 109 -isolation_signal
	    set ok false
	}

	set gDomain [descopeName $domain]
	set gName   [descopeName $name]
	set gIsolationSignal [descopeObject $isolation_signal]

	if {$ok} {
	    if {$rtupf::debug} {
		puts "  # setIsolationControl $gName $gDomain $gIsolationSignal"
	    }
	    set ok [$rtupf::pfcom setIsolationControl $gName $gDomain \
			$gIsolationSignal $isolation_sense \
			$location ]
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}
    }

    proc setLevelShifter {name domain elements 
			  no_shift threshold force_shift
			  src sink
			  applies_to
			  rule
			  location
			  name_prefix name_suffix
			  input_supply_set output_supply_set
			  internal_supply_set
			  instance
			  transitive
			  update} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	# pass == 2
	if {$threshold ne ""} {
	    UMsg_tclMessage PF 154 -threshold set_level_shifter
	}
	if {$force_shift} {
	    UMsg_tclMessage PF 154 -force_shift set_level_shifter
	}
	if {$src ne ""} {
	    UMsg_tclMessage PF 154 -source set_level_shifter
	}
	if {$sink ne ""} {
	    UMsg_tclMessage PF 154 -sink set_level_shifter
	}
	if {$input_supply_set ne ""} {
	    UMsg_tclMessage PF 154 -input_supply_set set_level_shifter
	}
	if {$output_supply_set ne ""} {
	    UMsg_tclMessage PF 154 -output_supply_set set_level_shifter
	}
	if {$internal_supply_set ne ""} {
	    UMsg_tclMessage PF 154 -internal_supply_set set_level_shifter
	}
	if {$instance ne ""} {
	    UMsg_tclMessage PF 154 -instance set_level_shifter
	}
	if {!$transitive} {
	    UMsg_tclMessage PF 154 -transitive set_level_shifter
	}

	set ok true
	# check require options
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 name
	    set ok false
	}

	if {$domain == ""} {
	    UMsg_tclMessage CMD 109 -domain
	    set ok false
	}

	if {$name_prefix eq ""} {
	    set name_prefix [rt::getParam UPFLevelShiftPrefix]
	}

	set gName [descopeName $name]
	set gDomain [descopeName $domain]
	set gElements [descopeObject $elements]

	if {$ok} {
	    if {$rtupf::debug} {
		puts "  # setLevelShifter $gName $gDomain $gElements"
	    }
	    set ok [$rtupf::pfcom setLevelShifter $gName $gDomain $gElements \
			$applies_to \
			$no_shift \
			$rule $location \
			$name_prefix $name_suffix \
			$update ]
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}
    }

    proc setPartialOnTranslation {translation full_on_tools off_tools} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 162 set_partial_on_translation
	return -code ok		
    }

    proc setPinRelatedSupply {libcell pins related_power_pin related_ground_pin} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 set_pin_related_supply
	return -code ok		
    }

    proc setPortAttributes {ports exclude_ports domains applies_to
			    elements exclude_elements
			    model
			    attributes
			    clamp_value
			    sinl_off_clamp source_off_clamp
			    receiver_supply driver_supply
			    related_power_port related_ground_port
			    related_bias_ports
			    repeater_supply
			    pg_type
			    transitive} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 153 set_port_attributes
	return -code ok		
    }

    proc setPowerSwitch {switchname
			 output_supply_port
			 input_supply_ports
			 control_ports
			 on_states
			 supply_set
			 on_partial_states
			 off_states
			 error_states} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}
	UMsg_tclMessage PF 163 set_power_switch
	return -code ok		
    }

    proc setRetention {name
		       domain elements exclude_elements
		       retention_power_net retention_ground_net
		       retention_supply_set
		       no_retention
		       save_signal restore_signal
		       save_condition restore_condition
		       retention_condition
		       use_retention_as_primary
		       parameters
		       instance
		       transitive update} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	if {![checkNoScope set_retention]} {
	    return -code error
	}
	set ok true
	if {$no_retention} {
	    UMsg_tclMessage PF 154 -no_retention set_retention
	}

	if {$use_retention_as_primary} {
	    UMsg_tclMessage PF 154 -use_retention_as_primary set_retention
	}
	if {$parameters ne ""} {
	    UMsg_tclMessage PF 154 -parameters set_retention
	}
	if {$instance ne ""} {
	    UMsg_tclMessage PF 154 -instance set_retention
	}
	if {!$transitive} {
	    UMsg_tclMessage PF 154 -transitive set_retention
	}

	# required options
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 <name>
	    set ok false
	}
	if {$domain == ""} {
	    UMsg_tclMessage CMD 109 -domain
	    set ok false
	}

	# invalid combinations
	if {$retention_supply_set ne "" && $retention_power_net ne ""} {
	    UMsg_tclMessage CMD 100 -retention_supply_set -retention_power_net
	    set ok false
	}
	if {$retention_supply_set ne "" && $retention_ground_net ne ""} {
	    UMsg_tclMessage CMD 100 -retention_supply_set -retention_ground_net
	    set ok false
	}

	# missing related options
	if {$save_signal ne "" && $restore_signal eq ""} {
	    UMsg_tclMessage CMD 107 -save_signal -restore_signal
	    set ok false
	}
	if {$restore_signal ne "" && $save_signal eq ""} {
	    UMsg_tclMessage CMD 107 -restore_signal -save_signal
	    set ok false
	}

	if {$ok} {
	    set ok [$rtupf::pfcom setRetention $name  $domain $elements $exclude_elements \
			$retention_power_net $retention_ground_net \
			$retention_supply_set \
			$save_signal $restore_signal \
			$save_condition $restore_condition \
			$update ]
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}
    }

    proc setRetentionControl {name domain 
			      save_signal restore_signal
			      assert_r_mutex assert_s_mutex assert_rs_mutex} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	set ok true
	if {$assert_r_mutex ne ""} {
	    UMsg_tclMessage PF 154 -assert_r_mutex set_retention_control
	}
	if {$assert_s_mutex ne ""} {
	    UMsg_tclMessage PF 154 -assert_s_mutex set_retention_control
	}
	if {$assert_rs_mutex ne ""} {
	    UMsg_tclMessage PF 154 -assert_rs_mutex set_retention_control
	}

	# required options
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 <name>
	    set ok false
	}
	if {$domain == ""} {
	    UMsg_tclMessage CMD 109 -domain
	    set ok false
	}

	if {$save_signal == ""} {
	    UMsg_tclMessage CMD 109 -save_signal
	    set ok false
	}
	if {$restore_signal == ""} {
	    UMsg_tclMessage CMD 109 -restore_signal
	    set ok false
	}

	if {$ok} {
	    set ok [$rtupf::pfcom setRetentionControl $name $domain \
			$save_signal $restore_signal ]
	}

	if {$ok} {
	    return -code ok 1
	} else {
	    return -code error
	}
    }

    proc setRetentionElements {name elements applies_to
			       exclude_elements
			       retention_purpose
			       transitive} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	UMsg_tclMessage PF 153 set_retention_elements
	return -code ok		
    }

    proc setScope {instance} {
	#UMsg_tclMessage PF 153 set_scope
	global array rtupf::scope2index

	if {$instance eq "."} {
	    return -code ok
	}

	if {$instance eq "" || $instance eq "/"} {
	    set rtupf::upfScope ""
	} elseif {$instance eq ".."} {
	    if {$rtupf::upfScope eq ""} {
		puts "Error - can not change scope to '$instance' with current scope of $rtupf::upfScope"
		return -code error
	    } else {
		set rtupf::upfScope [dirName $rtupf::upfScope]
	    }
	} else {
	    if {$rtupf::upfScope eq ""} {
		set instance [string trimleft $instance "/"]
		set rtupf::upfScope $instance
	    } else {
		# TBD - support for setting lower scope within lower scope
		puts "Error: Unsupported 'set_scope $instance' with current scope at '$rtupf::upfScope'"
		return -code error
	    }
	}
	    
	if {$rtupf::pass == 1} {
	    if {[llength $rtupf::upfScope] && 
		![info exists rtupf::scope2index($rtupf::upfScope)]} {
		set rtupf::scope2index($rtupf::upfScope) "$rtupf::atIndex"
		incr rtupf::atIndex
	    }
	}
	return -code ok		
    }

    proc setSimstateBehavior {enableDisable lib model} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	UMsg_tclMessage PF 162 set_simstate_behavior
	return -code ok		
    }

    proc upfVersion {version} {
	if {$version ne ""} {
	    UMsg_tclMessage PF 154 <version> upf_version
	}
	set toolUPFVersion [rt::getParam toolUPFVersion]
	return -code ok	$toolUPFVersion
    }

    proc useInterfaceCell {name strategy domain lib_cells map
			   elements exclude_elements
			   applies_to_clamp
			   update_any
			   force_function
			   inverter_supply_set} {
	if {$rtupf::pass == 1} {
	    return -code ok
	}

	UMsg_tclMessage PF 153 use_interface_cell
	return -code ok		
    }
}

cli::addHiddenCommand commit_upf \
    {rtupf::commitUPF}

cli::addHiddenCommand reset_upf \
    {rtupf::resetUPF}

cli::addHiddenCommand set_power_state \
    {rtupf::setPowerState} {string}

cli::addHiddenCommand add_domain_elements \
    {rtupf::addDomainElements} \
    {string} \
    {string elements}

cli::addHiddenCommand add_port_state \
    {rtupf::addPortState} \
    {string} \
    {*string state}

cli::addHiddenCommand add_power_state \
    {rtupf::addPowerState} \
    {string} \
    {*string state} \
    {string simstate} \
    {boolean legal} \
    {boolean illegal} \
    {boolean update}

cli::addHiddenCommand add_pst_state \
    {rtupf::addPSTState} \
    {string} \
    {string pst} \
    {string state}

cli::addHiddenCommand associate_supply_set \
    {rtupf::associateSupplySet} \
    {string} \
    {string handle}

cli::addHiddenCommand bind_checker \
    {rtupf::bindChecker} \
    {string} \
    {string module} \
    {string elements} \
    {string bind_to} \
    {string arch} \
    {string ports}

cli::addHiddenCommand connect_logic_net \
    {rtupf::connectLogicNet} \
    {string} \
    {string ports}

cli::addHiddenCommand connect_supply_net \
    {rtupf::connectSupplyNet} \
    {string} \
    {string ports} \
    {*string pg_type} \
    {string vct} \
    {string pins} \
    {string cells} \
    {string domain} \
    {string rail_connection}

cli::addHiddenCommand connect_supply_set \
    {rtupf::connectSupplyNet} \
    {string} \
    {*string connect} \
    {string elements} \
    {string exclude_elements} \
    {enum {TRUE FALSE} transitive TRUE}

cli::addHiddenCommand create_composite_domain \
    {rtupf::createCompositeDomain} \
    {string} \
    {string subdomains} \
    {*string supply} \
    {boolean update}

cli::addHiddenCommand create_hdl2upf_vct \
    {rtupf::createHdl2UpfVct} \
    {string} \
    {string hdl_type} \
    {string table}

cli::addHiddenCommand create_logic_net \
    {rtupf::createLogicNet} \
    {string}

cli::addHiddenCommand create_logic_port \
    {rtupf::createLogicPort} \
    {string} \
    {enum {in out inout} direction in}

cli::addHiddenCommand create_power_switch \
    {rtupf::createPowerSwitch} \
    {?string} \
    {string output_supply_port} \
    {*string input_supply_port} \
    {*string control_port} \
    {*string on_state} \
    {*string off_state} \
    {string supply_set} \
    {*string on_partial_state} \
    {*string ack_port} \
    {*string ack_delay} \
    {*string error_state} \
    {string domain}

cli::addHiddenCommand create_pst \
    {rtupf::createPST} \
    {?string} \
    {string supplies}

cli::addHiddenCommand create_supply_net \
    {rtupf::createSupplyNet} \
    {string} \
    {string domain} \
    {boolean reuse} \
    {enum {unresolved one_hot parallel parallel_one_hot} resolve unresolved}

cli::addHiddenCommand create_supply_port \
    {rtupf::createSupplyPort} \
    {string} \
    {string domain} \
    {enum {in out inout} direction in}

cli::addHiddenCommand create_supply_set \
    {rtupf::createSupplySet} \
    {string} \
    {*string function} \
    {string reference_gnd} \
    {boolean update}

cli::addHiddenCommand create_upf2hdl_vct \
    {rtupf::createUpf2HdlVct} \
    {string} \
    {string hdl_type} \
    {string table}

cli::addHiddenCommand describe_state_transition \
    {rtupf::describeStateTransition} \
    {string} \
    {string object} \
    {string from} \
    {string to} \
    {string paired} \
    {boolean legal} \
    {boolean illegal}

cli::addHiddenCommand load_simstate_behavior \
    {rtupf::loadSimstateBehavior} \
    {string} \
    {string file}

cli::addCommand load_upf \
    {rtupf::loadUpf} \
    {string} \
    {string scope} \
    {string version} \
    {#boolean debug}

cli::addHiddenCommand load_upf_protected \
    {rtupf::loadUpfProtected} \
    {string} \
    {boolean hide_globals} \
    {string scope} \
    {string version} \
    {string params}

cli::addHiddenCommand map_isolation_cell \
    {rtupf::mapIsolationCell} \
    {string} \
    {string domain} \
    {string elements} \
    {string lib_cells} \
    {string lib_cell_type} \
    {string lib_model_name}

cli::addHiddenCommand map_level_shifter_cell \
    {rtupf::mapLevelShifterCell} \
    {string} \
    {string domain} \
    {string lib_cells} \
    {string elements}

cli::addHiddenCommand map_power_switch \
    {rtupf::mapPowerSwitch} \
    {string} \
    {string domain} \
    {string lib_cells} \
    {string port_map}

cli::addHiddenCommand map_retention_cell \
    {rtupf::mapRetentionCell} \
    {string} \
    {string domain} \
    {string elements} \
    {string exclude_elements} \
    {string lib_cells} \
    {string lib_cell_type} \
    {string lib_model_name}

cli::addHiddenCommand merge_power_domains \
    {rtupf::mergePowerDomains} \
    {string} \
    {string power_domains} \
    {string scope} \
    {boolean all_equivalent}

cli::addHiddenCommand name_format \
    {rtupf::nameFormat} \
    {string isolation_prefix} \
    {string isolation_suffix} \
    {string level_shift_prefix} \
    {string implicit_supply_suffix} \
    {string implicit_logic_prefix} \
    {string implicit_logic_suffix}

cli::addCommand save_upf \
    {rtupf::saveUpf} \
    {string} \
    {string scope} \
    {string version} 

cli::addHiddenCommand set_design_attributes \
    {rtupf::setDesignAttributes} \
    {string elements} \
    {string models} \
    {string exclude_elements} \
    {string attribute}

cli::addHiddenCommand set_design_top \
    {rtupf::setDesignTop} \
    {string}

cli::addHiddenCommand set_domain_supply_net \
    {rtupf::setDomainSupplyNet} \
    {string} \
    {string primary_power_net} \
    {string primary_ground_net}

cli::addHiddenCommand set_isolation \
    {rtupf::setIsolation} \
    {?string} \
    {string domain} \
    {string elements} \
    {string source} \
    {string sink} \
    {enum {inputs outputs both} applies_to outputs} \
    {string applies_to_clamp} \
    {string applies_to_sink_off_clamp} \
    {string applies_to_source_off_clamp} \
    {string isolation_power_net} \
    {string isolation_ground_net} \
    {boolean no_isolation} \
    {string isolation_supply_set} \
    {string isolation_signal} \
    {enum {high low} isolation_sense high} \
    {string name_prefix} \
    {string name_suffix} \
    {enum {0 1 any z latch} clamp_value any} \
    {string sink_off_clamp} \
    {string source_off_clamp} \
    {enum {automatic self other fanout fanin faninout parent sibling} location self} \
    {boolean force_isolation} \
    {string instance} \
    {enum {TRUE FALSE} diff_supply_only FALSE} \
    {enum {TRUE FALSE} transitive TRUE} \
    {boolean update}

cli::addHiddenCommand set_isolation_control \
    {rtupf::setIsolationControl} \
    {?string} \
    {string domain} \
    {string isolation_signal} \
    {enum {high low} isolation_sense high} \
    {enum {self parent sibling fanout automatic} location automatic} \

cli::addHiddenCommand set_level_shifter \
    {rtupf::setLevelShifter} \
    {?string} \
    {string domain} \
    {string elements} \
    {boolean no_shift} \
    {double threshold} \
    {boolean force_shift} \
    {string source} \
    {string sink} \
    {enum {inputs outputs both} applies_to outputs} \
    {enum {low_to_high high_to_low both} rule both} \
    {enum {automatic self other fanout fanin faninout parent sibling} location automatic} \
    {string name_prefix} \
    {string name_suffix} \
    {string input_supply_set} \
    {string output_supply_set} \
    {string internal_supply_set} \
    {string instance} \
    {enum {TRUE FALSE} transitive TRUE} \
    {boolean update}

cli::addHiddenCommand set_partial_on_translation \
    {rtupf::setPartialOnTranslation} \
    {string} \
    {string full_on_tools} \
    {string off_tools}

cli::addHiddenCommand set_pin_related_supply \
    {rtupf::setPinRelatedSupply} \
    {string} \
    {string pins} \
    {string related_power_pin} \
    {string related_ground_pin}

cli::addHiddenCommand set_port_attributes \
    {rtupf::setPortAttributes} \
    {string ports} \
    {string exclude_ports} \
    {string domains} \
    {enum {inputs outputs both} applies_to both} \
    {string exclude_domains} \
    {string elements} \
    {string exclude_elements} \
    {string model} \
    {*string attribute} \
    {string clamp_value} \
    {string sink_off_clamp} \
    {string source_off_clamp} \
    {string receiver_supply} \
    {string driver_supply} \
    {string related_power_port} \
    {string related_ground_port} \
    {string related_bias_ports} \
    {string repeater_supply} \
    {string pg_type} \
    {enum {TRUE FALSE} transitive TRUE}

cli::addHiddenCommand set_power_switch \
    {rtupf::setPowerSwitch} \
    {string} \
    {string output_supply_port} \
    {*string input_supply_port} \
    {*string control_port} \
    {*string on_state} \
    {string supply_set} \
    {*string on_partial_state} \
    {*string off_state} \
    {*string error_state}

cli::addHiddenCommand set_retention \
    {rtupf::setRetention} \
    {?string} \
    {string domain} \
    {string elements} \
    {string exclude_elements} \
    {string retention_power_net} \
    {string retention_ground_net} \
    {string retention_supply_set} \
    {boolean no_retention} \
    {string save_signal} \
    {string restore_signal} \
    {string save_condition} \
    {string restore_condition} \
    {string retention_condition} \
    {boolean use_retention_as_primary} \
    {string parameters} \
    {*string instance} \
    {enum {TRUE FALSE} transitive TRUE} \
    {boolean update}

cli::addHiddenCommand set_retention_control \
    {rtupf::setRetentionControl} \
    {string} \
    {string domain} \
    {string save_signal} \
    {string restore_signal} \
    {*string assert_r_mutex} \
    {*string assert_s_mutex} \
    {*string assert_rs_mutex}

cli::addHiddenCommand set_retention_elements \
    {rtupf::setRetentionElements} \
    {string} \
    {string elements} \
    {enum {required not_optional not_required optional} applies_to required} \
    {string exclude_elements} \
    {enum {required optional} retention_purpose required} \
    {enum {TRUE FALSE} transitive TRUE}

cli::addHiddenCommand set_scope \
    {rtupf::setScope} \
    {?string}

cli::addHiddenCommand set_simstate_behavior \
    {rtupf::setSimstateBehavior} \
    {string} \
    {string lib} \
    {string model}

cli::addHiddenCommand upf_version \
    {rtupf::upfVersion} \
    {?string}

cli::addHiddenCommand use_interface_cell \
    {rtupf::useInterfaceCell} \
    {string} \
    {string strategy} \
    {string domain} \
    {string lib_cells} \
    {string map} \
    {string elements} \
    {string exclude_elements} \
    {string applies_to_clamp} \
    {string update_any} \
    {boolean force_function} \
    {string inverter_supply_set}
# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
