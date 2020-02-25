
; Copyright (C) 2019, k4m1  <k4m1@protonmail.com>
; All rights reserved. See /LICENSE for full license agreement.

; This code is responsible of doing bios call, and then returning
; back to unreal mode, assuming BIOS threw us back to real-mode
;

do_bios_call_13h:
	int	0x13
	cli
	push	ds
	lgdt	[gdt]
	mov	eax, cr0
	or	al, 1
	mov	cr0, eax
	jmp	.pm
.pm:
	mov	bx, 0x08
	mov	ds, bx
	and	al, 0xFE
	mov	cr0, eax
	pop	ds
	sti
	ret

%include "src/gdt.asm"

