# hsm.tcl feature script
#
# Loaded during startup

namespace import common::*
load_feature base hsi
load librdi_boardcommontasks[info sharedlibextension]

#rdi::load_library "hsm" librdi_hsmtasks

# Hiding the categories which are not required
rdi::hide_category XDC 

# suppress WARNING: [Common 17-204] Your XILINX environment variable is undefined
set_msg_config -id {Common 17-204} -suppress

# export all commands from the hsi:: Tcl namespace
#namespace eval hsi {namespace export *}

# import all exported hsi:: commands into the global namespace
namespace import hsi::*

#	Import all commands in hsi namespace to hsm namespace for backward compatibility.
#namespace eval hsm { namespace import ::hsi::* }


namespace eval rdi {

  # List of tasks to filter out from hsm.
  variable hsm_filter_tasks
  lappend hsm_filter_tasks \
  ::common::start_gui \
  ::common::stop_gui \
  ::common::endgroup \
  ::common::startgroup \
  ::common::list_features

  ################################################################
  # Hide tasks from vivado
  ################################################################
  proc hsm_filter {} {
    foreach task $rdi::hsm_filter_tasks {
      if {[info commands $task] != ""} {
        rdi::unregister_task $task
      } else {
        puts "can't unregister unknown command '$task'"
      }
    }
  }
  
  hsm_filter

}

proc setup_hsm_environment {}   {
  if { [info exists ::env(XILINX_SDK)] == 0 || 
       [info exists ::env(RDI_PLATFORM)] == 0 } {
    return
  }

  set xilinx_sdk $::env(XILINX_SDK)
  set pf $::env(RDI_PLATFORM)

  set path_str ""
  if { $pf == "lnx64" } {
    set ps ":"
    set gnu_pf "lin64"
    set gnu_mbpf "lin"
    set gnu_mblepf "lin64_le"
    set gnu_mbbepf "lin64_be"
  } elseif { $pf == "lnx32" } {
    set ps ":"
    set gnu_pf "lin"
    set gnu_mbpf "lin"
    set gnu_mblepf "lin32_le"
    set gnu_mbbepf "lin32_be"
  } elseif { $pf == "win64" } {
    set ps ";"
    set gnu_pf "nt64"
    set gnu_mbpf "nt"
    set gnu_mblepf "nt64_le"
    set gnu_mbbepf "nt64_be"
    set path_str "$xilinx_sdk/gnuwin//bin$ps"
  } elseif { $pf == "win32" } {
    set ps ";"
    set gnu_pf "nt"
    set gnu_mbpf "nt"
    set gnu_mblepf "nt_le"
    set gnu_mbbepf "nt_be"
    set path_str "$xilinx_sdk/gnuwin//bin$ps"
  } else {
  }

  #$(XILINX_SDK)\bin; $(XILINX_SDK)\gnu\microblaze\nt\bin; 
  #$(XILINX_SDK)\gnu\microblaze\linux_toolchain\nt64_le\bin; 
  #$(XILINX_SDK)\gnu\microblaze\linux_toolchain\nt64_be\bin; $(XILINX_SDK)\gnu\arm\nt\bin
  set path_str "$path_str$xilinx_sdk/gnu/microblaze/$gnu_mbpf/bin$ps"
  set path_str "$path_str$xilinx_sdk/gnu/microblaze/linux_toolchain/$gnu_mblepf/bin$ps"
  set path_str "$path_str$xilinx_sdk/gnu/microblaze/linux_toolchain/$gnu_mbbepf/bin$ps$xilinx_sdk/gnu/arm/$gnu_mbpf/bin$ps"
  set path_str "$path_str$xilinx_sdk/gnu/aarch64/$gnu_mbpf/aarch64-none/bin$ps$xilinx_sdk/gnu/aarch32/$gnu_mbpf/gcc-arm-none-eabi/bin$ps"
  if { [info exists ::env(PATH)] } {
    set ::env(PATH) $path_str$::env(PATH)
  }
}

setup_hsm_environment

#load librdi_hsmtasks.so
# tcl prompt
set tcl_prompt1 {puts -nonewline {hsi% }}
# start editline
rdi::start_editline hsi

#source -notrace [rdi::utils::find_approot_file scripts/hsm/xillib_hw.tcl ]
#source -notrace [rdi::utils::find_approot_file scripts/hsm/xillib_sw.tcl ]
#source -notrace [rdi::utils::find_approot_file scripts/hsm/xillib_common.tcl ]

# Export all commands in hsm::utils namespace
#namespace eval hsm::utils { namespace export * }

#	Import all commands in hsm::utils namespace to hsi::utils namespace
#namespace eval hsi::utils { namespace import ::hsm::utils::* }

#catch get_sw_cores

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
