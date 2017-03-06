if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}

package ifneeded xsdb::tcfinterp 0.1 [list source [file join [file dirname [info script]] xsdb_tcfinterp.tcl]]
package ifneeded xsdb::elf 0.1 [list source [file join [file dirname [info script]] elf.tcl]]
package ifneeded xsdb::gprof 0.1 [list source [file join [file dirname [info script]] gprof.tcl]]
package ifneeded xsdb::mbprofiler 0.1 [list source [file join [file dirname [info script]] mbprofiler.tcl]]
package ifneeded xsdb::bitfile 0.1 [list source [file join [file dirname [info script]] bitfile.tcl]]
package ifneeded xsdb::jtag::sequence 0.1 [list source [file join [file dirname [info script]] jtag_sequence.tcl]]
