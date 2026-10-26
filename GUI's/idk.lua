-- ==========================================
-- ADMIN DETECTOR  ·  PyroX Style
-- Staff = jede Gruppenrolle ÜBER der Standard-Rolle (niedrigste Member-Rolle) der Spiel-Gruppe
-- Menü: Pfeil-Button oben rechts -> Panel slidet von oben herunter -> Pfeil unten -> slidet wieder hoch
-- ==========================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local GroupService = game:GetService("GroupService")
local RunService = game:GetService("RunService")

-- Sicherstellen, dass LocalPlayer existiert
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

-- Hier kannst du zusätzliche Gruppen-IDs eintragen, die immer überwacht werden sollen
local customGroupIds = {

}

-- Optional: Mindest-Rank für Staff (nil = alles über der Standard-Rolle). Z.B. 20 blendet Rollen wie Tester/Influencer aus
local minStaffRank = nil

-- ===== Theme (PyroX) =====
local Theme = {
    Background = Color3.fromRGB(10, 10, 14),
    Panel      = Color3.fromRGB(16, 16, 22),
    Element    = Color3.fromRGB(20, 20, 28),
    ElementAlt = Color3.fromRGB(30, 30, 40),
    Hover      = Color3.fromRGB(42, 42, 56),
    Stroke     = Color3.fromRGB(48, 48, 62),
    Text       = Color3.fromRGB(240, 240, 248),
    SubText    = Color3.fromRGB(165, 165, 182),
}
local Accent = Color3.fromRGB(168, 85, 247)
local Warn = Color3.fromRGB(255, 90, 105)
local Good = Color3.fromRGB(80, 220, 140)
local FONT = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold
local LOGO = "rbxassetid://75876733222469"

local function Create(class, props)
    local inst = Instance.new(class)
    local p
    for k, v in pairs(props or {}) do
        if k == "Parent" then p = v else inst[k] = v end
    end
    if p then inst.Parent = p end
    return inst
end
local function Corner(o, r) return Create("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = o }) end
local function Stroke(o, c, t, tr)
    return Create("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
local function Tween(o, t, props, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function AddHover(btn, base, hover)
    btn.MouseEnter:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = hover }) end)
    btn.MouseLeave:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = base }) end)
end

-- ===== State =====
local activeCards = {}
local activeVisuals = {}
local trackedGroups = {}       -- { {id=, name=, baseRank=, baseName=} }
local staffList = {}           -- [userId] = {player, role, rank, group, groupId}
local visitedServers = { [game.JobId] = true }

local env = (getgenv and getgenv()) or _G
local httpRequest = (env.syn and env.syn.request)
    or (env.http and env.http.request)
    or env.http_request
    or env.request
    or (typeof(request) == "function" and request)

-- Hilfsfunktion: Verhindert, dass Roblox-Yield-Funktionen (wie GetGroupInfoAsync) das Script unendlich blockieren
local function callWithTimeout(fn, timeout)
    local done = false
    local success, result = false, nil

    task.spawn(function()
        local ok, res = pcall(fn)
        if not done then
            done = true
            success = ok
            result = res
        end
    end)

    local start = os.clock()
    while not done and (os.clock() - start) < (timeout or 5) do
        task.wait(0.05)
    end
    done = true
    return success, result
end

local function playAlertSound()
    task.spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://12221967"
        sound.Volume = 5
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end)
end

local parentContainer = CoreGui
if gethui then parentContainer = gethui() end
pcall(function()
    local old = parentContainer:FindFirstChild("AdminNotificatorHUD")
    if old then old:Destroy() end
end)

local screenGui = Create("ScreenGui", {
    Name = "AdminNotificatorHUD", ResetOnSpawn = false, DisplayOrder = 100, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentContainer,
})

local container = Create("Frame", {
    Name = "NotificationContainer", Size = UDim2.new(0, 400, 1, -20), Position = UDim2.new(0.5, -200, 0, 15),
    BackgroundTransparency = 1, Parent = screenGui,
})
Create("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = container,
})

