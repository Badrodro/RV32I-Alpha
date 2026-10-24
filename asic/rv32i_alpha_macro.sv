// RV32I-Alpha core as a hard macro: the core with its functional ports only.
// The RVFI trace port is used by formal verification and is left out of the layout.
// Engineer: Badreddine BENFETTOUMA (Université Bourgogne Europe)

module rv32i_alpha_macro (
    input  logic        clk,
    input  logic        rst,          // active high, async assert, sync de-assert

    output logic        imem_en,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    output logic        dmem_en,
    output logic [3:0]  dmem_we,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_gnt,

    output logic        trap,
    output logic        wb_valid,
    output logic [31:0] wb_data
);
    rv32i_core #(.FORMAL(1'b0)) core (
        .clk(clk), .rst(rst),
        .imem_en(imem_en), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_en(dmem_en), .dmem_we(dmem_we), .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata), .dmem_gnt(dmem_gnt),
        .trap(trap), .wb_valid(wb_valid), .wb_data(wb_data),
        .rvfi_valid(), .rvfi_order(), .rvfi_insn(), .rvfi_trap(), .rvfi_halt(), .rvfi_intr(),
        .rvfi_mode(), .rvfi_ixl(), .rvfi_rs1_addr(), .rvfi_rs2_addr(), .rvfi_rs1_rdata(),
        .rvfi_rs2_rdata(), .rvfi_rd_addr(), .rvfi_rd_wdata(), .rvfi_pc_rdata(), .rvfi_pc_wdata(),
        .rvfi_mem_addr(), .rvfi_mem_rmask(), .rvfi_mem_wmask(), .rvfi_mem_rdata(), .rvfi_mem_wdata()
    );
endmodule
