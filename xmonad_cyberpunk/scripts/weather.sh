#!/bin/bash
# Weather script for Gentoo
curl -s "wttr.in/?format=%c+%t+%w" | sed 's/+//g'