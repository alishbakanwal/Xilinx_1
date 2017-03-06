# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2009
#                             All rights reserved.
# ****************************************************************************
namespace eval rtcpf {
#    set pfdb  [getPFDb $rt::db]
    set pfcom [PFSynCom cpfcomhandler $rt::db]

    set versionCmds {set_cpf_version}
    set hierCmds {set_design set_instance end_design include}
    set macroCmds {set_macro_model end_macro_model set_floating_ports \
		       set_input_voltage_tolerance set_wire_feedthrough_ports}
    set genCmds {set_array_naming_style set_power_unit \
		     set_register_naming_style set_time_unit}
    set verCmds {assert_illegal_domain_configurations create_assertion_control}
    set pwrModeCmds {set_power_mode_control_group end_power_mode_control_group \
			 create_power_mode create_mode_transition update_power_mode}
    set impCstrCmds {create_analysis_view create_bias_net create_global_connection \
			 create_ground_nets create_isolation_rule \
			 create_level_shifter_rule create_nominal_condition \
			 create_operating_corner create_power_domain \
			 create_power_nets create_power_switch_rule \
			 create_state_retention_rule define_library_set \
			 identify_always_on_driver identify_power_logic \
			 identify_secondary_power_domain set_equivalent_control_pins \
			 set_power_target set_switching_activity \
			 update_isolation_rules update_level_shifter_rules \
			 update_nominal_condition update_power_domain \
			 update_power_switch_rule update_state_retention_rules}
    set libCmds {define_always_on_cell define_isolation_cell \
		     define_level_shifter_cell define_open_source_input_pin \
		     define_power_clamp_cell define_power_switch_cell \
		     define_related_power_pins define_state_retention_cell}

    set exportedCPFCmds {create_power_nets create_ground_nets \
			 define_always_on_cell define_isolation_cell \
			 define_level_shifter_cell define_state_retention_cell}

    set cpfCmds [concat $versionCmds $hierCmds $macroCmds $genCmds $verCmds \
		     $pwrModeCmds $impCstrCmds $libCmds]

    set cpfON false
    set cpfExposed false

    set fileStack {}
    set instanceStack {}

    proc convertToPFSynList {tclList} {
	set pfList [new_PFSynList]
	foreach elem $tclList {
	    [PFSynList_append $pfList $elem]
	}
	return $pfList
    }

    proc addCommonCommands {} {
	cli::addHiddenCommand create_power_domain \
	    {rtcpf::createPowerDomain} \
	    {string name} \
	    {string instances} \
	    {string boundary_ports} \
	    {boolean default} \
	    {string shutoff_condition} \
	    {boolean external_controlled_shutoff} \
	    {string default_isolation_condition} \
	    {string default_restore_edge} \
	    {string default_save_edge} \
	    {string default_restore_level} \
	    {string default_save_level} \
	    {enum {high low random} power_up_states random} \
	    {string active_state_conditions} \
	    {string base_domains}
    }

    proc exposeCPF {} {
	set prevState $rtcpf::cpfExposed

	if {$rtupf::upfON} {
	    UMsg_tclMessage PF 169 CPF UPF
	    return $prevState
	}

	if {!$rtcpf::cpfON} {
	    rtcpf::addCommonCommands
	}

	if {!$rtcpf::cpfExposed} {
	    foreach c $rtcpf::exportedCPFCmds {
		cli::hideCommand $c
	    }

	    foreach c $rtcpf::cpfCmds {
		cli::exposeCommand $c
	    }
	    set rtcpf::cpfExposed true
	}

	if {!$rtcpf::cpfON} {
	    cli::exposeCommand update_voltage_regions
	    cli::exposeCommand reset_cpf
	    cli::exposeCommand commit_cpf
	    set rtcpf::cpfON true
	}
	return $prevState
    }

    proc hideCPF {} {
	if {$rtcpf::cpfExposed} {
	    foreach c $rtcpf::cpfCmds {
		cli::hideCommand $c
	    }
	    set rtcpf::cpfExposed false

	    foreach c $rtcpf::exportedCPFCmds {
		cli::exposeCommand $c
	    }

	}
    }

