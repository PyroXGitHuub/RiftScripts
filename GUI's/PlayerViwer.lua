--// Local ESP, Live Viewport, Persistent Cache & Interactive 3D Weapon Modal
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end

--// CONFIG
local Config = {
    IgnoredNames = {
        "woodland", "shirt", "pants", "graphic", "face", "head", "hair", "eyebrows", "default"
    }
}

local function shouldIgnore(name)
    local lower = string.lower(name)
    for _, ignoreWord in ipairs(Config.IgnoredNames) do
        if string.find(lower, ignoreWord) then return true end
    end
    return false
end

--// DURATEX COLOR HELPER
local function getDuraColor(duraVal)
    if not duraVal then return Color3.fromRGB(200, 200, 200), "#C8C8C8" end
    local lowerDura = string.lower(tostring(duraVal))
    
    if lowerDura == "pristine" then
        return Color3.fromRGB(0, 255, 0), "#00FF00" -- Grün
    elseif lowerDura == "worn" then
        return Color3.fromRGB(255, 255, 0), "#FFFF00" -- Gelb
    elseif lowerDura == "damaged" then
        return Color3.fromRGB(255, 165, 0), "#FFA500" -- Orange
    elseif lowerDura == "badly damaged" then
        return Color3.fromRGB(255, 51, 51), "#FF3333" -- Rot
    end
    
    return Color3.fromRGB(200, 200, 200), "#C8C8C8"
end

--// DYNAMIC VALUE SYSTEM
local function getItemValue(itemName)
    local lower = string.lower(itemName)
    
    if string.find(lower, "m82a1") or string.find(lower, "ak47") or string.find(lower, "ar15") or 
       string.find(lower, "scar") or string.find(lower, "vss") or string.find(lower, "svd") or 
       string.find(lower, "m16") or string.find(lower, "aug") or string.find(lower, "fal") then
        return 75
    elseif string.find(lower, "spas") or string.find(lower, "remington") or string.find(lower, "ump") or 
           string.find(lower, "mp5") or string.find(lower, "12 gauge") then
        return 50
    elseif string.find(lower, "glock") or string.find(lower, "desert eagle") or string.find(lower, "m1911") or 
           string.find(lower, "berreta") or string.find(lower, "altyn") or string.find(lower, "korund") or 
           string.find(lower, "plate carrier") then
        return 35
    elseif string.find(lower, "helmet") or string.find(lower, "vest") or string.find(lower, "backpack") or 
           string.find(lower, "duffel") or string.find(lower, "katana") or string.find(lower, "machete") then
        return 20
    elseif string.find(lower, "knife") or string.find(lower, "bat") or string.find(lower, "axe") or 
           string.find(lower, "medkit") or string.find(lower, "bandage") or string.find(lower, "ifak") then
        return 10
    elseif string.find(lower, "mm") or string.find(lower, "acp") or string.find(lower, "water") or 
           string.find(lower, "beans") or string.find(lower, "bar") or string.find(lower, "juice") or 
           string.find(lower, "soup") then
        return 2
    end
    return 5
end

--// GUI SETUP
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PlayerInspectorGui"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 540)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("TextButton")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.TextSize = 13
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.Text = "Player Inspector By D3v1lHub"
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(0, 70, 0, 22)
UnloadBtn.Position = UDim2.new(1, -75, 0, 4)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
UnloadBtn.TextSize = 11
UnloadBtn.Font = Enum.Font.SourceSansBold
UnloadBtn.Text = "Unload"
UnloadBtn.Parent = TitleBar
Instance.new("UICorner", UnloadBtn).CornerRadius = UDim.new(0, 4)

-- PLAYER LIST (Vertical Scrolling Only)
local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Size = UDim2.new(0, 140, 0, 450)
PlayerList.Position = UDim2.new(0, 10, 0, 40)
PlayerList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PlayerList.BorderSizePixel = 0
PlayerList.ScrollingDirection = Enum.ScrollingDirection.Y
PlayerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerList.ScrollBarThickness = 5
PlayerList.Active = true
PlayerList.Parent = MainFrame
local ListLayout = Instance.new("UIListLayout", PlayerList)
ListLayout.Padding = UDim.new(0, 5)

