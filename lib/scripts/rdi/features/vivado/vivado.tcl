# % load_feature vivado
# 
# This file is sourced by load_feature after features.tcl

# set RT env vars BEFORE loading tcl library
set platformSeparator ":"
if {[info exist tcl_platform(platform)] && ($tcl_platform(platform) == "windows")} {
   set platformSeparator ";"
}
set RT_TCL_PATH_TMP [file join $rdi::approot scripts rt base_tcl tcl]
foreach rdiRoot [split "$::env(RDI_APPROOT)" $platformSeparator] {
   set RT_TCL_PATH_TMP [file join $rdiRoot scripts rt base_tcl tcl]
   if {[file exists $RT_TCL_PATH_TMP]} {
      break
   }
}
set env(RT_TCL_PATH) $RT_TCL_PATH_TMP

set HRT_TCL_PATH_TMP [file join $rdi::approot scripts rt fpga_tcl]
foreach rdiRoot [split "$::env(RDI_APPROOT)" $platformSeparator] {
   set HRT_TCL_PATH_TMP [file join $rdiRoot scripts rt fpga_tcl]
   if {[file exists $HRT_TCL_PATH_TMP]} {
      break
   }
}
set env(HRT_TCL_PATH) $HRT_TCL_PATH_TMP

if { ! [ info exists env(SYNTH_COMMON) ] } {
    set SYNTH_COMMON_TMP [file join $rdi::approot scripts rt data]
    foreach rdiRoot [split "$::env(RDI_APPROOT)" $platformSeparator] {
       set SYNTH_COMMON_TMP [file join $rdiRoot  scripts rt data]
       if {[file exists $SYNTH_COMMON_TMP]} {
          break
       }
    }
    set env(SYNTH_COMMON) $SYNTH_COMMON_TMP
}


rdi::load_library vivado librdi_vivadotasks

# define RT commands
source -notrace [file join $env(HRT_TCL_PATH) realTimeFpga.tcl]

# dont auto complete rds namespaces
rdi::hide_namespaces cli:: config:: dir:: rt:: rtdc:: sdc:: sdcrt:: 

# aliases
interp alias {} report_clock {} rdi::alias report_clock report_clocks
rdi::hide_commands report_clock

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
