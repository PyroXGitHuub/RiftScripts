--[[
	RiftLib  ·  Admin Panel GUI Library (Rift Scripts)
	------------------------------------------------------------
	Optik im Stil der PyroX GUI Library:
	  - animierter Farbverlauf am Rand (dreht im Uhrzeigersinn)
	  - Waifu-Hintergrund mit Abdunklung + Glow
	  - mehrere Modul-Fenster gleichzeitig offen

	API:
	  Library:ShowLoadingScreen({ Title, Steps, Duration })
	  Library:CreateWindow({ Title, Version, MenuKey, ConfigFolder, Accent, Logo, Background }) -> Window
	  Window:AddModule({ Name })            -> Module   (eigenes Fenster)
	  Window:OpenModule(name|mod) / CloseModule / ToggleModule / CloseAll
	  Window:Minimize() / Maximize() / Toggle()

	  Module:AddButton({ Name, Text, Callback })
	  Module:AddButtonGroup({ Buttons = { { Text, Callback, Style }, ... } })   Style: "outline" | "filled" | "plain" | "danger"
	  Module:AddToggle({ Name, Flag, Default, Callback })
	  Module:AddToggleWithKey({ Name, Flag, Default, Key, Callback })
	  Module:AddSlider({ Name, Flag, Min, Max, Default, Increment, Suffix, Callback })
	  Module:AddDropdown({ Name, Flag, Values, Default, Multi, Searchable, Special = "Player", Callback })
	  Module:AddSelector({ Name, Flag, Values, Default, Callback })      -- z.B. On | Off
	  Module:AddInput({ Name, Flag, Default, Placeholder, Numeric, Live, Callback })
	  Module:AddKeybind({ Name, Flag, Default, Mode = "Press"|"Toggle"|"Hold", Callback })
	  Module:AddColorPicker({ Name, Flag, Default, Callback })          -- landet automatisch ganz unten
	  Module:AddLabel(text) / AddParagraph({ Title, Content }) / AddInfo({ Name, Value }) / AddDivider(text)

	  Library:Notify({ Title, Content, Duration })
	  Library:SaveConfig(name) / LoadConfig(name) / DeleteConfig(name) / ListConfigs()
	  Library:SetAccent(Color3) / Library:Unload()
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
local RunService = cloneref(game:GetService("RunService"))
local TextService = cloneref(game:GetService("TextService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local LocalPlayer = Players.LocalPlayer

--// ==========================================
--// LIBRARY
--// ==========================================
local Library = {
	Version = "2.0.0",
	Flags = {},
	Options = {},
	Accent = Color3.fromRGB(150, 90, 255),
	ConfigFolder = "RiftLib",
	StrokeSpeed = 50, -- Grad pro Sekunde (Rand-Verlauf)
	Animations = true, -- alle UI-Animationen an/aus
	MobileMode = nil, -- nil = auto, true/false = erzwingen
	IsMobile = false,
	Assets = {
		Logo = "rbxassetid://75876733222469",
		Background = "rbxassetid://85708246103612",
	},
	BackgroundTint = Color3.fromRGB(120, 115, 135),
	_conns = {},
	_accentFns = {},
	_keybinds = {},
	_scales = {},
	_grads = {},
	_rot = 0,
	_base = 1,
	_z = 10,
	_listening = false,
	_windows = {},
}

local Theme = {
	Background = Color3.fromRGB(10, 10, 14),
	Panel = Color3.fromRGB(16, 16, 22),
	Element = Color3.fromRGB(20, 20, 28),
	ElementAlt = Color3.fromRGB(30, 30, 40),
	Hover = Color3.fromRGB(42, 42, 56),
	Stroke = Color3.fromRGB(48, 48, 62),
	Off = Color3.fromRGB(42, 42, 54),
	Text = Color3.fromRGB(240, 240, 248),
	SubText = Color3.fromRGB(165, 165, 182),
	Danger = Color3.fromRGB(220, 70, 80),
	DangerHover = Color3.fromRGB(90, 30, 38),
}
Library.Theme = Theme

local Font = Enum.Font.GothamMedium
local FontBold = Enum.Font.GothamBold
local ROW = 34

--// ==========================================
--// HELFER
--// ==========================================
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

local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function Round() return New("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function Stroke(color, thickness, transparency)
	return New("UIStroke", {
		Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
local function Pad(l, r, t, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
	})
end
local function Shine(rot)
	return New("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 195)), Rotation = rot or 90 })
end

local function Tween(inst, props, t, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function Lighten(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end
local function ContrastText(c)
	local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	if l > 0.62 then return Color3.fromRGB(18, 18, 24) end
	return Color3.new(1, 1, 1)
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

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function ClickFlash(btn)
	if Library.Animations == false then return end
	local sc = btn:FindFirstChild("ClickScale") or New("UIScale", { Name = "ClickScale", Parent = btn })
	sc.Scale = 0.93
	Tween(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
end

local function DetectMobile()
	if Library.MobileMode ~= nil then return Library.MobileMode == true end
	local ok, platform = pcall(function() return UserInputService:GetPlatform() end)
	if ok and platform then
		if platform == Enum.Platform.Android or platform == Enum.Platform.IOS then return true end
	end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function ComputeScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	if Library.IsMobile then
		return math.clamp(math.min((vp.X - 24) / 720, (vp.Y - 60) / 470), 0.45, 1)
	end
	return math.clamp(math.min((vp.X - 40) / 1000, (vp.Y - 40) / 560), 0.6, 1)
end

local function AddScale(frame)
	local s = New("UIScale", { Scale = Library._base, Parent = frame })
	table.insert(Library._scales, s)
	return s
end

-- Animierter Rand (Farbverlauf dreht sich im Uhrzeigersinn)
local function AnimatedStroke(obj, thickness)
	local st = New("UIStroke", {
		Color = Color3.new(1, 1, 1), Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = obj,
	})
	local g = New("UIGradient", { Rotation = Library._rot, Parent = st })
	OnAccent(function(c)
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(0.5, Theme.Stroke),
			ColorSequenceKeypoint.new(1, c),
		})
	end)
	table.insert(Library._grads, g)
	return st, g
end

-- Hintergrund (Waifu + Abdunklung + Glow)
local function Backdrop(frame, imageTransparency, shadeKeys, shadeRotation)
	New("ImageLabel", {
		Name = "Mascot", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Asset(Library.Assets.Background),
		ImageColor3 = Library.BackgroundTint, ImageTransparency = imageTransparency, ScaleType = Enum.ScaleType.Crop,
		ZIndex = 0, Parent = frame,
	}, { Corner(10) })
	New("Frame", {
		Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BorderSizePixel = 0, ZIndex = 1, Parent = frame,
	}, { Corner(10), New("UIGradient", { Rotation = shadeRotation or 0, Transparency = NumberSequence.new(shadeKeys) }) })
	local glow = New("Frame", {
		Name = "Glow", Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0, ZIndex = 1, Parent = frame,
	}, {
		Corner(10),
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.82) }) }),
	})
	Accent(glow, "BackgroundColor3")
end

local function Separator(parent, y)
	local sep = New("Frame", {
		Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, y), BorderSizePixel = 0, ZIndex = 3, Parent = parent,
	}, {
		New("UIGradient", { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1),
		}) }),
	})
	Accent(sep, "BackgroundColor3")
	return sep
end

local Ripple -- wird weiter unten gesetzt

local function HoverBg(btn, getBase, getHover)
	btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = getHover() }, 0.15) end)
	btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = getBase() }, 0.15) end)
end

-- Button in verschiedenen Styles
local function MakeButton(parent, text, style, props)
	style = style or "outline"
	local btn = New("TextButton", {
		AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Theme.ElementAlt, Font = FontBold, Text = text,
		TextSize = 12, TextColor3 = Theme.Text, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	}, { Corner(5) })
	for k, v in pairs(props or {}) do btn[k] = v end

	if style == "filled" then
		Shine().Parent = btn
		OnAccent(function(c) btn.BackgroundColor3 = c; btn.TextColor3 = ContrastText(c) end)
		HoverBg(btn, function() return Library.Accent end, function() return Lighten(Library.Accent, 0.15) end)
	elseif style == "danger" then
		Stroke(Theme.Danger, 1, 0.3).Parent = btn
		HoverBg(btn, function() return Theme.ElementAlt end, function() return Theme.DangerHover end)
	elseif style == "plain" then
		Stroke(Theme.Stroke, 1, 0.3).Parent = btn
		HoverBg(btn, function() return Theme.ElementAlt end, function() return Theme.Hover end)
	else -- outline (Akzent-Rand, Hover füllt)
		local st = Stroke(Library.Accent, 1, 0.35)
		st.Parent = btn
		Accent(st, "Color")
		btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundColor3 = Library.Accent, TextColor3 = ContrastText(Library.Accent) }, 0.15)
		end)
		btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundColor3 = Theme.ElementAlt, TextColor3 = Theme.Text }, 0.15)
		end)
	end
	btn.MouseButton1Click:Connect(function() ClickFlash(btn) end)
	Ripple(btn)
	btn.Parent = parent
	return btn
