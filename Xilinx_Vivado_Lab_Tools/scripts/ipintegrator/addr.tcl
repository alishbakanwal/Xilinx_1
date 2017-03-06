############################################################################### 
#Copyright 2014 Xilinx Inc. All rights reserved
##############################################################################
#
# Address Utilities used by rules
# ----------------------------------------------------------------------------

namespace eval ::bd::addr {
	

## Utility proc to compare two segments 
# @param A first segment 
# @param B second segment to compare
# @return returns -1, 0, or 1, depending on whether segment A is less than, equal to, or greater than segment B
proc cmp_by_seg_name {A B} {
   
   #puts "!!! $B"

   set bIsExt_A false
   set bIsExt_B false

   set intf_A [get_bd_intf_pin -of_object $A]
   if {[llength $intf_A] < 1} {
	set bIsExt_A true 
   	set intf_A [get_bd_intf_port -of_object $A]
   }
   set intf_B [get_bd_intf_pin -of_object $B]
   if {[llength $intf_B] < 1} {
	set bIsExt_B true 
   	set intf_B [get_bd_intf_port -of_object $B]
   }

   #Should never happen, but if cannot identify the masters segs interface
   #default to basic comparision of master seg name
   if {[llength $intf_A] < 1 || 
       [llength $intf_B] < 1} {

   	return [string compare $A $B]
   }


   #puts $A
   #puts $B

   #puts "!!! intf of $A is $intf_A"
   #puts "!!! intf of $B is $intf_B"

   set mode_A [get_property mode $intf_A]
   set mode_B [get_property mode $intf_B]

   #puts "!!! mode of $A is $mode_A"
   #puts "!!! mode of $B is $mode_B"
   
   #set bIsMstSeg_A [expr {"Master" eq $mode_A}]
   #set bIsMstSeg_B [expr {"Master" eq $mode_B}]

   set bIsMstSeg_A [expr {$bIsExt_A ? [expr {"Slave" eq $mode_A}] : [expr {"Master" eq $mode_A}]}]
   set bIsMstSeg_B [expr {$bIsExt_B ? [expr {"Slave" eq $mode_B}] : [expr {"Master" eq $mode_B}]}]


   set bBothMst [expr {$bIsMstSeg_A && $bIsMstSeg_B}]

   set slv_seg_A [expr { $bIsMstSeg_A ? [get_bd_addr_segs -of_object $A] : $A}]
   set slv_seg_B [expr { $bIsMstSeg_B ? [get_bd_addr_segs -of_object $B] : $B}]

   #puts "!!! slave seg of $A is $slv_seg_A"
   #puts "!!! slave seg of $B is $slv_seg_B"

   set name_A [get_property name $slv_seg_A]
   set name_B [get_property name $slv_seg_B]
  
   set bIsSameName [expr {$name_A eq $name_B}]
 
   #If different names, return.
   if {[expr 0 == $bIsSameName]} {
     return [string compare $name_A $name_B]
   }


  #2. If the name is the same, (e.g. Mem vs Mem), and they are 
  #   master segments then 

  if {$bBothMst} {
      #a.  try compare based on the offset 
      set ofs_A [get_property offset $A] 
      set ofs_B [get_property offset $B] 
      set bIsSameOfs [expr {$ofs_A eq $ofs_B}]

      if {[expr 0 == $bIsSameOfs]} {
     	return [string compare $ofs_A $ofs_B]
      } ]
      
     return [string compare $A $B]
  }

   #default to just comparing the full path name
   return [string compare $A $B]
}

# ----------------------------------------------------------------------------

## If given a list of master segments, extract the mapped slave segments
## sorts based on the name of the slave seg, e.g BAR0 vs BAR1.i
## If it encounters segments named the same, e.g. Mem vs Mem, and
## they are master segments, try and sort based on the offset 
## If given a list of slave segments just the name of the slave seg
# @param vSegs list of either master or slave segments to be sorted
# @return sorted list of segments
proc sort_by_seg_name {vSegs} {
    if {[llength $vSegs] <= 1} {return $vSegs}

    return [lsort -command ::bd::addr::cmp_by_seg_name $vSegs]
}



