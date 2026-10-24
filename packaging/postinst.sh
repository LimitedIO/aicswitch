#!/bin/sh
if command -v udevadm >/dev/null; then udevadm control --reload || true; fi
