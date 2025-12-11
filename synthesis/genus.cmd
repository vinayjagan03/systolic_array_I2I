# Cadence Genus(TM) Synthesis Solution, Version 25.11-s095_1, built Aug 12 2025 10:59:05

# Date: Fri Nov 28 23:17:00 2025
# Host: asicfab.ecn.purdue.edu (x86_64 w/Linux 4.18.0-553.84.1.el8_10.x86_64) (24cores*96cpus*2physical cpus*AMD EPYC 7352 24-Core Processor 512KB)
# OS:   Red Hat Enterprise Linux 8.10 (Ootpa)

source synthesis_flow.tcl
write_do_lec -golden_design rtl -revised_design $SYNTH_OUTPUTS/${TOP}_netlist.sv > $CONFRML/${TOP}_lec.tcl
exit
