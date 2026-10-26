import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "cursorHighlight"

    readonly property var daemonInstance: pluginService && pluginService.pluginDaemonInstances ? pluginService.pluginDaemonInstances[pluginId] : null
    readonly property bool highlightActive: daemonInstance ? daemonInstance.active : false

    // SelectionSetting loads its stored value on completion, which runs before
    // DMS injects pluginService - and the built-in reload loop only reaches
    // top-level children, not settings nested in section cards. Reload manually.
    onPluginServiceChanged: {
        if (pluginService)
            styleSetting.loadValue();
    }

    // Read-only code box with a copy button
    component BindCode: StyledRect {
        id: codeBox

        property string code

        width: parent.width
        height: codeEdit.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.3)

        TextEdit {
            id: codeEdit
            anchors.left: parent.left
            anchors.right: copyButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingS
            text: codeBox.code
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            font.family: Theme.monoFontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            selectionColor: Theme.primary
            selectedTextColor: Theme.surface
        }

        DankActionButton {
            id: copyButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingXS
            iconName: "content_copy"
            iconSize: Theme.iconSize - 6
            buttonSize: 28
            tooltipText: "Copy to clipboard"
            onClicked: {
                Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | dms cl copy", "_", codeBox.code]);
                ToastService.showInfo("Copied to clipboard");
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Cursor Highlight"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Click-through highlight at the cursor for presentations and screen sharing"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: generalColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: generalColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "General"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    width: parent.width - highlightToggle.width - Theme.spacingM
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: "Show Highlight"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: "Same as: dms ipc call cursorHighlight toggle"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }

                DankToggle {
                    id: highlightToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.highlightActive
                    onToggled: isChecked => {
                        if (root.daemonInstance)
                            root.daemonInstance.active = isChecked;
                    }
                }
            }

            ToggleSetting {
                settingKey: "onlyWhileSharing"
                label: "Show only when screen sharing is active"
                description: "Hides the bar widget otherwise, unless the highlight is on"
                defaultValue: false
            }

            StyledText {
                text: "Sharing is detected the same way as the privacy indicator, from PipeWire screencast streams. Not picked up? <a href=\"https://github.com/ReyArlena/dms-cursor-highlight/issues\" style=\"color: " + Theme.primary + ";\">Open an issue</a>."
                textFormat: Text.RichText
                linkColor: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                onLinkActivated: link => Qt.openUrlExternally(link)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            SliderSetting {
                settingKey: "pollRate"
                label: "Polling Rate"
                description: "How often the cursor position is sampled. Higher is smoother, slightly more CPU"
                defaultValue: 60
                minimum: 10
                maximum: 240
                unit: "Hz"
                rightIcon: "speed"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: appearanceColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: appearanceColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Appearance"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SelectionSetting {
                id: styleSetting
                settingKey: "style"
                label: "Style"
                description: "Shape drawn at the cursor position"
                defaultValue: "ring"
                options: [
                    { label: "Ring", value: "ring" },
                    { label: "Dot", value: "dot" },
                    { label: "Arrow", value: "arrow" }
                ]
            }

            StyledText {
                text: "Settings below are saved separately for each style."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            SliderSetting {
                settingKey: styleSetting.value + "Size"
                onSettingKeyChanged: loadValue()
                label: "Size"
                description: styleSetting.value === "arrow" ? "Length of the arrow" : "Radius of the highlight"
                defaultValue: 28
                minimum: 8
                maximum: 100
                unit: "px"
                rightIcon: "radio_button_unchecked"
            }

            SliderSetting {
                visible: styleSetting.value === "ring"
                settingKey: "ringThickness"
                label: "Ring Thickness"
                description: "Border width of the ring"
                defaultValue: 4
                minimum: 1
                maximum: 20
                unit: "px"
                rightIcon: "line_weight"
            }

            SliderSetting {
                settingKey: styleSetting.value + "OffsetX"
                onSettingKeyChanged: loadValue()
                label: "Offset X"
                description: "Horizontal shift from the cursor position"
                defaultValue: 0
                minimum: -100
                maximum: 100
                unit: "px"
                rightIcon: "swap_horiz"
            }

            SliderSetting {
                settingKey: styleSetting.value + "OffsetY"
                onSettingKeyChanged: loadValue()
                label: "Offset Y"
                description: "Vertical shift from the cursor position"
                defaultValue: 0
                minimum: -100
                maximum: 100
                unit: "px"
                rightIcon: "swap_vert"
            }

            ToggleSetting {
                id: rainbowSetting
                settingKey: styleSetting.value + "Rainbow"
                onSettingKeyChanged: loadValue()
                label: "Rainbow Mode"
                description: "Cycle the hue of the selected colour while visible"
                defaultValue: false
            }

            SliderSetting {
                visible: rainbowSetting.value
                settingKey: styleSetting.value + "RainbowSpeed"
                onSettingKeyChanged: loadValue()
                label: "Flash Speed"
                description: "1 is a slow ~10s cycle, 10 is ~1s"
                defaultValue: 5
                minimum: 1
                maximum: 10
                rightIcon: "speed"
            }

            ColorSetting {
                id: colorSetting
                settingKey: styleSetting.value + "Color"
                onSettingKeyChanged: loadValue()
                label: "Color"
                description: "Defaults to the theme primary color"
                defaultValue: Theme.primary
            }

            DankButton {
                text: "Reset Color to Theme Default"
                iconName: "format_color_reset"
                onClicked: {
                    // Remove the stored value entirely (instead of saving the current
                    // theme color as a fixed hex) so the highlight keeps following the theme
                    colorSetting.isInitialized = false;
                    colorSetting.value = colorSetting.defaultValue;
                    root.saveValue(styleSetting.value + "Color", undefined);
                    colorSetting.isInitialized = true;
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: tipsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: tipsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Keybind Tips"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "Example binds for the DMS Hyprland Lua config (e.g. dms/binds-user.lua) - adjust keys to taste."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }

            StyledText {
                text: "Show while holding a key (e.g. Control):"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            BindCode {
                code: "hl.bind(\"Control_L\", hl.dsp.exec_cmd(\"dms ipc call cursorHighlight enable\"), { non_consuming = true, description = \"Show cursor highlight (hold)\" })"
            }

            StyledText {
                text: "Hide when releasing a key (e.g. Control). Note: releasing a modifier key requires the modifier in the mods field:"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            BindCode {
                code: "hl.bind(\"CTRL + Control_L\", hl.dsp.exec_cmd(\"dms ipc call cursorHighlight disable\"), { release = true, non_consuming = true })"
            }

            StyledText {
                text: "Toggle with a keybind (e.g. Super+Shift+M):"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            BindCode {
                code: "hl.bind(\"SUPER + SHIFT + M\", hl.dsp.exec_cmd(\"dms ipc call cursorHighlight toggle\"), { description = \"Toggle cursor highlight\" })"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: referenceColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: referenceColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "code"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Reference"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "View this project on <a href=\"https://github.com/ReyArlena/dms-cursor-highlight\" style=\"color: " + Theme.primary + ";\">GitHub</a> for documentation, more information, and contributions."
                textFormat: Text.RichText
                linkColor: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
                onLinkActivated: link => Qt.openUrlExternally(link)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }
}
