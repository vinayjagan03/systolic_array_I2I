%.log: 
	@if [ ! -f ./src/testbench/$*_bind.sv ]; then \
	    echo "// Empty file" > ./src/testbench/$*_bind.sv; \
	fi
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/$*.sv \
	     ./src/testbench/$*_tb.sv \
	     ./src/testbench/$*_bind.sv 

%.sim: %.log
	vsim -coverage -c -voptargs="+acc" work.$*_tb -do  "coverage save -onexit $*_coverage.ucdb; run -all; quit" > ./simout/simout.txt

%.wav: %.log
	vsim -coverage -voptargs="+acc" work.$*_tb -do "view objects; do ./waveforms/$*.do; run -all;" -onfinish stop

lint_%:
	vlog -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/$*.sv
