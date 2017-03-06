package require tcf

namespace eval ::sdk {
    variable version 0.1
    variable sdk_workspace ""
    variable sdk_chan ""
    variable server_props ""
    variable sdk_conn_status ""
    variable help_prefix ""
    variable plx_install ""
    if { [string first "xsdb" [file tail [info nameofexecutable]]] != -1 } {
	set help_prefix "sdk "
    }

    proc sdk_conn_handler { conn } {
	variable sdk_chan
	variable sdk_conn_status

	set sdk_conn_status [dict get $conn state]
	set sdk_chan [dict get $conn chan]
    }

    proc sdk_disconn_handler {} {
	variable sdk_chan
	variable server_props
	variable sdk_conn_status

	set sdk_conn_status ""
	set sdk_chan ""
	set server_props ""
    }

    proc sdk_command_handler { data } {
	variable sdk_cmd_result
	set sdk_cmd_result $data
    }

    proc xsdk_eval { chan service cmd argfmt resfmt arglist } {
	variable sdk_cmd_result
	if { [info exists sdk_cmd_result] } {
	    error "sdk command already in progress"
	}
	catch {
	    set sdk_cmd_result pending
	    set arg [dict create chan $chan service $service cmd $cmd argfmt $argfmt resfmt $resfmt arglist $arglist]
	    ::tcf::sync_eval [list sdk_command_eval_client $arg]
	    vwait ::sdk::sdk_cmd_result
	    set sdk_cmd_result
	} msg opt
	unset sdk_cmd_result
	if { [::xsdb::dict_get_safe $msg err] != "" } {
	    error [dict get $msg err]
	}
	return -options $opt [::xsdb::dict_get_safe $msg data]
    }

    proc xsdb_command_handler {} {
	foreach command [::tcf::sync_eval get_xsdb_command_table] {
	    set chan [lindex $command 0]
	    set token [lindex $command 1]
	    set script [lindex $command 2]
	    if { [catch [list namespace eval :: $script] msg] } {
		::tcf::sync_eval [list ::tcf::send_reply $chan $token "es" [list $msg {}]]
	    } else {
		::tcf::sync_eval [list ::tcf::send_reply $chan $token "es" [list {} $msg]]
	    }
	}
    }

    proc getsdkchan {} {
	variable sdk_chan
	variable sdk_workspace
	variable server_props
	variable sdk_conn_status

	check_sdk_workspace
	if { $sdk_chan == "" } {
	    if { [catch {
		set server_props [::tcf::sync_eval {
		    variable server_connection

		    proc get_xsdb_command_table {} {
			variable xsdb_command_table
			if { [info exists xsdb_command_table] } {
			    set ret $xsdb_command_table
			    unset xsdb_command_table
			} else {
			    set ret {}
			}
			return $ret
		    }

		    proc xsdb_eval {chan token} {
			variable xsdb_command_table
			if { [catch {::tcf::read $chan s} data] } {
			    puts "xsdb_eval error $token $data"
			    ::tcf::disconnect $chan [list eval_event {puts "Channel closed"}]
			    return
			}

			if { ![info exists xsdb_command_table] } {
			    eval_event ::sdk::xsdb_command_handler
			}
			lappend xsdb_command_table [list $chan $token [lindex $data 0]]
		    }

		    proc xsdb_after {chan token} {
			if { [catch {::tcf::read $chan i} data] } {
			    puts "xsdb_eval error $token $data"
			    ::tcf::disconnect $chan [list eval_event {puts "Channel closed"}]
			    return
			}

			::tcf::post_event [list ::tcf::send_reply $chan $token "e" [list {}]] $data
		    }

		    proc xsdb_abort {chan token} {
			if { [catch {::tcf::read $chan {}} data] } {
			    puts "xsdb_eval error $token $data"
			    ::tcf::disconnect $chan [list eval_event {puts "Channel closed"}]
			    return
			}

			::tcf::generate_interrupt
			::tcf::send_reply $chan $token "e" [list {}]
		    }

		    proc server_connection_callback {type data} {
			variable server_connection
			switch $type {
			    start {
				if { [info exists server_connection] } {
				    puts "CLI already connected"
				    ::tcf::disconnect $data {apply {{} {}}}
				    return
				}
				dict set server_connection chan $data
				::tcf::on_command $data xsdb eval [list xsdb_eval $data]
				::tcf::on_command $data xsdb after [list xsdb_after $data]
				::tcf::on_command $data xsdb abort [list xsdb_abort $data]
				::tcf::on_disconnect $data {
				    variable server_connection
				    unset server_connection
				    eval_event {::sdk::sdk_disconn_handler}
				}
			    }
			    error -
			    connect {
				dict set server_connection state $type
				eval_event [list ::sdk::sdk_conn_handler $server_connection]
			    }
			}
		    }
		    set serverid [::tcf::server_start tcp:localhost:0 server_connection_callback]
		    set props [::tcf::get_server_properties $serverid]
		    return $props
		}]
	    } msg] } {
		error $msg
	    }
	    puts -nonewline "Starting SDK. This could take few seconds... "
	    flush stdout
	    exec xsdk -eclipseargs --launcher.suppressErrors -nosplash -application com.xilinx.sdk.cmdline.service \
		 [dict get $server_props Port] -data $sdk_workspace -vmargs -Dorg.eclipse.cdt.core.console=org.eclipse.cdt.core.systemConsole &

	    after $::xsdb::sdk_launch_timeout {set ::sdk::sdk_conn_status "timeout"}
	    vwait ::sdk::sdk_conn_status
	    switch $sdk_conn_status {
		connect {
		    puts "done"
		}
		error {
		    sdk_disconn_handler
		    error "TCF connection error"
		}
		timeout {
		    sdk_disconn_handler
		    error "timeout while establishing a connection with SDK"
		}
	    }
	}
	return $sdk_chan
    }

    proc check_sdk_workspace {} {
	variable sdk_workspace
	if { [string compare $sdk_workspace ""] == 0 } {
	    error "invalid workspace. set workspace using setws command"
	}
    }

