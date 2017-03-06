if { ! [ info exists ::env(BUILTIN_SYNTH) ] } {
    puts "Unimacro enabled only in vivado"
} else {
    set unimacroFiles { \
			    vhdl/src/unimacro/unimacro_VCOMP.vhd \
			    vhdl/src/unimacro/ADDMACC_MACRO.vhd \
			    vhdl/src/unimacro/ADDSUB_MACRO.vhd \
			    vhdl/src/unimacro/BRAM_SDP_MACRO.vhd \
			    vhdl/src/unimacro/BRAM_SINGLE_MACRO.vhd \
			    vhdl/src/unimacro/BRAM_TDP_MACRO.vhd \
			    vhdl/src/unimacro/COUNTER_LOAD_MACRO.vhd \
			    vhdl/src/unimacro/COUNTER_TC_MACRO.vhd \
			    vhdl/src/unimacro/EQ_COMPARE_MACRO.vhd \
			    vhdl/src/unimacro/FIFO_DUALCLOCK_MACRO.vhd \
			    vhdl/src/unimacro/FIFO_SYNC_MACRO.vhd \
			    vhdl/src/unimacro/MACC_MACRO.vhd \
			    vhdl/src/unimacro/MULT_MACRO.vhd \
			}

#    puts "Unimacro $unimacroFiles"
    foreach uf $unimacroFiles {
	set rt::rdiDataDir [rdi::get_data_dir -datafile $uf]
	if {[file exists $rt::rdiDataDir]} {
	    #	    # put legacy component translations here
#	    puts "rt::read_vhdl -lib UNIMACRO $rt::rdiDataDir/$uf"
	    rt::read_vhdl -lib UNIMACRO $rt::rdiDataDir/$uf
	} else {
	    #	    #    puts "Skipping $rf because RDI_DATADIR not found."
	}
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
