package require tcf

namespace eval ::xsdb::gdbremote {
    variable version 0.1

    # Connect to gdbremote server
    proc connect {args} {
	set options {
	    {multiprocess "enable/disable multiprocess mode" {args 1}}
	    {extended "enable/disable extended mode" {args 1}}
	    {auto_attach "enable/disable auto attach mode" {args 1}}
	    {architecture "specify default architecture" {args 1}}
	    {osabi "specify default osabi" {args 1}}
	    {log "specify log level" {args 1}}
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help gdbremote [lindex [split [lindex [info level 0] 0] ::] end]]
	}

	if { [llength $args] != 1 } {
	    error "wrong # args: should be \"gdbremote connect \[options\] <server>\""
	}

	if { [catch {
	    set chan [::xsdb::getcurchan]
	    set services [::tcf::sync_eval [list ::tcf::get_services $chan]]
	    if { [lsearch $services GdbClient] < 0 } {
		error "gdbremote connect not supported"
	    }
	}] } {
	    # No connection or current connection does not support
	    # GdbClient service - launch and connect to tcfgdbclient
	    # process to get access to GdbClient service.
	    set chan [::xsdb::connect -server tcfgdbclient -port 0]
	}

	set fields [split [lindex $args 0] :]
	if { [string compare -nocase tcp [lindex $fields 0]] == 0 } {
	    set fields [lrange $fields 1 end]
	}
	set host [lindex $fields 0]
	set port [lindex $fields 1]
	if { $host == "" } {
	    set host "127.0.0.1"
	}

	set arg [array get params]
	dict set arg host $host
	dict set arg port $port
	if {[dict exists $arg help]} {
	    set arg [dict remove $arg help]
	}
	::tcf::send_command $chan GdbClient connect "o{host s port s multiprocess b extended b auto_attach b architecture s osabi s log i}" es [list $arg]
	return ""
    }
    namespace export connect
    ::xsdb::setcmdmeta {gdbremote connect} categories {connections}
    ::xsdb::setcmdmeta {gdbremote connect} brief {Connect to gdbremote server}
    ::xsdb::setcmdmeta {gdbremote connect} description {
SYNOPSIS {
    gdbremote connect [options] server
        Connect to GDB remote server, e.g. qemu
}
OPTIONS {
    -architecture <name>
        Specify default architecture is remote server does not provide it.
}
DESCRIPTION {
    This command attempts to connect the a GDB Remote Server.
}
RETURNS {
    Nothing, if the connection is successful.
    Error string, if the connection failed.
}
}

    # Disconnect to gdbremote server
    proc disconnect {args} {
	set options {
	    {help "command help"}
	}
	array set params [::xsdb::get_options args $options 0]

	if { $params(help) } {
	    return [help gdbremote [lindex [split [lindex [info level 0] 0] ::] end]]
	}
	if { [llength $args] > 1 } {
	    error "wrong # args: should be \"gdbremote disconnect \[target-id\]\""
	}

	set chan [::xsdb::getcurchan]
	set targets [targets -target-properties]
	set match {}
	set l0target {}
	if { [llength $args] == 0 } {
	    foreach target $targets {
		if { [dict exists $target level] && [dict get $target level] == 0 } {
		    set l0target $target
		}
		if { [dict exists $target is_current] && [dict get $target is_current] } {
		    set match $l0target
		    break
		}
	    }
	} else {
	    set tid [lindex $args 0]
	    foreach target $targets {
		if { [dict exists $target level] && [dict get $target level] == 0 } {
		    set l0target $target
		}
		if { [dict exists $target target_id] && [dict get $target target_id] == $tid } {
		    set match $l0target
		    break
		}
	    }
	}
	if { $match == {} || ![dict exists $match target_ctx] || [dict get $match target_ctx] == "" } {
	    error "Invalid target. Use \"targets\" command to select a target"
	}
	::tcf::send_command $chan GdbClient disconnect "s" e [list [dict get $match target_ctx]]
	return ""
    }
    namespace export disconnect
    ::xsdb::setcmdmeta {gdbremote disconnect} categories {connections}
    ::xsdb::setcmdmeta {gdbremote disconnect} brief {Disconnect from gdbremote server}
    ::xsdb::setcmdmeta {gdbremote disconnect} description {
SYNOPSIS {
    gdbremote disconnect [target-id]
        Disconnect from GDB remote server, e.g. qemu
}
DESCRIPTION {
    This command disconnects GDB Remote Server for current or specified target.
}
RETURNS {
    Nothing, if the connection is close.
    Error string, if there is no active connection.
}
}

    namespace ensemble create -command ::gdbremote
}

package provide xsdb::gdbremote $::xsdb::gdbremote::version
