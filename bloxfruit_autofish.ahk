; ================================================
;  BLOX FRUITS - AUTO FISH MACRO
;  AutoHotkey v2
; ================================================
;  LUỒNG (1 lần, không tự loop):
;    [1] Giữ chuột trái (tích lực) → thả → quăng cần
;    [2] Chờ dấu "!" xuất hiện (cá cắn)
;    [3] Click chuột trái để giật cần
;    [4] Mini-game: block bám theo cá đến khi xong
;
;  PHÍM TẮT:
;    F1  = Bắt đầu 1 lần
;    F2  = Công cụ tìm màu pixel
;    F3  = Test quăng cần 1 lần
;    ESC = Dừng ngay
; ================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; ================================================
;  CẤU HÌNH - CHỈNH Ở ĐÂY
; ================================================

HoldDuration  := 800       ; ms giữ chuột tích lực
CastSettle    := 900       ; ms chờ cần chạm nước

; Màu dấu "!" khi cá cắn câu
BiteColor     := 0xFFADAF
BiteVariance  := 50

; Vùng quét dấu "!"
BiteScanX1    := 300
BiteScanY1    := 100
BiteScanX2    := 1400
BiteScanY2    := 600

; Tọa độ bar mini-game
BarLeft       := 609
BarRight      := 1868
BarTop        := 1052
BarBottom     := 1153

; Vùng quét trong bar (lùi vào trong để tránh viền/mũi tên ở 2 đầu)
BarScanX1     := 650
BarScanX2     := 1830
BarScanY1     := 1052
BarScanY2     := 1110

; Màu fish icon (xanh dương)
FishIconColor := 0x2975BD
FishVariance  := 55

; Màu block người chơi
BlockColor    := 0x545854
BlockVariance := 35

MiniGameTimeout := 30000

; Pixel kiểm tra thanh Power đầy (đo bằng F2)
PowerPixelX   := 2531
PowerPixelY   := 1112
PowerColor    := 0x639FFF
PowerVariance := 20   ; ms timeout tối đa mini-game

; Tốc độ ước tính block di chuyển (px/ms)
BlockHoldSpeed  := 0.50
BlockDriftSpeed := 0.70


; ================================================
;  BIẾN TRẠNG THÁI
; ================================================
global fishingActive := false
global trackingColor := false

; ================================================
;  HELPER
; ================================================
ShowStatus(msg) {
    ToolTip("[AUTO FISH] " . msg . "  |  F1=Bắt đầu  |  ESC=Dừng")
}

ColorMatch(c1, c2, v) {
    r := Abs(((c1 >> 16) & 0xFF) - ((c2 >> 16) & 0xFF))
    g := Abs(((c1 >>  8) & 0xFF) - ((c2 >>  8) & 0xFF))
    b := Abs(( c1        & 0xFF) - ( c2        & 0xFF))
    return (r <= v && g <= v && b <= v)
}

HideTooltip() {
    SetTimer(HideTooltip, 0)
    ToolTip()
}