end

--// ==========================================
--// ANIMATIONEN
--// ==========================================
local function Anim() return Library.Animations ~= false end

-- Ripple beim Klicken (Kreis breitet sich vom Klickpunkt aus)
function Ripple(btn)
	btn.ClipsDescendants = true
	btn.InputBegan:Connect(function(input)
		if not IsPress(input) or not Anim() then return end
		local abs, size = btn.AbsolutePosition, btn.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		local rx = math.clamp((input.Position.X - abs.X) / size.X, 0, 1)
		local ry = math.clamp((input.Position.Y - abs.Y) / size.Y, 0, 1)
		local circle = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rx, ry), Size = UDim2.fromScale(0, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
			BorderSizePixel = 0, ZIndex = btn.ZIndex + 5, Parent = btn,
		}, { Round() })
		Tween(circle, { Size = UDim2.fromScale(2.4, 2.4), BackgroundTransparency = 1 }, 0.55, Enum.EasingStyle.Quad)
		task.delay(0.6, function() circle:Destroy() end)
	end)
end

-- Einblenden: merkt sich die echten Transparenzen und blendet von unsichtbar dorthin
local fadeCache = setmetatable({}, { __mode = "k" })
local function FadeTargets(root)
	local out = {}
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, d in ipairs(list) do
		local c = fadeCache[d]
		if not c then
			c = {}
			if d:IsA("GuiObject") then c.BackgroundTransparency = d.BackgroundTransparency end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then c.TextTransparency = d.TextTransparency end
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then c.ImageTransparency = d.ImageTransparency end
			if d:IsA("UIStroke") then c.Transparency = d.Transparency end
			fadeCache[d] = c
		end
		if next(c) then out[#out + 1] = { d, c } end
	end
	return out
end
local function FadeIn(root, t, delay)
	if not Anim() then return end
	local targets = FadeTargets(root)
	for _, p in ipairs(targets) do
		for k in pairs(p[2]) do p[1][k] = 1 end
	end
	task.delay(delay or 0, function()
		for _, p in ipairs(targets) do
			if p[1].Parent then Tween(p[1], p[2], t or 0.3, Enum.EasingStyle.Quad) end
		end
	end)
end

-- Elemente eines Containers nacheinander einblenden
local function Stagger(container, step, t)
	if not Anim() then return end
	local kids = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible then table.insert(kids, c) end
	end
	table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i, c in ipairs(kids) do
		FadeIn(c, t or 0.3, math.min(i - 1, 14) * (step or 0.035))
	end
end

-- Pop-Animation beim Öffnen/Schließen von Fenstern
local popToken = setmetatable({}, { __mode = "k" })
local function PopIn(frame, slide)
	popToken[frame] = (popToken[frame] or 0) + 1
	local s = frame:FindFirstChildOfClass("UIScale")
	frame.Visible = true
	if not Anim() then
		if s then s.Scale = Library._base end
		return
	end
	if s then
		s.Scale = Library._base * 0.9
		Tween(s, { Scale = Library._base }, 0.35, Enum.EasingStyle.Back)
	end
	if slide then
		local final = frame.Position
		frame.Position = final + UDim2.fromOffset(slide.X, slide.Y)
		Tween(frame, { Position = final }, 0.4, Enum.EasingStyle.Quint)
	end
end
local function PopOut(frame)
	popToken[frame] = (popToken[frame] or 0) + 1
	local my = popToken[frame]
	local s = frame:FindFirstChildOfClass("UIScale")
	if not s or not Anim() then frame.Visible = false return end
	local tw = Tween(s, { Scale = Library._base * 0.9 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw.Completed:Connect(function()
		if popToken[frame] == my then
			frame.Visible = false
			s.Scale = Library._base
		end
	end)
end

-- Ziehen (Maus + Touch)
local function MakeDraggable(handle, target, onMove, onEnd)
	local dragging, dragInput, dragStart, startPos, moved = false, nil, nil, nil, false
	handle.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			moved = false
			dragStart = input.Position
			startPos = target.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					conn:Disconnect()
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
			if d.Magnitude > 6 then moved = true end
			if moved then
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
				if onMove then onMove() end
			end
		end
	end)
end

-- Auf Tastendruck warten (für Keybinds)
local activeListen
local function ListenKey(btn, cb)
	if activeListen then activeListen:Disconnect() activeListen = nil end
	Library._listening = true
	btn.Text = "..."
	activeListen = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		activeListen:Disconnect()
		activeListen = nil
		task.defer(function() Library._listening = false end)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
			cb(nil)
		else
			cb(input.KeyCode)
		end
	end)
end

--// ==========================================
--// OPTIONEN (Flags / Callbacks / Config)
--// ==========================================
local function NewOption(kind, opts, defaultValue)
	local opt = { Type = kind, Value = defaultValue, Callback = opts.Callback, NoSave = opts.NoSave, _listeners = {} }
	function opt:OnChanged(fn) table.insert(self._listeners, fn) end
	function opt:Get() return self.Value end
	function opt:SetVisible(v) if self._row then self._row.Visible = v end end
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

--// ==========================================
--// GUI ROOT
--// ==========================================
function Library:_EnsureGui()
	if self._gui and self._gui.Parent then return self._gui end
	self.IsMobile = DetectMobile()
	self._base = ComputeScale()

	local gui = Instance.new("ScreenGui")
	gui.Name = RandomString(10)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999

	local ok = false
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
		ok = pcall(function() gui.Parent = CoreGui end)
	end
	if not ok and type(gethui) == "function" then
		ok = pcall(function() gui.Parent = gethui() end)
	end
	if not ok then ok = pcall(function() gui.Parent = CoreGui end) end
	if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	self._gui = gui

	-- Keybinds
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

	-- Rand-Verlauf drehen (im Uhrzeigersinn)
	Connect(RunService.RenderStepped, function(dt)
		Library._rot = (Library._rot + dt * Library.StrokeSpeed) % 360
		local grads = Library._grads
		for i = #grads, 1, -1 do
			local g = grads[i]
			if g.Parent then g.Rotation = Library._rot else table.remove(grads, i) end
		end
	end)

	-- Skalierung bei Bildschirmänderung
	local cam = workspace.CurrentCamera
	if cam then
		Connect(cam:GetPropertyChangedSignal("ViewportSize"), function()
			Library._base = ComputeScale()
			for _, s in ipairs(Library._scales) do pcall(function() s.Scale = Library._base end) end
		end)
	end
	return gui
end

function Library:SetAccent(color)
	self.Accent = color
	for _, fn in ipairs(self._accentFns) do pcall(fn, color) end
end

--// ==========================================
--// NOTIFY
--// ==========================================
function Library:Notify(opts)
	if type(opts) == "string" then opts = { Content = opts } end
	opts = opts or {}
	local gui = self:_EnsureGui()
	local duration = opts.Duration or 3.5
	if not self._notifHolder or not self._notifHolder.Parent then
		self._notifHolder = New("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(290, 600), ZIndex = 100000, Parent = gui,
		}, { New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) }) })
	end
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), ZIndex = 1000, Parent = self._notifHolder })
	local card = New("Frame", {
		Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(310, 0), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.06,
		BorderSizePixel = 0, ZIndex = 1000, Parent = holder,
	}, { Corner(8), Stroke(Theme.Stroke, 1, 0.1) })
	local bar = New("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8), BorderSizePixel = 0, ZIndex = 1001, Parent = card }, { Corner(2) })
	Accent(bar, "BackgroundColor3")
	New("ImageLabel", {
		Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 18, 0.5, -12), BackgroundTransparency = 1, Image = Asset(self.Assets.Logo),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 1001, Parent = card,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -60, 0, 16), Font = FontBold, TextSize = 13,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Text = opts.Title or "Rift", ZIndex = 1001, Parent = card,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 25), Size = UDim2.new(1, -60, 0, 26), Font = Font, TextSize = 12,
		TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Text = opts.Content or "", ZIndex = 1001, Parent = card,
	})
	local timer = New("Frame", { Size = UDim2.new(1, -16, 0, 2), Position = UDim2.new(0, 8, 1, -4), BorderSizePixel = 0, ZIndex = 1001, Parent = card }, { Corner(1) })
	Accent(timer, "BackgroundColor3")

	Tween(card, { Position = UDim2.fromOffset(0, 0) }, 0.45, Enum.EasingStyle.Back)
	Tween(timer, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
	task.delay(duration, function()
		if not card.Parent then return end
		local tw = Tween(card, { Position = UDim2.fromOffset(310, 0) }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Wait()
		holder:Destroy()
	end)
end

--// ==========================================
--// LADEBILDSCHIRM
--// ==========================================
function Library:ShowLoadingScreen(opts)
	opts = opts or {}
	local gui = self:_EnsureGui()
	local dur = opts.Duration or 2
	local steps = opts.Steps or { "Loading Interface..." }

	local frame = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 150),
		BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 200000, Parent = gui,
	}, { Corner(12) })
	AddScale(frame)
	AnimatedStroke(frame, 1.5)
	Backdrop(frame, 0.55, { NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.45) }, 0)

	local logoBox = New("Frame", {
		Size = UDim2.fromOffset(118, 118), Position = UDim2.new(0, 16, 0.5, -59), BackgroundColor3 = Theme.Panel, ZIndex = 3, Parent = frame,
	}, { Corner(10) })
	local ls = Stroke(self.Accent, 1.5, 0.2)
	ls.Parent = logoBox
	Accent(ls, "Color")
	New("ImageLabel", {
		Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Image = Asset(opts.Logo or self.Assets.Logo),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = logoBox,
	})
	local titleText = opts.Title or "Rift"
	local title = New("TextLabel", {
		Size = UDim2.new(1, -166, 0, 24), Position = UDim2.fromOffset(150, 30), BackgroundTransparency = 1, Font = FontBold,
		Text = titleText, TextColor3 = Theme.Text, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = frame,
	})
	if Anim() then
		-- Schreibmaschinen-Effekt
		title.MaxVisibleGraphemes = 0
		task.spawn(function()
			for i = 1, #titleText do
				if not title.Parent then return end
				title.MaxVisibleGraphemes = i
				task.wait(0.045)
			end
			title.MaxVisibleGraphemes = -1
		end)
		-- Logo "atmet"
		local ls2 = New("UIScale", { Parent = logoBox })
		task.spawn(function()
			while logoBox.Parent do
				Tween(ls2, { Scale = 1.05 }, 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
				if not logoBox.Parent then break end
				Tween(ls2, { Scale = 1 }, 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
			end
		end)
	end
	local status = New("TextLabel", {
		Size = UDim2.new(1, -166, 0, 18), Position = UDim2.fromOffset(150, 56), BackgroundTransparency = 1, Font = Font,
		Text = steps[1], TextColor3 = Theme.SubText, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = frame,
	})
	local barBg = New("Frame", {
		Size = UDim2.new(1, -166, 0, 6), Position = UDim2.fromOffset(150, 98), BackgroundColor3 = Theme.Off, BorderSizePixel = 0, ZIndex = 3, Parent = frame,
	}, { Corner(3) })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 3, Parent = barBg }, { Corner(3), Shine(0) })
	Accent(fill, "BackgroundColor3")
	local percent = New("TextLabel", {
		Size = UDim2.new(1, -166, 0, 16), Position = UDim2.fromOffset(150, 110), BackgroundTransparency = 1, Font = FontBold, Text = "0%",
		TextColor3 = Lighten(self.Accent, 0.4), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = frame,
	})

	PopIn(frame, Vector2.new(0, 14))
	local tw = Tween(fill, { Size = UDim2.new(1, 0, 1, 0) }, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local start = os.clock()
	while tw.PlaybackState == Enum.PlaybackState.Playing or tw.PlaybackState == Enum.PlaybackState.Begin do
		local p = math.clamp((os.clock() - start) / dur, 0, 1)
		percent.Text = math.floor(fill.Size.X.Scale * 100) .. "%"
		status.Text = steps[math.clamp(math.floor(p * #steps) + 1, 1, #steps)]
		task.wait()
	end
	percent.Text = "100%"
	status.Text = opts.FinishText or "Finished!"
	task.wait(0.4)
	PopOut(frame)
	task.wait(0.2)
	frame:Destroy()
end

--// ==========================================
--// CONFIG SYSTEM
--// ==========================================
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
	name = name:gsub("%.json$", "")
	name = name:gsub("[^%w%-_ ]", "")
	name = name:match("^%s*(.-)%s*$") or ""
	return name
end

function Library:ListConfigs()
	local list = {}
	if not HasFS() then return list end
	pcall(function()
		EnsureFolders()
		for _, file in ipairs(listfiles(ConfigDir())) do
			local n = tostring(file):match("([^/\\]+)%.json$")
			if n then table.insert(list, n) end
		end
	end)
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

function Library:SaveConfig(name)
	name = CleanName(name)
	if name == "" then return false, "Enter a config name first" end
	if not HasFS() then return false, "Your executor doesn't support file functions" end
	local data = {}
	for flag, opt in pairs(self.Options) do
		if not opt.NoSave and opt.Serialize then
			local ok, val = pcall(opt.Serialize, opt)
			if ok and val ~= nil then data[flag] = val end
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
	if name == "" then return false, "Select or enter a config first" end
	if not HasFS() then return false, "Your executor doesn't support file functions" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(ConfigDir() .. "/" .. name .. ".json")) end)
	if not ok or type(data) ~= "table" then return false, 'Config "' .. name .. '" not found' end
	for flag, val in pairs(data) do
		local opt = self.Options[flag]
		if opt and opt.Deserialize and not opt.NoSave then pcall(opt.Deserialize, opt, val) end
	end
	return true, name
end

function Library:DeleteConfig(name)
	name = CleanName(name)
	if name == "" then return false, "Select a config first" end
	if not HasFS() then return false, "Your executor doesn't support file functions" end
	local ok, err = pcall(function() delfile(ConfigDir() .. "/" .. name .. ".json") end)
	if not ok then return false, tostring(err) end
	return true, name
end

--// ==========================================
--// MODULE (Elemente)
--// ==========================================
local Module = {}
Module.__index = Module

function Module:_NextOrder(isColor)
	self._order = self._order + 1
	if isColor then return 100000 + self._order end -- Color Picker immer ganz unten
	return self._order
end

function Module:_Row(height, order)
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, height or ROW), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.3, BorderSizePixel = 0,
		ClipsDescendants = true, LayoutOrder = order, ZIndex = 3, Parent = self._content,
	}, { Corner(6) })
	local st = Stroke(Theme.Stroke, 1, 0.35)
	st.Parent = row
	row.MouseEnter:Connect(function() Tween(st, { Color = Library.Accent, Transparency = 0.25 }, 0.2) end)
	row.MouseLeave:Connect(function() Tween(st, { Color = Theme.Stroke, Transparency = 0.35 }, 0.2) end)
	return row
