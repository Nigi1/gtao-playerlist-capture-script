#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook
#Include <AHKv2_Screenshot_Tools>

pToken := Gdip_Startup()
OnExit(*) => Gdip_Shutdown(pToken)

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
CoordMode("Pixel", "Screen")

configFile := A_ScriptDir "\config.ini"

; --- CONFIG -------------------------------------------------------------------
registeredHotkeys := Map()
autoModeEnabled := false
screenshotInterval := 10
captureHotkey := "F10"
tempCmdHotkey := "F6"
settingsHotkey := "F7"
overlayKey := "z"
discordPasteText := ""
safezoneSetting := 7
GAME_WIN_TITLE := "GTA5_enhanced.exe"
DISCORD_WIN_TITLE := "Discord.exe"

ROW_HEIGHTS_PX := Map(
    2160, [76, 75, 76, 75, 75, 76, 75, 75, 76, 75, 75, 76, 75, 75, 76, 75],
    1440, [50, 50, 51, 50, 50, 51, 50, 50, 50, 50, 51, 50, 50, 50, 51, 50],
    1080, [37, 38, 38, 37, 38, 38, 37, 38, 38, 37, 38, 38, 38, 37, 38, 37],
    720, [25, 25, 25, 26, 25, 25, 25, 25, 25, 25, 25, 26, 25, 25, 25, 25]
)

SAFEZONE_PX := Map(
    0, { x: 196, y: 108 },
    1, { x: 178, y: 98 },
    2, { x: 158, y: 87 },
    3, { x: 139, y: 76 },
    4, { x: 120, y: 65 },
    5, { x: 100, y: 54 },
    6, { x: 81, y: 44 },
    7, { x: 63, y: 33 },
    8, { x: 44, y: 22 },
    9, { x: 25, y: 11 },
    10, { x: 5, y: 0 }
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
    x: 863,
    y: 113,
    w: 28,
    h: 5
}

basePlayerlistCoords := {}
pixelCheckCoords := {}
rowHeights := []
windowSize := {}
playerCount := 0
widthOffset := 0
screenshotLoopActive := false

; ------------------------------------------------------------------------------

LoadConfig(configFile)

RegisterHotkey("capture", captureHotkey, (*) => HandleScreenshotHotkey())
RegisterHotkey("tempCmd", tempCmdHotkey, (*) => UpdatePasteTextTemp())
RegisterHotkey("settings", settingsHotkey, (*) => ShowSettingsForm())

TrayTip(captureHotkey " = Capture playerlist`n"
    . tempCmdHotkey " = Edit command (temporary)`n"
    . settingsHotkey " = Open settings`n"
    . (autoModeEnabled ? "AutoMode is enabled" : "AutoMode is disabled"),
    "Playerlist Capture", 1)

HandleScreenshotHotkey() {
    global autoModeEnabled

    if (autoModeEnabled) {
        ScreenshotLoop()
    } else {
        CapturePlayerlist()
    }
}

ScreenshotLoop() {
    global screenshotLoopActive

    if (screenshotLoopActive) {
        SetTimer(CapturePlayerlist, 0)

        result := MsgBox(
            "Automatic screenshots are currently running, taking a screenshot every 10 minutes.`n`nDo you want to stop automatic screenshots now?",
            "Stop Automatic Screenshots?", "YesNo")

        if (result = "Yes") {
            screenshotLoopActive := false
        } else {
            Sleep(1000)
            CapturePlayerlist()
            SetTimer(CapturePlayerlist, GetIntervalInMilliseconds())
        }
    } else {
        result := MsgBox(
            "AutoMode is enabled. Starting automatic captures will take a screenshot of the player list every 10 minutes until you press the hotkey again to stop.`n`nDo you want to start automatic captures now?",
            "Start Automatic Captures?", "YesNo")

        if (result = "Yes") {
            screenshotLoopActive := true
            Sleep(1000)
            CapturePlayerlist()
            SetTimer(CapturePlayerlist, GetIntervalInMilliseconds())
        }
    }
}

GetIntervalInMilliseconds() {
    global screenshotInterval

    return screenshotInterval * 60 * 1000
}

