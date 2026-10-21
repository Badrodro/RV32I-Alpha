library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU_decoder is
    Port (
        aluOP: in std_logic_vector(1 downto 0);
        funct3: in std_logic_vector(2 downto 0);
        funct7_5: in std_logic; -- only the bit 5 of funct7 is needed to make the difference between operations
        
        aluOUT: out std_logic_vector(3 downto 0)
        



 );
end ALU_decoder;

architecture Behavioral of ALU_decoder is
signal rtype_alt: std_logic;

begin
rtype_alt <= funct7_5 and not(aluOP(0)) and not(aluOP(1)); -- pre-decoding, it ensures that bit 30 is only interpreted as 'sub' for R-type and not for I-type immediate (like addi).

process(funct3,aluOP,funct7_5,rtype_alt)
begin
    case aluOP is
        when "00" | "01" => 
            case funct3 is 
               when "000" =>    
                   if rtype_alt = '1' then -- to make the difference between  R-type and I-type
                       aluOUT <= "0001"; -- sub
                   else
                       aluOUT <= "0000"; --add, addi etc
                   end if;
                    
                when "100" =>
                    aluOUT <= "0100"; -- xor
                
                when "110" =>
                    aluOUT <= "0011"; -- or
                
                when "111" =>
                    aluOUT <= "0010"; -- and
                
                when "001" =>
                    aluOUT <= "0101"; -- SLL
                
                when "101" =>
                    if funct7_5 = '1' then
                       aluOUT <= "0111"; -- sra / srai
                    else
                       aluOUT <= "0110"; -- srl / srli
                    end if;
                    
                when "010" =>
                    aluOUT <= "1000"; 
                
                when "011" =>
                    aluOUT <= "1001";
                
                when others =>
                    aluOUT <= "0000";
             end case;
             
         when "10" =>
            aluOUT <= "0000";
            
         when "11" => -- branch: reuse the ALU comparators, the condition is finished in top
            case funct3(2 downto 1) is
                when "10" =>
                    aluOUT <= "1000"; -- BLT / BGE use SLT
                when "11" =>
                    aluOUT <= "1001"; -- BLTU / BGEU use SLTU
                when others =>
                    aluOUT <= "0001"; -- BEQ / BNE use SUB and the zero flag
            end case;
         when others =>
            aluOUT <= "0000";
     end case;
 end process;                 

end Behavioral;
