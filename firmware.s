;
; Dwarf - A minimalist 16-bit RISC CPU

; firmware.s: Demo application
;

.LEDADDR		0x8000

.BIT0			0

@0x0
	nop

	ldu	r1,	LEDADDR
	ori	r1,	LEDADDR

	ldu	r2,	0xAA00
	ori	r2,	0xAA

	ori	r5,	0x01

	ori	r11,	0x0F
	ori	r12,	0xF0

	ori	r6,	0x55
main:
	brl	writeled
	nop
	ror	r2,	r5,	r2
	sks	r2,	BIT0
	nop
	mov	r11,	r6
	skc	r2,	BIT0
	nop
	mov	r12,	r6
	brl	writeled
	nop

	brl	main
	nop

@0x7FA
writeled:
	wrm	r1,	r6
	brr	r15
	nop