########################################################################
######### procedure to set the base/high parameters      ###############
######### related to a particular slave segment on an ip ###############
########################################################################
proc cfg_base_high_of_slv {ip slvSeg nDefBase nDefHigh } {
	
    set vBaseHighNms [get_base_high_names_of $slvSeg] 		
    if {2 != [llength $vBaseHighNms]} {
    	#puts "!!! $slvSeg could not find BaseHigh Names"
	::bd::send_msg -of $ip \
	    -type error \
	    -msg_id 1 \
	    -text "Could not find base high parameter names for $ip.$slvSeg"      
    	return
    }	
	
    set vMstSegs [get_bd_addr_segs -of_objects $slvSeg]
    set nMstSegs [llength $vMstSegs]
	    
    set vOfsRngs [consolidate_mapped_segs $vMstSegs] 
    set nOfsRngs [llength $vOfsRngs]
	
    set sBaseName [lindex $vBaseHighNms 0] 	
    set sHighName [lindex $vBaseHighNms 1] 	
	
    set vParams {}	
	
    if {0 == $nOfsRngs} {
	#Unmapped. Reset to default values
	#puts "!!! $slvSeg is unmapped"
	    
        #puts "!!! default $sBaseName == $nDefBase"
        #puts "!!! default $sHighName == $nDefHigh"
	    
        lappend vParams CONFIG.$sBaseName $nDefBase
      	lappend vParams CONFIG.$sHighName $nDefHigh
        set_property -quiet -dict $vParams $ip
	    
    } elseif {2 < $nOfsRngs} {
	#slave mapped to more than one address that cannot be combined
	#use index 0 and throw critical warning	
	    
	set nOfs [lindex $vOfsRngs 0]
	set nRng [lindex $vOfsRngs 1]
		
	::bd::send_msg -of $ip \
			   -type critical_warning \
			   -msg_id 1 \
			   -text "$slvSeg is mapped to multiple disjoint addresses $vOfsRngs. Using $nOfs $nRng"  
		
	set nBase [format {0x%08X} $nOfs]
	set nHigh [format {0x%08X} [expr {$nOfs + $nRng - 1}]]	
	    
	#puts "!!! $sBaseName == $nBase"
	#puts "!!! $sHighName == $nHigh"
	    
	lappend vParams CONFIG.$sBaseName $nBase
	lappend vParams CONFIG.$sHighName $nHigh
	set_property -quiet -dict $vParams $ip
	    
    } else {
	#Normal slave mapped to a single address or all addresses are
	#subsets of each other		
		
	set nOfs [lindex $vOfsRngs 0]
	set nRng [lindex $vOfsRngs 1]
		
	#puts "!!! nOfs == $nOfs"
	#puts "!!! nRng == $nRng"
		
	set nBase [format {0x%08X} $nOfs]
	set nHigh [format {0x%08X} [expr {$nOfs + $nRng - 1}]]
		
	#puts "!!! $sBaseName == $nBase"
	#puts "!!! $sHighName == $nHigh"
		
	lappend vParams CONFIG.$sBaseName $nBase
	lappend vParams CONFIG.$sHighName $nHigh
	set_property -quiet -dict $vParams $ip
     }
}

