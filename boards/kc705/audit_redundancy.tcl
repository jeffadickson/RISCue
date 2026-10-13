# Structural check only: verify named physical state replica groups survived.
proc replica_count {pattern} {
 set cells [get_cells -hierarchical -filter "NAME =~ $pattern && IS_SEQUENTIAL == 1"]
 if {[llength $cells]==0} {error "Missing protected state: $pattern"}
 return [llength $cells]
}
set out [open [file join $outdir redundancy.rpt] w]
if {$instrumented} {
 set groups {core_control *soc/core/c {0 1 2} ram_control *soc/ram/s {0 1 2} reporter *soc/reporter/report {0 1 2}}
 set core_path *soc/core
} else {
 set groups {core_control *soc/cpu/core/c {0 1 2} ram_control *soc/memory/ram/s {0 1 2} axi_ram *soc/memory/s {0 1 2} cpu_bridge *soc/cpu/bridge/s {0 1 2} host_bridge *soc/host_bridge/s {0 1 2}}
 set core_path *soc/cpu/core
}
foreach {name prefix replicas} $groups {
 set counts {}
 foreach n $replicas {lappend counts [replica_count ${prefix}${n}_reg*]}
 puts $out "$name sequential counts: $counts"
 if {[llength [lsort -unique $counts]]!=1} {error "$name replica counts differ: $counts"}
}
foreach unit {arithmetic0 arithmetic1} {
 foreach n {0 1 2} {puts $out "$unit state $n: [replica_count ${core_path}/$unit/s${n}_reg*]"}
}
if {$instrumented} {
 foreach n {0 1 2} {puts $out "injector state $n: [replica_count *instrumented/lab/controller/c${n}_reg*]"}
}
foreach lane {lane0 lane1 jump0 jump1} {
 set cells [get_cells -hierarchical -filter "NAME =~ ${core_path}/$lane"]
 if {[llength $cells]!=1} {error "Execution lane $lane was not preserved"}
 puts $out "execution lane retained: $lane"
}
if {$rf_tmr} {
 set counts {}
 foreach n {0 1 2} {lappend counts [replica_count ${core_path}/tmr${n}_reg*]}
 puts $out "register TMR counts: $counts"
 if {[llength [lsort -unique $counts]]!=1} {error "Register replica counts differ"}
}
close $out
