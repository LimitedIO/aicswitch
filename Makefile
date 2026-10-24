VERSION ?= $(or $(shell git describe --tags --always 2>/dev/null | sed "s/^v//"),dev)
PREFIX  ?= /usr/local
SBINDIR ?= $(PREFIX)/sbin
UDEVDIR ?= /etc/udev/rules.d
CFLAGS  ?= -O2 -Wall -Wextra
CFLAGS  += -DVERSION=\"$(VERSION)\"

all: aicswitch 99-aicswitch.rules

aicswitch: src/aicswitch.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

99-aicswitch.rules: 99-aicswitch.rules.in
	sed 's|@SBINDIR@|$(SBINDIR)|' $< > $@

install: all
	install -Dm755 aicswitch $(DESTDIR)$(SBINDIR)/aicswitch
	install -Dm644 99-aicswitch.rules $(DESTDIR)$(UDEVDIR)/99-aicswitch.rules
	-[ -z "$(DESTDIR)" ] && udevadm control --reload

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/aicswitch $(DESTDIR)$(UDEVDIR)/99-aicswitch.rules

clean:
	rm -f aicswitch 99-aicswitch.rules

.PHONY: all install uninstall clean
