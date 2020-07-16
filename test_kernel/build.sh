#!/bin/sh
i686-elf-gcc -T linker.ld -nostdlib start.s kernel.c -o test