    proc create_project {args} {
	puts "\nNote:: \"create_project\" command is Deprecated. Use \"sdk createhw\", \
	     \"sdk createbsp\" and \"sdk createapp\" commands"
	set options {
	    {type "project type" {default "hw" args 1}}
	    {name "project name" {args 1}}
	    {app "application template" {default {Hello World} args 1}}
	    {proc "target processor" {args 1}}
	    {hwspec "hwspecification file" {args 1}}
	    {hwproject "hwproject name" {args 1}}
	    {bsp "bsp project name" {default "" args 1}}
	    {os "project OS" {default "standalone" args 1}}
	    {lang "project launguage" {default "c" args 1}}
	    {mss "MSS File Path" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [lindex [info level 0] 0]]
	}

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}

	switch $params(type) {
	    hw {
		if { ![info exists params(hwspec)] } {
		    error "specify a HW specification file to create hw project"
		}
		if { [info exists params(hwproject)] || [info exists params(proc)] } {
		    error "extra args with -hw option"
		}
		return [create_hw_project -name $params(name) -hwspec $params(hwspec)]
	    }
	    bsp {
		if { ![info exists params(hwproject)] } {
		    error "specify a hwproject name to create a BSP project"
		}

		if { [info exists params(mss)] } {
		    if { [file isfile $params(mss)] == 0} {
			error "invalid mss file path"
		    }
		} elseif { ![info exists params(proc)] } {
		    error "specify a processor instance to create a BSP project"
		}

		if { [info exists params(hwspec)] } {
		    error "extra args with -bsp option"
		}
		if { [info exists params(mss)] } {
		    return [create_bsp_project -name $params(name) -hwproject $params(hwproject) \
			    -mss $params(mss)]
		} else {
		    return [create_bsp_project -name $params(name) -hwproject $params(hwproject) \
			    -proc $params(proc) -os $params(os)]
		}
	    }
	    app {
		if { ![info exists params(hwproject)] } {
		    error "specify a hwproject name to create an application project"
		}
		if { ![info exists params(proc)] } {
		    error "specify a processor instance to create an application project"
		}
		if { [info exists params(hwspec)] } {
		    error "extra args with -app option"
		}
		if { [string compare -nocase $params(os) "Linux"] == 0 } {
		    if { $params(bsp) != "" } {
			puts "WARNING: BSP is not required for Linux applications"
		    }
		} else {
		    if { $params(bsp) == "" } {
			set params(bsp) "$params(name)_bsp"
		    }
		}
		return [create_app_project -name $params(name) -hwproject $params(hwproject) \
			    -proc $params(proc) -os $params(os) -lang $params(lang) -app $params(app) -bsp $params(bsp)]
	    }
	    default {
		error "unknown project type $params(type)"
	    }
	}
    }
    namespace export create_project


    proc set_workspace { args } {
	puts "\nNote:: \"set_workspace\" command is Deprecated. Use \"setws\" command"
	return [setws {*}$args]
    }
    namespace export set_workspace

    proc get_workspace { args } {
	puts "\nNote:: \"get_workspace\" command is Deprecated. Use \"getws\" command"
	return [getws {*}$args]
    }
    namespace export get_workspace

    proc create_hw_project { args } {
	puts "\nNote:: \"create_hw_project\" command is Deprecated. Use \"createhw\" command"
	return [createhw {*}$args]
    }
    namespace export create_hw_project

    proc create_bsp_project { args } {
	puts "\nNote:: \"create_bsp_project\" command is Deprecated. Use \"createbsp\" command"
	return [createbsp {*}$args]
    }
    namespace export create_bsp_project

    proc create_app_project { args } {
	puts "\nNote:: \"create_app_project\" command is Deprecated. Use \"createapp\" command"
	return [createapp {*}$args]
    }
    namespace export create_app_project

    proc import_projects { args } {
	puts "\nNote:: \"import_projects\" command is Deprecated. Use \"importprojects\" command"
	return [importprojects {*}$args]
    }
    namespace export import_projects

    proc import_sources { args } {
	puts "\nNote:: \"import_sources\" command is Deprecated. Use \"importsources\" command"
	return [importsources {*}$args]
    }
    namespace export import_sources

    proc get_projects { args } {
	puts "\nNote:: \"get_projects\" command is Deprecated. Use \"getprojects\" command"
	return [getprojects {*}$args]
    }
    namespace export get_projects

    proc delete_projects { args } {
	puts "\nNote:: \"delete_projects\" command is Deprecated. Use \"deleteprojects\" command"
	return [deleteprojects {*}$args]
    }
    namespace export delete_projects

    proc build_project { args } {
	puts "\nNote:: \"build_project\" command is Deprecated. Use \"projects -build\" command"
	return [projects -build {*}$args]
    }
    namespace export build_project

    proc clean_project { args } {
	puts "\nNote:: \"clean_project\" command is Deprecated. Use \"projects -clean\" command"
	return [projects -clean {*}$args]
    }
    namespace export clean_project

    proc set_user_repo_path {args} {
	puts "\nNote:: \"set_user_repo_path\" command is Deprecated. Use \"repo -set\" command"
	return [set_user_repo_path_sdk $args]
    }
    namespace export set_user_repo_path

    proc get_user_repo_path {args} {
	puts "\nNote:: \"get_user_repo_path\" command is Deprecated. Use \"repo -get\" command"
	return [get_user_repo_path_sdk $args]
    }
    namespace export get_user_repo_path

    proc setws { args } {
	variable sdk_workspace
	variable sdk_chan
	variable help_prefix

	set options {
	    {switch "switch to new workspace"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}
	if { ![info exists params(path)] } {
	    if { [llength $args] > 0 } {
		set params(path) [lindex $args 0]
		set args [lrange $args 1 end]
	    } else {
		set params(path) [pwd]
	    }
	}
	if { [llength $args] } {
	    error "unexpected arguments: $args"
	}

	if {[file isfile $params(path)]} {
	    error "$params(path) is a file"
	} elseif {![file isdirectory $params(path)]} {
	    if { [catch { file mkdir $params(path) } msg ] } {
		error $msg
	    }
	}

	set params(path) [file normalize $params(path)]
	if { $sdk_workspace != "" && $sdk_chan != "" && $sdk_workspace != $params(path) } {
	    if { !$params(switch) } {
		error "workspace is already set. use -switch option to switch to new workspace"
	    }
	    ::xsdb::disconnect $sdk_chan
	    vwait ::sdk::sdk_conn_status
	}
	set sdk_workspace $params(path)
	return
    }
    namespace export setws
    ::xsdb::setcmdmeta setws categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta setws brief {Set SDK workspace} [subst $help_prefix]
    ::xsdb::setcmdmeta setws description [subst {
SYNOPSIS {
    [concat $help_prefix setws] \[OPTIONS\] \[path\]
        Set SDK workspace to <path>, for creating projects.
        If <path> doesn't exist, then the directory is created.
        If <path> is not specified, then current directory is used.
}
OPTIONS {
    -switch <path>
        Close existing workspace and switch to new workspace
}
RETURNS {
    Nothing if the workspace is set successfully.
    Error string, if the path specified is a file.
}
EXAMPLE {
    setws /tmp/wrk/wksp1
       Set the current workspace to /tmp/wrk/wksp1.

    setws -switch /tmp/wrk/wksp2
       Close the current workspace and switch to new workspace /tmp/wrk/wksp2.
}
}] [subst $help_prefix]

    proc getws { args } {
        variable sdk_workspace
	variable help_prefix
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

        return $sdk_workspace
    }
    namespace export getws
    ::xsdb::setcmdmeta getws categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta getws brief {Get SDK workspace} [subst $help_prefix]
    ::xsdb::setcmdmeta getws description [subst {
SYNOPSIS {
    [concat $help_prefix getws]
        Return the current SDK workspace
}
RETURNS {
    Current workspace
}
}] [subst $help_prefix]

    proc set_user_repo_path_sdk {args} {
	variable help_prefix
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { [llength $args] != 1 } {
	    error "wrong # args: should be \"sdk set_user_repo_path path\""
	}
	set repo_path [lindex $args 0]
	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" "setRepo" "o{Path s}" e [list [dict create Path [file normalize $repo_path]]]
	return
    }

    proc get_user_repo_path_sdk { args } {
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	set chan [getsdkchan]
	return [xsdk_eval $chan "Xsdk" getRepo "" s [list]]
    }


    proc get_app_templates {args} {
	puts "\nNote:: \"get_app_templates\" command is Deprecated. Use \"repo -apps\" command"
	variable help_prefix
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	return [::hsi::utils::get_all_app_details]
    }
    namespace export get_app_templates


    proc createhw {args} {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {name "project name" {args 1}}
	    {hwspec "hw specification file" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}

	if { ![info exists params(hwspec)] } {
	    error "HW specification file not specified"
	}
	set params(hwspec) [file normalize $params(hwspec)]
	set fmt [dict create Type s Name s HwSpec s]
	set data [dict create Type hw Name $params(name) HwSpec $params(hwspec)]
	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" createProject "o{$fmt}" e [list $data]
	return
    }
    namespace export createhw
    ::xsdb::setcmdmeta createhw categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta createhw brief {Create a hw project} [subst $help_prefix]
    ::xsdb::setcmdmeta createhw description [subst {
SYNOPSIS {
    [concat $help_prefix createhw] \[OPTIONS\]
        Create a hw project from a HW specification file
}
OPTIONS {
    -name <project-name>
        Project name that should be created

    -hwspec <HW specfiction file>
        HW specification file for creating a hw project
}
RETURNS {
    Nothing, if the HW project is created successfully.
    Error string, if invalid options are used or if the project can't be created.
}
EXAMPLE {
    createhw -name hw1 -hwspec system.hdf
        Create a hardware project with name hw1 from the hardware specification
        file system.hdf
}
}] [subst $help_prefix]

    proc updatehw {args} {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {hw "hardware project" {args 1}}
	    {newhwspec "new hw specification file" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { ![info exists params(hw)] } {
	    error "hw project not specified"
	}

	if { ![info exists params(newhwspec)] } {
	    error "new hw specification file not specified"
	}
	set params(newhwspec) [file normalize $params(newhwspec)]
	set fmt [dict create Name s HwSpec s]
	set data [dict create Name $params(hw) HwSpec $params(newhwspec)]
	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" changeHwSpec "o{$fmt}" e [list $data]
	return
    }
    namespace export updatehw
    ::xsdb::setcmdmeta updatehw categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta updatehw brief {Update a hw project} [subst $help_prefix]
    ::xsdb::setcmdmeta updatehw description [subst {
SYNOPSIS {
    [concat $help_prefix updatehw] \[OPTIONS\]
        Update a hw project with the changes in the new HW specification file
}
OPTIONS {
    -hw <hw-project>
        Hardware project that should be updated

    -newhwspec <hw specfiction file>
        New hw specification file for updating the hw project
}
RETURNS {
    Nothing, if the HW project is updated successfully.
    Error string, if invalid options are used or if the project can't be updated.
}
EXAMPLE {
    updatehw -hw hw1 -newhwspec system.hdf
        Update the hardware project hw1 with the changes in the new hardware
        specification file system.hdf
}
}] [subst $help_prefix]

    proc createbsp {args} {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {name "project name" {args 1}}
	    {proc "target processor" {args 1}}
	    {hwproject "hwproject name" {args 1}}
	    {mss "MSS File Path" {args 1}}
	    {os "project OS" {default "standalone" args 1}}
	    {arch "32/64 bit" {default "" args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}

	if { ![info exists params(hwproject)] } {
	    error "specify a hw project to create a BSP project"
	}

	if { [info exists params(mss)] } {
	    set params(mss) [file normalize $params(mss)]
	    if { [file isfile $params(mss)] == 0} {
		error "invalid mss file path"
	    }
	    if { [info exists params(proc)] || [info exists params(arch)] || [info exists params(os)] } {
		puts "WARNING: ignoring proc/arch/os details, when mss file is passed"
	    }
	} else {
	    if { ![info exists params(proc)] } {
		error "specify a processor instance or a mss file to create a BSP project"
	    } else {
		if { ($params(arch) == 32) || ($params(arch) == 64) || ($params(arch) == "") } {
		    if { [string match "psu_cortexa53*" $params(proc)] } {
			if { $params(arch) == "" } {
			    set params(arch) 64
			}
		    } else {
			if { $params(arch) == 64 } {
			    puts "WARNING: $params(arch)-bit not supported for the processor type - $params(proc). Setting 32-bit"
			}
			set params(arch) 32
		    }
		} else {
		    error "illegal arch type $params(arch). must be 32/64"
		}
	    }
	}

	if { [info exists params(mss)] } {
	    set fmt [dict create Type s Name s HwProject s Mss s]
	    set data [dict create Type bsp Name $params(name) HwProject $params(hwproject) Mss $params(mss)]
	} else {
	    set fmt [dict create Type s Name s HwProject s Proc s Os s ArchType s]
	    set data [dict create Type bsp Name $params(name) HwProject $params(hwproject) Proc $params(proc) Os $params(os) ArchType $params(arch)]
	}
	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" createProject "o{$fmt}" e [list $data]
	return
    }
    namespace export createbsp
    ::xsdb::setcmdmeta createbsp categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta createbsp brief {Create a bsp project} [subst $help_prefix]
    ::xsdb::setcmdmeta createbsp description [subst {
SYNOPSIS {
    [concat $help_prefix createbsp] \[OPTIONS\]
        Create a bsp project
}
OPTIONS {
    -name <project-name>
        Project name that should be created

    -proc <processor-name>
        Processor instance that should be used for creating bsp project.

    -hwproject <hw project name>
        HW project for which the application or bsp project should be created.

    -os <OS name>
        OS type for the application project.
        Default type is standalone

    -mss <MSS File path>
        MSS File path for creating BSP.
        This option can be used for creating a BSP from user mss file.
        When mss file is specified, then processor and os options will be
        ignored and processor/os details are extracted from mss file.

    -arch <arch-type>
        Processor architecture, <arch-type> can be 32 or 64
        This option is used to build the project with 32/64 bit toolchain.
        This is valid only for A53 processors, defaults to 32-bit for other
        processors.
}
RETURNS {
    Nothing, if the BSP project is created successfully.
    Error string, if invalid options are used or if the project can't be
    created.
}
EXAMPLE {
    createbsp -name bsp1 -hwproject hw1 -proc ps7_cortexa9_0
        Create a BSP project with name bsp1 from the hardware project hw1 for
        processor 'ps7_cortexa9_0'

    createbsp -name bsp1 -hwproject hw1 -proc ps7_cortexa9_0 -os standalone
        Create a BSP project with name bsp1 from the hardware project hw1 for
        processor 'ps7_cortexa9_0' and standalone os.

    createbsp -name bsp1 -hwproject hw1 -mss system.mss
        Create a BSP project with name bsp1 with all the details from
        system.mss

    createbsp -name bsp1 -hwproject hw1 -proc psu_cortexa53_0 -arch 32
        Create a BSP project with name bsp1 for psu_cortexa53_0 using a 32 bit
        tool chain.
}
}] [subst $help_prefix]

    proc createapp {args} {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {name "project name" {args 1}}
	    {app "application template" {default {Hello World} args 1}}
	    {proc "target processor" {args 1}}
	    {hwproject "hwproject name" {args 1}}
	    {bsp "bsp project name" {default "" args 1}}
	    {os "project OS" {default "standalone" args 1}}
	    {lang "project launguage" {default "c" args 1}}
	    {arch "32/64 bit" {default "" args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	set appfound 0
	if { ![info exists params(name)] } {
	    error "project name not specified"
	} else {
	    if { [string compare -nocase $params(lang) "C"] == 0 } {
		set applist [::hsi::utils::get_all_app_details -dict]
		dict for {app details} $applist {
		    set name [dict get $details userdefname]
		    if { $params(app) == $name } {
			set appfound 1
			break;
		    }
		}
		if { $appfound == 0 } {
		    error "$params(app) is not valid application template name\nplease use repo -apps to get the available templates"
		}
	    }
	}

	if { ![info exists params(hwproject)] } {
	    error "specify a hwproject name to create an application project"
	}
	if { ![info exists params(proc)] } {
	    error "specify a processor instance to create an application project"
	}
	if { [string compare -nocase $params(os) "Linux"] == 0 } {
	    if { $params(bsp) != "" } {
		puts "WARNING: BSP is not required for Linux applications"
	    }
	} else {
	    if { $params(bsp) == "" } {
		set params(bsp) "$params(name)_bsp"
	    }
	}

	if { ($params(arch) == 32) || ($params(arch) == 64) || ($params(arch) == "") } {
	    if { [string match "psu_cortexa53*" $params(proc)] } {
		if { $params(arch) == "" } {
		    set params(arch) 64
		}
	    } else {
		if { $params(arch) == 64 } {
		    puts "WARNING: $params(arch)-bit not supported for the processor type - $params(proc). Setting 32-bit"
		}
		set params(arch) 32
	    }
	} else {
	    error "illegal arch type $params(arch). must be 32/64"
	}

	set fmt [dict create Type s Name s HwProject s Proc s Os s Language s TemplateApp s Bsp s ArchType s]
	set data [dict create Type app Name $params(name) HwProject $params(hwproject) Proc $params(proc) Os $params(os) \
		  Language [string toupper $params(lang)] TemplateApp $params(app) Bsp $params(bsp) ArchType $params(arch)]

	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" createProject "o{$fmt}" e [list $data]
	return
    }
    namespace export createapp
    ::xsdb::setcmdmeta createapp categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta createapp brief {Create an application project} [subst $help_prefix]
    ::xsdb::setcmdmeta createapp description [subst {
SYNOPSIS {
    [concat $help_prefix createapp] \[OPTIONS\]
        Create an application project
}
OPTIONS {
    -name <project-name>
        Project name that should be created

    -app <template-application-name>
        Name of the template application.
        Default is "Hello World".
        Use 'repo -apps' command to get the list of all application templates.

    -proc <processor-name>
        Processor instance that should be used for creating application project.

    -hwproject <hw project name>
        HW project for which the application or bsp project should be created.

    -bsp <BSP project name>
        BSP project for which the application project should be created.
        If this option is not specified, a default bsp is created

    -os <OS name>
        OS type for the application project.
        Default type is standalone

    -lang <programming-language>
        <programming-language>, can be 'c' or 'c++'

    -arch <arch-type>
        Processor architecture, <arch-type> can be 32 or 64
        This option is used to build the project with 32/64 bit toolchain.
        This is valid only for A53 processors, defaults to 32-bit for other
        processors.
}
RETURNS {
    Nothing, if the Application project is created successfully.
    Error string, if invalid options are used or if the project can't be
    created.
}
EXAMPLE {
    createapp -name hello1 -bsp bsp1 -hwproject hw1 -proc ps7_cortexa9_0
       Create a default application "Hello World" project with name 'hello1'
       for processor 'ps7_cortexa9_0'

    createapp -name fsbl1 -app {Zynq FSBL} -hwproject hw1 -proc ps7_cortexa9_0
       Create a Zynq FSBL project with name 'fsbl1' and also creates a BSP
       'fsbl1_bsp' for processor 'ps7_cortexa9_0' and default OS 'standalone'

    createapp -name e1 -app {Empty Application} -hwproject hw2
              -proc microblaze_0 -lang c++
       Create an empty C++ application project with name 'e1'.

    createapp -name hello2 -app {Hello World} -hwproject hw1
              -proc psu_cortexa53_0 -arch 32
       Create a Hello World application project with name 'hello2' for
       processor 'psu_cortexa53_0' with 32-bit tool chain.
}
}] [subst $help_prefix]


proc createlib {args} {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {name "library name" {args 1}}
	    {type "library type" {default "" args 1}}
	    {proc "target processor" {args 1}}
	    {os "project OS" {default "linux" args 1}}
	    {lang "project launguage" {default "c" args 1}}
	    {arch "32/64 bit" {default "" args 1}}
	    {flags "compiler flags" {default "" args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}
	if { ![info exists params(proc)] } {
	    error "processor type not specified"
	}
	if { ($params(arch) == 32) || ($params(arch) == 64) || ($params(arch) == "") } {
	    if { [string match "psu_cortexa53" $params(proc)] } {
		if { $params(arch) == "" } {
		    set params(arch) 64
		}
	    } else {
		if { $params(arch) == 64 } {
		    puts "WARNING: $params(arch)-bit not supported for the processor type - $params(proc). Setting 32-bit"
		}
		set params(arch) 32
	    }
	} else {
	    error "illegal arch type $params(arch). must be 32/64"
	}
	if { $params(type) == "" } {
	    if { $params(os) == "linux" } {
		set params(type) "shared"
	    } else {
		set params(type) "static"
	    }
	}

	set fmt [dict create Type s Name s LibType s Proc s Os s Language s ArchType s CompilerFlags s]
	set data [dict create Type lib Name $params(name) LibType $params(type) Proc $params(proc) Os $params(os) \
		  Language [string toupper $params(lang)] ArchType $params(arch) CompilerFlags $params(flags)]

	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" createProject "o{$fmt}" e [list $data]
	return
    }
    namespace export createlib
    ::xsdb::setcmdmeta createlib categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta createlib brief {Create a library project} [subst $help_prefix]
    ::xsdb::setcmdmeta createlib description [subst {
SYNOPSIS {
    [concat $help_prefix createlib] \[OPTIONS\]
        Create a library project
}
OPTIONS {
    -name <project-name>
        Project name that should be created

    -type <library-type>
        <library-type> can be 'static' or 'shared'
        Default type is 'shared'

    -proc <processor-type>
        Processor type that should be used for creating application project.
        'ps7_cortex9', 'microblaze', 'psu_cortexa53' or 'psu_cortexr5'

    -os <OS name>
        OS type for the application project.
        'linux' or 'standalone'
        Default type is linux

    -lang <programming-language>
        <programming-language> can be 'c' or 'c++'
        Default is c

    -arch <arch-type>
        Processor architecture, <arch-type> can be 32 or 64
        This option is used to build the project with 32/64 bit toolchain.
        This is valid only for A53 processors, defaults to 32-bit for other
        processors.

    -flags <compiler-flags>
        Optional - compiler flags
}
RETURNS {
    Nothing, if the library project is created successfully
    Error string, if invalid options are used or if the project can't be
    created
}
EXAMPLE {
    createlib -name lib1 -type static -proc ps7_cortexa9
       Create a static library project with name 'lib1' for processor
       'ps7_cortexa9' and default os 'standalone' with default language 'C'

    createlib -name lib2 type shared -proc psu_cortexa53 -os linux -lang C++
       Create a shared library project with name 'lib2' for processor
       'psu_cortexa53' and Linux OS with C++ language

    createlib -name st-stnd-r5-c-flags -type static -proc psu_cortexr5
              -os standalone -lang C -arch 32 -flags {-g3 -pg}
       Create a static library project with name 'st-stnd-r5-c-flags' for
       processor 'psu_cortexr5' and standalone OS with C language with extra
       compiler flags '-g3 -pg'
}
}] [subst $help_prefix]


    proc projects { args } {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {build "builds the project"}
	    {clean "cleans the project"}
	    {type "build type" {default "all" args 1}}
	    {name "project name" {default "" args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { $params(name) != "" } {
	    if { $params(type) == "" || $params(type) == "all" } {
		error "please specify project type \"bsp\" or \"app\", when project name is specified"
	    }
	}

	if { $params(type) == "all" } {
		set params(name) "all"
	} else {
	    if { $params(type) != "bsp" && $params(type) != "app" } {
		error "unknown project type $params(type). should be \"all\", \"bsp\" or \"app\""
	    }
	    if { $params(name) == ""} {
		error "invalid project name"
	    }
	}

	set chan [getsdkchan]
	if { $params(build) } {
	    xsdk_eval $chan Xsdk build "o{[dict create Type s Name s]}" e [list [dict create Type $params(type) Name $params(name)]]
	    return
	}
	if { $params(clean) } {
	    xsdk_eval $chan Xsdk clean "o{[dict create Type s Name s]}" e [list [dict create Type $params(type) Name $params(name)]]
	    return
	}
    }
    namespace export projects
    ::xsdb::setcmdmeta projects categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta projects brief {Build/Clean projects} [subst $help_prefix]
    ::xsdb::setcmdmeta projects description [subst {
SYNOPSIS {
    [concat $help_prefix projects] \[OPTIONS\]
        Build/Clean a bsp/application project or all projects in workspace
}
OPTIONS {
    -build | -clean
	Build / Clean projects

    -type <project-type>
        <project-type> can be "all", "bsp" or "app"
        Default type is all

    -name <project-name>
        Name of the project that should be built
}
RETURNS {
    Nothing, if the project is built successfully.
    Error string, if invalid options are used or if the project can't be built.
}
EXAMPLE {
    projects -build -type bsp -name hello_bsp
       Build the BSP project 'hello_bsp'

    projects -build
       Build all the projects in the current workspace

    projects -clean -type app
       Clean all the application projects in the current workspace

    projects -clean
       Clean all the projects in the current workspace
}
}] [subst $help_prefix]

    proc importprojects { args } {
	variable sdk_workspace
	variable help_prefix

	set options {
	    # leave this for backward compatibility
	    {path "project(s) path" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}
	if { ![info exists params(path)] } {
	    if { [llength $args] > 0 } {
		set params(path) [lindex $args 0]
		set params(path) [file normalize $params(path)]
		set args [lrange $args 1 end]
	    } else {
		error "project path not specified"
	    }
	}

	if { [llength $args] } {
	    error "unexpected arguments: $args"
	}

	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" importProjects "o{[dict create Path s]}" e [list [dict create Path $params(path)]]
	return
    }
    namespace export importprojects
    ::xsdb::setcmdmeta importprojects categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta importprojects brief {Import projects to workspace} [subst $help_prefix]
    ::xsdb::setcmdmeta importprojects description [subst {
SYNOPSIS {
    [concat $help_prefix importprojects] <path>
        Import all the SDK projects from <path> to workspace
}
RETURNS {
    Nothing, if the projects are imported successfully.
    Error string, if project path is not specified or if the projects can't be
    imported.
}
EXAMPLE {
    importprojects /tmp/wrk/wksp1/hello1
        Import sdk project(s) into the current workspace
}
}] [subst $help_prefix]

    proc importsources { args } {
	variable sdk_workspace
	variable help_prefix

	set options {
	    {name "project name" {args 1}}
	    {path "sources path" {args 1}}
	    {linker-script "copy linker script" {args 0}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}

	if { ![info exists params(path)] } {
	    error "sources path not specified"
	}
	check_sdk_workspace

	# Copy all the files except linker
	foreach filelist [glob -dir $params(path) *] {
	    if { [file extension $filelist] != ".ld" } {
		if { [catch {file copy -force $filelist $sdk_workspace/$params(name)/src} msg ] } { error $msg }
	    }
	}
	if { $params(linker-script) } {
	    foreach lfile [glob -dir $params(path) "*.ld"] {
		set ld_file [file normalize $lfile]
		if { [catch {file copy -force $ld_file $sdk_workspace/$params(name)/src} msg ] } { error $msg }
	    }
	}
    }
    namespace export importsources
    ::xsdb::setcmdmeta importsources categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta importsources brief {Import sources to an application project} [subst $help_prefix]
    ::xsdb::setcmdmeta importsources description [subst {
SYNOPSIS {
    [concat $help_prefix importsources] \[OPTIONS\]
        Import sources from a path to application project in workspace
}
OPTIONS {
    -name <project-name>
        Application Project to which the sources should be imported

    -path <source-path>
        Path from which the source files should be imported.
        All the files/directories from the <source-path> are imported to
        application project. All existing source files will be overwritten
        in the application, and new ones will be copied. Linker script will
        not be copied to the application directory.

    -linker-script
        Copies the linker script as well.
}
RETURNS {
    Nothing, if the project sources are imported successfully.
    Error string, if invalid options are used or if the project sources can't
    be imported.
}
EXAMPLE {
    importsources -name hello1 -path /tmp/wrk/wksp2/hello2
        Import the 'hello2' project sources to 'hello1' application project
        without the linker script.

    importsources -name hello1 -path /tmp/wrk/wksp2/hello2 -linker-script
        Import the 'hello2' project sources to 'hello1' application project
        along with the linker script.
}
}] [subst $help_prefix]

    proc export_to_ds5 {args } {
	variable help_prefix
	set options {
	    {name "project name" {args 1}}
	    {path "target path" {args 1}}
	}
	array set params [::xsdb::get_options args $options]

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}
	if { ![info exists params(path)] } {
	    error "target path not specified"
	}

	set chan [getsdkchan]
	xsdk_eval $chan "Xsdk" migrate2Ds5 "o{[dict create Name s Path s]}" e [list [dict create Name $params(name) Path $params(path)]]
	return
    }
    namespace export export_to_ds5

    proc getprojects { args } {
	variable sdk_workspace
	variable help_prefix
	set options {
	    {type "project type" {default "all" args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	set projs ""
	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { $params(type) != "all" && $params(type) != "hw" && $params(type) != "bsp" && $params(type) != "app" } {
	    error "unknown project type $params(type). should be \"all\", \"hw\", \"bsp\" or \"app\""
	}

	set chan [getsdkchan]
	set ret_list [xsdk_eval $chan "Xsdk" getProjects "o{[dict create Type s]}" eA [list [dict create Type $params(type)]]]
	if { [lindex $ret_list 1] != "" } {
	    regsub -all {\;} [lindex $ret_list 1] "\n" projs
	}
	return $projs
    }
    namespace export getprojects
    ::xsdb::setcmdmeta getprojects categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta getprojects brief {Get projects from the workspace} [subst $help_prefix]
    ::xsdb::setcmdmeta getprojects description [subst {
SYNOPSIS {
    [concat $help_prefix getprojects] \[OPTIONS\]
        Get hw/bsp/application projects or all projects from the workspace
}
OPTIONS {
    -type <project-type>
        <project-type> can be "all", "hw", "bsp" or "app"
        Default type is all
}
RETURNS {
    List of all the projects of type <project-type> in the workspace.
}
EXAMPLE {
    getprojects
        Return the list of all the projects available in the current workspace.

    getprojects -type hw
        Return the list of hardware projects.
}
}] [subst $help_prefix]

    proc deleteprojects { args } {
	variable sdk_workspace
	variable help_prefix
	set options {
	    {name "project name" {args 1}}
	    {workspace-only "delete from workspace only" {default 0}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { ![info exists params(name)] } {
	    error "project name not specified"
	}

	set wksp "false"
	if { $params(workspace-only) == 1 } {
	    set wksp "true"
	}

	set chan [getsdkchan]
	set retval [xsdk_eval $chan "Xsdk" deleteProjects "o{[dict create Name s Workspace s]}" e [list [dict create Name $params(name) Workspace $wksp]]]
	if { [lindex $retval 0] != "" } {
	    error $retval
	}
	return
    }
    namespace export deleteprojects
    ::xsdb::setcmdmeta deleteprojects categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta deleteprojects brief {Delete project(s) from the workspace} [subst $help_prefix]
    ::xsdb::setcmdmeta deleteprojects description [subst {
SYNOPSIS {
    [concat $help_prefix deleteprojects] \[OPTIONS\]
        Delete project(s) from the workspace
}
OPTIONS {
    -name
        Project name/list to be deleted
        List of projects should be separated by semi-colon {proj1;proj2;proj3}

    -workspace-only
        Delete project from workspace only and not from disk.
        Default operation is to delete projects from disk
}
RETURNS {
    Nothing, if the projects are deleted successfully.
    Error string, if invalid options are used or if the project can't be deleted.
}
EXAMPLE {
    deleteprojects -name hello1
        Delete the hello1 project from the disk.

    deleteprojects -name hello1 -workspace-only
        Delete the hello1 project from workspace only.
}
}] [subst $help_prefix]

    proc set_build_config { args } {
	puts "\nNote:: \"set_build_config\" command is Deprecated. Use \"configapp\" command"
	set options {
	    {app "application name" {args 1}}
	    {type "build config type" {args 1}}
	}
	array set params [::xsdb::get_options args $options]
	return [configapp -app $params(app) build-config $params(type)]
    }
    namespace export set_build_config

    proc get_build_config { args } {
	puts "\nNote:: \"get_build_config\" command is Deprecated. Use \"configapp\" command"
	set options {
	    {app "application name" {args 1}}
	}
	array set params [::xsdb::get_options args $options]
	return [configapp -app $params(app) build-config]
    }
    namespace export get_build_config

    proc configapp { args } {
	variable sdk_workspace
	variable help_prefix
	set options {
	    {app "application name" {args 1}}
	    {set "set a param value" {default 0}}
	    {add "add to a param value"}
	    {remove "delete a param value"}
	    {info "more info of param value"}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { $params(set) + $params(add) + $params(remove) + $params(info) > 1 } {
	    error "conflicting options; use only one of -info, -add, -set, or -remove"
        }

	set chan [getsdkchan]
	set defs [lindex [xsdk_eval $chan XBuildSettings getDefinitions s "eA" [list ""]] 1]
	set names [lsort [dict keys $defs]]
	if { [llength $args] == 0 } {
	    if { $params(set) + $params(add) + $params(remove) + $params(info) != 0 } {
		error "conflicting options specified"
	    }
	    set result ""
	    foreach name $names {
		if { $result != "" } {
		    append result "\n"
		}
		append result [format "  %-30s %s" $name [::xsdb::dict_get_safe $defs $name description]]
	    }
	    return $result
	}

	if { [llength $args] > 2 } {
	    error "unexpected arguments: $args. should be \"configapp \[options\] \[name \[value\]\]\""
	}
	set name [lsearch -all -inline -glob $names "[lindex $args 0]*"]
	if { [llength $name] != 1 } {
	    if { [llength $name] == 0 } {
		set name $names
	    }
	    error "unknown or ambiguous parameter \"[lindex $args 0]\": must be [join $name {, }]"
	}
	set name [lindex $name 0]

	if { [info exists params(app)] } {
	    if { [lsearch [::sdk::getprojects] $params(app)] == -1 } {
		error "application project '$params(app)' doesn't exist in the workspace\nuse 'getprojects -type app' to get a list of application projects in workspace"
	    }
	} else {
	    error "application name not specified"
	}

	if { [llength $args] == 2 } {
	    if { $params(info) } {
		error "-info is not supported while setting a parameter value"
	    }
	    set value [lindex $args 1]
	    set props [::xsdb::dict_get_safe $defs $name props]
	    if { $params(set) + $params(add) + $params(remove) == 0 } {
		set params([lindex $props 0]) 1
	    }

	    foreach prop [array names params] {
		if { $params($prop) == 1 } {
		    if { [lsearch $props $prop] == -1 } {
			error "parameter $name doesn't support $prop operation"
		    }
		    xsdk_eval $chan XBuildSettings $prop sss e [list $params(app) $name $value]
		    return
		}
	    }
	}

	if { $params(info) } {
	    set result [format "  %-20s : %s\n" "Possible Values" [::xsdb::dict_get_safe $defs $name values]]
	    append result [format "  %-20s : %s\n" "Possible Operations" [regsub -all { } [::xsdb::dict_get_safe $defs $name props] {, }]]
	    append result [format "  %-20s : %s" "Default Operation" [lindex [::xsdb::dict_get_safe $defs $name props] 0]]
	    return $result
	}

	return [lindex [xsdk_eval $chan XBuildSettings get ss eA [list $params(app) $name]] 1]
    }
    namespace export configapp
    ::xsdb::setcmdmeta configapp categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta configapp brief {Configure settings for application projects} [subst $help_prefix]
    ::xsdb::setcmdmeta configapp description [subst {
SYNOPSIS {
    [concat $help_prefix configapp]
        List name and description for available configuration
        parameters for the application projects. Following configuration
        parameters can be configured for applications:
          assembler-flags         : Miscellaneous flags for assembler 
          build-config            : Get/set build configuration
          compiler-misc           : Compiler miscellaneous flags
          compiler-optimization   : Optimization level
          define-compiler-symbols : Define symbols. Ex. MYSYMBOL
          include-path            : Include path for header files
          libraries               : Libraries to be added while linking
          library-search-path     : Search path for the libraries added
          linker-misc             : Linker miscellaneous flags
          linker-script           : Linker script for linking
          undef-compiler-symbols  : Undefine symbols. Ex. MYSYMBOL

    [concat $help_prefix configapp] \[OPTIONS\] -app <app-name> <param-name>
        Get the value of configuration parameter <param-name> for the
        application specified by <app-name>.

    [concat $help_prefix configapp] \[OPTIONS\] -app <app-name>
    <param-name> <value>
        Set/modify/remove the value of configuration parameter <param-name>
        for the application specified by <app-name>.
}
OPTIONS {
    -set
        Set the configuration paramter value to new <value>

    -add
        Append the new <value> to configuration parameter value

    -remove
        Remove <value> from the configuration parameter value

    -info
        Displays more information like possible values and possible
        operations about the configuration parameter. A parameter name
        must be specified when this option is used
}
RETURNS {
    Depends on the arguments specified.
    <none>
        List of paramters and description of each parameter

    <parameter name>
        Parameter value or error, if unsupported paramter is specified

    <parameter name> <paramater value>
        Nothing if the value is set, or error, if unsupported paramter is
        specified
}
EXAMPLE {
    configapp
       Return the list of all the configurable options for the application.

    configapp -app test build-config
       Return the current build configuration.

    configapp -app test build-config release
       Set the current build configuration to release.

    configapp -app test define-compiler-symbols FSBL_DEBUG_INFO
       Add the define symbol FSBL_DEBUG_INFO to be passed to the compiler.

    configapp -app test -remove define-compiler-symbols FSBL_DEBUG_INFO
       Remove the define symbol FSBL_DEBUG_INFO to be passed to the compiler.

    configapp -app test compiler-misc {-pg}
       Append the -pg flag to compiler misc flags.

    configapp -app test -set compiler-misc {-c -fmessage-length=0 -MT"$@"}
       Set flags specified to compiler misc

    configapp -app test -info compiler-optimization
       Display more information about possible values/operation and default
       operation for compiler-optimization.
}
}] [subst $help_prefix]

    proc toolchain { args } {
	variable sdk_workspace
	variable help_prefix
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help [subst $help_prefix][lindex [split [lindex [info level 0] 0] ::] end]]
	}

	set chan [getsdkchan]
	set defs [lindex [xsdk_eval $chan Xsdk getAvailableToolchains s "eA" [list ""]] 1]
	set names [lsort [dict keys $defs]]
	if { [llength $args] == 0 } {
	    set fmt "  %-15s %s"
	    set result [format $fmt Name {Supported CPU Types}]
	    append result "\n[format $fmt "====" "==================="]"
	    foreach name $names {
		append result "\n"
		set desc [join [::xsdb::dict_get_safe $defs $name {cpu types}] {, }]
		append result [format $fmt $name $desc]
	    }
	    return $result
	}

	set proc_type [lindex $args 0]
	if { [llength $args] == 2 } {
	    set name [lsearch -all -inline -glob $names "[lindex $args 1]"]
	    if { [llength $name] != 1 } {
	        error "unknown toolchain \"[lindex $args 1]\": must be [join $names {, }]"
	    }
	    set name [lindex $args 1]
	    if { [lsearch [::xsdb::dict_get_safe $defs $name "cpu types"] $proc_type] == -1 } {
		error "$name is not a supported toolchain for processor type $proc_type"
	    }
	    return [lindex [xsdk_eval $chan Xsdk setToolchain ss e [list $proc_type $name]] 1]
	}

	if { [llength $args] != 1 } {
	    error {wrong # args: should be "toolchain [processor-type [tool-chain]]"}
	}

	return [lindex [xsdk_eval $chan Xsdk getToolchain s eA [list $proc_type]] 1]
    }
    namespace export toolchain
    ::xsdb::setcmdmeta toolchain categories {sdk} [subst $help_prefix]
    ::xsdb::setcmdmeta toolchain brief {Set or get toolchain used for building projects} [subst $help_prefix]
    ::xsdb::setcmdmeta toolchain description [subst {
SYNOPSIS {
    [concat $help_prefix toolchain]
        Return a list of available toolchains and supported processor types.

    [concat $help_prefix toolchain] <processor-type>
        Get the current toolchain for <processor-type>.

    [concat $help_prefix toolchain] <processor-type> <tool-chain>
        Set the <toolchain> for <processor-type>. Any new projects created
        will use the new toolchain during build.
}
RETURNS {
    Depends on the arguments specified
    <none>
        List of available toolchains and supported processor types

    <processor-type>
        Current toolchain for processor-type

    <processor-type> <tool-chain>
        Nothing if the tool-chain is set, or error, if unsupported tool-chain
        is specified
}
}] [subst $help_prefix]

    proc petalinux-install-path { args } {
	variable plx_install

	if {[string first "Linux" $::tcl_platform(os)] == -1} {
	    error "Petalinux commands are supported only on Linux platform"
	}

	if { [llength $args] == 0 } {
	    if { $plx_install == "" } {
		error "Petalinux installation path not set.\n\
Set the installation path using \"petalinux-install-path <path>\""
	    }
	    return $plx_install
	} elseif { [llength $args] > 1 } {
	    error "wrong # of args: should be \"petalinux-install-path \[path\]\""
	}

	set path [lindex $args 0]
	if { ![file isdirectory $path] || ![file exists $path/settings.sh] } {
	    error "$path is not a valid Petalinux installation"
	}
	# Source the script for sanity
	exec >&@stdout /bin/bash -c "source $path/settings.sh"
	set plx_install $path
	return
    }
    namespace export petalinux-install-path
    ::xsdb::setcmdmeta petalinux-install-path categories {petalinux} [subst $help_prefix]
    ::xsdb::setcmdmeta petalinux-install-path brief {Set or get PetaLinux installation path} [subst $help_prefix]
    ::xsdb::setcmdmeta petalinux-install-path description [subst {
SYNOPSIS {
    [concat $help_prefix petalinux-install-path] <path>
        Set PetaLinux installation path. XSCT uses this installation path to
        run the Petalinux commands.
        The following Petalinux commands are available:
            petalinux-boot
            petalinux-build
            petalinux-config
            petalinux-create
            petalinux-package
            petalinux-util

        Help for these Petalinux commands is available by running
        <petalinux-command> -help, after setting the installation path.
}
RETURNS {
    Installation path, if no arguments are specified.
    Nothing, if a valid installtion path is specified.
    Error string, if path is not a valid installation or wrong # of args are
    specified.
}
}] [subst $help_prefix]

    proc plx { args } {
	variable plx_install

	if {[string first "Linux" $::tcl_platform(os)] == -1} {
	    error "Petalinux commands are supported only on Linux platform"
	}

	if { $plx_install == "" } {
	    error "Petalinux installation path not set.\n\
Set the installation path using \"petalinux-install-path <path>\""
	}
	exec >&@stdout /bin/bash -c "source $plx_install/settings.sh > /dev/null; [list {*}$args]"
    }

    proc petalinux-boot { args } {
	return [plx {*}[linsert $args 0 petalinux-boot]]
    }
    namespace export petalinux-boot

    proc petalinux-build { args } {
	return [plx {*}[linsert $args 0 petalinux-build]]
    }
    namespace export petalinux-build

    proc petalinux-config { args } {
	return [plx {*}[linsert $args 0 petalinux-config]]
    }
    namespace export petalinux-config

    proc petalinux-create { args } {
	return [plx {*}[linsert $args 0 petalinux-create]]
    }
    namespace export petalinux-create

    proc petalinux-package { args } {
	return [plx {*}[linsert $args 0 petalinux-package]]
    }
    namespace export petalinux-package

    proc petalinux-util { args } {
	return [plx {*}[linsert $args 0 petalinux-util]]
    }
    namespace export petalinux-util

    namespace ensemble create -command ::sdk
}

package provide sdk $::sdk::version
