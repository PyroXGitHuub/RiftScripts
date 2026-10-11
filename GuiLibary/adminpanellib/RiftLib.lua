--[[
	RiftLib  -  Roblox GUI Library (Rift Scripts)

	Aufbau:
		Library:ShowLoadingScreen(opts)
		Library:CreateWindow(opts)            -> Window
		Window:AddModule(opts)                -> Module
		Module:AddButton / AddButtonGroup / AddToggle / AddSlider / AddDropdown
		       AddInput / AddKeybind / AddColorPicker / AddLabel / AddParagraph
		       AddInfo / AddDivider
		Library:Notify(opts)
		Library:SaveConfig / LoadConfig / DeleteConfig / ListConfigs
		Library:SetAccent(Color3)
		Library:Unload()

	Hinweis: Color Picker werden in jedem Modul automatisch ganz unten einsortiert.
]]

local genv = (getgenv and getgenv()) or _G
if genv.RiftLib and type(genv.RiftLib.Unload) == "function" then
	pcall(function() genv.RiftLib:Unload() end)
end

local cloneref = cloneref or function(o) return o end

local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local LocalPlayer = Players.LocalPlayer

--// Library table
local Library = {
	Version = "1.0.0",
	Flags = {},
	Options = {},
	Accent = Color3.fromRGB(138, 63, 252),
	ConfigFolder = "RiftLib",
	Assets = {
		Logo = "rbxassetid://75876733222469",
		Background = "rbxassetid://85708246103612",
	},
	_conns = {},
	_accentFns = {},
	_keybinds = {},
	_scales = {},
	_listening = false,
	_windows = {},
}

local Theme = {
	Background = Color3.fromRGB(10, 9, 15),
	Panel = Color3.fromRGB(16, 14, 24),
	Element = Color3.fromRGB(26, 23, 38),
	ElementHover = Color3.fromRGB(38, 33, 56),
	Stroke = Color3.fromRGB(52, 45, 78),
	Text = Color3.fromRGB(238, 233, 252),
	SubText = Color3.fromRGB(150, 142, 182),
}

--// Helpers
local CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local function RandomString(n)
	local t = {}
	for i = 1, n do
		local k = math.random(1, #CHARS)
		t[i] = CHARS:sub(k, k)
	end
	return table.concat(t)
end

local function Asset(id)
	if type(id) == "number" then return "rbxassetid://" .. id end
	if type(id) == "string" and id:match("^%d+$") then return "rbxassetid://" .. id end
	return id
end

local function New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function UICorner(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function UIStroke(color, thickness, transparency)
	return New("UIStroke", {
		Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Tween(inst, props, t, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function Safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[RiftLib] " .. tostring(err)) end
end

local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library._conns, c)
	return c
end

local function OnAccent(fn)
	pcall(fn, Library.Accent)
	table.insert(Library._accentFns, fn)
end

local function Accent(inst, prop)
	OnAccent(function(c) inst[prop] = c end)
end

local function GetScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if mobile then
		return math.clamp(math.min(vp.X / 950, vp.Y / 520), 0.55, 1)
	end
	return math.clamp(math.min(vp.X / 1000, vp.Y / 620), 0.7, 1)
end

local function AddScale(frame)
	local s = New("UIScale", { Scale = GetScale(), Parent = frame })
	table.insert(Library._scales, s)
	return s
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function MakeDraggable(handle, target, onEnd)
	local dragging, dragInput, dragStart, startPos, moved = false, nil, nil, nil, false
	handle.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if dragging and onEnd then onEnd(moved) end
					dragging = false
				end
			end)
		end
	end)
	handle.InputChanged:Connect(function(input)
		if IsMove(input) then dragInput = input end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if dragging and input == dragInput then
			local d = input.Position - dragStart
			if d.Magnitude > 5 then moved = true end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

--// Option base (Flags / Callbacks / Config)
local function NewOption(kind, opts, defaultValue)
	local opt = { Type = kind, Value = defaultValue, Callback = opts.Callback, NoSave = opts.NoSave, _listeners = {} }
	function opt:OnChanged(fn) table.insert(self._listeners, fn) end
	function opt:Get() return self.Value end
	function opt:_Fire(...)
		if self.Flag then Library.Flags[self.Flag] = self.Value end
		Safe(self.Callback, ...)
		for _, l in ipairs(self._listeners) do Safe(l, ...) end
	end
	if opts.Flag then
		opt.Flag = opts.Flag
		Library.Options[opts.Flag] = opt
		Library.Flags[opts.Flag] = defaultValue
	end
	return opt
end

--// GUI root
function Library:_EnsureGui()
	if self._gui and self._gui.Parent then return self._gui end
	local gui = Instance.new("ScreenGui")
	gui.Name = RandomString(10)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 999

	local ok = false
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
		ok = pcall(function() gui.Parent = CoreGui end)
	end
	if not ok and type(gethui) == "function" then
		ok = pcall(function() gui.Parent = gethui() end)
	end
	if not ok then
		ok = pcall(function() gui.Parent = CoreGui end)
	end
	if not ok or not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	self._gui = gui

	-- Keybind Handler (einmalig)
	Connect(UserInputService.InputBegan, function(input, gp)
		if Library._listening or gp then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		for _, kb in ipairs(Library._keybinds) do
			if kb.Value and kb.Value == input.KeyCode then kb:_Trigger(true) end
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		for _, kb in ipairs(Library._keybinds) do
			if kb.Value and kb.Value == input.KeyCode and kb.Mode == "Hold" then kb:_Trigger(false) end
		end
	end)

	-- UIScale bei Aenderung der Bildschirmgroesse
	local cam = workspace.CurrentCamera
	if cam then
		Connect(cam:GetPropertyChangedSignal("ViewportSize"), function()
			for _, s in ipairs(Library._scales) do
				pcall(function() s.Scale = GetScale() end)
			end
		end)
	end
	return gui
end

function Library:SetAccent(color)
	self.Accent = color
	for _, fn in ipairs(self._accentFns) do pcall(fn, color) end
end

--// Notify
function Library:Notify(opts)
	if type(opts) == "string" then opts = { Content = opts } end
	opts = opts or {}
	local gui = self:_EnsureGui()
	if not self._notifHolder or not self._notifHolder.Parent then
		self._notifHolder = New("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(280, 500),
			ZIndex = 10, Parent = gui,
		}, {
			New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 8),
			}),
		})
	end
	local card = New("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
		GroupTransparency = 1, Parent = self._notifHolder,
	}, { UICorner(10), UIStroke(Theme.Stroke, 1, 0.2) })
	local bar = New("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Parent = card })
	Accent(bar, "BackgroundColor3")
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -24, 0, 16),
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Text = opts.Title or "Rift", Parent = card,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -24, 0, 30),
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = opts.Content or "", Parent = card,
	})
	Tween(card, { GroupTransparency = 0 }, 0.2)
	task.delay(opts.Duration or 4, function()
		if card and card.Parent then
			local tw = Tween(card, { GroupTransparency = 1 }, 0.25)
			tw.Completed:Wait()
			card:Destroy()
		end
	end)
