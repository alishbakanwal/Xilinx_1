<?xml version="1.0"?>
<Properties>
<!-- fileset: sources_1 -->
	<Property
		IseProperty="Verilog Include Directories"
		GroupType="fileset"
		GroupName="sources_1"
		Step="N/A"
		Option="verilog_dir"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Verilog Macros"
		GroupType="fileset"
		GroupName="sources_1"
		Step="N/A"
		Option="verilog_define"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Generics, Parameters"
		GroupType="fileset"
		GroupName="sources_1"
		Step="N/A"
		Option="vhdl_generic"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Macro Search Path"
		GroupType="fileset"
		GroupName="sources_1"
		Step="N/A"
		Option="edif_extra_search_paths"
		DeviceDependency="no">
	</Property>
<!-- xst -->
	<Property
		IseProperty="Optimization Goal"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-opt_mode"
		DeviceDependency="no">
		<ValueMap IseValue="Speed"	MappedValue="speed"/>
		<ValueMap IseValue="Area" 	MappedValue="area"/>
	</Property>
	<Property
		IseProperty="Optimization Effort"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-opt_level"
		DeviceDependency="no">
		<ValueMap IseValue="Normal" MappedValue="1"/>
		<ValueMap IseValue="High" 	MappedValue="2"/>
		<ValueMap IseValue="Fast" 	MappedValue="0"/>
	</Property>
	<Property
		IseProperty="Optimization Effort virtex6"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-opt_level"
		DeviceDependency="no">
		<ValueMap IseValue="Normal" MappedValue="1"/>
		<ValueMap IseValue="High" 	MappedValue="2"/>
		<ValueMap IseValue="Fast" 	MappedValue="0"/>
	</Property>
	<Property
		IseProperty="Optimization Effort spartan6"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-opt_level"
		DeviceDependency="no">
		<ValueMap IseValue="Normal" MappedValue="1"/>
		<ValueMap IseValue="High" 	MappedValue="2"/>
		<ValueMap IseValue="Fast" 	MappedValue="0"/>
	</Property>
	<Property
		IseProperty="Register Balancing"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-register_balancing"
		DeviceDependency="no">
		<ValueMap IseValue="No"       MappedValue="no"/>
		<ValueMap IseValue="Yes"      MappedValue="yes"/>
		<ValueMap IseValue="Forward"  MappedValue="forward"/>
		<ValueMap IseValue="Backward" MappedValue="backward"/>
	</Property>
	<Property
		IseProperty="FSM Encoding Algorithm"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-fsm_encoding"
		DeviceDependency="no">
		<ValueMap IseValue="Auto"       MappedValue="auto"/>
		<ValueMap IseValue="One-Hot"    MappedValue="one-hot"/>
		<ValueMap IseValue="Compact"    MappedValue="compact"/>
		<ValueMap IseValue="Sequential" MappedValue="sequential"/>
		<ValueMap IseValue="Gray"       MappedValue="gray"/>
		<ValueMap IseValue="Johnson"    MappedValue="johnson"/>
		<ValueMap IseValue="User"       MappedValue="user"/>
		<ValueMap IseValue="Speed1"     MappedValue="speed1"/>
	</Property>
	<Property
		IseProperty="LUT Combining Xst"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-lc"
		DeviceDependency="no">
		<ValueMap IseValue="No"   MappedValue="off"/>
		<ValueMap IseValue="Auto" MappedValue="auto"/>
		<ValueMap IseValue="Area" MappedValue="area"/>
	</Property>
	<Property
		IseProperty="Automatic BRAM Packing"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-auto_bram_packing"
		DeviceDependency="no">
		<ValueMap IseValue="true"  MappedValue="yes"/>
		<ValueMap IseValue="false" MappedValue="no"/>
	</Property>
	<Property
		IseProperty="Use DSP48"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-use_dsp48"
		DeviceDependency="no">
		<ValueMap IseValue="Auto" MappedValue="auto"/>
		<ValueMap IseValue="Yes"  MappedValue="yes"/>
		<ValueMap IseValue="No"   MappedValue="no"/>
	</Property>
	<Property
		IseProperty="Use DSP Block"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-use_dsp48"
		DeviceDependency="no">
		<ValueMap IseValue="Auto"    MappedValue="auto"/>
		<ValueMap IseValue="Automax" MappedValue="automax"/>
		<ValueMap IseValue="Yes"     MappedValue="yes"/>
		<ValueMap IseValue="No"      MappedValue="no"/>
	</Property>
	<Property
		IseProperty="Pack I/O Registers into IOBs"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-iob"
		DeviceDependency="no">
		<ValueMap IseValue="Auto"    MappedValue="auto"/>
		<ValueMap IseValue="Yes"     MappedValue="true"/>
		<ValueMap IseValue="No"      MappedValue="false"/>
	</Property>
	<Property
		IseProperty="RAM Style"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-ram_style"
		DeviceDependency="no">
		<ValueMap IseValue="Auto"        MappedValue="auto"/>
		<ValueMap IseValue="Distributed" MappedValue="distributed"/>
		<ValueMap IseValue="Block"       MappedValue="block"/>
	</Property>
	<Property
		IseProperty="Number of Clock Buffers"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-bufg"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Resource Sharing"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-resource_sharing"
		DeviceDependency="no">
		<ValueMap IseValue="true"  MappedValue="yes"/>
		<ValueMap IseValue="false" MappedValue="no"/>
	</Property>
	<Property
		IseProperty="Add I/O Buffers"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-iobuf"
		DeviceDependency="no">
		<ValueMap IseValue="true"  MappedValue="true"/>
		<ValueMap IseValue="false" MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Netlist Hierarchy"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-netlist_hierarchy"
		DeviceDependency="no">
		<ValueMap IseValue="As Optimized" MappedValue="as_optimized"/>
		<ValueMap IseValue="Rebuilt"      MappedValue="rebuilt"/>
	</Property>
	<Property
		IseProperty="Power Reduction"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-power"
		DeviceDependency="no">
		<ValueMap IseValue="false" MappedValue="no"/>
		<ValueMap IseValue="true"  MappedValue="yes"/>
	</Property>
	<Property
		IseProperty="Power Reduction Xst"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-power"
		DeviceDependency="no">
		<ValueMap IseValue="false" MappedValue="no"/>
		<ValueMap IseValue="true"  MappedValue="yes"/>
	</Property>
	<Property
		IseProperty="Equivalent Register Removal XST"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-equivalent_register_removal"
		DeviceDependency="no">
		<ValueMap IseValue="false" MappedValue="no"/>
		<ValueMap IseValue="true"  MappedValue="yes"/>
	</Property>
	<Property
		IseProperty="Equivalent Register Removal Map"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="-equivalent_register_removal"
		DeviceDependency="no">
		<ValueMap IseValue="false" MappedValue="no"/>
		<ValueMap IseValue="true"  MappedValue="yes"/>
	</Property>
	<Property
		IseProperty="Other XST Command Line Options"
		GroupType="run"
		GroupName="synth_1"
		Step="xst"
		Option="More Options"
		DeviceDependency="no">
	</Property>
