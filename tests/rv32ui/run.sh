#!/usr/bin/env bash
# Runs the rv32ui tests of riscv-tests on the SystemVerilog core (Icarus Verilog).
# Needs clang and ld.lld with the RISC-V target, llvm-objcopy and iverilog.
# Skipped: fence_i (self-modifying code; the core has separate instruction and data ports and no
# Zifencei) and ma_data (misaligned accesses, which this core traps by design).
# Usage, from the repository root: ./tests/rv32ui/run.sh [test ...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/tests/rv32ui"
WORK="$ROOT/build/rv32ui"
RVT="$WORK/riscv-tests"
RVT_REV=3df703cd52d5f0d8224e3c50bf03c6cb70efff98   # riscv-tests version used for the results in the README
mkdir -p "$WORK"

if [ ! -d "$RVT/isa" ]; then
    git init -q "$RVT"
    git -C "$RVT" fetch -q --depth 1 https://github.com/riscv-software-src/riscv-tests.git "$RVT_REV"
    git -C "$RVT" checkout -q FETCH_HEAD
fi

iverilog -g2012 -o "$WORK/tb.vvp" "$HERE/tb_rv32ui.sv" \
    "$ROOT"/rtl/core/rv32i_{decoder,alu,lsu,regfile,core}.sv 2>&1 | grep -v "sorry: constant selects" || true

if [ $# -gt 0 ]; then TESTS="$*"; else
    TESTS=$(cd "$RVT/isa/rv32ui" && ls *.S | sed 's/\.S$//' | grep -v -x -e fence_i -e ma_data)
fi

pass=0; fail=0; failed=()
for t in $TESTS; do
    clang --target=riscv32 -march=rv32i -mabi=ilp32 -nostdlib -static -fuse-ld=lld \
        -I "$HERE/env" -I "$RVT/isa/macros/scalar" -T "$HERE/link.ld" \
        -o "$WORK/$t.elf" "$RVT/isa/rv32ui/$t.S"
    llvm-objcopy -O binary "$WORK/$t.elf" "$WORK/$t.bin"
    od -An -v -tx4 -w4 "$WORK/$t.bin" > "$WORK/$t.hex"
    r=$(vvp -n "$WORK/tb.vvp" +HEX="$WORK/$t.hex" | grep -E "^(PASS|FAIL)")
    printf "%-8s %s\n" "$t" "$r"
    if [[ $r == PASS* ]]; then pass=$((pass+1)); else fail=$((fail+1)); failed+=("$t"); fi
done
echo "rv32ui: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