end

--// Loading Screen
function Library:ShowLoadingScreen(opts)
	opts = opts or {}
	local gui = self:_EnsureGui()
	local dur = opts.Duration or 2
	local steps = opts.Steps or { "Loading..." }
	local logo = Asset(opts.Logo or self.Assets.Logo)

	local card = New("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 230),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 20, Parent = gui,
	}, { UICorner(14), UIStroke(Theme.Stroke, 1, 0.1) })
	AddScale(card)
	New("ImageLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = Asset(self.Assets.Background),
		ImageTransparency = 0.8, ScaleType = Enum.ScaleType.Crop, Parent = card,
	})
	New("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1, Image = logo, ScaleType = Enum.ScaleType.Fit, Parent = card,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 112), Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Theme.Text, Text = opts.Title or "Rift", Parent = card,
	})
	local status = New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 138), Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText, Text = opts.Subtitle or steps[1], Parent = card,
	})
	local track = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176), Size = UDim2.new(1, -60, 0, 6),
		BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = card,
	}, { UICorner(3) })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = track }, { UICorner(3) })
	Accent(fill, "BackgroundColor3")

	Tween(fill, { Size = UDim2.new(1, 0, 1, 0) }, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local n = #steps
	for i = 1, n do
		status.Text = steps[i]
		task.wait(dur / n)
	end
	local tw = Tween(card, { GroupTransparency = 1 }, 0.3)
	tw.Completed:Wait()
	card:Destroy()
end

--// Config System
local function HasFS()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfolder) == "function"
		and type(makefolder) == "function" and type(listfiles) == "function" and type(delfile) == "function"
end

local function ConfigDir() return Library.ConfigFolder .. "/configs" end

local function EnsureFolders()
	if not isfolder(Library.ConfigFolder) then makefolder(Library.ConfigFolder) end
	if not isfolder(ConfigDir()) then makefolder(ConfigDir()) end
end

local function CleanName(name)
	name = tostring(name or "")
	name = name:gsub("[^%w%-_ ]", "")
	name = name:gsub("^%s+", "")
	name = name:gsub("%s+$", "")
	return name
end

function Library:ListConfigs()
	local list = {}
	if not HasFS() then return list end
	pcall(function()
		EnsureFolders()
		for _, file in ipairs(listfiles(ConfigDir())) do
			local name = file:match("([^/\\]+)%.json$")
			if name then table.insert(list, name) end
		end
	end)
	table.sort(list)
	return list
end

function Library:SaveConfig(name)
	name = CleanName(name)
	if name == "" then return false, "Kein Config-Name angegeben" end
	if not HasFS() then return false, "Dein Executor unterstuetzt keine Dateifunktionen" end
	local data = {}
	for flag, opt in pairs(self.Options) do
		if not opt.NoSave and opt.Serialize then
			local ok, val = pcall(opt.Serialize, opt)
			if ok then data[flag] = val end
		end
	end
	local ok, err = pcall(function()
		EnsureFolders()
		writefile(ConfigDir() .. "/" .. name .. ".json", HttpService:JSONEncode(data))
	end)
	if not ok then return false, tostring(err) end
	return true, name
end

function Library:LoadConfig(name)
	name = CleanName(name)
	if name == "" then return false, "Keine Config ausgewaehlt" end
	if not HasFS() then return false, "Dein Executor unterstuetzt keine Dateifunktionen" end
	local path = ConfigDir() .. "/" .. name .. ".json"
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then return false, "Config konnte nicht gelesen werden" end
	for flag, val in pairs(data) do
		local opt = self.Options[flag]
		if opt and opt.Deserialize and not opt.NoSave then
			pcall(opt.Deserialize, opt, val)
		end
	end
	return true, name
