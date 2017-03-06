# % load_feature tclstore

# Initialize Xilinx Tcl Store
# Pre-condition: librdi_commontasks loaded

# rdi::register_proc and rdi::unregister_proc was moved to ::common 
# For the time being we import into rdi to make sure tclapp::load_apps 
# continue to work. Ultimately the tclapp support scripts should be 
# changed to use common::register_proc and common::unregister_proc
namespace eval rdi { namespace import ::common::register_proc ::common::unregister_proc }

if {[::tclapp::use_local]} { 
  catch {::tclapp::get_readable_repo_path}
  if {[tclapp::use_local]} { 
    lappend auto_path [::tclapp::get_user_repo_path]
  }
  if {[tclapp::use_local]} { 
    ::tclapp::create_tclstore
    if {[::tclapp::tcl_store_on]} {
      [catch {::tclapp::update_support}]
      [catch {::tclapp::register_persist_apps}]
      [catch {::tclapp::update_tclstore}]
    }
  } else {
    lappend auto_path [::tclapp::get_readable_repo_path]
  }
} else {
  lappend auto_path [::tclapp::get_readable_repo_path]
} 


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
