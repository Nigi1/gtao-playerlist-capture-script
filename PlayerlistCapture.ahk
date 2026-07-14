#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
#Include <AHKv2_Screenshot_Tools>

pToken := Gdip_Startup()
OnExit(*) => Gdip_Shutdown(pToken)

configFile := A_ScriptDir "\config.ini"

; --- CONFIG -------------------------------------------------------------------
TRIGGER_HOTKEY := IniRead(configFile, "Hotkeys", "CaptureHotkey", "F10")
OVERLAY_KEY := IniRead(configFile, "Hotkeys", "OverlayToggleKey", "z")
DISCORD_PASTE_TEXT := IniRead(configFile, "Discord", "Command", "")
GAME_WIN_TITLE := "GTA5_enhanced.exe"
DISCORD_WIN_TITLE := "Discord.exe"

ROW_HEIGHTS_PX := Map(
    2160, [76, 75, 76, 75, 75, 76, 75, 75, 76, 75, 75, 76, 75, 75, 76, 75],
    1440, [50, 50, 51, 50, 50, 51, 50, 50, 50, 50, 51, 50, 50, 50, 51, 50],
    1080, [37, 38, 38, 37, 38, 38, 37, 38, 38, 37, 38, 38, 38, 37, 38, 37],
    720, [25, 25, 25, 26, 25, 25, 25, 25, 25, 25, 25, 26, 25, 25, 25, 25]
)

BASE_REF := {
    width: 3840,
    height: 2160,
    x: 63,
    y: 33,
    w: 852,
    h: 75
}

COLORCHECK_REF := {
    width: 3840,
    height: 2160,
    x: 864,
    y: 113,
    w: 27,
    h: 5
}

basePlayerlistCoords := {}
pixelCheckCoords := {}
rowHeights := []
windowSize := {}
playerCount := 0
widthOffset := 0

; ------------------------------------------------------------------------------

Hotkey(TRIGGER_HOTKEY, (*) => GetPixelColors())

TrayTip("Discord Screenshot", "Ready.`n" TRIGGER_HOTKEY " = Screenshot playerlist.", 1)

GetPixelColors() {
    global GAME_WIN_TITLE, OVERLAY_KEY, DISCORD_PASTE_TEXT, rowHeights
    global basePlayerlistCoords, pixelCheckCoords, playerCount

    playerCount := 0

    if !gameHwnd := WinExist("ahk_exe " GAME_WIN_TITLE) {
        MsgBox("Game window not found:`n" GAME_WIN_TITLE, "Discord Screenshot", "Icon!")
        return
    }

    getWindowSize(gameHwnd)

    basePlayerlistCoords := getScreenRelativeCoords(BASE_REF)
    pixelCheckCoords := getScreenRelativeCoords(COLORCHECK_REF)

    rowHeights := getRowHeights()

    WinActivate("ahk_id" gameHwnd)
    WinWaitActive("ahk_id " gameHwnd, , 2)

    SendOverlayKey(OVERLAY_KEY)
    Sleep(200)
    findPlayerCount()

    if !CaptureGameRegionToClipboard(gameHwnd, basePlayerlistCoords) {
        MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
        return
    }

    PasteToDiscord(gameHwnd)

    SendTextToDiscord(DISCORD_PASTE_TEXT)
    Sleep(100)

    if playerCount = 16 {
        WinActivate("ahk_id" gameHwnd)
        WinWaitActive("ahk_id " gameHwnd, , 2)

        SendOverlayKey(OVERLAY_KEY)
        Sleep(200)
        findPlayerCount()

        if playerCount != 0 {
            if !CaptureGameRegionToClipboard(gameHwnd, basePlayerlistCoords) {
                MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
                return
            }

            PasteToDiscord(gameHwnd)
        }
    }
}

getWindowSize(gameHwnd) {
    global windowSize, widthOffset
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " gameHwnd)

    wndScreenshotWidth := winH * (16 / 9)
    if (winW != wndScreenshotWidth) {
        widthOffset := ((winW - wndScreenshotWidth) / 2) - 1
    }

    windowSize.winX := winX
    windowSize.winY := winY
    windowSize.winW := wndScreenshotWidth
    windowSize.winH := winH
}

