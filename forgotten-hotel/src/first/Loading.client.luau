--!nonstrict
-- Loading screen (ReplicatedFirst runs before anything else replicates).

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local gold = Color3.fromRGB(196, 160, 92)
local gui = Instance.new("ScreenGui")
gui.Name = "HotelLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(6, 4, 6)
bg.BorderSizePixel = 0
bg.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(40, 10, 16), Color3.fromRGB(4, 2, 4))
gradient.Rotation = 90
gradient.Parent = bg

local function label(text, font, size, y, color, height)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(0.9, 0, 0, height)
	l.Font = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = l
	l.Parent = bg
	return l
end

label("الفندق المنسي", Enum.Font.Arial, 64, 0.4, gold, 70)
label("THE FORGOTTEN HOTEL", Enum.Font.Bodoni, 30, 0.48, Color3.fromRGB(230, 220, 200), 40)
local status = label("جارٍ تسجيل الوصول...", Enum.Font.Garamond, 22, 0.62, Color3.fromRGB(160, 148, 132), 26)
local tip = label("", Enum.Font.Garamond, 18, 0.88, Color3.fromRGB(130, 120, 110), 22)

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.7)
ring.Size = UDim2.fromOffset(36, 36)
ring.BackgroundTransparency = 1
ring.Parent = bg
local stroke = Instance.new("UIStroke")
stroke.Color = gold
stroke.Thickness = 3
stroke.Parent = ring
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = ring
local strokeGradient = Instance.new("UIGradient")
strokeGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) })
strokeGradient.Parent = stroke

local tips = {
	"تسلّل في الظلام ولن يكاد الظل يراك.",
	"شعاع المصباح يُرى من أقصى الفندق.",
	"اختبئ قبل أن يراك. إن رآك وأنت تدخل، سيسحبك إلى الخارج.",
	"حارسة الغرف لا تغادر غرفتها أبدًا. اخرج وستكون بأمان.",
	"اقرأ كل شيء. كل رمز في الفندق مكتوب في مكان ما.",
	"يمكن لرفاقك إنعاشك إن سقطت. ابقوا معًا.",
	"الركض صاخب. المشي أهدأ. التسلّل صامت.",
}
local running = true
task.spawn(function()
	local i = math.random(1, #tips)
	while running do
		tip.Text = tips[i]
		i = i % #tips + 1
		task.wait(4)
	end
end)
local spin = RunService.RenderStepped:Connect(function(dt)
	strokeGradient.Rotation = (strokeGradient.Rotation + dt * 360) % 360
end)

local started = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "فتح الأبواب..."
ReplicatedStorage:WaitForChild("Remotes")
ReplicatedStorage:WaitForChild("Shared")
status.Text = "الفندق يتذكّرك."
while os.clock() - started < 3 do
	task.wait(0.1)
end
running = false
for _, d in bg:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(1), { TextTransparency = 1 }):Play()
	end
end
TweenService:Create(stroke, TweenInfo.new(1), { Transparency = 1 }):Play()
TweenService:Create(bg, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
task.wait(1.6)
spin:Disconnect()
gui:Destroy()
