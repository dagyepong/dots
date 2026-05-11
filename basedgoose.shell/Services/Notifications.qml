pragma Singleton

import QtQuick 6.10
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property list<Notif> notifications: []
    property var activeNotifications: []
    
    readonly property int maxNotifications: 100
    readonly property int maxCachedNotifications: 50
    
    readonly property string notificationsCachePath: {
        var home = Quickshell.env("HOME")
        return home + "/.cache/basedgoose.shell/notifications.json"
    }
    
    FileView {
        id: persistenceFile
        path: root.notificationsCachePath
        
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        
        JsonAdapter {
            id: persist
            
            property var savedNotifications: []
            property bool dndState: false
        }
        
        Component.onCompleted: {
            reload()
        }
    }
    
    Connections {
        target: persistenceFile
        
        function onLoaded() {
            if (persist.savedNotifications && persist.savedNotifications.length > 0) {
                root.restoreNotifications()
            }
        }
    }
    
    property NotificationServer server: NotificationServer {
        Component.onCompleted: {
            console.log("[Notifs] Notification server ready")
        }
        
        onNotification: notif => {
            root.addNotification(notif)
        }
    }
    
    readonly property var recentNotifications: notifications.filter(n => {
        if (n.closed) return false;
        const hoursSinceNotif = (new Date().getTime() - n.timestamp.getTime()) / (1000 * 60 * 60);
        return hoursSinceNotif < 24;
    }).sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime())
    
    readonly property var groupedNotifications: {
        const groups = {}
        const active = activeNotifications
        for (let i = 0; i < active.length; i++) {
            const n = active[i]
            const key = n.appName || "Unknown"
            if (!groups[key]) {
                groups[key] = []
            }
            groups[key].push(n)
        }
        return groups
    }
    
    readonly property var notificationCounts: {
        const counts = {}
        const grouped = groupedNotifications
        for (let app in grouped) {
            counts[app] = grouped[app].length
        }
        return counts
    }
    
    property bool dnd: persist.dndState
    
    Timer {
        interval: 3600000
        repeat: true
        running: true
        triggeredOnStart: false
        
        onTriggered: {
            const oneDayAgo = new Date().getTime() - (24 * 60 * 60 * 1000)
            const oldCount = root.notifications.length
            root.notifications = root.notifications.filter(n =>
                n.timestamp.getTime() > oneDayAgo
            )
            root.refreshActiveNotifications()
        }
    }
    
    function addNotification(notif) {
        if (dnd && notif.urgency < 2) {
            return;
        }
        
        
        const notifWrapper = notifComponent.createObject(root, {
            notification: notif
        });
        
        root.notifications = [notifWrapper, ...root.notifications].slice(0, root.maxNotifications);
        root.refreshActiveNotifications();
        root.saveNotifications();
    }
    
    function toggleDnd() {
        persist.dndState = !persist.dndState;
        dnd = persist.dndState;
    }
    
    function clearAll() {
        notifications.forEach(n => {
            n.closed = true;
            if (n.notification && typeof n.notification.dismiss === 'function') {
                n.notification.dismiss();
            }
        });
        root.refreshActiveNotifications();
        root.notifications = [...root.notifications];
        root.saveNotifications();
    }
    
    function clearApp(appName) {
        notifications.filter(n => n.appName === appName).forEach(n => n.close());
    }

    function refreshActiveNotifications() {
        root.activeNotifications = root.notifications.filter(n => !n.closed);
    }
    
    function saveNotifications() {
        const notificationsToSave = root.notifications.slice(0, root.maxCachedNotifications);
        
        const saved = notificationsToSave.map(n => ({
            id: n.id,
            summary: n.summary,
            body: n.body,
            appName: n.appName,
            appIcon: n.appIcon,
            appImage: n.appImage,
            urgency: n.urgency,
            timestamp: n.timestamp.getTime(),
            closed: n.closed,
            dismissed: n.dismissed
        }));
        
        persist.savedNotifications = saved;
    }
    
    function restoreNotifications() {        
        const restored = [];
        for (let i = 0; i < persist.savedNotifications.length; i++) {
            const data = persist.savedNotifications[i];
            const notifObj = notifComponent.createObject(root, {
                notification: null,
                id: data.id,
                summary: data.summary,
                body: data.body,
                appName: data.appName,
                appIcon: data.appIcon,
                appImage: data.appImage,
                urgency: data.urgency,
                timestamp: new Date(data.timestamp),
                closed: data.closed,
                dismissed: true  // Mark as dismissed so they don't show as popups
            });
            restored.push(notifObj);
        }
        
        root.notifications = restored;
        root.refreshActiveNotifications();
        dnd = persist.dndState;
    }

    component Notif: QtObject {
        id: notifWrapper
        
        property var notification
        property date timestamp: new Date()
        property bool closed: false
        property bool dismissed: false
        property bool hasAnimated: false 
        
        property string id: ""
        property string summary: ""
        property string body: ""
        property string appName: ""
        property string appIcon: ""
        property string appImage: ""
        property int urgency: 0
        property list<var> actions: []
        
        property Timer autoCloseTimer: Timer {
            interval: 5000
            repeat: false
            running: !notifWrapper.closed && !notifWrapper.dismissed
            onTriggered: {
                notifWrapper.dismissPopup();
            }
        }
        
        readonly property string timeString: {
            const diff = new Date().getTime() - timestamp.getTime();
            const minutes = Math.floor(diff / 60000);
            const hours = Math.floor(minutes / 60);
            const days = Math.floor(hours / 24);
            
            if (days > 0) return days + "d ago";
            if (hours > 0) return hours + "h ago";
            if (minutes > 0) return minutes + "m ago";
            return "Just now";
        }
        
        readonly property Connections conn: Connections {
            target: notifWrapper.notification
            
            function onClosed() {
                notifWrapper.close();
            }
            
            function onSummaryChanged() {
                notifWrapper.summary = notifWrapper.notification.summary;
            }
            
            function onBodyChanged() {
                notifWrapper.body = notifWrapper.notification.body;
            }
            
            function onAppNameChanged() {
                notifWrapper.appName = notifWrapper.notification.appName;
            }
            
            function onAppIconChanged() {
                notifWrapper.appIcon = notifWrapper.notification.appIcon;
            }
            
            function onImageChanged() {
                notifWrapper.appImage = notifWrapper.notification.image;
            }
            
            function onUrgencyChanged() {
                notifWrapper.urgency = notifWrapper.notification.urgency;
            }
            
            function onActionsChanged() {
                notifWrapper.actions = notifWrapper.notification.actions.map(a => ({
                    identifier: a.identifier,
                    text: a.text,
                    invoke: () => a.invoke()
                }));
            }
        }
        
        function dismissPopup() {
            if (dismissed) return;
            dismissed = true;
            root.refreshActiveNotifications();
        }
        
        function close() {
            if (closed) return;
            
            closed = true;
            
            if (notification && typeof notification.dismiss === 'function') {
                notification.dismiss();
            }
            
            root.refreshActiveNotifications();
        }
        
        function invokeAction(actionId) {
            const action = actions.find(a => a.identifier === actionId);
            if (action && action.invoke) {
                action.invoke();
            }
        }
        
        Component.onCompleted: {
            if (!notification)
                return;
            
            id = notification.id;
            summary = notification.summary;
            body = notification.body;
            appName = notification.appName;
            appIcon = notification.appIcon;
            appImage = notification.image;
            urgency = notification.urgency;
            actions = notification.actions.map(a => ({
                identifier: a.identifier,
                text: a.text,
                invoke: () => {
                    if (typeof a.invoke === 'function') {
                        a.invoke()
                    }
                }
            }));
        }
    }
    
    Component {
        id: notifComponent
        
        Notif {}
    }
    
    function deleteNotification(notif) {
        if (root.notifications.includes(notif)) {
            root.notifications = root.notifications.filter(n => n !== notif);
            if (notif.notification && typeof notif.notification.dismiss === 'function') {
                notif.notification.dismiss();
            }
            notif.destroy();
            root.refreshActiveNotifications();
            root.saveNotifications();
        }
    }
}