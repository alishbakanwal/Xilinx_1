# ****************************************************************************
#             Copyright (C) Oasys Design Systems, Inc. 2004 - 2009
#                             All rights reserved.
# ****************************************************************************

# Loading internal commands
if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " commands" }
tcl_source $env(RT_TCL_PATH)/internal/commands.tcl

# Loading regress
if {[info exist env(RT_REGRESS)] &&
    [file isdirectory $env(RT_REGRESS)]} {
    if {$rt_tool_name != "realTimeFpga"} { rt::UMsg_print " regress" }
    tcl_source $env(RT_REGRESS)/scripts/regress.tcl
}
# removed because it shows up all the time - seems like its
# really an 'internal' kind of message and shouldn't always be issued?
# else {
#    UMsg_print "\n"
#    UMsg_print "Warning: could not load regress"
# }



# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
