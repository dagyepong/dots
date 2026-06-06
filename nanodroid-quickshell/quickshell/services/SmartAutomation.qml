pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Smart Automation Service — handles DND and scheduled notifications.
 */
Singleton {
    id: root

    // --- State ---
    property bool dndActive: false
    property bool scheduleDndActive: false
    property bool pomodoroDndActive: PomodoroService.active && PomodoroService.mode === 0

    // Apply DND state to Notifications service
    readonly property bool shouldBeDnd: scheduleDndActive || pomodoroDndActive
    onShouldBeDndChanged: {
        Notifications.silent = shouldBeDnd;
        root.dndActive = shouldBeDnd;
    }

    // --- Notifications only for Schedule DND ---
    onScheduleDndActiveChanged: {
        if (scheduleDndActive) {
            sendNotification("Scheduled Focus Active", "Do Not Disturb has been enabled for your event.");
        } else if (!pomodoroDndActive) {
            sendNotification("Scheduled Focus Ended", "Do Not Disturb has been disabled.");
        }
    }

    // --- Main Automation Timer ---
    Timer {
        id: mainTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: runAutomationCycle()
    }

    function runAutomationCycle() {
        const now = new Date();
        const nowDateStr = Qt.formatDate(now, "yyyy-MM-dd");
        
        let anyEventActive = false;
        let expiredEventIds = [];

        ScheduleService.events.forEach(event => {
            // 2. Recurrence / Day Check
            let isEventDay = (event.date === nowDateStr);
            if (event.recurrence === "daily") isEventDay = true;
            else if (event.recurrence === "weekly") {
                const eventDate = new Date(event.date + "T00:00:00");
                isEventDay = (eventDate.getDay() === now.getDay());
            } else if (event.recurrence === "monthly") {
                const eventDate = new Date(event.date + "T00:00:00");
                isEventDay = (eventDate.getDate() === now.getDate());
            }

            if (!isEventDay) return;

            // 3. Time Check
            const eventStart = new Date(nowDateStr + "T" + event.time);
            const eventEnd = event.endTime 
                ? new Date(nowDateStr + "T" + event.endTime) 
                : new Date(eventStart.getTime() + 3600000);
            
            // 4. DND Active Check
            if (event.focus && now >= eventStart && now < eventEnd) {
                anyEventActive = true;
            }

            // 5. Notification Logic
            const diffMs = eventStart.getTime() - now.getTime();
            const diffHours = diffMs / 3600000;

            // 00:00 (Today) Notif
            const lastNotified00 = event.lastNotified00Date || "";
            if (lastNotified00 !== nowDateStr) {
                sendNotification("Today's Schedule", `Upcoming event: ${event.title} at ${event.time}`);
                ScheduleService.updateEvent(event.id, { lastNotified00Date: nowDateStr });
            }

            // 1h Before Notif
            const lastNotified1h = event.lastNotified1hDate || "";
            if (diffHours > 0 && diffHours <= 1.0 && lastNotified1h !== nowDateStr) {
                sendNotification("Starting Soon", `${event.title} starts in 1 hour (${event.time})`);
                ScheduleService.updateEvent(event.id, { lastNotified1hDate: nowDateStr });
            }

            // 6. Expiry Check (Auto-delete "once" events)
            if (event.recurrence === "once") {
                if (now.getTime() > (eventEnd.getTime() + 30000)) {
                    expiredEventIds.push(event.id);
                }
            }
        });

        // Apply DND State
        if (root.scheduleDndActive !== anyEventActive) {
            root.scheduleDndActive = anyEventActive;
        }

        // Cleanup Expired Events
        expiredEventIds.forEach(id => {

            ScheduleService.deleteEvent(id);
        });
    }

    function sendNotification(title, body) {
        const iconPath = Directories.home.replace("file://", "") + "/.config/quickshell/nandoroid/assets/icons/asura-shell.svg";
        const cmd = [
            "notify-send",
            "-a", "Asura Shell",
            "-i", iconPath,
            title,
            body
        ];
        Quickshell.execDetached(cmd);
    }

    Component.onCompleted: {
        Qt.callLater(() => runAutomationCycle());
    }
}
