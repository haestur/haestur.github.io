#!/bin/bash

#echo "PID        TTY(dev_t)        STATUS        TIME(seconds)        CMD"
printf "%-10s%-15s%-10s%-20s%s\n" "PID" "TTY(dev_t)" "STATUS" "TIME(sec)" "CMD"

for var in $(ls /proc | sort -n | awk '/^[[:digit:]]*$/{print $0}'); do
	if [ ! -d /proc/$var ]; then
		continue 
	fi
	PROCESS_STAT=($(sed 's/\([^)]+\)//' "/proc/$var/stat"))
	PROCESS_PID=${PROCESS_STAT[0]}
	PROCESS_STATUS=${PROCESS_STAT[2]}
	PROCESS_TTY=${PROCESS_STAT[6]}
	PROCESS_TCOMM=${PROCESS_STAT[1]}
	PROCESS_UTIME=${PROCESS_STAT[13]}
	PROCESS_STIME=${PROCESS_STAT[14]}
	CLK_TCK=$(getconf CLK_TCK)

	let PROCESS_UTIME_SEC="$PROCESS_UTIME / $CLK_TCK"
	let PROCESS_STIME_SEC="$PROCESS_STIME / $CLK_TCK"
	let PROCESS_USAGE_SEC="$PROCESS_UTIME_SEC + $PROCESS_STIME_SEC"

	if [ -f /proc/$var/cmdline ] && [ $(cat /proc/$var/cmdline | wc -c) -gt 0 ]; then
		CMDLINE=$(tr '\0' ' ' < /proc/$var/cmdline)
                PROCESS_CMD=${CMDLINE}
	else
		PROCESS_CMD=$(echo $PROCESS_TCOMM | tr '(' '[' | tr ')' ']')
	fi
	printf "%-10s%-15s%-10s%-20s%s\n" "${PROCESS_PID}" "${PROCESS_TTY}" "${PROCESS_STATUS}" "${PROCESS_USAGE_SEC}" "${PROCESS_CMD}"
done