end

local function RowLabel(row, text, rightSpace)
	return New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -((rightSpace or 0) + 16), 0, ROW),
		Font = Font, Text = text or "", TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = row,
	})
end

local function Switch(row, xOffset)
	local sw = New("TextButton", {
		Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, xOffset, 0, ROW / 2 - 10), BackgroundColor3 = Theme.Off,
		AutoButtonColor = false, Text = "", ZIndex = 3, Parent = row,
	}, { Corner(10), Stroke(Theme.Stroke, 1, 0.3) })
	local knob = New("Frame", {
		Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Theme.SubText, BorderSizePixel = 0, ZIndex = 4, Parent = sw,
	}, { Corner(8) })
	local function set(state, animate)
		local bg = state and Library.Accent or Theme.Off
		local pos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		local kc = state and Color3.new(1, 1, 1) or Theme.SubText
		if animate then
			Tween(sw, { BackgroundColor3 = bg }, 0.25)
			Tween(knob, { Position = pos, BackgroundColor3 = kc }, 0.3, Enum.EasingStyle.Back)
		else
			sw.BackgroundColor3 = bg
			knob.Position = pos
			knob.BackgroundColor3 = kc
		end
	end
	return sw, set
end

local function KeyName(key) return key and key.Name or "None" end

-- 1. Button
function Module:AddButton(opts)
	opts = opts or {}
	local row = self:_Row(ROW, self:_NextOrder())
	RowLabel(row, opts.Name or "Button", (opts.ButtonWidth or 105) + 10)
	local btn = MakeButton(row, opts.Text or "Click", opts.Style or "outline", {
		Size = UDim2.fromOffset(opts.ButtonWidth or 105, 24), Position = UDim2.new(1, -((opts.ButtonWidth or 105) + 10), 0.5, -12),
	})
	btn.MouseButton1Click:Connect(function() Safe(opts.Callback) end)
	local obj = { _row = row }
	function obj:SetText(t) btn.Text = t end
	function obj:Fire() Safe(opts.Callback) end
	function obj:SetVisible(v) row.Visible = v end
	return obj
