if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}

package ifneeded xsdb 0.1 [list source [file join [file dirname [info script]] xsdb.tcl]]
package ifneeded xsdb::jtag 0.1 [list source [file join [file dirname [info script]] jtag.tcl]]
package ifneeded xsdb::tfile 0.1 [list source [file join [file dirname [info script]] tfile.tcl]]
package ifneeded xsdb::server 0.1 [list source [file join [file dirname [info script]] xsdbserver.tcl]]
package ifneeded xsdb::gdbremote 0.1 [list source [file join [file dirname [info script]] gdbremote.tcl]]
package ifneeded sdk 0.1 [list source [file join [file dirname [info script]] sdk.tcl]]
source [file join [file dirname [info script]] pkgIndex2.tcl]
