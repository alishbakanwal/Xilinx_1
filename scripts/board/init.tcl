##############################################################################
# Copyright 2011 Xilinx Inc. All rights reserved
##############################################################################
# init file sourced when rules are loaded
#

#Enable BIT feature based on project env
if { [get_param -quiet project.enableBITabFlow] == 0 } { 
	return false
}	

# Load files
set filepath [file dirname [file normalize [info script]]]
source -notrace ${filepath}/apply_board_connection.tcl
source -notrace ${filepath}/associated_to_board.tcl

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