getRowHeights() {
    global windowSize, ROW_HEIGHTS_PX

    key := windowSize.winH
    if ROW_HEIGHTS_PX.Has(key) {
        return ROW_HEIGHTS_PX[key]
    } else {
        closestKey := ""
        closestDiff := 999999

        for h, arr in ROW_HEIGHTS_PX {
            diff := Abs(h - key)
            if diff < closestDiff {
                closestDiff := diff
                closestKey := h
            }
        }

        if closestKey = ""
            throw Error("No row-height data available at all")

        return ROW_HEIGHTS_PX[closestKey]
    }
}

getScreenRelativeCoords(refObj) {
    global windowSize, widthOffset

    scaleX := windowSize.winW / refObj.width
    scaleY := windowSize.winH / refObj.height

    return {
        x: Round(refObj.x * scaleX) + windowSize.winX + widthOffset,
        y: Round(refObj.y * scaleY) + windowSize.winY,
        w: Round(refObj.w * scaleX),
        h: Round(refObj.h * scaleY)
    }
}

SendOverlayKey(keySpec) {
    SendInput("{z down}")
    Sleep(50)
    SendInput("{z up}")
}

findPlayerCount() {
    global playerCount

    playerCount := FindLastActivePlayerRow()

    ; MsgBox("Detected Player Count: " PLAYER_COUNT)
}

FindLastActivePlayerRow(maxIndex := 16) {
    global playerCount
    if RowHasColor(16) {
        playerCount := 16
        return 16
    }

    if RowHasColor(8) {
        index := 8
        while (index + 1 <= maxIndex && RowHasColor(index + 1)) {
            index++
        }
        playerCount := index
        return index
    }

    if !RowHasColor(1) {
        playerCount := 0
        return 0
    }

    index := 1
    while (index + 1 <= maxIndex && RowHasColor(index + 1)) {
        index++
    }
    playerCount := index
    return index
}

RowHasColor(index) {
    global basePlayerlistCoords, pixelCheckCoords, windowSize
    playerRow := getPlayerRow(basePlayerlistCoords, index)
    fixHeight := Round(0.0023148 * windowSize.winH)
    step := 5

    if windowSize.winH <= 1440 && windowSize.winH > 1080 {
        step := 3
    } else if windowSize.winH <= 1080 {
        step := 2
    }

    ; MsgBox(pixelCheckCoords.x ", " playerRow.y + fixHeight ", " pixelCheckCoords.w ", " pixelCheckCoords.h)

    return HasColorCoverage(pixelCheckCoords.x, playerRow.y + fixHeight, pixelCheckCoords.w, pixelCheckCoords.h,
        0x000000, 0.1, step)
}

getPlayerRow(baseRow, index) {
    global rowHeights

    y := baseRow.y

    loop index {
        y += rowHeights[A_Index]
    }

    return { x: baseRow.x, y: y, w: baseRow.w, h: rowHeights[index] }
}

HasColorCoverage(x1, y1, w, h, color, minPercent := 0.1, step := 4, variation := 0) {
    totalSamples := 0
    matchCount := 0

    x2 := x1 + w
    y2 := y1 + h

    y := y1
    while (y <= y2) {
        x := x1
        while (x <= x2) {
            totalSamples++
            if (PixelGetColor(x, y) = color)
                matchCount++
            x += step
        }
        y += step
    }

    percentage := (matchCount / totalSamples) * 100
    ; MsgBox("Color Coverage: " Round(percentage, 2) "%`nMatches: " matchCount "`nTotal Samples: " totalSamples)

    return (matchCount / totalSamples) >= minPercent
}

