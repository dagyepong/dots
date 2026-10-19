hl.layer_rule({ name = "pjsekai-region-no-anim", match = { namespace = "^pjsekai-region$" }, no_anim = true }) -- pjsekai:region-no-anim
hl.layer_rule({ name = "pjsekai-region-preview-no-anim", match = { namespace = "^pjsekai-region-preview$" }, no_anim = true }) -- pjsekai:region-preview-no-anim
hl.config({ ["general"] = { ["gaps_out"] = 14 } }) -- pjsekai:hypr:general.gaps_out
hl.config({ ["general"] = { ["gaps_in"] = 6 } }) -- pjsekai:hypr:general.gaps_in
hl.config({ ["decoration"] = { ["inactive_opacity"] = 1.00 } }) -- pjsekai:hypr:decoration.inactive_opacity
hl.config({ ["general"] = { ["border_size"] = 2 } }) -- pjsekai:hypr:general.border_size
hl.config({ ["misc"] = { ["animate_manual_resizes"] = true } }) -- pjsekai:hypr:misc.animate_manual_resizes
hl.animation({ leaf = "workspaces", enabled = true, speed = 7.00, bezier = "menu_decel", style = "slidefadevert" }) -- pjsekai:hypr:animation.workspaces
pcall(hl.config, { ["general"] = { ["col"] = { ["active_border"] = "rgba(00feeeee)", ["inactive_border"] = "rgba(00757bcc)" } } }) -- pjsekai:apptheme:hyprland