-- SELECT NONE BUTTON
local SelectNoneBtn = Instance.new("TextButton")
SelectNoneBtn.Size = UDim2.new(0, 140, 0, 35)
SelectNoneBtn.Position = UDim2.new(0, 10, 0, 495)
SelectNoneBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
SelectNoneBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
SelectNoneBtn.TextSize = 12
SelectNoneBtn.Font = Enum.Font.SourceSansBold
SelectNoneBtn.Text = "Select None"
SelectNoneBtn.Parent = MainFrame
Instance.new("UICorner", SelectNoneBtn).CornerRadius = UDim.new(0, 4)

-- DETAIL FRAME / LOOT (Vertical Scrolling Only)
local DetailFrame = Instance.new("ScrollingFrame")
DetailFrame.Size = UDim2.new(0, 150, 0, 320)
DetailFrame.Position = UDim2.new(0, 160, 0, 40)
DetailFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
DetailFrame.BorderSizePixel = 0
DetailFrame.ScrollingDirection = Enum.ScrollingDirection.Y
DetailFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
DetailFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
DetailFrame.ScrollBarThickness = 5
DetailFrame.Active = true
DetailFrame.Parent = MainFrame
local DetailLayout = Instance.new("UIListLayout", DetailFrame)
DetailLayout.Padding = UDim.new(0, 4)

local CharViewport = Instance.new("ViewportFrame")
CharViewport.Size = UDim2.new(0, 230, 0, 320)
CharViewport.Position = UDim2.new(0, 320, 0, 40)
CharViewport.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CharViewport.BorderSizePixel = 0
CharViewport.Parent = MainFrame
Instance.new("UICorner", CharViewport).CornerRadius = UDim.new(0, 6)
local CharCamera = Instance.new("Camera", CharViewport)
CharViewport.CurrentCamera = CharCamera

-- ITEM SHOWCASE (3-Column Grid Layout & Vertical Scrolling Only)
local ItemShowcase = Instance.new("ScrollingFrame")
ItemShowcase.Size = UDim2.new(0, 390, 0, 160)
ItemShowcase.Position = UDim2.new(0, 160, 0, 370)
ItemShowcase.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ItemShowcase.BorderSizePixel = 0
ItemShowcase.ScrollingDirection = Enum.ScrollingDirection.Y
ItemShowcase.AutomaticCanvasSize = Enum.AutomaticSize.Y
ItemShowcase.CanvasSize = UDim2.new(0, 0, 0, 0)
ItemShowcase.ScrollBarThickness = 6
ItemShowcase.Active = true
ItemShowcase.Parent = MainFrame
Instance.new("UICorner", ItemShowcase).CornerRadius = UDim.new(0, 6)

local ShowcasePadding = Instance.new("UIPadding", ItemShowcase)
ShowcasePadding.PaddingLeft = UDim.new(0, 6)
ShowcasePadding.PaddingRight = UDim.new(0, 6)
ShowcasePadding.PaddingTop = UDim.new(0, 6)
ShowcasePadding.PaddingBottom = UDim.new(0, 6)

local ShowcaseLayout = Instance.new("UIGridLayout", ItemShowcase)
ShowcaseLayout.CellSize = UDim2.new(0, 120, 0, 125)
ShowcaseLayout.CellPadding = UDim2.new(0, 6, 0, 6)
ShowcaseLayout.SortOrder = Enum.SortOrder.LayoutOrder

--// WEAPON INSPECT MODAL
local ModalFrame = Instance.new("Frame")
ModalFrame.Size = UDim2.new(0, 350, 0, 350)
ModalFrame.Position = UDim2.new(0.5, -175, 0.5, -175)
ModalFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ModalFrame.BorderSizePixel = 0
ModalFrame.Visible = false
ModalFrame.Active = true
ModalFrame.ZIndex = 10
ModalFrame.Parent = ScreenGui
Instance.new("UICorner", ModalFrame).CornerRadius = UDim.new(0, 8)

