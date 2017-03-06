##################################################################
# Utility to instantiate and connect test bench IPs
##################################################################

namespace eval ::bd::tb:: {

#Data Structure for BD INTF PINS this includes
#1. INTF VLNV 2. TB IP VLNV 3. MODE of INTF PIN 4. <> 5. TB IP Instance Name
  set intf_pins_dict {xilinx.com:interface:uart_rtl:1.0 {VLNV xilinx.com:ip:uart_model:1.0 MODE Master CONFIG_PROC None INST_NAME uart_model_} \
	  xilinx.com:interface:ddrx_rtl:1.0 {VLNV xilinx.com:ip:micron_ddr3:1.0 MODE Master CONFIG_PROC None INST_NAME micron_ddr3_} \
	  xilinx.com:interface:diff_clock_rtl:1.0 {VLNV xilinx.com:ip:clk_gen:1.0 MODE Slave CONFIG_PROC configure_clk_gen INST_NAME clk_gen_}\
	  xilinx.com:interface:aximm_rtl:1.0 {VLNV xilinx.com:ip:cdn_axi_bfm:5.0 MODE Both CONFIG_PROC config_aximm INST_NAME cdn_axi_bfm_}\
	  xilinx.com:interface:axis_rtl:1.0 {VLNV xilinx.com:ip:cdn_axi_bfm:5.0 MODE Both CONFIG_PROC config_aximm INST_NAME cdn_axi_bfm_}}
  
  set rst_dict {rst {VLNV xilinx.com:ip:rst_gen:1.0 DIR I CONFIG_PROC config_rst INST_NAME rst_gen_}}
  set clk_dict {clk {VLNV xilinx.com:ip:clk_gen:1.0 DIR I CONFIG_PROC config_clk INST_NAME clk_gen_}}

#To connect Intf bd pins  
  proc connect_intf_pins {intf_pins bd_cell} {
    set intf_pins_dict $::bd::tb::intf_pins_dict

    foreach intf_pin $intf_pins {
       set matched 0
       set vlnv_i [get_property VLNV $intf_pin]
       if {[dict exists $intf_pins_dict $vlnv_i] == 1} {
          set mode [get_property MODE $intf_pin]
          if {($mode == "Both") || ($mode == [dict get $intf_pins_dict $vlnv_i MODE])} {set matched 1} {set matched 0}
          if {[string length [get_bd_intf_nets -of_objects $intf_pin -quiet]] == 0} {set matched 1} {set matched 0}
          if {$matched == 1} {[add_intf_tb_ip $intf_pin $bd_cell]}
       }
    }   
  }

#Gather information and instantiate IP
  proc add_intf_tb_ip {intf_pin bd_cell} {
    set intf_pins_dict $::bd::tb::intf_pins_dict
    set vlnv_i [get_property VLNV $intf_pin]
    set vlnv_tb_ip [dict get $intf_pins_dict $vlnv_i VLNV]
    set inst_name [get_unique_cell [dict get $intf_pins_dict $vlnv_i INST_NAME]]
    set cell_inst [create_bd_cell -type ip -vlnv $vlnv_tb_ip $inst_name]
	
    configure_intf_tb_ip $cell_inst $intf_pin
    connect_bd_intf_net [get_bd_intf_pins $intf_pin] [get_bd_intf_pins -of_objects $cell_inst -filter "VLNV =~ *$vlnv_i"] 
}

#configure TB IP
  proc configure_intf_tb_ip { cell_inst intf_pin } {
    set intf_pins_dict $::bd::tb::intf_pins_dict
    set vlnv_i [get_property VLNV $intf_pin]
    if {[dict get $intf_pins_dict $vlnv_i CONFIG_PROC] == "None"} {return} {[[dict get $intf_pins_dict $vlnv_i CONFIG_PROC] $cell_inst $intf_pin]}
  }

#To connect BD Pins
  proc connect_bd_pins {bd_pins pins_dict bd_cell} {
    foreach bd_pin $bd_pins {
       set type [get_property TYPE $bd_pin]
       if {[dict exists $pins_dict $type] == 1} {
           set dir [get_property DIR $bd_pin]
           set connected [get_bd_nets -of_objects $bd_pin -quiet]
           if {($dir == [dict get $pins_dict $type DIR]) && ([string length $connected] == 0)} {
             add_pin_tb_ip $bd_pin $pins_dict $bd_cell
           }
       }
    }
  }

#Gather information and instantiate IP
  proc add_pin_tb_ip {bd_pin pins_dict bd_cell} {
    set type [get_property TYPE $bd_pin]
    set vlnv_tb_ip [dict get $pins_dict $type VLNV]
    set inst_name [get_unique_cell [dict get $pins_dict $type INST_NAME]]
    set cell_inst [create_bd_cell -type ip -vlnv $vlnv_tb_ip $inst_name]
    configure_pin_tb_ip $cell_inst $bd_pin $pins_dict $bd_cell
    connect_bd_net [get_bd_pins -of_objects $cell_inst -filter "TYPE =~ $type"] [get_bd_pins $bd_pin]
  }
#Configure TB IP
  proc configure_pin_tb_ip {cell_inst bd_pin pins_dict bd_cell} {
    set type [get_property TYPE $bd_pin]
    if {[dict get $pins_dict $type CONFIG_PROC] == "None"} {return} {[[dict get $pins_dict $type CONFIG_PROC] $cell_inst $bd_pin $bd_cell]}
  }
  
  
  proc get_unique_cell {inst_name} {
	set inst_num 0;
	set i_name $inst_name$inst_num;
	set resp [get_bd_cells $i_name -quiet];
	while {[string length $resp] != 0} {
            incr inst_num;
	    set i_name $inst_name$inst_num;
	    set resp [get_bd_cells $i_name -quiet];
	}
	return $i_name
 }

