#!/usr/bin/env bash
# Runs the full-system testbench with GHDL (open-source VHDL simulator).
# Usage, from the repository root:  ./scripts/sim.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/ghdl"
mkdir -p "$WORK"
cd "$WORK"

# order matters: each unit is analysed after the units it uses
SRC="ALU ALU_decoder Main_decoder Imm_gen Load_store_unit Register_file core ROM RAM reset_sync basys3_top"
for f in $SRC; do ghdl -a --std=08 "$ROOT/src/$f.vhd"; done
ghdl -a --std=08 "$ROOT/tb/top_tb.vhd"
ghdl -e --std=08 top_tb

ghdl -r --std=08 top_tb --ieee-asserts=disable-at-0 | tee sim.log
grep -q "SUCCESS" sim.log
