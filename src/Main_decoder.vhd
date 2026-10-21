library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Main_decoder is
     Port (
        opcode: in std_logic_vector(6 downto 0);
        
        regWrite: out std_logic; -- write in register authorization ( ONLY IN REGISTER )
        immType: out std_logic_vector (2 downto 0); -- 3 bits to select the TYPE of the immediate
        aluSrc: out std_logic; -- '0' we take the output of the second register, '1' we take the immediate (multiplexer before the ALU) //  either rs1+ rs2 or rs1 + imm (imm is a constant)
        aluSrcA: out std_logic_vector(1 downto 0); -- first ALU operand: "00" rs1, "01" PC (AUIPC), "10" zero (LUI)
        memWrite: out std_logic; --  write in RAM or not
        resultSrc: out std_logic_vector(1 downto 0); -- what we will stock in register ( either the result of the ALU, or a data from the RAM or the return adress)
        aluOP: out std_logic_vector(1 downto 0); -- code sent to the ALU_decoder module
        branch: out std_logic; -- if we jump or not
        isLoad: out std_logic; -- we need a stall because de ram is synchronous
        jump: out std_logic; -- immediate jump or not
        jalr: out std_logic;
        trap: out std_logic -- system event bit
        );
end Main_decoder;

architecture Behavioral of Main_decoder is


begin

process(opcode)
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
        when "0110011" => -- R-type
            regWrite <= '1';
            aluSrc <= '0'; -- only two registers operation
            memWrite <= '0';
            resultSrc <= "00"; -- result of the ALU
            aluOP <= "00";  -- the alu decoder need to watch funct3 and funct7 to choose the specific operation
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
            
        when "0010011" => -- I-type
            regWrite <= '1';
            immType <= "001";
            aluSrc <= '1'; -- operation between a register and the immediate
            memWrite <= '0';
            resultSrc <= "00";
            aluOP <= "01"; -- the alu decoder will watch only funct3
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
            
        when "0000011" => -- LOAD instructions
            regWrite <= '1';
            immType <= "001";
            aluSrc <= '1';
            memWrite <= '0';
            resultSrc <= "01"; -- ram 
            aluOP <= "10"; -- forced addition
            branch <= '0';
            jump <= '0';
            isLoad <= '1';
            jalr <= '0';
            trap <= '0';
            
        when "0100011" => -- STORE instructions
            regWrite <= '0';
            immType <= "010"; -- store-type immediate
            aluSrc <= '1';
            memWrite <= '1'; -- write in RAM
            aluOP <= "10";
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
            
        when "1100011" => -- branch
            regWrite <= '0';
            immType <= "011"; -- b-type
            aluSrc <= '0';
            memWrite <= '0';
            aluOP <= "11"; -- comparison selected by funct3 in the ALU decoder
            branch <= '1';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
            
        when "1101111" => -- JAL instruction
            regWrite <= '1';
            immType <= "101"; -- j-type
            memWrite <= '0';
            resultSrc <= "10"; -- the return address is saved
            branch <= '0';
            jump <= '1';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
            
        when "1100111" => -- JALR instruction
            regWrite <= '1';
            immType <= "001";
            aluSrc <= '1';
            memWrite <= '0';
            resultSrc <= "10";
            aluOP <= "10"; 
            branch <= '0';
            jump <= '1';
            isLoad <= '0';
            jalr <= '1';
            trap <= '0';
            
        when "0110111" => --LUI instruction
            regWrite <= '1';
            immType <= "100";
            aluSrc <= '1';
            aluSrcA <= "10"; -- rd = 0 + imm (bits 19:15 are part of the immediate, not rs1)
            memWrite <= '0';
            resultSrc <= "00";
            aluOP <= "10";  
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
            
        when "0010111" => -- AUIPC instruction
            regWrite <= '1';
            immType <= "100";
            aluSrc <= '1';
            aluSrcA <= "01"; -- rd = PC + imm
            memWrite <= '0';
            resultSrc <= "00";
            aluOP <= "10";
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            trap <= '0';
            
        when "1110011" => -- SYSTEM instruction
            regWrite <= '0';
            aluSrc <= '0';
            memWrite <= '0';
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '1';
            
        when others => -- includes FENCE, executed as a NOP (single hart, no cache)
            regWrite <= '0';
            aluSrc <= '0';
            memWrite <= '0';
            aluOP <= "00";
            branch <= '0';
            jump <= '0';
            isLoad <= '0';
            jalr <= '0';
            trap <= '0';
       end case;
end process;
    
    

end Behavioral;
