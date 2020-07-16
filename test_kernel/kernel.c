#define HANG() asm("hlt")

void
output(short port, unsigned char byte)
{
	asm volatile("outb %1,%0"::"dN"(port), "a"(byte));
}

void
ser_print(char *msg)
{
	int i;
	
	for (i = 0; ; i++) {
		if (!msg[i]) {
			break;
		}
		output(0x03f8, msg[i]);
	}
}

void
main(void)
{
	ser_print("hello from C kernel\n\0");

	do { HANG(); } while (1);
}



