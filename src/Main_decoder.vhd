library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Main decoder: turns an instruction into the control signals of the datapath.
-- Every encoding that is not an RV32I instruction raises "trap", and so do
-- ECALL and EBREAK (there is no exception handler: the core halts).
-- FENCE is executed as a NOP (single hart, no cache).

entity Main_decoder is
     Port (
        instr: in std_logic_vector(31 downto 0);

        regWrite: out std_logic; -- the instruction writes rd
        immType: out std_logic_vector (2 downto 0); -- format of the immediate (see Imm_gen)
        aluSrc: out std_logic; -- second ALU operand: '0' rs2, '1' immediate
        aluSrcA: out std_logic_vector(1 downto 0); -- first ALU operand: "00" rs1, "01" PC (AUIPC), "10" zero (LUI)
        memWrite: out std_logic; -- store
        resultSrc: out std_logic_vector(1 downto 0); -- value written to rd: "00" ALU, "01" load data, "10" PC + 4
        aluOP: out std_logic_vector(1 downto 0); -- class of ALU operation, refined by the ALU decoder
        branch: out std_logic; -- conditional branch
        isLoad: out std_logic; -- load (the data memory is synchronous: 2 cycles)
        jump: out std_logic; -- JAL or JALR
        jalr: out std_logic; -- JALR (target = rs1 + imm)
        trap: out std_logic -- ECALL, EBREAK or illegal instruction
        );
end Main_decoder;

architecture Behavioral of Main_decoder is
    signal opcode: std_logic_vector(6 downto 0);
    signal funct3: std_logic_vector(2 downto 0);
    signal funct7: std_logic_vector(6 downto 0);
begin

opcode <= instr(6 downto 0);
funct3 <= instr(14 downto 12);
funct7 <= instr(31 downto 25);

process(opcode, funct3, funct7)
begin
    regWrite <= '0';
    immType <= "000";
    aluSrc <= '0';
    aluSrcA <= "00";
    memWrite <= '0';
    resultSrc <= "00";
    aluOP <= "00";
    branch <= '0';
    jump <= '0';
    isLoad <= '0';
    jalr <= '0';
    trap <= '0';

    case opcode is
        when "0110011" => -- R-type: funct7 must be 0000000, or 0100000 for SUB / SRA
            regWrite <= '1';
            aluOP <= "00"; -- the ALU decoder looks at funct3 and funct7
            if not (funct7 = "0000000" or (funct7 = "0100000" and (funct3 = "000" or funct3 = "101"))) then
                trap <= '1';
            end if;

        when "0010011" => -- I-type ALU
            regWrite <= '1';
            immType <= "001";
            aluSrc <= '1';
            aluOP <= "01"; -- the ALU decoder looks at funct3 (and funct7 for the shifts)
            if funct3 = "001" and funct7 /= "0000000" then -- SLLI
                trap <= '1';
            elsif funct3 = "101" and funct7 /= "0000000" and funct7 /= "0100000" then -- SRLI / SRAI
                trap <= '1';
            end if;

        when "0000011" => -- loads: LB LH LW LBU LHU
            regWrite <= '1';
            immType <= "001";
            aluSrc <= '1';
            resultSrc <= "01";
            aluOP <= "10"; -- address = rs1 + imm
            isLoad <= '1';
            if funct3 = "011" or funct3 = "110" or funct3 = "111" then
                trap <= '1';
            end if;

        when "0100011" => -- stores: SB SH SW
            immType <= "010";
            aluSrc <= '1';
            memWrite <= '1';
            aluOP <= "10";
            if funct3(2) = '1' or funct3 = "011" then
                trap <= '1';
            end if;

        when "1100011" => -- branches
            immType <= "011";
            aluOP <= "11"; -- comparison chosen by funct3 in the ALU decoder
            branch <= '1';
            if funct3(2 downto 1) = "01" then
                trap <= '1';
            end if;

        when "1101111" => -- JAL
            regWrite <= '1';
            immType <= "101";
            resultSrc <= "10"; -- rd = PC + 4
            jump <= '1';

        when "1100111" => -- JALR
            regWrite <= '1';
            immType <= "001";
            aluSrc <= '1';
            resultSrc <= "10";
            aluOP <= "10";
            jump <= '1';
            jalr <= '1';
            if funct3 /= "000" then
                trap <= '1';
            end if;

        when "0110111" => -- LUI: rd = 0 + imm (bits 19:15 belong to the immediate, not to rs1)
            regWrite <= '1';
            immType <= "100";
            aluSrc <= '1';
            aluSrcA <= "10";
            aluOP <= "10";

        when "0010111" => -- AUIPC: rd = PC + imm
            regWrite <= '1';
            immType <= "100";
            aluSrc <= '1';
            aluSrcA <= "01";
            aluOP <= "10";

        when "0001111" => -- FENCE: NOP (FENCE.I is not part of RV32I)
            if funct3 /= "000" then
                trap <= '1';
            end if;

        when others => -- SYSTEM (ECALL, EBREAK, CSRs) and every unknown opcode
            trap <= '1';
    end case;
end process;

end Behavioral;
