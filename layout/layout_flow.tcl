# Get global variables
source ../global_variables.tcl

set LOCAL_ROOT [file normalize [file dirname [info script]]]

# Set Scripts Directory
set LAYOUT_SCRIPTS $LOCAL_ROOT

# Set layout report and output directories
set LAYOUT_REPORTS "$LOCAL_ROOT/reports"
set LAYOUT_OUTPUTS  "$LOCAL_ROOT/outputs"


file mkdir $LAYOUT_REPORTS
file mkdir $LAYOUT_OUTPUTS

# Define variables for clarity (Optional but recommended)
set TECH_LEF "$LEF_ROOT/NangateOpenCellLibrary.tech.lef"
set MACRO_LEF "$LEF_ROOT/NangateOpenCellLibrary.macro.lef" 
set STD_CELL_LEF "$LEF_ROOT/NangateOpenCellLibrary.lef"

# Read MMMC file generated from Genus Synthesis
read_mmmc $SYNTH_OUT/mmmc.tcl

read_physical -lef [list $TECH_LEF $MACRO_LEF $STD_CELL_LEF]

read_netlist $SYNTH_OUT/${TOP}_netlist.sv

set_db init_power_nets VDD
set_db init_ground_nets VSS

init_design

create_floorplan -core_margins_by die -core_density_size 2.0 0.7 8 12 8 12

# Create PDN
source [ file join $LAYOUT_SCRIPTS create_pdn.tcl ]

# Perform cell placement
source [ file join $LAYOUT_SCRIPTS configure_placement.tcl ]

# Place design 
place_design
opt_design -pre_cts

# Check placement
check_place

# Generate reports
report_area > $LAYOUT_REPORTS/area_prects.txt
report_power > $LAYOUT_REPORTS/power_prects.txt
time_design -pre_cts -slack_report > $LAYOUT_REPORTS/timing_setup_prects.txt
time_design -pre_cts -hold -slack_report > $LAYOUT_REPORTS/timing_hold_prects.txt
report_gate_count -out_file $LAYOUT_REPORTS/gates_prects.txt
report_qor -format text -file $LAYOUT_REPORTS/qor_prects.txt
report_route -summary > $LAYOUT_REPORTS/route_prects.txt

# Early power rail analysis
#source [ file join $LAYOUT_SCRIPTS early_power_rail.tcl ]

# Early global route
source [ file join $LAYOUT_SCRIPTS early_global_route.tcl ]

# Clock tree synthesis
source [ file join $LAYOUT_SCRIPTS create_clock_tree.tcl ]

report_clock_trees > $LAYOUT_REPORTS/clocktree.txt
report_skew_groups > $LAYOUT_REPORTS/clocktree_skew.txt

# Optimize again after CTS
opt_design -post_cts

report_area > $LAYOUT_REPORTS/area_postcts.txt
report_power > $LAYOUT_REPORTS/power_postcts.txt
time_design -post_cts -slack_report > $LAYOUT_REPORTS/timing_setup_postcts.txt
time_design -post_cts -hold -slack_report > $LAYOUT_REPORTS/timing_hold_postcts.txt
report_gate_count -out_file $LAYOUT_REPORTS/gates_postcts.txt
report_qor -format text -file $LAYOUT_REPORTS/qor_postcts.txt
report_route -summary > $LAYOUT_REPORTS/route_postcts.txt

# Commence final detailed routing
# (layers 1-11, medium effort on vias, timing+SI driven)
set_db route_design_top_routing_layer 10
set_db route_design_bottom_routing_layer 1

#set_db route_design_detail_use_multi_cut_via_effort medium
# high effort instead of medium fixes DRC spacing violation
set_db route_design_concurrent_minimize_via_count_effort high
set_db route_design_detail_fix_antenna true
set_db route_design_with_timing_driven true
set_db route_design_with_si_driven true

route_design -global_detail -via_opt

# default is 'single'. 
# Set here to 'ocv' because postroute says so
set_db timing_analysis_type ocv

# Optimize yet again after routing
opt_design -post_route

report_area > $LAYOUT_REPORTS/area_postroute.txt
report_power > $LAYOUT_REPORTS/power_postroute.txt
report_gate_count -out_file $LAYOUT_REPORTS/gates_postroute.txt
report_qor -format text -file $LAYOUT_REPORTS/qor_postroute.txt
report_route -summary > $LAYOUT_REPORTS/route_postroute.txt

time_design -post_route -slack_report > $LAYOUT_REPORTS/timing_setup_postroute.txt
time_design -post_route -hold -slack_report > $LAYOUT_REPORTS/timing_hold_postroute.txt
set_db timing_analysis_type single

# Run DRC+connectivity checks
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

# Save the final db
write_db savedDesign



