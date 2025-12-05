onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/clk}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/n_rst}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/input_start}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/x_i}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/w_i}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/x_o}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/w_o}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/add_res}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/m_res}
add wave -noupdate {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/y}
add wave -noupdate -expand -group adder {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/U_ADD/valid_in}
add wave -noupdate -expand -group adder {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/U_ADD/a}
add wave -noupdate -expand -group adder {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/U_ADD/b}
add wave -noupdate -expand -group adder {/tb_top/DUT/u_systolic_array_top/sys_array/row[0]/col[0]/pe/u_fp32_mac/U_ADD/mant_res}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {339569 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 499
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
WaveRestoreZoom {270687 ps} {399313 ps}
