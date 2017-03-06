# Globals
set canvaswidth 500
set canvasheight 500
set rightFrameWidth 25
set listBoxHeight 20
set gridsize 19
set offset 3
set regionOffset 1.5
set pinsize 1
set netLineWidth 3
set digress 0.3
set consoleWidth 50
set consoleHeight 12
set highlightWidth 3
set trafficEntryWidth 15
set spaceFrameHeight 30
set msTypeWidth 10
set physLocWidth 20
set panIncr 10
set lensMargin 10
set lensTolerance 1e-3
set numColorGradients 5
set channelWidthForMaps 5
set compilerBWDenominator 19200
set toolPrefix "xnw"
set masterRegex "noc_nmu|master"
set slaveRegex "noc_nsu|slave"
set ddrRegex "ddr_controller"
set switchRegex "noc_switch|switch"
set masterFrameName "masterFrame"
set slaveFrameName "slaveFrame"
set trafficFrameName "trafficFrame"
set simSettingsLbfName "simSettingsFrame"
set gridcolor "#CACACA"
set regioncolor "#CACACA"
set mastercolor "blue"
set slavecolor "green"
set switchcolor "red"
set outlinecolor "white"
set textcolor "white"
set instStipple "gray25"
set rubberBandColor "white"
set portconnectioncolor "#948E92"
set portfillcolor "#E753F5"
set highlightColor "white"
set lensBoundaryColor "red"
set gridtag "grid"
set regiontag "region"
set porttag "port"
set insttag "inst"
set highlighttag "highlight"
set prevMapDisplayType1 "none"
set prevMapDisplayType2 "write"
set mapTypeString ""
set mapTypeStringTag "mapTypeString"
set boldFont "-family helvetica -size 24 -weight bold"
set topLevelWindowTitle "Xilinx NOC Wizard"
set outDir [append toolPrefix "Out"]
set compilerOutFile "$outDir/$toolPrefix\__compiler__out.txt"
set simulatorOutFile "$outDir/$toolPrefix\__simulator__out.txt"
set solutionOutFile "$outDir/$toolPrefix\__solution__out.txt"
set ntfOutFile "$outDir/$toolPrefix\__ntf__out.ntf"
set npfOutFile "$outDir/$toolPrefix\__npf__out.npf"
set npfDBOutFile "$outDir/$toolPrefix\__npfDB__out.txt"
set graphOutFile "$outDir/$toolPrefix\__graph__out.txt"
set typeOutFile "$outDir/$toolPrefix\__type__out.txt"
set jsonOutFileOrig "$outDir/$toolPrefix\__adl__orig__out.txt"
set jsonOutFilePruned "$outDir/$toolPrefix\__adl__pruned__out.txt"
set ntfToImportFile "$outDir/$toolPrefix\__ntf__to__import__out.txt"
set userTrafficOutFile "$outDir/$toolPrefix\__userTrafficQos__out.txt"
set trafficSetOutFile "$outDir/$toolPrefix\__trafficset__out.txt"
set regionOutFile "$outDir/$toolPrefix\__region__out.txt"
set regridFile "$outDir/$toolPrefix\__regrid__out.txt"
set latencyPlotFile "$outDir/$toolPrefix\__latency__plot.html"
set outModelFile "$outDir/$toolPrefix\__model_out.txt"
#-----------------------------------------------------------------------------------

# Check if tcl version is >= 8.5
#if {$::tcl_version < 8.5} {
#   puts "ERROR-100: Please use tcl 8.5 or newer"
#   return
#}


if {0} {
#TODO:
# implement all zoom buttons and keyboard shortcuts
# implement help and about-me windows
# update the help text
# fix minimum geometry of toplevel
# remove old code for zoom 
# remove old code for json parse
# redraw should not draw nets if they are hidden
# create a top level dir for dumping out all outputs into
# remove ytransform
# fix regrid
# fix ParseSolutionAndDrawNets
# fix issue with zoomout
# provide support for multiple solutions
# simulation data display - show data on ports
# tcl command window
# splitter between canvas and console
# white display in certain VNC settings
# use traffic window - multiple physical location selection
# support for NPF format
# improve splashscreen
# call simulatio executable
# add progress bars for compiler and simulator
# remove focus from search entry
# DDR display
}


#======================================================================
proc showHelp {} {

set helpStr "\
KeyBoard Shortcuts-
\tView-
\t\t1) Zoom-Fit  : f
\t\t2) Zoom-Out  : Ctrl-Z
\t\t3) Zoom-In   : Ctrl-z
\t\t4) Pan-Left  : Left Arrow Key
\t\t5) Pan-Right : Right Arrow Key
\t\t6) Pan-Up    : Up Arrow Key
\t\t7) Pan-Down  : Down Arrow Key

\tGeneral-
\t\t1) Quit      : Ctrl-q


Mouse Gestures-
\t1) Zooming : Left-Click and drag

		                         |
		                         |
		    Zoom-Fit             |           Zoom-Out <factor>
		             ****        |       ****
		             * *.        |        .**
		             *    .      |      .   *
		                    .    |    .
		                      .  |  .
		                        .|.
		------------------------------------------------------
		                        .|.
		                      .  |  .
		                    .    |    .
		                  .      |      .    
		              * .        |        . *
		              **         |         **
		              ****       |       ****
		  Zoom-In <factor>       |           Zoom-Area   
		                         |
		

\t2) Property Query : Double-Click


Net Searching Features-
"

myPuts $helpStr
}


# Overwrite puts and parray for non-debug mode
proc myPuts {args} {
   global env
   if {[info exists env(DEBUG_DRAWNOCGRAPH)]} {
      eval "::puts $args"
   }
}

proc myParray {args {pattern *}} {
   global env
   if {[info exists env(DEBUG_DRAWNOCGRAPH)]} {
      upvar 1 $args array
      if {![array exists array]} {
         error "\"$args\" isn't an array"
      }
      set maxl 0
      foreach name [lsort [array names array $pattern]] {
         if {[string length $name] > $maxl} {
            set maxl [string length $name]
         }
      }
      set maxl [expr {$maxl + [string length $args] + 2}]
      foreach name [lsort [array names array $pattern]] {
         set nameString [format %s(%s) $args $name]
         puts stdout [format "%-*s = %s" $maxl $nameString $array($name)]
      }
   }
}

#------------------------------#
   
proc createGui {} {
   global env
   global canvaswidth
   global canvasheight
   global rightFrameWidth
   global listBoxHeight
   global consoleWidth
   global consoleHeight
   global c
   global listBox
   global gridCheckbox
   global portNamesCheckBox
   global instNamesCheckbox
   global log
   global topLevelWindowTitle
   global tclPromptEval

# Gui
    #Menu
    menu .mbar
    . configure -menu .mbar
    
    menu .mbar.file -tearoff 0
    .mbar add cascade -menu .mbar.file -label "File" -underline 0
    .mbar.file add command -label "Exit (Ctrl-q)" -underline 0 -command {OnExit}     
    
    menu .mbar.tools -tearoff 0
    .mbar add cascade -menu .mbar.tools -label "Tools" -underline 0
    .mbar.tools add command -label "User Traffic & Qos" -underline 0 -command "CreateTrafficGui" 
    .mbar.tools add command -label "Compile" -underline 0 -command "doCompile" 
    .mbar.tools add command -label "Simulate" -underline 0 -command "doSimulate" 

    menu .mbar.view -tearoff 0
    .mbar add cascade -menu .mbar.view -label "View" -underline 0
    .mbar.view add command -label "Zoom In (Ctrl-z)" -underline 5 -command "zoomInByFactor" 
    .mbar.view add command -label "Zoom Out (Ctrl-Z)" -underline 5 -command "zoomOutByFactor" 
    .mbar.view add command -label "Zoom Top (f)" -underline 5 -command "zoomFit" 
    .mbar.view add command -label "Back" -underline 0 -command "" -state disabled 

    menu .mbar.help -tearoff 0
    .mbar add cascade -menu .mbar.help -label "Help" -underline 0
    .mbar.help add command -label "Show Help" -underline 0 -command "showHelp" -state disabled 
    .mbar.help add command -label "About" -underline 0 -command "" -state disabled 
        

    #Toolbar
    frame .toolbar -bd 1 -relief raised
    
    button .toolbar.userTraffic -relief raised -text "User Traffic & Qos" -command "CreateTrafficGui" 
    button .toolbar.compile -relief raised -text "Compile" -command "doCompile" 
    button .toolbar.simulate -relief raised -text "Simulate" -command "doSimulate" 
    
    if {[info exists env(DEBUG_DRAWNOCGRAPH)]} {
      button .toolbar.regrid -text "Regrid" -command "Regrid"
      grid .toolbar.regrid -row 2 -column 1
    }
    pack .toolbar.userTraffic -side left -padx 2 -pady 2
    pack .toolbar.compile -side left -padx 2 -pady 2
    pack .toolbar.simulate -side left -padx 2 -pady 2
    if {[info exists env(DEBUG_DRAWNOCGRAPH)]} {
      pack .toolbar.regrid -side left -padx 2 -pady 2
    }
    
    pack .toolbar -fill x
		
    #Panedwindow
    panedwindow .p -orient vertical -sashwidth 10 -handlesize 15 -showhandle 1 -sashrelief ridge -opaqueresize false

    #Left Frame
    frame .p.rightTop 
    set c [canvas .p.rightTop.c -width $canvaswidth -height $canvasheight -background black]
    #        -xscrollcommand ".p.rightTop.shoriz set" \
    #        -yscrollcommand ".p.rightTop.svert set"]

    #scrollbar .p.rightTop.svert  -orient v -command "$c yview"
    #scrollbar .p.rightTop.shoriz -orient h -command "$c xview" 
    grid .p.rightTop.c      -row 0 -column 0 -columnspan 3 -sticky news
    #grid .p.rightTop.svert  -row 0 -column 3 -columnspan 1 -sticky ns
    #grid .p.rightTop.shoriz -row 1 -column 0 -columnspan 3 -sticky ew
    grid columnconfigure .p.rightTop 0 -weight 1
    grid columnconfigure .p.rightTop 1 -weight 1
    grid columnconfigure .p.rightTop 2 -weight 1
    grid rowconfigure .p.rightTop 0 -weight 1

    
    # Set up event bindings for canvas:
    #bind $c <3> "zoomMark $c %x %y"
    #bind $c <B3-Motion> "zoomStroke $c %x %y"
    #bind $c <ButtonRelease-3> "zoomArea $c %x %y"
    
    bind $c <Double-1> {selectItemAtXY $c %x %y }
    bind $c <1> "zoomStart $c %x %y"
    bind $c <B1-Motion> "zoomMove $c %x %y"
    bind $c <ButtonRelease-1> "zoomEnd $c %x %y"
    bind $c <Configure>    {redraw $c}
   
    bind . <Control-KeyPress-z> {zoomInByFactor}
    bind . <Control-KeyPress-Z> {zoomOutByFactor}
    bind $c <Key-Up> {moveUp $c}
    bind $c <Key-Down> {moveDown $c}
    bind $c <Key-Left> {moveLeft $c}
    bind $c <Key-Right> {moveRight $c}
    bind $c <f> {zoomFit}

    focus $c

    if {[info exists env(DEBUG_DRAWNOCGRAPH)]} {
      bind $c <3>         {downCanvasItem %W %x %y}
      bind $c <B3-Motion> {moveCanvasItem %W %x %y}
      bind $c <ButtonRelease-3> {snapCanvasItem %W %x %y}
    }

    #General bindings for entry
    bind Entry <<PasteSelection>> {
      if {$tk_strictMotif || ![info exists tk::Priv(mouseMoved)] || !$tk::Priv(mouseMoved)} {
         tk::EntryPaste %W %x
      }   
    }

	 proc ::tk::EntryPaste {w x} {
	    $w icursor [EntryClosestGap $w $x] 
	    catch {$w insert insert [string trim [::tk::GetSelection $w PRIMARY]]}
	    if {[string compare "disabled" [$w cget -state]]} {focus $w} 
	 }
	
	 proc ::tk::EntryClosestGap {w x} {
	    set pos [$w index @$x]
	    set bbox [$w bbox $pos]
	    if {($x - [lindex $bbox 0]) < ([lindex $bbox 2]/2)} {
	       return $pos
	    }   
	    incr pos 
	 }

    #Right Frame
    frame .left -borderwidth 2 -relief groove 

    #Labelframe to hold zoom buttons
    labelframe .left.zoomLabelFrame -text "View" -width $rightFrameWidth
    #  Add a couple of zooming buttons
    button .left.zoomLabelFrame.zoomin  -text "Zoom In"  -command "zoomInByFactor" 
    button .left.zoomLabelFrame.zoomout -text "Zoom Out" -command "zoomOutByFactor"
    button .left.zoomLabelFrame.zoomtop -text "Zoom Top" -command "zoomFit"
    button .left.zoomLabelFrame.back -text "Back" -command ""
    button .left.zoomLabelFrame.help -text "Help" -command ""
    .left.zoomLabelFrame.back configure -state disabled
    .left.zoomLabelFrame.help configure -state disabled
    grid .left.zoomLabelFrame.zoomin -row 0 -column 0 -sticky ew
    grid .left.zoomLabelFrame.zoomout -row 0 -column 1 -sticky ew
    grid .left.zoomLabelFrame.zoomtop -row 1 -column 0 -sticky ew
    grid .left.zoomLabelFrame.back -row 1 -column 1 -sticky ew
    grid .left.zoomLabelFrame.help -row 2 -column 0 -sticky ew
    


    #Labelframe to hold settings buttons
    labelframe .left.settingsLabelFrame -text "Display" -width $rightFrameWidth
    set gridCheckbox [checkbutton .left.settingsLabelFrame.showGrid -text "Grid" -variable showGrid -anchor w -command "toggleGrid $c"]
    $gridCheckbox select 
    set regionCheckbox [checkbutton .left.settingsLabelFrame.showRegion -text "Region" -variable showRegion -anchor w -command "toggleRegion $c"]
    set portNamesCheckBox [checkbutton .left.settingsLabelFrame.showPortNames -text "Port Names" -variable showPortNames -anchor w -command "togglePortNames $c"]
    $portNamesCheckBox select
    set instNamesCheckbox [checkbutton .left.settingsLabelFrame.showInstNames -text "Inst Names" -variable showInstNames -anchor w -command "toggleInstNames $c"]
    $instNamesCheckbox select
    button .left.settingsLabelFrame.clear -text "Clear Highlights" -command "clearCanvasHighlights"
    grid .left.settingsLabelFrame.showGrid -row 0 -column 0 -sticky ew
    grid .left.settingsLabelFrame.showRegion -row 1 -column 0 -sticky ew
    grid .left.settingsLabelFrame.showPortNames -row 0 -column 1 -sticky ew
    grid .left.settingsLabelFrame.showInstNames -row 1 -column 1 -sticky ew
    grid .left.settingsLabelFrame.clear -row 2 -column 0 -columnspan 2 -sticky w

    #Labelframe for compiler
    labelframe .left.compilerLabelFrame -text "Compiler" -width $rightFrameWidth
    radiobutton .left.compilerLabelFrame.none -text "Nets" -variable mapDisplayType1 -value "none" -anchor w -command ShowMapWrapper
    radiobutton .left.compilerLabelFrame.bandwidth -text "Bandwidth" -variable mapDisplayType1 -value "compilerBandwidth" -anchor w -command ShowMapWrapper
    .left.compilerLabelFrame.bandwidth configure -state disabled
    .left.compilerLabelFrame.none select
    grid .left.compilerLabelFrame.none -row 0 -column 0 -sticky ew
    grid .left.compilerLabelFrame.bandwidth -row 0 -column 1 -sticky ew

    #Labelframe for simulator 
    labelframe .left.simulatorLabelFrame -text "Simulator Heat Maps" -width $rightFrameWidth
    radiobutton .left.simulatorLabelFrame.rawUtil  -text "Raw Util%" -variable mapDisplayType1 -value "rawutil" -anchor w -command ShowMapWrapper
    radiobutton .left.simulatorLabelFrame.effUtil  -text "Effective Util%" -variable mapDisplayType1 -value "effectiveutil" -anchor w -command ShowMapWrapper
    radiobutton .left.simulatorLabelFrame.bandwidth  -text "Bandwidth" -variable mapDisplayType1 -value "simulatorBandwidth" -anchor w -command ShowMapWrapper
    frame .left.simulatorLabelFrame.rwframe
    radiobutton .left.simulatorLabelFrame.rwframe.write -text "Write" -variable mapDisplayType2 -value "write" -anchor w -command ShowMapWrapper
    radiobutton .left.simulatorLabelFrame.rwframe.read -text "Read" -variable mapDisplayType2 -value "read" -anchor w -command ShowMapWrapper
    button .left.simulatorLabelFrame.settings -text "Map Settings" -command "showHeatMapSettingsGui"
    ttk::separator .left.simulatorLabelFrame.s1 -orient horizontal 
    ttk::separator .left.simulatorLabelFrame.s2 -orient horizontal 
    .left.simulatorLabelFrame.rwframe.write select

    grid .left.simulatorLabelFrame.rwframe.write -row 0 -column 0
    grid .left.simulatorLabelFrame.rwframe.read -row 0 -column 1

    grid .left.simulatorLabelFrame.rawUtil -row 0 -column 0 -sticky ew
    grid .left.simulatorLabelFrame.effUtil -row 1 -column 0 -sticky ew
    grid .left.simulatorLabelFrame.bandwidth -row 2 -column 0 -sticky ew
    grid .left.simulatorLabelFrame.s1 -row 3 -column 0 -sticky ew -padx 5 -pady 3 -columnspan 2
    grid .left.simulatorLabelFrame.rwframe -row 4 -column 0 -sticky ew
    grid .left.simulatorLabelFrame.s2 -row 5 -column 0 -sticky ew -padx 5 -pady 3 -columnspan 2
    grid .left.simulatorLabelFrame.settings -row 6 -column 0 -sticky ew -columnspan 1


    # Create the listbox
    labelframe .left.searchLabelFrame -text "Search Nets" -width $rightFrameWidth
    scrollbar .left.searchLabelFrame.s -command ".left.searchLabelFrame.l yview"
    set listBox [listbox .left.searchLabelFrame.l -yscroll ".left.searchLabelFrame.s set" -selectmode multiple -height $listBoxHeight -background white -exportselection 0]
    bind .left.searchLabelFrame.l <B1-ButtonRelease> {showNet $c $listBox [.left.searchLabelFrame.l curselection]}

    #Create the searchbox
    #label .left.searchLabel -text "Search:"
    entry .left.searchLabelFrame.searchEntry -relief sunken -bd 2 -textvariable searchname -background white 
    bind .left.searchLabelFrame.searchEntry <Return> {doSearch $searchname; set searchname ""}
    

    # Create show/hide buttons
    frame .left.searchLabelFrame.netButtonsFrame
    button .left.searchLabelFrame.netButtonsFrame.showAll -text "Show All"  -command "showAll $c $listBox" 
    button .left.searchLabelFrame.netButtonsFrame.hideAll -text "Hide All"  -command "hideAll $c $listBox"
    grid .left.searchLabelFrame.netButtonsFrame.showAll -row 0 -column 0 -sticky ew
    grid .left.searchLabelFrame.netButtonsFrame.hideAll -row 0 -column 1 -sticky ew
    
    grid .left.searchLabelFrame.searchEntry -row 0 -column 0 -columnspan 2 -sticky ew
    grid .left.searchLabelFrame.l -row 1 -column 0 -sticky ew 
    grid .left.searchLabelFrame.s -row 1 -column 1 -sticky news
    grid .left.searchLabelFrame.netButtonsFrame -row 2 -column 0 -columnspan 2 
 

    #grid .left.zoomLabelFrame -row 0 -column 0 -columnspan 2 -sticky ew
    grid .left.settingsLabelFrame -row 0 -column 0 -columnspan 2 -sticky ew -padx 3 -pady 5
    grid .left.compilerLabelFrame -row 1 -column 0 -columnspan 2 -sticky ew -padx 3 -pady 5
    grid .left.simulatorLabelFrame -row 2 -column 0 -columnspan 2 -sticky ew -padx 3 -pady 5
    grid .left.searchLabelFrame -row 3 -column 0 -columnspan 2 -sticky w -padx 3 -pady 5


    #Bottom frame for log console
    frame .p.rightBottom
    set log [text .p.rightBottom.log -width $consoleWidth -height $consoleHeight \
     -borderwidth 2 -relief sunken -setgrid true \
     -yscrollcommand {.p.rightBottom.scroll set} -background white]
    $log config -state disabled 
    scrollbar .p.rightBottom.scroll -command {.p.rightBottom.log yview}
    set tclPrompt [entry .p.rightBottom.prompt -background white]

    # Text tags give script output, command errors, command
	 # results, and the prompt a different appearance
	 $log tag configure prompt -underline true
 	 $log tag configure result -foreground black 
 	 $log tag configure error -foreground red
 	 $log tag configure output -foreground blue
	

	 # Insert the prompt and initialize the limit mark
	 set tclPromptEval(prompt) ""
	 set tclPromptEval(text) $tclPrompt
    set tclPromptEval(slave) [SlaveInit shell]
    RegisterTclCommands $tclPromptEval(slave)
    initTclCommandsStack
	
	 # Key bindings that limit input and eval things. The break in
	 # the bindings skips the default Text binding for the event.
	 bind $tclPrompt <Return> {EvalTypein ; break}
	 bind $tclPrompt <Key-Up> {showTclCommandUp}
	 bind $tclPrompt <Key-Down> {showTclCommandDown}


    grid .p.rightBottom.log -row 0 -column 0 -sticky ewns 
    grid .p.rightBottom.scroll -row 0 -column 1 -sticky ns
    grid .p.rightBottom.prompt -row 1 -column 0 -columnspan 2 -sticky ew 
    grid columnconfigure .p.rightBottom 0 -weight 1
    grid columnconfigure .p.rightBottom 1 -weight 0
    grid rowconfigure .p.rightBottom 0 -weight 1
    grid rowconfigure .p.rightBottom 1 -weight 0

    pack .p.rightBottom -side bottom -fill both -expand true

    #Grid the frames now 
    #grid .p.rightTop -row 0 -column 0 -expand 1
    #grid .left -row 0 -column 1
    pack .p.rightTop   -side right -expand 1 -fill both
    pack .p.rightBottom -side bottom -expand 0
    pack .left   -side left -fill y

    .p add .p.rightTop -stretch always -minsize 100
    .p add .p.rightBottom -stretch never -minsize 100 
    pack .p -fill both -expand 1

    bind . <Control-KeyPress-q> {OnExit}
    wm protocol . WM_DELETE_WINDOW {OnExit}
    wm title . $topLevelWindowTitle 
}

proc CreateTrafficGui {{reCreate 0}} {
   global trafficGuiTopLevel
   global masterGuiIndexes
   global slaveGuiIndexes
   global trafficGuiIndexes
   global trafficEntryWidth
   global masterTypeWidth
   global physLocWidth
   global typeToLocArr
   global qosArr
   global transTypeArr 
   global spaceFrameHeight
   global masterInfoArr
   global slaveInfoArr
   global trafficInfoArr
   global runMode

   array set transTypeArr {
      "RW" 1
      "RO" 1
      "WO" 1
      "STRM" 1
   }



   if {[info exists trafficGuiTopLevel] && !$reCreate} {
      wm deiconify $trafficGuiTopLevel
      raise $trafficGuiTopLevel
   } else {
      if {[info exists trafficGuiTopLevel]} {
         destroyWidget $trafficGuiTopLevel
      }
      set trafficGuiTopLevel [toplevel .trafficGui]
      wm title $trafficGuiTopLevel "User Traffic and QoS"
      wm protocol $trafficGuiTopLevel WM_DELETE_WINDOW {saveTrafficFileBeforeClosing}
      wm geometry $trafficGuiTopLevel 110x30 
      if {$runMode == "compile"} {
         wm withdraw $trafficGuiTopLevel
      }

      set myMenu [menu $trafficGuiTopLevel.mbar]
      $trafficGuiTopLevel configure -menu $myMenu 
    
      menu $myMenu.file -tearoff 0
      $myMenu.file add command -label "Import Traffic and Qos" -underline 0 -command "importTrafficAndQos"
      $myMenu.file add command -label "Import NTF" -underline 0 -command "importNTF"
      $myMenu.file add command -label "Export Traffic and Qos" -underline 0 -command "exportTrafficAndQos"
      $myMenu.file add command -label "Export NTF" -underline 0 -command "exportNTF"
      $myMenu add cascade -menu $myMenu.file -label "File" -underline 0

	   set myNoteBook [ttk::notebook .trafficGui.n]
	   pack $myNoteBook -expand yes -fill both 
	
	   set topFrame1 [frame $myNoteBook.topFrame1]
	   set topFrame2 [frame $myNoteBook.topFrame2]
	
	   #-----Text widget within which all other frames will be embedded. This is done to get the Scroll capability.
	   set TT1 [text $topFrame1.t -yscrollcommand "$topFrame1.scroll set" -setgrid true -wrap word]
	   scrollbar $topFrame1.scroll -command "$TT1 yview"
	   pack $topFrame1.scroll -side right -fill y
	   pack $TT1 -expand yes -fill both
	
	   set finalTopFrame1 [frame $TT1.topFrame1]
	   grid $finalTopFrame1 -row 0 -column 0
	
	   $TT1 window create end -window $finalTopFrame1
	   $TT1 configure -state disabled
	   $TT1 configure -cursor {}
	   #-----
	
	   #-----Text widget within which all other frames will be embedded. This is done to get the Scroll capability.
	   set TT2 [text $topFrame2.t -yscrollcommand "$topFrame2.scroll set" -setgrid true -wrap word]
	   scrollbar $topFrame2.scroll -command "$TT2 yview"
	   pack $topFrame2.scroll -side right -fill y
	   pack $TT2 -expand yes -fill both
	
	   set finalTopFrame2 [frame $TT2.topFrame2]
	   grid $finalTopFrame2 -row 0 -column 0
	
	   $TT2 window create end -window $finalTopFrame2
	   $TT2 configure -state disabled
	   $TT2 configure -cursor {}
	   #-----
	
	
	
	
	   set masterFrame [frame $finalTopFrame1.masterFrame]
	   frame $finalTopFrame1.spaceFrame1 -height $spaceFrameHeight 
	   set slaveFrame [frame $finalTopFrame1.slaveFrame]
	   set trafficFrame [frame $finalTopFrame2.trafficFrame]
	
	   array set masterGuiIndexes {index 0}
	   array set slaveGuiIndexes {index 0}
	   array set trafficGuiIndexes {index 0}
	  
     
     #Populate the gui
      if {[info exists masterInfoArr]} {
         for {set i 0} {$i < [array size masterInfoArr]} {incr i} {
            set elem $masterInfoArr($i)
 	         addMSRow $masterFrame "Master" $elem
         }
      } else {
   	   for {set i 0} {$i < 5} {incr i} {
	        addMSRow $masterFrame "Master" 
	      }
      }


      if {[info exists slaveInfoArr]} {
         for {set i 0} {$i < [array size slaveInfoArr]} {incr i} {
            set elem $slaveInfoArr($i)
 	         addMSRow $slaveFrame "Slave" $elem
         }
      } else {
   	   for {set i 0} {$i < 5} {incr i} {
	         addMSRow $slaveFrame "Slave" 
	      }
      }


      if {[info exists trafficInfoArr]} {
         for {set i 0} {$i < [array size trafficInfoArr]} {incr i} {
            set elem $trafficInfoArr($i)
	         addTrafficRow $trafficFrame $elem
         }
      } else {
	      for {set i 0} {$i < 5} {incr i} {
	         addTrafficRow $trafficFrame 
	      }
      }

	   pack $topFrame1 -expand yes -fill both 
	   grid $finalTopFrame1.masterFrame -row 0 -column 0
	   grid $finalTopFrame1.spaceFrame1 -row 1 -column 0
	   grid $finalTopFrame1.slaveFrame -row 2 -column 0
	   
	   grid $finalTopFrame2.trafficFrame -row 0 -column 0
	   
	   $myNoteBook add $topFrame1 -text "Interfaces" 
	   $myNoteBook add $topFrame2 -text "Data Flow"
         
   }
}

