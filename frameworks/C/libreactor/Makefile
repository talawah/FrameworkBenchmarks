PROG   = libreactor
OBJS   = src/setup.o src/main.o
CFLAGS = -std=gnu11 -Wall -O3 -march=x86-64 -mtune=generic -flto -fuse-linker-plugin -Isrc
LDADD  = -lreactor -ldynamic -lclo

$(PROG): $(OBJS)
	$(CC) -o $@ $^ $(CFLAGS) $(LDADD)

clean:
	rm -f $(PROG) $(OBJS)
