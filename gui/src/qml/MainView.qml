import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

// Rift Play home screen: console-style launcher (horizontal tile row,
// details + actions underneath, controller hints at the bottom).
Pane {
    id: consolePane
    padding: 0

    readonly property color accentA: "#7cf3ff"
    readonly property color accentB: "#b48cff"
    readonly property color accentC: "#ff7ad9"
    readonly property var selectedHost: hostsView.currentItem && hostsView.currentItem.visible ? hostsView.currentItem.host : null
    readonly property int visibleHostCount: {
        let n = 0;
        for (let i = 0; i < Chiaki.hosts.length; ++i)
            if (Chiaki.hosts[i].display)
                n++;
        return n;
    }

    function stateText(host) {
        if (!host)
            return "";
        if (host.duid)
            return host.discovered ? qsTr("Ready to register") : qsTr("Available via PSN");
        if (!host.discovered)
            return host.registered ? qsTr("Offline · press △ to wake up") : qsTr("Not found on network");
        if (host.state === "standby")
            return qsTr("Rest mode");
        if (host.state === "ready")
            return qsTr("On");
        return host.state;
    }

    function stateColor(host) {
        if (!host || !host.discovered)
            return "#6b7280";
        if (host.state === "standby")
            return "#f5a524";
        return "#2fd47a";
    }

    function moveSelection(step) {
        if (!hostsView.count)
            return;
        for (let i = 0; i < hostsView.count; i++) {
            if (step > 0)
                hostsView.incrementCurrentIndex();
            else
                hostsView.decrementCurrentIndex();
            if (hostsView.currentItem && hostsView.currentItem.visible)
                break;
        }
    }

    StackView.onActivated: {
        forceActiveFocus(Qt.TabFocusReason);
        if(!Chiaki.autoConnect && !root.initialAsk && !Chiaki.window.directStream)
        {
            root.initialAsk = true;
            if(Chiaki.settings.addSteamShortcutAsk && (typeof Chiaki.createSteamShortcut === "function"))
                root.showRemindDialog(qsTr("Add to Steam"), qsTr("Would you like to add Rift Play to Steam as a non-Steam game\n(or update an existing shortcut) with artwork and controller layout?") + "\n\n" + qsTr("(You can do this later from the main menu by pressing L3.)"), false, () => root.showSteamShortcutDialog(true));
            else if(Chiaki.settings.remotePlayAsk)
            {
                if(!Chiaki.settings.psnRefreshToken || !Chiaki.settings.psnAuthToken || !Chiaki.settings.psnAuthTokenExpiry || !Chiaki.settings.psnAccountId)
                    root.showRemindDialog(qsTr("Remote Play via PSN"), qsTr("Would you like to connect to PSN?\nThis enables:\n- Automatic registration\n- Playing outside of your home network without port forwarding?") + "\n\n" + qsTr("(Note: If you select no now and want to do this later, go to the Config section of the settings.)"), true, () => root.showPSNTokenDialog(false));
                else
                    Chiaki.settings.remotePlayAsk = false;
            }
        }
    }

    Keys.onLeftPressed: moveSelection(-1)
    Keys.onRightPressed: moveSelection(1)
    Keys.onUpPressed: moveSelection(-1)
    Keys.onDownPressed: moveSelection(1)
    Keys.onMenuPressed: root.showSettingsDialog()
    Keys.onReturnPressed: if (hostsView.currentItem && hostsView.currentItem.visible) hostsView.currentItem.connectToHost()
    Keys.onYesPressed: if (hostsView.currentItem && hostsView.currentItem.visible) hostsView.currentItem.wakeUpHost()
    Keys.onNoPressed: if (hostsView.currentItem && hostsView.currentItem.visible) hostsView.currentItem.deleteHost()
    Keys.onEscapePressed: root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit())
    Keys.onPressed: (event) => {
        if (event.modifiers)
            return;
        switch (event.key) {
        case Qt.Key_PageUp:
            if (hostsView.currentItem && hostsView.currentItem.visible) hostsView.currentItem.setConsolePin();
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            if (Chiaki.settings.psnAuthToken) Chiaki.refreshPsnToken();
            event.accepted = true;
            break;
        case Qt.Key_F1:
            if (typeof Chiaki.createSteamShortcut === "function") root.showSteamShortcutDialog(false);
            event.accepted = true;
            break;
        case Qt.Key_F2:
            root.showManualHostDialog();
            event.accepted = true;
            break;
        }
    }

    // ---------- Background ----------
    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#151233" }
            GradientStop { position: 0.55; color: "#0b0a1d" }
            GradientStop { position: 1.0; color: "#050409" }
        }

        // soft ambient glows (radial-gradient images, slowly breathing)
        Repeater {
            model: [
                { src: "violet", s: 1.15, x: -0.25, y: -0.55, o: 0.32 },
                { src: "cyan",   s: 0.85, x: 0.55,  y: -0.45, o: 0.22 },
                { src: "pink",   s: 0.75, x: 0.05,  y: 0.45,  o: 0.16 }
            ]
            Image {
                required property var modelData
                required property int index
                source: "qrc:/icons/riftplay-glow-" + modelData.src + ".svg"
                width: consolePane.width * modelData.s
                height: width
                sourceSize: Qt.size(256, 256)
                smooth: true
                x: consolePane.width * modelData.x
                y: consolePane.height * modelData.y
                opacity: modelData.o
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: modelData.o * 1.35; duration: 4500 + index * 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: modelData.o * 0.75; duration: 4500 + index * 900; easing.type: Easing.InOutSine }
                }
            }
        }

        // micro-texture of tiny PlayStation-style symbols (like the controller's
        // grip texture): one tiled image, almost invisible unless you look closely
        Image {
            anchors.fill: parent
            source: "qrc:/icons/shape-texture.svg"
            sourceSize: Qt.size(72, 72)
            fillMode: Image.Tile
            smooth: true
            opacity: 0.05
        }

        // flowing particle ribbons (separate file: if the Particles module is
        // missing the Loader simply stays empty and the home still works)
        Loader {
            anchors.fill: parent
            source: Chiaki.settings.animatedBackground ? "RiftBackground.qml" : ""
            onLoaded: item.running = Qt.binding(() => consolePane.visible && Qt.application.state === Qt.ApplicationActive)
        }

    }

    // ---------- Top bar ----------
    Item {
        id: topBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 22
            leftMargin: 44
            rightMargin: 44
        }
        height: 64

        RowLayout {
            anchors.fill: parent
            spacing: 18

            Image {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                sourceSize: Qt.size(92, 92)
                source: "qrc:/icons/chiaking.svg"
            }

            Label {
                text: "Rift Play"
                font.pixelSize: 30
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                color: "white"
            }

            Rectangle {
                Layout.leftMargin: 18
                Layout.preferredHeight: 38
                Layout.preferredWidth: consolesTab.implicitWidth + 36
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.12)
                Label {
                    id: consolesTab
                    anchors.centerIn: parent
                    text: qsTr("Consoles")
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    color: "white"
                }
            }

            Item { Layout.fillWidth: true }

            TopBarButton {
                visible: !!Chiaki.settings.psnAuthToken
                iconSource: "qrc:/icons/r1.svg"
                text: qsTr("Refresh PSN")
                onClicked: Chiaki.refreshPsnToken()
            }

            TopBarButton {
                iconSource: "qrc:/icons/add-24px.svg"
                text: qsTr("Add console")
                onClicked: root.showManualHostDialog()
            }

            TopBarButton {
                iconSource: "qrc:/icons/discover-" + (Chiaki.discoveryEnabled ? "" : "off-") + "24px.svg"
                text: Chiaki.discoveryEnabled ? qsTr("Searching") : qsTr("Search off")
                onClicked: Chiaki.discoveryEnabled = !Chiaki.discoveryEnabled
            }

            TopBarButton {
                iconSource: "qrc:/icons/settings-20px.svg"
                onClicked: root.showSettingsDialog()
            }

            Label {
                id: clockLabel
                Layout.leftMargin: 10
                font.pixelSize: 26
                font.weight: Font.Medium
                color: "white"
                text: Qt.formatTime(new Date(), "HH:mm")
                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    onTriggered: clockLabel.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }
        }
    }

    // ---------- Console tiles ----------
    ListView {
        id: hostsView
        anchors {
            top: topBar.bottom
            topMargin: consolePane.height * 0.07
            left: parent.left
            right: parent.right
        }
        height: 300
        orientation: ListView.Horizontal
        leftMargin: 44
        rightMargin: 44
        spacing: 26
        clip: false
        keyNavigationWraps: true
        highlightMoveDuration: 220
        preferredHighlightBegin: 44
        preferredHighlightEnd: 44 + 300
        highlightRangeMode: ListView.ApplyRange
        interactive: true
        model: Chiaki.hosts
        visible: consolePane.visibleHostCount > 0
        onCountChanged: {
            if(!hostsView.currentItem)
                hostsView.incrementCurrentIndex();
            if(!hostsView.currentItem)
                return;
            if(!hostsView.currentItem.visible)
                consolePane.moveSelection(1);
        }

        delegate: Item {
            id: delegate
            readonly property var host: modelData
            readonly property bool selected: ListView.isCurrentItem
            visible: modelData.display
            width: modelData.display ? 260 : 0
            height: 300

            function connectToHost() {
                if(modelData.discovered)
                    Chiaki.connectToHost(index, modelData.name);
                else
                    Chiaki.connectToHost(index);
            }

            function wakeUpHost() {
                if(!modelData.discovered && !modelData.duid)
                    Chiaki.wakeUpHost(index);
            }

            function deleteHost() {
                if (modelData.manual)
                    root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"), () => {Chiaki.deleteHost(index)});
                else if (modelData.discovered && !modelData.registered)
                    root.showConfirmDialog(qsTr("Hide Console"), qsTr("Are you sure you want to hide this console?") + "\n\n" + qsTr("Note: You can unhide from the Consoles section of the Settings under Hidden Consoles"), () => Chiaki.hideHost(modelData.mac, modelData.name));
            }

            function setConsolePin() {
                root.showConsolePinDialog(index);
            }

            Rectangle {
                id: tile
                anchors.centerIn: parent
                width: 240
                height: 240
                radius: 26
                scale: delegate.selected ? 1.12 : 0.92
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: delegate.selected ? "#2a2560" : "#1b1838" }
                    GradientStop { position: 1.0; color: delegate.selected ? "#14122e" : "#100e22" }
                }
                border.width: delegate.selected ? 4 : 1
                border.color: delegate.selected ? "white" : Qt.rgba(1, 1, 1, 0.10)

                // selection glow ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -10
                    radius: parent.radius + 10
                    color: "transparent"
                    border.width: 6
                    border.color: consolePane.accentB
                    opacity: delegate.selected ? 0.35 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }

                Image {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: 26
                    }
                    width: 150
                    height: 150
                    fillMode: Image.PreserveAspectFit
                    source: "image://svg/console-ps" + (modelData.ps5 ? "5" : "4") + (modelData.state == "standby" ? "#light_standby" : "#light_on")
                    sourceSize: Qt.size(width, height)
                    opacity: modelData.discovered || modelData.duid ? 1 : 0.45
                }

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 22
                    }
                    spacing: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: consolePane.stateColor(modelData)
                    }
                    Label {
                        text: modelData.ps5 ? "PS5" : "PS4"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (hostsView.currentIndex === index)
                            delegate.connectToHost();
                        else
                            hostsView.currentIndex = index;
                    }
                }
            }
        }
    }

    // ---------- Selected console details ----------
    ColumnLayout {
        id: details
        visible: consolePane.selectedHost !== null
        anchors {
            top: hostsView.bottom
            topMargin: 34
            left: parent.left
            right: parent.right
            leftMargin: 56
            rightMargin: 56
        }
        spacing: 10

        Label {
            Layout.fillWidth: true
            text: consolePane.selectedHost ? (consolePane.selectedHost.name || qsTr("PlayStation")) : ""
            font.pixelSize: 46
            font.weight: Font.Bold
            color: "white"
            elide: Text.ElideRight
        }

        RowLayout {
            spacing: 14
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: consolePane.stateColor(consolePane.selectedHost)
            }
            Label {
                text: {
                    const h = consolePane.selectedHost;
                    if (!h)
                        return "";
                    let parts = [consolePane.stateText(h)];
                    if (h.registered)
                        parts.push(qsTr("Registered"));
                    if (h.manual)
                        parts.push(qsTr("Manual"));
                    if (h.address && !Chiaki.settings.streamerMode && !h.duid)
                        parts.push(h.address);
                    return parts.join("   ·   ");
                }
                font.pixelSize: 20
                color: Qt.rgba(1, 1, 1, 0.7)
            }
        }

        Label {
            visible: !!(consolePane.selectedHost && consolePane.selectedHost.discovered && consolePane.selectedHost.app)
            text: consolePane.selectedHost && consolePane.selectedHost.app ? qsTr("Now playing: %1").arg(consolePane.selectedHost.app) : ""
            font.pixelSize: 20
            color: consolePane.accentA
        }

        RowLayout {
            Layout.topMargin: 20
            spacing: 16

            ActionButton {
                primary: true
                text: consolePane.selectedHost && !consolePane.selectedHost.registered && !consolePane.selectedHost.duid ? qsTr("Register") : qsTr("Play")
                glyph: root.controllerButton("cross")
                onClicked: if (hostsView.currentItem) hostsView.currentItem.connectToHost()
            }

            ActionButton {
                visible: !!(consolePane.selectedHost && consolePane.selectedHost.registered && !consolePane.selectedHost.duid && !consolePane.selectedHost.discovered)
                text: qsTr("Wake up")
                glyph: root.controllerButton("pyramid")
                onClicked: if (hostsView.currentItem) hostsView.currentItem.wakeUpHost()
            }

            ActionButton {
                visible: !!(consolePane.selectedHost && consolePane.selectedHost.registered)
                text: qsTr("Console PIN")
                glyph: "qrc:/icons/l1.svg"
                onClicked: if (hostsView.currentItem) hostsView.currentItem.setConsolePin()
            }

            ActionButton {
                visible: !!(consolePane.selectedHost && (consolePane.selectedHost.manual || (consolePane.selectedHost.discovered && !consolePane.selectedHost.registered)))
                text: consolePane.selectedHost && consolePane.selectedHost.manual ? qsTr("Delete") : qsTr("Hide")
                glyph: root.controllerButton("box")
                onClicked: if (hostsView.currentItem) hostsView.currentItem.deleteHost()
            }
        }
    }

    // ---------- Empty state ----------
    ColumnLayout {
        visible: consolePane.visibleHostCount === 0
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 760)
        spacing: 18

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 150
            Layout.preferredHeight: 150
            sourceSize: Qt.size(300, 300)
            source: "image://svg/console-ps5#light_standby"
            fillMode: Image.PreserveAspectFit
            opacity: 0.6
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: Chiaki.discoveryEnabled
                NumberAnimation { to: 0.25; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.7; duration: 1100; easing.type: Easing.InOutSine }
            }
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Chiaki.discoveryEnabled ? qsTr("Looking for your PlayStation…") : qsTr("No consoles yet")
            font.pixelSize: 36
            font.weight: Font.Bold
            color: "white"
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Turn on your PS5 or PS4 and make sure it is on the same Wi‑Fi network.\nYou can also add it by IP address or sign in to PSN to play from anywhere.")
            font.pixelSize: 20
            color: Qt.rgba(1, 1, 1, 0.65)
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            spacing: 16
            ActionButton {
                primary: true
                text: qsTr("Add by IP")
                glyph: "qrc:/icons/r3.svg"
                onClicked: root.showManualHostDialog()
            }
            ActionButton {
                visible: !Chiaki.settings.psnAuthToken
                text: qsTr("Sign in to PSN")
                onClicked: root.showPSNTokenDialog(false)
            }
            ActionButton {
                visible: !Chiaki.discoveryEnabled
                text: qsTr("Search network")
                onClicked: Chiaki.discoveryEnabled = true
            }
        }
    }

    // ---------- Bottom hint bar ----------
    Rectangle {
        id: hintBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 64
        color: Qt.rgba(0, 0, 0, 0.35)

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 44
                rightMargin: 44
            }
            spacing: 34

            Hint {
                glyph: root.controllerButton("cross")
                text: consolePane.selectedHost && !consolePane.selectedHost.registered && !consolePane.selectedHost.duid ? qsTr("Register") : qsTr("Play")
                visible: consolePane.selectedHost !== null
            }
            Hint {
                glyph: root.controllerButton("pyramid")
                text: qsTr("Wake up")
                visible: !!(consolePane.selectedHost && consolePane.selectedHost.registered && !consolePane.selectedHost.duid && !consolePane.selectedHost.discovered)
            }
            Hint { glyph: "qrc:/icons/options.svg"; text: qsTr("Settings") }
            Hint { glyph: "qrc:/icons/r3.svg"; text: qsTr("Add console") }
            Hint { glyph: "qrc:/icons/l3.svg"; text: qsTr("Add to Steam"); visible: typeof Chiaki.createSteamShortcut === "function" }

            Item { Layout.fillWidth: true }

            Label {
                text: "v" + Qt.application.version
                font.pixelSize: 16
                color: Qt.rgba(1, 1, 1, 0.4)
            }
        }
    }

    // ---------- Inline components ----------
    component TopBarButton: Button {
        id: tbb
        property string iconSource
        flat: true
        focusPolicy: Qt.NoFocus
        Layout.preferredHeight: 52
        icon.source: iconSource
        icon.width: 28
        icon.height: 28
        icon.color: "white"
        font.pixelSize: 18
        font.capitalization: Font.MixedCase
        leftPadding: 14
        rightPadding: text ? 18 : 14
        Material.roundedScale: Material.FullScale
        Material.foreground: "white"
    }

    component ActionButton: Button {
        id: ab
        property bool primary: false
        property string glyph
        focusPolicy: Qt.NoFocus
        Layout.preferredHeight: 60
        leftPadding: glyph ? 58 : 30
        rightPadding: 30
        font.pixelSize: 20
        font.weight: Font.DemiBold
        font.capitalization: Font.MixedCase
        Material.roundedScale: Material.FullScale
        Material.background: primary ? "white" : Qt.rgba(1, 1, 1, 0.12)
        Material.foreground: primary ? "#0b0a1d" : "white"
        Material.elevation: 0

        Rectangle {
            visible: !!ab.glyph
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
            width: 34
            height: 34
            radius: 17
            color: ab.primary ? "#0b0a1d" : "transparent"
            Image {
                anchors.centerIn: parent
                width: 26
                height: 26
                sourceSize: Qt.size(52, 52)
                source: ab.glyph
            }
        }
    }

    component Hint: RowLayout {
        id: hint
        property string glyph
        property string text
        spacing: 10
        Image {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            sourceSize: Qt.size(52, 52)
            source: hint.glyph
        }
        Label {
            text: hint.text
            font.pixelSize: 17
            color: Qt.rgba(1, 1, 1, 0.8)
        }
    }
}
