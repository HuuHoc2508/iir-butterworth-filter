# IIR Filter Timing Constraints
# Quartus II SDC File

#**************************************************************
# Clock Constraints
#**************************************************************

# Main Wishbone clock - 50 MHz (20ns period)
create_clock -name "wb_clk_i" -period 20.000 [get_ports {wb_clk_i}]

# Derive PLL clocks (if any)
derive_pll_clocks

# Derive clock uncertainty
derive_clock_uncertainty

#**************************************************************
# Input/Output Delays
#**************************************************************

# Input delay - assume 2ns from external register
set_input_delay -clock wb_clk_i -max 2.0 [get_ports {wb_dat_i[*]}]
set_input_delay -clock wb_clk_i -max 2.0 [get_ports {wb_adr_i[*]}]
set_input_delay -clock wb_clk_i -max 2.0 [get_ports {wb_we_i}]
set_input_delay -clock wb_clk_i -max 2.0 [get_ports {wb_stb_i}]
set_input_delay -clock wb_clk_i -max 2.0 [get_ports {wb_cyc_i}]
set_input_delay -clock wb_clk_i -max 2.0 [get_ports {wb_rst_i}]

set_input_delay -clock wb_clk_i -min 0.5 [get_ports {wb_dat_i[*]}]
set_input_delay -clock wb_clk_i -min 0.5 [get_ports {wb_adr_i[*]}]
set_input_delay -clock wb_clk_i -min 0.5 [get_ports {wb_we_i}]
set_input_delay -clock wb_clk_i -min 0.5 [get_ports {wb_stb_i}]
set_input_delay -clock wb_clk_i -min 0.5 [get_ports {wb_cyc_i}]
set_input_delay -clock wb_clk_i -min 0.5 [get_ports {wb_rst_i}]

# Output delay - assume 2ns to external register
set_output_delay -clock wb_clk_i -max 2.0 [get_ports {wb_dat_o[*]}]
set_output_delay -clock wb_clk_i -max 2.0 [get_ports {wb_ack_o}]

set_output_delay -clock wb_clk_i -min 0.5 [get_ports {wb_dat_o[*]}]
set_output_delay -clock wb_clk_i -min 0.5 [get_ports {wb_ack_o}]

#**************************************************************
# False Paths
#**************************************************************

# Reset is asynchronous
set_false_path -from [get_ports {wb_rst_i}]
