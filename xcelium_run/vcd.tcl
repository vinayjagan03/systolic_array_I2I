###############################################################
# vcd.tcl — Adaptive VCD dump using Tcl arguments
###############################################################

if {[llength $argv] < 1} {
    puts "ERROR: DESIGN not passed to vcd.tcl via -tclargs"
    exit 1
}

set DESIGN [lindex $argv 0]

set VCD_PATH "../src/testbench/${DESIGN}.vcd"
set TOP_TB   "tb_${DESIGN}"

puts "INFO: Dumping VCD for DESIGN = $DESIGN"
puts "INFO: VCD Output = $VCD_PATH"
puts "INFO: Top TB     = $TOP_TB"

database -open -vcd vcddb \
         -into $VCD_PATH \
         -default -timescale ns

probe -create -vcd ${TOP_TB}.DUT -all -depth all

run
exit

