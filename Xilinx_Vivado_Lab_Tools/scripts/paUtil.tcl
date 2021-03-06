# COPYRIGHT NOTICE
# Copyright 1986-1999, 2001-2009 Xilinx, Inc. All Rights Reserved.
# 

namespace eval paUtil {
   namespace export launchParallelRuns 
   namespace export memStat
   namespace export generateSSF
   namespace export csv2ssf

   global ::paUtil::_LAUNCH_PAR_HOST_LIST ""
   global ::paUtil::_LAUNCH_PAR_EMAIL_LIST ""
   global ::paUtil::_LAUNCH_PAR_EMAIL_EVERY_JOB ""

   variable _CSV_INDEX
   variable _CSV_BUS_REGEXP {(\S+)\[(\S+)\]}
   variable _SSF_PIN_LABEL_UNIQUE
   variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL 200
   variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL_SIDE 100
   variable _SSF_SETTINGS_SITE_TYPE_REGEXP_LIST [list {IO.*GC.*} {IO.*} {MGT.*CLK.*} {MGT.*} {VCC.*|VBATT.*} {GND.*} {RSVD.*} {NC.*}]

   proc _INIT_CSV_INDEX {valueList} {
      # TODO - document this proc
      # IO Bank,Pin Number,IOB Alias,Site Type,Prohibit,Interface,Signal Name,Direction,DiffPair Type,DiffPair Signal,IO Standard,Drive (mA),Slew Rate
      variable _CSV_INDEX

      for {set x 0} {$x < [llength $valueList]} {incr x} {
         set _CSV_INDEX([lindex $valueList $x]) $x
      }
   }

   proc _GET_CSV_INDEX {name} {
      # TODO - document this proc
      variable _CSV_INDEX
      return $_CSV_INDEX($name)
   }

   proc _INIT_SSF_PIN_LABEL_UNIQUE {data} {
      # TODO - document this proc
      # reset all the pin label uniquifiers to 0
      variable _SSF_PIN_LABEL_UNIQUE

      foreach element $data {
         set _SSF_PIN_LABEL_UNIQUE([lindex $element [_GET_CSV_INDEX "Site Type"]]) 0
      }
   }

   proc _GET_SSF_SITE_TYPE_INDEX {value} {
      # TODO - document this proc
      variable _SSF_SETTINGS_SITE_TYPE_REGEXP_LIST
      set index -1
      for {set x 0} {$x < [llength $_SSF_SETTINGS_SITE_TYPE_REGEXP_LIST]} {incr x} {
         # apply the regular expression on the value passed in
         if {[regexp [lindex $_SSF_SETTINGS_SITE_TYPE_REGEXP_LIST $x] $value]} {
	    # exit the loop if a hit is determined
	    set index $x
	    break
	 }
      }
      if {$index == -1} {
         # if no match was found, set the index to be the catch-all value: last index +1
         set index [llength $_SSF_SETTINGS_SITE_TYPE_REGEXP_LIST]
      }
      return $index
   }

   proc isFileGood {fileIn {extension}} {
      # TODO - Document this proc
      # isfileGood
      if {![file exists $file]} {
         puts "ERROR: File $file not found!"
      } elseif {[info exists extension]} {
         if {[file extension $fileIn] != $extension} {
	    puts "ERROR: File $fileIn type is not the expected type"
	    # TODO - do we want to fail if the extension doesn't match?
	    return 0
	 }
      }
      return [file readable $fileIn]
   }

   proc isLineWellFormedCSV {headerList expectedNumberOfHeaders} {
      # TODO - Document this proc
      if {[llength $headerList]i != $expectedNumberOfHeaders} {
	 return 1
      } else return 0
   }

   proc isLineComment {line} {
      # TODO - Document this proc
      # TODO - speedup - combine these into a single regexp call
      if {[regexp {^\s*$} $line]} {
         # line is all whitespace or empty, so assume comment
	 return 1
      } elseif {[regexp {^,+$} $line]} {
         # line contains only commas, so assume comment
	 return 1
      } elseif {![regexp {,} $line]} {
         # line does not contain any commas, so assume comment
	 return 1
      } elseif {[regexp {^Top:} $line]} {
         # line contains known csv header comment "Top:"
	 return 1
      } elseif {[regexp {^Netlist:} $line]} {
         # line contains known csv header comment "Netlist:"
	 return 1
      } elseif {[regexp {^Generated by:} $line]} {
         # line contains known csv header comment "Generated by:"
	 return 1
      } elseif {[regexp {^Build:} $line]} {
         # line contains known csv header comment "Build:"
	 return 1
      } else {
         return 0
      }
   }