; ================================================
;  F1 - BẬT / TẮT
; ================================================
#MaxThreadsPerHotkey 2
F1:: {
    global fishingActive
    if (fishingActive) {
        fishingActive := false
        MouseClick("Left",,,,, "U")
        Send "{LButton up}"
        ToolTip("[AUTO FISH] Đã dừng!")
        SetTimer(HideTooltip, 2000)
        return
    }

    fishingActive := true
    castCount     := 0

    loop {
        if (!fishingActive)
            break

        ; ---- BƯỚC 1: QUĂNG CẦN ----
        ShowStatus("Đang tích lực quăng cần...")
        MouseClick("Left",,,,, "D")
        Sleep(HoldDuration)
        MouseClick("Left",,,,, "U")

        if (!fishingActive)
            break

        ShowStatus("Cần đang bay... chờ chạm nước")
        Sleep(CastSettle)

        if (!fishingActive)
            break

        ; ---- BƯỚC 2: CHỜ DẤU "!" ----
        ShowStatus("Chờ cá cắn... (đang quét dấu !)")
        loop {
            if (!fishingActive)
                break
            foundX := 0, foundY := 0
            if (PixelSearch(&foundX, &foundY, BiteScanX1, BiteScanY1, BiteScanX2, BiteScanY2, BiteColor, BiteVariance))
                break
            Sleep(80)
        }

        if (!fishingActive)
            break

        ; ---- BƯỚC 3: GIẬT CẦN ----
        ShowStatus("CÁ CẮN! Đang giật cần...")
        MouseClick("Left")
        Sleep(500)

        if (!fishingActive)
            break

        ; ---- BƯỚC 4: MINI-GAME ----
        ; Kiểm tra thanh Power đầy → bấm Z trước khi chơi
        c := PixelGetColor(PowerPixelX, PowerPixelY, "RGB")
        if (ColorMatch(c, PowerColor, PowerVariance)) {
            ShowStatus("Power đầy! Bấm Z...")
            Send "{z}"
            Sleep(500)
        }

        ShowStatus("Bắt đầu mini-game...")
        PlayMiniGame()

        if (!fishingActive)
            break

        ; ---- SAU MINI-GAME: đợi 5s → click → đợi 2s → lặp lại ----
        castCount++
        ShowStatus("Xong! (" . castCount . " con) Chờ 5s...")
        Sleep(5000)

        if (!fishingActive)
            break

        MouseClick("Left")
        ShowStatus("Xong! (" . castCount . " con) Chờ 2s...")
        Sleep(2000)
    }

    fishingActive := false
    ToolTip("[AUTO FISH] Đã dừng  |  Câu được: " . castCount . " con  |  F1=Chạy lại")
    SetTimer(HideTooltip, 5000)
}

; ================================================
;  MINI-GAME: POSITION + VELOCITY TRACKING
; ================================================
PlayMiniGame() {
    global fishingActive

    startGame  := A_TickCount
    missCount  := 0
    MissMax    := 10
    MinPlayMs  := 2000
    isHolding  := false
    DeadBand   := 12
    lastFx     := -1
    prevFx     := -1   ; frame trước nữa để tính velocity
    locked     := false
    lockStart  := 0
    LockMs     := 1200
    LockRange  := 55

    lastBlockX := BarLeft + 150   ; vị trí block lần cuối thấy được (gray pixel)

    loop {
        if (!fishingActive) {
            if (isHolding) {
                Send "{LButton up}"
                isHolding := false
            }
            return
        }

        if ((A_TickCount - startGame) > MiniGameTimeout) {
            if (isHolding) {
                Send "{LButton up}"
                isHolding := false
            }
            ShowStatus("Timeout mini-game!")
            return
        }

        ; --- Tìm block xám ---
        bx := 0, by := 0
        blockFound := PixelSearch(&bx, &by, BarScanX1, BarScanY1, BarScanX2, BarScanY2, BlockColor, BlockVariance)
        if (blockFound)
            lastBlockX := bx   ; chỉ cập nhật khi thấy thật

        ; --- Tìm cá (xanh) ---
        fx := 0, fy := 0
        fishFound := PixelSearch(&fx, &fy, BarScanX1, BarScanY1, BarScanX2, BarScanY2, FishIconColor, FishVariance)

        ; --- Phát hiện kết thúc ---
        if ((A_TickCount - startGame) > MinPlayMs) {
            if (!fishFound && !blockFound) {
                missCount++
                if (missCount >= MissMax) {
                    if (isHolding) {
                        Send "{LButton up}"
                        isHolding := false
                    }
                    ShowStatus("Mini-game xong!")
                    Sleep(800)
                    return
                }
            } else {
                missCount := 0
            }
        }

        ; --- Chế độ LOCK ---
        if (locked) {
            elapsed := A_TickCount - lockStart
            if (elapsed >= LockMs) {
                ; Hết 2s → thoát lock, tracking lại
                locked := false
            } else {
                ; Pulse 200ms hold / 200ms release
                if (Mod(elapsed, 400) < 200) {
                    if (!isHolding) {
                        Send "{LButton down}"
                        isHolding := true
                    }
                } else {
                    if (isHolding) {
                        Send "{LButton up}"
                        isHolding := false
                    }
                }
                ShowStatus("LOCK " . (LockMs - elapsed) . "ms | ca=" . fx . " block=" . lastBlockX . " miss=" . missCount)
                Sleep(40)
                continue
            }
        }

        ; --- Check lock trước (kể cả khi fishFound = false) ---
        if (!locked) {
            if (!blockFound) {
                ; Block xám biến mất = block đang chồng cá → LOCK
                locked    := true
                lockStart := A_TickCount
                ShowStatus("Vào LOCK (overlap)! | block=" . lastBlockX)
            } else if (fishFound && Abs(fx - lastBlockX) <= LockRange) {
                ; Vị trí đủ gần → LOCK
                locked    := true
                lockStart := A_TickCount
                lastBlockX := fx
                ShowStatus("Vào LOCK (pos)! | ca=" . fx . " block=" . lastBlockX)
            }
        }

        ; --- Tracking (chỉ chạy khi chưa lock) ---
        if (!locked) {
            if (fishFound) {
                ; Dự đoán vị trí cá frame tiếp theo dựa vào velocity
                velocity  := (lastFx >= 0) ? (fx - lastFx) : 0
                predictFx := fx + velocity   ; cá sẽ ở đây frame sau

                if (predictFx > lastBlockX + 8) {
                    if (!isHolding) {
                        Send "{LButton down}"
                        isHolding := true
                    }
                    ShowStatus("Track → | ca=" . fx . " v=" . velocity . " block=" . lastBlockX . " miss=" . missCount)

                } else if (predictFx < lastBlockX - 38) {
                    if (isHolding) {
                        Send "{LButton up}"
                        isHolding := false
                    }
                    ShowStatus("Track ← | ca=" . fx . " v=" . velocity . " block=" . lastBlockX . " miss=" . missCount)

                } else {
                    ShowStatus("Track = | ca=" . fx . " v=" . velocity . " block=" . lastBlockX . " miss=" . missCount)
                }

                prevFx := lastFx
                lastFx := fx

            } else {
                ; Không thấy cá → hold để tìm
                lastFx := -1
                ShowStatus("Tìm cá... block=" . lastBlockX . " miss=" . missCount)
                if (!isHolding) {
                    Send "{LButton down}"
                    isHolding := true
                }
            }
        }

        Sleep(20)
    }
}

