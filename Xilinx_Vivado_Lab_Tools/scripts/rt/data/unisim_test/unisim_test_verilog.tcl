if { ! [ info exists ::env(BUILTIN_SYNTH) ] } {
    puts "Unisim_test enabled only in vivado"
} else {
    set unisimtestFiles { \
			    verilog/src/olympus/test/BITSLICE_CONTROL_TEST.v \
			    verilog/src/olympus/test/BITSLICE_FF_TEST.v \
			    verilog/src/olympus/test/BYTE_TEST.v \
			    verilog/src/olympus/test/FIFO36E2_TEST.v \
			    verilog/src/olympus/test/GTHE3_CHANNEL_TEST.v \
			    verilog/src/olympus/test/GTHE3_COMMON_TEST.v \
			    verilog/src/olympus/test/HARD_SYNC_TEST.v \
			    verilog/src/olympus/test/HPIO_DIFFINBUF_TEST.v \
			    verilog/src/olympus/test/HPIO_DIFFOUTBUF_TEST.v \
			    verilog/src/olympus/test/HPIO_INBUF_TEST.v \
			    verilog/src/olympus/test/HPIO_OUTBUF_TEST.v \
			    verilog/src/olympus/test/HRIO_DIFFINBUF_TEST.v \
			    verilog/src/olympus/test/HRIO_DIFFOUTBUF_TEST.v \
			    verilog/src/olympus/test/HRIO_INBUF_TEST.v \
			    verilog/src/olympus/test/HRIO_OUTBUF_TEST.v \
			    verilog/src/olympus/test/IBUFDS_GTE3_TEST.v \
			    verilog/src/olympus/test/IDELAYE3_TEST.v \
			    verilog/src/olympus/test/ISERDESE3_TEST.v \
			    verilog/src/olympus/test/MMCME3_TEST.v \
			    verilog/src/olympus/test/OBUFDS_GTE3_TEST.v \
			    verilog/src/olympus/test/ODELAYE3_TEST.v \
			    verilog/src/olympus/test/OSERDESE3_TEST.v \
			    verilog/src/olympus/test/PCIE_3_1_TEST.v \
			    verilog/src/olympus/test/PLLE3_TEST.v \
			    verilog/src/olympus/test/PMV2_TEST.v \
			    verilog/src/olympus/test/PMVIOB_TEST.v \
			    verilog/src/olympus/test/PMV_TEST.v \
			    verilog/src/olympus/test/PULL_TEST.v \
			    verilog/src/olympus/test/RAMB36E2_TEST.v \
			    verilog/src/olympus/test/RIU_OR_TEST.v \
			    verilog/src/olympus/test/RXTX_BITSLICE_TEST.v \
			    verilog/src/olympus/test/RX_BITSLICE_TEST.v \
			    verilog/src/olympus/test/SYSMONE1_TEST.v \
			    verilog/src/olympus/test/TX_BITSLICE_TEST.v \
			    verilog/src/olympus/test/TX_BITSLICE_TRI_TEST.v \
			    verilog/src/olympus/test/GCLK_TEST_BUFE3.v \
			    verilog/src/olympus/test/GCLK_TEST_DELAY.v \
			    verilog/src/olympus/test/HPIO_ZMATCH_BLK_HCLK.v \
			}
    #    puts "Unisimtest $unisimtestFiles"
    foreach uf $unisimtestFiles {
	set rt::rdiDataDir [rdi::get_data_dir -quiet -datafile $uf]
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
