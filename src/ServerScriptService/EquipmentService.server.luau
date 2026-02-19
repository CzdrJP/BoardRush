local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Constants
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipmentConstants"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipmentRemotes = Remotes:WaitForChild("Equipment")
local RequestEquipSkateboard = EquipmentRemotes:WaitForChild(Constants.REMOTE_EVENT_NAME)
local RequestPurchaseSkateboard = EquipmentRemotes:WaitForChild(Constants.REMOTE_PURCHASE_NAME)

--------------------------------------------------------------------------------
-- ポーズ定数（微調整用）
--------------------------------------------------------------------------------
local ARM_ANGLE_DEG  = 25   -- 腕のAポーズ角度（斜め下）
local LEAN_ANGLE_DEG = 15   -- 前傾角度

--------------------------------------------------------------------------------
-- ポーズ保存テーブル（プレイヤーごと）
--------------------------------------------------------------------------------
local savedPoseState = {} -- [player] = { animateDisabled, autoRotate, rootTransform, rightShoulderTF, leftShoulderTF }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function countBaseParts(model)
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then n = n + 1 end
	end
	return n
end

--------------------------------------------------------------------------------
-- Motor6D 探索（場所決め打ち禁止）
--------------------------------------------------------------------------------

-- 肩 Motor6D: GetDescendants() から Name 一致で取得（R15/R6 両対応）
local function findShoulderMotors(character)
	local right, left = nil, nil
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") then
			if desc.Name == "RightShoulder" or desc.Name == "Right Shoulder" then
				right = desc
			elseif desc.Name == "LeftShoulder" or desc.Name == "Left Shoulder" then
				left = desc
			end
		end
	end
	return right, left
end

-- Root Motor6D: HumanoidRootPart ↔ Torso/LowerTorso を繋ぐ Motor6D を Part0/Part1 で探索
local function findRootMotor(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	-- Torso (R6) or LowerTorso (R15)
	local torso = character:FindFirstChild("LowerTorso")
		or character:FindFirstChild("Torso")
	if not torso then return nil end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") then
			if (desc.Part0 == hrp and desc.Part1 == torso)
			or (desc.Part0 == torso and desc.Part1 == hrp) then
				return desc
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- ライディングポーズ適用 / 解除
--------------------------------------------------------------------------------
local function applyRidingPose(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootMotor = findRootMotor(character)

	local saved = {}

	-- 1) Humanoidプロパティ: 元の値を保存 + 調整
	if humanoid then
		saved.autoRotate = humanoid.AutoRotate
		saved.hipHeight = humanoid.HipHeight
		humanoid.HipHeight = humanoid.HipHeight + 0.5
		saved.walkSpeed = humanoid.WalkSpeed
		-- 最高速度をAttributeで公開（クライアントの加速度システムが使用）
		player:SetAttribute("MaxWalkSpeed", humanoid.WalkSpeed * 5)
		humanoid.WalkSpeed = 0 -- クライアントが加速度で制御
	end

	-- 2) C0 に-90°Y回転を掛けて体を横向きにする（アニメに上書きされない）
	if rootMotor then
		saved.rootC0 = rootMotor.C0
		rootMotor.C0 = rootMotor.C0 * CFrame.Angles(0, math.rad(-90), 0)
	end

	savedPoseState[player] = saved
	print("[EquipmentService] Applied riding pose for " .. player.Name)
end

local function removeRidingPose(player, character)
	local saved = savedPoseState[player]
	if not saved then return end

	if character and character.Parent then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootMotor = findRootMotor(character)

		-- 元の値へ復元
		if humanoid and saved.autoRotate ~= nil then
			humanoid.AutoRotate = saved.autoRotate
		end
		if humanoid and saved.hipHeight ~= nil then
			humanoid.HipHeight = saved.hipHeight
		end
		if humanoid and saved.walkSpeed ~= nil then
			humanoid.WalkSpeed = saved.walkSpeed
		end
		player:SetAttribute("MaxWalkSpeed", nil)
		if rootMotor and saved.rootC0 then
			rootMotor.C0 = saved.rootC0
		end

		print("[EquipmentService] Removed riding pose for " .. player.Name)
	end

	savedPoseState[player] = nil
