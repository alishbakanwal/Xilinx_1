interp hide {} get_nets __get_nets
interp alias {} get_nets {} my_get_nets
interp hide {} set_property __set_property
interp alias {} set_property {} my_set_property

set dont_touch_txt [open "dont_touch.txt" "w"]
proc my_get_nets { net args } {
    global dont_touch_txt;
    set keep_net [interp invokehidden {} __get_nets -quiet $net]
    if { [string length $keep_net] == 0 } {
        return
    }

    set cells [get_cells -quiet -of_objects [interp invokehidden {} __get_nets -quiet $net]]
    if { [string length $cells] == 0 } {
        return
    }

    set parent_mod [get_property -quiet PARENT [lindex [get_cells -quiet -of_objects [lindex [interp invokehidden {} __get_nets -quiet $net] 0] ] 0 ] ]
    
    set owner_mod $parent_mod
    if { [string length $parent_mod] == 0 } {
        set owner_mod $rt::top
    }
    set bus_name [get_property -quiet BUS_NAME [lindex [interp invokehidden {} __get_nets -quiet $net] 0]]
    
    if { [string length $bus_name] == 0 } {
        set net_name [string range $keep_net [expr [string last "/" $keep_net] + 1 ] [string length $keep_net]]
    } else {
        set net_name [string range $bus_name [expr [string last "/" $bus_name] + 1 ] [string length $bus_name]]
    }
    puts $dont_touch_txt "$owner_mod $net_name"
}


proc my_set_property { property value  args } {
}




# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