end

-- 2. Button-Reihe
function Module:AddButtonGroup(opts)
	opts = opts or {}
	local list = opts.Buttons or {}
	local n = math.max(#list, 1)
	local row = self:_Row(ROW + 2, self:_NextOrder())
	local holder = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0, 26), ZIndex = 3, Parent = row,
	}, { New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local obj = { Buttons = {}, _row = row }
	for i, b in ipairs(list) do
		local btn = MakeButton(holder, b.Text or "Button", b.Style or "outline", {
			Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0), LayoutOrder = i,
		})
		btn.MouseButton1Click:Connect(function() Safe(b.Callback, btn) end)
		obj.Buttons[i] = btn
	end
	function obj:SetVisible(v) row.Visible = v end
	return obj
end

-- 3. Toggle
function Module:AddToggle(opts)
	opts = opts or {}
	local opt = NewOption("Toggle", opts, opts.Default == true)
	local row = self:_Row(ROW, self:_NextOrder())
	opt._row = row
	RowLabel(row, opts.Name or "Toggle", 60)
	local sw, set = Switch(row, -52)
	OnAccent(function() set(opt.Value, false) end)

	function opt:Set(v, silent)
		self.Value = v and true or false
		set(self.Value, true)
		if not silent then self:_Fire(self.Value) end
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d == true) end

	sw.MouseButton1Click:Connect(function() opt:Set(not opt.Value) end)
	local click = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0), Text = "", ZIndex = 3, Parent = row })
	click.MouseButton1Click:Connect(function() opt:Set(not opt.Value) end)
	return opt
end

-- 4. Toggle mit Keybind (Reset | Key | Switch)
function Module:AddToggleWithKey(opts)
	opts = opts or {}
	local opt = NewOption("ToggleWithKey", opts, opts.Default == true)
	local row = self:_Row(ROW, self:_NextOrder())
	opt._row = row
	opt.Key = opts.Key
	RowLabel(row, opts.Name or "Toggle", 182)

	local reset = MakeButton(row, "Reset", "plain", { Size = UDim2.fromOffset(46, 24), Position = UDim2.new(1, -178, 0.5, -12), Font = Font, TextSize = 11 })
	local keyBtn = MakeButton(row, KeyName(opt.Key), "plain", { Size = UDim2.fromOffset(66, 24), Position = UDim2.new(1, -126, 0.5, -12) })
	local sw, set = Switch(row, -52)
	OnAccent(function() set(opt.Value, false) end)

	function opt:Set(v, silent)
		self.Value = v and true or false
		set(self.Value, true)
		if not silent then self:_Fire(self.Value) end
	end
	function opt:SetKey(key)
		self.Key = key
		self._kb.Value = key
		keyBtn.Text = KeyName(key)
		if self.Flag then Library.Flags[self.Flag .. "_Key"] = key end
	end
	function opt:Serialize() return { V = self.Value, K = self.Key and self.Key.Name or false } end
	function opt:Deserialize(d)
		if type(d) == "table" then
			if d.K then
				local ok, key = pcall(function() return Enum.KeyCode[d.K] end)
				self:SetKey(ok and key or nil)
			else
				self:SetKey(nil)
			end
			self:Set(d.V == true)
		else
			self:Set(d == true)
		end
	end

	opt._kb = { Value = opt.Key, Mode = "Press" }
	function opt._kb:_Trigger(down)
		if not down then return end
		opt:Set(not opt.Value)
		if opts.Notify ~= false then
			Library:Notify({ Title = opts.Name or "Toggle", Content = "is now " .. (opt.Value and "ON" or "OFF"), Duration = 2 })
		end
	end
	table.insert(Library._keybinds, opt._kb)
	if opt.Flag then Library.Flags[opt.Flag .. "_Key"] = opt.Key end

	sw.MouseButton1Click:Connect(function() opt:Set(not opt.Value) end)
	keyBtn.MouseButton1Click:Connect(function() ListenKey(keyBtn, function(key) opt:SetKey(key) end) end)
	reset.MouseButton1Click:Connect(function() opt:SetKey(nil) end)
	return opt
end

-- 5. Slider
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
		return tonumber(string.format("%." .. dec .. "f", math.clamp(v, min, max)))
	end

	local opt = NewOption("Slider", opts, round(opts.Default or min))
	local row = self:_Row(52, self:_NextOrder())
	opt._row = row
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -110, 0, 20), Font = Font, Text = opts.Name or "Slider",
		TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = row,
	})
	local pill = New("TextBox", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 7), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.75, Font = FontBold, Text = "", TextSize = 12, ClearTextOnFocus = false, ZIndex = 3, Parent = row,
	}, { Corner(4), Pad(8, 8) })
	OnAccent(function(c) pill.BackgroundColor3 = c; pill.TextColor3 = Lighten(c, 0.6) end)

	local bar = New("Frame", {
		Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 35), BackgroundColor3 = Theme.Off, BorderSizePixel = 0, ZIndex = 3, Parent = row,
	}, { Corner(3) })
	local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 3, Parent = bar }, { Corner(3), Shine(0) })
	Accent(fill, "BackgroundColor3")
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 5, Parent = bar,
	}, { Corner(6) })
	local ks = Stroke(Library.Accent, 2, 0)
	ks.Parent = knob
	Accent(ks, "Color")
	local hit = New("TextButton", {
		Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 25), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6, Parent = row,
	})

	local function render(animate)
		local a = (max == min) and 0 or (opt.Value - min) / (max - min)
		if animate then
			Tween(fill, { Size = UDim2.new(a, 0, 1, 0) }, 0.08)
			Tween(knob, { Position = UDim2.new(a, 0, 0.5, 0) }, 0.08)
		else
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
		end
		pill.Text = tostring(opt.Value) .. suffix
	end
	render(false)

	function opt:Set(v, silent, force)
		v = round(tonumber(v) or self.Value or min)
		local changed = v ~= self.Value
		self.Value = v
		render(true)
		if (changed or force) and not silent then self:_Fire(v) end
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d, false, true) end

	pill.FocusLost:Connect(function()
		local num = tonumber((pill.Text:gsub("[^%d%.%-]", "")))
		if num then opt:Set(num) else render(false) end
	end)

	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		opt:Set(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			Tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15)
			fromX(input.Position.X)
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then fromX(input.Position.X) end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if dragging and IsPress(input) then
			dragging = false
			Tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.15)
		end
	end)
	return opt
end

