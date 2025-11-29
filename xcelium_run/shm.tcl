###############################################################
# shm.tcl — Adaptive SHM dump into fixed shm_out directory
# Uses Tcl arguments (argv) from xrun -tclargs
###############################################################

# Expect DESIGN from tclargs
if {[llength $argv] < 1} {
    puts "ERROR: DESIGN not passed to shm.tcl via -tclargs"
    exit 1
}

set DESIGN [lindex $argv 0]

set SHM_PATH "../src/testbench/shm_out"
set TOP_TB   "tb_${DESIGN}"

puts "INFO: DESIGN        = $DESIGN"
puts "INFO: SHM Output    = $SHM_PATH"
puts "INFO: Top Testbench = $TOP_TB"

# Open SHM database (fixed directory)
database -open shmdb -shm -default -into $SHM_PATH

# Probe everything (signals + memories)
probe -all -ports -shm -memories -depth all -packed 1000000


run
exit

