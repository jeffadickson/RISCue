# Board release remains TMR until a parity mapped-netlist audit exists.
if {[info exists ::env(PIPELINE_PROTECTION)] && $::env(PIPELINE_PROTECTION) ne "TMR"} {
 error "This board flow supports PIPELINE_PROTECTION=TMR only; PARITY_REPLAY is simulation experimental"
}
# vivado -mode batch -source boards/kc705/build.tcl -tclargs OUTDIR RF_TMR FI WORDS CLK_DIV STAGE
if {$argc ni {6 7}} {error "Expected OUTDIR RF_TMR FI WORDS CLK_DIV STAGE"}
lassign $argv output rf_tmr fi words clk_div stage instrumented
if {$instrumented eq ""} {set instrumented 0}
if {$instrumented ni {0 1} || ($instrumented && !$fi)} {error "Instrumentation requires FI=1"}
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
if {$instrumented} {source [file join $boarddir lab create_debug_ip.tcl]}
foreach name {ft_pkg.sv riscue_pipeline_pkg.sv riscue_rvc.sv riscue_jump_target.sv riscue_execute.sv riscue_muldiv.sv riscue_pipeline_core.sv ft_ecc_ram.sv ft_event_monitor.sv riscue_pipeline_soc.sv fi_campaign_controller.sv riscue_axi_master_bridge.sv riscue_axi_core.sv riscue_axi_ecc_ram.sv riscue_serial_monitor.sv riscue_monitor_soc.sv} {
 read_verilog -sv [file join $root rtl $name]
}
if {$instrumented} {read_verilog -sv [file join $boarddir lab riscue_kc705_lab.sv]}
foreach name {uart_tx.sv uart_rx.sv status_uart.sv riscue_kc705.sv monitor_top.sv} {read_verilog -sv [file join $boarddir $name]}
synth_design -top riscue_kc705 -part $part -flatten_hierarchy none -generic [list RF_TMR=$rf_tmr FI_ENABLE=$fi WORDS=$words CLK_DIV=$clk_div INSTRUMENTED=$instrumented]
read_xdc [file join $boarddir kc705.xdc]
if {$instrumented} {
 set hubs [get_debug_cores -quiet dbg_hub]
 if {[llength $hubs]!=1} {error "Expected one debug hub"}
 set_property C_CLK_INPUT_FREQ_HZ [expr {int(1.0e9/$clk_div)}] $hubs
 set_property C_ENABLE_CLK_DIVIDER false $hubs
}
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
if {$instrumented} {write_debug_probes -force riscue_kc705.ltx}
write_bitstream -force riscue_kc705.bit
set out [open build-info.txt w]
puts $out "Vivado: [version -short]"
puts $out "Part: $part; RF_TMR=$rf_tmr; FI_ENABLE=$fi; WORDS=$words; CLK_DIV=$clk_div"
puts $out "Firmware initialized from firmware.hex; target is laboratory bring-up."
close $out