end

function Library:DeleteConfig(name)
	name = CleanName(name)
	if name == "" then return false, "Keine Config ausgewaehlt" end
	if not HasFS() then return false, "Dein Executor unterstuetzt keine Dateifunktionen" end
	local ok, err = pcall(function() delfile(ConfigDir() .. "/" .. name .. ".json") end)
	if not ok then return false, tostring(err) end
	return true, name
end

--// Module (Komponenten)
local Module = {}
Module.__index = Module

function Module:_NextOrder(isColor)
	self._order = self._order + 1
	if isColor then return 10000 + self._order end -- Color Picker immer ganz unten
	return self._order
end

function Module:_Row(height, order)
	return New("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = order, Parent = self._content,
	}, { UICorner(8), UIStroke(Theme.Stroke, 1, 0.3) })
end

local function RowLabel(row, text, widthScale)
	return New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(widthScale or 0.5, -12, 0, 36),
		Font = Enum.Font.GothamMedium, Text = text or "", TextColor3 = Theme.Text, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
end

local function SmallButton(parent, text, size, pos, anchor)
	local btn = New("TextButton", {
		AnchorPoint = anchor or Vector2.new(1, 0.5), Position = pos, Size = size,
		BackgroundColor3 = Library.Accent, AutoButtonColor = false, Text = text,
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0, Parent = parent,
	}, { UICorner(6) })
	Accent(btn, "BackgroundColor3")
	btn.MouseEnter:Connect(function() Tween(btn, { BackgroundTransparency = 0.2 }, 0.1) end)
	btn.MouseLeave:Connect(function() Tween(btn, { BackgroundTransparency = 0 }, 0.1) end)
	return btn
end

function Module:AddButton(opts)
	opts = opts or {}
	local row = self:_Row(36, self:_NextOrder())
	RowLabel(row, opts.Name or "Button")
	local btn = SmallButton(row, opts.Text or "Click", UDim2.fromOffset(opts.ButtonWidth or 84, 24), UDim2.new(1, -8, 0, 18))
	btn.MouseButton1Click:Connect(function() Safe(opts.Callback) end)
	local obj = {}
	function obj:SetText(t) btn.Text = t end
	function obj:Fire() Safe(opts.Callback) end
	return obj
end

function Module:AddButtonGroup(opts)
	opts = opts or {}
	local list = opts.Buttons or {}
	local n = math.max(#list, 1)
	local row = self:_Row(36, self:_NextOrder())
	local holder = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0, 24), Parent = row,
	}, { New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, b in ipairs(list) do
		local btn = SmallButton(holder, b.Text or "Button", UDim2.new(1 / n, -math.ceil(6 * (n - 1) / n), 1, 0), UDim2.new(), Vector2.new(0, 0))
		btn.LayoutOrder = i
		btn.MouseButton1Click:Connect(function() Safe(b.Callback) end)
	end
end

function Module:AddToggle(opts)
	opts = opts or {}
	local opt = NewOption("Toggle", opts, opts.Default == true)
	local row = self:_Row(36, self:_NextOrder())
	RowLabel(row, opts.Name or "Toggle", 0.75)
	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 18), Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = row,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local function render(animate)
		local col = opt.Value and Library.Accent or Theme.Stroke
		local pos = opt.Value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		if animate then
			Tween(track, { BackgroundColor3 = col }, 0.15)
			Tween(knob, { Position = pos }, 0.15)
		else
			track.BackgroundColor3 = col
			knob.Position = pos
		end
	end
	OnAccent(function() render(false) end)

	function opt:Set(v, silent)
		self.Value = v and true or false
		render(true)
		if not silent then self:_Fire(self.Value) end
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d == true) end

	local click = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = row })
	click.MouseButton1Click:Connect(function() opt:Set(not opt.Value) end)
	return opt
end

