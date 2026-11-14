import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons as Commons

// Карточка панели по материалу стиля (BarStyle.material, ~/.config/omarchy/style.json):
//   paper  — лист бумаги: неровные края, рваный низ, тайл текстуры, скотч (стиль Paper);
//   soft   — неоморфизм: цвет фона, рельеф двумя мягкими тенями — тёмной и светлой;
//   brutal — толстая рамка цвета текста и жёсткая смещённая тень без размытия;
//   bevel  — ретро-кант: светлый сверху-слева, тёмный снизу-справа;
//   glow   — неон: рамка акцента и свечение тем же цветом;
//   liquid — жидкое стекло (Vitreus): прозрачная заливка под размытием Hyprland, мягкая глубокая тень,
//            световой блик сверху, ободок-блик (ярче сверху-слева) и слабая подсветка акцентом снизу.
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
  // liquid: имя слоя окна панели — тогда под карточкой настоящее стекло (LiquidGlass: преломляет обои), иначе
  // прозрачная заливка под размытием Hyprland, как было.
  property string glassLayer: ""
  // или сразу место карточки на экране (окно у левого верхнего угла монитора — его координаты и есть экранные)
  property point glassOrigin: Qt.point(NaN, NaN)
  property bool glassBelow: false
  // перешеек к бару (LiquidGlass.joinRect в координатах карточки) и запас вокруг карточки под него
  property rect glassJoin: Qt.rect(0, 0, 0, 0)
  property real glassJoinK: 0
  property real glassJoinRadius: 16
  property real glassBleed: 0
  // крылья (вторая фигура слияния — кусок кромки рамки) и вырезы: где стекло не рисовать (внутри бара и рамки)
  property rect glassJoin2: Qt.rect(0, 0, 0, 0)
  property real glassJoin2K: 0
  property real glassJoin2Radius: 0
  property rect glassCut: Qt.rect(0, 0, 0, 0)
  property rect glassCut2: Qt.rect(0, 0, 0, 0)
  // пластик: края, которыми карточка слита с баром или рамкой ("top" "bottom" "left" "right") — там нет контура,
  // карточка заходит на mergeExt px на контур бара, по бокам — вогнутые изгибы mergeFillet с контуром
  property var mergeEdges: []
  property real mergeExt: 3
  property real mergeFillet: 14
  function merged(e) { return mergeEdges.indexOf(e) !== -1 }
  readonly property bool realGlass: card.material === "liquid" && (card.glassLayer !== "" || !isNaN(card.glassOrigin.x))

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

  // ── liquid: жидкое стекло ──────────────────────────────────────────────
  // Тень — RectangularShadow: рисует только тень по форме, ей не нужна непрозрачная заливка-источник
  // (MultiEffect строит тень по альфе, а стекло почти прозрачное). Лёгкая — под стеклом она его чуть темнит.
  RectangularShadow {
    visible: card.material === "liquid" && card.style.shadowOn && !card.style.plastic
    anchors.fill: parent
    radius: card.radius
    offset.y: 8 * card.style.lift
    blur: 28
    spread: -4
    color: Qt.rgba(0, 0, 0, card.style.elevation >= 2 ? 0.38 : 0.26)
  }
  // ── пластиковые основы тем Vitreus ────────────────────────────────────
  // retro: заливка цвета фона темы, контур 2.3 px цвета текста, жёсткая тень (6, 7) без размытия, светлая кромка сверху;
  //   на больших панелях (decor) — красный язычок на верхней кромке, прорези-ручки снизу справа и винт слева.
  // doodle: кремовый лист, контур чернилами 2.8 px, сплошная тень-копия (3.5, 3.5). proxy: тёмная плита, синяя жёсткая
  // тень (2.5, 3). milk: две мягкие тени — светлая сверху-слева и тёмная снизу-справа. paper: мягкая тень и тонкий контур.
  property bool decor: false
  Item {
    id: plastic
    visible: card.material === "liquid" && card.style.plastic
    anchors.fill: parent
    readonly property string b: card.style.base
    readonly property color fill: Commons.Color.background
    readonly property color ink: Commons.Color.foreground
    readonly property color accent: Commons.Color.accent
    readonly property real r: Math.max(2, card.radius * (1 - 0.73 * card.style.squareness))
    readonly property real bw: ({ retro: 2.3, doodle: 2.8, proxy: 1.9, paper: 1.6 })[b] || 0
    readonly property color line: b === "paper" ? Qt.rgba(ink.r, ink.g, ink.b, 0.45) : b === "proxy" ? Qt.rgba(0.9, 0.95, 0.96, 0.6) : ink
    readonly property point hard: ({ retro: Qt.point(6, 7), doodle: Qt.point(3.5, 3.5), proxy: Qt.point(3.4, 4) })[b] || Qt.point(0, 0)
    readonly property color hardColor: b === "proxy" ? "#2a8cff" : b === "doodle" ? ink : Qt.rgba(ink.r, ink.g, ink.b, 0.55)

    // слитые края: тело тянется за край на ext (закрывает контур бара), а его свой контур и углы уходят за обрезку
    readonly property real ext: card.mergeExt
    readonly property real hide: ext + r + bw + 2
    readonly property real eT: card.merged("top") ? ext : 0
    readonly property real eB: card.merged("bottom") ? ext : 0
    readonly property real eL: card.merged("left") ? ext : 0
    readonly property real eR: card.merged("right") ? ext : 0
    function grow(e) { return card.merged(e) ? hide : 0 }

    // жёсткая тень без размытия
    Item {
      visible: plastic.hard.x > 0
      x: -plastic.eL; y: -plastic.eT
      width: card.width + plastic.eL + (card.merged("right") ? plastic.eR : plastic.hard.x + 1)
      height: card.height + plastic.eT + (card.merged("bottom") ? plastic.eB : plastic.hard.y + 1)
      clip: card.mergeEdges.length > 0
      Rectangle {
        x: plastic.eL + plastic.hard.x - plastic.grow("left"); y: plastic.eT + plastic.hard.y - plastic.grow("top")
        width: card.width + plastic.grow("left") + plastic.grow("right"); height: card.height + plastic.grow("top") + plastic.grow("bottom")
        radius: plastic.r
        color: plastic.hardColor
      }
    }
    // мягкие тени (milk — две, paper — одна)
    RectangularShadow {
      visible: plastic.b === "milk"
      anchors.fill: parent; radius: plastic.r
      offset: Qt.vector2d(-4, -4); blur: 11; spread: 0
      color: Qt.rgba(1, 1, 1, 0.5)
    }
    RectangularShadow {
      visible: plastic.b === "milk" || plastic.b === "paper"
      anchors.fill: parent; radius: plastic.r
      offset: Qt.vector2d(plastic.b === "milk" ? 4 : 2, plastic.b === "milk" ? 5 : 4.5); blur: plastic.b === "milk" ? 13 : 12; spread: 0
      color: Qt.rgba(plastic.ink.r, plastic.ink.g, plastic.ink.b, plastic.b === "milk" ? 0.28 : 0.42)
    }
    Item {
      x: -plastic.eL; y: -plastic.eT
      width: parent.width + plastic.eL + plastic.eR; height: parent.height + plastic.eT + plastic.eB
      clip: card.mergeEdges.length > 0
      Rectangle {
        x: plastic.eL - plastic.grow("left"); y: plastic.eT - plastic.grow("top")
        width: card.width + plastic.grow("left") + plastic.grow("right"); height: card.height + plastic.grow("top") + plastic.grow("bottom")
        radius: plastic.r
        color: plastic.fill
        border.width: plastic.bw
        border.color: plastic.line
      }
    }
    // вогнутые изгибы у слитых краёв (по два на край)
    Repeater {
      model: card.mergeEdges.length > 0 ? [["top", -1], ["top", 1], ["bottom", -1], ["bottom", 1], ["left", -1], ["left", 1], ["right", -1], ["right", 1]]
                                          .filter(function(m) {
                                            // изгиб не нужен, если соседний край тоже слит (угол у рамки)
                                            var adj = m[0] === "top" || m[0] === "bottom" ? (m[1] < 0 ? "left" : "right") : (m[1] < 0 ? "top" : "bottom")
                                            return card.merged(m[0]) && !card.merged(adj)
                                          }) : []
      MergeFillet {
        required property var modelData
        edge: modelData[0]; side: modelData[1]
        w: card.width; h: card.height
        f: card.mergeFillet; bw: plastic.bw; ext: plastic.ext
        fill: plastic.fill; line: plastic.line
      }
    }
    // retro: светлая кромка (литой край)
    Rectangle {
      visible: plastic.b === "retro" && !card.merged("top")
      x: plastic.bw + 1; y: plastic.bw + 1
      width: parent.width - 2 * (plastic.bw + 1); height: 2
      radius: 1
      color: Qt.rgba(1, 1, 1, 0.4)
    }
    // retro: язычок на верхней кромке (78×24: основание, лицо акцентом, блик, контур)
    Item {
      visible: plastic.b === "retro" && card.decor && !card.merged("top")
      x: 58; y: -9
      width: 78; height: 24
      Rectangle { x: 2; y: 3; width: parent.width; height: parent.height; radius: 5; color: Qt.rgba(plastic.ink.r, plastic.ink.g, plastic.ink.b, 0.38) }
      Rectangle { anchors.fill: parent; radius: 5; color: Qt.darker(plastic.accent, 1.35) }
      Rectangle { width: parent.width; height: 19; y: 0; radius: 5; color: plastic.accent }
      Rectangle { x: 6; y: 2; width: parent.width - 12; height: 2.2; radius: 1.1; color: Qt.rgba(1, 1, 1, 0.55) }
      Rectangle { anchors.fill: parent; radius: 5; color: "transparent"; border.width: 1.4; border.color: plastic.ink }
    }
    // retro: прорези-ручки снизу справа и винт слева
    Row {
      visible: plastic.b === "retro" && card.decor && !card.merged("bottom")
      anchors { right: parent.right; rightMargin: 20; bottom: parent.bottom; bottomMargin: -4 }
      spacing: 9
      Repeater {
        model: 8
        Rectangle {
          width: 6; height: 22; radius: 2
          color: Qt.rgba(plastic.ink.r * 0.94 + 0.06, plastic.ink.g * 0.94 + 0.06, plastic.ink.b * 0.94 + 0.06, 1)
          Rectangle { width: 1.2; height: parent.height - 3; x: 0.6; y: 1; color: Qt.rgba(1, 1, 1, 0.45) }
        }
      }
    }
    Rectangle {
      visible: plastic.b === "retro" && card.decor
      x: 12; anchors { bottom: parent.bottom; bottomMargin: 10 }
      width: 7.2; height: 7.2; radius: 3.6
      color: Qt.darker(plastic.fill, 1.25)
      border.width: 1; border.color: plastic.ink
      Rectangle { anchors.centerIn: parent; width: 5; height: 1.2; rotation: 35; color: plastic.ink }
    }
  }

  Item {
    visible: card.material === "liquid" && !card.style.plastic
    anchors.fill: parent

    Rectangle {   // стекло
      visible: !card.realGlass
      anchors.fill: parent
      radius: card.radius
      color: card.style.color
    }
    LiquidGlass {
      visible: card.realGlass
      active: card.realGlass && card.visible && card.width > 4
      anchors.fill: parent
      radius: card.radius
      layerNamespace: card.glassLayer
      screenOrigin: card.glassOrigin
      belowWindows: card.glassBelow
      joinRect: card.glassJoin
      joinK: card.glassJoinK
      joinRadius: card.glassJoinRadius
      bleed: card.glassBleed
      join2Rect: card.glassJoin2
      join2K: card.glassJoin2K
      join2Radius: card.glassJoin2Radius
      cutRect: card.glassCut
      cut2Rect: card.glassCut2
      tintColor: Qt.rgba(card.style.color.r, card.style.color.g, card.style.color.b, 1)
    }
    Rectangle {   visible: !card.realGlass  // свет сверху: мягкий градиент на верхней трети
      anchors { left: parent.left; right: parent.right; top: parent.top }
      height: parent.height * 0.45
      radius: card.radius
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
      }
    }
    Rectangle {   visible: !card.realGlass  // подсветка акцентом снизу — «преломление» цвета сквозь толщу
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: parent.height * 0.5
      radius: card.radius
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(card.style.accentColor.r, card.style.accentColor.g, card.style.accentColor.b, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(card.style.accentColor.r, card.style.accentColor.g, card.style.accentColor.b, 0.10) }
      }
    }
    Rectangle {   visible: !card.realGlass  // ободок
      anchors.fill: parent
      radius: card.radius
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.16)
    }
    Rectangle {   visible: !card.realGlass  // блик по верхней кромке: ярче к левому краю
      x: card.radius * 0.6
      y: 0.5
      width: parent.width - card.radius * 1.2
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
        GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.65) }
        GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.18) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
      }
    }
    Rectangle {   visible: !card.realGlass  // блик по левой кромке
      x: 0.5
      y: card.radius * 0.6
      width: 1
      height: parent.height * 0.5
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.45) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
      }
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
