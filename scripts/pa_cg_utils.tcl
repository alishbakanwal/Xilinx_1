# COPYRIGHT NOTICE
# Copyright 1986-1999, 2001-2009 Xilinx, Inc. All Rights Reserved.
#
# FILE: pa_cg_utils.tcl
#
# This script contains utilities used in the Coregen interface
#

################################################
# Initialise CORE Generator 2.0 CiT components #
################################################

;# declare globals
global iStringContainer
global iRepositoryManager
global iProjectManager
global iTGI
global iTGIHelper
global iGenerationManager
global iIPEngine

namespace eval ::Classid_Tcltask {
   set CStringVectorLibName      "libTcltask_Helpers"
   set CStringVector             "{28710473-d8d4-48c6-b908-d5855e4b6a00}"
}

namespace eval ::Classid_SimC {
  set CRepositoryManagerLibName "libSimC_CRepositoryManager"
  set CRepositoryManager        "{bb780dde-678b-49b5-8dfb-3881188ae60b}"

  set CProjectManagerLibName    "libSimC_CProjectManager"
  set CProjectManager           "{f3be11d8-e22f-4f59-8ce9-f358bfb6c9c5}"

  set CGenerationManagerLibName "libSimC_CGenerationManager"
  set CGenerationManager        "{bce5a2ea-ce82-4158-8b25-7facac70e585}"

  set CIPEngineLibName          "libSimC_CIPEngine"
  set CIPEngine                 "{b0240c75-c285-4752-98b1-1038e49822ce}"
}

# load stubs
#puts -nonewline "Loading CiT stubs..."
if { [ catch { load libCitI_CoreStub[info sharedlibextension] } ] } {
   puts "Error loading CiT library - Coregen support disabled"
   exit 2;
}
if { [ catch { load libUtilI_UtilStub[info sharedlibextension] } ] } {
   puts "Error loading CiT library - Coregen support disabled"
   exit 2;
}
if { [ catch { load libSimI_IRepositoryManagerStub[info sharedlibextension] } ] } {
   puts "Error loading CiT library - Coregen support disabled"
   exit 2;
}
if { [ catch { load libSimI_IProjectManagerStub[info sharedlibextension] } ] } {
   puts "Error loading CiT library - Coregen support disabled"
   exit 2;
}
if { [ catch { load libSimI_IGenerationManagerStub[info sharedlibextension] } ] } {
   puts "Error loading CiT library - Coregen support disabled"
   exit 2;
}
if { [ catch { load libSimI_IIPEngineStub[info sharedlibextension] } ] } {
   puts "Error loading CiT library - Coregen support disabled"
   exit 2;
}
#puts "Done"

# load components
#puts -nonewline "Loading CiT components..."
Xilinx::CitP::FactoryLoad $Classid_Tcltask::CStringVectorLibName
Xilinx::CitP::FactoryLoad $Classid_SimC::CIPEngineLibName
#puts "Done"

# create components
#puts -nonewline "Creating IPEngine CiT component..."
set cStringVector [Xilinx::CitP::CreateComponent $Classid_Tcltask::CStringVector]
if { $cStringVector eq "0" } {
   puts ""
   puts "ERROR: Failed to create StringVector component"
   exit 1
}
set cIPEngine [Xilinx::CitP::CreateComponent $Classid_SimC::CIPEngine]
if { $cIPEngine eq "0" } {
   puts ""
   puts "ERROR: Failed to create IPEngine component"
   exit 1
}
#puts "Done"

# get interfaces onto component
#puts -nonewline "Getting IPEngine CiT component interfaces..."
set iStringContainer   [$cStringVector GetInterface $::xilinx::UtilI::IStringContainerID]
if { $iStringContainer eq "0" } {
   puts ""
   puts "ERROR: Failed to get StringContainer CiT component interface"
   exit 1
}
set iRepositoryManager [$cIPEngine GetInterface $::xilinx::SimI::IRepositoryManagerID]
if { $iRepositoryManager eq "0" } {
   puts ""
   puts "ERROR: Failed to get RepositoryManager CiT component interface"
   exit 1
} elseif { $cgIndexMapPath ne "" } {
   if { ![$iRepositoryManager SetConfigFile $cgIndexMapPath] } {
      puts ""
      puts "ERROR: Failed to set RepositoryManager CiT component index map file"
      exit 1
   }
}
set iProjectManager    [$cIPEngine GetInterface $::xilinx::SimI::IProjectManagerID]
if { $iProjectManager eq "0" } {
   puts ""
   puts "ERROR: Failed to get ProjectManager CiT component interface"
   exit 1
}
set iTGI               [$cIPEngine GetInterface $::xilinx::SimI::ITGIID]
if { $iTGI eq "0" } {
   puts ""
   puts "ERROR: Failed to get TGI CiT component interface"
   exit 1
}
set iTGIHelper         [$cIPEngine GetInterface $::xilinx::SimI::ITGIHelperID]
if { $iTGIHelper eq "0" } {
   puts ""
   puts "ERROR: Failed to get TGIHelper CiT component interface"
   exit 1
}
set iGenerationManager [$cIPEngine GetInterface $::xilinx::SimI::IGenerationManagerID]
if { $iGenerationManager eq "0" } {
   puts ""
   puts "ERROR: Failed to get GenerationManager CiT component interface"
   exit 1
}
set iIPEngine          [$cIPEngine GetInterface $::xilinx::SimI::IIPEngineID]
if { $iIPEngine eq "0" } {
   puts ""
   puts "ERROR: Failed to get IPEngine CiT component interface"
   exit 1
}

