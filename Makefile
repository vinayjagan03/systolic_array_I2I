%.log: 
	@if [ ! -f ./src/testbench/$*_bind.sv ]; then \
	    echo "// Empty file" > ./src/testbench/$*_bind.sv; \
	fi
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/$*.sv \
		 ./src/testbench/tb_$*.sv

%.sim: %.log
	vsim -coverage -c -voptargs="+acc" tb_$* -do  "run -all; quit"

%.wav: %.log
	vsim -coverage -voptargs="+acc" tb_$* -do "view objects; do ./waveforms/$*.do; run -all;" -onfinish stop

systolic_array.sim:
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
		 ./src/modules/fp32_add.sv ./src/modules/fp32_mul.sv ./src/modules/fp32_mac.sv \
	     ./src/modules/processing_element.sv \
	     ./src/modules/systolic_array.sv \
	     ./src/testbench/tb_systolic_array.sv 

	vsim -coverage -c -voptargs="+acc" tb_systolic_array -do  "run -all; quit"

systolic_array.wav:
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
		 ./src/modules/fp32_add.sv ./src/modules/fp32_mul.sv ./src/modules/fp32_mac.sv \
	     ./src/modules/processing_element.sv \
	     ./src/modules/systolic_array.sv \
	     ./src/testbench/tb_systolic_array.sv 

	vsim -coverage -voptargs="+acc" tb_systolic_array -do "view objects; do ./waveforms/wave.do; run -all;"


sys_array_riya.sim:
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint=full +incdir+./src/include/ \
		 ./src/modules/fp32_add.sv ./src/modules/fp32_mul.sv ./src/modules/fp32_mac.sv \
	     ./src/modules/processing_element.sv \
	     ./src/modules/systolic_array.sv \
	     ./src/modules/sram_0rw1r1w_32_64_freepdk45.sv ./src/modules/top_pd_working.sv ./src/testbench/tb_working.sv

	vsim -coverage -c -voptargs="+acc" tb_sa_spad_top -do  "run -all; quit"

sys_array_riya.wav:
	vlog -compile_uselibs -cover bs -sv -pedanticerrors -lint +incdir+./src/include/ \
		 ./src/modules/fp32_add.sv ./src/modules/fp32_mul.sv ./src/modules/fp32_mac.sv \
	     ./src/modules/processing_element.sv \
	     ./src/modules/systolic_array.sv \
	     ./src/modules/sram_0rw1r1w_32_64_freepdk45.sv ./src/modules/top_pd_working.sv ./src/testbench/tb_working.sv

	vsim -coverage -voptargs="+acc" tb_sa_spad_top -do "view objects; do ./waveforms/wave.do; run -all;"


lint_%:
	vlog -sv -pedanticerrors -lint +incdir+./src/include/ \
	     ./src/modules/$*.sv