   proc parseCSV {FILEIN} {
      # TODO - document this proc
      # TODO - remove the FILEOUT reference if we don't use it
      # parse the csv file
      set lineNumber 0
      set csvHeaderParsed 0
      set headerList [list ]
      set data [list]
      while {[gets $FILEIN line] >= 0} {
         incr lineNumber
	 if {[isLineComment $line]} {
	    # TODO - do we want to put this info as comments in the output file?
	    # TODO - change this to just put a single pound sign
#	    puts $FILEOUT "# $line"
	 } elseif {$csvHeaderParsed == 0} {
	    # the first non-comment, comma delimted line must specify the headers
	    set headerList [split $line {,}]
            set numHeaders [llength $headerList]
	    _INIT_CSV_INDEX $headerList
	    set csvHeaderParsed 1
	 } else {
	    # parse the values
	    set valuesList [split $line {,}]
	    if {[llength $valuesList] != [llength $headerList]} {
               puts "WARNING:  csv line $lineNumber is not well formed - expected number of values not found : $line"
	    }
	    lappend data $valuesList
	 }
      }
      return $data
   }

   proc computeNumSymbols {numPins} {
      # TODO - document this proc

      variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL
      variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL_SIDE

      if {$_SSF_SETTINGS_MAX_PINS_PER_SYMBOL < 1} {
         puts "ERROR: You cannot have zero or negative pins per symbol, assuming 1 symbol"
	 return 1
      } else {
         set numSymbols [expr $numPins / $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL]
	 set remainder [expr $numPins % $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL]
	 if {$remainder > 0} {
	    incr numSymbols
	 }
	 return $numSymbols
      }
   }

   proc writeHeaderSSF {FILEOUT sfrID} {
      # TODO - doucment this proc
      puts $FILEOUT "#%SSF2.0"
      puts $FILEOUT "#%SFR_REQID $sfrID"
      puts $FILEOUT "#"
      puts $FILEOUT "# DO NOT REMOVE THE FIRST TWO LINES!"
      puts $FILEOUT "# File cannot be submitted or processed without them!"
      puts $FILEOUT "#"
      puts $FILEOUT "# Symbol Source File (SSF) for eCad schematic symbols"
      puts $FILEOUT "#"
      puts $FILEOUT "# The contents of this file are Nortel Networks proprietary data."
      puts $FILEOUT "# Unauthorized use or reproduction is prohibited."
      puts $FILEOUT "#"
      puts $FILEOUT "# NOTE:  Maximum 100 pins per side of each box."
      puts $FILEOUT "#"
      puts $FILEOUT "# NOTE:  Allowed pinuse values are: IN OUT BI TRI POWER GROUND NC"
      puts $FILEOUT "#"
   }

   proc writeFooterSSF {FILEOUT part jedec prefix cpc class crev} {
      # TODO - doucment this proc
      puts $FILEOUT "####################### attributes   #######################"
      puts $FILEOUT "#%ATTR"
      puts $FILEOUT "JEDEC_TYPE           $jedec"
      puts $FILEOUT "PART_NAME            $part"
      puts $FILEOUT "PHYS_DES_PREFIX      $prefix"
      puts $FILEOUT "CPCODE               $cpc"
      puts $FILEOUT "CLASS                $class"
      puts $FILEOUT "CREV                 $crev"
   }

   proc getPinNumberSSF {pin} {
      # TODO - doucment this proc
      return [lindex $pin [_GET_CSV_INDEX "Pin Number"]]
   }

   proc getPinLabelSSF {pin} {
      # TODO - doucment this proc
      # TODO - uniquify pin labels
      variable _SSF_PIN_LABEL_UNIQUE
      set pinSiteType [lindex $pin [_GET_CSV_INDEX "Site Type"]]
      if {[array names _SSF_PIN_LABEL_UNIQUE $pinSiteType] == ""} {
         set _SSF_PIN_LABEL_UNIQUE($pinSiteType) 0
      } else {
         incr _SSF_PIN_LABEL_UNIQUE($pinSiteType)
      }
      # TODO - implement a list of siteTypes to uniquify - don't want to do all
      if {$_SSF_PIN_LABEL_UNIQUE($pinSiteType) > 1} {
	 append pinSiteType $_SSF_PIN_LABEL_UNIQUE($pinSiteType)
      } elseif {[regexp {GND|VCC|VBAT|NC} $pinSiteType]} {
         # TODO - these are known site types that need uniquifying - are there others?
	 # for certain site types, we know there will be multiple pins,
	 # so generate a unqiute pin label from the first
	 append pinSiteType $_SSF_PIN_LABEL_UNIQUE($pinSiteType)
      }
      return $pinSiteType
   }

   proc getPinUseSSF {pin} {
      # TODO - doucment this proc
      # NOTE:  Allowed pinuse values are: IN OUT BI TRI POWER GROUND NC
      set pinSiteType [lindex $pin [_GET_CSV_INDEX "Site Type"]]
      set pinDirection [lindex $pin [_GET_CSV_INDEX "Direction"]]
      if {[regexp {VCC|VBAT} $pinSiteType]} {
         return "POWER"
      } elseif {[regexp {GND} $pinSiteType]} {
         return "GROUND"
      } elseif {[regexp {^NC$} $pinSiteType]} {
         return "NC"
      } elseif {$pinDirection != ""} {
         if {$pinDirection == "INOUT"} {
	    return "BI"
	 } else {
            return $pinDirection
	 }
      } else {
         # when in doubt, assume BI
         return "BI"
      }
   }