proc addMSRow {w mstype {values ""}} {
   global masterGuiIndexes
   global slaveGuiIndexes
   global trafficEntryWidth
   global masterFrameName
   global slaveFrameName
   global msTypeWidth
   global physLocWidth
   global typeToLocArr

   if {$mstype == "Master"} {
      set index $masterGuiIndexes(index)
      set frameName $masterFrameName
   } else {
      set index $slaveGuiIndexes(index)
      set frameName $slaveFrameName
   }

   set myFrame [frame $w.$frameName$index]
   
   if {$index == 0} {
      label $myFrame.name -text "$mstype" -width $trafficEntryWidth
      label $myFrame.type -text "Type" -width $msTypeWidth
      label $myFrame.loc -text "Physical Location" -width $physLocWidth
      grid $myFrame.name -row 0 -column 0 -sticky w
      grid $myFrame.type -row 0 -column 1 -sticky w
      grid $myFrame.loc -row 0 -column 2 -sticky w
   }

   foreach elem [array names typeToLocArr] {
      set t1 [lindex [split $elem ","] 0]
      set t2 [lindex [split $elem ","] 1]
      if {$mstype == "Master" && $t2 == "NMU"} {
         lappend masterTypeValues $t1
      }
      if {$mstype == "Slave" && $t2 == "NSU"} {
         lappend slaveTypeValues $t1
      }
   }

   entry $myFrame.msName -width $trafficEntryWidth -relief sunken -bd 2 -textvariable msName$mstype$index -background white
   if {$mstype == "Master"} {
      ttk::combobox $myFrame.msType -textvariable msType$mstype$index -width $msTypeWidth -values $masterTypeValues 
      bind $myFrame.msType <<ComboboxSelected>> [list setPhyLocCB %W $myFrame.physicalLocation "NMU"]
   } else {
      ttk::combobox $myFrame.msType -textvariable msType$mstype$index -width $msTypeWidth -values $slaveTypeValues 
      bind $myFrame.msType <<ComboboxSelected>> [list setPhyLocCB %W $myFrame.physicalLocation "NSU"]
   }
   bind $myFrame.msType <KeyRelease> [list ComboBoxAutoComplete %W %K]
   ttk::combobox $myFrame.physicalLocation -textvariable physicalLocation$mstype$index -width $physLocWidth -values "Unassigned" 
   bind $myFrame.physicalLocation <KeyRelease> [list ComboBoxAutoComplete %W %K]
   $myFrame.physicalLocation current 0
   button $myFrame.addRowButton -text "+"  -command "addMSRow $w $mstype"
   button $myFrame.removeRowButton -text "x"  -command "destroyWidget $myFrame"
   if {$index == 0} {
      $myFrame.removeRowButton configure -state disabled
   }


   #Populate values
   if {[info exists values] && $values != ""} {
      set name [lindex [split $values ","] 0]
      set type [lindex [split $values ","] 1]
      set loc [lindex [split $values ","] 2]
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      # VERY IMPORTANT NOTE: setting the following variables (which are 
      # entry widget's -textvariable) to global is important to access them.
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      global msName$mstype$index
      global msType$mstype$index
      global physicalLocation$mstype$index
      if {$name != "{}"} {
         set msName$mstype$index $name
      } 
      if {$type != "{}"} {
         set msType$mstype$index $type
      }
      if {$loc != "{}"} {
         set physicalLocation$mstype$index $loc
      }
   }


   grid $myFrame -row $index -column 0 -pady 5
   grid $myFrame.msName -row 1 -column 0
   grid $myFrame.msType -row 1 -column 1
   grid $myFrame.physicalLocation -row 1 -column 2
   grid $myFrame.addRowButton -row 1 -column 3
   grid $myFrame.removeRowButton -row 1 -column 4
  
   if {$mstype == "Master"} {
      incr masterGuiIndexes(index)
   } else {
      incr slaveGuiIndexes(index)
   }
}

proc destroyWidget {w} {
   foreach elem [wlist $w] {
      if {[winfo class $elem] == "Entry" || [winfo class $elem] == "TCombobox"} {
            set varname [$elem cget -textvariable]
            global [set varname]
            if {[info exists [set varname]]} {
               set [set varname] ""
               #NOTE: the following "unset" doesn't really work!! So we are just setting the variable to empty string! Need to investigate this more later.
               unset [set varname]
            }
      }
   }
   destroy $w
}

proc saveTrafficFileBeforeClosing {} {
   global trafficGuiTopLevel
   wm withdraw $trafficGuiTopLevel
   return

   set answer [tk_messageBox -message "User-Traffic/Data-Flow information has changed. Save As NTF?" -type yesno -icon question]
   switch -- $answer {
      yes {
         set types {
            {"All files"            *}
         }   
         set filename [tk_getSaveFile -filetypes $types]
         if {![info exists filename]} {
            tk_messageBox -message "Please provide a valid filename" -type ok -icon error
         }
         wm withdraw $trafficGuiTopLevel
      } 
      no {wm withdraw $trafficGuiTopLevel}
   }
}

proc setPhyLocCB {typeCB phyLocCB NU} {
   global typeToLocArr
   $phyLocCB configure -values [concat "Unassigned" $typeToLocArr([$typeCB get],$NU)]
   $phyLocCB current 0
}

proc ComboBoxAutoComplete {path key} {
  if {[string length $key] > 1 && [string tolower $key] != $key} {return}
  
  set text [string map [list {[} {\[} {]} {\]}] [$path get]]
  if {[string equal $text ""]} {return}
  
  set values [$path cget -values]
  set x [lsearch $values $text*]
  if {$x < 0} {return}
  
  set index [$path index insert]
  $path set [lindex $values $x]
  $path icursor $index
  $path selection range insert end
  event generate $path <<ComboboxSelected>>
}

proc addTrafficRow {w {values ""}} {
   global trafficGuiIndexes
   global trafficEntryWidth
   global trafficFrameName
   global transTypeArr 
   global qosArr

   set frameName $trafficFrameName
   set index $trafficGuiIndexes(index)
   set myFrame [frame $w.$frameName$index]
   
   if {$index == 0} {
      label $myFrame.master -text "Master" -width $trafficEntryWidth 
      label $myFrame.slave -text "Slave" -width $trafficEntryWidth 
      label $myFrame.type -text "Transaction Type" -width $trafficEntryWidth
      label $myFrame.read -text "Read Qos" -width $trafficEntryWidth
      label $myFrame.write -text "Write/STRM QoS" -width $trafficEntryWidth
      grid $myFrame.master -row 0 -column 0 -sticky w
      grid $myFrame.slave -row 0 -column 1 -sticky w
      grid $myFrame.type -row 0 -column 2 -sticky w
      grid $myFrame.read -row 0 -column 3 -sticky w
      grid $myFrame.write -row 0 -column 4 -sticky w
   }

   entry $myFrame.mName -width $trafficEntryWidth -relief sunken -bd 2 -textvariable mName$index -background white
   entry $myFrame.sName -width $trafficEntryWidth -relief sunken -bd 2 -textvariable sName$index -background white
   ttk::combobox $myFrame.transType -textvariable transType$index -width $trafficEntryWidth -values [array names transTypeArr] 
   bind $myFrame.transType <<ComboboxSelected>> [list selectTransTypeFields %W $myFrame]
   bind $myFrame.transType <KeyRelease> [list ComboBoxAutoComplete %W %K]
   ttk::combobox $myFrame.readQos -textvariable readQos$index -width $trafficEntryWidth -values [array names qosArr] 
   bind $myFrame.readQos <KeyRelease> [list ComboBoxAutoComplete %W %K]
   entry $myFrame.readLat -width $trafficEntryWidth -relief sunken -bd 2 -textvariable readLat$index -background white
   entry $myFrame.readBW -width $trafficEntryWidth -relief sunken -bd 2 -textvariable readBW$index -background white
   ttk::combobox $myFrame.writeQos -textvariable writeQos$index -width $trafficEntryWidth -values [array names qosArr] 
   bind $myFrame.writeQos <KeyRelease> [list ComboBoxAutoComplete %W %K]
   entry $myFrame.writeLat -width $trafficEntryWidth -relief sunken -bd 2 -textvariable writeLat$index -background white
   entry $myFrame.writeBW -width $trafficEntryWidth -relief sunken -bd 2 -textvariable writeBW$index -background white
   label $myFrame.lat -text "Latency" 
   label $myFrame.bw -text "Bandwidth" 

   button $myFrame.addRowButton -text "+"  -command "addTrafficRow $w"
   button $myFrame.removeRowButton -text "x"  -command "destroyWidget $myFrame"
   if {$index == 0} {
      $myFrame.removeRowButton configure -state disabled
   }

   #Populate values
   if {[info exists values] && $values != ""} {
      set master [lindex [split $values ","] 0]
      set slave [lindex [split $values ","] 1]
      set trans [lindex [split $values ","] 2]
      set readQos [lindex [split $values ","] 3]
      set readLat [lindex [split $values ","] 4]
      set readBW [lindex [split $values ","] 5]
      set writeQos [lindex [split $values ","] 6]
      set writeLat [lindex [split $values ","] 7]
      set writeBW [lindex [split $values ","] 8]
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      # VERY IMPORTANT NOTE: setting the following variables (which are 
      # entry widget's -textvariable) to global is important to access them.
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      global mName$index 
      global sName$index
      global transType$index
      global readQos$index
      global readLat$index
      global readBW$index
      global writeQos$index
      global writeLat$index
      global writeBW$index

      if {$master != "{}"} {set mName$index $master}
	   if {$slave != "{}"} {set sName$index $slave}
	   if {$trans != "{}"} {set transType$index $trans; event generate $myFrame.transType <<ComboboxSelected>>}
	   if {$readQos != "{}"} {set readQos$index $readQos}
	   if {$readLat != "{}"} {set readLat$index $readLat}
	   if {$readBW != "{}"} {set readBW$index $readBW}
	   if {$writeQos != "{}"} {set writeQos$index $writeQos}
	   if {$writeLat != "{}"} {set writeLat$index $writeLat}
	   if {$writeBW != "{}"} {set writeBW$index $writeBW}
   }
   grid $myFrame -row $index -column 0 -pady 5
   
   grid $myFrame.mName -row 1 -column 0
   grid $myFrame.sName -row 1 -column 1
   grid $myFrame.transType -row 1 -column 2
   grid $myFrame.lat -row 2 -column 2 -sticky e
   grid $myFrame.bw -row 3 -column 2 -sticky e
   grid $myFrame.readQos -row 1 -column 3
   grid $myFrame.readLat -row 2 -column 3
   grid $myFrame.readBW -row 3 -column 3
   grid $myFrame.writeQos -row 1 -column 4
   grid $myFrame.writeLat -row 2 -column 4
   grid $myFrame.writeBW -row 3 -column 4
   grid $myFrame.addRowButton -row 1 -column 5
   grid $myFrame.removeRowButton -row 1 -column 6
  
   incr trafficGuiIndexes(index)
}

proc selectTransTypeFields {w myFrame} {
   $myFrame.readQos configure -state normal
   $myFrame.readLat configure -state normal
   $myFrame.readBW configure -state normal
   $myFrame.writeQos configure -state normal
   $myFrame.writeLat configure -state normal
   $myFrame.writeBW configure -state normal

   if {[$w get] == "RO"} {
      $myFrame.writeQos set [lindex [$myFrame.writeQos cget -values] 0]
      $myFrame.writeLat delete 0 end 
      $myFrame.writeLat insert 0 "0" 
      $myFrame.writeBW delete 0 end 
      $myFrame.writeBW insert 0 "0" 

      $myFrame.writeQos configure -state disabled
      $myFrame.writeLat configure -state disabled
      $myFrame.writeBW configure -state disabled
   } elseif {[$w get] == "WO" || [$w get] == "STRM" } {
      $myFrame.readQos set [lindex [$myFrame.readQos cget -values] 0]
      $myFrame.readLat delete 0 end 
      $myFrame.readLat insert 0 "0" 
      $myFrame.readBW delete 0 end 
      $myFrame.readBW insert 0 "0" 

      $myFrame.readQos configure -state disabled
      $myFrame.readLat configure -state disabled
      $myFrame.readBW configure -state disabled
   }
}

proc wlist {{W .}} {
   set list [list $W]
   foreach w [winfo children $W] {
      set list [concat $list [wlist $w]]
   }
   return $list
}

proc exportTrafficAndQos {{filename ""}} {
   global trafficGuiTopLevel
   global masterFrameName
   global slaveFrameName
   global trafficFrameName
   global masterInfoArr
   global slaveInfoArr
   global trafficInfoArr

   if {$filename == ""} {
      set types {
         {"All files"            *}
      }   
      set filename [tk_getSaveFile -filetypes $types]
      if {![info exists filename]} {
         tk_messageBox -message "Please provide a valid filename" -type ok -icon error
         return
      }   
   }

   if {$filename == ""} {
      return
   } 


   if {[info exists masterIndexes]} {unset masterIndexes}
   if {[info exists slaveIndexes]} {unset slaveIndexes}
   if {[info exists trafficIndexes]} {unset trafficIndexes}
   if {[info exists masterInfoArr]} {array unset masterInfoArr}
   if {[info exists slaveInfoArr]} {array unset slaveInfoArr}
   if {[info exists trafficInfoArr]} {array unset trafficInfoArr}

   set mindex 0
   set sindex 0
   set tindex 0
   
   foreach elem [wlist $trafficGuiTopLevel] {
      if {[regexp $masterFrameName $elem] || [regexp $slaveFrameName $elem]} {
         if {[regexp $masterFrameName $elem]} {
            set exp ".*.$masterFrameName\(\[0-9\]+\)?\(\.\(.*\)\)?"
         } elseif {[regexp $slaveFrameName $elem]} {
            set exp ".*.$slaveFrameName\(\[0-9\]+\)?\(\.\(.*\)\)?"
         }
         regexp $exp $elem -> nextindex wname
         regsub -all {\.} $wname "" wname 
            if {[regexp $masterFrameName $elem]} {
               if {$wname == "removeRowButton"} {
                  incr mindex 
               }
            } elseif {[regexp $slaveFrameName $elem]} {
               if {$wname == "removeRowButton"} {
                  incr sindex
               }
            }
         if {[info exists wname]} {
            if {$wname != ""} {
               if {$wname == "msName" || $wname == "msType" || $wname == "physicalLocation"} {
                  if {[regexp $masterFrameName $elem]} {
                     if {[info exists masterInfoArr($mindex)]} {
                        set temp $masterInfoArr($mindex)
                        set masterInfoArr($mindex) [lappend temp [list [$elem get]]]
                     } else {
                        set masterInfoArr($mindex) [list [list [$elem get]]]
                     }
                  } elseif {[regexp $slaveFrameName $elem]} {
                     if {[info exists slaveInfoArr($sindex)]} {
                        set temp $slaveInfoArr($sindex)
                        set slaveInfoArr($sindex) [lappend temp [list [$elem get]]]
                     } else {
                        set slaveInfoArr($sindex) [list [list [$elem get]]]
                     }
                  }
               }
            }
         }
      } elseif {[regexp $trafficFrameName $elem]} {
         set exp ".*.$trafficFrameName\(\[0-9\]+\)?\(\.\(.*\)\)?"
         regexp $exp $elem -> nextindex wname
         regsub -all {\.} $wname "" wname
         if {$wname == "removeRowButton"} {
            incr tindex
         }
         if {[info exists wname]} {
            if {$wname != ""} {
               if {$wname == "mName" || $wname == "sName" || $wname == "transType" || $wname == "readQos" || $wname == "readLat" || $wname == "readBW" || $wname == "writeQos" || $wname == "writeLat" || $wname == "writeBW"} {
                  if {[info exists trafficInfoArr($tindex)]} {
                     set temp $trafficInfoArr($tindex)
                     set trafficInfoArr($tindex) [lappend temp [list [$elem get]]]
                  } else {
                     set trafficInfoArr($tindex) [list [list [$elem get]]]
                  }
               }
            }
         }
      }
   }

   foreach {k v} [array get masterInfoArr] {
      set v [join $v ","]
      set masterInfoArr($k) $v
   }
   foreach {k v} [array get slaveInfoArr] {
      set v [join $v ","]
      set slaveInfoArr($k) $v
   }
   foreach {k v} [array get trafficInfoArr] {
      set v [join $v ","]
      set trafficInfoArr($k) $v
   }

   myParray masterInfoArr
   myParray slaveInfoArr
   myParray trafficInfoArr


   set OUT [open $filename w]
   puts $OUT "#Master"
   if {[info exists masterInfoArr]} {
      for {set i 0} {$i < [array size masterInfoArr]} {incr i} {
         set elem $masterInfoArr($i)
         puts $OUT "[split $elem ","]"
      }
   }

   puts $OUT "#Slave"
   if {[info exists slaveInfoArr]} {
      for {set i 0} {$i < [array size slaveInfoArr]} {incr i} {
         set elem $slaveInfoArr($i)
         puts $OUT "[split $elem ","]"
      }
   }

   puts $OUT "#Traffic"
   if {[info exists trafficInfoArr]} {
       for {set i 0} {$i < [array size trafficInfoArr]} {incr i} {
         set elem $trafficInfoArr($i)
         puts $OUT "[split $elem ","]"
      }
   }

   close $OUT
}

proc importNTF {{filename ""}} {
   global ntfToImportFile
   global qosArr

   if {$filename == ""} {
      set types {
         {"NTF Files"            .ntf}
      }   
      set filename [tk_getOpenFile -filetypes $types]
      if {![info exists filename]} {
         tk_messageBox -message "Please provide a valid filename" -type ok -icon error
         return
      }   
   }
   
   if {$filename == ""} {
      return
   }


	set F [open $filename r]
	set jsonFile [read $F]
	close $F
	set jsonData [json::json2dict $jsonFile]
	
   dict for {key values} $jsonData {
      myPuts "#$key, $values"
      if {$key == "nmu_list"} {
         set mcount 0
         for {set i 0} {$i < [llength $values]} {incr i} {
            dict for {k v} [lindex $values $i] {
               myPuts "nmu_list ==> $k, $v"
               switch $k {
                  "logical_name" {set logicalName $v}
                  "type" {set type $v}
                  "region" {set region $v}
                  "physical_location" {set physicalLocation $v}
                  "communication_type" {set communicationType $v}
                  "rate_limiter" {set rateLimiter $v}
               }
            }
            set mInfoArr($mcount) "$logicalName,$type,$region,$physicalLocation,$communicationType,$rateLimiter"
            incr mcount
         }
      }

      if {$key == "nsu_list"} {
         set scount 0
         for {set i 0} {$i < [llength $values]} {incr i} {
            dict for {k v} [lindex $values $i] {
               myPuts "nsu_list ==> $k, $v"
               switch $k {
                  "logical_name" {set logicalName $v}
                  "type" {set type $v}
                  "region" {set region $v}
                  "physical_location" {set physicalLocation $v}
                  "communication_type" {set communicationType $v}
               }
            }
            set sInfoArr($scount) "$logicalName,$type,$region,$physicalLocation,$communicationType"
            incr scount
         }
      }

      if {$key == "traffic_info"} {
         set tcount 0
         for {set i 0} {$i < [llength $values]} {incr i} {
            dict for {k v} [lindex $values $i] {
               myPuts "==> $k, $v"
               if {$k == "path"} {
                  for {set j 0} {$j < [llength $v]} {incr j} {
                     dict for {k1 v1} [lindex $v $j] {
                        myPuts "====> $k1, $v1"
                        if {$k1 == "nsu"} {
                           set v1 [lindex $v1 0]
                           for {set k 0} {$k < [llength $v1]} {incr k} {
                              if {[lindex $v1 $k] == "name"} {
                                 set slaveName [lindex $v1 [expr $k + 1]]
                              }
                           }
                        }
                        if {$k1 == "nmu"} {
                           set v1 [lindex $v1 0]
                           for {set k 0} {$k < [llength $v1]} {incr k} {
                              if {[lindex $v1 $k] == "name"} {
                                 set masterName [lindex $v1 [expr $k + 1]]
                              }
                           }
                        }
                     }
                  }
               }
               if {$k == "read_requirements"} {
                  set v [lindex $v 0]
                  for {set j 0} {$j < [llength $v]} {incr j} {
                     if {[lindex $v $j] == "latency"} {
                        set readLatency [lindex $v [expr $j + 1]]
                     }
                     if {[lindex $v $j] == "bandwidth"} {
                        set readBW [lindex $v [expr $j + 1]]
                     }
                     if {[lindex $v $j] == "traffic_class"} {
                        set readQos [lindex $v [expr $j + 1]]
                        foreach {qk qv} [array get qosArr] {
                           if {$readQos == $qv} {set readQos $qk}
                        }
                     }
                  }
               }
               if {$k == "write_requirements"} {
                  set v [lindex $v 0]
                  for {set j 0} {$j < [llength $v]} {incr j} {
                     if {[lindex $v $j] == "latency"} {
                        set writeLatency [lindex $v [expr $j + 1]]
                     }
                     if {[lindex $v $j] == "bandwidth"} {
                        set writeBW [lindex $v [expr $j + 1]]
                     }
                     if {[lindex $v $j] == "traffic_class"} {
                        set writeQos [lindex $v [expr $j + 1]]
                        foreach {qk qv} [array get qosArr] {
                           if {$writeQos == $qv} {set writeQos $qk}
                        }
                     }
                  }
               }
            }
            set tInfoArr($tcount) "$masterName,$slaveName,RW,$readQos,$readLatency,$readBW,$writeQos,$writeLatency,$writeBW"
            incr tcount
            myPuts "--------------------------------"
         }
      }
   }

   myParray mInfoArr
   myParray sInfoArr
   myParray tInfoArr
   set OUT [open $ntfToImportFile w]

   puts $OUT "#Master"
   for {set i 0} {$i < [array size mInfoArr]} {incr i} {
      set elem $mInfoArr($i)
      foreach {logicalName type region physicalLocation communicationType rateLimiter} [split $elem ","] {break}
      if {$physicalLocation == ""} {set physicalLocation "Unassigned"}
      puts $OUT "$logicalName $type $physicalLocation"
   }

   puts $OUT "#Slave"
   for {set i 0} {$i < [array size sInfoArr]} {incr i} {
      set elem $sInfoArr($i)
      foreach {logicalName type region physicalLocation communicationType} [split $elem ","] {break}
      if {$physicalLocation == ""} {set physicalLocation "Unassigned"}
      puts $OUT "$logicalName $type $physicalLocation"
   }

   puts $OUT "#Traffic"
   for {set i 0} {$i < [array size tInfoArr]} {incr i} {
      set elem $tInfoArr($i)
      puts $OUT "[split $elem ","]"
   }

   close $OUT

   importTrafficAndQos $ntfToImportFile
}

