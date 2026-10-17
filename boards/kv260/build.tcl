# Board release remains TMR until a parity mapped-netlist audit exists.
if {[info exists ::env(PIPELINE_PROTECTION)] && $::env(PIPELINE_PROTECTION) ne "TMR"} {
 error "This board flow supports PIPELINE_PROTECTION=TMR only; PARITY_REPLAY is simulation experimental"
}
# Explicit KV260/K26 block-design build. No programming or boot-image replacement.
if {$argc!=5} {error "Expected OUTDIR RF_TMR FI CLOCK_HZ STAGE"}
lassign $argv output rf_tmr fi clock_hz stage
if {$rf_tmr ni {0 1} || $fi ni {0 1} || $stage ni {synth bit} || ![string is integer -strict $clock_hz] || $clock_hz<1000000 || $clock_hz>100000000} {error "Invalid configuration"}
set root [file dirname [file dirname [file dirname [file normalize [info script]]]]]
set outdir [file normalize $output];file mkdir $outdir
set part xck26-sfvc784-2LV-c
if {[llength [get_parts -quiet $part]]!=1} {error "Install K26 device support for $part"}
if {[info exists ::env(KV260_BOARD_REPO)]} {set_param board.repoPaths [list $::env(KV260_BOARD_REPO)]}
set boards [get_board_parts -quiet *kv260*:part0:*]
if {[llength $boards]==0} {set boards [get_board_parts -quiet *kv260_som*:part0:*]}
if {[info exists ::env(KV260_BOARD_PART)]} {set board $::env(KV260_BOARD_PART)} elseif {[llength $boards]>0} {set board [lindex [lsort -dictionary $boards] end]} else {error "Install the official KV260 board preset or set KV260_BOARD_REPO"}
create_project riscue_kv260 [file join $outdir project] -part $part -force
set_property board_part $board [current_project]
foreach name {ft_pkg.sv riscue_pipeline_pkg.sv riscue_rvc.sv riscue_jump_target.sv riscue_execute.sv riscue_muldiv.sv riscue_pipeline_core.sv ft_ecc_ram.sv ft_event_monitor.sv fi_campaign_controller.sv riscue_axi_soc.sv riscue_kv260_axi.sv} {add_files -norecurse [file join $root rtl $name]}
update_compile_order -fileset sources_1
create_bd_design riscue_system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__FPGA_PL0_ENABLE {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ [expr {$clock_hz/1.0e6}]] $ps
set core [create_bd_cell -type module -reference riscue_kv260_axi riscue]
set_property -dict [list CONFIG.RF_TMR $rf_tmr CONFIG.FI_ENABLE $fi CONFIG.CLOCK_HZ $clock_hz CONFIG.WORDS 8192] $core
set interconnect [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:* host_bus]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $interconnect
set reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* pl_reset]
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] [get_bd_intf_pins host_bus/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins host_bus/M00_AXI] [get_bd_intf_pins riscue/S_AXI]
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins ps/maxihpm0_fpd_aclk] [get_bd_pins host_bus/aclk] [get_bd_pins pl_reset/slowest_sync_clk] [get_bd_pins riscue/aclk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins pl_reset/ext_reset_in]
set_property CONFIG.C_EXT_RESET_HIGH {0} $reset
set const [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:* clocks_good]
set_property CONFIG.CONST_VAL {1} $const
connect_bd_net [get_bd_pins clocks_good/dout] [get_bd_pins pl_reset/dcm_locked]
connect_bd_net [get_bd_pins pl_reset/peripheral_aresetn] [get_bd_pins riscue/aresetn] [get_bd_pins host_bus/aresetn]
assign_bd_address
set segments [get_bd_addr_segs -of_objects [get_bd_addr_spaces ps/Data] -filter {NAME =~ *riscue*}]
if {[llength $segments]!=1} {error "Expected one RISCue register segment; inspect address map"}
set_property offset 0xA0000000 $segments
set_property range 128K $segments
validate_bd_design;save_bd_design
set bd [get_files */riscue_system.bd]
generate_target all $bd
set wrapper [make_wrapper -files $bd -top];add_files -norecurse $wrapper
set_property top riscue_system_wrapper [current_fileset]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
launch_runs synth_1 -jobs 4;wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis did not complete"}
open_run synth_1
source [file join $root boards kv260 audit_redundancy.tcl]
report_utilization -hierarchical -file [file join $outdir utilization_synth.rpt]
if {$stage eq "synth"} {exit}
launch_runs impl_1 -to_step route_design -jobs 4;wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation did not complete"}
open_run impl_1
source [file join $root boards kv260 audit_redundancy.tcl]
report_timing_summary -report_unconstrained -file [file join $outdir timing.rpt]
report_drc -file [file join $outdir drc.rpt]
foreach delay {max min} {set p [get_timing_paths -delay_type $delay -max_paths 1];if {[llength $p]==0||[get_property SLACK [lindex $p 0]]<0} {error "$delay timing failed"}}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors remain"}
write_bitstream -force -bin_file [file join $outdir riscue_kv260.bit]
write_hw_platform -fixed -include_bit -force -file [file join $outdir riscue_kv260.xsa]
set f [open [file join $outdir build-info.txt] w];puts $f "Vivado [version -short]; board=$board; part=$part; CLOCK_HZ=$clock_hz; RF_TMR=$rf_tmr; FI_ENABLE=$fi";close $f
