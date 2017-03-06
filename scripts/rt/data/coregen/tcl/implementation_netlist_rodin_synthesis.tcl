puts "COREGEN RODIN SYNTHESIS PROTOTYPE SCRIPT, NOT FOR USE IN A PRODUCTION ENVIRONMENT" ;# -alexs 20100916
#
# any script that uses this must set the env var 

set xstScrFile $::env(XIL_CG_RODIN_SCR_FILE)

set instanceName [file rootname [file tail $xstScrFile]]
puts $instanceName

# Read XST inputs for file information (use this rather than TGI), as older cores
# will not have a full IP-XACT representation.
# XST script file : parameters like part and optimisation

set xstScrFileContents [open $xstScrFile r]

array set xstOptions {}

while {![eof $xstScrFileContents] && [gets $xstScrFileContents] ne "run"} {} ;# we are interested in the parameters passed to the XST run command
while {![eof $xstScrFileContents]} {
   set line [gets $xstScrFileContents]
   if {[llength $line]>0} {
      set xstOptions([lindex $line 0]) [lrange $line 1 end]
   }
}

close $xstScrFileContents

puts "XST OPTIONS"
parray xstOptions

# This is not a generic scr file reader, coregen outputs are a predictable subset of scr file syntax
set outputFile $xstOptions(-ofn)
set xstProjectFile $xstOptions(-ifn)
set transientDirectory [file dirname $xstProjectFile]
set part $xstOptions(-p)

# XST project file : paths to HDL files, and the libraries under which they are contained

set xstProjectFileContents [open $xstProjectFile r]

while {![eof $xstProjectFileContents]} {
   set line [gets $xstProjectFileContents]
   puts $line
   if {[llength $line]==2} {
      set libname [lindex $line 0]
      set file [file join $transientDirectory [lindex $line 1]]
      lappend generatedFiles($libname) $file
   }
}

close $xstProjectFileContents

#
# Stop doing XST project reading
###############################################################################

###############################################################################
# Start doing planAhead-specific stuff
#

create_project -force -part $xstOptions(-p) proj1 .
   
   # TODO: This currently creates a shallow netlist which does not include files from other
   # filesets.  I don't know how to specify in planAhead which library a file belongs to.
foreach libname [array names generatedFiles] {
   if {$libname eq "work"} {
      foreach f $generatedFiles($libname) {
        read_vhdl $f
      }
   } else {
      foreach f $generatedFiles($libname) {
        read_vhdl -library $libname $f
      }
   }
}

set_property top $instanceName [ get_filesets sources_1]
set_param synth.elaboration.rodinMoreOptions {set ioInsertion false}
synth_design -part $xstOptions(-p) 
write_edif $instanceName.edf
exec edif2ngd -noa $instanceName.edf $instanceName.ngc

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
