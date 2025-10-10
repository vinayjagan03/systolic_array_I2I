onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/clk}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/n_rst}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/x_i}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/w_i}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/input_start}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/partial_sum}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/x_o}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/w_o}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/data_ready}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/stall}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/current_state}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/next_state}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/fp32_result}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/fp32_ready}
add wave -noupdate -group pe(0,0) {/tb_systolic_array/dut/row[0]/col[0]/pe/start_mac}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/psum_reg}
add wave -noupdate -group pe(0,0) -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/next_psum_reg}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/valid_in}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/ready_in}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/a}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/b}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/c}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/use_acc}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/clr_acc}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/valid_out}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/y}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/m_vld}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/m_res}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/acc_q}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/add_lhs}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/add_rhs}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/add_vin}
add wave -noupdate {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/a_vld}
add wave -noupdate -radix float32 {/tb_systolic_array/dut/row[0]/col[0]/pe/u_fp32_mac/add_res}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {75 ns} 0}
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
WaveRestoreZoom {34 ns} {118 ns}