function Module:AddSlider(opts)
	opts = opts or {}
	local min, max = opts.Min or 0, opts.Max or 100
	local inc = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local dec = 0
	local incStr = tostring(inc)
	local dot = incStr:find("%.")
	if dot then dec = #incStr - dot end

	local function round(v)
		v = math.clamp(v, min, max)
		v = math.floor((v - min) / inc + 0.5) * inc + min
		v = math.clamp(v, min, max)
		return tonumber(string.format("%." .. dec .. "f", v))
	end

	local opt = NewOption("Slider", opts, round(opts.Default or min))
	local row = self:_Row(52, self:_NextOrder())
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.6, -12, 0, 30),
		Font = Enum.Font.GothamMedium, Text = opts.Name or "Slider", TextColor3 = Theme.Text, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	local valueLabel = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.4, -12, 0, 30),
		Font = Enum.Font.GothamBold, Text = "", TextColor3 = Theme.SubText, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	local hit = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 31), Size = UDim2.new(1, -24, 0, 16), Parent = row })
	local track = New("Frame", {
		Position = UDim2.new(0, 0, 0.5, -3), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = hit,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = track }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Accent(fill, "BackgroundColor3")
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local function render()
		local a = (max == min) and 0 or (opt.Value - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		valueLabel.Text = tostring(opt.Value) .. suffix
	end
	render()

	function opt:Set(v, silent, force)
		v = round(tonumber(v) or min)
		local changed = v ~= self.Value
		self.Value = v
		render()
		if (changed or force) and not silent then self:_Fire(v) end
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d, false, true) end

	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		opt:Set(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(input)
		if IsPress(input) then dragging = true; fromX(input.Position.X) end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then fromX(input.Position.X) end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if IsPress(input) then dragging = false end
	end)
	return opt
end

function Module:AddDropdown(opts)
	opts = opts or {}
	local multi = opts.Multi == true
	local searchable = opts.Searchable == true
	local values = opts.Values or {}
	local selectedSet = {}
	local opt = NewOption("Dropdown", opts, nil)
	if multi then opt.Value = {} end

	local row = self:_Row(36, self:_NextOrder())
	RowLabel(row, opts.Name or "Dropdown", 0.45)
	local valueLabel = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 0), Size = UDim2.new(0.55, -34, 0, 36),
		Font = Enum.Font.Gotham, Text = "None", TextColor3 = Theme.SubText, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	local arrow = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(16, 36),
		Font = Enum.Font.GothamBold, Text = ">", TextColor3 = Theme.SubText, TextSize = 14, Rotation = 90, Parent = row,
	})
	local listFrame = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 40), Size = UDim2.new(1, -16, 0, 0), Visible = false, Parent = row,
	})
	local search
	if searchable then
		search = New("TextBox", {
			Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.2, BorderSizePixel = 0,
			Font = Enum.Font.Gotham, Text = "", PlaceholderText = "Search...", PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text,
			TextSize = 12, ClearTextOnFocus = false, Parent = listFrame,
		}, { UICorner(6), New("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })
	end
	local scroll = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, searchable and 30 or 0),
		Size = UDim2.new(1, 0, 1, searchable and -30 or 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Accent, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = listFrame,
	}, { New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	Accent(scroll, "ScrollBarImageColor3")

	local buttons = {}
	local function isSelected(v)
		if multi then return selectedSet[v] == true end
		return opt.Value == v
	end
	local function updateText()
		if multi then
			local t = {}
			for _, v in ipairs(values) do if selectedSet[v] then t[#t + 1] = v end end
			opt.Value = t
			valueLabel.Text = #t > 0 and table.concat(t, ", ") or "None"
		else
			valueLabel.Text = opt.Value ~= nil and tostring(opt.Value) or "None"
		end
	end
	local function paint()
		for v, b in pairs(buttons) do
			local sel = isSelected(v)
			b.BackgroundColor3 = sel and Library.Accent or Theme.Element
			b.BackgroundTransparency = sel and 0.55 or 0.1
			b.TextColor3 = sel and Theme.Text or Theme.SubText
		end
	end
	OnAccent(function() paint() end)

	local open = false
	local function listHeight()
		local n = math.min(#values, 5)
		return math.max(n, 1) * 28 + (searchable and 30 or 0)
	end
	local function setOpen(state)
		open = state
		if state then
			listFrame.Size = UDim2.new(1, -16, 0, listHeight())
			listFrame.Visible = true
		end
		Tween(row, { Size = UDim2.new(1, 0, 0, state and (40 + listHeight() + 8) or 36) }, 0.18)
		Tween(arrow, { Rotation = state and -90 or 90 }, 0.18)
		if not state then
			task.delay(0.2, function() if not open then listFrame.Visible = false end end)
		end
	end

	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		buttons = {}
		for i, v in ipairs(values) do
			local b = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.1, BorderSizePixel = 0,
				AutoButtonColor = false, Font = Enum.Font.Gotham, Text = tostring(v), TextSize = 12, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = scroll,
			}, { UICorner(6), New("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })
			buttons[v] = b
			b.MouseButton1Click:Connect(function()
				if multi then
					selectedSet[v] = not selectedSet[v] or nil
					updateText(); paint()
					opt:_Fire(opt.Value)
				else
					opt:Set(v)
					setOpen(false)
				end
			end)
		end
		paint()
	end

	if search then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = search.Text:lower()
			for v, b in pairs(buttons) do
				b.Visible = q == "" or tostring(v):lower():find(q, 1, true) ~= nil
			end
		end)
	end

	function opt:Set(v, silent)
		if multi then
			selectedSet = {}
			if type(v) == "table" then
				for k, val in pairs(v) do
					if type(k) == "number" then selectedSet[val] = true
					elseif val == true then selectedSet[k] = true end
				end
			elseif type(v) == "string" then
				selectedSet[v] = true
			end
		else
			self.Value = v
		end
		updateText(); paint()
		if not silent then self:_Fire(self.Value) end
	end
	function opt:SetValues(newValues, keep)
		values = newValues or {}
		if not keep then
			if multi then
				for k in pairs(selectedSet) do
					if not table.find(values, k) then selectedSet[k] = nil end
				end
			elseif self.Value ~= nil and not table.find(values, self.Value) then
				self.Value = nil
			end
		end
		build(); updateText(); paint()
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d) end

	build()
	local default = opts.Default
	if type(default) == "number" and not multi then default = values[default] end
	if default ~= nil then
		if multi then
			selectedSet = {}
			if type(default) == "table" then
				for k, val in pairs(default) do
					if type(k) == "number" then selectedSet[val] = true elseif val == true then selectedSet[k] = true end
				end
			else
				selectedSet[default] = true
			end
		else
			opt.Value = default
		end
		if opts.Flag then Library.Flags[opts.Flag] = opt.Value end
	end
	updateText(); paint()

	local head = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Text = "", Parent = row })
	head.MouseButton1Click:Connect(function() setOpen(not open) end)
	return opt
end

function Module:AddInput(opts)
	opts = opts or {}
	local opt = NewOption("Input", opts, tostring(opts.Default or ""))
	local row = self:_Row(36, self:_NextOrder())
	RowLabel(row, opts.Name or "Input", 0.4)
	local box = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.new(0.6, -14, 0, 24),
		BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.2, BorderSizePixel = 0, Font = Enum.Font.Gotham,
		Text = opt.Value, PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text,
		TextSize = 12, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	}, { UICorner(6), UIStroke(Theme.Stroke, 1, 0.4), New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if opts.Numeric then
			local cleaned = box.Text:gsub("[^%d%.%-]", "")
			if cleaned ~= box.Text then box.Text = cleaned return end
		end
		opt.Value = box.Text
		if opt.Flag then Library.Flags[opt.Flag] = opt.Value end
		if opts.Live then opt:_Fire(opt.Value) end
	end)
	box.Focused:Connect(function() Tween(box.UIStroke, { Color = Library.Accent, Transparency = 0 }, 0.12) end)
	box.FocusLost:Connect(function(enter)
		Tween(box.UIStroke, { Color = Theme.Stroke, Transparency = 0.4 }, 0.12)
		if not opts.Live then opt:_Fire(opt.Value) end
	end)

	function opt:Set(v, silent)
		v = tostring(v == nil and "" or v)
		box.Text = v
		self.Value = v
		if not silent then self:_Fire(v) end
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d) end
	return opt
