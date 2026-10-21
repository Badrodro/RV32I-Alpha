# Full Vivado flow for RV32I-Alpha on the Basys 3 (non-project mode).
# Regenerates the reports used in the README and the bitstream.
#
# Usage, from the repository root:
#   vivado -mode batch -source scripts/vivado_build.tcl
#
# Outputs:
#   reports/top_utilization_placed.rpt
#   reports/top_timing_summary_routed.rpt
#   reports/top_power_routed.rpt
#   build/top.bit

set root [file normalize [file join [file dirname [info script]] ..]]
set part xc7a35tcpg236-1

file mkdir [file join $root build]
file mkdir [file join $root reports]

read_vhdl [glob [file join $root src *.vhd]]
read_xdc  [file join $root constraints Basys3.xdc]

synth_design -top top -part $part
opt_design
place_design
report_utilization -file [file join $root reports top_utilization_placed.rpt]
route_design
report_timing_summary -file [file join $root reports top_timing_summary_routed.rpt]
report_power          -file [file join $root reports top_power_routed.rpt]
write_bitstream -force [file join $root build top.bit]

puts "Done. Reports are in [file join $root reports], bitstream in [file join $root build top.bit]"
