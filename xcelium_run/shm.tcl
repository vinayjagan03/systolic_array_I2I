###############################################################
# shm.tcl — SHM dump using environment variable DESIGN
###############################################################

if {![info exists ::env(DESIGN)]} {
    puts "ERROR: DESIGN not passed via environment variable"
    exit 1
}

set DESIGN $::env(DESIGN)
set SHM_PATH "../src/shm_out"
set TOP_TB   "tb_${DESIGN}"

puts "INFO: DESIGN        = $DESIGN"
puts "INFO: SHM Output    = $SHM_PATH"
puts "INFO: Top Testbench = $TOP_TB"

database -open shmdb -shm -default -into $SHM_PATH
probe -all -dynamic -ports -shm -memories -depth all

run
exit

