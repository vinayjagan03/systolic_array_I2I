%.log: 
	@if [ ! -f ./src/testbench/$*_bind.sv ]; then \
	    echo "// Empty file" > ./src/testbench/$*_bind.sv; \
	fi
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/$*.sv \

%.sim: %.log
	vsim -coverage -c -voptargs="+acc" tb_$* -do  "run -all; quit"

%.wav: %.log
	vsim -coverage -voptargs="+acc" work.tb_$* -do "view objects; do ./waveforms/$*.do; run -all;" -onfinish stop

systolic_array.sim:
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/processing_element.sv \
	     ./src/modules/systolic_array.sv \
	     ./src/testbench/tb_systolic_array.sv ./src/testbench/systolic_array_bind.sv

	vsim -coverage -c -voptargs="+acc" tb_systolic_array -do  "run -all; quit"

systolic_array.wav:
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/processing_element.sv \
	     ./src/modules/systolic_array.sv \
	     ./src/testbench/tb_systolic_array.sv ./src/testbench/systolic_array_bind.sv

	vsim -coverage -voptargs="+acc" tb_systolic_array -do "view objects; do ./waveforms/wave.do; run -all;"


lint_%:
	vlog -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/$*.sv
