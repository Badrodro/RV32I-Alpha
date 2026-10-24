# RV32I-Alpha: a two-stage RISC-V core for the Basys 3 and SKY130

![CI](https://github.com/Badrodro/RV32I-Alpha/actions/workflows/ci.yml/badge.svg)

RV32I-Alpha is a 32-bit RISC-V core that implements the RV32I base integer instruction set.
It is written in VHDL; a SystemVerilog version is proven equivalent to it. The core is checked
with [riscv-formal](https://github.com/YosysHQ/riscv-formal) and passes the official `rv32ui`
tests. It is built for the Digilent Basys 3 (Xilinx Artix-7) with Vivado, and has been hardened to
a DRC- and LVS-clean GDSII macro in the SkyWater SKY130 process with open-source tools.

## Architecture

![RV32I-Alpha architecture](assets/rv32i_architecture.png)

*Data paths in black, control signals in dashed red. Source: [assets/rv32i_architecture.svg](assets/rv32i_architecture.svg).*

- **Two stages.** IF sends `pc_if` to a synchronous instruction memory. The output register of that
  memory is the IF/EX pipeline register. EX decodes, reads the register file, executes, accesses
  data memory and writes back in the same cycle.
- **Hazards.** The register file is written at the end of EX and read by the next instruction after
  that clock edge, so there is no forwarding. Branches are predicted not taken: a taken branch or a
  jump kills the instruction fetched behind it.
- **ALU.** One 33-bit adder serves ADD, SUB, SLT, SLTU and the branch comparisons; one right shifter
  serves SRL, SRA and SLL. Equality is compared on the operands, in parallel with the adder.
- **Target adder.** `(pc_ex or rs1) + imm` serves the branches, JAL, JALR and AUIPC.
- **Memory ports.** Harvard interface. The data port holds a request until `dmem_gnt` is high, so a
  slower memory or an arbiter can insert wait states. The Basys 3 top ties `dmem_gnt` to 1.
- **Traps.** ECALL, EBREAK, every non-RV32I encoding, misaligned loads and stores, and jumps or taken
  branches to a misaligned target stop the core with no side effect (`trap` = 1). There are no CSRs
  and no interrupts. FENCE executes as a NOP.

| Instruction | Cycles |
| :--- | ---: |
| ALU, LUI, AUIPC, store, branch not taken | 1 |
| Branch taken, JAL, JALR | 2 (one bubble) |
| Load | 2 |
| Load or store with data-port wait states | + one per cycle with `dmem_gnt` = 0 |

## Verification

| Check | Tool | Depth |
| :--- | :--- | ---: |
| 37 instruction checks (`insn`), `ill` | riscv-formal (Yosys, SymbiYosys, Yices) | 10 |
| `reg`, `pc_fwd`, `pc_bwd`, `causal`, `unique`, `cover` | riscv-formal | 10 |
| `liveness` (at most two wait cycles in a row assumed) | riscv-formal | 15 |
| Instruction port: the retired instruction is the word fetched at its PC | SymbiYosys, `formal/memcheck.sv` | 16 |
| Data port, with random wait states: a load returns the bytes last stored at its address | SymbiYosys, `formal/memcheck.sv` | 10 |
| Every non-RV32I word traps, against an independent reference decoder | SymbiYosys, `formal/memcheck.sv` | 16 |
| VHDL and SystemVerilog versions are sequentially equivalent (1794 / 1794 cells) | Yosys `equiv_make`, `equiv_induct` | induction |
| Self-checking torture test passes in 197 cycles | GHDL | full program |
| [riscv-tests](https://github.com/riscv-software-src/riscv-tests) `rv32ui`: 40 tests pass, with random data-port wait states | Icarus Verilog, SystemVerilog core | full programs |

riscv-formal and the memory-port checks use bounded model checking: they show that no
counterexample exists within the stated number of cycles from reset, not correctness for every
execution. While the checks were written, 8 bugs were injected into the core one at a time
(SLTU computed as signed, no kill after a taken branch, no trap on a misaligned store, wrong link
address, no load stall, wrong illegal-instruction decode, instruction memory never disabled, wrong
SH byte lanes); each was caught by at least one check.

The torture test (`asm/torture_test.s`) covers the six branches (taken, not taken, equal
operands), LUI and AUIPC, every R-type and I-type ALU instruction, writes to `x0`, JAL and JALR,
every load and store width, back-to-back loads and the use of a value right after its load.

| Task | Command (from the repository root) |
| :--- | :--- |
| riscv-formal and memory-port checks (48 checks, about a minute on 4 cores) | `./formal/run.sh` |
| VHDL / SystemVerilog equivalence | `./formal/equiv_vhdl_sv.sh` |
| Torture test in simulation | `./scripts/sim.sh` |
| `rv32ui` tests (about 10 s) | `./tests/rv32ui/run.sh` |

All four run in CI on every push (*Actions* tab). `formal/run.sh` and `tests/rv32ui/run.sh`
download riscv-formal and riscv-tests at fixed commits. The `rv32ui` tests run with a minimal test
environment (the core has no CSRs: a test ends with ECALL and reports its result in `gp`); two
tests are skipped: `fence_i` (self-modifying code, which separate instruction and data ports do
not support) and `ma_data` (misaligned accesses, which the core traps by design).

## Implementation

### SKY130 (LibreLane, GDSII)

![RV32I-Alpha hardened in SKY130](assets/rv32i_sky130_layout.png)

*(a) Standard-cell placement, register-file flip-flops in blue. (b) Signal wires on met1&ndash;met5
and the power grid. Drawn from the final DEF by `asic/defplot.py`.*

| Item | Result |
| :--- | :--- |
| Flow | LibreLane 3.0.16, sky130_fd_sc_hd: synthesis, floorplan and power grid, placement, clock tree, timing repair, routing, parasitic extraction, sign-off |
| Die | 466.9 &times; 477.6 &micro;m (0.223 mm&sup2;), 13 350 standard cells, 54 % utilization |
| Physical sign-off | DRC clean (Magic and KLayout), LVS clean (Netgen), no antenna violations |
| Timing at 40 MHz (25 ns) | setup met at the typical (+4.24 ns) and fast corners, **not met at the slow corner** (&minus;4.85 ns); hold met at every corner |
| Power | 5.9 mW at 40 MHz, typical corner (default switching activity) |

The input and output delays are the LibreLane defaults (20 % of the clock period on every port).
The slow corner fails on the combinational paths from the instruction input through the execute
stage to the data-memory outputs. Constraints, commands and the source of each number:
[asic/README.md](asic/README.md). The GDSII (gzip), the LEF and the sign-off metrics of this run
are in [asic/macro/](asic/macro/).

### FPGA (Basys 3, XC7A35T-1, Vivado 2024.2)

`scripts/vivado_build.tcl` runs two implementations and writes their reports to `reports/`:
the core alone, out of context, and the board top level (core, instruction ROM, 4 KB data RAM in
one BRAM, reset synchronizer, Pmod output of the write-back bus). Pin mapping
(`constraints/Basys3.xdc`): `clk` on the 100 MHz oscillator, `reset` on BTNC, `trap` on LED 15,
and the last value written to a register on the four Pmod headers. The bitstream has not been
tested on a board yet.

| Implementation (routed) | LUTs | Flip-flops | BRAM | Timing at 100 MHz |
| :--- | ---: | ---: | ---: | :--- |
| Core alone, out of context | 675 (631 logic, 44 distributed RAM for the register file) | 63 | 0 | met, worst slack +0.111 ns |
| Board top level | 751 (707 logic, 44 distributed RAM) | 127 | 1 | **not met**, worst slack &minus;0.538 ns |

- The out-of-context run constrains only the paths between registers of the core; its memory
  ports have no input or output delays.
- On the board, the critical path (9.97 ns) runs from the instruction ROM output register through
  the register file, the second-operand mux and the address computation to the write enable of
  the data BRAM. Static timing therefore supports about 95 MHz (10.54 ns) for the board build,
  not 100 MHz.
- The instruction ROM has constant contents, so Vivado builds it from LUTs and a 32-bit output
  register instead of a BRAM.
- Power estimate for the board build (vectorless, medium confidence): 80 mW on chip, of which
  72 mW device static and 8 mW dynamic.

## Repository layout

| Path | Contents |
| :--- | :--- |
| `src/` | VHDL core (`core.vhd`) and Basys 3 top level with its memories |
| `rtl/core/` | SystemVerilog version of the core |
| `tb/`, `asm/` | Testbench, torture test program and ROM generator |
| `tests/rv32ui/` | Test environment, testbench and script for the riscv-tests `rv32ui` suite |
| `formal/` | riscv-formal configuration, memory-port properties, equivalence script |
| `asic/` | LibreLane configuration, macro top level and layout plotting script |
| `scripts/` | Simulation, Vivado build and synthesis estimate scripts |
| `constraints/` | Basys 3 pin constraints |
| `reports/` | Vivado reports of the current version |
| `assets/` | Architecture diagram and layout figure |

After editing the torture test, regenerate the ROM with `python3 asm/build_rom.py` (needs
`llvm-mc` and `llvm-objcopy`).

## Roadmap

- Close timing at the SKY130 slow corner (ss, 100 &deg;C, 1.60 V).
- Close timing at 100 MHz on the board build (data-memory write-enable path).
- Run the bitstream on a Basys 3 board.

## Contact

Badreddine Benfettouma, Université Bourgogne Europe, Dijon, France.
Email: Badreddine_Benfettouma@etu.ube.fr
