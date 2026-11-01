#!/bin/bash
# Install and enable the lightsoff boot service. Run from anywhere with sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

cd "$(dirname "$0")"

install -D -m 0755 lightsoff.sh /usr/local/sbin/lightsoff
install -D -m 0644 lightsoff.service /etc/systemd/system/lightsoff.service
systemctl daemon-reload
# reenable rather than enable, so re-running this after changing [Install]
# also removes symlinks for targets that were dropped.
systemctl reenable lightsoff.service

echo "Installed and enabled. Test it now with: sudo systemctl start lightsoff.service"
