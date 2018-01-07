--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- spartan3board.vhd: This entity combines the CPU with a seven segment display unit and
-- 		      an LED array and interfaces it to Spartan-3 Start Board equiped
-- 		      with a Xilinx Spartan-3 XC3S1000FT256-4 FPGA
--
-- Copyright (c) 2017, Helmut Sipos <helmut.sipos@gmail.com>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity spartan3board is
	port(I_clk        : in std_logic;

	     O_leds       : out std_logic_vector (7 downto 0);
	     O_an         : out std_logic_vector (3 downto 0);
	     O_sseg       : out std_logic_vector (7 downto 0)
	);
end;

architecture logic of spartan3board is
	signal clk		   : std_logic;
	signal prescaler	   : std_logic_vector (25 downto 0);
	signal address	           : std_logic_vector(15 downto 1);
	signal write_operation     : std_logic;
	signal data_w              : std_logic_vector(15 downto 0);
	signal debug_data          : std_logic_vector(15 downto 0);
	signal enable_leds_write   : std_logic;

begin
	-- From the 50 MHz clock generate a 1 (one!) Hz clock so to be able to
        -- follow CPU operation with the naked eye.
	clk_div : process is
	begin
		if rising_edge(I_clk) then
			-- 50.000.000 in binary
			if prescaler < "10111110101111000010000000" then
				prescaler <= prescaler + 1;
			else
				prescaler <= (others => '0');
				clk <= not clk;
			end if;
		end if;
	end process;

	-- Instantiate and connect the CPU
	cpu: entity work.cpu(logic)
	port map (
		 I_clk             => clk

		,O_address         => address
		,O_write_operation => write_operation
		,O_data_w          => data_w
		,O_debug_data      => debug_data
	);

	-- Instantiate and connect the seven segment display
	sevseg: entity work.sevseg(logic)
	port map(
		 I_clk_slow   => clk
		,I_clk_fast   => I_clk
		,I_data       => debug_data

		,O_an         => O_an
		,O_sseg       => O_sseg
	);


	-- LEDs mapped at address 0x8000
	enable_leds_write <= '1' when (address(15 downto 1) = "100000000000000")
			    	  and (write_operation = '1') else '0';

	-- Instantiate and connect the LED array display
	leds: entity work.leds(logic)
	port map(
		 I_clk          => clk
		,I_enable_write => enable_leds_write
		,I_data		=> data_w(7 downto 0)

		,O_leds         => O_leds
	);
end;

