# Get global variables
source ../global_variables.tcl

# Get this script file directory
set LOCAL_ROOT [file normalize [file dirname [info script]]]

# Set power report and output directory
set POWER_REPORT "$LOCAL_ROOT/reports"
set POWER_OUTPUT "$LOCAL_ROOT/outputs"
file mkdir $POWER_REPORT
file mkdir $POWER_OUTPUT

# Load Clean Elaboration DB (from RTL synthesis flow)
#rtlstim2gate -init $SYNTH_OUT/${TOP}_elab.db
set_rtl_stim_to_gate_config -init $SYNTH_OUT/${TOP}_elab.db -keep_libraries

# Read synthesised netlist
read_netlist $SYNTH_OUT/${TOP}_netlist.sv

# Read SDC contraints
read_sdc $SYNTH_OUT/${TOP}_constraints.sdc

# Enable name mapping
#set_rtl_stim_to_gate_config -map_file $SYNTH_OUT/${TOP}_name_mapping.tcl
set_rtl_stim_to_gate_config -map_file $SYNTH_OUT/mapped.rpt
#set_db stim_auto_mapping 1
#set_rtl_stim_to_gate_config -rule generate "%s_%s"

# Read Stimulus
read_stimulus \
    -file $TESTBENCH/shm_out -format shm \
    -dut_instance /tb_${TOP} \
    -report_missing_signals all -out $POWER_REPORT/missing_signals_all.rpt

# Write stimulus to sdb
write_sdb -out $POWER_OUTPUT/${TOP}.sdb

# Report unasserted flops
report_sdb_annotation -show_details reg:unasserted -out $POWER_REPORT/flop_unasserted.rpt 

# Apply RTLStim2Gate RULES
#rtlstim2gate -rule ungroup          {%s %s}
#rtlstim2gate -rule reg_ext          {%s_register_%s}
#rtlstim2gate -rule bit_slice        {[%s]}
#rtlstim2gate -rule array_slice      {_%s_}
#rtlstim2gate -rule hier_slice       {[%s]}
#rtlstim2gate -rule generate         {%s %s}
#rtlstim2gate -rule record           {%s[%s]}

# Computer and Report Power
compute_power
report_power

# Save report to file
report_power -out $POWER_REPORT/${TOP}_power.rpt

# Write joules DB
write_db -to_file $POWER_OUTPUT/${TOP}.jdb
