# запуск в ModelSim: do run_modelsim.do
vlib work
vlog -sv apb_master.sv apb_slave.sv tb_top.sv
vsim -voptargs=+acc work.tb_top
add wave -radix hex /tb_top/*
add wave -radix hex /tb_top/DUT/apb_st
add wave -radix hex /tb_top/DUT/register_with_some_name
run -all
