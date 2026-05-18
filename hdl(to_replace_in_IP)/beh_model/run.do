vlib work
vmap work work

vlog +acc +sv Neuromorphic_X1_Beh.v Neuromorphic_X1_wb_tb.v

vsim work.Neuromorphic_X1_wb_tb

add wave -position insertpoint sim:/Neuromorphic_X1_wb_tb/*
add wave -position insertpoint sim:/Neuromorphic_X1_wb_tb/dut/core_inst/*

run -all