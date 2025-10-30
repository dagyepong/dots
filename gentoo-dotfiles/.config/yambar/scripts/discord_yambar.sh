#!/bin/bash

if pgrep -x Discord >/dev/null; then
  echo "Discord_status|string|Discord running"
else
  echo "Discord_status|string|Discord not running"
fi
echo ""
