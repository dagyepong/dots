pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

Item {
    id: service

    property bool running: false
    property string backendState: "Stopped"
    property string tailnet: ""
    property string host: ""
    property var selfIPs: []
    property var peers: []

    function toggle() {
        if (running) {
            toggleProc.command = ["bash", "-c", "tailscale down"]
        } else {
            toggleProc.command = ["bash", "-c", "tailscale up"]
        }
        toggleProc.running = true
    }

    function copyIp(ip) {
        copyProc.command = ["bash", "-c", "echo -n " + ip + " | wl-copy || echo -n " + ip + " | xclip -selection clipboard"]
        copyProc.running = true
    }

    Process { id: toggleProc; onExited: service.poll() }
    Process { id: copyProc }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: service.poll()
    }

    function poll() {
        statusProc.running = true
    }

    Process {
        id: statusProc
        // Flatten output to a single line so SplitParser receives the complete JSON object at once
        command: ["bash", "-c", "tailscale status --json | tr -d '\\n'"]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    let json = JSON.parse(data);
                    service.backendState = json.BackendState || "Stopped";
                    service.running = (service.backendState === "Running");
                    service.tailnet = json.MagicDNSSuffix || "";
                    
                    if (json.Self) {
                        service.host = json.Self.HostName || "Self";
                        service.selfIPs = json.Self.TailscaleIPs || [];
                    }

                    let peerList = [];
                    if (json.Peer) {
                        let keys = Object.keys(json.Peer);
                        for (let i = 0; i < keys.length; i++) {
                            let p = json.Peer[keys[i]];
                            peerList.push({
                                host: p.HostName || "",
                                dns: p.DNSName ? p.DNSName.replace(/\.$/, "") : "",
                                online: p.Online || false,
                                ips: p.TailscaleIPs || []
                            });
                        }
                    }
                    service.peers = peerList;
                } catch(e) {
                    service.running = false;
                    service.backendState = "Stopped";
                    service.peers = [];
                    service.selfIPs = [];
                }
            }
        }
        
        onExited: (code) => {
            if (code !== 0) {
                service.running = false;
                service.backendState = "Stopped";
            }
        }
    }
}
