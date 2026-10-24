// RV32I-Alpha: instruction decoder.
// Main control signals, ALU control (the ALU uses the funct3 encoding) and immediate.
// Every encoding that is not an RV32I instruction raises trap, and so do ECALL and EBREAK
// (there is no exception handler: the core halts). FENCE is executed as a NOP.

module rv32i_decoder (
    input  logic [31:0] instr,

    output logic        reg_write,   // the instruction writes rd
    output logic        alu_src,     // second ALU operand: 0 rs2, 1 immediate
    output logic        zero_a,      // first ALU operand: 0 rs1, 1 zero (LUI)
    output logic        mem_write,   // store
    output logic        is_load,     // load (2 cycles: the data memory is synchronous)
    output logic [1:0]  result_src,  // rd value: 0 ALU, 1 load data, 2 PC + 4, 3 PC + imm (AUIPC)
    output logic        branch,      // conditional branch
    output logic        jump,        // JAL or JALR
    output logic        jalr,        // JALR (target = rs1 + imm)
    output logic        trap,        // ECALL, EBREAK or illegal instruction

    output logic [2:0]  alu_fn,      // ALU operation (funct3 encoding)
    output logic        alu_sub,     // ADD -> SUB
    output logic        alu_arith,   // SRL -> SRA
    output logic [31:0] imm
);
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    logic [2:0] imm_type;            // 1 I, 2 S, 3 B, 4 U, 5 J, 0 none
    logic [1:0] alu_op;              // 0 R-type, 1 I-type, 2 add, 3 branch

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin
        reg_write  = 1'b0;
        imm_type   = 3'd0;
        alu_src    = 1'b0;
        zero_a     = 1'b0;
        mem_write  = 1'b0;
        result_src = 2'd0;
        alu_op     = 2'd0;
        branch     = 1'b0;
        jump       = 1'b0;
        is_load    = 1'b0;
        jalr       = 1'b0;
        trap       = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type: funct7 is 0000000, or 0100000 for SUB / SRA
                reg_write = 1'b1;
                alu_op    = 2'd0;
                if (!(funct7 == 7'b0000000 || (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101))))
                    trap = 1'b1;
            end
            7'b0010011: begin // I-type ALU
                reg_write = 1'b1;
                imm_type  = 3'd1;
                alu_src   = 1'b1;
                alu_op    = 2'd1;
                if (funct3 == 3'b001 && funct7 != 7'b0000000)
                    trap = 1'b1; // SLLI
                else if (funct3 == 3'b101 && funct7 != 7'b0000000 && funct7 != 7'b0100000)
                    trap = 1'b1; // SRLI / SRAI
            end
            7'b0000011: begin // loads: LB LH LW LBU LHU
                reg_write  = 1'b1;
                imm_type   = 3'd1;
                alu_src    = 1'b1;
                result_src = 2'd1;
                alu_op     = 2'd2; // address = rs1 + imm
                is_load    = 1'b1;
                if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111)
                    trap = 1'b1;
            end
            7'b0100011: begin // stores: SB SH SW
                imm_type  = 3'd2;
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'd2;
                if (funct3[2] || funct3 == 3'b011)
                    trap = 1'b1;
            end
            7'b1100011: begin // branches
                imm_type = 3'd3;
                alu_op   = 2'd3;
                branch   = 1'b1;
                if (funct3[2:1] == 2'b01)
                    trap = 1'b1;
            end
            7'b1101111: begin // JAL
                reg_write  = 1'b1;
                imm_type   = 3'd5;
                result_src = 2'd2;
                jump       = 1'b1;
            end
            7'b1100111: begin // JALR
                reg_write  = 1'b1;
                imm_type   = 3'd1;
                alu_src    = 1'b1;
                result_src = 2'd2;
                alu_op     = 2'd2;
                jump       = 1'b1;
                jalr       = 1'b1;
                if (funct3 != 3'b000)
                    trap = 1'b1;
            end
            7'b0110111: begin // LUI: rd = 0 + imm (bits 19:15 belong to the immediate)
                reg_write = 1'b1;
                imm_type  = 3'd4;
                alu_src   = 1'b1;
                zero_a    = 1'b1;
                alu_op    = 2'd2;
            end
            7'b0010111: begin // AUIPC: rd = PC + imm, computed by the jump target adder
                reg_write  = 1'b1;
                imm_type   = 3'd4;
                result_src = 2'd3;
            end
            7'b0001111: begin // FENCE: NOP (FENCE.I is not part of RV32I)
                if (funct3 != 3'b000)
                    trap = 1'b1;
            end
            default: trap = 1'b1; // SYSTEM (ECALL, EBREAK, CSRs) and unknown opcodes
        endcase
    end

    // ALU control: funct3 goes straight through for OP and OP-IMM
    always_comb begin
        case (alu_op)
            2'd0: begin alu_fn = funct3; alu_sub = instr[30]; alu_arith = instr[30]; end  // R-type
            2'd1: begin alu_fn = funct3; alu_sub = 1'b0;      alu_arith = instr[30]; end  // I-type (no SUBI)
            2'd3: begin alu_fn = {2'b01, funct3[1]}; alu_sub = 1'b1; alu_arith = 1'b0; end // branch: SLT/SLTU
            default: begin alu_fn = 3'b000; alu_sub = 1'b0; alu_arith = 1'b0; end          // addition
        endcase
    end

    // immediate
    always_comb begin
        case (imm_type)
            3'd1: imm = {{20{instr[31]}}, instr[31:20]};                                  // I
            3'd2: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};                     // S
            3'd3: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};     // B
            3'd4: imm = {instr[31:12], 12'b0};                                            // U
            3'd5: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};   // J
            default: imm = 32'b0;
        endcase
    end
endmodule
