#!/bin/bash

if [ $# -ne 1 ] ; then
	ATTEMPTS=3
else
	ATTEMPTS=$1
fi
COUNT=0
NO_CARRIER=0
NO_IP=0
MAX_ERRORS=5
MAX_CONNECT_WAIT=60
PING_ERRORS=0

MAX_CONNECT=0
MIN_CONNECT=99999999
TOTAL_CONNECT=0

LOG_FILE=/userdata/system/logs/S20connman.log

TIMESTAMP=`date +%Y%m%d.%H%M%S.%N`

for i in $(seq 1 $ATTEMPTS) ; do
	echo "Test iteration $i of $ATTEMPTS"

	COUNT=$(($COUNT + 1))

	echo "    Restarting Connman"

	mv $LOG_FILE $LOG_FILE.$TIMESTAMP
	
	/etc/init.d/S20connman restart
	
	if grep -q "NO CARRIER" $LOG_FILE ; then
		echo "No Carrier Error at test $i"
		NO_CARRIER=$(($NO_CARRIER + 1))

		if [ $NO_CARRIER -gt $MAX_ERRORS ] ; then
			echo "Aborting test, $NO_CARRIER is too many errors"
			break
		fi
		continue
	fi

	echo -n "    Waiting for IP Address"

	for ipcheck in $(seq 1 $MAX_CONNECT_WAIT) ; do
		ifconfig wlan0 > ifconfig.log

		if grep -q "inet" ifconfig.log; then
			echo ""
			echo -n "    Took $ipcheck seconds to get IP"
			TOTAL_CONNECT=$(($TOTAL_CONNECT + $ipcheck))
			if [ $ipcheck -lt $MIN_CONNECT ] ; then
				MIN_CONNECT=$ipcheck
			fi
			if [ $ipcheck -gt $MAX_CONNECT ] ; then
				MAX_CONNECT=$ipcheck
			fi

			break
			
		fi

		echo -n "."

		sleep 1
	done

	echo ""

	if ! grep -q "inet" ifconfig.log; then
		echo "No IP address at test $i"
		NO_IP=$(($NO_IP + 1))
		if [ $NO_IP -gt $MAX_ERRORS ] ; then
			echo "Aborting test, $NO_IP is too many errors"
			break
		fi
		continue
	fi

	echo "Checking for Internet Connection"

	ping www.google.com -c 2 > ping_google.log

	if ! grep -q " time=" ping_google.log; then
		echo "Ping failure (www.google.com)"
		PING_ERRORS=$(($PING_ERRORS + 1))
	fi
done

echo "$NO_CARRIER No Carrier errors in $i attempts"
echo "$NO_IP No IP Address errors in $i attempts"
echo "$PING_ERRORS Ping errors in $i attempts"

echo "Minimum Connection time: $MIN_CONNECT"
echo "Average Connection time: $(($TOTAL_CONNECT / $i))"
echo "Maximum Connection time: $MAX_CONNECT"
