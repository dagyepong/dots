-- Define the modifier (if not already defined)
local mod = "SUPER"

-- Use the corrected concatenation
hl.bind(mod .. " + A", hl.dsp.exec_cmd("flock -n -o /tmp/rishot.lock qs -c rishot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("flock -n -o /tmp/rishot.lock env RISHOT_MODE=monitor qs -c rishot"))