<!-- ngdbuild -->
	<Property
		IseProperty="Create I/O Pads from Ports"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="-a"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Allow Unmatched LOC Constraints"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="-aul"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Allow Unmatched Timing Group Constraints"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="-aut"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Use LOC Constraints"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="-r"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="false"/>
		<ValueMap IseValue="false" 	MappedValue="true"/>
	</Property>
	<Property
		IseProperty="Allow Unexpanded Blocks"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="-u"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="User Rules File for Netlister Launcher"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="-ur"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Other Ngdbuild Command Line Options"
		GroupType="run"
		GroupName="impl_1"
		Step="ngdbuild"
		Option="More Options"
		DeviceDependency="no">
	</Property>
<!-- map -->
	<Property
		IseProperty="Use RLOC Constraints"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-ir"
		DeviceDependency="no">
		<ValueMap IseValue="Yes"				MappedValue="off"/>
		<ValueMap IseValue="No" 				MappedValue="all"/>
		<ValueMap IseValue="For Packing Only" 	MappedValue="place"/>
	</Property>
	<Property
		IseProperty="Starting Placer Cost Table (1-100)"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-t"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Starting Placer Cost Table (1-100) Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-t"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Starting Placer Cost Table (1-100) Spartan6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-t"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Starting Placer Cost Table (1-100) Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-t"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Starting Placer Cost Table (1-100) Map spartan6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-t"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Extra Cost Tables Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-xt"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Extra Cost Tables Map virtex6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-xt"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Placer Effort Level Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-ol"
		DeviceDependency="no">
		<ValueMap IseValue="None"		MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="Standard" 	MappedValue="std"/>
		<ValueMap IseValue="High" 		MappedValue="high"/>
	</Property>
	<Property
		IseProperty="Placer Extra Effort Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-xe"
		DeviceDependency="no">
		<ValueMap IseValue="None"					MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="Continue on Impossible"	MappedValue="c"/>
		<ValueMap IseValue="Normal" 				MappedValue="n"/>
	</Property>
	<Property
		IseProperty="Optimization Strategy (Cover Mode)"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-cm"
		DeviceDependency="no">
		<ValueMap IseValue="Area"		MappedValue="area"/>
		<ValueMap IseValue="Speed" 		MappedValue="speed"/>
		<ValueMap IseValue="Balanced" 	MappedValue="balanced"/>
		<ValueMap IseValue="Off" 		MappedValue="area"/>
	</Property>
	<Property
		IseProperty="Allow Logic Optimization Across Hierarchy"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-ignore_keep_hierarchy"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Map Slice Logic into Unused Block RAMs"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-bp"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="LUT Combining Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-lc"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="Auto" 	MappedValue="auto"/>
		<ValueMap IseValue="Area" 	MappedValue="area"/>
	</Property>
	<Property
		IseProperty="Register Ordering virtex6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-r"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="4" 		MappedValue="4"/>
		<ValueMap IseValue="8" 		MappedValue="8"/>
	</Property>
	<Property
		IseProperty="Timing Mode Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-ntd"
		DeviceDependency="no">
		<ValueMap IseValue="Performance Evaluation"		MappedValue=""/>
		<ValueMap IseValue="Non Timing Driven" 			MappedValue=""/>
	</Property>
	<Property
		IseProperty="Register Ordering spartan6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-r"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="4" 		MappedValue="4"/>
		<ValueMap IseValue="8" 		MappedValue="8"/>
	</Property>
	<Property
		IseProperty="Perform Timing-Driven Packing and Placement"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-timing"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Combinatorial Logic Optimization"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-logic_opt"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="on"/>
		<ValueMap IseValue="false" 	MappedValue="off"/>
	</Property>
	<Property
		IseProperty="Global Optimization map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-global_opt"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="Speed" 	MappedValue="speed"/>
	</Property>
	<Property
		IseProperty="Retiming"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-retiming"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="on"/>
		<ValueMap IseValue="false" 	MappedValue="off"/>
	</Property>
	<Property
		IseProperty="Retiming Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-retiming"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="on"/>
		<ValueMap IseValue="false" 	MappedValue="off"/>
	</Property>
	<Property
		IseProperty="Register Duplication"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-register_duplication"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="false"/>
		<ValueMap IseValue="On" 	MappedValue="true"/>
	</Property>
	<Property
		IseProperty="Register Duplication Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-register_duplication"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="false"/>
		<ValueMap IseValue="On" 	MappedValue="true"/>
	</Property>
	<Property
		IseProperty="Power Reduction Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-power"
		DeviceDependency="no">
		<ValueMap IseValue="false"		MappedValue="off"/>
		<ValueMap IseValue="true"		MappedValue="on"/>
	</Property>
	<Property
		IseProperty="Power Reduction Map spartan6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-power"
		DeviceDependency="no">
		<ValueMap IseValue="Off" 			MappedValue="off"/>
		<ValueMap IseValue="On"				MappedValue="on"/>
		<ValueMap IseValue="High"			MappedValue="high"/>
		<ValueMap IseValue="Extra Effort"	MappedValue="xe"/>
	</Property>
	<Property
		IseProperty="Power Reduction Map virtex6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-power"
		DeviceDependency="no">
		<ValueMap IseValue="Off" 			MappedValue="off"/>
		<ValueMap IseValue="On"				MappedValue="on"/>
		<ValueMap IseValue="High"			MappedValue="high"/>
		<ValueMap IseValue="Extra Effort"	MappedValue="xe"/>
	</Property>
	<Property
		IseProperty="Trim Unconnected Signals"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-u"
		DeviceDependency="no">
		<ValueMap IseValue="true"		MappedValue="false"/>
		<ValueMap IseValue="false"		MappedValue="true"/>
	</Property>
	<Property
		IseProperty="Pack I/O Registers/Latches into IOBs"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-pr"
		DeviceDependency="no">
		<ValueMap IseValue="Off"					MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="For Inputs Only"		MappedValue="i"/>
		<ValueMap IseValue="For Outputs Only"		MappedValue="o"/>
		<ValueMap IseValue="For Inputs and Outputs"	MappedValue="b"/>
	</Property>
	<Property
		IseProperty="Enable Multi-Threading"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-mt"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="2"		MappedValue="on"/>
	</Property>
	<Property
		IseProperty="Power Activity File Map"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-activityfile"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Power Activity File Map spartan6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-activityfile"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Power Activity File Map virtex6"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="-activityfile"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Other Map Command Line Options"
		GroupType="run"
		GroupName="impl_1"
		Step="map"
		Option="More Options"
		DeviceDependency="no">
	</Property>