end

function Module:AddKeybind(opts)
	opts = opts or {}
	local opt = NewOption("Keybind", opts, opts.Default)
	opt.Mode = opts.Mode or "Press" -- "Press" | "Toggle" | "Hold"
	opt.State = false
	local row = self:_Row(36, self:_NextOrder())
	RowLabel(row, opts.Name or "Keybind", 0.5)
	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.fromOffset(opts.ButtonWidth or 96, 24),
		BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.2, BorderSizePixel = 0, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text, Text = "", Parent = row,
	}, { UICorner(6), UIStroke(Theme.Stroke, 1, 0.4) })
	local function render()
		btn.Text = opt.Value and opt.Value.Name or "None"
	end
	render()

	function opt:Set(key, silent)
		self.Value = key
		if self.Flag then Library.Flags[self.Flag] = key end
		render()
	end
	function opt:_Trigger(down)
		if self.Mode == "Hold" then
			self.State = down
			self:_Fire(down)
		elseif down then
			if self.Mode == "Toggle" then
				self.State = not self.State
				self:_Fire(self.State)
			else
				self:_Fire()
			end
		end
	end
	function opt:Serialize() return self.Value and self.Value.Name or nil end
	function opt:Deserialize(d)
		local ok, key = pcall(function() return Enum.KeyCode[d] end)
		self:Set(ok and key or nil)
	end

	local listenConn
	btn.MouseButton1Click:Connect(function()
		if listenConn then return end
		Library._listening = true
		btn.Text = "..."
		listenConn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listenConn:Disconnect()
				listenConn = nil
				task.defer(function() Library._listening = false end)
				if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
					opt:Set(nil)
				else
					opt:Set(input.KeyCode)
				end
			end
		end)
	end)
	table.insert(Library._keybinds, opt)
	return opt
end

function Module:AddColorPicker(opts)
	opts = opts or {}
	local default = opts.Default or Color3.fromRGB(255, 255, 255)
	local opt = NewOption("ColorPicker", opts, default)
	local h, s, v = default:ToHSV()

	local row = self:_Row(36, self:_NextOrder(true))
	RowLabel(row, opts.Name or "Color", 0.6)
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 9), Size = UDim2.fromOffset(38, 18),
		BackgroundColor3 = default, BorderSizePixel = 0, Parent = row,
	}, { UICorner(5), UIStroke(Theme.Stroke, 1, 0.2) })
	local picker = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 116), Visible = false, Parent = row })
	local sv = New("Frame", {
		Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -52, 0, 100), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Parent = picker,
	}, { UICorner(6) })
	New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sv,
	}, { UICorner(6), New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = sv,
	}, { UICorner(6), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = sv,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), UIStroke(Color3.new(1, 1, 1), 2, 0) })

	local hueKeys = {}
	for i = 0, 6 do table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 1), 1, 1))) end
	local hue = New("Frame", {
		Position = UDim2.new(1, -34, 0, 6), Size = UDim2.fromOffset(24, 100), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = picker,
	}, { UICorner(6), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueKeys) }) })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = hue,
	}, { UICorner(2), UIStroke(Color3.new(0, 0, 0), 1, 0.3) })

	local function apply(fire)
		local c = Color3.fromHSV(h, s, v)
		opt.Value = c
		swatch.BackgroundColor3 = c
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
		hueCursor.Position = UDim2.new(0.5, 0, h, 0)
		if fire then opt:_Fire(c) else if opt.Flag then Library.Flags[opt.Flag] = c end end
	end
	apply(false)

	function opt:Set(c, silent)
		h, s, v = c:ToHSV()
		apply(not silent)
	end
	function opt:Serialize()
		local c = self.Value
		return { R = math.floor(c.R * 255 + 0.5), G = math.floor(c.G * 255 + 0.5), B = math.floor(c.B * 255 + 0.5) }
	end
	function opt:Deserialize(d)
		if type(d) == "table" then self:Set(Color3.fromRGB(d.R or 255, d.G or 255, d.B or 255)) end
	end

	local dragSV, dragHue = false, false
	local function updateSV(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		apply(true)
	end
	local function updateHue(pos)
		h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
		apply(true)
	end
	sv.InputBegan:Connect(function(input) if IsPress(input) then dragSV = true; updateSV(input.Position) end end)
	hue.InputBegan:Connect(function(input) if IsPress(input) then dragHue = true; updateHue(input.Position) end end)
	Connect(UserInputService.InputChanged, function(input)
		if not IsMove(input) then return end
		if dragSV then updateSV(input.Position) elseif dragHue then updateHue(input.Position) end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if IsPress(input) then dragSV = false; dragHue = false end
	end)

	local open = false
	local head = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Text = "", Parent = row })
	head.MouseButton1Click:Connect(function()
		open = not open
		if open then picker.Visible = true end
		Tween(row, { Size = UDim2.new(1, 0, 0, open and 152 or 36) }, 0.18)
		if not open then task.delay(0.2, function() if not open then picker.Visible = false end end) end
	end)
	return opt
