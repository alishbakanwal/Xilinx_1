# % load_feature labtools
# 
# This file is sourced by load_feature after features.tcl

# libraries
rdi::load_library "hsm" librdi_hsmtasks

# export all commands from the hsi:: Tcl namespace
namespace eval hsi {namespace export *}

namespace eval hsm { namespace import ::hsi::* }


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