<!-- par -->
	<Property
		IseProperty="Place &amp; Route Effort Level (Overall)"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-ol"
		DeviceDependency="no">
		<ValueMap IseValue="None"		MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="Standard" 	MappedValue="std"/>
		<ValueMap IseValue="High" 		MappedValue="high"/>
	</Property>
	<Property
		IseProperty="Placer Effort Level (Overrides Overall Level)"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-pl"
		DeviceDependency="no">
		<ValueMap IseValue="None"		MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="Standard" 	MappedValue="std"/>
		<ValueMap IseValue="High" 		MappedValue="high"/>
	</Property>
	<Property
		IseProperty="Router Effort Level (Overrides Overall Level)"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-rl"
		DeviceDependency="no">
		<ValueMap IseValue="None"		MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="Standard" 	MappedValue="std"/>
		<ValueMap IseValue="High" 		MappedValue="high"/>
	</Property>
	<Property
		IseProperty="Extra Effort (Highest PAR level only)"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-xe"
		DeviceDependency="no">
		<ValueMap IseValue="None"		MappedValue="&lt;none&gt;"/>
		<ValueMap IseValue="Standard" 	MappedValue="c"/>
		<ValueMap IseValue="High" 		MappedValue="n"/>
	</Property>
	<Property
		IseProperty="Ignore User Timing Constraints Par"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-x"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Starting Placer Cost Table (1-100) Par"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-t"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Power Reduction Par"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-power"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="on"/>
		<ValueMap IseValue="false" 	MappedValue="off"/>
	</Property>
	<Property
		IseProperty="Timing Mode Par"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-ntd"
		DeviceDependency="no">
		<ValueMap IseValue="Performance Evaluation"		MappedValue=""/>
		<ValueMap IseValue="Non Timing Driven" 			MappedValue=""/>
	</Property>
	<Property
		IseProperty="Enable Multi-Threading par virtex5"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-mt"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="2"		MappedValue="2"/>
		<ValueMap IseValue="3"		MappedValue="3"/>
		<ValueMap IseValue="4"		MappedValue="4"/>
	</Property>
	<Property
		IseProperty="Enable Multi-Threading par spartan6"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-mt"
		DeviceDependency="no">
		<ValueMap IseValue="Off"	MappedValue="off"/>
		<ValueMap IseValue="2"		MappedValue="2"/>
		<ValueMap IseValue="3"		MappedValue="3"/>
		<ValueMap IseValue="4"		MappedValue="4"/>
	</Property>
	<Property
		IseProperty="Power Activity File"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-activityfile"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Power Activity File Par"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="-activityfile"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Other Place &amp; Route Command Line Options"
		GroupType="run"
		GroupName="impl_1"
		Step="par"
		Option="More Options"
		DeviceDependency="no">
	</Property>
