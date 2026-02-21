-- -------------------------------------------------------------------------
-- UI構築 (Pop & Dynamic Design)
-- -------------------------------------------------------------------------
local ScreenGui = script.Parent

local function addHoverAnimation(guiObject, scaleTarget)
	scaleTarget = scaleTarget or 1.05
	local originalSize = guiObject.Size
	
	guiObject.MouseEnter:Connect(function()
		TweenService:Create(guiObject, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * scaleTarget, originalSize.Y.Scale, originalSize.Y.Offset * scaleTarget)
		}):Play()
	end)
	
	guiObject.MouseLeave:Connect(function()
		TweenService:Create(guiObject, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize
		}):Play()
	end)
end

-- 「アイテム」ボタン（画面右下）
local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.Size = UDim2.new(0, 140, 0, 50)
openButton.Position = UDim2.new(1, -160, 0.9, -30)
openButton.AnchorPoint = Vector2.new(0.5, 0.5)
openButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
openButton.TextColor3 = Color3.fromRGB(50, 150, 255)
openButton.Font = Enum.Font.GothamBlack
openButton.TextSize = 20
openButton.Text = "👜 ITEMS"
openButton.AutoButtonColor = false
openButton.Parent = ScreenGui

local openCorner = Instance.new("UICorner", openButton)
openCorner.CornerRadius = UDim.new(0, 25)

local openStroke = Instance.new("UIStroke", openButton)
openStroke.Color = Color3.fromRGB(200, 220, 255)
openStroke.Thickness = 3
openStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local openShadow = Instance.new("Frame")
openShadow.Name = "DropShadow"
openShadow.Size = UDim2.new(1, 0, 1, 4)
openShadow.Position = UDim2.new(0, 0, 0, 4)
openShadow.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
openShadow.ZIndex = openButton.ZIndex - 1
openShadow.Parent = openButton
local shadowCorner = Instance.new("UICorner", openShadow)
shadowCorner.CornerRadius = UDim.new(0, 25)

addHoverAnimation(openButton, 1.08)

-- メインフレーム (丸みを帯びたポップなウィンドウ)
local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 420)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.GroupTransparency = 1 
mainFrame.Parent = ScreenGui

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 20)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(220, 220, 240)
mainStroke.Thickness = 4

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -100, 0, 60)
titleLabel.Position = UDim2.new(0, 25, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(60, 60, 80)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 26
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Your Items"
titleLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -30, 0, 15)
closeButton.AnchorPoint = Vector2.new(0.5, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBlack
closeButton.TextSize = 20
closeButton.Text = "X"
closeButton.AutoButtonColor = false
closeButton.Parent = mainFrame
local closeCorner = Instance.new("UICorner", closeButton)
closeCorner.CornerRadius = UDim.new(1, 0)
addHoverAnimation(closeButton, 1.15)

local container = Instance.new("ScrollingFrame")
container.Name = "Container"
container.Size = UDim2.new(1, -30, 1, -80)
container.Position = UDim2.new(0, 15, 0, 65)
container.BackgroundTransparency = 1
container.CanvasSize = UDim2.new(0, 0, 0, 0)
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.ScrollBarThickness = 8
container.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 220)
container.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.Parent = container
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0, 12)
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function createItemEntry(itemId, itemName)
	local frame = Instance.new("Frame")
	frame.Name = itemId
	frame.Size = UDim2.new(1, -10, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.Parent = container

	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 15)
	
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(230, 230, 245)
	stroke.Thickness = 2
	
	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.new(1, 0, 1, 4)
	shadow.Position = UDim2.new(0, 0, 0, 4)
	shadow.BackgroundColor3 = Color3.fromRGB(240, 240, 250)
	shadow.ZIndex = frame.ZIndex - 1
	shadow.Parent = frame
	local sCorner = Instance.new("UICorner", shadow)
	sCorner.CornerRadius = UDim.new(0, 15)

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 54, 0, 54)
	icon.Position = UDim2.new(0, 15, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundColor3 = Color3.fromRGB(230, 240, 255)
	icon.Parent = frame
	local iconCorner = Instance.new("UICorner", icon)
	iconCorner.CornerRadius = UDim.new(0, 12)
	local emoji = Instance.new("TextLabel", icon)
	emoji.Size = UDim2.new(1, 0, 1, 0)
	emoji.BackgroundTransparency = 1
	emoji.Text = "🛹"
	emoji.TextSize = 32

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 120, 1, 0)
	nameLabel.Position = UDim2.new(0, 85, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextWrapped = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = itemName
	nameLabel.Parent = frame

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(0, 85, 0, 44)
	actionButton.Position = UDim2.new(1, -55, 0.5, 0)
	actionButton.AnchorPoint = Vector2.new(0.5, 0.5)
	actionButton.BackgroundColor3 = Color3.fromRGB(50, 220, 100)
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Font = Enum.Font.GothamBlack
	actionButton.TextSize = 16
	actionButton.Text = "装備"
	actionButton.AutoButtonColor = false
	actionButton.Parent = frame
	
	local uiCorner = Instance.new("UICorner", actionButton)
	uiCorner.CornerRadius = UDim.new(0, 12)
	
	addHoverAnimation(actionButton, 1.1)

	return frame, actionButton
end

-- -------------------------------------------------------------------------
-- UI ロジック
-- -------------------------------------------------------------------------

local isOpen = false

local function toggleUI()
	isOpen = not isOpen
	if isOpen then
		mainFrame.Visible = true
		mainFrame.Position = UDim2.new(0.5, 0, 0.55, 0)
		
		TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			GroupTransparency = 0
		}):Play()
	else
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0.55, 0),
			GroupTransparency = 1
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			if not isOpen then mainFrame.Visible = false end
		end)
	end
end

openButton.MouseButton1Click:Connect(toggleUI)
closeButton.MouseButton1Click:Connect(toggleUI)

local boardButtons = {}

if EquipmentConstants and EquipmentConstants.BOARD_LIST then
	for _, boardInfo in ipairs(EquipmentConstants.BOARD_LIST) do
		local displayName = boardInfo.displayName
		local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. boardInfo.id)
		
		if isUnlocked then
			local itemFrame, actionBtn = createItemEntry(boardInfo.id, displayName)
			boardButtons[boardInfo.id] = { frame = itemFrame, button = actionBtn, info = boardInfo }
			
			actionBtn.MouseButton1Click:Connect(function()
				if RequestEquipEvent then
					RequestEquipEvent:FireServer(boardInfo.id)
				end
			end)
		end
	end
else
	local skateboardId = "Skateboard"
	if EquipmentConstants then
		skateboardId = EquipmentConstants.DEFAULT_BOARD_NAME or "Skateboard"
	end
	local _, actionBtn = createItemEntry(skateboardId, skateboardId)
	actionBtn.MouseButton1Click:Connect(function()
		if RequestEquipEvent then RequestEquipEvent:FireServer(skateboardId) end
	end)
end

local function updateButtonState()
	if not EquipmentConstants then return end
	local equippedId = player:GetAttribute(EquipmentConstants.ATTR_EQUIPPED_ID)

	for boardId, entry in pairs(boardButtons) do
		if equippedId == boardId then
			entry.button.Text = "外す"
			entry.button.BackgroundColor3 = Color3.fromRGB(255, 100, 120) -- ピンクレッド
		else
			entry.button.Text = "装備"
			entry.button.BackgroundColor3 = Color3.fromRGB(50, 220, 100)   -- ライムグリーン
		end
	end
end
