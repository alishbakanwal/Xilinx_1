## This file is only for Ultrascale and Ultrascale +
##TODO::Only single rank memories are supported yet
##TODO::Uneven memory distribution is not supported e.g. 72 MIG Data width and
##16 bit component width
##Calculate the number of mem files required
proc get_number_of_mem_files { Component_width Mig_width } {
  if { $Mig_width < $Component_width} {
    puts "ERROR::Component Width must be greater than equal to the MIG Data Width\n"
    return 0
  }
  set n_mem_files [expr {$Mig_width/$Component_width} ]
  return $n_mem_files
}

#split original mem file data into each row of size 8byte or 16byte based on the
#component width
#Starting address is always 0 for mem files. Need more investigation to enhance
#this
proc split_data { Component_width orig_mem prefix output_dir } {
 
  set fh [open $orig_mem r]

  set mem_data_array ""
  set file_name [file join $output_dir ${prefix}_int_ddr.mem]
  set fileId [open $file_name "w"]

  while { [gets $fh data] >= 0} {
    set find [string range $data 0 1]
    set print_to_files 1
    set stripped_data [string map {" " ""} $data]
    set stripped_data [string trim $stripped_data]
    set length [string length $stripped_data]
    if {$length != 0} {
      if {$find == "//"} {
        #do nothing
        set print_to_files 0
      } elseif {$find == "@0"} {
         set addr [string range $stripped_data 1 $length-1]
         set addr @0$addr
         set addr [string toupper $addr]
         set print_to_files 1
      } else {
        set char_for_each_mem  [ expr {$Component_width / 4} ]
        for {set i 0} {$i < $length} {incr i $char_for_each_mem} {
          set mem_data_array [concat $mem_data_array[string range $stripped_data $i [expr {$i+$char_for_each_mem-1} ]]] 
        }
        set print_to_files 2
      }
      if {$print_to_files == 0} {
      } elseif {$print_to_files == 1} {
        puts $fileId $mem_data_array
        set mem_data_array ""
        puts $fileId $addr
      } else {
        if {[string length $mem_data_array] >= [expr {$Component_width * 2}]} {
          set s_length [string length $mem_data_array] 
          for {set j 0} {$j < $s_length} {incr j [expr {$Component_width*2}]} {
            if {[string length $mem_data_array] < [expr {$Component_width*2}]} {
              break
            }
            puts $fileId [string range $mem_data_array 0 [expr {$Component_width*2 -1}]]
            set mem_data_array [string range $mem_data_array [expr {$Component_width * 2}] [string length $mem_data_array]]
         }
       }

     }
   }
  }
  puts $fileId $mem_data_array
  set mem_data_array ""
  close $fileId
} 

#Byte swaping and Word reversing and encoding according to MIG logic to map DQ
# app_data.
#Data Mapping for MIG: MIG always read in the burst of 8. Mapping of DQ to
#app_data is like first byte of each beat is concatenated together to form first
#LSB of app_data and then second byte concatenated together to form another
#chunk of app_data and so on. 
#Spliting data accross multiple files
#Each component has its own mem files. The division of data among mem files is
#according to row bases.
proc prep_mem {mem_file optiona optionb prefix output_dir Component_width n_mem_files} {
set swap $optiona
set pipe_swap $optionb
set mem $mem_file
array set mem_data_array {}
array set fileId {}
set fp [open $mem r]  
for {set i 0} {$i < $n_mem_files} {incr i} {
    set mem_data_array($i) ""
    set file_name [file join $output_dir ${prefix}_ddr_$i\.mem]
    set fileId($i) [open $file_name "w"]
    if {$swap == "swap"} {
      if {$pipe_swap == "rev"} {
        puts $fileId($i) "//This is a byte and word swapped version of $mem"
      } else {
        puts $fileId($i) "//This is a byte swapped version of $mem"
      }
      puts $fileId($i) "@0"
    }
}
 set file_number [expr {$n_mem_files - 1}]
 while { [gets $fp data] >= 0 } {
  set length [string length $data]
  set find [string range $data 0 1]
 
  if {$length != 0} {
   if {$find == "//" || $find == "@0"} {
    #puts $data
   } else {
    set temp [string map {" " ""} $data]
    set temp_data ""
    for {set i 0} {$i < $length} {incr i 8} {
        set byte0 [string range $temp $i+6 $i+7]
        set byte1 [string range $temp $i+4 $i+5]
        set byte2 [string range $temp $i+2 $i+3]
        set byte3 [string range $temp $i+0 $i+1]
        set word [concat $byte1$byte0$byte3$byte2]
        set temp_data [concat $temp_data $word] 
    }
    #puts "temp_data $temp_data"
    
    if {$pipe_swap == "rev"} {
     set req_word ""
     set m_word ""
     set stripped_temp_data [string map {" " ""} $temp_data]
     for {set i 0} {$i < $length} {incr i [expr {$Component_width * 2}]} {
      for {set j [expr {$Component_width/4 -1}]} {$j >= 0} {set j [expr {$j - 1}]} {
        set word [string range $stripped_temp_data [expr {$i + 8*$j}] [expr {$i + 8*$j + 7}]]
        set req_word [concat $req_word$word]
      }
     }
     if {[string length $req_word] > 16} {
       set word ""
       for {set i 0} {$i < [expr [string length $req_word]/2]} {incr i 2} {
          set first_byte [string range $req_word $i [expr {$i + 1}]]
          set ninth_byte [string range $req_word [expr {$i + 16}] [expr {$i + 16 + 1}]]
          set word [concat $word$first_byte$ninth_byte]
       }
       set req_word $word
     }
     puts $fileId($file_number) $req_word
     set file_number [expr {$file_number -1}]
     if {$file_number < 0} {
        set file_number [expr {$n_mem_files -1}]
     }
     #puts "rev: $req_word"
    } else {
     puts $fileId($file_number) $temp_data
     #puts "swap: $temp_data"
    }
    
        
   }
  }

 }
close $fp
for {set i 0} {$i < $n_mem_files} {incr i} {
  close $fileId($i)
}

}

#Function to be called by user
#Arguments: 1. Component_width :- width of components of DDR Memory (either 8 0r 16)
#2. Mig_width : Width of DQ Port (Total Data Width of DDR Memory)
#3. orig_mem : Name of the mem file generated by Vivado
#4. prefix: string to be use as prefix for the ddr mem file (Value should match with the parameter MemoryFilePrefix of Micron DDR3/4 IP)
#5. output_directory: Directory to release the generated mem files
proc gen_ddr_mem_files {Component_width Mig_width orig_mem prefix output_directory} {
   split_data $Component_width $orig_mem $prefix $output_directory        
   set n_mem_file [get_number_of_mem_files $Component_width $Mig_width]

   prep_mem [file join $output_directory ${prefix}_int_ddr.mem] swap rev $prefix $output_directory $Component_width $n_mem_file
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
