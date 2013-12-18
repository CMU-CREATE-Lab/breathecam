#!/bin/sh

/Applications/TemperatureMonitor.app/Contents/MacOS/tempmonitor -th >> /Users/adminuser/Desktop/hazecam/temperature.csv
while true
do
  /Applications/TemperatureMonitor.app/Contents/MacOS/tempmonitor -tv >> /Users/adminuser/Desktop/hazecam/temperature.csv
  /bin/sleep 60
done