# vivado -mode batch -source boards/kc705/debug/build.tcl -tclargs OUTDIR RF_TMR synth|bit
if {$argc!=3} {error "Expected OUTDIR RF_TMR synth|bit"}
lassign $argv out rf stage
if {$rf ni {0 1} || $stage ni {synth bit}} {error "Invalid configuration"}
set here [file dirname [file normalize [info script]]]
set root [file dirname [file dirname [file dirname $here]]]
file mkdir $out
cd $out
foreach name {ft_pkg riscue_pipeline_pkg riscue_rvc riscue_jump_target riscue_execute riscue_muldiv riscue_pipeline_core ft_ecc_ram riscue_jtag_dtm riscue_debug_module riscue_debug_soc} {
 read_verilog -sv [file join $root rtl $name.sv]
}
read_verilog -sv [file join $here top.sv]
synth_design -top riscue_kc705_debug -part xc7k325tffg900-2 -flatten_hierarchy none -generic RF_TMR=$rf
read_xdc [file join $here debug.xdc]
report_utilization -hierarchical -file utilization_synth.rpt
write_checkpoint -force debug_synth.dcp
if {$stage eq "synth"} {exit}
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -report_unconstrained -file timing.rpt
report_cdc -file cdc.rpt
report_drc -file drc.rpt
report_utilization -hierarchical -file utilization_impl.rpt
foreach delay {min max} {
 set paths [get_timing_paths -delay_type $delay -max_paths 1]
 if {[llength $paths]==0 || [get_property SLACK [lindex $paths 0]]<0} {error "Timing failed"}
}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC failed"}
write_checkpoint -force debug_impl.dcp
write_bitstream -force riscue_debug.bit
