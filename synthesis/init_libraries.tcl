# Select timing library, physical lib cells (lef)

# Nangate 45nm
set_db init_lib_search_path $LIB_ROOT
set_db library NangateOpenCellLibrary_typical.lib

set TECH_LEF "$LEF_ROOT/NangateOpenCellLibrary.tech.lef"
set MACRO_LEF "$LEF_ROOT/NangateOpenCellLibrary.macro.lef" 
set STD_CELL_LEF "$LEF_ROOT/NangateOpenCellLibrary.lef"
set_db lef_library [list $TECH_LEF $MACRO_LEF $STD_CELL_LEF]

