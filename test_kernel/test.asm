

header:
	db "nyan"
	dd 0x00000001

	mov	dx, 0x3f8
	mov	al, 'H'
	out	dx, al

	mov	al, 'E'
	out	dx, al

	mov	al, 'L'
	out	dx, al
	out	dx, al

	mov	al, '0'
	out	dx, al

	
	cli
	hlt
	jmp 	$ - 2

times 2048 db 0x41


