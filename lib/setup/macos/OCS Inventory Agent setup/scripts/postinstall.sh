#!/bin/bash

# Constants
APP_PATH="/Applications/OCS-NG.app/Contents/Resources/"
EXEC_AGENT="AGENT-MACOS"
EXEC_DAEMON="DAEMON-MACOS"
TMP_CONFIG_FILE="/tmp/installer_config.txt"
LOG_PATH="/var/log/ocsinventory-agent/ocsinventory-agent.log"
STORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_NAME="org.ocsinventory.agent"


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
# Run the agent with provided arguments
sudo "$APP_PATH$EXEC_AGENT" -f true -m 0 -p "$PASSWORD" -u "$USERNAME" -s "$URL" -l "$LOG_PATH" -d "$STORE_DATA_PATH"


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
        <string>$APP_PATH$EXEC_DAEMON</string>
        <string>-d</string>
        <string>$APP_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_PATH</string>
    <key>StandardErrorPath</key>
    <string>$LOG_PATH</string>
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
