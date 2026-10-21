# Pin constraints for bist_top on the PYNQ-Z2.
# Pin numbers checked against the official pynq-z2_v1.0.xdc (sysclk, sw[0],
# led[0..3], btn[0]); ports renamed to match the bist_top port names.

# 125 MHz system clock
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 8.000 -name sys_clk [get_ports clk]

# BTN0 = reset, SW0 = fault injection
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports btn_rst]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports sw_inject]

# LD0..LD3
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# Button and switch are asynchronous, human-speed inputs (already 2-FF synchronised)
set_false_path -from [get_ports {btn_rst sw_inject}]

# LEDs are human-speed outputs with no external timing requirement
set_false_path -to [get_ports {led[*]}]