-- ===== Server Hop =====
local function serverHop()
    local placeId = game.PlaceId
    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(placeId))
    if httpRequest then
        local success, response = pcall(function() return httpRequest({ Url = url, Method = "GET" }) end)
        if success and response and response.Body then
            local ok, decoded = pcall(function() return HttpService:JSONDecode(response.Body) end)
            if ok and decoded and decoded.data then
                for _, server in ipairs(decoded.data) do
                    if server.id ~= game.JobId and not visitedServers[server.id] and server.playing < server.maxPlayers then
                        visitedServers[server.id] = true
                        TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
                        return
                    end
                end
            end
        end
    end
    TeleportService:Teleport(placeId, LocalPlayer)
end

local function getUserHeadshot(userId)
    local success, content = callWithTimeout(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end, 4)
    if success and content then return content end
    return "rbxassetid://0"
end

-- ===== Nametag =====
local function applyVisuals(player, roleText, duration)
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        if not character then return end
        if activeVisuals[player.UserId] then activeVisuals[player.UserId]() end
        for _, child in ipairs(character:GetChildren()) do
            if child.Name == "AdminBillboard" then child:Destroy() end
        end

        local head = character:WaitForChild("Head", 5)
        local billboard = Create("BillboardGui", {
            Name = "AdminBillboard", Size = UDim2.new(0, 200, 0, 35), StudsOffset = Vector3.new(0, 3.5, 0),
            AlwaysOnTop = true, Adornee = head or character,
        })
        local textLabel = Create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "[" .. string.upper(roleText) .. "]",
            TextColor3 = Warn, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0,
            Font = FONTB, TextSize = 16, Parent = billboard,
        })
        billboard.Parent = character

        local isBlinking = true
        task.spawn(function()
            while isBlinking and billboard and billboard.Parent do
                textLabel.TextTransparency = 0
                task.wait(0.3)
                textLabel.TextTransparency = 0.3
                task.wait(0.3)
            end
        end)
        local cleanup = function()
            isBlinking = false
            if billboard and billboard.Parent then billboard:Destroy() end
        end
        if duration then task.delay(duration, cleanup) end
        activeVisuals[player.UserId] = cleanup
    end)
end

