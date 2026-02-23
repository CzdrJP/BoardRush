local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent

-- 共通ホバーアニメーション関数
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

-- 既存のMainFrameがあれば削除（同じスクリプトの再実行時防止）
if gui:FindFirstChild("MainFrame") then
	gui.MainFrame:Destroy()
end

-- スタジオ内にコピー(ShopGuiの複製など)が残っている場合の強制排除 (一旦無効化)
-- for _, child in ipairs(player.PlayerGui:GetChildren()) do
-- 	if child:IsA("ScreenGui") and child ~= gui then
-- 		local duplicateMain = child:FindFirstChild("MainFrame")
-- 		if duplicateMain and duplicateMain:FindFirstChild("ProductContainer") then
-- 			child:Destroy()
-- 			print("[ShopClient] 別名のShop UI（または重複した古いUI）を検知したため強制削除しました:", child.Name)
-- 		end
-- 	end
-- end

-- UI構築 (Pop & Dynamic Design)
local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 540, 0, 420) -- ItemsUIと同じサイズ・グリッド構造に
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(245, 250, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.GroupTransparency = 1 
mainFrame.Parent = gui

local uiScale = Instance.new("UIScale", mainFrame)
uiScale.Scale = 0

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 8)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(200, 220, 240)
mainStroke.Thickness = 4

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -100, 0, 60)
titleLabel.Position = UDim2.new(0, 25, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(60, 80, 100)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 26
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Shop"
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
closeCorner.CornerRadius = UDim.new(0, 6)
addHoverAnimation(closeButton, 1.15)

-- コンテナ作成
local container = Instance.new("ScrollingFrame")
container.Name = "ProductContainer"
container.Size = UDim2.new(1, -30, 1, -80)
container.Position = UDim2.new(0, 15, 0, 65)
container.BackgroundTransparency = 1
container.CanvasSize = UDim2.new(0, 0, 0, 0)
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.ScrollBarThickness = 8
container.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 220)
container.Parent = mainFrame

local uiLayout = Instance.new("UIGridLayout")
uiLayout.Parent = container
uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiLayout.CellPadding = UDim2.new(0, 15, 0, 15)
uiLayout.CellSize = UDim2.new(0, 110, 0, 145)
uiLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- 依存関係の保護 (ItemsClientと同じ安全な取得方式)
local function safeWaitFor(parent, name, timeout)
	local obj = parent:WaitForChild(name, timeout)
	if not obj then
		warn(string.format("[ShopClient] %.1f秒以内に %s が %s 内に見つかりませんでした。", timeout, name, parent.Name))
	end
	return obj
end

local Shared = safeWaitFor(ReplicatedStorage, "Shared", 5)
local Remotes = safeWaitFor(ReplicatedStorage, "Remotes", 5)

local EquipmentConstants = nil
if Shared then
	local module = safeWaitFor(Shared, "EquipmentConstants", 5)
	if module then
		EquipmentConstants = require(module)
	end
end

local RequestPurchaseEvent = nil
if Remotes and EquipmentConstants then
	local equipmentRemotes = safeWaitFor(Remotes, "Equipment", 5)
	if equipmentRemotes then
		RequestPurchaseEvent = safeWaitFor(equipmentRemotes, EquipmentConstants.REMOTE_PURCHASE_NAME, 5)
	end
end

if not RequestPurchaseEvent then
	warn("[ShopClient] 致命的エラー: RequestPurchaseSkateboard イベントが取得できませんでした。購入処理は機能しません。")
end

-- 商品エントリ生成 (Popスタイル)
local function createProductEntry(boardInfo)
	local containerFrame = Instance.new("Frame")
	containerFrame.Name = boardInfo.id
	containerFrame.BackgroundTransparency = 1
	containerFrame.Parent = container

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(1, 0, 0, 110)
	actionButton.BackgroundColor3 = Color3.fromRGB(245, 245, 255)
	actionButton.Text = ""
	actionButton.AutoButtonColor = false
	actionButton.Parent = containerFrame

	local corner = Instance.new("UICorner", actionButton)
	corner.CornerRadius = UDim.new(0, 12)
	
	local stroke = Instance.new("UIStroke", actionButton)
	stroke.Color = Color3.fromRGB(220, 220, 235)
	stroke.Thickness = 3
	
	local emoji = Instance.new("TextLabel", actionButton)
	emoji.Size = UDim2.new(1, 0, 1, 0)
	emoji.Position = UDim2.new(0, 0, -0.1, 0)
	emoji.BackgroundTransparency = 1
	emoji.Text = "🛹"
	emoji.TextSize = 50
	emoji.Active = false -- ★クリック吸収防止

	local priceLabel = Instance.new("TextLabel", actionButton)
	priceLabel.Size = UDim2.new(1, 0, 0, 20)
	priceLabel.Position = UDim2.new(0, 0, 0.7, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
	priceLabel.Font = Enum.Font.GothamBlack
	priceLabel.TextSize = 14
	priceLabel.Text = (boardInfo.price or 0) .. " G"
	priceLabel.Active = false -- ★クリック吸収防止

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 25)
	nameLabel.Position = UDim2.new(0, 0, 0, 120)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(80, 80, 100)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextWrapped = true
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Text = boardInfo.displayName
	nameLabel.Active = false -- ★クリック吸収防止
	nameLabel.Parent = containerFrame

	local statusBadge = Instance.new("Frame")
	statusBadge.Name = "StatusBadge"
	statusBadge.Size = UDim2.new(1, 10, 0, 28)
	statusBadge.AnchorPoint = Vector2.new(0.5, 1)
	statusBadge.Position = UDim2.new(0.5, 0, 1, -10)
	statusBadge.BackgroundColor3 = Color3.fromRGB(50, 220, 100)
	statusBadge.Visible = false
	statusBadge.Active = false -- ★クリック吸収防止
	statusBadge.Parent = actionButton
	
	local badgeCorner = Instance.new("UICorner", statusBadge)
	badgeCorner.CornerRadius = UDim.new(0, 8)
	
	local badgeText = Instance.new("TextLabel", statusBadge)
	badgeText.Size = UDim2.new(1, 0, 1, 0)
	badgeText.BackgroundTransparency = 1
	badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeText.Font = Enum.Font.GothamBlack
	badgeText.TextSize = 14
	badgeText.Text = "BOUGHT"
	badgeText.Active = false -- ★クリック吸収防止

	addHoverAnimation(actionButton, 1.05)

	return containerFrame, actionButton, stroke, statusBadge