CapturePlayerlist() {
    global GAME_WIN_TITLE, overlayKey, discordPasteText
    global basePlayerlistCoords, pixelCheckCoords, playerCount, rowHeights, windowSize, autoModeEnabled

    playerCount := 0

    if !gameHwnd := WinExist("ahk_exe " GAME_WIN_TITLE) {
        MsgBox("Game window not found:`n" GAME_WIN_TITLE, "Discord Screenshot", "Icon!")
        return
    }

    windowSize := GetWindowSize(gameHwnd)
    ApplySafezoneOffset(safezoneSetting)
    basePlayerlistCoords := GetScreenRelativeCoords(BASE_REF)
    if widthOffset > 0
        basePlayerlistCoords.x += widthOffset
    pixelCheckCoords := GetScreenRelativeCoords(COLORCHECK_REF)
    rowHeights := GetRowHeights()

    WinActivate("ahk_id" gameHwnd)
    WinWaitActive("ahk_id " gameHwnd, , 2)

    SendOverlayKey(overlayKey)
    Sleep(200)
    playerCount := FindLastActivePlayerRow()

    if !CaptureGameRegionToClipboard(gameHwnd, basePlayerlistCoords) {
        MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
        return
    }

    PasteToDiscord(gameHwnd)

    SendTextToDiscord(discordPasteText)
    Sleep(100)

    if playerCount = 16 {
        WinActivate("ahk_id" gameHwnd)
        WinWaitActive("ahk_id " gameHwnd, , 2)

        SendOverlayKey(overlayKey)
        Sleep(200)
        playerCount := FindLastActivePlayerRow()

        if playerCount != 0 {
            if !CaptureGameRegionToClipboard(gameHwnd, basePlayerlistCoords) {
                MsgBox("Failed to capture the first screenshot.", "Discord Screenshot", "Icon!")
                return
            }

            PasteToDiscord(gameHwnd)
        }
    }

    if (autoModeEnabled) {
        Send("{Enter}")
        Sleep(500)
        WinActivate("ahk_id" gameHwnd)
    }

}

UpdatePasteTextTemp() {
    global discordPasteText

    Suspend(true)

    existingValue := discordPasteText

    inputGui := Gui("+AlwaysOnTop", "Set Value")
    inputGui.BackColor := "F3F3F3"
    inputGui.MarginX := 20
    inputGui.MarginY := 15
    inputGui.SetFont("s10 c333333", "Segoe UI")

    inputGui.Add("Text", "w260", "Discord Paste Command")
    inputGui.SetFont("s9 c666666")
    inputGui.Add("Text", "w260 y+2", "This value is used for the current session only.")

    inputGui.SetFont("s11 cBlack", "Segoe UI")
    editCtrl := inputGui.Add("Edit", "w260 h30 y+12 vUserInput", existingValue)

    inputGui.SetFont("s10 cWhite bold")
    btnSaveTemp := inputGui.Add("Button", "w260 h32 y+15 Default", "Save")
    btnSaveTemp.OnEvent("Click", (*) => SaveTempText(inputGui, editCtrl))

    inputGui.OnEvent("Close", (*) => CloseGui(inputGui))
    inputGui.OnEvent("Escape", (*) => CloseGui(inputGui))
    inputGui.Show("w300 Center")
}

SaveTempText(inputGui, editCtrl) {
    global discordPasteText

    discordPasteText := editCtrl.Text
    inputGui.Destroy()
    Suspend(false)
}

ShowSettingsForm() {
    global configFile

    Suspend(true)

    settingsGui := Gui("+AlwaysOnTop", "Settings")
    settingsGui.BackColor := "F3F3F3"
    settingsGui.MarginX := 20
    settingsGui.MarginY := 15
    settingsGui.SetFont("s10 c333333", "Segoe UI")

    settingsGui.Add("Text", "w260", "Settings")
    settingsGui.SetFont("s9 c666666")
    settingsGui.Add("Text", "w260 y+2", "Changes are saved to config.ini")

    settingsGui.SetFont("s10 cBlack", "Segoe UI")

    settingsGui.Add("Text", "w120 y+15", "Auto Mode:")
    autoModeToggle := settingsGui.Add("DropDownList", "w150 x+10 yp Choose" ((IniRead(configFile, "Settings",
        "AutoMode", "false") = "true") ? 1 : 2), ["On", "Off"])

    settingsGui.Add("Text", "w120 x20 y+10", "Interval (minutes):")
    editInterval := settingsGui.Add("Edit", "w150 x+10 yp", IniRead(configFile, "Settings", "ScreenshotInterval",
        "10"))

    settingsGui.Add("Text", "w120 x20 y+15", "Capture Hotkey:")
    editCapture := settingsGui.Add("Hotkey", "w150 x+10 yp", IniRead(configFile, "Hotkeys", "CaptureHotkey", ""))

    settingsGui.Add("Text", "w120 x20 y+10", "Command Hotkey:")
    editTempCommand := settingsGui.Add("Hotkey", "w150 x+10 yp", IniRead(configFile, "Hotkeys", "TempCommandHotkey", ""
    ))

    settingsGui.Add("Text", "w120 x20 y+10", "Settings Hotkey:")
    editSettings := settingsGui.Add("Hotkey", "w150 x+10 yp", IniRead(configFile, "Hotkeys", "SettingsHotkey", ""))

    settingsGui.Add("Text", "w120 x20 y+10", "Overlay Toggle Key:")
    editOverlay := settingsGui.Add("Edit", "w150 x+10 yp", IniRead(configFile, "Settings", "OverlayToggleKey", ""))

    settingsGui.Add("Text", "w120 x20 y+10", "Command:")
    editCommand := settingsGui.Add("Edit", "w150 x+10 yp", IniRead(configFile, "Settings", "Command", ""))

    settingsGui.Add("Text", "w120 x20 y+10", "Safezone Setting:")
    ddlSafezone := settingsGui.Add("DropDownList", "w150 x+10 yp Choose" (IniRead(configFile, "Settings",
        "SafezoneSetting", "0") + 1), ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])

    settingsGui.SetFont("s10 cWhite bold")
    btnSave := settingsGui.Add("Button", "w280 h32 x20 y+20 Default", "Save")
    btnSave.OnEvent("Click", (*) => SaveSettingsForm(settingsGui, editCapture, editTempCommand, editSettings,
        editOverlay, editCommand, ddlSafezone, autoModeToggle, editInterval))

    settingsGui.OnEvent("Close", (*) => CloseGui(settingsGui))
    settingsGui.OnEvent("Escape", (*) => CloseGui(settingsGui))
    settingsGui.Show("w320 Center")
}

