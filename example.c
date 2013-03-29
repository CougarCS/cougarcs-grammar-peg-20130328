#include<string.h>
int main(int argc, char** argv) {
	if ( argc >= 3
			&& strcmp(argv[1], argv[2]) == 0 ) {
		return 1;
	}
	return 0;
}
