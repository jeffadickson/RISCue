# Host stages a descriptor; the FPGA schedules all injection edges.
namespace eval riscue {
 variable outputs {request_toggle arm command_target command_index mask_low mask_high command_delay command_count command_gap command_trigger_kind command_trigger_pc command_index_step command_rotate command_stop_on_fatal core_reset}
 proc vio {} {
  set matches [get_hw_vios -filter {CELL_NAME =~ *test_vio}]
  if {[llength $matches]!=1} {error "Expected one RISCue VIO"}
  return [lindex $matches 0]
 }
 proc probe {name direction} {
  variable outputs
  set inputs {done_toggle busy status accepted attempted last_pc last_cycle pc flags cause corrected_count uncorrectable_count disagreement_count fatal_count controller_disagreement fi_index configuration trigger_cycle first_flags first_pc first_address last_flags report_last_pc last_address controller_error_sticky}
  set names [expr {$direction eq "out"?$outputs:$inputs}]
  set i [lsearch -exact $names $name]
  if {$i<0} {error "Unknown $direction probe $name"}
  set found {}
  foreach p [get_hw_probes -of_objects [vio]] {
   if {[file tail [get_property NAME $p]] in [list "probe_${direction}${i}" $name]} {lappend found $p}
  }
  if {[llength $found]!=1} {error "Cannot resolve $name"}
  return [lindex $found 0]
 }
 proc put {name value} {
  set p [probe $name out]
  set_property OUTPUT_VALUE $value $p
  commit_hw_vio $p
 }
 proc get {name} {
  refresh_hw_vio [vio]
  set value [get_property INPUT_VALUE [probe $name in]]
  regsub -nocase {^0x} $value {} value
  if {![regexp {^[0-9a-fA-F]+$} $value]} {error "Unexpected probe value for $name"}
  return [expr "0x$value"]
 }
 proc disarm {} {put arm 0}
 proc reset_core {} {disarm;put core_reset 1;after 10;put core_reset 0;after 10}
 proc snapshot {} {
  set r [dict create]
  foreach n {status accepted attempted last_pc last_cycle trigger_cycle pc flags cause corrected_count uncorrectable_count disagreement_count fatal_count controller_error_sticky} {dict set r $n [get $n]}
  return $r
 }
 proc inject {descriptor {timeout_ms 5000}} {
  if {(([get configuration] >> 8) & 255)!=2} {error "Expected injection ABI version 2"}
  disarm
  if {[get busy]} {after 20}
  if {[get busy]} {error "Previous job did not stop"}
  set before [get done_toggle]
  set defaults [dict create target 8 index 1023 mask 1 delay 1 gap 2 count 1 trigger_kind 0 trigger_pc 0 index_step 0 rotate 0 stop_on_fatal 1]
  set descriptor [dict merge $defaults $descriptor]
  set mask [dict get $descriptor mask]
  regsub -nocase {^0x} $mask {} mask
  if {![regexp {^[0-9a-fA-F]{1,128}$} $mask]} {error "Mask must be 1..128 hex digits"}
  set mask "[string repeat 0 [expr {128-[string length $mask]}]]$mask"
  put mask_low [string range $mask 64 127];put mask_high [string range $mask 0 63]
  foreach n {target index delay gap count trigger_kind trigger_pc index_step rotate stop_on_fatal} {
   set v [dict get $descriptor $n]
   set maximum 0xffffffff
   if {$n eq "target"} {set maximum 15}
   if {$n eq "count"} {set maximum 65535}
   if {$n eq "trigger_kind"} {set maximum 2}
   if {$n in {rotate stop_on_fatal}} {set maximum 1}
   if {![string is entier -strict $v]||$v<0||$v>$maximum} {error "Invalid $n"}
   if {($n in {count delay} && $v<1)||($n eq "gap" && $v<2)} {error "Invalid $n"}
   put command_$n [format %x $v]
  }
  set ilas [get_hw_ilas -filter {CELL_NAME =~ *test_ila}]
  if {[llength $ilas]==1} {run_hw_ila [lindex $ilas 0]}
  put arm 1
  set p [probe request_toggle out]
  set token [get_property OUTPUT_VALUE $p]
  regsub -nocase {^0x} $token {} token
  put request_toggle [expr {!("0x$token")}]
  set deadline [expr {[clock milliseconds]+$timeout_ms}]
  while {[get done_toggle]==$before} {
   if {[clock milliseconds]>$deadline} {disarm;error "Campaign timed out; injection disarmed"}
   after 20
  }
  disarm
  return [snapshot]
 }
}