   proc writeSymbolSSF {FILEOUT pinList symbolNum} {
      # TODO - doucment this proc

      variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL
      variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL_SIDE

      set sideBoundaryIndex [llength $pinList]
      if {[llength $pinList] >= $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL_SIDE} {
         # TODO - divide it in half for now...
         set sideBoundaryIndex [expr [llength $pinList]/2]
      }

      # TOOD - need a better mapping for pin_label and pinuse
      puts $FILEOUT "###################### symbol $symbolNum #######################"
      if {$symbolNum > 1} {
         # skip this for the first symbol
         puts $FILEOUT "#%SYMBOL"
      }
      puts $FILEOUT "#"

      puts $FILEOUT "# left side"
      puts $FILEOUT "# pin_label                                 pin_number  pinuse"
      for {set x 0} {$x < $sideBoundaryIndex} {incr x} {
         set pin [lindex $pinList $x]
         puts $FILEOUT "[getPinLabelSSF $pin] [getPinNumberSSF $pin] [getPinUseSSF $pin]"
      }
      puts $FILEOUT "#"

      puts $FILEOUT "# right side"
      puts $FILEOUT "#%SIDE"
      puts $FILEOUT "# pin_label                                 pin_number  pinuse"
      for {set x $sideBoundaryIndex} {$x < [llength $pinList]} {incr x} {
         set pin [lindex $pinList $x]
         puts $FILEOUT "[getPinLabelSSF $pin] [getPinNumberSSF $pin] [getPinUseSSF $pin]"
      }
      puts $FILEOUT "#"

      puts $FILEOUT "# top side"
      puts $FILEOUT "#%SIDE"
      puts $FILEOUT "# pin_label                                 pin_number  pinuse"
      puts $FILEOUT "#"

      puts $FILEOUT "# bottom side"
      puts $FILEOUT "#%SIDE"
      puts $FILEOUT "# pin_label                                 pin_number  pinuse"
      puts $FILEOUT "#"
   }

   proc arrayListGetValues {inList} {
# TODO - remove this proc if not used..
      # takes a list of array index-value pairs returned from "array get foo"
      # and returns a list of just the elements - this is what array values foo
      # should return if it existed
      set returnList [list]
      set odd 0
      foreach element $inList {
         if {!$odd} {
	    set odd 1
	 } else {
	    # even index elements are the values
	    # strip all the braces and quotes
	    regsub -all {\{} $element "" element
	    regsub -all {\}} $element "" element
	    regsub -all "\"" $element "" element
            lappend returnList $element
            set odd 0
	 }
      }
      return $returnList
   }

   proc lsortUnique {inList} {
      # tcl 8.0 does not contain the -unique option to lsort
      foreach item $inList {
         set outList("$item") 1
      }
      return [array names outList]
   }

   proc myLsortByBank {left right} {
      # TODO - document this proc
      # sort first by bank #, then dictionary string compare
      set leftSite [lindex $left [_GET_CSV_INDEX "Site Type"]]
      set rightSite [lindex $right [_GET_CSV_INDEX "Site Type"]]
      set leftBank [lindex $left [_GET_CSV_INDEX "IO Bank"]]
      set rightBank [lindex $right [_GET_CSV_INDEX "IO Bank"]]
#      regexp {_(\d+)$} $leftSite matchVar leftSite
#      regexp {_(\d+)$} $rightSite matchVar rightSite
      if {[info exists leftBank] && \
          [info exists rightBank] && \
          $leftBank != "" && \
          $rightBank != ""} {
         # both left and right match the syntax for bank
         if {$leftBank < $rightBank} {
            return [expr -1]
         } elseif {$leftBank > $rightBank} {
            return [expr 1]
         }
	 # strip the bank number before performing string compare
	 regsub {_(\d+)$} $leftSite {} leftSite
	 regsub {_(\d+)$} $rightSite {} rightSite
         return [string compare $leftSite $rightSite]
      } 
      if {[info exists leftBank] && \
          $leftBank != "" } {
	 # if we get to this point, the left entry has a bank
	 # defined and the right does not, so the left wins
	 return [expr -1]
      }
      if {[info exists rightBank] && \
          $rightBank != "" } {
	 # if we get to this point, the right entry has a bank
	 # defined and the left does not, so the left wins
	 return [expr 1]
      }
      # finally, we compare two items with no bank assignment
      return [string compare $leftSite $rightSite]
   }

   proc myLsortCmd {left right} {
      # TODO - document this proc
      # this is a custom sort routine, to push empty list elements to the end of the list
      if {$left == ""} {
         if {$right != ""} {
            return -1
	 } else {
	    return 0
	 }
      } elseif {$right == ""} {
         if {$left != ""} {
            return 1
	 } else {
	    return 0
	 }
      } elseif {$left < $right} {
         return -1
      } elseif {$left > $right} {
         return 1
      } else {
         return 0
      }
   }