 proc configure_clk_gen {cell_inst intf_pin} {
   set FREQ_HZ [get_property CONFIG.FREQ_HZ [get_bd_intf_pins $intf_pin]]
   set_property -dict [list CONFIG.Clock_Type {Differential} CONFIG.FREQ_HZ $FREQ_HZ] [get_bd_cells $cell_inst]
 }
 
 proc config_clk {cell_inst bd_pin bd_cell} {
    set assc_rsts [get_property CONFIG.ASSOCIATED_RESET $bd_pin -quiet]
    if {[string length $assc_rsts] != 0} {
          set assc_rsts [split $assc_rsts :]
	  foreach assc_rst $assc_rsts {
	     set rstn_pin [get_bd_pins -of_objects $bd_cell -filter "NAME =~ $assc_rst" -quiet]
	     if {[string length $rstn_pin] != 0 } {
               if {[get_property DIR $rstn_pin] == "I"} {
                 connect_bd_net [get_bd_pins $cell_inst/sync_rst] $rstn_pin
                 set_property CONFIG.Reset_Polarity [get_property CONFIG.POLARITY $rstn_pin] $cell_inst
               }
	     }
          }
    }
      set_property CONFIG.FREQ_HZ [get_property CONFIG.FREQ_HZ [get_bd_pins $bd_pin]] $cell_inst
 }
 
 proc config_rst {cell_inst bd_pin bd_cell} {  
   set_property -dict [list CONFIG.rst_polarity [get_property CONFIG.POLARITY $bd_pin]] $cell_inst
 }

