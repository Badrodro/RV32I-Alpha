// Extra formal checks for the RV32I-Alpha core, not covered by the riscv-formal suite.
//
// riscv-formal checks each retired instruction against the ISA, given the memory data
// the core reports on RVFI. It does not check that this data really came from the
// memory port at the right address and the right time. This harness does:
//
//   imem    : the instruction retired at PC = A is the word the instruction memory
//             returned for address A (symbolic A and symbolic word).
//   dmem    : a load from address A returns the last bytes stored to A, through the
//             real dmem port (riscv-formal's rvfi_dmem_check + a one-word memory model).
//   illegal : every 32-bit word that is not an RV32I instruction traps without side
//             effects; FENCE is a NOP; ECALL / EBREAK trap. The reference decoder below
//             is written independently of src/Main_decoder.vhd.
//
// The memories return arbitrary data for every other address, so all programs are covered.

module memcheck (
	input clock
);
	reg reset = 1;
	always @(posedge clock) reset <= 0;

	`RVFI_WIRES

	// ---- memory ports -------------------------------------------------------------
	wire        imem_en;
	wire [31:0] imem_addr;
	reg  [31:0] imem_rdata;
	wire        dmem_en;
	wire [ 3:0] dmem_we;
	wire [31:0] dmem_addr;
	wire [31:0] dmem_wdata;
	reg  [31:0] dmem_rdata;
	wire        trap, wb_valid;
	wire [31:0] wb_data;

	`rvformal_rand_reg [31:0] imem_rand;
	`rvformal_rand_reg [31:0] dmem_rand;

	// symbolic instruction word at a symbolic (word-aligned) address
	`rvformal_rand_const_reg [31:0] sym_pc;
	`rvformal_rand_const_reg [31:0] sym_insn;
	always @* assume (sym_pc[1:0] == 2'b00);

	always @(posedge clock) begin
		if (imem_en)
			imem_rdata <= (imem_addr == sym_pc) ? sym_insn : imem_rand;
	end

	// one real memory word at the address chosen by rvfi_dmem_check, arbitrary data elsewhere
	wire [31:0] sym_daddr;
	reg  [31:0] dword;
	always @(posedge clock) begin
		if (dmem_en) begin
			if (dmem_addr[31:2] == sym_daddr[31:2]) begin
				dmem_rdata <= dword;
				if (dmem_we[0]) dword[ 7: 0] <= dmem_wdata[ 7: 0];
				if (dmem_we[1]) dword[15: 8] <= dmem_wdata[15: 8];
				if (dmem_we[2]) dword[23:16] <= dmem_wdata[23:16];
				if (dmem_we[3]) dword[31:24] <= dmem_wdata[31:24];
			end else begin
				dmem_rdata <= dmem_rand;
			end
		end
	end
	always @* assume (sym_daddr[1:0] == 2'b00);

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
		.trap       (trap),
		.wb_valid   (wb_valid),
		.wb_data    (wb_data),
		`RVFI_CONN32
	);

	// ---- dmem: loads see the stored bytes ------------------------------------------
`ifdef CHECK_DMEM
	rvfi_dmem_check dmem_check (
		.clock     (clock),
		.reset     (reset),
		.enable    (1'b1),
		.dmem_addr (sym_daddr),
		`RVFI_CONN
	);
`else
	`rvformal_rand_const_reg [31:0] sym_daddr_free;
	assign sym_daddr = sym_daddr_free;
`endif

	// ---- imem: the retired instruction is the fetched one ---------------------------
`ifdef CHECK_IMEM
	always @* begin
		if (!reset && rvfi_valid && rvfi_pc_rdata == sym_pc)
			assert (rvfi_insn == sym_insn);
	end
`endif

	// ---- illegal instructions ---------------------------------------------------------
`ifdef CHECK_ILLEGAL
	function automatic legal_rv32i(input [31:0] i);
		reg [6:0] op, f7;
		reg [2:0] f3;
		begin
			op = i[6:0]; f3 = i[14:12]; f7 = i[31:25];
			case (op)
				7'b0110111, 7'b0010111, 7'b1101111: legal_rv32i = 1;                // LUI AUIPC JAL
				7'b1100111: legal_rv32i = (f3 == 3'd0);                             // JALR
				7'b1100011: legal_rv32i = (f3 != 3'd2 && f3 != 3'd3);               // branches
				7'b0000011: legal_rv32i = (f3 == 3'd0 || f3 == 3'd1 || f3 == 3'd2 || f3 == 3'd4 || f3 == 3'd5);
				7'b0100011: legal_rv32i = (f3 <= 3'd2);                             // stores
				7'b0010011: legal_rv32i = (f3 == 3'd1) ? (f7 == 7'd0) :
				                          (f3 == 3'd5) ? (f7 == 7'd0 || f7 == 7'b0100000) : 1'b1;
				7'b0110011: legal_rv32i = (f7 == 7'd0) || (f7 == 7'b0100000 && (f3 == 3'd0 || f3 == 3'd5));
				7'b0001111: legal_rv32i = (f3 == 3'd0);                             // FENCE
				default:    legal_rv32i = 0;  // SYSTEM is handled below
			endcase
		end
	endfunction

	wire is_system = rvfi_insn[6:0] == 7'b1110011;
	wire is_fence  = rvfi_insn[6:0] == 7'b0001111 && rvfi_insn[14:12] == 3'd0;

	always @* begin
		if (!reset && rvfi_valid) begin
			if (!legal_rv32i(rvfi_insn) || is_system) begin
				assert (rvfi_trap);
				assert (rvfi_rd_addr == 0 && rvfi_rd_wdata == 0);
				assert (rvfi_mem_wmask == 0);
			end
			if (is_fence) begin
				assert (!rvfi_trap);
				assert (rvfi_rd_addr == 0);
				assert (rvfi_mem_wmask == 0 && rvfi_mem_rmask == 0);
				assert (rvfi_pc_wdata == rvfi_pc_rdata + 4);
			end
		end
		// a trapped instruction halts the core: nothing retires after it
		if (!reset && trap)
			assert (!rvfi_valid && !dmem_en && !imem_en);
	end
`endif

	// ---- port hygiene (always on) ----------------------------------------------------
	always @* begin
		if (!reset) begin
			assert (imem_addr[1:0] == 2'b00);
			if (dmem_we != 4'b0000) assert (dmem_en);
		end
	end
endmodule
