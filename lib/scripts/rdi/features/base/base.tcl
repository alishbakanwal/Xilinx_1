# % load_feature base
# 
# This file is sourced by load_feature after features.tcl
#
# The base feature contains absolute minimum basic functionality
# needed by all products regardless of what other features (if any)
# they load explicitly

# quit alias is used by Vivado simulator.
catch {interp alias {} quit {} exit}

# hide aliases from command completion
rdi::hide_commands \
 quit

# There is a slight problem with tcl's unknown when overwriting
# channels to redirect at GUI.
# The problem is described in this thread:
# http://coding.derkeiler.com/Archive/Tcl/comp.lang.tcl/2005-02/1051.html
# Boils down to this code in init.tcl 
#  ...
#  if {[namespace which -command console] eq ""} {
#	set redir ">&@stdout <@stdin"
#  }
#  ...
# The redirect causes a problem for certain shell commands The fix
# seems to as simple as adding a dummy 'console' command to make Tcl
# think it's dealing with a Tk based wish console.  
proc console {} {}
proc rdi::disable_console {} {
    rename ::console rdi::console
}
proc rdi::enable_console {} {
    rename rdi::console ::console
}
# By default, disable console, since we are in tcl mode
# until the gui is started.  start_gui will enable.
rdi::disable_console

# work around x11 XSupportsLocale bug
rdi::x11_workaround

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
