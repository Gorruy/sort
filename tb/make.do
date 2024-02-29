vlib work

vlog -sv ../rtl/sorting.sv
vlog -sv ../rtl/dual_port_ram.v
vlog -sv ../rtl/bubble_sort.sv
vlog -sv ~/intelFPGA_lite/18.1/quartus/eda/sim_lib/altera_mf.v
vlog -sv top_tb.sv

vsim -novopt top_tb
add log -r /*
add wave -r *
run -all