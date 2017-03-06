if { ! [ info exists ::env(BUILTIN_SYNTH) ] } {
    puts "Unimacro enabled only in vivado"
} else {
    set unimacroFiles { \
			    verilog/src/unimacro/ADDMACC_MACRO.v \
			    verilog/src/unimacro/ADDSUB_MACRO.v \
			    verilog/src/unimacro/BRAM_SDP_MACRO.v \
			    verilog/src/unimacro/BRAM_SINGLE_MACRO.v \
			    verilog/src/unimacro/BRAM_TDP_MACRO.v \
			    verilog/src/unimacro/COUNTER_LOAD_MACRO.v \
			    verilog/src/unimacro/COUNTER_TC_MACRO.v \
			    verilog/src/unimacro/EQ_COMPARE_MACRO.v \
			    verilog/src/unimacro/FIFO_DUALCLOCK_MACRO.v \
			    verilog/src/unimacro/FIFO_SYNC_MACRO.v \
			    verilog/src/unimacro/MACC_MACRO.v \
			    verilog/src/unimacro/MULT_MACRO.v \
			}

#    puts "Unimacro $unimacroFiles"
    foreach uf $unimacroFiles {
	set rt::rdiDataDir [rdi::get_data_dir -datafile $uf]
	if {[file exists $rt::rdiDataDir]} {
	    #	    # put legacy component translations here
#	    puts "rt::read_verilog $rt::rdiDataDir/$uf"
	    rt::read_verilog $rt::rdiDataDir/$uf
	} else {
	    #	    #    puts "Skipping $rf because RDI_DATADIR not found."
	}
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
