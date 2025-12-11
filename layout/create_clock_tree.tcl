# Get global settings
source ../global_variables.tcl

# NDR for clock tree tracks (double spacing+width)
create_route_rule -name NDR_ClockTree \
 -width {metal1 0.12 metal2 0.16 metal3 0.16 metal4 0.16 metal5 0.16 metal6 0.16 metal7 0.16 metal8 0.16 metal9 0.16 metal10 0.44 } \
 -spacing {metal1 0.12 metal2 0.14 metal3 0.14 metal4 0.14 metal5 0.14 metal6 0.14 metal7 0.14 metal8 0.14 metal9 0.14 metal10 0.4} \

# Clock tree configuration:
# Routing on layers 9-5 and in between
create_route_type -name ClockTrack -top_preferred_layer 9 -bottom_preferred_layer 5 -route_rule NDR_ClockTree

# Timing targets and track types
# max skew 100 ps (0.1 TU), max transition time 150 ps (0.15 TU)
set_db cts_route_type_leaf ClockTrack
set_db cts_route_type_trunk ClockTrack
set_db cts_target_skew 0.1
set_db cts_target_max_transition_time 0.15

# Save all constraints (above + SDC)
create_clock_tree_spec -out_file $LAYOUT_OUT/clocktree.spec

# Design clock tree
clock_opt_design
