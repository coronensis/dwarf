--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Implements the memory controller
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
use work.dwarf.all;

entity memory_controller is
	port (
		I_clk		 : in std_logic;
		I_pc_next        : in std_logic_vector(15 downto 1);
		I_mem_source     : in mem_source_type;
		I_ram_data_read  : in std_logic_vector(15 downto 0);
		I_rt_value       : in std_logic_vector(15 downto 0);
		I_alu_res        : in std_logic_vector(15 downto 0);

		O_cpu_pause	 : out std_logic;
		O_instruction    : out std_logic_vector(15 downto 0);
		O_ram_address    : out std_logic_vector(15 downto 1);
		O_ram_data_read  : out std_logic_vector(15 downto 0);
		O_ram_data_write : out std_logic_vector(15 downto 0);
		O_ram_we	 : out std_logic;
		O_mem_address  	 : out std_logic_vector(15 downto 1);
		O_mem_data_write : out std_logic_vector(15 downto 0);
		O_mem_we	 : out std_logic
	);
end;

architecture logic of memory_controller is

	signal R_instruction	  : std_logic_vector(15 downto 0);
	signal R_instruction_next : std_logic_vector(15 downto 0);
	signal R_address	  : std_logic_vector(15 downto 1);
	signal R_mem_we		  : std_logic;
	signal R_mem_state	  : mem_state_type;
begin
	memctrl_proc: process (I_clk, I_pc_next, I_mem_source, I_ram_data_read, I_rt_value, I_alu_res) is

		variable address_next_var     : std_logic_vector(15 downto 1);
		variable ram_read_var	      : std_logic_vector(15 downto 0);
		variable ram_write_var	      : std_logic_vector(15 downto 0);
		variable instruction_next_var : std_logic_vector(15 downto 0);
		variable we_next_var	      : std_logic;
		variable mem_state_next_var   : mem_state_type;
		variable pause_var	      : std_logic;
	begin
		we_next_var	     := '0';
		pause_var	     := '0';
		ram_read_var	     := ZERO;
		ram_write_var	     := ZERO;
		mem_state_next_var   := R_mem_state;
		instruction_next_var := R_instruction;
		address_next_var     := I_pc_next;

		case I_mem_source is
			when MEM_SOURCE_READ16 =>
				ram_read_var	:= I_ram_data_read;

			when MEM_SOURCE_WRITE16 =>
				ram_write_var	:= I_rt_value;
				we_next_var	:= '1';

			when others =>
		end case;

		if I_mem_source = MEM_SOURCE_FETCH then
			address_next_var	:= I_pc_next;
			mem_state_next_var	:= MEM_STATE_ADDR;
			instruction_next_var	:= I_ram_data_read;
		else
			if R_mem_state = MEM_STATE_ADDR then
				address_next_var	:= I_alu_res(15 downto 1);
				mem_state_next_var	:= MEM_STATE_ACCESS;
				pause_var		:= '1';
				R_instruction_next	<= I_ram_data_read;
			else
				instruction_next_var	:= R_instruction_next;
				address_next_var	:= I_pc_next;
				mem_state_next_var	:= MEM_STATE_ADDR;
				we_next_var := '0';
			end if;
		end if;

		if rising_edge(I_clk) then

			R_address     <= address_next_var;
			R_mem_we      <= we_next_var;
			R_instruction <= instruction_next_var;
			R_mem_state   <= mem_state_next_var;

		end if;

		O_cpu_pause        <= pause_var;

		O_instruction	   <= R_instruction;

		O_ram_address	   <= address_next_var;
		O_ram_data_read	   <= ram_read_var;
		O_ram_data_write   <= ram_write_var;
		O_ram_we	   <= we_next_var;

		O_mem_address	   <= R_address;
		O_mem_we 	   <= R_mem_we;
		O_mem_data_write   <= ram_write_var;

	end process;
end;

