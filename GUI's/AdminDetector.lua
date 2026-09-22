-- ===== ANIMATED AUTOMATIC GROUP-STAFF DETECTOR (OPTIMIZED & FIXED) =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Design Palette
local THEME = {
    Background = Color3.fromRGB(18, 18, 18),
    CardBG = Color3.fromRGB(24, 24, 24),
    CardTransparency = 0.20,
    AccentRed = Color3.fromRGB(220, 35, 45),
    Border = Color3.fromRGB(45, 45, 45),
    ButtonDark = Color3.fromRGB(30, 30, 30),
    TextMain = Color3.fromRGB(240, 240, 240),
    TextSub = Color3.fromRGB(160, 160, 160),
    FontBold = Enum.Font.SourceSansBold,
    FontRegular = Enum.Font.SourceSans
}

local targetKeywords = {
    "owner", "co-owner", "administrator", "admin", "developer", "dev", "moderator", "mod", "staff", "creator", "builder", "manager", 
    "helper", "Friend", "Staff", "Contributor", "Community Lead", "Studio Developer", "Owner", "Founder"
}

-- Hier kannst du zusätzliche Gruppen-IDs eintragen, die immer überwacht werden sollen
local customGroupIds = {
    
}

local activeCards = {}
local activeVisuals = {}
local trackedGroups = {}
local visitedServers = { [game.JobId] = true }

-- HTTP Request für Server Hop 
local env = (getgenv and getgenv()) or _G
local httpRequest = (env.syn and env.syn.request) 
    or (env.http and env.http.request) 
    or env.http_request 
    or env.request 
    or (typeof(request) == "function" and request)

local function playAlertSound()
    task.spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://12221967"
        sound.Volume = 5
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end)
end

local parentContainer = CoreGui
if gethui then parentContainer = gethui() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminNotificatorHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentContainer

local container = Instance.new("Frame")
container.Name = "NotificationContainer"
container.Size = UDim2.new(0, 400, 1, -20)
container.Position = UDim2.new(0.5, -200, 0, 15)
container.BackgroundTransparency = 1
container.Parent = screenGui

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = container
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 8)
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

-- ===== NAMETAG SYSTEM =====
local function applyVisuals(player, roleText, duration)
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        if not character then return end

        if activeVisuals[player.UserId] then
            activeVisuals[player.UserId]()
        end

        for _, child in ipairs(character:GetChildren()) do
            if child.Name == "AdminBillboard" then
                child:Destroy()
            end
        end

        local head = character:WaitForChild("Head", 5)
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "AdminBillboard"
        billboard.Size = UDim2.new(0, 200, 0, 35)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Adornee = head or character

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "[" .. string.upper(roleText) .. "]"
        textLabel.TextColor3 = THEME.AccentRed
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.TextStrokeTransparency = 0
        textLabel.Font = THEME.FontBold
        textLabel.TextSize = 16
        textLabel.Parent = billboard

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

        if duration then
            task.delay(duration, cleanup)
        end

        activeVisuals[player.UserId] = cleanup
    end)
end

-- ===== SERVER HOP =====
local function serverHop()
    local placeId = game.PlaceId
    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(placeId))
    
    if httpRequest then
        local success, response = pcall(function() return httpRequest({ Url = url, Method = "GET" }) end)
        if success and response and response.Body then
            local decoded = HttpService:JSONDecode(response.Body)
            if decoded and decoded.data then
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

-- ===== USER DETAILS =====
local function getUserHeadshot(userId)
    local success, content = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if success and content then return content end
    return "rbxassetid://0"
end

