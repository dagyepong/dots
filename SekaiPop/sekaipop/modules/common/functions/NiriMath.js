.pragma library

// The rules behind the niri workspace badges (services/NiriWorkspaces.qml reads
// niri's event stream from its socket and hands each line to parse() and
// applyEvent() below). Pure functions on plain objects, so they can be
// unit-tested with node: tests/niri-test/niri_unit.js.
//
// A "workspace" is niri's own object, as the event stream sends it:
//
//   { id, idx, name, output, is_active, is_focused, active_window_id, is_urgent }
//
//   id                niri's global handle, what FocusWorkspace is sent
//   idx               the number on its output, from 1 at the top
//   output            the output it lives on ("eDP-1")
//   is_active         shown on its output right now
//   active_window_id  null when the workspace has no windows

// one line from niri's socket as an object, or null when it is empty or not a
// json object
function parse(line) {
    if (line.trim() === "")
        return null

    let message = null

    try {
        message = JSON.parse(line)
    } catch (e) {
        console.warn("NiriMath: failed to parse a niri socket line: " + line)
        return null
    }

    if (message === null || typeof message !== "object")
        return null

    return message
}

// the new workspace list after one event, or null when the event changes
// nothing (an event this file does not use, or one about an unknown workspace)
function applyEvent(workspaces, event) {
    const changed = event.WorkspacesChanged
    if (changed)
        return Array.isArray(changed.workspaces) ? changed.workspaces : null

    const activated = event.WorkspaceActivated
    if (activated)
        return activate(workspaces, activated.id, activated.focused === true)

    const windowChanged = event.WorkspaceActiveWindowChanged
    if (windowChanged)
        return setActiveWindow(workspaces, windowChanged.workspace_id, windowChanged.active_window_id)

    return null
}

// the workspace becomes the active one on its output, and the focused one
// everywhere when `focused` is true
function activate(workspaces, id, focused) {
    const target = findById(workspaces, id)

    if (target === null)
        return null

    const result = []

    for (const workspace of workspaces) {
        const copy = Object.assign({}, workspace)
        const isTarget = workspace.id === id

        if (workspace.output === target.output)
            copy.is_active = isTarget

        if (focused)
            copy.is_focused = isTarget

        result.push(copy)
    }

    return result
}

function setActiveWindow(workspaces, id, windowId) {
    if (findById(workspaces, id) === null)
        return null

    const result = []

    for (const workspace of workspaces) {
        if (workspace.id !== id) {
            result.push(workspace)
            continue
        }

        // niri sends null when the last window closes
        const activeWindow = windowId === undefined ? null : windowId

        result.push(Object.assign({}, workspace, { active_window_id: activeWindow }))
    }

    return result
}

function findById(workspaces, id) {
    for (const workspace of workspaces) {
        if (workspace.id === id)
            return workspace
    }

    return null
}

// the idx shown on `output`, or 1 when niri has not reported that output yet
// (the same fallback Bar.qml uses on Hyprland)
function activeOn(workspaces, output) {
    for (const workspace of workspaces) {
        if (workspace.output === output && workspace.is_active)
            return workspace.idx
    }

    return 1
}

// the idxs on `output` that have windows
function occupiedOn(workspaces, output) {
    const occupied = []

    for (const workspace of workspaces) {
        if (workspace.output !== output)
            continue

        if (workspace.active_window_id === null || workspace.active_window_id === undefined)
            continue

        occupied.push(workspace.idx)
    }

    return occupied
}

/*
 * the id of workspace `idx` on `output`, for FocusWorkspace. a badge can show
 * a number niri does not have yet (the bar always shows 1..count); that goes
 * to the last workspace on the output, the empty one niri keeps at the end,
 * the same as `niri msg action focus-workspace` does. null when niri has not
 * reported the output
 */
function idOf(workspaces, output, idx) {
    let last = null

    for (const workspace of workspaces) {
        if (workspace.output !== output)
            continue

        if (workspace.idx === idx)
            return workspace.id

        if (last === null || workspace.idx > last.idx)
            last = workspace
    }

    return last === null ? null : last.id
}
