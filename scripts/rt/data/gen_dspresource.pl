#!/usr/bin/perl
# Create a cell-parameter-type table.  Input is from 
# $XILINX/verilog/src/iSE/unisim_comp.v, output to 
# rtx/data/parameter_type.txt
exists($ENV{XILINX}) or die "Environment variable \$XILINX not set\n";

$XstDspResourceFileName = "$ENV{XILINX}/../env/JDBHelpers/XstHelpers/data//*virtex6*/xst2DeviceResources.xrl  $ENV{XILINX}/../env/JDBHelpers/XstHelpers/data/blanc/xst2DeviceResources.xrl $ENV{XILINX}/../env/JDBHelpers/XstHelpers/data/*fuji*/xst2DeviceResources.xrl ";
system "grep -Pho '([0-9]+)\" name=\"DSP48E1\"|Device=\"(.*)\"' $XstDspResourceFileName | grep -Pho 'x[^\"]+|^[0-9]+' | sed -e 'N' -e 's:\\(x.*\\)\\n\\([0-9]*\\):if { [expr [string first \"\\1\" \$_PartId] == 0] } {set_parameter dspResource \\2}:g' | sort -r > DSPResource.tcl";


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