-- 6. Dropdown (Single / Multi / Suche / Spieler-Liste)
function Module:AddDropdown(opts)
	opts = opts or {}
	local multi = opts.Multi == true
	local searchable = opts.Searchable == true
	local isPlayer = opts.Special == "Player"
	local values = opts.Values or {}
	local selectedSet = {}
	local opt = NewOption("Dropdown", opts, nil)
	if multi then opt.Value = {} end

	local function playerList()
		local t = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer or opts.IncludeLocal then table.insert(t, p.Name) end
		end
		table.sort(t, function(a, b) return a:lower() < b:lower() end)
		return t
	end
	if isPlayer then values = playerList() end

	local row = self:_Row(ROW, self:_NextOrder())
	opt._row = row
	RowLabel(row, opts.Name or "Dropdown", 150)

	local dropBtn = New("TextButton", {
		Size = UDim2.fromOffset(140, 24), Position = UDim2.new(1, -150, 0, ROW / 2 - 12), BackgroundColor3 = Theme.ElementAlt, AutoButtonColor = false,
		Font = Font, Text = "", TextColor3 = Theme.Text, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = row,
	}, { Corner(5), Stroke(Theme.Stroke, 1, 0.3), Pad(9, 22) })
	HoverBg(dropBtn, function() return Theme.ElementAlt end, function() return Theme.Hover end)
	local arrow = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, 13, 0.5, 0), BackgroundTransparency = 1,
		Font = FontBold, Text = "▼", TextColor3 = Theme.SubText, TextSize = 9, ZIndex = 4, Parent = dropBtn,
	})

	local listFrame = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, ROW + 2), Size = UDim2.new(1, -16, 0, 0), Visible = false, ZIndex = 3, Parent = row,
	})
	local search
	if searchable then
		search = New("TextBox", {
			Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.ElementAlt, BorderSizePixel = 0, Font = Font, Text = "", PlaceholderText = "Search...",
			PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text, TextSize = 12, ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = listFrame,
		}, { Corner(5), Stroke(Theme.Stroke, 1, 0.3), Pad(8, 8) })
	end
	local scroll = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, searchable and 30 or 0),
		Size = UDim2.new(1, 0, 1, searchable and -30 or 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 4, Parent = listFrame,
	}, { New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }), Pad(0, 4, 0, 0) })
	Accent(scroll, "ScrollBarImageColor3")
	local empty = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Font = Font, Text = "No options", TextColor3 = Theme.SubText,
		TextSize = 12, Visible = false, ZIndex = 4, Parent = scroll,
	})

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
			dropBtn.Text = #t > 0 and table.concat(t, ", ") or "Select..."
		else
			dropBtn.Text = opt.Value ~= nil and tostring(opt.Value) or "Select..."
		end
	end
	local function paint()
		for v, b in pairs(buttons) do
			local sel = isSelected(v)
			b.BackgroundColor3 = sel and Library.Accent or Theme.ElementAlt
			b.TextColor3 = sel and ContrastText(Library.Accent) or Theme.Text
			b.Font = sel and FontBold or Font
		end
	end
	OnAccent(function() paint() end)

	local open = false
	local function listHeight()
		return math.min(math.max(#values, 1), 6) * 28 + (searchable and 30 or 0)
	end
	local function setOpen(state)
		open = state
		if state then
			listFrame.Size = UDim2.new(1, -16, 0, listHeight())
			listFrame.Visible = true
			Stagger(scroll, 0.025, 0.22)
		end
		Tween(row, { Size = UDim2.new(1, 0, 0, state and (ROW + 2 + listHeight() + 8) or ROW) }, 0.25)
		Tween(arrow, { Rotation = state and 180 or 0 }, 0.2)
		if not state then task.delay(0.25, function() if not open then listFrame.Visible = false end end) end
	end

	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		buttons = {}
		empty.Visible = #values == 0
		for i, v in ipairs(values) do
			local b = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.ElementAlt, AutoButtonColor = false, Font = Font, Text = tostring(v),
				TextSize = 12, TextColor3 = Theme.Text, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i, ZIndex = 4, Parent = scroll,
			}, { Corner(5) })
			local st = Stroke(Theme.Stroke, 1, 0.5)
			st.Parent = b
			b.MouseEnter:Connect(function() Tween(st, { Color = Library.Accent, Transparency = 0.1 }, 0.15) end)
			b.MouseLeave:Connect(function() Tween(st, { Color = Theme.Stroke, Transparency = 0.5 }, 0.15) end)
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
		if search then search.Text = "" end
		paint()
	end

	if search then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = search.Text:lower()
			for v, b in pairs(buttons) do b.Visible = q == "" or tostring(v):lower():find(q, 1, true) ~= nil end
		end)
	end

	local function applySet(v)
		selectedSet = {}
		if type(v) == "table" then
			for k, val in pairs(v) do
				if type(k) == "number" then selectedSet[val] = true elseif val == true then selectedSet[k] = true end
			end
		elseif v ~= nil then
			selectedSet[v] = true
		end
	end

	function opt:Set(v, silent)
		if multi then applySet(v) else self.Value = v end
		updateText(); paint()
		if not silent then self:_Fire(self.Value) end
	end
	function opt:SetValues(newValues)
		values = newValues or {}
		if multi then
			for k in pairs(selectedSet) do if not table.find(values, k) then selectedSet[k] = nil end end
		elseif self.Value ~= nil and not table.find(values, self.Value) then
			self.Value = nil
		end
		build(); updateText(); paint()
		if open then setOpen(true) end
		if self.Flag then Library.Flags[self.Flag] = self.Value end
	end
	opt.Refresh = opt.SetValues
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d) end

	build()
	local default = opts.Default
	if type(default) == "number" and not multi then default = values[default] end
	if default ~= nil then
		if multi then applySet(default) else opt.Value = default end
	end
	updateText(); paint()
	if opt.Flag then Library.Flags[opt.Flag] = opt.Value end

	if isPlayer then
		local function refresh() opt:SetValues(playerList()) end
		Connect(Players.PlayerAdded, refresh)
		Connect(Players.PlayerRemoving, function() task.defer(refresh) end)
	end

	dropBtn.MouseButton1Click:Connect(function() setOpen(not open) end)
	return opt
end

-- 7. Auswahl-Leiste (z.B. On | Off)
function Module:AddSelector(opts)
	opts = opts or {}
	local values = opts.Values or { "On", "Off" }
	local opt = NewOption("Selector", opts, opts.Default or values[1])
	local row = self:_Row(ROW, self:_NextOrder())
	opt._row = row

	local widths, total = {}, 0
	for i, v in ipairs(values) do
		local w = math.max(TextService:GetTextSize(tostring(v), 12, FontBold, Vector2.new(500, 24)).X + 20, 44)
		widths[i] = w
		total = total + w
	end
	total = total + (#values - 1) * 4
	RowLabel(row, opts.Name or "Selector", total + 10)

	local holder = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(total, 24),
		BackgroundTransparency = 1, ZIndex = 3, Parent = row,
	}, { New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local btns = {}
	local function paint()
		for v, b in pairs(btns) do
			local sel = opt.Value == v
			Tween(b, { BackgroundColor3 = sel and Library.Accent or Theme.ElementAlt, TextColor3 = sel and ContrastText(Library.Accent) or Theme.SubText }, 0.18)
		end
	end
	for i, v in ipairs(values) do
		local b = New("TextButton", {
			Size = UDim2.fromOffset(widths[i], 24), BackgroundColor3 = Theme.ElementAlt, AutoButtonColor = false, Font = FontBold, Text = tostring(v),
			TextSize = 12, TextColor3 = Theme.SubText, LayoutOrder = i, ZIndex = 3, Parent = holder,
		}, { Corner(5), Stroke(Theme.Stroke, 1, 0.3) })
		btns[v] = b
		Ripple(b)
		b.MouseButton1Click:Connect(function() ClickFlash(b); opt:Set(v) end)
	end
	OnAccent(function() paint() end)

	function opt:Set(v, silent)
		if not table.find(values, v) then return end
		self.Value = v
		paint()
		if not silent then self:_Fire(v) end
	end
	function opt:Serialize() return self.Value end
	function opt:Deserialize(d) self:Set(d) end
	return opt
end

-- 8. Texteingabe
function Module:AddInput(opts)
	opts = opts or {}
	local opt = NewOption("Input", opts, tostring(opts.Default or ""))
	local row = self:_Row(ROW, self:_NextOrder())
	opt._row = row
	RowLabel(row, opts.Name or "Input", 160)
	local box = New("TextBox", {
		Size = UDim2.fromOffset(150, 24), Position = UDim2.new(1, -160, 0.5, -12), BackgroundColor3 = Theme.ElementAlt, BorderSizePixel = 0,
		Font = Font, Text = opt.Value, PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text,
		TextSize = 12, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = row,
	}, { Corner(5), Pad(8, 8) })
	local st = Stroke(Theme.Stroke, 1, 0.3)
	st.Parent = box

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if opts.Numeric then
			local cleaned = box.Text:gsub("[^%d%.%-]", "")
			if cleaned ~= box.Text then box.Text = cleaned return end
		end
		opt.Value = box.Text
		if opt.Flag then Library.Flags[opt.Flag] = opt.Value end
		if opts.Live then opt:_Fire(opt.Value) end
	end)
	box.Focused:Connect(function() Tween(st, { Color = Library.Accent, Transparency = 0 }, 0.2) end)
	box.FocusLost:Connect(function(enter)
		Tween(st, { Color = Theme.Stroke, Transparency = 0.3 }, 0.2)
		if not opts.Live then opt:_Fire(opt.Value, enter) end
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
Module.AddTextBox = Module.AddInput

-- 9. Keybind
function Module:AddKeybind(opts)
	opts = opts or {}
	local opt = NewOption("Keybind", opts, opts.Default)
	opt.Mode = opts.Mode or "Press"
	opt.State = false
	local row = self:_Row(ROW, self:_NextOrder())
	opt._row = row
	RowLabel(row, opts.Name or "Keybind", 100)
	local btn = MakeButton(row, KeyName(opt.Value), "plain", { Size = UDim2.fromOffset(90, 24), Position = UDim2.new(1, -100, 0.5, -12) })

	function opt:Set(key)
		self.Value = key
		if self.Flag then Library.Flags[self.Flag] = key end
		btn.Text = KeyName(key)
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
	function opt:Serialize() return self.Value and self.Value.Name or false end
	function opt:Deserialize(d)
		if not d then self:Set(nil) return end
		local ok, key = pcall(function() return Enum.KeyCode[d] end)
		self:Set(ok and key or nil)
	end

	btn.MouseButton1Click:Connect(function() ListenKey(btn, function(key) opt:Set(key) end) end)
	table.insert(Library._keybinds, opt)
	return opt
end

-- 10. Color Picker (immer ganz unten im Modul)
function Module:AddColorPicker(opts)
	opts = opts or {}
	local default = opts.Default or Color3.fromRGB(255, 255, 255)
	local opt = NewOption("ColorPicker", opts, default)
	local h, s, v = default:ToHSV()

	local row = self:_Row(ROW, self:_NextOrder(true))
	opt._row = row
	RowLabel(row, opts.Name or "Color", 60)
	local swatch = New("Frame", {
		Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -50, 0, ROW / 2 - 9), BackgroundColor3 = default, BorderSizePixel = 0, ZIndex = 3, Parent = row,
	}, { Corner(5), Stroke(Theme.Stroke, 1, 0.2) })

	local picker = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, ROW + 4), Size = UDim2.new(1, 0, 0, 136), Visible = false, ZIndex = 3, Parent = row })
	local sv = New("Frame", {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 0, 100), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = picker,
	}, { Corner(6) })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = sv },
		{ Corner(6), New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3, Parent = sv },
		{ Corner(6), New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 4, Parent = sv,
	}, { Round(), Stroke(Color3.new(1, 1, 1), 2, 0) })

	local hueKeys = {}
	for i = 0, 6 do table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1))) end
	local hue = New("Frame", {
		Position = UDim2.new(1, -38, 0, 0), Size = UDim2.fromOffset(24, 100), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = picker,
	}, { Corner(6), New("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueKeys) }) })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = hue,
	}, { Corner(2), Stroke(Color3.new(0, 0, 0), 1, 0.3) })

	local hex = New("TextBox", {
		Position = UDim2.fromOffset(12, 108), Size = UDim2.new(1, -24, 0, 24), BackgroundColor3 = Theme.ElementAlt, BorderSizePixel = 0, Font = FontBold,
		Text = "", PlaceholderText = "#FFFFFF", PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text, TextSize = 12, ClearTextOnFocus = false, ZIndex = 3, Parent = picker,
	}, { Corner(5), Stroke(Theme.Stroke, 1, 0.3) })

	local function apply(fire)
		local c = Color3.fromHSV(h, s, v)
		opt.Value = c
		swatch.BackgroundColor3 = c
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
		hueCursor.Position = UDim2.new(0.5, 0, h, 0)
		if not hex:IsFocused() then hex.Text = "#" .. c:ToHex():upper() end
		if fire then opt:_Fire(c) elseif opt.Flag then Library.Flags[opt.Flag] = c end
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

	hex.FocusLost:Connect(function()
		local ok, c = pcall(function() return Color3.fromHex((hex.Text:gsub("#", ""))) end)
		if ok and c then opt:Set(c) else hex.Text = "#" .. opt.Value:ToHex():upper() end
	end)

	local dragSV, dragHue = false, false
	local function updateSV(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		apply(true)
	end
	local function updateHue(pos)
		h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 0.999)
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
	local head = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW), Text = "", ZIndex = 5, Parent = row })
	head.MouseButton1Click:Connect(function()
		open = not open
		if open then picker.Visible = true end
		Tween(row, { Size = UDim2.new(1, 0, 0, open and (ROW + 4 + 136 + 6) or ROW) }, 0.25)
		if not open then task.delay(0.25, function() if not open then picker.Visible = false end end) end
	end)
	return opt
