## Preload jvm as hdi::report hasn't been ported to C side yet
## Reset placer memory monitor afterward
#rdi::load_jvm
#debug::placer_monitor -clear
#debug::placer_monitor -start
#
#source pa_env.tcl
#set_param -name place.hardVerbose -value 469538
#set_param -name place.oldMsgVerbose -value 1
#
#set_param -name edifin.supportNgd2Edif -value yes
#set_param -name place.debugShape -value shape.txt
#set_param -name edifin.autoFunnelFilterName -value "NO_FILTER"
##set_param -name Sweep.delete_driverless_net -value yes
#create_project -w ${top} ${top} -part ${partid}
#set_property design_mode GateLvl [get_property srcset [current_run]]
#set_property edif_top_file ./${top}.edf [get_property srcset [current_run]]
#add_files ./cores
#add_files -fileset [get_property constrset [current_run]] -norecurse [list ./${top}.ucf]
#set_property target_ucf ./${top}.ucf [get_property constrset [current_run]]
#open_netlist_design -srcset [get_property srcset [current_run]] -constrset [get_property constrset [current_run]] -part ${partid} -name netlist_1
#
#set_param -name vladimir -value yes
#set_param -name sta.maxThreads -value 1
#set_param -name place.maxThreads -value 1
#report_stats -file before_opt.rpt
#place_opt -retarget
#place_opt -propconst
#report_stats -file after_cprop.rpt
#place_opt -remap
#report_stats -file after_remap.rpt
#place_opt -sweep
#report_stats -file after_opt.rpt
#place_design
#report_timing -delay_type max -path_type full_clock_expanded -max_paths 20 -nworst 1 -sort_by slack -significant_digits 3 -input_pins  -nets  -results results_place -file ./taResults.txt
#write_edif ./top.edn
#write_ucf {./top.ucf} -mode design
#write_ncd -file ./${top}.map.ncd
#write_pcf -file ./${top}.map.pcf

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
