# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2008
#                             All rights reserved.
# ****************************************************************************

rt::UMsgHandler_disable PARAM 100
if {[rt::UParam_get lutSize 0] != ""} {
    # make sure that 'rt_tool_name' is set to 'realTimeFpga' - as many other 
    # tcl files keyoff on this name for FPGA v/s ASIC flow - sbhatia
    set rt_tool_name realTimeFpga; # do not change this line - see above
    set tclPath $env(RT_TCL_PATH)
    set tclExt tcl
} else {
    set rt_tool_name realTime
    set tclPath $env(RT_LIBPATH)/share/tcl
    set tclExt odb
}

rt::UMsgHandler_enable PARAM 100

# Process command line parameters
source ${tclPath}/cmdline.$tclExt

# Setting logfilename
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " log" }
source ${tclPath}/log.$tclExt

# Loading prompt
if { [info exists ::env(XILINX_REALTIMEFPGA)] } {
    rt::UMsg_print " prompt"
    if {$tcl_version == "8.4"} {
        set ::tcl_prompt1_string {return "\[$rt_tool_name\]$ "}
    } else {
        set ::tcl_prompt1 {puts -nonewline stdout "\[$rt_tool_name\]$ "}
    }
}

# Loading utils
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " utils" }
source ${tclPath}/utils.$tclExt

# Loading config
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " config" }
source ${tclPath}/config.$tclExt

# Loading sdc
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " sdc" }
source ${tclPath}/sdc.$tclExt
source ${tclPath}/dc.$tclExt

# Loading cli
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " cli" }
source ${tclPath}/cli.$tclExt

# Loading commands
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " commands" }
source ${tclPath}/commands.$tclExt

# from now on source has been renamed to tcl_source

set prog [rt::UParam_get program 0]
if {$rt_tool_name != "realTimeFpga"} {

    # Loading verify
    rt::UMsg_print " verify"
    tcl_source ${tclPath}/verify_hier.$tclExt

    # Loading dft
    rt::UMsg_print " dft"
    tcl_source ${tclPath}/dft.$tclExt
    tcl_source ${tclPath}/dftdc.$tclExt

    # Loading ctl
    rt::UMsg_print " ctl"
    tcl_source ${tclPath}/ctl_parse.$tclExt

    # Loading edit
    rt::UMsg_print " edit"
    tcl_source ${tclPath}/edit.$tclExt

    # Loading upf/cpf
    rt::UMsg_print " upf/cpf"
    tcl_source ${tclPath}/upf.$tclExt
    tcl_source ${tclPath}/cpf.$tclExt

    # Loading captable
    rt::UMsg_print " captable"
    tcl_source ${tclPath}/atop.$tclExt
    tcl_source ${tclPath}/soce.$tclExt

    # Loading beta
    rt::UMsg_print " beta"
    tcl_source ${tclPath}/beta.$tclExt

}

# Loading dir
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " dir" }
tcl_source ${tclPath}/dir.$tclExt

# Load internal startup file
if [file exist "$env(RT_TCL_PATH)/internal/realTime.tcl"] {
    if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " \nLoading $env(RT_TCL_PATH)/internal/realTime.tcl:" }
    tcl_source $env(RT_TCL_PATH)/internal/realTime.tcl
}

# Finished loading init stuff
rt::UMsg_print "\n"

# Eval arguments specified on the command line using -e option
if { $rt::cmd_line_eval != "" } {
    rt::UMsg_print "Executing command line script: \"$::cmd_line_eval\"\n"
    if {[catch "eval $::cmd_line_eval" msg]} {
	puts $msg
	exit -1
    }
}

# Loading global system startup file
if {[info exist env(RT_INIT_FILE)] && [file exist $env(RT_INIT_FILE)]} {
    rt::UMsg_print "\n"
    rt::UMsg_print "Loading $env(RT_INIT_FILE):"
    tcl_source $env(RT_INIT_FILE)
}

if {$rt::cmd_line_no_init == 0} {
	# Loading global user startup file
	if [file exist "~/.oasys/realTime.tcl"] {
	    rt::UMsg_print "\n"
	    rt::UMsg_print "Loading ~/.oasys/realTime.tcl:"
	    tcl_source ~/.oasys/realTime.tcl
    }

	# Load local user startup file
	if [file exist "./realTime.tcl"] {
	    rt::UMsg_print "\n"
	    rt::UMsg_print "Loading ./realTime.tcl:"
	    tcl_source ./realTime.tcl
    }
}

# Set interrupt script
set env(RT_INTERUPT) [file normalize "~/.oasys/realTime-interrupt.tcl"]

# Check env vars for param settings
foreach nm [array names env] {
    if [string match RT_UParam_* $nm] {
	set p [string range $nm 10 end]
	set v $env($nm)
	if {[rt::UParam_set $p $v] == 0} {
	    exit -1
	}
    }
}

# source remaining files
if [info exist rt::cmd_line_sources] {
    foreach src $rt::cmd_line_sources {
	puts "Loading command line file: $src"
	if {[catch "source $rt::cmd_line_echo $src" msg]} {
	    puts $msg
	    exit -1
	}
    }
    if {$rt::cmd_line_no_exit == 0} {
	exit 0
    }
}
# Finished loading stuff
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print "\n" }
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print "realtime tcl init completed.\n" }

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
