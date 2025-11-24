# Set current directory root as variable
set ROOT [file normalize [file dirname [info script]]]
#set LIB_ROOT /mnt/apps/prebuilt/eda/designkits/GPDK/gsclib045/lan/flow/t1u1/reference_libs/GPDK045/gsclib045_svt_v4.4/gsclib045/

set LIB_ROOT /package/eda/cells/NanGate_45nm_OCL_v2010_12/pdk_v1.3_v2010_12/NangateOpenCellLibrary_PDKv1_3_v2010_12/Front_End/Liberty/NLDM

set PKG $ROOT/src/include
set DATA $ROOT/src/modules
set SCRIPTS $ROOT/scripts
set OUTPUT $ROOT/out
set INTERMEDIATE $ROOT/interm
set INTERM_GENUS_INV $INTERMEDIATE/genus_to_innovus
