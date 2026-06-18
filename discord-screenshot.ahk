#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
#Include <AHKv2_Screenshot_Tools>
#Include <OCR>

pToken := Gdip_Startup()
OnExit(*) => Gdip_Shutdown(pToken)

configFile := A_ScriptDir "\config.ini"

; --- CONFIG -------------------------------------------------------------------
TRIGGER_HOTKEY_ONE := IniRead(configFile, "hotkeys", "capture_one", "F9")
TRIGGER_HOTKEY_TWO := IniRead(configFile, "hotkeys", "capture_two", "F10")
OVERLAY_KEY := IniRead(configFile, "hotkeys", "game_overlay", "z")
DISCORD_PASTE_TEXT := IniRead(configFile, "hotkeys", "command_text", "")
GAME_WIN_TITLE := "GTA.exe"
DISCORD_WIN_TITLE := "Discord.exe"

ROW_HEIGHTS_PCT := [0.069907, 0.034722, 0.035185, 0.034722, 0.034722, 0.035185, 0.034722, 0.034722, 0.035185, 0.034722,
    0.034722, 0.035185, 0.034722, 0.034722, 0.035185, 0.034722]

ROW_HEIGHTS_COORDS := []

BASE_SCREENSHOT_PCT := {
    x: 0.01640625,
    y: 0.01527777,
    w: 0.22213541,
    h: 0.06990740
}

BASE_SCREENSHOT_COORDS := {}

PIXEL_COLOR_PCT := {
    x: 0.224739,
    y: 0.050000,
    w: 0.006770,
    h: 0.004629
}

BASE_PIXEL_COORDS := {}

WINDOW_SIZE := {}

PLAYER_COUNT := 1

; ------------------------------------------------------------------------------

Hotkey(TRIGGER_HOTKEY_One, (*) => GetPixelColors())

TrayTip("Discord Screenshot", "Ready.`n" TRIGGER_HOTKEY_ONE " = Screenshot playerlist.", 1)

; RunScreenshotSequence(count := 1) {
;     global GAME_WIN_TITLE, DISCORD_WIN_TITLE, OVERLAY_KEY, DISCORD_PASTE_TEXT

;     if !gameHwnd := WinExist("ahk_exe " GAME_WIN_TITLE) {
;         MsgBox("Game window not found:`n" GAME_WIN_TITLE, "Discord Screenshot", "Icon!")
;         return
;     }

;     loop count {
;         WinActivate("ahk_id" gameHwnd)
;         WinWaitActive("ahk_id " gameHwnd, , 2)

;         SendOverlayKey(OVERLAY_KEY)
;         Sleep(350)

;         if !CaptureGameRegionToClipboard(gameHwnd) {
;             MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
;             return
;         }

;         PasteToDiscord(gameHwnd)

;         if (A_Index < count) {
;             WinActivate("ahk_id " gameHwnd)
;             WinWaitActive("ahk_id " gameHwnd, , 2)
;         }
;     }
;     SendTextToDiscord(DISCORD_PASTE_TEXT)
; }

GetPixelColors() {
    global GAME_WIN_TITLE, DISCORD_WIN_TITLE, OVERLAY_KEY, DISCORD_PASTE_TEXT
    global BASE_SCREENSHOT_COORDS, BASE_PIXEL_COORDS

    if !gameHwnd := WinExist("ahk_exe " GAME_WIN_TITLE) {
        MsgBox("Game window not found:`n" GAME_WIN_TITLE, "Discord Screenshot", "Icon!")
        return
    }

    getWindowSize(gameHwnd)

    BASE_SCREENSHOT_COORDS := getScreenRelativeCoords(BASE_SCREENSHOT_PCT)
    BASE_PIXEL_COORDS := getScreenRelativeCoords(PIXEL_COLOR_PCT)

    getScreenRelativeRowHeight(gameHwnd, ROW_HEIGHTS_PCT)

    WinActivate("ahk_id" gameHwnd)
    WinWaitActive("ahk_id " gameHwnd, , 2)

    SendOverlayKey(OVERLAY_KEY)
    Sleep(100)
    findPlayerCount()

    if !CaptureGameRegionToClipboard(gameHwnd) {
        MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
        return
    }

    PasteToDiscord(gameHwnd)

    if PLAYER_COUNT = 16 {
        WinActivate("ahk_id" gameHwnd)
        WinWaitActive("ahk_id " gameHwnd, , 2)

        SendOverlayKey(OVERLAY_KEY)
        Sleep(100)
        findPlayerCount()

        if !CaptureGameRegionToClipboard(gameHwnd) {
            MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
            return
        }

        PasteToDiscord(gameHwnd)
    }

    SendTextToDiscord(DISCORD_PASTE_TEXT)
}

