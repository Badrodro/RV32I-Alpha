# SKY130 implementation of the core

The SystemVerilog core (`rtl/core/`) is hardened to a GDSII macro in the SkyWater SKY130 process
with [LibreLane](https://github.com/librelane/librelane) (Yosys, OpenROAD, Magic, KLayout,
Netgen) and the `sky130_fd_sc_hd` standard cells. `rv32i_alpha_macro.sv` wraps the core with its
functional ports only; the RVFI trace port, used for formal verification, is left out.

| File | Contents |
| :--- | :--- |
| `config.json` | LibreLane configuration |
| `rv32i_alpha_macro.sv` | Top level of the macro |
| `defplot.py` | Draws the placement, the signal wires and the power grid from a routed DEF |
| `macro/` | GDSII (gzip), LEF and sign-off metrics of the run reported below |

## Running it

Tools used for the results below: LibreLane 3.0.16 and the sky130A PDK built by ciel from
open_pdks `8afc8346`. The full flow takes about 40 minutes on 4 cores.

```sh
cd asic
librelane --manual-pdk --pdk-root "$PDK_ROOT" --pdk sky130A --scl sky130_fd_sc_hd \
    --run-tag signoff config.json
python3 defplot.py "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef" \
    runs/signoff/final/def/rv32i_alpha_macro.def layout.png
```

The GDSII is written to `runs/signoff/final/gds/`, and every number below is in
`runs/signoff/final/metrics.json`. The files of the run reported here are in `macro/`: the GDSII
(gzip), the LEF abstract for integration in a larger design, and `metrics.json`.

## Constraints

- Clock period 25 ns (40 MHz).
- LibreLane default I/O constraints: input and output delays of 20 % of the clock period on
  every port, 33.4 fF load on each output.
- Synthesis strategy `DELAY 1`, core utilization target 40 %.

The longest paths are combinational from the instruction input (`imem_rdata`) to the data-memory
outputs and the write-back bus: the instruction memory register is the pipeline register, so
decode, register read, ALU and address computation share one cycle with the port delays.

## Results

| Item | Result |
| :--- | :--- |
| Die | 466.9 &times; 477.6 &micro;m (0.223 mm&sup2;) |
| Standard cells | 13 350 cells (not counting fill and decap), 112 623 &micro;m&sup2;, 54 % utilization |
| Flip-flops | 1 055: 992 in the register file (x1&ndash;x31), 63 elsewhere |
| Buffers added for timing | 2 838, of which 1 037 for hold |
| Routed wire length | 527 mm, met1&ndash;met5 |
| DRC (Magic and KLayout) | 0 violations |
| LVS (Netgen) | layout matches the netlist |
| Antenna | 0 violating nets |
| Power, typical corner at 40 MHz | 5.9 mW (OpenSTA, default switching activity) |

Setup and hold slack at 25 ns, after routing, with extracted parasitics (nominal RC corner):

| Corner | Setup slack | Hold slack |
| :--- | ---: | ---: |
| Typical (tt, 25 &deg;C, 1.80 V) | +4.24 ns | +0.34 ns |
| Fast (ff, &minus;40 &deg;C, 1.95 V) | +7.89 ns | +0.13 ns |
| Slow (ss, 100 &deg;C, 1.60 V) | **&minus;4.85 ns** | +0.90 ns |

- Setup is met at 40 MHz at the typical and fast corners, and hold at every corner, including
  the minimum and maximum RC corners (typical setup slack between +3.77 and +4.74 ns).
- Setup is **not** met at the slow corner (down to &minus;5.72 ns with maximum RC). Closing it
  needs a longer clock period or a shorter combinational path through the execute stage.
- Remaining electrical warnings at the typical corner: 31 max-slew (slowest edge 0.90 ns
  against a 0.75 ns limit), 2 max-capacitance (clock-tree root and one fanout buffer) and
  8 max-fanout (clock-tree and fanout buffers).

![Layout](../assets/rv32i_sky130_layout.png)
