#!/bin/bash
grim -g "$(slurp -b '#2E2A1E55' -c '#fb751bff')" -t ppm - | satty -f - --output-filename ~/Pictures/Screenshot_$(date '+%Y%m%d_%H%M%S').png
