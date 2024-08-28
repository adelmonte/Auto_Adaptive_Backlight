# Auto_Adaptive_Backlight
Automatically adjust your laptop's screen brightness based on ambient light conditions.

## Dependencies
You can check if your system has an ambient light sensor with: ```lsmod | grep als```

- `brillo`: Used for smooth brightness adjustments
- `iio-sensor-proxy`: Ambient Light Sensor Daemon

## Installation

1. Install (and enable) the required dependencies:
   ```
   yay brillo iio-sensor-proxy
   yay iio-sensor-proxy
   
   systemctl enable --now iio-sensor-proxy.service
   ```

2. Copy the script to: `/usr/local/bin/auto-brightness.sh`

3. Make the script executable:
   ```
   sudo chmod +x /usr/local/bin/auto-brightness.sh
   ```
   
4. Copy the systemd service file to: `/etc/systemd/system/auto-brightness.service`

5. Copy the systemd timer file to: `/etc/systemd/system/auto-brightness.timer`

6. Enable and start the timer and service:
   ```
   sudo systemctl enable --now auto-brightness.timer
   sudo systemctl enable --now auto-brightness.service
   ```

## Configuration

The script uses several key variables that you might want to adjust based on your specific laptop model and preferences:

1. `LIGHT_SENSOR`: The path to your laptop's light sensor. 
   - Current value: `/sys/bus/iio/devices/iio:device0/in_illuminance_raw`
   - This path may vary depending on your laptop model. You can find the correct path by exploring the `/sys/bus/iio/devices/` directory.

2. `BRIGHTNESS_DEVICE`: The path to your laptop's brightness control file.
   - Current value: `/sys/class/backlight/intel_backlight/device/intel_backlight/brightness`
   - This path may be different for non-Intel graphics cards. Look in `/sys/class/backlight/` for the appropriate directory.

3. `min_light` and `max_light`: The range of light values your sensor produces.
   - Current values: 0 and 800
   - These may need adjustment based on your light sensor's sensitivity and range. I find anything above 800 is extremely bright (flashing torch directly into sensor).

4. `min_brightness` and `max_brightness`: The minimum and maximum brightness levels.
   - Current values: 1 and 100
   - Adjust these if your laptop's brightness range is different.

5. Brightness calculation function: The `calculate_brightness` function uses a piece-wise approach to map light levels to brightness. You may want to adjust the thresholds and slopes to better suit your preferences and environment.

6. `MANUAL_TIMEOUT`: The time (in seconds) that the script will wait after a manual brightness adjustment before resuming automatic control.
   - Current value: 180 (3 minutes)
   - Adjust this value based on your preference for how long manual adjustments should persist.

7. (TIMER) `OnUnitActiveSec=5s` The time (in seconds) the script will execute. Increasing this interval will save battery power but will result in delayed brightness adjustments.

Remember to test the script thoroughly after making any changes to ensure it works correctly with your specific hardware.

## Usage

Once installed and configured, the script will run automatically every 5 seconds. It will adjust your screen brightness based on the ambient light level, while also respecting manual adjustments for a specified period of time.

To manually override the automatic brightness control, simply adjust your brightness using your laptop's brightness keys. The script will detect this manual change and pause automatic adjustments for the duration specified by `MANUAL_TIMEOUT`.

## Troubleshooting

If the script doesn't work as expected, check the following:

1. Ensure the light sensor path (`LIGHT_SENSOR`) is correct for your laptop.
2. Verify that the brightness control file path (`BRIGHTNESS_DEVICE`) is correct.
3. Check the system logs for any error messages:
   ```
   journalctl -u auto-brightness.service
   ```
4. Try your luck with the Debug Script.
