# RV32I-Alpha: A Compact Single-Cycle RISC-V Core for the Basys 3

![Simulation](https://github.com/Badrodro/RV32I-Alpha-Ultra-Low-Area-RISC-V-Core-for-Basys-3/actions/workflows/ci.yml/badge.svg)

**RV32I-Alpha** is a compact 32-bit RISC-V processor written in VHDL and designed for FPGA implementation on the **Digilent Basys 3** (Artix-7). It is intended as an experimental base for future work in **ASIC design** and **Near-/In-Memory Computing**.

## Architecture Overview

The core implements the **RV32I Base Integer Instruction Set** (all 37 user-level instructions, `FENCE` as a NOP, `ECALL`/`EBREAK` as a halt) on a **single-cycle datapath**:

- **Fetch:** the program counter addresses an asynchronous ROM, so an instruction is available in the same cycle.
- **Execute:** the control unit (main decoder + ALU decoder) drives the immediate generator, the register file (32 x 32, distributed RAM) and the ALU. A multiplexer selects the first ALU operand (`rs1`, `PC` for `AUIPC`, `0` for `LUI`) and another the second (`rs2` or immediate).
- **Branches:** the ALU computes `SUB`, `SLT` or `SLTU` and a small block turns the result into the branch decision, so the six branch conditions reuse the ALU comparators. A dedicated adder computes the jump/branch target.
- **Memory:** a load/store unit aligns bytes and half-words and drives the byte enables of a synchronous BRAM.
- **Write-back:** ALU result, load data or `PC + 4` is written to `rd`.

![RISC-V RV32I Architecture](assets/rv32i_architecture.png)

*Diagram source: [assets/rv32i_architecture.svg](assets/rv32i_architecture.svg). Data paths in black, control signals in dashed red.*

## Implementation Results (Basys 3 / XC7A35T)

> **Status:** the Vivado figures below were measured on an earlier version of the core (before the fixes to branches, `LUI`/`AUIPC` and byte/half-word memory access) with a 9-instruction program in ROM. They will be regenerated with `scripts/vivado_build.tcl`.

| Metric | Value (earlier version, Vivado 2025.2) | Utilization % |
| :--- | :--- | :--- |
| **Logic Cells (LUT)** | 314 | 1.51% |
| **Memory (LUTRAM)** | 44 | 0.46% |
| **Flip-Flops (FF)** | 32 | 0.08% |
| **Block RAM (BRAM)** | 1 | 2.00% |
| **Total On-Chip Power** | 0.1 W | -- |
| **Dynamic Power** | 0.028 W | -- |
| **Worst Negative Slack** | 0.165 ns | Timing met @ 100 MHz |
| **Maximum Frequency** | 101.7 MHz | -- |

### Why the area depends on the program in ROM

The instruction ROM is a constant table built from LUTs. Because its contents are known at synthesis time, the tools simplify the decoder and datapath for the instructions that actually appear in the program. The 314-LUT figure therefore describes the core *specialised for a 9-instruction program*, not a general RV32I core.

Open-source estimates (Yosys 0.33 `synth_xilinx`, xc7 family, logic LUTs only, Vivado is usually somewhat smaller):

| Configuration | Logic LUTs (Yosys) |
| :--- | ---: |
| Earlier version, 9-instruction ROM (Vivado: 270 logic LUTs) | 342 |
| Current version, 177-instruction torture test in ROM | 887 |
| **Core only**, instruction bus as an input (earlier version) | 778 |
| **Core only**, instruction bus as an input (current version) | 767 |

The "core only" line is the one to compare with other cores, which publish figures without their program memory.

---

## Comparison with Selected Open-Source RV32I Cores

> **Disclaimer:** The figures below are taken from the public repositories of each project. They are provided for **contextual positioning only**, not as a strict apples-to-apples benchmark, because FPGA families, tool versions, synthesis strategies, enabled features, memory systems, and SoC integration differ across projects.

| Core | ISA / Style | Published FPGA target / flow | LUTs | FFs / Regs | BRAM | Max Freq. | Link |
| :--- | :--- | :--- | ---: | ---: | ---: | ---: | :--- |
| **RV32I-Alpha** | RV32I, single-cycle (CPI 1, loads 2) | Basys 3 / XC7A35T | *to be re-measured, core only (~770 with Yosys)* | 33 | 1 | *to be re-measured* | [This repository](https://github.com/Badrodro/RV32I-Alpha-Ultra-Low-Area-RISC-V-Core-for-Basys-3) |
| **VexRiscv small** | RV32I, pipelined | Artix-7 / neutral synthesis | 504 | 505 | N/A | 243 MHz | [SpinalHDL/VexRiscv](https://github.com/SpinalHDL/VexRiscv) |
| **Rudi-RV32I** | RV32I, no pipeline | Artix-7 grade 1 FPGA | 575 *(CPU only)* | N/P | N/P | >80 MHz | [hamsternz/Rudi-RV32I](https://github.com/hamsternz/Rudi-RV32I) |
| **PicoRV32 (small)** | Configurable RV32I-family core | Xilinx 7-Series / area-optimized synthesis | 761 | 442 | N/P | N/P* | [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) |
| **Pequeno Light** | RV32I, 5-stage pipeline | Artix-7 xc7a35tcpg236-1 | 1076 | 552 | 0 | 114 MHz | [iammituraj/pequeno_riscv](https://github.com/iammituraj/pequeno_riscv) |

\* Upstream PicoRV32 publishes Xilinx 7-Series utilization for the small core, but the README timing number is reported separately for a different evaluated configuration/target, so it is intentionally not merged here.

> **Note on data integrity:** All Vivado data for **RV32I-Alpha** comes directly from Xilinx Vivado 2025.2 reports (earlier version of the core, see above). Screenshots and raw reports are available:
> - [View Utilization Report (314 LUTs)](assets/utilization_report.png) | [top_utilization_placed.rpt](reports/top_utilization_placed.rpt)
> - [View Power Analysis Report (0.1 W)](assets/power_report.png) | [top_power_routed.rpt](reports/top_power_routed.rpt)
> - [View Timing Summary (WNS 0.165 ns)](assets/timing_report.png) | [top_timing_summary_routed.rpt](reports/top_timing_summary_routed.rpt)

## Performance & CPI

The core is single-cycle except for loads, which wait one extra cycle for the synchronous BRAM.

- **General instructions:** ALU operations such as `add`, `sub`, and `xor`, as well as branch instructions, achieve a **CPI of 1**.
- **Memory operations:** Due to the synchronous nature of the SRAM and the integrated stall logic, the `LOAD` instruction **requires 2 cycles** (**CPI = 2**) to ensure correct data timing and avoid hazards. The `STORE` instruction completes in **1 cycle**.
- **Program termination:** `ebreak` and `ecall` assert the **Trap** output and freeze the program counter. This is used to end test programs; there is no exception handling or CSR support yet.

## Repository layout

| Path | Contents |
| :--- | :--- |
| `src/` | VHDL sources (`top.vhd` is the top level) |
| `tb/` | Full-core testbench |
| `asm/` | Torture test program and ROM generator |
| `constraints/` | Basys 3 pin constraints |
| `scripts/` | GHDL simulation and Vivado build scripts |
| `reports/`, `assets/` | Vivado reports, screenshots and diagrams |

## Building and simulating

| Task | Command (from the repository root) |
| :--- | :--- |
| Simulate the torture test (GHDL) | `./scripts/sim.sh` |
| Full Vivado flow + reports + bitstream | `vivado -mode batch -source scripts/vivado_build.tcl` |
| Rebuild the ROM after editing the program | `python3 asm/build_rom.py` |

Pin mapping (`constraints/Basys3.xdc`): `clk` on the 100 MHz oscillator, `reset` on BTNC, `trap` on LED 15 (lights up when the program reaches `ebreak`), and the 32-bit `testOUT` write-back bus on the four Pmod headers.

The simulation also runs automatically on GitHub at every push (see the *Actions* tab).

## Verification

Verification relies on a full-core simulation testbench and a self-checking, ROM-resident torture test program. Each check jumps to a `fail` label on a wrong result, and the program always ends with `ebreak`. The instruction just before `ebreak` writes the verdict in `x31` (1 = pass, otherwise the number of the failed test). The testbench reads it on `testOUT` when `TRAP` rises and reports **SUCCESS** or the failed test number.

Covered by the test:
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` (taken and not taken, equal operands)
- `LUI` and `AUIPC`
- all R-type and I-type ALU instructions, writes to `x0`
- `JAL` and `JALR` (including clearing bit 0 of the target)
- `LW`, `LH`, `LHU`, `LB`, `LBU`, `SW`, `SH`, `SB`, back-to-back loads and use of a value right after its load
- trap-based program termination (`ebreak`)

Main program used for end-to-end validation:
- [torture_test](asm/torture_test.s)

After editing the program, regenerate the ROM contents with `python3 asm/build_rom.py` (needs LLVM: `llvm-mc` and `llvm-objcopy`).

Not supported yet: misaligned loads/stores (they do not trap), `FENCE` is executed as a NOP, and there are no CSRs.

More advanced verification methods such as formal verification and finer-grain block-level testbenches are planned as future work.

## Roadmap

- **ASIC flow exploration:** Generate a first GDSII version of the core using OpenLane and the SkyWater 130 nm PDK.
- **Formal verification:** Integrate **riscv-formal** to strengthen ISA-level correctness checks.
- **Custom acceleration extension:** Explore a lightweight matrix-vector multiplication (MVM) unit for future Near-Memory Computing experiments.
- **Official compliance tests:** Run the `rv32ui` suite from [riscv-tests](https://github.com/riscv-software-src/riscv-tests).
- **Core / memory split:** Separate the core from its ROM and RAM to report core-only area in Vivado (out-of-context synthesis).
- **Fresh Vivado figures:** Regenerate the reports above with `scripts/vivado_build.tcl`.

## Contact

If you have any questions or suggestions about the project, feel free to contact me:

- **Email:** Badreddine_Benfettouma@etu.ube.fr

---

*Designed with Xilinx Vivado 2025.2 and verified with GHDL by Badreddine BENFETTOUMA. I am currently a student at University of Bourgogne Europe, with research interests in digital system architecture and Near-/In-Memory Computing.*
