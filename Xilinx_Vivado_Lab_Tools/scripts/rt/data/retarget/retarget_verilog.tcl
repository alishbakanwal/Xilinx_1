if { ! [ info exists ::env(BUILTIN_SYNTH) ] } {
    set rt::rdiDataDir $env(RDI_DATADIR)
    if {[file exists $rt::rdiDataDir]} {
        # put legacy component translations here
        rt::read_verilog $rt::rdiDataDir/verilog/src/retarget/DSP48.v
        rt::read_verilog $rt::rdiDataDir/verilog/src/retarget/DSP48A.v
        rt::read_verilog $rt::rdiDataDir/verilog/src/retarget/DSP48A1.v
        rt::read_verilog $rt::rdiDataDir/verilog/src/retarget/DSP48E.v
    } else {
    #    puts "Skipping retarget because RDI_DATADIR not found."
    }
} else {
    set retargetFiles { \
			    verilog/src/retarget/DSP48.v \
			    verilog/src/retarget/DSP48A.v \
			    verilog/src/retarget/DSP48A1.v \
			    verilog/src/retarget/DSP48E.v \
			}
    #puts "Retarget $retargetFiles"
    foreach rf $retargetFiles {
	set rt::rdiDataDir [rdi::get_data_dir -datafile $rf]
	if {[file exists $rt::rdiDataDir]} {
#	    # put legacy component translations here
#	    puts "rt::read_verilog $rt::rdiDataDir/$rf"
	    rt::read_verilog $rt::rdiDataDir/$rf
	} else {
#	    #    puts "Skipping $rf because RDI_DATADIR not found."
	}
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
