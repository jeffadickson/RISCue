# Explicit JTAG programming only; never called by the build target.
if {$argc!=1} {error "Expected bitstream filename"}
set bit [file normalize [lindex $argv 0]]
if {![file exists $bit]} {error "Missing bitstream: $bit"}
open_hw_manager
connect_hw_server
open_hw_target
set devices [get_hw_devices -filter {PART =~ xc7k325t*}]
if {[llength $devices]!=1} {error "Expected exactly one connected XC7K325T; select the intended target manually"}
set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $bit $device
program_hw_devices $device
close_hw_manager
