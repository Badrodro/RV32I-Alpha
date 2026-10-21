library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ALU control. The ALU uses the funct3 encoding of RV32I, so for OP and OP-IMM
-- funct3 goes straight through; only the other instruction classes are remapped.

entity ALU_decoder is
    Port (
        aluOP: in std_logic_vector(1 downto 0); -- "00" R-type, "01" I-type, "10" add, "11" branch
        funct3: in std_logic_vector(2 downto 0);
        funct7_5: in std_logic; -- instruction bit 30: SUB / SRA / SRAI

        fn: out std_logic_vector(2 downto 0);
        sub: out std_logic;
        arith: out std_logic
 );
end ALU_decoder;

architecture Behavioral of ALU_decoder is
begin

process(aluOP, funct3, funct7_5)
begin
    case aluOP is
        when "00" => -- R-type
            fn <= funct3;
            sub <= funct7_5;
            arith <= funct7_5;
        when "01" => -- I-type: there is no SUBI, bit 30 only selects SRAI
            fn <= funct3;
            sub <= '0';
            arith <= funct7_5;
        when "11" => -- branch: BLT/BGE compare signed (SLT), BLTU/BGEU unsigned (SLTU)
            fn <= "01" & funct3(1);
            sub <= '1';
            arith <= '0';
        when others => -- loads, stores, JALR, LUI: addition
            fn <= "000";
            sub <= '0';
            arith <= '0';
    end case;
end process;

end Behavioral;
