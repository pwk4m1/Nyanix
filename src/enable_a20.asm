;
; Copyright (c) 2019, k4m1 <k4m1@protonmail.com>
; All rights reserved. Read /LICENSE for full license agreement.
; 
; This file contains code responsible of enabling A20, and
; then proceeding to call loader_main
;

loader_entry:
	pop	dx
	mov	sp, 0x9c00
	mov	bp, sp

	mov	byte [boot_device], dl

	; init heap for malloc/free
	call 	mm_heap_init

	call	enable_a20_with_bios
	test	eax, eax
	jz	.a20_is_on

	call	enable_a20_with_kbdctl
	test	eax, eax
	jz	.a20_is_on

	call	enable_a20_with_fast_92
	call	check_a20
	test	eax, eax
	jz	.a20_is_on

	call	enable_a20_ioee
	test	eax, eax
	jz	.a20_is_on

	mov	esi, msg_a20_fail
	call	panic

.a20_is_on:
	mov	si, msg_a20_is_on
	call	write_serial

	call	loader_main

	cli
	hlt

; =================================================================== ;
; Messages to output                                                  ;
; =================================================================== ;
msg_a20_fail:
	db	"FAILED TO ENABLE A20!", 0

msg_a20_is_on:
	db	"A20 enabled.", 0x0A, 0x0D, 0

; =================================================================== ;
; Code related to a20 gate.                                           ;
; =================================================================== ;

enable_a20_with_fast_92:
	in	al, 0x92
	test	al, 2
	jnz	.no_92
	or	al, 2
	out	0x92, al
.no_92:
	ret

kbd_wait_for_clear:
	in	al, 0x64
	test	al, 2
	jnz	kbd_wait_for_clear
	ret

enable_a20_ioee:
	push	bp
	mov	bp, sp
	in	al, 0xee
	call	check_a20
	mov	sp, bp
	pop	bp
	ret

enable_a20_with_kbdctl:
	push	bp
	mov	bp, sp

	cli
	call	kbd_wait_for_clear

	; Send write command
	mov	al, 0xd1
	out	0x64, al

	; Wait for kbdctl
	call	kbd_wait_for_clear

	; set A20 on
	mov	al, 0xdf
	out	0x60, al

	; wait for kbdctl
	call	kbd_wait_for_clear

	; Check if we succeeded or not
	call	check_a20

	sti
	mov	sp, bp
	pop	bp
	ret

check_a20:
	; Check if we enabled a20 or not
	mov	eax, 0x012345
	mov	ebx, 0x112345
	mov	[eax], eax
	mov	[ebx], ebx
	mov	eax, dword [eax]
	mov	ebx, dword [ebx]
	cmp	eax, ebx
	jne	.a20_on
	mov	eax, 1
	ret
.a20_on:
	xor	eax, eax
	ret

enable_a20_with_bios:
	; check if BIOS support is present
	mov	ax, 0x2403
	int	0x15
	jb	.fail
	test	ah, ah
	jz	.fail

	; It is? get a20 status
	mov	ax, 0x2402
	int	0x15
	jb	.fail
	test	ah, ah
	jz	.fail

	; See if a20 is already activated
	cmp	al, 1
	jz	.a20_is_on

	mov	ax, 0x2401
	int	0x15
	jb	.fail
	test	ah, ah
	jz	.fail

.a20_is_on:
	mov	eax, 0
	ret

.fail:
	mov	eax, 1
	ret

; Reserved single byte to store boot-device ID
boot_device:
	db	0

%include "src/consoles.asm"
%include "src/loader_main.asm"