-- ===== Benachrichtigung (Karte) =====
local function createNotification(data)
    local targetHeight = 112

    local wrapper = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = container,
    })
    local card = Create("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, targetHeight), Position = UDim2.new(0, 0, 0, -targetHeight),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, GroupTransparency = 1, Parent = wrapper,
    })
    Corner(card, 10)
    Stroke(card, Theme.Stroke, 1, 0.1)
    local bar = Create("Frame", {
        Size = UDim2.new(0, 3, 1, -20), Position = UDim2.new(0, 8, 0, 10), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = card,
    })
    Corner(bar, 2)

    local avatar = Create("ImageLabel", {
        Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 20, 0, 12), BackgroundColor3 = Theme.Element,
        Image = data.avatarUrl, Parent = card,
    })
    Corner(avatar, 28)
    Stroke(avatar, Accent, 1.5, 0.2)

    Create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 16), Position = UDim2.new(0, 88, 0, 10), BackgroundTransparency = 1, Font = FONTB,
        Text = data.headerText or "STAFF DETECTED", TextColor3 = Warn, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 88, 0, 26), BackgroundTransparency = 1, Font = FONTB,
        Text = string.format("%s (@%s)", data.displayName, data.username), TextColor3 = Theme.Text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 28), Position = UDim2.new(0, 88, 0, 44), BackgroundTransparency = 1, Font = FONT,
        Text = string.format("Role: %s\nGroup: %s", data.role, data.group), TextColor3 = Theme.SubText, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
    })

    local stayBtn = Create("TextButton", {
        Size = UDim2.new(0.5, -16, 0, 24), Position = UDim2.new(0, 12, 0, 78), BackgroundColor3 = Theme.ElementAlt,
        AutoButtonColor = false, Font = FONTB, Text = "Stay", TextColor3 = Theme.Text, TextSize = 12, Parent = card,
    })
    Corner(stayBtn, 6)
    Stroke(stayBtn, Theme.Stroke, 1, 0.2)
    AddHover(stayBtn, Theme.ElementAlt, Theme.Hover)

    local hopBtn = Create("TextButton", {
        Size = UDim2.new(0.5, -16, 0, 24), Position = UDim2.new(0.5, 4, 0, 78), BackgroundColor3 = Accent,
        AutoButtonColor = false, Font = FONTB, Text = "Server Hop", TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Parent = card,
    })
    Corner(hopBtn, 6)
    AddHover(hopBtn, Accent, Accent:Lerp(Color3.new(1, 1, 1), 0.15))

    local line = Create("Frame", {
        Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 1, -4), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = card,
    })
    Corner(line, 1)

    Tween(wrapper, 0.45, { Size = UDim2.new(1, 0, 0, targetHeight) }, Enum.EasingStyle.Quart)
    Tween(card, 0.45, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Quart)
    local lineTween = TweenService:Create(line, TweenInfo.new(10, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
    lineTween:Play()

    local isClosing = false
    local function removeCard()
        if isClosing then return end
        isClosing = true
        Tween(card, 0.4, { Position = UDim2.new(0, 0, 0, targetHeight), GroupTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        local t = Tween(wrapper, 0.4, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        t.Completed:Connect(function() wrapper:Destroy() end)
    end
    stayBtn.MouseButton1Click:Connect(removeCard)
    hopBtn.MouseButton1Click:Connect(function()
        hopBtn.Text = "Teleporting..."
        serverHop()
    end)
    lineTween.Completed:Connect(removeCard)
    return removeCard
end

-- ==========================================
-- MENÜ (Pfeil oben rechts -> Panel slidet herunter)
-- ==========================================
local PANEL_W, PANEL_H = 350, 400
local panelOpen = false
local panelBusy = false

local Panel = Create("Frame", {
    Name = "StaffPanel", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
    Position = UDim2.new(1, -16, 0, 1 - PANEL_H), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.06,
    BorderSizePixel = 0, Parent = screenGui,
})
Corner(Panel, 10)
local PanelScale = Create("UIScale", { Scale = 1, Parent = Panel })
local PanelStroke = Stroke(Panel, Color3.new(1, 1, 1), 1.5, 0)
local StrokeGrad = Create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Accent), ColorSequenceKeypoint.new(0.5, Theme.Stroke), ColorSequenceKeypoint.new(1, Accent),
    }), Parent = PanelStroke,
})
local Glow = Create("Frame", {
    Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = Panel,
})
Corner(Glow, 10)
Create("UIGradient", {
    Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.85) }), Parent = Glow,
})

-- Header
Create("ImageLabel", {
    Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 12, 0, 14), BackgroundTransparency = 1, Image = LOGO, Parent = Panel,
})
Create("TextLabel", {
    Size = UDim2.new(1, -120, 0, 22), Position = UDim2.new(0, 44, 0, 14), BackgroundTransparency = 1, Font = FONTB,
    Text = "Admin Detector", TextColor3 = Color3.new(1, 1, 1), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = Panel,
})
Create("UIGradient", {
    Color = ColorSequence.new(Color3.new(1, 1, 1), Accent:Lerp(Color3.new(1, 1, 1), 0.35)), Parent = Panel:FindFirstChild("TextLabel"),
})
local CountBadge = Create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X,
    Position = UDim2.new(1, -12, 0, 15), BackgroundColor3 = Accent, BackgroundTransparency = 0.78, Font = FONTB,
    Text = "0 Staff", TextColor3 = Accent:Lerp(Color3.new(1, 1, 1), 0.55), TextSize = 11, Parent = Panel,
})
Corner(CountBadge, 10)
Create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = CountBadge })

