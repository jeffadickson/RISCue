if {$argc!=4} {error "Expected BUILD_DIR TARGET INDEX MASK_HEX"}
lassign $argv build target index mask
open_hw_manager
connect_hw_server
set targets [get_hw_targets]
if {[llength $targets]!=1} {error "Select one intended hardware target"}
set_property PARAM.FREQUENCY 1000000 [lindex $targets 0]
open_hw_target [lindex $targets 0]
set devices [get_hw_devices -filter {PART =~ xc7k325t*}]
if {[llength $devices]!=1} {error "Expected one XC7K325T"}
set device [lindex $devices 0]
set ltx [file normalize [file join $build riscue_kc705.ltx]]
if {![file exists $ltx]} {error "Missing matching instrumentation .ltx"}
set_property PROBES.FILE $ltx $device
refresh_hw_device $device
source [file join [file dirname [info script]] hardware_lab.tcl]
set result [riscue::inject [dict create target $target index $index mask $mask]]
puts $result
set out [open [file join $build hardware-injection.log] a];puts $out $result;close $out
if {[dict get $result status]!=0} {error "Campaign failed; see hardware-injection.log"}
close_hw_manager
