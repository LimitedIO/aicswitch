#!/bin/sh
# aicswitch uninstaller
#   curl -fsSL https://limitedio.github.io/aicswitch/uninstall.sh | sudo sh
#   ... | sudo sh -s -- --driver   also remove the DKMS WiFi/BT driver
set -eu

BIN=/usr/local/sbin/aicswitch
RULE=/etc/udev/rules.d/99-aicswitch.rules
MODCONF=/etc/modules-load.d/aicswitch.conf
DRIVER_SRC=/usr/src/aic8800d80-installer

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
sub() { printf '    %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

driver=0
for a in "$@"; do
	case "$a" in
	--driver) driver=1 ;;
	-h | --help) echo "usage: uninstall.sh [--driver]"; exit 0 ;;
	*) die "unknown option: $a" ;;
	esac
done
[ "$(id -u)" = 0 ] || die "run as root (pipe into 'sudo sh')"

say "Removing aicswitch files"
for f in "$BIN" "$RULE" "$MODCONF"; do
	if [ -e "$f" ]; then rm -f "$f"; sub "removed $f"; else sub "not present: $f"; fi
done
if command -v udevadm >/dev/null; then udevadm control --reload; sub "reloaded udev rules"; fi

if [ "$driver" = 1 ]; then
	say "Removing AIC8800 DKMS driver"
	if command -v dkms >/dev/null; then
		dkms status 2>/dev/null | grep -i aic8800 | sed 's|[,:].*||' | sort -u | while read -r mod; do
			sub "dkms remove $mod --all"
			dkms remove "$mod" --all || true
		done
	else
		sub "dkms not installed; nothing to remove"
	fi
	rm -f /etc/modprobe.d/aic8800*.conf /etc/udev/rules.d/aic.rules 2>/dev/null || true
	if [ -d "$DRIVER_SRC" ]; then rm -rf "$DRIVER_SRC"; sub "removed $DRIVER_SRC"; fi
	sub "if the module is still loaded, it goes away on next reboot"
else
	sub "WiFi/BT driver left in place (add --driver to remove it too)"
fi
say "Done."