#puts "Done"
proc toStringContainer {inList} {
  if { [set cStringVector [::Xilinx::CitP::CreateComponent $::Classid_Tcltask::CStringVector]] eq "0" } {
     puts "ERROR: Failed to create StringVector component"
     exit 1
  }
  if { [set iStringContainer [$cStringVector GetInterface $::xilinx::UtilI::IStringContainerID]] eq "0" } {
     puts "ERROR: Failed to get StringContainer CiT component interface"
     exit 1
  }
  $iStringContainer Clear
  foreach element $inList {
     $iStringContainer Add element
  }
  return $iStringContainer
}

proc getGeneratedImplementationFiles { componentInstanceID } {

   global iTGI
   global iTGIHelper
   global iStringContainer
   global iGenerationManager

   set impFiles {}

   set componentID [$iTGI getComponentInstanceComponentID $componentInstanceID]

   if  { $componentInstanceID ne "" && $componentID ne "" } {

      set allChainIDs [$iTGIHelper getGeneratorChainIDs $componentID]

      ;# filter chains for COREGEN chains
      set     chainGroups     {}
      lappend chainGroups     "COREGEN"
      $iStringContainer Clear
      foreach chainGroup $chainGroups {
         set group $chainGroup
         $iStringContainer Add group
      }      
      set coregenChainIDs [$iGenerationManager FilterChainIDsByGroup $allChainIDs $iStringContainer "AND"]

      ;# filter chains for implementation files
      set     chainGroups {}
      lappend chainGroups "IP_XCO_CHAIN"
      lappend chainGroups "IMPLEMENTATION_FILES_CHAIN"
      lappend chainGroups "INSTANTIATION_TEMPLATES_CHAIN"
      $iStringContainer Clear
      foreach chainGroup $chainGroups {
         set group $chainGroup
         $iStringContainer Add group
      }      
      set impChainIDs [$iGenerationManager FilterChainIDsByGroup $coregenChainIDs $iStringContainer "OR"]

      ;# gather generated implementation files
      set fileSetIDs [$iTGIHelper getGeneratedFileSetIDs $componentInstanceID $impChainIDs]
      for {$fileSetIDs GetIterator fileSetIDItr; $fileSetIDItr First } {![$fileSetIDItr IsEnd]} {$fileSetIDItr Next} {
         set fileSetID [$fileSetIDItr CurrentItem]
         set fileIDs   [$iTGI getFileSetFileIDs $fileSetID]
         for {$fileIDs GetIterator fileIDItr; $fileIDItr First } {![$fileIDItr IsEnd]} {$fileIDItr Next} {
            set fileID   [$fileIDItr CurrentItem]
            set fileName [$iTGI getFileName $fileID false]
            regsub -all {\\} $fileName {/} fileName
            lappend impFiles $fileName
         }
      }
   }

   return $impFiles
}

proc getGeneratedSimulationFiles { componentInstanceID } {

   global iTGI
   global iTGIHelper
   global iStringContainer
   global iGenerationManager

   set simFiles {}

   set componentID [$iTGI getComponentInstanceComponentID $componentInstanceID]

   if  { $componentInstanceID ne "" && $componentID ne "" } {

      set allChainIDs [$iTGIHelper getGeneratorChainIDs $componentID]

      ;# filter chains for COREGEN chains
      set     chainGroups     {}
      lappend chainGroups     "COREGEN"
      $iStringContainer Clear
      foreach chainGroup $chainGroups {
         set group $chainGroup
         $iStringContainer Add group
      }      
      set coregenChainIDs [$iGenerationManager FilterChainIDsByGroup $allChainIDs $iStringContainer "AND"]

      ;# filter chains for simulation files
      set     chainGroups {}
      lappend chainGroups "BEHAVIORAL_SIMULATION_MODEL_CHAIN"
      lappend chainGroups "SIMULATION_MODELS_CHAIN"
      lappend chainGroups "STRUCTURAL_SIMULATION_MODELS_CHAIN"
      $iStringContainer Clear
      foreach chainGroup $chainGroups {
         set group $chainGroup
         $iStringContainer Add group
      }      
      set simChainIDs [$iGenerationManager FilterChainIDsByGroup $coregenChainIDs $iStringContainer "OR"]

      ;# gather generated simulation files
      set fileSetIDs [$iTGIHelper getGeneratedFileSetIDs $componentInstanceID $simChainIDs]
      for {$fileSetIDs GetIterator fileSetIDItr; $fileSetIDItr First } {![$fileSetIDItr IsEnd]} {$fileSetIDItr Next} {
         set fileSetID [$fileSetIDItr CurrentItem]
         set fileIDs   [$iTGI getFileSetFileIDs $fileSetID]
         for {$fileIDs GetIterator fileIDItr; $fileIDItr First } {![$fileIDItr IsEnd]} {$fileIDItr Next} {
            set fileID   [$fileIDItr CurrentItem]
            set fileName [$iTGI getFileName $fileID false]
            regsub -all {\\} $fileName {/} fileName
            lappend simFiles $fileName
         }
      }
   }

   return $simFiles
}