proc importTrafficAndQos {{filename ""}} {
   global masterInfoArr
   global slaveInfoArr
   global trafficInfoArr
   global netlistFile

   if {$filename == ""} {
      set types {
         {"All files"            *}
      }   
      set filename [tk_getOpenFile -filetypes $types]
      if {![info exists filename]} {
         tk_messageBox -message "Please provide a valid filename" -type ok -icon error
         return
      }
   }
   
   if {$filename == ""} {
      return
   }

   if {[info exists masterInfoArr]} {array unset masterInfoArr}
   if {[info exists slaveInfoArr]} {array unset slaveInfoArr}
   if {[info exists trafficInfoArr]} {array unset trafficInfoArr}
   
   set netlistFile $filename
   set F [open $filename r]
   while {[gets $F line] >= 0} {
      if {[regexp {^\s*$} $line]} continue 
      regsub -all {^\s+} $line "" line
      regsub -all {\s+} $line " " line
      if {[regexp {#Master} $line]} {
         set mcount 0
         while {[gets $F line] >= 0} {
            if {[regexp {#} $line]} { break }
            if {[regexp {^\s*$} $line]} continue
            set masterInfoArr($mcount) "[lindex $line 0],[lindex $line 1],[lindex $line 2]"
            incr mcount
         }
      }
      if {[regexp {#Slave} $line]} {
         set scount 0
         while {[gets $F line] >= 0} {
            if {[regexp {#} $line]} { break }
            if {[regexp {^\s*$} $line]} continue 
            set slaveInfoArr($scount) "[lindex $line 0],[lindex $line 1],[lindex $line 2]"
            incr scount
         }
      }
      if {[regexp {#Traffic} $line]} {
         set tcount 0
         while {[gets $F line] >= 0} {
            if {[regexp {#} $line]} { break }
            set mName [lindex $line 0]
            set sName [lindex $line 1]
            set transType [lindex $line 2]
            set readQos [lindex $line 3]
            set readLat [lindex $line 4]
            set readBW [lindex $line 5]
            set writeQos [lindex $line 6]
            set writeLat [lindex $line 7]
            set writeBW [lindex $line 8]
            set trafficInfoArr($tcount) "$mName,$sName,$transType,$readQos,$readLat,$readBW,$writeQos,$writeLat,$writeBW"
            incr tcount
         }
      }
   }
   close $F

   CreateTrafficGui 1
}
#------------------------------#

# Canvas procs
    #--------------------------------------------------------
    #
    #  zoomMark
    #
    #  Mark the first (x,y) coordinate for zooming.
    #
    #--------------------------------------------------------
    proc zoomMark {c x y} {
        global zoomArea
        set zoomArea(x0) [$c canvasx $x]
        set zoomArea(y0) [$c canvasy $y]
        $c create rectangle $x $y $x $y -outline yellow -tag zoomArea
    }

    #--------------------------------------------------------
    #
    #  zoomStroke
    #
    #  Zoom in to the area selected by itemMark and
    #  itemStroke.
    #
    #--------------------------------------------------------
    proc zoomStroke {c x y} {
        global zoomArea
        $c delete zoomText
        set zoomArea(x1) [$c canvasx $x]
        set zoomArea(y1) [$c canvasy $y]
        $c coords zoomArea $zoomArea(x0) $zoomArea(y0) $zoomArea(x1) $zoomArea(y1)
        if {($zoomArea(x1) >= $zoomArea(x0)) && ($zoomArea(y1) >= $zoomArea(y0))} {
           $c create text $zoomArea(x1) $zoomArea(y1) -text "zoom-in" -fill white -tag zoomText
        } else {
           $c create text $zoomArea(x1) $zoomArea(y1) -text "zoom-out" -fill white -tag zoomText
        }
    }

    #--------------------------------------------------------
    #
    #  zoomArea
    #
    #  Zoom in to the area selected by itemMark and
    #  itemStroke.
    #
    #--------------------------------------------------------
    proc zoomArea {c x y} {
        global zoomArea

        #--------------------------------------------------------
        #  Get the final coordinates.
        #  Remove area selection rectangle
        #--------------------------------------------------------
        set zoomArea(x1) [$c canvasx $x]
        set zoomArea(y1) [$c canvasy $y]
        $c delete zoomArea
        $c delete zoomText

        #--------------------------------------------------------
        #  Check for zero-size area
        #--------------------------------------------------------
        if {($zoomArea(x0)==$zoomArea(x1)) || ($zoomArea(y0)==$zoomArea(y1))} {
            return
        }

        #--------------------------------------------------------
        #  Determine size and center of selected area
        #--------------------------------------------------------
        set areaxlength [expr {abs($zoomArea(x1)-$zoomArea(x0))}]
        set areaylength [expr {abs($zoomArea(y1)-$zoomArea(y0))}]
        set xcenter [expr {($zoomArea(x0)+$zoomArea(x1))/2.0}]
        set ycenter [expr {($zoomArea(y0)+$zoomArea(y1))/2.0}]

        #--------------------------------------------------------
        #  Determine size of current window view
        #  Note that canvas scaling always changes the coordinates
        #  into pixel coordinates, so the size of the current
        #  viewport is always the canvas size in pixels.
        #  Since the canvas may have been resized, ask the
        #  window manager for the canvas dimensions.
        #--------------------------------------------------------
        set winxlength [winfo width $c]
        set winylength [winfo height $c]

        #--------------------------------------------------------
        #  Calculate scale factors, and choose smaller
        #--------------------------------------------------------
        if {([expr $zoomArea(x1)-$zoomArea(x0)] > 0) && ([expr $zoomArea(y1)-$zoomArea(y0)] > 0)} {
           set xscale [expr {$winxlength/$areaxlength}]
           set yscale [expr {$winylength/$areaylength}]
        } else {
           set xscale [expr {$areaxlength/$winxlength}]
           set yscale [expr {$areaylength/$winylength}]
        }
        if { $xscale > $yscale } {
            set factor $yscale
        } else {
            set factor $xscale
        }

        #--------------------------------------------------------
        #  Perform zoom operation
        #--------------------------------------------------------
        zoom $c $factor $xcenter $ycenter $winxlength $winylength
    }


    #--------------------------------------------------------
    #
    #  zoom
    #
    #  Zoom the canvas view, based on scale factor 
    #  and centerpoint and size of new viewport.  
    #  If the center point is not provided, zoom 
    #  in/out on the current window center point.
    #
    #  This procedure uses the canvas scale function to
    #  change coordinates of all objects in the canvas.
    #
    #--------------------------------------------------------
    proc zoom { canvas factor \
            {xcenter ""} {ycenter ""} \
            {winxlength ""} {winylength ""} } {

        #--------------------------------------------------------
        #  If (xcenter,ycenter) were not supplied,
        #  get the canvas coordinates of the center
        #  of the current view.  Note that canvas
        #  size may have changed, so ask the window 
        #  manager for its size
        #--------------------------------------------------------
        set winxlength [winfo width $canvas]; # Always calculate [ljl]
        set winylength [winfo height $canvas]
        if { [string equal $xcenter ""] } {
            set xcenter [$canvas canvasx [expr {$winxlength/2.0}]]
            set ycenter [$canvas canvasy [expr {$winylength/2.0}]]
        }

        #--------------------------------------------------------
        #  Scale all objects in the canvas
        #  Adjust our viewport center point
        #--------------------------------------------------------
        $canvas scale all 0 0 $factor $factor
        set xcenter [expr {$xcenter * $factor}]
        set ycenter [expr {$ycenter * $factor}]

        #--------------------------------------------------------
        #  Get the size of all the items on the canvas.
        #
        #  This is *really easy* using 
        #      $canvas bbox all
        #  but it is also wrong.  Non-scalable canvas
        #  items like text and windows now have a different
        #  relative size when compared to all the lines and
        #  rectangles that were uniformly scaled with the 
        #  [$canvas scale] command.  
        #
        #  It would be better to tag all scalable items,
        #  and make a single call to [bbox].
        #  Instead, we iterate through all canvas items and
        #  their coordinates to compute our own bbox.
        #--------------------------------------------------------
        set x0 1.0e30; set x1 -1.0e30 ;
        set y0 1.0e30; set y1 -1.0e30 ;
        foreach item [$canvas find all] {
            switch -exact [$canvas type $item] {
                "arc" -
                "line" -
                "oval" -
                "polygon" -
                "rectangle" {
                    set coords [$canvas coords $item]
                    foreach {x y} $coords {
                        if { $x < $x0 } {set x0 $x}
                        if { $x > $x1 } {set x1 $x}
                        if { $y < $y0 } {set y0 $y}
                        if { $y > $y0 } {set y1 $y}
                    }
                }
            }
        }

        #--------------------------------------------------------
        #  Now figure the size of the bounding box
        #--------------------------------------------------------
        set xlength [expr {$x1-$x0}]
        set ylength [expr {$y1-$y0}]

        #--------------------------------------------------------
        #  But ... if we set the scrollregion and xview/yview 
        #  based on only the scalable items, then it is not 
        #  possible to zoom in on one of the non-scalable items
        #  that is outside of the boundary of the scalable items.
        #
        #  So expand the [bbox] of scaled items until it is
        #  larger than [bbox all], but do so uniformly.
        #--------------------------------------------------------
        foreach {ax0 ay0 ax1 ay1} [$canvas bbox all] {break}

        while { ($ax0<$x0) || ($ay0<$y0) || ($ax1>$x1) || ($ay1>$y1) } {
            # triple the scalable area size
            set x0 [expr {$x0-$xlength}]
            set x1 [expr {$x1+$xlength}]
            set y0 [expr {$y0-$ylength}]
            set y1 [expr {$y1+$ylength}]
            set xlength [expr {$xlength*3.0}]
            set ylength [expr {$ylength*3.0}]
        }

        #--------------------------------------------------------
        #  Now that we've finally got a region defined with
        #  the proper aspect ratio (of only the scalable items)
        #  but large enough to include all items, we can compute
        #  the xview/yview fractions and set our new viewport
        #  correctly.
        #--------------------------------------------------------
        set newxleft [expr {($xcenter-$x0-($winxlength/2.0))/$xlength}]
        set newytop  [expr {($ycenter-$y0-($winylength/2.0))/$ylength}]
        $canvas configure -scrollregion [list $x0 $y0 $x1 $y1]
        $canvas xview moveto $newxleft 
        $canvas yview moveto $newytop 

        #--------------------------------------------------------
        #  Change the scroll region one last time, to fit the
        #  items on the canvas.
        #--------------------------------------------------------
        $canvas configure -scrollregion [$canvas bbox all]
    }
#------------------------------#

# Generic Canvas Zoom procs
proc getRubberBandToScreenRatio {c} {
   #This function is used while zooming in/out with mouse.
   #It returned number is a multiple of 0.5
   global rubberBand

   set winxlength [winfo width $c]
   set winylength [winfo height $c]
   set lengthRubberBand [expr sqrt(pow(($rubberBand(urx) - $rubberBand(llx)),2) + pow(($rubberBand(ury) - $rubberBand(lly)),2))]
   set lengthScreen [expr sqrt(pow($winxlength,2) + pow($winylength,2))]
   set ratio [format %.1f [expr 0.5 + (int((int(($lengthRubberBand * 100)/double($lengthScreen)) / 10.0)) * 0.5)]]
   return $ratio
}

proc zoomStart {c x y} {
   focus $c
   global rubberBand 
   global rubberBandColor 
   set rubberBand(llx) [$c canvasx $x]
   set rubberBand(lly) [$c canvasy $y]
   $c create line $x $y $x $y -fill $rubberBandColor -tag rubberBandLine 
   $c create rectangle $x $y $x $y -outline $rubberBandColor -tag rubberBandRect 
}

proc zoomMove {c x y} {
   global rubberBand 
   global rubberBandColor 
   $c delete zoomText
   set rubberBand(urx) [$c canvasx $x]
   set rubberBand(ury) [$c canvasy $y]
   set winxlength [winfo width $c]
   set winylength [winfo height $c]

   #Clip the rubberband to stay within screen
   if {$rubberBand(urx) > $winxlength} {set rubberBand(urx) $winxlength}
   if {$rubberBand(ury) > $winylength} {set rubberBand(ury) $winylength}
   if {$rubberBand(urx) < 0} {set rubberBand(urx) 0}
   if {$rubberBand(ury) < 0} {set rubberBand(ury) 0}

   #Check for different zoom modes
   if {($rubberBand(urx) >= $rubberBand(llx)) && ($rubberBand(ury) >= $rubberBand(lly))} {
      #Zoom-Area
      $c create text $rubberBand(urx) $rubberBand(ury) -text "Zoom-Area" -tag zoomText -fill $rubberBandColor
      $c coords rubberBandRect $rubberBand(llx) $rubberBand(lly) $rubberBand(urx) $rubberBand(ury)
      $c coords rubberBandLine $rubberBand(llx) $rubberBand(lly) $rubberBand(llx) $rubberBand(lly)
   } elseif {($rubberBand(urx) < $rubberBand(llx)) && ($rubberBand(ury) < $rubberBand(lly))} {
      #Zoom-Fit
      $c create text $rubberBand(urx) $rubberBand(ury) -text "Zoom-Fit" -tag zoomText -fill $rubberBandColor
      $c coords rubberBandLine $rubberBand(llx) $rubberBand(lly) $rubberBand(urx) $rubberBand(ury)
      $c coords rubberBandRect $rubberBand(llx) $rubberBand(lly) $rubberBand(llx) $rubberBand(lly)
   } elseif {($rubberBand(urx) >= $rubberBand(llx)) && ($rubberBand(ury) < $rubberBand(lly))} {
      #Zoom-Out Ratio
      set ratio [getRubberBandToScreenRatio $c] 
      $c create text $rubberBand(urx) $rubberBand(ury) -text "Zoom-Out -$ratio" -tag zoomText -fill $rubberBandColor
      $c coords rubberBandLine $rubberBand(llx) $rubberBand(lly) $rubberBand(urx) $rubberBand(ury)
      $c coords rubberBandRect $rubberBand(llx) $rubberBand(lly) $rubberBand(llx) $rubberBand(lly)
   } elseif {($rubberBand(urx) < $rubberBand(llx)) && ($rubberBand(ury) >= $rubberBand(lly))} {
      #Zoom-In Ratio
      set ratio [getRubberBandToScreenRatio $c] 
      $c create text $rubberBand(urx) $rubberBand(ury) -text "Zoom-In +$ratio" -tag zoomText -fill $rubberBandColor
      $c coords rubberBandLine $rubberBand(llx) $rubberBand(lly) $rubberBand(urx) $rubberBand(ury)
      $c coords rubberBandRect $rubberBand(llx) $rubberBand(lly) $rubberBand(llx) $rubberBand(lly)
   }
}

proc zoomEnd {c x y} {
   global rubberBand 
   global lens

   set rubberBand(urx) [$c canvasx $x]
   set rubberBand(ury) [$c canvasy $y]
  
   #Delete zoom text and rubberbands
   $c delete zoomText
   $c delete rubberBandRect
   $c delete rubberBandLine

   #Return if rubberband is too small size
   if {[expr abs($rubberBand(llx) - $rubberBand(urx))] <= 10 || [expr abs($rubberBand(lly) - $rubberBand(ury))] <= 10} {
       return
   }
  
   #Clip the rubberband to stay within screen
   set winxlength [winfo width $c]
   set winylength [winfo height $c]

   if {$rubberBand(urx) > $winxlength} {set rubberBand(urx) $winxlength}
   if {$rubberBand(ury) > $winylength} {set rubberBand(ury) $winylength}
   if {$rubberBand(urx) < 0} {set rubberBand(urx) 0}
   if {$rubberBand(ury) < 0} {set rubberBand(ury) 0}

   #Check for different zoom modes
   if {($rubberBand(urx) >= $rubberBand(llx)) && ($rubberBand(ury) >= $rubberBand(lly))} { 
      #Zoom-Area
      #Note: below we have flipped len's lly and ury computation
      foreach {newLensllx newLensury} [translateScreenToDB [list $rubberBand(llx) $rubberBand(lly)]] {break}
      foreach {newLensurx newLenslly} [translateScreenToDB [list $rubberBand(urx) $rubberBand(ury)]] {break}
      set lens(llx) $newLensllx
      set lens(lly) $newLenslly
      set lens(urx) $newLensurx
      set lens(ury) $newLensury
   } elseif {($rubberBand(urx) < $rubberBand(llx)) && ($rubberBand(ury) < $rubberBand(lly))} {
      #Zoom-Fit
      if {[checkIsZoomFit]} {return}
      setZoomFitLens
   } elseif {($rubberBand(urx) >= $rubberBand(llx)) && ($rubberBand(ury) < $rubberBand(lly))} {
      #Zoom-Out Ratio
      if {[checkIsZoomFit]} {return}
      set ratio [expr [getRubberBandToScreenRatio $c] * 0.05]
      zoomByFactor "zoomout" $ratio
      if {[checkIsZoomFit]} {setZoomFitLens}
   } elseif {($rubberBand(urx) < $rubberBand(llx)) && ($rubberBand(ury) >= $rubberBand(lly))} {
      #Zoom-In Ratio
      set ratio [expr [getRubberBandToScreenRatio $c] * 0.05]
      zoomByFactor "zoomin" $ratio
   }

   redraw $c
}

proc zoomByFactor {mode ratio} {
   global lens
   
   set lensXLength [expr $lens(urx) - $lens(llx)]
   set lensYLength [expr $lens(ury) - $lens(lly)]
   if {$lensXLength <= $lensYLength} {
      set add [expr $lensXLength * $ratio]
   } else {
      set add [expr $lensYLength * $ratio]
   }
   
   if {$mode == "zoomout"} {
      set lens(llx) [expr $lens(llx) - $add] 
      set lens(lly) [expr $lens(lly) - $add] 
      set lens(urx) [expr $lens(urx) + $add] 
      set lens(ury) [expr $lens(ury) + $add] 
   } elseif {$mode == "zoomin"} {
      set lens(llx) [expr $lens(llx) + $add] 
      set lens(lly) [expr $lens(lly) + $add] 
      set lens(urx) [expr $lens(urx) - $add] 
      set lens(ury) [expr $lens(ury) - $add] 
   }
}

proc zoomOutByFactor {} {
   global c
   if {[checkIsZoomFit]} {return}
   zoomByFactor "zoomout" 0.05
   redraw $c
}

proc zoomInByFactor {} {
   global c
   zoomByFactor "zoomin" 0.05
   redraw $c
}

proc checkIsZoomFit {} {
   global lens
   if {$lens(llx) <= $lens(topllx) && $lens(lly) <= $lens(toplly) && $lens(urx) >= $lens(topurx) && $lens(ury) >= $lens(topury)} {
      return 1
   } else {
      return 0
   }
}

proc setZoomFitLens {} {
   global lens
   set lens(llx) $lens(topllx)
   set lens(lly) $lens(toplly)
   set lens(urx) $lens(topurx)
   set lens(ury) $lens(topury)
   myPuts "After setZoomFitLens Lens = $lens(llx) $lens(lly) $lens(urx) $lens(ury)"
}

proc zoomFit {} {
   global c
   if {[checkIsZoomFit]} {return}
   setZoomFitLens
   redraw $c
}

proc moveUp {c} {
   if {[checkIsZoomFit]} {return}
   global lens
   global globalZoomFactor
   global panIncr
   global lensTolerance
   if {[expr abs($lens(ury) - $lens(topury))] < $lensTolerance} {return}
   if {$lens(lly) <= $lens(toplly) && $lens(ury) >= $lens(topury)} {return}
   set lens(lly) [expr ($lens(lly) + ($panIncr * $globalZoomFactor))]
   set lens(ury) [expr ($lens(ury) + ($panIncr * $globalZoomFactor))]
   redraw $c
}

proc moveDown {c} {
   if {[checkIsZoomFit]} {return}
   global lens
   global globalZoomFactor
   global panIncr
   global lensTolerance
   if {[expr abs($lens(lly) - $lens(toplly))] < $lensTolerance} {return}
   if {$lens(lly) <= $lens(toplly) && $lens(ury) >= $lens(topury)} {return}
   set lens(lly) [expr ($lens(lly) - ($panIncr * $globalZoomFactor))]
   set lens(ury) [expr ($lens(ury) - ($panIncr * $globalZoomFactor))]
   redraw $c
}

proc moveLeft {c} {
   if {[checkIsZoomFit]} {return}
   global lens
   global globalZoomFactor
   global panIncr
   global lensTolerance
   if {[expr abs($lens(llx) - $lens(topllx))] < $lensTolerance} {return}
   if {$lens(llx) <= $lens(topllx) && $lens(urx) >= $lens(topurx)} {return}
   set lens(llx) [expr ($lens(llx) - ($panIncr * $globalZoomFactor))]
   set lens(urx) [expr ($lens(urx) - ($panIncr * $globalZoomFactor))]
   redraw $c
}

proc moveRight {c} {
   if {[checkIsZoomFit]} {return}
   global lens
   global globalZoomFactor
   global panIncr
   global lensTolerance
   if {[expr abs($lens(urx) - $lens(topurx))] < $lensTolerance} {return}
   if {$lens(llx) <= $lens(topllx) && $lens(urx) >= $lens(topurx)} {return}
   set lens(llx) [expr ($lens(llx) + ($panIncr * $globalZoomFactor))]
   set lens(urx) [expr ($lens(urx) + ($panIncr * $globalZoomFactor))]
   redraw $c
}


proc updateGlobalZoomFactor {c} {
   global globalZoomFactor
   global lens
   set winxlength [winfo width $c]
   set winylength [winfo height $c]

   set xfactor [expr ($lens(urx) - $lens(llx))/double($winxlength)]
   set yfactor [expr ($lens(ury) - $lens(lly))/double($winylength)]

   myPuts "xfactor = $xfactor, yfactor = $yfactor, %diff = [expr ($xfactor - $yfactor) * (100/double($xfactor))]"

   if {$xfactor > $yfactor} {
      set globalZoomFactor $xfactor
   } else {
      set globalZoomFactor $yfactor
   }
}

proc preserveLensAspectRatio {c} {
   global lens
   if {[checkIsZoomFit]} {setZoomFitLens}
   set winxlength [winfo width $c]
   set winylength [winfo height $c]

   set lensxlength [expr $lens(urx) - $lens(llx)]
   set lensylength [expr $lens(ury) - $lens(lly)]

   set aspectLens [expr $lensylength/double($lensxlength)]
   set aspectScreen [expr $winylength/double($winxlength)]

   if {$aspectScreen > $aspectLens} {
      set excess [expr ($lens(ury) - $lens(lly)) * ($aspectScreen/double($aspectLens) - 1)]
      set lens(ury) [expr $lens(ury) + ($excess/2.0)]
      set lens(lly) [expr $lens(lly) - ($excess/2.0)]
   } else {
      set excess [expr ($lens(urx) - $lens(llx)) * ($aspectLens/double($aspectScreen) - 1)]
      set lens(urx) [expr $lens(urx) + ($excess/2.0)]
      set lens(llx) [expr $lens(llx) - ($excess/2.0)]
   }
   myPuts "After preserveLensAspectRatio Lens = $lens(llx) $lens(lly) $lens(urx) $lens(ury)"
}

proc clipLens {} {
   global lens

   set lensxlength [expr abs($lens(urx) - $lens(llx))]
   set lensylength [expr abs($lens(ury) - $lens(lly))]
   set toplensxlength [expr abs($lens(topurx) - $lens(topllx))]
   set toplensylength [expr abs($lens(topury) - $lens(toplly))]

   myPuts "lensxlength = $lensxlength, lensylength = $lensylength, toplensxlength = $toplensxlength, toplensylength = $toplensylength" 
   if {($lensxlength >= $toplensxlength) || ($lensylength >= $toplensylength)} {
      if {($lensxlength >= $toplensxlength)} {
         myPuts "case 5"
         set off [expr abs(($lens(urx) - $lens(llx)) - ($lens(topurx) - $lens(topllx)))/2.0]
         set lens(llx) [expr $lens(topllx) - $off]
         set lens(urx) [expr $lens(topurx) + $off]
      }
      if {($lensylength >= $toplensylength)} {
         myPuts "case 6"
         set off [expr abs(($lens(ury) - $lens(lly)) - ($lens(topury) - $lens(toplly)))/2.0]
         set lens(lly) [expr $lens(toplly) - $off]
         set lens(ury) [expr $lens(topury) + $off]
      }
   }

   if {($lens(llx) < $lens(topllx)) && ($lens(urx) < $lens(topurx))} {
      myPuts "case 1"
      set off [expr abs($lens(llx) - $lens(topllx))]
      set lens(llx) $lens(topllx)
      set lens(urx) [expr $lens(urx) + $off]
   }
   if {($lens(lly) < $lens(toplly)) && ($lens(ury) < $lens(topury))} {
      myPuts "case 2"
      set off [expr abs($lens(lly) - $lens(toplly))]
      set lens(lly) $lens(toplly)
      set lens(ury) [expr $lens(ury) + $off]
   }
   if {($lens(urx) > $lens(topurx)) && ($lens(llx) > $lens(topllx))} {
      myPuts "case 3"
      set off [expr abs($lens(urx) - $lens(topurx))]
      set lens(urx) $lens(topurx)
      set lens(llx) [expr $lens(llx) - $off]
   }
   if {($lens(ury) > $lens(topury)) && ($lens(lly) > $lens(toplly))} {
      myPuts "case 4"
      set off [expr abs($lens(ury) - $lens(topury))]
      set lens(ury) $lens(topury)
      set lens(lly) [expr $lens(lly) - $off]
   }
   myPuts "After clipLens Lens = $lens(llx) $lens(lly) $lens(urx) $lens(ury)"
}

proc redraw {c} {
   preserveLensAspectRatio $c
   clipLens
   updateGlobalZoomFactor $c
   drawGeometries $c
   ShowMap
   update idletasks
}

proc isRectIntersectLens {dbCoords} {
   global lens
   foreach {rllx rlly rurx rury} $dbCoords {break}
   if {$rllx > $rurx} {swap rllx rurx}
   if {$rlly > $rury} {swap rlly rury}
   if {($lens(urx) < $rllx) || ($rurx < $lens(llx)) || ($lens(ury) < $rlly) || ($rury < $lens(lly))} {
      return 0 
   } else {
      return 1 
   }
}

proc isLinesIntersectLens {dbCoords} {
   set intersects 0
   for {set i 0} {$i < [expr [llength $dbCoords] - 3]} {incr i 2} {
      set dbllx [lindex $dbCoords $i]
      set dblly [lindex $dbCoords [expr $i + 1]]
      set dburx [lindex $dbCoords [expr $i + 2]]
      set dbury [lindex $dbCoords [expr $i + 3]]
      set r [list $dbllx $dblly $dburx $dbury]
      if {[isRectIntersectLens $r]} {set intersects 1}
   }
   return $intersects
}

proc isPointInsideLens {dbCoords} {
   global lens
   foreach {rllx rlly} $dbCoords {break}
   if {($lens(urx) < $rllx) || ($rllx < $lens(llx)) || ($lens(ury) < $rlly) || ($rlly < $lens(lly))} {
      return 0 
   } else {
      return 1 
   }
}

proc swap {p q} {
   upvar 1 $p a
   upvar 1 $q b
   set temp $a
   set a $b
   set b $temp
}

proc translateDBToScreen {dbPoint} {
   global lens
   global globalZoomFactor
   global c

   foreach {dbx dby} $dbPoint {break}
   set winylength [winfo height $c]
   set screenx [expr ($dbx - $lens(llx))/double($globalZoomFactor)]
   set screeny [expr $winylength - (($dby - $lens(lly))/double($globalZoomFactor))]
   return [list $screenx $screeny]
}


proc translateScreenToDB {screenPoint} {
   global lens
   global globalZoomFactor
   global c
   foreach {screenx screeny} $screenPoint {break}
   set winylength [winfo height $c]
   set dbx [expr ($screenx * $globalZoomFactor) + $lens(llx)]
   set dby [expr (($winylength - $screeny) * $globalZoomFactor) + $lens(lly)]
   return [list $dbx $dby]
}



##########################################################
##########################################################
##########################################################
##########################################################
##########################################################
##########################################################
array set old_colors {
   0 "#E2FFF8 teal"
   1 "#FF00FF pink"
   2 "#0080FF blue"
   3 "#00FF00 green"
   4 "#848484 gray"
   5 "#FFFF00 yellow"
   6 "#00FFFF lightblue"
   7 "#FFBF00 orange"
   8 "#21610B darkgreen"
   9 "#FF0000 red"
   10 "#8A4B08 brown"
   11 "#8A0886 purple"
}

array set colors {
   0 "maroon"
   1 "deep pink"
   2 "dodger blue"
   3 "SpringGreen2"
   4 "gray79"
   5 "yellow"
   6 "turquoise1"
   7 "orange"
   8 "green4"
   9 "IndianRed1"
   10 "firebrick4"
   11 "khaki3"
}

array set qosArr {
   "LL" "LOW_LATENCY"
   "ISO" "ISOCHRONOUS"
   "BE" "BEST_EFFORT"
}

array set blockTypeMapArr {
   "SWITCH" "noc_switch"
   "MASTER" "noc_nmu"
   "SLAVE" "noc_nsu"
   "DDRC" "ddr_controller"
}

array set compTypeMapArr {
   "pl,NMU" "PL_NMU"
   "pl,NSU" "PL_NSU"
}

array set compTypeToBlockTypeArr {
   "NPS" "SWITCH"
   "PS_NCI" "MASTER"
   "PS_CCI" "MASTER"
   "PMC_NMU" "MASTER"
   "PMC_NSU" "SLAVE"
   "PS_NSU" "SLAVE"
   "PL_NMU" "MASTER"
   "PL_NSU" "SLAVE"
   "ME_NMU" "MASTER"
   "ME_NSU" "SLAVE"
   "DDRC" "SLAVE"
   "PS_RPU" "MASTER"
   "PCIE_NMU" "MASTER"
   "PCIE_NSU" "SLAVE"
}


proc getColorForNet {n} {
   global colors
   set index [expr $n % [array size colors]]
   return $colors($index)
}


proc createDefaultHeatMapGradient {} {
   global initialGradientColors
   #Contents: r,g,b,value
   set initialGradientColors(0) [list 0 0 1 0.0]
   set initialGradientColors(1) [list 0 1 1 0.25]
   set initialGradientColors(2) [list 0 1 0 0.5]
   set initialGradientColors(3) [list 1 1 0 0.75]
   set initialGradientColors(4) [list 1 0 0 1.0]
}

proc getColorGradientAtValue {value} {
   global initialGradientColors
   if {[array size initialGradientColors] ==0} {
      return
   }

   for {set i 0} {$i < [array size initialGradientColors]} {incr i} {
      set currC $initialGradientColors($i)
      foreach {currCr currCg currCb currCval} $currC {break}
      if {$value < $currCval} {
         set prevC $initialGradientColors([expr max(0,$i-1)])
         foreach {prevCr prevCg prevCb prevCval} $prevC {break}
         set valueDiff [expr ($prevCval - $currCval)]
         set fractBetween [expr ($valueDiff == 0) ? 0 : ($value - $currCval) / $valueDiff]
         set red [expr int(ceil((($prevCr - $currCr)*$fractBetween + $currCr) * 255))]
         set green [expr int(ceil((($prevCg - $currCg)*$fractBetween + $currCg) * 255))]
         set blue [expr int(ceil((($prevCb - $currCb)*$fractBetween + $currCb) * 255))]
         set newcolor [format "#%02x%02x%02x" $red $green $blue]
         return $newcolor
      }
   }

   set size [array size initialGradientColors]
   set lastC $initialGradientColors([expr $size - 1])
   foreach {lastCr lastCg lastCb lastCval} $lastC {break}
   set red [expr int(ceil($lastCr * 255))]
   set green [expr int(ceil($lastCg * 255))]
   set blue [expr int(ceil($lastCb * 255))]
   set newcolor [format "#%02x%02x%02x" $red $green $blue]
   return $newcolor
}

proc createColorGradientsForMaps {} {
   global mapGradientColors
   global passFailMapGradientColors
   global numColorGradients

   createDefaultHeatMapGradient

   #For index "-1", set a default color
   set mapGradientColors(-1) "#000000"
   for {set i 0} {$i < $numColorGradients} {incr i} {
      set val [format %.2f [expr $i * (1/double($numColorGradients - 1))]]
      set mapGradientColors($i) [getColorGradientAtValue $val]
   }
   myParray mapGradientColors

   set passFailMapGradientColors(-1) "black"
   set passFailMapGradientColors(0) "green"
   set passFailMapGradientColors(1) "orange"
   set passFailMapGradientColors(2) "red"
}


proc showHeatMapSettingsGui {} {
   global heatMapSettingsGui

   wm deiconify $heatMapSettingsGui
   raise $heatMapSettingsGui
}

proc createHeatMapSettingsGui {} {
   global heatMapSettingsGui
   global mapGradientColors
   global passFailMapGradientColors
   global heatMapSettings

   set heatMapSettings(utilRange0) 1
   set heatMapSettings(utilRange1) 1
   set heatMapSettings(utilRange2) 1
   set heatMapSettings(utilRange3) 1
   set heatMapSettings(utilRange4) 1
   set heatMapSettings(bwRange0) 1
   set heatMapSettings(bwRange1) 1
   set heatMapSettings(bwRange2) 1

   set heatMapSettingsGui [toplevel .heatMapSettingsGui]
   wm title $heatMapSettingsGui "Simulation Map Settings"
   wm geometry $heatMapSettingsGui +5+5
   wm attributes $heatMapSettingsGui -topmost 1
   wm protocol $heatMapSettingsGui WM_DELETE_WINDOW {saveHeatMapSettingsAndQuit}
   wm withdraw $heatMapSettingsGui

   set utilLbf [labelframe $heatMapSettingsGui.utilLbf -text "Utilization %"]
   set bwLbf [labelframe $heatMapSettingsGui.bwLbf -text "Bandwidth (achvd/reqd)"]
   ttk::separator $heatMapSettingsGui.s -orient horizontal
   
   #ok/cancel buttons
   frame $heatMapSettingsGui.buttons
   button $heatMapSettingsGui.buttons.ok -text "Ok" -command "saveHeatMapSettingsAndQuit" 
   button $heatMapSettingsGui.buttons.cancel -text "Cancel" -command "restoreHeatMapSettingsAndQuit"
   grid $heatMapSettingsGui.buttons.ok -row 0 -column 0 
   grid $heatMapSettingsGui.buttons.cancel -row 0 -column 1 -padx 20

   #top level grid
   grid $utilLbf -row 0 -column 0 -padx 15 -pady 5 -sticky ns
   grid $bwLbf -row 0 -column 1 -padx 15 -pady 5 -sticky n
   grid $heatMapSettingsGui.s -row 1 -column 0 -pady 5 -columnspan 2 -sticky ew
   grid $heatMapSettingsGui.buttons -row 2 -column 0 -columnspan 2 

   #Utilization
   checkbutton $utilLbf.range0 -text "\[0 - 20\]" -variable utilRange0 -anchor w -command ""
   checkbutton $utilLbf.range1 -text "\(20 - 40\]" -variable utilRange1 -anchor w -command ""
   checkbutton $utilLbf.range2 -text "\(40 - 60\]" -variable utilRange2 -anchor w -command ""
   checkbutton $utilLbf.range3 -text "\(60 - 80\]" -variable utilRange3 -anchor w -command ""
   checkbutton $utilLbf.range4 -text "\(80 - 100\]" -variable utilRange4 -anchor w -command ""
   button $utilLbf.cb0 -text "" -command "" -bg $mapGradientColors(0) -disabledforeground $mapGradientColors(0)
   button $utilLbf.cb1 -text "" -command "" -bg $mapGradientColors(1) -disabledforeground $mapGradientColors(1)
   button $utilLbf.cb2 -text "" -command "" -bg $mapGradientColors(2) -disabledforeground $mapGradientColors(2)
   button $utilLbf.cb3 -text "" -command "" -bg $mapGradientColors(3) -disabledforeground $mapGradientColors(3)
   button $utilLbf.cb4 -text "" -command "" -bg $mapGradientColors(4) -disabledforeground $mapGradientColors(4)
   if {$heatMapSettings(utilRange0) == 1} {$utilLbf.range0 select} else {$utilLbf.range0 deselect}
   if {$heatMapSettings(utilRange1) == 1} {$utilLbf.range1 select} else {$utilLbf.range1 deselect}
   if {$heatMapSettings(utilRange2) == 1} {$utilLbf.range2 select} else {$utilLbf.range2 deselect}
   if {$heatMapSettings(utilRange3) == 1} {$utilLbf.range3 select} else {$utilLbf.range3 deselect}
   if {$heatMapSettings(utilRange4) == 1} {$utilLbf.range4 select} else {$utilLbf.range4 deselect}
   $utilLbf.cb0 configure -state disabled
   $utilLbf.cb1 configure -state disabled
   $utilLbf.cb2 configure -state disabled
   $utilLbf.cb3 configure -state disabled
   $utilLbf.cb4 configure -state disabled

   grid $utilLbf.range4 -row 0 -column 0 -sticky w
   grid $utilLbf.cb4 -row 0 -column 1
   grid $utilLbf.range3 -row 1 -column 0 -sticky w
   grid $utilLbf.cb3 -row 1 -column 1
   grid $utilLbf.range2 -row 2 -column 0 -sticky w
   grid $utilLbf.cb2 -row 2 -column 1
   grid $utilLbf.range1 -row 3 -column 0 -sticky w
   grid $utilLbf.cb1 -row 3 -column 1
   grid $utilLbf.range0 -row 4 -column 0 -sticky w
   grid $utilLbf.cb0 -row 4 -column 1

   #Bandwidth
   checkbutton $bwLbf.range0 -text ">= 1" -variable bwRange0 -anchor w -command ""
   checkbutton $bwLbf.range1 -text ">= 0.8 && < 1" -variable bwRange1 -anchor w -command ""
   checkbutton $bwLbf.range2 -text "< 0.8" -variable bwRange2 -anchor w -command ""
   button $bwLbf.cb0 -text "" -command "" -bg $passFailMapGradientColors(0) -disabledforeground $passFailMapGradientColors(0)
   button $bwLbf.cb1 -text "" -command "" -bg $passFailMapGradientColors(1) -disabledforeground $passFailMapGradientColors(1)
   button $bwLbf.cb2 -text "" -command "" -bg $passFailMapGradientColors(2) -disabledforeground $passFailMapGradientColors(2)
   if {$heatMapSettings(bwRange0) == 1} {$bwLbf.range0 select} else {$bwLbf.range0 deselect}
   if {$heatMapSettings(bwRange1) == 1} {$bwLbf.range1 select} else {$bwLbf.range1 deselect}
   if {$heatMapSettings(bwRange2) == 1} {$bwLbf.range2 select} else {$bwLbf.range2 deselect}
   $bwLbf.cb0 configure -state disabled
   $bwLbf.cb1 configure -state disabled
   $bwLbf.cb2 configure -state disabled

   grid $bwLbf.range2 -row 0 -column 0 -sticky w
   grid $bwLbf.cb2 -row 0 -column 1 -sticky e
   grid $bwLbf.range1 -row 1 -column 0 -sticky w
   grid $bwLbf.cb1 -row 1 -column 1 -sticky e
   grid $bwLbf.range0 -row 2 -column 0 -sticky w
   grid $bwLbf.cb0 -row 2 -column 1 -sticky e
}

proc saveHeatMapSettingsAndQuit {} {
   global heatMapSettings
   global heatMapSettingsGui

   global utilRange0
   global utilRange1
   global utilRange2
   global utilRange3
   global utilRange4
   global bwRange0
   global bwRange1
   global bwRange2

   set heatMapSettings(utilRange0) $utilRange0
   set heatMapSettings(utilRange1) $utilRange1
   set heatMapSettings(utilRange2) $utilRange2
   set heatMapSettings(utilRange3) $utilRange3
   set heatMapSettings(utilRange4) $utilRange4
   set heatMapSettings(bwRange0) $bwRange0
   set heatMapSettings(bwRange1) $bwRange1
   set heatMapSettings(bwRange2) $bwRange2

   wm withdraw $heatMapSettingsGui
   ShowMapWrapper 1
}

proc restoreHeatMapSettingsAndQuit {} {
   global heatMapSettings
   global heatMapSettingsGui

   global utilRange0
   global utilRange1
   global utilRange2
   global utilRange3
   global utilRange4
   global bwRange0
   global bwRange1
   global bwRange2

   set utilRange0 $heatMapSettings(utilRange0) 
   set utilRange1 $heatMapSettings(utilRange1) 
   set utilRange2 $heatMapSettings(utilRange2) 
   set utilRange3 $heatMapSettings(utilRange3) 
   set utilRange4 $heatMapSettings(utilRange4) 
   set bwRange0 $heatMapSettings(bwRange0) 
   set bwRange1 $heatMapSettings(bwRange1) 
   set bwRange2 $heatMapSettings(bwRange2) 

   wm withdraw $heatMapSettingsGui
}

proc ytransform {y} {
   global c
   global canvasheight
   set winylength [winfo height $c]
   if {$winylength == 1} {
      set winylength $canvasheight
   }
   return [expr $winylength - $y]
}

proc zoomTop {c nCols nRows} {
   global canvaswidth
   global canvasheight
   global gridsize
   set lenX [expr $nCols * $gridsize]
   set lenY [expr $nRows * $gridsize]

   set xscale [expr double($canvaswidth)/$lenX]
   set yscale [expr double($canvasheight)/$lenY]
   
   if { $xscale > $yscale } {
      set factor $yscale
   } else {
      set factor $xscale
   }
   myPuts "DBG-402: factor = $factor"
   zoom $c $factor
}

proc downCanvasItem {w x y} {
   global env
   if {![info exists env(DEBUG_DRAWNOCGRAPH)]} {return}
   set ::ID [$w find withtag current]
   set ::X $x; set ::Y $y
}

proc moveCanvasItem {w x y} {
   global env
   if {![info exists env(DEBUG_DRAWNOCGRAPH)]} {return}

   global instPlacementArr
   global portCoordinatesArr
   global portConnectionArr
   global gridtag
   
   set selection [$w find withtag current]
   set selectedItem [lindex [$w gettags $selection] 0]
  

   #Check if this is an Inst
   if {[info exists instPlacementArr($selectedItem)]} {
      $w move $::ID [expr {$x-$::X}] [expr {$y-$::Y}]
      foreach {k v} [array get portCoordinatesArr] {
         set inst [lindex [split $k ","] 0]
         if {$inst == $selectedItem} {
            set portid [$w find withtag $k]
            $w move $portid [expr {$x-$::X}] [expr {$y-$::Y}]
            foreach {connectionName connections} [array get portConnectionArr] {
               set pairs [split $connections]
               set from [lindex $pairs 0]
               set to [lindex $pairs 1]
               if {($from == $k) || ($to == $k)} {
                  set lineid [$w find withtag "$from,$to"]
                  set coords [$w coords $lineid]
                  set llx [lindex $coords 0]
                  set lly [lindex $coords 1]
                  set urx [lindex $coords 2]
                  set ury [lindex $coords 3]
                  if {$from == $k} {
                     set llx [expr $llx + ($x-$::X)]
                     set lly [expr $lly + ($y-$::Y)]
                  }
                  if {$to == $k} {
                     set urx [expr $urx + ($x-$::X)]
                     set ury [expr $ury + ($y-$::Y)]
                  }
                  set coords [list $llx $lly $urx $ury]
                  $w coords $lineid $coords
               }
            }
         }
      }
      set ::X $x; set ::Y $y
      #Snap to grid
      $w delete ::tempMoveBox
      $w create rectangle 0 0 0 0 -tag ::tempMoveBox -outline yellow -width 2
      set grids [$w find withtag $gridtag]
      foreach grid $grids {
         set gridcoords [$w coords $grid]
         set instcoords [$w coords $selectedItem]
         foreach {gllx glly gurx gury} $gridcoords {break}
         foreach {illx illy iurx iury} $instcoords {break}
         if {($iurx < $gurx) && ($illx > $gllx) && ($iury < $gury) && ($illy > $glly)} {
            $w coords ::tempMoveBox $gridcoords
            set info [$w itemcget $grid -tags]
            regsub -all $gridtag $info "" info
            regsub -all {_} $info " " info
            set instPlacementArr($selectedItem) [list [lindex $info 0] [lindex $info 1]]
         }
      }
      drawInstPlacement $w
      drawPortConnections $w
   }
}

proc snapCanvasItem {w x y} {
   global env
   if {![info exists env(DEBUG_DRAWNOCGRAPH)]} {return}
   $w delete ::tempMoveBox
}
    
proc Regrid {} {
   global regridFile
   global c
   global env
   global gridtag
   global instPlacementArr

   if {[info exists env(DEBUG_DRAWNOCGRAPH)]} {
      puts "calling regrid"
      set OUT [open $regridFile w]
      set grids [$c find withtag $gridtag]
      foreach {k v} [array get instPlacementArr] {
         puts $OUT "$k X = [lindex $v 0] Y = [lindex $v 1]"
      }
      close $OUT
   }
}

proc selectItemAtXY {c x y} {
  global log
  global instPlacementArr
  global netNamesArr
  global portCoordinatesArr
  global regionArr
  global regiontag


  set selection [$c find withtag current]
  set selectedItem [lindex [$c gettags $selection] 0]
  if {$selectedItem == $regiontag} {
     set selectedItem [lindex [$c gettags $selection] 1]
  }
  myPuts "selectedItem = #$selectedItem#"
  #Check if this is an Inst or Net
  if {[info exists instPlacementArr($selectedItem)]} {
     clearLog
     handleInstSelection $selectedItem
  } elseif {[info exists netNamesArr($selectedItem)]} {
     clearLog
     handleNetSelection $selectedItem
  } elseif {[info exists regionArr($selectedItem)]} {
     clearLog
     handleRegionSelection $selectedItem
  } elseif {[info exists portCoordinatesArr($selectedItem)]} {
     clearLog
     handlePortSelection $selectedItem
     handleChannelSelection $selectedItem
  } else {
     return
  }
}

proc handleInstSelection {selectedItem} {
     global log
     global instPlacementArr
     global instCellArr
     global portConnectionArr
     global netConnectionArr
     global bwInfoArr


     $log config -state normal
     $log insert end "----------------------------------\n"
     $log insert end "Inst: $selectedItem\n"

     set x [lindex $instPlacementArr($selectedItem) 0]
     set y [lindex $instPlacementArr($selectedItem) 1]
     $log insert end "X = $x, Y = $y\n"


     if {[info exists instCellArr($selectedItem)]} {
        $log insert end "Type: $instCellArr($selectedItem)\n"
     }


     foreach {k v} [array get netConnectionArr] {
        set k [split $k ","]
        foreach {netName master masterPort masterLogicalName slave slavePort slaveLogicalName VC TC CT achievedLatency reqdLatency reqdBW} $k {break}
        foreach pair $v {
           set inst [lindex [split $pair ","] 0]
           if {$inst == $selectedItem} {
              set printStr "Net: %10s, VC = %3s, TC = %5s, CT = %5s, Achieved Latency = %5s, Reqd Latency = %5s, Reqd BW = %5s"
              set printStr [format $printStr $netName $VC $TC $CT $achievedLatency $reqdLatency $reqdBW]
              $log insert end "$printStr\n"
              break
           }
        }
     }

     if {[info exists bwInfoArr($selectedItem)]} {
	     foreach {requiredReadBW requiredWriteBW achievedReadBW achievedWriteBW} $bwInfoArr($selectedItem) {break}
        $log insert end "Required Read BW: $requiredReadBW\n"
        $log insert end "Required Write BW: $requiredWriteBW\n"
        $log insert end "Achieved Read BW: $achievedReadBW\n"
        $log insert end "Achieved Write BW: $achievedWriteBW\n"
     }

     $log insert end "----------------------------------\n"
     $log see end
     $log config -state disabled
}

proc handleNetSelection {selectedItem} {
     global log
     global netConnectionArr

     $log config -state normal
     $log insert end "----------------------------------\n"
     
     foreach {k v} [array get netConnectionArr] {
        set k [split $k ","]
        set netName [lindex $k 0]
        if {$netName == $selectedItem} {
           foreach {netName master masterPort masterLogicalName slave slavePort slaveLogicalName VC TC CT achievedLatency reqdLatency reqdBW} $k {break}
           $log insert end "Net: $selectedItem\n"
           $log insert end "From = $master, Port = $masterPort\n" 
           $log insert end "To = $slave, Port = $slavePort\n" 
           $log insert end "VC = $VC\n" 
           $log insert end "TC = $TC\n" 
           $log insert end "CT = $CT\n" 
           $log insert end "Achieved Structural Latency = $achievedLatency\n" 
           $log insert end "Required Latency = $reqdLatency\n" 
           $log insert end "Required BandWidth = $reqdBW\n" 
           $log insert end "Route = $v\n" 
        }
     }
     $log insert end "----------------------------------\n"
     $log see end
     $log config -state disabled
}


proc handlePortSelection {selectedItem} {
     global log
     global portConnectionArr
     global netConnectionArr


     $log config -state normal
     $log insert end "----------------------------------\n"

     set inst [lindex [split $selectedItem ","] 0]
     set port [lindex [split $selectedItem ","] 1]

     $log insert end "Port: $port\n"
     $log insert end "Inst: $inst\n"


     foreach {k v} [array get netConnectionArr] {
        set k [split $k ","]
        foreach {netName master masterPort masterLogicalName slave slavePort slaveLogicalName VC TC CT achievedLatency reqdLatency reqdBW} $k {break}
        foreach pair $v {
           if {$pair == $selectedItem} {
              set printStr "Net: %10s, VC = %3s, TC = %5s, CT = %5s, Achieved Latency = %5s, Reqd Latency = %5s, Reqd BW = %5s"
              set printStr [format $printStr $netName $VC $TC $CT $achievedLatency $reqdLatency $reqdBW]
              $log insert end "$printStr\n"
              break
           }
        }
     }

     $log insert end "----------------------------------\n"
     $log see end
     $log config -state disabled
}

proc handleChannelSelection {selectedItem} {
     global log
     global simulationInfoArr
     global simulationPostInfoArr
     global simulationEndtime
     global compilerBWArr

     $log config -state normal
     $log insert end "----------------------------------\n"

     $log insert end "Channel Info:\n"

     
     foreach {k v} [array get simulationInfoArr] {
        set minst [lindex [split $k ","] 0]
        set mport [lindex [split $k ","] 1]
        set sinst [lindex [split $k ","] 2]
        set sport [lindex [split $k ","] 3]
        if {$selectedItem == "$minst,$mport" || $selectedItem == "$sinst,$sport"} {
           foreach elem $v {
              set elem [lindex $elem 0]
              foreach {time packetid packettype header vc src dest} $elem {break}
              set printStr "Time: %10s, PktId = %10s, PktType = %3s, VC = %3s, Src = %5s, Dst = %5s"
              set printStr [format $printStr $time $packetid $packettype $vc $src $dest]
              $log insert end "$printStr\n"
           }
           foreach {rawRdUtilization rawWrUtilization effRdUtilization effWrUtilization rdBandwidth wrBandwidth} $simulationPostInfoArr($k) {break}
           showOnLog "Raw Read Utilization % : $rawRdUtilization"
           showOnLog "Raw Write Utilization % : $rawWrUtilization"
           showOnLog "Effective Read Utilization % : $effRdUtilization"
           showOnLog "Effective Write Utilization % : $effWrUtilization"
           showOnLog "Read Bandwidth (MB/s): $rdBandwidth"
           showOnLog "Write Bandwidth (MB/s): $wrBandwidth"
           break
        }
     }
    
     foreach {k v} [array get compilerBWArr] {
        set minst [lindex [split $k ","] 0]
        set mport [lindex [split $k ","] 1]
        set sinst [lindex [split $k ","] 2]
        set sport [lindex [split $k ","] 3]
        if {$selectedItem == "$minst,$mport" || $selectedItem == "$sinst,$sport"} {
           showOnLog "Total reqd compiler BW(Mb/s): $v"
        }
     }

     $log insert end "----------------------------------\n"
     $log see end
     $log config -state disabled
}

proc handleRegionSelection {selectedItem} {
     global log
     global regionArr 

     $log config -state normal
     $log insert end "----------------------------------\n"

     $log insert end "Region: $selectedItem\n"
     $log insert end "Instances: $regionArr($selectedItem)\n"

     $log insert end "----------------------------------\n"
     $log see end
     $log config -state disabled
}

proc initLenses {} {
   global lens
   set lens(llx) 1e6
   set lens(lly) 1e6
   set lens(urx) -1e6 
   set lens(ury) -1e6 

   set lens(topllx) 1e6
   set lens(toplly) 1e6
   set lens(topurx) -1e6 
   set lens(topury) -1e6 
}

proc drawGrid {c nCols nRows} {
   myPuts "DBG-876: calling drawGrid"
   global gridsize
   global gridcolor
   global gridtag
   global canvaswidth
   global canvasheight
   global gridObjectArr
   global lens
   global lensMargin

   if {[info exists gridObjectArr]} {array unset gridObjectArr}
   initLenses

   for {set i 0} {$i < $nCols} {incr i} {
      for {set j 0} {$j < $nRows} {incr j} {
         set llx [expr $i * $gridsize]
         set lly [expr $j * $gridsize]
         set urx [expr $llx + $gridsize]
         set ury [expr $lly + $gridsize]
         #$c create rectangle $llx [ytransform $lly] $urx [ytransform $ury] -outline $gridcolor -tags [list $gridtag "$gridtag\_$i\_$j"] -dash "-  -  -" 
         set gridObjectArr($gridtag\_$i\_$j) "{$llx $lly $urx $ury} -outline $gridcolor -tags \"$gridtag $gridtag\_$i\_$j\" -dash \"-  -  -\""
         if {$llx <= $lens(llx)} {set lens(llx) $llx}
         if {$lly <= $lens(lly)} {set lens(lly) $lly}
         if {$urx >= $lens(urx)} {set lens(urx) $urx}
         if {$ury >= $lens(ury)} {set lens(ury) $ury}
      }
   }
   myParray gridObjectArr

   set lens(topllx) [expr $lens(llx) - $lensMargin]
   set lens(toplly) [expr $lens(lly) - $lensMargin]
   set lens(topurx) [expr $lens(urx) + $lensMargin]
   set lens(topury) [expr $lens(ury) + $lensMargin]

   set lens(llx) $lens(topllx) 
   set lens(lly) $lens(toplly) 
   set lens(urx) $lens(topurx) 
   set lens(ury) $lens(topury) 
}

proc drawRegions {} {
   global regionCoordsArr
   global regionObjectArr
   global regionNameObjectArr
   global gridsize
   global regiontag
   global regionOffset
   global regioncolor
   global textcolor
   global highlightColor
   global highlightWidth
   
   if {[info exists regionObjectArr]} {array unset regionObjectArr}
   if {[info exists regionNameObjectArr]} {array unset regionNameObjectArr}
   
   foreach {k v} [array get regionCoordsArr] {
      set rllx [lindex $v 0]
      set rlly [lindex $v 1]
      set rurx [lindex $v 2]
      set rury [lindex $v 3]
      set llx [expr ($rllx * $gridsize) + $regionOffset]
      set lly [expr ($rlly * $gridsize) + $regionOffset]
      set urx [expr (($rurx + 1) * $gridsize) - $regionOffset]
      set ury [expr (($rury + 1) * $gridsize) - $regionOffset]
      set regionObjectArr($k) "{$llx $lly $urx $ury} -outline $regioncolor -tags \"$regiontag $k\" -activeoutline $highlightColor -activewidth $highlightWidth"
      set regionNameObjectArr($k) "{$llx $lly} -text $k -anchor se -fill $textcolor -tag $regiontag"
   }
}

proc drawInstPlacement {c} {
   global instPlacementArr
   global instBboxArr
   global instCellArr
   global masterRegex
   global slaveRegex
   global ddrRegex
   global switchRegex
   global gridsize
   global canvaswidth
   global canvasheight
   global offset
   global mastercolor
   global slavecolor
   global switchcolor
   global outlinecolor
   global textcolor
   global highlightColor
   global highlightWidth
   global instStipple
   global insttag
   global instObjectArr
   global instNameObjectArr

   if {[info exists instObjectArr]} {array unset instObjectArr}
   if {[info exists instNameObjectArr]} {array unset instNameObjectArr}
   if {[info exists instBboxArr]} {array unset instBboxArr}

   foreach {instname coords} [array get instPlacementArr] {
      set x [lindex $coords 0]
      set y [lindex $coords 1]
      set color white
      if {[regexp $masterRegex $instCellArr($instname)]} {
         set color $mastercolor 
      } elseif {[regexp $slaveRegex|$ddrRegex $instCellArr($instname)]} {
         set color $slavecolor
      } elseif {[regexp $switchRegex $instCellArr($instname)]} {
         set color $switchcolor 
      } else {
         #Ignore everything except Master, Slave and Switch
         continue
      }
      #Draw the bbox for inst
      set llx [expr ($x * $gridsize) + $offset]
      set lly [expr ($y * $gridsize) + $offset]
      set urx [expr ($llx + $gridsize) - (2 * $offset)]
      set ury [expr ($lly + $gridsize) - (2 * $offset)]
      #$c create rectangle $llx [ytransform $lly] $urx [ytransform $ury] -outline $outlinecolor -fill $color -tag $instname -activeoutline $highlightColor -activewidth $highlightWidth
      set instObjectArr($instname) "{$llx $lly $urx $ury} -outline $outlinecolor -fill $color -tag $instname -activeoutline $highlightColor -activewidth $highlightWidth -stipple $instStipple"
      
      #Draw the inst name
      set centerx [expr $llx + ($urx - $llx)/2.0]
      set centery [expr $lly + ($ury - $lly)/2.0]
      myPuts "DBG-400: $llx $lly $urx $ury, $centerx $centery"
      #$c create text $centerx [ytransform $centery] -text $instname -fill $textcolor -tag $insttag
      set instNameObjectArr($instname) "{$centerx $centery} -text $instname -fill $textcolor -tag $insttag"

      set instBboxArr($instname) [list $llx $lly $urx $ury]
   }
   myParray instObjectArr
   myParray instNameObjectArr
}

proc drawPortConnections {c} {
   global instPlacementArr
   global instPortDirArr
   global portConnectionArr
   global portconnectioncolor
   global channelObjectArr
  
   if {[info exists instPortDirArr]} {array unset instPortDirArr}

   foreach {connectionName connections} [array get portConnectionArr] {
      set pairs [split $connections]
      set from [lindex $pairs 0]
      set fromInst [lindex [split $from ","] 0]
      set fromPort [lindex [split $from ","] 1]
      set fromInstX [lindex $instPlacementArr($fromInst) 0]
      set fromInstY [lindex $instPlacementArr($fromInst) 1]
      set to [lindex $pairs 1]
      set toInst [lindex [split $to ","] 0]
      set toPort [lindex [split $to ","] 1]
      set toInstX [lindex $instPlacementArr($toInst) 0]
      set toInstY [lindex $instPlacementArr($toInst) 1]

      set deltaX [expr $toInstX - $fromInstX]
      set deltaY [expr $toInstY - $fromInstY]

      if {$deltaX == 0} {
         if {$deltaY >= 0} {
            set dir "N"
         } else {
            set dir "S"
         }
      } else {
         if {$deltaY == 0} {
            if {$deltaX < 0} {
               set dir "W"
            } else {
               set dir "E"
            }
         } else {
            if {($deltaX > 0) && ($deltaY > 0)} {
               set dir "NE"
            } elseif {($deltaX < 0) && ($deltaY > 0)} {
               set dir "NW"
            } elseif {($deltaX > 0) && ($deltaY < 0)} {
               set dir "SE"
            } elseif {($deltaX < 0) && ($deltaY < 0)} {
               set dir "SW"
            }
         }
      }
      myPuts "DBG-456: connecting $from to $to: $dir"
      if {[regexp {N} $dir]} {
         #From inst's port should be on Top and To inst's port on Bottom
         lappend instPortDirArr($fromInst,Top) $fromPort
         lappend instPortDirArr($toInst,Bottom) $toPort
      } elseif {[regexp {S} $dir]} {
         #From inst's port should be on Bottom and To inst's port on Top
         lappend instPortDirArr($fromInst,Bottom) $fromPort
         lappend instPortDirArr($toInst,Top) $toPort
      } elseif {[regexp {W} $dir]} {
         #From inst's port should be on Left and To inst's port on Right
         lappend instPortDirArr($fromInst,Left) $fromPort
         lappend instPortDirArr($toInst,Right) $toPort
      } elseif {[regexp {E} $dir]} {
         #From inst's port should be on Right and To inst's port on Left
         lappend instPortDirArr($fromInst,Right) $fromPort
         lappend instPortDirArr($toInst,Left) $toPort
      } 
   }

   #
   populatePortCoordinates $c
   
   #
   if {[info exists channelObjectArr]} {array unset channelObjectArr}
   foreach {connectionName connections} [array get portConnectionArr] {
      set pairs [split $connections]
      set from [lindex $pairs 0]
      set to [lindex $pairs 1]
      connectInstPortToInstPort $c $from $to $portconnectioncolor 
   }
   myParray channelObjectArr
}

proc populatePortCoordinates {c} {
   global instPortDirArr
   global instBboxArr
   global portCoordinatesArr
   global pinsize
   global outlinecolor
   global textcolor
   global porttag
   global highlightWidth
   global highlightColor
   global portfillcolor
   global portObjectArr
   global portNameObjectArr

   if {[info exists portObjectArr]} {array unset portObjectArr}
   if {[info exists portNameObjectArr]} {array unset portNameObjectArr}
   if {[info exists portCoordinatesArr]} {array unset portCoordinatesArr}

   foreach {inst bbox} [array get instBboxArr] {
      set llx [lindex $bbox 0]
      set lly [lindex $bbox 1]
      set urx [lindex $bbox 2]
      set ury [lindex $bbox 3]
      if {[info exists instPortDirArr($inst,Top)]} {
         set nPorts [llength $instPortDirArr($inst,Top)]
         set delta [expr ($urx - $llx)/double($nPorts + 1)]
         set count 1
         foreach port $instPortDirArr($inst,Top) {
            set portX [expr $llx + ($count * $delta)]
            set portY $ury
            set portCoordinatesArr($inst,$port) [list $portX $portY]
            incr count
         }
      }

      if {[info exists instPortDirArr($inst,Bottom)]} {
         set nPorts [llength $instPortDirArr($inst,Bottom)]
         set delta [expr ($urx - $llx)/double($nPorts + 1)]
         set count 1
         foreach port $instPortDirArr($inst,Bottom) {
            set portX [expr $llx + ($count * $delta)]
            set portY $lly
            set portCoordinatesArr($inst,$port) [list $portX $portY] 
            incr count
         }
      }

      if {[info exists instPortDirArr($inst,Left)]} {
         set nPorts [llength $instPortDirArr($inst,Left)]
         set delta [expr ($ury - $lly)/double($nPorts + 1)]
         set count 1
         foreach port $instPortDirArr($inst,Left) {
            set portX $llx
            set portY [expr $lly + ($count * $delta)]
            set portCoordinatesArr($inst,$port) [list $portX $portY] 
            incr count
         }
      }

      if {[info exists instPortDirArr($inst,Right)]} {
         set nPorts [llength $instPortDirArr($inst,Right)]
         set delta [expr ($ury - $lly)/double($nPorts + 1)]
         set count 1
         foreach port $instPortDirArr($inst,Right) {
            set portX $urx
            set portY [expr $lly + ($count * $delta)]
            set portCoordinatesArr($inst,$port) [list $portX $portY] 
            incr count
         }
      }
   }

   myParray portCoordinatesArr

   #Draw the ports
   foreach {k v} [array get portCoordinatesArr] {
      set name [lindex [split $k ","] 0]
      set pinname [lindex [split $k ","] 1]
         set x [lindex $v 0]
         set y [lindex $v 1]
         set cirllx [expr $x - $pinsize]
         set cirlly [expr $y - $pinsize]
         set cirurx [expr $x + $pinsize]
         set cirury [expr $y + $pinsize]
         #$c create oval $cirllx [ytransform $cirlly] $cirurx [ytransform $cirury] -outline $outlinecolor -tag "$name,$pinname" -activeoutline $highlightColor -activewidth $highlightWidth -fill $portfillcolor
         set portObjectArr($name,$pinname) "{$cirllx $cirlly $cirurx $cirury} -outline $outlinecolor -tag \"$name,$pinname\" -activeoutline $highlightColor -activewidth $highlightWidth -fill $portfillcolor"
         #$c create text $cirllx [ytransform $cirlly] -text $pinname -anchor se -fill $textcolor -tag $porttag 
         set portNameObjectArr($name,$pinname) "{$cirllx $cirlly} -text $pinname -anchor se -fill $textcolor -tag $porttag"
   }
   myParray portObjectArr
   myParray portNameObjectArr
}

proc connectInstPortToInstPort {c from to {color ""} {lineWidth 1} {isNet "false"} {netName ""}} {
   myPuts "DBG-599: connecting ports $from to $to, with color $color"
   global portCoordinatesArr
   global netPortConnectionsArr
   global pinsize
   global digress
   global outlinecolor
   global portfillcolor
   global highlightColor
   global highlightWidth
   global netCoordinatesArr
   global channelObjectArr
   

   if {[info exists portCoordinatesArr($from)] && [info exists portCoordinatesArr($to)]} {
      set fromx [lindex $portCoordinatesArr($from) 0]
      set fromy [lindex $portCoordinatesArr($from) 1]
      set tox [lindex $portCoordinatesArr($to) 0]
      set toy [lindex $portCoordinatesArr($to) 1]

      set cirllx [expr $fromx - $pinsize]
      set cirlly [expr $fromy - $pinsize]
      set cirurx [expr $fromx + $pinsize]
      set cirury [expr $fromy + $pinsize]
      #$c create oval $cirllx [ytransform $cirlly] $cirurx [ytransform $cirury] -outline $outlinecolor -fill $portfillcolor -tag $netName 

      set cirllx [expr $tox - $pinsize]
      set cirlly [expr $toy - $pinsize]
      set cirurx [expr $tox + $pinsize]
      set cirury [expr $toy + $pinsize]
      #$c create oval $cirllx [ytransform $cirlly] $cirurx [ytransform $cirury] -outline $outlinecolor -fill $portfillcolor -tag $netName 
      
      if {$isNet == "true"} {
         if {[info exists netPortConnectionsArr($from,$to)]} {
            myPuts "DBG-600: found overlap between $from and $to"
            set count $netPortConnectionsArr($from,$to)
            set netPortConnectionsArr($from,$to) [expr $count + 1]
            set count $netPortConnectionsArr($from,$to)
            myPuts "DBG-602: count = $count"
            set x1 $fromx
            set y1 $fromy
            set x2 $tox
            set y2 $toy
            if {[expr $count % 2] == 0} {
               set x3 [expr (($x1+$x2)/2.0) + (($count*$digress*($y1-$y2)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
               set y3 [expr (($y1+$y2)/2.0) + (($count*$digress*($x2-$x1)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
            } else {
               set x3 [expr (($x1+$x2)/2.0) - (($count*$digress*($y1-$y2)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
               set y3 [expr (($y1+$y2)/2.0) - (($count*$digress*($x2-$x1)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
            }
            #$c create line $fromx [ytransform $fromy] $x3 [ytransform $y3] -fill $color -width $lineWidth -tag $netName -activefill $highlightColor -activewidth $highlightWidth 
            #$c create line $x3 [ytransform $y3] $tox [ytransform $toy] -fill $color -width $lineWidth -tag $netName -activefill $highlightColor -activewidth $highlightWidth
            if {[info exists netCoordinatesArr($netName)]} {
              set temp $netCoordinatesArr($netName)
              set netCoordinatesArr($netName) [lappend temp [list $fromx $fromy $x3 $y3] [list $x3 $y3 $tox $toy]]
            } else {
            set netCoordinatesArr($netName) [list [list $fromx $fromy $x3 $y3] [list $x3 $y3 $tox $toy]] 
            }
         } elseif {[info exists netPortConnectionsArr($to,$from)]} {
            myPuts "DBG-600: found overlap between $to and $from"
            set count $netPortConnectionsArr($to,$from)
            set netPortConnectionsArr($to,$from) [expr $count + 1]
            set count $netPortConnectionsArr($to,$from)
            myPuts "DBG-602: count = $count"
            set x2 $fromx
            set y2 $fromy
            set x1 $tox
            set y1 $toy
            if {[expr $count % 2] == 0} {
               set x3 [expr (($x1+$x2)/2.0) + (($count*$digress*($y1-$y2)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
               set y3 [expr (($y1+$y2)/2.0) + (($count*$digress*($x2-$x1)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
            } else {
               set x3 [expr (($x1+$x2)/2.0) - (($count*$digress*($y1-$y2)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
               set y3 [expr (($y1+$y2)/2.0) - (($count*$digress*($x2-$x1)) / (sqrt(($y1-$y2)*($y1-$y2) + ($x2-$x1)*($x2-$x1))))]
            }
            #$c create line $fromx [ytransform $fromy] $x3 [ytransform $y3] -fill $color -width $lineWidth -tag $netName -activefill $highlightColor -activewidth $highlightWidth 
            #$c create line $x3 [ytransform $y3] $tox [ytransform $toy] -fill $color -width $lineWidth -tag $netName -activefill $highlightColor -activewidth $highlightWidth 
            if {[info exists netCoordinatesArr($netName)]} {
              set temp $netCoordinatesArr($netName)
              set netCoordinatesArr($netName) [lappend temp [list $fromx $fromy $x3 $y3] [list $x3 $y3 $tox $toy]]
            } else {
            set netCoordinatesArr($netName) [list [list $fromx $fromy $x3 $y3] [list $x3 $y3 $tox $toy]] 
            }
         } else {
            set netPortConnectionsArr($from,$to) 1
            #$c create line $fromx [ytransform $fromy] $tox [ytransform $toy] -fill $color -width $lineWidth -tag $netName  -activefill $highlightColor -activewidth $highlightWidth
            if {[info exists netCoordinatesArr($netName)]} {
              set temp $netCoordinatesArr($netName)
              set netCoordinatesArr($netName) [lappend temp [list $fromx $fromy $tox $toy]]
            } else {
            set netCoordinatesArr($netName) [list [list $fromx $fromy $tox $toy]] 
            }
         }
      } else {
         #$c create line $fromx [ytransform $fromy] $tox [ytransform $toy] -fill $color -width $lineWidth -tag "$from\_$to"
         set channelObjectArr($from,$to) "{$fromx $fromy $tox $toy} -fill $color -width $lineWidth -tag \"$from,$to\""
      }
   } else {
      myPuts "ERROR-101: Could not connect $from to $to"
   }
}

proc drawNets {c listBox} {
   global netConnectionArr
   global netNamesArr
   global netLineWidth
   global netCoordinatesArr
   global highlightWidth
   global highlightColor
   global netObjectArr
   global netPortConnectionsArr
   
   if {[info exists netObjectArr]} {array unset netObjectArr}
   if {[info exists netPortConnectionsArr]} {array unset netPortConnectionsArr}
   if {[info exists netCoordinatesArr]} {array unset netCoordinatesArr}
   if {[info exists netNamesArr]} {array unset netNamesArr}
   $listBox delete 0 end

   foreach {k v} [array get netConnectionArr] {
      set k [split $k ","]
      set netName [lindex $k 0]
      set netNamesArr($netName) 1
      $listBox insert end $netName
      $listBox selection set end end
      myPuts "DBG-333: netName = $netName"
      for {set i 0} {$i < [expr [llength $v] - 1]} {set i [expr $i + 1]} {
         set from [lindex $v $i]
         set to [lindex $v [expr $i + 1]]
         connectInstPortToInstPort $c $from $to "" $netLineWidth "true" $netName 
      }
   }
   myParray netCoordinatesArr
   #Draw the net now
   set count 0
   foreach {netName v} [array get netCoordinatesArr] {
      myPuts "k = $netName"
      set color [getColorForNet $count]
      foreach fourPoints $v {
         foreach point $fourPoints {
            lappend coords $point
         }
      }
      myPuts "net coords = $coords"
      #$c create line $coords -fill $color -width $netLineWidth -tag $netName  -activefill $highlightColor -activewidth $highlightWidth
      set netObjectArr($netName) "{$coords} -fill \"$color\" -width $netLineWidth -tag $netName  -activefill $highlightColor -activewidth $highlightWidth"
      unset coords
      incr count
   }
   myParray netObjectArr
}

proc clearCanvasHighlights {} {
   global highlightObjectArr
   global c

   array unset highlightObjectArr
   redraw $c
}

proc drawGeometries {c} {
   global gridObjectArr
   global regionObjectArr
   global instObjectArr
   global instNameObjectArr
   global portObjectArr 
   global portNameObjectArr
   global regionNameObjectArr
   global channelObjectArr
   global netObjectArr
   global highlightObjectArr
   global showGrid 
   global showPortNames 
   global showInstNames
   global listBox
   global mapTypeString
   global mapTypeStringTag

   $c delete "all"
   drawTopLens $c
   drawCanvasObjects $c gridObjectArr "rect" 
   drawCanvasObjects $c regionObjectArr "rect" 
   drawCanvasObjects $c instObjectArr "rect"
   drawCanvasObjects $c instNameObjectArr "text"
   drawCanvasObjects $c highlightObjectArr "rect"
   drawCanvasObjects $c portObjectArr "oval"
   drawCanvasObjects $c portNameObjectArr "text"
   drawCanvasObjects $c regionNameObjectArr "text"
   drawCanvasObjects $c channelObjectArr "line"
   drawCanvasObjects $c netObjectArr "lines"

   #Text for map-type
   $c create text 10 10 -text $mapTypeString -tag $mapTypeStringTag -fill white -font {-family aerial -size 10} -anchor nw
   
   toggleGrid $c
   toggleRegion $c
   toggleInstNames $c
   togglePortNames $c
   showNet $c $listBox [$listBox curselection] 1
}

proc drawTopLens {c} {
   global lens
   global lensMargin
   global lensBoundaryColor

   set factors [list [expr 2/double(5)] [expr 3/double(5)]]
   foreach factor $factors {
      set llx [expr $lens(topllx) + ($lensMargin * $factor)]
      set lly [expr $lens(toplly) + ($lensMargin * $factor)]
      set urx [expr $lens(topurx) - ($lensMargin * $factor)]
      set ury [expr $lens(topury) - ($lensMargin * $factor)]
      foreach {screenllx screenlly} [translateDBToScreen [list $llx $lly]] {break}
      foreach {screenurx screenury} [translateDBToScreen [list $urx $ury]] {break}
      $c create rect $screenllx $screenlly $screenurx $screenury -outline $lensBoundaryColor 
   }
}

proc drawCanvasObjects {c objs type} {
   upvar $objs ObjectArr
   foreach {k v} [array get ObjectArr] {
      set dbCoords [lindex $v 0]
      if {$type == "rect" || $type == "oval" || $type == "line"} {
         if {[isRectIntersectLens $dbCoords]} {
            foreach {dbllx dblly dburx dbury} $dbCoords {break}
            foreach {screenllx screenlly} [translateDBToScreen [list $dbllx $dblly]] {break}
            foreach {screenurx screenury} [translateDBToScreen [list $dburx $dbury]] {break}
            set cmd "$c create $type $screenllx $screenlly $screenurx $screenury [lrange $v 1 end]"
            myPuts "$cmd"
            eval $cmd
         }
      }
      if {$type == "lines"} {
         if {[isLinesIntersectLens $dbCoords]} {
            set screencoords ""
            for {set i 0} {$i < [expr [llength $dbCoords] - 1]} {incr i 2} {
               set dbllx [lindex $dbCoords $i]
               set dblly [lindex $dbCoords [expr $i + 1]]
               foreach {screenllx screenlly} [translateDBToScreen [list $dbllx $dblly]] {break}
               set screencoords [concat $screencoords "$screenllx $screenlly"]
            }
            set cmd "$c create line $screencoords [lrange $v 1 end]"
            myPuts "$cmd"
            eval $cmd
         }
      }
      if {$type == "text"} {
         if {[isPointInsideLens $dbCoords]} {
            foreach {dbllx dblly} $dbCoords {break}
            foreach {screenllx screenlly} [translateDBToScreen [list $dbllx $dblly]] {break}
            set cmd "$c create $type $screenllx $screenlly [lrange $v 1 end]"
            myPuts "$cmd"
            eval $cmd
         }
      }
   }
}

proc showOnLog {str {tag "result"}} {
   global log
   $log config -state normal 
   $log insert end "$str\n" $tag 
   $log see end
   $log config -state disabled 
}

proc clearLog {} {
   global log 
   $log config -state normal
   $log delete 1.0 end
   $log config -state disabled 
}

proc showNet {c listBox nets {isRedraw 0}} {
   global netNamesArr
   if {!$isRedraw} {
      clearLog
   }
   myPuts "DBG-567: calling shownet for $nets"
   foreach n [array names netNamesArr] {
      $c itemconfigure $n -state hidden
   }
   foreach n $nets {
      myPuts "DBG-568: showing net [$listBox get $n]"
      myPuts "DBG-569: the net is $netNamesArr([$listBox get $n])"
      $c itemconfigure [$listBox get $n] -state normal
      if {!$isRedraw} {
         handleNetSelection [$listBox get $n]
      }
   }
}

proc showAll {c listBox} {
   global netNamesArr
   $listBox selection set 0 end
   foreach n [array names netNamesArr] {
      $c itemconfigure $n -state normal 
   }
}

proc hideAll {c listBox} {
   global netNamesArr
   $listBox selection clear 0 end
   foreach n [array names netNamesArr] {
      $c itemconfigure $n -state hidden 
   }
}

proc doSearch {name} {
   global c
   global listBox
   global netConnectionArr
   myPuts "DBG-333: searching for pattern $name"
   regsub -all {^\s+} $name "" name
   regsub -all {\s+} $name " " name

   

   if {[regexp {:} $name]} {
      set searchStr [lindex [split $name ":"] 1]
      foreach {k v} [array get netConnectionArr] {
         set k [split $k ","]
         foreach {netName from fromPort fromLogicalName to toPort toLogicalName VC TC CT achievedLatency reqdLatency reqdBW} $k {break}
         #myPuts "DBG-334: netname = $netName"
         if {[regexp -nocase {vc:} $name]} {
            set searchField $VC 
         } elseif {[regexp -nocase {tc:} $name]} {
            set searchField $TC 
         } elseif {[regexp -nocase {ct:} $name]} {
            set searchField $CT
         } elseif {[regexp -nocase {f:} $name]} {
            set searchField $from
         } elseif {[regexp -nocase {t:} $name]} {
            set searchField $to
         } else {
            #ERROR
            set searchField ""
         }
         if {[regexp {\*|\$|\?|\.} $name]} {
            if {[regexp -nocase "$searchStr" $searchField]} {
               lappend matchingNets $netName
            }
         } else {
            if {$searchStr == $searchField} {
               lappend matchingNets $netName
            }
         }
      }
      if {[info exists matchingNets]} {      
         myPuts "DBG-654: matchingnets = $matchingNets"
         handleSearchedNet $c $listBox $matchingNets
         unset matchingNets
      } else {
         tk_messageBox -message "Nothing matched $name" -type ok -icon error 
      }
   } else {
      handleSearchedNet $c $listBox $name
   }
}

proc handleSearchedNet {c listBox names} {
	   myPuts "DBG-666: searching net $names"
	   set index -1
	   set foundMatch 0
      set exact 1
	   if {[info exists matchingIndexes]} {
	      unset matchingIndexes
	   }
      if {[regexp {\*|\$|\?|\.} $names]} {set exact 0}
	   foreach elem [$listBox get 0 end] {
	      #myPuts "DBG-667: iterating through $elem"
	      incr index
         foreach name $names {
            if {$exact == 1} {
	            if {$name == $elem} {
	               myPuts "DBG-668: found a match for $name in $elem"
      	         set foundMatch 1
      	         lappend matchingIndexes $index
      	      }
            } else {
	            if {[regexp -nocase "$name" $elem]} {
	               myPuts "DBG-669: found a match for $name in $elem"
      	         set foundMatch 1
      	         lappend matchingIndexes $index
      	      }
            }
         }
	   }
	   if {$foundMatch == 1} {
	      $listBox selection clear 0 end
	      foreach ind $matchingIndexes {
	         $listBox selection set $ind $ind
	      }
	      showNet $c $listBox [$listBox curselection] 
	   } else {
         tk_messageBox -message "Nothing matched $names" -type ok -icon error 
      }
}

proc toggleGrid {c} {
   global gridtag
   global showGrid
   if {!$showGrid} {
      $c itemconfigure $gridtag -state hidden 
   } else {
      $c itemconfigure $gridtag -state normal 
   }
}

proc toggleRegion {c} {
   global regiontag
   global showRegion
   if {!$showRegion} {
      $c itemconfigure $regiontag -state hidden 
   } else {
      $c itemconfigure $regiontag -state normal 
   }
}

proc togglePortNames {c} {
   global porttag
   global showPortNames
   if {!$showPortNames} {
      $c itemconfigure $porttag -state hidden 
   } else {
      $c itemconfigure $porttag -state normal 
   }
}

proc toggleInstNames {c} {
   global insttag
   global showInstNames
   if {!$showInstNames} {
      $c itemconfigure $insttag -state hidden 
   } else {
      $c itemconfigure $insttag -state normal 
   }
}

proc ShowMapWrapper {{force 0}} {
   global c
   global prevMapDisplayType1
   global prevMapDisplayType2
   global mapDisplayType1
   global mapDisplayType2
   global trafficInfoArr
   global simulationPostInfoArr
   global netConnectionArr

   #Checks
   if {!$force} {
      if {($prevMapDisplayType1 == $mapDisplayType1) &&  ($prevMapDisplayType2 == $mapDisplayType2)} {return}
      if {($prevMapDisplayType1 == $mapDisplayType1) &&  (($mapDisplayType1 == "none") || ($mapDisplayType1 == "compilerBandwidth"))} {return}
   }

   if {$mapDisplayType1 != "none"} {
	   if {$mapDisplayType1 == "compilerBandwidth"} {
	      if {![info exists netConnectionArr]} {
	         tk_messageBox -message "Compiler results not available. Please run Compiler first." -type ok -icon error
	         return
	      }
	   } else {
	      if {![info exists trafficInfoArr] || ![info exists simulationPostInfoArr]} {
	         tk_messageBox -message "Simulation results not available. Please run Simulation first." -type ok -icon error
	         return
	      }
	   }
   }

   . config -cursor watch
   redraw $c
   . config -cursor {}
}

proc ShowMap {} {
   global prevMapDisplayType1
   global prevMapDisplayType2
   global mapDisplayType1
   global mapDisplayType2
   global mapGradientColors
   global passFailMapGradientColors
   global masterRegex
   global slaveRegex
   global switchRegex
   global ddrRegex
   global simulationPostInfoArr
   global compilerBWArr
   global bwInfoArr
   global instCellArr
   global channelObjectArr
   global instObjectArr
   global compilerBWDenominator
   global c
   global listBox
   global mapTypeString
   global mapTypeStringTag
   global channelWidthForMaps
   global heatMapSettings

   #Configure the map type text
   switch $mapDisplayType1 {
	   "rawutil" {
	      switch $mapDisplayType2 {
	         "read" {set mapTypeString "Raw Read Util% Map"}
	         "write" {set mapTypeString "Raw Write Util% Map"}
	      }
	   }
	   "effectiveutil" {
	      switch $mapDisplayType2 {
	         "read" {set mapTypeString "Effective Read Util% Map"}
	         "write" {set mapTypeString "Effective Write Util% Map"}
	      }
	   }
	   "simulatorBandwidth" {
	      switch $mapDisplayType2 {
	         "read" {set mapTypeString "Simulation Read Bandwidth Map"}
	         "write" {set mapTypeString "Simulation Write Bandwidth Map"}
	      }
	   }
	   "compilerBandwidth" {
	      set mapTypeString "Compiler Bandwidth Map"
	   }
      "none" {
         if {$prevMapDisplayType1 != "none"} {showAll $c $listBox}
         set mapTypeString ""
         $c itemconfigure $mapTypeStringTag -text $mapTypeString
         set prevMapDisplayType1 $mapDisplayType1
         set prevMapDisplayType2 $mapDisplayType2
         return
      }
	}



   set prevMapDisplayType1 $mapDisplayType1
   set prevMapDisplayType2 $mapDisplayType2

   #configure text for the maptype
   $c itemconfigure $mapTypeStringTag -text $mapTypeString

   #Hide all nets, as its the map view
   hideAll $c $listBox

   #Configure the canvas objects according to map type
   if {$mapDisplayType1 == "rawutil" || $mapDisplayType1 == "effectiveutil"} {
	   #Channel objects for utilization maps
	   foreach {k v} [array get simulationPostInfoArr] {
	      if {[info exists channelObjectArr($k)]} {
	         set tag [lindex $channelObjectArr($k) [expr [lsearch $channelObjectArr($k) "-tag"] + 1]]
	         set item [$c find withtag $tag]
	         foreach {rawRdUtilization rawWrUtilization effRdUtilization effWrUtilization rdBandwidth wrBandwidth} $v {break}
			   set index -1
	         switch $mapDisplayType1 {
			      "rawutil" {
			         switch $mapDisplayType2 {
			            "read" {set index [findIndexForUtilization $rawRdUtilization]}
			            "write" {set index [findIndexForUtilization $rawWrUtilization]}
			            default {}
			         }
			      }
			      "effectiveutil" {
			         switch $mapDisplayType2 {
			            "read" {set index [findIndexForUtilization $effRdUtilization]}
			            "write" {set index [findIndexForUtilization $effWrUtilization]}
			            default {}
			         }
			      }
			   }
            if {$index != -1} {
               if {$heatMapSettings(utilRange$index)} {
   	            $c itemconfigure $item -fill $mapGradientColors($index) -width $channelWidthForMaps
               }
            }
	      }
	   }
	   return
   }

   if {$mapDisplayType1 == "simulatorBandwidth"} {
	   #Instance objects for bandwidth maps
      foreach {inst cell} [array get instCellArr] {
         if {[info exists instObjectArr($inst)]} {
	         set tag [lindex $instObjectArr($inst) [expr [lsearch $instObjectArr($inst) "-tag"] + 1]]
			   set item [$c find withtag $tag]
			   set index -1
	         if {[regexp $masterRegex $cell] || [regexp $slaveRegex $cell] || [regexp $ddrRegex $cell]} {
			      foreach {requiredReadBW requiredWriteBW achievedReadBW achievedWriteBW} $bwInfoArr($inst) {break} 
			      switch $mapDisplayType1 {
					   "simulatorBandwidth" {
					      switch $mapDisplayType2 {
					         "read" {set index [findIndexForBW $requiredReadBW $achievedReadBW]}
					         "write" {set index [findIndexForBW $requiredWriteBW $achievedWriteBW]}
					         default {}
					      }
					   }
					}
	         } elseif {[regexp $switchRegex $cell]} {
	            set index -1
	         }
            if {$index == -1} {
   			   $c itemconfigure $item -fill $passFailMapGradientColors($index) -stipple "" 
            } else {
               if {$heatMapSettings(bwRange$index)} {
   			      $c itemconfigure $item -fill $passFailMapGradientColors($index) -stipple "" 
               } else {
   			      $c itemconfigure $item -fill $passFailMapGradientColors(-1) -stipple "" 
               }
            }
		   }
      }
	   return
   }
   
   if {$mapDisplayType1 == "compilerBandwidth"} {
	   #Channel objects for bandwidth maps
      foreach {k v} [array get compilerBWArr] {
         if {[info exists channelObjectArr($k)]} {
	         set tag [lindex $channelObjectArr($k) [expr [lsearch $channelObjectArr($k) "-tag"] + 1]]
			   set item [$c find withtag $tag]
			   set index -1
            set index [findIndexForBW $compilerBWDenominator $v]
            if {$index != -1} {
               if {$heatMapSettings(bwRange$index)} {
   			      $c itemconfigure $item -fill $passFailMapGradientColors($index) -width $channelWidthForMaps 
               }
            }
		   }
      }
      return
   }
}

proc findIndexForUtilization {val} {
   global numColorGradients
   set utilbinsize [expr 100/$numColorGradients]
   return [expr int(floor($val/double($utilbinsize)))]
}

proc findIndexForBW {required achieved} {

   if {$required == 0} {return -1}

   set ratio [expr $achieved/double($required)]

   if {$ratio >= 1} {return 0}
   if {$ratio < 1 && $ratio >= 0.8} {return 1}
   if {$ratio < 0.8} {return 2}
}
#################################################################


#--------------------------------
# Tcl prompt utilities
#--------------------------------
proc initTclCommandsStack {} {
   global tclCommandStack
   global tclCommandStackSize
   global tclCommandStackPointer

   set tclCommandStackSize 0
   set tclCommandStackPointer -1
}

proc pushTclCommand {command} {
   global tclCommandStack
   global tclCommandStackSize
   global tclCommandStackPointer

   set tclCommandStack($tclCommandStackSize) $command
   incr tclCommandStackSize
   set tclCommandStackPointer $tclCommandStackSize
}

proc showTclCommandUp {} {
   global tclPromptEval
   global tclCommandStack
   global tclCommandStackSize
   global tclCommandStackPointer

   incr tclCommandStackPointer -1
   
   if {$tclCommandStackPointer > -1} {
         $tclPromptEval(text) delete 0 end
         $tclPromptEval(text) insert 0 $tclCommandStack($tclCommandStackPointer)
   } else {
      $tclPromptEval(text) delete 0 end
      set tclCommandStackPointer -1
   }
}

proc showTclCommandDown {} {
   global tclPromptEval
   global tclCommandStack
   global tclCommandStackSize
   global tclCommandStackPointer

   incr tclCommandStackPointer

   if {$tclCommandStackPointer < $tclCommandStackSize} {
         $tclPromptEval(text) delete 0 end
         $tclPromptEval(text) insert 0 $tclCommandStack($tclCommandStackPointer)
   } else {
      $tclPromptEval(text) delete 0 end
      set tclCommandStackPointer $tclCommandStackSize
   }
}

proc processSourcedCommands {command} {
   regsub -all {\s+} $command " " command

   if {[llength $command] > 2} {showOnLog "Invalid arguments to source" error; return 0}
   set filename [lindex $command 1]

   set F [open $filename r]
   while {[gets $F line] >= 0} {
      if {[regexp {^#} $line]} {continue}
      if {[regexp {^\s*$} $line]} {continue}
      regsub -all {\s+} $line " " line
      Eval $line
   }
   close $F
}

proc EvalTypein {} {
   # Evaluate everything between limit and end as a Tcl command
   global tclPromptEval

   set command [$tclPromptEval(text) get]
   set command [string trim $command]
   pushTclCommand $command
   Eval $command
}

proc Eval {command} {
   global tclPromptEval
   
   if {[lindex $command 0] == "source"} {
      processSourcedCommands $command
   } elseif {[lsearch -exact [info commands] [lindex $command 0]] != -1} {
      if [info complete $command] {
         EvalTclCommand $command
         $tclPromptEval(text) delete 0 end
      }
   } else {
      $tclPromptEval(text) delete 0 end
      ProcessTclCommand $command
   }

}

proc EvalTclCommand {command} {
   # Evaluate a command and display its result
   global tclPromptEval
   global log

   $log config -state normal
   $log insert end $command output
   $log insert end \n output
   if [catch {$tclPromptEval(slave) eval $command} result] {
      $log insert end $result error
   } else {
      $log insert end $result result
   }
   if {$result != ""} {
      $log insert end \n
   }
   $log see end
   $log config -state disabled
}

proc SlaveInit {slave} {
   # Create and initialize the slave interpreter
   interp create $slave
   #load {} Tk $slave
   interp alias $slave reset {} ResetAlias $slave
   interp alias $slave puts {} PutsAlias $slave
   return $slave
}

proc ResetAlias {slave} {
   # The reset alias deletes the slave and starts a new one
   interp delete $slave
   SlaveInit $slave
}

proc PutsAlias {slave args} {
   global log

   # The puts alias puts stdout and stderr into the text widget
   if {[llength $args] > 3} {
      error "invalid arguments"
   }
   set newline "\n"
   if {[string match "-nonewline" [lindex $args 0]]} {
      set newline ""
      set args [lreplace $args 0 0]
   }
   if {[llength $args] == 1} {
      set chan stdout
      set string [lindex $args 0]$newline
   } else {
      set chan [lindex $args 0]
      set string [lindex $args 1]$newline
   }
   if [regexp (stdout|stderr) $chan] {
      $log config -state normal
      $log insert end $string result 
      $log see end
      $log config -state disabled 
   } else {
      puts -nonewline $chan $string
   }
}

proc displayHelpForTclCommand {cmd} {
   global tclCommands

   if {[info exists tclCommands($cmd)]} {
      showOnLog "Usage"
      showOnLog "$cmd [dict get $tclCommands($cmd) Usage]"
   }
}

proc RegisterTclCommands {slave} {
   global tclCommands
   global tclPromptEval

   set tclCommands(help) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "" \
                                         "Command" ""]


   set tclCommands(compile) [dict create "RequiredOptions" [list "-ntf" "-npf"] \
                                         "Defaults" [list] \
                                         "Usage" "-ntf <ntf file name> ?-help?" \
                                         "Command" ""]

   set tclCommands(get_net_data) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "-name <net name> | -from <inst name> | -to <inst name> | -tc <traffic class> ?-help?" \
                                         "Command" ""]

   set tclCommands(get_port_data) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "-inst <inst name> -port <port name> \[-utilization -raw|-effective -read|-write\] | \[-bandwidth -read|-write\] | \[-detail\] ?-help?" \
                                         "Command" ""]

   set tclCommands(get_simulation_log) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "" \
                                         "Command" ""]

   set tclCommands(get_compiler_log) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "" \
                                         "Command" ""]

   set tclCommands(show_simulation_map) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "\[-utilization -raw|-effective -read|-write\] | \[-bandwidth -read|-write\] | -nets ?-help?" \
                                         "Command" ""]

   #set tclCommands(show_compiler_map) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "-bandwidth | -nets ?-help?" \
                                         "Command" ""]

   set tclCommands(highlight_region_instances) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "-name <region name> ?-help?" \
                                         "Command" ""]

   set tclCommands(clear_highlights) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "" \
                                         "Command" ""]

   set tclCommands(plot_latency) [dict create "RequiredOptions" [list ""] \
                                         "Defaults" [list] \
                                         "Usage" "-name <NMU physical name> ?-help?" \
                                         "Command" ""]

   myParray tclCommands
}

proc ProcessTclCommand {command} {
   global tclCommands
   global log
   
   $log config -state normal
   $log config -state normal
   $log insert end $command output
   $log insert end \n output
   $log see end
   $log config -state disabled

   set cmd [lindex $command 0]
   if {![info exists tclCommands($cmd)]} {
      showOnLog "invalid command name \"$cmd\"" error
      return
   }

   switch $cmd {
      "help" {RunTclCommand_Help $command}
      "compile" {RunTclCommand_Compile $command}
      "get_net_data" {RunTclCommand_GetNetData $command}
      "get_port_data" {RunTclCommand_GetPortData $command}
      "get_compiler_log" {RunTclCommand_GetCompilerLog $command}
      "get_simulation_log" {RunTclCommand_GetSimulationLog $command}
      "show_simulation_map" {RunTclCommand_ShowSimMap $command}
      "show_compiler_map" {RunTclCommand_ShowCompilerMap $command}
      "highlight_region_instances" {RunTclCommand_HighlightRegionInstances $command}
      "clear_highlights" {RunTclCommand_ClearHighlights $command}
      "plot_latency" {RunTclCommand_PlotLatency $command}
   }

   return
}


proc RunTclCommand_Help {command} {
   global tclCommands
   
   set cmd [lindex $command 0]

   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   showOnLog "--------------------------"
   showOnLog "Available TCL commands-"
   showOnLog "--------------------------"
   foreach n [lsort [array names tclCommands]] {
      showOnLog $n
   }
   showOnLog "--------------------------"
   showOnLog "Please use -help with a TCL command to get the usage options"
}


proc RunTclCommand_Compile {command} {
   global runMode
   global ntfFile
   global importFile

   set cmd [lindex $command 0]
   
   set runMode "compile"
   if {[info exists ntfFile]} {unset ntfFile}
   if {[info exists importFile]} {unset importFile}

   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-ntf" {set ntfFile $next; incr i}
         "-import" {set importFile $next; incr i}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   RunCompilerWrapper
}

proc RunTclCommand_GetNetData {command} {
   set cmd [lindex $command 0]
   
   if {[llength $command] == 1} {displayHelpForTclCommand $cmd; return 0}
   
   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-name" {doSearch $next; return}
         "-from" {doSearch "f:$next"; return}
         "-to" {doSearch "t:$next"; return}
         "-tc" {doSearch "tc:$next"; return}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }
}

proc RunTclCommand_GetPortData {command} {
   global simulationInfoArr
   global simulationPostInfoArr
   
   set cmd [lindex $command 0]
  
   #Defaults
   set utilization 0
   set raw 0
   set effective 0
   set read 0
   set write 0
   set bandwidth 0
   set detail 0

   #Get Option values
   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-inst" {set inst $next; incr i}
         "-port" {set port $next; incr i}
         "-utilization" {set utilization 1}
         "-raw" {set raw 1}
         "-effective" {set effective 1}
         "-read" {set read 1}
         "-write" {set write 1}
         "-bandwidth" {set bandwidth 1}
         "-detail" {set detail 1}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   #Process options
   if {![info exists inst]} {
      showOnLog "Please specify a inst name" error
      displayHelpForTclCommand $cmd; return 0
   }
   if {![info exists port]} {
      showOnLog "Please specify a port name" error
      displayHelpForTclCommand $cmd; return 0
   }
   if {($detail == 0) && ($utilization == 0) && ($bandwidth == 0)} {
      set detail 1
   }
   if {$detail || $utilization || $bandwidth} {
      if {$detail && $utilization} {
         showOnLog "Please only specify one of -detail or -utilization" error
         displayHelpForTclCommand $cmd; return 0
      }
      if {$detail && $bandwidth} {
         showOnLog "Please only specify one of -detail or -bandwidth" error
         displayHelpForTclCommand $cmd; return 0
      }
      if {$utilization && $bandwidth} {
         showOnLog "Please only specify one of -utilization or -bandwidth" error
         displayHelpForTclCommand $cmd; return 0
      }
      if {$detail && $utilization && $bandwidth} {
         showOnLog "Please only specify one of -detail or -utilization or -bandwidth" error
         displayHelpForTclCommand $cmd; return 0
      }
      if {$utilization} {
         if {!$raw && !$effective} {
            set raw 1
            set effective 1
         }
         if {!$read && !$write} {
            set read 1
            set write 1
         }
      }
      if {$bandwidth} {
         if {!$read && !$write} {
            set read 1
            set write 1
         }
      }
   }

   if {$detail} {
      handleChannelSelection "$inst,$port"
      return
   }
   if {$utilization || $bandwidth} {
      set foundmatch 0
      foreach {k v} [array get simulationInfoArr] {
        set minst [lindex [split $k ","] 0]
        set mport [lindex [split $k ","] 1]
        set sinst [lindex [split $k ","] 2]
        set sport [lindex [split $k ","] 3]
        if {"$inst,$port" == "$minst,$mport" || "$inst,$port" == "$sinst,$sport"} {
           foreach {rawRdUtilization rawWrUtilization effRdUtilization effWrUtilization rdBandwidth wrBandwidth} $simulationPostInfoArr($k) {break}
           set foundmatch 1
        }
      }
      
      if {$foundmatch} {
         if {$utilization} {
            if {$raw} {
               if {$read} {showOnLog "Raw Read Utilization % : $rawRdUtilization"}
               if {$write} {showOnLog "Raw Write Utilization % : $rawWrUtilization"}
            } 
            if {$effective} {
               if {$read} {showOnLog "Effective Read Utilization % : $effRdUtilization"}
               if {$write} {showOnLog "Effective Write Utilization % : $effWrUtilization"}
            }
         } elseif {$bandwidth} {
            if {$read} {showOnLog "Read Bandwidth (MB/s): $rdBandwidth"}
            if {$write} {showOnLog "Write Bandwidth (MB/s): $wrBandwidth"}
         }
      } else {
         showOnLog "No simulation data found for $inst, $port" error
      }
      return
   }
}

proc RunTclCommand_GetCompilerLog {command} {
   global compilerOutFile 
   
   set cmd [lindex $command 0]
  
   #Get Option values
   if {[llength $command] > 1} {
      showOnLog "unrecognized options [lrange $command 1 end]" error; displayHelpForTclCommand $cmd; return 0
   }
   showFileOnConsole $compilerOutFile
}

proc RunTclCommand_GetSimulationLog {command} {
   global simulatorOutFile 
   
   set cmd [lindex $command 0]
  
   #Get Option values
   if {[llength $command] > 1} {
      showOnLog "unrecognized options [lrange $command 1 end]" error; displayHelpForTclCommand $cmd; return 0
   }
   showFileOnConsole $simulatorOutFile
}

proc RunTclCommand_ShowSimMap {command} {
   global mapDisplayType1
   global mapDisplayType2

   set cmd [lindex $command 0]
 
   #Defaults
   set utilization 0
   set raw 0
   set effective 0
   set read 0
   set write 0
   set bandwidth 0
   set nets 0

   #Get Option values
   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-utilization" {set utilization 1}
         "-raw" {set raw 1}
         "-effective" {set effective 1}
         "-read" {set read 1}
         "-write" {set write 1}
         "-bandwidth" {set bandwidth 1}
         "-nets" {set nets 1}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   #Process options
   if {($utilization == 0) && ($bandwidth == 0) && ($nets == 0)} {
      showOnLog "Please specify alteast one of -bandwidth or -utilization or -nets" error
      displayHelpForTclCommand $cmd; return 0
   }
   if {$utilization || $bandwidth || $nets} {
      if {$utilization && $bandwidth && $nets} {
         showOnLog "Please only specify one of -utilization or -bandwidth or -nets" error
         displayHelpForTclCommand $cmd; return 0
      }
      if {$utilization} {
         if {$raw && $effective} {
            showOnLog "Please only specify one of -raw or -effective" error
            displayHelpForTclCommand $cmd; return 0
         }
         if {$read && $write} {
            showOnLog "Please only specify one of -read or -write" error
            displayHelpForTclCommand $cmd; return 0
         }
         if {!$raw && !$effective} {
            set raw 1
         }
         if {!$read && !$write} {
            set write 1
         }
         if {$raw} {
            set mapDisplayType1 "rawutil"
         } elseif {$effective} {
            set mapDisplayType1 "effectiveutil"
         }
         if {$read} {
            set mapDisplayType2 "read"
         } elseif {$write} {
            set mapDisplayType2 "write"
         }
      }
      if {$bandwidth} {
         if {$read && $write} {
            showOnLog "Please only specify one of -read or -write" error
            displayHelpForTclCommand $cmd; return 0
         }
         if {!$read && !$write} {
            set write 1
         }
         set mapDisplayType1 "simulatorBandwidth"
         if {$read} {
            set mapDisplayType2 "read"
         } elseif {$write} {
            set mapDisplayType2 "write"
         }
      }
      if {$nets} {
         set mapDisplayType1 "none"
      }
   }
   ShowMapWrapper
}

proc RunTclCommand_ShowCompilerMap {command} {
   global mapDisplayType1
   global mapDisplayType2

   set cmd [lindex $command 0]
 
   #Defaults
   set bandwidth 0
   set nets 0

   #Get Option values
   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-bandwidth" {set bandwidth 1}
         "-nets" {set nets 1}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   #Process options
   if {($bandwidth == 0) && ($nets == 0)} {
      showOnLog "Please specify alteast one of -bandwidth or -nets" error
      displayHelpForTclCommand $cmd; return 0
   }
   if {$bandwidth || $nets} {
      if {$bandwidth && $nets} {
         showOnLog "Please only specify one of -bandwidth or -nets" error
         displayHelpForTclCommand $cmd; return 0
      }
      if {$bandwidth} {
         set mapDisplayType1 "compilerBandwidth"
      }
      if {$nets} {
         set mapDisplayType1 "none"
      }
   }
   ShowMapWrapper
}

proc RunTclCommand_HighlightRegionInstances {command} {
   global regionArr
   global instObjectArr
   global highlightObjectArr
   global highlighttag
   global c

   set cmd [lindex $command 0]
 
   #Defaults
   set rname ""

   #Get Option values
   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-name" {set rname $next; incr i}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   #Process option values
   if {$rname == ""} {
      showOnLog "Please specify a valid -name" error
      displayHelpForTclCommand $cmd; return 0
   }

   if {![info exists regionArr($rname)]} {
      showOnLog "Region \"$rname\" doesn't exist" error
      return 0
   } else {
      set instances $regionArr($rname)
      array unset highlightObjectArr
      foreach inst $instances {
         set highlightObjectArr($inst) "[list [lindex $instObjectArr($inst) 0]] -outline yellow -tag $highlighttag -activeoutline white -activewidth 3 -width 5"
      }
      redraw $c
   }
}

proc RunTclCommand_ClearHighlights {command} {
   set cmd [lindex $command 0]
  
   #Get Option values
   if {[llength $command] > 1} {
      showOnLog "unrecognized options [lrange $command 1 end]" error; displayHelpForTclCommand $cmd; return 0
   }

   clearCanvasHighlights
}

proc RunTclCommand_PlotLatency {command} {
   global outDir

   set cmd [lindex $command 0]
 
   #Defaults
   set nmuName ""

   #Get Option values
   for {set i 1} {$i < [llength $command]} {incr i} {
      set current [lindex $command $i]
      set next [lindex $command [expr $i + 1]]
      switch $current {
         "-name" {set nmuName $next; incr i}
         "-help" {displayHelpForTclCommand $cmd; return 0}
         default {showOnLog "unrecognized option $current" error; displayHelpForTclCommand $cmd; return 0}
      }
   }

   #Process option values
   if {$nmuName == ""} {
      showOnLog "Please specify a valid -name" error
      displayHelpForTclCommand $cmd; return 0
   }

   set filename "$outDir/$nmuName.lat"

   if {![file exists $filename]} {
      showOnLog "Latency data file $filename doesn't exist" error
      return 0
   } else {
      showLatencyPlot $filename
   }
}

#---------------------------------
# Json utilities
#---------------------------------
namespace eval json {}

proc json::getc {{txtvar txt}} {
    # pop single char off the front of the text
    upvar 1 $txtvar txt
    if {$txt eq ""} {
      return -code error "unexpected end of text"
    }

    set c [string index $txt 0]
    set txt [string range $txt 1 end]
    return $c
}

proc json::json2dict {txt} {
    return [_json2dict]
}

proc json::_json2dict {{txtvar txt}} {
    upvar 1 $txtvar txt

    set state TOP

    set txt [string trimleft $txt]
    while {$txt ne ""} {
      set c [string index $txt 0]

      # skip whitespace
      while {[string is space $c]} {
          getc
          set c [string index $txt 0]
      }

   if {$c eq "\{"} {
       # object
       switch -- $state {
      TOP {
          # we are dealing with an Object
          getc
          set state OBJECT
          set dictVal [dict create]
      }
      VALUE {
          # this object element's value is an Object
          dict set dictVal $name [_json2dict]
          set state COMMA
      }
      LIST {
          # next element of list is an Object
          lappend listVal [_json2dict]
          set state COMMA
      }
      default {
          return -code error "unexpected open brace in $state mode"
      }
       }
   } elseif {$c eq "\}"} {
       getc
       if {$state ne "OBJECT" && $state ne "COMMA"} {
      return -code error "unexpected close brace in $state mode"
       }
       return $dictVal
   } elseif {$c eq ":"} {
       # name separator
       getc

       if {$state eq "COLON"} {
      set state VALUE
       } else {
      return -code error "unexpected colon in $state mode"
       }
   } elseif {$c eq ","} {
       # element separator
       if {$state eq "COMMA"} {
      getc
      if {[info exists listVal]} {
          set state LIST
      } elseif {[info exists dictVal]} {
          set state OBJECT
      }
       } else {
      return -code error "unexpected comma in $state mode"
       }
   } elseif {$c eq "\""} {
       # string
       # capture quoted string with backslash sequences
       set reStr {(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\"))}
       set string ""
       if {![regexp $reStr $txt string]} {
      set txt [string replace $txt 32 end ...]
      return -code error "invalid formatted string in $txt"
       }
       set txt [string range $txt [string length $string] end]
       # chop off outer ""s and substitute backslashes
       # This does more than the RFC-specified backslash sequences,
       # but it does cover them all
       set string [subst -nocommand -novariable \
             [string range $string 1 end-1]]

       switch -- $state {
      TOP {
          return $string
      }
      OBJECT {
          set name $string
          set state COLON
      }
      LIST {
          lappend listVal $string
          set state COMMA
      }
      VALUE {
          dict set dictVal $name $string
          unset name
          set state COMMA
      }
       }
   } elseif {$c eq "\["} {
       # JSON array == Tcl list
       switch -- $state {
      TOP {
          getc
          set state LIST
      }
      LIST {
          lappend listVal [_json2dict]
          set state COMMA
      }
      VALUE {
          dict set dictVal $name [_json2dict]
          set state COMMA
      }
      default {
          return -code error "unexpected open bracket in $state mode"
      }
       }
   } elseif {$c eq "\]"} {
       # end of list
       getc
       if {![info exists listVal]} {
      #return -code error "unexpected close bracket in $state mode"
      # must be an empty list
      return ""
       }

       return $listVal
   } elseif {0 && $c eq "/"} {
       # comment
       # XXX: Not in RFC 4627
       getc
       set c [getc]
       switch -- $c {
      / {
          # // comment form
          set i [string first "\n" $txt]
          if {$i == -1} {
         set txt ""
          } else {
         set txt [string range $txt [incr i] end]
          }
      }
      * {
          # /* comment */ form
          getc
          set i [string first "*/" $txt]
          if {$i == -1} {
         return -code error "incomplete /* comment"
          } else {
         set txt [string range $txt [incr i] end]
          }
      }
      default {
          return -code error "unexpected slash in $state mode"
      }
       }
   } elseif {[string match {[-0-9]} $c]} {
       # one last check for a number, no leading zeros allowed,
       # but it may be 0.xxx
       string is double -failindex last $txt
       if {$last > 0} {
      set num [string range $txt 0 [expr {$last - 1}]]
      set num [string trim $num]
      set txt [string range $txt $last end]

      switch -- $state {
          TOP {
         return $num
          }
          LIST {
         lappend listVal $num
         set state COMMA
          }
          VALUE {
         dict set dictVal $name $num
         set state COMMA
          }
          default {
         getc
         return -code error "unexpected number '$c' in $state mode"
          }
      }
       } else {
      getc
      return -code error "unexpected '$c' in $state mode"
       }
   } elseif {[string match {[ftn]} $c]
        && [regexp {^(true|false|null)} $txt val]} {
       # bare word value: true | false | null
       set txt [string range $txt [string length $val] end]

       switch -- $state {
      TOP {
          return $val
      }
      LIST {
          lappend listVal $val
          set state COMMA
      }
      VALUE {
          dict set dictVal $name $val
          set state COMMA
      }
      default {
          getc
          return -code error "unexpected '$c' in $state mode"
      }
       }
   } else {
       # error, incorrect format or unexpected end of text
       return -code error "unexpected '$c' in $state mode"
   }
    }
}

#=====================================================
# JSON write utilities
namespace eval ::json::write {
    namespace export \
   string array array_simple object indented aligned

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::json::write::indented {bool} {
    if {![::string is boolean -strict $bool]} {
   return -code error "Expected boolean, got \"$bool\""
    }
    variable indented $bool
    return
}

proc ::json::write::aligned {bool} {
    if {![::string is boolean -strict $bool]} {
   return -code error "Expected boolean, got \"$bool\""
    }
    variable aligned $bool

    if {$aligned} {
   variable indented 1
    }
    return
}

proc ::json::write::string {s} {
    variable quotes
    return "\"[::string map $quotes $s]\""
}

proc ::json::write::array_simple {args} {
    # always compact form.
    return "\[[join $args ,]\]"
}

proc ::json::write::array {args} {
    # always compact form.
   # return "\[[join $args ,]\]"
   set count 0
   foreach elem [lindex $args 0] {
      if {$count == 0} {
         append out "" $elem
         incr count
      } else {
         append out ",\n" $elem
      }
   }
   return "\[\n$out\n\]"
}

proc ::json::write::object {args} {
    # The dict in args maps string keys to json-formatted data. I.e.
    # we have to quote the keys, but not the values, as the latter are
    # already in the proper format.

    variable aligned
    variable indented

    set dict {}
    foreach {k v} $args {
   lappend dict [string $k] $v
    }

    if {$aligned} {
   set max [MaxKeyLength $dict]
    }

    if {$indented} {
   set content {}
   foreach {k v} $dict {
       if {$aligned} {
      set k [AlignLeft $max $k]
       }
       if {[::string match *\n* $v]} {
      # multi-line value
      lappend content "    $k : [Indent $v {    } 1]"
       } else {
      # single line value.
      lappend content "    $k : $v"
       }
   }
   if {[llength $content]} {
       return "\{\n[join $content ,\n]\n\}"
   } else {
       return "\{\}"
   }
    } else {
   # ultra compact form.
   set tmp {}
   foreach {k v} $dict {
       lappend tmp "$k:$v"
   }
   return "\{[join $tmp ,]\}"
    }
}

# ### ### ### ######### ######### #########
## Internals.

proc ::json::write::Indent {text prefix skip} {
    set pfx ""
    set result {}
    foreach line [split $text \n] {
   if {!$skip} { set pfx $prefix } else { incr skip -1 }
   lappend result ${pfx}$line
    }
    return [join $result \n]
}

proc ::json::write::MaxKeyLength {dict} {
    # Find the max length of the keys in the dictionary.

    set lengths 0 ; # This will be the max if the dict is empty, and
          # prevents the mathfunc from throwing errors for
          # that case.

    foreach str [dict keys $dict] {
   lappend lengths [::string length $str]
    }

    return [tcl::mathfunc::max {*}$lengths]
}

proc ::json::write::AlignLeft {fieldlen str} {
    return [format %-${fieldlen}s $str]
    #return $str[::string repeat { } [expr {$fieldlen - [::string length $str]}]]
}

# ### ### ### ######### ######### #########

namespace eval ::json::write {
    # Configuration of the layout to write.

    # indented = boolean. objects are indented.
    # aligned  = boolean. object keys are aligned vertically.

    # aligned  => indented.

    # Combinations of the format specific entries
    # I A |
    # - - + ---------------------
    # 0 0 | Ultracompact (no whitespace, single line)
    # 1 0 | Indented
    # 0 1 | Not possible, per the implications above.
    # 1 1 | Indented + vertically aligned keys
    # - - + ---------------------

    variable indented 1
    variable aligned  1

    variable quotes \
   [list "\"" "\\\"" / \\/ \\ \\\\ \b \\b \f \\f \n \\n \r \\r \t \\t]
}
#------------------------------------------------
#------------------------------------------------
#------------------------------------------------
#------------------------------------------------

proc parseJsonData {fileName} {
global jsonOutFileOrig
global jsonOutFilePruned
global masterRegex
global slaveRegex
global ddrRegex
global switchRegex
global portConnectionArr
global instPlacementArr
global pinArr
global typeToLocArr 
global instCellArr
global ddrPairArr
global ddrPortArr
global ddrPortReverseMapArr
global ddrPortPairArr
global nRows
global nCols
set nRows 0
set nCols 0

if {[info exists portConnectionArr]} {array unset portConnectionArr}
if {[info exists instPlacementArr]} {array unset instPlacementArr}
if {[info exists pinArr]} {array unset pinArr}
if {[info exists typeToLocArr ]} {array unset typeToLocArr }
if {[info exists instCellArr]} {array unset instCellArr}
if {[info exists typeArr]} {array unset typeArr}
if {[info exists ddrPairArr]} {array unset ddrPairArr}
if {[info exists ddrPortArr]} {array unset ddrPortArr}
if {[info exists ddrPortReverseMapArr]} {array unset ddrPortReverseMapArr}
if {[info exists ddrPortPairArr]} {array unset ddrPortPairArr}


set F [open $fileName r]
set jsonFile [read $F]
close $F
set jsonData [json::json2dict $jsonFile]
#myPuts "[dict get $jsonData Conns]"
#myPuts "[dict get $jsonData Insts]"
#myPuts "[dict get $jsonData Modules]"

dict for {key values} $jsonData {
    myPuts "==============================================="
    myPuts "Key : $key"
    if {$key == "noc_connections"} {
    updateSplashScreenUpdateText "Processing NoC Channels ..."
      for {set i 0} {$i < [llength $values]} {incr i} {
         set stubbed "false"
         dict for {k v} [lindex $values $i] {
            myPuts "$k, $v"
            set v [lindex $v 0]
            if {$k == "to_port"} {
               for {set j 0} {$j < [llength $v]} {incr j} {
                  set elem [lindex $v $j] 
                  if {$elem == "instance"} {
                     set toInst [lindex $v [expr $j + 1]]
                  } elseif {$elem  == "port_name"} {
                     set toPort [lindex $v [expr $j + 1]]
                  }
               }
            } elseif {$k == "from_port"} {
               for {set j 0} {$j < [llength $v]} {incr j} {
                  set elem [lindex $v $j] 
                  if {$elem == "instance"} {
                     set fromInst [lindex $v [expr $j + 1]]
                  } elseif {$elem  == "port_name"} {
                     set fromPort [lindex $v [expr $j + 1]]
                  }
               }
            } elseif {$k == "stubbed"} {
               set stubbed $v
            }
         }
         if {$stubbed == "false"} {
            set portConnectionArr($i) [list "$fromInst,$fromPort" "$toInst,$toPort"]
         }
         myPuts "--------------------------"
      }
    } elseif {$key == "noc_modules"} {
    updateSplashScreenUpdateText "Processing NoC Modules ..."
      for {set i 0} {$i < [llength $values]} {incr i} {
         dict for {k v} [lindex $values $i] {
            myPuts "$k, $v"
            if {$k == "in_ports"} {
               for {set j 0} {$j < [llength $v]} {incr j} {
                  set elem [lindex $v $j]
                  if {[lindex $elem 0] == "name"} {
                     lappend ports [list [lindex $elem 1] "in"]
                  }
               }
            } elseif {$k == "out_ports"} {
               for {set j 0} {$j < [llength $v]} {incr j} {
                  set elem [lindex $v $j]
                  if {[lindex $elem 0] == "name"} {
                     lappend ports [list [lindex $elem 1] "out"]
                  }
               }
            } elseif {$k == "name"} {
               set cellName $v
            }
         }
         set pinArr($cellName) $ports
         if {[info exists ports]} { unset ports }
         myPuts "--------------------------"
      }
    } elseif {$key == "noc_components"} {
    updateSplashScreenUpdateText "Processing NoC Components ..."
      for {set i 0} {$i < [llength $values]} {incr i} {
         dict for {k v} [lindex $values $i] {
            myPuts "$k, $v"
            for {set j 0} {$j < [llength $v]} {incr j} {
               set elem [lindex $v $j]
               for {set l 0} {$l < [llength $elem]} {incr l} {
                  if {[lindex $elem $l] == "name"} {
                     set instCellArr([lindex $elem [expr $l + 1]]) $k
                     set instName [lindex $elem [expr $l + 1]]
                  }
                  if {[lindex $elem $l] == "row"} {
                     set Y [lindex $elem [expr $l + 1]]
                  }
                  if {[lindex $elem $l] == "col"} {
                     set X [lindex $elem [expr $l + 1]]
                  }
                  if {[lindex $elem $l] == "region"} {
                     set region [lindex $elem [expr $l + 1]]
                  }
               }
               set instPlacementArr($instName) [list $X $Y]
               if {$nCols <= $X} {set nCols [expr $X + 1]}
               if {$nRows <= $Y} {set nRows [expr $Y + 1]}
               if {[info exists typeArr($region)]} {
                  set temp $typeArr($region)
                  set typeArr($region) [lappend temp $instName]
               } else {
                  set typeArr($region) [list $instName]
               }
            }
         }
         myPuts "--------------------------"
      }
    } else {
       myPuts "WARNING-100: Ignoring the section for $key"
    }
}
myPuts "==============================================="

myParray typeArr
# Arrange  typeToLocArr by master/slave types
foreach {k v} [array get typeArr] {
   foreach elem $v {
      if {[info exists instCellArr($elem)]} {
         if {[regexp $masterRegex $instCellArr($elem)]} {
               if {[info exists typeToLocArr($k,NMU)]} {
                  set temp $typeToLocArr($k,NMU)
                  set  typeToLocArr($k,NMU) [lappend temp $elem]
               } else {
                  set  typeToLocArr($k,NMU) [list $elem]
               }
         } elseif {[regexp $slaveRegex|$ddrRegex $instCellArr($elem)]} {
               if {[info exists typeToLocArr($k,NSU)]} {
                  set temp $typeToLocArr($k,NSU)
                  set  typeToLocArr($k,NSU) [lappend temp $elem]
               } else {
                  set  typeToLocArr($k,NSU) [list $elem]
               }
         }
      } else {
         myPuts "ERROR-203: Could not find $elem's type"
      }
   }
}
myParray typeToLocArr 


#Split the DDRs
foreach {k v} [array get portConnectionArr] {
   set frominst [lindex [split [lindex $v 0] ","] 0]
   set fromport [lindex [split [lindex $v 0] ","] 1]
   set toinst [lindex [split [lindex $v 1] ","] 0]
   set toport [lindex [split [lindex $v 1] ","] 1]
   if {$instCellArr($toinst) == $ddrRegex} {
      swap frominst toinst
      swap fromport toport
   }
   if {$instCellArr($frominst) == $ddrRegex} {
      if {![info exists ddrPairArr($frominst,$toinst)]} {
         set ddrPairArr($frominst,$toinst) "$frominst\__$fromport"
      }
      lappend ddrPortPairArr($frominst,$toinst) "$fromport"
      regsub -all {[0-9]+} $fromport "" mappedport
      set ddrPortArr($frominst,$fromport) [list $ddrPairArr($frominst,$toinst) $mappedport]
      set ddrPortReverseMapArr($ddrPairArr($frominst,$toinst),$mappedport) [list $frominst $fromport]
   }
}
myParray ddrPairArr
myParray ddrPortArr
myParray ddrPortPairArr
myParray ddrPortReverseMapArr
if {0} {
#Update typeToLocArr to account for split DDRs
if {[info exists ddrlist]} {unset ddrlist}
foreach {k v} [array get  typeToLocArr] {
   foreach elem $v {
      if {$instCellArr($elem) == $ddrRegex} {
         set ddrkey $k
         foreach key [array names ddrPairArr] {
            set name [lindex [split $key ","] 0]
            if {$name == $elem} {
               lappend ddrlist $ddrPairArr($key)
            }
         }
      }
   }
   set typeToLocArr($ddrkey) $ddrlist
}
myParray typeToLocArr 
}

#Post process
dumpJsonData $jsonOutFileOrig
pruneJsonData
dumpJsonData $jsonOutFilePruned
dumpModel
}


proc pruneJsonData {} {
   global portConnectionArr
   global instCellArr
   global masterRegex
   global slaveRegex
   global ddrRegex
   global switchRegex

   # portConnectionArr may contain instances other than Master, Slave or Switch. Ignore those.
   foreach {connectionName connections} [array get portConnectionArr] {
      set pairs [split $connections]
      set from [lindex $pairs 0]
      set fromInst [lindex [split $from ","] 0]
      myPuts "checking $fromInst"
      set fromInstCell $instCellArr($fromInst)
      if {[regexp $masterRegex $fromInstCell] || \
          [regexp $slaveRegex $fromInstCell] || \
          [regexp $ddrRegex $fromInstCell] || \
          [regexp $switchRegex $fromInstCell]} {
      } else {
         if {[info exists portConnectionArr($connectionName)]} {
            myPuts "INFO: Deleting $portConnectionArr($connectionName)"
            unset portConnectionArr($connectionName)
         }
      }

      set to [lindex $pairs 1]
      set toInst [lindex [split $to ","] 0]
      set toInstCell $instCellArr($toInst)
      if {[regexp $masterRegex $toInstCell] || \
          [regexp $slaveRegex $toInstCell] || \
          [regexp $ddrRegex $toInstCell] || \
          [regexp $switchRegex $toInstCell]} {
      } else {
         if {[info exists portConnectionArr($connectionName)]} {
            myPuts "INFO: Deleting $portConnectionArr($connectionName)"
            unset portConnectionArr($connectionName)
         }
      }
   }
}

proc dumpJsonData {fileName} {
   global instPlacementArr
   global instCellArr
   global portConnectionArr

   set OUT [open $fileName w]

   puts $OUT "#Instances"
   foreach {k v} [array get instCellArr] {
      puts $OUT "$k, $v, $instPlacementArr($k)"
   }

   puts $OUT "#Connections"
   foreach {k v} [array get portConnectionArr] {
      regsub -all {,} $v " " v 
      puts $OUT "$v"
   }

   close $OUT
}

proc dumpModel {} {
   global portConnectionArr
   global instPlacementArr
   global pinArr
   global typeArr 
   global typeToLocArr 
   global instCellArr
   global ddrPairArr
   global ddrPortArr
   global ddrPortPairArr
   global ddrPortReverseMapArr
   global outModelFile
   global masterRegex
   global slaveRegex
   global ddrRegex
   global switchRegex
   global blockTypeMapArr
   global compTypeMapArr
   global compTypeToBlockTypeArr



   #Write the model file now
   set OUT [open $outModelFile w]
   #Components section
   puts $OUT "#Components"
   puts $OUT "#<inst name> <comp type> <partition ID> <chip-region-local ID> <X> <Y>"
   set instNames [lsort -dictionary [array names instCellArr]]
   foreach k $instNames {
      set v $instCellArr($k)
      if {[regexp $masterRegex $v] || [regexp $slaveRegex $v] || [regexp $switchRegex $v]} {
         #NOTE: check the model file if any "NA"s get printed
         set compType "NA"
         foreach {type insts} [array get typeToLocArr] {
            foreach inst $insts {
               if {$k == $inst} {
                  if {[info exists compTypeMapArr($type)]} {
                     set compType $compTypeMapArr($type)
                  } else {
                     set compType $type
                  }
               }
               if {[regexp {PS_NCI} $k]} {set compType "PS_NCI"}
               if {[regexp {PS_CCI} $k]} {set compType "PS_CCI"}
               if {[regexp {PMC_NMU} $k]} {set compType "PMC_NMU"}
               if {[regexp {PMC_NSU} $k]} {set compType "PMC_NSU"}
               if {[regexp {PS_NSU} $k]} {set compType "PS_NSU"}
               if {[regexp {RPU} $k]} {set compType "PS_RPU"}
               if {[regexp {PCIE_NMU} $k]} {set compType "PCIE_NMU"}
               if {[regexp {PCIE_NSU} $k]} {set compType "PCIE_NSU"}
               if {[regexp $switchRegex $v]} {set compType "NPS"}
            }
         }
         #NOTE: check the model file is any ","s get printed
         #NOTE: writing partition-ID as 0
         #NOTE: writing chip-region-local-ID as 000000000000
         puts $OUT "$k $compType 0 000000000000 [lindex $instPlacementArr($k) 0] [lindex $instPlacementArr($k) 1]"
      }
   }

   
   #CompType
   puts $OUT "#CompTypes"
   puts $OUT "#<comp type> <block type> <ports>"
   foreach {k v} [array get compTypeToBlockTypeArr] {
      if {$k == "DDRC"} {
         #NOTE: HARDCODED entry for DDRC. It must be cross-checked by looking at ddrPortPairArr and pinArr.
         puts $OUT "DDRC SLAVE resp0 out req0 in resp1 out req1 in resp2 out req2 in resp3 out req3 in"
      } else {
         puts $OUT "$k $v [join $pinArr($blockTypeMapArr($v))]"
      }
   }

   
   #DDRC
   puts $OUT "#DDRC"
   puts $OUT "#<ddrc name> <X> <Y> <partition ID0> <addr0> <partition ID1> <addr1> <partition ID2> <addr2> <partition ID3> <addr3>"
   foreach {k v} [array get instCellArr] {
      if {[regexp $ddrRegex $v]} {
         #NOTE: writing partition-ID as 0
         #NOTE: writing chip-region-local-ID as 000000000000
         puts $OUT "$k [lindex $instPlacementArr($k) 0] [lindex $instPlacementArr($k) 1] 0 000000000000 0 000000000000 0 000000000000 0 000000000000"
      }
   }

   #Graph
   puts $OUT "#Graph"
   puts $OUT "#<inst name> <port name> <inst name> <port name> <latency>"
	foreach {k v} [array get portConnectionArr] {
      set frominst [lindex [split [lindex $v 0] ","] 0]
      set fromport [lindex [split [lindex $v 0] ","] 1]
      set toinst [lindex [split [lindex $v 1] ","] 0]
      set toport [lindex [split [lindex $v 1] ","] 1]
      #NOTE: writing latency as 0
      puts $OUT "$frominst $fromport $toinst $toport 0"
	}

   close $OUT
}

proc parseModel {filename} {
   global portConnectionArr
   global instPlacementArr
   global pinArr
   global typeArr 
   global typeToLocArr 
   global instCellArr
   global ddrPairArr
   global ddrPortArr
   global ddrPortReverseMapArr
   global nCols
   global nRows
   global blockTypeMapArr
   global compTypeMapArr
   global compTypeToBlockTypeArr

   set nCols 0
   set nRows 0

   if {[info exists portConnectionArr]} {array unset portConnectionArr}
   if {[info exists instPlacementArr]} {array unset instPlacementArr}
   if {[info exists pinArr]} {array unset pinArr}
   if {[info exists typeToLocArr]} {array unset typeToLocArr }
   if {[info exists instCellArr]} {array unset instCellArr}
   if {[info exists typeArr]} {array unset typeArr}
   if {[info exists ddrPairArr]} {array unset ddrPairArr}
   if {[info exists ddrPortArr]} {array unset ddrPortArr}
   if {[info exists ddrPortReverseMapArr]} {array unset ddrPortReverseMapArr}


   set F [open $filename r]
   set state "ignore"
   set substate "ignore"
   set graphCount 0
   while {[gets $F line] >= 0} {
      if {[regexp {^#Components} $line]} {set state "Components"}
      if {[regexp {^#CompTypes} $line]} {set state "CompTypes"}
      if {[regexp {^#DDRC} $line]} {set state "DDRC"}
      if {[regexp {^#Graph} $line]} {set state "Graph"}
      if {[regexp {^#Trafficset} $line]} {set state "Trafficset"}
      if {[regexp {^#} $line]} {continue}
      if {[regexp {^\s*$} $line]} {continue}
      regsub -all {\s+} $line " " line

      switch $state {
         "Components" {
            set X [lindex $line 4]
            set Y [lindex $line 5]
            if {$nCols <= $X} {set nCols [expr $X + 1]}
            if {$nRows <= $Y} {set nRows [expr $Y + 1]}
            set instPlacementArr([lindex $line 0]) [list $X $Y]
            set instCellArr([lindex $line 0]) [lindex $line 1]
            lappend tempTypeToLocArr([lindex $line 1]) [lindex $line 0]
         }

         "CompTypes" {
            set compTypesArr([lindex $line 0]) [lindex $line 1]
            set pinArr([lindex $line 1]) [lrange $line 2 end]
         }

         "DDRC" {
            set X [lindex $line 1]
            set Y [lindex $line 2]
            if {$nCols <= $X} {set nCols [expr $X + 1]}
            if {$nRows <= $Y} {set nRows [expr $Y + 1]}
            set instPlacementArr([lindex $line 0]) [list $X $Y]
            #NOTE: HARDCODED the cell-type as DDRC
            set instCellArr([lindex $line 0]) "DDRC"
            lappend tempTypeToLocArr(DDRC) [lindex $line 0]
         }

         "Graph" {
            set portConnectionArr($graphCount) [list "[lindex $line 0],[lindex $line 1]" "[lindex $line 2],[lindex $line 3]"]
            incr graphCount
         }

         "Trafficset" {}

         default {
            puts "ERROR-310: Unrecognized line in $filename: $line"
         }
      }
   }
   close $F


   #post-process
   foreach {k v} [array get instCellArr] {
      if {$v == "DDRC"} {
         set instCellArr($k) $blockTypeMapArr($v)
      } else {
         set instCellArr($k) $blockTypeMapArr($compTypesArr($v))
      }
   }

   foreach {k v} [array get tempTypeToLocArr] {
      if {$k == "DDRC"} {
         set typeToLocArr($k,NSU) $v
      } else {
         switch $compTypesArr($k) {
            "MASTER" {set typeToLocArr($k,NMU) $v}
            "SLAVE" {set typeToLocArr($k,NSU) $v}
            default {}
         }
      }
   }
   array unset tempTypeToLocArr


   myParray portConnectionArr
   myParray instCellArr
   myParray instPlacementArr
   myParray pinArr
   myParray typeToLocArr
}

proc parseGridCoords {fileName} {
   global nRows
   global nCols
   set nRows 0
   set nCols 0
   global instPlacementArr
   set F [open $fileName r]
   while {[gets $F line] >= 0} {
      if {[regexp {^#} $line]} {
         continue
      }
      if {[regexp {^\s*$} $line]} {continue}
      regsub -all {\s+} $line " " line
      set instName [lindex $line 0]
      set X [lindex $line 3]
      set Y [lindex $line 6]
      set instPlacementArr($instName) [list $X $Y]
      if {$nCols <= $X} {set nCols [expr $X + 1]}
      if {$nRows <= $Y} {set nRows [expr $Y + 1]}
   }
   close $F
}

proc parseRegionFile {fileName} {
   global instPlacementArr
   global regionArr 
   global regionCoordsArr 

   if {[info exists regionArr]} {array unset regionArr}
   if {[info exists regionCoordsArr]} {array unset regionCoordsArr}
   
   set F [open $fileName r]
   while {[gets $F line] >= 0} {
      if {[regexp {^#} $line]} {
         continue
      }
      if {[regexp {^\s*$} $line]} {continue}
      regsub -all {\s+} $line " " line
      set region [lindex $line 0]
      set regionArr($region) [lrange $line 1 end]
   }
   close $F

   myParray regionArr 

   foreach {k v} [array get regionArr] {
      set minX 1e6
      set minY 1e6
      set maxX 1e-6
      set maxY 1e-6
      foreach elem $v {
         if {![info exists instPlacementArr($elem)]} {
            puts "ERROR-110: $elem specified in the -region file $fileName is not present in the NOC-ADL"
            errorAndExit
         }
         set X [lindex $instPlacementArr($elem) 0]
         set Y [lindex $instPlacementArr($elem) 1]
         if {$X < $minX} {set minX $X}
         if {$Y < $minY} {set minY $Y}
         if {$X > $maxX} {set maxX $X}
         if {$Y > $maxY} {set maxY $Y}
      }
      set regionCoordsArr($k) [list $minX $minY $maxX $maxY]
   }

  myParray regionCoordsArr
}


proc parseSolution {fileName} {
   global netConnectionArr
   global ddrPortReverseMapArr
   global compilerBWArr

   if {[info exists netConnectionArr]} {array unset netConnectionArr}
   if {[info exists compilerBWArr]} {array unset compilerBWArr}
   global cumulativeStructuralLatency
   set cumulativeStructuralLatency 0
   set F [open $fileName r]
   while {[gets $F line] >= 0} {
      if {[regexp {^#} $line]} {
         continue
      }
      if {[regexp {^\s*$} $line]} {continue}
      regsub -all {\s+} $line " " line
      regsub -all {,\s+} $line "," line
      set line [split $line ","]
      myPuts "DBG-287: line = $line"
      myPuts "DBG-288: line0 = [lindex $line 0], line1 = [lindex $line 1], line2 = [lindex $line 2]"
      #Reading the following format
      foreach {netName master masterPort masterLogicalName slave slavePort slaveLogicalName VC TC CT achievedLatency reqdLatency reqdBW pairs} $line {break} 
      set cumulativeStructuralLatency [expr $cumulativeStructuralLatency + $achievedLatency]
      
      #Reverse map the split DDRs
      if {[info exists ddrPortReverseMapArr($master,$masterPort)]} {
         set mappedmaster [lindex $ddrPortReverseMapArr($master,$masterPort) 0]
         set mappedmasterPort [lindex $ddrPortReverseMapArr($master,$masterPort) 1]
         set master $mappedmaster
         set masterPort $mappedmasterPort
      }
      if {[info exists ddrPortReverseMapArr($slave,$slavePort)]} {
         set mappedslave [lindex $ddrPortReverseMapArr($slave,$slavePort) 0]
         set mappedslavePort [lindex $ddrPortReverseMapArr($slave,$slavePort) 1]
         set slave $mappedslave
         set slavePort $mappedslavePort
      }
      for {set i 0} {$i < [llength $pairs]} {set i [expr $i + 2]} {
         set inst [lindex $pairs $i]
         set port [lindex $pairs [expr $i + 1]]
         if {[info exists ddrPortReverseMapArr($inst,$port)]} {
            set mappedinst [lindex $ddrPortReverseMapArr($inst,$port) 0]
            set mappedport [lindex $ddrPortReverseMapArr($inst,$port) 1]
            set inst $mappedinst
            set port $mappedport
         }
         lappend pair "$inst,$port"
      }
      set key "$netName,$master,$masterPort,$masterLogicalName,$slave,$slavePort,$slaveLogicalName,$VC,$TC,$CT,$achievedLatency,$reqdLatency,$reqdBW"
      regsub -all {\s+} $key "" key 
      set netConnectionArr($key) $pair
      myPuts "DBG-289: pair = $pair"
      if {[info exists compilerBWArr($master,$masterPort,$slave,$slavePort)]} {
         set compilerBWArr($master,$masterPort,$slave,$slavePort) [expr $compilerBWArr($master,$masterPort,$slave,$slavePort) + $reqdBW]
      } else {
         set compilerBWArr($master,$masterPort,$slave,$slavePort) $reqdBW
      }
      unset pair
   }
   myParray netConnectionArr
   myParray compilerBWArr
   set cumulativeStructuralLatency "Total Structural Latency: $cumulativeStructuralLatency"
}

proc exportNTF {{filename ""}} {
   global userTrafficOutFile

   if {$filename == ""} {
      set types {
         {"NTF files"            .ntf}
      }   
      set filename [tk_getSaveFile -filetypes $types]
      if {![info exists filename]} {
         tk_messageBox -message "Please provide a valid filename" -type ok -icon error
         return
      }   
   }

   exportTrafficAndQos $userTrafficOutFile
   dumpNTF $filename
}

proc dumpNTF {filename} {
   global masterInfoArr
   global slaveInfoArr
   global trafficInfoArr
   global qosArr

   #nmu_list
   if {[info exists nmujsonout]} {unset nmujsonout}
   for {set i 0} {$i < [array size masterInfoArr]} {incr i} {
      set elem $masterInfoArr($i)
      foreach {name type phyloc} [split $elem ","] {break}
      if {$phyloc == "Unassigned"} {set phyloc ""}
      set communicationType "AXI_MM"
      for {set j 0} {$j < [array size trafficInfoArr]} {incr j} {
         set tinfo $trafficInfoArr($j)
         foreach {mName sName transType readQos readLat readBW writeQos writeLat writeBW} [split $tinfo ","] {break}
         if {$name == $mName || $name == $sName} {
            if {$transType == "STRM"} {
               set communicationType "STRM"
            }
         }
      }

      lappend nmujsonout [::json::write object \
                           "logical_name" [::json::write string $name] \
                           "type" [::json::write string $type] \
                           "region" [::json::write string ""] \
                           "physical_location" [::json::write string $phyloc] \
                           "communication_type" [::json::write string $communicationType] \
                           "rate_limiter" [::json::write string ""] \
                         ]
   }
   #set nmujsonout "\"nmu_list\" :  [::json::write array $nmujsonout]"
   myPuts "$nmujsonout"

   #nsu_list
   if {[info exists nsujsonout]} {unset nsujsonout}
   for {set i 0} {$i < [array size slaveInfoArr]} {incr i} {
      set elem $slaveInfoArr($i)
      foreach {name type phyloc} [split $elem ","] {break}
      if {$phyloc == "Unassigned"} {set phyloc ""}
      set communicationType "AXI_MM"
      for {set j 0} {$j < [array size trafficInfoArr]} {incr j} {
         set tinfo $trafficInfoArr($j)
         foreach {mName sName transType readQos readLat readBW writeQos writeLat writeBW} [split $tinfo ","] {break}
         if {$name == $mName || $name == $sName} {
            if {$transType == "STRM"} {
               set communicationType "STRM"
            }
         }
      }
      lappend nsujsonout [::json::write object \
                           "logical_name" [::json::write string $name] \
                           "type" [::json::write string $type] \
                           "region" [::json::write string ""] \
                           "physical_location" [::json::write string $phyloc] \
                           "communication_type" [::json::write string $communicationType] \
                         ]
   }
   #set nsujsonout "\"nsu_list\" :  [::json::write array $nsujsonout]"
   myPuts "$nsujsonout"

   #traffic_info
   if {[info exists trafficjsonout]} {unset trafficjsonout}
   for {set i 0} {$i < [array size trafficInfoArr]} {incr i} {
      set elem $trafficInfoArr($i)
      foreach {mName sName transType readQos readLat readBW writeQos writeLat writeBW} [split $elem ","] {break}
      foreach {qk qv} [array get qosArr] {
         if {$readQos == $qk} {set readQos $qv}
         if {$writeQos == $qk} {set writeQos $qv}
      }
      lappend trafficjsonout [::json::write object \
                           "path" [::json::write array [list [::json::write object "nsu" [::json::write array_simple [::json::write object "name" \"$sName\"]]] [::json::write object "nmu" [::json::write array_simple [::json::write object "name" \"$mName\"]]]]] \
                           "read_requirements" [::json::write array [list [::json::write object "latency" \"$readLat\" "bandwidth" \"$readBW\" "traffic_class" \"$readQos\"] [::json::write object "traffic_generator" [::json::write array [list [::json::write object "pattern" \"\"] [::json::write object "parameters" [::json::write array [::json::write string ""]]]]]]]] \
                           "write_requirements" [::json::write array [list [::json::write object "latency" \"$writeLat\" "bandwidth" \"$writeBW\" "traffic_class" \"$writeQos\"] [::json::write object "traffic_generator" [::json::write array [list [::json::write object "pattern" \"\"] [::json::write object "parameters" [::json::write array [::json::write string ""]]]]]]]] \
                           ]

   }
   #set trafficjsonout "\"traffic_info\" :  [::json::write array $trafficjsonout]"
   myPuts "$trafficjsonout"


   #Final output string
   set finalJsonOut [::json::write object "device" [::json::write array_simple [::json::write object "name" \"sample_device\"]] \
      "version" \"0.21\" \
      "nmu_list" [::json::write array $nmujsonout] \
      "nsu_list" [::json::write array $nsujsonout] \
      "traffic_info" [::json::write array $trafficjsonout] \
   ]

   set OUT [open $filename w]
   puts $OUT $finalJsonOut
   close $OUT
}

proc dumpNPF {} {
   global netConnectionArr
   global instCellArr
   global masterRegex
   global slaveRegex
   global ddrRegex
   global switchRegex
   global ddrPortArr
   global npfOutFile
   global nocadlFile
   global nmuConfigArr
   global nsuConfigArr
   global env
   global outDir

   if {[info exists nmuConfigArr]} {array unset nmuConfigArr}
   if {[info exists nsuConfigArr]} {array unset nsuConfigArr}
   if {[info exists switchConfigArr]} {array unset switchConfigArr}
   if {[info exists switchRtTableArr]} {array unset switchRtTableArr}
   if {[info exists rtPathArr]} {array unset rtPathArr}

   foreach {k v} [array get netConnectionArr] {
      set k [split $k ","]
      foreach {netName from fromPort fromLogicalName to toPort toLogicalName VC TC CT achievedLatency reqdLatency reqdBW} $k {break}
      set rtPathArr($v) 1

      if {[regexp $masterRegex $instCellArr($from)]} {
         set nmuConfigArr($fromLogicalName) $from
      } elseif {[regexp $slaveRegex $instCellArr($from)]} {
         set nsuConfigArr($fromLogicalName) $from
      } elseif {[regexp $ddrRegex $instCellArr($from)]} {
         set nsuConfigArr($fromLogicalName) [lindex $ddrPortArr($from,$fromPort) 0]
      }
      if {[regexp $masterRegex $instCellArr($to)]} {
         set nmuConfigArr($toLogicalName) $to
      } elseif {[regexp $slaveRegex $instCellArr($to)]} {
         set nsuConfigArr($toLogicalName) $to
      } elseif {[regexp $ddrRegex $instCellArr($to)]} {
         set nsuConfigArr($toLogicalName) [lindex $ddrPortArr($to,$toPort) 0]
      }

      foreach pair $v {
         set inst [lindex [split $pair ","] 0]
         set port [lindex [split $pair ","] 1]
         if {[regexp $switchRegex $instCellArr($inst)]} {
            if {[info exists switchConfigArr($inst)]} {
               set temp $switchConfigArr($inst)
               set switchConfigArr($inst) [lappend temp $port] 
            } else {
               set switchConfigArr($inst) [list $port] 
            }

         }
      }

      myParray switchConfigArr

      foreach {sw p} [array get switchConfigArr] {
         if {[info exists switchRtTableArr($sw)]} {
            set temp $switchRtTableArr($sw)
            set switchRtTableArr($sw) [lappend temp [list $p $VC $from $fromPort $to $toPort]] 
         } else {
            set switchRtTableArr($sw) [list [list $p $VC $from $fromPort $to $toPort]] 
         }
      }

      if {[info exists switchConfigArr]} {array unset switchConfigArr}
   }

   myParray nmuConfigArr
   myParray nsuConfigArr
   myParray switchRtTableArr
   myParray rtPathArr 

   # Herve: disable NPF out. Experimenting with nocrouting generating it (-f <npf_out>)
   startProgressBar "Generating NPF data for IP integrator"    
   dumpNPFDB
   endProgressBar
   return
    
   #Construct the data out
   #nmu_config
   if {[info exists nmujsonout]} {unset nmujsonout}
   foreach {k v} [array get nmuConfigArr] {
      #set out [::json::write object "key1" "value1" "key2" "value2"]
      lappend nmujsonout [::json::write object "logical_name" \"$k\" "physical_location" \"$v\" "register_values" "\[\]"]
   }
   #set nmujsonout [::json::write object "nmu_config" [::json::write array $nmujsonout]]
   set nmujsonout "\"nmu_config\" :  [::json::write array $nmujsonout]"
   myPuts "$nmujsonout"
 
   #nsu_config
   if {[info exists nsujsonout]} {unset nsujsonout}
   foreach {k v} [array get nsuConfigArr] {
      lappend nsujsonout [::json::write object "logical_name" \"$k\" "physical_location" \"$v\" "register_values" "\[\]"]
   }
   #set nsujsonout [::json::write object "nsu_config" [::json::write array $nsujsonout]]
   set nsujsonout "\"nsu_config\" : [::json::write array $nsujsonout]"
   myPuts "$nsujsonout"

   #nps_config
   if {[info exists swjsonout]} {unset swjsonout}
   foreach sw  [array names instCellArr] {
      if {[regexp $switchRegex $instCellArr($sw)]} {
         if {[info exists switchRtTableArr($sw)]} {
            set v $switchRtTableArr($sw)
            if {[info exists rtTable]} {unset rtTable}
            foreach elem $v {
               lappend rtTable [::json::write object "in_port" \"[lindex [lindex $elem 0] 0]\" \
               "vc" \"[lindex $elem 1]\" \
               "dst_inst" \"[lindex $elem 4]\" \
               "dst_port" \"[lindex $elem 5]\" \
               "out_port" \"[lindex [lindex $elem 0] 1]\" \
               ]
            }
            lappend swjsonout [::json::write object "name" \"$sw\" "rt_table" [::json::write array $rtTable] "register_values" "\[\]"]
         } else {
            lappend swjsonout [::json::write object "name" \"$sw\" "rt_table" "\[\]" "register_values" "\[\]"]
         }
      }
   }
   #set swjsonout [::json::write object "nps_config" [::json::write array $swjsonout]]
   set swjsonout "\"nps_config\" : [::json::write array $swjsonout]"
   myPuts "$swjsonout"

   #route_paths
   if {[info exists rtPathjsonout]} {unset rtPathjsonout}
   foreach {k v} [array get rtPathArr] {
      lappend rtPathjsonout "[::json::write string [join [split $k ","] " "]]"
   }
   set rtPathjsonout "\"route_paths\" :  [::json::write array $rtPathjsonout]"
   myPuts "$rtPathjsonout"
 

   #Final output string
   set finalJsonOut [::json::write object "device" "\[\n[::json::write object "name" \"sample_device\"]\n\]" \
   "version" \"0.22\" \
   "npf_info" "\[\n{\n$nmujsonout,\n$nsujsonout,\n$swjsonout,\n$rtPathjsonout\n}\n\]"\
   ]

   # produce npf file without register detail
   set npfOutFilePre "${npfOutFile}.pre_reg"
   set OUT [open $npfOutFilePre w]
   puts $OUT $finalJsonOut
   close $OUT
    
   # call gennocregmap to produce final NPF with registers
   set vlogOutDir "${outDir}/vlog_reg_out"
   file delete -force -- $vlogOutDir
   set cmd "exec $env(RDI_ROOT)/prep/rdi/vivado/bin/loader -exec gennocregmap --nocadl $nocadlFile --input_np $npfOutFilePre --output_np $npfOutFile --vlogpath $vlogOutDir"
   myPuts $cmd

   startProgressBar "Generating NPF registers"

   set res [catch $cmd]

   if {$res == 0} {
      file delete $npfOutFilePre
      dumpNPFDB
      endProgressBar
   } else {
      endProgressBar
      tk_messageBox -message "NPF Register generation failed" -type ok -icon error
   }    

}

proc dumpNPFDB {} {
   global npfOutFile
   global npfDBOutFile

	set F [open $npfOutFile r]
	set jsonFile [read $F]
	close $F
	
   set jsonData [json::json2dict $jsonFile]

   set OUT [open $npfDBOutFile w]
   puts $OUT $jsonData
   close $OUT
}


proc createSocket {portnum} {
   global socketChannel
   set socketChannel [socket localhost $portnum]
   myPuts "Creating socket at port $portnum"
}

proc updateSplashScreenUpdateText {str} {
   global splashScreenUpdateText
   if {[info exists splashScreenUpdateText]} {
      $splashScreenUpdateText configure -text $str
      update idletasks
   }
}

proc launchGui {} {
   global isGuiMode

	hideTopLevel
   if {$isGuiMode} {
      StartSplashScreen
   }
	
   global nocadlFile
   global modelFile
	global gridCoordsFile
	global regionFile
	global instPlacementArr 
	global pinArr
	global portConnectionArr
	global instCellArr
	global portCoordinatesArr
	global instPortDirArr
	global nCols
	global nRows
	global c
	global gridCheckbox
	global portNamesCheckBox
	global instNamesCheckbox
	
	#---------------------------------
	updateSplashScreenUpdateText "Loading Device ..."
   if {[info exists nocadlFile]} {
   	parseJsonData $nocadlFile 
   } elseif {[info exists modelFile]} {
      parseModel $modelFile
   }
	updateSplashScreenUpdateText "Done loading device ..."
	myParray instPlacementArr
	myParray pinArr
	myParray portConnectionArr
	myParray instCellArr
	myPuts "ncols = $nCols, nrows = $nRows"
	#---------------------------------
	
	if {[info exists gridCoordsFile]} {
	   parseGridCoords $gridCoordsFile
	}
	if {[info exists regionFile]} {
	parseRegionFile $regionFile
   }
	#########################
	#Call all drawing functions now
	#########################
	updateSplashScreenUpdateText "Configuring NOC Topology ..."
	createGui
   createHeatMapSettingsGui
	drawGrid $c $nCols $nRows
	drawInstPlacement $c
	drawPortConnections $c
	myParray portCoordinatesArr
	myParray instPortDirArr
   drawRegions 
	#zoomTop $c $nCols $nRows
	#---------------------------------
	#defaults
	$gridCheckbox invoke
	$portNamesCheckBox invoke
	$instNamesCheckbox invoke
	updateSplashScreenUpdateText "Launching GUI ..."

   if {$isGuiMode} {
	   EndSplashScreen
      showTopLevel
   }
}

proc ParseSolutionAndDrawNets {solutionFile} {
   global c
   global nCols
   global nRows
   global listBox

   parseSolution $solutionFile
   drawNets $c $listBox
   redraw $c
}

proc startProgressBar {str} {
   . config -cursor watch
   createBusyWindow $str
   update idletasks
}

proc endProgressBar {} {
   global busyWindow
   . config -cursor {}
   destroy $busyWindow
}

proc createBusyWindow {str} {
   global busyWindow
   
   set busyWindow [toplevel .b -bd 3 -relief raised -background white]
   wm withdraw $busyWindow
   wm transient $busyWindow .
   wm attributes $busyWindow -type splash 
   pack [label $busyWindow.l -text $str -font {-family times -size 20} -foreground black -background white]
  
   set parent . 
   set child $busyWindow
   set w [winfo width $parent]
   set h [winfo height $parent]
   set x [winfo rootx $parent]
   set y [winfo rooty $parent]
   set wc [winfo reqwidth  $child]
   set hc [winfo reqheight $child]
   set xpos "+[expr { $x + ($w / 2) - ($wc / 2) } ]"
   set ypos "+[expr { $y + ($h / 2) - ($hc / 2) } ]"

   wm geometry $child "$xpos$ypos"
   wm deiconify $child
}

proc RunCompilerWrapper {} {
   global runMode
   global ntfFile
   global importFile

   if {$runMode == "compile"} {
      update
      if {[info exists ntfFile]} {
         importNTF $ntfFile
      } elseif {[info exists importFile]} {
         importTrafficAndQos $importFile
      }
      doCompile
      set runMode "normal"
   }
}

proc RunSimulationWrapper {} {
   global runMode

   if {$runMode == "simulate"} {
      set runMode "compile"
      RunCompilerWrapper
      set runMode "simulate"
      doSimulate
      RunSimulation
      set runMode "normal"
   }
}

proc doCompile {} {
   global nocadlFile
   global netlistFile
   global trafficSetOutFile
   global regionOutFile
   global regionFile
   global compilerOutFile
   global solutionOutFile
   global graphOutFile
   global typeOutFile
   global npfOutFile
   global outDir
   global env
   global trafficGuiTopLevel
   global socketChannel

   if {![info exists trafficGuiTopLevel]} {
      tk_messageBox -message "User-traffic/Dataflow not available. Please provide User-traffic/Dataflow information first." -type ok -icon error
      return
   }


   dumpFilesForCompiler
   #Send a signal to wizard
   puts -nonewline $socketChannel "Compile"
   flush $socketChannel
   return

   startProgressBar "Running Compiler"


   #Create the run command
   regsub -all "$outDir/" $netlistFile "" nlf 
   regsub -all "$outDir/" $solutionOutFile "" slf
   regsub -all "$outDir/" $graphOutFile "" grf 
   regsub -all "$outDir/" $typeOutFile "" tyf
   regsub -all "$outDir/" $compilerOutFile "" cof
   regsub -all "$outDir/" $trafficSetOutFile "" tsf
   regsub -all "$outDir/" $regionOutFile "" rgf

   # running the compiler in a subdir, so watch for relative file paths
   set resolvedNpfOutFilePath $npfOutFile
   if { [file pathtype $npfOutFile] == "relative" } {
       set resolvedNpfOutFilePath "../$npfOutFile"
   }
   set resolvedNocadlFilePath $nocadlFile
   if { [file pathtype $nocadlFile] == "relative" } {
       set resolvedNocadlFilePath "../$nocadlFile"
   }
    
   set cmd "exec $env(RDI_ROOT)/prep/rdi/vivado/bin/loader -exec nocrouting -n $nlf -o $slf -f $resolvedNpfOutFilePath -g $grf -a $resolvedNocadlFilePath -s $tsf -p $tyf -r $rgf > $cof"
   myPuts $cmd

   #Go to outdir and run the command
   cd $outDir
   set res [catch $cmd]
   cd ..

   #Show output log on console
   showFileOnConsole $compilerOutFile
   
   if {$res == 0} {
      ParseSolutionAndDrawNets $solutionOutFile
      endProgressBar
      dumpNPF
   } else {
      endProgressBar
      tk_messageBox -message "Compiler failed" -type ok -icon error
   }
}

proc showFileOnConsole {filename} {
   global log

	set F [open $filename r]
	set data [read $F]
	close $F

   set out [split $data "\n"]
   clearLog
   $log config -state normal
   foreach elem $out {
      $log insert end "$elem\n"
   }
   $log see end
   $log config -state disabled
}

proc dumpFilesForCompiler {} {
   global portConnectionArr
   global typeToLocArr
   global instCellArr
   global ddrRegex
   global graphOutFile
   global typeOutFile
   global netlistFile
   global userTrafficOutFile
   global trafficSetFile
   global trafficSetOutFile
   global regionOutFile
   global ddrPairArr
   global ddrPortArr
   global regionArr

   myPuts "dumping user-traffic and Qos"
   exportTrafficAndQos $userTrafficOutFile
   set netlistFile $userTrafficOutFile
   return

   exec cp $trafficSetFile $trafficSetOutFile

   #Process region file
   set OUT [open $regionOutFile w]
	foreach {k v} [array get  regionArr] {
	   if {[info exists values]} {unset values}
	   foreach elem $v {
	      if {$instCellArr($elem) == $ddrRegex} {
	         foreach key [array names ddrPairArr] {
	            set name [lindex [split $key ","] 0]
	            if {$name == $elem} {
	               lappend values $ddrPairArr($key)
	            }
	         }
	      } else {
	         lappend values $elem
	      }
	   }
	   puts $OUT "$k $values"
	}
   close $OUT


   
   myPuts "printing portConnectionArr to $graphOutFile"
	set OUT [open $graphOutFile w]
	foreach {k v} [array get portConnectionArr] {
         set frominst [lindex [split [lindex $v 0] ","] 0]
         set fromport [lindex [split [lindex $v 0] ","] 1]
         set toinst [lindex [split [lindex $v 1] ","] 0]
         set toport [lindex [split [lindex $v 1] ","] 1]
         if {$instCellArr($frominst) == $ddrRegex} {
   	      puts $OUT "$ddrPairArr($frominst,$toinst) [lindex $ddrPortArr($frominst,$fromport) 1] $toinst $toport"
         } elseif {$instCellArr($toinst) == $ddrRegex} {
   	      puts $OUT "$frominst $fromport $ddrPairArr($toinst,$frominst) [lindex $ddrPortArr($toinst,$toport) 1]"
         } else {
   	      puts $OUT "$frominst $fromport $toinst $toport"
         }
	}
	close $OUT

   myPuts "printing  typeToLocArr to $typeOutFile"
	set OUT [open $typeOutFile w]
	foreach {k v} [array get  typeToLocArr] {
      puts $OUT "[split $k ","] $v"
	}
	close $OUT
}

proc doSimulate {} {
   createSimulatorOptionsGui
}

proc createSimulatorOptionsGui {} {
   global runMode
   global simSettingsLbfName
   global simulatorOptionsGui
   global simulationSettingsArr

   set ddrtypes [list "ddr4b" "ddr4c" "ddr4d" "ddr4e" "ddr3a" "ddr3b" "ddr3c"]

   set simulationSettingsArr(simtime) 5000 
   set simulationSettingsArr(ddrtype) "ddr4d" 
   set simulationSettingsArr(nocfreq) 1000 
   set simulationSettingsArr(simmst) 2 
   set simulationSettingsArr(simslv) 10 
   set simulationSettingsArr(simmode) 1
   set simulationSettingsArr(ddraddrmap) "default"
   set simulationSettingsArr(ddrwidth) 32 
   
   set simulatorOptionsGui [toplevel .simulatorOptionsGui]
   wm title $simulatorOptionsGui "Run Simulation"
   wm geometry $simulatorOptionsGui +5+5
   wm attributes $simulatorOptionsGui -topmost 1
   if {$runMode == "simulate"} {
      wm withdraw $simulatorOptionsGui
   }


   set simSettingsLbf [labelframe $simulatorOptionsGui.$simSettingsLbfName -text "Simulation Settings"]
   grid $simSettingsLbf -row 0 -column 0


   label $simSettingsLbf.t -text "Run Time(ns)"
   entry $simSettingsLbf.simtime -relief sunken -bd 2 -textvariable simtime  -background white
   label $simSettingsLbf.dt -text "DDR Type"
   ttk::combobox $simSettingsLbf.ddrtype -textvariable ddrtype -values $ddrtypes 
   bind $simSettingsLbf.ddrtype <KeyRelease> [list ComboBoxAutoComplete %W %K]
   label $simSettingsLbf.nf -text "Noc Freq(Mhz)"
   entry $simSettingsLbf.nocfreq -relief sunken -bd 2 -textvariable nocfreq  -background white
   label $simSettingsLbf.ddrwidth -text "DDR Width"
   radiobutton $simSettingsLbf.ddrwidth32 -text "32 bit" -variable ddrwidth -value "32" -anchor w 
   radiobutton $simSettingsLbf.ddrwidth64 -text "64 bit" -variable ddrwidth -value "64" -anchor w 

   grid $simSettingsLbf.t -row 0 -column 0 -sticky w 
   grid $simSettingsLbf.simtime -row 0 -column 1 -sticky ew -columnspan 2 
   grid $simSettingsLbf.dt -row 1 -column 0 -sticky w 
   grid $simSettingsLbf.ddrtype -row 1 -column 1 -sticky ew -columnspan 2 
   grid $simSettingsLbf.nf -row 2 -column 0 -sticky w 
   grid $simSettingsLbf.nocfreq -row 2 -column 1 -sticky ew -columnspan 2 
   grid $simSettingsLbf.ddrwidth -row 3 -column 0 -sticky w 
   grid $simSettingsLbf.ddrwidth32 -row 3 -column 1 -sticky w 
   grid $simSettingsLbf.ddrwidth64 -row 3 -column 2 -sticky w 
 

   ttk::separator $simulatorOptionsGui.s -orient horizontal
   grid $simulatorOptionsGui.s -row 1 -column 0 -pady 5 -sticky ew

   frame $simulatorOptionsGui.bottomframe
   button $simulatorOptionsGui.bottomframe.run -text "Run Simulation" -command "RunSimulation"
   button $simulatorOptionsGui.bottomframe.cancel  -text "Cancel" -command "destroy $simulatorOptionsGui"

   grid $simulatorOptionsGui.bottomframe -row 2 -column 0
   grid $simulatorOptionsGui.bottomframe.run -row 0 -column 0
   grid $simulatorOptionsGui.bottomframe.cancel -row 0 -column 1

   #Populate the fields from simulationSettingsArr
   global simtime
   global ddrtype
   global nocfreq
   global ddrwidth
   set simtime $simulationSettingsArr(simtime)
   set ddrtype $simulationSettingsArr(ddrtype)
   set nocfreq $simulationSettingsArr(nocfreq)
   set ddrwidth $simulationSettingsArr(ddrwidth)
}

proc ChooseSimulationNetlistDir {} {
   global simnetlist
   set dir [tk_chooseDirectory -title "Choose simulation netlist"]
   if {![info exists dir]} {
      tk_messageBox -message "Please provide a valid directory" -type ok -icon error
      return
   }
   if {$dir != ""} {
      set simnetlist $dir
   }
}

proc SaveSimulationSettings {} {
   global simulatorOptionsGui
   global simulationSettingsArr
   global simSettingsLbfName
   global ddrwidth

   #Save the simulation settings first
   foreach elem [wlist $simulatorOptionsGui] {
      if {[regexp $simSettingsLbfName $elem]} {
         set exp ".*.$simSettingsLbfName\.\(.*\)"
         regexp $exp $elem -> wname 
         if {[info exists wname]} {
            if {$wname != ""} {
               switch $wname {
                  "simtime" {set simulationSettingsArr(simtime) [$elem get]}
                  "ddrtype" {set simulationSettingsArr(ddrtype) [$elem get]}
                  "nocfreq" {set simulationSettingsArr(nocfreq) [$elem get]}
               }
            }
         }
      }
   }

   set simulationSettingsArr(ddrwidth) $ddrwidth
   
   myParray simulationSettingsArr 
}

proc RunSimulation {} {
   global simulationSettingsArr
   global simulatorOptionsGui
   global nocadlFile
   global npfOutFile
   global ntfOutFile
   global simulatorOutFile
   global outDir
   global env
   
   startProgressBar "Running Simulation"
   SaveSimulationSettings
   DumpFilesForSimulation

   destroy $simulatorOptionsGui
   update 

   #Set the following env var to disable the copyright message of systemc, which gets printed as "cerr".
   set env(SYSTEMC_DISABLE_COPYRIGHT_MESSAGE) 1

   #Create the run command
   regsub -all "$outDir/" $simulatorOutFile "" sof 

   #running the simulator in a subdir, so watch for relative file paths
   set resolvedNtfOutFilePath $ntfOutFile
   if { [file pathtype $ntfOutFile] == "relative" } {
       set resolvedNtfOutFilePath "../$ntfOutFile"
   }
   set resolvedNpfOutFilePath $npfOutFile
   if { [file pathtype $npfOutFile] == "relative" } {
       set resolvedNpfOutFilePath "../$npfOutFile"
   }
   set resolvedNocadlFilePath $nocadlFile
   if { [file pathtype $nocadlFile] == "relative" } {
       set resolvedNocadlFilePath "../$nocadlFile"
   }
   #

   set cmd "exec $env(RDI_ROOT)/prep/rdi/vivado/bin/loader -exec  xensim -nocadl $resolvedNocadlFilePath -ntf $resolvedNtfOutFilePath -npf $resolvedNpfOutFilePath -time $simulationSettingsArr(simtime) -perflog . -mst $simulationSettingsArr(simmst) -slv $simulationSettingsArr(simslv) -mode $simulationSettingsArr(simmode) -ddrtype $simulationSettingsArr(ddrtype) -nocfreq $simulationSettingsArr(nocfreq) -ddraddrmap $simulationSettingsArr(ddraddrmap) -ddrwidth $simulationSettingsArr(ddrwidth) > $sof"
   myPuts $cmd

   #Go to outdir and run the command
   cd $outDir
   set res [catch $cmd]
   cd ..

   #Show output log on console
   showFileOnConsole $simulatorOutFile

   if {$res == 0} {
      parseSimulationFile "$outDir/noc.channels"
      endProgressBar
   } else {
      endProgressBar
      tk_messageBox -message "Simulator failed" -type ok -icon error
   }
}

proc DumpFilesForSimulation {} {
   global userTrafficOutFile
   global ntfOutFile

   exportTrafficAndQos $userTrafficOutFile
   dumpNTF $ntfOutFile
}

proc parseSimulationFile {filename} {
   global simulationInfoArr
   global simulationPostInfoArr
   global simulationSettingsArr
   global bwInfoArr
   global simulationEndtime
   global simulationEndtimeunit
   global masterRegex
   global slaveRegex
   global ddrRegex
   global ddrPortReverseMapArr
   global instCellArr
   global trafficInfoArr
   global nmuConfigArr
   global nsuConfigArr


   if {[info exists simulationInfoArr]} {array unset simulationInfoArr}
   if {[info exists simulationPostInfoArr]} {array unset simulationPostInfoArr}
   if {[info exists simulationEndtime]} {unset simulationEndtime}
   if {[info exists simulationEndtimeunit]} {unset simulationEndtimeunit}
   if {[info exists bwInfoArr]} {array unset bwInfoArr}

   set F [open $filename r]
   while {[gets $F line] >= 0} {
      if {[regexp {^\s*$} $line]} {continue}
      if {[regexp {#} $line]} {continue}
      regsub -all {^\s+} $line "" line
      regsub -all {\s+} $line " " line
      if {[regexp {end time} $line]} {
         regsub -all {:} $line " " line
         set simulationEndtime [lindex $line 2]
         set simulationEndtimeunit [lindex $line 3]
         if {$simulationEndtimeunit == "us"} {set simulationEndtime [expr $simulationEndtime * 1000]}
         if {$simulationEndtimeunit == "ms"} {set simulationEndtime [expr $simulationEndtime * 1e6]}
         continue
      }
      set line [split $line ","]
      set mname [lindex $line 0]
      set mpname [lindex $line 1]
      set sname [lindex $line 2]
      set spname [lindex $line 3]
      lappend simulationInfoArr($mname,$mpname,$sname,$spname) [list [lrange $line 4 end]]
   }
   close $F

   myParray simulationInfoArr


   #Post process simulationInfoArr to get bw%, utilization info 
   foreach {k v} [array get simulationInfoArr] {
      foreach {minst mport sinst sport} [split $k ","] {break}
      set numRawRdFlits 0
      set numRawWrFlits 0
      set numEffRdFlits 0
      set numEffWrFlits 0
      foreach elem $v {
         set elem [lindex $elem 0]
         foreach {time packetid packettype header vc src dest} $elem {break}
      	  # interpret packet type: 0=RD_req; 1=WR_req; 2=RD_resp; 3=WR_resp; 4=StreamingWR
         if { $packettype == 0 } {
            incr numRawRdFlits;
         }
         if { $packettype == 1 || $packettype == 4 } {
            incr numRawWrFlits; 
            if { $header == 0 } {
               incr numEffWrFlits;
            }
         }
         if { $packettype == 2 } {
            incr numRawRdFlits;
            incr numEffRdFlits;
         }
         if { $packettype == 3 } {
            incr numRawWrFlits;
         }
      }
      set rawRdUtilization [expr ($numRawRdFlits * 100)/double($simulationEndtime)]
      set rawWrUtilization [expr ($numRawWrFlits * 100)/double($simulationEndtime)]
      set effRdUtilization [expr ($numEffRdFlits * 100)/double($simulationEndtime)]
      set effWrUtilization [expr ($numEffWrFlits * 100)/double($simulationEndtime)]
     
      set rdBandwidth [expr ($numEffRdFlits * 16 * $simulationSettingsArr(nocfreq))/double($simulationEndtime)]
      set wrBandwidth [expr ($numEffWrFlits * 16 * $simulationSettingsArr(nocfreq))/double($simulationEndtime)]

      set simulationPostInfoArr($k) [list $rawRdUtilization $rawWrUtilization $effRdUtilization $effWrUtilization $rdBandwidth $wrBandwidth]
   }
   myParray simulationPostInfoArr


   #Post process to get the bandwidth/utilization info for maps
   foreach {inst cell} [array get instCellArr] {
      if {[regexp $masterRegex $cell] || [regexp $slaveRegex $cell] || [regexp $ddrRegex $cell]} {
         set requiredReadBW 0
         set requiredWriteBW 0
         set achievedReadBW 0
         set achievedWriteBW 0

         #Find Required BW
         for {set j 0} {$j < [array size trafficInfoArr]} {incr j} {
            set tinfo $trafficInfoArr($j)
            foreach {mName sName transType readQos readLat readBW writeQos writeLat writeBW} [split $tinfo ","] {break}
            set slaveInst $nsuConfigArr($sName)
            #Reverse map the DDR
            if {[regexp $ddrRegex $cell]} {
               foreach {ddrk ddrv} [array get ddrPortReverseMapArr] {
                  if {$nsuConfigArr($sName) == [lindex [split $ddrk ","] 0]} {
                     set slaveInst [lindex $ddrv 0]
                     break
                  }
               }
            }
            if {$inst == $nmuConfigArr($mName) || $inst == $slaveInst} {
               set requiredReadBW [expr $requiredReadBW + $readBW]
               set requiredWriteBW [expr $requiredWriteBW + $writeBW]
            }
         }
         #Find achieved BW
         foreach {k v} [array get simulationPostInfoArr] {
            foreach {fromInst fromPort toInst toPort} [split $k ","] {break}
            foreach {rawRdUtilization rawWrUtilization effRdUtilization effWrUtilization rdBandwidth wrBandwidth} $v {break}
            if {$inst == $fromInst || $inst == $toInst} {
               set achievedReadBW [expr $achievedReadBW + $rdBandwidth]
               set achievedWriteBW [expr $achievedWriteBW + $wrBandwidth]
            }
         }
         set bwInfoArr($inst) [list $requiredReadBW $requiredWriteBW $achievedReadBW $achievedWriteBW]
      }
   }
   myParray bwInfoArr
}

proc showLatencyPlot {filename} {
   parseLatencyFile $filename
   generateLatencyPlot
}

proc parseLatencyFile {filename} {
   global latencyPlotArr

   set F [open $filename r]
   while {[gets $F line] >= 0} {
      if {[regexp {^\s*$} $line]} {continue}
      if {[regexp {#} $line]} {continue}
      regsub -all {^\s+} $line "" line
      regsub -all {\s+} $line " " line
      set line [split $line ","]
      foreach {tid commtype nmuReqTime nocReqTime nocRespTime} $line {break}
      #We are converting all the time units to be in "ns" eventually
      set nmuReqTime [convertToNanoSeconds $nmuReqTime]
      set nocReqTime [convertToNanoSeconds $nocReqTime]
      set nocRespTime [convertToNanoSeconds $nocRespTime]
      set nmuLat [expr $nocReqTime - $nmuReqTime]
      set nocLat [expr $nocRespTime - $nocReqTime]

      switch $commtype {
         "read" {lappend latencyPlotArr(read) [list $nmuLat $nocLat]}
         "write" {lappend latencyPlotArr(write) [list $nmuLat $nocLat]}
      }
   }
   close $F

   myParray latencyPlotArr
}

proc convertToNanoSeconds {elem} {
   #Input comes in format {<value> <unit>}
   #Output is just returned as converted <value>
   switch [lindex $elem 1] {
      "ps" {return [expr [lindex $elem 0] / 1e3]}
      "ns" {return [lindex $elem 0]}
      "us" {return [expr [lindex $elem 0] * 1e3]}
      "ms" {return [expr [lindex $elem 0] * 1e6]}
   }
}

proc generateLatencyPlot {} {
   global latencyPlotArr
   global latencyPlotFile


   set htmlStr1 ""
   for {set i 0} {$i < [llength $latencyPlotArr(read)]} {incr i} {
      set elem [lindex $latencyPlotArr(read) $i]
      if {$i == [expr [llength $latencyPlotArr(read)] - 1]} {
         set htmlStr1 [concat $htmlStr1 "\[$i, [lindex $elem 0], [lindex $elem 1]\]"]
      } else {
         set htmlStr1 [concat $htmlStr1 "\[$i, [lindex $elem 0], [lindex $elem 1]\],\n"]
      }
   }

   set htmlStr2 ""
   for {set i 0} {$i < [llength $latencyPlotArr(write)]} {incr i} {
      set elem [lindex $latencyPlotArr(write) $i]
      if {$i == [expr [llength $latencyPlotArr(write)] - 1]} {
         set htmlStr2 [concat $htmlStr2 "\[$i, [lindex $elem 0], [lindex $elem 1]\]"]
      } else {
         set htmlStr2 [concat $htmlStr2 "\[$i, [lindex $elem 0], [lindex $elem 1]\],\n"]
      }
   }


   set OUT [open $latencyPlotFile w]
   puts $OUT "\
<html>
  <head>
    <script type=\"text/javascript\" src=\"https://www.gstatic.com/charts/loader.js\"></script>
    <script type=\"text/javascript\">
      google.charts.load('current', {'packages':\['corechart'\]});
      google.charts.setOnLoadCallback(drawChart);
      function drawChart() {
        var data1 = google.visualization.arrayToDataTable(\[
          \['Transaction', 'NMU', 'NOC'\],
          $htmlStr1
        \]);

        var data2 = google.visualization.arrayToDataTable(\[
          \['Transaction', 'NMU', 'NOC'\],
          $htmlStr2
        \]);

        var options1 = {
          title: 'Read Latency',
          hAxis: {title: 'Transaction'},
          vAxis: {title: 'Latency'},
          legend: {position: 'right', textStyle: {color: 'blue', fontSize: 16}} 
        };

        var options2 = {
          title: 'Write Latency',
          hAxis: {title: 'Transaction'},
          vAxis: {title: 'Latency'},
          legend: {position: 'right', textStyle: {color: 'blue', fontSize: 16}} 
        };


        var chart1 = new google.visualization.ScatterChart(document.getElementById('chart_div1'));
        var chart2 = new google.visualization.ScatterChart(document.getElementById('chart_div2'));

        chart1.draw(data1, options1);
        chart2.draw(data2, options2);
      }
    </script>
  </head>
  <body>
    <div id=\"chart_div1\" style=\"width: 900px; height: 300px;\"></div>
    <div id=\"chart_div2\" style=\"width: 900px; height: 300px;\"></div>
  </body>
</html>
   "
   close $OUT

   exec firefox $latencyPlotFile
}

proc hideTopLevel {} {
   wm withdraw .
}

proc showTopLevel {} {
   wm deiconify .
}

proc StartSplashScreen {} {
   global topLevelWindowTitle
   global splashScreen
   global splashScreenUpdateText

   set splashScreen [toplevel .x -bd 3 -relief raised -background white]
   wm withdraw $splashScreen 
   wm overrideredirect $splashScreen 1 
   label $splashScreen.l -text $topLevelWindowTitle -font {-family times -size 36} -foreground green -background white
   set splashScreenUpdateText [label $splashScreen.l2 -text "" -font {-family aerial -size 10} -background white]
   pack $splashScreen.l -side top -expand 1 -fill both -padx 30 -pady 30 
   pack $splashScreen.l2 -side top -expand 0 -fill both -padx 30 -pady 30 
   tk::PlaceWindow $splashScreen
   update idletasks 
}

proc EndSplashScreen {} {
   global splashScreen
   destroy $splashScreen
}

proc setupOutDir {} {
   global outDir
   if {[file exists $outDir]} {
      file delete -force $outDir
   }
   file mkdir $outDir
}

proc errorAndExit {} {
   OnExit
}

proc OnExit {} {
   global socketChannel
   if {[info exists socketChannel]} {
      myPuts "Closing socket"
      puts -nonewline $socketChannel "END"
      flush $socketChannel
      close $socketChannel
   }
   destroy .
   exit
}

#Main
proc main {args} {
	global nocadlFile
	global modelFile
	global gridCoordsFile
	global regionFile
	global trafficSetFile
   global ntfFile
   global importFile
   global npfOutFile
   global npfDBOutFile
   global runMode
   global isGuiMode
	
	set isBatchMode 0
	set isGuiMode 0
	set runMode "normal"
	
	#Parse input arguments
	set argv [lindex $args 0]
	set argc [llength $argv]
	regsub -all {\s+} $argv " " argv
	
	myPuts "args = $args, argv = $argv, [lindex $argv 0]"
	
	for {set i 0} {$i < $argc} {incr i} {
	   if {[regexp -nocase {\-nocadl} [lindex $argv $i]]} {
	      set nocadlFile [lindex $argv [expr $i + 1]]
	      incr i
      } elseif {[regexp -nocase {\-model} [lindex $argv $i]]} {
	      set modelFile [lindex $argv [expr $i + 1]]
	      incr i
	   } elseif {[regexp -nocase {\-trafficset} [lindex $argv $i]]} {
	      set trafficSetFile [lindex $argv [expr $i + 1]]
	      incr i
      } elseif {[regexp -nocase {\-region} [lindex $argv $i]]} {
	      set regionFile [lindex $argv [expr $i + 1]]
	      incr i
	   } elseif {[regexp -nocase {\-grid} [lindex $argv $i]]} {
	      set gridCoordsFile [lindex $argv [expr $i + 1]]
	      incr i
	   } elseif {[regexp -nocase {\-batch} [lindex $argv $i]]} {
	      set isBatchMode 1
	   } elseif {[regexp -nocase {\-gui} [lindex $argv $i]]} {
	      set isGuiMode 1
	   } elseif {[regexp -nocase {\-compile} [lindex $argv $i]]} {
	      set runMode "compile"
	   } elseif {[regexp -nocase {\-simulate} [lindex $argv $i]]} {
	      set runMode "simulate"
      } elseif {[regexp -nocase {\-ntf} [lindex $argv $i]]} {
	      set ntfFile [lindex $argv [expr $i + 1]]
	      incr i
      } elseif {[regexp -nocase {\-import} [lindex $argv $i]]} {
	      set importFile [lindex $argv [expr $i + 1]]
	      incr i
      } elseif {[lindex $argv $i] == "-npf"} {
	      set npfOutFile [lindex $argv [expr $i + 1]]
	      incr i
      } elseif {[lindex $argv $i] == "-npfdb"} {
	      set npfDBOutFile [lindex $argv [expr $i + 1]]
	      incr i
	   } elseif {[regexp -nocase {\-solution} [lindex $argv $i]]} {
	      set solutionFile [lindex $argv [expr $i + 1]]
	      set runMode "readSolution"
	      incr i
	   } elseif {[regexp -nocase {\-port} [lindex $argv $i]]} {
	      set socketPort [lindex $argv [expr $i + 1]]
	      incr i
	   } else {
	      puts "ERROR-102: Unrecognized option [lindex $argv $i]"
	   }
	}
	
	#Now check the options
	if {$isBatchMode && $isGuiMode} {
	   puts "ERROR-103: Cannot set both -batch and -gui together"
	   errorAndExit 
	}
	
	if {![info exists nocadlFile] && ![info exists modelFile]} {
	   puts "ERROR-104: Please specify a -nocadl or -model file"
	   errorAndExit 
	}
	
   if {[info exists nocadlFile] && ![info exists trafficSetFile]} {
	   puts "ERROR-105: Please specify a -trafficset file"
	   errorAndExit 
	}

   if {$runMode == "compile"} {
      if {![info exists ntfFile] && ![info exists importFile]} {
	      puts "ERROR-106: Please specify a -ntf file"
   	   errorAndExit 
   	}
      if {[info exists ntfFile] && [info exists importFile]} {
	      puts "ERROR-107: Please specify only one of -ntf or -import file"
   	   errorAndExit 
   	}
      if {![info exists regionFile]} {
	      puts "ERROR-108: Please specify a -region file"
   	   errorAndExit 
   	}
      #if {![info exists npfFile]} {
	   #   puts "ERROR-109: Please specify a -npf file"
   	#   errorAndExit 
   	#}
   }

   if {$runMode == "readSolution"} {
      if {![info exists solutionFile]} {
	      puts "ERROR-109: Please specify a -solution file"
   	   errorAndExit 
   	}
      if {![info exists importFile]} {
	      puts "ERROR-110: Please specify a -import file"
   	   errorAndExit 
   	}
   }

   #Setup dir for dumping outputs
	#setupOutDir

   #Setup color gradients needed for maps
   createColorGradientsForMaps

   #Create socket to talk to wizard
   if {[info exists socketPort]} {createSocket $socketPort}
	
   #For both -batch and -gui modes the gui is created. In -batch mode we just never 'show' the gui.
   launchGui 
  
   switch $runMode {
      "compile" {RunCompilerWrapper}
      "simulate" {RunSimulationWrapper}
      "readSolution" {
         importTrafficAndQos $importFile
         ParseSolutionAndDrawNets $solutionFile
      }
   }
   
   if {$isBatchMode} {OnExit}
}


#Call main
main $argv
