cli::addCommand impera::new_partition {$rt::db newImperaPartition} {string} 
cli::addCommand impera::assign_inst_to_partition {$rt::db assignInstToPartition} {string} {string}
cli::addCommand impera::write_verilog_for_partition {$rt::db writeVerilogForPartition} {string}
cli::addCommand impera::assign_top_level_glue_logic_to_partition {$rt::db assignTopLevelGlueLogicToPartition} {string}
cli::addCommand impera::assign_remaining_logic_to_partition {$rt::db assignRemainingLogicToPartition} {string}
cli::addCommand impera::report_partitions {$rt::db reportImperaPartitions}
cli::addCommand impera::report_inter_fpga_traces {$rt::db reportImperaInterFPGATraces}
cli::addCommand impera::move_instance_to_top {$rt::db moveInstanceToTop} {string}

proc impera::read_xdc {file} {
  global list impera::list_of_xdcs
  lappend impera::list_of_xdcs $file

  set ::rt::SDCFileList $impera::list_of_xdcs
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
