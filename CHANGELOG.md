# Changelog

## 1.0.1 - 2026-10-24

- Fix missing armv6 `.deb`: the `armhf` package is now built from the armv6 binary, so it runs on every ARM board, including Raspberry Pi Zero/1.

## 1.0.0 - 2026-10-24

- Initial release: switch AIC8800D80 `1111:1111` dongles out of driver-CD mode.
- udev rule for automatic switching on plug-in.
- Static binaries plus deb/rpm/apk/Arch packages for 7 architectures.
- One-line installer with optional DKMS driver install.
