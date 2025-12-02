onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/tb_new_working/DUT/sys_array/row[0]/col[0]/pe/clk}
add wave -noupdate {/tb_new_working/DUT/sys_array/row[0]/col[0]/pe/n_rst}
add wave -noupdate -radix float32 {/tb_new_working/DUT/sys_array/row[0]/col[0]/pe/x_i}
add wave -noupdate -radix float32 {/tb_new_working/DUT/sys_array/row[0]/col[0]/pe/w_i}
add wave -noupdate {/tb_new_working/DUT/sys_array/row[0]/col[0]/pe/current_state}
add wave -noupdate -radix float32 {/tb_new_working/DUT/sys_array/row[0]/col[0]/pe/partial_sum}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {91087 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
configure wave -timelineunits ps
update
WaveRestoreZoom {21787 ps} {208163 ps}
