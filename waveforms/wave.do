onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/clk}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/n_rst}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/x_i}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/w_i}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/input_start}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/partial_sum}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/x_o}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/w_o}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/data_ready}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/stall}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/current_state}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/next_state}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/fp32_result}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/fp32_ready}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/start_mac}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/psum_reg}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/next_psum_reg}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {17 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 315
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {200 ns}
