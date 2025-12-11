# Get global variables
source ../global_variables.tcl

set LOCAL_ROOT [file normalize [file dirname [info script]]]

set SCRIPTS $LOCAL_ROOT

# Set synthesis report and output directories
set SYNTH_REPORTS "$LOCAL_ROOT/reports"
set SYNTH_OUTPUTS  "$LOCAL_ROOT/outputs"

file mkdir $SYNTH_REPORTS
file mkdir $SYNTH_OUTPUTS

# Set Libs and Verilog search path
set_db init_lib_search_path $LIB_ROOT
set_db init_hdl_search_path [list $MODULES $INCLUDE] 

# Load technology libraries
source [file join $SCRIPTS init_libraries.tcl]

# Read HDL
source [file join $SCRIPTS load_hdl.tcl]

# Conformal FV directory
set_db verification_directory $CONFRML
set_db verification_directory_naming_style $CONFRML/fv/%s

# Elaborate design
elaborate $TOP

# Write Elaboration DB for Joules
write_db -to_file $SYNTH_OUTPUTS/${TOP}_elab.db

# Check design for completeness
check_design $TOP

# Read SDC
read_sdc $SCRIPTS/constraints.sdc

# Check if timing constraints are complete
check_timing_intent

syn_gen
syn_map
syn_opt

# Export reports
report_area > $SYNTH_REPORTS/area.rpt
report_power > $SYNTH_REPORTS/power.rpt
report_timing > $SYNTH_REPORTS/timing.rpt
report_gates > $SYNTH_REPORTS/gates.rpt
report_qor > $SYNTH_REPORTS/qor.rpt

# Export final design netlist + constraints used
write_hdl > $SYNTH_OUTPUTS/${TOP}_netlist.sv
write_sdc > $SYNTH_OUTPUTS/${TOP}_constraints.sdc
write_name_mapping -to_file $SYNTH_OUTPUTS/${TOP}_name_mapping.tcl

# Make a dofile for LEC
write_do_lec -golden_design rtl -revised_design $SYNTH_OUTPUTS/${TOP}_netlist.sv > $CONFRML/${TOP}_lec.tcl

# Write sdf
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > $SYNTH_OUTPUTS/${TOP}.sdf

# Write mmmc file for innovus
write_mmmc -dir $SYNTH_OUTPUTS
