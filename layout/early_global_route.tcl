# Get global settings
source ../global_variables.tcl

# Early global route settings
# Top and bottom allowed layers for routing (M1 bottom, M10 top)

set_db route_early_global_bottom_routing_layer 1
set_db route_early_global_top_routing_layer 10

# Run early global route
route_early_global
