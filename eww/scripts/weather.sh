#!/bin/bash
# Get weather for your city (replace "YourCity")
curl -s "wttr.in/Chicago?format=%c+%t" | sed 's/ //g' | tr -d '\n'
