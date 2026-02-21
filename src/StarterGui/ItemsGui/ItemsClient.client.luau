local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- -------------------------------------------------------------------------
-- Phase 0: 安全性チェックと重複排除
-- -------------------------------------------------------------------------

-- 1. 重複ItemsGuiのチェック
local guis = {}
for _, child in ipairs(playerGui:GetChildren()) do
	if child.Name == "ItemsGui" then
		table.insert(guis, child)
	end
end

if #guis > 1 then
	warn("[ItemsClient] PlayerGui内に複数のItemsGuiを検知しました！重複を削除します。")
	-- 自分自身（このスクリプトの祖先）を特定
	local myGui = script:FindFirstAncestor("ItemsGui")
	for _, g in ipairs(guis) do
		if g ~= myGui then
			g:Destroy()
			warn("[ItemsClient] 重複したItemsGuiを削除しました。")
		end
	end
end

-- 2. 依存関係の保護
local function safeWaitFor(parent, name, timeout)
	local obj = parent:WaitForChild(name, timeout)
	if not obj then
		warn(string.format("[ItemsClient] %.1f秒以内に %s が %s 内に見つかりませんでした。", timeout, name, parent.Name))
	end
	return obj
end

local Shared = safeWaitFor(ReplicatedStorage, "Shared", 5)
local Remotes = safeWaitFor(ReplicatedStorage, "Remotes", 5)

if not Shared or not Remotes then
	warn("[ItemsClient] 重大: 依存関係が見つかりません。UIは表示されますが機能しません。")
end

local EquipmentConstants = nil
if Shared then
	local module = safeWaitFor(Shared, "EquipmentConstants", 5)
	if module then
		EquipmentConstants = require(module)
	end
end

local RequestEquipEvent = nil
if Remotes and EquipmentConstants then
	local equipmentRemotes = safeWaitFor(Remotes, "Equipment", 5)
	if equipmentRemotes then
		RequestEquipEvent = safeWaitFor(equipmentRemotes, EquipmentConstants.REMOTE_EVENT_NAME, 5)
	end
end

-- -------------------------------------------------------------------------
-- UI構築 (Pop & Dynamic Design)
-- -------------------------------------------------------------------------
local ScreenGui = script.Parent

-- 既存UIがあれば削除（ホットリロード時の重複防止）
if ScreenGui:FindFirstChild("MainFrame") then ScreenGui.MainFrame:Destroy() end
if ScreenGui:FindFirstChild("OpenButton") then ScreenGui.OpenButton:Destroy() end

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
openCorner.CornerRadius = UDim.new(0, 8)

local openStroke = Instance.new("UIStroke", openButton)
openStroke.Color = Color3.fromRGB(200, 220, 255)
openStroke.Thickness = 3
openStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

addHoverAnimation(openButton, 1.08)

-- メインフレーム (丸みを帯びたポップなウィンドウ)
local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 540, 0, 420) -- 横幅を540に拡張 (110*4 + 15*3 + マージン)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.GroupTransparency = 1 
mainFrame.Parent = ScreenGui

local uiScale = Instance.new("UIScale", mainFrame)
uiScale.Scale = 0

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 8)

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
closeCorner.CornerRadius = UDim.new(0, 6)
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

local uiLayout = Instance.new("UIGridLayout")
uiLayout.Parent = container
uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiLayout.CellPadding = UDim2.new(0, 15, 0, 15)
uiLayout.CellSize = UDim2.new(0, 110, 0, 145)
uiLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function createItemEntry(itemId, itemName)
	local containerFrame = Instance.new("Frame")
	containerFrame.Name = itemId
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
	emoji.BackgroundTransparency = 1
	emoji.Text = "🛹"
	emoji.TextSize = 56

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
	nameLabel.Text = itemName
	nameLabel.Parent = containerFrame

	local equipBadge = Instance.new("Frame")
	equipBadge.Name = "EquipBadge"
	equipBadge.Size = UDim2.new(1, -20, 0, 24)
	equipBadge.AnchorPoint = Vector2.new(0.5, 1)
	equipBadge.Position = UDim2.new(0.5, 0, 1, -10)
	equipBadge.BackgroundColor3 = Color3.fromRGB(50, 220, 100)
	equipBadge.Visible = false
	equipBadge.Parent = actionButton
	
	local badgeCorner = Instance.new("UICorner", equipBadge)
	badgeCorner.CornerRadius = UDim.new(0, 8)
	
	local badgeText = Instance.new("TextLabel", equipBadge)
	badgeText.Size = UDim2.new(1, 0, 1, 0)
	badgeText.BackgroundTransparency = 1
	badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeText.Font = Enum.Font.GothamBlack
	badgeText.TextSize = 12
	badgeText.Text = "EQUIPPED"

	addHoverAnimation(actionButton, 1.05)

	return containerFrame, actionButton, stroke, equipBadge
