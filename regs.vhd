--
-- Dwarf - A minimalist 16-bit RISC CPU
--
-- cpu.vhd: Implements the register bank
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
library UNISIM;
use UNISIM.vcomponents.all;
use work.dwarf.all;

entity regs is
	port (
		I_clk	    : in std_logic;
		I_cpu_pause : in std_logic;
		I_rs_idx    : in std_logic_vector(3 downto 0);
		I_rt_idx    : in std_logic_vector(3 downto 0);
		I_rd_idx    : in std_logic_vector(3 downto 0);
		I_rd_value  : in std_logic_vector(15 downto 0);

		O_rs_value  : out std_logic_vector(15 downto 0);
		O_rt_value  : out std_logic_vector(15 downto 0)
	);
end;

architecture logic of regs is
	signal R_reg_write_enable : std_logic;
begin

	R_reg_write_enable <= '1' when ((I_rd_idx /= "0000") and (I_cpu_pause = '0')) else '0';

	-- RAM16X1D: 16 x 1 positive edge write, asynchronous read dual-port
	-- distributed RAM for all Xilinx FPGAs

	-- 16 registers
	reg_loop: for i in 0 to 15 generate
	begin
		--Read port A
		reg_bit1a : RAM16X1D
		port map (
			 WCLK  => I_clk,              -- Port A write clock input
			 WE    => R_reg_write_enable,			  -- Port A write enable input
			 A0    => I_rd_idx(0),      -- Port A address[0] input bit
			 A1    => I_rd_idx(1),      -- Port A address[1] input bit
			 A2    => I_rd_idx(2),      -- Port A address[2] input bit
			 A3    => I_rd_idx(3),      -- Port A address[3] input bit
			 D     => I_rd_value(i),      -- Port A 1-bit data input
			 DPRA0 => I_rs_idx(0),      -- Port B address[0] input bit
			 DPRA1 => I_rs_idx(1),      -- Port B address[1] input bit
			 DPRA2 => I_rs_idx(2),      -- Port B address[2] input bit
			 DPRA3 => I_rs_idx(3),      -- Port B address[3] input bit
			 DPO   => O_rs_value(i), -- Port B 1-bit data output
			 SPO   => open                -- Port A 1-bit data output
		);

		--Read port B
		reg_bit2a : RAM16X1D
		port map (
			 WCLK  => I_clk,              -- Port A write clock input
			 WE    => R_reg_write_enable,			  -- Port A write enable input
			 A0    => I_rd_idx(0),      -- Port A address[0] input bit
			 A1    => I_rd_idx(1),      -- Port A address[1] input bit
			 A2    => I_rd_idx(2),      -- Port A address[2] input bit
			 A3    => I_rd_idx(3),      -- Port A address[3] input bit
			 D     => I_rd_value(i),      -- Port A 1-bit data input
			 DPRA0 => I_rt_idx(0),      -- Port B address[0] input bit
			 DPRA1 => I_rt_idx(1),      -- Port B address[1] input bit
			 DPRA2 => I_rt_idx(2),      -- Port B address[2] input bit
			 DPRA3 => I_rt_idx(3),      -- Port B address[3] input bit
			 DPO   => O_rt_value(i), -- Port B 1-bit data output
			 SPO   => open                -- Port A 1-bit data output
		);
	end generate;
end;

