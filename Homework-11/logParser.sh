#!/bin/bash


# is already running?
ps -ef | grep -v $$ | grep -q [l]ogParser && echo "Already running" && exit 1

IP_BY_REQUESTS=$(cat access_log | cut -d ' ' -f 1 | sort | uniq -c | sort -nr | head)
URL_BY_REQUESTS=$(cat access_log | grep -v "OPTIONS" | cut -d ' ' -f 7 | sort | uniq -c | sort -nr | head)
HTTP_ERRORS=$(cat error_log)
HTTP_STATUS_CODES=$(cat access_log | cut -d ' ' -f 9 | sort | uniq -c | sort -nr | grep -v "-")

printf "\nNUMBER OF REQUESTS BY IP:\n   
$IP_BY_REQUESTS\n 
\nNUMBER OF REQUESTS BY URL: \n 
$URL_BY_REQUESTS\n 
\nHTTP ERRORS:\n 
$HTTP_ERRORS\n 
\nNUBER OF REQIESTS BY HTTP STATUS CODES:\n 
$HTTP_STATUS_CODES\n" #| mail -s "logParser results" itbn



