#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <linux/input.h>

#define TestBit(bit, array) (array[(bit) / 8] & (1 << ((bit) % 8)))

int find_keyboard() {
	int i, j;
        int fd;
        char filename[32];
        char key_bitmask[(KEY_MAX + 7) / 8];

        for (i=0; i<32; i++) {
                snprintf(filename,sizeof(filename), "/dev/input/event%d", i);

                fd = open(filename, O_RDWR);
                ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(key_bitmask)), key_bitmask);

		for (j = 0; j < BTN_MISC; j++) {
			if (TestBit(j, key_bitmask))
				break;
		}

                if (j < BTN_MISC) {
                        return fd;
                }
		close (fd);
        }
        return 0;
}

int main(int argc, char** argv) {
	int fd;
	int key;
	struct input_event event;

	if (argc == 2) {
		key = atoi(argv[1]);
	} else {
		return 1;
	}

	fd = find_keyboard();

	if (!fd) {
		return 2;
	}

	event.type = EV_KEY;
	event.code = key;
	event.value = 1;
	write(fd, &event, sizeof event);

	event.type = EV_KEY;
	event.code = key;
	event.value = 0;
	write(fd, &event, sizeof event);
	
	return 0;
}

