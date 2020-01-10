--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Glues together the whole CPU including the program counter logic, memory
--          controller, instruction decoder, ALU, register bank and internal RAM
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

entity cpu is
	port (
		I_clk		 : in std_logic;
		I_reset		 : in std_logic;
		I_switches	 : in std_logic_vector(7 downto 0);

		O_mem_address  	 : out std_logic_vector(15 downto 1);
		O_mem_data_write : out std_logic_vector(15 downto 0);
		O_mem_we	 : out std_logic;
		O_debug_data	 : out std_logic_vector(15 downto 0);
		O_enable_decoder : out std_logic;
		O_pause_cpu 	 : out std_logic;
		O_take_branch 	 : out std_logic
	);
end;

architecture logic of cpu is

	-- Instruction Decoder
	signal R_instruction	: std_logic_vector(15 downto 0);
	signal R_ram_read_val	: std_logic_vector(15 downto 0);
	signal R_alu_func	: alu_function_type;
	signal R_mem_source	: mem_source_type;
	signal R_cpu_pause	: std_logic;
	signal R_enable_decoder	: std_logic;

	-- Arithmetic Logic Unit
	signal R_alu_a		: std_logic_vector(15 downto 0);
	signal R_alu_b		: std_logic_vector(15 downto 0);
	signal R_alu_res	: std_logic_vector(15 downto 0);

	-- Program Counter
	signal R_take_branch	: std_logic;
	signal R_pc_source	: pc_source_type;
	signal R_pc_current	: std_logic_vector(15 downto 1);
	signal R_pc_next	: std_logic_vector(15 downto 1);

	-- Register Bank
	signal R_rs_idx		: std_logic_vector(3 downto 0);
	signal R_rs_value	: std_logic_vector(15 downto 0);
	signal R_rt_idx		: std_logic_vector(3 downto 0);
	signal R_rt_value	: std_logic_vector(15 downto 0);
	signal R_rd_idx		: std_logic_vector(3 downto 0);
	signal R_rd_value	: std_logic_vector(15 downto 0);

	-- Internal RAM
	signal R_ram_address	  : std_logic_vector(15 downto 1);
	signal R_ram_write_enable : std_logic;
	signal R_ram_data_write	  : std_logic_vector(15 downto 0);
	signal R_ram_data_read	  : std_logic_vector(15 downto 0);

begin

--------------------------------------------------------------------------------
-- Debug Interface
--------------------------------------------------------------------------------

-- Map some register to the seven segment display to be visible from the outside
with I_switches select
	O_debug_data <= R_instruction		when "00000000",
			R_ram_read_val		when "00000001",
			R_pc_current & '0'	when "00000010",
			R_pc_next & '0'		when "00000100",
			R_alu_res		when "00001000",
			R_ram_address & '0'	when "00010000",
			R_ram_data_read 	when others;

O_enable_decoder <= R_enable_decoder;
O_take_branch    <= R_take_branch;
O_pause_cpu      <= R_cpu_pause;

--------------------------------------------------------------------------------
-- Program Counter
--------------------------------------------------------------------------------

        -- Instantiate and connect the program counter
        program_counter: entity work.program_counter(logic)
        port map (
		 I_clk		  => I_clk
		,I_cpu_pause      => R_cpu_pause
		,I_take_branch	  => R_take_branch
		,I_pc_source	  => R_pc_source
		,I_alu_res	  => R_alu_res
		,I_instruction	  => R_instruction

		,O_pc_current	  => R_pc_current
		,O_pc_next	  => R_pc_next
		,O_enable_decoder => R_enable_decoder
        );

--------------------------------------------------------------------------------
-- Memory controller
--------------------------------------------------------------------------------

        -- Instantiate and connect the memory controller
        memory_controller: entity work.memory_controller(logic)
        port map (
		 I_clk		  => I_clk
                ,I_pc_next        => R_pc_next
                ,I_mem_source     => R_mem_source
                ,I_ram_data_read  => R_ram_data_read
                ,I_rt_value       => R_rt_Value
		,I_alu_res	  => R_alu_res

		,O_cpu_pause      => R_cpu_pause
		,O_instruction	  => R_instruction
                ,O_ram_address    => R_ram_address
                ,O_ram_data_read  => R_ram_read_val
                ,O_ram_data_write => R_ram_data_write
                ,O_ram_we         => R_ram_write_enable
                ,O_mem_address    => O_mem_address
                ,O_mem_data_write => O_mem_data_write
                ,O_mem_we         => O_mem_we
        );

---------------------------------------------------------------------
-- Instruction Decoder
---------------------------------------------------------------------

        -- Instantiate and connect the instruction decoder
        decoder: entity work.decoder(logic)
        port map (
                 I_instruction    => R_instruction
		,I_enable_decoder => R_enable_decoder
                ,I_alu_res        => R_alu_res
                ,I_rs_value       => R_rs_value
                ,I_rt_value       => R_rt_value
                ,I_pc_current     => R_pc_current
                ,I_ram_read_val   => R_ram_read_val

                ,O_alu_a          => R_alu_a
                ,O_alu_b          => R_alu_b
                ,O_alu_func       => R_alu_func
                ,O_rs_idx         => R_rs_idx
                ,O_rt_idx         => R_rt_idx
                ,O_rd_idx         => R_rd_idx
                ,O_rd_value       => R_rd_value
                ,O_pc_source      => R_pc_source
                ,O_take_branch    => R_take_branch
                ,O_mem_source     => R_mem_source
        );

---------------------------------------------------------------------
-- ALU
---------------------------------------------------------------------

        -- Instantiate and connect the arithmetic logical unit
        alu: entity work.alu(logic)
        port map (
                 I_alu_func    	=> R_alu_func
                ,I_alu_a       	=> R_alu_a
                ,I_alu_b       	=> R_alu_b

                ,O_alu_res    	=> R_alu_res
        );

---------------------------------------------------------------------
-- Register Bank
---------------------------------------------------------------------

        -- Instantiate and connect the register bank
        regs: entity work.regs(logic)
        port map (
		 I_clk	     => I_clk
		,I_cpu_pause => R_cpu_pause
                ,I_rs_idx    => R_rs_idx
                ,I_rt_idx    => R_rt_idx
                ,I_rd_idx    => R_rd_idx
                ,I_rd_value  => R_rd_value

                ,O_rs_value  => R_rs_value
                ,O_rt_value  => R_rt_value
        );

---------------------------------------------------------------------
-- Random Access Memory
---------------------------------------------------------------------

        -- Instantiate and connect the internal RAM
        ram: entity work.ram(logic)
        port map (
		 I_clk		    => I_clk
		,I_ram_address      => R_ram_address
		,I_ram_write_enable => R_ram_write_enable
		,I_ram_data_write   => R_ram_data_write

		,O_ram_data_read    => R_ram_data_read
        );
end;