CloseGui(settingsGui) {
    settingsGui.Destroy()
    Suspend(false)
}

SaveSettingsForm(settingsGui, editCapture, editTempCommand, editSettings, editOverlay, editCommand, ddlSafezone,
    autoModeToggle, editInterval) {
    global configFile

    newCaptureHotkey := editCapture.Value
    newTempCmdHotkey := editTempCommand.Value
    newSettingsHotkey := editSettings.Value

    IniWrite(newCaptureHotkey, configFile, "Hotkeys", "CaptureHotkey")
    IniWrite(newTempCmdHotkey, configFile, "Hotkeys", "TempCommandHotkey")
    IniWrite(newSettingsHotkey, configFile, "Hotkeys", "SettingsHotkey")
    IniWrite(editOverlay.Text, configFile, "Settings", "OverlayToggleKey")
    IniWrite(editCommand.Text, configFile, "Settings", "Command")
    IniWrite(ddlSafezone.Text, configFile, "Settings", "SafezoneSetting")
    IniWrite(autoModeToggle.Text = "On" ? "true" : "false", configFile, "Settings", "AutoMode")
    IniWrite(editInterval.Text, configFile, "Settings", "ScreenshotInterval")

    settingsGui.Destroy()
    Suspend(false)

    LoadConfig(configFile)

    UpdateHotkey("capture", newCaptureHotkey)
    UpdateHotkey("tempCmd", newTempCmdHotkey)
    UpdateHotkey("settings", newSettingsHotkey)
}

RegisterHotkey(name, keyString, callback) {
    global registeredHotkeys

    if (keyString != "")
        Hotkey(keyString, callback, "On")

    registeredHotkeys[name] := { key: keyString, callback: callback }
}

UpdateHotkey(name, newKeyString) {
    global registeredHotkeys

    if !registeredHotkeys.Has(name) {
        throw Error("Unknown hotkey name: " name)
    }

    entry := registeredHotkeys[name]
    oldKeyString := entry.key

    if (oldKeyString != "" && oldKeyString != newKeyString) {
        try Hotkey(oldKeyString, "Off")
    }

    if (newKeyString != "") {
        Hotkey(newKeyString, entry.callback, "On")
    }

    entry.key := newKeyString
}

GetWindowSize(gameHwnd) {
    global windowSize, widthOffset
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " gameHwnd)

    wndScreenshotWidth := winH * (16 / 9)
    if (winW != wndScreenshotWidth) {
        widthOffset := ((winW - wndScreenshotWidth) / 2) - 1
    }

    scaleX := winW / 3840
    scaleY := winH / 2160

    return {
        winX: winX,
        winY: winY,
        winW: wndScreenshotWidth,
        winH: winH,
        winScaleX: scaleX,
        winScaleY: scaleY
    }
}

ApplySafezoneOffset(offsetSetting) {
    global SAFEZONE_PX, BASE_REF

    if !SAFEZONE_PX.Has(offsetSetting) {
        offsetSetting := 7
    }
    offset := SAFEZONE_PX[offsetSetting]
    BASE_REF.x := offset.x
    BASE_REF.y := offset.y
}

