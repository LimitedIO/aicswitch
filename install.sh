#!/bin/sh
# aicswitch installer
#   curl -fsSL https://limitedio.github.io/aicswitch/install.sh | sudo sh
#   ... | sudo sh -s -- --driver      also build + install the WiFi/BT driver
#   ... | sudo sh -s -- --uninstall   remove aicswitch
set -eu

REPO=LimitedIO/aicswitch
DRIVER_REPO=https://github.com/shenmintao/aic8800d80.git
DRIVER_REF=f9ab41822373efe70649d011edb587d1170364e7
BIN=/usr/local/sbin/aicswitch
RULE=/etc/udev/rules.d/99-aicswitch.rules

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

fetch() {
	if command -v curl >/dev/null; then curl -fsSL "$1" -o "$2"
	elif command -v wget >/dev/null; then wget -qO "$2" "$1"
	else die "need curl or wget"; fi
}

uninstall() {
	rm -f "$BIN" "$RULE"
	if command -v udevadm >/dev/null; then udevadm control --reload; fi
	say "aicswitch removed"
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
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	say "Downloading aicswitch ($arch)"
	fetch "https://github.com/$REPO/releases/latest/download/aicswitch-linux-$arch.tar.gz" "$tmp/a.tgz"
	tar -xzf "$tmp/a.tgz" -C "$tmp"
	install -Dm755 "$tmp/aicswitch" "$BIN"
	sed "s|@SBINDIR@|${BIN%/*}|" "$tmp/99-aicswitch.rules.in" >"$RULE"
	chmod 644 "$RULE"
	if command -v udevadm >/dev/null; then
		udevadm control --reload
		udevadm trigger --subsystem-match=scsi_generic --action=add || true
	fi
	say "Installed $("$BIN" --version) to $BIN"
}

install_driver() {
	command -v git >/dev/null || die "the driver needs git (install it and re-run)"
	src=/usr/src/aic8800d80-installer
	say "Fetching AIC8800 driver ($DRIVER_REPO)"
	rm -rf "$src"
	git clone -q "$DRIVER_REPO" "$src"
	git -C "$src" -c advice.detachedHead=false checkout -q "$DRIVER_REF"
	say "Building driver with DKMS (this takes a minute)"
	if (: </dev/tty) 2>/dev/null; then (cd "$src" && bash ./install.sh </dev/tty)
	else (cd "$src" && bash ./install.sh </dev/null); fi
}

[ "$(uname -s)" = Linux ] || die "aicswitch only supports Linux"

driver=0
for a in "$@"; do
	case "$a" in
	--driver) driver=1 ;;
	--uninstall) uninstall; exit 0 ;;
	-h | --help) echo "usage: install.sh [--driver | --uninstall]"; exit 0 ;;
	*) die "unknown option: $a" ;;
	esac
done

[ "$(id -u)" = 0 ] || die "run as root (pipe into 'sudo sh')"
install_tool
if [ "$driver" = 1 ]; then install_driver; fi
if [ "$driver" = 0 ] && ! grep -q '^aic8800_fdrv ' /proc/modules 2>/dev/null; then
	say "No AIC8800 driver loaded. Re-run with: sh -s -- --driver"
fi
say "Done. Unplug and replug your dongle."
