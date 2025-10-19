#!/bin/bash
# Check for Gentoo updates
updates=$(emerge -puDN @world 2>/dev/null | grep -c "\[ebuild.*U\]")
security=$(glsa-check -l affected 2>/dev/null | grep -c "\[GLS" || echo "0")

if [ $updates -gt 0 ] || [ $security -gt 0 ]; then
    echo " $updates| $security"
else
    echo " 0"
fi