   proc myLsortCmdOld {left right} {
      # TODO - document this proc
      # this is a custom sort routine, to push empty list elements to the end of the list
      if {$left < $right} {
         return -1
      } elseif {$left > $right} {
         return 1
      } else {
         return 0
      }
   }

   proc myLsortCmdNew {left right} {
      # TODO - document this proc
      # this is a custom sort routine, to push empty list elements to the end of the list
      if {$left < $right || ($left != "" && $right == "")} {
         return -1
      } elseif {$left > $right || ($left == "" && $right != "")} {
         return 1
      } else {
         return 0
      }
   }

   proc consolidateBuckets {bucketList} {
      # TODO - document this proc
      variable _SSF_SETTINGS_MAX_PINS_PER_SYMBOL
      set myBucketList [list]
      for {set x 0} {$x < [llength $bucketList]} {incr x} {
         set currentBucket [lindex $bucketList $x] 
         set currentBucketLength [llength $currentBucket]
	 if {$currentBucketLength == 0} {
	    # skip empty buckets
	    continue
	 } elseif {$currentBucketLength > $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL} {
	    # calculate how many times larger than the max the current bucket is
	    set numBreaks [expr $currentBucketLength / $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL]
	    if {[expr $currentBucketLength % $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL] > 0} {
	       incr numBreaks
	    }
	    # break up the big bucket into $numBreaks pieces:
	    set currentIndex 0
	    for {set y 0} {$y < $numBreaks} {incr y} {
	       set nextIndex [expr $currentIndex + $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL - 1]
	       lappend myBucketList [lrange $currentBucket $currentIndex $nextIndex]
	       set currentIndex [expr $currentIndex + $_SSF_SETTINGS_MAX_PINS_PER_SYMBOL]
	    }
	 } else {
	    lappend myBucketList $currentBucket
	 }
      }
      return $myBucketList
   }

   proc generateBucketsByBank {data {numBuckets 1}} {
      # TODO - document this proc
      # TODO - need to match numBuckets w/ numBanks
      set numPins [llength $data]
      set bucket 0
      set bucketSize [expr $numPins/$numBuckets]
      set currentBucket [list]
      set bucketList [list]
      set bankList [list]
      set banklessList [list]
      foreach element $data {
         set bank [lindex $element [_GET_CSV_INDEX "IO Bank"]]
	 if {$bank == ""} {
	    lappend banklessList $element
	 } else {
	    lappend bankList $element
	    set bankNames($bank) 1
	 }
      }
      # iterate through the list of pins assigned to banks, sorted numerically by bank
      foreach element [lsort -index [_GET_CSV_INDEX "IO Bank"] -integer $bankList] {
	 lappend currentBucket $element
         if {$bucket < $bucketSize} {
	    incr bucket
	 } else {
	    lappend bucketList $currentBucket
            set currentBucket [list]
            set bucket 0
	 }
      }
      if {[llength $currentBucket] > 0} {
         lappend bucketList $currentBucket
         set currentBucket [list]
         set bucket 0
      }
      # iterate through the list of pins not assigned to banks, sorted by pin name
      foreach element [lsort -index [_GET_CSV_INDEX "Pin Number"] -dictionary $banklessList] {
	 lappend currentBucket $element
         if {$bucket < $bucketSize} {
	    incr bucket
	 } else {
	    lappend bucketList $currentBucket
            set currentBucket [list]
            set bucket 0
	 }
      }
      if {[llength $currentBucket] > 0} {
         lappend bucketList $currentBucket
      }
      return $bucketList
   }

   proc generateBucketsBySiteType {data {numBuckets 1}} {
      # TODO - document this proc
      variable _SSF_SETTINGS_SITE_TYPE_REGEXP_LIST
      set numPins [llength $data]
      set bucket 0
      set bucketSize [expr $numPins/$numBuckets]
      set currentBucket [list]
      set bucketList [list]
      set bucketListSorted [list]

      puts "INFO:  SSF symbols will be sorted in order with buckets determined by the following orderd list of regular expressions:"
      puts "INFO:     $_SSF_SETTINGS_SITE_TYPE_REGEXP_LIST"
      # initialize the bucket list w/ the ordered priority defined in ssf settings
      for {set x 0} {$x <= [llength $_SSF_SETTINGS_SITE_TYPE_REGEXP_LIST]} {incr x} {
         # number of buckets is 1 + the size of the setttings' regexp groupings
	 lappend bucketList [list]
      }
      # iterate through the list of pins assigned to banks, sorted alphabetically by site type
      foreach element [lsort -index [_GET_CSV_INDEX "Site Type"] -dictionary $data] {
         # set the current bucket to be the one that matches this element's site type 
	 set bucketIndex [_GET_SSF_SITE_TYPE_INDEX [lindex $element [_GET_CSV_INDEX "Site Type"]]]
         set currentBucket [lindex $bucketList $bucketIndex]
	 set bucket [llength $currentBucket]
	 lappend currentBucket $element
	 set bucketList [lreplace $bucketList $bucketIndex $bucketIndex $currentBucket]
	 # TODO - reconcile max size of a bucket
      }
      # now do the secondary sort
      for {set x 0} {$x <= [llength $bucketList]} {incr x} {
         # number of buckets is 1 + the size of the setttings' regexp groupings
	 lappend bucketListSorted [lsort -command myLsortByBank [lindex $bucketList $x]]
      }
      return $bucketListSorted
   }

