--!nonstrict
-- UI kit: palette, fonts and small constructors used by every screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local Theme = {}

Theme.Colors = {
	bg = Color3.fromRGB(8, 6, 8),
	panel = Color3.fromRGB(20, 12, 14),
	panel2 = Color3.fromRGB(32, 18, 22),
	burgundy = Color3.fromRGB(92, 24, 34),
	deep = Color3.fromRGB(50, 12, 20),
	gold = Color3.fromRGB(196, 160, 92),
	goldDim = Color3.fromRGB(130, 104, 62),
	text = Color3.fromRGB(232, 222, 204),
	dim = Color3.fromRGB(160, 148, 132),
	danger = Color3.fromRGB(210, 50, 44),
	cold = Color3.fromRGB(130, 170, 230),
	good = Color3.fromRGB(110, 200, 130),
	paper = Color3.fromRGB(226, 214, 186),
	ink = Color3.fromRGB(36, 28, 22),
}

Theme.Fonts = {
	title = Enum.Font.Bodoni,
	body = Enum.Font.Garamond,
	ui = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	type = Enum.Font.SpecialElite,
	horror = Enum.Font.Creepster,
}

function Theme.New(className: string, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if inst:IsA("GuiObject") and props and props.BorderSizePixel == nil then
		inst.BorderSizePixel = 0
	end
	inst.Parent = parent
	return inst
end

function Theme.Corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

function Theme.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.gold
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.Padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Theme.TextLimit(label: Instance, maxSize: number, minSize: number?)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.MinTextSize = minSize or 8
	c.Parent = label
	return c
end

function Theme.Gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Theme.List(parent: Instance, padding: number, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	if align then
		l.HorizontalAlignment = align
	end
	l.Parent = parent
	return l
end

function Theme.Label(parent: Instance, text: string, props)
	props = props or {}
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = props.color or Theme.Colors.text
	label.Font = props.font or Theme.Fonts.body
	label.TextScaled = props.scaled ~= false
	label.TextSize = props.size or 18
	label.TextWrapped = true
	label.TextXAlignment = props.align or Enum.TextXAlignment.Right
	label.TextYAlignment = props.valign or Enum.TextYAlignment.Center
	label.Size = props.dims or UDim2.fromScale(1, 1)
	label.Position = props.pos or UDim2.new()
	label.AnchorPoint = props.anchor or Vector2.zero
	label.RichText = props.rich == true
	label.LayoutOrder = props.order or 0
	label.ZIndex = props.z or 1
	label.BorderSizePixel = 0
	if props.max then
		Theme.TextLimit(label, props.max)
	end
	label.Parent = parent
	return label
end

-- Styled button: dark panel, gold outline, hover glow, click sound.
function Theme.Button(parent: Instance, text: string, onClick: () -> (), props)
	props = props or {}
	local C = Theme.Colors
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = props.color or C.panel2
	button.BackgroundTransparency = props.transparency or 0.1
	button.Size = props.dims or UDim2.new(1, 0, 0, 44)
	button.Position = props.pos or UDim2.new()
	button.AnchorPoint = props.anchor or Vector2.zero
	button.LayoutOrder = props.order or 0
	button.ZIndex = props.z or 1
	button.BorderSizePixel = 0
	button.Parent = parent
	Theme.Corner(button, 6)
	local stroke = Theme.Stroke(button, C.gold, 1, 0.55)
	local label = Theme.Label(button, text, {
		font = props.font or Theme.Fonts.title,
		color = props.textColor or C.text,
		align = props.align or Enum.TextXAlignment.Center,
		dims = UDim2.new(1, -16, 1, -10),
		pos = UDim2.fromOffset(8, 5),
		max = props.max or 24,
		z = (props.z or 1) + 1,
	})
	label.Name = "Label"
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		Sounds.Play("UIHover")
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0 }):Play()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = C.burgundy }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.55 }):Play()
		TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = props.color or C.panel2 }):Play()
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		Sounds.Play("UIClick")
		onClick()
	end)
	return button, label
end

function Theme.SetDisabled(button: GuiButton, disabled: boolean)
	button:SetAttribute("Disabled", disabled)
	button.BackgroundTransparency = disabled and 0.6 or 0.1
	local label = button:FindFirstChild("Label")
	if label then
		label.TextTransparency = disabled and 0.5 or 0
	end
end

-- Dark framed panel with a burgundy gradient and gold border.
function Theme.Panel(parent: Instance, props)
	props = props or {}
	local C = Theme.Colors
	local frame = Instance.new("Frame")
	frame.Name = props.name or "Panel"
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = props.transparency or 0.04
	frame.Size = props.dims or UDim2.fromScale(0.5, 0.6)
	frame.Position = props.pos or UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	frame.ZIndex = props.z or 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.Gradient(frame, C.panel2, C.bg, 90)
	Theme.Corner(frame, 10)
	Theme.Stroke(frame, C.gold, 1.2, 0.35)
	if props.maxSize then
		local size = Instance.new("UISizeConstraint")
		size.MaxSize = props.maxSize
		size.Parent = frame
	end
	return frame
end

-- Edge vignette made of four gradient strips (no image assets).
function Theme.Vignette(parent: Instance, color: Color3, strength: number, z: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Vignette"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = z or 1
	holder.Parent = parent
	local specs = {
		{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
	}
	for _, spec in specs do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.Size = spec[1]
		f.Position = spec[2]
		f.ZIndex = z or 1
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - strength),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
	return holder
end

return Theme