; ================================================
;  F2 - CÔNG CỤ TÌM MÀU PIXEL
; ================================================
F2:: {
    global trackingColor
    MsgBox(
        "HƯỚNG DẪN:`n`n" .
        "1. Click OK để bắt đầu`n" .
        "2. Di chuột đến vị trí cần đo`n" .
        "3. Ghi lại X, Y, màu HEX`n`n" .
        "Nhấn ESC để thoát chế độ theo dõi",
        "Tìm màu pixel - F2", 64
    )
    trackingColor := true
    SetTimer(TrackPixel, 50)
}

TrackPixel() {
    global trackingColor
    if (!trackingColor) {
        SetTimer(TrackPixel, 0)
        return
    }
    MouseGetPos(&mx, &my)
    c := PixelGetColor(mx, my, "RGB")
    hexStr := Format("0x{:06X}", c)
    rVal := (c >> 16) & 0xFF
    gVal := (c >>  8) & 0xFF
    bVal :=  c        & 0xFF
    ToolTip("X=" . mx . "  Y=" . my . "`nHEX: " . hexStr . "`nRGB: " . rVal . "," . gVal . "," . bVal . "`n`nESC = thoát")
}

; ================================================
;  F3 - TEST QUĂNG CẦN
; ================================================
F3:: {
    ToolTip("[TEST] Đang tích lực " . HoldDuration . "ms...")
    MouseClick("Left",,,,, "D")
    Sleep(HoldDuration)
    MouseClick("Left",,,,, "U")
    ToolTip("[TEST] Đã quăng!")
    SetTimer(HideTooltip, 2000)
}

; ================================================
;  ESC - DỪNG KHẨN CẤP
; ================================================
~Escape:: {
    global fishingActive, trackingColor
    if (trackingColor) {
        trackingColor := false
        SetTimer(TrackPixel, 0)
        ToolTip()
        return
    }
    if (fishingActive) {
        fishingActive := false
        MouseClick("Left",,,,, "U")
        Send "{LButton up}"
        ToolTip("[AUTO FISH] Đã dừng!")
        SetTimer(HideTooltip, 2000)
    }
}

; Thông báo khởi động
ToolTip("[AUTO FISH] Sẵn sàng!  F1=Bắt đầu  F2=Tìm màu  F3=Test")
SetTimer(HideTooltip, 4000)
