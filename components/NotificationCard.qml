// Notification card. Pure presentational — no service, Notification, or
// ListModel references. The popup container drives lifetime; the history
// panel drives static rendering. Both use the same component.

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../NotificationLogic.js" as NotificationLogic
import "../dotmatrix" as DotMatrix

BorderSurface {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  // Nerd Font glyph rendered in the icon slot when no real icon is set.
  // Used by omarchy-notification-send so user-action toasts (`Silenced
  // notifications` etc.) show their bell/lock/etc. glyph without leaking
  // into the summary text.
  property string glyph: ""
  // NotificationUrgency: Low=0, Normal=1, Critical=2 (upstream).
  property int urgency: 1
  property double timestamp: 0
  property int cornerRadius: 0
  // drawer: карточка внутри общей подложки — полупрозрачный фон, рамка невидима
  // (толщина та же, чтобы не сдвигалась вёрстка).
  property bool flat: false
  // dotmatrix: монохромная карточка #000000 с тонким контуром #2a2a2a и красным LED на critical.
  property bool dotmatrix: false

  // System monospace font injected by the container.
  property string fontFamily: ""

  readonly property bool hovered: hoverTracker.hovered

  signal closeRequested()
  signal cardClicked()
  // Prefer per-notification media/avatar data, then fall back to the app icon.
  // The `check` flag avoids Qt's missing-texture placeholder for unknown names.
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  readonly property bool hasGlyph: glyph.length > 0
  readonly property bool compactGlyph: NotificationLogic.shouldRenderCompactGlyph(glyph, smallIconSource, singleLineToast)
  readonly property bool hasSmallIcon: smallIconSource.length > 0
  readonly property bool summaryStartsWithGlyph: NotificationLogic.summaryStartsWithGlyph(summary)
  readonly property bool singleLineToast: sanitizedBody.length === 0
  readonly property bool collapseRedundantIcon: singleLineToast && !hasGlyph && summaryStartsWithGlyph
  readonly property string sanitizedBody: sanitizeBody(body)
  readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)

  readonly property color dimColor: Qt.darker(Commons.Color.notifications.text, 1.4)
  readonly property color bodyColor: Qt.darker(Commons.Color.notifications.text, 1.15)
  readonly property color accentColor: urgency === 2 ? Commons.Color.urgent : (urgency === 0 ? dimColor : Commons.Color.notifications.countdown)
  readonly property var cardBorderSpec: Border.surfaceSpec("notifications", "border", Commons.Color.notifications.border, Math.max(1, Style.space(2)))

  function sanitizeBody(s) {
    return NotificationLogic.sanitizeBody(s, app, appIcon)
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: Style.space(380)
  // Add vertical border insets so mainColumn (inset by border on top/left/right)
  // doesn't push content under the bottom edge.
  implicitHeight: mainColumn.implicitHeight + borderTop + borderBottom
  radius: cornerRadius
  color: dotmatrix ? DotMatrix.Palette.bg : (flat ? Util.alpha(Commons.Color.notifications.text, 0.06) : Commons.Color.notifications.background)
  borderSpec: dotmatrix
    ? Border.flat(hovered ? DotMatrix.Palette.muted : DotMatrix.Palette.line, 1)
    : (flat ? ({ color: "transparent", widths: cardBorderSpec.widths, gradient: null }) : cardBorderSpec)
  clip: true

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.closeRequested()
      } else {
        root.cardClicked()
      }
    }
  }

  ColumnLayout {
    id: mainColumn
    // Inset by the card border so the content doesn't paint over the card's
    // outer border.
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: root.borderTop
    anchors.leftMargin: root.borderLeft
    anchors.rightMargin: root.borderRight
    spacing: 0

    // DOT-MATRIX metadata header: 6x6 red LED on critical, monochrome app icon, uppercase Space Mono app name, close glyph.
    RowLayout {
      visible: root.dotmatrix
      Layout.fillWidth: true
      Layout.leftMargin: Style.space(14)
      Layout.rightMargin: Style.space(12)
      Layout.topMargin: Style.space(12)
      spacing: 8

      Rectangle {
        visible: root.urgency === 2
        Layout.preferredWidth: 6
        Layout.preferredHeight: 6
        radius: 3
        color: DotMatrix.Palette.danger
      }

      Image {
        id: dotmatrixAppIcon
        readonly property string src: root.iconSource(root.appIcon)
        visible: src.length > 0 && status !== Image.Error
        Layout.preferredWidth: 15
        Layout.preferredHeight: 15
        source: src
        sourceSize.width: 30
        sourceSize.height: 30
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
          saturation: -1
          brightness: -0.05
        }
      }

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: (root.app.length > 0 ? root.app : "NOTICE").toUpperCase()
        font.family: DotMatrix.Palette.fontMono
        font.pixelSize: 10
        font.letterSpacing: 1.6
        color: DotMatrix.Palette.muted
      }

      Text {
        textFormat: Text.PlainText
        text: String.fromCodePoint(0xF0156)
        font.family: DotMatrix.Palette.fontIcon
        font.pixelSize: 13
        color: closeArea.containsMouse ? DotMatrix.Palette.fg : DotMatrix.Palette.muted

        MouseArea {
          id: closeArea
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeRequested()
        }
      }
    }

    // Text content.
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Style.space(root.dotmatrix ? 14 : 12)
      Layout.rightMargin: Style.space(12)
      Layout.topMargin: root.dotmatrix ? Style.space(6) : (root.singleLineToast ? Style.space(7) : Style.space(10))
      Layout.bottomMargin: root.dotmatrix ? Style.space(12) : (root.singleLineToast ? Style.space(7) : Style.space(10))
      spacing: root.collapseRedundantIcon ? 0 : (root.compactGlyph ? Style.space(8) : Style.space(12))

      Item {
        id: smallIconSlot
        Layout.preferredWidth: visible ? Style.space(40) : 0
        Layout.preferredHeight: visible ? Style.space(40) : 0
        Layout.alignment: Qt.AlignVCenter
        // Hide the slot when the icon failed to resolve (themed-icon name
        // not in the user's icon theme) AND we don't have a glyph fallback
        // — prevents rendering Qt's pink broken-image placeholder.
        visible: (!root.dotmatrix || root.image.length > 0 || (root.hasGlyph && !root.compactGlyph))
          && !root.collapseRedundantIcon && !root.compactGlyph && (root.hasSmallIcon || root.hasGlyph)
          && (root.hasGlyph || smallIconImage.status !== Image.Error)

        Image {
          id: smallIconImage
          anchors.fill: parent
          source: root.smallIconSource
          sourceSize.width: smallIconSlot.width * Screen.devicePixelRatio
          sourceSize.height: smallIconSlot.height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          visible: !root.hasGlyph || smallIconImage.status === Image.Ready
          layer.enabled: root.dotmatrix
          layer.effect: MultiEffect {
            saturation: -1
          }
        }

        // Glyph fallback (Nerd Font character) when no image icon is
        // available. Used by omarchy-notification-send's `-g` flag.
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: root.hasGlyph && smallIconImage.status !== Image.Ready
          text: root.glyph
          color: root.dotmatrix ? DotMatrix.Palette.fg : Commons.Color.notifications.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignVCenter
        visible: root.compactGlyph
        text: root.glyph
        color: root.dotmatrix ? DotMatrix.Palette.fg : Commons.Color.notifications.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.space(2)

        Text {
          // The spec defines the summary as a single line of plain text, so
          // AutoText could only ever promote a hostile string to rich text.
          // The body below is StyledText on purpose — see Service.qml's
          // bodyMarkupSupported — and is stripped in NotificationLogic.
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: root.summary.length > 0
          text: root.summary
          font.family: root.dotmatrix ? DotMatrix.Palette.fontTitle : "Liberation Sans"
          color: root.dotmatrix ? DotMatrix.Palette.fg : Commons.Color.notifications.text
          font.pixelSize: root.dotmatrix ? (DotMatrix.Palette.dotLayer ? 17 : 15) : Style.font.title
          font.weight: root.dotmatrix ? DotMatrix.Palette.titleWeight(Font.Medium) : Font.Bold
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        Text {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(2)
          visible: root.sanitizedBody.length > 0
          text: root.styledBody
          textFormat: Text.StyledText
          font.family: root.dotmatrix ? DotMatrix.Palette.fontSans : "Liberation Sans"
          color: root.dotmatrix ? DotMatrix.Palette.dim : root.bodyColor
          font.pixelSize: root.dotmatrix ? 13 : Style.font.title
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 3
        }
      }
    }
  }

}
