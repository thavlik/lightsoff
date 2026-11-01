# lightsoff

Turns off every RGB LED at boot, before anyone logs in, and again every time
the machine wakes from suspend or hibernate. A root systemd service runs
`/usr/local/bin/openrgb -c 000000` five times, 2 seconds apart.

| File                | Installed to                          | What it does                                                        |
| ------------------- | ------------------------------------- | ------------------------------------------------------------------- |
| `lightsoff.sh`      | `/usr/local/sbin/lightsoff`           | Waits for udev to settle, then runs `openrgb -c 000000` five times. |
| `lightsoff.service` | `/etc/systemd/system/lightsoff.service` | Oneshot system service that runs the script at boot and on resume. |
| `install.sh`        | (not installed)                       | Copies the two files above, reloads systemd, enables the service.   |
| `uninstall.sh`      | (not installed)                       | Disables and removes everything `install.sh` and the service created. |

## How it works

- **It's a system service, not a user one.** It runs as root, so it doesn't
  need a login, the OpenRGB GUI, a running OpenRGB server, or udev permission
  rules. Without a server, each `openrgb -c 000000` call detects the hardware
  itself, which takes about 3 seconds on this machine (2× Corsair Dominator
  Platinum over SMBus, 2× NZXT Hue 2 over HID).
- **When it runs.** It starts right after `sysinit.target`, the earliest point
  where local filesystems are mounted, kernel modules are loaded and udev has
  started creating `/dev/hidraw*` and `/dev/i2c-*`. The script then runs
  `udevadm settle` so the first attempt can see every device. It runs in
  parallel with the GDM login screen, not ahead of it. The lights should go
  out within a few seconds of boot, and all five runs take about 25 seconds.
  See [Make the login screen wait](#make-the-login-screen-wait-optional) if you
  want GDM to hold until all five runs are done.
- **After resume.** The same service is also wanted by `suspend.target`,
  `hibernate.target`, `hybrid-sleep.target` and `suspend-then-hibernate.target`,
  and ordered after them. Each of those targets only becomes active once the
  machine has woken up, so the five runs start right after every wake-up. USB
  devices re-enumerating after resume are covered by the same `udevadm settle`
  and the 2-second spacing between runs.
- **The service has its own OpenRGB config.** It sets `HOME=/var/lib/lightsoff`,
  so OpenRGB writes its config and logs to `/var/lib/lightsoff/.config/OpenRGB/`
  and doesn't touch your `~/.config/OpenRGB`. A fresh config behaves the same
  as yours: you have no detectors disabled, and your one device setting
  (Corsair Dominator model `CMT`) is also the default. Without `HOME` set,
  OpenRGB would write its logs to the current directory, which for a service
  is `/`.
- **Logs.** OpenRGB writes one ~6 KB log file per run and never deletes old
  ones, so the script deletes its own OpenRGB logs once they're 30 days old.
- **If an OpenRGB server is already running** (for example you started it
  from the GUI), `openrgb -c` connects to that server instead of driving the
  hardware directly. That's the same thing that happens when you run it by
  hand.

## Install

1. Review `lightsoff.sh` and `lightsoff.service`.

2. Install and enable the service:

   ```bash
   sudo ./install.sh
   ```

   For a first install, that is equivalent to:

   ```bash
   sudo install -D -m 0755 lightsoff.sh /usr/local/sbin/lightsoff
   sudo install -D -m 0644 lightsoff.service /etc/systemd/system/lightsoff.service
   sudo systemctl daemon-reload
   sudo systemctl enable lightsoff.service
   ```

3. Test it without rebooting. Turn your lights back on and close the OpenRGB
   GUI first, so two OpenRGB processes aren't using the SMBus at the same time.
   This command blocks for about 25 seconds:

   ```bash
   sudo systemctl start lightsoff.service
   ```

4. Check that all five runs succeeded (the last line should say `5/5 runs succeeded`):

   ```bash
   journalctl -b -u lightsoff.service
   ```

5. Reboot. After logging in, see how many seconds after boot the service ran
   (`-o short-monotonic` shows the time since boot):

   ```bash
   journalctl -b -o short-monotonic -u lightsoff.service -u gdm.service
   ```

6. Test resume. Suspend the machine, wake it, and give it about 25 seconds.
   The journal should show a second set of five runs right after the
   wake-up:

   ```bash
   systemctl suspend
   ```

   ```bash
   journalctl -b -u lightsoff.service -u systemd-suspend.service
   ```

## Tuning

You can change the number of runs, the pause between them, and the per-run
timeout without editing the installed files. Open a drop-in with:

```bash
sudo systemctl edit lightsoff.service
```

Then add:

```ini
[Service]
Environment=LIGHTSOFF_RUNS=8 LIGHTSOFF_DELAY=3 LIGHTSOFF_RUN_TIMEOUT=60
```

### Make the login screen wait (optional)

By default GDM starts at the same time as the service. If you want the login
screen to appear only after all five runs have finished, add this in the same
drop-in. It adds about 25 seconds to every boot.

```ini
[Unit]
Before=display-manager.service
```

## Troubleshooting

- **Some lights stay on after boot.** Raise `LIGHTSOFF_RUNS` or
  `LIGHTSOFF_DELAY` (see [Tuning](#tuning)). To see what the service's OpenRGB
  detects, run:

  ```bash
  sudo HOME=/var/lib/lightsoff /usr/local/bin/openrgb -l
  ```

- **Runs fail with FUSE or mount errors.** `/usr/local/bin/openrgb` is an
  AppImage, so it mounts itself through FUSE on every run. If that ever fails
  at boot, add `Environment=APPIMAGE_EXTRACT_AND_RUN=1` under `[Service]` in
  the drop-in. Each run then unpacks to `/tmp` first instead of mounting, which
  is slower but doesn't need FUSE.
- **The OpenRGB GUI is open when you suspend.** If its server is running, the
  resume runs connect to it, which is fine. If the GUI is open without the
  server, the service and the GUI both talk to the hardware directly after
  wake-up. Close the GUI before suspending, or start its server.
- **You want to turn the lights off again by hand.** Run
  `sudo systemctl start lightsoff.service` or `sudo lightsoff` at any time.

## Uninstall

```bash
sudo ./uninstall.sh
```

This disables the service and deletes `/usr/local/sbin/lightsoff`,
`/etc/systemd/system/lightsoff.service`, any `systemctl edit` drop-in in
`/etc/systemd/system/lightsoff.service.d/`, and `/var/lib/lightsoff`.