########################################################################
######### procedure to consolidate the values of a group of  
######### master segments that a single slave segment is     
######### mapped into 	
#########	
######### takes a list of master segments
######### returns a list with {} or multiples of 2 values representing
########  {offset range offset range...}	
########	
######### 1. If two master segments (MS == master segments) are subsets
########      of each other, i.e. one fits completely inside 	 
#########     the other, then the enclosing segment will	  
#########     be returned.	
######### 2. For any other cases, then the set of disjointed segments
#########    values will be returned.
#########
########################################################################
proc consolidate_mapped_segs {vMS {bCombineContigious false} } {
     
    set nMS [llength $vMS]
	
    #puts "!!!"	
    #puts "!!! Mapped Segs to group are $vMS"
	
    set vOfsRngs {}
	
    if {0 == $nMS} {
	return $vOfsRngs
    } elseif { 1 == $nMS} {
	    
    	set nOfs [get_property offset [lindex $vMS 0]]
    	set nRng [get_property range  [lindex $vMS 0]]
    	lappend vOfsRngs $nOfs $nRng
	return $vOfsRngs    
	    
    } else {
	#puts "!!! consolidate segments $vMS"  
	    
	#build an array with unique offsets    
	#only a single offset and the largest range mapped to that
	#offset are added to the array
	array set dOffsets {}
    	foreach MS $vMS {
            set nOfs [get_property offset $MS]
            set nRng [get_property range  $MS] 
            
            set nOfsDecimal [expr $nOfs]
            #puts "!!! $MS"
            #puts "!!! offset == $nOfs == $nOfsDecimal"
            #puts "!!! range  == $nRng"
		    
	    if {![info exists dOffsets($nOfsDecimal)]} {
		#set dOffsets($nOfs) $nRng
		set dOffsets($nOfsDecimal) $nRng
	    } else {
		set nRngExists $dOffsets($nOfsDecimal)
		    
		#Choose the bigger segment at the same offset 
		if {$nRng > $nRngExists} {
		    #puts "!!! $nRng > $nRngExists"
		    #set dOffsets($nOfs) $nRng
		    set dOffsets($nOfsDecimal) $nRng
		}	
	    }
    	} 
	
	set nOffsets [array size dOffsets]
	#puts "!!! consolidated into $nOffsets segments"
	#foreach ofs [array names dOffsets] {
        #     puts "!!! $ofs  == $dOffsets($ofs)"    
	#}    
	    
	if {1 == $nOffsets} {
	    #puts "!!! consolidated into a single segment $vMS"  
	    foreach ofs [array names dOffsets] {
	    	#puts "!!! $ofs  == $dOffsets($ofs)"
	    	lappend vOfsRngs $ofs $dOffsets($ofs)
	    }	
		
	   #puts "!!! Returning $vOfsRngs"	
	   #puts "!!! -------------------"		
           return $vOfsRngs		
	}
	    
	#cannot sort array, extract offsets into seperate list and sort that   
	set vSortedOfs {}    
	foreach ofs [array names dOffsets] {
	   #puts "!!! $ofs  == $dOffsets($ofs)"    
	   lappend vSortedOfs $ofs 
	}
	
	#puts "!!! Before Sort of offsets $vSortedOfs"
	    
	set vSortedOfs [lsort -real $vSortedOfs]    
	#Now rebuild an list with of the unique offset and range 
	set vSortedOfsRngs {}    
	foreach ofs $vSortedOfs {   
	   lappend vSortedOfsRngs $ofs $dOffsets($ofs)
	}	
	    
	#puts "!!! Sorted offsets ranges $vSortedOfsRngs"
	    
	#Now collapse addresses that are subsets of each other into each other
	#and expand contiguous ranges into larger ranges, removing ranges from 
	#the list until we are left with ranges that are disjoint or a single  
	#range. The list is sorted offsets, which means the larger
        #offsets will be to the right, and if a range is contiguous, it
	#will eventually end up beside the range with which it will be combined.  
	#Keep looping through the list until the end is reached but no more 
	#combinations can be identified.    
	    
	#Actions    
	# DONE = Finished    
	# A2B  = Merge A into B, remove A   
	# B2A  = Merge B into A, remove B    
	# NEXT = Do nothing. Move to next set to compare
	set nIdxA    0   
	set bAction NEXT;
	    
        #puts "Action is $bAction"	
        #puts "loop done [string compare $bAction DONE]"	
	while {0 != [string compare $bAction DONE]} {
	   set nSortedOfsRngs [llength $vSortedOfsRngs]   
	   for {set idx 0 } {$idx < $nSortedOfsRngs} {incr idx 2} {
	   	set nIdxA  $idx   
		set nOfsA [lindex $vSortedOfsRngs [expr {$idx + 0}]]
   	   	set nRngA [lindex $vSortedOfsRngs [expr {$idx + 1}]]
            	set nOfsADec [expr $nOfsA]
   	   	#puts "!!! nOfsA  == $nOfsA == $nOfsADec"
          	#puts "!!! nRngA  == $nRngA"

		if {$idx == [expr {$nSortedOfsRngs - 2}]} {
		   set bAction DONE	
		   break; #out of for loop
		}	
		   
		set nOfsB [lindex $vSortedOfsRngs [expr {$idx + 2}]]
   	   	set nRngB [lindex $vSortedOfsRngs [expr {$idx + 3}]]
            	set nOfsBDec [expr $nOfsB]
   	   	#puts "!!! nOfsB  == $nOfsB == $nOfsBDec"
           	#puts "!!! nRngB  == $nRngB"
		#puts "!!!"
		#puts "!!! A2B  [::bd::addr_func isAsubsetofB $nOfsADec $nRngA $nOfsBDec $nRngB]"
		#puts "!!! B2A  [::bd::addr_func isAsubsetofB $nOfsBDec $nRngB $nOfsADec $nRngA]"
		#puts "!!!"
		   
		set nBaseA $nOfsADec   
		set nHighA [expr {$nBaseA + $nRngA - 1}]
		set nBaseB $nOfsBDec
		set nHighB [expr {$nBaseB + $nRngB - 1}]
		if {($nBaseB > $nBaseA) && ($nBaseB < $nHighA) && 
		    ($nHighB > $nBaseA) && ($nHighB < $nHighA)} {
		   #puts "!!! B subset of A"	    
		   set bAction B2A	 
		   break	    
		} elseif {($nBaseA > $nBaseB) && ($nBaseA < $nHighB) && 
			  ($nHighA > $nBaseB) && ($nHighA < $nHighB)} {
	           #puts "!!! A subset of B"	    
	           set bAction A2B 	
		   break	    
	        } elseif {[::bd::addr_func isAsubsetofB $nOfsADec $nRngA $nOfsBDec $nRngB]} {
	            #puts "!!! A subset of B"
	            set bAction A2B
		    break
		} elseif {[::bd::addr_func isAsubsetofB $nOfsBDec $nRngB $nOfsADec $nRngA]} {
		    #puts "!!! B subset of A"
		    set bAction B2A
		    break
	        } elseif {(true == $bCombineContigious) &&
			  ($nBaseB == [expr {$nHighA + 1}])} {
		    #puts "!!! A is contiguous to B"	    
				  
		    set nRngAB  [expr {$nRngA + $nRngB}]
		    #puts "!!! [format {0x%016X} $nRngA]  + [format {0x%016X} $nRngB]  == [format {0x%016X} $nRngAB]"
	            set bIsPow2	[expr {0 == [expr {$nRngAB & [expr {$nRngAB - 1}]}]} ? true : false]
	            set bIsAlgn	[::bd::addr_func isAligned $nOfsADec $nRngAB]
				  
		    #puts "AB [format {0x%016X} $nRngAB] is pow2 $bIsPow2"
		    #puts "AB [format {0x%016X} $nRngAB] Is aligned $bIsAlgn" 
				  
		    if {$bIsPow2 && $bIsAlgn} {
		    	set bAction AB
			break   
		    }
				  
		    set bAction NEXT
		    #puts "!!! Move to next comparison"	   
		 } else {
		    #puts "!!! Move to next comparison"	    
		    set bAction NEXT
		}	
	     }
             
	     #Perform the action determined in the previous comparison	
             switch $bAction {
		  DONE { break; #out of while loop
		  }	  
		  A2B {
		      #delete A	, Ofs and Rng  
		      set vSortedOfsRngs [lreplace $vSortedOfsRngs [expr {$nIdxA + 0}] [expr {$nIdxA + 0}]]
		      set vSortedOfsRngs [lreplace $vSortedOfsRngs [expr {$nIdxA + 0}] [expr {$nIdxA + 0}]]
		      #puts "!!! $vSortedOfsRngs"
		      continue;	  
		  }	  
		  B2A  {
		      #delete B	, Ofs and Rng  
		      set vSortedOfsRngs [lreplace $vSortedOfsRngs [expr {$nIdxA + 2}] [expr {$nIdxA + 2}]]
		      set vSortedOfsRngs [lreplace $vSortedOfsRngs [expr {$nIdxA + 2}] [expr {$nIdxA + 2}]]
		      #puts "!!! $vSortedOfsRngs"
		      continue;#with while loop	  
		  }
		  AB  {
		      #puts "!!! A combine with B"
		      set nRngA [lindex $vSortedOfsRngs [expr {$nIdxA + 1}]]
		      set nRngB [lindex $vSortedOfsRngs [expr {$nIdxA + 3}]]
		      #puts "!!! nRngA  == $nRngA"
		      #puts "!!! nRngA  == $nRngB"
		      set nRngAB [expr {$nRngA + $nRngB}] 	   
		      #puts "!!! nRngA + nRngB  == $nRngAB"
		      lset vSortedOfsRngs [expr {$nIdxA + 1}] $nRngAB
			  
		      set vSortedOfsRngs [lreplace $vSortedOfsRngs [expr {$nIdxA + 2}] [expr {$nIdxA + 2}]]
		      set vSortedOfsRngs [lreplace $vSortedOfsRngs [expr {$nIdxA + 2}] [expr {$nIdxA + 2}]]
		      #puts "!!! $vSortedOfsRngs"
		      continue;#with while loop	  
		  }
		  NEXT  { continue;#with while loop	  
		  }
             }	     
	}
	    
	set vOfsRngs $vSortedOfsRngs 
    }
	    
    set nOfsRngs [llength $vOfsRngs]
    #puts "!!! Returning $vOfsRngs"	
    #puts "!!! -------------------"	
    return $vOfsRngs
}
	

