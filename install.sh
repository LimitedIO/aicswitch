#!/bin/sh
# aicswitch installer
#   curl -fsSL https://limitedio.github.io/aicswitch/install.sh | sudo sh
#   ... | sudo sh -s -- --driver      also build + install the WiFi/BT driver
#   ... | sudo sh -s -- --uninstall   remove aicswitch (see also uninstall.sh)
set -eu

REPO=LimitedIO/aicswitch
SITE=https://limitedio.github.io/aicswitch
DRIVER_REPO=https://github.com/shenmintao/aic8800d80.git
DRIVER_REF=f9ab41822373efe70649d011edb587d1170364e7
BIN=/usr/local/sbin/aicswitch
RULE=/etc/udev/rules.d/99-aicswitch.rules
MODCONF=/etc/modules-load.d/aicswitch.conf

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
sub() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

fetch() {
	if command -v curl >/dev/null; then curl -fL --progress-bar "$1" -o "$2"
	elif command -v wget >/dev/null; then wget -q --show-progress -O "$2" "$1"
	else die "need curl or wget"; fi
}

uninstall() {
	say "Removing aicswitch"
	for f in "$BIN" "$RULE" "$MODCONF"; do
		if [ -e "$f" ]; then rm -f "$f"; sub "removed $f"; else sub "not present: $f"; fi
	done
	if command -v udevadm >/dev/null; then udevadm control --reload; sub "reloaded udev rules"; fi
	say "aicswitch removed. The WiFi/BT driver (if installed) was left alone;"
	sub "remove it with: dkms remove aic8800d80/1.0.0 --all  (check 'dkms status')"
}

install_tool() {
	case "$(uname -m)" in
	x86_64 | amd64) arch=x86_64 ;;
	i?86) arch=i686 ;;
	aarch64 | arm64) arch=aarch64 ;;
	armv7* | armv8l) arch=armv7 ;;
	armv6*) arch=armv6 ;;
	riscv64) arch=riscv64 ;;
	ppc64le) arch=ppc64le ;;
	*) die "unsupported architecture: $(uname -m)" ;;
	esac
	url="https://github.com/$REPO/releases/latest/download/aicswitch-linux-$arch.tar.gz"
	say "Step 1/4: download aicswitch"
	sub "architecture: $arch"
	sub "from: $url"
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	fetch "$url" "$tmp/a.tgz"
	tar -xzf "$tmp/a.tgz" -C "$tmp"

	say "Step 2/4: install the program"
	install -Dm755 "$tmp/aicswitch" "$BIN"
	sub "wrote $BIN"

	say "Step 3/4: install the udev rule (runs aicswitch when the dongle is plugged in)"
	sed "s|@SBINDIR@|${BIN%/*}|" "$tmp/99-aicswitch.rules.in" >"$RULE"
	chmod 644 "$RULE"
	sub "wrote $RULE"

	say "Step 4/4: make it survive reboots"
	if [ -d /etc/modules-load.d ]; then
		printf '# aicswitch: load SCSI generic at boot so udev can see the dongle\nsg\n' >"$MODCONF"
		sub "wrote $MODCONF (loads the 'sg' module at every boot)"
	else
		warn "/etc/modules-load.d missing; make sure the 'sg' module loads at boot"
	fi
	modprobe sg 2>/dev/null && sub "loaded 'sg' module now" || sub "'sg' already built in or unavailable"
	if command -v udevadm >/dev/null; then
		udevadm control --reload
		sub "reloaded udev rules"
		udevadm trigger --subsystem-match=scsi_generic --action=add || true
		sub "re-ran plug-in event for attached devices (switches a connected dongle now)"
	else
		warn "udevadm not found; reboot or replug for the rule to apply"
	fi
	say "Installed $("$BIN" --version)"
}

install_driver() {
	command -v git >/dev/null || die "the driver needs git (install it and re-run)"
	src=/usr/src/aic8800d80-installer
	say "Driver: fetch AIC8800 WiFi/BT driver"
	sub "from: $DRIVER_REPO @ $DRIVER_REF"
	sub "into: $src"
	rm -rf "$src"
	git clone -q "$DRIVER_REPO" "$src"
	git -C "$src" -c advice.detachedHead=false checkout -q "$DRIVER_REF"
	say "Driver: build + install with DKMS (this takes a minute; its own output follows)"
	if (: </dev/tty) 2>/dev/null; then (cd "$src" && bash ./install.sh </dev/tty)
	else (cd "$src" && bash ./install.sh </dev/null); fi
	if command -v mokutil >/dev/null && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
		warn "Secure Boot is ON: unsigned DKMS modules will not load after reboot unless signed/enrolled."
	fi
}

[ "$(uname -s)" = Linux ] || die "aicswitch only supports Linux"

driver=0
for a in "$@"; do
	case "$a" in
	--driver) driver=1 ;;
	--uninstall) [ "$(id -u)" = 0 ] || die "run as root"; uninstall; exit 0 ;;
	-h | --help) echo "usage: install.sh [--driver | --uninstall]"; exit 0 ;;
	*) die "unknown option: $a" ;;
	esac
done

[ "$(id -u)" = 0 ] || die "run as root (pipe into 'sudo sh')"
say "aicswitch installer (source: https://github.com/$REPO)"
sub "files touched: $BIN, $RULE, $MODCONF"
install_tool
if [ "$driver" = 1 ]; then install_driver; fi
if [ "$driver" = 0 ] && ! grep -q '^aic8800_fdrv ' /proc/modules 2>/dev/null; then
	warn "No AIC8800 driver loaded. Re-run with: curl -fsSL $SITE/install.sh | sudo sh -s -- --driver"
fi
say "Done. Unplug and replug your dongle (or just reboot)."
sub "uninstall any time: curl -fsSL $SITE/uninstall.sh | sudo sh"
