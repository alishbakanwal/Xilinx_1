##############################################################################
# Copyright 2011 Xilinx Inc. All rights reserved
##############################################################################
# init file sourced when rules are loaded
#
;# source tcl scripts within package
set dir [file dirname [info script]]
source -notrace [file join $dir utils.tcl]

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