##############################################
# Generate BOM file for a component instance #
##############################################
proc GenerateBOMFile { filename componentInstanceID generatorChainIDs } {

   global iTGI
   global iTGIHelper

   set instanceName    [$iTGI       getComponentInstanceName $componentInstanceID]
   set componentIpType [$iTGIHelper getComponentIpType       $componentInstanceID]
   set outputDirectory [$iTGIHelper getOutputDirectory       $componentInstanceID true]

   set impFiles        [getGeneratedImplementationFiles $componentInstanceID]
   set simFiles        [getGeneratedSimulationFiles     $componentInstanceID]
   set fileHandle      [open "$filename" "w"]

   puts $fileHandle "<?xml version=\"1.0\"?>"
   puts $fileHandle "<BillOfMaterials Version=\"1\" Minor=\"2\">"
   puts $fileHandle "  <IPInstance name=\"$instanceName\">"
   puts $fileHandle "    <FileSets>"

   set fileSetIDs [$iTGIHelper getGeneratedFileSetIDs $componentInstanceID $generatorChainIDs]
   for {$fileSetIDs GetIterator fileSetIDItr; $fileSetIDItr First } {![$fileSetIDItr IsEnd]} {$fileSetIDItr Next} {

      set fileSetID   [$fileSetIDItr CurrentItem]
      set fileSetName [$iTGI getName $fileSetID]

      puts $fileHandle "      <FileSet generator=\"$fileSetName\">"

      set generatorFileCount 0

      set fileIDs    [$iTGI getFileSetFileIDs $fileSetID]
      for {$fileIDs GetIterator fileIDItr; $fileIDItr First } {![$fileIDItr IsEnd]} {$fileIDItr Next} {
         
         set fileID     [$fileIDItr CurrentItem]
         set fileName   [$iTGI getFileName $fileID false]
         regsub -all {\\} $fileName {/} fileName

         set fileType "ignore" ;# default
         set fileTypes  [$iTGI getFileType $fileID]
         for {$fileTypes GetIterator fileTypeItr; $fileTypeItr First } {![$fileTypeItr IsEnd]} {$fileTypeItr Next} {
            set fileType [$fileTypeItr CurrentItem]
            if { $fileType ne "" } { break }
         }

         ;# CR:589308 - Spirit generation flow does NOT deliver an XMDF file. Instead we
         ;#             must resolve implementation file types from their generator chains.
         if { ![file isfile [file join $outputDirectory "${instanceName}_xmdf.tcl"]] 
            && [string equal -nocase $componentIpType "spirit"] 
            && [lsearch -exact $impFiles $fileName] < 0 
            && [lsearch -exact $simFiles $fileName] < 0 } {    
            set fileType "ignore" ;# override filetype
         }

         set fileTime     [$iTGIHelper getFileTimestamp $fileID]
         set fileCheckSum [$iTGIHelper getFileChecksum  $fileID]

         ;# If there is logicalName data, put it in as library data.
         set libInfo [$iTGI getFileLogicalName $fileID]
         set slen [string length $libInfo] 
         if { $slen != 0 } { 
            puts $fileHandle "        <File name=\"$fileName\" type=\"$fileType\" library=\"$libInfo\" timestamp=\"$fileTime\" checksum=\"$fileCheckSum\"></File>"
         } else { 
            puts $fileHandle "        <File name=\"$fileName\" type=\"$fileType\" timestamp=\"$fileTime\" checksum=\"$fileCheckSum\"></File>"
         }

         incr generatorFileCount

      } ;# end fileItr

      if { $generatorFileCount <= 0 } {
         ;# CR:552216 - Ensure at least 1 "dummy" log file exists per generator. This is a requirement 
         ;#             for PA integration. - bcotter (10-Mar-2010)
         set fileName     "./$fileSetName.xlog"
         set fileType     "ignore"
         set fileTime     [clock format [clock seconds] -format "%a %b %d %H:%M:%S GMT %Y" -gmt true]
         set fileCheckSum "0xFFFFFFFF"
         puts $fileHandle "        <File name=\"$fileName\" type=\"$fileType\" timestamp=\"$fileTime\" checksum=\"$fileCheckSum\"></File>"
      }

      puts $fileHandle "      </FileSet>"

   } ;# end fileSetIDItr

   puts $fileHandle "    </FileSets>"
   puts $fileHandle "  </IPInstance>"
   puts $fileHandle "</BillOfMaterials>"

   close $fileHandle

} ;# end GenerateBOMFile()

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
