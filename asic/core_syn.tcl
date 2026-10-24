# Yosys synthesis of the SystemVerilog core (rtl/core) for sky130_fd_sc_hd,
# typical corner (tt, 25 C, 1.80 V). Register file built from flip-flops.
# From the repository root, with PDK_ROOT set:  yosys -c asic/core_syn.tcl
yosys -import
file mkdir build/asic
set lib $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_liberty -lib $lib
read_verilog -sv rtl/core/rv32i_decoder.sv rtl/core/rv32i_alu.sv rtl/core/rv32i_lsu.sv \
    rtl/core/rv32i_regfile.sv rtl/core/rv32i_core.sv
synth -top rv32i_core -flatten
dfflibmap -liberty $lib
abc -liberty $lib
opt_clean -purge
hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
setundef -zero
tee -o build/asic/core_syn.stat stat -liberty $lib
write_verilog -noattr build/asic/core_syn.v
