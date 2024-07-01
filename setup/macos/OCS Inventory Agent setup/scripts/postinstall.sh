#!/bin/bash

# Constants
APP_PATH="/Applications/OCS-NG.app/Contents/Resources/"
EXEC_AGENT="AGENT-MACOS"
EXEC_DAEMON="DAEMON-MACOS"
TMP_CONFIG_FILE="/tmp/installer_config.txt"
LOG_PATH="/var/log/ocsinventory-agent/ocsinventory-agent.log"
STORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_NAME="org.ocsinventory.agent"
CONFIG_PATH="/etc/ocsinventory-agent/inventory.json"

# Check if the config agent is ready exist in the system then run the agent without parameters
if [[ -f "$CONFIG_PATH" ]]; then
    echo "Configuration file found. Running the agent with existing configuration..."
    sudo "$APP_PATH$EXEC_AGENT"
    exit 0
fi

# Function to read configuration values of each 
read_config() {
    local TMP_CONFIG_FILE="$1"
    if [[ -f "$TMP_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                'server') URL="$value" ;;
                'username') USERNAME="$value" ;;
                'password') PASSWORD="$value" ;;
                'serviceMode') SERVICE_MODE="$value" ;;
                'logLevel') LOG_LEVEL="$value" ;;
                'runNow') RUN_NOW="$value" ;;
            esac
        done < "$TMP_CONFIG_FILE"
    else
        echo "Configuration file not found!"
        exit 1
    fi
}

# Copy the daemon executable to /usr/local/bin
cp "$DAEMON_SOURCE_PATH" "$DAEMON_DEST_PATH"
chmod +x "$DAEMON_DEST_PATH"

read_config "$TMP_CONFIG_FILE"

# Retrieve log level values (0: Error 1: Warning 2: Info 3: Verbose)
LOG_LEVEL_VALUES=2
case "$LOG_LEVEL" in
    'Error') LOG_LEVEL_VALUES=0 ;;
    'Warning') LOG_LEVEL_VALUES=1 ;;
    'Info') LOG_LEVEL_VALUES=2 ;;
    'Verbose') LOG_LEVEL_VALUES=3 ;;
esac

# Run the agent with provided arguments
sudo "$APP_PATH$EXEC_AGENT" -f true -m 0 -p "$PASSWORD" -u "$USERNAME" -s "$URL" -l "$LOG_PATH" -d "$STORE_DATA_PATH" -v "$LOG_LEVEL_VALUES"

if [[ "$RUN_NOW" == "yes" || "$RUN_NOW" == "Yes" ]]; then
    echo "Running the agent now..."
    sudo "$APP_PATH$EXEC_AGENT" -f true -m 2 -p "$PASSWORD" -u "$USERNAME" -s "$URL" -l "$LOG_PATH" -d "$STORE_DATA_PATH" -v "$LOG_LEVEL_VALUES"
fi



# Function to register service if SERVICE_MODE is yes or Yes
register_service() {
    if [[ "$SERVICE_MODE" == "yes" || "$SERVICE_MODE" == "Yes" ]]; then
        echo "Creating OCS Inventory Agent service..."
        
        # Create service file
        cat << EOF | sudo tee "/Library/LaunchDaemons/$SERVICE_NAME.plist" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>"$APP_PATH$EXEC_DAEMON"</string>
        <string>-d</string>
        <string>"$APP_PATH"</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>"$LOG_PATH"</string>
    <key>StandardErrorPath</key>
    <string>"$LOG_PATH"</string>
</dict>
</plist>
EOF

        # Set permissions and load service
        sudo chown root:wheel "/Library/LaunchDaemons/$SERVICE_NAME.plist"
        sudo launchctl load "/Library/LaunchDaemons/$SERVICE_NAME.plist"
        
        echo "OCS Inventory Agent service registered."
    else
        echo "Service registration skipped as SERVICE MODE is not 'yes' or 'Yes'."
    fi
}

register_service

# Remove temporary configuration file
rm -f "$TMP_CONFIG_FILE"

exit 0