end

--------------------------------------------------------------------------------
-- Equip / Unequip Logic
--------------------------------------------------------------------------------
local unequipSkateboard -- 前方宣言
-- BOARD_LISTからテンプレート名を取得するヘルパー
local function getTemplateName(boardId: string): string?
	for _, board in ipairs(Constants.BOARD_LIST) do
		if board.id == boardId then
			return board.templateName
		end
	end
	return nil
end

local function equipSkateboard(player: Player, boardName: string?)
	if not player.Character or not player.Character.Parent then return end
	
	-- デフォルトボード
	local boardId = boardName or Constants.DEFAULT_BOARD_NAME
	
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then return end
	
	-- 既に装備済みの場合
	local existing = character:FindFirstChild(Constants.EQUIPPED_INSTANCE_NAME)
	if existing then
		local currentId = player:GetAttribute(Constants.ATTR_EQUIPPED_ID)
		if currentId == boardId then
			-- 同じボードなら解除
			unequipSkateboard(player)
			return
		else
			-- 別のボードなら付け替え（先に解除）
			unequipSkateboard(player)
		end
	end
	
	-- ロック状態チェック (ボードIDに対応するアンロック属性を確認)
	local unlockAttr = Constants.ATTR_UNLOCKED_PREFIX .. boardId
	local isUnlocked = player:GetAttribute(unlockAttr)
	
	-- 定義されているボード情報を確認（価格0なら自動アンロック扱いにするか、明示的にアンロックするか）
	-- ここでは属性が必須とする（PlayerAddedで初期化）
	if not isUnlocked then
		warn("[EquipmentService] Item is locked: " .. boardId)
		return
	end
	
	-- テンプレート名取得
	local templateName = getTemplateName(boardId)
	if not templateName then
		warn("[EquipmentService] Unknown board: " .. boardId)
		return
	end
	
	-- アセット取得 (ServerStorage由来)
	local template = ServerStorage:FindFirstChild(templateName)
	if not template then
		warn("[EquipmentService] " .. templateName .. " not found in ServerStorage!")
		return
	end
	
	local clone = template:Clone()
	clone.Name = Constants.EQUIPPED_INSTANCE_NAME
	
	-- 安全ガード: BasePart数チェック
	local tmplCount = countBaseParts(template)
	local cloneCount = countBaseParts(clone)
	if tmplCount ~= cloneCount then
		warn("[EquipmentService] BasePart mismatch! tmpl=" .. tmplCount .. " clone=" .. cloneCount)
		clone:Destroy()
		return
	end
	
	-- PrimaryPart設定 (未設定なら自動設定)
	if not clone.PrimaryPart then
		local firstPart = clone:FindFirstChildWhichIsA("BasePart")
		if firstPart then
			clone.PrimaryPart = firstPart
		else
			warn("[EquipmentService] Skateboard model has no BaseParts!")
			clone:Destroy()
			return
		end
	end
	
	-- 物理設定 (追従・安全性確保)
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.Massless = true
			desc.CanQuery = false
			desc.CanTouch = false
		end
	end
	
	-- 位置合わせ (足元へのオフセット)
	local offset = CFrame.new(0.3, -2.94, 2.1) * CFrame.Angles(0, math.rad(180), 0)
	local targetCFrame = rootPart.CFrame * offset
	clone:PivotTo(targetCFrame)
	
	clone.Parent = character
	
	-- Weld
	local w = Instance.new("WeldConstraint")
	w.Part0 = rootPart
	w.Part1 = clone.PrimaryPart
	w.Parent = clone.PrimaryPart
	
	-- Attribute更新
	player:SetAttribute(Constants.ATTR_IS_EQUIPPED, true)
	player:SetAttribute(Constants.ATTR_EQUIPPED_ID, boardId)
	
	-- ライディングポーズ適用
	applyRidingPose(player, character)
	
	print("[EquipmentService] Equipped " .. boardId .. " on " .. player.Name)
