# Set current directory root as variable
set ROOT [file normalize [file dirname [info script]]]

# Base Nangate directory
set NANGATE_BASE /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12

# Set LIB and LEF folder
set LIB_ROOT "$NANGATE_BASE/Front_End/Liberty/NLDM"
set LEF_ROOT "$NANGATE_BASE/Back_End/lef"

puts "ROOT = $ROOT"
puts "LIB_ROOT = $LIB_ROOT"
puts "LEF_ROOT = $LEF_ROOT"

# Set modules and include folder
set MODULES $ROOT/src/modules
set INCLUDE $ROOT/src/include
set TESTBENCH $ROOT/src/testbench

# Set Synthesis Output Directory
set SYNTH_OUT $ROOT/synthesis/outputs

# Set Conformal directory
set CONFRML $ROOT/lec

# Set Layout Output Directory
set LAYOUT_OUT $ROOT/layout/outputs

# Set top module
set TOP top