 proc config_aximm {cell_inst intf_pin} {
    set protocol [get_property CONFIG.PROTOCOL $intf_pin]
    set type [get_property MODE $intf_pin]

    if {$type == "Slave"} {
      set_property CONFIG.C_MODE_SELECT 0 $cell_inst 
	
      if {$protocol == "AXI4"} {
       set_property CONFIG.C_PROTOCOL_SELECTION 1 $cell_inst
	   set_property CONFIG.C_M_AXI4_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_ADDR_WIDTH [get_property CONFIG.ADDR_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_ARUSER_WIDTH [get_property CONFIG.ARUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_AWUSER_WIDTH [get_property CONFIG.AWUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_BUSER_WIDTH  [get_property CONFIG.BUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_RUSER_WIDTH  [get_property CONFIG.RUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_WUSER_WIDTH  [get_property CONFIG.WUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_NARROW_BURST  [get_property CONFIG.SUPPORTS_NARROW_BURST  $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_ID_WIDTH  [get_property CONFIG.ID_WIDTH $intf_pin] $cell_inst
      } elseif {$protocol == "AXI4LITE"} {
           set_property CONFIG.C_PROTOCOL_SELECTION 2 $cell_inst
	   set_property CONFIG.C_M_AXI4_LITE_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI4_LITE_ADDR_WIDTH [get_property CONFIG.ADDR_WIDTH $intf_pin] $cell_inst
      } elseif {$protocol == "AXI3"} {
           set_property CONFIG.C_PROTOCOL_SELECTION 0 $cell_inst
	   set_property CONFIG.C_M_AXI3_ID_WIDTH  [get_property CONFIG.ID_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI3_DATA_WIDTH [get_property CONFIG.DATA_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXI3_ADDR_WIDTH [get_property CONFIG.ADDR_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_NARROW_BURST_AXI3  [get_property CONFIG.SUPPORTS_NARROW_BURST  $intf_pin] $cell_inst
      } else {
	   set_property CONFIG.C_PROTOCOL_SELECTION 3 $cell_inst
	   set_property CONFIG.C_M_AXIS_TID_WIDTH  [get_property CONFIG.TID_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXIS_TDEST_WIDTH  [get_property CONFIG.TDEST_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXIS_TUSER_WIDTH  [get_property CONFIG.TUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_M_AXIS_TDATA_WIDTH  [expr [get_property CONFIG.TDATA_NUM_BYTES $intf_pin] * 8] $cell_inst
	   if {[get_property CONFIG.HAS_TSTRB $intf_pin] == 0} {
	      set_property CONFIG.C_M_AXIS_STROBE_NOT_USED 1 $cell_inst
	   } else {
	      set_property CONFIG.C_M_AXIS_STROBE_NOT_USED 0 $cell_inst
	   }
	   if {[get_property CONFIG.HAS_TKEEP $intf_pin] == 0} {
	      set_property CONFIG.C_M_AXIS_KEEP_NOT_USED 1 $cell_inst
	   } else {
	      set_property CONFIG.C_M_AXIS_KEEP_NOT_USED 0 $cell_inst
	   }
      }
   } else {
      set_property CONFIG.C_MODE_SELECT 1 $cell_inst
      if {$protocol == "AXI4"} {
           set_property CONFIG.C_PROTOCOL_SELECTION 1 $cell_inst
	   set_property CONFIG.C_S_AXI4_ARUSER_WIDTH [get_property CONFIG.ARUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_S_AXI4_AWUSER_WIDTH [get_property CONFIG.AWUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_S_AXI4_BUSER_WIDTH  [get_property CONFIG.BUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_S_AXI4_RUSER_WIDTH  [get_property CONFIG.RUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_S_AXI4_WUSER_WIDTH  [get_property CONFIG.WUSER_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_NARROW_BURST  [get_property CONFIG.SUPPORTS_NARROW_BURST  $intf_pin] $cell_inst
	   set_property CONFIG.C_S_AXI4_ID_WIDTH  [get_property CONFIG.ID_WIDTH $intf_pin] $cell_inst
	   set data_width [get_property CONFIG.DATA_WIDTH $intf_pin]
	   set addr_width [get_property CONFIG.ADDR_WIDTH $intf_pin]
	   set high_addr [calculate_high_addr_bfm $addr_width]
	   set_property -dict [list CONFIG.C_S_AXI4_DATA_WIDTH $data_width CONFIG.C_S_AXI4_ADDR_WIDTH $addr_width CONFIG.C_S_AXI4_HIGHADDR $high_addr] $cell_inst
      } elseif {$protocol == "AXI4LITE"} {
           set_property CONFIG.C_PROTOCOL_SELECTION 2 $cell_inst
	   set data_width [get_property CONFIG.DATA_WIDTH $intf_pin]
	   set addr_width [get_property CONFIG.ADDR_WIDTH $intf_pin]
	   set high_addr [calculate_high_addr_bfm $addr_width]
	   set_property -dict [list CONFIG.C_S_AXI4_LITE_DATA_WIDTH $data_width CONFIG.C_S_AXI4_LITE_ADDR_WIDTH $addr_width CONFIG._S_AXI4_LITE_HIGHADDR $high_addr] $cell_inst
      } elseif {$protocol == "AXI3"} {
           set_property CONFIG.C_PROTOCOL_SELECTION 0 $cell_inst
	   set_property CONFIG.C_S_AXI3_ID_WIDTH  [get_property CONFIG.ID_WIDTH $intf_pin] $cell_inst
	   set_property CONFIG.C_NARROW_BURST_AXI3  [get_property CONFIG.SUPPORTS_NARROW_BURST  $intf_pin] $cell_inst
	   set data_width [get_property CONFIG.DATA_WIDTH $intf_pin]
	   set addr_width [get_property CONFIG.ADDR_WIDTH $intf_pin]
	   set high_addr [calculate_high_addr_bfm $addr_width]
	   set_property -dict [list CONFIG.C_S_AXI3_DATA_WIDTH $data_width CONFIG.C_S_AXI3_ADDR_WIDTH $addr_width CONFIG.C_S_AXI3_HIGHADDR $high_addr] $cell_inst  
      } else {
	   set_property CONFIG.C_PROTOCOL_SELECTION 3 $cell_inst
      }
  }
 }
 #proc to calculate high adress for BFM
 proc calculate_high_addr_bfm { addr } {
   set n_bits [expr {$addr/4}]
   set f_bits [expr {int(floor($n_bits))}]
   set fmat 0x
   set h_val f
   set h_val [string repeat $h_val $f_bits]
   return $fmat$h_val
 }

 #Proc to get called from TCL Console
 proc add_tb_modules {bd_cell} {
   set rst_dict $::bd::tb::rst_dict
   set clk_dict $::bd::tb::clk_dict

   connect_intf_pins [get_bd_intf_pins -of_objects $bd_cell] $bd_cell
   connect_bd_pins [get_bd_pins -of_objects $bd_cell] $clk_dict $bd_cell
   connect_bd_pins [get_bd_pins -of_objects $bd_cell] $rst_dict $bd_cell
 }
} 
# namespace ::bd::tb::

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