local StatusDot = Create("Frame", {
    Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 14, 0, 42), BackgroundColor3 = Good, BorderSizePixel = 0, Parent = Panel,
})
Corner(StatusDot, 4)
local DotRing = Create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Good, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = StatusDot,
})
Corner(DotRing, 8)
task.spawn(function()
    while Panel.Parent do
        DotRing.Size = UDim2.new(1, 0, 1, 0)
        DotRing.BackgroundTransparency = 0.5
        Tween(DotRing, 1.2, { Size = UDim2.new(2.6, 0, 2.6, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
        task.wait(1.4)
    end
end)
local GroupInfoLbl = Create("TextLabel", {
    Size = UDim2.new(1, -36, 0, 14), Position = UDim2.new(0, 28, 0, 39), BackgroundTransparency = 1, Font = FONT,
    Text = "Loading group...", TextColor3 = Theme.SubText, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, Parent = Panel,
})
local Sep = Create("Frame", {
    Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 56), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = Panel,
})
Create("UIGradient", {
    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) }), Parent = Sep,
})

-- Liste
local ListScroll = Create("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -112), Position = UDim2.new(0, 10, 0, 64), BackgroundTransparency = 1, BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 3, ScrollBarImageColor3 = Accent, Parent = Panel,
})
local ListLayout = Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = ListScroll })
ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ListScroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 4)
end)
local EmptyBox = Create("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, Parent = ListScroll })
local EmptyCircle = Create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0.5, 0, 0, 28),
    BackgroundColor3 = Good, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = EmptyBox,
})
Corner(EmptyCircle, 28)
Stroke(EmptyCircle, Good, 1.5, 0.3)
do
    local c1 = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 10, 0, 3.5), Position = UDim2.new(0.5, -6, 0.5, 3),
        BackgroundColor3 = Good, BorderSizePixel = 0, Rotation = 45, Parent = EmptyCircle,
    })
    Corner(c1, 2)
    local c2 = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 20, 0, 3.5), Position = UDim2.new(0.5, 4, 0.5, 0),
        BackgroundColor3 = Good, BorderSizePixel = 0, Rotation = -50, Parent = EmptyCircle,
    })
    Corner(c2, 2)
end
Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 94), BackgroundTransparency = 1, Font = FONTB,
    Text = "Server is clear", TextColor3 = Theme.Text, TextSize = 14, Parent = EmptyBox,
})
Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 114), BackgroundTransparency = 1, Font = FONT,
    Text = "No staff members in this server", TextColor3 = Theme.SubText, TextSize = 12, Parent = EmptyBox,
})

-- Server Hop Button im Panel
local PanelHop = Create("TextButton", {
    Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 1, -40), BackgroundColor3 = Theme.ElementAlt,
    AutoButtonColor = false, Font = FONTB, Text = "Server Hop", TextColor3 = Theme.Text, TextSize = 12, Parent = Panel,
})
Corner(PanelHop, 6)
Stroke(PanelHop, Accent, 1, 0.45)
AddHover(PanelHop, Theme.ElementAlt, Theme.Hover)
PanelHop.MouseButton1Click:Connect(function()
    PanelHop.Text = "Teleporting..."
    serverHop()
end)

-- Pfeil-Tabs
local function makeChevron(parent, up)
    local holder = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 16, 0, 10), Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1, ZIndex = 6, Parent = parent,
    })
    local parts = {}
    for i = 1, 2 do
        local f = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 10, 0, 2.5), BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0, ZIndex = 6, Parent = holder,
        })
        Corner(f, 2)
        local sign = (i == 1) and 1 or -1
        f.Position = UDim2.new(0.5, -sign * 3.2, 0.5, 0)
        f.Rotation = (up and -sign or sign) * 38
        parts[i] = f
    end
    return holder, parts
