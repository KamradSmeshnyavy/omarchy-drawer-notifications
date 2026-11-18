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
  // rumda (по мотивам mako из hexonide/rumda — только облик): песочная карточка светлым акцентом, коричневый
  // текст, рамка 2 px чуть темнее карточки, моноширинный Terminess.
  property bool sand: false
  // nier (по мотивам уведомлений Unit-3, samyns — MIT, widgets/Notifications.qml): бежевый лист NieR #d6cfb5 с рамкой
  // чернилами, полоса важности 3 px слева, шапка — плашка NOTICE / CRITICAL / INFO с японской подписью, имя приложения,
  // время и квадрат ✕; заголовок и текст чернилами, Share Tech Mono.
  property bool nier: false
  readonly property color nierAcc: urgency === 2 ? "#6e2a2a" : urgency === 0 ? "#7a7358" : "#463f2e"
  readonly property string nierFont: Qt.fontFamilies().indexOf("Share Tech Mono") !== -1 ? "Share Tech Mono" : "monospace"
  // space (по мотивам стиля Space из elifouts/Dotfiles, GPL-3.0): плашка HUD — фон темы 78 %, рамка акцентом 35 %,
  // черта 2 px акцентом слева, уголки 7 px; шапка «NOTICE // ПРИЛОЖЕНИЕ», время и ✕ капсом вразрядку.
  property bool hud: false
  readonly property string hudFont: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property color hudAcc: urgency === 2 ? Commons.Color.urgent : Commons.Color.accent
  // crt (по мотивам стиля Retro из elifouts/Dotfiles, GPL-3.0; retro/notify-default.png): фон темы, рамка 1 px цветом
  // трубки на 45 %, Terminess, внизу «ПРИЛОЖЕНИЕ · ВРЕМЯ» тускло и полоска 3 px акцентом, тающая за 6 с (под мышью — стоит).
  property bool retro: false
  readonly property string retroFont: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : "monospace"
  property real retroLeft: 1
  NumberAnimation on retroLeft { running: root.retro; paused: running && root.hovered; to: 0; duration: 6000 }
  readonly property string sandFont: Qt.fontFamilies().indexOf("Terminess Nerd Font") !== -1 ? "Terminess Nerd Font" : "monospace"
  readonly property color ink: nier ? "#2e2a1f" : sand ? Qt.darker(Commons.Color.accent, 1.55) : Commons.Color.notifications.text

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

  readonly property color dimColor: nier ? "#7a7358" : sand ? Qt.lighter(ink, 1.25) : Qt.darker(Commons.Color.notifications.text, 1.4)
  readonly property color bodyColor: nier ? "#463f2e" : sand ? ink : Qt.darker(Commons.Color.notifications.text, 1.15)
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
  color: retro ? Util.alpha(Commons.Color.background, 0.94) : hud ? Util.alpha(Commons.Color.background, 0.78) : nier ? "#d6cfb5" : dotmatrix ? DotMatrix.Palette.bg : sand ? Qt.tint(Commons.Color.accent, Qt.rgba(1, 1, 1, 0.45)) : (flat ? Util.alpha(Commons.Color.notifications.text, 0.06) : Commons.Color.notifications.background)
  borderSpec: retro ? Border.flat(Util.alpha(hudAcc, 0.45), 1) : hud ? Border.flat(Util.alpha(hudAcc, 0.35), 1) : nier ? Border.flat("#463f2e", 1) : dotmatrix
    ? Border.flat(hovered ? DotMatrix.Palette.muted : DotMatrix.Palette.line, 1)
    : sand ? Border.flat(hovered ? Qt.darker(Commons.Color.accent, 1.1) : Qt.tint(Commons.Color.accent, Qt.rgba(1, 1, 1, 0.22)), 2)
    : (flat ? ({ color: "transparent", widths: cardBorderSpec.widths, gradient: null }) : cardBorderSpec)
  clip: true

  HoverHandler { id: hoverTracker }
  Rectangle { visible: root.nier; x: 1; y: 1; width: 3; height: root.height - 2; color: root.nierAcc; z: 5 }
  // crt: полоска-таймер акцентом внизу
  Rectangle { visible: root.retro; x: 10; y: root.height - 8; width: (root.width - 20) * root.retroLeft; height: 3; color: root.hudAcc; z: 5 }
  // space: черта акцентом слева и уголки
  Rectangle { visible: root.hud; x: 0; y: 7; width: 2; height: root.height - 7; color: root.hudAcc; z: 5 }
  Repeater {
    model: root.hud ? 4 : 0
    Item {
      required property int index
      z: 6
      x: index % 2 ? root.width - 7 : 0
      y: index > 1 ? root.height - 7 : 0
      width: 7; height: 7
      Rectangle { width: 7; height: 1; y: parent.index > 1 ? 6 : 0; color: root.hudAcc }
      Rectangle { width: 1; height: 7; x: parent.index % 2 ? 6 : 0; color: root.hudAcc }
    }
  }

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

    // nier: шапка — плашка важности, японская подпись, приложение, время, квадрат ✕
    RowLayout {
      visible: root.nier
      Layout.fillWidth: true
      Layout.leftMargin: Style.space(16)
      Layout.rightMargin: Style.space(10)
      Layout.topMargin: Style.space(10)
      spacing: 8
      Rectangle {
        Layout.preferredWidth: nierTag.implicitWidth + 10
        Layout.preferredHeight: 14
        color: root.nierAcc
        Text { id: nierTag; anchors.centerIn: parent; text: root.urgency === 2 ? "CRITICAL" : root.urgency === 0 ? "INFO" : "NOTICE"; color: "#d6cfb5"; font.family: root.nierFont; font.pixelSize: 8; font.letterSpacing: 2 }
      }
      Text { text: root.urgency === 2 ? "緊急" : root.urgency === 0 ? "情報" : "通知"; color: "#7a7358"; font.pixelSize: 9 }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: (root.app.length > 0 ? root.app : "SYSTEM").toUpperCase()
        color: "#7a7358"; font.family: root.nierFont; font.pixelSize: 8; font.letterSpacing: 2
      }
      Text { text: root.timestamp > 0 ? Qt.formatTime(new Date(root.timestamp), "HH:mm") : ""; color: "#7a7358"; font.family: root.nierFont; font.pixelSize: 8; font.letterSpacing: 1 }
      Rectangle {
        Layout.preferredWidth: 16; Layout.preferredHeight: 16
        color: nierClose.containsMouse ? root.nierAcc : "transparent"
        border.color: "#463f2e"; border.width: 1
        Text { anchors.centerIn: parent; text: "✕"; color: nierClose.containsMouse ? "#d6cfb5" : "#463f2e"; font.family: root.nierFont; font.pixelSize: 9 }
        MouseArea { id: nierClose; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
      }
    }

    // space: шапка HUD
    RowLayout {
      visible: root.hud
      Layout.fillWidth: true
      Layout.leftMargin: Style.space(14)
      Layout.rightMargin: Style.space(10)
      Layout.topMargin: Style.space(9)
      spacing: 8
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: (root.urgency === 2 ? "CRITICAL" : root.urgency === 0 ? "INFO" : "NOTICE") + "  //  " + (root.app.length > 0 ? root.app : "SYSTEM").toUpperCase()
        color: Util.alpha(root.hudAcc, 0.85); font.family: root.hudFont; font.pixelSize: 9; font.letterSpacing: 1.6
      }
      Text { text: root.timestamp > 0 ? Qt.formatTime(new Date(root.timestamp), "HH:mm") : ""; color: Util.alpha(Commons.Color.foreground, 0.45); font.family: root.hudFont; font.pixelSize: 9; font.letterSpacing: 1.6 }
      Text {
        text: "✕"
        color: hudClose.containsMouse ? root.hudAcc : Util.alpha(Commons.Color.foreground, 0.5)
        font.family: root.hudFont; font.pixelSize: 10
        MouseArea { id: hudClose; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
      }
    }

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
      Layout.leftMargin: Style.space(root.dotmatrix || root.hud ? 14 : 12)
      Layout.rightMargin: Style.space(12)
      Layout.topMargin: root.dotmatrix || root.hud ? Style.space(6) : (root.singleLineToast ? Style.space(7) : Style.space(10))
      Layout.bottomMargin: root.dotmatrix || root.retro ? Style.space(14) : (root.singleLineToast ? Style.space(7) : Style.space(10))
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
          color: root.dotmatrix ? DotMatrix.Palette.fg : root.ink
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignVCenter
        visible: root.compactGlyph
        text: root.glyph
        color: root.dotmatrix ? DotMatrix.Palette.fg : root.ink
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
          font.family: root.dotmatrix ? DotMatrix.Palette.fontTitle : root.nier ? root.nierFont : root.retro ? root.retroFont : root.hud ? root.hudFont : root.sand ? root.sandFont : "Liberation Sans"
          color: root.dotmatrix ? DotMatrix.Palette.fg : root.ink
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
          font.family: root.dotmatrix ? DotMatrix.Palette.fontSans : root.nier ? root.nierFont : root.retro ? root.retroFont : root.hud ? root.hudFont : root.sand ? root.sandFont : "Liberation Sans"
          color: root.dotmatrix ? DotMatrix.Palette.dim : root.bodyColor
          font.pixelSize: root.dotmatrix ? 13 : Style.font.title
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 3
        }
        // crt: «ПРИЛОЖЕНИЕ · ВРЕМЯ» тускло
        Text {
          Layout.fillWidth: true
          visible: root.retro
          text: (root.app.length > 0 ? root.app : "system") + "  ·  " + (root.timestamp > 0 ? Qt.formatTime(new Date(root.timestamp), "HH:mm") : "now")
          font.family: root.retroFont
          font.pixelSize: 12
          color: Util.alpha(Commons.Color.foreground, 0.5)
          elide: Text.ElideRight
        }
      }
    }
  }

}
