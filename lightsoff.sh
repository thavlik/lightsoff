#!/bin/bash
# Turn off every RGB LED that OpenRGB can see.
#
# Some devices ignore the first attempt, so the command is repeated several
# times with a short pause in between. Spreading the runs out also catches
# USB devices that finish enumerating a little later in boot.
#
# Installed as /usr/local/sbin/lightsoff and run at boot by lightsoff.service.
# Can also be run by hand: sudo lightsoff
set -u

OPENRGB=${OPENRGB:-/usr/local/bin/openrgb}
RUNS=${LIGHTSOFF_RUNS:-5}
DELAY=${LIGHTSOFF_DELAY:-2}             # seconds between runs
RUN_TIMEOUT=${LIGHTSOFF_RUN_TIMEOUT:-60} # seconds before giving up on one run

# Wait for udev to finish creating /dev/hidraw* and /dev/i2c-* and loading the
# SMBus driver, so the very first run already sees every device.
if ! udevadm settle --timeout=30; then
    echo "lightsoff: udevadm settle timed out, continuing anyway" >&2
fi

ok=0
for ((i = 1; i <= RUNS; i++)); do
    echo "lightsoff: run $i/$RUNS"
    if timeout "$RUN_TIMEOUT" "$OPENRGB" -c 000000; then
        ok=$((ok + 1))
    else
        echo "lightsoff: run $i/$RUNS failed (exit $?)" >&2
    fi
    if ((i < RUNS)); then
        sleep "$DELAY"
    fi
done

# OpenRGB writes a log file per run (5 per boot) and never deletes old ones.
find "${HOME:-/root}/.config/OpenRGB/logs" -name 'OpenRGB_*.log' -mtime +30 -delete 2>/dev/null || true

echo "lightsoff: $ok/$RUNS runs succeeded"
((ok > 0))