    proc writeCPF {fileNm} {
	set ok true
	puts "warning: write_cpf is a BETA feature only!"
	set retStat [[rt::design] writeCpf $fileNm]
	if {$retStat < 0} {
	    set ok false
	}
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}	
    }

    proc commitCPF {} {
	rt::start_state "commit_cpf"
	set ok [$rtcpf::pfcom commitPF]
	rt::stop_state "commit_cpf"

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc resetCPF {} {
	set ok [$rtcpf::pfcom resetPFDb]
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc pushInstance {inst} {
	lappend rtcpf::instanceStack $inst
    }
    proc popInstance {} {
	set len [llength $rtcpf::instanceStack]
	set rtcpf::instanceStack [lrange $rtcpf::instanceStack 0 end-1]
    }
    proc currentInstance {} {
	if {[llength $rtcpf::instanceStack] > 0} {
	    return [lindex $rtcpf::instanceStack end]
	} else {
	    return ""
	}
    }

    proc pushFileDir {fileNm} {
	set fileDir [file dirname $fileNm]
	lappend rtcpf::fileStack $fileDir
    }
    proc popFileDir {} {
	set len [llength $rtcpf::fileStack]
	set rtcpf::fileStack [lrange $rtcpf::fileStack 0 end-1]
    }
    proc topFileDir {} {
	return [lindex $rtcpf::fileStack end]
    }

    proc assertIllegalDomainConfigurations {name
					    domain_conditions
					    group_modes} {
	UMsg_tclMessage PF 153 assert_illegal_domain_configurations
	return -code ok
    }

    proc createAnalysisView {name
			     mode
			     user_attributes
			     domain_corners
			     group_views} {
	UMsg_tclMessage PF 153 create_analysis_view
	return -code ok
    }

    proc createAssertionControl {name
				 assertions
				 domains
				 exclude
				 shutoff_condition
				 type} {
	UMsg_tclMessage PF 153 create_assertion_control
	return -code ok	
    }

    proc createBiasNet {net
			driver
			user_attributes
			peak_ir_drop_limit
			average_ir_drop_limit} {
	UMsg_tclMessage PF 153 create_bias_net
	return -code ok	
    }

    proc createGlobalConnection {net
				 pins
				 domain
				 instances} {
	if {$domain ne ""} {
	    UMsg_tclMessage PF 154 -domain create_global_connection
	}

	if {$instances ne ""} {
	    UMsg_tclMessage PF 154 -instances create_global_connection
	}

	set ok true
	if {$instances ne ""} {
	    foreach inst $instances {
		foreach pin $pins {
		    if {![$rtcpf::pfcom createGlobalConnection $net $pin $domain $inst]} {
			set ok false
		    }
		}
	    }
	} else {
	    foreach pin $pins {
		if {![$rtcpf::pfcom createGlobalConnection $net $pin $domain $instances]} {
		    set ok false
		}
	    }
	}
	if {$ok} {
	return -code ok	
	} else {
	    return -code error
	}
    }

    proc createGroundNets {nets voltage
			   external_shutoff_condition
			   internal
			   user_attributes
			   peak_ir_drop_limit
			   average_ir_drop_limit} {
	# check for unsupported options
	if {$voltage ne ""} {
	    UMsg_tclMessage PF 154 -voltage create_ground_nets
	}
	if {$external_shutoff_condition ne ""} {
	    UMsg_tclMessage PF 154 -external_shutoff_condition create_ground_nets
	}
	if {$internal} {
	    UMsg_tclMessage PF 154 -external_shutoff_condition create_ground_nets
	}
	if {$user_attributes ne ""} {
	    UMsg_tclMessage PF 154 -user_attributes create_ground_nets
	}
	if {$average_ir_drop_limit > 0} {
	    UMsg_tclMessage PF 154 -average_ir_drop_limit create_ground_nets
	}
	if {$peak_ir_drop_limit > 0} {
	    UMsg_tclMessage PF 154 -peak_ir_drop_limit create_ground_nets
	}

	set netList [new_PFSynList]
	foreach net $nets {
	    [PFSynList_append $netList $net]
	}
	set ok [$rtcpf::pfcom createSupplyNets $netList 0.0 false]
	rt::delete_PFSynList $netList

	if {$ok} {
	    return -code ok 
	} else {
	    return -code error
	}	
    }

    proc createIsolationRule {name
			      isolation_condition no_condition
			      from to
			      pins exclude
			      isolation_target
			      isolation_output
			      secondary_domain} {
	set ok true
	if {$no_condition} {
	    if {$isolation_condition != ""} {
		UMsg_tclMessage PF 137 $isolation_condition
		set ok false
	    }
	} else {
	    if {$isolation_condition == ""} {
		UMsg_tclMessage PF 138
		set ok false
	    }
	}

	if {$ok} {
	    set ok [$rtcpf::pfcom createIsolationRule $name $isolation_condition \
			$from $to $pins $exclude \
			$isolation_target $isolation_output \
			$secondary_domain ]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createLevelShifterRule {name from to pins exclude} {
	#cli::echoCommandArgs create_level_shifter_rule $name \
	#    $pins $from $to
	set fromList     [convertToPFSynList $from]
	set toList       [convertToPFSynList $to]
	set pinsList     [convertToPFSynList $pins]
	set excludeList  [convertToPFSynList $exclude]

	set ok [$rtcpf::pfcom createLevelShifterRule $name $fromList $toList $pinsList $excludeList ]

	rt::delete_PFSynList $fromList
	rt::delete_PFSynList $toList
	rt::delete_PFSynList $pinsList
	rt::delete_PFSynList $excludeList

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createModeTransition {name from to
			       start_condition end_condition
			       cycles clock_pin latency} {
	UMsg_tclMessage PF 153 create_mode_transition
	return -code ok		
    }

    proc createNominalCondition {name voltage ground_voltage
				 state pmos_bias_voltage nmos_bias_voltage} {
#	cli::echoCommandArgs create_nominal_condition $name $voltage
	if {$ground_voltage > 0} {
	    UMsg_tclMessage PF 154 -ground_voltage create_nominal_condition    
	}
	if {$state ne ""} {
	    UMsg_tclMessage PF 154 -state create_nominal_condition   
	}
	if {$pmos_bias_voltage ne ""} {
	    UMsg_tclMessage PF 154 -pmos_bias_voltage create_nominal_condition   
	}
	if {$nmos_bias_voltage ne ""} {
	    UMsg_tclMessage PF 154 -nmos_bias_voltage create_nominal_condition   
	}

	set ok [$rtcpf::pfcom createNominalCondition $name $voltage]
	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}	
    }

    proc createOperatingCorner {name voltage ground_voltage
				pmos_bias_voltage nmos_bias_voltage
				process temperature library_set} {
	UMsg_tclMessage PF 153 create_operating_corner
	return -code ok		
    }

    proc createPowerDomain {name instances
			    boundary_ports default
			    shutoff_condition external_controlled_shutoff
			    default_isolation_condition
			    default_restore_edge
			    default_save_edge
			    default_restore_level
			    default_save_level
			    power_up_states
			    active_state_conditions
			    base_domains} {
	set ok true
	if {$boundary_ports ne ""} {
	    #UMsg_tclMessage PF 154 -boundary_ports create_power_domain
	}
	if {$shutoff_condition ne ""} {
	    UMsg_tclMessage PF 154 -shutoff_condition create_power_domain
	}
	if {$external_controlled_shutoff} {
	    UMsg_tclMessage PF 154 -external_controlled_shutoff create_power_domain
	}
	if {$default_isolation_condition ne ""} {
	    UMsg_tclMessage PF 154 -default_isolation_condition create_power_domain
	}
	if {$default_restore_edge ne ""} {
	    UMsg_tclMessage PF 154 -default_restore_edge create_power_domain
	}
	if {$default_save_edge ne ""} {
	    UMsg_tclMessage PF 154 -default_save_edge create_power_domain
	}
	if {$default_restore_level ne ""} {
	    UMsg_tclMessage PF 154 -default_restore_level create_power_domain
	}
	if {$default_save_level ne ""} {
	    UMsg_tclMessage PF 154 -default_save_level create_power_domain
	}
	if {$power_up_states ne "random"} {
	    UMsg_tclMessage PF 154 -power_up_states create_power_domain
	}
	if {$active_state_conditions ne ""} {
	    UMsg_tclMessage PF 154 -active_state_conditions create_power_domain
	}
	if {$base_domains ne ""} {
	    UMsg_tclMessage PF 154 -base_domains create_power_domain
	}
	if {$name == ""} {
	    UMsg_tclMessage CMD 109 -name
	    set ok false
	}

	if {$ok} {
	    set ok [$rtcpf::pfcom createPowerDomain $name $instances $boundary_ports $default $shutoff_condition]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createPowerMode {name default domain_conditions group_modes update} {
#	cli::echoCommandArgs create_power_mode $name $default $domain_conditions
	if {$group_modes ne ""} {
	    UMsg_tclMessage PF 154 -group_modes create_power_mode
	}	
	set condList [convertToPFSynList $domain_conditions]
	set ok [$rtcpf::pfcom createPowerMode $name $default $condList $update]
	rt::delete_PFSynList $condList

	if {$ok} {
	    $rtcpf::pfcom invalidateDesignPF
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc createPowerNets {nets voltage external_shutoff_condition
			  internal
			  user_attributes
			  peak_ir_drop_limit
			  average_ir_drop_limit} {
	#cli::echoCommandArgs create_power_nets $nets $voltage
	if {$voltage ne ""} {
	    UMsg_tclMessage PF 154 -voltage create_power_nets
	}
	if {$external_shutoff_condition ne ""} {
	    UMsg_tclMessage PF 154 -external_shutoff_condition create_power_nets
	}
	if {$internal} {
	    UMsg_tclMessage PF 154 -external_shutoff_condition create_power_nets
	}
	if {$user_attributes ne ""} {
	    UMsg_tclMessage PF 154 -user_attributes create_power_nets
	}
	if {$average_ir_drop_limit > 0} {
	    UMsg_tclMessage PF 154 -average_ir_drop_limit create_power_nets
	}
	if {$peak_ir_drop_limit > 0} {
	    UMsg_tclMessage PF 154 -peak_ir_drop_limit create_power_nets
	}

	set netList [new_PFSynList]
	foreach net $nets {
	    [PFSynList_append $netList $net]
	}
	set ok [$rtcpf::pfcom createSupplyNets $netList 1.0 true]
	rt::delete_PFSynList $netList

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc createPowerSwitchRule {name domain
				external_power_net
				external_ground_net} {
#	cli::echoCommandArgs create_power_switch_rule \
#	    $name $domain $external_power_net $external_ground_net
	UMsg_tclMessage PF 153 create_power_switch_rule
	return -code ok	
    }

    proc createRetentionRule {name domain
			      instances exclude
			      save_level save_edge
			      restore_level restore_edge
			      restore_precondition save_precondition
			      secondary_domain
			      target_type} {
	#cli::echoCommandArgs create_state_retention_rule $name $domain \
	#   $instances $exclude $restore_edge $save_edge \
	#   $restore_level $save_level \
        #   $secondary_domain $target_type
	if {$restore_precondition ne ""} {
	    UMsg_tclMessage PF 154 -restore_precondition create_state_retention_rule
	}
	if {$save_precondition ne ""} {
	    UMsg_tclMessage PF 154 -save_precondition create_state_retention_rule
	}

	set ok true

	if {$ok} {
	    set ok [$rtcpf::pfcom createRetentionRule $name $domain \
			$instances $exclude $save_level $save_edge \
			$restore_level $restore_edge $secondary_domain $target_type ]
	}

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc defineLibrarySet {name libraries user_attributes} {
	# cli::echoCommandArgs define_library_set $name $libraries
	if {$user_attributes ne ""} {
	    UMsg_tclMessage PF 154 -user_attributes define_library_set
	}

	set libFileList [new_PFSynList]

	foreach libName $libraries {
	    set libFile [rt::searchPath $libName]
	    set libFileNorm [file normalize $libFile]
	    [PFSynList_append $libFileList $libFileNorm]
	}
	set ok [$rtcpf::pfcom defineLibrarySet $name $libFileList]
	rt::delete_PFSynList $libFileList

	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc endDesign {module} {
	# cli::echoCommandArgs end_design
	if {$module ne ""} {
	    UMsg_tclMessage PF 154 [module] end_design
	}

	set ok [$rtcpf::pfcom endDesign ]
	if {$ok} {
	    set currInst [rtcpf::currentInstance]
	    if {$currInst ne ""} {
		rtcpf::popInstance
	    }
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc endMacroModel {macro_cell} {
	UMsg_tclMessage PF 153 end_macro_model
	set ok [$rtcpf::pfcom endMacroModel]
	return -code ok	
    }

    proc endPowerModeControlGroup {} {
	UMsg_tclMessage PF 153 end_power_mode_control_group
	return -code ok	
    }

    proc identifyAlwaysOnDriver {pins no_propagation} {
	UMsg_tclMessage PF 153 identify_always_on_driver
	return -code ok	
    }

    proc identifyPowerLogic {type instances module} {
	UMsg_tclMessage PF 153 identify_power_logic
	return -code ok	
    }

    proc identifySecondaryPowerDomain {secondary_domain
				       instances
				       cells
				       domain
				       from
				       to} {
	UMsg_tclMessage PF 153 identify_power_logic
	return -code ok	
    }

    proc include {fileNm} {
	set fileDir [rtcpf::topFileDir]
	set effFile [file join $fileDir $fileNm]
	if {[file exists $effFile]} {
	    rtcpf::pushFileDir $effFile
	    if {[catch {uplevel 2 source $effFile} emsg]} {
	    	puts $emsg
	    }
	    rtcpf::popFileDir
	} else {
	    UMsg_tclMessage CMD 114 $effFile
	    return -code error
	}
	return -code ok	
    }

    proc setArrayNamingStyle {style} {
	if {$style ne ""} {
	    rt::setParameter array_naming_style $style
	}
	return -code ok [rt::getParam array_naming_style]
    }

    proc setCpfVersion {version} {
	cli::echoCommandArgs set_cpf_version $version
    }

    proc setDesign {name ports honor_boundary_port_domain parameters} {
	# cli::echoCommandArgs set_design $name
	if {$honor_boundary_port_domain} {
	    UMsg_tclMessage PF 154 -honor_boundary_port_domain set_design
	}
	if {$parameters ne ""} {
	    UMsg_tclMessage PF 154 -parameters set_design
	}
	set portList {}
	foreach port $ports {
	    lappend portList $port
	}

	set currInst [rtcpf::currentInstance]
	set ok [$rtcpf::pfcom setDesign $currInst $name $portList]
	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc setEquivalentControlPins {master pins domain rules} {
	UMsg_tclMessage PF 153 set_equivalent_control_pins
	return -code ok	
    }

    proc setFloatingPorts {port_list} {
	UMsg_tclMessage PF 153 set_floating_ports
	return -code ok	
    }

    proc setInputVoltageTolerance {ports bias} {
	UMsg_tclMessage PF 153 set_input_voltage_tolerance
	return -code ok	
    }

    proc setInstance {instance design model port_mapping
		      domain_mapping parameter_mapping} {
	puts "debug '$domain_mapping'"

	set ok true
	if {$parameter_mapping ne ""} {
	    UMsg_tclMessage PF 154 -parameter_mapping set_instance
	}
	if {$model ne ""} {
	    UMsg_tclMessage PF 154 -model set_instance
	}

	# check required options
	if {$instance eq ""} {
	    UMsg_tclMessage CMD 109 <instance>
	    set ok false
	}
	if {$design eq "" && $model == ""} {
	    UMsg_tclMessage CMD 109 -design
	}

	set ok [$rtcpf::pfcom setInstance $instance $design $model $port_mapping $domain_mapping]
	if {$ok} {
	    if {$design eq "" && $model eq ""} {
		rtcpf::pushInstance $instance
	    }
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc setMacroModel {macro_cell} {
	UMsg_tclMessage PF 153 set_macro_model
	set ok [$rtcpf::pfcom setMacroModel $macro_cell]
	if {$ok} {
	    return -code ok $macro_cell
	} else {
	    return -code error
	}
    }

    proc setPowerModeControlGroup {name domains groups} {
	UMsg_tclMessage PF 153 set_power_mode_control_group
	return -code ok	
    }

    proc setPowerTarget {leakage dynamic} {
	UMsg_tclMessage PF 153 set_power_target
	return -code ok	
    }

    proc setPowerUnit {unit} {
	UMsg_tclMessage PF 153 set_power_unit
	return -code ok
    }

    proc setRegisterNamingStyle {cpfstyle} {
	if {$cpfstyle ne ""} {
	    set style [string trimright $cpfstyle "%s"]
	    set style "%s$style"
	    rt::setParameter reg_naming_style $style
	}

	set style [rt::getParam reg_naming_style]
	set cpfstyle [string trimleft $style "%s"]
	set cpfstyle "$cpfstyle%s"
	return -code ok $cpfstyle
    }

    proc setSwitchingActivity {all pins instances hierarchical probability
			       toggle_rate clock_pins toggle_percentage mode} {
	UMsg_tclMessage PF 153 set_switching_activity
	return -code ok
    }

    proc setTimeUnit {unit} {
	UMsg_tclMessage PF 153 set_time_unit
	return -code ok
    }

    proc setWireFeedThroughPorts {port_list} {
	UMsg_tclMessage PF 153 set_wire_feedthrough_ports
	return -code ok
    }

    proc updateIsolationRules {names location
			       within_hierarchy
			       cells
			       prefix
			       open_source_pins_only} { 
	if {$within_hierarchy ne ""} {
	    UMsg_tclMessage PF 154 -within_hierarchy update_isolation_rules
	}
	if {$cells ne ""} {
	    UMsg_tclMessage PF 154 -cells update_isolation_rules
	}	

	set cellList [rt::getLibCells $cells 1]
	set cellNames ""
	foreach cell $cellList {
	    lappend cellNames [$cell _name]
	}

	if {$open_source_pins_only} {
	    UMsg_tclMessage PF 154 -open_source_pins_only update_isolation_rules
	}

	if {$prefix eq ""} {
	    set prefix "CPF_ISO"
	}

	set ok [$rtcpf::pfcom updateIsolationRules $names $location $prefix $cellNames]

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc updateLevelShifterRules {names location
				  within_hierarchy
				  cells
				  prefix} {
	if {$within_hierarchy ne ""} {
	    UMsg_tclMessage PF 154 -within_hierarchy update_level_shifter_rules
	}
	if {$cells ne ""} {
	    #UMsg_tclMessage PF 154 -cells update_level_shifter_rules
	}	
	set cellList [rt::getLibCells $cells 1]
	set cellNames ""
	foreach cell $cellList {
	    lappend cellNames [$cell _name]
	}

	set nameList     [convertToPFSynList $names]
	if {$prefix eq ""} {
	    set prefix "CPF_LS"
	}

	set ok [$rtcpf::pfcom updateLevelShifterRules $nameList $location $prefix $cellNames]

	rt::delete_PFSynList $nameList

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc updateNominalCondition {name library_set} {
#	cli::echoCommandArgs update_nominal_condition $name $library_set
	set ok [$rtcpf::pfcom updateNominalCondition $name $library_set]
	if {$ok} {
	    return -code ok $name
	} else {
	    return -code error
	}
    }

    proc updatePowerDomain {name 
			    library_set
			    primary_power_net
			    primary_ground_net
			    equivalent_power_nets
			    equivalent_ground_nets
			    pmos_bias_net
			    nmos_bias_net
			    user_attributes
			    transition_slope
			    transition_latency
			    transition_cycles} {
	if {$equivalent_power_nets ne ""} {
	    UMsg_tclMessage PF 154 -equivalent_power_nets update_power_domain
	}
	if {$equivalent_ground_nets ne ""} {
	    UMsg_tclMessage PF 154 -equivalent_ground_nets update_power_domain
	}
	if {$pmos_bias_net ne ""} {
	    UMsg_tclMessage PF 154 -pmos_bias_net update_power_domain
	}
	if {$nmos_bias_net ne ""} {
	    UMsg_tclMessage PF 154 -nmos_bias_net update_power_domain
	}
	if {$user_attributes ne ""} {
	    UMsg_tclMessage PF 154 -user_attributes update_power_domain
	}
	if {$transition_slope ne ""} {
	    UMsg_tclMessage PF 154 -transition_slope update_power_domain
	}
	if {$transition_latency ne ""} {
	    UMsg_tclMessage PF 154 -transition_latency update_power_domain
	}
	if {$transition_cycles ne ""} {
	    UMsg_tclMessage PF 154 -transition_cycles update_power_domain
	}

	set ok [$rtcpf::pfcom updatePowerDomain $name $library_set $primary_power_net $primary_ground_net]
	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc updatePowerMode {name 
			  activity_file activity_file_weight
			  sdc_files setup_sdc_files hold_sdc_files
			  peak_ir_drop_limit average_ir_drop_limit
			  leakage_power_limit dynamic_power_limit} {
#	cli::echoCommandArgs update_power_mode $name $sdc_files
	UMsg_tclMessage PF 153 update_power_mode
	return -code ok
    }

    proc updatePowerSwitchRule {name 
				enable_condition_1
				enable_condition_2
				acknowledge_receiver_1
				acknowledge_receiver_2
				cells
				gate_bias_net
				prefix
				peak_ir_drop_limit average_ir_drop_limit} {
#	cli::echoCommandArgs update_power_mode $name $sdc_files
	UMsg_tclMessage PF 153 update_power_switch_rule
	return -code ok
    }

    proc updateRetentionRules {names cell_type cells set_reset_control} {
	if {$cells ne ""} {
	    UMsg_tclMessage PF 154 -cells update_state_retention_rules
	}
	if {$set_reset_control} {
	    UMsg_tclMessage PF 154 -set_reset_control update_state_retention_rules
	}

	# need this to set the type to bool
	set ok true
	if {$ok} {
	    set ok [$rtcpf::pfcom updateRetentionRules $names $cell_type ]
	}

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc checkPGSpecification {power_switchable
			       ground_switchable
			       power
			       ground} {
	set ok true

	if {$power ne "" && $ground ne "" &&
	    ($power_switchable ne "" || $ground_switchable ne "")} {
	    if {$power_switchable ne "" && $ground_switchable ne ""} {
		UMsg_tclMessage CMD 100 "-power_switchable" "-ground_switchable"
		set ok false
	    }
	} else {
	    if {$power ne ""} {
		if {$ground eq ""} {
		    UMsg_tclMessage CMD 107 -power -ground
		} else {
		    UMsg_tclMessage CMD 107 "-power" "-power_switchable or -ground_switchable"
		}
		set ok false
	    } elseif {$ground ne ""} {
		if {$power eq ""} {
		    UMsg_tclMessage CMD 107 "-ground" "-power"
		} else {
		    UMsg_tclMessage CMD 107 "-ground" "-power_switchable or -ground_switchable"
		}
		set ok false
	    } elseif {$power_switchable ne ""} {
		if {$power eq ""} {
		    UMsg_tclMessage CMD 107 "-power_switchable" "-power"
		} else {
		    UMsg_tclMessage CMD 107 "-power_switchable" "-ground"
		}
		set ok false
	    } elseif {$ground_switchable ne ""} {
		if {$power eq ""} {
		    UMsg_tclMessage CMD 107 "-ground_switchable" "-power"
		} else {
		    UMsg_tclMessage CMD 107 "-ground_switchable" "-ground"
		}
		set ok false
	    } else {
		# all -power -ground -power_switchable -ground_switchable not specified
	    }
	}
	return $ok
    }

    proc defineAlwaysOnCell {cells
			     power_switchable
			     ground_switchable
			     power
			     ground} {
	set ok [checkPGSpecification $power_switchable $ground_switchable $power $ground]

	if {$ok} {
	    set cellList [rt::getLibCells $cells 1]

	    foreach cell $cellList {
		set lok [$rtcpf::pfcom defineAlwaysOnCell \
			     $cell $power_switchable $ground_switchable \
			     $power $ground]
		if {!$lok} {
		    set ok false
		}
	    }
	    $rt::db invalidateTargetLibs
	}

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc checkPowerTypeAgainstLoc {power_switchable
				   ground_switchable
				   power
				   ground
				   valid_location} {
	set ok true
	if {$power_switchable ne ""} {
	    set powerType "backupHeader"
	} elseif {$ground_switchable ne ""} {
	    set powerType "backupGround"
	} else {
	    set powerType "primary"
	}

	if {$powerType == "primary"} {
	    if {$valid_location == "off"} {
		UMsg_tclMessage PF 155 "Primary" "off"
		set ok false
	    }
	} else {
	    if {$valid_location == "on"} {
		UMsg_tclMessage PF 155 "Backup" "off"
		set ok false
	    }
	}
	return $ok
    }

    proc defineIsolationCell {cells
			      library_set
			      always_on_pins
			      power_switchable
			      ground_switchable
			      power
			      ground
			      valid_location
			      enable_pin
			      no_enable
			      non_dedicated} {
	set ok true
	if {$library_set ne ""} {
	    UMsg_tclMessage PF 154 -library_set define_isolation_cell
	}
	if {$always_on_pins ne ""} {
	    UMsg_tclMessage PF 154 -always_on_pins define_isolation_cell
	}
	if {$no_enable} {
	    UMsg_tclMessage PF 154 -no_enable define_isolation_cell
	}
	if {$enable_pin eq ""} {
	    UMsg_tclMessage CMD 109 -enable_pin
	    set ok false
	}
	if {$non_dedicated} {
	    UMsg_tclMessage PF 154 -non_dedicated define_isolation_cell
	}
	if {$ok} {
	    set ok [checkPGSpecification $power_switchable $ground_switchable $power $ground]
	}
	if {$ok} {
	    set ok [checkPowerTypeAgainstLoc $power_switchable $ground_switchable \
			$power $ground $valid_location]
	}

	if {$ok} {
	    set cellList [rt::getLibCells $cells 1]

	    foreach cell $cellList {
		set lok [$rtcpf::pfcom defineIsolationCell \
			     $cell $power_switchable $ground_switchable \
			     $power $ground $valid_location $enable_pin]
		if {!$lok} {
		    set ok false
		}
	    }
	    $rt::db invalidateTargetLibs
	}

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc defineLevelShifterCell {cells
				 library_set
				 always_on_pins
				 input_voltage_range
				 output_voltage_range
				 ground_input_voltage_range
				 ground_output_voltage_range
				 direction
				 valid_location
				 input_power_pin
				 output_power_pin
				 power
				 ground
				 enable} {
	if {$library_set ne ""} {
	    UMsg_tclMessage PF 154 -library_set define_level_shifter_cell
	}
	if {$always_on_pins ne ""} {
	    UMsg_tclMessage PF 154 -always_on_pins define_level_shifter_cell
	}
	if {$ground_input_voltage_range ne ""} {
	    UMsg_tclMessage PF 154 -ground_input_voltage_range define_level_shifter_cell
	}
	if {$ground_output_voltage_range ne ""} {
	    UMsg_tclMessage PF 154 -ground_output_voltage_range define_level_shifter_cell
	}
	if {$power ne ""} {
	    UMsg_tclMessage PF 154 -power define_level_shifter_cell
	}
	if {$enable ne ""} {
	    UMsg_tclMessage PF 154 -enable define_level_shifter_cell
	}

	set cellList [rt::getLibCells $cells 1]
	set pfList   [new_PFSynList]
	foreach cell $cellList {
	    PFSynList_append $pfList [$cell _name]
	}

	set IRList [split $input_voltage_range ":"]
	set IRLen  [llength $IRList]
	set ORList [split $output_voltage_range ":"]
	set ORLen  [llength $ORList]

	set IRfrom ""
	set IRto   ""
	if {$IRLen == 2} {
	    set IRfrom [lindex $IRList 0]
	    set IRto   [lindex $IRList 1]
	} elseif {$IRLen == 1} {
	    set IRfrom [lindex $IRList 0]
	    set IRto   [lindex $IRList 0]
	}

	set ORfrom ""
	set ORto   ""
	if {$ORLen == 2} {
	    set ORfrom [lindex $ORList 0]
	    set ORto   [lindex $ORList 1]
	} elseif {$ORLen == 1} {
	    set ORfrom [lindex $ORList 0]
	    set ORto   [lindex $ORList 0]
	}

	set ok [$rtcpf::pfcom defineLevelShifterCell \
		    $pfList $IRfrom $IRto $ORfrom $ORto \
		    $direction $valid_location \
		    $input_power_pin $output_power_pin $ground]
	rt::delete_PFSynList $pfList

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }

    proc defineOpenSourceInputPin {cells 
				   pin
				   library_set} {
	UMsg_tclMessage PF 153 define_open_source_input_pin
	return -code ok
    }

    proc definePowerClampCell {cells 
			       data
			       power ground
			       library_set} {
	UMsg_tclMessage PF 153 define_power_clamp_cell
	return -code ok
    }

    proc definePowerSwitchCell {cells 
				library_set
				stage_1_enable
				stage_1_output
				stage_2_enable
				stage_2_output
				type
				enable_pin_bias
				gate_bias_pin
				power_switchable
				power
				ground_switchable
				ground
				stage_1_on_resistance
				stage_2_on_resistance
				stage_1_saturation_current
				stage_2_saturation_current
				leakage_current} {
	UMsg_tclMessage PF 153 define_power_switch_cell
	return -code ok
    }

    proc defineRelatedPowerPins {data_pins
				 cells
				 library_set
				 power
				 ground} {
	UMsg_tclMessage PF 153 define_related_power_pins
	return -code ok
    }

    proc defineRetentionCell {cells
			      cell_type
			      always_on_pins
			      restore_function
			      save_function
			      power_switchable
			      ground_switchable
			      power
			      ground} {
	set ok [checkPGSpecification $power_switchable $ground_switchable $power $ground]

	if {$ok} {
	    set cellList [rt::getLibCells $cells 1]

	    foreach cell $cellList {
		set lok [$rtcpf::pfcom defineRetentionCell \
			     $cell $power_switchable $ground_switchable \
			     $power $ground $cell_type $always_on_pins \
			     $restore_function $save_function ]
		if {!$lok} {
		    set ok false
		}
	    }
	    $rt::db invalidateTargetLibs
	}

	if {$ok} {
	    return -code ok
	} else {
	    return -code error
	}
    }
}

cli::addHiddenCommand commit_cpf \
    {rtcpf::commitCPF}

cli::addHiddenCommand reset_cpf \
    {rtcpf::resetCPF}

cli::addCommand write_cpf \
    {rtcpf::writeCPF} {string}

cli::addHiddenCommand assert_illegal_domain_configurations \
    {rtcpf::assertIllegalDomainConfigurations} \
    {string name} \
    {string domain_conditions} \
    {string group_modes}

cli::addHiddenCommand create_analysis_view \
    {rtcpf::createAnalysisView} \
    {string name} \
    {string mode} \
    {string user_attributes} \
    {string domain_corners} \
    {string group_views}

cli::addHiddenCommand create_assertion_control \
    {rtcpf::createAssertionControl} \
    {string name} \
    {string assertions} \
    {string domains} \
    {string exclude} \
    {string shutoff_condition} \
    {enum {reset suspend} type reset}

cli::addHiddenCommand create_bias_net \
    {rtcpf::createBiasNet} \
    {string net} \
    {string driver} \
    {string users_attributes} \
    {double peak_ir_drop_limit 0} \
    {double average_ir_drop_limit 0}

cli::addHiddenCommand create_global_connection \
    {rtcpf::createGlobalConnection} \
    {string net} \
    {string pins} \
    {string domain} \
    {string instances}

cli::addCommand create_ground_nets \
    {rtcpf::createGroundNets} \
    {string nets} \
    {string voltage} \
    {string external_shutoff_condition} \
    {boolean internal} \
    {string user_attributes} \
    {double peak_ir_drop_limit 0} \
    {double average_ir_drop_limit 0}

cli::addHiddenCommand create_isolation_rule \
    {rtcpf::createIsolationRule} \
    {string name} \
    {string isolation_condition} \
    {boolean no_condition} \
    {string from} \
    {string to} \
    {string pins} \
    {string exclude} \
    {enum {from to} isolation_target from} \
    {enum {high low hold tristate} isolation_output low} \
    {string secondary_domain}

cli::addHiddenCommand create_level_shifter_rule \
    {rtcpf::createLevelShifterRule} \
    {string name} \
    {string from} \
    {string to} \
    {string pins} \
    {string exclude}

cli::addHiddenCommand create_mode_transition \
    {rtcpf::createModeTransition} \
    {string name} \
    {string from} \
    {string to} \
    {string start_condition} \
    {string end_condition} \
    {string cycles} \
    {string clock_pin} \
    {string latency}

cli::addHiddenCommand create_nominal_condition \
    {rtcpf::createNominalCondition} \
    {string name} \
    {double voltage} \
    {double ground_voltage 0} \
    {string state} \
    {double pmos_bias_voltage} \
    {double nmos_bias_voltage}

cli::addHiddenCommand create_operating_corner \
    {rtcpf::createOperatingCorner} \
    {string name} \
    {double voltage} \
    {double ground_voltage 0} \
    {double pmos_bias_voltage} \
    {double nmos_bias_voltage} \
    {double process} \
    {double temperature} \
    {double library_set}

cli::addHiddenCommand create_power_mode \
    {rtcpf::createPowerMode} \
    {string name} \
    {boolean default} \
    {string domain_conditions} \
    {string group_modes} \
    {#boolean update}

cli::addCommand create_power_nets \
    {rtcpf::createPowerNets} \
    {string nets} \
    {string voltage} \
    {string external_shutoff_condition} \
    {boolean internal} \
    {string user_attributes} \
    {double peak_ir_drop_limit 0} \
    {double average_ir_drop_limit 0}

cli::addHiddenCommand create_power_switch_rule \
    {rtcpf::createPowerSwitchRule} \
    {string name} \
    {string domain} \
    {string external_power_net} \
    {string external_ground_net}

cli::addHiddenCommand create_state_retention_rule \
    {rtcpf::createRetentionRule} \
    {string name} \
    {string domain} \
    {string instances} \
    {string exclude} \
    {string save_level} \
    {string save_edge} \
    {string restore_level} \
    {string restore_edge} \
    {string restore_precondition} \
    {string save_precondition} \
    {string secondary_domain} \
    {enum {flop latch both} target_type both}

cli::addHiddenCommand define_library_set \
    {rtcpf::defineLibrarySet} \
    {string name} \
    {string libraries} \
    {string user_attributes}

cli::addHiddenCommand end_design \
    {rtcpf::endDesign} \
    {?string}

cli::addHiddenCommand end_macro_model \
    {rtcpf::endMacroModel} \
    {?string}

cli::addHiddenCommand end_power_mode_control_group \
    {rtcpf::endPowerModeControlGroup}

### get_parameter comes here
cli::addHiddenCommand identify_always_on_driver \
    {rtcpf::identifyAlwaysOnDriver} \
    {string pins} \
    {boolean no_propagation}

cli::addHiddenCommand identify_power_logic \
    {rtcpf::identifyPowerLogic} \
    {enum {isolation} type isolation} \
    {string instances} \
    {string module}

cli::addHiddenCommand identify_secondary_power_domain \
    {rtcpf::identifySecondPowerDomain} \
    {string secondary_domain} \
    {string instances} \
    {string cells} \
    {string domain} \
    {string from} \
    {string to}

cli::addHiddenCommand include \
    {rtcpf::include} \
    {string}

cli::addHiddenCommand set_array_naming_style \
    {rtcpf::setArrayNamingStyle} \
    {?string}

cli::addHiddenCommand set_cpf_version \
    {rtcpf::setCpfVersion} \
    {string}

cli::addHiddenCommand set_design \
    {rtcpf::setDesign} \
    {string} \
    {string ports} \
    {boolean honor_boundary_port_domain} \
    {string parameters}

cli::addHiddenCommand set_equivalent_control_pins \
    {rtcpf::setEquivalentControlPins} \
    {string master} \
    {string pins} \
    {string domain} \
    {string rules}

cli::addHiddenCommand set_floating_ports \
    {rtcpf::setFloatingPorts} \
    {string}

# set_hierarchy_separator is defined in SDC

cli::addHiddenCommand set_input_voltage_tolerance \
    {rtcpf::setInputVoltageTolerance} \
    {string ports} \
    {string bias}

cli::addHiddenCommand set_instance \
    {rtcpf::setInstance} \
    {?string} \
    {string design} \
    {string model} \
    {string port_mapping} \
    {string domain_mapping} \
    {string parameter_mapping}
    
cli::addHiddenCommand set_macro_model \
    {rtcpf::setMacroModel} \
    {string}

cli::addHiddenCommand set_power_mode_control_group \
    {rtcpf::setPowerModeControlGroup} \
    {string name} \
    {string domains} \
    {string groups}

cli::addHiddenCommand set_power_target \
    {rtcpf::setPowerTarget} \
    {double leakage} \
    {double dynamic}

cli::addHiddenCommand set_power_unit \
    {rtcpf::setPowerUnit} \
    {?string}

cli::addHiddenCommand set_register_naming_style \
    {rtcpf::setRegisterNamingStyle} \
    {?string}

cli::addHiddenCommand set_switching_activity \
    {rtcpf::setSwitchingActivity} \
    {boolean all} \
    {string pins} \
    {string instances} \
    {boolean hierarchical} \
    {double probability} \
    {double toggle_rate} \
    {string clock_pins} \
    {double toggle_percentage} \
    {string mode}

cli::addHiddenCommand set_time_unit \
    {rtcpf::setTimeUnit} \
    {?string}

cli::addHiddenCommand set_wire_feedthrough_ports \
    {rtcpf::setWireFeedThroughPorts} \
    {string}

cli::addHiddenCommand update_isolation_rules \
    {rtcpf::updateIsolationRules} \
    {string names} \
    {enum {from to} location to} \
    {string within_hierarchy} \
    {string cells} \
    {string prefix} \
    {boolean open_source_pins_only}

cli::addHiddenCommand update_level_shifter_rules \
    {rtcpf::updateLevelShifterRules} \
    {string names} \
    {enum {from to} location to} \
    {string within_hierarchy} \
    {string cells} \
    {string prefix}

cli::addHiddenCommand update_nominal_condition \
    {rtcpf::updateNominalCondition} \
    {string name} \
    {string library_set}

cli::addHiddenCommand update_power_domain \
    {rtcpf::updatePowerDomain} \
    {string name} \
    {#string library_set} \
    {string primary_power_net} \
    {string primary_ground_net} \
    {string equivalent_power_nets} \
    {string equivalent_ground_nets} \
    {string pmos_bias_net} \
    {string nmos_bias_net} \
    {string user_attributes} \
    {string transition_slope} \
    {string transition_latency} \
    {string transition_cycles}

cli::addHiddenCommand update_power_mode \
    {rtcpf::updatePowerMode} \
    {string name} \
    {string activity_file} \
    {double activity_file_weight} \
    {string sdc_files} \
    {string setup_sdc_files} \
    {string hold_sdc_files} \
    {string peak_ir_drop_limit} \
    {string average_ir_drop_limit} \
    {double leakage_power_limit} \
    {double dynamic_power_limit}

cli::addHiddenCommand update_power_switch_rule \
    {rtcpf::updatePowerSwitchRule} \
    {string name} \
    {string enable_condition_1} \
    {string enable_condition_2} \
    {string acknowledge_receiver_1} \
    {string acknowledge_receiver_2} \
    {string cells} \
    {string gate_bias_net} \
    {string prefix} \
    {double peak_ir_drop_limit} \
    {double average_ir_drop_limit}

cli::addHiddenCommand update_state_retention_rules \
    {rtcpf::updateRetentionRules} \
    {string names} \
    {string cell_type} \
    {string cells} \
    {boolean set_reset_control}


#########################################
# Library Cell-Related CPF Commands
###########################################
cli::addCommand define_always_on_cell \
    {rtcpf::defineAlwaysOnCell} \
    {string cells} \
    {string power_switchable} \
    {string ground_switchable} \
    {string power} \
    {string ground}

cli::addCommand define_isolation_cell \
    {rtcpf::defineIsolationCell} \
    {string cells} \
    {string library_set} \
    {string always_on_pins} \
    {string power_switchable} \
    {string ground_switchable} \
    {string power} \
    {string ground} \
    {enum {to from on off} valid_location to} \
    {string enable_pin} \
    {boolean no_enable} \
    {boolean non_dedicated}

cli::addCommand define_level_shifter_cell \
    {rtcpf::defineLevelShifterCell} \
    {string cells} \
    {string library_set} \
    {string always_on_pins} \
    {string input_voltage_range} \
    {string output_voltage_range} \
    {string ground_input_voltage_range} \
    {string ground_output_voltage_range} \
    {enum {bidir up down} direction up} \
    {enum {to from either} valid_location to} \
    {string input_power_pin} \
    {string output_power_pin} \
    {string power} \
    {string ground} \
    {string enable}

cli::addHiddenCommand define_open_source_input_pin \
    {rtcpf::defineOpenSourceInputPin} \
    {string cells} \
    {string pin} \
    {string library_set}

cli::addHiddenCommand define_power_clamp_cell \
    {rtcpf::defineOpenSourceInputPin} \
    {string cells} \
    {string data} \
    {string power} \
    {string ground} \
    {string library_set}

cli::addHiddenCommand define_power_switch_cell \
    {rtcpf::definePowerSwitchCell} \
    {string cells} \
    {string library_set} \
    {string stage_1_enable} \
    {string stage_1_output} \
    {string stage_2_enable} \
    {string stage_2_output} \
    {enum {footer header} type header} \
    {string enable_pin_bias} \
    {string gate_bias_pin} \
    {string power_switchable} \
    {string power} \
    {string ground_switchable} \
    {string ground} \
    {double stage_1_on_resistance} \
    {double stage_2_on_resistance} \
    {double stage_1_saturation_current} \
    {double stage_2_saturation_current} \
    {double leakage_current}

cli::addHiddenCommand define_related_power_pins \
    {rtcpf::defineRelatedPowerPins} \
    {string data_pins} \
    {string cells} \
    {string library_set} \
    {string power} \
    {string ground}

cli::addCommand define_state_retention_cell \
    {rtcpf::defineRetentionCell} \
    {string cells} \
    {string cell_type} \
    {string always_on_pins} \
    {string restore_function} \
    {string save_function} \
    {string power_switchable} \
    {string ground_switchable} \
    {string power} \
    {string ground}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
