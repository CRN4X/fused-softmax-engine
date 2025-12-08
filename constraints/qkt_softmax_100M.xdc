
create_clock -period 16.000 -name clk -waveform {0.000 8.000} [get_ports clk]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.020 [get_ports {k_j[*]}]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.040 [get_ports {k_j[*]}]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.400 [get_ports {num_queries[*]}]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.600 [get_ports {num_queries[*]}]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.020 [get_ports {q_i[*]}]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.040 [get_ports {q_i[*]}]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.100 [get_ports rst_]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.200 [get_ports rst_]
set_input_delay -clock [get_clocks clk] -min -add_delay 0.020 [get_ports start]
set_input_delay -clock [get_clocks clk] -max -add_delay 0.040 [get_ports start]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports {dk_idx[*]}]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.030 [get_ports {dk_idx[*]}]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports {key_idx[*]}]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.030 [get_ports {key_idx[*]}]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports {softmax_idx[*]}]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.030 [get_ports {softmax_idx[*]}]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports {softmax_j[*]}]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.030 [get_ports {softmax_j[*]}]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports done]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.030 [get_ports done]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports valid_out]
set_output_delay -clock [get_clocks clk] -max -add_delay 0.030 [get_ports valid_out]
set_property LOAD 20 [get_ports {dk_idx[0]}]
set_property LOAD 20 [get_ports {dk_idx[1]}]
set_property LOAD 20 [get_ports {dk_idx[2]}]
set_property LOAD 20 [get_ports {dk_idx[3]}]
set_property LOAD 20 [get_ports {dk_idx[4]}]
set_property LOAD 20 [get_ports {dk_idx[5]}]
set_property LOAD 20 [get_ports done]
set_property LOAD 20 [get_ports {key_idx[0]}]
set_property LOAD 20 [get_ports {key_idx[1]}]
set_property LOAD 20 [get_ports {key_idx[2]}]
set_property LOAD 20 [get_ports {key_idx[3]}]
set_property LOAD 20 [get_ports {key_idx[4]}]
set_property LOAD 20 [get_ports {key_idx[5]}]
set_property LOAD 20 [get_ports {key_idx[6]}]
set_property LOAD 20 [get_ports {key_idx[7]}]
set_property LOAD 20 [get_ports {key_idx[8]}]
set_property LOAD 20 [get_ports {softmax_idx[0]}]
set_property LOAD 20 [get_ports {softmax_idx[1]}]
set_property LOAD 20 [get_ports {softmax_idx[2]}]
set_property LOAD 20 [get_ports {softmax_idx[3]}]
set_property LOAD 20 [get_ports {softmax_idx[4]}]
set_property LOAD 20 [get_ports {softmax_idx[5]}]
set_property LOAD 20 [get_ports {softmax_idx[6]}]
set_property LOAD 20 [get_ports {softmax_idx[7]}]
set_property LOAD 20 [get_ports {softmax_j[0]}]
set_property LOAD 20 [get_ports {softmax_j[10]}]
set_property LOAD 20 [get_ports {softmax_j[11]}]
set_property LOAD 20 [get_ports {softmax_j[1]}]
set_property LOAD 20 [get_ports {softmax_j[2]}]
set_property LOAD 20 [get_ports {softmax_j[3]}]
set_property LOAD 20 [get_ports {softmax_j[4]}]
set_property LOAD 20 [get_ports {softmax_j[5]}]
set_property LOAD 20 [get_ports {softmax_j[6]}]
set_property LOAD 20 [get_ports {softmax_j[7]}]
set_property LOAD 20 [get_ports {softmax_j[8]}]
set_property LOAD 20 [get_ports {softmax_j[9]}]
set_property LOAD 20 [get_ports valid_out]
set_switching_activity -default_static_probability 0.200
set_switching_activity -toggle_rate 12.500 -type {lut} -static_probability 0.200 -all 
set_switching_activity -toggle_rate 12.500 -type {register} -static_probability 0.200 -all 
set_switching_activity -toggle_rate 12.500 -type {shift_register} -static_probability 0.200 -all 
set_switching_activity -toggle_rate 12.500 -type {dsp} -static_probability 0.200 -all 
set_switching_activity -deassert_resets 
set_switching_activity -default_toggle_rate 20.000
set_switching_activity -default_static_probability 0.400
set_switching_activity -toggle_rate 20.000 -type {lut} -static_probability 0.400 -all 
set_switching_activity -toggle_rate 20.000 -type {register} -static_probability 0.400 -all 
set_switching_activity -toggle_rate 20.000 -type {shift_register} -static_probability 0.400 -all 
set_switching_activity -toggle_rate 20.000 -type {dsp} -static_probability 0.400 -all 
set_switching_activity -deassert_resets 
set_switching_activity -toggle_rate 20.000 -type {lut} -static_probability 0.400 -all 
set_switching_activity -toggle_rate 20.000 -type {register} -static_probability 0.400 -all 
set_switching_activity -toggle_rate 20.000 -type {shift_register} -static_probability 0.400 -all 
set_switching_activity -toggle_rate 20.000 -type {dsp} -static_probability 0.400 -all 

set_input_delay -clock [get_clocks *] 1.000 [get_ports start]


