.global _start
.global header
.type _start, @function

.extern main
.extern __kernel_size

.section .kern_head
header:
	.ascii "nyan"
	.long __kernel_size

.section .text
.type _start, @function
_start:
	movl 	$0x7c00, %esp
	movl 	%esp, %ebp
	
	call 	main

	cli
	hlt


