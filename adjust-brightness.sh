#!/bin/bash

# Constants
LIGHT_SENSOR="/sys/bus/iio/devices/iio:device0/in_illuminance_raw"
BRIGHTNESS_FILE="/tmp/last_set_brightness"
BRIGHTNESS_DEVICE="/sys/class/backlight/intel_backlight/brightness"
MAX_BRIGHTNESS_DEVICE="/sys/class/backlight/intel_backlight/max_brightness"
MANUAL_FLAG_FILE="/tmp/manual_brightness_change"
MANUAL_TIMEOUT=180  # 3 minutes in seconds
BRIGHTNESS_THRESHOLD=5  # Minimum brightness change threshold (in percentage)

# Cache max brightness
MAX_DEVICE_BRIGHTNESS=$(cat "$MAX_BRIGHTNESS_DEVICE")

# Function to get the light level
get_light_level() {
    cat "$LIGHT_SENSOR"
}

# Function to set brightness smoothly
set_brightness_smooth() {
    local target=$1
    local current=$(cat "$BRIGHTNESS_DEVICE")
    local steps=20
    local sleep_time=0.05
    for ((i=1; i<=steps; i++)); do
        local new_brightness=$((current + (target - current) * i / steps))
        echo "$new_brightness" > "$BRIGHTNESS_DEVICE"
        sleep $sleep_time
    done
    # Ensure final value is set
    echo "$target" > "$BRIGHTNESS_DEVICE"
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
    
    # Convert percentage to device-specific value
    echo $((brightness * MAX_DEVICE_BRIGHTNESS / 100))
}

# Check if the brightness device exists
if [ ! -f "$BRIGHTNESS_DEVICE" ]; then
    exit 1
fi

# Get the current brightness
current_brightness=$(cat "$BRIGHTNESS_DEVICE")
current_brightness_percent=$((current_brightness * 100 / MAX_DEVICE_BRIGHTNESS))

# Check for manual override
current_time=$(date +%s)
if [ -f "$MANUAL_FLAG_FILE" ]; then
    manual_time=$(cat "$MANUAL_FLAG_FILE")
    time_diff=$((current_time - manual_time))
    if [ $time_diff -lt $MANUAL_TIMEOUT ]; then
        exit 0
    else
        rm "$MANUAL_FLAG_FILE"
    fi
fi

# Check for manual adjustment
if [ -f "$BRIGHTNESS_FILE" ]; then
    last_set_brightness=$(cat "$BRIGHTNESS_FILE")
    last_set_brightness_percent=$((last_set_brightness * 100 / MAX_DEVICE_BRIGHTNESS))
    if [ "$current_brightness" != "$last_set_brightness" ]; then
        brightness_diff=$((current_brightness_percent - last_set_brightness_percent))
        if [ ${brightness_diff#-} -ge $BRIGHTNESS_THRESHOLD ]; then
            echo "$current_time" > "$MANUAL_FLAG_FILE"
            echo "$current_brightness" > "$BRIGHTNESS_FILE"
            exit 0
        fi
    fi
else
    echo "$current_brightness" > "$BRIGHTNESS_FILE"
fi

# Get the light level and calculate the target brightness
light=$(get_light_level)
if [ -n "$light" ]; then
    target_brightness=$(calculate_brightness "$light")
    target_brightness_percent=$((target_brightness * 100 / MAX_DEVICE_BRIGHTNESS))
    
    # Check if the change in brightness is significant
    brightness_diff=$((target_brightness_percent - current_brightness_percent))
    if [ ${brightness_diff#-} -ge $BRIGHTNESS_THRESHOLD ]; then
        set_brightness_smooth "$target_brightness"
        echo "$target_brightness" > "$BRIGHTNESS_FILE"
    fi
fi