local ModalTitle = Instance.new("TextLabel")
ModalTitle.Size = UDim2.new(1, -40, 0, 30)
ModalTitle.Position = UDim2.new(0, 10, 0, 0)
ModalTitle.BackgroundTransparency = 1
ModalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ModalTitle.TextSize = 13
ModalTitle.Font = Enum.Font.SourceSansBold
ModalTitle.TextXAlignment = Enum.TextXAlignment.Left
ModalTitle.ZIndex = 11
ModalTitle.Parent = ModalFrame

local CloseModalBtn = Instance.new("TextButton")
CloseModalBtn.Size = UDim2.new(0, 26, 0, 22)
CloseModalBtn.Position = UDim2.new(1, -30, 0, 4)
CloseModalBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseModalBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseModalBtn.Text = "X"
CloseModalBtn.Font = Enum.Font.SourceSansBold
CloseModalBtn.TextSize = 13
CloseModalBtn.ZIndex = 11
CloseModalBtn.Parent = ModalFrame
Instance.new("UICorner", CloseModalBtn).CornerRadius = UDim.new(0, 4)

local ModalVP = Instance.new("ViewportFrame")
ModalVP.Size = UDim2.new(1, -20, 1, -40)
ModalVP.Position = UDim2.new(0, 10, 0, 35)
ModalVP.BackgroundTransparency = 1
ModalVP.ZIndex = 10
ModalVP.Parent = ModalFrame

local ModalCam = Instance.new("Camera", ModalVP)
ModalVP.CurrentCamera = ModalCam

-- Drag UI for Main Frame
local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = MainFrame.Position end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

--// TRACER DRAWING SETUP (Purple Tracer Line)
local tracerLine = nil
if Drawing and Drawing.new then
    tracerLine = Drawing.new("Line")
    tracerLine.Color = Color3.fromRGB(170, 0, 255) -- Lila
    tracerLine.Thickness = 2
    tracerLine.Transparency = 1
    tracerLine.Visible = false
end

--// CACHE & MODAL STATE
local playerPersistentCache = {}
local activeItemViewports = {}
local selectedPlayer = nil
local activeClonedChar = nil
local renderConnection = nil
local eventConnections = {}

local currentModalModel = nil
local currentModalData = nil
local modalZoom = 2.0
local modalRotAngle = 0

