import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "cursor-highlight"

    // The daemon surface owns the on/off state; the pill is just a remote for
    // it. Appearance settings come from pluginData, shared by both surfaces.
    readonly property var daemonInstance: pluginService && pluginService.pluginDaemonInstances ? pluginService.pluginDaemonInstances[pluginId] : null
    readonly property bool highlightActive: daemonInstance ? daemonInstance.active : false
    readonly property string highlightStyle: pluginData.style || "ring"

    readonly property var styleOptions: [
        {
            "value": "ring",
            "label": "Ring"
        },
        {
            "value": "dot",
            "label": "Dot"
        },
        {
            "value": "arrow",
            "label": "Arrow"
        }
    ]

    function settingValue(key, fallback) {
        const stored = pluginData[key];
        return stored !== undefined ? stored : fallback;
    }

    // Writes through PluginService so the daemon, the settings panel, and every
    // other bar instance all see the change
    function saveSetting(key, value) {
        if (pluginService && pluginService.savePluginData)
            pluginService.savePluginData(pluginId, key, value);
    }

    // PluginComponent's own triggerPopout() hands off to pillClickAction when
    // one is set, and its popout is private to that file, so the menu gets its
    // own PluginPopout positioned the same way triggerPopout does.
    function openStyleMenu() {
        const globalPos = root.mapToItem(null, 0, 0);
        const currentScreen = root.parentScreen || Screen;
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, root.width, root.barSpacing, barPosition, root.barConfig);
        styleMenu.setTriggerPosition(pos.x, pos.y, pos.width, root.section, currentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
        styleMenu.toggle();
    }

    pillClickAction: () => {
        if (root.daemonInstance)
            root.daemonInstance.toggle();
    }

    pillRightClickAction: () => root.openStyleMenu()

    // Draws a highlight style - ring, dot, or the same arrowhead the overlay
    // uses - so both the pill and the menu show the real shape. When struck,
    // the shape is crossed corner to corner the way Material's own "_off"
    // icons are: a gap is cleared out of the shape first, then the line is
    // drawn inside it. The gap is punched rather than painted so it shows
    // whatever is behind, which keeps it right in any theme. The slash runs
    // diagonally because a horizontal one splits the filled dot and arrow into
    // fragments that stop reading as their own style.
    component StyleGlyph: Canvas {
        id: glyph

        property color iconColor: Theme.surfaceText
        property string shape: "ring"
        property bool struck: false
        property real glyphSize: 20
        readonly property real stroke: Math.max(1.5, glyphSize * 0.1)

        width: glyphSize
        height: glyphSize
        implicitWidth: width
        implicitHeight: height

        // Canvas only repaints on resize by itself
        onIconColorChanged: requestPaint()
        onShapeChanged: requestPaint()
        onStruckChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const s = width;
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.fillStyle = iconColor;
            ctx.strokeStyle = iconColor;

            ctx.save();
            if (shape === "dot") {
                ctx.beginPath();
                ctx.arc(s / 2, s / 2, s * 0.3, 0, Math.PI * 2);
                ctx.fill();
            } else if (shape === "arrow") {
                // Same path and 23 degree lean as the overlay's arrowhead,
                // scaled to the icon box and centred on its rotated bounds,
                // then nudged 2px right: the shape's visual mass sits left of
                // its bounds centre, so true centring reads as leaning left
                const a = s * 0.95;
                ctx.translate(s / 2 - a * 0.331 + 2, s / 2 - a * 0.483);
                ctx.rotate(23 * Math.PI / 180);
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(a * 0.9, a * 0.35);
                ctx.lineTo(a * 0.55, a * 0.55);
                ctx.lineTo(a * 0.35, a * 0.9);
                ctx.closePath();
                ctx.fill();
            } else {
                ctx.beginPath();
                ctx.arc(s / 2, s / 2, s * 0.34, 0, Math.PI * 2);
                ctx.lineWidth = stroke;
                ctx.stroke();
            }
            ctx.restore();

            if (!struck)
                return;

            // Bottom-left to top-right
            ctx.beginPath();
            ctx.moveTo(s * 0.03, s * 0.97);
            ctx.lineTo(s * 0.97, s * 0.03);

            ctx.globalCompositeOperation = "destination-out";
            ctx.lineWidth = stroke * 2.6;
            ctx.stroke();

            ctx.globalCompositeOperation = "source-over";
            ctx.lineWidth = stroke;
            ctx.stroke();
        }
    }

    // Slider wired straight to a plugin setting. Mirrors what SliderSetting
    // does in the settings panel, minus its PluginSettings ancestor lookup.
    component SettingSlider: Column {
        id: ctl

        property string settingKey: ""
        property string label: ""
        property int defaultValue: 0
        property int minimum: 0
        property int maximum: 100
        property string rightIcon: ""
        property string unit: ""

        readonly property int currentValue: root.settingValue(ctl.settingKey, ctl.defaultValue)

        width: parent.width
        spacing: Theme.spacingXS

        // DankSlider assigns its own value while dragging, which breaks any
        // binding on it. Push the stored value back in whenever it changes, so
        // switching style - which repoints settingKey at a different stored
        // value - still moves the handle.
        onCurrentValueChanged: slider.value = ctl.currentValue

        StyledText {
            text: ctl.label
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DankSlider {
            id: slider

            width: parent.width
            value: ctl.currentValue
            minimum: ctl.minimum
            maximum: ctl.maximum
            rightIcon: ctl.rightIcon
            unit: ctl.unit
            wheelEnabled: false
            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
            onSliderValueChanged: newValue => root.saveSetting(ctl.settingKey, newValue)
        }
    }

    component Divider: Rectangle {
        width: parent.width
        height: 1
        color: Theme.withAlpha(Theme.outline, 0.3)
    }

    Component {
        id: stylePill

        StyleGlyph {
            glyphSize: root.iconSize
            shape: root.highlightStyle
            struck: !root.highlightActive
            iconColor: root.highlightActive ? Theme.primary : Theme.surfaceText
        }
    }

    horizontalBarPill: stylePill

    verticalBarPill: stylePill

    PluginPopout {
        id: styleMenu

        // Set outright rather than left to PluginPopout's default, which builds
        // it from a layerNamespacePlugin that is only in scope inside
        // PluginComponent's own file
        layerNamespace: "dms:plugins:cursor-highlight"
        contentWidth: 300

        pluginContent: Component {
            PopoutComponent {
                id: menu

                headerText: "Cursor Highlight"
                showCloseButton: true
                spacing: Theme.spacingS

                Repeater {
                    model: root.styleOptions

                    StyledRect {
                        id: styleRow

                        required property var modelData

                        readonly property bool isCurrent: styleRow.modelData.value === root.highlightStyle

                        width: menu.width
                        height: 40
                        radius: Theme.cornerRadius
                        color: styleRow.isCurrent ? Theme.primarySelected : (rowArea.containsMouse ? Theme.surfaceContainerHigh : "transparent")

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            StyleGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                glyphSize: Theme.iconSize
                                shape: styleRow.modelData.value
                                iconColor: styleRow.isCurrent ? Theme.primary : Theme.surfaceText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: styleRow.modelData.label
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: styleRow.isCurrent ? Font.Medium : Font.Normal
                                color: styleRow.isCurrent ? Theme.primary : Theme.surfaceText
                            }
                        }

                        DankIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: styleRow.isCurrent
                            name: "check"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveSetting("style", styleRow.modelData.value)
                        }
                    }
                }

                Divider {}

                StyledText {
                    text: "Saved separately for each style"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                SettingSlider {
                    settingKey: root.highlightStyle + "Size"
                    label: root.highlightStyle === "arrow" ? "Length" : "Size"
                    defaultValue: 28
                    minimum: 8
                    maximum: 100
                    unit: "px"
                    rightIcon: "radio_button_unchecked"
                }

                SettingSlider {
                    visible: root.highlightStyle === "ring"
                    settingKey: "ringThickness"
                    label: "Ring Thickness"
                    defaultValue: 4
                    minimum: 1
                    maximum: 20
                    unit: "px"
                    rightIcon: "line_weight"
                }

                SettingSlider {
                    settingKey: root.highlightStyle + "OffsetX"
                    label: "Offset X"
                    defaultValue: 0
                    minimum: -100
                    maximum: 100
                    unit: "px"
                    rightIcon: "swap_horiz"
                }

                SettingSlider {
                    settingKey: root.highlightStyle + "OffsetY"
                    label: "Offset Y"
                    defaultValue: 0
                    minimum: -100
                    maximum: 100
                    unit: "px"
                    rightIcon: "swap_vert"
                }

                Item {
                    width: parent.width
                    height: rainbowToggle.height

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Rainbow Mode"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }

                    DankToggle {
                        id: rainbowToggle

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.settingValue(root.highlightStyle + "Rainbow", false)
                        onToggled: isChecked => root.saveSetting(root.highlightStyle + "Rainbow", isChecked)
                    }
                }

                SettingSlider {
                    visible: root.settingValue(root.highlightStyle + "Rainbow", false)
                    settingKey: root.highlightStyle + "RainbowSpeed"
                    label: "Flash Speed"
                    defaultValue: 5
                    minimum: 1
                    maximum: 10
                    rightIcon: "speed"
                }

                Divider {}

                Item {
                    width: parent.width
                    height: 36

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Color"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }

                    Rectangle {
                        id: swatch

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        height: 28
                        radius: Theme.cornerRadius
                        color: root.settingValue(root.highlightStyle + "Color", Theme.primary)
                        border.color: Theme.outlineStrong
                        border.width: 2

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!PopoutService || !PopoutService.colorPickerModal)
                                    return;
                                // Stored as a hex string; pluginData round-trips
                                // through JSON, which a color value would not
                                const key = root.highlightStyle + "Color";
                                PopoutService.colorPickerModal.selectedColor = swatch.color;
                                PopoutService.colorPickerModal.pickerTitle = "Highlight Color";
                                PopoutService.colorPickerModal.onColorSelectedCallback = selected => root.saveSetting(key, selected.toString());
                                PopoutService.colorPickerModal.show();
                            }
                        }
                    }
                }
            }
        }
    }
}