   proc generateBucketsQuickAndDirty {data {numBuckets 1}} {
      # TODO - document this proc
      set numPins [llength data]
      set bucket 0
      set bucketSize [expr $numPins/$numBuckets]
      set currentBucket [list]
      set bucketList [list]
      foreach element $data {
	 lappend currentBucket $element
         if {$bucket < $bucketSize} {
	    incr bucket
	 } else {
	    lappend bucketList $currentBucket
            set currentBucket [list]
            set bucket 0
	 }
      }
      if {[llength $currentBucket] > 0} {
         lappend bucketList $currentBucket
      }
      return $bucketList
   }

   proc generateBuckets {data {numBuckets 1} {strategy siteType}} {
      # TODO - document this proc
      switch $strategy {
         siteType {
	    return [generateBucketsBySiteType $data $numBuckets]
	 }
         bank {
	    return [generateBucketsByBank $data $numBuckets]
	 }
         quickAndDirty {
	    return [generateBucketsQuickAndDirty $data $numBuckets]
	 }
         default {
	    return [generateBucketsBySiteType $data $numBuckets]
	 }
      }
   }

   proc writeSSF {data FILEOUT part jedec prefix cpc class crev sfrReqID {numSymbols 1} } {
      # TODO - document this proc
      # reset the unique pin label data structures
      variable _SSF_PIN_LABEL_UNIQUE
      set buckets [list ]
      set numPins [llength $data]
      _INIT_SSF_PIN_LABEL_UNIQUE $data
      puts "INFO: Total number of pins in part is: $numPins"
      set neededNumSymbols [computeNumSymbols $numPins]
      puts "INFO: Minimum number of symbols needed:  $neededNumSymbols"
      if {$numSymbols < $neededNumSymbols} {
         puts "ERROR: the requested number of symbols ($numSymbols) is less than needed -using computed number of symbols $neededNumSymbols"
	 set numSymbols $neededNumSymbols
      }
      writeHeaderSSF $FILEOUT $sfrReqID
      set buckets [consolidateBuckets [generateBuckets $data $numSymbols siteType]]
      set numBuckets [llength $buckets]
      for {set symbol 1} {$symbol<=$numBuckets} {incr symbol} {
	 set currentSymbolPinList [lindex $buckets [expr $symbol -1]]
	 puts "INFO: Writing symbol # $symbol with [llength $currentSymbolPinList] pins"
         writeSymbolSSF $FILEOUT $currentSymbolPinList $symbol
      }
      writeFooterSSF $FILEOUT $part $jedec $prefix $cpc $class $crev
   }

   proc csv2ssf { {csvIn in.csv} {ssfOut out.ssf} part jedec prefix cpc class crev sfrReqID {numSymbols 1} } {
      # TODO - Document this proc
      # csv2ssf
      set FILEIN ""
      set FILEOUT ""
      if {$csvIn == "in.csv"} {
         puts "WARNING:  no csv input file specified, assuming in.csv"
      }
      if {$ssfOut == "out.ssf"} {
	puts "WARNING:  no ssf output file specified, assuming out.ssf"
      }
      puts "INFO: Opening $csvIn for read operation"
      if {[catch "set FILEIN [open $csvIn r]"]} {
         puts "ERROR:  error opening $csvIn"
      }
      puts "INFO: Opening $ssfOut for write operation"
      if {[catch "set FILEOUT [open $ssfOut w]"]} {
         puts "ERROR:  error opening $ssfOut"
      }
      set data [parseCSV $FILEIN]
      writeSSF $data $FILEOUT $part $jedec $prefix $cpc $class $crev $sfrReqID $numSymbols
      puts "INFO: Closing file $csvIn"
      close $FILEIN
      puts "INFO: Closing file $ssfOut"
      close $FILEOUT
      puts "INFO: done."
   }