########################################################################
######### procedure to obtain the names of the base and high parameters
######### related to a particular slave segment
#########	
######### takes a slave segment	
######### returns list with {} or {basename highname}	
########################################################################
proc get_base_high_names_of {slvSeg} {
    set	vBaseHighNames {}
    set sBaseName [get_property offset_base_param $slvSeg]
    set sHighName [get_property offset_high_param $slvSeg]
	
    if {[llength $sBaseName] < 1 ||
        [llength $sHighName] < 1} {
	   return $vBaseHighNames
    }
	
    lappend vBaseHighNames $sBaseName $sHighName
    return $vBaseHighNames	 
}

proc is_any_MSsupersetofA {dMS nOfsA nRngA} {
	
    dict for {MS vOfsRng} $dMS {
        #puts "$MS == $vOfsRng"
	set nOfsB [lindex $vOfsRng 0] 	
	set nRngB [lindex $vOfsRng 1] 		    
	if {[::bd::addr_func isAsubsetofB $nOfsA $nRngA $nOfsB $nRngB]} {
		return true
	}
    } 
    
   return false
}
	
########################################################################
######### procedure to determine whether or not an MMU is required for an SI
######### most commonly the SI of an interconnect
######### takes an SI bif	
######### returns True or False
########################################################################
proc is_mmu_required_for {SI_BIF} {
	
   #Notation KEY
   #  SI == Slave bif	 
   #  MI == Master bif	 
   #  SS == Slave Segment
   #  MS == Master segment	 
	
   #puts "!!! IS_MMU_REQUIRED FOR $SI_BIF"	 
	
   set mode_SI [get_property mode $SI_BIF]
   set bIsSlaveBif [expr {"Slave" eq $mode_SI}]	
	
   if {false == $bIsSlaveBif} {
	return false;
   }	   
	
   set vSI_addressed   [get_bd_addr_segs -addressed   -of_object $SI_BIF]
   set vSI_addressable [get_bd_addr_segs -addressable -of_object $SI_BIF]
   set vSI_addressing  [get_bd_addr_segs -addressing  -of_object $SI_BIF]
	
   #Check and make sure all the mappable segments are mapped
   #puts "!!! $SI_BIF addressable $vSI_addressable"
   #puts "!!! $SI_BIF addressed   $vSI_addressed"
   #puts "!!! $SI_BIF addressing  $vSI_addressing"
	
   if {[llength $vSI_addressed] !=  
       [llength $vSI_addressable]} {
       #puts "!!! $SI_BIF requires an MMU"
       return true;
   }	
	
   #Get the master segments visible to this slave bif
   #set vSI_MS [get_bd_addr_segs -addressing -of_object $SI_BIF]
   #puts "!!! $SI_BIF addressing $vSI_MS"
	
   #Save the MS's directly accessible to this bif
   set dSI_MS [dict create]
   foreach SI_MS $vSI_addressing {
   	set nSI_MS_Ofs [get_property offset $SI_MS]
   	set nSI_MS_Rng [get_property range  $SI_MS] 
   	dict set dSI_MS $SI_MS [list $nSI_MS_Ofs $nSI_MS_Rng]	
   } 
	
   set dOfsRng [dict create]	
   set dOfsRng [dict create]
	
   foreach SI_SS $vSI_addressed {
   	set vSS_MS [get_bd_addr_segs -of_object $SI_SS]
	#puts "!!! $SI_SS addressed by $vSS_MS"
   	foreach SS_MS $vSS_MS {
   	    if {![dict exists $dOfsRng $SI_SS]} {
   	     	 set nSS_MS_Ofs [get_property offset $SS_MS]
		 set nSS_MS_Rng [get_property range  $SS_MS] 
		 #puts "!!! 1 SS_MS == $SS_MS $nSS_MS_Ofs"
		 #puts "!!! 1 SS_MS == $SS_MS $nSS_MS_Rng"
		       
	    	 dict set dOfsRng $SI_SS [list $nSS_MS_Ofs $nSS_MS_Rng]	
	    	 continue
	    }
		   
	    if {[dict exists $dSI_MS $SS_MS]} {
	    	
		#puts "!!! 2 $SS_MS is visible to $SI_BIF"
		#Get the slave segment of this master segment and see
		#if its stored values are less than this 
	    	set MS_SS [lindex [get_bd_addr_segs -of_object $SS_MS] 0]
	    	if {[dict exists $dOfsRng $MS_SS]} {
	           set vOfsRng_SS [dict get $dOfsRng $MS_SS]	
	    	   set nSS_Ofs [lindex $vOfsRng_SS 0] 	
	    	   set nSS_Rng [lindex $vOfsRng_SS 1] 	
			       
	    	   set nMS_SS_Ofs [get_property offset $SS_MS] 	
	    	   set nMS_SS_Rng [get_property range  $SS_MS] 
		   if {[::bd::addr_func isAsubsetofB $nSS_Ofs $nSS_Rng $nMS_SS_Ofs $nMS_SS_Rng]} {
		   	#puts "!!! 2 Resetting stored values for $MS_SS"
		   	dict set dOfsRng $SI_SS [list $nMS_SS_Ofs $nMS_SS_Rng]
		   }
	    	}
		#puts "!!! 2 $MS_SS is slave of to $SI_BIF"
	    } else {
		#If this segment visible from this location any of the 
		#segments mapped into this location cover this segment, 
		#then no need to compare it     
		set nOfsA [get_property offset $SS_MS] 	
		set nRngA [get_property range  $SS_MS] 	
		if {[is_any_MSsupersetofA $dSI_MS $nOfsA $nRngA]} {
			continue; #looping through master segments
		}
	    }
             		   
	    set vOfsRng_SS [dict get $dOfsRng $SI_SS]	
	    set nSS_Ofs [lindex $vOfsRng_SS 0] 	
	    set nSS_Rng [lindex $vOfsRng_SS 1] 	
		
	    set nMS_Ofs [get_property offset $SS_MS]
	    set nMS_Rng [get_property range  $SS_MS] 
		
	    #puts "!!! 2 SS_MS == $SS_MS $nMS_Ofs"
	    #puts "!!! 2 SS_MS == $SS_MS $nMS_Rng"
		
      	    set bOfsMatch [expr $nSS_Ofs eq $nMS_Ofs] 
      	    set bRngMatch [expr $nSS_Rng eq $nMS_Rng] 
      	    set bIsSubset [expr [::bd::addr_func isAsubsetofB  $nSS_Ofs $nSS_Rng $nMS_Ofs $nMS_Rng] ||\
      	    		        [::bd::addr_func isAsubsetofB  $nMS_Ofs $nMS_Rng $nSS_Ofs $nSS_Rng]]
		
	    #puts "!!! bOfsMatch == $bOfsMatch"
	    #puts "!!! bRngMatch == $bRngMatch"
	    #puts "!!! bIsSubset == $bIsSubset"
		
	    set bMatch [expr {$bOfsMatch && $bRngMatch}]
	    #puts "!!! bMatch    == $bMatch"
		    
	    if {0 == $bMatch} {
	    	return true;
	    }
	}
   }
	
   #puts "!!! $SI_BIF does NOT require an MMU"
   return false
} 

