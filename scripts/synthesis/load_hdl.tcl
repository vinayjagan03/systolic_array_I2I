# Read the Verilog in (with syntax check)
read_hdl -sv systolic_array_pkg.svh
read_hdl -sv {top.sv 
systolic_array.sv 
controller.sv 
fp32_add.sv 
fp32_mac.sv 
fp32_mul.sv 
processing_element.sv 
systolic_array_top.sv}

# Parse + optimize the Verilog
#
# NOTE: There are multiple designs that are
# recognized as top-level after read_hdl and a simple
# elaboration. 
# By passing the desired module as argument we
# only work on that and its dependencies -> it's also
# set as top-level automatically
elaborate top

# Check design for completeness
check_design top

# Top-level module after elaboration is given by
# current_design. If ambiguous (not the case here)
# we can choose with set_top_module which one we
# want to work with.

set_top_module top
puts "<=INFO=> Current top level module: top"
