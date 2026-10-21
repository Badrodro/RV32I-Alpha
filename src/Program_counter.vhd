library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Program_counter is
    Port ( 
    reset : in std_logic;
    pcNext: in std_logic_vector(31 downto 0); -- for jump instructions (jal or jalr)
    pcSel: in std_logic;
    clk: in std_logic;
    stall: in std_logic;
    
    pcOUT : out std_logic_vector(31 downto 0)
);
end Program_counter;

architecture Behavioral of Program_counter is
    signal s_pcOUT: unsigned(31 downto 0);
    
begin

process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            s_pcOUT <= (others => '0');
        elsif stall = '0' then
            if pcSel = '0' then
                s_pcOUT <= s_pcOUT + 4;
            else
                s_pcOUT <= unsigned(pcNext); -- adress calculated previously
            end if;
         end if; -- if stall = '1' the PC is blocked
    end if;
end process;

pcOUT <= std_logic_vector(s_pcOUT);

end Behavioral;
