import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../Commons" as Commons

Rectangle {
    id: root
    
    property color dividerColor: Commons.Theme.surfaceBorder
    property real dividerOpacity: Commons.Theme.dividerOpacity
    property int thickness: 1
    property bool vertical: false
    
    opacity: root.dividerOpacity
    
    Layout.fillWidth: !root.vertical
    Layout.fillHeight: root.vertical
    Layout.preferredHeight: root.vertical ? -1 : root.thickness
    Layout.preferredWidth: root.vertical ? root.thickness : -1
    
    implicitWidth: root.vertical ? root.thickness : 100
    implicitHeight: root.vertical ? 100 : root.thickness
    
    color: root.dividerColor
}
