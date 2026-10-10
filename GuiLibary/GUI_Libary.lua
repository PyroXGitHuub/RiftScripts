--[[
    PyroX GUI Library  ·  v3.1.0  (Remake)
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
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local success, parent = pcall(function()
    return CoreGui
end)
if not success or not parent then
    parent = PlayerGui
end

for _, oldName in ipairs({"SketchGUILibrary", "SketchGUILibrary_Mobile"}) do
    local old = parent:FindFirstChild(oldName)
    if old then
        old:Destroy()
    end
end

local Library = {}
Library.Version = "v3.1.0"
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
    if Library.MobileMode ~= nil then
        return Library.MobileMode == true
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
    local MAIN_BG = 0.1

    local Window = {}

    local ScreenGui = Create("ScreenGui", {
        Name = "SketchGUILibrary",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parent,
    })

    -- Skalierung (Mobile / kleine Bildschirme)
    local function ComputeScale()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        if IsMobile then
            return math.clamp(math.min((vp.X - 24) / 750, (vp.Y - 80) / 480), 0.35, 1)
        end
        return math.clamp(math.min((vp.X - 40) / 750, (vp.Y - 40) / 480), 0.5, 1)
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
        Size = UDim2.new(0, 750, 0, 480),
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
        Size = UDim2.new(0, 210, 0, 480),
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
        Position = UDim2.new(1, IsMobile and -50 or -12, 0.5, 0),
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
    if IsMobile then
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
        Size = UDim2.new(0, 140, 1, -58),
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
        Size = UDim2.new(1, -12, 1, -52),
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
        Size = UDim2.new(1, -164, 1, -58),
        Position = UDim2.new(0, 156, 0, 50),
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

    SettLabel("MENU TOGGLE KEY", 230)

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
    local function ToggleMainMenu(isOpen)
        menuOpen = isOpen
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        if MobileStroke then
            Tween(MobileStroke, 0.25, {Color = isOpen and Library.ThemeColor or Theme.Stroke})
            Tween(MobileIcon, 0.4, {Rotation = isOpen and 0 or -90}, Enum.EasingStyle.Back)
        end
        if menuOpen then
            ScreenGui.Enabled = true
            MainFrame.Size = UDim2.new(0, 700, 0, 440)
            MainFrame.BackgroundTransparency = 1
            TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, 750, 0, 480), BackgroundTransparency = MAIN_BG}):Play()
            if Mascot then
                Mascot.ImageTransparency = 1
                TweenService:Create(Mascot, tweenInfo, {ImageTransparency = Library.BackgroundImageTransparency}):Play()
            end
            if DimOverlay.Visible then
                TweenService:Create(DimOverlay, tweenInfo, {BackgroundTransparency = 0.6}):Play()
            end
        else
            CloseAllPopups()
            local tw1 = TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, 700, 0, 440), BackgroundTransparency = 1})
            local tw2 = TweenService:Create(DimOverlay, tweenInfo, {BackgroundTransparency = 1})
            tw1:Play()
            tw2:Play()
            if Mascot then
                TweenService:Create(Mascot, tweenInfo, {ImageTransparency = 1}):Play()
            end
            tw1.Completed:Connect(function()
                if not menuOpen then
                    ScreenGui.Enabled = false
                    MainFrame.Size = UDim2.new(0, 750, 0, 480)
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
            end
        elseif not gameProcessed then
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
        end
    end)

    local sideTabs = {}
    local firstSideTab = true

    SettingsButton.MouseButton1Click:Connect(function()
        CloseAllPopups()
        for _, t in pairs(sideTabs) do
            SetTabVisual(t.Button, false)
            t.HeaderBar.Visible = false
            for _, sub in pairs(t.SubTabs) do
                SetTabVisual(sub.Button, false)
                sub.Container.Visible = false
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
        local tw = TweenService:Create(FilterPanel, tweenInfo, {BackgroundTransparency = 1, Size = UDim2.new(0, 190, 0, 460)})
        tw:Play()
        tw.Completed:Wait()
        FilterPanel.Visible = false
        FilterPanel.BackgroundTransparency = 0.1
        FilterPanel.Size = UDim2.new(0, 210, 0, 480)
    end
    table.insert(openPopups, CloseFilter)

    local function ToggleFilterPanel()
        local targetState = not filterOpen
        CloseAllPopups()
        if targetState then
            filterOpen = true
            FilterPanel.Visible = true
            FilterPanel.BackgroundTransparency = 1
            FilterPanel.Size = UDim2.new(0, 190, 0, 460)
            local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            TweenService:Create(FilterPanel, tweenInfo, {BackgroundTransparency = 0.1, Size = UDim2.new(0, 210, 0, 480)}):Play()
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
            Size = UDim2.new(1, -2, 0, 32),
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

        local SubTabHeaderBar = Create("ScrollingFrame", {
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
                for _, sub in pairs(t.SubTabs) do
                    SetTabVisual(sub.Button, false)
                    sub.Container.Visible = false
                end
            end

            SetTabVisual(SideButton, true)
            SubTabHeaderBar.Visible = true
            if t_first_sub then
                SetTabVisual(t_first_sub.Button, true)
                if t_first_sub.Container then
                    ShowContainer(t_first_sub.Container)
                end
            end
        end)

        TabObj.Button = SideButton
        TabObj.HeaderBar = SubTabHeaderBar
        TabObj.SubTabs = {}

        function TabObj:AddSubTab(subTabName)
            local SubObj = {}

            local textW = TextService:GetTextSize(subTabName, 12, Library.FontBold, Vector2.new(1000, 30)).X
            local SubButton = Create("TextButton", {
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

            local ElementScroll = Create("ScrollingFrame", {
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

            local ElementLayout = Create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = ElementScroll,
            })
            ElementLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                ElementScroll.CanvasSize = UDim2.new(0, 0, 0, ElementLayout.AbsoluteContentSize.Y + 12)
            end)

            SubButton.MouseButton1Click:Connect(function()
                CloseAllPopups()
                for _, s in pairs(TabObj.SubTabs) do
                    SetTabVisual(s.Button, false)
                    s.Container.Visible = false
                end
                SetTabVisual(SubButton, true)
                ShowContainer(ElementScroll)
            end)

            SubObj.Button = SubButton
            SubObj.Container = ElementScroll
            table.insert(TabObj.SubTabs, SubObj)

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

                local binding = false
                KeyButton.MouseButton1Click:Connect(function()
                    binding = true
                    KeyButton.Text = "..."
                end)

                ResetButton.MouseButton1Click:Connect(function()
                    ClickFlash(ResetButton)
                    binding = false
                    Library.Flags[flag] = Enum.KeyCode.None
                    KeyButton.Text = "None"
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
                            if callback then callback(keyValue) end
                        end
                    elseif not gameProcessed and Library.Flags[flag] ~= Enum.KeyCode.None then
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

                local function toggleAction()
                    Library.Flags[flagToggle] = not Library.Flags[flagToggle]
                    SetSwitch(Switch, Knob, Library.Flags[flagToggle])
                    ShowPopup(text .. " is now " .. (Library.Flags[flagToggle] and "ON" or "OFF"))
                    if callback then callback(Library.Flags[flagToggle]) end
                end

                Switch.MouseButton1Click:Connect(toggleAction)

                local binding = false
                KeyBtn.MouseButton1Click:Connect(function()
                    binding = true
                    KeyBtn.Text = "..."
                end)

                ResetBtn.MouseButton1Click:Connect(function()
                    ClickFlash(ResetBtn)
                    binding = false
                    Library.Flags[flagKey] = Enum.KeyCode.None
                    KeyBtn.Text = "None"
                end)

                UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if binding then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            Library.Flags[flagKey] = input.KeyCode
                            KeyBtn.Text = input.KeyCode.Name
                            binding = false
                        end
                    elseif not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and Library.Flags[flagKey] ~= Enum.KeyCode.None and input.KeyCode == Library.Flags[flagKey] then
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
    -- Feste Logo-Farbe für den Ladebildschirm (unabhängig von der Theme-Farbe)
    local LoadColor = Color3.fromRGB(168, 85, 247)
    -- ==========================================
    local LoadingFrame = Create("Frame", {
        Name = "Loading",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 400, 0, 150),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 9999,
        Parent = ScreenGui,
    })
    Corner(LoadingFrame, 12)
    local LoadStroke = Stroke(LoadingFrame, Color3.new(1, 1, 1), 1.5, 0)
    local LoadGrad = Create("UIGradient", {Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, LoadColor),
        ColorSequenceKeypoint.new(0.5, Theme.Stroke),
        ColorSequenceKeypoint.new(1, LoadColor),
    }), Parent = LoadStroke})
    AddScale(LoadingFrame)

    local LoadMascot = Create("ImageLabel", {
        Size = UDim2.new(0, 118, 0, 118),
        Position = UDim2.new(0, 16, 0.5, -59),
        BackgroundColor3 = Theme.Panel,
        Image = LOGO,
        ScaleType = Enum.ScaleType.Crop,
        Parent = LoadingFrame,
    })
    Corner(LoadMascot, 10)
    Stroke(LoadMascot, LoadColor, 1.5, 0.2)

    Create("TextLabel", {
        Size = UDim2.new(1, -166, 0, 24),
        Position = UDim2.new(0, 150, 0, 30),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = titleText or "GUI Library",
        TextColor3 = Theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = LoadingFrame,
    })

    local SubTextLoad = Create("TextLabel", {
        Size = UDim2.new(1, -166, 0, 18),
        Position = UDim2.new(0, 150, 0, 56),
        BackgroundTransparency = 1,
        Font = Library.Font,
        Text = "Loading Interface...",
        TextColor3 = Theme.SubText,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = LoadingFrame,
    })

    local BarBG = Create("Frame", {
        Size = UDim2.new(1, -166, 0, 6),
        Position = UDim2.new(0, 150, 0, 98),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        Parent = LoadingFrame,
    })
    Corner(BarBG, 3)

    local BarFill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = LoadColor,
        BorderSizePixel = 0,
        Parent = BarBG,
    })
    Corner(BarFill, 3)
    Shine(BarFill, 0)

    local Percent = Create("TextLabel", {
        Size = UDim2.new(1, -166, 0, 16),
        Position = UDim2.new(0, 150, 0, 110),
        BackgroundTransparency = 1,
        Font = Library.FontBold,
        Text = "0%",
        TextColor3 = Lighten(LoadColor, 0.4),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = LoadingFrame,
    })

    -- Rotierender Rahmen-Verlauf
    local rotConn
    rotConn = RunService.RenderStepped:Connect(function(dt)
        if not ScreenGui.Parent then
            rotConn:Disconnect()
            return
        end
        if ScreenGui.Enabled then
            StrokeGrad.Rotation = (StrokeGrad.Rotation + dt * 45) % 360
            if LoadGrad.Parent then
                LoadGrad.Rotation = StrokeGrad.Rotation
            end
        end
    end)

    task.spawn(function()
        local loadTween = TweenService:Create(BarFill, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)})
        loadTween:Play()
        while loadTween.PlaybackState == Enum.PlaybackState.Playing or loadTween.PlaybackState == Enum.PlaybackState.Begin do
            Percent.Text = tostring(math.floor(BarFill.Size.X.Scale * 100)) .. "%"
            task.wait()
        end
        Percent.Text = "100%"
        SubTextLoad.Text = "Finished!"
        task.wait(0.5)

        -- Fade Out
        FadeOut(LoadingFrame, 0.5)
        task.wait(0.5)
        LoadingFrame:Destroy()

        MainFrame.Visible = true
        isLoaded = true
        ToggleMainMenu(true)
    end)

    return Window
end

return Library
