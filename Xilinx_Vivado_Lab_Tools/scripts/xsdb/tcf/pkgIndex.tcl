if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}

package ifneeded tcf 0.1 [list source [file join $dir tcf.tcl]]