################################################################################
######### procedure to collapse the addresses visible to an MI BI
######### most commonly the MI of an interconnect removing duplicates
######### and choosing the largest aperture and combining contigious addresses
######### takes an MI bif	
######### returns a list of ofs rng tuples i.e. [list [ofs rng] [ofs rng]]
################################################################################
proc get_addresses_of {MI_BIF {bCombineContigious true} } {
	
    #Get the master segments visible to this slave bif	
    set vMI_SS [get_bd_addr_segs -addressable -of_object $MI_BIF]
    set vMI_MS [get_bd_addr_segs -addressing  -of_object $MI_BIF]
	
    set dMI_MS [dict create]
    foreach MI_MS $vMI_MS {
    	#puts "MS for $MI_BIF == $MI_MS"
	set nMI_MS_Ofs [get_property offset $MI_MS]
	set nMI_MS_Rng [get_property range  $MI_MS]
	dict set dMI_MS $MI_MS [list $nMI_MS_Ofs $nMI_MS_Rng]	
    } 
    
    #puts "SS for $MI_BIF == $vMI_SS"
    #puts "MS for $MI_BIF == $vMI_MS"
	
    #Sort the master segments by slave segment
    set dSS_MS [dict create]
    foreach MI_SS $vMI_SS {
    	set vSS_MS [get_bd_addr_segs -of_object $MI_SS]
    	set nSS_MS [llength $vSS_MS]
    	foreach SS_MS $vSS_MS {
	    #set SS_MS [lindex $vSS_MS 0]
	    if {![dict exists $dMI_MS $SS_MS]} {
	    	continue
	    } else {
		set dMI_MS [dict remove $dMI_MS $SS_MS]	
	    }		    
		    
	    if {![dict exists $dSS_MS $MI_SS]} {
		    #puts "!!! SSxMS  == $SS_MS  x $MS_AS"
		    dict set dSS_MS $MI_SS [list $SS_MS]	
		    continue
	     }
		       
	     set vMS [dict get $dSS_MS $MI_SS]
	     lappend vMS $SS_MS      
	     dict set dSS_MS $MI_SS $vMS
	}
    }
    
    #puts "dMI_MS == [dict size $dMI_MS]"
	
    set vALL_MS {}
    dict for {SS vMS} $dSS_MS {
	#puts "vMS == $vMS"  
	 set vALL_MS [list {*}$vALL_MS {*}$vMS]
    } 
	
    #dict for {MI_MS vOfsRng} $dMI_MS {	
	 #set vALL_MS [list {*}$vALL_MS $MI_MS]
    #}
    #puts "$MI_BIF == $vALL_MS"	
	
    set vOfsRngs [consolidate_mapped_segs $vALL_MS $bCombineContigious]
	
    set nOfsRngs [llength $vOfsRngs]
    set vOfsRngTuples {}
    set nIdx 0	
	
    #puts "!!! nIdx     == $nIdx"
    #puts "!!! nOfsRngs == $nOfsRngs"	
    #puts "!!! vOfsRngs == $vOfsRngs"	
	  
    while {$nIdx < $nOfsRngs} {
	set oIdx $nIdx    
	set rIdx [expr {$nIdx + 1}]
	
	set nOfs [lindex $vOfsRngs $oIdx]
	set nRng [lindex $vOfsRngs $rIdx]
	set nHex [format {0x%016llX} $nOfs]
	    
	#puts "!!! nOfs == $nOfs == $nHex"
	#puts "!!! nRng == $nRng"
	#lappend vOfsRngTuples [list [lindex $vOfsRngs $nOfs] [lindex $vOfsRngs $nRng] ] 
	lappend vOfsRngTuples [list $nHex $nRng]
	set nIdx [expr {$nIdx + 2}]
    }
	
    #puts "!!! $MI_BIF == $vOfsRngTuples"
	
    return $vOfsRngTuples
}	

}
# end namespace ::bd::addr


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