end

--------------------------------------------------------------------------------
-- Unequip Logic
--------------------------------------------------------------------------------
unequipSkateboard = function(player: Player)
	if not player.Character or not player.Character.Parent then return end

	local character = player.Character

	-- 装備モデルを削除
	local equipped = character:FindFirstChild(Constants.EQUIPPED_INSTANCE_NAME)
	if equipped then
		equipped:Destroy()
	end

	-- ポーズ解除
	removeRidingPose(player, character)

	-- Attributeリセット
	player:SetAttribute(Constants.ATTR_IS_EQUIPPED, false)
	player:SetAttribute(Constants.ATTR_EQUIPPED_ID, "")

	print("[EquipmentService] Unequipped skateboard from " .. player.Name)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- Remote Request
RequestEquipSkateboard.OnServerEvent:Connect(function(player, boardName)
	equipSkateboard(player, boardName)
end)

-- Purchase Request
RequestPurchaseSkateboard.OnServerEvent:Connect(function(player, boardId)
	if not boardId then return end
	
	-- ボード定義検索
	local targetBoard = nil
	for _, b in ipairs(Constants.BOARD_LIST) do
		if b.id == boardId then
			targetBoard = b
			break
		end
	end
	
	if not targetBoard then
		warn("[EquipmentService] Purchase failed: Unknown board " .. tostring(boardId))
		return
	end
	
	-- 既にアンロック済みか確認
	local unlockAttr = Constants.ATTR_UNLOCKED_PREFIX .. boardId
	if player:GetAttribute(unlockAttr) then
		warn("[EquipmentService] Already unlocked: " .. boardId)
		return
	end
	
	-- 価格チェック
	local price = targetBoard.price or 0
	local currentMoney = player:GetAttribute("TrickScore") or 0
	
	if currentMoney >= price then
		-- 購入処理
		player:SetAttribute("TrickScore", currentMoney - price)
		player:SetAttribute(unlockAttr, true)
		print("[EquipmentService] User " .. player.Name .. " purchased " .. boardId .. " for " .. price)
	else
		warn("[EquipmentService] Not enough money for " .. boardId)
	end
end)

-- Respawn Listener
Players.PlayerAdded:Connect(function(player)
	-- 初期アンロック処理（無料アイテム）
	for _, b in ipairs(Constants.BOARD_LIST) do
		if (b.price or 0) <= 0 then
			player:SetAttribute(Constants.ATTR_UNLOCKED_PREFIX .. b.id, true)
		end
	end
	player.CharacterAdded:Connect(function(character)
		-- リスポーン時はポーズ状態をクリア & 装備状態リセット
		removeRidingPose(player, character)
		player:SetAttribute(Constants.ATTR_IS_EQUIPPED, false)
		player:SetAttribute(Constants.ATTR_EQUIPPED_ID, "")
	end)
end)

-- 既存プレイヤー対応 (Reload時など)
for _, player in ipairs(Players:GetPlayers()) do
	-- 初期化時に属性リセット
	player:SetAttribute(Constants.ATTR_IS_EQUIPPED, false)
	
	player.CharacterAdded:Connect(function(character)
		removeRidingPose(player, character)
		player:SetAttribute(Constants.ATTR_IS_EQUIPPED, false)
		player:SetAttribute(Constants.ATTR_EQUIPPED_ID, "")
	end)
end

-- プレイヤー離脱時クリーンアップ
Players.PlayerRemoving:Connect(function(player)
	savedPoseState[player] = nil
end)

print("[EquipmentService] Initialized (ServerStorage Source + Riding Pose)")
