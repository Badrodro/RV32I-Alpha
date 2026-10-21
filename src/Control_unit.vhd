library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity Control_unit is
    Port (
        -- input of main decoder
        opcode: in std_logic_vector(6 downto 0);
        reset: in std_logic;
        clk: in std_logic;
        -- inputs of alu decoder
        funct3: in std_logic_vector(2 downto 0);
        funct7_5: in std_logic;
        
        -- outputs of maindecoder
        regWrite: out std_logic; -- write in register authorization ( ONLY IN REGISTER )
        immType: out std_logic_vector (2 downto 0); -- 3 bits to select the TYPE of the immediate
        aluSrcA: out std_logic_vector(1 downto 0); -- first ALU operand: rs1, PC or zero
        aluSrc: out std_logic; -- '0' we take the output of the second register, '1' we take the immediate (multiplexer before the ALU) //  either rs1+ rs2 or rs1 + imm (imm is a constant)
        memWrite: out std_logic; --  write in RAM or not
        resultSrc: out std_logic_vector(1 downto 0); -- what we will stock in register( either the result of the ALU, or a data from the RAM or the return adress)
        branch: out std_logic; -- if we jump or not
        jump: out std_logic; -- immediate jump or not 
        stall: out std_logic; -- we stop the PC because we wait the RAM to give us the data we asked for
        jalr: out std_logic; 
        trap: out std_logic; -- we stop the PC because there is a system instruction
        
         -- output of alu decoder
        aluOUT: out std_logic_vector(3 downto 0) --
        
     );
end Control_unit;

architecture Behavioral of Control_unit is
signal s_aluOP: std_logic_vector(1 downto 0);

signal s_isLoad : std_logic;
signal step_load : std_logic;
signal s_regWrite : std_logic;
signal s_memWrite : std_logic; 
signal s_stall    : std_logic;
begin

process(clk,reset)
begin
    if reset = '1' then
        step_load <= '0';
    elsif rising_edge(clk) then
        if s_isLoad = '1' and step_load = '0' then
            step_load <= '1';
        else
            step_load <= '0';
        end if;
    end if;
end process;

s_stall <= '1' when (s_isLoad = '1' and step_load = '0') else '0';
stall <= s_stall;

regWrite <= s_regWrite when s_stall = '0' else '0';
memWrite <= s_memWrite when s_stall = '0' else '0';


-- we link the two parts
mainDecoder: entity work.Main_decoder port map (
    opcode => opcode,
    
    regWrite => s_regWrite,
    immType => immType,
    aluSrc => aluSrc,
    aluSrcA => aluSrcA,
    memWrite => s_memWrite,
    resultSrc => resultSrc,
    branch => branch,
    jump => jump,
    aluOP => s_aluOP,
    isLoad => s_isLoad,
    jalr => jalr,
    trap => trap
     );
aluDecoder: entity work.ALU_decoder port map (
    aluOP =>s_aluOP,
    funct3 => funct3,
    funct7_5 => funct7_5,
    
    aluOUT => aluOUT
    );

end Behavioral;
