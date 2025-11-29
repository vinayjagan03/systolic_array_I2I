# Set search path
set_db init_hdl_search_path [list $MODULES $INCLUDE] 

# Read all required RTL files
read_hdl -language sv {	top.sv
			controller.sv
			fp32_add.sv 
			fp32_mac.sv 
			fp32_mul.sv
			processing_element.sv
			systolic_array.sv
			systolic_array_top.sv
			}