end

-- 11. Text / Infos
function Module:AddLabel(text)
	local lbl = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, Font = Font, Text = text or "",
		TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = self:_NextOrder(),
		ZIndex = 3, Parent = self._content,
	}, { Pad(4, 4, 2, 2) })
	local obj = {}
	function obj:Set(t) lbl.Text = t end
	function obj:SetVisible(b) lbl.Visible = b end
	return obj
end

function Module:AddParagraph(opts)
	opts = opts or {}
	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.3,
		BorderSizePixel = 0, LayoutOrder = self:_NextOrder(), ZIndex = 3, Parent = self._content,
	}, {
		Corner(6), Stroke(Theme.Stroke, 1, 0.35),
		New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad(12, 12, 8, 9),
	})
	local title = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, Font = FontBold, Text = opts.Title or "",
		TextColor3 = Theme.Text, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 3, Parent = frame,
	})
	local content = New("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y, Font = Font, Text = opts.Content or "",
		TextColor3 = Theme.SubText, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 3, Parent = frame,
	})
	local obj = {}
	function obj:Set(t, c) if t then title.Text = t end if c then content.Text = c end end
	function obj:SetVisible(b) frame.Visible = b end
	return obj
end

function Module:AddInfo(opts)
	opts = opts or {}
	local row = self:_Row(ROW, self:_NextOrder())
	RowLabel(row, opts.Name or "Info", 130)
	local pill = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.78, Font = FontBold, Text = tostring(opts.Value or ""), TextSize = 11, ZIndex = 3, Parent = row,
	}, { Corner(10), Pad(9, 9) })
	OnAccent(function(c) pill.BackgroundColor3 = c; pill.TextColor3 = Lighten(c, 0.55) end)
	local obj = {}
	function obj:Set(t) pill.Text = tostring(t) end
	function obj:SetVisible(b) row.Visible = b end
	return obj
end

function Module:AddDivider(text)
	local hasText = text and text ~= ""
	local f = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, hasText and 24 or 8), LayoutOrder = self:_NextOrder(), ZIndex = 3, Parent = self._content,
	})
	if hasText then
		New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 4), Size = UDim2.new(1, -2, 0, 14), Font = FontBold, Text = string.upper(text),
			TextColor3 = Theme.SubText, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = f,
		})
	end
	local line = New("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 3, Parent = f,
	}, { New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }) }) })
	Accent(line, "BackgroundColor3")
end
Module.AddSection = Module.AddDivider

--// ==========================================
--// WINDOW
--// ==========================================
local Window = {}
Window.__index = Window

local MAIN_W, MAIN_H = 320, 470
local MOD_W = 340

function Window:Notify(opts) Library:Notify(opts) end

function Window:_Find(m)
	if type(m) == "table" then return m end
	for _, mod in ipairs(self._allModules) do
		if mod.Name == m then return mod end
	end
end

local function Front(frame)
	Library._z = Library._z + 1
	frame.ZIndex = Library._z
end

-- Freien Platz rechts neben dem Hauptfenster suchen
function Window:_Place(mod)
	if mod._moved then return end
	local gui = Library._gui
	local vp = gui.AbsoluteSize
	local mp, ms = self._main.AbsolutePosition, self._main.AbsoluteSize
	local w = MOD_W * Library._base
	local startX = mp.X + ms.X + 10
	local cols = math.floor((vp.X - startX) / (w + 10))
	local slot = mod._slot or 0
	local x, y
	if cols >= 1 then
		x = startX + (slot % cols) * (w + 10)
		y = mp.Y + math.floor(slot / cols) * 36
	else
		x = math.clamp(mp.X + 24 + slot * 22, 0, math.max(vp.X - w, 0))
		y = mp.Y + 30 + slot * 22
	end
	mod._frame.Position = UDim2.fromOffset(x, y)
end

function Window:OpenModule(m)
	local mod = self:_Find(m)
	if not mod or self._open[mod] then return end
	local used = {}
	for o in pairs(self._open) do if not o._moved and o._slot then used[o._slot] = true end end
	local slot = 0
	while used[slot] do slot = slot + 1 end
	mod._slot = slot
	self._open[mod] = true
	self:_Place(mod)
	Front(mod._frame)
	if not self._minimized then
		PopIn(mod._frame, Vector2.new(-24, 0))
		mod._reveal()
	end
	if mod._refresh then mod._refresh() end
	if mod == self._settings then self._settingsVisual(true) end
end

function Window:CloseModule(m)
	local mod = self:_Find(m)
	if not mod or not self._open[mod] then return end
	self._open[mod] = nil
	mod._moved = false
	PopOut(mod._frame)
	if mod._refresh then mod._refresh() end
	if mod == self._settings then self._settingsVisual(false) end
end

function Window:ToggleModule(m)
	local mod = self:_Find(m)
	if not mod then return end
	if self._open[mod] then self:CloseModule(mod) else self:OpenModule(mod) end
end

function Window:CloseAll()
	for mod in pairs(self._open) do self:CloseModule(mod) end
end

function Window:Minimize()
	if self._minimized then return end
	self._minimized = true
	PopOut(self._main)
	for mod in pairs(self._open) do PopOut(mod._frame) end
	PopIn(self._circle)
	local key = self._menuKey and self._menuKey.Value
	if Library.IsMobile or not key then
		Library:Notify({ Title = "Rift", Content = "GUI minimized. Tap the round button to reopen.", Duration = 3 })
	else
		Library:Notify({ Title = "Rift", Content = "GUI minimized. Press [" .. key.Name .. "] to reopen.", Duration = 3 })
	end
end

