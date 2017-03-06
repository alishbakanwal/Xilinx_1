############################################################################
# This file to create sc_metadata for all the IPs using C-Model and System C#
############################################################################

namespace eval ::bd::sc_cosim {
  namespace export \
      get_systemc_metadata_dict
}

proc ::bd::sc_cosim::get_systemc_metadata_dict { cellpath } {
  set cell [get_bd_cells $cellpath]
  set clk_pins [get_bd_pins -filter {TYPE == "clk"} -of $cell]
  foreach clk_pin $clk_pins {
    set clk_name [lindex [split $clk_pin /] end]
    set clk_dict [dict create freq [get_property CONFIG.FREQ_HZ $clk_pin]]
    dict append clk_dict domain [get_property CONFIG.CLK_DOMAIN $clk_pin]
    dict append clk_dict phase [get_property CONFIG.PHASE $clk_pin]
    dict append clk_dict clk_id [dict get $clk_dict domain]_[dict get $clk_dict freq]_[ expr int([dict get $clk_dict phase]) ]
    dict append dict_of_clkdict $clk_name $clk_dict
  }
  return $dict_of_clkdict
}