end

function Module:AddLabel(text)
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham,
		Text = text or "", TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = self:_NextOrder(), Parent = self._content,
	}, { New("UIPadding", { PaddingLeft = UDim.new(0, 4) }) })
	local obj = {}
	function obj:Set(t) lbl.Text = t end
	return obj
end

function Module:AddParagraph(opts)
	opts = opts or {}
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, LayoutOrder = self:_NextOrder(), Parent = self._content,
	}, {
		UICorner(8), UIStroke(Theme.Stroke, 1, 0.3),
		New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	local title = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.GothamBold,
		Text = opts.Title or "", TextColor3 = Theme.Text, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = frame,
	})
	local content = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham,
		Text = opts.Content or "", TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = frame,
	})
	local obj = {}
	function obj:Set(t, c) if t then title.Text = t end if c then content.Text = c end end
	return obj
end

function Module:AddInfo(opts)
	opts = opts or {}
	local row = self:_Row(36, self:_NextOrder())
	RowLabel(row, opts.Name or "Info", 0.5)
	local val = New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.5, -12, 0, 36),
		Font = Enum.Font.GothamBold, Text = tostring(opts.Value or ""), TextColor3 = Theme.SubText, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	local obj = {}
	function obj:Set(t) val.Text = tostring(t) end
	return obj
end

function Module:AddDivider(text)
	local hasText = text and text ~= ""
	local f = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, hasText and 22 or 8), LayoutOrder = self:_NextOrder(), Parent = self._content,
	})
	if hasText then
		local t = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -4, 0, 18), Font = Enum.Font.GothamBold,
			Text = string.upper(text), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
		})
		Accent(t, "TextColor3")
	end
	New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = f,
	})
end

--// Window
local Window = {}
Window.__index = Window

function Window:Notify(opts) Library:Notify(opts) end

function Window:Minimize()
	if self._minimized then return end
	self._minimized = true
	self._main.Visible = false
	if self._open then self._open._frame.Visible = false end
	self._circle.Visible = true
end

function Window:Maximize()
	if not self._minimized then return end
	self._minimized = false
	self._circle.Visible = false
	self._main.Visible = true
	if self._open then self._open._frame.Visible = true end
end

function Window:Toggle()
	if self._minimized then self:Maximize() else self:Minimize() end
end

function Window:_OpenModule(mod)
	if self._open == mod and mod._frame.Visible then
		mod._frame.Visible = false
		self._open = nil
	else
		for _, m in ipairs(self._allModules) do m._frame.Visible = false end
		if not mod._moved then
			local sc = GetScale()
			local mp = self._main.Position
			mod._frame.Position = UDim2.new(mp.X.Scale, mp.X.Offset + (self._mainWidth + 10) * sc, mp.Y.Scale, mp.Y.Offset)
		end
		mod._frame.Visible = true
		self._open = mod
	end
	for _, m in ipairs(self._allModules) do
		m._active = (self._open == m)
		if m._refreshBtn then m._refreshBtn() end
	end
end

