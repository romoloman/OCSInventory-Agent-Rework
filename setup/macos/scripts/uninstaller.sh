#!/bin/bash

OSVER=`uname -r`
echo "OSVer is $OSVER"

PID=`ps ax -e | grep OCS-NG | grep -v grep | grep -v $0 | awk '{print $1}'`
if [ "$PID" !=  "" ]; then
	echo "killing process: $PID"
	sudo kill "$PID"
fi

FILES="/Library/Receipts/OCS-NG* /etc/ocsinventory-agent/ /var/lib/ocsinventory-agent/ /Applications/OCS-NG.app /var/log/ocsinventory-agent/"

if [ "$OSVER" == "7.9.0" ]; then
	FILES="$FILES /Library/StartupItems/OCSInventory"
else
	FILES="$FILES /Library/LaunchDaemons/org.ocsinventory.agent.plist"

	echo 'Stopping and unloading service'
	sudo launchctl stop org.ocsinventory.agent
	sudo launchctl unload /Library/LaunchDaemons/org.ocsinventory.agent.plist
	sudo rm /Library/LaunchDaemons/org.ocsinventory.agent.plist
fi

for FILE in $FILES; do
  echo 'removing '."$FILE"
  rm -f -R "$FILE"
done

