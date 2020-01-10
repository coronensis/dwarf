--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Implements the program counter logic
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
use work.dwarf.all;

entity program_counter is
	port (
		I_clk		 : in std_logic;
		I_cpu_pause	 : in std_logic;
		I_take_branch	 : in std_logic;
		I_pc_source	 : in pc_source_type;
		I_alu_res	 : in std_logic_vector(15 downto 0);
		I_instruction	 : in std_logic_vector(15 downto 0);

		O_pc_current	 : out std_logic_vector(15 downto 1);
		O_pc_next	 : out std_logic_vector(15 downto 1);
		O_enable_decoder : out std_logic
	);
end;

architecture logic of program_counter is
	signal R_pc_current : std_logic_vector(15 downto 1) := "111111111111111";
begin

	-- pc current was fetched and is currently being executed

	-- pc next is currently fetched and will be executed next

	pc_select: process (I_clk, I_cpu_pause, I_take_branch, I_pc_source, I_alu_res, I_instruction) is
		variable pc_var : std_logic_vector(15 downto 1);
	begin

		-- Default case. increment he program counter by two
	        -- lowest bit is always 0 due to allignment to 16 bits
		pc_var := R_pc_current + '1';

		-- Alternative sources for the program counter
		case I_pc_source is
			when PC_FROM_OPCODE11_0 =>
				pc_var := ZERO(15 downto 13) & I_instruction(11 downto 0);
			when PC_FROM_BRANCH =>
				if I_take_branch = '1' then
					pc_var := I_alu_res(15 downto 1);
				end if;
			when others =>
		end case;

		-- While the CPU is paused stay on the current instr. address
		if I_cpu_pause = '1' then
			pc_var := R_pc_current;
		end if;

		if rising_edge(I_clk) then
			-- Take over the new address. instruction has been fetched
			R_pc_current <= pc_var;

			-- If a jump occurs suppress execution of the previusly fetched
			-- instruction (delay slot)
			if I_take_branch = '0' then
				O_enable_decoder <= '1';
			else
				O_enable_decoder <= '0';
			end if;

		end if;

		-- The address of the instruction to be fetched next
		O_pc_current <= R_pc_current;
		O_pc_next <= pc_var;

	end process;
end;

