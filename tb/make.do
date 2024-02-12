vlib work

vlog -sv ../rtl/avalon.sv
vlog -sv top_tb.sv

vsim -novopt top_tb
add log -r /*
add wave -r *
run -all