GetRowHeights() {
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

GetScreenRelativeCoords(refObj) {
    global windowSize

    return {
        x: Round(refObj.x * windowSize.winScaleX) + windowSize.winX,
        y: Round(refObj.y * windowSize.winScaleY) + windowSize.winY,
        w: Round(refObj.w * windowSize.winScaleX),
        h: Round(refObj.h * windowSize.winScaleY)
    }
}

SendOverlayKey(keySpec) {
    SendInput("{z down}")
    Sleep(50)
    SendInput("{z up}")
}

FindLastActivePlayerRow(maxIndex := 16) {
    global playerCount

    if !RowHasColor(1) {
        playerCount := 0
        return 0
    }

    if RowHasColor(maxIndex) {
        playerCount := maxIndex
        return maxIndex
    }

    lo := 1
    hi := maxIndex
    while (hi - lo > 1) {
        mid := (lo + hi) // 2
        if RowHasColor(mid)
            lo := mid
        else
            hi := mid
    }

    playerCount := lo
    return lo
}

RowHasColor(index) {
    global basePlayerlistCoords, pixelCheckCoords, windowSize
    playerRowY := GetPlayerRowY(basePlayerlistCoords, pixelCheckCoords, index)

    if windowSize.winH > 1440 {
        step := 4
    } else if windowSize.winH > 720 {
        step := 2
    } else {
        step := 1
    }

    return HasColorCoverage(pixelCheckCoords.x, playerRowY,
        pixelCheckCoords.w,
        pixelCheckCoords.h,
        0x000000, 0.1, step)
}

GetPlayerRowY(baseRow, checkCoords, index) {
    global rowHeights

    y := checkCoords.y

    loop index - 1 {
        y += rowHeights[A_Index]
    }

    return y
}

HasColorCoverage(x1, y1, w, h, color, minPercent := 0.1, step := 4, variation := 0) {
    totalSamples := 0
    matchCount := 0

    x2 := x1 + w - 1
    y2 := y1 + h - 1

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

LoadConfig(configFile) {
    global autoModeEnabled, screenshotInterval, captureHotkey, tempCmdHotkey, settingsHotkey, overlayKey,
        discordPasteText, safezoneSetting

    errors := []

    autoModeEnabled := (Trim(IniRead(configFile, "Settings", "AutoMode", "false")) = "true")

    screenshotInterval := Trim(IniRead(configFile, "Settings", "ScreenshotInterval", "10"))
    if (!IsNumber(screenshotInterval) || screenshotInterval <= 0 || screenshotInterval > 60) {
        errors.Push("The interval '" screenshotInterval "' is not a valid interval. Falling back to a default interval of 10 minutes."
        )
        screenshotInterval := 10
    }

    captureHotkey := Trim(IniRead(configFile, "Hotkeys", "CaptureHotkey", "F10"))
    if !IsValidKeyName(StripModifiers(captureHotkey)) {
        errors.Push("CaptureHotkey '" captureHotkey "' is not a recognized key. Falling back to F10.")
        captureHotkey := "F10"
    }

    tempCmdHotkey := Trim(IniRead(configFile, "Hotkeys", "TempCommandHotkey", "F6"))
    if !IsValidKeyName(StripModifiers(tempCmdHotkey)) {
        errors.Push("TempCommandHotkey '" tempCmdHotkey "' is not a recognized key. Falling back to F6.")
        captureHotkey := "F6"
    }

    settingsHotkey := Trim(IniRead(configFile, "Hotkeys", "SettingsHotkey", "F7"))
    if !IsValidKeyName(StripModifiers(settingsHotkey)) {
        errors.Push("SettingsHotkey '" settingsHotkey "' is not a recognized key. Falling back to F7.")
        captureHotkey := "F7"
    }

    overlayKey := Trim(IniRead(configFile, "Settings", "OverlayToggleKey", "z"))
    if !IsValidKeyName(overlayKey) {
        errors.Push("OverlayToggleKey '" overlayKey "' is not a recognized key. Falling back to 'z'.")
        overlayKey := "z"
    }

    discordPasteText := Trim(IniRead(configFile, "Settings", "Command", ""))

    rawSafezone := Trim(IniRead(configFile, "Settings", "SafezoneSetting", "7"))
    safezoneSetting := 7
    try {
        val := Integer(rawSafezone)
        if (val >= 0 && val <= 10)
            safezoneSetting := val
        else
            errors.Push("SafezoneSetting must be between 0-10. Falling back to 7.")
    } catch {
        errors.Push("SafezoneSetting must be a number. Falling back to 7.")
    }

    if (errors.Length > 0) {
        msg := "Some settings in config.ini were invalid:`n`n"
        for err in errors
            msg .= "- " err "`n"
        MsgBox(msg, "Config Warning", "Icon!")
    }
}

IsValidKeyName(keyName) {
    return (GetKeyVK(keyName) != 0) || (GetKeySC(keyName) != 0)
}

StripModifiers(keyStr) {
    return RegExReplace(keyStr, "^[\^!+#]+")
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
