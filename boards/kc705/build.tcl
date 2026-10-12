# vivado -mode batch -source boards/kc705/build.tcl -tclargs OUTDIR RF_TMR FI WORDS CLK_DIV STAGE
if {$argc!=6} {error "Expected OUTDIR RF_TMR FI WORDS CLK_DIV STAGE"}
lassign $argv output rf_tmr fi words clk_div stage
foreach value [list $rf_tmr $fi $words $clk_div] {if {![string is integer -strict $value]} {error "Non-integer configuration"}}
if {$rf_tmr ni {0 1} || $fi ni {0 1} || $words<1024 || $words>8192 || $clk_div<8 || $clk_div>128 || $stage ni {synth bit}} {error "Invalid KC705 configuration"}
set boarddir [file dirname [file normalize [info script]]]
set root [file dirname [file dirname $boarddir]]
set outdir [file normalize $output]
file mkdir $outdir
if {![file exists [file join $outdir firmware.hex]]} {error "Prepare firmware.hex first"}
cd $outdir
set part xc7k325tffg900-2
if {[llength [get_parts $part]]!=1} {error "Install Kintex-7 device support for $part"}
foreach name {ft_pkg.sv rv32_execute.sv rv32im_ft_core.sv ft_ecc_ram.sv ft_event_monitor.sv rv32im_ft_soc.sv} {
 read_verilog -sv [file join $root rtl $name]
}
foreach name {uart_tx.sv status_uart.sv riscue_kc705.sv} {read_verilog -sv [file join $boarddir $name]}
synth_design -top riscue_kc705 -part $part -flatten_hierarchy none -generic [list RF_TMR=$rf_tmr FI_ENABLE=$fi WORDS=$words CLK_DIV=$clk_div]
read_xdc [file join $boarddir kc705.xdc]
source [file join $boarddir audit_redundancy.tcl]
report_utilization -hierarchical -file utilization_synth.rpt
write_checkpoint -force riscue_synth.dcp
if {$stage eq "synth"} {puts "Synthesis complete; implementation/timing not verified.";exit}
opt_design
place_design
phys_opt_design
route_design
source [file join $boarddir audit_redundancy.tcl]
report_utilization -hierarchical -file utilization_impl.rpt
report_timing_summary -report_unconstrained -file timing.rpt
report_drc -file drc.rpt
report_cdc -file cdc.rpt
write_checkpoint -force riscue_impl.dcp
foreach delay {max min} {
 set paths [get_timing_paths -delay_type $delay -max_paths 1]
 if {[llength $paths]==0} {error "No $delay timing path found"}
 if {[get_property SLACK [lindex $paths 0]]<0} {error "$delay timing failed; inspect timing.rpt and choose a slower CLK_DIV"}
}
set failures [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $failures]!=0} {error "DRC errors remain; inspect drc.rpt"}
write_bitstream -force riscue_kc705.bit
set out [open build-info.txt w]
puts $out "Vivado: [version -short]"
puts $out "Part: $part; RF_TMR=$rf_tmr; FI_ENABLE=$fi; WORDS=$words; CLK_DIV=$clk_div"
puts $out "Firmware initialized from firmware.hex; target is laboratory bring-up."
close $out