end

-- -------------------------------------------------------------------------
-- UI ロジック
-- -------------------------------------------------------------------------

local isOpen = false

local function toggleUI()
	isOpen = not isOpen
	if isOpen then
		mainFrame.Visible = true
		mainFrame.Position = openButton.Position
		uiScale.Scale = 0
		
		TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			GroupTransparency = 0
		}):Play()
		TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1
		}):Play()
	else
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = openButton.Position,
			GroupTransparency = 1
		})
		local scaleTween = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0
		})
		closeTween:Play()
		scaleTween:Play()
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
			local itemFrame, actionBtn, stroke, badge = createItemEntry(boardInfo.id, displayName)
			boardButtons[boardInfo.id] = { frame = itemFrame, button = actionBtn, stroke = stroke, badge = badge, info = boardInfo }
			
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
	local _, actionBtn, stroke, badge = createItemEntry(skateboardId, skateboardId)
	boardButtons[skateboardId] = { button = actionBtn, stroke = stroke, badge = badge }
	actionBtn.MouseButton1Click:Connect(function()
		if RequestEquipEvent then RequestEquipEvent:FireServer(skateboardId) end
	end)
end

-- ボタン状態の更新
local function updateButtonState()
	if not EquipmentConstants then return end
	local equippedId = player:GetAttribute(EquipmentConstants.ATTR_EQUIPPED_ID)

	for boardId, entry in pairs(boardButtons) do
		if equippedId == boardId then
			entry.stroke.Color = Color3.fromRGB(50, 220, 100) -- Green
			entry.stroke.Thickness = 4
			entry.badge.Visible = true
		else
			entry.stroke.Color = Color3.fromRGB(220, 220, 235)
			entry.stroke.Thickness = 3
			entry.badge.Visible = false
		end
	end
end

-- 初期チェック
updateButtonState()

-- 属性変更の監視
player.AttributeChanged:Connect(function(attributeName)
	if EquipmentConstants and (
		attributeName == EquipmentConstants.ATTR_IS_EQUIPPED or 
		attributeName == EquipmentConstants.ATTR_EQUIPPED_ID
	) then
		updateButtonState()
	elseif EquipmentConstants and string.find(attributeName, EquipmentConstants.ATTR_UNLOCKED_PREFIX) then
		-- アンロック状態が変わったらリストを再構築
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		boardButtons = {}
		
		for _, boardInfo in ipairs(EquipmentConstants.BOARD_LIST) do
			local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. boardInfo.id)
			if isUnlocked then
				local itemFrame, actionBtn, stroke, badge = createItemEntry(boardInfo.id, boardInfo.displayName)
				boardButtons[boardInfo.id] = { frame = itemFrame, button = actionBtn, stroke = stroke, badge = badge, info = boardInfo }
				actionBtn.MouseButton1Click:Connect(function()
					if RequestEquipEvent then RequestEquipEvent:FireServer(boardInfo.id) end
				end)
			end
		end
		updateButtonState()
	end
end)

print("[ItemsClient] 初期化成功")

-- -------------------------------------------------------------------------
-- 走行音ミュート（装備中のみ）
-- -------------------------------------------------------------------------
local savedRunningVolume = nil

local function updateRunningSound()
	if not EquipmentConstants then return end
	local isEquipped = player:GetAttribute(EquipmentConstants.ATTR_IS_EQUIPPED)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local runningSound = hrp:FindFirstChild("Running")
	if not runningSound or not runningSound:IsA("Sound") then return end

	if isEquipped then
		if savedRunningVolume == nil then
			savedRunningVolume = runningSound.Volume
		end
		runningSound.Volume = 0
	else
		if savedRunningVolume ~= nil then
			runningSound.Volume = savedRunningVolume
			savedRunningVolume = nil
		end
	end