end

local function makeTab(parent, up)
    local b = Create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 64, 0, 28), BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.02, AutoButtonColor = false, Text = "", Parent = parent,
    })
    Corner(b, 10)
    local st = Stroke(b, Accent, 1.5, 0.35)
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 175, 215)), Rotation = 90, Parent = b,
    })
    local holder, parts = makeChevron(b, up)
    b.MouseEnter:Connect(function()
        Tween(b, 0.2, { BackgroundColor3 = Accent:Lerp(Theme.Panel, 0.6) })
        Tween(st, 0.2, { Transparency = 0, Thickness = 2 })
        for _, f in ipairs(parts) do Tween(f, 0.2, { BackgroundColor3 = Color3.new(1, 1, 1) }) end
    end)
    b.MouseLeave:Connect(function()
        Tween(b, 0.2, { BackgroundColor3 = Theme.Panel })
        Tween(st, 0.2, { Transparency = 0.35, Thickness = 1.5 })
        for _, f in ipairs(parts) do Tween(f, 0.2, { BackgroundColor3 = Theme.Text }) end
    end)
    return b, holder
end

local Tab, TabChevron = makeTab(Panel, false)
Tab.Size = UDim2.new(0, 72, 0, 30)
Tab.Position = UDim2.new(0.5, 0, 1, 3)
Tab.ZIndex = 5

local OPEN_Y = 40
local CLOSED_Y = 1 - PANEL_H

local function setPanel(open)
    if panelBusy or open == panelOpen then return end
    panelBusy = true
    panelOpen = open
    if open then
        PanelScale.Scale = 0.94
        Tween(PanelScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
        Tween(TabChevron, 0.5, { Rotation = 180 }, Enum.EasingStyle.Back)
        local t = Tween(Panel, 0.65, { Position = UDim2.new(1, -16, 0, OPEN_Y) }, Enum.EasingStyle.Back)
        t.Completed:Connect(function() panelBusy = false end)
    else
        Tween(TabChevron, 0.5, { Rotation = 0 }, Enum.EasingStyle.Back)
        Tween(PanelScale, 0.45, { Scale = 0.96 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        local t = Tween(Panel, 0.5, { Position = UDim2.new(1, -16, 0, CLOSED_Y) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            PanelScale.Scale = 1
            panelBusy = false
        end)
    end
end

Tab.MouseButton1Click:Connect(function() setPanel(not panelOpen) end)

RunService.RenderStepped:Connect(function(dt)
    if panelOpen then
        StrokeGrad.Rotation = (StrokeGrad.Rotation + 40 * dt) % 360
    end
end)

-- ===== Staff-Liste pflegen =====
local rows = {}

local function refreshCount()
    local n = 0
    for _ in pairs(staffList) do n = n + 1 end
    CountBadge.Text = n .. " Staff"
    EmptyBox.Visible = (n == 0)
    local col = (n > 0) and Warn or Good
    Tween(CountBadge, 0.3, { BackgroundColor3 = col, TextColor3 = col:Lerp(Color3.new(1, 1, 1), 0.5) })
    Tween(StatusDot, 0.3, { BackgroundColor3 = col })
    Tween(DotRing, 0.3, { BackgroundColor3 = col })
end

local function addRow(info)
    local userId = info.player.UserId
    if rows[userId] then rows[userId]:Destroy() end

    local row = Create("CanvasGroup", {
        LayoutOrder = -info.rank, Size = UDim2.new(1, -6, 0, 54), BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, GroupTransparency = 1, Parent = ListScroll,
    })
    Corner(row, 8)
    local st = Stroke(row, Theme.Stroke, 1, 0.35)
    row.MouseEnter:Connect(function() Tween(st, 0.2, { Color = Accent, Transparency = 0.25 }) end)
    row.MouseLeave:Connect(function() Tween(st, 0.2, { Color = Theme.Stroke, Transparency = 0.35 }) end)

    local av = Create("ImageLabel", {
        Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0, 8, 0.5, -19), BackgroundColor3 = Theme.ElementAlt,
        Image = "rbxassetid://0", Parent = row,
    })
    Corner(av, 19)
    Stroke(av, Accent, 1.5, 0.3)
    task.spawn(function() av.Image = getUserHeadshot(userId) end)

    Create("TextLabel", {
        Size = UDim2.new(1, -140, 0, 18), Position = UDim2.new(0, 54, 0, 9), BackgroundTransparency = 1, Font = FONTB,
        Text = string.format("%s (@%s)", info.player.DisplayName, info.player.Name), TextColor3 = Theme.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -140, 0, 16), Position = UDim2.new(0, 54, 0, 28), BackgroundTransparency = 1, Font = FONT,
        Text = info.role .. "  ·  " .. info.group, TextColor3 = Theme.SubText, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    local chip = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = Accent, BackgroundTransparency = 0.78, Font = FONTB,
        Text = "Rank " .. info.rank, TextColor3 = Accent:Lerp(Color3.new(1, 1, 1), 0.55), TextSize = 11, Parent = row,
    })
    Corner(chip, 10)
    Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })

    row.Position = UDim2.new(0, 14, 0, 0)
    Tween(row, 0.45, { GroupTransparency = 0 })
    rows[userId] = row