   proc writeVHDL {data FILEOUT topModule {instTemplate 0}} {
      # TODO - document this proc
      variable _CSV_BUS_REGEXP
      if {!$instTemplate} {
         # create declaration template
         puts $FILEOUT "LIBRARY IEEE;"
         puts $FILEOUT "USE IEEE.STD_LOGIC_1164.ALL;"
         puts $FILEOUT "ENTITY $topModule IS"
         puts $FILEOUT "   PORT ("
      } else {
         # create instantiation template
         puts $FILEOUT "${topModule}_inst : $topModule"
         puts $FILEOUT "   PORT MAP ("
      }
      set current 0
      set last [expr [llength $data] -1]
      # TODO - figure out what mode should be - hard-coded?
      set mode "STD_LOGIC"
      foreach element [lsort -dictionary -index [_GET_CSV_INDEX "Signal Name"] $data] {
         set port [lindex $element [_GET_CSV_INDEX "Signal Name"]]
	 set type [lindex $element [_GET_CSV_INDEX "Direction"]]
	 if {$port != ""} {
	    # skip all pins which are not assigned to signals
	    if {[regexp $_CSV_BUS_REGEXP $port result name bit]} {
               if {[info exists vectorPorts($name)]} {
                  set vectorPorts($name) "$vectorPorts($name) $bit"
	       } else {
                  set vectorPorts($name) $bit
	       }
               if {[info exists vectorType($name)]} {
	          # all the bits of the vector should be of the same type, if not issue an error
	          if {$vectorType($name) != $type} {
		     puts "ERROR: Vector Signal $name direction $type conflicts with a previous definition $vectorType($name)"
		  }
	       } else {
                  set vectorType($name) $type
               }
	    } else {
	       # output all the scalar ports
	       if {$current == $last && ![array exists vectorPorts]} {
                  if {!$instTemplate} {
                     # create declaration template
	             # the last port definition does not have a semicolon
                     puts $FILEOUT "      $port : $type $mode"
		  } else {
                     # create instantiation template
	             # the last port definition does not have a comma
                     puts $FILEOUT "      $port => $port"
		  }
	       } else {
                  if {!$instTemplate} {
                     # create declaration template
                     puts $FILEOUT "      $port : $type $mode;"
		  } else {
                     # create instantiation template
                     puts $FILEOUT "      $port => $port,"
		  }
	       }
	    }
	 }
	 incr current
      }
      # now do the vector ports:
      set mode "STD_LOGIC_VECTOR"
      if {[array exists vectorPorts]} {
         set current 0
         set last [expr [array size vectorPorts] -1]
         foreach vector [lsort -dictionary [array names vectorPorts]] {
            set minBit ""
	    set maxBit ""
	    foreach bit [lsort -integer $vectorPorts($vector)] {
	       if {$minBit == ""} {
		  set minBit $bit
	       } elseif {$bit < $minBit} {
	          set minBit $bit
	       }
	       if {$maxBit == ""} {
		  set maxBit $bit
	       } elseif {$bit > $maxBit} {
		  set maxBit $bit
	       }
	    }
	    if {$maxBit != [expr [llength $vectorPorts($vector)] - 1]} {
	       # we are in trouble, the largets index for the vector does not match
	       # the size of the port signals assigned in the csv
	       puts "ERROR:  The max port index $maxBit of vector $vector does not match the number of port indices read from the csv:  $vectorPorts($vector)"
	    }
            if {!$instTemplate} {
               # create declaration template
	       if {$current == $last} {
	          # the last port definition does not have a semicolon
                  puts $FILEOUT "      $vector : $vectorType($vector) $mode\($maxBit DOWNTO $minBit\)"
	       } else {
                  puts $FILEOUT "      $vector : $vectorType($vector) $mode\($maxBit DOWNTO $minBit\);"
	       }
	    } else {
               # create instantiation template
	       if {$current == $last} {
	          # the last port definition does not have a comma
                  puts $FILEOUT "      $vector => $vector"
	       } else {
                  puts $FILEOUT "      $vector => $vector,"
	       }
	    }
	    incr current
	 }
      }
      puts $FILEOUT "   );"
      if {!$instTemplate} {
         # create declaration template
         puts $FILEOUT "END $topModule;"
      }
   }

