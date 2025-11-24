# Select timing library, physical lib cells (lef)
# and parasitic capacitances (qrc)

puts $LIB_ROOT
set_db library {/package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12/Front_End/Liberty/NLDM/NangateOpenCellLibrary_typical.lib}
set lef_list [glob /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12/Back_End/lef/*.lef]
set_db lef_library $lef_list

set_db lp_insert_clock_gating false

