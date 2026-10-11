--[[
	RiftLib Example
	Lädt die Library per loadstring (GitHub raw Link unten anpassen).
]]

local GUI_VERSION = "v1.0.0" -- wird in Settings als "GUI Version" angezeigt
local LIB_URL = "https://raw.githubusercontent.com/PyroXGitHuub/RiftScripts/main/RiftLib.lua"

local Library = loadstring(game:HttpGet(LIB_URL))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

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

--// Modul: Speed
local Speed = Window:AddModule({ Name = "Speed" })
local speedEnabled, speedValue = false, 50

Speed:AddToggle({
	Name = "Enabled", Flag = "SpeedEnabled", Default = false,
	Callback = function(v)
		speedEnabled = v
		if not v then
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end
	end,
})
Speed:AddSlider({
	Name = "Speed", Flag = "SpeedValue", Min = 16, Max = 200, Default = 50, Increment = 1,
	Callback = function(v) speedValue = v end,
})
Speed:AddKeybind({
	Name = "Toggle Key", Flag = "SpeedKey", Mode = "Press",
	Callback = function() Library.Options.SpeedEnabled:Set(not Library.Flags.SpeedEnabled) end,
})

RunService.Heartbeat:Connect(function()
	if not speedEnabled then return end
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = speedValue end
end)

--// Modul: Noclip
local Noclip = Window:AddModule({ Name = "Noclip" })
local noclip = false
Noclip:AddToggle({ Name = "Enabled", Flag = "Noclip", Callback = function(v) noclip = v end })
RunService.Stepped:Connect(function()
	if not noclip or not LocalPlayer.Character then return end
	for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
end)

--// Modul: Alle Komponenten (Demo)
local Demo = Window:AddModule({ Name = "Component Demo" })

Demo:AddDivider("Buttons")
Demo:AddButton({
	Name = "Simple Button", Text = "Click",
	Callback = function() Library:Notify({ Title = "Rift", Content = "Button geklickt!" }) end,
})
Demo:AddButtonGroup({
	Buttons = {
		{ Text = "One", Callback = function() print("One") end },
		{ Text = "Two", Callback = function() print("Two") end },
		{ Text = "Three", Callback = function() print("Three") end },
	},
})

Demo:AddDivider("Toggle & Slider")
Demo:AddToggle({ Name = "Toggle", Flag = "DemoToggle", Default = false, Callback = function(v) print("Toggle:", v) end })
Demo:AddSlider({ Name = "Slider", Flag = "DemoSlider", Min = 0, Max = 100, Default = 30, Increment = 1, Callback = function(v) print("Slider:", v) end })
Demo:AddSlider({ Name = "Slider (Dezimal)", Flag = "DemoSliderDec", Min = 0, Max = 1, Default = 0.5, Increment = 0.05, Suffix = "x" })

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

Demo:AddDivider("Eingaben")
Demo:AddInput({ Name = "Text Input", Flag = "DemoInput", Placeholder = "Tippe etwas...", Callback = function(v) print("Input:", v) end })
Demo:AddInput({ Name = "Zahl Input", Flag = "DemoNumber", Numeric = true, Default = "10", Callback = function(v) print("Zahl:", tonumber(v)) end })
Demo:AddKeybind({ Name = "Keybind (Press)", Flag = "DemoKeyPress", Mode = "Press", Callback = function() print("Key gedrückt") end })
Demo:AddKeybind({ Name = "Keybind (Toggle)", Flag = "DemoKeyToggle", Mode = "Toggle", Callback = function(s) print("Key Toggle:", s) end })
Demo:AddKeybind({ Name = "Keybind (Hold)", Flag = "DemoKeyHold", Mode = "Hold", Callback = function(d) print("Key Hold:", d) end })

Demo:AddDivider("Infos")
Demo:AddLabel("Ein einfaches Label für kurze Hinweise.")
Demo:AddParagraph({ Title = "Paragraph", Content = "Hier kannst du längeren Text anzeigen, der automatisch umbricht." })
Demo:AddInfo({ Name = "Info Zeile", Value = "Wert" })

-- Color Picker werden automatisch ganz unten im Modul einsortiert
Demo:AddColorPicker({ Name = "Color Picker", Flag = "DemoColor", Default = Color3.fromRGB(138, 63, 252), Callback = function(c) print("Color:", c) end })

Library:Notify({ Title = "Rift", Content = "Geladen! Minimieren mit RightShift.", Duration = 5 })
