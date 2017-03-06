
if {[ info exists ::env(BUILTIN_SYNTH) ] && [rt::get_parameter enableParallelHelperSpawn]} {
  # Call parallel_synth_helper that will fork vivado processes later
  set helperShmKey [rt::get_parameter helper_shm_key]
  if {$helperShmKey == "" && [$rt::db isSharedMemoryAvailable] } {
    puts "INFO: Launching helper process for spawning children vivado processes"
    rt::set_parameter helper_shm_key "LaunchHelperProcessKey_[pid]_[clock seconds]"
    set rt::helper_process_pid [rt::parallel_synth_helper_wrapper [rt::get_parameter helper_shm_key] $rt::partid [pid] ]
    puts "INFO: Helper process launched with PID $rt::helper_process_pid "
  }
} else {
  rt::set_parameter helper_shm_key "dummy"
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
