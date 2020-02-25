;
; Copyright (c) 2019, k4m1 <k4m1@protonmail.com>
; All rights reserved. See /LICENSE for full license agreement.
;
;
; This file contains MBR. We'll load 2nd stage loader & initialize serial
; port in here.
;

org	0x7c00
bits	16

%ifndef SECTOR_CNT
	%define SECTOR_CNT 2
%endif

; Clear CS, jump to mbr_start
jmp	0x0000:mbr_start

mbr_start:
	cli
	cld

	; Clear rest of segments
	xor	ax, ax
	mov	ds, ax
	mov	ss, ax
	mov	es, ax

	mov	sp, 0x7c00
	mov	bp, sp

	sti

	; Store boot device
	push	dx

	; swap to unreal mode
	cli
	push	ds
	lgdt	[gdt]
	mov	eax, cr0
	or	al, 1
	mov	cr0, eax
	jmp	.pmode
.pmode:
	mov	bx, 0x08
	mov	ds, bx
	and	al, 0xFE
	mov	cr0, eax
	pop	ds
	sti

	; Clear screen
	xor	ax, ax
	mov	al, 0x03
	int	0x10

	; Initialize serial port
	mov	dx, 0x3F9
	xor	al, al
	out	dx, al

	add	dx, 2
	mov	al, 0x80
	out	dx, al

	sub	dx, 3
	xor	al, al
	out	dx, al

	inc	dx
	out	dx, al

	add	dx, 2
	add	al, 3
	out	dx, al

	dec	dx
	mov	al, 0xC7
	out	dx, al

	add	dx, 2
	mov	al, 0x0B
	out	dx, al

load_second_stage:
	pop	dx
	push	dx
	mov	bx, loader_entry
	xor	ch, ch
	mov	cl, 0x02
	xor	dh, dh
	mov	byte [.sectors_to_load], SECTOR_CNT

	.read_start:
		mov	di, 5
	.read:
		mov	ah, 0x02
		mov	al, byte [.sectors_to_load]
		int	0x13
		jc	.retry
		cmp	al, byte [.sectors_to_load]
		je	.done
		sub	byte [.sectors_to_load], al
		mov	cl, 0x01
		xor	dh, 1
		jnz	.read_start
		inc	ch
		jmp	.read_start
	.retry:
		; disk read failed, reset disk
		xor	ah, ah
		int	0x13
		dec	di
		jnz	.read
		mov	si, .msg_diskread_fail
		jmp	.fail
	.done:
		jmp	loader_entry
	.fail:
		lodsb
		or	al, al
		mov	ah, 0x0E
		int	0x10
		test	al, al
		jnz	.fail
	.hang:
		cli
		hlt
		jmp	.hang

.sectors_to_load:
	db	0
.msg_diskread_fail:
	db	"HALT: Failed to read boot disk", 0x0A, 0x0D, 0

%include "src/gdt.asm"

; Padding & Signature
times	510-($-$$) db 0
dw	0xAA55

%include "src/enable_a20.asm"

