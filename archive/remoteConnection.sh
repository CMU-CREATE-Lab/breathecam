#!/bin/sh

while [ 1 ]; do
	ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o ExitOnForwardFailure=yes -R 2323:localhost:22 -R 2324:192.168.2.2:80 gigapantester@lauwers.ece.cmu.edu
	sleep 60
done