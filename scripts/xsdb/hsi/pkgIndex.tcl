if {![package vsatisfies [package provide Tcl] 8.5]} {
    # PRAGMA: returnok
    return
}

package ifneeded hsi 0.1 [list source [file join $dir hsi.tcl]]
package ifneeded hsi::utils 0.1 [list source [file join $dir hsiutils.tcl]]
package ifneeded hsi::help 0.1 [list source [file join $dir hsihelp.tcl]]