end

local function removeRow(userId)
    local row = rows[userId]
    rows[userId] = nil
    if row then
        local t = Tween(row, 0.3, { GroupTransparency = 1 })
        t.Completed:Connect(function() row:Destroy() end)
    end
end

-- ===== Prüfung der Spieler (Rolle über der Standard-Rolle = Staff) =====
local function checkPlayer(player, isStartup)
    if player.UserId == LocalPlayer.UserId and not isStartup then return end

    task.spawn(function()
        local best = nil
        for _, g in ipairs(trackedGroups) do
            local ok, rank = callWithTimeout(function() return player:GetRankInGroup(g.id) end, 4)
            if ok and rank and rank > g.baseRank and rank >= (minStaffRank or 0) then
                local okRole, roleName = callWithTimeout(function() return player:GetRoleInGroup(g.id) end, 4)
                if not best or rank > best.rank then
                    best = { rank = rank, role = (okRole and roleName) or ("Rank " .. rank), group = g.name, groupId = g.id }
                end
            end
        end
        if not best or not player.Parent then return end

        best.player = player
        local isNew = staffList[player.UserId] == nil
        staffList[player.UserId] = best
        addRow(best)
        refreshCount()

        if isNew then
            playAlertSound()
            applyVisuals(player, best.role, isStartup and 10 or nil)
            if activeCards[player.UserId] then activeCards[player.UserId]() end
            activeCards[player.UserId] = createNotification({
                headerText = isStartup and "STAFF IN SERVER" or "STAFF JOINED",
                username = player.Name,
                displayName = player.DisplayName,
                role = best.role,
                group = best.group,
                avatarUrl = getUserHeadshot(player.UserId),
            })
        end
    end)
end

-- Web-API Fallback falls GroupService:GetGroupInfoAsync() hängt oder fehlschlägt
local function fetchGroupViaHttp(groupId)
    if not httpRequest then return nil end
    local info = { Name = "Group " .. groupId, Roles = {} }

    local ok1, res1 = pcall(function()
        return httpRequest({ Url = "https://groups.roblox.com/v1/groups/" .. tostring(groupId), Method = "GET" })
    end)
    if ok1 and res1 and res1.Body then
        local okDec, dec = pcall(function() return HttpService:JSONDecode(res1.Body) end)
        if okDec and dec and dec.name then
            info.Name = dec.name
        end
    end

    local ok2, res2 = pcall(function()
        return httpRequest({ Url = "https://groups.roblox.com/v1/groups/" .. tostring(groupId) .. "/roles", Method = "GET" })
    end)
    if ok2 and res2 and res2.Body then
        local okDec, dec = pcall(function() return HttpService:JSONDecode(res2.Body) end)
        if okDec and dec and dec.roles then
            for _, r in ipairs(dec.roles) do
                if r.rank and r.name then
                    table.insert(info.Roles, { Rank = r.rank, Name = r.name })
                end
            end
        end
    end

    if #info.Roles > 0 then
        return info
    end
    return nil
