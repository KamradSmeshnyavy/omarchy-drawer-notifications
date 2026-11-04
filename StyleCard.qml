import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Карточка панели по материалу стиля (BarStyle.material, ~/.config/omarchy/style.json):
//   paper  — лист бумаги: неровные края, рваный низ, тайл текстуры, скотч (стиль Paper);
//   soft   — неоморфизм: цвет фона, рельеф двумя мягкими тенями — тёмной и светлой;
//   brutal — толстая рамка цвета текста и жёсткая смещённая тень без размытия;
//   bevel  — ретро-кант: светлый сверху-слева, тёмный снизу-справа;
//   glow   — неон: рамка акцента и свечение тем же цветом.
// Подставляется вместо плавающей карточки (Rectangle) дашборда, меню выключения, OSD и уведомлений
// (BarStyle.card). Один и тот же файл лежит в omarchy-desktop-widgets, omarchy-edge-osd и
// omarchy-drawer-notifications — правки переносить во все три.
Item {
  id: card

  required property var style        // BarStyle.qml
  property real radius: 6
  property int seed: 1                // у каждой панели свой — края не повторяются
  property bool tape: true
  property real textureOpacity: 0.9
  // Насколько рваный край: обычные стороны — лёгкая неровность, низ — заметный разрыв.
  property real roughness: 1.2
  property real tear: 3.2

  // Точки контура: обход по часовой со скруглёнными углами, шаг ~9 px, сдвиг по
  // нормали из детерминированного ГПСЧ (mulberry32), чтобы край не «дрожал» при перерисовке.
  function outline(w, h, r, seed, rough, tear) {
    var s = seed >>> 0
    function rnd() {
      s = (s + 0x6D2B79F5) >>> 0
      var t = s
      t = Math.imul(t ^ (t >>> 15), t | 1)
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
    var pts = []
    r = Math.max(0, Math.min(r, w / 2, h / 2))
    function edge(x0, y0, x1, y1, nx, ny, amp) {
      var len = Math.hypot(x1 - x0, y1 - y0)
      var n = Math.max(1, Math.round(len / 9))
      for (var i = 0; i < n; i++) {
        var t = i / n
        var j = (i === 0) ? 0 : (rnd() - 0.5) * 2 * amp
        pts.push(Qt.point(x0 + (x1 - x0) * t + nx * j, y0 + (y1 - y0) * t + ny * j))
      }
    }
    function arc(cx, cy, a0) {
      for (var k = 0; k <= 4; k++) {
        var a = a0 + k * Math.PI / 8
        pts.push(Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a)))
      }
    }
    var m = Math.max(rough, tear)        // поле под неровность, чтобы край не обрезался
    var L = m, T = m, R = w - m, B = h - m
    edge(L + r, T, R - r, T, 0, 1, rough)
    arc(R - r, T + r, -Math.PI / 2)
    edge(R, T + r, R, B - r, -1, 0, rough)
    arc(R - r, B - r, 0)
    // Низ — рваный: крупнее амплитуда и редкие «зацепы».
    var len = R - L - 2 * r, n = Math.max(1, Math.round(len / 6))
    for (var i = 0; i < n; i++) {
      var x = R - r - len * i / n
      var j = (rnd() - 0.5) * 2 * tear + (rnd() < 0.08 ? tear * 0.9 : 0)
      pts.push(Qt.point(x, B - Math.abs(j)))
    }
    arc(L + r, B - r, Math.PI / 2)
    edge(L, B - r, L, T + r, 1, 0, rough)
    arc(L + r, T + r, Math.PI)
    pts.push(pts[0])
    return pts
  }
  readonly property string material: style.material
  readonly property bool paper: material === "paper"
  readonly property var points: paper ? outline(width, height, radius, seed, roughness, tear) : []
  function shade(c, k) { return Qt.rgba(c.r * k, c.g * k, c.b * k, 1) }
  function lift(c, k) { return Qt.rgba(c.r + (1 - c.r) * k, c.g + (1 - c.g) * k, c.b + (1 - c.b) * k, 1) }

  // ── soft: две тени — тёмная вниз-вправо, светлая вверх-влево ─────────
  Rectangle {
    visible: card.material === "soft"
    anchors.fill: parent
    radius: card.radius
    color: card.style.color
    layer.enabled: visible && card.width > 1
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: card.lift(card.style.color, card.style.darkSurface ? 0.12 : 0.85)
      shadowOpacity: 0.9
      shadowBlur: 0.7
      shadowHorizontalOffset: -5
      shadowVerticalOffset: -5
    }
  }
  Rectangle {
    visible: card.material === "soft"
    anchors.fill: parent
    radius: card.radius
    color: card.style.color
    layer.enabled: visible && card.width > 1
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: card.shade(card.style.color, card.style.darkSurface ? 0.35 : 0.72)
      shadowOpacity: 0.95
      shadowBlur: 0.8
      shadowHorizontalOffset: 6
      shadowVerticalOffset: 6
    }
  }

  // ── brutal: жёсткая тень-плашка + толстая рамка ───────────────────────
  Rectangle {
    visible: card.material === "brutal"
    x: 6
    y: 6
    width: parent.width
    height: parent.height
    radius: card.radius
    color: card.style.inkColor
  }
  Rectangle {
    visible: card.material === "brutal"
    anchors.fill: parent
    radius: card.radius
    color: card.style.color
    border.width: 3
    border.color: card.style.inkColor
  }

  // ── bevel: заливка + светлый и тёмный кант по 2 px ────────────────────
  Rectangle {
    visible: card.material === "bevel"
    anchors.fill: parent
    color: card.style.color
    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 2; color: card.lift(card.style.color, 0.45) }
    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 2; color: card.lift(card.style.color, 0.45) }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2; color: card.shade(card.style.color, 0.4) }
    Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 2; color: card.shade(card.style.color, 0.4) }
    Rectangle {
      anchors { fill: parent; margins: 2 }
      color: "transparent"
      Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: card.shade(card.style.color, 0.7) }
      Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: card.shade(card.style.color, 0.7) }
    }
  }

  // ── glow: рамка акцента и свечение ────────────────────────────────────
  Rectangle {
    visible: card.material === "glow"
    anchors.fill: parent
    radius: card.radius
    color: card.style.color
    border.width: 1
    border.color: card.style.accentColor
    layer.enabled: visible && card.width > 1
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: card.style.accentColor
      shadowOpacity: 0.85
      shadowBlur: 1.0
    }
  }

  // Лист: заливка + обводка, тень — по токенам стиля.
  Item {
    id: sheet
    anchors.fill: parent
    visible: card.paper
    layer.enabled: card.paper && card.style.shadowOn && card.width > 1
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: "#000000"
      shadowOpacity: card.style.shadowOpacity * 0.8
      shadowBlur: card.style.shadowBlur
      shadowVerticalOffset: 3 * card.style.lift
      shadowHorizontalOffset: 1 * card.style.lift
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: card.style.color
        strokeColor: card.style.borderWidth > 0 ? card.style.borderColor : "transparent"
        strokeWidth: Math.max(1, card.style.borderWidth)
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: card.points }
      }
    }

    // Текстура, обрезанная по форме листа.
    Image {
      id: grain
      anchors.fill: parent
      visible: false
      source: card.style.textureSource
      fillMode: Image.Tile
      horizontalAlignment: Image.AlignLeft
      verticalAlignment: Image.AlignTop
      smooth: false
      asynchronous: true
    }
    Shape {
      id: mask
      anchors.fill: parent
      visible: false
      layer.enabled: true
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: "white"
        strokeColor: "transparent"
        PathPolyline { path: card.points }
      }
    }
    MultiEffect {
      anchors.fill: parent
      visible: card.style.textureSource !== "" && grain.status === Image.Ready
      source: grain
      opacity: card.textureOpacity
      maskEnabled: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }
  }

  // Скотч: полупрозрачная полоска цвета акцента, чуть повёрнута, с зубчатыми торцами.
  Shape {
    visible: card.paper && card.tape && card.width > 120
    width: 72
    height: 20
    x: Math.round(card.width / 2 - width / 2 + ((card.seed * 37) % 41) - 20)
    y: -7
    rotation: ((card.seed * 13) % 9) - 4
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: card.style.tapeColor
      strokeColor: "transparent"
      PathPolyline {
        path: [Qt.point(2, 0), Qt.point(70, 0), Qt.point(72, 4), Qt.point(69, 8), Qt.point(72, 12), Qt.point(70, 16),
          Qt.point(71, 20), Qt.point(2, 20), Qt.point(0, 16), Qt.point(3, 12), Qt.point(0, 8), Qt.point(3, 4), Qt.point(2, 0)]
      }
    }
  }
}