function Window:Maximize()
	if not self._minimized then return end
	self._minimized = false
	PopOut(self._circle)
	PopIn(self._main, Vector2.new(0, 16))
	self:_RevealList()
	for mod in pairs(self._open) do
		PopIn(mod._frame, Vector2.new(-24, 0))
		mod._reveal()
	end
end

function Window:Toggle()
	if self._minimized then self:Maximize() else self:Minimize() end
end

-- Modul-Liste nacheinander reinsliden lassen
function Window:_RevealList()
	if not Anim() then return end
	local i = 0
	for _, mod in ipairs(self._listed) do
		if mod._btn and mod._btn.Visible then
			local active = self._open[mod] == true
			local d = math.min(i, 12) * 0.04
			i = i + 1
			mod._btn.BackgroundTransparency = 1
			mod._label.TextTransparency = 1
			mod._arrow.TextTransparency = 1
			mod._label.Position = UDim2.fromOffset(34, 0)
			task.delay(d, function()
				Tween(mod._btn, { BackgroundTransparency = active and 0.05 or 0.35 }, 0.3, Enum.EasingStyle.Quad)
				Tween(mod._label, { TextTransparency = 0, Position = UDim2.fromOffset(16, 0) }, 0.4, Enum.EasingStyle.Quint)
				Tween(mod._arrow, { TextTransparency = 0 }, 0.4, Enum.EasingStyle.Quad)
			end)
		end
	end
end

function Window:AddModule(opts)
	if type(opts) == "string" then opts = { Name = opts } end
	opts = opts or {}
	local window = self
	local gui = Library._gui
	local mod = setmetatable({ Name = opts.Name or "Module", _order = 0, _window = self }, Module)

	-- Modul-Fenster
	local frame = New("Frame", {
		Name = RandomString(8), Size = UDim2.fromOffset(MOD_W, 140), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.1,
		BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 5, Parent = gui,
	}, { Corner(10) })
	local scale = AddScale(frame)
	AnimatedStroke(frame, 1.5)
	Backdrop(frame, 0.45, {
		NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0.55),
	}, 0)
	frame.InputBegan:Connect(function(input) if IsPress(input) then Front(frame) end end)

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Active = true, ZIndex = 3, Parent = frame })
	New("ImageLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0.5, -11), Size = UDim2.fromOffset(22, 22), Image = Asset(Library.Assets.Logo),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = header,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -90, 1, 0), Font = FontBold, Text = mod.Name,
		TextColor3 = Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = header,
	})
	local close = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(28, 24), BackgroundColor3 = Theme.ElementAlt,
		AutoButtonColor = false, Font = FontBold, Text = "×", TextSize = 16, TextColor3 = Theme.Text, ZIndex = 4, Parent = header,
	}, { Corner(6), Stroke(Theme.Stroke, 1, 0.3) })
	HoverBg(close, function() return Theme.ElementAlt end, function() return Theme.DangerHover end)
	Ripple(close)
	close.MouseButton1Click:Connect(function() window:CloseModule(mod) end)
	Separator(frame, 42)
	MakeDraggable(header, frame, nil, function(moved) if moved then mod._moved = true end end)

	local content = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -54),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3, Parent = frame,
	})
	Accent(content, "ScrollBarImageColor3")
	local layout = New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	local pad = Pad(10, 12, 2, 8)
	pad.Parent = content
	mod._reveal = function()
		content.CanvasPosition = Vector2.new(0, 0)
		if not Anim() then return end
		pad.PaddingTop = UDim.new(0, 18)
		Tween(pad, { PaddingTop = UDim.new(0, 2) }, 0.45, Enum.EasingStyle.Quint)
		Stagger(content, 0.035, 0.3)
	end
	local function resize()
		local k = scale.Scale > 0 and scale.Scale or 1
		local h = layout.AbsoluteContentSize.Y / k + 10 + 54
		frame.Size = UDim2.fromOffset(MOD_W, math.clamp(h, 110, 480))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	task.defer(resize)

	mod._frame = frame
	mod._content = content
	table.insert(self._allModules, mod)

	-- Eintrag in der Modul-Liste
	if not opts.Hidden then
		self._count = self._count + 1
		local btn = New("TextButton", {
			Size = UDim2.new(1, -2, 0, 36), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.35, AutoButtonColor = false,
			Text = "", LayoutOrder = self._count, ZIndex = 3, Parent = self._list,
		}, { Corner(6), Shine() })
		local ind = New("Frame", {
			Size = UDim2.new(0, 3, 0.5, 0), Position = UDim2.new(0, 5, 0.25, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 4, Parent = btn,
		}, { Corner(2) })
		local label = New("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -44, 1, 0), Font = Font, Text = mod.Name,
			TextColor3 = Theme.SubText, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4, Parent = btn,
		})
		local arrow = New("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(14, 14),
			Font = FontBold, Text = "›", TextColor3 = Theme.SubText, TextSize = 18, ZIndex = 4, Parent = btn,
		})
		mod._refresh = function()
			local active = window._open[mod] == true
			Tween(btn, {
				BackgroundColor3 = active and Library.Accent or Theme.Element,
				BackgroundTransparency = active and 0.05 or 0.35,
			}, 0.22)
			Tween(label, { TextColor3 = active and ContrastText(Library.Accent) or Theme.SubText }, 0.22)
			Tween(arrow, { TextColor3 = active and ContrastText(Library.Accent) or Theme.SubText, Rotation = active and 90 or 0 }, 0.22)
			Tween(ind, { BackgroundTransparency = active and 0 or 1 }, 0.22)
			label.Font = active and FontBold or Font
			Tween(label, { Position = UDim2.fromOffset(16, 0) }, 0.22)
		end
		OnAccent(function() mod._refresh() end)
		btn.MouseEnter:Connect(function()
			if window._open[mod] then return end
			Tween(btn, { BackgroundColor3 = Theme.Hover }, 0.15)
			if Anim() then Tween(label, { Position = UDim2.fromOffset(21, 0), TextColor3 = Theme.Text }, 0.2) end
		end)
		btn.MouseLeave:Connect(function()
			if window._open[mod] then return end
			Tween(btn, { BackgroundColor3 = Theme.Element }, 0.15)
			Tween(label, { Position = UDim2.fromOffset(16, 0), TextColor3 = Theme.SubText }, 0.2)
		end)
		Ripple(btn)
		btn.MouseButton1Click:Connect(function() ClickFlash(btn); window:ToggleModule(mod) end)
		mod._btn = btn
		mod._label = label
		mod._arrow = arrow
		table.insert(self._listed, mod)
	end
	return mod
end

