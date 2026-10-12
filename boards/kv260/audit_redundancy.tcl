# Structural presence/equal-size checks, not a physical separation proof.
set roots [get_cells -hierarchical -filter {REF_NAME =~ riscue_kv260_axi*}]
if {[llength $roots]!=1} {error "Expected one AXI wrapper for redundancy audit"}
set rootcell [get_property NAME [lindex $roots 0]]
set f [open [file join $outdir redundancy.rpt] w]
foreach {group suffix} {
 bridge /c
 core /soc/core/c
 ram /soc/ram/s
 recorder /soc/reporter/report
 injector /injector/c
 arithmetic0 /soc/core/arithmetic0/s
 arithmetic1 /soc/core/arithmetic1/s
} {
 set counts {}
 foreach n {0 1 2} {
  set pattern ${rootcell}${suffix}${n}_reg*
  set count [llength [get_cells -hierarchical -filter "NAME =~ $pattern && IS_SEQUENTIAL == 1"]]
  if {$count==0} {error "Missing $group replica $n"}
  lappend counts $count
 }
 if {[llength [lsort -unique $counts]]!=1} {error "$group replica counts differ: $counts"}
 puts $f "$group sequential replica sizes: $counts"
}
foreach name {lane0 lane1 jump0 jump1} {
 set namepath ${rootcell}/soc/core/$name
 if {[llength [get_cells -hierarchical -filter "NAME == $namepath"]]!=1} {error "Missing compared lane $name"}
 puts $f "lane retained: $namepath"
}
if {$rf_tmr} {
 set counts {}
 foreach n {0 1 2} {
  set pattern ${rootcell}/soc/core/tmr${n}_reg*
  set count [llength [get_cells -hierarchical -filter "NAME =~ $pattern && IS_SEQUENTIAL == 1"]]
  if {$count==0} {error "Missing TMR RF $n"};lappend counts $count
 }
 if {[llength [lsort -unique $counts]]!=1} {error "RF replica sizes differ"}
 puts $f "RF sequential replica sizes: $counts"
}
close $f
