local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent

-- UI構築
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 500)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = gui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- タイトルバー（閉じるボタン付き）
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- 下部の角丸を隠すためのカバー
local cover = Instance.new("Frame")
cover.Size = UDim2.new(1, 0, 0, 10)
cover.Position = UDim2.new(0, 0, 1, -10)
cover.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
cover.BorderSizePixel = 0
cover.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "ショップ"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.BackgroundTransparency = 1
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
closeButton.TextSize = 18
closeButton.Parent = titleBar

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- 依存関係
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EquipmentConstants = require(Shared:WaitForChild("EquipmentConstants"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestPurchaseEvent = Remotes:WaitForChild("Equipment"):WaitForChild(EquipmentConstants.REMOTE_PURCHASE_NAME)

-- コンテナ作成
local container = Instance.new("ScrollingFrame")
container.Name = "ProductContainer"
container.Size = UDim2.new(1, -20, 1, -60)
container.Position = UDim2.new(0, 10, 0, 50)
container.BackgroundTransparency = 1
container.CanvasSize = UDim2.new(0, 0, 0, 0)
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.ScrollBarThickness = 6
container.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.Parent = container
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0, 5)

-- 商品エントリ生成
local function createProductEntry(boardInfo)
	local frame = Instance.new("Frame")
	frame.Name = boardInfo.id
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	frame.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 150, 0, 30)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = boardInfo.displayName
	nameLabel.Parent = frame

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(0, 150, 0, 20)
	priceLabel.Position = UDim2.new(0, 10, 0, 35)
	priceLabel.BackgroundTransparency = 1
	priceLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
	priceLabel.Font = Enum.Font.GothamMedium
	priceLabel.TextSize = 14
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Text = "価格: " .. (boardInfo.price or 0) .. " G"
	priceLabel.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0, 100, 0, 40)
	buyButton.Position = UDim2.new(1, -110, 0.5, 0)
	buyButton.AnchorPoint = Vector2.new(0, 0.5)
	buyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 14
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.Text = "購入"
	buyButton.Parent = frame
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = buyButton
	
	return frame, buyButton
end

local productButtons = {} -- { [id] = { button, info } }

-- 商品リスト構築
if EquipmentConstants.BOARD_LIST then
	for _, boardInfo in ipairs(EquipmentConstants.BOARD_LIST) do
		-- 価格設定があるものだけ表示
		if (boardInfo.price or 0) > 0 then
			local frame, btn = createProductEntry(boardInfo)
			productButtons[boardInfo.id] = { button = btn, info = boardInfo }
			
			btn.MouseButton1Click:Connect(function()
				local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. boardInfo.id)
				if not isUnlocked then
					-- クリック時に所持金チェックを行う
					local currentMoney = player:GetAttribute("TrickScore") or 0
					local price = boardInfo.price or 0
					if currentMoney >= price then
						RequestPurchaseEvent:FireServer(boardInfo.id)
					else
						-- 資金不足フィードバック（必要なら音など）
						print("Not enough money")
					end
				end
			end)
		end
	end
end

-- ボタン状態更新
local function updateShopState()
	local currentMoney = player:GetAttribute("TrickScore") or 0
	
	for id, entry in pairs(productButtons) do
		local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. id)
		local price = entry.info.price or 0
		
		if isUnlocked then
			entry.button.Text = "購入済み"
			entry.button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			entry.button.Active = true -- 常にActiveにしておく
			entry.button.AutoButtonColor = false
		else
			if currentMoney >= price then
				entry.button.Text = "購入"
				entry.button.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
				entry.button.Active = true
				entry.button.AutoButtonColor = true
			else
				entry.button.Text = "資金不足"
				entry.button.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
				entry.button.Active = true -- 資金不足でもボタン自体は有効（クリック検知させるため）
				entry.button.AutoButtonColor = false
			end
		end
	end
end

-- 監視
player.AttributeChanged:Connect(function(attr)
	if attr == "TrickScore" or string.find(attr, EquipmentConstants.ATTR_UNLOCKED_PREFIX) then
		updateShopState()
	end
end)

-- 初期化
updateShopState()

-- ProximityPrompt検知
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if triggeredPlayer ~= player then return end
	
	-- 名前で簡易チェック
	if prompt.Name == "ShopPrompt" or 
	   (prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == "ShopNPC") then
		mainFrame.Visible = true
		updateShopState() -- 開いたときにも更新
	end
end)