function Window:AddModule(opts)
	if type(opts) == "string" then opts = { Name = opts } end
	opts = opts or {}
	local window = self
	local gui = Library._gui
	local mod = setmetatable({ Name = opts.Name or "Module", _order = 0, _active = false }, Module)

	-- Modul-Fenster
	local frame = New("Frame", {
		Name = RandomString(8), Size = UDim2.fromOffset(340, 120), Position = UDim2.new(0.5, 0, 0.5, -200),
		BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, Visible = false, Active = true,
		ZIndex = 3, Parent = gui,
	}, { UICorner(12) })
	AddScale(frame)
	local stroke = UIStroke(Theme.Stroke, 1.5, 0)
	stroke.Parent = frame
	Accent(stroke, "Color")
	New("ImageLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = Asset(Library.Assets.Background), ImageTransparency = 0.86,
		ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Parent = frame,
	}, { UICorner(12) })

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), ZIndex = 2, Parent = frame })
	New("ImageLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 9), Size = UDim2.fromOffset(24, 24), Image = Asset(Library.Assets.Logo),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = header,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -90, 1, 0), Font = Enum.Font.GothamBold,
		Text = mod.Name, TextColor3 = Theme.Text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = header,
	})
	local close = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.2, BorderSizePixel = 0, AutoButtonColor = false, Text = "x",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text, ZIndex = 2, Parent = header,
	}, { UICorner(6) })
	close.MouseEnter:Connect(function() Tween(close, { BackgroundColor3 = Color3.fromRGB(150, 40, 70) }, 0.1) end)
	close.MouseLeave:Connect(function() Tween(close, { BackgroundColor3 = Theme.Element }, 0.1) end)
	close.MouseButton1Click:Connect(function() window:_OpenModule(mod) end)
	New("Frame", {
		Position = UDim2.new(0, 10, 0, 42), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, ZIndex = 2, Parent = frame,
	})
	MakeDraggable(header, frame, function(moved) if moved then mod._moved = true end end)

	local content = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 1, -46),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Library.Accent, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2, Parent = frame,
	})
	Accent(content, "ScrollBarImageColor3")
	local layout = New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	New("UIPadding", {
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = content,
	})
	local function resize()
		local k = frame.AbsoluteSize.X / 340
		if k <= 0 then k = 1 end
		local h = layout.AbsoluteContentSize.Y / k + 14 + 46
		frame.Size = UDim2.fromOffset(340, math.clamp(h, 110, 460))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	task.defer(resize)

	mod._frame = frame
	mod._content = content
	table.insert(self._allModules, mod)

	-- Button in der Modul-Liste (Hauptfenster)
	if not opts.Hidden then
		self._count = self._count + 1
		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.2, BorderSizePixel = 0,
			AutoButtonColor = false, Text = "", LayoutOrder = self._count, Parent = self._list,
		}, { UICorner(8) })
		local bstroke = UIStroke(Theme.Stroke, 1, 0.3)
		bstroke.Parent = btn
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.GothamMedium,
			Text = mod.Name, TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn,
		})
		New("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(14, 38),
			Font = Enum.Font.GothamBold, Text = ">", TextColor3 = Theme.SubText, TextSize = 14, Parent = btn,
		})
		btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.ElementHover }, 0.1) end)
		btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Element }, 0.1) end)
		btn.MouseButton1Click:Connect(function() window:_OpenModule(mod) end)
		mod._btn = btn
		mod._refreshBtn = function()
			bstroke.Color = mod._active and Library.Accent or Theme.Stroke
			bstroke.Transparency = mod._active and 0 or 0.3
		end
		OnAccent(function() mod._refreshBtn() end)
		table.insert(self._listed, mod)
	end
	return mod
end

