# Nyanix
Simple bootloader project. Aiming for clean code.

Usage:
	At very beginning of your kernel, there *must* be header as defined
	in KERNEL_HEADER.txt file. Very beginning as in within first 5 kb after
	bootloader. This header tells the bootloader how
	large your kernel and/or OS is. Refer to test_kernel/test.asm to
	see how-to set up the header.

	Kernel may be in any format, but the signature must be within
	said limit.

	After the header, the bootloader assumes to be kernel entry point.
	If you wish to have some sort of data-section there, your kernel
	must be formated in following way:

		section .text
		kernel_header
		jump to code entry
		section .whatever
		...

That's all, I guess. Do enjoy.


Oh one more thing, kernel is loaded to address: 0x000100ee 

