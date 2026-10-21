library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- A testbench has no ports (it is an empty entity)
entity top_tb is
end top_tb;

architecture sim of top_tb is
    -- 1. Signal Declarations
    signal clk_tb     : std_logic := '0';
    signal reset_tb   : std_logic := '1';
    signal trap_tb    : std_logic; -- Monitor the trap signal for system termination
    signal testOUT_tb : std_logic_vector(31 downto 0);

    constant clk_period : time := 10 ns;
    signal sim_done   : boolean := false; -- stops the clock so the simulation ends by itself

begin

    -- 3. Unit Under Test (UUT) Instantiation
    uut: entity work.top
        port map (
            clk     => clk_tb,
            reset   => reset_tb,
            trap    => trap_tb, -- Mapping the trap signal for validation
            testOUT => testOUT_tb
        );

    -- 4. Clock Generation Process
    clk_process : process
    begin
        while not sim_done loop
            clk_tb <= '0'; wait for clk_period/2;
            clk_tb <= '1'; wait for clk_period/2;
        end loop;
        wait;
    end process;

    -- 5. Intelligent Stimulus Process
    stim_proc: process
        variable last_wb : std_logic_vector(31 downto 0) := (others => '0');
    begin        
        -- Initial reset sequence
        reset_tb <= '1';
        wait for 25 ns;
        reset_tb <= '0';

        -- The test program ends with an ebreak (TRAP). The instruction just before it
        -- writes the verdict in x31: 1 = pass, otherwise the number of the failed test.
        -- testOUT shows the write-back bus, so we keep the last value seen before TRAP.
        -- Signals are sampled on the clock edge, i.e. the value of the instruction
        -- that has just finished.
        for cycle in 0 to 2000 loop
            wait until rising_edge(clk_tb);
            exit when trap_tb = '1';
            last_wb := testOUT_tb;
        end loop;

        if trap_tb /= '1' then
            assert false report "ERROR: Simulation timeout! The processor never reached ebreak/ecall." severity failure;
        elsif unsigned(last_wb) = 1 then
            report "SUCCESS: all checks of the torture test passed." severity note;
        else
            assert false report "ERROR: torture test failed at test number " & integer'image(to_integer(unsigned(last_wb))) severity failure;
        end if;

        -- Stop simulation (no more events once the clock stops)
        sim_done <= true;
        wait;
    end process;

end sim;
