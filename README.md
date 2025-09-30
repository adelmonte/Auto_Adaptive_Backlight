# Auto_Adaptive_Backlight
Automatically adjust your laptop's screen brightness based on ambient light conditions.

## Prerequisites
Check if your system has an ambient light sensor:
```bash
lsmod | grep als
```

Or check for IIO devices:
```bash
ls /sys/bus/iio/devices/
```

If you see `iio:device0` or similar, you have a compatible sensor.

## Installation

1. Copy the script to `/usr/local/bin/auto-brightness.sh`

2. Make the script executable:
   ```bash
   sudo chmod +x /usr/local/bin/auto-brightness.sh
   ```

3. Copy the systemd service file to `/etc/systemd/system/auto-brightness.service`

4. Copy the systemd timer file to `/etc/systemd/system/auto-brightness.timer`

5. Enable and start the timer and service:
   ```bash
   sudo systemctl enable --now auto-brightness.timer
   sudo systemctl enable --now auto-brightness.service
   ```

**Note:** This script reads directly from the kernel's IIO subsystem and requires no additional dependencies.

## Configuration
The script uses several key variables that you might want to adjust based on your specific laptop model and preferences:

1. **`LIGHT_SENSOR`**: The path to your laptop's light sensor
   - Default: `/sys/bus/iio/devices/iio:device0/in_illuminance_raw`
   - This path may vary depending on your laptop model. Explore `/sys/bus/iio/devices/` to find the correct path.

2. **`BRIGHTNESS_DEVICE`**: The path to your laptop's brightness control file
   - Default: `/sys/class/backlight/intel_backlight/brightness`
   - For non-Intel graphics cards, look in `/sys/class/backlight/` for the appropriate directory (e.g., `amdgpu_bl0`, `nvidia_0`).

3. **`min_light` and `max_light`**: The range of light values your sensor produces
   - Default: 0 and 800
   - Adjust based on your sensor's range. Test by reading the sensor in different lighting conditions:
     ```bash
     watch -n 0.5 cat /sys/bus/iio/devices/iio:device0/in_illuminance_raw
     ```

4. **`min_brightness` and `max_brightness`**: The minimum and maximum brightness percentages
   - Default: 1 and 100
   - Adjust to your preference (e.g., set `min_brightness` to 10 if 1% is too dim).

5. **Brightness calculation function**: The `calculate_brightness` function uses a piece-wise approach to map light levels to brightness
   - Adjust the thresholds (20, 100) and multipliers to suit your preferences and environment.

6. **`MANUAL_TIMEOUT`**: Time (in seconds) to pause automatic adjustments after manual brightness changes
   - Default: 180 (3 minutes)
   - Increase if you want manual adjustments to persist longer.

7. **`BRIGHTNESS_THRESHOLD`**: Minimum brightness change percentage to trigger an adjustment
   - Default: 5%
   - Reduce for more responsive adjustments; increase to reduce frequent small changes.

8. **Poll interval** (in timer file): `OnUnitActiveSec=5s`
   - Default: 5 seconds
   - Increase to 10-15 seconds to reduce CPU wake-ups (negligible impact on battery, slight delay in brightness response).

## Usage
Once installed and configured, the script runs automatically every 5 seconds, adjusting your screen brightness based on ambient light while respecting manual adjustments.

To manually override automatic brightness control, simply adjust brightness using your laptop's brightness keys. The script detects this change and pauses automatic adjustments for the duration specified by `MANUAL_TIMEOUT`.

## Troubleshooting

**Script doesn't adjust brightness:**
1. Verify the light sensor path is correct:
   ```bash
   cat /sys/bus/iio/devices/iio:device0/in_illuminance_raw
   ```
   The value should change when you cover/uncover the sensor.

2. Verify the brightness control path is correct:
   ```bash
   ls /sys/class/backlight/
   ```
   Then check: `cat /sys/class/backlight/intel_backlight/brightness`

3. Ensure you have write permissions to the brightness file. The systemd service should run with appropriate privileges.

**Check service logs:**
```bash
journalctl -u auto-brightness.service -f
```

**Test the script manually:**
```bash
sudo /usr/local/bin/auto-brightness.sh
```

**Brightness adjustments are too sensitive/not sensitive enough:**
- Adjust `BRIGHTNESS_THRESHOLD` (lower = more sensitive)
- Modify the `calculate_brightness` function thresholds
- Change the timer interval in `auto-brightness.timer`