--// CLEAR SELECTION FUNCTION
local function clearSelection()
    selectedPlayer = nil
    if activeClonedChar then activeClonedChar:Destroy() activeClonedChar = nil end
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    
    for _, child in ipairs(DetailFrame:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    
    for _, child in ipairs(ItemShowcase:GetChildren()) do
        if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then child:Destroy() end
    end
    activeItemViewports = {}
    
    if tracerLine then
        tracerLine.Visible = false
    end
end

SelectNoneBtn.MouseButton1Click:Connect(function()
    clearSelection()
end)

local function openWeaponModal(itemName, modelTemplate, titleColor)
    if currentModalModel then currentModalModel:Destroy() end
    
    ModalTitle.Text = "Inspection: " .. itemName
    ModalTitle.TextColor3 = titleColor or Color3.fromRGB(255, 255, 255)
    
    local clone = modelTemplate:Clone()
    clone.Parent = ModalVP
    currentModalModel = clone
    
    local cf, size = clone:GetBoundingBox()
    local maxSize = math.max(size.X, size.Y, size.Z)
    modalZoom = maxSize * 0.9
    if modalZoom < 0.8 then modalZoom = 0.8 end
    
    currentModalData = {
        center = cf.Position,
        size = maxSize
    }
    CloseModalBtn.Modal = true
    ModalFrame.Visible = true
end

CloseModalBtn.MouseButton1Click:Connect(function()
    CloseModalBtn.Modal = false
    ModalFrame.Visible = false
    if currentModalModel then
        currentModalModel:Destroy()
        currentModalModel = nil
    end
end)

-- Mouse wheel zoom in modal frame
UserInputService.InputChanged:Connect(function(input)
    if ModalFrame.Visible and input.UserInputType == Enum.UserInputType.MouseWheel then
        local delta = input.Position.Z
        if delta > 0 then
            modalZoom = math.max(0.3, modalZoom - 0.2)
        else
            modalZoom = math.min(10.0, modalZoom + 0.2)
        end
    end
end)

-- Cleanup on player leaving (Cache + Event Connections)
Players.PlayerRemoving:Connect(function(plr)
    playerPersistentCache[plr] = nil
    if eventConnections[plr] then
        for _, conn in ipairs(eventConnections[plr]) do
            if conn then conn:Disconnect() end
        end
        eventConnections[plr] = nil
    end
    if selectedPlayer == plr then
        clearSelection()
    end
end)

local function updateItemShowcase(itemNamesMap)
    for _, child in ipairs(ItemShowcase:GetChildren()) do
        if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then 
            child:Destroy() 
        end
    end
    activeItemViewports = {}
    
    local modelsFolder = ReplicatedStorage:FindFirstChild("CLIENT_ASSETS")
    if modelsFolder then modelsFolder = modelsFolder:FindFirstChild("ItemViewportModels") end
    
    for itemName, itemData in pairs(itemNamesMap) do
        local duraVal = type(itemData) == "table" and itemData.duraTex or nil
        local nameColor = getDuraColor(duraVal)
        
        local modelTemplate = modelsFolder and modelsFolder:FindFirstChild(itemName)
        if modelTemplate then
            local container = Instance.new("Frame")
            container.Size = UDim2.new(0, 120, 0, 125)
            container.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            container.Parent = ItemShowcase
            Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
            
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -4, 0, 22)
            nameLbl.Position = UDim2.new(0, 2, 1, -22)
            nameLbl.BackgroundTransparency = 1
            nameLbl.TextColor3 = nameColor -- Nimmt hier nun die Farbe des DuraTex an
            nameLbl.TextSize = 10
            nameLbl.Font = Enum.Font.SourceSansBold
            nameLbl.Text = itemName
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.Parent = container
            
            local vp = Instance.new("ViewportFrame")
            vp.Size = UDim2.new(1, 0, 1, -22)
            vp.BackgroundTransparency = 1
            vp.Parent = container
            
            local cam = Instance.new("Camera", vp)
            vp.CurrentCamera = cam
            
            local clone = modelTemplate:Clone()
            clone.Parent = vp
            
            -- Interactive click button
            local clickBtn = Instance.new("TextButton")
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Text = ""
            clickBtn.Parent = container
            clickBtn.MouseButton1Click:Connect(function()
                openWeaponModal(itemName, modelTemplate, nameColor)
            end)
            
            local cf, size = clone:GetBoundingBox()
            table.insert(activeItemViewports, {model = clone, camera = cam, center = cf.Position, size = math.max(size.X, size.Y, size.Z)})
        end
    end
end

local function updateDetailView(plr)
    if selectedPlayer ~= plr then return end
    
    for _, child in ipairs(DetailFrame:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    
    local cache = playerPersistentCache[plr]
    if not cache then return end
    
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 25)
    header.BackgroundTransparency = 1
    header.TextColor3 = Color3.fromRGB(0, 255, 128)
    header.TextSize = 12
    header.Font = Enum.Font.SourceSansBold
    header.Text = "Loot: " .. plr.Name
    header.Parent = DetailFrame
    
    local hasItems = false
    for itemName, itemData in pairs(cache.items) do
        hasItems = true
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.SourceSans
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.RichText = true
        
        local duraVal = type(itemData) == "table" and itemData.duraTex or nil
        local duraText = ""
        
        if duraVal then
            local _, hexColor = getDuraColor(duraVal)
            duraText = string.format(" <font color=\"%s\">[%s]</font>", hexColor, tostring(duraVal))
        end
        
        lbl.Text = "- " .. itemName .. duraText
        lbl.Parent = DetailFrame
    end
    
    if not hasItems then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.SourceSans
        lbl.Text = "No loot found"
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = DetailFrame
    end
    
    updateItemShowcase(cache.items)