end

-- -------------------------------------------------------------------------
-- ライディングポーズ（クライアント側：アイドルアニメ再生）
-- -------------------------------------------------------------------------
local idleTrack = nil

local function updateRidingPose()
	if not EquipmentConstants then return end
	local isEquipped = player:GetAttribute(EquipmentConstants.ATTR_IS_EQUIPPED)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animate = character:FindFirstChild("Animate")

	if isEquipped then
		-- Animate無効化（走り・ジャンプ等を停止）
		if animate then
			animate.Disabled = true
		end

		-- 全AnimationTrack停止
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop(0)
				end

				-- Animateスクリプト内からアイドルアニメーションIDを取得
				local idleAnim = nil
				if animate then
					local idleFolder = animate:FindFirstChild("idle")
					if idleFolder then
						local anim = idleFolder:FindFirstChildOfClass("Animation")
						if anim then
							idleAnim = anim
						end
					end
				end

				-- アイドルアニメーションを再生
				if idleAnim then
					idleTrack = animator:LoadAnimation(idleAnim)
					idleTrack.Looped = true
					idleTrack.Priority = Enum.AnimationPriority.Movement
					idleTrack:Play()
				end
			end
		end
	else
		-- アイドルトラック停止
		if idleTrack then
			idleTrack:Stop(0)
			idleTrack:Destroy()
			idleTrack = nil
		end

		-- Animate復元
		if animate then
			animate.Disabled = false
		end
	end
end

-- -------------------------------------------------------------------------
-- 加速度方式の移動速度システム（装備中のみ）
-- -------------------------------------------------------------------------
local RunService = game:GetService("RunService")
local ACCEL_TIME = 2.0  -- 0→1 までの秒数
local DECEL_TIME = 1.3  -- 1→0 までの秒数
local speedFactor = 0
local accelConnection = nil

local function startAcceleration()
	if accelConnection then accelConnection:Disconnect() end
	speedFactor = 0
	local lastVelocity = Vector3.zero

	accelConnection = RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then return end

		local maxSpeed = player:GetAttribute("MaxWalkSpeed") or 32
		local moveDir = humanoid.MoveDirection
		local isMoving = moveDir.Magnitude > 0.01

		if isMoving then
			-- 加速フェーズ: WalkSpeedで通常移動
			speedFactor = math.min(1, speedFactor + dt / ACCEL_TIME)
			humanoid.WalkSpeed = maxSpeed * speedFactor
			-- 現在の水平速度を記録（慣性用）
			local vel = hrp.AssemblyLinearVelocity
			lastVelocity = Vector3.new(vel.X, 0, vel.Z)
		else
			if speedFactor > 0 then
				-- 減速フェーズ: WalkSpeed=0にしてHRP速度を直接制御
				speedFactor = math.max(0, speedFactor - dt / DECEL_TIME)
				humanoid.WalkSpeed = 0
				-- 慣性: 最後の速度を徐々に減衰
				local ratio = speedFactor / 1 -- 現在の減衰率
				local targetVel = lastVelocity * ratio
				hrp.AssemblyLinearVelocity = Vector3.new(
					targetVel.X,
					hrp.AssemblyLinearVelocity.Y, -- Y(重力)は維持
					targetVel.Z
				)
			else
				humanoid.WalkSpeed = 0
			end
		end
	end)
end

local function stopAcceleration()
	if accelConnection then
		accelConnection:Disconnect()
		accelConnection = nil
	end
	speedFactor = 0
end

-- -------------------------------------------------------------------------
-- イベント接続
-- -------------------------------------------------------------------------
player.AttributeChanged:Connect(function(attributeName)
	if EquipmentConstants and attributeName == EquipmentConstants.ATTR_IS_EQUIPPED then
		task.defer(updateRunningSound)
		task.defer(updateRidingPose)
		-- 加速度システム
		local isEquipped = player:GetAttribute(EquipmentConstants.ATTR_IS_EQUIPPED)
		if isEquipped then
			task.defer(startAcceleration)
		else
			stopAcceleration()
		end
	end
end)

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.5)
	updateRunningSound()
	updateRidingPose()
	-- リスポーン時は加速度も停止
	stopAcceleration()
end)

