#!/bin/sh
# Made-up song -> analyzer -> chart rules. Needs python3 + numpy and node.
set -e
cd "$(dirname "$0")"
python3 evaluate.py
python3 ../../scripts/cava/sekai_analyzer.py --file /tmp/sekai_test_song.raw > /tmp/sekai_frames.jsonl
node chart_test.js /tmp/sekai_frames.jsonl
node chart_unit.js
# the aubio glue, against a stand-in with the same API (NOT real aubio)
PYTHONPATH=fake_aubio python3 evaluate.py aubio
node chart_test.js /tmp/sekai_frames_aubio.jsonl | tail -1
