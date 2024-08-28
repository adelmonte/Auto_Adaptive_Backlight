#!/bin/bash

# Constants
LIGHT_SENSOR="/sys/bus/iio/devices/iio:device0/in_illuminance_raw"
BRIGHTNESS_FILE="/tmp/last_set_brightness"
BRIGHTNESS_DEVICE="/sys/class/backlight/intel_backlight/device/intel_backlight/brightness"
MANUAL_FLAG_FILE="/tmp/manual_brightness_change"
LOG_FILE="/tmp/brightness_adjustment.log"
MANUAL_TIMEOUT=180  # 3 minutes in seconds

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to get the light level
get_light_level() {
    cat "$LIGHT_SENSOR"
}

# Function to set brightness smoothly
set_brightness_smooth() {
    local level=$1
    brillo -u 250000 -S "$level" -e
}





# Function to calculate brightness based on light level
calculate_brightness() {
    local light=$1
    local min_light=0
    local max_light=800
    local min_brightness=1  # Minimum brightness of 1%
    local max_brightness=100

    # Clamp light level within bounds
    light=$(( light < min_light ? min_light : (light > max_light ? max_light : light) ))

    # Use a piece-wise function for more natural brightness progression
    local brightness
    if ((light <= 20)); then
        # Rapid increase for very low light levels
        brightness=$(( min_brightness + (light * 19 / 20) ))
    elif ((light <= 100)); then
        # Slower increase for low to medium light levels
        brightness=$(( 20 + (light - 20) * 30 / 80 ))
    else
        # Gradual increase for medium to high light levels
        brightness=$(( 50 + (light - 100) * 50 / 700 ))
    fi

    # Ensure brightness is within bounds
    brightness=$(( brightness < min_brightness ? min_brightness : (brightness > max_brightness ? max_brightness : brightness) ))

    echo "$brightness"
}











# Check if the brightness device exists
if [ ! -f "$BRIGHTNESS_DEVICE" ]; then
    log_message "Brightness device not found: $BRIGHTNESS_DEVICE"
    exit 1
fi

# Get the current brightness
current_brightness=$(brillo -G | cut -d'.' -f1)
log_message "Current brightness: $current_brightness"

# Check if manual flag exists and if it's still within the timeout period
current_time=$(date +%s)
if [ -f "$MANUAL_FLAG_FILE" ]; then
    manual_time=$(cat "$MANUAL_FLAG_FILE")
    time_diff=$((current_time - manual_time))
    if [ $time_diff -lt $MANUAL_TIMEOUT ]; then
        log_message "Manual adjustment flag active. Skipping automatic adjustment. Time remaining: $((MANUAL_TIMEOUT - time_diff)) seconds"
        exit 0
    else
        log_message "Manual adjustment timeout expired. Resuming automatic adjustments."
        rm "$MANUAL_FLAG_FILE"
    fi
fi

# Check for manual adjustment
if [ -f "$BRIGHTNESS_FILE" ]; then
    last_set_brightness=$(cat "$BRIGHTNESS_FILE")
    log_message "Last set brightness: $last_set_brightness"
    if [[ "$current_brightness" != "$last_set_brightness" ]]; then
        log_message "Potential manual adjustment detected. Current: $current_brightness, Last set: $last_set_brightness"
        # Check if the difference is significant (e.g., more than 5%)
        if (( ${current_brightness#-} - ${last_set_brightness#-} > 5 )) || (( ${last_set_brightness#-} - ${current_brightness#-} > 5 )); then
            log_message "Confirmed manual adjustment. Difference is significant."
            echo "$current_time" > "$MANUAL_FLAG_FILE"
            echo "$current_brightness" > "$BRIGHTNESS_FILE"
            exit 0
        else
            log_message "Ignoring small difference. Continuing with auto-adjustment."
        fi
    fi
else
    log_message "No previous brightness file found. Creating it."
    echo "$current_brightness" > "$BRIGHTNESS_FILE"
fi

# Proceed with automatic adjustment
light=$(get_light_level)
log_message "Current light level: $light"
if [ -n "$light" ]; then
    brightness=$(calculate_brightness "$light")
    log_message "Calculated brightness: $brightness"
    set_brightness_smooth "$brightness"
    echo "$brightness" > "$BRIGHTNESS_FILE"
    log_message "Light level: $light, Brightness set to: $brightness%"
else
    log_message "No light level reading available"
fi