PasteToDiscord(gameHwnd) {
    global DISCORD_WIN_TITLE

    discordHwnd := 0

    ; Find the first Discord window that isn't the overlay (which also has "Discord.exe" as class)
    for hwnd in WinGetList("ahk_exe " DISCORD_WIN_TITLE) {
        if (WinGetTitle("ahk_id " hwnd) != "Discord Overlay") {
            discordHwnd := hwnd
            break
        }
    }

    if !discordHwnd {
        MsgBox("Discord window not found:`n" DISCORD_WIN_TITLE, "Discord Screenshot", "Icon!")
        return
    }

    WinActivate("ahk_id " discordHwnd)
    WinWaitActive("ahk_id " discordHwnd, , 2)

    if !WinActive("ahk_id " discordHwnd) {
        MsgBox("Failed to focus Discord")
        return
    }

    Send("^v")
    Sleep(120)
}

SendTextToDiscord(text) {
    if (!text)
        return

    SendText(text)
}

CaptureGameRegionToClipboard(gameHwnd := 0, coords := {}) {
    rect := GetCaptureRect(gameHwnd, coords)
    if !rect
        return false
    return CaptureScreenRegionToClipboard(rect.x, rect.y, rect.w, rect.h, false)
}

GetCaptureRect(gameHwnd := 0, coords := {}) {
    global rowHeights, playerCount
    if !coords {
        MsgBox("Missing percentage object for capture region.")
        return
    }

    additionalHeight := 0

    loop playerCount {
        additionalHeight += rowHeights[A_Index]
    }

    return {
        x: coords.x,
        y: coords.y,
        w: coords.w,
        h: coords.h + additionalHeight
    }
}

CaptureScreenRegionToClipboard(x, y, w, h, saveToFile := false, filePath := "") {
    try {
        rect := x "|" y "|" w "|" h
        pBitmap := Gdip_BitmapFromScreen(rect)
        if !pBitmap
            return false

        if saveToFile {
            if !filePath
                filePath := A_ScriptDir "\screenshot_" A_Now ".png"
            Gdip_SaveBitmapToFile(pBitmap, filePath)
        }
        ok := Gdip_SetBitmapToClipboard(pBitmap)
        Gdip_DisposeImage(pBitmap)
        return ok
    } catch {
        return false
    }
}

Gdip_CreateHBITMAPFromBitmap(pBitmap, Background := 0) {
    hBitmap := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", pBitmap, "UPtr*", &hBitmap, "Int", Background)
    return hBitmap
}

Gdip_SetBitmapToClipboard(pBitmap) {
    if !pBitmap
        return false

    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap, 0)
    if !hBitmap
        return false

    off1 := A_PtrSize = 8 ? 52 : 44
    off2 := A_PtrSize = 8 ? 32 : 24
    oi := Buffer(A_PtrSize = 8 ? 104 : 84, 0)
    if !DllCall("GetObject", "UPtr", hBitmap, "Int", oi.Size, "UPtr", oi.Ptr) {
        DllCall("DeleteObject", "UPtr", hBitmap)
        return false
    }

    hdib := DllCall("GlobalAlloc", "UInt", 2, "UPtr", 40 + NumGet(oi, off1, "UInt"), "UPtr")
    if !hdib {
        DllCall("DeleteObject", "UPtr", hBitmap)
        return false
    }

    pdib := DllCall("GlobalLock", "UPtr", hdib, "UPtr")
    DllCall("RtlMoveMemory", "UPtr", pdib, "UPtr", oi.Ptr + off2, "UPtr", 40)
    DllCall("RtlMoveMemory", "UPtr", pdib + 40, "UPtr", NumGet(oi, off2 - A_PtrSize, "UPtr"), "UPtr", NumGet(oi, off1,
        "UInt"))
    DllCall("GlobalUnlock", "UPtr", hdib)
    DllCall("DeleteObject", "UPtr", hBitmap)

    if !DllCall("OpenClipboard", "UPtr", 0) {
        DllCall("GlobalFree", "UPtr", hdib)
        return false
    }

    DllCall("EmptyClipboard")
    result := DllCall("SetClipboardData", "UInt", 8, "UPtr", hdib)
    DllCall("CloseClipboard")
    if !result {
        DllCall("GlobalFree", "UPtr", hdib)
        return false
    }

    return true
}
