# Main tcl script executed through the updatemem loader
# From here you can call any tcl command known to the product
# Here is an example

proc updatemem_proc {args} {
  #puts "updatemem executable is live!!"
  #puts "update_mem $args"
  
  set arg1 [lindex $args 0]
  update_mem {*}$arg1
}

if [catch {updatemem_proc $argv} result] {
 puts $result
}




# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
