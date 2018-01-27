# Dwarf - A minimalist 16-bit RISC CPU

## Overview

The main purpose of this project is to explore CPU design and provide a minimalist implementation.
It is utterly useless for anything but studying/teaching the structure and  implementation of a simple
processor.

It is loosely based on the MIPS I(tm) architecture and used the Plasma CPU developed by Steve Rhoads
as a source of inspiration.

The CPU proper implementation is less than 1000 lines of VHDL code, including comments, runs at the
magnificent speed of 1 Hz (yes, ONE Hertz) and has an incredible memory size of 1024 16-bit words.

## Motivation

I am not a hardware designer, I am a software developer (that is the reason why the HW design probably
will look silly to profesional HW developers). Yet I always felt the urge to build my own CPU.
So after spending quite some time studying digital hardware design and HDL as well as CPU design and
working every now and then for a few hours on this project, I finally...
...got tired of it, brought it to a raw but functional state and threw it into the public.

Maybe it will be useful to someone.

But what actually motivated me to do this is:

1.) Fun
2.) Learning
3.) The "because I can" attitude
4.) Programmer folklore - as found here for instance:

[The story of Mel](http://www.pbm.com/~lindahl/mel.html)

[Real Programmers write in Fortran.](http://www.pbm.com/~lindahl/real.programmers.html)

"...in this decadent era of Lite beer, hand calculators and "user-friendly" software but back in the Good Old Days,
when the term "software" sounded funny and Real Computers were made out of drums and vacuum tubes,
Real Programmers wrote in machine code. Not Fortran. Not RATFOR. Not, even, assembly language. Machine Code.
Raw, unadorned, inscrutable hexadecimal numbers. Directly."

"Lest a whole new generation of programmers grow up in ignorance of this glorious past, I feel duty-bound to
describe, as best I can through the generation gap, how a Real Programmer wrote code."

So...
If you can't do it in C, do it in assembly language. If you can't do it in assembly language, do it in VHDL. If you can't
do it in VHDL it isn't worth doing. (Paraphrased)


## General Characteristics

+ RISC (MISC probably more appropriate). HAZARD / High "RISC" actually if planning to use it for anything meaningful :)
+ Load-store architecture
+ 16-bit fixed instruction length
+ Von Neumann architecture
+ General-purpose register machine
+ Delay slots (arise from previous presence of a pipeline that was removed)
+ Addressing modes: Immediate, register, absolute memory
+ Alligned 16 bit word addressing only
+ Simple scalar architecture - straight forward sequential fetch-decode-execute operation

No bells and whistles and no fancy stuff

Therefore:

+ **No** status register
+ **No** notion of a stack
+ **No** notion of signed numbers. Everything is unsigned
+ **No** interrupts
+ **No** peripheral hardware like timers, UARTs, IO ports, etc.

Well, actually the glue that binds it to the Development board also provides outputs to four seven-segment displays
and eight LEDs

Further on...
Additional non-features:

+ **No** superscalar features
+ **No** cache
+ **No** pipeline
+ **No** branch prediction
+ **No** out of order execution
+ **No** speculative execution
+ **No** MMU

And hence **No** vulnerability to [Meltdown and Spectre](https://meltdownattack.com/).

At least one quality to be attributed to this CPU :)

## Demostration Video

Take a look at **dwarf.mov** to see the CPU in action. It executes the **firmware.s** demo program.
The digits on the seven-segment display show the instruction counter. The dots on the seven-segment display show the
CPU clock. The LEDs display the output of the demo program.


## Documentation

Check **documentation.txt** for a rought description of the CPU, the instruction set and the tools
involved in implementing the CPU on real hardware (an FPGA in this case) as well as developing software for it.
There is also a raw schematic diagram in **dwarf.dia**


## Future Plans / TODOs

Probably nothing will happen from my side in the foreseeable future due to lack of time and lost interest in the topic.
You are highly welcome to take the project further. I will provide assistance to the best of my possibilities.

Suggestions for further development:

+ Extend the CPU to 32 bit
+ Revisit the instruction set and make it more useful (currently it's quite randomly put together)
+ Add usefull addressing modes
+ Make it multi core
+ External RAM interface
+ Interrupts
+ I/O ports
+ Timers

Turn it into a SoC with

+ Keyboard interface
+ Video
+ Audio
+ Network
+ UART
+ Mouse

Add all the other bells and whistles it currently misses.
Use your imagination.

## Software / Hardware

Developed under GNU/Linux - [Ubuntu](https://www.ubuntu.com/) distribution

+ Uses the [Xilinx  ISE WebPACK Design Software v 14.7](https://www.xilinx.com/products/design-tools/ise-design-suite/ise-webpack.html) for synthesis
+ Uses the [xc3sprog suite of utilities](http://xc3sprog.sourceforge.net/) for downloading the FPGA configuration bitstream
+ Tested on [The Spartan®-3 Starter Board](https://store.digilentinc.com/spartan-3-board-retired/)

## References

Recommended reading

[From NAND to Tetris](http://www.nand2tetris.org/)

[FPGA Prototyping by VHDL Examples: Xilinx Spartan-3 Version](https://www.amazon.com/FPGA-Prototyping-VHDL-Examples-Spartan-3/dp/0470185317)

## Homepage And Source Code Repository

https://github.com/coronensis/dwarf

## Contact
Helmut Sipos <helmut.sipos@gmail.com>
