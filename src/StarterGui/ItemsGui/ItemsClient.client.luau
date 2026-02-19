local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

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
-- UI構築 (ファイル同期トラブル回避のためコードで生成)
-- -------------------------------------------------------------------------
local ScreenGui = script.Parent

-- UI要素を生成

-- 「アイテム」ボタン
local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.Size = UDim2.new(0, 120, 0, 40)
openButton.Position = UDim2.new(1, -140, 0.9, -10) -- 右下
openButton.AnchorPoint = Vector2.new(0, 0)
openButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 18
openButton.Text = "アイテム"
openButton.Parent = ScreenGui

-- メインフレーム
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = ScreenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.Text = "アイテム"
titleLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.Parent = mainFrame

local container = Instance.new("ScrollingFrame")
container.Name = "Container"
container.Size = UDim2.new(1, -20, 1, -60)
container.Position = UDim2.new(0, 10, 0, 50)
container.BackgroundTransparency = 1
container.CanvasSize = UDim2.new(0, 0, 0, 0) -- レイアウトにより自動調整
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.ScrollBarThickness = 6
container.Parent = mainFrame

local uiList = Instance.new("UIListLayout")
uiList.Parent = container
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Padding = UDim.new(0, 5)

-- アイテムテンプレート生成関数
local function createItemEntry(itemId, itemName)
	local frame = Instance.new("Frame")
	frame.Name = itemId
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	frame.Parent = container

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 50, 0, 50)
	icon.Position = UDim2.new(0, 5, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- 仮の背景色
	icon.Image = "" -- 仮画像（プレースホルダー）
	icon.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 120, 1, 0)
	nameLabel.Position = UDim2.new(0, 65, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = itemName
	nameLabel.Parent = frame

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(0, 80, 0, 36)
	actionButton.Position = UDim2.new(1, -90, 0.5, 0)
	actionButton.AnchorPoint = Vector2.new(0, 0.5)
	actionButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Font = Enum.Font.GothamBold
	actionButton.TextSize = 14
	actionButton.Text = "装備する"
	actionButton.AutoButtonColor = true
	actionButton.Parent = frame
	
	-- 角丸
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 4)
	uiCorner.Parent = actionButton

	return frame, actionButton
end

-- -------------------------------------------------------------------------
-- UI ロジック
-- -------------------------------------------------------------------------

-- 開閉処理
openButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- アイテムリスト描画（複数ボード対応）
local boardButtons = {} -- { [boardId] = { frame, button } }
-- アイテム欄での購入機能は削除（ショップUI分離のため）

if EquipmentConstants and EquipmentConstants.BOARD_LIST then
	for _, boardInfo in ipairs(EquipmentConstants.BOARD_LIST) do
		local displayName = boardInfo.displayName
		-- 価格表示は維持するが、ここでは購入不可
		
		local itemFrame, actionBtn = createItemEntry(boardInfo.id, displayName)
		boardButtons[boardInfo.id] = { frame = itemFrame, button = actionBtn, info = boardInfo }
		
		-- 各ボタンのクリックイベント
		actionBtn.MouseButton1Click:Connect(function()
			local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. boardInfo.id)
			-- Purchase処理は削除
			
			if isUnlocked then
				-- 装備/解除
				if RequestEquipEvent then
					RequestEquipEvent:FireServer(boardInfo.id)
				end
			end
		end)
	end
else
	-- フォールバック: 旧形式(略)
end

-- ボタン状態の更新
local function updateButtonState()
	if not EquipmentConstants then return end
	
	local equippedId = player:GetAttribute(EquipmentConstants.ATTR_EQUIPPED_ID)
	-- money監視は不要になったが、UI更新トリガーとしては残る

	for boardId, entry in pairs(boardButtons) do
		local isUnlocked = player:GetAttribute(EquipmentConstants.ATTR_UNLOCKED_PREFIX .. boardId)
		
		if isUnlocked then
			-- アンロック済み
			if equippedId == boardId then
				entry.button.Text = "解除する"
				entry.button.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- 赤
			else
				entry.button.Text = "装備する"
				entry.button.BackgroundColor3 = Color3.fromRGB(0, 180, 0)   -- 緑
			end
			entry.button.AutoButtonColor = true
			entry.button.Active = true
			entry.button.Transparency = 0
		else
			-- 未ロック（ロック中）
			entry.button.Text = "ロック中"
			entry.button.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- グレー
			entry.button.AutoButtonColor = false
			entry.button.Active = false
		end
	end
end

-- 初期チェック
updateButtonState()

-- 属性変更の監視
player.AttributeChanged:Connect(function(attributeName)
	if EquipmentConstants and (
		attributeName == EquipmentConstants.ATTR_IS_EQUIPPED or 
		attributeName == EquipmentConstants.ATTR_EQUIPPED_ID or
		string.find(attributeName, EquipmentConstants.ATTR_UNLOCKED_PREFIX)
	) then
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