findPlayerCount() {
    global PLAYER_COUNT

    PLAYER_COUNT := FindLastActivePlayerRow()

    MsgBox("Detected Player Count: " PLAYER_COUNT)
}

FindLastActivePlayerRow(maxIndex := 16) {
    global PLAYER_COUNT
    if RowHasColor(16) {
        PLAYER_COUNT := 16
        return 16
    }

    if RowHasColor(8) {
        index := 8
        while (index + 1 <= maxIndex && RowHasColor(index + 1)) {
            index++
        }
        PLAYER_COUNT := index
        return index
    }

    index := 1
    while (index + 1 <= maxIndex && RowHasColor(index + 1)) {
        index++
    }
    PLAYER_COUNT := index
    return index
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

RowHasColor(index) {
    global BASE_PIXEL_COORDS, WINDOW_SIZE
    playerRow := getPlayerRow(BASE_SCREENSHOT_COORDS, index)
    fixHeight := 0.0023148 * WINDOW_SIZE.winH

    return HasColorCoverage(BASE_PIXEL_COORDS.x, playerRow.y + fixHeight, BASE_PIXEL_COORDS.w, BASE_PIXEL_COORDS.h -
        fixHeight, 0x000000, 0.2)
}

getPlayerRow(baseRow, index) {
    global ROW_HEIGHTS_COORDS

    y := baseRow.y

    loop index - 1 {
        y += ROW_HEIGHTS_COORDS[A_Index]
    }

    return { x: baseRow.x, y: y, w: baseRow.w, h: ROW_HEIGHTS_COORDS[index] }
}

getScreenRelativeCoords(pctObj) {
    global WINDOW_SIZE

    x := Round((WINDOW_SIZE.winX + WINDOW_SIZE.winW) * pctObj.x)
    y := Round((WINDOW_SIZE.winY + WINDOW_SIZE.winH) * pctObj.y)
    w := Round(WINDOW_SIZE.winW * pctObj.w)
    h := Round(WINDOW_SIZE.winH * pctObj.h)

    return { x: x, y: y, w: w, h: h }
}

getWindowSize(gameHwnd) {
    global WINDOW_SIZE
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " gameHwnd)
    WINDOW_SIZE.winX := winX
    WINDOW_SIZE.winY := winY
    WINDOW_SIZE.winW := winW
    WINDOW_SIZE.winH := winH
}

getScreenRelativeRowHeight(gameHwnd, pctArray) {
    global ROW_HEIGHTS_COORDS

    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id" gameHwnd)

    loop pctArray.Length {
        ROW_HEIGHTS_COORDS.Push(Round(winH * pctArray[A_Index]))
    }
}

PasteToDiscord(gameHwnd) {

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

SendOverlayKey(keySpec) {
    SendInput("{z down}")
    Sleep(50)
    SendInput("{z up}")
}

GetCaptureRect(gameHwnd := 0, pctObj := {}) {
    global ROW_HEIGHTS_COORDS, PLAYER_COUNT
    if !pctObj {
        MsgBox("Missing percentage object for capture region.")
        return
    }

    additionalHeight := 0

    loop PLAYER_COUNT - 1 {
        additionalHeight += ROW_HEIGHTS_COORDS[A_Index + 1]
    }

    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id" gameHwnd)

    x := Round((winX + winW) * pctObj.x)
    y := Round((winY + winH) * pctObj.y)
    w := Round(winW * pctObj.w)
    h := Round(winH * pctObj.h) + additionalHeight

    if (w <= 0 || h <= 0)
        return false

    ; MsgBox("Capture Rect:`nX: " x "`nY: " y "`nW: " w "`nH: " h)
    return { x: x, y: y, w: w, h: h }
}

CaptureGameRegionToClipboard(gameHwnd := 0) {
    global BASE_SCREENSHOT_PCT
    rect := GetCaptureRect(gameHwnd, BASE_SCREENSHOT_PCT)
    if !rect
        return false
    return CaptureScreenRegionToClipboard(rect.x, rect.y, rect.w, rect.h, false)
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
