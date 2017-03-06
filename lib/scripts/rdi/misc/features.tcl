# 
# This script defines all Rodin features available
# Script is sourced at application startup time

namespace eval rdi {
    set approot $::env(HDI_APPROOT)
    set ldext [info sharedlibextension]
    set task_libraries {}

    proc load_library { feature library } {
        if { [lsearch $rdi::task_libraries $library$rdi::ldext] == -1 } {
            if {[catch {uplevel 1 load $library$rdi::ldext} result]} {
                error "$result\nCould not load library '$library' needed by '$feature', please check installation."
            }
            lappend rdi::task_libraries $library$rdi::ldext
        }
    }

    proc load_internal_library { feature library } {
        if { [get_param tcl.dontLoadInternalLibraries] == 0 } {
            if { [lsearch $rdi::task_libraries $library$rdi::ldext] == -1 } {
                if {[catch {uplevel 1 load $library$rdi::ldext} result]==0} {
                    lappend rdi::task_libraries $library$rdi::ldext
                }
            }
        }
    }
}

namespace eval rdi::utils {
    set platformSeparator ":"
    if {[info exist tcl_platform(platform)] && ($tcl_platform(platform) == "windows")} {
        set platformSeparator ";"
    }
    proc find_approot_file {relPath} {
        variable platformSeparator
        set foundFile [file join $rdi::approot $relPath]
        foreach rdiRoot [split "$::env(RDI_APPROOT)" $platformSeparator] {
            set foundFile [file join $rdiRoot $relPath]
            if {[file exists $foundFile]} {
                break
            }
        }
        return $foundFile
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
