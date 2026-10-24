#!/bin/sh
command -v udevadm >/dev/null && udevadm control --reload || true
