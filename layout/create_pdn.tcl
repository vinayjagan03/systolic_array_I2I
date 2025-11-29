# Set up PDN

# Create power rings (VDD, VSS)
# (width = spacing = 3 microns, centered in channel
# between core and I/O)
add_rings -nets {VDD VSS} -type core_rings -follow core \
 -layer {top metal10 bottom metal10 left metal9 right metal9} \
 -width {top 3 bottom 3 left 3 right 3} \
 -spacing {top 3 bottom 3 left 3 right 3} \
 -offset {top 1 bottom 1 left 1 right 1} \
 -center 1 -threshold 0

#add_io_fillers -fill_any_gap

# Create power stripes (VDD, VSS)
# (3 pairs, same width and spacing as with rings)
add_stripes -nets {VDD VSS} -layer metal9 \
 -direction vertical \
 -width 3 -spacing 3 -number_of_sets 3

# Connect global nets VDD and VSS
connect_global_net VDD -type pg_pin -pin_base_name VDD -all
connect_global_net VDD -type tie_hi -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -all
connect_global_net VSS -type tie_lo -inst_base_name *

# Create power+ground pins and connect with rings
create_pg_pin -name VDD -net VDD 
create_pg_pin -name VSS -net VSS  
update_power_vias -add_vias 1 -top_layer metal10 -bottom_layer metal10 -area {6 7 8 9}
update_power_vias -add_vias 1 -top_layer metal10 -bottom_layer metal10 -area {6 7 8 9}

# Create follow pins (logic-to-power connections)
set_db route_special_via_connect_to_shape { stripe }
route_special -connect core_pin \
 -layer_change_range { metal1(1) metal10(10) } \
 -block_pin_target nearest_target \
 -core_pin_target first_after_row_end \
 -allow_jogging 1 \
 -crossover_via_layer_range { metal1(1) metal10(10) } \
 -nets { VSS VDD } -allow_layer_change 1 \
 -target_via_layer_range { metal1(1) metal10(10) }
