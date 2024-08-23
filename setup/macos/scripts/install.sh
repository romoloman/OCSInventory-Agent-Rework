#!/bin/bash
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")

# Function to display usage information
usage() {
	echo "Usage: $0 [-l Link] [-u USERNAME] [-p PASSWORD] [-v LOG_LEVEL ] [-c CERTIFICATE] [-s] [-n] [-h]"
	echo "  -l LINK             link of the OCS Inventory NG server"
	echo "  -u USERNAME         Username"
	echo "  -p PASSWORD         Password"
	echo "  -v LOG_LEVEL        Log level"
	echo "  -c CERTIFICATE      Path to the certificate file"
	echo "  -s                  Service mode (register service)"
	echo "  -n                  Run the agent now"
	echo "  -h                  Display this help message"
	exit 1
}

# Default values
SERVICE=false
NOW=false # if true, we run the agent now with mode 2

# Parse command-line arguments
while getopts "l:u:p:v:c:snh" opt; do
	case ${opt} in
	l) URL=$OPTARG ;;
	u) USERNAME=$OPTARG ;;
	p) PASSWORD=$OPTARG ;;
	v) LOG_LEVEL=$OPTARG ;;
	c) CERTIFICATE=$OPTARG ;;
	s) SERVICE=true ;;
	n) NOW=true ;;
	h) usage ;;
	*) usage ;;
	esac
done

# Change service and now values to yes if the flags are set
if [ "$SERVICE" = "true" ]; then
	SERVICE="yes"
else
	SERVICE="no"
fi

if [ "$NOW" = "true" ]; then
	NOW="yes"
else
	NOW="no"
fi

# Check if the required parameters are set
if [ -z "$URL" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$LOG_LEVEL" ]; then
	usage
fi



# Save the configuration to /tmp/installer_config_file.txt
cat <<EOF | sudo tee "/tmp/installer_config.txt" >/dev/null
server=${URL}
username=${USERNAME}
password=${PASSWORD}
logLevel=${LOG_LEVEL}
serviceMode=${SERVICE}
runNow=${NOW}
certificate=${CERTIFICATE}
EOF

# build the package path by navigating one level up from the script directory
SETUP_PATH=$(dirname "$WORKING_DIRECTORY")
PKG_PATH="${SETUP_PATH}/OCS Inventory Agent setup/build/OCS Inventory Agent Setup.mpkg"

# Check if the package exists
if [ -f "$PKG_PATH" ]; then
	echo "Package not found: $PKG_PATH"
	exit 1
fi
# Run installer with configuration file
sudo installer -pkg "$PKG_PATH" -target /Applications

exit 0
