# Vivado flow for RV32I-Alpha on the Basys 3 (non-project mode).
#
# Usage, from the repository root:
#   vivado -mode batch -source scripts/vivado_build.tcl
#
# Step 1: core alone, out of context (no memories, no I/O buffers), 100 MHz clock.
#         This is the figure to compare with other cores.
#   reports/core_ooc_utilization.rpt
#   reports/core_ooc_timing.rpt
# Step 2: full Basys 3 design (core + ROM + RAM), placed and routed.
#   reports/top_utilization_placed.rpt
#   reports/top_timing_summary_routed.rpt
#   reports/top_power_routed.rpt
#   build/top.bit

set root [file normalize [file join [file dirname [info script]] ..]]
set part xc7a35tcpg236-1
set rtl  [glob [file join $root src *.vhd]]

file mkdir [file join $root build]
file mkdir [file join $root reports]

# ---- step 1: core only (out of context) ----------------------------------------
read_vhdl -vhdl2008 $rtl
synth_design -top rv32i_core -part $part -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
opt_design
place_design
route_design
report_utilization     -file [file join $root reports core_ooc_utilization.rpt]
report_timing_summary  -file [file join $root reports core_ooc_timing.rpt]
close_design

# ---- step 2: full design on the board --------------------------------------------
# (the VHDL files read above stay loaded; only the board constraints are added)
read_xdc  [file join $root constraints Basys3.xdc]
synth_design -top basys3_top -part $part
opt_design
place_design
report_utilization -file [file join $root reports top_utilization_placed.rpt]
route_design
report_timing_summary -file [file join $root reports top_timing_summary_routed.rpt]
report_power          -file [file join $root reports top_power_routed.rpt]
write_bitstream -force [file join $root build top.bit]

puts "Done. Reports are in [file join $root reports], bitstream in [file join $root build top.bit]"