end

local productButtons = {} -- { [id] = { button, stroke, badge, info } }

-- 商品リスト構築
if EquipmentConstants.BOARD_LIST then
	for _, boardInfo in ipairs(EquipmentConstants.BOARD_LIST) do
		-- 価格設定があるものだけ表示
		if (boardInfo.price or 0) > 0 then
			local frame, btn, stroke, badge = createProductEntry(boardInfo)
			productButtons[boardInfo.id] = { button = btn, stroke = stroke, badge = badge, info = boardInfo }
			
			local isProcessingPurchase = false
			
			btn.MouseButton1Click:Connect(function()
				if isProcessingPurchase then return end
				
				local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. boardInfo.id)
				if not isUnlocked then
					-- クリック時に所持金チェックを行う
					local currentMoney = player:GetAttribute("TrickScore") or 0
					local price = boardInfo.price or 0
					
					print(string.format("[ShopClient] Attempting to buy %s | Money: %d / Price: %d", boardInfo.id, currentMoney, price))
					
					if currentMoney >= price then
						isProcessingPurchase = true
						RequestPurchaseEvent:FireServer(boardInfo.id)
						
						-- 数秒後にデバウンス解除（サーバーから応答がない場合のフェイルセーフ）
						task.delay(1.5, function()
							isProcessingPurchase = false
						end)
					else
						print("[ShopClient] Not enough money. Required:", price, "Current:", currentMoney)
					end
				else
					print("[ShopClient] Already unlocked:", boardInfo.id)
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
			entry.stroke.Color = Color3.fromRGB(150, 150, 150)
			entry.stroke.Thickness = 3
			entry.badge.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			entry.badge.Visible = true
			entry.badge:FindFirstChildOfClass("TextLabel").Text = "BOUGHT"
		else
			if currentMoney >= price then
				entry.stroke.Color = Color3.fromRGB(50, 200, 255)
				entry.stroke.Thickness = 3
				entry.badge.Visible = false
			else
				entry.stroke.Color = Color3.fromRGB(255, 100, 100)
				entry.stroke.Thickness = 3
				entry.badge.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
				entry.badge.Visible = true
				entry.badge:FindFirstChildOfClass("TextLabel").Text = "NO MONEY"
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

-- UI開閉ロジック
local isOpen = false

local function toggleUI(forceState)
	if forceState ~= nil then
		isOpen = forceState
	else
		isOpen = not isOpen
	end
	
	-- ★もし古いスクリプトが裏でFrame型のMainFrameを生成してしまっていたら、開く直前に破壊する
	for _, child in ipairs(gui:GetChildren()) do
		if child.Name == "MainFrame" and child:IsA("Frame") then
			child:Destroy()
			print("[ShopClient] 古いスクリプトによるUIを検知・排除しました")
		end
	end

	if isOpen then
		updateShopState()
		mainFrame.Visible = true
		mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		uiScale.Scale = 0.8 -- 少し小さめから出現
		
		TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0
		}):Play()
		TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1
		}):Play()
	else
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 1
		})
		local scaleTween = TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.8
		})
		closeTween:Play()
		scaleTween:Play()
		closeTween.Completed:Connect(function()
			if not isOpen then mainFrame.Visible = false end
		end)
	end
end

closeButton.MouseButton1Click:Connect(function()
	toggleUI(false)
end)

-- ProximityPrompt検知
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if triggeredPlayer ~= player then return end
	
	if prompt.Name == "ShopPrompt" or 
	   (prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == "ShopNPC") then
		toggleUI(true)
	end
end)

print("[ShopClient] Initialized RequestPurchaseEvent path:", RequestPurchaseEvent and RequestPurchaseEvent.GetFullName and RequestPurchaseEvent:GetFullName() or "NIL")