end

local function processNewItem(plr, item)
    if not item then return end
    if item:IsA("Tool") or item:IsA("Accessory") or item:IsA("Model") then
        if not shouldIgnore(item.Name) then
            if not playerPersistentCache[plr] then
                playerPersistentCache[plr] = { score = 0, items = {} }
            end
            
            local duraAttr = item:GetAttribute("DuraTex")
            
            if not playerPersistentCache[plr].items[item.Name] then
                playerPersistentCache[plr].items[item.Name] = {
                    duraTex = duraAttr
                }
                playerPersistentCache[plr].score = playerPersistentCache[plr].score + getItemValue(item.Name)
                
                if selectedPlayer == plr then
                    updateDetailView(plr)
                end
            else
                local currentData = playerPersistentCache[plr].items[item.Name]
                if type(currentData) == "table" and duraAttr and currentData.duraTex ~= duraAttr then
                    currentData.duraTex = duraAttr
                    if selectedPlayer == plr then
                        updateDetailView(plr)
                    end
                end
            end
        end
    end
end

local function scanPlayerInitial(plr)
    local char = Workspace:FindFirstChild(plr.Name)
    if char then
        for _, item in ipairs(char:GetChildren()) do processNewItem(plr, item) end
    end
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do processNewItem(plr, item) end
    end
end

local function hookInventoryEvents(plr)
    if eventConnections[plr] then
        for _, conn in ipairs(eventConnections[plr]) do conn:Disconnect() end
    end
    eventConnections[plr] = {}
    
    local function onCharacterAdded(char)
        table.insert(eventConnections[plr], char.ChildAdded:Connect(function(child) task.wait(0.1) processNewItem(plr, child) end))
    end
    
    if plr.Character then onCharacterAdded(plr.Character) end
    table.insert(eventConnections[plr], plr.CharacterAdded:Connect(onCharacterAdded))
    
    table.insert(eventConnections[plr], plr.ChildAdded:Connect(function(child)
        if child.Name == "Backpack" then
            table.insert(eventConnections[plr], child.ChildAdded:Connect(function(item) task.wait(0.1) processNewItem(plr, item) end))
        end
    end))
    
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        table.insert(eventConnections[plr], bp.ChildAdded:Connect(function(item) task.wait(0.1) processNewItem(plr, item) end))
    end
end

local function setupViewport(plr)
    selectedPlayer = plr
    if activeClonedChar then activeClonedChar:Destroy() activeClonedChar = nil end
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    
    updateDetailView(plr)
    
    local char = Workspace:FindFirstChild(plr.Name)
    if not char then return end
    
    activeClonedChar = char:Clone()
    for _, obj in ipairs(activeClonedChar:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") then obj:Destroy() end
    end
    
    local center = Vector3.new(0, 5, 0)
    activeClonedChar:PivotTo(CFrame.new(center))
    activeClonedChar.Parent = CharViewport
    
    local rotAngle = 0
    
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        local realChar = Workspace:FindFirstChild(plr.Name)
        if realChar and realChar:FindFirstChild("HumanoidRootPart") and activeClonedChar and activeClonedChar:FindFirstChild("HumanoidRootPart") then
            activeClonedChar.HumanoidRootPart.CFrame = CFrame.new(center) * (realChar.HumanoidRootPart.CFrame - realChar.HumanoidRootPart.Position)
            for _, realDesc in ipairs(realChar:GetDescendants()) do
                if realDesc:IsA("Motor6D") then
                    local cloneDesc = activeClonedChar:FindFirstChild(realDesc.Name, true)
                    if cloneDesc and cloneDesc:IsA("Motor6D") then cloneDesc.Transform = realDesc.Transform end
                end
            end
        end
        
        rotAngle = rotAngle + (dt * 1.5)
        
        -- Main Character Camera in Viewport
        local dist = 7.0
        local camPos = center + Vector3.new(math.cos(rotAngle * 0.8) * dist, 2.2, math.sin(rotAngle * 0.8) * dist)
        CharCamera.CFrame = CFrame.new(camPos, center + Vector3.new(0, 1, 0))
        
        -- Rotate 3D Showcase Items
        for _, itemData in ipairs(activeItemViewports) do
            if itemData.camera and itemData.model then
                local itemDist = itemData.size * 0.8
                if itemDist < 1.0 then itemDist = 1.0 end 
                local cPos = itemData.center + Vector3.new(math.cos(rotAngle)*itemDist, itemDist*0.1, math.sin(rotAngle)*itemDist)
                itemData.camera.CFrame = CFrame.new(cPos, itemData.center)
            end
        end
        
        -- Update Pop-up Modal 3D Camera & Zoom
        if ModalFrame.Visible and currentModalModel and currentModalData then
            modalRotAngle = modalRotAngle + (dt * 1.5)
            local cPos = currentModalData.center + Vector3.new(math.cos(modalRotAngle) * modalZoom, modalZoom * 0.2, math.sin(modalRotAngle) * modalZoom)
            ModalCam.CFrame = CFrame.new(cPos, currentModalData.center)
        end
    end)
