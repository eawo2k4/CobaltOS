// CobaltOS login splash (shown by KSplash while Plasma starts).
// Copied into the CobaltOS global theme at build time; images/logo.png is
// rendered from artwork/splash-logo.svg.
import QtQuick

Rectangle {
    id: root
    // KSplash sets this from 1 to 6 as the desktop starts up.
    property int stage: 0

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#0B1A3D" }
        GradientStop { position: 1.0; color: "#030817" }
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: logo.width
        height: logo.height + bar.anchors.topMargin + bar.height
        opacity: 0

        Image {
            id: logo
            source: "images/logo.png"
            width: Math.min(root.width * 0.42, 760)
            height: width * 200 / 760
            sourceSize.width: 1520
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // progress bar that fills as Plasma starts
        Rectangle {
            id: bar
            anchors.top: logo.bottom
            anchors.topMargin: logo.height * 0.45
            anchors.horizontalCenter: logo.horizontalCenter
            width: logo.width * 0.5
            height: Math.max(4, logo.height * 0.025)
            radius: height / 2
            color: "#1A2B57"

            Rectangle {
                height: parent.height
                radius: parent.radius
                color: "#7FD4FF"
                width: parent.width * Math.min(1, root.stage / 6)
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        NumberAnimation on opacity {
            from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic
        }
    }
}