<!-- trce -->
	<Property
		IseProperty="Report Fastest Path(s) in Each Constraint"
		GroupType="run"
		GroupName="impl_1"
		Step="trce"
		Option="-fastpaths"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Report Fastest Path(s) in Each Constraint Post Trace"
		GroupType="run"
		GroupName="impl_1"
		Step="trce"
		Option="-fastpaths"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Generate Datasheet Section Post Trace"
		GroupType="run"
		GroupName="impl_1"
		Step="trce"
		Option="-nodatasheet"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Report Unconstrained Paths"
		GroupType="run"
		GroupName="impl_1"
		Step="trce"
		Option="-u"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Report Unconstrained Paths Post Trace"
		GroupType="run"
		GroupName="impl_1"
		Step="trce"
		Option="-u"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Number of Paths in Error/Verbose Report Post Trace"
		GroupType="run"
		GroupName="impl_1"
		Step="trce"
		Option="-v"
		DeviceDependency="no">
	</Property>
<!-- bitgen -->
	<Property
		IseProperty="Run Design Rules Checker (DRC)"
		GroupType="run"
		GroupName="impl_1"
		Step="bitgen"
		Option="-d"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="false"/>
		<ValueMap IseValue="false" 	MappedValue="true"/>
	</Property>
	<Property
		IseProperty="Create Bit File"
		GroupType="run"
		GroupName="impl_1"
		Step="bitgen"
		Option="-j"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="false"/>
		<ValueMap IseValue="false" 	MappedValue="true"/>
	</Property>
	<Property
		IseProperty="Create ASCII Configuration File"
		GroupType="run"
		GroupName="impl_1"
		Step="bitgen"
		Option="-b"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Create Logic Allocation File"
		GroupType="run"
		GroupName="impl_1"
		Step="bitgen"
		Option="-l"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Create Mask File"
		GroupType="run"
		GroupName="impl_1"
		Step="bitgen"
		Option="-m"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Other Bitgen Command Line Options"
		GroupType="run"
		GroupName="impl_1"
		Step="bitgen"
		Option="More Options"
		DeviceDependency="no">
	</Property>
