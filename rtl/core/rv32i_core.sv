// RV32I-Alpha core
// Engineer: Badreddine BENFETTOUMA (University of Bourgogne Europe)
//
// Two-stage pipeline:
//   IF : pc_if is sent to the synchronous instruction memory.
//   EX : the instruction comes out of the memory (imem_rdata) one cycle later and is decoded,
//        executed and written back in the same cycle. The memory output register is the
//        IF/EX pipeline register.
// Hazards:
//   - Data: none. The register file is written at the end of EX and read by the next
//     instruction after that clock edge.
//   - Control: branches are predicted not taken. A taken branch or a jump kills the
//     instruction fetched behind it (one bubble).
//   - Loads stay two cycles in EX; the instruction memory output is held meanwhile.
// Traps (core halts, no side effect, trap = 1): ECALL, EBREAK, illegal instructions,
// misaligned loads/stores, jumps or taken branches to a misaligned target.
// Memories (outside):
//   imem: data valid one clock after (imem_en, imem_addr), output held while imem_en = 0.
//   dmem: request held until dmem_gnt = 1; read data valid in the cycle after the grant.

module rv32i_core #(
    parameter logic [31:0] RESET_ADDR = 32'h0000_0000,
    parameter bit          FORMAL     = 1'b0            // drive the RVFI trace port
) (
    input  logic        clk,
    input  logic        rst,          // active high, async assert, sync de-assert

    output logic        imem_en,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    output logic        dmem_en,
    output logic [3:0]  dmem_we,      // one write enable per byte, 0000 = read
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_gnt,     // the memory accepts the request this cycle

    output logic        trap,         // the core has halted
    output logic        wb_valid,     // a register (not x0) is written this cycle
    output logic [31:0] wb_data,

    // RISC-V Formal Interface (driven only when FORMAL = 1)
    output logic        rvfi_valid,
    output logic [63:0] rvfi_order,
    output logic [31:0] rvfi_insn,
    output logic        rvfi_trap,
    output logic        rvfi_halt,
    output logic        rvfi_intr,
    output logic [1:0]  rvfi_mode,
    output logic [1:0]  rvfi_ixl,
    output logic [4:0]  rvfi_rs1_addr,
    output logic [4:0]  rvfi_rs2_addr,
    output logic [31:0] rvfi_rs1_rdata,
    output logic [31:0] rvfi_rs2_rdata,
    output logic [4:0]  rvfi_rd_addr,
    output logic [31:0] rvfi_rd_wdata,
    output logic [31:0] rvfi_pc_rdata,
    output logic [31:0] rvfi_pc_wdata,
    output logic [31:0] rvfi_mem_addr,
    output logic [3:0]  rvfi_mem_rmask,
    output logic [3:0]  rvfi_mem_wmask,
    output logic [31:0] rvfi_mem_rdata,
    output logic [31:0] rvfi_mem_wdata
);
    // pipeline state (word addresses: bits 1:0 of the PCs are always zero)
    logic [31:2] pc_if;       // address being fetched
    logic [31:2] pc_ex;       // address of the instruction in EX
    logic        ex_valid;    // imem_rdata holds an instruction to execute
    logic        load_wait;   // second cycle of a load
    logic        halted;

    logic [31:0] instr;
    logic [4:0]  rs1, rs2, rd;
    assign instr = imem_rdata;
    assign rs1   = instr[19:15];
    assign rs2   = instr[24:20];
    assign rd    = instr[11:7];

    // ---------------------------------------------------------------- decode
    logic        d_reg_write, d_alu_src, d_zero_a, d_mem_write, d_is_load;
    logic        d_branch, d_jump, d_jalr, d_trap;
    logic [1:0]  d_result_src;
    logic [2:0]  alu_fn;
    logic        alu_sub, alu_arith;
    logic [31:0] imm;

    rv32i_decoder dec (
        .instr(instr), .reg_write(d_reg_write), .alu_src(d_alu_src), .zero_a(d_zero_a),
        .mem_write(d_mem_write), .is_load(d_is_load), .result_src(d_result_src),
        .branch(d_branch), .jump(d_jump), .jalr(d_jalr), .trap(d_trap),
        .alu_fn(alu_fn), .alu_sub(alu_sub), .alu_arith(alu_arith), .imm(imm)
    );

    // ---------------------------------------------------------------- execute
    logic [31:0] data1, data2, src1, src2, alu_result, load_data, result_wb, store_word;
    logic [31:0] pc_base, pc_target, link_addr, pc_next_ex;
    logic        lt, eq, reg_we, misaligned;
    logic [3:0]  lane_mask;

    rv32i_regfile rf (
        .clk(clk), .raddr1(rs1), .raddr2(rs2), .rdata1(data1), .rdata2(data2),
        .we(reg_we), .waddr(rd), .wdata(result_wb)
    );

    assign src1 = d_zero_a ? 32'd0 : data1;   // LUI: 0 + imm
    assign src2 = d_alu_src ? imm : data2;

    rv32i_alu alu (
        .a(src1), .b(src2), .fn(alu_fn), .sub(alu_sub), .arith(alu_arith),
        .result(alu_result), .lt(lt), .eq(eq)
    );

    // branch: funct3[2] = 0 -> equality, 1 -> less than (signed or not, chosen by the decoder);
    // funct3[0] = 1 -> inverted
    logic branch_cond, take_target;
    assign branch_cond = instr[14] ? lt : eq;
    assign take_target = d_jump | (d_branch & (branch_cond ^ instr[12]));

    assign pc_base    = d_jalr ? data1 : {pc_ex, 2'b00};
    assign pc_target  = (pc_base + imm) & 32'hFFFF_FFFE;   // JALR clears bit 0; also AUIPC
    assign link_addr  = {pc_if, 2'b00};                    // PC + 4: while EX is valid, pc_if = pc_ex + 4
    assign pc_next_ex = take_target ? pc_target : link_addr;

    rv32i_lsu lsu (
        .funct3(instr[14:12]), .addr_low(alu_result[1:0]), .store_data(data2),
        .mem_rdata(dmem_rdata), .lane_mask(lane_mask), .misaligned(misaligned),
        .mem_wdata(store_word), .load_data(load_data)
    );

    always_comb begin
        case (d_result_src)
            2'd1:    result_wb = load_data;
            2'd2:    result_wb = link_addr;
            2'd3:    result_wb = pc_target;
            default: result_wb = alu_result;
        endcase
    end

    // ---------------------------------------------------------------- control
    logic ex_live, trap_now, load_req, store_ok, mem_req, mem_wait, stall, freeze, redirect, retire;
    logic mem_misaligned, pc_misaligned, mem_hold;

    assign ex_live        = ex_valid & ~halted;
    assign mem_misaligned = (d_is_load | d_mem_write) & misaligned;
    assign pc_misaligned  = take_target & pc_target[1];    // no compressed instructions
    assign trap_now       = ex_live & (d_trap | mem_misaligned | pc_misaligned);

    // a load waits for its grant, then for its data; a store waits for its grant
    assign load_req = ex_live & d_is_load & ~load_wait & ~trap_now;
    assign store_ok = ex_live & d_mem_write & ~trap_now;
    assign mem_req  = load_req | store_ok;
    assign mem_wait = mem_req & ~dmem_gnt;
    assign stall    = load_req | mem_wait;
    assign freeze   = halted | trap_now | stall;
    assign redirect = ex_live & take_target & ~trap_now;
    assign retire   = ex_live & ~stall;
    assign reg_we   = ex_live & d_reg_write & ~trap_now & ~stall;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_if     <= RESET_ADDR[31:2];
            ex_valid  <= 1'b0;
            load_wait <= 1'b0;
            halted    <= 1'b0;
        end else begin
            load_wait <= load_req & dmem_gnt;
            if (trap_now) halted <= 1'b1;
            if (!freeze) begin
                if (redirect) begin
                    pc_if    <= pc_target[31:2];
                    ex_valid <= 1'b0;          // kill the instruction fetched behind the jump
                end else begin
                    pc_if    <= pc_if + 30'd1;
                    ex_valid <= 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk)                   // no reset: only used when ex_valid = 1
        if (!freeze) pc_ex <= pc_if;

    // ---------------------------------------------------------------- outputs
    // The instruction memory is disabled (output held) whenever the core stalls. This depends
    // on the decoder and dmem_gnt only, not on the ALU, so it is ready early in the cycle
    // (an ASIC SRAM can capture it on the falling edge). A trapping instruction may fetch one
    // useless word: the core halts on the next edge anyway.
    assign mem_hold   = ex_live & ((d_is_load & ~load_wait) | (d_mem_write & ~dmem_gnt));
    assign imem_en    = ~(halted | mem_hold);
    assign imem_addr  = {pc_if, 2'b00};

    assign dmem_en    = mem_req;
    assign dmem_we    = store_ok ? lane_mask : 4'b0000;
    assign dmem_addr  = alu_result;
    assign dmem_wdata = store_word;

    assign trap       = halted;
    assign wb_valid   = reg_we & (rd != 5'd0);
    assign wb_data    = result_wb;

    // ---------------------------------------------------------------- RVFI
    generate
        if (FORMAL) begin : g_rvfi
            logic [63:0] order;
            always_ff @(posedge clk or posedge rst)
                if (rst) order <= 64'd0;
                else if (retire) order <= order + 64'd1;

            assign rvfi_valid     = retire;
            assign rvfi_order     = order;
            assign rvfi_insn      = instr;
            assign rvfi_trap      = trap_now;
            assign rvfi_halt      = trap_now;
            assign rvfi_intr      = 1'b0;
            assign rvfi_mode      = 2'b11;
            assign rvfi_ixl       = 2'b01;
            assign rvfi_rs1_addr  = rs1;
            assign rvfi_rs2_addr  = rs2;
            assign rvfi_rs1_rdata = data1;
            assign rvfi_rs2_rdata = data2;
            assign rvfi_rd_addr   = wb_valid ? rd : 5'd0;
            assign rvfi_rd_wdata  = wb_valid ? result_wb : 32'd0;
            assign rvfi_pc_rdata  = {pc_ex, 2'b00};
            assign rvfi_pc_wdata  = pc_next_ex;
            assign rvfi_mem_addr  = {alu_result[31:2], 2'b00};
            assign rvfi_mem_rmask = (d_is_load & ~trap_now) ? lane_mask : 4'b0000;
            assign rvfi_mem_wmask = store_ok ? lane_mask : 4'b0000;
            assign rvfi_mem_rdata = dmem_rdata;
            assign rvfi_mem_wdata = store_word;
        end else begin : g_no_rvfi
            assign rvfi_valid = 1'b0;     assign rvfi_order = 64'd0;     assign rvfi_insn = 32'd0;
            assign rvfi_trap = 1'b0;      assign rvfi_halt = 1'b0;       assign rvfi_intr = 1'b0;
            assign rvfi_mode = 2'b00;     assign rvfi_ixl = 2'b00;
            assign rvfi_rs1_addr = 5'd0;  assign rvfi_rs2_addr = 5'd0;
            assign rvfi_rs1_rdata = 32'd0; assign rvfi_rs2_rdata = 32'd0;
            assign rvfi_rd_addr = 5'd0;   assign rvfi_rd_wdata = 32'd0;
            assign rvfi_pc_rdata = 32'd0; assign rvfi_pc_wdata = 32'd0;
            assign rvfi_mem_addr = 32'd0; assign rvfi_mem_rmask = 4'd0;  assign rvfi_mem_wmask = 4'd0;
            assign rvfi_mem_rdata = 32'd0; assign rvfi_mem_wdata = 32'd0;
        end
    endgenerate
endmodule
