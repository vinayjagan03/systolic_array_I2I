#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Sat Nov 29 01:59:55 2025                
#                                                     
#######################################################

#@(#)CDS: Innovus v25.11-s102_1 (64bit) 08/27/2025 13:03 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: NanoRoute 25.11-s102_1 NR250730-0928/25_11-UB (database version 18.20.674) {superthreading v2.20}
#@(#)CDS: AAE 25.11-s028 (64bit) 08/27/2025 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: CTE 25.11-s034_1 () Aug 18 2025 08:55:47 ( )
#@(#)CDS: SYNTECH 25.11-s013_1 () Jul 30 2025 05:18:51 ( )
#@(#)CDS: CPE v25.11-s029
#@(#)CDS: IQuantus/TQuantus 24.1.0-s290 (64bit) Sun Jul 20 21:40:56 PDT 2025 (Linux 4.18.0-305.el8.x86_64)

#@ source layout_flow.tcl 
#@ Begin verbose source (pre): source layout_flow.tcl 
#@ source ../global_variables.tcl
#@ Begin verbose source ../global_variables.tcl (pre)
set ROOT [file normalize [file dirname [info script]]]
set NANGATE_BASE /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12
set LIB_ROOT "$NANGATE_BASE/Front_End/Liberty/NLDM"
set LEF_ROOT "$NANGATE_BASE/Back_End/lef"
puts "ROOT = $ROOT"
puts "LIB_ROOT = $LIB_ROOT"
puts "LEF_ROOT = $LEF_ROOT"
set MODULES $ROOT/src/modules
set INCLUDE $ROOT/src/include
set TESTBENCH $ROOT/src/testbench
set SYNTH_OUT $ROOT/synthesis/outputs
set CONFRML $ROOT/lec
set LAYOUT_OUT $ROOT/layout/outputs
set TOP top
#@ End verbose source ../global_variables.tcl
set LOCAL_ROOT [file normalize [file dirname [info script]]]
set LAYOUT_SCRIPTS $LOCAL_ROOT
set LAYOUT_REPORTS "$LOCAL_ROOT/reports"
set LAYOUT_OUTPUTS  "$LOCAL_ROOT/outputs"
file mkdir $LAYOUT_REPORTS
file mkdir $LAYOUT_OUTPUTS
set TECH_LEF "$LEF_ROOT/NangateOpenCellLibrary.tech.lef"
set MACRO_LEF "$LEF_ROOT/NangateOpenCellLibrary.macro.lef" 
set STD_CELL_LEF "$LEF_ROOT/NangateOpenCellLibrary.lef"
read_mmmc $SYNTH_OUT/mmmc.tcl
#@ Begin verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/synthesis/outputs/mmmc.tcl (pre)
create_library_set -name default_emulate_libset_max \
    -timing { /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12/Front_End/Liberty/NLDM/NangateOpenCellLibrary_typical.lib }
create_opcond -name default_emulate_opcond \
    -process 1.0 \
    -voltage 1.1 \
    -temperature 25.0
create_timing_condition -name default_emulate_timing_cond_max \
    -opcond default_emulate_opcond \
    -library_sets { default_emulate_libset_max }
create_rc_corner -name default_emulate_rc_corner \
    -temperature 25.0 \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -pre_route_clock_res 0.0 \
    -pre_route_clock_cap 0.0 \
    -post_route_res {1.0 1.0 1.0} \
    -post_route_cap {1.0 1.0 1.0} \
    -post_route_cross_cap {1.0 1.0 1.0} \
    -post_route_clock_res {1.0 1.0 1.0} \
    -post_route_clock_cap {1.0 1.0 1.0} \
    -post_route_clock_cross_cap {1.0 1.0 1.0}
create_delay_corner -name default_emulate_delay_corner \
    -early_timing_condition { default_emulate_timing_cond_max } \
    -late_timing_condition { default_emulate_timing_cond_max } \
    -early_rc_corner default_emulate_rc_corner \
    -late_rc_corner default_emulate_rc_corner
create_constraint_mode -name default_emulate_constraint_mode \
    -sdc_files { /scratch/asicfab/a/vkevat/systolic_array_I2I/synthesis/outputs/default_emulate_constraint_mode.sdc }
create_analysis_view -name default_emulate_view \
    -constraint_mode default_emulate_constraint_mode \
    -delay_corner default_emulate_delay_corner
set_analysis_view -setup { default_emulate_view } \
                  -hold { default_emulate_view }
