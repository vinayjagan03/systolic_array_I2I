onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_controller/u_controller/clk
add wave -noupdate /tb_controller/u_controller/n_rst
add wave -noupdate /tb_controller/u_controller/AWVALID
add wave -noupdate /tb_controller/u_controller/AWADDR
add wave -noupdate /tb_controller/u_controller/AWREADY
add wave -noupdate /tb_controller/u_controller/WDVALID
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {201 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 374
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
WaveRestoreZoom {8 ns} {26 ns}
