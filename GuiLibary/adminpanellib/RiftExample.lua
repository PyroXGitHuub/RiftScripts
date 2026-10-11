--[[
	RiftLib Example
	Lädt die Library per loadstring von GitHub.
]]

local GUI_VERSION = "v1.0.0" -- wird oben im Header und in den Settings als "GUI Version" angezeigt
local LIB_URL = "https://raw.githubusercontent.com/PyroXGitHuub/RiftScripts/refs/heads/main/GuiLibary/adminpanellib/RiftLib.lua"

local Library = loadstring(game:HttpGet(LIB_URL))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Optional: Animationen komplett aus (auch in Settings umschaltbar)
-- Library.Animations = false

--// Loading Screen
Library:ShowLoadingScreen({
	Title = "Rift Scripts",
	Duration = 2.5,
	Steps = { "Loading library...", "Building interface...", "Almost done..." },
})

--// Fenster
local Window = Library:CreateWindow({
	Title = "Rift CMD's",
	Version = GUI_VERSION,
	MenuKey = Enum.KeyCode.RightShift, -- Standard-Taste zum Minimieren/Maximieren (in Settings änderbar)
	ConfigFolder = "RiftScripts",
})

local function GetHumanoid()
	return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
end

--// Modul: Speed
local Speed = Window:AddModule({ Name = "Speed" })
local speedEnabled, speedValue = false, 50

Speed:AddToggleWithKey({
	Name = "Enable Speed", Flag = "SpeedEnabled", Default = false, Key = nil,
	Callback = function(v)
		speedEnabled = v
		if not v then
			local hum = GetHumanoid()
			if hum then hum.WalkSpeed = 16 end
		end
	end,
})
Speed:AddSlider({
	Name = "Speed Amount", Flag = "SpeedValue", Min = 16, Max = 200, Default = 50, Increment = 1,
	Callback = function(v) speedValue = v end,
})

RunService.Heartbeat:Connect(function()
	if not speedEnabled then return end
	local hum = GetHumanoid()
	if hum then hum.WalkSpeed = speedValue end
end)

--// Modul: Jump
local Jump = Window:AddModule({ Name = "Jump Power" })
local jumpEnabled, jumpValue = false, 50
Jump:AddToggleWithKey({
	Name = "Enable Jump", Flag = "JumpEnabled",
	Callback = function(v)
		jumpEnabled = v
		local hum = GetHumanoid()
		if hum and not v then hum.UseJumpPower = true; hum.JumpPower = 50 end
	end,
})
Jump:AddSlider({ Name = "Jump Amount", Flag = "JumpValue", Min = 50, Max = 300, Default = 80, Callback = function(v) jumpValue = v end })
RunService.Heartbeat:Connect(function()
	if not jumpEnabled then return end
	local hum = GetHumanoid()
	if hum then hum.UseJumpPower = true; hum.JumpPower = jumpValue end
end)

--// Modul: Noclip
local Noclip = Window:AddModule({ Name = "Noclip" })
local noclip = false
Noclip:AddToggleWithKey({ Name = "Enable Noclip", Flag = "Noclip", Callback = function(v) noclip = v end })
RunService.Stepped:Connect(function()
	if not noclip or not LocalPlayer.Character then return end
	for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
end)

--// Modul: Teleport (Spieler-Dropdown)
local Teleport = Window:AddModule({ Name = "Teleport" })
local target = Teleport:AddDropdown({ Name = "Player", Flag = "TPTarget", Special = "Player", Searchable = true })
Teleport:AddButton({
	Name = "Teleport to Player", Text = "Goto",
	Callback = function()
		local plr = target.Value and Players:FindFirstChild(target.Value)
		local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local theirRoot = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and theirRoot then
			myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 3)
		else
			Library:Notify({ Title = "Teleport", Content = "Select a valid player first" })
		end
	end,
})

--// Modul: Alle Komponenten (Demo)
local Demo = Window:AddModule({ Name = "Component Demo" })

Demo:AddDivider("Buttons")
Demo:AddButton({ Name = "Simple Button", Text = "Click", Callback = function() Library:Notify({ Title = "Rift", Content = "Button clicked!" }) end })
Demo:AddButton({ Name = "Filled Button", Text = "Run", Style = "filled", Callback = function() print("Run") end })
Demo:AddButtonGroup({
	Buttons = {
		{ Text = "One", Callback = function() print("One") end },
		{ Text = "Two", Style = "filled", Callback = function() print("Two") end },
		{ Text = "Three", Style = "danger", Callback = function() print("Three") end },
	},
})

Demo:AddDivider("Toggles")
Demo:AddToggle({ Name = "Toggle", Flag = "DemoToggle", Default = false, Callback = function(v) print("Toggle:", v) end })
Demo:AddToggleWithKey({ Name = "Toggle with Key", Flag = "DemoToggleKey", Key = Enum.KeyCode.G, Callback = function(v) print("ToggleKey:", v) end })
Demo:AddSelector({ Name = "Selector", Flag = "DemoSelector", Values = { "On", "Off" }, Default = "Off", Callback = function(v) print("Selector:", v) end })

Demo:AddDivider("Sliders")
Demo:AddSlider({ Name = "Slider", Flag = "DemoSlider", Min = 0, Max = 100, Default = 30, Callback = function(v) print("Slider:", v) end })
Demo:AddSlider({ Name = "Slider (Decimal)", Flag = "DemoSliderDec", Min = 0, Max = 1, Default = 0.5, Increment = 0.05, Suffix = "x" })

Demo:AddDivider("Dropdowns")
Demo:AddDropdown({
	Name = "Dropdown", Flag = "DemoDropdown", Values = { "Option 1", "Option 2", "Option 3" }, Default = "Option 1",
	Callback = function(v) print("Dropdown:", v) end,
})
Demo:AddDropdown({
	Name = "Multi Dropdown", Flag = "DemoMulti", Multi = true, Searchable = true,
	Values = { "Apple", "Banana", "Cherry", "Grape", "Lemon", "Mango", "Orange" }, Default = { "Apple" },
	Callback = function(v) print("Multi:", table.concat(v, ", ")) end,
})

Demo:AddDivider("Inputs")
Demo:AddInput({ Name = "Text Input", Flag = "DemoInput", Placeholder = "Type something...", Callback = function(v) print("Input:", v) end })
Demo:AddInput({ Name = "Number Input", Flag = "DemoNumber", Numeric = true, Default = "10", Callback = function(v) print("Number:", tonumber(v)) end })
Demo:AddKeybind({ Name = "Keybind (Press)", Flag = "DemoKeyPress", Mode = "Press", Callback = function() print("Key pressed") end })
Demo:AddKeybind({ Name = "Keybind (Toggle)", Flag = "DemoKeyToggle", Mode = "Toggle", Callback = function(s) print("Key toggle:", s) end })
Demo:AddKeybind({ Name = "Keybind (Hold)", Flag = "DemoKeyHold", Mode = "Hold", Callback = function(d) print("Key hold:", d) end })

Demo:AddDivider("Info")
Demo:AddLabel("A simple label for short hints.")
Demo:AddParagraph({ Title = "Paragraph", Content = "Use this for longer text. It wraps automatically and grows with its content." })
Demo:AddInfo({ Name = "Info Row", Value = "Value" })

-- Color Picker landen automatisch ganz unten im Modul
Demo:AddColorPicker({ Name = "Color Picker", Flag = "DemoColor", Default = Color3.fromRGB(150, 90, 255), Callback = function(c) print("Color:", c) end })

Library:Notify({ Title = "Rift", Content = "Loaded! Minimize with RightShift.", Duration = 5 })
