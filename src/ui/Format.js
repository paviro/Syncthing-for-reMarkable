.pragma library

function formatBytes(value) {
    if (value === undefined || value === null)
        return "n/a"

    var size = Number(value)
    if (!isFinite(size))
        return "n/a"

    var units = ["B", "KB", "MB", "GB", "TB"]
    var unitIndex = 0
    while (size >= 1024 && unitIndex < units.length - 1) {
        size = size / 1024
        unitIndex += 1
    }

    var precision = unitIndex === 0 ? 0 : 1
    return size.toFixed(precision) + " " + units[unitIndex]
}

function formatPercent(value) {
    if (value === undefined || value === null)
        return "0.00%"

    var numeric = Number(value)
    if (!isFinite(numeric))
        numeric = 0

    if (numeric >= 100)
        numeric = 100
    else
        numeric = Math.floor(Math.max(0, numeric) * 100) / 100

    return numeric.toFixed(2) + "%"
}

function formatTimeAgo(value) {
    if (!value)
        return "unknown"

    var timestamp = Date.parse(value)
    if (isNaN(timestamp))
        return value

    var seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000))
    if (seconds < 60)
        return "just now"
    if (seconds < 3600)
        return Math.floor(seconds / 60) + " min ago"
    if (seconds < 86400)
        return Math.floor(seconds / 3600) + " h ago"
    return Math.floor(seconds / 86400) + " d ago"
}
