#!/usr/bin/env bash
# Formal verification of the RV32I-Alpha core.
#
#   1. riscv-formal (https://github.com/YosysHQ/riscv-formal): every RV32I instruction
#      plus the consistency checks (reg, pc_fwd, pc_bwd, causal, unique, liveness, ill).
#   2. formal/memcheck.sby: the memory ports really deliver what RVFI reports
#      (imem, dmem) and every non-RV32I encoding traps (illegal).
#
# Needs: yosys + GHDL plugin (yosys -m ghdl), SymbiYosys (sby), yices-smt2, and a
# riscv-formal checkout given by RISCV_FORMAL (cloned into build/ otherwise).
#
# Usage, from the repository root:
#   ./formal/run.sh                         # everything
#   ./formal/run.sh insn_add_ch0 reg_ch0    # selected riscv-formal checks
#   ./formal/run.sh extra                   # only the memcheck tasks
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/formal"
RVF="${RISCV_FORMAL:-$WORK/riscv-formal-src}"
RVF_REV=c992aa61fdfe0846c5ed90324c596202a1c69b76   # riscv-formal version used for the results in the README
mkdir -p "$WORK"

if [ ! -d "$RVF/checks" ]; then
    git init -q "$RVF"
    git -C "$RVF" fetch -q --depth 1 https://github.com/YosysHQ/riscv-formal.git "$RVF_REV"
    git -C "$RVF" checkout -q FETCH_HEAD
fi

run_rvf=1; run_extra=1; selected=()
if [ $# -gt 0 ]; then
    run_extra=0
    for a in "$@"; do
        if [ "$a" = "extra" ]; then run_extra=1; else selected+=("$a"); fi
    done
    [ ${#selected[@]} -eq 0 ] && run_rvf=0
fi

pass=0; fail=0; failed=()
count() { # directory, name
    if [ -f "$1/PASS" ]; then pass=$((pass+1)); else fail=$((fail+1)); failed+=("$2"); fi
}

# ---- 1. riscv-formal ------------------------------------------------------------
if [ $run_rvf -eq 1 ]; then
    CORE="$WORK/rvf/cores/rv32i_alpha"   # riscv-formal expects cores/<name>/ below its root
    rm -rf "$WORK/rvf"
    mkdir -p "$CORE"
    ln -s "$RVF/checks" "$WORK/rvf/checks"
    ln -s "$RVF/insns" "$WORK/rvf/insns"
    sed "s#@repo@#$ROOT#g" "$ROOT/formal/checks.cfg" > "$CORE/checks.cfg"
    cd "$CORE"
    python3 ../../checks/genchecks.py > /dev/null
    if [ ${#selected[@]} -gt 0 ]; then
        make -C checks -j"$(nproc)" "${selected[@]/%//status}" > make.log 2>&1 || true
        for n in "${selected[@]}"; do count "checks/$n" "$n"; done
    else
        make -C checks -j"$(nproc)" > make.log 2>&1 || true
        for d in checks/*/; do count "$d" "$(basename "$d")"; done
    fi
fi

# ---- 2. memory ports and illegal instructions -------------------------------------
if [ $run_extra -eq 1 ]; then
    cd "$WORK"
    sed -e "s#@repo@#$ROOT#g" -e "s#@rvf@#$RVF#g" "$ROOT/formal/memcheck.sby" > memcheck.sby
    for t in imem dmem illegal; do
        sby -f memcheck.sby "$t" > "memcheck_$t.log" 2>&1 &
    done
    wait || true
    for t in imem dmem illegal; do count "memcheck_$t" "memcheck_$t"; done
fi

echo "formal: $pass passed, $fail failed"
for n in "${failed[@]+"${failed[@]}"}"; do echo "  FAIL: $n"; done
[ "$fail" -eq 0 ]