   proc writeVerilog {data FILEOUT topModule {instTemplate 0}} {
      # TODO - document this proc
      variable _CSV_BUS_REGEXP
      if {!$instTemplate} {
         # create declaration template
         puts $FILEOUT "module $topModule ("
      } else {
         # create instantiation template
         puts $FILEOUT "$topModule ${topModule}_inst ("
      }
      set current 0
      set last [expr [llength $data] -1]
      foreach element [lsort -dictionary -index [_GET_CSV_INDEX "Signal Name"] $data] {
         set port [lindex $element [_GET_CSV_INDEX "Signal Name"]]
	 set type [string tolower [lindex $element [_GET_CSV_INDEX "Direction"]]]
	 regsub {^in$} $type {input} type
	 regsub {^out$} $type {output} type
	 if {$port != ""} {
	    # skip all pins which are not assigned to signals
	    if {[regexp $_CSV_BUS_REGEXP $port result name bit]} {
               if {[info exists vectorPorts($name)]} {
                  set vectorPorts($name) "$vectorPorts($name) $bit"
	       } else {
                  set vectorPorts($name) $bit
	       }
               if {[info exists vectorType($name)]} {
	          # all the bits of the vector should be of the same type, if not issue an error
	          if {$vectorType($name) != $type} {
		     puts "ERROR: Vector Signal $name direction $type conflicts with a previous definition $vectorType($name)"
		  }
	       } else {
                  set vectorType($name) $type
               }
	    } else {
	       # output all the scalar ports
	       if {$current == $last && ![array exists vectorPorts]} {
                  if {!$instTemplate} {
                     # create declaration template
	             # the last port definition does not have a comma
                     puts $FILEOUT "      $type $port"
		  } else {
                     # create instantiation template
	             # the last port definition does not have a comma
                     puts $FILEOUT "      .${port}($port)"
		  }
	       } else {
                  if {!$instTemplate} {
                     # create declaration template
                     puts $FILEOUT "      $type $port,"
		  } else {
                     # create instantiation template
                     puts $FILEOUT "      .${port}($port),"
		  }
	       }
	    }
	 }
	 incr current
      }
      # now do the vector ports:
      if {[array exists vectorPorts]} {
         set current 0
         set last [expr [array size vectorPorts] -1]
         foreach vector [lsort -dictionary [array names vectorPorts]] {
            set minBit ""
	    set maxBit ""
	    foreach bit [lsort -integer $vectorPorts($vector)] {
	       if {$minBit == ""} {
		  set minBit $bit
	       } elseif {$bit < $minBit} {
	          set minBit $bit
	       }
	       if {$maxBit == ""} {
		  set maxBit $bit
	       } elseif {$bit > $maxBit} {
		  set maxBit $bit
	       }
	    }
	    if {$maxBit != [expr [llength $vectorPorts($vector)] - 1]} {
	       # we are in trouble, the largets index for the vector does not match
	       # the size of the port signals assigned in the csv
	       puts "ERROR:  The max port index $maxBit of vector $vector does not match the number of port indices read from the csv:  $vectorPorts($vector)"
	    }
            if {!$instTemplate} {
               # create declaration template
	       if {$current == $last} {
	          # the last port definition does not have a comma
                  puts $FILEOUT "      $vectorType($vector) \[${maxBit}:${minBit}\] $vector"
	       } else {
                  puts $FILEOUT "      $vectorType($vector) \[${maxBit}:${minBit}\] $vector,"
	       }
	    } else {
               # create instantiation template
	       if {$current == $last} {
	          # the last port definition does not have a comma
                  puts $FILEOUT "      .${vector}\($vector\)"
	       } else {
                  puts $FILEOUT "      .${vector}\($vector\),"
	       }
	    }
	    incr current
	 }
      }
      puts $FILEOUT "   );"
      if {!$instTemplate} {
         # create declaration template
         puts $FILEOUT "endmodule"
      }
   }

   proc generateSSF {part jedec prefix cpc class crev sfrReqID {numSymbols 1}} {
      # TODO - finish implmenting this proc
      if {[file exists $part.ppr]} {
	 if {[ catch {hdi::project open -file $part.ppr} returnVar]} {
            puts "WARNING: $returnVar"
            puts "WARNING: Continuing..."
	 }
      } else {
         hdi::project new -name $part -dir .
      }
      if {[catch {hdi::floorplan new -name $part -part $part -project $part} returnVar]} {
         puts "WARNING:  $returnVar"
         puts "WARNING: Continuing..."
      }
      hdi::floorplan save -name $part -project $part
      hdi::port export -format csv -project $part -floorplan $part -file $part.csv
      paUtil::csv2ssf $part.csv $part.ssf $part $jedec $prefix $cpc $class $crev $sfrReqID $numSymbols
      hdi::project close -name $part
   }

   proc getFileSystem {} {
      # tries to determine what the host platform is
      if {[info exists tcl_platform(host_platform)]} {
         # this is a jacl (planAhead-only) tcl var
         return $tcl_platform(host_platform)
      } elseif {[info exists tcl_platform(platform)]} {
         # this is a general tcl platform variable
         return $tcl_platform(platform)
      } else {
         # else try to determine from the PATH environment varaible
         set path $::env(PATH)
         if {[regexp {^[A-Za-z]:} $path]} {
            return windows
         } else {
            return unix
         }
      }
   }

   proc regexpFile {expression fileIn} {
      # returns all lines that match occurrence of regular expression matched in the file
      set lineMatches [list]
      set FILEIN ""
      puts "INFO: Opening $fileIn for read operation"
      if {[catch "set FILEIN [open $fileIn r]"]} {
         puts "ERROR:  error opening $fileIn"
      }
      while {[gets $FILEIN line] >= 0} {
         if {[regexp $expression $line]} {
            lappend lineMatches $line
         }
      }
      close $FILEIN
      return $lineMatches
   }

   proc getMem {pid} {
      # TODO - implement getMem - then document it
      # queries the kernel for current heap memory 
      set mem ""
      if {$pid != ""} {
         if {[getFileSystem] == "windows"} {
	    # handle windows kernel call
	    # TODO - implement the windows tasklist command call...
	    # TODO - review to make sure mem is 16th token, and is always in Kbytes???
	    # TODO - exec is currently broken on windows in jacl - 3910
	    set mem [lindex [exec tasklist /FI "PID eq $pid"] 16]
	 } else {
	    # handle linux/unix kernel call through the ps command
	    # RSS - Resident Set Size - is the best memory metric we have, it's the 18th field returned from ps
	    set mem [lindex [exec ps v -p $pid] 17]
	 }
      }
      return $mem
   }

