if { ! [ info exists ::env(BUILTIN_SYNTH) ] } {
    set rt::rdiDataDir $env(RDI_DATADIR)
    if {[file exists $rt::rdiDataDir]} {
	# put legacy component translations here
	rt::read_vhdl $rt::rdiDataDir/vhdl/src/unisims/retarget/MULT18X18.vhd
	rt::read_vhdl $rt::rdiDataDir/vhdl/src/unisims/retarget/MULT18X18S.vhd
    } else {
	#    puts "Skipping retarget because RDI_DATADIR not found."
    }
} else {
    set retargetFiles { \
			    vhdl/src/unisims/retarget/MULT18X18.vhd \
			    vhdl/src/unisims/retarget/MULT18X18S.vhd \
			}
    #puts "Retarget $retargetFiles"
    foreach rf $retargetFiles {
	set rt::rdiDataDir [rdi::get_data_dir -datafile $rf]
	if {[file exists $rt::rdiDataDir]} {
#	    # put legacy component translations here
#	    puts "rt::read_vhdl $rt::rdiDataDir/$rf"
	    rt::read_vhdl $rt::rdiDataDir/$rf
	} else {
#	    #    puts "Skipping $rf because RDI_DATADIR not found."
	}
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
