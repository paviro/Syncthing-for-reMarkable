.pragma library

var background = "#c9def3"
var surface = "#fbfcfe"
var surfaceMuted = "#dcecff"
var surfacePressed = "#c4ddfb"
var dashboardSurface = surface
var headerSurface = surface
var listSurface = surface
var border = "#315f9a"
var borderSoft = "#6f93bf"
var text = "#08122e"
var textMuted = "#2f3a4f"
var textSubtle = "#566174"
var accent = "#006edb"
var accentPressed = "#0051a3"
var accentSoft = "#9fd0ff"
var folderAccent = "#8b26d9"
var folderAccentPressed = "#6616a6"
var folderAccentSoft = "#d8a8ff"
var peerAccent = "#e25a00"
var peerAccentPressed = "#a33b00"
var peerAccentSoft = "#ffc287"
var onAccent = "#ffffff"
var successBg = "#b7f23a"
var successBorder = "#247800"
var successProgress = "#8eea1f"
var successPressed = "#185f00"
var warningBg = "#ffd32f"
var warningBorder = "#986100"
var warningPressed = "#744800"
var errorBg = "#ff7668"
var errorBorder = "#b01717"
var errorPressed = "#870f0f"
var mutedBg = "#d5dce6"
var mutedBorder = "#67798f"
var overlay = "#7a080c17"

var itemColors = [
    "#006dff",
    "#a600ff",
    "#ff5a00",
    "#00a33a",
    "#e0002a",
    "#00a8c8",
    "#ffb000",
    "#d000b8",
    "#d8d000",
    "#7a3cff"
]

function itemColor(index) {
    var safeIndex = Number(index)
    if (!isFinite(safeIndex) || safeIndex < 0)
        safeIndex = 0
    return itemColors[Math.floor(safeIndex) % itemColors.length]
}

function itemColorForKey(key, salt) {
    var text = `${salt || ""}:${key || ""}`
    var hash = 0
    for (var i = 0; i < text.length; i++) {
        hash = ((hash << 5) - hash + text.charCodeAt(i)) | 0
    }
    return itemColors[Math.abs(hash) % itemColors.length]
}