-- ===== NOTIFICATION UI =====
local function createNotification(data)
    local targetHeight = 145

    local wrapper = Instance.new("Frame")
    wrapper.Size = UDim2.new(1, 0, 0, 0)
    wrapper.BackgroundTransparency = 1
    wrapper.ClipsDescendants = true
    wrapper.Parent = container

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, targetHeight)
    card.BackgroundColor3 = THEME.CardBG
    card.BorderSizePixel = 0
    card.BackgroundTransparency = 1
    card.Position = UDim2.new(0, 0, 0, -targetHeight)
    card.Parent = wrapper

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = THEME.Border
    cardStroke.Thickness = 1
    cardStroke.Transparency = 1
    cardStroke.Parent = card

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, 70, 0, 70)
    avatarImg.Position = UDim2.new(0, 10, 0, 10)
    avatarImg.BackgroundColor3 = THEME.Background
    avatarImg.BackgroundTransparency = 1
    avatarImg.ImageTransparency = 1
    avatarImg.Image = data.avatarUrl
    avatarImg.Parent = card

    local imgStroke = Instance.new("UIStroke")
    imgStroke.Color = THEME.Border
    imgStroke.Thickness = 1
    imgStroke.Transparency = 1
    imgStroke.Parent = avatarImg

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -95, 0, 18)
    titleLabel.Position = UDim2.new(0, 90, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = THEME.AccentRed
    titleLabel.TextTransparency = 1
    titleLabel.Font = THEME.FontBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = data.headerText or "STAFF DETECTED"
    titleLabel.Parent = card

    local userLabel = Instance.new("TextLabel")
    userLabel.Size = UDim2.new(1, -95, 0, 16)
    userLabel.Position = UDim2.new(0, 90, 0, 28)
    userLabel.BackgroundTransparency = 1
    userLabel.TextColor3 = THEME.TextMain
    userLabel.TextTransparency = 1
    userLabel.Font = THEME.FontBold
    userLabel.TextSize = 15
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.Text = string.format("%s (@%s)", data.displayName, data.username)
    userLabel.Parent = card

    local detailsLabel = Instance.new("TextLabel")
    detailsLabel.Size = UDim2.new(1, -95, 0, 36)
    detailsLabel.Position = UDim2.new(0, 90, 0, 46)
    detailsLabel.BackgroundTransparency = 1
    detailsLabel.TextColor3 = THEME.TextSub
    detailsLabel.TextTransparency = 1
    detailsLabel.Font = THEME.FontRegular
    detailsLabel.TextSize = 13
    detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
    detailsLabel.TextYAlignment = Enum.TextYAlignment.Top
    detailsLabel.TextWrapped = true
    detailsLabel.Text = string.format("Role: %s\nGroup: %s", data.role, data.group)
    detailsLabel.Parent = card

    local stayBtn = Instance.new("TextButton")
    stayBtn.Size = UDim2.new(0, 180, 0, 26)
    stayBtn.Position = UDim2.new(0, 10, 0, 92)
    stayBtn.BackgroundColor3 = THEME.ButtonDark
    stayBtn.BackgroundTransparency = 1
    stayBtn.TextColor3 = THEME.TextMain
    stayBtn.TextTransparency = 1
    stayBtn.Font = THEME.FontBold
    stayBtn.TextSize = 13
    stayBtn.Text = "Stay"
    stayBtn.Parent = card

    local stayStroke = Instance.new("UIStroke")
    stayStroke.Color = THEME.Border
    stayStroke.Thickness = 1
    stayStroke.Transparency = 1
    stayStroke.Parent = stayBtn

    local hopBtn = Instance.new("TextButton")
    hopBtn.Size = UDim2.new(0, 180, 0, 26)
    hopBtn.Position = UDim2.new(1, -190, 0, 92)
    hopBtn.BackgroundColor3 = THEME.AccentRed
    hopBtn.BackgroundTransparency = 1
    hopBtn.TextColor3 = THEME.TextMain
    hopBtn.TextTransparency = 1
    hopBtn.Font = THEME.FontBold
    hopBtn.TextSize = 13
    hopBtn.Text = "Server Hop"
    hopBtn.Parent = card

    local hopStroke = Instance.new("UIStroke")
    hopStroke.Color = THEME.Border
    hopStroke.Thickness = 1
    hopStroke.Transparency = 1
    hopStroke.Parent = hopBtn

    local lineBackground = Instance.new("Frame")
    lineBackground.Size = UDim2.new(1, -20, 0, 2)
    lineBackground.Position = UDim2.new(0, 10, 0, 130)
    lineBackground.BackgroundColor3 = THEME.ButtonDark
    lineBackground.BackgroundTransparency = 1
    lineBackground.BorderSizePixel = 0
    lineBackground.Parent = card

    local lineFill = Instance.new("Frame")
    lineFill.Size = UDim2.new(1, 0, 1, 0)
    lineFill.BackgroundColor3 = THEME.AccentRed
    lineFill.BackgroundTransparency = 1
    lineFill.BorderSizePixel = 0
    lineFill.Parent = lineBackground

    local tweenInfoIn = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    TweenService:Create(wrapper, tweenInfoIn, { Size = UDim2.new(1, 0, 0, targetHeight) }):Play()
    TweenService:Create(card, tweenInfoIn, { BackgroundTransparency = THEME.CardTransparency, Position = UDim2.new(0, 0, 0, 0) }):Play()
    TweenService:Create(cardStroke, tweenInfoIn, { Transparency = 0 }):Play()
    TweenService:Create(avatarImg, tweenInfoIn, { BackgroundTransparency = 0, ImageTransparency = 0 }):Play()
    TweenService:Create(imgStroke, tweenInfoIn, { Transparency = 0 }):Play()
    TweenService:Create(titleLabel, tweenInfoIn, { TextTransparency = 0 }):Play()
    TweenService:Create(userLabel, tweenInfoIn, { TextTransparency = 0 }):Play()
    TweenService:Create(detailsLabel, tweenInfoIn, { TextTransparency = 0 }):Play()
    TweenService:Create(stayBtn, tweenInfoIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(stayStroke, tweenInfoIn, { Transparency = 0 }):Play()
    TweenService:Create(hopBtn, tweenInfoIn, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
    TweenService:Create(hopStroke, tweenInfoIn, { Transparency = 0 }):Play()
    TweenService:Create(lineBackground, tweenInfoIn, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(lineFill, tweenInfoIn, { BackgroundTransparency = 0 }):Play()

    local lineTween = TweenService:Create(lineFill, TweenInfo.new(10, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
    lineTween:Play()

    local isClosing = false
    local function removeCard()
        if isClosing then return end
        isClosing = true

        local tweenInfoOut = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        local fadeTween = TweenService:Create(card, tweenInfoOut, { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, targetHeight) })
        TweenService:Create(wrapper, tweenInfoOut, { Size = UDim2.new(1, 0, 0, 0) }):Play()
        TweenService:Create(cardStroke, tweenInfoOut, { Transparency = 1 }):Play()
        TweenService:Create(avatarImg, tweenInfoOut, { BackgroundTransparency = 1, ImageTransparency = 1 }):Play()
        TweenService:Create(imgStroke, tweenInfoOut, { Transparency = 1 }):Play()
        TweenService:Create(titleLabel, tweenInfoOut, { TextTransparency = 1 }):Play()
        TweenService:Create(userLabel, tweenInfoOut, { TextTransparency = 1 }):Play()
        TweenService:Create(detailsLabel, tweenInfoOut, { TextTransparency = 1 }):Play()
        TweenService:Create(stayBtn, tweenInfoOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        TweenService:Create(stayStroke, tweenInfoOut, { Transparency = 1 }):Play()
        TweenService:Create(hopBtn, tweenInfoOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        TweenService:Create(hopStroke, tweenInfoOut, { Transparency = 1 }):Play()
        TweenService:Create(lineBackground, tweenInfoOut, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(lineFill, tweenInfoOut, { BackgroundTransparency = 1 }):Play()
        
        fadeTween:Play()
        fadeTween.Completed:Connect(function() wrapper:Destroy() end)
    end

    stayBtn.MouseButton1Click:Connect(removeCard)
    hopBtn.MouseButton1Click:Connect(function()
        hopBtn.Text = "Teleporting..."
        serverHop()
    end)

    lineTween.Completed:Connect(removeCard)
    return removeCard
end

-- ===== PRÜFUNG DER SPIELER (ASYNCHRON = KEINE LAGS) =====
local function checkPlayer(player, isStartup)
    if player.UserId == LocalPlayer.UserId and not isStartup then return end

    -- Komplett im Hintergrund ausführen, damit das Skript nicht einfriert
    task.spawn(function()
        for _, groupId in ipairs(trackedGroups) do
            local success, rank = pcall(function() return player:GetRankInGroup(groupId) end)
            local successRole, roleName = pcall(function() return player:GetRoleInGroup(groupId) end)

            if success and rank and rank > 0 then
                local isStaff = false
                local lowerRole = string.lower(roleName or "")

                for _, kw in ipairs(targetKeywords) do
                    if string.find(lowerRole, kw) then
                        isStaff = true
                        break
                    end
                end

                if rank >= 100 then
                    isStaff = true
                end

                if isStaff then
                    playAlertSound()
                    applyVisuals(player, roleName, isStartup and 10 or nil)

                    if activeCards[player.UserId] then
                        activeCards[player.UserId]()
                    end

                    local avatarUrl = getUserHeadshot(player.UserId)
                    local header = isStartup and "DETECTOR INITIALIZED" or "STAFF DETECTED"

                    local removeFunc = createNotification({
                        headerText = header,
                        username = player.Name,
                        displayName = player.DisplayName,
                        role = roleName,
                        group = "Group ID: " .. tostring(groupId),
                        avatarUrl = avatarUrl
                    })
                    
                    activeCards[player.UserId] = removeFunc
                    break
                end
            end
        end
    end)
end

-- ===== HAUPTABLAUF =====
task.spawn(function()
    -- NEU: Native und sichere Erkennung der Group ID. Verursacht KEINE Errors!
    if game.CreatorType == Enum.CreatorType.Group then
        table.insert(trackedGroups, game.CreatorId)
        print("✅ Game Group ID automatisch gefunden: " .. tostring(game.CreatorId))
    end

    -- Füge benutzerdefinierte Gruppen hinzu
    for _, gid in ipairs(customGroupIds) do
        if not table.find(trackedGroups, gid) then
            table.insert(trackedGroups, gid)
        end
    end

    -- Test-Benachrichtigung für dich selbst beim Start
    playAlertSound()
    createNotification({
        headerText = "DETECTOR READY",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        role = "Script User",
        group = "Aktiv (" .. #trackedGroups .. " Gruppen)",
        avatarUrl = getUserHeadshot(LocalPlayer.UserId)
    })

    -- Prüfe alle bereits im Server befindlichen Spieler
    for _, player in ipairs(Players:GetPlayers()) do
        checkPlayer(player, true)
    end

    -- Lausche auf neue Spieler
    Players.PlayerAdded:Connect(function(player)
        task.wait(2) -- Kurz warten bis der Spieler geladen ist
        checkPlayer(player, false)
    end)

    Players.PlayerRemoving:Connect(function(player)
        if activeCards[player.UserId] then
            activeCards[player.UserId]()
            activeCards[player.UserId] = nil
        end
        if activeVisuals[player.UserId] then
            activeVisuals[player.UserId]()
            activeVisuals[player.UserId] = nil
        end
    end)
end)
