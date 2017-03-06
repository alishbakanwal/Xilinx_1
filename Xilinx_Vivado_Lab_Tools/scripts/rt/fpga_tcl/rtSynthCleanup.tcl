#
# move stuff that is in the 'rt::' namespace
# but that will cause problems if run when synthesis isn't active
# into the hopefully clearly name rt::donotuse namespace
#
# also move some stuff shoved into the global namespace out to rt::donotuse
#
if { [info exists rt::db] && $rt::db ne "rt-undefined" && ! [info exists ::env(XILINX_REALTIMEFPGA)] } {

  # turn off rt command echo
  set rt::saveCmdEcho $rt::cmdEcho
  set rt::cmdEcho 0

  # hide some global junk
  #rename quit       rt::donotuse::quit
  rename sh         rt::donotuse::sh
  rename tcl_puts   rt::donotuse::tcl_puts
  rename tcl_source rt::donotuse::tcl_source

  # find all the procs named _{bunch of digits}_
  # and move them to the rt::namespace
  foreach rt::_procname [info commands _*] {
    if { [regexp {_[0-9a-f].*_p_[NU].*} $rt::_procname] } {
      rename $rt::_procname rt::_procs::$rt::_procname
    }
  }

  # now hide dangerous things...
  rt::_x_save
  rename rt::_x_save rt::donotuse::_x_save

  set rt::cmdEcho $rt::saveCmdEcho

}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
