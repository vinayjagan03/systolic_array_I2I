# Power analysis settings
set_db power_method static
set_db power_view default_emulate_view
set_db power_corner max
set_db power_write_db true
set_db power_write_static_currents true
set_db power_honor_negative_energy true
set_db power_ignore_control_signals true

set_power_output_dir interm/layout/power_analysis
set_default_switching_activity -input_activity 0.2 -period 1.0
read_activity_file -reset
set_power -reset
set_dynamic_power_simulation -reset
report_power -rail_analysis_format VS -out_file interm/layout/power_analysis/systolic_array.rpt

# Early power rail analysis
# NOTE: xd (accelerated) accuracy means early, hd means signoff
set_rail_analysis_config -method era_static \
 -power_switch_eco false -write_movies false \
 -write_voltage_waveforms false \
 -write_decap_eco true \
 -accuracy xd \
 -analysis_view default_emulate_view \
 -process_techgen_em_rules false \
 -enable_rlrp_analysis false \
 -extraction_tech_file /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/captables/NCSU_FreePDK_45nm.capTbl


# Prepare XY file for pads
write_power_pads -auto_fetch -net VDD -voltage_source_file interm/layout/power_analysis/systolic_array_vdd.pp

# Run analysis
set_pg_nets -net VDD -voltage 1.1 -threshold 1.0
set_power_data -format current -scale 1 interm/layout/power_analysis/static_VDD.ptiavg
set_power_pads -net VDD -format xy -file interm/layout/power_analysis/systolic_array_vdd.pp
set_package -spice_model_file {} -mapping_file {}
report_rail -type net -results_directory interm/layout/power_analysis VDD