function Library:CreateWindow(opts)
	opts = opts or {}
	if opts.Accent then self.Accent = opts.Accent end
	if opts.Logo then self.Assets.Logo = Asset(opts.Logo) end
	if opts.Background then self.Assets.Background = Asset(opts.Background) end
	if opts.MobileMode ~= nil then self.MobileMode = opts.MobileMode end
	self.ConfigFolder = opts.ConfigFolder or self.ConfigFolder
	local gui = self:_EnsureGui()
	if opts.Accent then self:SetAccent(opts.Accent) end

	local win = setmetatable({
		_allModules = {}, _listed = {}, _open = {}, _count = 0, _minimized = false,
		Version = opts.Version or "v1.0.0",
	}, Window)
	table.insert(self._windows, win)

	-- Hauptfenster
	local b = self._base
	local main = New("Frame", {
		Name = RandomString(8), Size = UDim2.fromOffset(MAIN_W, MAIN_H),
		Position = UDim2.new(0.5, -math.floor((MAIN_W + 10 + MOD_W) / 2 * b), 0.5, -math.floor(MAIN_H / 2 * b)),
		BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.1, BorderSizePixel = 0, Active = true, ZIndex = 4, Visible = false, Parent = gui,
	}, { Corner(10) })
	AddScale(main)
	AnimatedStroke(main, 1.5)
	Backdrop(main, 0.25, {
		NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 0.1),
	}, 90)
	win._main = main

	-- Kopfzeile
	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Active = true, ZIndex = 3, Parent = main })
	New("ImageLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0.5, -13), Size = UDim2.fromOffset(26, 26), Image = Asset(self.Assets.Logo),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = header,
	})
	New("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -160, 1, 0), Font = FontBold, Text = opts.Title or "Rift CMD's",
		TextColor3 = Theme.Text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = header,
	})
	local verPill = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.78, Font = FontBold, Text = tostring(win.Version), TextSize = 11, ZIndex = 3, Parent = header,
	}, { Corner(10), Pad(9, 9) })
	OnAccent(function(c) verPill.BackgroundColor3 = c; verPill.TextColor3 = Lighten(c, 0.55) end)
	local minBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(28, 24), BackgroundColor3 = Theme.ElementAlt,
		AutoButtonColor = false, Font = FontBold, Text = "—", TextSize = 13, TextColor3 = Theme.Text, ZIndex = 4, Parent = header,
	}, { Corner(6), Stroke(Theme.Stroke, 1, 0.3) })
	HoverBg(minBtn, function() return Theme.ElementAlt end, function() return Theme.Hover end)
	Ripple(minBtn)
	Separator(main, 46)

	-- Hauptfenster ziehen: angedockte Modul-Fenster ziehen mit
	MakeDraggable(header, main, function()
		for mod in pairs(win._open) do win:_Place(mod) end
	end)
	main.InputBegan:Connect(function(input) if IsPress(input) then Front(main) end end)

	-- Suche
	local searchBox = New("TextBox", {
		Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.25,
		BorderSizePixel = 0, Font = Font, Text = "", PlaceholderText = "Search Module", PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 3, Parent = main,
	}, { Corner(6), Pad(12, 12) })
	local sst = Stroke(Theme.Stroke, 1, 0.3)
	sst.Parent = searchBox
	searchBox.Focused:Connect(function() Tween(sst, { Color = Library.Accent, Transparency = 0 }, 0.2) end)
	searchBox.FocusLost:Connect(function() Tween(sst, { Color = Theme.Stroke, Transparency = 0.3 }, 0.2) end)

	-- Modul-Liste
	local list = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 98), Size = UDim2.new(1, -20, 1, -98 - 54),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3, Parent = main,
	}, { New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }), Pad(1, 6, 1, 4) })
	Accent(list, "ScrollBarImageColor3")
	win._list = list

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = searchBox.Text:lower()
		for _, m in ipairs(win._listed) do
			if m._btn then m._btn.Visible = q == "" or m.Name:lower():find(q, 1, true) ~= nil end
		end
	end)

	-- Settings-Button unten
	local settingsBtn = New("TextButton", {
		Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = Theme.ElementAlt, BackgroundTransparency = 0.2,
		AutoButtonColor = false, Font = FontBold, Text = "Settings", TextSize = 13, TextColor3 = Theme.Text, ZIndex = 3, Parent = main,
	}, { Corner(6) })
	local setStroke = Stroke(Theme.Stroke, 1, 0.3)
	setStroke.Parent = settingsBtn
	local settingsOpen = false
	win._settingsVisual = function(active)
		settingsOpen = active
		Tween(setStroke, { Color = active and Library.Accent or Theme.Stroke, Transparency = active and 0 or 0.3 }, 0.2)
		Tween(settingsBtn, { TextColor3 = active and Lighten(Library.Accent, 0.5) or Theme.Text }, 0.2)
	end
	OnAccent(function() if settingsOpen then win._settingsVisual(true) end end)
	HoverBg(settingsBtn, function() return Theme.ElementAlt end, function() return Theme.Hover end)
	Ripple(settingsBtn)

	-- Runder Button (nur sichtbar wenn minimiert; auch für Handy)
	local circle = New("ImageButton", {
		Name = RandomString(8), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.08, AutoButtonColor = false, Image = "", Visible = false, ZIndex = 90000, Parent = gui,
	}, { Round() })
	AddScale(circle)
	AnimatedStroke(circle, 2)
	New("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1,
		Image = Asset(self.Assets.Logo), ScaleType = Enum.ScaleType.Fit, ZIndex = 901, Parent = circle,
	})
	win._circle = circle
	-- Pulsierender Ring solange minimiert
	local ring = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, ZIndex = 899, Parent = circle,
	}, { Round() })
	local ringStroke = Stroke(self.Accent, 2, 1)
	ringStroke.Parent = ring
	Accent(ringStroke, "Color")
	task.spawn(function()
		while gui.Parent do
			if circle.Visible and Anim() then
				ring.Size = UDim2.fromScale(1, 1)
				ringStroke.Transparency = 0.15
				Tween(ring, { Size = UDim2.fromScale(1.7, 1.7) }, 1.2, Enum.EasingStyle.Quad)
				Tween(ringStroke, { Transparency = 1 }, 1.2, Enum.EasingStyle.Quad)
				task.wait(1.7)
			else
				task.wait(0.3)
			end
		end
	end)
	MakeDraggable(circle, circle, nil, function(moved)
		if not moved then win:Maximize() end
	end)

	minBtn.MouseButton1Click:Connect(function() win:Minimize() end)

	--// SETTINGS-FENSTER
	local settings = win:AddModule({ Name = "Settings", Hidden = true })
	win._settings = settings
	settingsBtn.MouseButton1Click:Connect(function() ClickFlash(settingsBtn); win:ToggleModule(settings) end)

	settings:AddDivider("Info")
	settings:AddInfo({ Name = "GUI Version", Value = win.Version })
	settings:AddInfo({ Name = "Library Version", Value = "v" .. self.Version })
	settings:AddInfo({ Name = "Mobile Mode", Value = self.IsMobile and "ON" or "OFF" })

	settings:AddDivider("Interface")
	win._menuKey = settings:AddKeybind({
		Name = "Minimize Key", Default = opts.MenuKey or Enum.KeyCode.RightShift, Mode = "Press", NoSave = true,
		Callback = function() win:Toggle() end,
	})
	settings:AddToggle({ Name = "Animations", Default = self.Animations ~= false, NoSave = true, Callback = function(v) Library.Animations = v end })
	settings:AddButton({ Name = "Close all windows", Text = "Close", Style = "plain", Callback = function()
		for mod in pairs(win._open) do if mod ~= settings then win:CloseModule(mod) end end
	end })

	settings:AddDivider("Configs")
	local nameInput = settings:AddInput({ Name = "Config Name", Placeholder = "", NoSave = true })
	local cfgDrop = settings:AddDropdown({ Name = "Saved Configs", Values = self:ListConfigs(), NoSave = true })
	cfgDrop:OnChanged(function(v) if v then nameInput:Set(v, true) end end)
	local function refreshConfigs(select)
		cfgDrop:SetValues(Library:ListConfigs())
		cfgDrop:Set(select, true)
	end
	local function pickName()
		local n = CleanName(nameInput.Value)
		if n ~= "" then return n end
		return cfgDrop.Value
	end
	local function report(ok, msg, okText)
		Library:Notify({ Title = "Config", Content = ok and (okText .. ' "' .. tostring(msg) .. '"') or tostring(msg) })
	end
	local deleteArmed, deleteToken = false, 0
	local group
	group = settings:AddButtonGroup({
		Buttons = {
			{ Text = "Load", Style = "plain", Callback = function()
				local ok, msg = Library:LoadConfig(pickName())
				report(ok, msg, "Loaded")
			end },
			{ Text = "Save", Style = "filled", Callback = function()
				local ok, msg = Library:SaveConfig(pickName())
				report(ok, msg, "Saved")
				if ok then refreshConfigs(msg) end
			end },
			{ Text = "Delete", Style = "danger", Callback = function(btn)
				local n = pickName()
				if not n or n == "" then report(false, "Select a config first") return end
				if not deleteArmed then
					deleteArmed = true
					deleteToken = deleteToken + 1
					local my = deleteToken
					btn.Text = "Sure?"
					task.delay(3, function()
						if deleteArmed and deleteToken == my then deleteArmed = false; btn.Text = "Delete" end
					end)
					return
				end
				deleteArmed = false
				btn.Text = "Delete"
				local ok, msg = Library:DeleteConfig(n)
				report(ok, msg, "Deleted")
				if ok then nameInput:Set("", true); refreshConfigs(nil) end
			end },
			{ Text = "Refresh", Style = "plain", Callback = function() refreshConfigs(cfgDrop.Value) end },
		},
	})
	settings:AddLabel("Folder: " .. self.ConfigFolder .. "/configs")

	settings:AddDivider("Menu")
	settings:AddButton({ Name = "Unload GUI", Text = "Unload", Style = "danger", Callback = function() Library:Unload() end })
	settings:AddColorPicker({
		Name = "Accent Color", Default = self.Accent, NoSave = true,
		Callback = function(c) Library:SetAccent(c) end,
	})

	-- Einblenden (Liste erst, wenn die Module hinzugefügt wurden)
	Front(main)
	PopIn(main, Vector2.new(0, 16))
	task.defer(function() win:_RevealList() end)
	return win
end

function Library:Unload()
	if activeListen then activeListen:Disconnect() activeListen = nil end
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	self._conns = {}
	if self._gui then pcall(function() self._gui:Destroy() end) end
	self._gui = nil
	self._notifHolder = nil
	self._keybinds = {}
	self._accentFns = {}
	self._scales = {}
	self._grads = {}
	self._windows = {}
	self.Flags = {}
	self.Options = {}
	if genv.RiftLib == self then genv.RiftLib = nil end
end

genv.RiftLib = Library
return Library
