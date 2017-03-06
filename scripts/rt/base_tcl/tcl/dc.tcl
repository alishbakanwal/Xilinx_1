namespace eval rtdc {
    proc getObjRef {obj objClass quiet} {
        set objRef $obj
        if {[rt::typeOf $objRef] eq "NULL"} {
            if {$objClass eq ""} {
                if {!$quiet} { puts "warning: object class type not specified" }
                return ""
            }
            switch -- $objClass {
                "lib_cell" {
                    set objRef [find -obj -lib_cell $obj]
                    if {$objRef ne "NULL"} {
                        set objRef [$objRef isCell]
                    }
                }
                "cell" -
                "inst"      { set objRef [find -obj -instance $obj] }
                "net"       { set objRef [find -obj -net $obj] }
                "pin"       { set objRef [find -obj -pin $obj] }
                "lib_pin"   {
                    set objRef {}
                    if {[regexp (.*)\/(.*) $obj match cell pin]} {
                        set cells [find -obj -lib_cell $cell]
                        foreach cell $cells {
                            set port [$cell findPort $pin]
                            if {$port ne "NULL" && $port ne ""} {
                                lappend objRef $port
                            }
                        }
                    }
                }
                "module" { set objRef [find -obj -module $obj] }
                "clock" { set objRef [[rt::design] findClocks $obj] }
                "power_domain" {set objRef [find -obj -power_domain $obj] }
                default {
                    if {!$quiet} { puts "warning: unknown object class type \'$objClass\'" }  
                    return ""
                }
            } 
        }
        return $objRef
    }
    
    proc getCellAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NCellS"} {
            return -code error "unexpected object type for \'[$objRef name $UNM_sdc]\'"
        }
        
        if {$attr eq "object_class"} {
            return "lib_cell"
        }
        
        return [$objRef getGAttribute $attr $quiet]
    }
    
    proc getModAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NRealModS"} {
            return -code error "unexpected object type for \'[$objRef name $UNM_sdc]\'"
        }
        
        if {$attr eq "object_class"} {
            return "design"
        }
        
        return [$objRef getGAttribute $attr $quiet]
    }
    
    proc getInstAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NInstS"} {
            return -code error "unexpected object type for \'[$objRef name $UNM_sdc]\'"
        }
        
        if {$attr eq "object_class"} {
            return "cell"
        }
        
        set val [$objRef getGAttribute $attr $quiet]
        switch -- $attr {
            "bbox" {
                if {[llength $val] != 4} {
                    return ""
                } else {
                    set top    [lindex $val 0]
                    set bottom [lindex $val 1]
                    set left   [lindex $val 2]
                    set right  [lindex $val 3]
                    
                    set bboxList [list]
                    lappend bboxList $top
                    lappend bboxList $bottom
                    lappend bboxList $left
                    lappend bboxList $right
                    
                    set ll [list]
                    set lr [list]
                    set ur [list]
                    set ul [list]
                    
                    lappend ll $left
                    lappend ll $bottom
                    
                    lappend lr $right
                    lappend lr $bottom
                    
                    lappend ur $right
                    lappend ur $top
                    
                    lappend ul $left
                    lappend ul $top
                    
                    lappend bboxList $ll
                    lappend bboxList $lr
                    lappend bboxList $ur
                    lappend bboxList $ul
                    
                    return $bboxList
                }
            }
            "origin" {
                if {[llength $val] != 2} {
                    return ""
                } else {
                    set origin [list]
                    lappend origin [lindex $val 0]
                    lappend origin [lindex $val 1]
                    return $origin
                }
            }
            "movebound" {
                if {[llength $val] != 4} {
                    return ""
                } else {
                    set top    [lindex $val 0]
                    set bottom [lindex $val 1]
                    set left   [lindex $val 2]
                    set right  [lindex $val 3]
                    
                    set moveBoundList [list]
                    lappend moveBoundList $top
                    lappend moveBoundList $bottom
                    lappend moveBoundList $left
                    lappend moveBoundList $right
                    
                    set ll [list]
                    set lr [list]
                    set ur [list]
                    set ul [list]
                    
                    lappend ll $left
                    lappend ll $bottom
                    
                    lappend lr $right
                    lappend lr $bottom
                    
                    lappend ur $right
                    lappend ur $top
                    
                    lappend ul $left
                    lappend ul $top
                    
                    lappend moveBoundList $ll
                    lappend moveBoundList $lr
                    lappend moveBoundList $ur
                    lappend moveBoundList $ul
                    
                    return $moveBoundList
                }
            }
            default { return $val }
        }
    }
    
    proc getNetAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NNetS"} {
            return -code error "unexpected object type for \'[$objRef name $UNM_sdc]\'"
        }
        
        if {$attr eq "object_class"} {
            return "net"
        }
        
        return [$objRef getGAttribute $attr $quiet]
    }
    
    proc getPinAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NPinS"} {
            return -code error "unexpected object type for \'[$objRef name $UNM_sdc]\'"
        }
        
        if {$attr eq "object_class"} {
            set inst [$objRef ownerInstance]
            if {$inst eq "NULL"} {
                return "port"
            } else {
                return "pin"
            }
        }
        
        return [$objRef getGAttribute $attr $quiet]
    }
    
    proc getLibPinAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NPort"} {
            return -code error "unexpected object type for \'[$objRef name]\'"
        }
        
        if {$attr eq "object_class"} {
            return "lib_pin"
        }
        
        return [$objRef getGAttribute $attr $quiet]
    }
    
    proc getClockAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "TClock"} {
            return -code error "unexpected object type for \'[$objRef name]\'"
        }
        
        if {$attr eq "object_class"} {
            return "clock"
        }
        
        set val [$objRef getGAttribute $attr $quiet]
        
        switch -- $attr {
            "sources" {
                if {$val ne "" && $val ne "NULL"} {
                    set srcList [expr $val]
                } else {
                    set srcList ""
                }
                return $srcList
            }
            default { return $val }
        }
    }
    
    proc getTimingPathAttribute {quiet objRef attr} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "TTimingPath"} {
            return -code error "unexpected object type"
        }
        
        if {$attr eq "object_class"} {
            return "timing_path"
        }
        
        set val [$objRef getGAttribute $attr $quiet]
        
        switch -- $attr {
            "startpoint_clock" -
            "endpoint_clock"   { return [sdcrt::findClocksInCurrentMode $val]  }
            "startpoint" -
            "endpoint" {
                if {$val ne "" && $val ne "NULL"} {
                    set pin [expr $val]
                } else {
                    set pin ""
                }
                return $pin
            }
            "slack" { return [string trimright $val "ps"] }
            default { return $val }
        }
    }
    
    proc getAttribute {quiet objClass objList attr} {
        set values {}
        array unset valueAdded
        
        foreach obj $objList {
            set objRef [rtdc::getObjRef $obj $objClass $quiet]
            
            if {$objRef eq "NULL" || $objRef eq "" || [llength $objRef] == 0} {
                if {!$quiet} { puts "warning: could not find an object for \'$obj\'." }
                continue
            }
            
            set objType [rt::typeOf $objRef]
            switch -- $objType {
                "NRefS" -
                "NCellS"      {
                    set attrValue [rtdc::getCellAttribute $quiet $objRef $attr]
                }
                "NRealModS"   {
                    set attrValue [rtdc::getModAttribute $quiet $objRef $attr]
                }
                "NInstS"      {
                    set attrValue [rtdc::getInstAttribute $quiet $objRef $attr]
                }
                "NNetS"       {
                    set attrValue [rtdc::getNetAttribute $quiet $objRef $attr]
                }
                "NPort"       {
                    set attrValue [rtdc::getLibPinAttribute $quiet $objRef $attr]
                }
                "NPinS"       {
                    set attrValue [rtdc::getPinAttribute $quiet $objRef $attr]
                }
                "TClock"      {
                    set attrValue [rtdc::getClockAttribute $quiet $objRef $attr]
                }
                "TTimingPath" {
                    set attrValue [rtdc::getTimingPathAttribute $quiet $objRef $attr]
                }
                default       {
                    if {!$quiet} { "unknown type of object \'$objType\' for \'[$objRef name]\'" }
                    continue
                }
            }
            # append if string list or merge if collection of objects
            if {$objClass ne "" || ![info exists valueAdded($attrValue)]} {
                set valueAdded($attrValue) 1
                lappend values $attrValue
            }
        }
        
        if {[llength $values] == 1} {
            set values [lindex $values 0]
        }
        
        return [utils::flatList $values]
    }
    
    proc setCellAttribute {quiet objRef attr value} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NCellS"} {
            return -code error "unexpected object type for \'[$objRef name]\'"
        }
        
        $objRef setGAttribute $attr $value $quiet
        return
    }
    
    proc setInstAttribute {quiet objRef attr value} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NInstS"} {
            return -code error "unexpected object type for \'[$objRef name]\'"
        }
        
        $objRef setGAttribute $attr $value $quiet
        return
    }
    
    proc setNetAttribute {quiet objRef attr value} {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NNetS"} {
            return -code error "unexpected object type for \'[$objRef name]\'"
        }
        
        $objRef setGAttribute $attr $value $quiet
        return
    }
    
    proc setPinAttribute {quiet objRef attr value { fromXdc false } } {
        global UNM_sdc
        
        if {[rt::typeOf $objRef] ne "NPinS"} {
            return -code error "unexpected object type for \'[$objRef name]\'"
        }
        
        switch -- $attr {
            "location" {
                if {!$quiet && [llength $value] != 2} {
                    puts "warning: unexpected value \'$value\' in set_attribute"
                    return
                }
                $objRef setGAttribute $attr "[lindex $value 0] [lindex $value 1]" $quiet
            }
            "layer" {
                if {[llength $value] == 0} {
                    if {! $quiet} { puts "warning: incorrect number of values in set_attribute" }
                    return
                }
                set numLayers [lindex $value 0]
                if {[llength $value] != [expr {$numLayers * 5 + 1}]} {
                    if {! $quiet} { puts "warning: incorrect number of values in set_attribute" }
                    return
                }
                
                set pinIdx [$objRef index]
                set maxLayer [$rt::db maxRouteLayer]
                set err 0
                for {set i 0} {$i < $numLayers} {incr i} {
                    set layerName [lindex $value [expr {$i * 5 + 1}]]
                    
                    set foundLayer 0
                    for {set j 0} {$j < $maxLayer} {incr j} {
                        set routeLayerName [$rt::db routeLayerName $j]
                        if {$layerName == $routeLayerName} {
                            set foundLayer 1
                            break
                        }
                    }
                    if {$foundLayer == 0} {
                        if {! $quiet} { puts "warning: unknown layer name \'$layerName\' in set_attribute" }
                        set err 1
                    }
                }
                if {$err} {
                    return
                }
                
                set attrValStr [lindex $value 0]
                for {set i 1} {$i < [llength $value]} {incr i} {
                    set attrValStr "$attrValStr [lindex $value $i]"
                }
                $objRef setGAttribute $attr $attrValStr $quiet
            }
            default {
                $objRef setGAttribute $attr $value $quiet
                return
            }
        }
    }
    
    proc setAttribute {quiet objClass obj attr value} {
        set objRef [rtdc::getObjRef $obj $objClass $quiet]
        
        if {$objRef eq "NULL" || $objRef eq "" || [llength $objRef] == 0} {
            if {!$quiet} { puts "warning: could not find an object for \'$obj\'." }
            return
        }
        
        if {[llength $objRef] > 1} {
            if {!$quiet} { puts "warning: more than one object specified in \'set_attribute $obj $attr\'" }
            return
        }
        
        set objType [rt::typeOf $objRef]
        switch -- $objType {
            "NPinS"    { return [rtdc::setPinAttribute $quiet $objRef $attr $value] }
            "NNetS"    { return [rtdc::setNetAttribute $quiet $objRef $attr $value] }
            "NInstS"   { return [rtdc::setInstAttribute $quiet $objRef $attr $value] }
            "NCellS"   { return [rtdc::setCellAttribute $quiet $objRef $attr $value] }
            default    { return -code error "unknown type of object \'$objType\' for \'[$objRef name]\' in set_attribute" }
        }
    }
    
    # extend this list as new attributes are supported...
    variable aSynthAttrs
    array set aSynthAttrs {
        BUFFER_TYPE    "supported"
		CLOCK_BUFFER_TYPE "supported"
		IO_BUFFER_TYPE  "supported"
		DONT_TOUCH     "supported"
        GATED_CLOCK    "supported"
        KEEP           "supported"
        KEEP_HIERARCHY "supported"
        MARK_DEBUG     "supported"
        MAX_FANOUT     "supported"
        RAM_STYLE      "supported"
        ROM_STYLE      "supported"
        USE_DSP48      "supported"
        SEU_PROTECT    "supported"
        ESSENTIAL_CLASSIFICATION_VALUE "supported"
        HD.PARTITION   "supported"
        HD.ISOLATED    "supported"
        HD.RECONFIGURABLE "supported"
		DIRECT_ENABLE   "supported"
		DIRECT_RESET   "supported"
		SHREG_EXTRACT  "supported"
		IOB            "supported"
		FSM_ENCODING   "supported"
		FSM_SAFE_STATE "supported"
		ASYNC_REG      "supported"
		CASCADE_HEIGHT  "supported"
		RW_ADDR_COLLISION "supported"
		EXTRACT_ENABLE "supported"
		EXTRACT_RESET "supported"
		META_OPT        "supported"
		SRL_STYLE     "supported"
		PIPE_ENDPOINT   "supported"
		PIPE_STARTPOINT "supported"
    }
    
    variable aXdcFileInfo
    array set aXdcFileInfo {}
	
	#added to extract the leading number in $fid in proc setProperty
	proc getNumberInString {str} {
		set num [lindex [split $str] 0]
		return $num
	}
    # note: by definition, these are always 'read from xdc'
    proc setProperty {quiet attr value obj} {
        
        variable aSynthAttrs
        variable aXdcFileInfo
        global sdcrt::cachedfname
        global sdcrt::cachedlnum
        
        if { $attr == "SRC_FILE_INFO" } {
            if { [regexp "cfile:(.*) rfile:(.*) id:(.*) " $value match fpath rpath fid]} {
				set realFid [getNumberInString $fid]
				set aXdcFileInfo(id_$realFid) $fpath
				return
            }
            if { [regexp "cfile:(.*) rfile:(.*) id:(.*)" $value match fpath rpath fid]} {
				set realFid [getNumberInString $fid]
				set aXdcFileInfo(id_$realFid) $fpath
				return
            }
        }
        
        if { $attr == "src_info" } {
            # grab src_info values and cache them for access by next command
            regexp "type:(.*) file:(.*) line:(.*) export:(.*) save:(.*) read:(.*)" $value match type fid line export save_ read_
            if { ($type eq "TCL") || ($type eq "PI") } {
                #set cachedfname "NONE (auto generated)"
                #set cachedlnum "NOLINE"
                set cachedfname "auto generated constraint"
                set cachedlnum ""
            } else {
                set cachedfname $aXdcFileInfo(id_$fid)
                set cachedlnum $line
            }
            return 
        }
        
        global ::rt::presdc::timing_is_disabled
        if { $timing_is_disabled && ([rt::get_parameter readLatencyFile] == false) &&  ($attr == "PIPE_ENDPOINT") } {
          # skip PIPE_ENDPINT for processing set_property, it will be handled by timing constraint later.
          return
        }  
        if { ! $timing_is_disabled && !(([rt::get_parameter readLatencyFile] == true) && ($attr == "PIPE_ENDPOINT")) } {
            # timing is not disabled, so set_property iS disabled
            # we do this because otherwise many of the set_property calls will bounce
            # but "PIPE_ENDPOINT" should be processed due to not finding the "PIN".  
            return
        }
        
        # just check and get out if no objects
        if { $obj == "" } {
            if {!$quiet} {
                puts "WARNING: set_property $attr could not find object (constraint file \
	$cachedfname, line $cachedlnum)."
            }
            return
        }
        
        set objRef [rtdc::getObjRef $obj "" $quiet]
        
        if {$objRef eq "NULL" || $objRef eq "" || [llength $objRef] == 0} {
            if {!$quiet} {
                puts "WARNING: set_property $attr for \'$obj\': could not find object (constraint file \
		  $cachedfname, line $cachedlnum)."
            }
            return
        }
        
        foreach anobj $objRef {
            
            set objType [rt::typeOf $anobj]
            
            switch -- $objType {
                "SBlock" -
                "NPinS"  -
                "NNetS"  -
                "NInstS" {
                    # see aSynthAttrs list definition above for support attr list.
                    set ucattr [string toupper $attr]
                    if { [ info exists aSynthAttrs($ucattr) ] } {
                        
                        if { $aSynthAttrs($ucattr) eq "not supported" } {
                            if { $cachedfname ne "" } {
                                puts "WARNING: set_property $attr for '[$anobj name]' is not supported (constraint file \
				  $cachedfname, line $cachedlnum). Insert this attribute in your hdl source instead."
                            } else {
                                puts "WARNING: set_property $attr for '[$anobj name]' is not supported. Insert this attribute in your hdl source instead."
                            }
                            return ; # not failed, just isn't going to work.
                        }
                        
                        # ok, its a supported attribute... so lets set it.
						set success [$rt::db setXdcDirective $anobj $attr $value]
						if {$cachedfname ne "" && $success == 1} {
							puts "Applied set_property $attr = $value for [$anobj fullName]. (constraint file \
				  $cachedfname, line $cachedlnum)."
                        }
                    } else {            
                        # this captures the attribute for potential propagation after synthesis.
                        $rt::db setXdcAttribute $anobj $attr $value
                    }
                    continue
                }
                default  {
                    if { $cachedfname ne "" } {
                        return -code error "unsupported object type for \'[$anobj name]\' in set_property command \
			  (constraint file $cachedfname, line $cachedlnum)."
                    } else {
                        return -code error "unsupported object type for \'[$anobj name]\' in set_property command."
                    }
                }
            }
        }
    }
    
    proc removeInputDelay {pins} {
        set pinList [sdcrt::pinList $pins]
        foreach pin $pinList {
            $pin removeInputDelay
        }
        rt::release $pinList
    }
    
    proc removeInputTransition {pins} {
        set pinList [sdcrt::pinList $pins]
        foreach pin $pinList {
            $pin removeInputTransition
        }
        rt::release $pinList
    }
    
    proc removeDrivingCell {pins} {
        set pinList [sdcrt::pinList $pins]
        foreach pin $pinList {
            $pin removeDrivingCell
        }
        rt::release $pinList
    }
    
    proc removeOutputDelay {pins} {
        set pinList [sdcrt::pinList $pins]
        foreach pin $pinList {
            $pin removeOutputDelay
        }
        rt::release $pinList
    }
    
    proc removeLoad {pins} {
        set pinList [sdcrt::pinList $pins]
        foreach pin $pinList {
            $pin removeLoad
        }
        rt::release $pinList
    }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
