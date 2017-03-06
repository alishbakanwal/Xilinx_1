package require Tcl 8.5

set loaded 0
foreach d $::auto_path {
    if { ![catch {load [file join $d librdi_commontasks[info sharedlibextension]]}] &&
	 ![catch {load [file join $d librdi_hsmtasks[info sharedlibextension]]}]} {
	set loaded 1
	break
    }
}
if { !$loaded } {
    load librdi_commontasks[info sharedlibextension]
    load librdi_hsmtasks[info sharedlibextension]
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
    }

    set path_str "$path_str$xilinx_sdk/gnu/microblaze/$gnu_mbpf/bin$ps"
    set path_str "$path_str$xilinx_sdk/gnu/microblaze/linux_toolchain/$gnu_mblepf/bin$ps"
    set path_str "$path_str$xilinx_sdk/gnu/microblaze/linux_toolchain/$gnu_mbbepf/bin$ps$xilinx_sdk/gnu/arm/$gnu_mbpf/bin$ps"
    if { [info exists ::env(PATH)] } {
      set ::env(PATH) $path_str$::env(PATH)
    }
}
setup_hsm_environment

if { [info commands rdi::tcl::package] != "" } {
   rename package rdi::package
   rename rdi::tcl::package package
}
if { [info commands tcl::source] != "" } {
   rename source rdi::source
   rename tcl::source source
}
package provide hsi 0.1
