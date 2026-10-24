# OpenROAD placement and detailed routing of build/asic/core_syn.v (see asic/README.md).
# From the repository root, with PDK_ROOT set:  openroad -exit asic/core_pnr.tcl
# Not done here: power grid, clock-tree synthesis, buffering and timing repair.
set_thread_count 4
set sc $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd
read_lef $sc/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $sc/lef/sky130_fd_sc_hd.lef
read_liberty $sc/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog build/asic/core_syn.v
link_design rv32i_core
create_clock -period 20 [get_ports clk]
initialize_floorplan -utilization 45 -aspect_ratio 1 -core_space 6 -site unithd
make_tracks
place_pins -hor_layers met3 -ver_layers met2
tapcell -distance 14 -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1
global_placement -density 0.55
detailed_placement
write_def build/asic/core_placed.def
set_routing_layers -signal met1-met4
global_route -allow_congestion
detailed_route -output_drc build/asic/drc.rpt -verbose 1
report_design_area
write_def build/asic/core.def