<!-- isim -->
	<Property
		IseProperty="Specify 'define Macro Name and Value"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="verilog_define"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Simulation Run Time ISim"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="runtime"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Incremental Compilation"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="fuse.incremental"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Compile for HDL Debugging"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="fuse.nodebug"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Value Range Check"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="fuse.range_check"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Custom Project Filename"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="fuse_custom_prj"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Custom Waveform Configuration File Behav"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="isim.wcfg"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Custom Simulation Command File"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="isim.cmdfile"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Load glbl"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="fuse.load_glbl"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Specify Top Level Instance Names Behavioral"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="top"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="ISim UUT Instance Name"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="unit_under_test"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Delay Values To Be Read from SDF"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="isim.sdf_delay"
		DeviceDependency="no">
		<ValueMap IseValue="Setup Time"	MappedValue="sdfmax"/>
		<ValueMap IseValue="Hold Time" 	MappedValue="sdfmin"/>
	</Property>
	<Property
		IseProperty="Other Compiler Options"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="fuse.more_options"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Other Simulator Commands Behavioral"
		GroupType="fileset"
		GroupName="sim_1"
		Step="isim"
		Option="isim.more_options"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Simulation Model Target"
		GroupType="fileset"
		GroupName="sim_1"
		Step="netgen"
		Option="ng.output_hdl_format"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Retain Hierarchy"
		GroupType="fileset"
		GroupName="sim_1"
		Step="netgen"
		Option="ng.retain_hierarchy"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
	<Property
		IseProperty="Rename Top Level Module To"
		GroupType="fileset"
		GroupName="sim_1"
		Step="netgen"
		Option="ng.rename_top"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Other NETGEN Command Line Options"
		GroupType="fileset"
		GroupName="sim_1"
		Step="netgen"
		Option="ng.more_netgen_options"
		DeviceDependency="no">
	</Property>
	<Property
		IseProperty="Generate Architecture Only (No Entity Declaration)"
		GroupType="fileset"
		GroupName="sim_1"
		Step="netgen"
		Option="ng.gen_arch_only"
		DeviceDependency="no">
		<ValueMap IseValue="true"	MappedValue="true"/>
		<ValueMap IseValue="false" 	MappedValue="false"/>
	</Property>
<!-- Special properties -->
	<Property
		IseProperty="Project Generator"
		GroupType="N/A"
		GroupName="N/A"
		Step="N/A"
		Option="N/A"
		DeviceDependency="no">
	</Property>
</Properties>
