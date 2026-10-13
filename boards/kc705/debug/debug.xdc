# AMD UG810 v1.9 Table 1-29, FMC LPC J2. VADJ and adapter VTref must be 2.5 V.
set_property -dict {PACKAGE_PIN AD12 IOSTANDARD LVDS} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN AD11 IOSTANDARD LVDS} [get_ports sys_clk_n]
create_clock -name sys_clk -period 5.000 [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN AB7 IOSTANDARD LVCMOS15} [get_ports cpu_reset]
# J2 G6/G7/D8/D9 are ordinary FMC signals, NOT the FMC configuration JTAG chain.
set_property -dict {PACKAGE_PIN AD23 IOSTANDARD LVCMOS25} [get_ports debug_tck]
set_property -dict {PACKAGE_PIN AE24 IOSTANDARD LVCMOS25} [get_ports debug_tms]
set_property -dict {PACKAGE_PIN AE23 IOSTANDARD LVCMOS25} [get_ports debug_tdi]
set_property -dict {PACKAGE_PIN AF23 IOSTANDARD LVCMOS25 SLEW SLOW DRIVE 8} [get_ports debug_tdo]
create_clock -name debug_tck -period 1000.000 [get_ports debug_tck]
set_input_delay -clock debug_tck -max 100 [get_ports {debug_tms debug_tdi}]
set_input_delay -clock debug_tck -min 0 [get_ports {debug_tms debug_tdi}]
set_output_delay -clock debug_tck -max 100 [get_ports debug_tdo]
set_output_delay -clock debug_tck -min 0 [get_ports debug_tdo]
set pins {AB8 AA8 AC9 AB9 AE26 G19 E18 F16}
for {set i 0} {$i<8} {incr i} {
 set port [get_ports [format {led[%d]} $i]]
 set_property PACKAGE_PIN [lindex $pins $i] $port
 set_property IOSTANDARD [expr {$i<4?"LVCMOS15":"LVCMOS25"}] $port
}
set_false_path -from [get_ports cpu_reset]
set_false_path -to [get_ports {led[*]}]
# Toggle CDC first stages only; never hide all paths between the two clocks.
foreach name {req_meta rsp_meta} {
 set cells [get_cells -hier -regexp ".*dtm/${name}_reg"]
 if {[llength $cells]!=1} {error "Missing DTM synchronizer $name"}
 set_false_path -to [get_pins -of_objects $cells -filter {REF_PIN_NAME == D}]
}
# Payload stays fixed until acknowledgement crosses two synchronizer stages.
# Bound data settling below the two-cycle handshake latency in either domain.
foreach name {request_payload response_payload} {
 set cells [get_cells -hier -regexp ".*dtm/${name}_reg\\\[.*\\\]"]
 if {[llength $cells]==0} {error "Missing bundled-data CDC $name"}
 set_max_delay -datapath_only 50 -from [get_pins -of_objects $cells -filter {REF_PIN_NAME == Q}]
}
