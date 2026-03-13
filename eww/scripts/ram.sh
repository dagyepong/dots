#!/bin/bash
# Get RAM usage percentage
free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}' | sed 's/$/%/'
