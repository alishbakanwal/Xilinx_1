# % load_feature core
# 
# This file is sourced by load_feature after features.tcl

rdi::load_library core librdi_tcltasks
rdi::load_library core librdi_coretasks
rdi::load_internal_library core librdi_commontasks_internal
rdi::load_internal_library core librdi_tcltasks_internal

# aliases
interp alias {} set_attribute {} rdi::alias set_attribute set_property
interp alias {} get_attribute {} rdi::alias get_attribute get_property
interp alias {} reset_attribute {} rdi::alias reset_attribute reset_property
interp alias {} report_attribute {} rdi::alias report_attribute report_property
interp alias {} list_attribute_value {} rdi::alias list_attribute_value list_property_value
interp alias {} list_attribute {} rdi::alias list_attribute list_property

# PR603480 for Rodin Beta 4. Remove these aliases possibly in Rodin 1.0
interp alias {} device::get_bels {} rdi::alias device::get_bels get_bels
interp alias {} device::get_clock_regions {} rdi::alias device::get_clock_regions get_clock_regions
interp alias {} device::get_nodes {} rdi::alias device::get_nodes get_nodes
interp alias {} device::get_site_pins {} rdi::alias device::get_site_pins get_site_pins
interp alias {} device::get_tiles {} rdi::alias device::get_tiles get_tiles
interp alias {} device::get_pips {} rdi::alias device::get_pips get_pips
interp alias {} device::get_wires {} rdi::alias device::get_wires get_wires

# hide aliases from command completion
rdi::hide_commands \
 set_attribute \
 get_attribute \
 reset_attribute \
 report_attribute \
 list_attribute_value \
 list_attribute \
 device::get_bels \
 device::get_clock_regions \
 device::get_nodes \
 device::get_site_pins \
 device::get_tiles \
 device::get_pips \
 device::get_wires

# dont auto complete certain namespaces
rdi::hide_namespaces rdi:: tcl:: test:: utils:: tclapp::

# do not auto complete ip namespaces
rdi::hide_namespaces ipgen:: ipgui:: ipsys:: ipx:: ipxit:: xit:: 

source -notrace [rdi::utils::find_approot_file "scripts/deprecated.tcl"]

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
