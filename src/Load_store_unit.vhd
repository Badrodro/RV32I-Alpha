library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Sits between the core and the 32-bit data memory.
-- Stores: places the byte / half-word on the right lane and gives the lanes to write.
-- Loads: picks the byte / half-word out of the memory word and sign- or zero-extends it.
-- Misaligned accesses are flagged: the core traps on them instead of corrupting memory.

entity Load_store_unit is
    Port (
    funct3: in std_logic_vector(2 downto 0); -- access size and sign (LB/LH/LW/LBU/LHU, SB/SH/SW)
    addrLow: in std_logic_vector(1 downto 0); -- 2 LSB of the address = byte position in the word

    storeData: in std_logic_vector(31 downto 0); -- rs2
    ramDataIN: in std_logic_vector(31 downto 0); -- word read from the memory

    laneMask: out std_logic_vector(3 downto 0); -- bytes of the word touched by the access
    misaligned: out std_logic; -- half-word not on an even address, or word not on a multiple of 4
    ramDataOUT: out std_logic_vector(31 downto 0); -- data sent to the memory
    loadData: out std_logic_vector(31 downto 0) -- value written back in rd
    );
end Load_store_unit;

architecture Behavioral of Load_store_unit is

begin

-- lanes and alignment (same for loads and stores)
process(funct3, addrLow)
begin
    case funct3(1 downto 0) is
        when "00" => -- byte
            misaligned <= '0';
            case addrLow is
                when "00" => laneMask <= "0001";
                when "01" => laneMask <= "0010";
                when "10" => laneMask <= "0100";
                when others => laneMask <= "1000";
            end case;

        when "01" => -- half-word
            misaligned <= addrLow(0);
            if addrLow(1) = '1' then
                laneMask <= "1100";
            else
                laneMask <= "0011";
            end if;

        when others => -- word
            misaligned <= addrLow(1) or addrLow(0);
            laneMask <= "1111";
    end case;
end process;

-- store data: the byte / half-word is copied on every lane, only the selected lanes are written
with funct3(1 downto 0) select ramDataOUT <=
    storeData(7 downto 0) & storeData(7 downto 0) & storeData(7 downto 0) & storeData(7 downto 0) when "00",
    storeData(15 downto 0) & storeData(15 downto 0) when "01",
    storeData when others;

-- load path
process(funct3, addrLow, ramDataIN)
variable v_byte: std_logic_vector(7 downto 0);
variable v_half: std_logic_vector(15 downto 0);
begin
    case addrLow is
        when "00" => v_byte := ramDataIN(7 downto 0);
        when "01" => v_byte := ramDataIN(15 downto 8);
        when "10" => v_byte := ramDataIN(23 downto 16);
        when others => v_byte := ramDataIN(31 downto 24);
    end case;

    if addrLow(1) = '1' then
        v_half := ramDataIN(31 downto 16);
    else
        v_half := ramDataIN(15 downto 0);
    end if;

    case funct3 is
        when "000" => loadData <= (31 downto 8 => v_byte(7)) & v_byte; -- LB (sign extension)
        when "001" => loadData <= (31 downto 16 => v_half(15)) & v_half; -- LH (sign extension)
        when "100" => loadData <= (31 downto 8 => '0') & v_byte; -- LBU
        when "101" => loadData <= (31 downto 16 => '0') & v_half; -- LHU
        when others => loadData <= ramDataIN; -- LW
    end case;
end process;

end Behavioral;
