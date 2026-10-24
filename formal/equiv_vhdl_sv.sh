#!/usr/bin/env bash
# Sequential equivalence proof: SystemVerilog core (rtl/core) == VHDL core (reference).
# Yosys equiv_make / equiv_simple / equiv_induct on every output and register, RVFI included.
# Needs yosys with the GHDL plugin. Usage: ./formal/equiv_vhdl_sv.sh [vhdl dir] (default src)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VD="${1:-$ROOT/src}"
V=""
for f in ALU ALU_decoder Main_decoder Imm_gen Load_store_unit Register_file core; do V="$V $VD/$f.vhd"; done
S=""
for f in rv32i_decoder rv32i_alu rv32i_lsu rv32i_regfile rv32i_core; do S="$S $ROOT/rtl/core/$f.sv"; done
yosys -m ghdl -p "
ghdl --std=08 -gFORMAL=true $V -e rv32i_core; rename rv32i_core gold;
read_verilog -sv $S; chparam -set FORMAL 1 rv32i_core; rename rv32i_core gate;
cd gate; rename rf rf_inst; cd ..;
proc; flatten; opt_clean; memory -nomap; memory_map; opt -fast; async2sync;
equiv_make gold gate equiv; hierarchy -top equiv;
equiv_simple -seq 4; equiv_induct -seq 4; equiv_status -assert" 2>&1 | grep -E "are proven|Equivalence successfully|ERROR"