end

--// GLOBAL TRACER LOOP (Maus zu Spieler)
local tracerConnection = RunService.RenderStepped:Connect(function()
    if selectedPlayer and tracerLine then
        local realChar = Workspace:FindFirstChild(selectedPlayer.Name)
        local targetPart = realChar and (realChar:FindFirstChild("HumanoidRootPart") or realChar:FindFirstChild("Head"))
        
        if targetPart then
            local Camera = Workspace.CurrentCamera
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                tracerLine.From = mousePos
                tracerLine.To = Vector2.new(screenPos.X, screenPos.Y)
                tracerLine.Visible = true
            else
                tracerLine.Visible = false
            end
        else
            tracerLine.Visible = false
        end
    elseif tracerLine then
        tracerLine.Visible = false
    end
end)

--// MAIN LOOP (PLAYERS IN WORKSPACE INCLUDING LOCALPLAYER)
local playerButtons = {}
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1)
        for _, btn in pairs(playerButtons) do if btn and btn.Parent then btn:Destroy() end end
        playerButtons = {}
        
        for _, plr in ipairs(Players:GetPlayers()) do
            local charInWorkspace = Workspace:FindFirstChild(plr.Name)
            if charInWorkspace and charInWorkspace:FindFirstChild("HumanoidRootPart") then
                
                if not playerPersistentCache[plr] then
                    playerPersistentCache[plr] = { score = 0, items = {} }
                    scanPlayerInitial(plr)
                    if not eventConnections[plr] then hookInventoryEvents(plr) end
                else
                    scanPlayerInitial(plr)
                end
                
                local score = playerPersistentCache[plr].score
                
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -10, 0, 45)
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextSize = 11
                btn.Font = Enum.Font.SourceSansBold
                
                if plr == LocalPlayer then
                    btn.Text = string.format("%s (You)\nValue: %d", plr.Name, score)
                    btn.TextColor3 = Color3.fromRGB(100, 200, 255)
                else
                    btn.Text = string.format("%s\nValue: %d", plr.Name, score)
                end
                
                btn.Parent = PlayerList
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.MouseButton1Click:Connect(function() setupViewport(plr) end)
                table.insert(playerButtons, btn)
            end
        end
    end
end)

UnloadBtn.MouseButton1Click:Connect(function()
    clearSelection()
    if tracerConnection then tracerConnection:Disconnect() end
    if tracerLine then tracerLine:Remove() end
    for _, conns in pairs(eventConnections) do for _, c in ipairs(conns) do c:Disconnect() end end
    ScreenGui:Destroy()
end)

print("[Inspector] Player Inspector By D3v1lHub loaded successfully!")
