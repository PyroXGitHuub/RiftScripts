--[[
    PyroX GUI Library  ·  v3.4.0  (Loading Screen)
    ------------------------------------------------------------
    API ist 1:1 kompatibel mit v2.x:
      Library.New / Window:AddTab / Tab:AddSubTab
      AddToggle, AddSlider, AddKeybind, AddDropdown (:Refresh),
      AddFilterButton (:AddItem), AddColorPicker, AddToggleWithKey,
      AddTextBox, AddButton, Library.SaveSettings / LoadSettings
    Flags, Config-Ordner & Callbacks funktionieren exakt wie vorher.

    NEU in v3.1.0 (Config-System):
      - Dropdown mit allen vorhandenen Configs (Config auswählen)
      - Load / Save / Delete (Delete mit Bestätigung)
      - Neue Config: einfach einen Namen ins Feld schreiben und Save drücken
      - Config-Name ist standardmäßig LEER (kein "config1" mehr).
        Ohne Namen wird nichts gespeichert, es kommt ein Hinweis.
      - Library.ListConfigs()        -> Liste aller Config-Namen
      - Library.DeleteSettings(name) -> Config löschen

    NEU (optional, VOR Library.New setzen):
      Library.BackgroundImage             = "rbxassetid://109649034704782"
      Library.BackgroundTint              = Color3.fromRGB(120, 115, 135)
      Library.BackgroundImageTransparency = 0.25
      Library.MobileMode                  = nil   -- nil = auto, true/false = erzwingen
      Library.SettingsFileName            = "meinconfig" -- optional: wird beim Start automatisch geladen

    NEU in v3.2.0 (alles optional, alte Scripts laufen unveraendert):
      - PC-Layout: alle Sub-Tabs eines Tabs sind gleichzeitig als Karten sichtbar (2 Spalten).
        Mobile bleibt wie bisher (Sub-Tab-Leiste oben).
      - Shift-Lock / gameProcessed Fix: Menue-Taste und Keybinds funktionieren jetzt auch bei
        aktivem Shift-Lock (nur wenn gerade nicht in ein TextFeld getippt wird).
      - Maus wird beim Oeffnen des Menues freigegeben (First Person / Mouse-Lock Games)
        und danach wiederhergestellt.   Library.AutoUnlockMouse = false  schaltet das ab.
      - Mobile: Keybind / ToggleWithKey oeffnen eine Tastatur zum Auswaehlen. Fuer die gewaehlte
        Taste entsteht ein Button auf dem Screen (zeigt den Key-Namen, frei verschiebbar solange
        das Menue offen ist, antippen = Taste druecken).
      - Library.IsPC / Library.IsMobile

    NEU in v3.4.0 (PC-Layout, uebersichtlichere Sub-Tabs):
      - Unter dem Seitentitel gibt es jetzt eine Sub-Tab-Leiste (Chips). Es wird standardmaessig nur
        EIN Sub-Tab auf einmal angezeigt (volle Breite), statt alle Karten gleichzeitig.
      - Der Chip "All" zeigt wie vorher alle Sub-Tabs als Karten in 2 Spalten.
      - Die Auswahl bleibt pro Tab erhalten, solange das Menue offen bleibt.
      - Library.PCSubTabMode = "tabs"   -- (Standard) Chip-Leiste, ein Sub-Tab auf einmal
        Library.PCSubTabMode = "cards"  -- altes Verhalten (alle Karten, keine Leiste)
        (VOR Library.New setzen; Mobile ist davon nicht betroffen)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local success, parent = pcall(function()
    return CoreGui
end)
if not success or not parent then
    parent = PlayerGui
end

for _, oldName in ipairs({"SketchGUILibrary", "SketchGUILibrary_Mobile", "PyroXGUI_MobileKeys", "PyroXGUI_KeyPicker", "PyroXGUI_Loading"}) do
    local old = parent:FindFirstChild(oldName)
    if old then
        old:Destroy()
    end
end

local Library = {}
Library.Version = "v3.4.0"
Library.ThemeColor = Library.ThemeColor or Color3.fromRGB(150, 90, 255)
Library.Flags = {}
Library.SettingsFileName = "" -- bewusst leer: der Nutzer muss selbst einen Namen wählen
Library.ConfigFolder = ""
Library.ElementUpdaters = {}

-- Neue optionale Einstellungen
Library.BackgroundImage = "rbxassetid://85708246103612"
Library.BackgroundTint = Color3.fromRGB(120, 115, 135)
Library.BackgroundImageTransparency = 0.25
Library.MobileMode = nil
Library.IsMobile = false
Library.IsPC = true
Library.PCSubTabMode = Library.PCSubTabMode or "tabs" -- "tabs" = Chip-Leiste (ein Sub-Tab), "cards" = alle Karten
Library.AutoUnlockMouse = true
Library.ShowLoadingScreen = true
Library.LoadingSound = true
Library.LoadingSoundId = "rbxassetid://107366908379453"
Library.LoadingSoundVolume = 0.6
Library.LoadingBlur = true
Library.MobileKeyButtons = {}
Library.MobileKeysEditing = false
Library.Font = Enum.Font.GothamMedium
Library.FontBold = Enum.Font.GothamBold

Library.Theme = {
    Background = Color3.fromRGB(10, 10, 14),
    Panel      = Color3.fromRGB(16, 16, 22),
    Element    = Color3.fromRGB(20, 20, 28),
    ElementAlt = Color3.fromRGB(30, 30, 40),
    Hover      = Color3.fromRGB(42, 42, 56),
    Stroke     = Color3.fromRGB(48, 48, 62),
    Off        = Color3.fromRGB(42, 42, 54),
    Text       = Color3.fromRGB(240, 240, 248),
    SubText    = Color3.fromRGB(165, 165, 182),
}
local Theme = Library.Theme

local BaseFolderName = "PyroXGUI"
local LOGO = "rbxassetid://75876733222469"

-- ==========================================
-- HELFER (nur Optik, keine Logik)
-- ==========================================

local function Create(class, props)
    local inst = Instance.new(class)
    local p
    for k, v in pairs(props or {}) do
        if k == "Parent" then
            p = v
        else
            inst[k] = v
        end
    end
    if p then
        inst.Parent = p
    end
    return inst
end

local function Corner(obj, r)
    return Create("UICorner", {CornerRadius = UDim.new(0, r or 6), Parent = obj})
end

local function Stroke(obj, color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = obj,
    })
end

local function Tween(obj, t, props, style, dir)
    local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function Shine(obj, rot)
    return Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 195)),
        Rotation = rot or 90,
        Parent = obj,
    })
end

local function Lighten(c, a)
    return c:Lerp(Color3.new(1, 1, 1), a)
end

local function ContrastText(c)
    local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
    if l > 0.62 then
        return Color3.fromRGB(18, 18, 24)
    end
    return Color3.new(1, 1, 1)
end

local function IsPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- Tastatur-Eingaben gelten auch dann, wenn das Spiel sie "verbraucht" hat (z.B. Shift-Lock auf
-- RightShift). Nur wenn gerade in ein TextFeld getippt wird, werden sie ignoriert.
local function ShouldHandleKey(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        return UserInputService:GetFocusedTextBox() == nil
    end
    return not gameProcessed
end

local function AddHover(btn, base, hover)
    btn.MouseEnter:Connect(function()
        Tween(btn, 0.15, {BackgroundColor3 = hover})
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.15, {BackgroundColor3 = base})
    end)
end

local function ClickFlash(btn)
    local sc = btn:FindFirstChild("ClickScale") or Create("UIScale", {Name = "ClickScale", Parent = btn})
    sc.Scale = 0.93
    Tween(sc, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
end

local function FadeOut(root, t)
    local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local list = root:GetDescendants()
    table.insert(list, root)
    for _, d in ipairs(list) do
        if d:IsA("GuiObject") then
            TweenService:Create(d, info, {BackgroundTransparency = 1}):Play()
        end
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            TweenService:Create(d, info, {TextTransparency = 1}):Play()
        end
        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
            TweenService:Create(d, info, {ImageTransparency = 1}):Play()
        end
        if d:IsA("UIStroke") then
            TweenService:Create(d, info, {Transparency = 1}):Play()
        end
    end
end

-- Element-Zeile (Hintergrund jedes Elements)
local function MakeRow(container, height)
    local row = Create("Frame", {
        Size = UDim2.new(1, -8, 0, height or 34),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = container,
    })
    Corner(row, 6)
    local st = Stroke(row, Theme.Stroke, 1, 0.35)
    row.MouseEnter:Connect(function()
        Tween(st, 0.2, {Color = Library.ThemeColor, Transparency = 0.25})
    end)
    row.MouseLeave:Connect(function()
        Tween(st, 0.2, {Color = Theme.Stroke, Transparency = 0.35})
    end)
    return row
end

local function MakeLabel(row, text, rightSpace, size)
    return Create("TextLabel", {
        Size = UDim2.new(1, -((rightSpace or 0) + 16), 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = size or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = row,
    })
end

local function MakeSmallButton(row, text, width, xOffset, textSize)
    local b = Create("TextButton", {
        Size = UDim2.new(0, width, 0, 24),
        Position = UDim2.new(1, xOffset, 0.5, -12),
        BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false,
        Font = Library.Font,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = textSize or 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = row,
    })
    Corner(b, 5)
    Stroke(b, Theme.Stroke, 1, 0.3)
    AddHover(b, Theme.ElementAlt, Theme.Hover)
    return b
end

-- Animierter Switch (ersetzt den alten ON/OFF Button rein optisch)
local function CreateSwitch(row, xOffset, state)
    local sw = Create("TextButton", {
        Size = UDim2.new(0, 42, 0, 20),
        Position = UDim2.new(1, xOffset, 0.5, -10),
        BackgroundColor3 = state and Library.ThemeColor or Theme.Off,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 3,
        Parent = row,
    })
    Corner(sw, 10)
    Stroke(sw, Theme.Stroke, 1, 0.3)
    local knob = Create("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 16, 0, 16),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.SubText,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = sw,
    })
    Corner(knob, 8)
    return sw, knob
end

local function SetSwitch(sw, knob, state)
    Tween(sw, 0.25, {BackgroundColor3 = state and Library.ThemeColor or Theme.Off})
    Tween(knob, 0.3, {
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.SubText,
    }, Enum.EasingStyle.Back)
end

local function DetectMobile()
    -- Manuelle Überschreibung hat Vorrang
    if Library.MobileMode ~= nil then
        return Library.MobileMode == true
    end

    -- 1) Plattform direkt abfragen (funktioniert auch im Emulator)
    local okPlat, platform = pcall(function()
        return UserInputService:GetPlatform()
    end)
    if okPlat and platform then
        if platform == Enum.Platform.Android or platform == Enum.Platform.IOS then
            return true
        end
        if platform == Enum.Platform.Windows or platform == Enum.Platform.OSX
            or platform == Enum.Platform.Linux or platform == Enum.Platform.UWP then
            -- Desktop: nur Mobile, wenn Touch ohne Maus
            return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
        end
    end

    -- 2) Fallback: Touch vorhanden und keine echte Tastatur
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return true
    end
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- ==========================================
-- CONFIG
-- ==========================================

-- Entfernt .json, ungültige Dateizeichen und Leerzeichen am Rand
local function SanitizeConfigName(name)
    name = tostring(name or "")
    name = name:gsub("%.json$", "")
    name = name:gsub('[\\/:*?"<>|]', "")
    name = name:match("^%s*(.-)%s*$") or ""
    return name
end

local function GetConfigDisplayName()
    return SanitizeConfigName(Library.SettingsFileName)
end

-- Gibt den Config-Ordner zurück (und erstellt ihn bei Bedarf)
local function GetConfigFolder()
    if makefolder and isfolder and not isfolder(BaseFolderName) then
        pcall(function() makefolder(BaseFolderName) end)
    end

    local currentFolder = BaseFolderName
    if Library.ConfigFolder and Library.ConfigFolder ~= "" then
        currentFolder = BaseFolderName .. "/" .. Library.ConfigFolder
        if makefolder and isfolder and not isfolder(currentFolder) then
            pcall(function() makefolder(currentFolder) end)
        end
    end
    return currentFolder
end

-- Gibt nil zurück, wenn kein Config-Name gesetzt ist
local function GetFilePath(nameOverride)
    local name = SanitizeConfigName(nameOverride or Library.SettingsFileName)
    if name == "" then
        return nil
    end
    return GetConfigFolder() .. "/" .. name .. ".json"
end

-- Nur für die Anzeige im Settings-Panel (erstellt keine Ordner)
local function GetConfigPathString()
    local folder = BaseFolderName
    if Library.ConfigFolder and Library.ConfigFolder ~= "" then
        folder = folder .. "/" .. Library.ConfigFolder
    end
    local name = GetConfigDisplayName()
    if name == "" then
        return folder .. "/"
    end
    return folder .. "/" .. name .. ".json"
end

local function GetEnumFromValue(val)
    if typeof(val) == "EnumItem" then
        return val
    elseif type(val) == "table" and val.Enum and val.Name then
        local ok, res = pcall(function()
            return Enum[val.Enum][val.Name]
        end)
        if ok then return res end
    elseif type(val) == "string" then
        if val == "None" then
            return Enum.KeyCode.None
        end
        local ok, res = pcall(function()
            return Enum.KeyCode[val]
        end)
        if ok and res then return res end

        for _, item in ipairs(Enum.UserInputType:GetEnumItems()) do
            if item.Name == val then
                return item
            end
        end
    end
    return Enum.KeyCode.None
end

-- ==========================================
-- NOTIFICATIONS
-- ==========================================

