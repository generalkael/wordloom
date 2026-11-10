import QtQuick
import QtQuick.Layouts
import com.wordloom.app

// The icon for a binder item kind / section root, drawn from bundled SVGs
// (emoji depend on the system's fonts and don't render everywhere). An
// item's own icon and colour (`icon`, `tint`; Icon & Colour… in the binder)
// come from the Icons set instead.
Image {
    property string kind: ""
    property string role: ""
    property string icon: ""     // a name in Icons.set; "" = the kind's own
    property string tint: ""     // "#rrggbb"; "" = the icon's own colours
    property int size: 16
    readonly property bool custom: (icon !== "" && Icons.set[icon] !== undefined) || tint !== ""
    source: custom ? Icons.url(icon && Icons.set[icon] ? icon : Icons.defaultFor(kind, role), tint) : Theme.kindIcon(kind, role)
    sourceSize.width: size
    sourceSize.height: size
    width: size
    height: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    fillMode: Image.PreserveAspectFit
    smooth: true
}
