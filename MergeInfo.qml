import QtQuick
import Quickshell
import Quickshell.Io

// У каких кромок рабочей области элемент сливается с баром / рамкой (как у Vitreus): у рамки — у всех четырёх, у
// сплошного бара во всю длину края — у него, у плавающей пилюли — ни у каких. Геометрию пишет kamradsmeshnyavy.bar в
// $XDG_RUNTIME_DIR/omarchy-bar-geom.json. Файл общий для widgets, osd и notifications.
Item {
  id: mi

  property var g: ({})
  readonly property bool known: g.position !== undefined
  readonly property bool framed: g.framed === true
  readonly property bool pill: ["floating", "pill", "islands", "notches", "notch", "hug"].indexOf(String(g.shape || "")) !== -1
  readonly property var edges: !known || g.hidden === true ? [] : framed ? ["top", "bottom", "left", "right"] : pill ? [] : [String(g.position)]
  function has(e) { return edges.indexOf(e) !== -1 }

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-bar-geom.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { mi.g = JSON.parse(text()) || {} } catch (e) { mi.g = {} } }
  }
}
