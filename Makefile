#
# Dwarf - A minimalist 16-bit RISC CPU
#
# Makefile: MAKE(1) control file with targets for building the different parts
#                   of the SoC demonstrating the Dwarf CPU
#
# Copyright (c) 2017, Helmut Sipos <helmut.sipos@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

all: clean firmware bitstream

firmware: asm.c mkramimg.c
	gcc -Wall -Werror -g -o asm asm.c
	gcc -Wall -Werror -g -o mkramimg mkramimg.c
	./asm -l -f firmware.asm >firmware.lst
	./asm -f firmware.asm >firmware.txt
	./mkramimg ram.vhd firmware.txt

bitstream:
	./synthesize

install:
	xc3sprog -c jtaghs1 -v -p 0 spartan3board.bit

clean:
	rm -rf _ngo dwarf.gise spartan3board.bgn spartan3board.bit spartan3board_bitgen.xwbt \
	       	spartan3board.bld spartan3board.cmd_log spartan3board.drc spartan3board_guide.ncd \
		spartan3board.lso spartan3board_map.map spartan3board_map.mrp spartan3board_map.ncd \
		spartan3board_map.ngm spartan3board_map.xrpt spartan3board.ncd spartan3board.ngc \
		spartan3board.ngd spartan3board_ngdbuild.xrpt spartan3board.ngr spartan3board.pad \
		spartan3board_pad.csv spartan3board_pad.txt spartan3board.par spartan3board_par.xrpt \
		spartan3board.pcf spartan3board.prj spartan3board.ptwx spartan3board.stx \
		spartan3board_summary.xml spartan3board.syr spartan3board.twr spartan3board.twx \
	       	spartan3board.unroutes spartan3board_usage.xml spartan3board.ut spartan3board.xpi \
		spartan3board.xst spartan3board_xst.xrpt dwarf.xise usage_statistics_webtalk.html \
		spartan3board_vhdl.prj webtalk.log webtalk_pn.xml xlnx_auto_0_xdb _xmsgs xst .Xil \
		cpu_tb_beh.prj cpu_tb_isim_beh.exe cpu_tb_isim_beh.wdb cpu_tb_stx_beh.prj fuse.log \
	       	fuse.xmsgs fuseRelaunch.cmd isim.cmd isim.log spartan3board_envsettings.html xilinxsim.ini \
		isim iseconfig spartan3board_summary.html asm mkramimg firmware.txt firmware.lst

