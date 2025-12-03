###############################################################
# vcd.tcl — VCD dump using environment variable DESIGN
###############################################################

if {![info exists ::env(DESIGN)]} {
    puts "ERROR: DESIGN not passed via environment variable"
    exit 1
}

set DESIGN $::env(DESIGN)
set VCD_PATH "../src/${DESIGN}.vcd"
set TOP_TB   "tb_${DESIGN}"

puts "INFO: Dumping VCD for DESIGN = $DESIGN"
puts "INFO: VCD Output = $VCD_PATH"
puts "INFO: Top TB     = $TOP_TB"

database -open -vcd vcddb -into $VCD_PATH -default -timescale ns
probe -create -vcd ${TOP_TB}.DUT -all -depth all

run
exit

