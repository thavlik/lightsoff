#!/bin/bash
# Disable and remove the lightsoff boot service. Run from anywhere with sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

systemctl disable lightsoff.service 2>/dev/null || true
rm -f /etc/systemd/system/lightsoff.service /usr/local/sbin/lightsoff
# Overrides added with: systemctl edit lightsoff.service
rm -rf /etc/systemd/system/lightsoff.service.d
# OpenRGB config and logs written by the service (see StateDirectory=).
rm -rf /var/lib/lightsoff
systemctl daemon-reload

echo "Removed."
