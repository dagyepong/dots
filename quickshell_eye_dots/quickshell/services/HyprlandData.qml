// ┌────────────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░█░█░█░█▀█░█▀▄░█░░░█▀█░█▀█░█▀▄░█▀▄░█▀█░▀█▀░█▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▀█░░█░░█▀▀░█▀▄░█░░░█▀█░█░█░█░█░█░█░█▀█░░█░░█▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░░▀░░▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀░░▀▀░░▀░▀░░▀░░▀░▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Converted for Niri compositor support ───────────────────────────────├┤
// └──────────────────────────────────────────────────────────────────────┘┘

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

/**
 * Provides access to Niri window, workspace, and monitor data structured 
 * to mimic the expected HyprlandData properties used across Daniel Berg's dotfiles.
 */
Singleton {
  id: root
  property var windowList: []
  property var addresses: []
  property var windowByAddress: ({})
  property var workspaces: []
  property var workspaceIds: []
  property var workspaceById: ({})
  property var workspacesByMonitor: ({})
  property var windowsByWorkspace: ({})
  property var activeWorkspace: null
  property var monitors: []
  property var layers: ({})
  property var special: []
  property string specialEventData: ""
  property string submap: ""
  property bool submapActive: submap.length > 0

  property var urgentWindows: []
  // Fallback representation for active top level window matching Niri's JSON keys
  property var activeTopLevel: null

  function clearUrgentByClass(c) {
    root.urgentWindows = root.urgentWindows.filter(win => {
      return win.class !== c
    })
  }

  function updateWindowList() {
    getClients.running = true;
  }

  function updateMonitors() {
    getMonitors.running = true;
  }

  function updateWorkspaces() {
    getWorkspaces.running = true;
  }

  function updateAll() {
    updateWindowList();
    updateMonitors();
    updateWorkspaces();
  }

  Component.onCompleted: {
    updateAll();
    eventStream.running = true;
  }

  // Niri event stream listener handles real-time updates efficiently
  Process {
    id: eventStream
    command: ["niri", "msg", "event-stream"]
    stdout: StdioCollector {
      id: eventCollector
      onStreamFinished: {
        // If the stream drops, restart it
        eventStream.running = true;
      }
    }
    // Read line by line from Niri's event stream output
    onRunningChanged: {
      if (!running) {
        // Auto-reconnect safety net
        eventStream.running = true;
      }
    }
  }

  // Parse incoming event line chunks if needed, or simply trigger a refresh on change
  Connections {
    target: eventCollector
    function onTextChanged() {
      // Whenever niri emits an event, refresh state dictionaries
      root.updateAll();
    }
  }

  // Fetch all open windows from Niri
  Process {
    id: getClients
    command: ["niri", "msg", "--json", "windows"]
    stdout: StdioCollector {
      id: clientsCollector
      onStreamFinished: {
        if (clientsCollector?.text) {
          try {
            const rawWindows = JSON.parse(clientsCollector.text);
            // Map Niri window structure to match expected properties (id, address, workspace id, class, etc.)
            root.windowList = rawWindows.map(w => ({
              address: String(w.id),
              id: w.id,
              title: w.title ?? "",
              class: w.app_id ?? "",
              workspace: { id: w.workspace_id },
              is_focused: w.is_focused,
              is_floating: w.is_floating
            }));

            let tempWinByAddress = {};
            let focusedWin = null;
            for (var i = 0; i < root.windowList.length; ++i) {
              var win = root.windowList[i];
              tempWinByAddress[win.address] = win;
              if (win.is_focused) {
                focusedWin = win;
              }
            }
            root.windowByAddress = tempWinByAddress;
            root.windowsByWorkspace = Functions.groupBy(root.windowList, w => w.workspace.id);
            root.addresses = root.windowList.map(win => win.address);
            root.activeTopLevel = focusedWin;
          } catch(e) {
            console.error("Failed to parse Niri windows JSON: " + e);
          }
        }
      }
    }
  }

  // Fetch monitors / outputs from Niri
  Process {
    id: getMonitors
    command: ["niri", "msg", "--json", "outputs"]
    stdout: StdioCollector {
      id: monitorsCollector
      onStreamFinished: {
        if (monitorsCollector?.text) {
          try {
            const rawOutputs = JSON.parse(monitorsCollector.text);
            // Niri outputs object structure formatting
            root.monitors = Object.keys(rawOutputs).map(key => {
              let out = rawOutputs[key];
              return {
                name: key,
                make: out.make ?? "",
                model: out.model ?? "",
                activeWorkspace: out.current_workspace_id
              };
            });
          } catch(e) {
            console.error("Failed to parse Niri outputs JSON: " + e);
          }
        }
      }
    }
  }

  // Layers stub (Niri handles layers differently via layer-shell, return empty object to prevent crashes)
  function updateLayers() {
    root.layers = {};
  }

  // Fetch workspaces from Niri
  Process {
    id: getWorkspaces
    command: ["niri", "msg", "--json", "workspaces"]
    stdout: StdioCollector {
      id: workspacesCollector
      onStreamFinished: {
        if (workspacesCollector?.text) {
          try {
            const rawWorkspaces = JSON.parse(workspacesCollector.text);
            const workspaces = rawWorkspaces.map(ws => ({
              id: ws.id,
              name: ws.name ?? String(ws.idx),
              monitor: ws.output,
              active: ws.is_active,
              focused: ws.is_focused
            })).sort((a, b) => a.id - b.id);

            root.workspaces = workspaces;
            root.special = []; // Niri doesn't have Hyprland special workspaces out of the box
            root.workspacesByMonitor = Functions.groupBy(root.workspaces, x => x.monitor);
            
            let byId = {};
            let activeWs = null;
            for (var i = 0; i < root.workspaces.length; ++i) {
              var ws = root.workspaces[i];
              byId[ws.id] = ws;
              if (ws.active || ws.focused) {
                activeWs = ws;
              }
            }
            root.workspaceById = byId;
            root.workspaceIds = root.workspaces.map(ws => ws.id);
            if (activeWs) {
              root.activeWorkspace = activeWs;
            }
          } catch(e) {
            console.error("Failed to parse Niri workspaces JSON: " + e);
          }
        }
      }
    }
  }
}
