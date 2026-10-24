# SKY130 flow for the core

Synthesis, placement and routing of the SystemVerilog core (`rtl/core/`) in the SkyWater
SKY130 process, with the `sky130_fd_sc_hd` standard cells at the typical corner.

Tools used for the numbers below: Yosys 0.62, OpenROAD 26Q2, Python 3 with Pillow. PDK: sky130A
built by ciel, open_pdks `8afc8346`. Yosys 0.33 gives a different netlist (4 976 cells,
60 335 µm²), so the Yosys version matters.

From the repository root, with `PDK_ROOT` pointing to the sky130 version directory:

```sh
yosys -c asic/core_syn.tcl            # -> build/asic/core_syn.v, core_syn.stat
openroad -exit asic/core_pnr.tcl      # -> build/asic/core.def (about 25 min on 4 threads)
python3 asic/defplot.py \
    $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef \
    build/asic/core.def build/asic/core_layout.png
```

| Value | Source |
| :--- | :--- |
| 4 696 cells, 59 557 µm² | `core_syn.stat` (standard cells only, no tap cells) |
| die 375.8 × 375.8 µm | `DIEAREA` in `core.def` |
| 47 % utilization, 61 737 µm² | `report_design_area` (includes 1 742 tap cells) |
| 234 224 µm of wire, 42 237 vias | detailed router log; `defplot.py` recomputes the same wire length from the DEF |
| 0 violations | detailed router (`build/asic/drc.rpt` is empty); this is not a sign-off DRC |
| 992 register-file flip-flops | `defplot.py`: enable flip-flops on the 31 write-enable nets that each drive 32 of them |

Not done in this flow: power grid, clock-tree synthesis, buffering and timing repair, timing
closure, sign-off DRC and LVS, GDSII.