#@ End verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/synthesis/outputs/mmmc.tcl
read_physical -lef [list $TECH_LEF $MACRO_LEF $STD_CELL_LEF]
read_netlist $SYNTH_OUT/${TOP}_netlist.sv
set_db init_power_nets VDD
set_db init_ground_nets VSS
init_design
create_floorplan -core_margins_by die -core_density_size 2.0 0.7 8 12 8 12
#@ source [ file join $LAYOUT_SCRIPTS create_pdn.tcl ]
#@ Begin verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/create_pdn.tcl (pre)
add_rings -nets {VDD VSS} -type core_rings -follow core \
 -layer {top metal10 bottom metal10 left metal9 right metal9} \
 -width {top 3 bottom 3 left 3 right 3} \
 -spacing {top 3 bottom 3 left 3 right 3} \
 -offset {top 1 bottom 1 left 1 right 1} \
 -center 1 -threshold 0
add_stripes -nets {VDD VSS} -layer metal9 \
 -direction vertical \
 -width 3 -spacing 3 -number_of_sets 3
connect_global_net VDD -type pg_pin -pin_base_name VDD -all
connect_global_net VDD -type tie_hi -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -all
connect_global_net VSS -type tie_lo -inst_base_name *
create_pg_pin -name VDD -net VDD 
create_pg_pin -name VSS -net VSS  
update_power_vias -add_vias 1 -top_layer metal10 -bottom_layer metal10 -area {6 7 8 9}
update_power_vias -add_vias 1 -top_layer metal10 -bottom_layer metal10 -area {6 7 8 9}
set_db route_special_via_connect_to_shape { stripe }
route_special -connect core_pin \
 -layer_change_range { metal1(1) metal10(10) } \
 -block_pin_target nearest_target \
 -core_pin_target first_after_row_end \
 -allow_jogging 1 \
 -crossover_via_layer_range { metal1(1) metal10(10) } \
 -nets { VSS VDD } -allow_layer_change 1 \
 -target_via_layer_range { metal1(1) metal10(10) }
#@ End verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/create_pdn.tcl
#@ source [ file join $LAYOUT_SCRIPTS configure_placement.tcl ]
#@ Begin verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/configure_placement.tcl (pre)
set_db place_design_floorplan_mode false
set_db place_design_refine_place true
set_db place_global_cong_effort auto
set_db place_global_place_io_pins true
set_db opt_effort high 
set_db opt_power_effort none 
set_db opt_remove_redundant_insts true
set_db opt_area_recovery default
set_db opt_leakage_to_dynamic_ratio 1.0
#@ End verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/configure_placement.tcl
place_design
opt_design -pre_cts
check_place
report_area > $LAYOUT_REPORTS/area_prects.txt
report_power > $LAYOUT_REPORTS/power_prects.txt
time_design -pre_cts -slack_report > $LAYOUT_REPORTS/timing_setup_prects.txt
time_design -pre_cts -hold -slack_report > $LAYOUT_REPORTS/timing_hold_prects.txt
report_gate_count -out_file $LAYOUT_REPORTS/gates_prects.txt
report_qor -format text -file $LAYOUT_REPORTS/qor_prects.txt
report_route -summary > $LAYOUT_REPORTS/route_prects.txt
#@ source [ file join $LAYOUT_SCRIPTS early_global_route.tcl ]
#@ Begin verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/early_global_route.tcl (pre)
#@ source ../global_variables.tcl
#@ Begin verbose source ../global_variables.tcl (pre)
set ROOT [file normalize [file dirname [info script]]]
set NANGATE_BASE /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12
set LIB_ROOT "$NANGATE_BASE/Front_End/Liberty/NLDM"
set LEF_ROOT "$NANGATE_BASE/Back_End/lef"
puts "ROOT = $ROOT"
puts "LIB_ROOT = $LIB_ROOT"
puts "LEF_ROOT = $LEF_ROOT"
set MODULES $ROOT/src/modules
set INCLUDE $ROOT/src/include
set TESTBENCH $ROOT/src/testbench
set SYNTH_OUT $ROOT/synthesis/outputs
set CONFRML $ROOT/lec
set LAYOUT_OUT $ROOT/layout/outputs
set TOP top
#@ End verbose source ../global_variables.tcl
set_db route_early_global_bottom_routing_layer 1
set_db route_early_global_top_routing_layer 10
route_early_global
#@ End verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/early_global_route.tcl
#@ source [ file join $LAYOUT_SCRIPTS create_clock_tree.tcl ]
#@ Begin verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/create_clock_tree.tcl (pre)
#@ source ../global_variables.tcl
#@ Begin verbose source ../global_variables.tcl (pre)
set ROOT [file normalize [file dirname [info script]]]
set NANGATE_BASE /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12
set LIB_ROOT "$NANGATE_BASE/Front_End/Liberty/NLDM"
set LEF_ROOT "$NANGATE_BASE/Back_End/lef"
puts "ROOT = $ROOT"
puts "LIB_ROOT = $LIB_ROOT"
puts "LEF_ROOT = $LEF_ROOT"
set MODULES $ROOT/src/modules
set INCLUDE $ROOT/src/include
set TESTBENCH $ROOT/src/testbench
set SYNTH_OUT $ROOT/synthesis/outputs
set CONFRML $ROOT/lec
set LAYOUT_OUT $ROOT/layout/outputs
set TOP top
#@ End verbose source ../global_variables.tcl
create_route_rule -name NDR_ClockTree \
 -width {metal1 0.12 metal2 0.16 metal3 0.16 metal4 0.16 metal5 0.16 metal6 0.16 metal7 0.16 metal8 0.16 metal9 0.16 metal10 0.44 } \
 -spacing {metal1 0.12 metal2 0.14 metal3 0.14 metal4 0.14 metal5 0.14 metal6 0.14 metal7 0.14 metal8 0.14 metal9 0.14 metal10 0.4} \