local function ShowPopup(message)
    local notifGui = parent:FindFirstChild("PyroXGUI_Notification")
    if not notifGui then
        notifGui = Instance.new("ScreenGui")
        notifGui.Name = "PyroXGUI_Notification"
        notifGui.ResetOnSpawn = false
        notifGui.DisplayOrder = 50
        notifGui.Parent = parent
    end

    local accent = Library.ThemeColor
    local W, H = 280, 48

    local NotifFrame = Create("Frame", {
        Size = UDim2.new(0, W, 0, H),
        Position = UDim2.new(1, 20, 1, -(H + 16)),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        ZIndex = 9999,
        Parent = notifGui,
    })
    Corner(NotifFrame, 8)
    Stroke(NotifFrame, Theme.Stroke, 1, 0.1)

    local AccentBar = Create("Frame", {
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 10000,
        Parent = NotifFrame,
    })
    Corner(AccentBar, 2)

    Create("ImageLabel", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 18, 0.5, -11),
        BackgroundTransparency = 1,
        Image = LOGO,
        ZIndex = 10000,
        Parent = NotifFrame,
    })

    Create("TextLabel", {
        Size = UDim2.new(1, -58, 1, -4),
        Position = UDim2.new(0, 48, 0, 0),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = message,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 10000,
        Parent = NotifFrame,
    })

    local Timer = Create("Frame", {
        Size = UDim2.new(1, -16, 0, 2),
        Position = UDim2.new(0, 8, 1, -4),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 10000,
        Parent = NotifFrame,
    })
    Corner(Timer, 1)

    for _, child in ipairs(notifGui:GetChildren()) do
        if child:IsA("Frame") and child ~= NotifFrame and not child:GetAttribute("Leaving") then
            Tween(child, 0.3, {
                Position = UDim2.new(1, -(W + 12), 1, child.Position.Y.Offset - (H + 6))
            }, Enum.EasingStyle.Quad)
        end
    end

    Tween(NotifFrame, 0.45, {Position = UDim2.new(1, -(W + 12), 1, -(H + 16))}, Enum.EasingStyle.Back)
    Tween(Timer, 3, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)

    task.spawn(function()
        task.wait(3)
        NotifFrame:SetAttribute("Leaving", true)
        local slideOut = Tween(NotifFrame, 0.4, {Position = UDim2.new(1, 20, 1, NotifFrame.Position.Y.Offset)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        slideOut.Completed:Wait()
        NotifFrame:Destroy()
    end)
end


-- ==========================================
-- MOBILE: BUTTONS AUF DEM SCREEN + KEY-PICKER
-- ==========================================

local SHORT_KEYS = {
    LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
    LeftAlt = "LAlt", RightAlt = "RAlt", Backspace = "Bksp", Return = "Enter", Space = "Space",
    Up = "Up", Down = "Down", Left = "Left", Right = "Right",
    One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
    Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
    MouseButton1 = "M1", MouseButton2 = "M2", MouseButton3 = "M3",
}
local function ShortKeyName(name)
    return SHORT_KEYS[name] or tostring(name)
end

local MobileKeyGui
local function GetMobileKeyGui()
    if MobileKeyGui and MobileKeyGui.Parent then
        return MobileKeyGui
    end
    MobileKeyGui = Create("ScreenGui", {
        Name = "PyroXGUI_MobileKeys",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 15,
        IgnoreGuiInset = true,
        Parent = parent,
    })
    return MobileKeyGui
end

local function RefreshMobileKeyLook(obj)
    local editing = Library.MobileKeysEditing
    if obj.Stroke then
        Tween(obj.Stroke, 0.2, {
            Color = Library.ThemeColor,
            Transparency = editing and 0 or 0.45,
            Thickness = editing and 3 or 2,
        })
    end
end

function Library.SetMobileKeyEditing(on)
    Library.MobileKeysEditing = on and true or false
    for _, obj in ipairs(Library.MobileKeyButtons) do
        RefreshMobileKeyLook(obj)
    end
end

-- Erstellt einen Button auf dem Screen. onTap wird beim Antippen ausgefuehrt.
-- posFlag: Flag-Name unter dem die Position (als Bildschirm-Anteil) gespeichert wird.
function Library.CreateMobileKey(posFlag, onTap)
    local gui = GetMobileKeyGui()
    local obj = {}

    local idx = #Library.MobileKeyButtons
    local saved = Library.Flags[posFlag]
    local sx, sy
    if type(saved) == "table" and tonumber(saved.X) and tonumber(saved.Y) then
        sx, sy = tonumber(saved.X), tonumber(saved.Y)
    else
        sx = 0.93 - 0.09 * math.floor(idx / 5)
        sy = 0.22 + 0.13 * (idx % 5)
    end

    local btn = Create("TextButton", {
        Name = "MobileKey",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 54, 0, 54),
        Position = UDim2.new(sx, 0, sy, 0),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.1,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = "?",
        TextColor3 = Theme.Text,
        TextScaled = true,
        ZIndex = 5,
        Parent = gui,
    })
    Corner(btn, 27)
    obj.Stroke = Stroke(btn, Library.ThemeColor, 2, 0.45)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
        Parent = btn,
    })
    Create("UITextSizeConstraint", {MaxTextSize = 18, MinTextSize = 8, Parent = btn})

    local pressed, moved = false, false
    local startPos, startScale
    local conns = {}

    btn.InputBegan:Connect(function(input)
        if IsPress(input) then
            pressed = true
            moved = false
            startPos = input.Position
            startScale = Vector2.new(btn.Position.X.Scale, btn.Position.Y.Scale)
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    c:Disconnect()
                    if not pressed then return end
                    pressed = false
                    if moved then
                        Library.Flags[posFlag] = {X = btn.Position.X.Scale, Y = btn.Position.Y.Scale}
                    else
                        ClickFlash(btn)
                        if onTap then
                            task.spawn(onTap)
                        end
                    end
                end
            end)
        end
    end)

    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if pressed and IsMove(input) and Library.MobileKeysEditing then
            local d = input.Position - startPos
            if d.Magnitude > 6 then
                moved = true
            end
            if moved then
                local vp = gui.AbsoluteSize
                if vp.X > 0 and vp.Y > 0 then
                    btn.Position = UDim2.new(
                        math.clamp(startScale.X + d.X / vp.X, 0.03, 0.97), 0,
                        math.clamp(startScale.Y + d.Y / vp.Y, 0.05, 0.95), 0)
                end
            end
        end
    end))

    function obj:SetKey(name)
        btn.Text = ShortKeyName(name)
    end
    function obj:SetPos(x, y)
        if tonumber(x) and tonumber(y) then
            btn.Position = UDim2.new(tonumber(x), 0, tonumber(y), 0)
        end
    end
    function obj:SetActive(state)
        Tween(btn, 0.2, {
            BackgroundColor3 = state and Library.ThemeColor or Theme.Panel,
            TextColor3 = state and ContrastText(Library.ThemeColor) or Theme.Text,
        })
    end
    function obj:Destroy()
        for _, c in ipairs(conns) do
            c:Disconnect()
        end
        for i, o in ipairs(Library.MobileKeyButtons) do
            if o == obj then
                table.remove(Library.MobileKeyButtons, i)
                break
            end
        end
        btn:Destroy()
    end

    table.insert(Library.MobileKeyButtons, obj)
    RefreshMobileKeyLook(obj)
    return obj
end

-- Tastatur-Layout zum Auswaehlen einer Taste (Mobile)
function Library.OpenKeyPicker(title, onPick, currentName)
    local old = parent:FindFirstChild("PyroXGUI_KeyPicker")
    if old then
        old:Destroy()
    end

    local gui = Create("ScreenGui", {
        Name = "PyroXGUI_KeyPicker",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 40,
        IgnoreGuiInset = true,
        Parent = parent,
    })
    local function close()
        if gui.Parent then
            gui:Destroy()
        end
    end

    local back = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 1,
        Parent = gui,
    })
    back.MouseButton1Click:Connect(close)

    local PW, PH = 540, 372
    local panel = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, PW, 0, PH),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 2,
        Parent = gui,
    })
    Corner(panel, 12)
    Stroke(panel, Library.ThemeColor, 1.5, 0.2)
    local sc = Create("UIScale", {Parent = panel})
    local function fit()
        local vp = gui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then
            vp = Vector2.new(1280, 720)
        end
        sc.Scale = math.clamp(math.min((vp.X - 16) / PW, (vp.Y - 16) / PH), 0.35, 1)
    end
    fit()
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

    Create("TextLabel", {
        Size = UDim2.new(1, -170, 0, 26),
        Position = UDim2.new(0, 14, 0, 10),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = "Pick a key:  " .. tostring(title),
        TextColor3 = Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = panel,
    })

    local function smallBtn(text, w, xFromRight, color)
        local b = Create("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.new(0, w, 0, 26),
            Position = UDim2.new(1, xFromRight, 0, 10),
            BackgroundColor3 = color or Theme.ElementAlt,
            AutoButtonColor = false,
            Font = Library.FontBold,
            Text = text,
            TextColor3 = Theme.Text,
            TextSize = 12,
            ZIndex = 3,
            Parent = panel,
        })
        Corner(b, 6)
        Stroke(b, Theme.Stroke, 1, 0.3)
        return b
    end
    local closeBtn = smallBtn("X", 30, -12)
    closeBtn.MouseButton1Click:Connect(close)
    local clearBtn = smallBtn("No Key", 80, -50, Color3.fromRGB(90, 30, 38))
    clearBtn.MouseButton1Click:Connect(function()
        close()
        if onPick then onPick(Enum.KeyCode.None) end
    end)

    local function K(label, code, w)
        return {label = label, code = code or label, w = w or 44}
    end
    local rows = {
        {K("F1", "F1", 38), K("F2", "F2", 38), K("F3", "F3", 38), K("F4", "F4", 38), K("F5", "F5", 38), K("F6", "F6", 38),
         K("F7", "F7", 38), K("F8", "F8", 38), K("F9", "F9", 38), K("F10", "F10", 38), K("F11", "F11", 38), K("F12", "F12", 38)},
        {K("1", "One"), K("2", "Two"), K("3", "Three"), K("4", "Four"), K("5", "Five"),
         K("6", "Six"), K("7", "Seven"), K("8", "Eight"), K("9", "Nine"), K("0", "Zero")},
        {K("Q"), K("W"), K("E"), K("R"), K("T"), K("Y"), K("U"), K("I"), K("O"), K("P")},
        {K("A"), K("S"), K("D"), K("F"), K("G"), K("H"), K("J"), K("K"), K("L")},
        {K("Z"), K("X"), K("C"), K("V"), K("B"), K("N"), K("M"), {spacer = 22},
         K("Up", "Up", 40), K("Dn", "Down", 40), K("Lt", "Left", 40), K("Rt", "Right", 40)},
        {K("Shift", "LeftShift", 74), K("Ctrl", "LeftControl", 74), K("Alt", "LeftAlt", 60),
         K("Space", "Space", 150), K("Tab", "Tab", 56)},
    }

    local GAP, ROWH = 4, 40
    for r, row in ipairs(rows) do
        local total = 0
        for i, it in ipairs(row) do
            total = total + (it.spacer or it.w) + (i > 1 and GAP or 0)
        end
        local x = (PW - total) / 2
        local y = 50 + (r - 1) * (ROWH + 6)
        for _, it in ipairs(row) do
            if it.spacer then
                x = x + it.spacer + GAP
            else
                local active = (currentName ~= nil and currentName == it.code)
                local kb = Create("TextButton", {
                    Size = UDim2.new(0, it.w, 0, ROWH),
                    Position = UDim2.new(0, x, 0, y),
                    BackgroundColor3 = active and Library.ThemeColor or Theme.ElementAlt,
                    AutoButtonColor = false,
                    Font = Library.FontBold,
                    Text = it.label,
                    TextColor3 = active and ContrastText(Library.ThemeColor) or Theme.Text,
                    TextSize = 13,
                    ZIndex = 3,
                    Parent = panel,
                })
                Corner(kb, 6)
                Stroke(kb, Theme.Stroke, 1, 0.3)
                local code = it.code
                kb.MouseButton1Click:Connect(function()
                    local kc = Enum.KeyCode[code]
                    close()
                    if kc and onPick then
                        onPick(kc)
                    end
                end)
                x = x + it.w + GAP
            end
        end
    end

    return close
end

-- Verbindet Key-Flag + Screen-Button (nur Mobile). getKey liefert den aktuellen Key,
-- trigger wird beim Antippen des Buttons ausgefuehrt.
local function AttachScreenKey(posFlag, getKey, trigger)
    local ctl = {}
    local sk
    function ctl.Update()
        if not Library.IsMobile then return end
        local k = getKey()
        if typeof(k) == "EnumItem" and k ~= Enum.KeyCode.None then
            if not sk then
                sk = Library.CreateMobileKey(posFlag, trigger)
            end
            sk:SetKey(k.Name)
            local p = Library.Flags[posFlag]
            if type(p) == "table" then
                sk:SetPos(p.X, p.Y)
            end
        elseif sk then
            sk:Destroy()
            sk = nil
        end
    end
    function ctl.SetActive(state)
        if sk then sk:SetActive(state) end
    end
    return ctl
end

-- Liste aller vorhandenen Configs im aktuellen Config-Ordner
function Library.ListConfigs()
    local result = {}
    if not listfiles then
        return result
    end
    local folder = GetConfigFolder()
    local ok, files = pcall(function()
        return listfiles(folder)
    end)
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then
                table.insert(result, n)
            end
        end
    end
    table.sort(result, function(a, b)
        return a:lower() < b:lower()
    end)
    return result
end

function Library.SaveSettings()
    if not writefile then
        ShowPopup("Saving is not supported by your executor")
        return
    end

    local path = GetFilePath()
    if not path then
        ShowPopup("Enter a config name first")
        return
    end

    local ok, encoded = pcall(function()
        local exportTable = {}
        for k, v in pairs(Library.Flags) do
            if typeof(v) == "Color3" then
                exportTable[k] = {R = v.R, G = v.G, B = v.B}
            elseif typeof(v) == "EnumItem" then
                -- Fix: tostring() splitten, da v.EnumType.Name einen Fehler auslöst
                local split = tostring(v):split(".")
                exportTable[k] = {Enum = split[2], Name = split[3]}
            else
                exportTable[k] = v
            end
        end
        return HttpService:JSONEncode(exportTable)
    end)
    if ok then
        pcall(function()
            writefile(path, encoded)
        end)
        ShowPopup('saved "' .. GetConfigDisplayName() .. '"')
    end
end

-- silent = true: keine Fehler-Popups (wird beim Start so aufgerufen)
function Library.LoadSettings(silent)
    local path = GetFilePath()
    if not path then
        if not silent then
            ShowPopup("Select or enter a config name first")
        end
        return
    end

    if not (readfile and isfile) then
        if not silent then
            ShowPopup("Loading is not supported by your executor")
        end
        return
    end

    if not isfile(path) then
        if not silent then
            ShowPopup('config "' .. GetConfigDisplayName() .. '" not found')
        end
        return
    end

    local ok, decoded = pcall(function()
        local content = readfile(path)
        return HttpService:JSONDecode(content)
    end)
    if ok and type(decoded) == "table" then
        for k, v in pairs(decoded) do
            if type(v) == "table" and v.Enum and v.Name then
                pcall(function()
                    Library.Flags[k] = Enum[v.Enum][v.Name]
                end)
            else
                Library.Flags[k] = v
            end
        end
        for _, updateFunc in pairs(Library.ElementUpdaters) do
            pcall(updateFunc)
        end
        ShowPopup('loaded "' .. GetConfigDisplayName() .. '"')
    elseif not silent then
        ShowPopup("Could not read config")
    end
end

function Library.DeleteSettings(name)
    local clean = SanitizeConfigName(name or Library.SettingsFileName)
    if clean == "" then
        ShowPopup("Select a config first")
        return false
    end
    if not (delfile and isfile) then
        ShowPopup("Deleting is not supported by your executor")
        return false
    end

    local path = GetFilePath(clean)
    if not path or not isfile(path) then
        ShowPopup('config "' .. clean .. '" not found')
        return false
    end

    local ok = pcall(function()
        delfile(path)
    end)
    if ok then
        ShowPopup('deleted "' .. clean .. '"')
        return true
    end
    ShowPopup("Could not delete config")
    return false
end

-- ==========================================
-- WINDOW
-- ==========================================

