# Pin facts: AMD/Xilinx UG810 v1.9, Tables 1-9, 1-20, 1-27.
# The fixed system clock is bank 33 LVDS (not LVDS_25).
set_property PACKAGE_PIN AD12 [get_ports sys_clk_p]
set_property PACKAGE_PIN AD11 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports {sys_clk_p sys_clk_n}]
create_clock -name sys_clk -period 5.000 [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN AB7 IOSTANDARD LVCMOS15} [get_ports cpu_reset]
set_property -dict {PACKAGE_PIN AA12 IOSTANDARD LVCMOS15} [get_ports fault_button]
set_property -dict {PACKAGE_PIN K24 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 8} [get_ports uart_tx]
set pins {AB8 AA8 AC9 AB9 AE26 G19 E18 F16}
for {set i 0} {$i<8} {incr i} {
 set port [get_ports [format {led[%d]} $i]]
 set_property PACKAGE_PIN [lindex $pins $i] $port
 set_property IOSTANDARD [expr {$i<4?"LVCMOS15":"LVCMOS25"}] $port
 set_property SLEW SLOW $port
 set_property DRIVE 8 $port
}
# Asynchronous external controls terminate at reset/button synchronizers.
set_false_path -from [get_ports {cpu_reset fault_button}]
# LEDs and asynchronous UART have no external synchronous capture clock.
set_false_path -to [get_ports {led[*] uart_tx}]