create_route_type -name ClockTrack -top_preferred_layer 9 -bottom_preferred_layer 5 -route_rule NDR_ClockTree
set_db cts_route_type_leaf ClockTrack
set_db cts_route_type_trunk ClockTrack
set_db cts_target_skew 0.1
set_db cts_target_max_transition_time 0.15
create_clock_tree_spec -out_file $LAYOUT_OUT/clocktree.spec
clock_opt_design
#@ End verbose source /scratch/asicfab/a/vkevat/systolic_array_I2I/layout/create_clock_tree.tcl
report_clock_trees > $LAYOUT_REPORTS/clocktree.txt
report_skew_groups > $LAYOUT_REPORTS/clocktree_skew.txt
opt_design -post_cts
report_area > $LAYOUT_REPORTS/area_postcts.txt
report_power > $LAYOUT_REPORTS/power_postcts.txt
time_design -post_cts -slack_report > $LAYOUT_REPORTS/timing_setup_postcts.txt
time_design -post_cts -hold -slack_report > $LAYOUT_REPORTS/timing_hold_postcts.txt
report_gate_count -out_file $LAYOUT_REPORTS/gates_postcts.txt
report_qor -format text -file $LAYOUT_REPORTS/qor_postcts.txt
report_route -summary > $LAYOUT_REPORTS/route_postcts.txt
set_db route_design_top_routing_layer 10
set_db route_design_bottom_routing_layer 1
set_db route_design_concurrent_minimize_via_count_effort high
set_db route_design_detail_fix_antenna true
set_db route_design_with_timing_driven true
set_db route_design_with_si_driven true
route_design -global_detail -via_opt
set_db timing_analysis_type ocv
opt_design -post_route
report_area > $LAYOUT_REPORTS/area_postroute.txt
report_power > $LAYOUT_REPORTS/power_postroute.txt
report_gate_count -out_file $LAYOUT_REPORTS/gates_postroute.txt
report_qor -format text -file $LAYOUT_REPORTS/qor_postroute.txt
report_route -summary > $LAYOUT_REPORTS/route_postroute.txt
time_design -post_route -slack_report > $LAYOUT_REPORTS/timing_setup_postroute.txt
time_design -post_route -hold -slack_report > $LAYOUT_REPORTS/timing_hold_postroute.txt
set_db timing_analysis_type single
set_db check_drc_disable_rules {}
set_db check_drc_implant true
set_db check_drc_implant_across_rows false
set_db check_drc_ndr_spacing false
set_db check_drc_check_only default
set_db check_drc_inside_via_def false
set_db check_drc_exclude_pg_net false
set_db check_drc_ignore_trial_route false
set_db check_drc_use_min_spacing_on_block_obs auto
set_db check_drc_report $LAYOUT_REPORTS/${TOP}.drc.rpt
set_db check_drc_limit 1000
check_drc
check_connectivity -type all
write_db savedDesign
#@ End verbose source: layout_flow.tcl
gui_select -rect {32.31950 80.07200 84.79200 28.96250}
gui_select -point {111.59650 53.94950}
gui_select -point {133.17600 106.87650}
exit
