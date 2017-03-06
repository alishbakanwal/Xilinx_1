#
# move stuff from the rt::donotuse namespace back to
# the rt:: namespace prior to synthesis operation.
if { [info exists rt::db] && $rt::db eq "rt-undefined" } {

  # turn off rt command echo
  set rt::saveCmdEcho $rt::cmdEcho
  set rt::cmdEcho 0

  # and put some rt stuff into the global namespace...
  #rename rt::donotuse::quit       quit
  rename rt::donotuse::sh         sh
  rename rt::donotuse::tcl_puts   tcl_puts
  rename rt::donotuse::tcl_source tcl_source

  rename rt::donotuse::_x_restore rt::_x_restore
  rt::_x_restore

  # find all the procs named _{bunch of digits}_
  # and move them to the rt::namespace
  foreach rt::procname [info commands rt::_procs::*] {
    rename $rt::procname [namespace tail $rt::procname]
  }

  set rt::cmdEcho $rt::saveCmdEcho

}

rt::disable_message PARAM-104

if { [llength [info commands get_msg_config ] ] != 0 } {
  set num_errors_at_start [get_msg_config -count -severity ERROR]
  set num_warnings_at_start [get_msg_config -count -severity WARNING]
  set num_critical_warnings_at_start [get_msg_config -count -severity {CRITICAL WARNING}]
}

rt::install_oasys_sighandlers


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
