# Pin constraints for bist_top on the PYNQ-Z2.
# Pin numbers are from my memory of the TUL master XDC: check them against
# the official PYNQ-Z2 master XDC before building.

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
