import QtQuick
import QtQml.Models

// One list of the Files card (DockFilesCard.qml): the folder's FolderListModel (`source`),
// all of it, or while `active` only what was modified at or after `cutoff` (ms).
//
// A FolderListModel can sort but not filter, so the filter is a group: every row that passes
// is put in "keep" and the views show that group instead of everything. The order stays
// the folder model's own (name, date or type), and nothing is copied: rows come and go with
// the folder, and a change in how many there are (a file added, another folder opened)
// runs the check again, once, after the change has settled.
//
// The delegate is set by whoever uses it (a DelegateModel's delegate is what the view draws).
DelegateModel {
    id: root

    property var source: null
    property bool active: false
    property real cutoff: 0

    model: root.source
    filterOnGroup: root.active ? "keep" : "items"

    groups: [
        DelegateModelGroup {
            name: "keep"
            includeByDefault: false
        }
    ]

    function refilter() {
        if (!root.active)
            return
        const all = root.items
        const n = all.count
        for (let i = 0; i < n; i++) {
            const it = all.get(i)
            it.inKeep = Number(it.model.fileModified) >= root.cutoff
        }
    }

    onActiveChanged: Qt.callLater(root.refilter)
    onCutoffChanged: Qt.callLater(root.refilter)

    Connections {
        target: root.items

        function onCountChanged() {
            Qt.callLater(root.refilter)
        }
    }
}