end

-- Gruppe laden: Mit Timeout & HTTP-Fallback
local function addGroup(groupId)
    if not groupId or groupId <= 0 then return end
    for _, g in ipairs(trackedGroups) do
        if g.id == groupId then return end
    end

    local entry = { id = groupId, name = "Group " .. groupId, baseRank = 1 }
    
    -- 1. Versuch: GroupService mit 5s Timeout
    local ok, info = callWithTimeout(function()
        return GroupService:GetGroupInfoAsync(groupId)
    end, 5)

    -- 2. Versuch (Fallback): Direkte Roblox Web-API, falls GroupService hängt/fehlschlägt
    if not ok or not info then
        info = fetchGroupViaHttp(groupId)
        ok = (info ~= nil)
    end

    if ok and info then
        entry.name = info.Name or entry.name
        local lowest
        for _, r in ipairs(info.Roles or {}) do
            if r.Rank > 0 and (not lowest or r.Rank < lowest.Rank) then
                lowest = r
            end
        end
        if lowest then
            entry.baseRank = lowest.Rank
            entry.baseName = lowest.Name
        end
    end

    table.insert(trackedGroups, entry)
end

local function updateGroupLabel()
    if #trackedGroups > 0 then
        local names = {}
        for _, g in ipairs(trackedGroups) do
            names[#names + 1] = g.name .. (g.baseName and (" (Member: " .. g.baseName .. ")") or "")
        end
        GroupInfoLbl.Text = table.concat(names, ", ")
    else
        if game.CreatorType == Enum.CreatorType.User then
            GroupInfoLbl.Text = "User-Game (Keine Spiel-Gruppe)"
        else
            GroupInfoLbl.Text = "Keine Gruppe gefunden (customGroupIds leer)"
        end
    end
end

-- ===== Hauptablauf =====
task.spawn(function()
    -- Warten bis das Spiel Basis-Daten geladen hat (max. 5 Sekunden)
    if not game:IsLoaded() then
        callWithTimeout(function() game.Loaded:Wait() end, 5)
    end

    -- Falls CreatorId noch 0 ist, kurz warten
    local waitStart = os.clock()
    while game.CreatorId == 0 and (os.clock() - waitStart) < 3 do
        task.wait(0.1)
    end

    if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
        GroupInfoLbl.Text = "Loading group (" .. tostring(game.CreatorId) .. ")..."
        addGroup(game.CreatorId)
    end

    for _, gid in ipairs(customGroupIds) do
        addGroup(gid)
    end

    -- UI sofort aktualisieren
    updateGroupLabel()
    refreshCount()

    playAlertSound()
    createNotification({
        headerText = "DETECTOR READY",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        role = "Script User",
        group = "Aktiv (" .. #trackedGroups .. " Gruppen)",
        avatarUrl = getUserHeadshot(LocalPlayer.UserId),
    })

    for _, player in ipairs(Players:GetPlayers()) do
        checkPlayer(player, true)
    end

    Players.PlayerAdded:Connect(function(player)
        task.wait(2)
        checkPlayer(player, false)
    end)

    Players.PlayerRemoving:Connect(function(player)
        local id = player.UserId
        if activeCards[id] then activeCards[id]() activeCards[id] = nil end
        if activeVisuals[id] then activeVisuals[id]() activeVisuals[id] = nil end
        if staffList[id] then
            staffList[id] = nil
            removeRow(id)
            refreshCount()
        end
    end)
end)
