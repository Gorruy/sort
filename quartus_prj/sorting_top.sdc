set_time_format -unit ns -decimal_places 3

create_clock -period 6.667 -name clk_150 -waveform {0.000 3.333} [get_ports clk_i]

derive_pll_clocks