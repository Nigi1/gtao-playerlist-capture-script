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
GAME_WIN_TITLE := "Photos.exe"
DISCORD_WIN_TITLE := "Discord.exe"

; CAP_X_PCT := 0.01640625
; CAP_Y_PCT := 0.01527777
; CAP_W_PCT := 0.22187500
; CAP_H_PCT := 0.59259259

; CAP_X_PCT_UW := 0.01640625
; CAP_Y_PCT_UW := 0.01527777
; CAP_W_PCT_UW := 0.22187500
; CAP_H_PCT_UW := 0.59259259

; OCR_X := 0.114322
; OCR_Y := 0.022222
; OCR_W := 0.014322
; OCR_H := 0.021296

OCR_PLAYERCOUNT := ""

PLAYER_RECT_PCT := {}

ROW_HEIGHTS := [76, 75, 75, 76, 75, 75, 76, 75, 75, 76, 75, 75, 76, 75, 76, 75]

BASE_SCREENSHOT_PCT := {
    x: 0.01640625,
    y: 0.01527777,
    w: 0.22187500,
    h: 0.06944444
}

OCR_SCREENSHOT_PCT := {
    x: 0.113802,
    y: 0.022222,
    w: 0.014843,
    h: 0.021296
}

; ------------------------------------------------------------------------------

; Hotkey(TRIGGER_HOTKEY_ONE, (*) => RunScreenshotSequence(1))
; Hotkey(TRIGGER_HOTKEY_TWO, (*) => RunScreenshotSequence(2))
Hotkey(TRIGGER_HOTKEY_One, (*) => TakeScreenshot())

TrayTip("Discord Screenshot", "Ready.`n" TRIGGER_HOTKEY_ONE " = Screenshot playerlist.", 1)

RunScreenshotSequence(count := 1) {
    global GAME_WIN_TITLE, DISCORD_WIN_TITLE, OVERLAY_KEY, DISCORD_PASTE_TEXT

    if !gameHwnd := WinExist("ahk_exe " GAME_WIN_TITLE) {
        MsgBox("Game window not found:`n" GAME_WIN_TITLE, "Discord Screenshot", "Icon!")
        return
    }

    loop count {
        WinActivate("ahk_id" gameHwnd)
        WinWaitActive("ahk_id " gameHwnd, , 2)

        SendOverlayKey(OVERLAY_KEY)
        Sleep(350)

        if !CaptureGameRegionToClipboard(gameHwnd) {
            MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
            return
        }

        PasteToDiscord(gameHwnd)

        if (A_Index < count) {
            WinActivate("ahk_id " gameHwnd)
            WinWaitActive("ahk_id " gameHwnd, , 2)
        }
    }
    SendTextToDiscord(DISCORD_PASTE_TEXT)
}

TakeScreenshot() {
    global GAME_WIN_TITLE, DISCORD_WIN_TITLE, OVERLAY_KEY, DISCORD_PASTE_TEXT, OCR_PLAYERCOUNT

    if !gameHwnd := WinExist("ahk_exe " GAME_WIN_TITLE) {
        MsgBox("Game window not found:`n" GAME_WIN_TITLE, "Discord Screenshot", "Icon!")
        return
    }

    loop 2 {
        WinActivate("ahk_id" gameHwnd)
        WinWaitActive("ahk_id " gameHwnd, , 2)

        SendOverlayKey(OVERLAY_KEY)
        Sleep(350)

        if (A_index != 2) {
            GetPlayerCount(gameHwnd)

            if !OCR_PLAYERCOUNT {
                ToolTip("OCR failed to read player count. Defaulting to 2 screenshots.")
                SetTimer(() => ToolTip(), -3000)
                OCR_PLAYERCOUNT := 30
            }
        }

        if !CaptureGameRegionToClipboard(gameHwnd) {
            MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
            return
        }

        PasteToDiscord(gameHwnd)

        if OCR_PLAYERCOUNT < 17
            break

    }

    SendTextToDiscord(DISCORD_PASTE_TEXT)
}

GetPlayerCount(gameHwnd) {
    global OCR_PLAYERCOUNT

    ocrPixels := GetCaptureRect(gameHwnd, OCR_SCREENSHOT_PCT)

    result := OCR.FromRect(ocrPixels.x, ocrPixels.y, ocrPixels.w, ocrPixels.h)
    ; MsgBox("OCR Result: " result.Text)
    cleanResult := RegExReplace(result.Text, "[^\d]", "")
    ; MsgBox(cleanResult)
    OCR_PLAYERCOUNT := cleanResult
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
    if !pctObj {
        MsgBox("Missing percentage object for capture region.")
        return
    }

    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id" gameHwnd)

    x := Round((winX + winW) * pctObj.x)
    y := Round((winY + winH) * pctObj.y)
    w := Round(winW * pctObj.w)
    h := Round(winH * pctObj.h)

    if (w <= 0 || h <= 0)
        return false

    MsgBox("Capture Rect:`nX: " x "`nY: " y "`nW: " w "`nH: " h)
    return { x: x, y: y, w: w, h: h }
}

CaptureGameRegionToClipboard(gameHwnd := 0) {
    global BASE_SCREENSHOT_PCT
    rect := GetCaptureRect(gameHwnd, BASE_SCREENSHOT_PCT)
    if !rect
        return false
    return CaptureScreenRegionToClipboard(rect.x, rect.y, rect.w, rect.h)
}

CaptureScreenRegionToClipboard(x, y, w, h) {
    try {
        rect := x "|" y "|" w "|" h
        pBitmap := Gdip_BitmapFromScreen(rect)
        if !pBitmap
            return false
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