   proc memStat {} {
      # TODO - implement memStat - then document it
      # queries the kernel for current heap memory and cpu usage stats
      set pid ""
      if {[catch "set pid [pid]"]} {
         # jacl has not implemented the pid tcl pid command (jacl is currenlty only Tcl 8.0 compliant
         if {[file exists planAhead.log]} {
            # attempt to get the pid from the planAhead log file - last "#Process ID:" string in log
	    set pid [lindex [split [lindex [regexpFile {^# Process ID: \d+$} planAhead.log] end]] end]
         }
      }
      if {$pid != ""} {
         return [getMem $pid]
      } else {
         puts "ERROR:  Unable to determine process id"
         return ""
      }
   }

   proc launchParallelRuns {project floorplan dir runList} {
      # TODO - document this proc
      # $dir option is the directory for the project (where the ppr file is located)
      global ::paUtil::_LAUNCH_PAR_HOST_LIST
      global ::paUtil::_LAUNCH_PAR_EMAIL_LIST
      global ::paUtil::_LAUNCH_PAR_EMAIL_EVERY_JOB
      set runParCmd ""
      if {[llength $runList] > 0} {
         if {[file exists $dir]} {
	    set scriptList [list]
	    set workDir $dir/${project}.runs
	    hdi::run schedule -names $runList -project $project -floorplan $floorplan 
	    # launch scripts only
	    hdi::run launch -project $project -jobs 1 -scriptsOnly yes -allPlacement no -dir $workDir
	    # TODO - need some way of delivering this script on multiple platforms...
	    set foundRunPar 0
	    set runParTcl ""
       set platformSeparator ":"
       if {[info exist tcl_platform(platform)] && ($tcl_platform(platform) == "windows")} {
          set platformSeparator ";"
       }
	    foreach rdiRoot [split "$::env(RDI_APPROOT)" $platformSeparator] {
	       if {[file exists $rdiRoot/scripts/runPar.tcl]} {
	          set runParTcl "$rdiRoot/scripts/runPar.tcl"
	          set foundRunPar 1
	          break
	       }
	    }
	    if {!$foundRunPar} {
	       puts "ERROR:  runPar.tcl not found in scripts/ under any of $::env(RDI_APPROOT)"
	       return
	    }
	    foreach run $runList {
	       if {[file exists $workDir/$floorplan/$run/runme.sh]} {
	          lappend scriptList $workDir/$floorplan/$run/runme.sh
	       } else {
	          puts "ERROR: Unable to find valid run script: $workDir/$floorplan/$run/runme.sh"
	       }
	    }
	    if {[llength $scriptList] <= 0} {
	       puts "ERROR: no valid run scripts found for $runList"
	       return 0
	    }
	    set runParCmd "$runParTcl -rootDir $workDir -jobCmd ssh "
	    if {[info exists ::paUtil::_LAUNCH_PAR_EMAIL_LIST] && $::paUtil::_LAUNCH_PAR_EMAIL_LIST != ""} {
	       append runParCmd "-email \"$::paUtil::_LAUNCH_PAR_EMAIL_LIST\" "
	    }
	    if {[info exists ::paUtil::_LAUNCH_PAR_EMAIL_EVERY_JOB] && $::paUtil::_LAUNCH_PAR_EMAIL_EVERY_JOB != ""} {
	       append runParCmd "-emailEveryJob "
	    }
	    if {[info exists ::paUtil::_LAUNCH_PAR_HOST_LIST] && $::paUtil::_LAUNCH_PAR_HOST_LIST != ""} {
	       append runParCmd "-hosts \"$::paUtil::_LAUNCH_PAR_HOST_LIST\" "
	    }
	    # launch the runs in parallel
	    set fileOut $workDir/launchPar.sh
            if {[catch "set FILEOUT [open $fileOut w]"]} {
               puts "ERROR:  error opening $fileOut"
            }
	    puts $FILEOUT "#!/bin/sh"
	    puts $FILEOUT "#"
	    puts $FILEOUT "# PlanAhead(TM)"
	    puts $FILEOUT "# launchPar.sh: a PlanAhead-generated ExploreAhead Script for UNIX"
	    puts $FILEOUT "# Copyright 1986-1999, 2001-2009 Xilinx, Inc. All Rights Reserved."
	    puts $FILEOUT "#"
	    foreach run $runList {
	       # TODO - test these runs to make sure they completed correctly
	       # TODO - need to touch these files to tell EA all is well that ends well
	       puts $FILEOUT "/bin/touch $workDir/$floorplan/$run/.queue.rst"
	    }
	    puts $FILEOUT "$runParCmd $scriptList > $workDir/runPar.log 2>&1"
	    close $FILEOUT
	    # make the wrapper script executable
	    hdi::command exec -block yes -cmd "chmod +x $fileOut"
	    # execute the wrapper script as a background process
	    hdi::command exec -block no -cmd $fileOut
	 } else {
            puts "ERROR:  Invalid dir $dir"
	 }
      } else {
         puts "ERROR:  no runs were specified"
      }
   }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
