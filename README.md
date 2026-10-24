<p align="center"><img src="media/logo.svg" width="112" alt="aicswitch logo"></p>
<h1 align="center">aicswitch</h1>
<p align="center">Make AIC8800 WiFi 6 / Bluetooth USB dongles work on Linux.</p>
<p align="center">
  <a href="https://github.com/LimitedIO/aicswitch/releases/latest"><img src="https://img.shields.io/github/v/release/LimitedIO/aicswitch" alt="release"></a>
  <a href="https://github.com/LimitedIO/aicswitch/actions/workflows/ci.yml"><img src="https://github.com/LimitedIO/aicswitch/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/LimitedIO/aicswitch" alt="license"></a>
</p>

Cheap WiFi 6 USB dongles built on the **AICSemi AIC8800D80** chip show up on Linux as a tiny
USB disk holding a Windows installer, instead of a network card:

```
$ lsusb
Bus 001 Device 120: ID 1111:1111 Pandora International Ltd. 88M80
```

**aicswitch** sends the dongle the same vendor command the Windows tool uses, so it turns into a
real WiFi + Bluetooth adapter. A udev rule does this automatically every time you plug it in.

## Symptoms

Your dongle needs aicswitch if any of these apply:

- `lsusb` shows `ID 1111:1111 Pandora International Ltd. 88M80`
- A small USB drive called **"Wifi Driver"** containing `Wifi6_install.exe` appears when you plug it in
- `dmesg` shows `scsi ... Direct-Access LGX WIFI6` and `usb-storage`, but no network interface
- `eject` and `usb_modeswitch` don't make the WiFi adapter appear

Tested with the **AICSemi AIC8800D80** chip (WiFi 6 + Bluetooth 5) sold under brands like LGX and in no-name "WiFi 6 USB adapter" sticks.

## Install

Switcher plus the WiFi/Bluetooth driver (recommended):

```sh
curl -fsSL https://limitedio.github.io/aicswitch/install.sh | sudo sh -s -- --driver
```

Only the switcher, if you already have an AIC8800 driver:

```sh
curl -fsSL https://limitedio.github.io/aicswitch/install.sh | sudo sh
```

Then unplug the dongle and plug it back in. To remove aicswitch, run the same command with `-s -- --uninstall`.

### Packages

Every [release](https://github.com/LimitedIO/aicswitch/releases/latest) ships static binaries and
packages for **x86_64, i686, aarch64, armv7, armv6, riscv64 and ppc64le**:

| Distro | File | Install |
|---|---|---|
| Debian, Ubuntu, Mint, Raspberry Pi OS | `.deb` | `sudo apt install ./aicswitch_*.deb` |
| Fedora, RHEL, openSUSE | `.rpm` | `sudo dnf install ./aicswitch-*.rpm` |
| Arch, Manjaro | `.pkg.tar.zst` | `sudo pacman -U aicswitch-*.pkg.tar.zst` |
| Alpine | `.apk` | `sudo apk add --allow-untrusted aicswitch_*.apk` |
| Anything else | `aicswitch-linux-<arch>.tar.gz` | static binary, no dependencies |

### From source

```sh
make
sudo make install        # PREFIX=/usr/local, UDEVDIR=/etc/udev/rules.d
```

You only need a C compiler and libc.

## Usage

You normally never run it yourself, because udev runs it for you. To run it by hand:

```sh
sudo aicswitch            # find and switch every attached AIC dongle
sudo aicswitch /dev/sg1   # switch a specific SCSI generic device
aicswitch --version
```

After switching, the dongle shows up as `a69c:8d80 aicsemi AIC Wlan`, and as `a69c:8d81 AICSemi AIC 8800D80`
once the driver has loaded its firmware.

## How it works

1. The dongle starts in "driver CD" mode as USB mass storage (vendor `AIC`, model `WIFI6`).
2. udev matches the `1111:1111` SCSI generic device and runs `aicswitch /dev/sgN`.
3. aicswitch sends the 16-byte vendor SCSI command `FD 00 00 00 00 00 00 00 00 00 00 00 00 00 00 F2` with `SG_IO`.
   This command was found by disassembling `Usb_Driver.dll` from the Windows installer stored on the dongle.
   A standard SCSI eject does **not** switch these units, which is why `usb_modeswitch`/`eject` rules don't help.
4. The dongle reconnects as `a69c:8d80`, and the AIC8800 driver uploads firmware and creates a `wlx…` interface plus an `hci` Bluetooth controller.

## Driver

aicswitch only handles the mode switch. The WiFi/Bluetooth kernel driver is
[shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80) (GPL), which `--driver` installs through DKMS
so it survives kernel updates. If Secure Boot is enabled, you have to sign the module or turn Secure Boot off.

## Adding another dongle

If your dongle has a different storage-mode USB ID, add it to `ids[]` in [`src/aicswitch.c`](src/aicswitch.c)
and to [`99-aicswitch.rules.in`](99-aicswitch.rules.in), then open a PR.

## License

[MIT](LICENSE)
