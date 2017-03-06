package provide hsi 1.0
package require Tcl 8.5

set hsi_loaded 0
foreach d $::auto_path {
  if { ![catch {load [file join $d librdi_commontasks[info sharedlibextension]]}] &&
     ![catch {load [file join $d librdi_hsmtasks[info sharedlibextension]]}]} {
    set hsi_loaded 1
    break
  }
}

if { !$hsi_loaded } {
  load librdi_commontasks[info sharedlibextension]
  load librdi_hsmtasks[info sharedlibextension]
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
