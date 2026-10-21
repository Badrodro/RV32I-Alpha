// riscv-formal wrapper for the RV32I-Alpha core (VHDL, read through the GHDL plugin).
//
// Both memories are modelled by their contract only: synchronous read, data valid one
// clock after an enabled (and, for dmem, granted) request, output held otherwise.
// dmem_gnt is free, so every wait-state pattern is covered. The data
// itself is unconstrained (any value on every read), so the checks cover every program
// and every memory content.

module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);
	(* keep *) `rvformal_rand_reg [31:0] imem_rand;
	(* keep *) `rvformal_rand_reg [31:0] dmem_rand;
	(* keep *) `rvformal_rand_reg        dmem_gnt;   // wait states: any pattern

	(* keep *) wire        imem_en;
	(* keep *) wire [31:0] imem_addr;
	(* keep *) reg  [31:0] imem_rdata;

	(* keep *) wire        dmem_en;
	(* keep *) wire [ 3:0] dmem_we;
	(* keep *) wire [31:0] dmem_addr;
	(* keep *) wire [31:0] dmem_wdata;
	(* keep *) reg  [31:0] dmem_rdata;

	(* keep *) wire        trap;
	(* keep *) wire        wb_valid;
	(* keep *) wire [31:0] wb_data;

	always @(posedge clock) begin
		if (imem_en) imem_rdata <= imem_rand;
		if (dmem_en && dmem_gnt) dmem_rdata <= dmem_rand;
	end

	rv32i_core uut (
		.clk        (clock),
		.rst        (reset),
		.imem_en    (imem_en),
		.imem_addr  (imem_addr),
		.imem_rdata (imem_rdata),
		.dmem_en    (dmem_en),
		.dmem_we    (dmem_we),
		.dmem_addr  (dmem_addr),
		.dmem_wdata (dmem_wdata),
		.dmem_rdata (dmem_rdata),
		.dmem_gnt   (dmem_gnt),
		.trap       (trap),
		.wb_valid   (wb_valid),
		.wb_data    (wb_data),
		`RVFI_CONN32
	);

`ifdef RV32I_ALPHA_FAIRNESS
	// liveness only: the memory never makes the core wait more than two cycles in a row
	reg [2:0] waited = 0;
	always @(posedge clock) waited <= {waited[1:0], dmem_en && !dmem_gnt};
	always @* assume (~waited);
`endif

`ifdef RV32I_ALPHA_PORT_CHECKS
	// Extra properties on the memory ports (not part of riscv-formal).
	always @* begin
		if (!reset) begin
			assert (imem_addr[1:0] == 2'b00);
			assert (!(dmem_we != 4'b0000 && !dmem_en));  // a write is always an enabled access
		end
	end
`endif
endmodule