function Library.New(titleText, customThemeColor)
    if customThemeColor then
        Library.ThemeColor = customThemeColor
    end

    Library.IsMobile = DetectMobile()
    local IsMobile = Library.IsMobile
    local IsPC = not IsMobile
    Library.IsPC = IsPC
    local MAIN_BG = 0.1

    -- PC bekommt ein groesseres Fenster (alle Sub-Tabs als Karten), Mobile bleibt wie bisher
    local WIN_W = IsPC and 1040 or 750
    local WIN_H = IsPC and 640 or 480
    local SIDEBAR_W = IsPC and 170 or 140

    -- Falls ein altes GUI beim Neu-Ausfuehren offen war: Maus-Freigabe sauber beenden
    pcall(function() RunService:UnbindFromRenderStep("PyroXMouseFree") end)

    local Window = {}

    local ScreenGui = Create("ScreenGui", {
        Name = "SketchGUILibrary",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parent,
    })

    -- Unsichtbarer Modal-Button: gibt die Maus frei (Shift-Lock / First Person) solange das Menue offen ist
    local ModalBtn
    if IsPC then
        ModalBtn = Create("TextButton", {
            Name = "MouseUnlock",
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Parent = ScreenGui,
        })
    end

    -- Skalierung (Mobile / kleine Bildschirme)
    local function ComputeScale()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        if IsMobile then
            return math.clamp(math.min((vp.X - 24) / WIN_W, (vp.Y - 80) / WIN_H), 0.35, 1)
        end
        return math.clamp(math.min((vp.X - 40) / WIN_W, (vp.Y - 40) / WIN_H), 0.45, 1)
    end

    local Scales = {}
    local function AddScale(obj)
        local s = Create("UIScale", {Scale = ComputeScale(), Parent = obj})
        table.insert(Scales, s)
        return s
    end

    -- MainFrame
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = MAIN_BG,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
        Parent = ScreenGui,
    })
    Corner(MainFrame, 10)
    local MainScale = AddScale(MainFrame)

    -- Animierter Farbverlauf-Rahmen
    local MainStroke = Stroke(MainFrame, Color3.new(1, 1, 1), 1.5, 0)
    local strokeColors = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Library.ThemeColor),
        ColorSequenceKeypoint.new(0.5, Theme.Stroke),
        ColorSequenceKeypoint.new(1, Library.ThemeColor),
    })
    local StrokeGrad = Create("UIGradient", {Color = strokeColors, Parent = MainStroke})

    -- Maskottchen-Hintergrund
    local mascotImg
    if Library.BackgroundImage and tostring(Library.BackgroundImage) ~= "" then
        mascotImg = tostring(Library.BackgroundImage)
        if tonumber(mascotImg) then
            mascotImg = "rbxassetid://" .. mascotImg
        end
    end

    local Mascot
    if mascotImg then
        Mascot = Create("ImageLabel", {
            Name = "Mascot",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image = mascotImg,
            ImageColor3 = Library.BackgroundTint or Color3.new(1, 1, 1),
            ImageTransparency = Library.BackgroundImageTransparency,
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 0,
            Parent = MainFrame,
        })
        Corner(Mascot, 10)
    end

    -- Abdunklung links (Lesbarkeit), rechts sieht man das Maskottchen
    local Shade = Create("Frame", {
        Name = "Shade",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = MainFrame,
    })
    Corner(Shade, 10)
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(0.35, 0.3),
            NumberSequenceKeypoint.new(1, 0.6),
        }),
        Parent = Shade,
    })

    -- Leichter Farbschimmer unten in der Theme-Farbe
    local Glow = Create("Frame", {
        Name = "Glow",
        Size = UDim2.new(1, 0, 0.55, 0),
        Position = UDim2.new(0, 0, 0.45, 0),
        BackgroundColor3 = Library.ThemeColor,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = MainFrame,
    })
    Corner(Glow, 10)
    Create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.82),
        }),
        Parent = Glow,
    })

    local DimOverlay = Create("TextButton", {
        Name = "DimOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.6,
        AutoButtonColor = false,
        Text = "",
        Visible = false,
        ZIndex = 50,
        Parent = MainFrame,
    })
    Corner(DimOverlay, 10)

    local openPopups = {}
    local function CloseAllPopups()
        for _, closeFunc in ipairs(openPopups) do
            pcall(closeFunc)
        end
        DimOverlay.Visible = false
    end

    DimOverlay.MouseButton1Click:Connect(function()
        CloseAllPopups()
    end)

    -- Rechtes Filter-Panel
    local FilterPanel = Create("Frame", {
        Name = "FilterPanel",
        Size = UDim2.new(0, 210, 0, WIN_H),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
        Parent = ScreenGui,
    })
    Corner(FilterPanel, 10)
    Stroke(FilterPanel, Library.ThemeColor, 1, 0.5)
    AddScale(FilterPanel)

    -- Color Picker Panel
    local ColorPickerPanel = Create("Frame", {
        Name = "ColorPickerPanel",
        Size = UDim2.new(0, 210, 0, 196),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
        Parent = ScreenGui,
    })
    Corner(ColorPickerPanel, 10)
    Stroke(ColorPickerPanel, Library.ThemeColor, 1, 0.5)
    AddScale(ColorPickerPanel)

    local CPContent = Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 4,
        Parent = ColorPickerPanel,
    })

    local function UpdatePanelPositions()
        local absPos = MainFrame.AbsolutePosition
        local absSize = MainFrame.AbsoluteSize
        local sc = MainScale.Scale
        local vpX = ScreenGui.AbsoluteSize.X
        local panelW = 210 * sc
        local x = absPos.X + absSize.X + 8
        -- Kein Platz rechts (z.B. Handy)? Dann innerhalb des GUIs anzeigen
        if vpX > 0 and x + panelW > vpX then
            x = absPos.X + absSize.X - panelW - 8
        end
        FilterPanel.Position = UDim2.new(0, x, 0, absPos.Y)
        ColorPickerPanel.Position = UDim2.new(0, x, 0, absPos.Y + 180 * sc)
    end

    MainFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdatePanelPositions)
    MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdatePanelPositions)
    task.spawn(function()
        task.wait(0.05)
        UpdatePanelPositions()
    end)

    local function RefreshScale()
        local s = ComputeScale()
        for _, sc in ipairs(Scales) do
            sc.Scale = s
        end
        UpdatePanelPositions()
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(RefreshScale)
    end

    -- Title Bar
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 3,
        Parent = MainFrame,
    })

    Create("ImageLabel", {
        Name = "Logo",
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(0, 12, 0.5, -13),
        BackgroundTransparency = 1,
        Image = LOGO,
        ZIndex = 3,
        Parent = TopBar,
    })

    Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -220, 1, 0),
        Position = UDim2.new(0, 46, 0, 0),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = titleText or "GUI Library",
        TextColor3 = Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = TopBar,
    })

    local VersionLabel = Create("TextLabel", {
        Name = "Version",
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.new(0, 0, 0, 20),
        AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, -50, 0.5, 0),
        BackgroundColor3 = Library.ThemeColor,
        BackgroundTransparency = 0.78,
        Font = Library.FontBold,
        Text = Library.Version,
        TextColor3 = Lighten(Library.ThemeColor, 0.55),
        TextSize = 11,
        ZIndex = 3,
        Parent = TopBar,
    })
    Corner(VersionLabel, 10)
    Create("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = VersionLabel})


    local MobileCloseBtn
    do
        MobileCloseBtn = Create("TextButton", {
            Name = "Minimize",
            AnchorPoint = Vector2.new(1, 0.5),
            Size = UDim2.new(0, 30, 0, 26),
            Position = UDim2.new(1, -12, 0.5, 0),
            BackgroundColor3 = Theme.ElementAlt,
            AutoButtonColor = false,
            Font = Library.FontBold,
            Text = "—",
            TextColor3 = Theme.Text,
            TextSize = 14,
            ZIndex = 4,
            Parent = TopBar,
        })
        Corner(MobileCloseBtn, 6)
        Stroke(MobileCloseBtn, Theme.Stroke, 1, 0.3)
    end

    local Separator = Create("Frame", {
        Size = UDim2.new(1, -24, 0, 1),
        Position = UDim2.new(0, 12, 0, 42),
        BackgroundColor3 = Library.ThemeColor,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = MainFrame,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = Separator,
    })

    -- Dragging (Maus + Touch)
    local dragging, dragInput, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if IsPress(input) then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    TopBar.InputChanged:Connect(function(input)
        if IsMove(input) then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            UpdatePanelPositions()
        end
    end)

    -- Sidebar
    local Sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_W, 1, -58),
        Position = UDim2.new(0, 8, 0, 50),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = MainFrame,
    })
    Corner(Sidebar, 8)
    Stroke(Sidebar, Theme.Stroke, 1, 0.45)

    local SideTabScroll = Create("ScrollingFrame", {
        Name = "SideTabScroll",
        Size = UDim2.new(1, -12, 1, IsPC and -92 or -52),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Library.ThemeColor,
        ZIndex = 3,
        Parent = Sidebar,
    })
    Create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), Parent = SideTabScroll})

    local SideLayout = Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = SideTabScroll,
    })
    SideLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SideTabScroll.CanvasSize = UDim2.new(0, 0, 0, SideLayout.AbsoluteContentSize.Y + 10)
    end)

    local ContentContainer = Create("Frame", {
        Name = "ContentContainer",
        Size = UDim2.new(1, -(SIDEBAR_W + 24), 1, -58),
        Position = UDim2.new(0, SIDEBAR_W + 16, 0, 50),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = MainFrame,
    })

    local SettingsButton = Create("TextButton", {
        Size = UDim2.new(1, -12, 0, 34),
        Position = UDim2.new(0, 6, 1, -40),
        BackgroundColor3 = Theme.ElementAlt,
        BackgroundTransparency = 0.2,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = "Settings",
        TextColor3 = Theme.Text,
        TextSize = 13,
        ZIndex = 3,
        Parent = Sidebar,
    })
    Corner(SettingsButton, 6)
    local SettingsStroke = Stroke(SettingsButton, Theme.Stroke, 1, 0.3)

    local function SetSettingsVisual(active)
        Tween(SettingsStroke, 0.2, {Color = active and Library.ThemeColor or Theme.Stroke, Transparency = active and 0 or 0.3})
        Tween(SettingsButton, 0.2, {TextColor3 = active and Lighten(Library.ThemeColor, 0.5) or Theme.Text})
    end

    -- Tab-Optik
    local function SetTabVisual(btn, active)
        local ind = btn:FindFirstChild("Indicator")
        Tween(btn, 0.22, {
            BackgroundColor3 = active and Library.ThemeColor or Theme.Element,
            BackgroundTransparency = active and 0.05 or 0.35,
            TextColor3 = active and ContrastText(Library.ThemeColor) or Theme.SubText,
        })
        btn.Font = active and Library.FontBold or Library.Font
        if ind then
            Tween(ind, 0.22, {BackgroundTransparency = active and 0 or 1})
        end
    end

    local function ShowContainer(container)
        container.Visible = true
        container.Position = UDim2.new(0, 0, 0, 46)
        Tween(container, 0.3, {Position = UDim2.new(0, 0, 0, 36)})
    end

    -- Settings Panel
    local SettingsPanel = Create("Frame", {
        Name = "SettingsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
        Parent = ContentContainer,
    })
    Corner(SettingsPanel, 8)
    Stroke(SettingsPanel, Theme.Stroke, 1, 0.3)

    Create("TextLabel", {
        Size = UDim2.new(1, -28, 0, 22),
        Position = UDim2.new(0, 14, 0, 12),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = "Configuration Settings",
        TextColor3 = Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -28, 0, 16),
        Position = UDim2.new(0, 14, 0, 34),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "Save, load & manage your configs",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11,
        Parent = SettingsPanel,
    })

    local function SettLabel(txt, y)
        return Create("TextLabel", {
            Size = UDim2.new(1, -28, 0, 16),
            Position = UDim2.new(0, 14, 0, y),
            BackgroundTransparency = 1,
            Font = Library.FontBold,
            Text = txt,
            TextColor3 = Theme.SubText,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 11,
            Parent = SettingsPanel,
        })
    end

    -- ---------- SAVED CONFIGS (Dropdown) ----------
    SettLabel("SAVED CONFIGS", 62)

    local ConfigDropButton = Create("TextButton", {
        Size = UDim2.new(1, -112, 0, 32),
        Position = UDim2.new(0, 14, 0, 80),
        BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false,
        Font = Library.Font,
        Text = "Select a config...",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Corner(ConfigDropButton, 6)
    Stroke(ConfigDropButton, Theme.Stroke, 1, 0.2)
    AddHover(ConfigDropButton, Theme.ElementAlt, Theme.Hover)
    Create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 26), Parent = ConfigDropButton})
    local ConfigArrow = Create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(1, 13, 0.5, 0),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = "▼",
        TextColor3 = Theme.SubText,
        TextSize = 9,
        ZIndex = 12,
        Parent = ConfigDropButton,
    })

    local RefreshBtn = Create("TextButton", {
        Size = UDim2.new(0, 84, 0, 32),
        Position = UDim2.new(1, -98, 0, 80),
        BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = "Refresh",
        TextColor3 = Theme.Text,
        TextSize = 12,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Corner(RefreshBtn, 6)
    Stroke(RefreshBtn, Theme.Stroke, 1, 0.2)
    AddHover(RefreshBtn, Theme.ElementAlt, Theme.Hover)

    -- ---------- CONFIG NAME (Eingabe, standardmäßig leer) ----------
    SettLabel("CONFIG NAME (type a new name to create a new config)", 122)
    local SettNameBox = Create("TextBox", {
        Size = UDim2.new(1, -28, 0, 32),
        Position = UDim2.new(0, 14, 0, 140),
        BackgroundColor3 = Theme.ElementAlt,
        BorderSizePixel = 0,
        Font = Library.Font,
        Text = SanitizeConfigName(Library.SettingsFileName),
        PlaceholderText = "Enter a config name...",
        PlaceholderColor3 = Theme.SubText,
        TextColor3 = Theme.Text,
        TextSize = 13,
        ClearTextOnFocus = false,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Corner(SettNameBox, 6)
    local SettNameStroke = Stroke(SettNameBox, Theme.Stroke, 1, 0.2)

    -- ---------- Load / Save / Delete ----------
    local ButtonRow = Create("Frame", {
        Size = UDim2.new(1, -28, 0, 34),
        Position = UDim2.new(0, 14, 0, 182),
        BackgroundTransparency = 1,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = ButtonRow,
    })

    local LoadBtn = Create("TextButton", {
        LayoutOrder = 1,
        Size = UDim2.new(1 / 3, -6, 1, 0),
        BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = "Load",
        TextColor3 = Theme.Text,
        TextSize = 13,
        ZIndex = 11,
        Parent = ButtonRow,
    })
    Corner(LoadBtn, 6)
    Stroke(LoadBtn, Theme.Stroke, 1, 0.2)
    AddHover(LoadBtn, Theme.ElementAlt, Theme.Hover)

    local SaveBtn = Create("TextButton", {
        LayoutOrder = 2,
        Size = UDim2.new(1 / 3, -6, 1, 0),
        BackgroundColor3 = Library.ThemeColor,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = "Save",
        TextColor3 = ContrastText(Library.ThemeColor),
        TextSize = 13,
        ZIndex = 11,
        Parent = ButtonRow,
    })
    Corner(SaveBtn, 6)
    Shine(SaveBtn)
    AddHover(SaveBtn, Library.ThemeColor, Lighten(Library.ThemeColor, 0.15))

    local DeleteBtn = Create("TextButton", {
        LayoutOrder = 3,
        Size = UDim2.new(1 / 3, -6, 1, 0),
        BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = "Delete",
        TextColor3 = Theme.Text,
        TextSize = 13,
        ZIndex = 11,
        Parent = ButtonRow,
    })
    Corner(DeleteBtn, 6)
    Stroke(DeleteBtn, Color3.fromRGB(220, 70, 80), 1, 0.3)
    AddHover(DeleteBtn, Theme.ElementAlt, Color3.fromRGB(90, 30, 38))

    -- ---------- MENU TOGGLE KEY ----------
    local menuKeyFlag = "MenuToggleKey"
    if Library.Flags[menuKeyFlag] == nil then
        Library.Flags[menuKeyFlag] = Enum.KeyCode.RightShift
    end

    local MenuKeyLabel = SettLabel("MENU TOGGLE KEY", 230)

    local currentMenuKey = Library.Flags[menuKeyFlag]
    local MenuKeyButton = Create("TextButton", {
        Size = UDim2.new(1, -28, 0, 32),
        Position = UDim2.new(0, 14, 0, 248),
        BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false,
        Font = Library.FontBold,
        Text = (typeof(currentMenuKey) == "EnumItem" and currentMenuKey ~= Enum.KeyCode.None) and currentMenuKey.Name or "RightShift",
        TextColor3 = Theme.Text,
        TextSize = 13,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Corner(MenuKeyButton, 6)
    Stroke(MenuKeyButton, Theme.Stroke, 1, 0.2)
    AddHover(MenuKeyButton, Theme.ElementAlt, Theme.Hover)

    -- Mobile hat den runden Button oben, die Menue-Taste gibt es dort nicht
    if IsMobile then
        MenuKeyButton.Visible = false
        MenuKeyLabel.Visible = false
    end

    -- PC: kleiner Hinweis unten in der Sidebar
    local KeyHint
    if IsPC then
        KeyHint = Create("TextLabel", {
            Name = "KeyHint",
            Size = UDim2.new(1, -12, 0, 32),
            Position = UDim2.new(0, 6, 1, -78),
            BackgroundTransparency = 1,
            Font = Library.Font,
            Text = "",
            TextColor3 = Theme.SubText,
            TextSize = 10,
            TextWrapped = true,
            ZIndex = 3,
            Parent = Sidebar,
        })
    end
    local function UpdateKeyHint()
        if not KeyHint then return end
        local k = Library.Flags[menuKeyFlag]
        local n = (typeof(k) == "EnumItem" and k ~= Enum.KeyCode.None) and k.Name or "RightShift"
        KeyHint.Text = "[" .. n .. "] show / hide"
    end
    UpdateKeyHint()

    local PathInfo = Create("TextLabel", {
        Size = UDim2.new(1, -28, 0, 16),
        Position = UDim2.new(0, 14, 1, -48),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "File: " .. GetConfigPathString(),
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 11,
        Parent = SettingsPanel,
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -28, 0, 16),
        Position = UDim2.new(0, 14, 1, -28),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "Mobile Mode: " .. (IsMobile and "ON" or "OFF") .. "   ·   " .. Library.Version,
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11,
        Parent = SettingsPanel,
    })

    -- ---------- Config-Liste (Popup-Dropdown) ----------
    local ConfigList = Create("ScrollingFrame", {
        Size = UDim2.new(1, -112, 0, 0),
        Position = UDim2.new(0, 14, 0, 116),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Library.ThemeColor,
        Visible = false,
        ZIndex = 30,
        Parent = SettingsPanel,
    })
    Corner(ConfigList, 8)
    Stroke(ConfigList, Library.ThemeColor, 1, 0.35)
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
        Parent = ConfigList,
    })
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = ConfigList,
    })

    local knownConfigs = {}
    local configButtons = {}
    local configButtonMap = {}
    local configListHeight = 38
    local configListOpen = false
    local deleteToken = 0
    local deleteArmed = false

    local function CurrentName()
        return SanitizeConfigName(Library.SettingsFileName)
    end

    local function CloseConfigList()
        if not configListOpen then return end
        configListOpen = false
        Tween(ConfigArrow, 0.2, {Rotation = 0})
        ConfigList.Visible = false
    end
    table.insert(openPopups, CloseConfigList)

    local function UpdateDropText()
        local name = CurrentName()
        if name == "" then
            ConfigDropButton.Text = "Select a config..."
            return
        end
        local exists = false
        for _, n in ipairs(knownConfigs) do
            if n == name then
                exists = true
                break
            end
        end
        ConfigDropButton.Text = exists and name or ("New: " .. name)
    end

    local function RecolorConfigButtons()
        local name = CurrentName()
        for n, b in pairs(configButtonMap) do
            local active = (n == name)
            b.BackgroundColor3 = active and Library.ThemeColor or Theme.ElementAlt
            b.TextColor3 = active and ContrastText(Library.ThemeColor) or Theme.Text
        end
    end

    local function UpdatePathInfo()
        PathInfo.Text = "File: " .. GetConfigPathString()
    end

    local function SelectConfig(name)
        Library.SettingsFileName = name
        SettNameBox.Text = name
        UpdateDropText()
        RecolorConfigButtons()
        UpdatePathInfo()
        CloseConfigList()
    end

    local function RefreshConfigList()
        for _, b in ipairs(configButtons) do
            b:Destroy()
        end
        configButtons = {}
        configButtonMap = {}

        knownConfigs = Library.ListConfigs()
        local count = #knownConfigs
        configListHeight = math.clamp(math.max(count, 1) * 30 + 8, 38, 160)
        ConfigList.CanvasSize = UDim2.new(0, 0, 0, math.max(count, 1) * 30 + 8)

        if count == 0 then
            local empty = Create("TextLabel", {
                Size = UDim2.new(1, -4, 0, 28),
                BackgroundTransparency = 1,
                Font = Library.Font,
                Text = "No configs found",
                TextColor3 = Theme.SubText,
                TextSize = 12,
                ZIndex = 31,
                Parent = ConfigList,
            })
            table.insert(configButtons, empty)
        end

        for i, n in ipairs(knownConfigs) do
            local OptBtn = Create("TextButton", {
                LayoutOrder = i,
                Size = UDim2.new(1, -4, 0, 28),
                BackgroundColor3 = Theme.ElementAlt,
                AutoButtonColor = false,
                Font = Library.Font,
                Text = n,
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 31,
                Parent = ConfigList,
            })
            Corner(OptBtn, 5)
            local optStroke = Stroke(OptBtn, Theme.Stroke, 1, 0.5)
            OptBtn.MouseEnter:Connect(function()
                Tween(optStroke, 0.15, {Color = Library.ThemeColor, Transparency = 0.1})
            end)
            OptBtn.MouseLeave:Connect(function()
                Tween(optStroke, 0.15, {Color = Theme.Stroke, Transparency = 0.5})
            end)
            OptBtn.MouseButton1Click:Connect(function()
                SelectConfig(n)
            end)
            table.insert(configButtons, OptBtn)
            configButtonMap[n] = OptBtn
        end

        RecolorConfigButtons()
        UpdateDropText()
    end

    -- Übernimmt den Text aus dem Namensfeld (bereinigt) und gibt ihn zurück
    local function ApplyNameFromBox()
        local clean = SanitizeConfigName(SettNameBox.Text)
        Library.SettingsFileName = clean
        SettNameBox.Text = clean
        UpdateDropText()
        RecolorConfigButtons()
        UpdatePathInfo()
        return clean
    end

    -- Dropdown öffnen/schließen
    ConfigDropButton.MouseButton1Click:Connect(function()
        local targetState = not configListOpen
        CloseAllPopups()
        if targetState then
            RefreshConfigList()
            configListOpen = true
            Tween(ConfigArrow, 0.2, {Rotation = 180})
            ConfigList.Size = UDim2.new(1, -112, 0, 0)
            ConfigList.Visible = true
            Tween(ConfigList, 0.25, {Size = UDim2.new(1, -112, 0, configListHeight)})
        end
    end)

    RefreshBtn.MouseButton1Click:Connect(function()
        ClickFlash(RefreshBtn)
        RefreshConfigList()
    end)

    SettNameBox.Focused:Connect(function()
        CloseConfigList()
        Tween(SettNameStroke, 0.2, {Color = Library.ThemeColor, Transparency = 0})
    end)
    SettNameBox.FocusLost:Connect(function()
        Tween(SettNameStroke, 0.2, {Color = Theme.Stroke, Transparency = 0.2})
        ApplyNameFromBox()
    end)

    LoadBtn.MouseButton1Click:Connect(function()
        ClickFlash(LoadBtn)
        CloseConfigList()
        ApplyNameFromBox()
        Library.LoadSettings()
    end)

    SaveBtn.MouseButton1Click:Connect(function()
        ClickFlash(SaveBtn)
        CloseConfigList()
        local name = ApplyNameFromBox()
        if name == "" then
            ShowPopup("Enter a config name first")
            return
        end
        Library.SaveSettings()
        RefreshConfigList()
    end)

    -- Delete mit Bestätigung (zweiter Klick innerhalb von 3 Sekunden)
    DeleteBtn.MouseButton1Click:Connect(function()
        ClickFlash(DeleteBtn)
        CloseConfigList()
        local name = ApplyNameFromBox()
        if name == "" then
            ShowPopup("Select a config to delete")
            return
        end

        if not deleteArmed then
            deleteArmed = true
            deleteToken = deleteToken + 1
            local myToken = deleteToken
            DeleteBtn.Text = "Confirm?"
            task.delay(3, function()
                if deleteArmed and deleteToken == myToken then
                    deleteArmed = false
                    DeleteBtn.Text = "Delete"
                end
            end)
            return
        end

        deleteArmed = false
        deleteToken = deleteToken + 1
        DeleteBtn.Text = "Delete"

        if Library.DeleteSettings(name) then
            Library.SettingsFileName = ""
            SettNameBox.Text = ""
            RefreshConfigList()
            UpdatePathInfo()
        end
    end)

    RefreshConfigList()

    local bindingMenuKey = false
    MenuKeyButton.MouseButton1Click:Connect(function()
        bindingMenuKey = true
        MenuKeyButton.Text = "Press any key..."
    end)

    -- Mobile Minimize-Button (eigene ScreenGui, damit er sichtbar bleibt wenn das GUI zu ist)
    local MobileGui, MobileBtn, MobileStroke, MobileIcon
    if IsMobile then
        MobileGui = Create("ScreenGui", {
            Name = "SketchGUILibrary_Mobile",
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 20,
            Parent = parent,
        })
        MobileBtn = Create("ImageButton", {
            Name = "MinimizeButton",
            AnchorPoint = Vector2.new(0.5, 0),
            Size = UDim2.new(0, 48, 0, 48),
            Position = UDim2.new(0.5, 0, 0, 8),
            BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = 0.08,
            AutoButtonColor = false,
            Image = "",
            Parent = MobileGui,
        })
        Corner(MobileBtn, 24)
        MobileStroke = Stroke(MobileBtn, Theme.Stroke, 2, 0)
        MobileIcon = Create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 28, 0, 28),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 1,
            Image = LOGO,
            Parent = MobileBtn,
        })
    end

    local menuOpen = false
    local isLoaded = false

    -- Maus freigeben solange das Menue offen ist (Shift-Lock, First Person, Mouse-Lock Games)
    local prevMouseBehavior, prevMouseIcon
    local function SetMouseFree(on)
        if not IsPC or not Library.AutoUnlockMouse then return end
        pcall(function() RunService:UnbindFromRenderStep("PyroXMouseFree") end)
        if on then
            if prevMouseBehavior == nil then
                prevMouseBehavior = UserInputService.MouseBehavior
                prevMouseIcon = UserInputService.MouseIconEnabled
            end
            pcall(function() ModalBtn.Modal = true end)
            RunService:BindToRenderStep("PyroXMouseFree", Enum.RenderPriority.Last.Value + 5, function()
                if not ScreenGui.Parent or not menuOpen then
                    return
                end
                -- Rechtsklick gehalten = Kamera drehen (Standard-Kamera / Spiel darf die Maus selbst sperren)
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    return
                end
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        else
            pcall(function() ModalBtn.Modal = false end)
            if prevMouseBehavior ~= nil then
                pcall(function()
                    UserInputService.MouseBehavior = prevMouseBehavior
                    UserInputService.MouseIconEnabled = prevMouseIcon
                end)
                prevMouseBehavior = nil
                prevMouseIcon = nil
            end
        end
    end
    local function ToggleMainMenu(isOpen)
        menuOpen = isOpen
        SetMouseFree(isOpen)
        Library.SetMobileKeyEditing(isOpen)
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        if MobileStroke then
            Tween(MobileStroke, 0.25, {Color = isOpen and Library.ThemeColor or Theme.Stroke})
            Tween(MobileIcon, 0.4, {Rotation = isOpen and 0 or -90}, Enum.EasingStyle.Back)
        end
        if menuOpen then
            ScreenGui.Enabled = true
            MainFrame.Size = UDim2.new(0, WIN_W - 50, 0, WIN_H - 40)
            MainFrame.BackgroundTransparency = 1
            TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, WIN_W, 0, WIN_H), BackgroundTransparency = MAIN_BG}):Play()
            if Mascot then
                Mascot.ImageTransparency = 1
                TweenService:Create(Mascot, tweenInfo, {ImageTransparency = Library.BackgroundImageTransparency}):Play()
            end
            if DimOverlay.Visible then
                TweenService:Create(DimOverlay, tweenInfo, {BackgroundTransparency = 0.6}):Play()
            end
        else
            CloseAllPopups()
            local tw1 = TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, WIN_W - 50, 0, WIN_H - 40), BackgroundTransparency = 1})
            local tw2 = TweenService:Create(DimOverlay, tweenInfo, {BackgroundTransparency = 1})
            tw1:Play()
            tw2:Play()
            if Mascot then
                TweenService:Create(Mascot, tweenInfo, {ImageTransparency = 1}):Play()
            end
            tw1.Completed:Connect(function()
                if not menuOpen then
                    ScreenGui.Enabled = false
                    MainFrame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
                    MainFrame.BackgroundTransparency = MAIN_BG
                    if Mascot then
                        Mascot.ImageTransparency = Library.BackgroundImageTransparency
                    end
                end
            end)

            if IsMobile then
                ShowPopup("GUI closed! Tap the button on top to reopen.")
            else
                local currentKey = Library.Flags[menuKeyFlag]
                local keyName = (typeof(currentKey) == "EnumItem" and currentKey ~= Enum.KeyCode.None) and currentKey.Name or "RightShift"
                ShowPopup("GUI closed! Press [" .. keyName .. "] to reopen.")
            end
        end
    end

    if MobileCloseBtn then
        MobileCloseBtn.MouseButton1Click:Connect(function()
            ToggleMainMenu(false)
        end)
    end

    -- Mobile Button: Tippen = öffnen/schließen, Ziehen = verschieben
    if MobileBtn then
        local mbDragging, mbMoved, mbStart, mbStartPos = false, false, nil, nil
        MobileBtn.InputBegan:Connect(function(input)
            if IsPress(input) then
                mbDragging = true
                mbMoved = false
                mbStart = input.Position
                mbStartPos = MobileBtn.Position
                local conn
                conn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        conn:Disconnect()
                        mbDragging = false
                        if not mbMoved and isLoaded then
                            ClickFlash(MobileBtn)
                            ToggleMainMenu(not menuOpen)
                        end
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if mbDragging and IsMove(input) then
                local d = input.Position - mbStart
                if d.Magnitude > 8 then
                    mbMoved = true
                end
                if mbMoved then
                    MobileBtn.Position = UDim2.new(mbStartPos.X.Scale, mbStartPos.X.Offset + d.X, mbStartPos.Y.Scale, mbStartPos.Y.Offset + d.Y)
                end
            end
        end)
    end

    -- Menue-Taste per ContextActionService (hohe Prioritaet + Sink): das Spiel bekommt die Taste
    -- nicht mehr, d.h. Shift-Lock wird NICHT mehr umgeschaltet wenn RightShift das Menue oeffnet.
    local casBound = false
    local function BindMenuAction()
        pcall(function() ContextActionService:UnbindAction("PyroXMenuKey") end)
        casBound = false
        if IsMobile then return end
        local k =Library.Flags[menuKeyFlag]
        if typeof(k) == "string" then
            k = Enum.KeyCode[k]
        end
        if typeof(k) ~= "EnumItem" or k == Enum.KeyCode.None or k.EnumType ~= Enum.KeyCode then
            return
        end
        local ok = pcall(function()
            ContextActionService:BindActionAtPriority("PyroXMenuKey", function(_, state)
                if bindingMenuKey then
                    return Enum.ContextActionResult.Pass
                end
                if state == Enum.UserInputState.Begin then
                    ToggleMainMenu(not menuOpen)
                end
                return Enum.ContextActionResult.Sink
            end, false, Enum.ContextActionPriority.High.Value + 2000, k)
        end)
        casBound = ok
    end
    pcall(function() ContextActionService:UnbindAction("PyroXMenuKey") end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if bindingMenuKey then
            local validKey = false
            local keyName = ""
            local keyValue = nil

            if input.UserInputType == Enum.UserInputType.Keyboard then
                validKey = true
                keyName = input.KeyCode.Name
                keyValue = input.KeyCode
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                validKey = true
                keyName = input.UserInputType.Name
                keyValue = input.UserInputType
            end

            if validKey then
                Library.Flags[menuKeyFlag] = keyValue
                MenuKeyButton.Text = keyName
                bindingMenuKey = false
                UpdateKeyHint()
                BindMenuAction()
            end
        elseif not casBound and ShouldHandleKey(input, gameProcessed) then
            local targetKey = Library.Flags[menuKeyFlag]
            if typeof(targetKey) == "string" then
                pcall(function()
                    targetKey = Enum.KeyCode[targetKey] or Enum.UserInputType[targetKey] or Enum.KeyCode.RightShift
                end)
            end
            if targetKey then
                if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == targetKey) or (input.UserInputType == targetKey) then
                    ToggleMainMenu(not menuOpen)
                end
            end
        end
    end)

    table.insert(Library.ElementUpdaters, function()
        local val = Library.Flags[menuKeyFlag]
        if val ~= nil then
            if typeof(val) == "string" then
                pcall(function()
                    Library.Flags[menuKeyFlag] = Enum.KeyCode[val] or Enum.UserInputType[val] or Enum.KeyCode.RightShift
                end)
            end
            local currentKey = Library.Flags[menuKeyFlag]
            MenuKeyButton.Text = (typeof(currentKey) == "EnumItem" and currentKey ~= Enum.KeyCode.None) and currentKey.Name or "RightShift"
            UpdateKeyHint()
            BindMenuAction()
        end
    end)
    BindMenuAction()

    local sideTabs = {}
    local firstSideTab = true

    SettingsButton.MouseButton1Click:Connect(function()
        CloseAllPopups()
        for _, t in pairs(sideTabs) do
            SetTabVisual(t.Button, false)
            t.HeaderBar.Visible = false
            if not IsPC then
                for _, sub in pairs(t.SubTabs) do
                    SetTabVisual(sub.Button, false)
                    sub.Container.Visible = false
                end
            end
        end
        SettingsPanel.Visible = not SettingsPanel.Visible
        SetSettingsVisual(SettingsPanel.Visible)
        if SettingsPanel.Visible then
            RefreshConfigList()
        end
    end)

    local FilterTitle = Create("TextLabel", {
        Name = "FilterTitle", -- WICHTIG: Name, damit wir ihn später finden
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = "LOOT FILTER",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = FilterPanel,
    })
    local FilterLine = Create("Frame", {
        Size = UDim2.new(1, -24, 0, 1),
        Position = UDim2.new(0, 12, 0, 35),
        BackgroundColor3 = Library.ThemeColor,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = FilterPanel,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = FilterLine,
    })

    -- Animiertes Filter Panel
    local filterOpen = false
    local function CloseFilter()
        if not filterOpen then return end
        filterOpen = false
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tw = TweenService:Create(FilterPanel, tweenInfo, {BackgroundTransparency = 1, Size = UDim2.new(0, 190, 0, WIN_H - 20)})
        tw:Play()
        tw.Completed:Wait()
        FilterPanel.Visible = false
        FilterPanel.BackgroundTransparency = 0.1
        FilterPanel.Size = UDim2.new(0, 210, 0, WIN_H)
    end
    table.insert(openPopups, CloseFilter)

    local function ToggleFilterPanel()
        local targetState = not filterOpen
        CloseAllPopups()
        if targetState then
            filterOpen = true
            FilterPanel.Visible = true
            FilterPanel.BackgroundTransparency = 1
            FilterPanel.Size = UDim2.new(0, 190, 0, WIN_H - 20)
            local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            TweenService:Create(FilterPanel, tweenInfo, {BackgroundTransparency = 0.1, Size = UDim2.new(0, 210, 0, WIN_H)}):Play()
        else
            CloseFilter()
        end
    end

    -- Gemeinsame Verbindungen des Color Pickers (werden beim Neuaufbau getrennt)
    local cpConnections = {}
    local function ClearCPConnections()
        for _, c in ipairs(cpConnections) do
            c:Disconnect()
        end
        cpConnections = {}
    end

    function Window:AddTab(tabName)
        local TabObj = {}
        local t_first_sub = nil
        local isThisFirstTab = firstSideTab

        local SideButton = Create("TextButton", {
            Size = UDim2.new(1, -2, 0, IsPC and 36 or 32),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 0.35,
            AutoButtonColor = false,
            Font = Library.Font,
            Text = tabName,
            TextColor3 = Theme.SubText,
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 3,
            Parent = SideTabScroll,
        })
        Corner(SideButton, 6)
        Shine(SideButton)
        local ind = Create("Frame", {
            Name = "Indicator",
            Size = UDim2.new(0, 3, 0.5, 0),
            Position = UDim2.new(0, 5, 0.25, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = SideButton,
        })
        Corner(ind, 2)

        local SubTabHeaderBar
        local PCColLeft, PCColRight
        local PCSubCount = 0
        local PCPageScroll, PCChipBar, PCAllChip
        local PCSingle = false
        if IsPC then
            -- PC: eine Seite pro Tab, alle Sub-Tabs als Karten in 2 Spalten
            SubTabHeaderBar = Create("Frame", {
                Name = tabName .. "_Page",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Visible = false,
                ZIndex = 3,
                Parent = ContentContainer,
            })
            Create("TextLabel", {
                Name = "PageTitle",
                Size = UDim2.new(1, -4, 0, 28),
                Position = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Font = Library.FontBold,
                Text = tabName,
                TextColor3 = Theme.Text,
                TextSize = 18,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 3,
                Parent = SubTabHeaderBar,
            })
            local pageLine = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 0, 31),
                BackgroundColor3 = Library.ThemeColor,
                BorderSizePixel = 0,
                ZIndex = 3,
                Parent = SubTabHeaderBar,
            })
            Create("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.6, 0.5),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = pageLine,
            })
            local PageScroll = Create("ScrollingFrame", {
                Name = "PageScroll",
                Size = UDim2.new(1, 0, 1, -40),
                Position = UDim2.new(0, 0, 0, 40),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = Library.ThemeColor,
                ZIndex = 3,
                Parent = SubTabHeaderBar,
            })
            PCPageScroll = PageScroll
            PCColLeft = Create("Frame", {
                Name = "ColLeft",
                Size = UDim2.new(0.5, -7, 0, 0),
                Position = UDim2.new(0, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                ZIndex = 3,
                Parent = PageScroll,
            })
            PCColRight = Create("Frame", {
                Name = "ColRight",
                Size = UDim2.new(0.5, -9, 0, 0),
                Position = UDim2.new(0.5, 3, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                ZIndex = 3,
                Parent = PageScroll,
            })
            for _, col in ipairs({PCColLeft, PCColRight}) do
                Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 8),
                    Parent = col,
                })
                Create("UIPadding", {PaddingBottom = UDim.new(0, 10), Parent = col})
            end

            -- Sub-Tab-Leiste (Chips): erst sichtbar, wenn der Tab mindestens 2 Sub-Tabs hat
            PCChipBar = Create("ScrollingFrame", {
                Name = "SubTabChips",
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.new(0, 0, 0, 38),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                ScrollingDirection = Enum.ScrollingDirection.X,
                Visible = false,
                ZIndex = 3,
                Parent = SubTabHeaderBar,
            })
            Create("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = PCChipBar})
            local chipLayout = Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = PCChipBar,
            })
            chipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                PCChipBar.CanvasSize = UDim2.new(0, chipLayout.AbsoluteContentSize.X + 10, 0, 0)
            end)
        else
            SubTabHeaderBar = Create("ScrollingFrame", {
                Name = tabName .. "_SubBar",
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                ScrollingDirection = Enum.ScrollingDirection.X,
                Visible = false,
                ZIndex = 3,
                Parent = ContentContainer,
            })
            Create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), Parent = SubTabHeaderBar})

            local SubHeaderLayout = Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = SubTabHeaderBar,
            })
            SubHeaderLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                SubTabHeaderBar.CanvasSize = UDim2.new(0, SubHeaderLayout.AbsoluteContentSize.X + 10, 0, 0)
            end)
        end

        if firstSideTab then
            SetTabVisual(SideButton, true)
            SubTabHeaderBar.Visible = true
        end

        SideButton.MouseButton1Click:Connect(function()
            CloseAllPopups()
            SettingsPanel.Visible = false
            SetSettingsVisual(false)
            for _, t in pairs(sideTabs) do
                SetTabVisual(t.Button, false)
                t.HeaderBar.Visible = false
                if not IsPC then
                    for _, sub in pairs(t.SubTabs) do
                        SetTabVisual(sub.Button, false)
                        sub.Container.Visible = false
                    end
                end
            end

            SetTabVisual(SideButton, true)
            SubTabHeaderBar.Visible = true
            if IsPC then
                SubTabHeaderBar.Position = UDim2.new(0, 0, 0, 12)
                Tween(SubTabHeaderBar, 0.3, {Position = UDim2.new(0, 0, 0, 0)})
            end
            if t_first_sub and not IsPC then
                SetTabVisual(t_first_sub.Button, true)
                if t_first_sub.Container then
                    ShowContainer(t_first_sub.Container)
                end
            end
        end)

        TabObj.Button = SideButton
        TabObj.HeaderBar = SubTabHeaderBar
        TabObj.SubTabs = {}

        -- PC: Sub-Tab auswaehlen (sel = SubObj) oder "All" (sel = nil) = alle Karten in 2 Spalten
        local function PCSelect(sel)
            if not IsPC or Library.PCSubTabMode == "cards" then return end
            PCSingle = sel ~= nil
            TabObj.PCSelected = sel
            PCColLeft.Size = PCSingle and UDim2.new(1, -4, 0, 0) or UDim2.new(0.5, -7, 0, 0)
            PCColRight.Visible = not PCSingle
            for _, s in ipairs(TabObj.SubTabs) do
                local card = s.Container
                if PCSingle then
                    if s == sel then
                        card.Parent = PCColLeft
                        card.Visible = true
                    else
                        card.Visible = false
                    end
                else
                    card.Parent = s.PCCol
                    card.Visible = true
                end
            end
            if PCAllChip then SetTabVisual(PCAllChip, not PCSingle) end
            for _, s in ipairs(TabObj.SubTabs) do
                if s.Chip then SetTabVisual(s.Chip, s == sel) end
            end
            PCPageScroll.CanvasPosition = Vector2.new(0, 0)
        end

        -- PC: Leiste ein-/ausblenden und Seiteninhalt darunter verschieben
        local function PCRelayout()
            if not IsPC then return end
            local useChips = Library.PCSubTabMode ~= "cards" and #TabObj.SubTabs >= 2
            PCChipBar.Visible = useChips
            PCPageScroll.Position = UDim2.new(0, 0, 0, useChips and 74 or 40)
            PCPageScroll.Size = UDim2.new(1, 0, 1, useChips and -74 or -40)
        end

        function TabObj:AddSubTab(subTabName)
            local SubObj = {}

            local SubButton, ElementScroll, ElementLayout, CardFrame
            if IsPC then
                PCSubCount = PCSubCount + 1
                local colParent = (PCSubCount % 2 == 1) and PCColLeft or PCColRight
                CardFrame = Create("Frame", {
                    Name = subTabName .. "_Card",
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Panel,
                    BackgroundTransparency = 0.3,
                    BorderSizePixel = 0,
                    LayoutOrder = PCSubCount,
                    ZIndex = 3,
                    Parent = colParent,
                })
                Corner(CardFrame, 8)
                Stroke(CardFrame, Theme.Stroke, 1, 0.4)
                Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = CardFrame,
                })
                local cardHead = Create("Frame", {
                    Name = "Head",
                    LayoutOrder = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundTransparency = 1,
                    ZIndex = 3,
                    Parent = CardFrame,
                })
                local cardBar = Create("Frame", {
                    Size = UDim2.new(0, 3, 0, 14),
                    Position = UDim2.new(0, 10, 0, 10),
                    BackgroundColor3 = Library.ThemeColor,
                    BorderSizePixel = 0,
                    ZIndex = 4,
                    Parent = cardHead,
                })
                Corner(cardBar, 2)
                Create("TextLabel", {
                    Size = UDim2.new(1, -30, 1, 0),
                    Position = UDim2.new(0, 22, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Library.FontBold,
                    Text = subTabName,
                    TextColor3 = Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 4,
                    Parent = cardHead,
                })
                local cardLine = Create("Frame", {
                    Size = UDim2.new(1, -20, 0, 1),
                    Position = UDim2.new(0, 10, 1, -1),
                    BackgroundColor3 = Library.ThemeColor,
                    BorderSizePixel = 0,
                    ZIndex = 4,
                    Parent = cardHead,
                })
                Create("UIGradient", {
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.1),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                    Parent = cardLine,
                })
                ElementScroll = Create("Frame", {
                    Name = "Elements",
                    LayoutOrder = 2,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    ZIndex = 3,
                    Parent = CardFrame,
                })
                Create("UIPadding", {
                    PaddingTop = UDim.new(0, 8),
                    PaddingBottom = UDim.new(0, 10),
                    PaddingLeft = UDim.new(0, 8),
                    Parent = ElementScroll,
                })
                Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 6),
                    Parent = ElementScroll,
                })
                -- Platzhalter damit der Rest der Library (Button / Visual) unveraendert funktioniert
                SubButton = Create("TextButton", {
                    Visible = false,
                    Size = UDim2.new(0, 0, 0, 0),
                    Text = "",
                    Parent = CardFrame,
                })
                SubObj.PCCol = colParent
                if Library.PCSubTabMode ~= "cards" then
                    -- "All"-Chip wird mit dem ersten Sub-Tab angelegt
                    if not PCAllChip then
                        PCAllChip = Create("TextButton", {
                            Name = "AllChip",
                            Size = UDim2.new(0, 52, 0, 26),
                            BackgroundColor3 = Theme.Element,
                            BackgroundTransparency = 0.35,
                            AutoButtonColor = false,
                            Font = Library.Font,
                            Text = "All",
                            TextColor3 = Theme.SubText,
                            TextSize = 12,
                            LayoutOrder = 0,
                            ZIndex = 4,
                            Parent = PCChipBar,
                        })
                        Corner(PCAllChip, 6)
                        Shine(PCAllChip)
                        PCAllChip.MouseButton1Click:Connect(function()
                            CloseAllPopups()
                            PCSelect(nil)
                        end)
                    end
                    local chipW = TextService:GetTextSize(subTabName, 12, Library.FontBold, Vector2.new(1000, 30)).X
                    local chip = Create("TextButton", {
                        Name = subTabName .. "_Chip",
                        Size = UDim2.new(0, math.max(64, chipW + 26), 0, 26),
                        BackgroundColor3 = Theme.Element,
                        BackgroundTransparency = 0.35,
                        AutoButtonColor = false,
                        Font = Library.Font,
                        Text = subTabName,
                        TextColor3 = Theme.SubText,
                        TextSize = 12,
                        LayoutOrder = PCSubCount,
                        ZIndex = 4,
                        Parent = PCChipBar,
                    })
                    Corner(chip, 6)
                    Shine(chip)
                    SubObj.Chip = chip
                    chip.MouseButton1Click:Connect(function()
                        CloseAllPopups()
                        PCSelect(SubObj)
                    end)
                    -- ist gerade ein einzelner Sub-Tab offen, bleibt die neue Karte erst versteckt
                    if PCSingle then CardFrame.Visible = false end
                end
            else
                local textW = TextService:GetTextSize(subTabName, 12, Library.FontBold, Vector2.new(1000, 30)).X
                SubButton = Create("TextButton", {
                    Size = UDim2.new(0, math.max(84, textW + 28), 0, 27),
                    BackgroundColor3 = Theme.Element,
                    BackgroundTransparency = 0.35,
                    AutoButtonColor = false,
                    Font = Library.Font,
                    Text = subTabName,
                    TextColor3 = Theme.SubText,
                    TextSize = 12,
                    ZIndex = 3,
                    Parent = SubTabHeaderBar,
                })
                Corner(SubButton, 6)
                Shine(SubButton)

                ElementScroll = Create("ScrollingFrame", {
                    Size = UDim2.new(1, 0, 1, -36),
                    Position = UDim2.new(0, 0, 0, 36),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = Library.ThemeColor,
                    Visible = false,
                    ZIndex = 3,
                    Parent = ContentContainer,
                })
                Create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), Parent = ElementScroll})

                ElementLayout = Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 6),
                    Parent = ElementScroll,
                })
                ElementLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    ElementScroll.CanvasSize = UDim2.new(0, 0, 0, ElementLayout.AbsoluteContentSize.Y + 12)
                end)
            end

            if not IsPC then
                SubButton.MouseButton1Click:Connect(function()
                    CloseAllPopups()
                    for _, s in pairs(TabObj.SubTabs) do
                        SetTabVisual(s.Button, false)
                        s.Container.Visible = false
                    end
                    SetTabVisual(SubButton, true)
                    ShowContainer(ElementScroll)
                end)
            end

            SubObj.Button = SubButton
            SubObj.Container = IsPC and CardFrame or ElementScroll
            table.insert(TabObj.SubTabs, SubObj)
            if IsPC then
                if #TabObj.SubTabs == 1 then PCSelect(SubObj) end
                PCRelayout()
            end

            if not t_first_sub then
                t_first_sub = SubObj
                if isThisFirstTab then
                    SetTabVisual(SubButton, true)
                    ElementScroll.Visible = true
                end
            end

            -- 1. Toggle Button
            function SubObj:AddToggle(text, default, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Toggle"
                    default = cfg.Default
                    callback = cfg.Callback
                end

                local flag = tabName .. "_" .. subTabName .. "_" .. text
                if type(Library.Flags[flag]) ~= "boolean" then
                    Library.Flags[flag] = (default ~= nil) and default or false
                end

                local ToggleFrame = MakeRow(ElementScroll, 34)
                MakeLabel(ToggleFrame, text, 60)
                local Switch, Knob = CreateSwitch(ToggleFrame, -52, Library.Flags[flag])

                Switch.MouseButton1Click:Connect(function()
                    Library.Flags[flag] = not Library.Flags[flag]
                    SetSwitch(Switch, Knob, Library.Flags[flag])
                    if callback then callback(Library.Flags[flag]) end
                end)

                table.insert(Library.ElementUpdaters, function()
                    local val = Library.Flags[flag]
                    if val ~= nil then
                        SetSwitch(Switch, Knob, val)
                        if callback then callback(val) end
                    end
                end)
            end

            -- 2. Slider
            function SubObj:AddSlider(text, min, max, default, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Slider"
                    min = cfg.Min or 0
                    max = cfg.Max or 100
                    default = cfg.Default or min
                    callback = cfg.Callback
                end

                local flag = tabName .. "_" .. subTabName .. "_" .. text
                if type(Library.Flags[flag]) ~= "number" then
                    Library.Flags[flag] = default or min
                end

                local SliderFrame = MakeRow(ElementScroll, 52)

                Create("TextLabel", {
                    Size = UDim2.new(1, -100, 0, 20),
                    Position = UDim2.new(0, 12, 0, 6),
                    BackgroundTransparency = 1,
                    Font = Library.Font,
                    Text = text,
                    TextColor3 = Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 3,
                    Parent = SliderFrame,
                })

                local ValueLabel = Create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Size = UDim2.new(0, 0, 0, 18),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Position = UDim2.new(1, -10, 0, 7),
                    BackgroundColor3 = Library.ThemeColor,
                    BackgroundTransparency = 0.75,
                    Font = Library.FontBold,
                    Text = tostring(Library.Flags[flag]),
                    TextColor3 = Lighten(Library.ThemeColor, 0.6),
                    TextSize = 12,
                    ZIndex = 3,
                    Parent = SliderFrame,
                })
                Corner(ValueLabel, 4)
                Create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = ValueLabel})

                local SliderBar = Create("Frame", {
                    Size = UDim2.new(1, -24, 0, 6),
                    Position = UDim2.new(0, 12, 0, 35),
                    BackgroundColor3 = Theme.Off,
                    BorderSizePixel = 0,
                    ZIndex = 3,
                    Parent = SliderFrame,
                })
                Corner(SliderBar, 3)

                local startPosVal = math.clamp((Library.Flags[flag] - min) / (max - min), 0, 1)

                local SliderFill = Create("Frame", {
                    Size = UDim2.new(startPosVal, 0, 1, 0),
                    BackgroundColor3 = Library.ThemeColor,
                    BorderSizePixel = 0,
                    ZIndex = 3,
                    Parent = SliderBar,
                })
                Corner(SliderFill, 3)
                Shine(SliderFill, 0)

                local SKnob = Create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.new(0, 12, 0, 12),
                    Position = UDim2.new(startPosVal, 0, 0.5, 0),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 5,
                    Parent = SliderBar,
                })
                Corner(SKnob, 6)
                Stroke(SKnob, Library.ThemeColor, 2, 0)

                -- Größere Trefferfläche (wichtig für Mobile)
                local Hit = Create("TextButton", {
                    Size = UDim2.new(1, -12, 0, 26),
                    Position = UDim2.new(0, 6, 0, 25),
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 6,
                    Parent = SliderFrame,
                })

                local function setVisual(pos, val)
                    Tween(SliderFill, 0.08, {Size = UDim2.new(pos, 0, 1, 0)})
                    Tween(SKnob, 0.08, {Position = UDim2.new(pos, 0, 0.5, 0)})
                    ValueLabel.Text = tostring(val)
                end

                local draggingSlider = false
                local function updateSlider(input)
                    local pos = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                    local val = math.floor(min + ((max - min) * pos))
                    Library.Flags[flag] = val
                    setVisual(pos, val)
                    if callback then callback(val) end
                end

                Hit.InputBegan:Connect(function(input)
                    if IsPress(input) then
                        draggingSlider = true
                        Tween(SKnob, 0.15, {Size = UDim2.new(0, 16, 0, 16)})
                        updateSlider(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if IsPress(input) and draggingSlider then
                        draggingSlider = false
                        Tween(SKnob, 0.15, {Size = UDim2.new(0, 12, 0, 12)})
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if draggingSlider and IsMove(input) then
                        updateSlider(input)
                    end
                end)

                table.insert(Library.ElementUpdaters, function()
                    local val = Library.Flags[flag]
                    if val ~= nil then
                        local pos = math.clamp((val - min) / (max - min), 0, 1)
                        setVisual(pos, val)
                        if callback then callback(val) end
                    end
                end)
            end

            -- 3. Keybind
            function SubObj:AddKeybind(text, defaultKey, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Keybind"
                    defaultKey = cfg.Default or cfg.Key or Enum.KeyCode.None
                    callback = cfg.Callback
                end

                local flag = tabName .. "_" .. subTabName .. "_" .. text
                if Library.Flags[flag] == nil then
                    Library.Flags[flag] = defaultKey or Enum.KeyCode.None
                end

                local KeyFrame = MakeRow(ElementScroll, 34)
                MakeLabel(KeyFrame, text, 140)

                local ResetButton = MakeSmallButton(KeyFrame, "Reset", 50, -138, 11)
                local KeyButton = MakeSmallButton(KeyFrame, (typeof(Library.Flags[flag]) == "EnumItem" and Library.Flags[flag] ~= Enum.KeyCode.None) and Library.Flags[flag].Name or "None", 76, -84, 12)
                KeyButton.Font = Library.FontBold

                local Screen = AttachScreenKey(flag .. "_ScreenPos", function()
                    return Library.Flags[flag]
                end, function()
                    if callback then callback(Library.Flags[flag]) end
                end)
                local UpdateScreenKey = Screen.Update

                local binding = false
                KeyButton.MouseButton1Click:Connect(function()
                    if IsMobile then
                        local cur = Library.Flags[flag]
                        Library.OpenKeyPicker(text, function(kc)
                            Library.Flags[flag] = kc
                            KeyButton.Text = (kc ~= Enum.KeyCode.None) and kc.Name or "None"
                            UpdateScreenKey()
                            if callback then callback(kc) end
                        end, typeof(cur) == "EnumItem" and cur.Name or nil)
                        return
                    end
                    binding = true
                    KeyButton.Text = "..."
                end)
                UpdateScreenKey()

                ResetButton.MouseButton1Click:Connect(function()
                    ClickFlash(ResetButton)
                    binding = false
                    Library.Flags[flag] = Enum.KeyCode.None
                    KeyButton.Text = "None"
                    UpdateScreenKey()
                    if callback then callback(Enum.KeyCode.None) end
                end)

                UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if binding then
                        local validKey = false
                        local keyName = ""
                        local keyValue = nil

                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            validKey = true
                            keyName = input.KeyCode.Name
                            keyValue = input.KeyCode
                        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                            validKey = true
                            keyName = input.UserInputType.Name
                            keyValue = input.UserInputType
                        end

                        if validKey then
                            Library.Flags[flag] = keyValue
                            KeyButton.Text = keyName
                            binding = false
                            UpdateScreenKey()
                            if callback then callback(keyValue) end
                        end
                    elseif ShouldHandleKey(input, gameProcessed) and Library.Flags[flag] ~= Enum.KeyCode.None then
                        if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Library.Flags[flag]) or (input.UserInputType == Library.Flags[flag]) then
                            if callback then callback(Library.Flags[flag]) end
                        end
                    end
                end)

                table.insert(Library.ElementUpdaters, function()
                    local val = Library.Flags[flag]
                    if val ~= nil then
                        if typeof(val) == "string" then
                            pcall(function()
                                if val == "None" then
                                    Library.Flags[flag] = Enum.KeyCode.None
                                else
                                    Library.Flags[flag] = Enum.KeyCode[val] or Enum.UserInputType[val] or Enum.KeyCode.None
                                end
                            end)
                        end
                        local currentKey = Library.Flags[flag]
                        KeyButton.Text = (typeof(currentKey) == "EnumItem" and currentKey ~= Enum.KeyCode.None) and currentKey.Name or "None"
                        UpdateScreenKey()
                        if callback and typeof(currentKey) == "EnumItem" then callback(currentKey) end
                    end
                end)
            end

            -- 4. Dropdown (Animiert)
            function SubObj:AddDropdown(text, options, multiSelect, default, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Dropdown"
                    options = cfg.Options or {}
                    multiSelect = cfg.MultiSelect or false
                    default = cfg.Default
                    callback = cfg.Callback
                end

                local flag = tabName .. "_" .. subTabName .. "_" .. text
                if Library.Flags[flag] == nil or type(Library.Flags[flag]) ~= (multiSelect and "table" or "string") then
                    if multiSelect then
                        Library.Flags[flag] = default or {}
                    else
                        Library.Flags[flag] = default or options[1]
                    end
                end

                local DropFrame = MakeRow(ElementScroll, 34)
                MakeLabel(DropFrame, text, 145)

                local DropButton = Create("TextButton", {
                    Size = UDim2.new(0, 135, 0, 24),
                    Position = UDim2.new(1, -145, 0.5, -12),
                    BackgroundColor3 = Theme.ElementAlt,
                    AutoButtonColor = false,
                    Font = Library.Font,
                    Text = "",
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 3,
                    Parent = DropFrame,
                })
                Corner(DropButton, 5)
                Stroke(DropButton, Theme.Stroke, 1, 0.3)
                AddHover(DropButton, Theme.ElementAlt, Theme.Hover)
                Create("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 22), Parent = DropButton})
                local Arrow = Create("TextLabel", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(1, 13, 0.5, 0),
                    BackgroundTransparency = 1,
                    Font = Library.FontBold,
                    Text = "▼",
                    TextColor3 = Theme.SubText,
                    TextSize = 9,
                    ZIndex = 4,
                    Parent = DropButton,
                })

                local updateButtonText
                local targetHeight = math.clamp(#options * 30 + 10, 30, 180)
                local ListFrame = Create("ScrollingFrame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.new(0, 220, 0, targetHeight),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    BackgroundColor3 = Theme.Panel,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, #options * 32 + 8),
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = Library.ThemeColor,
                    Visible = false,
                    ZIndex = 60,
                    Parent = MainFrame,
                })
                Corner(ListFrame, 8)
                Stroke(ListFrame, Library.ThemeColor, 1, 0.35)
                Create("UIPadding", {
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
                    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                    Parent = ListFrame,
                })

                local dropdownOpen = false
                local function CloseDropdown()
                    if not dropdownOpen then return end
                    dropdownOpen = false
                    Tween(Arrow, 0.2, {Rotation = 0})
                    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local tw = TweenService:Create(ListFrame, tweenInfo, {BackgroundTransparency = 1, Size = UDim2.new(0, 200, 0, 0)})
                    tw:Play()
                    tw.Completed:Wait()
                    ListFrame.Visible = false
                    ListFrame.BackgroundTransparency = 0
                    ListFrame.Size = UDim2.new(0, 220, 0, targetHeight)
                end
                table.insert(openPopups, CloseDropdown)

                Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 2),
                    Parent = ListFrame,
                })

                local optButtons = {}

                local function createButtons()
                    for _, btn in pairs(optButtons) do
                        btn:Destroy()
                    end
                    optButtons = {}

                    for _, opt in ipairs(options) do
                        local OptBtn = Create("TextButton", {
                            Size = UDim2.new(1, -4, 0, 28),
                            BackgroundColor3 = Theme.ElementAlt,
                            AutoButtonColor = false,
                            Font = Library.Font,
                            Text = opt,
                            TextColor3 = Theme.Text,
                            TextSize = 12,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            ZIndex = 61,
                            Parent = ListFrame,
                        })
                        Corner(OptBtn, 5)
                        local optStroke = Stroke(OptBtn, Theme.Stroke, 1, 0.5)
                        OptBtn.MouseEnter:Connect(function()
                            Tween(optStroke, 0.15, {Color = Library.ThemeColor, Transparency = 0.1})
                        end)
                        OptBtn.MouseLeave:Connect(function()
                            Tween(optStroke, 0.15, {Color = Theme.Stroke, Transparency = 0.5})
                        end)

                        OptBtn.MouseButton1Click:Connect(function()
                            if multiSelect then
                                Library.Flags[flag][opt] = not Library.Flags[flag][opt]
                                OptBtn.BackgroundColor3 = Library.Flags[flag][opt] and Library.ThemeColor or Theme.ElementAlt
                            else
                                Library.Flags[flag] = opt
                                CloseAllPopups()
                            end
                            updateButtonText()
                            if callback then callback(Library.Flags[flag]) end
                        end)
                        optButtons[opt] = OptBtn
                    end
                end

                createButtons()

                updateButtonText = function()
                    if multiSelect then
                        local active = {}
                        for k, v in pairs(Library.Flags[flag]) do
                            if v then table.insert(active, k) end
                            if optButtons[k] then
                                optButtons[k].BackgroundColor3 = v and Library.ThemeColor or Theme.ElementAlt
                            end
                        end
                        DropButton.Text = (#active > 0) and table.concat(active, ", ") or "Select..."
                    else
                        DropButton.Text = tostring(Library.Flags[flag])
                        for opt, btn in pairs(optButtons) do
                            btn.BackgroundColor3 = (opt == Library.Flags[flag]) and Library.ThemeColor or Theme.ElementAlt
                        end
                    end
                end
                updateButtonText()

                DropButton.MouseButton1Click:Connect(function()
                    local targetState = not dropdownOpen
                    CloseAllPopups()
                    if targetState then
                        dropdownOpen = true
                        Tween(Arrow, 0.2, {Rotation = 180})
                        ListFrame.Visible = true
                        ListFrame.BackgroundTransparency = 1
                        ListFrame.Size = UDim2.new(0, 200, 0, 0)
                        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        TweenService:Create(ListFrame, tweenInfo, {BackgroundTransparency = 0, Size = UDim2.new(0, 220, 0, targetHeight)}):Play()
                        DimOverlay.Visible = true
                        DimOverlay.BackgroundTransparency = 1
                        TweenService:Create(DimOverlay, tweenInfo, {BackgroundTransparency = 0.6}):Play()
                    else
                        CloseDropdown()
                    end
                end)

                table.insert(Library.ElementUpdaters, function()
                    if Library.Flags[flag] ~= nil then
                        updateButtonText()
                        if callback then callback(Library.Flags[flag]) end
                    end
                end)

                local DropdownObj = {}
                function DropdownObj:Refresh(newOptions)
                    options = newOptions
                    targetHeight = math.clamp(#options * 30 + 10, 30, 180)
                    ListFrame.CanvasSize = UDim2.new(0, 0, 0, #options * 32 + 8)

                    createButtons()

                    if not multiSelect then
                        local found = false
                        for _, opt in ipairs(options) do
                            if opt == Library.Flags[flag] then found = true break end
                        end
                        if not found then
                            Library.Flags[flag] = options[1] or ""
                        end
                    end
                    updateButtonText()
                end

                return DropdownObj
            end

            -- 5. Filter Button
            function SubObj:AddFilterButton(text, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Filter"
                    callback = cfg.Callback
                end

                local FilterBtnFrame = MakeRow(ElementScroll, 34)
                MakeLabel(FilterBtnFrame, text, 120)

                local OpenBtn = MakeSmallButton(FilterBtnFrame, "Open Filter", 105, -115, 12)

                -- Eigene Liste für genau diesen Button erstellen
                local MyFilterScroll = Create("ScrollingFrame", {
                    Size = UDim2.new(1, -12, 1, -48),
                    Position = UDim2.new(0, 6, 0, 42),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = Library.ThemeColor,
                    Visible = false,
                    ZIndex = 4,
                    Parent = FilterPanel,
                })
                Create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), Parent = MyFilterScroll})

                local FilterListLayout = Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 5),
                    Parent = MyFilterScroll,
                })
                FilterListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    MyFilterScroll.CanvasSize = UDim2.new(0, 0, 0, FilterListLayout.AbsoluteContentSize.Y + 10)
                end)

                OpenBtn.MouseButton1Click:Connect(function()
                    ClickFlash(OpenBtn)
                    -- Verstecke alle anderen Listen im FilterPanel
                    for _, child in ipairs(FilterPanel:GetChildren()) do
                        if child:IsA("ScrollingFrame") then
                            child.Visible = false
                        end
                    end
                    -- Zeige nur diese an
                    MyFilterScroll.Visible = true

                    -- Ändere den Titel dynamisch
                    local titleLbl = FilterPanel:FindFirstChild("FilterTitle")
                    if titleLbl then titleLbl.Text = string.upper(text) end

                    ToggleFilterPanel()
                    if callback then callback() end
                end)

                local FilterObj = {}

                -- AddItem packt das Item NUR in diese eigene Liste
                function FilterObj:AddItem(itemName, default, itemCallback)
                    if type(itemName) == "table" and not itemName.Name and not itemName.Text then
                        for _, name in ipairs(itemName) do
                            FilterObj:AddItem(name, default, itemCallback)
                        end
                        return
                    end

                    if type(itemName) == "table" then
                        local cfg = itemName
                        itemName = cfg.Name or cfg.Text or "Item"
                        default = cfg.Default
                        itemCallback = cfg.Callback
                    end

                    -- Der Flag bekommt den Namen vom Filter, damit Configs sich nicht überschneiden
                    local flag = "Filter_" .. text .. "_" .. itemName
                    if Library.Flags[flag] == nil then
                        Library.Flags[flag] = (default ~= nil) and default or false
                    end

                    local ItemFrame = MakeRow(MyFilterScroll, 32)
                    ItemFrame.Size = UDim2.new(1, -6, 0, 32)
                    MakeLabel(ItemFrame, itemName, 56, 12)
                    local Switch, Knob = CreateSwitch(ItemFrame, -50, Library.Flags[flag])

                    Switch.MouseButton1Click:Connect(function()
                        Library.Flags[flag] = not Library.Flags[flag]
                        SetSwitch(Switch, Knob, Library.Flags[flag])
                        ShowPopup(itemName .. " is now " .. (Library.Flags[flag] and "ON" or "OFF"))

                        if itemCallback then itemCallback(Library.Flags[flag]) end
                    end)

                    table.insert(Library.ElementUpdaters, function()
                        local val = Library.Flags[flag]
                        if val ~= nil then
                            SetSwitch(Switch, Knob, val)
                            if itemCallback then itemCallback(val) end
                        end
                    end)
                end

                return FilterObj
            end

            -- 6. Color Picker (Animiert)
            function SubObj:AddColorPicker(text, defaultColor, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Color Picker"
                    defaultColor = cfg.Default or Color3.fromRGB(255, 255, 255)
                    callback = cfg.Callback
                end

                local flag = tabName .. "_" .. subTabName .. "_" .. text
                if Library.Flags[flag] == nil or typeof(Library.Flags[flag]) == "boolean" or type(Library.Flags[flag]) == "number" or type(Library.Flags[flag]) == "string" then
                    Library.Flags[flag] = defaultColor or Color3.fromRGB(255, 255, 255)
                end

                local ColorFrame = MakeRow(ElementScroll, 34)
                MakeLabel(ColorFrame, text, 120)

                local curCol = Library.Flags[flag]
                if type(curCol) == "table" then
                    curCol = Color3.new(curCol["R"] or 1, curCol["G"] or 1, curCol["B"] or 1)
                    Library.Flags[flag] = curCol
                end

                local ColorDisplay = Create("TextButton", {
                    Size = UDim2.new(0, 105, 0, 24),
                    Position = UDim2.new(1, -115, 0.5, -12),
                    BackgroundColor3 = curCol,
                    AutoButtonColor = false,
                    Font = Library.FontBold,
                    Text = "Set Color",
                    TextColor3 = ContrastText(curCol),
                    TextSize = 12,
                    ZIndex = 3,
                    Parent = ColorFrame,
                })
                Corner(ColorDisplay, 5)
                Stroke(ColorDisplay, Theme.Stroke, 1, 0.2)

                local function SetDisplayColor(col)
                    ColorDisplay.BackgroundColor3 = col
                    ColorDisplay.TextColor3 = ContrastText(col)
                end

                local colorPickerOpen = false
                local function CloseColorPicker()
                    if not colorPickerOpen then return end
                    colorPickerOpen = false
                    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local tw = TweenService:Create(ColorPickerPanel, tweenInfo, {BackgroundTransparency = 1, Size = UDim2.new(0, 190, 0, 176)})
                    tw:Play()
                    tw.Completed:Wait()
                    ColorPickerPanel.Visible = false
                    ColorPickerPanel.BackgroundTransparency = 0.1
                    ColorPickerPanel.Size = UDim2.new(0, 210, 0, 196)
                end
                table.insert(openPopups, CloseColorPicker)

                ColorDisplay.MouseButton1Click:Connect(function()
                    local targetState = not colorPickerOpen
                    CloseAllPopups()
                    if targetState then
                        colorPickerOpen = true

                        ClearCPConnections()
                        for _, v in pairs(CPContent:GetChildren()) do
                            v:Destroy()
                        end

                        Create("TextLabel", {
                            Size = UDim2.new(1, -24, 0, 26),
                            Position = UDim2.new(0, 12, 0, 4),
                            BackgroundTransparency = 1,
                            Font = Library.FontBold,
                            Text = text .. " RGB",
                            TextColor3 = Theme.Text,
                            TextSize = 13,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            ZIndex = 4,
                            Parent = CPContent,
                        })

                        local c = Library.Flags[flag]
                        if type(c) == "table" then c = Color3.new(c["R"] or 1, c["G"] or 1, c["B"] or 1) end
                        local red, green, blue = math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)

                        local Preview = Create("Frame", {
                            Size = UDim2.new(0, 34, 0, 22),
                            Position = UDim2.new(0, 12, 0, 32),
                            BackgroundColor3 = c,
                            BorderSizePixel = 0,
                            ZIndex = 4,
                            Parent = CPContent,
                        })
                        Corner(Preview, 5)
                        Stroke(Preview, Theme.Stroke, 1, 0)

                        local HexLabel = Create("TextLabel", {
                            Size = UDim2.new(1, -66, 0, 22),
                            Position = UDim2.new(0, 54, 0, 32),
                            BackgroundTransparency = 1,
                            Font = Library.FontBold,
                            Text = "#" .. c:ToHex():upper(),
                            TextColor3 = Theme.SubText,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 4,
                            Parent = CPContent,
                        })

                        local function refreshPreview()
                            local col = Color3.fromRGB(red, green, blue)
                            Preview.BackgroundColor3 = col
                            HexLabel.Text = "#" .. col:ToHex():upper()
                            SetDisplayColor(col)
                        end

                        local function makeColorSlider(name, yPos, initialVal, fillColor, updateFunc)
                            local sLbl = Create("TextLabel", {
                                Size = UDim2.new(1, -24, 0, 15),
                                Position = UDim2.new(0, 12, 0, yPos),
                                BackgroundTransparency = 1,
                                Font = Library.Font,
                                Text = name .. ": " .. tostring(initialVal),
                                TextColor3 = Theme.Text,
                                TextSize = 12,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                ZIndex = 4,
                                Parent = CPContent,
                            })

                            local sBar = Create("Frame", {
                                Size = UDim2.new(1, -24, 0, 6),
                                Position = UDim2.new(0, 12, 0, yPos + 19),
                                BackgroundColor3 = Theme.Off,
                                BorderSizePixel = 0,
                                ZIndex = 4,
                                Parent = CPContent,
                            })
                            Corner(sBar, 3)

                            local sFill = Create("Frame", {
                                Size = UDim2.new(initialVal / 255, 0, 1, 0),
                                BackgroundColor3 = fillColor,
                                BorderSizePixel = 0,
                                ZIndex = 4,
                                Parent = sBar,
                            })
                            Corner(sFill, 3)

                            local sHit = Create("TextButton", {
                                Size = UDim2.new(1, -12, 0, 30),
                                Position = UDim2.new(0, 6, 0, yPos),
                                BackgroundTransparency = 1,
                                AutoButtonColor = false,
                                Text = "",
                                ZIndex = 6,
                                Parent = CPContent,
                            })

                            local draggingVal = false
                            local function apply(input)
                                local pos = math.clamp((input.Position.X - sBar.AbsolutePosition.X) / sBar.AbsoluteSize.X, 0, 1)
                                local val = math.floor(pos * 255)
                                sFill.Size = UDim2.new(pos, 0, 1, 0)
                                sLbl.Text = name .. ": " .. tostring(val)
                                updateFunc(val)
                            end

                            sHit.InputBegan:Connect(function(input)
                                if IsPress(input) then
                                    draggingVal = true
                                    apply(input)
                                end
                            end)
                            table.insert(cpConnections, UserInputService.InputEnded:Connect(function(input)
                                if IsPress(input) then draggingVal = false end
                            end))
                            table.insert(cpConnections, UserInputService.InputChanged:Connect(function(input)
                                if draggingVal and IsMove(input) then
                                    apply(input)
                                end
                            end))
                        end

                        makeColorSlider("Red", 64, red, Color3.fromRGB(255, 75, 95), function(v)
                            red = v
                            local newCol = Color3.fromRGB(red, green, blue)
                            Library.Flags[flag] = newCol
                            refreshPreview()
                            if callback then callback(newCol) end
                        end)
                        makeColorSlider("Green", 104, green, Color3.fromRGB(70, 220, 120), function(v)
                            green = v
                            local newCol = Color3.fromRGB(red, green, blue)
                            Library.Flags[flag] = newCol
                            refreshPreview()
                            if callback then callback(newCol) end
                        end)
                        makeColorSlider("Blue", 144, blue, Color3.fromRGB(80, 145, 255), function(v)
                            blue = v
                            local newCol = Color3.fromRGB(red, green, blue)
                            Library.Flags[flag] = newCol
                            refreshPreview()
                            if callback then callback(newCol) end
                        end)

                        ColorPickerPanel.Visible = true
                        ColorPickerPanel.BackgroundTransparency = 1
                        ColorPickerPanel.Size = UDim2.new(0, 190, 0, 176)
                        local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        TweenService:Create(ColorPickerPanel, tweenInfo, {BackgroundTransparency = 0.1, Size = UDim2.new(0, 210, 0, 196)}):Play()
                    else
                        CloseColorPicker()
                    end
                end)

                table.insert(Library.ElementUpdaters, function()
                    local col = Library.Flags[flag]
                    if type(col) == "table" then
                        col = Color3.new(col["R"] or 1, col["G"] or 1, col["B"] or 1)
                        Library.Flags[flag] = col
                    end
                    if typeof(col) == "Color3" then
                        SetDisplayColor(col)
                        if callback then callback(col) end
                    end
                end)
            end

            -- 7. Toggle Button with Keybind
            function SubObj:AddToggleWithKey(text, defaultToggle, defaultKey, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Toggle With Key"
                    defaultToggle = cfg.Default
                    defaultKey = cfg.Key
                    callback = cfg.Callback
                end

                local flagToggle = tabName .. "_" .. subTabName .. "_" .. text .. "_Toggle"
                local flagKey = tabName .. "_" .. subTabName .. "_" .. text .. "_Key"
                if type(Library.Flags[flagToggle]) ~= "boolean" then
                    Library.Flags[flagToggle] = (defaultToggle ~= nil) and defaultToggle or false
                end
                if Library.Flags[flagKey] == nil then
                    Library.Flags[flagKey] = defaultKey or Enum.KeyCode.None
                end

                local Frame = MakeRow(ElementScroll, 34)
                MakeLabel(Frame, text, 180)

                local ResetBtn = MakeSmallButton(Frame, "Reset", 46, -178, 11)
                local KeyBtn = MakeSmallButton(Frame, (typeof(Library.Flags[flagKey]) == "EnumItem" and Library.Flags[flagKey] ~= Enum.KeyCode.None) and Library.Flags[flagKey].Name or "None", 66, -126, 12)
                KeyBtn.Font = Library.FontBold
                local Switch, Knob = CreateSwitch(Frame, -52, Library.Flags[flagToggle])

                local toggleAction
                local Screen = AttachScreenKey(flagKey .. "_ScreenPos", function()
                    return Library.Flags[flagKey]
                end, function()
                    toggleAction()
                end)
                local UpdateScreenKey = Screen.Update

                toggleAction = function()
                    Library.Flags[flagToggle] = not Library.Flags[flagToggle]
                    SetSwitch(Switch, Knob, Library.Flags[flagToggle])
                    Screen.SetActive(Library.Flags[flagToggle])
                    ShowPopup(text .. " is now " .. (Library.Flags[flagToggle] and "ON" or "OFF"))
                    if callback then callback(Library.Flags[flagToggle]) end
                end

                Switch.MouseButton1Click:Connect(toggleAction)

                local binding = false
                KeyBtn.MouseButton1Click:Connect(function()
                    if IsMobile then
                        local cur = Library.Flags[flagKey]
                        Library.OpenKeyPicker(text, function(kc)
                            Library.Flags[flagKey] = kc
                            KeyBtn.Text = (kc ~= Enum.KeyCode.None) and kc.Name or "None"
                            UpdateScreenKey()
                            Screen.SetActive(Library.Flags[flagToggle])
                        end, typeof(cur) == "EnumItem" and cur.Name or nil)
                        return
                    end
                    binding = true
                    KeyBtn.Text = "..."
                end)
                UpdateScreenKey()
                Screen.SetActive(Library.Flags[flagToggle])

                ResetBtn.MouseButton1Click:Connect(function()
                    ClickFlash(ResetBtn)
                    binding = false
                    Library.Flags[flagKey] = Enum.KeyCode.None
                    KeyBtn.Text = "None"
                    UpdateScreenKey()
                end)

                UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if binding then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            Library.Flags[flagKey] = input.KeyCode
                            KeyBtn.Text = input.KeyCode.Name
                            binding = false
                            UpdateScreenKey()
                            Screen.SetActive(Library.Flags[flagToggle])
                        end
                    elseif input.UserInputType == Enum.UserInputType.Keyboard and ShouldHandleKey(input, gameProcessed) and Library.Flags[flagKey] ~= Enum.KeyCode.None and input.KeyCode == Library.Flags[flagKey] then
                        toggleAction()
                    end
                end)

                table.insert(Library.ElementUpdaters, function()
                    local tVal = Library.Flags[flagToggle]
                    local kVal = Library.Flags[flagKey]
                    if type(kVal) == "string" then
                        pcall(function()
                            if kVal == "None" then
                                Library.Flags[flagKey] = Enum.KeyCode.None
                            else
                                Library.Flags[flagKey] = Enum.KeyCode[kVal] or Enum.KeyCode.None
                            end
                        end)
                        kVal = Library.Flags[flagKey]
                    end
                    if tVal ~= nil then
                        SetSwitch(Switch, Knob, tVal)
                        if callback then callback(tVal) end
                    end
                    if kVal ~= nil and typeof(kVal) == "EnumItem" then
                        KeyBtn.Text = (kVal ~= Enum.KeyCode.None) and kVal.Name or "None"
                        UpdateScreenKey()
                        Screen.SetActive(Library.Flags[flagToggle])
                    end
                end)
            end

            -- 8. Text Field
            function SubObj:AddTextBox(text, placeholder, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "TextBox"
                    placeholder = cfg.Placeholder or "Enter Text..."
                    callback = cfg.Callback
                end

                local flag = tabName .. "_" .. subTabName .. "_" .. text
                if type(Library.Flags[flag]) ~= "string" then
                    Library.Flags[flag] = ""
                end

                local TextFrame = MakeRow(ElementScroll, 34)
                MakeLabel(TextFrame, text, 150)

                local Box = Create("TextBox", {
                    Size = UDim2.new(0, 140, 0, 24),
                    Position = UDim2.new(1, -150, 0.5, -12),
                    BackgroundColor3 = Theme.ElementAlt,
                    BorderSizePixel = 0,
                    Font = Library.Font,
                    PlaceholderText = placeholder or "Enter Text...",
                    PlaceholderColor3 = Theme.SubText,
                    Text = tostring(Library.Flags[flag]),
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 3,
                    Parent = TextFrame,
                })
                Corner(Box, 5)
                local BoxStroke = Stroke(Box, Theme.Stroke, 1, 0.3)
                Create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = Box})

                Box.Focused:Connect(function()
                    Tween(BoxStroke, 0.2, {Color = Library.ThemeColor, Transparency = 0})
                end)

                Box.FocusLost:Connect(function(enterPressed)
                    Tween(BoxStroke, 0.2, {Color = Theme.Stroke, Transparency = 0.3})
                    Library.Flags[flag] = Box.Text
                    if callback then callback(Box.Text, enterPressed) end
                end)

                table.insert(Library.ElementUpdaters, function()
                    local val = Library.Flags[flag]
                    if val ~= nil then
                        Box.Text = tostring(val)
                        if callback then callback(tostring(val), false) end
                    end
                end)
            end

            -- 9. Simple Button
            function SubObj:AddButton(text, callback)
                if type(text) == "table" then
                    local cfg = text
                    text = cfg.Name or cfg.Text or "Button"
                    callback = cfg.Callback
                end

                local BtnFrame = MakeRow(ElementScroll, 34)
                MakeLabel(BtnFrame, text, 120)

                local Button = Create("TextButton", {
                    Size = UDim2.new(0, 105, 0, 24),
                    Position = UDim2.new(1, -115, 0.5, -12),
                    BackgroundColor3 = Theme.ElementAlt,
                    AutoButtonColor = false,
                    Font = Library.FontBold,
                    Text = "Click",
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    ZIndex = 3,
                    Parent = BtnFrame,
                })
                Corner(Button, 5)
                Stroke(Button, Library.ThemeColor, 1, 0.35)

                Button.MouseEnter:Connect(function()
                    Tween(Button, 0.15, {BackgroundColor3 = Library.ThemeColor, TextColor3 = ContrastText(Library.ThemeColor)})
                end)
                Button.MouseLeave:Connect(function()
                    Tween(Button, 0.15, {BackgroundColor3 = Theme.ElementAlt, TextColor3 = Theme.Text})
                end)

                Button.MouseButton1Click:Connect(function()
                    ClickFlash(Button)
                    if callback then callback() end
                end)
            end

            return SubObj
        end

        table.insert(sideTabs, TabObj)
        firstSideTab = false
        return TabObj
    end

    -- Beim Start still laden (nur wenn ein Config-Name vorab gesetzt wurde)
    Library.LoadSettings(true)

    -- ==========================================
    -- LADEBILDSCHIRM
    -- ==========================================
    local LoadColor = Library.ThemeColor
    local rotConn
    local StrokeGradLoad

    local function OpenMenuNow()
        MainFrame.Visible = true
        isLoaded = true
        ToggleMainMenu(true)
    end

    -- Dauerhafte Rotation des Rahmen-Verlaufs (Hauptfenster + Ladebildschirm)
    rotConn = RunService.RenderStepped:Connect(function(dt)
        if not ScreenGui.Parent then
            rotConn:Disconnect()
            return
        end
        if ScreenGui.Enabled then
            StrokeGrad.Rotation = (StrokeGrad.Rotation + dt * 45) % 360
        end
        if StrokeGradLoad and StrokeGradLoad.Parent then
            StrokeGradLoad.Rotation = (StrokeGradLoad.Rotation + dt * 90) % 360
        end
    end)

    if Library.ShowLoadingScreen == false then
        OpenMenuNow()
        return Window
    end

    local LoadGui = Create("ScreenGui", {
        Name = "PyroXGUI_Loading",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        IgnoreGuiInset = true,
        Parent = parent,
    })

    -- Bildschirm abdunkeln (+ leichter Blur)
    local Backdrop = Create("Frame", {
        Name = "Backdrop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 1,
        Parent = LoadGui,
    })
    Create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0.12),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent = Backdrop,
    })
    local BACKDROP_T = 0.12
    Tween(Backdrop, 0.6, {BackgroundTransparency = BACKDROP_T})

    local Blur
    if Library.LoadingBlur ~= false then
        pcall(function()
            Blur = Instance.new("BlurEffect")
            Blur.Name = "PyroXLoadingBlur"
            Blur.Size = 0
            Blur.Parent = game:GetService("Lighting")
            TweenService:Create(Blur, TweenInfo.new(0.6), {Size = 16}):Play()
        end)
    end

    -- Karte (CanvasGroup, damit alles gemeinsam einblendet)
    local CARD_W, CARD_H = 540, 250
    local Card = Create("CanvasGroup", {
        Name = "Card",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, CARD_W, 0, CARD_H),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 2,
        Parent = LoadGui,
    })
    Corner(Card, 14)
    local CardStroke = Stroke(Card, Color3.new(1, 1, 1), 1.5, 0)
    StrokeGradLoad = Create("UIGradient", {Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, LoadColor),
        ColorSequenceKeypoint.new(0.5, Theme.Stroke),
        ColorSequenceKeypoint.new(1, LoadColor),
    }), Parent = CardStroke})

    local CardScale = Create("UIScale", {Parent = Card})
    local function FitCard()
        local vp = LoadGui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then
            vp = Vector2.new(1280, 720)
        end
        CardScale.Scale = math.clamp(math.min((vp.X - 24) / CARD_W, (vp.Y - 24) / CARD_H), 0.45, 1.15)
    end
    FitCard()
    LoadGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitCard)

    -- Hintergrund-Glow unten
    local CardGlow = Create("Frame", {
        Size = UDim2.new(1, 0, 0.6, 0),
        Position = UDim2.new(0, 0, 0.4, 0),
        BackgroundColor3 = LoadColor,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = Card,
    })
    Create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.8),
        }),
        Parent = CardGlow,
    })

    -- Logo mit pulsierendem Ring
    local LogoHolder = Create("Frame", {
        Size = UDim2.new(0, 84, 0, 84),
        Position = UDim2.new(0, 24, 0, 24),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Card,
    })
    Corner(LogoHolder, 18)
    local LogoRing = Stroke(LogoHolder, LoadColor, 2, 0.2)
    Create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 56, 0, 56),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1,
        Image = LOGO,
        ZIndex = 4,
        Parent = LogoHolder,
    })
    local pulseTween = TweenService:Create(LogoRing, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.9, Thickness = 4})
    pulseTween:Play()

    Create("TextLabel", {
        Size = UDim2.new(1, -150, 0, 28),
        Position = UDim2.new(0, 126, 0, 24),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = titleText or "GUI Library",
        TextColor3 = Theme.Text,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = Card,
    })

    local StatusLabel = Create("TextLabel", {
        Size = UDim2.new(1, -150, 0, 18),
        Position = UDim2.new(0, 126, 0, 54),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "Starting...",
        TextColor3 = Lighten(LoadColor, 0.45),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = Card,
    })

    -- Info-Chips (Spiel, Modus, Version, Executor) - kein Spielername
    local ChipRow = Create("Frame", {
        Size = UDim2.new(1, -150, 0, 22),
        Position = UDim2.new(0, 126, 0, 84),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = Card,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = ChipRow,
    })
    local function MakeChip(order, text, maxW)
        local chip = Create("TextLabel", {
            LayoutOrder = order,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = LoadColor,
            BackgroundTransparency = 0.82,
            Font = Library.FontBold,
            Text = text,
            TextColor3 = Lighten(LoadColor, 0.55),
            TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
            Parent = ChipRow,
        })
        Corner(chip, 11)
        Create("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = chip})
        if maxW then
            Create("UISizeConstraint", {MaxSize = Vector2.new(maxW, 22), Parent = chip})
        end
        return chip
    end
    local ChipMode = MakeChip(1, IsMobile and "MOBILE" or "PC")
    local ChipVer = MakeChip(2, Library.Version)
    local ChipGame = MakeChip(3, "Loading game...", 190)

    task.spawn(function()
        local name
        pcall(function()
            name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        end)
        if not name or name == "" then
            pcall(function() name = game.Name end)
        end
        if name and ChipGame.Parent then
            ChipGame.Text = tostring(name)
        end
    end)

    -- Tipp-Zeile
    local TipLabel = Create("TextLabel", {
        Size = UDim2.new(1, -48, 0, 34),
        Position = UDim2.new(0, 24, 0, 128),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 4,
        Parent = Card,
    })

    -- Fortschrittsbalken
    local BarBG = Create("Frame", {
        Size = UDim2.new(1, -48, 0, 8),
        Position = UDim2.new(0, 24, 0, 188),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Card,
    })
    Corner(BarBG, 4)
    local BarFill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = LoadColor,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = BarBG,
    })
    Corner(BarFill, 4)
    Shine(BarFill, 0)

    local InfoLabel = Create("TextLabel", {
        Size = UDim2.new(1, -120, 0, 16),
        Position = UDim2.new(0, 24, 0, 206),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "PyroX GUI " .. Library.Version,
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = Card,
    })
    local Percent = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.new(0, 80, 0, 16),
        Position = UDim2.new(1, -24, 0, 206),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = "0%",
        TextColor3 = Lighten(LoadColor, 0.45),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4,
        Parent = Card,
    })
    BarFill:GetPropertyChangedSignal("Size"):Connect(function()
        Percent.Text = tostring(math.floor(BarFill.Size.X.Scale * 100)) .. "%"
    end)

    -- Ladesound
    local LoadSound
    if Library.LoadingSound ~= false then
        task.spawn(function()
            pcall(function()
                local snd = Instance.new("Sound")
                snd.Name = "PyroXLoadingSound"
                snd.SoundId = Library.LoadingSoundId or "rbxassetid://107366908379453"
                snd.Volume = Library.LoadingSoundVolume or 0.6
                snd.Looped = false
                snd.Parent = LoadGui
                LoadSound = snd
                if not snd.IsLoaded then
                    local t0 = os.clock()
                    repeat task.wait() until snd.IsLoaded or os.clock() - t0 > 1.5
                end
                snd:Play()
            end)
        end)
    end

    TweenService:Create(Card, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()

    local function keyName()
        local k = Library.Flags[menuKeyFlag]
        return (typeof(k) == "EnumItem" and k ~= Enum.KeyCode.None) and k.Name or "RightShift"
    end
    local tips
    if IsMobile then
        tips = {
            "Tap the round button at the top to open or close the menu.",
            "Drag the round button to move it wherever you like.",
            "Set a key in the menu to get a movable button on your screen.",
            "Your settings can be saved and loaded in the Settings tab.",
            "Almost there...",
        }
    else
        tips = {
            "Press [" .. keyName() .. "] to show or hide the menu.",
            "Drag the top bar to move the window.",
            "Hold right mouse button to move the camera while the menu is open.",
            "Your settings can be saved and loaded in the Settings tab.",
            "Almost there...",
        }
    end

    local stages = {
        {"Initializing...", 0.14, 0.55},
        {"Loading modules...", 0.38, 0.8},
        {"Building interface...", 0.66, 0.9},
        {"Applying settings...", 0.88, 0.7},
        {"Finalizing...", 1, 0.6},
    }

    task.spawn(function()
        for i, st in ipairs(stages) do
            StatusLabel.Text = st[1]
            TipLabel.TextTransparency = 1
            TipLabel.Text = tips[i] or ""
            TweenService:Create(TipLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
            if i == 5 then
                local tabsN = #sideTabs
                local featN = #Library.ElementUpdaters
                InfoLabel.Text = tabsN .. " tabs  ·  " .. featN .. " features  ·  PyroX GUI " .. Library.Version
                pcall(function()
                    local exec = identifyexecutor()
                    if exec then
                        InfoLabel.Text = InfoLabel.Text .. "  ·  " .. tostring(exec)
                    end
                end)
            end
            Tween(BarFill, st[3], {Size = UDim2.new(st[2], 0, 1, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            task.wait(st[3] + 0.05)
        end
        Percent.Text = "100%"
        StatusLabel.Text = "Ready!"
        task.wait(0.45)

        -- Ausblenden
        if LoadSound then
            pcall(function()
                TweenService:Create(LoadSound, TweenInfo.new(0.5), {Volume = 0}):Play()
            end)
        end
        pcall(function() pulseTween:Cancel() end)
        TweenService:Create(Card, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1}):Play()
        TweenService:Create(Backdrop, TweenInfo.new(0.55), {BackgroundTransparency = 1}):Play()
        if Blur then
            pcall(function() TweenService:Create(Blur, TweenInfo.new(0.5), {Size = 0}):Play() end)
        end
        task.wait(0.4)
        OpenMenuNow()
        task.wait(0.2)
        pcall(function() if Blur then Blur:Destroy() end end)
        pcall(function() if LoadSound then LoadSound:Stop() end end)
        LoadGui:Destroy()
        StrokeGradLoad = nil
    end)

    return Window
end

return Library