function Library:CreateWindow(opts)
	opts = opts or {}
	local gui = self:_EnsureGui()
	if opts.Accent then self:SetAccent(opts.Accent) end
	if opts.Logo then self.Assets.Logo = Asset(opts.Logo) end
	if opts.Background then self.Assets.Background = Asset(opts.Background) end
	self.ConfigFolder = opts.ConfigFolder or self.ConfigFolder

	local win = setmetatable({
		_allModules = {}, _listed = {}, _count = 0, _minimized = false, _mainWidth = 300,
		Version = opts.Version or "1.0.0",
	}, Window)
	table.insert(self._windows, win)

	local sc = GetScale()
	local main = New("Frame", {
		Name = RandomString(8), Size = UDim2.fromOffset(300, 440), Position = UDim2.new(0.5, -325 * sc, 0.5, -220 * sc),
		BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, Active = true, ZIndex = 2, Parent = gui,
	}, { UICorner(12) })
	AddScale(main)
	local mstroke = UIStroke(Theme.Stroke, 1.5, 0)
	mstroke.Parent = main
	Accent(mstroke, "Color")
	New("ImageLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = Asset(self.Assets.Background), ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Parent = main,
	}, {
		UICorner(12),
		New("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.45, 0.1), NumberSequenceKeypoint.new(1, 0) }),
		}),
	})
	win._main = main

	-- Header
	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), ZIndex = 2, Parent = main })
	New("ImageLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 10), Size = UDim2.fromOffset(32, 32), Image = Asset(self.Assets.Logo),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = header,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 52, 0, 0), Size = UDim2.new(1, -160, 1, 0), Font = Enum.Font.GothamBold,
		Text = opts.Title or "Rift CMD's", TextColor3 = Theme.Text, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = header,
	})
	local settingsBtn = SmallButton(header, "Settings", UDim2.fromOffset(66, 26), UDim2.new(1, -46, 0.5, 0))
	settingsBtn.ZIndex = 2
	local minBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.2, BorderSizePixel = 0, AutoButtonColor = false, Text = "-",
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, ZIndex = 2, Parent = header,
	}, { UICorner(6) })
	minBtn.MouseEnter:Connect(function() Tween(minBtn, { BackgroundColor3 = Theme.ElementHover }, 0.1) end)
	minBtn.MouseLeave:Connect(function() Tween(minBtn, { BackgroundColor3 = Theme.Element }, 0.1) end)
	New("Frame", {
		Position = UDim2.new(0, 10, 0, 52), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, ZIndex = 2, Parent = main,
	})
	MakeDraggable(header, main)

	-- Suche
	local searchBox = New("TextBox", {
		Position = UDim2.new(0, 12, 0, 62), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.2,
		BorderSizePixel = 0, Font = Enum.Font.Gotham, Text = "", PlaceholderText = "Search Module", PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 2, Parent = main,
	}, { UICorner(8), UIStroke(Theme.Stroke, 1, 0.3), New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	local sstroke = searchBox:FindFirstChildOfClass("UIStroke")
	searchBox.Focused:Connect(function() Tween(sstroke, { Color = Library.Accent, Transparency = 0 }, 0.12) end)
	searchBox.FocusLost:Connect(function() Tween(sstroke, { Color = Theme.Stroke, Transparency = 0.3 }, 0.12) end)

	-- Modul-Liste
	local list = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 12, 0, 106), Size = UDim2.new(1, -24, 1, -138),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = self.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2, Parent = main,
	}, {
		New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	})
	Accent(list, "ScrollBarImageColor3")
	win._list = list

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = searchBox.Text:lower()
		for _, m in ipairs(win._listed) do
			if m._btn then m._btn.Visible = q == "" or m.Name:lower():find(q, 1, true) ~= nil end
		end
	end)

	New("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -6), Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.Gotham, Text = "Rift  -  " .. tostring(win.Version), TextColor3 = Theme.SubText, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = main,
	})

	-- Runder Button zum Oeffnen (nur sichtbar wenn minimiert, auch fuer Mobile)
	local circle = New("ImageButton", {
		Name = RandomString(8), Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, 24, 0.5, -29), BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0, AutoButtonColor = false, Image = Asset(self.Assets.Logo), ScaleType = Enum.ScaleType.Fit, Visible = false,
		ZIndex = 4, Parent = gui,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), New("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	AddScale(circle)
	local cstroke = UIStroke(Theme.Stroke, 2, 0)
	cstroke.Parent = circle
	Accent(cstroke, "Color")
	win._circle = circle
	MakeDraggable(circle, circle, function(moved)
		if not moved then win:Maximize() end
	end)

	minBtn.MouseButton1Click:Connect(function() win:Minimize() end)

	-- Settings Modul
	local settings = win:AddModule({ Name = "Settings", Hidden = true })
	win._settings = settings
	settingsBtn.MouseButton1Click:Connect(function() win:_OpenModule(settings) end)

	settings:AddInfo({ Name = "GUI Version", Value = win.Version })
	settings:AddInfo({ Name = "Library Version", Value = "v" .. self.Version })
	settings:AddDivider("Interface")
	settings:AddKeybind({
		Name = "Minimize Key", Default = opts.MenuKey or Enum.KeyCode.RightShift, Mode = "Press", NoSave = true,
		Callback = function() win:Toggle() end,
	})

	settings:AddDivider("Configs")
	local nameInput = settings:AddInput({ Name = "Config Name", Placeholder = "", NoSave = true })
	local cfgDropdown = settings:AddDropdown({ Name = "Config List", Values = self:ListConfigs(), NoSave = true })
	local function refreshConfigs(select)
		cfgDropdown:SetValues(Library:ListConfigs())
		cfgDropdown:Set(select, true)
	end
	local function pickName()
		local n = CleanName(nameInput.Value)
		if n ~= "" then return n end
		return cfgDropdown.Value
	end
	local function report(ok, msg, okText)
		if ok then
			Library:Notify({ Title = "Config", Content = okText .. ": " .. tostring(msg) })
		else
			Library:Notify({ Title = "Config", Content = tostring(msg) })
		end
	end
	settings:AddButtonGroup({
		Buttons = {
			{ Text = "Save", Callback = function()
				local n = pickName()
				local ok, msg = Library:SaveConfig(n)
				report(ok, msg, "Gespeichert")
				if ok then refreshConfigs(msg) end
			end },
			{ Text = "Load", Callback = function()
				local ok, msg = Library:LoadConfig(pickName())
				report(ok, msg, "Geladen")
			end },
			{ Text = "Delete", Callback = function()
				local ok, msg = Library:DeleteConfig(pickName())
				report(ok, msg, "Geloescht")
				if ok then refreshConfigs(nil) end
			end },
			{ Text = "Refresh", Callback = function() refreshConfigs(cfgDropdown.Value) end },
		},
	})
	settings:AddDivider("Menu")
	settings:AddButton({ Name = "Unload GUI", Text = "Unload", Callback = function() Library:Unload() end })
	settings:AddColorPicker({
		Name = "Accent Color", Default = self.Accent, NoSave = true,
		Callback = function(c) Library:SetAccent(c) end,
	})

	return win
end

function Library:Unload()
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	self._conns = {}
	if self._gui then pcall(function() self._gui:Destroy() end) end
	self._gui = nil
	self._notifHolder = nil
	self._keybinds = {}
	self._accentFns = {}
	self._scales = {}
	self._windows = {}
	self.Flags = {}
	self.Options = {}
	if genv.RiftLib == self then genv.RiftLib = nil end
end

genv.RiftLib = Library
return Library
