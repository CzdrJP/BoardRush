local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent

-- Shared
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(sharedFolder:WaitForChild("EquipmentConstants"))

-- Remote
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local equipRemote = Remotes:WaitForChild("Equipment"):WaitForChild(Constants.REMOTE_EVENT_NAME)

--------------------------------------------------------------------------------
-- UI Construction (Code-based)
--------------------------------------------------------------------------------

-- 1. Items Button (Right Side)
local itemsBtn = Instance.new("TextButton")
itemsBtn.Name = "ItemsButton"
itemsBtn.Size = UDim2.new(0, 100, 0, 40)
itemsBtn.Position = UDim2.new(1, -120, 0.5, -20) -- Right Middle
itemsBtn.AnchorPoint = Vector2.new(0, 0.5)
itemsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
itemsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
itemsBtn.Text = "Items"
itemsBtn.TextSize = 18
itemsBtn.Font = Enum.Font.GothamBold
itemsBtn.Parent = gui

local uic = Instance.new("UICorner")
uic.CornerRadius = UDim.new(0, 8)
uic.Parent = itemsBtn

-- 2. Items Window (Center)
local window = Instance.new("Frame")
window.Name = "ItemsWindow"
window.Size = UDim2.new(0, 300, 0, 200)
window.Position = UDim2.new(0.5, 0, 0.5, 0)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
window.Visible = false
window.Parent = gui

local wic = Instance.new("UICorner")
wic.CornerRadius = UDim.new(0, 12)
wic.Parent = window

local title = Instance.new("TextLabel")
title.Text = "Equipment"
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(200, 200, 200)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = window

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextColor3 = Color3.Color3.new(1,1,1)
closeBtn.Parent = window
local cic = Instance.new("UICorner"); cic.Parent = closeBtn

-- 3. List Item (Skateboard Row)
local row = Instance.new("Frame")
row.Name = "ItemRow"
row.Size = UDim2.new(0.9, 0, 0, 50)
row.Position = UDim2.new(0.05, 0, 0.3, 0)
row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
row.Parent = window
local ric = Instance.new("UICorner"); ric.Parent = row

local icon = Instance.new("ImageLabel")
icon.Name = "Icon"
icon.Size = UDim2.new(0, 40, 0, 40)
icon.Position = UDim2.new(0, 5, 0, 5)
icon.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
icon.Image = "rbxassetid://9701275785" -- 仮アイコン (Skateboard asset ID reused if valid image, else blank)
icon.Parent = row
local iic = Instance.new("UICorner"); iic.Parent = icon

local label = Instance.new("TextLabel")
label.Text = "Basic Skateboard"
label.Size = UDim2.new(0.5, 0, 1, 0)
label.Position = UDim2.new(0, 55, 0, 0)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1, 1, 1)
label.TextXAlignment = Enum.TextXAlignment.Left
label.Font = Enum.Font.Gotham
label.Parent = row

-- Equip Button
local equipBtn = Instance.new("TextButton")
equipBtn.Name = "EquipButton"
equipBtn.Text = "装備する"
equipBtn.Size = UDim2.new(0, 80, 0, 30)
equipBtn.Position = UDim2.new(1, -90, 0.5, 0)
equipBtn.AnchorPoint = Vector2.new(0, 0.5)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
equipBtn.TextColor3 = Color3.new(1, 1, 1)
equipBtn.Font = Enum.Font.GothamBold
equipBtn.Parent = row
local eic = Instance.new("UICorner"); eic.Parent = equipBtn

--------------------------------------------------------------------------------
-- Logic
--------------------------------------------------------------------------------

local isProcessing = false

-- Open/Close
itemsBtn.MouseButton1Click:Connect(function()
	window.Visible = not window.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
	window.Visible = false
end)

-- Equip Handling
equipBtn.MouseButton1Click:Connect(function()
	if isProcessing then return end
	if player:GetAttribute(Constants.ATTR_IS_EQUIPPED) then return end -- Already equipped check
	
	isProcessing = true
	equipBtn.Text = "処理中..."
	equipBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	
	task.delay(0.5, function() -- Pseudo debounce / feedback delay
		equipRemote:FireServer()
		
		-- Optimistic Update
		equipBtn.Text = "装備中"
		equipBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
		equipBtn.AutoButtonColor = false
		-- isProcessing remains true to prevent re-click? Or release after cooldown?
		-- For MVP, once equipped, stay equipped.
		
		isProcessing = false 
		-- If we supported unequip, we would toggle here.
	end)
end)

-- Attribute Listener (Sync state if equipped from server/respawn)
player:GetAttributeChangedSignal(Constants.ATTR_IS_EQUIPPED):Connect(function()
	local isEquipped = player:GetAttribute(Constants.ATTR_IS_EQUIPPED)
	if isEquipped then
		equipBtn.Text = "装備中"
		equipBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
	else
		equipBtn.Text = "装備する"
		equipBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
	end
end)

-- Init Check
if player:GetAttribute(Constants.ATTR_IS_EQUIPPED) then
	equipBtn.Text = "装備中"
	equipBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
end

print("[ItemsGuiController] Initialized")
