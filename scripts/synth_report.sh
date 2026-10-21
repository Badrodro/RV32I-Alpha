#!/usr/bin/env bash
# Open-source area and timing estimates for the RV32I-Alpha core (no vendor tools).
#
#   FPGA : Yosys synth_xilinx (xc7), cells after mapping. Yosys is usually less
#          efficient than Vivado, so compare versions with each other, not with Vivado.
#   ASIC : Yosys + ABC mapped on sky130_fd_sc_hd (typical corner, 25 C, 1.8 V),
#          cell area and the longest register-to-register path reported by OpenSTA
#          (no wires, no placement: an optimistic but consistent estimate).
#
# Needs yosys with the GHDL plugin. The ASIC part needs a sky130 liberty file
# (LIB=... or PDK_ROOT set) and OpenSTA ("sta") on the PATH; it is skipped otherwise.
#
# Usage: ./scripts/synth_report.sh [top] [vhdl files...]   (default: the core)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/synth"
mkdir -p "$OUT"
TOP="${1:-rv32i_core}"
shift || true
if [ $# -gt 0 ]; then FILES="$*"; else
    FILES=""
    for f in ALU ALU_decoder Main_decoder Imm_gen Load_store_unit Register_file core; do
        FILES="$FILES $ROOT/src/$f.vhd"
    done
fi
YOSYS="${YOSYS:-yosys}"

# ---- FPGA ---------------------------------------------------------------------
$YOSYS -q -m ghdl -p "ghdl --std=08 $FILES -e $TOP; synth_xilinx -family xc7 -flatten -top $TOP; tee -q -o $OUT/${TOP}_xc7.txt stat" > "$OUT/${TOP}_xc7.log" 2>&1
# (works with the stat formats of Yosys 0.33 and 0.6x: "<count> <cell>")
awk '$2 ~ /^LUT[1-6]$/{l+=$1} $2=="RAM32M"{r=$1} $2=="RAM64M"{r64=$1} $2 ~ /^FD[A-Z]+$/{f+=$1} $2=="CARRY4"{c=$1} $2=="MUXF7"{m7=$1} $2=="MUXF8"{m8=$1}
     END{printf "FPGA xc7 : %d logic LUTs, %d LUTRAM (RAM32M/64M x4), %d FF, %d CARRY4, %d MUXF7, %d MUXF8\n", l, 4*(r+r64), f, c, m7, m8}' "$OUT/${TOP}_xc7.txt"

# ---- ASIC ---------------------------------------------------------------------
LIB="${LIB:-${PDK_ROOT:-/nonexistent}/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib}"
if [ ! -f "$LIB" ] || ! command -v sta > /dev/null; then
    echo "ASIC     : skipped (no sky130 liberty or no OpenSTA)"
    exit 0
fi
# ADDER=ripple (Yosys default), or a parallel-prefix carry network from Yosys'
# techlibs/common/choices (needs a recent Yosys): sklansky, kogge-stone, han-carlson
ADDER="${ADDER:-ripple}"
if [ "$ADDER" = "ripple" ]; then FINE="synth -flatten -top $TOP"; else
    FINE="synth -flatten -top $TOP -run :fine; techmap -map +/techmap.v -map +/choices/$ADDER.v; synth -top $TOP -run fine:"; fi
$YOSYS -q -m ghdl -p "ghdl --std=08 $FILES -e $TOP; $FINE; dfflibmap -liberty $LIB; abc -liberty $LIB -D 10000; opt_clean; setundef -zero; hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO; tee -q -o $OUT/${TOP}_sky130.txt stat -liberty $LIB; write_verilog -noattr $OUT/${TOP}_sky130.v" > "$OUT/${TOP}_sky130.log" 2>&1
area=$(awk '/Chip area/{print $NF}' "$OUT/${TOP}_sky130.txt")
cells=$(awk '$NF ~ /^sky130_fd_sc_hd__/ {n+=$1} END{print n+0}' "$OUT/${TOP}_sky130.txt")
dffs=$(awk '$NF ~ /^sky130_fd_sc_hd__(dfrtp|dfxtp|dfstp|dfbbp|dfrbp|edfxtp|dfsbp|dfxbp|sdf)/ {n+=$1} END{print n+0}' "$OUT/${TOP}_sky130.txt")
cat > "$OUT/${TOP}_sta.tcl" <<EOF
read_liberty $LIB
read_verilog $OUT/${TOP}_sky130.v
link_design $TOP
create_clock -name clk -period 10 [get_ports clk]
set_input_delay 0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]
set_output_delay 0 -clock clk [all_outputs]
report_checks -path_delay max -group_path_count 1 -path_group clk -format full_clock_expanded -digits 3
report_wns
EOF
sta -no_init -exit "$OUT/${TOP}_sta.tcl" > "$OUT/${TOP}_sta.txt" 2>&1 || true
arrival=$(awk '/data arrival time/{print $1; exit}' "$OUT/${TOP}_sta.txt")
slack=$(awk '/slack \((MET|VIOLATED)\)/{print $1; exit}' "$OUT/${TOP}_sta.txt")
echo "ASIC sky130 (tt, pre-layout, ${ADDER} adder): ${area} um2, ${cells} cells (${dffs} flip-flops), critical path ${arrival} ns (slack ${slack} ns at 10 ns)"
