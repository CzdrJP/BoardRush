local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Constants
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipmentConstants"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipmentRemotes = Remotes:WaitForChild("Equipment")
local RequestEquipSkateboard = EquipmentRemotes:WaitForChild(Constants.REMOTE_EVENT_NAME)

-- Assets Path
local ITEM_ASSETS_NAME = "ItemAssets"
local SKATEBOARDS_FOLDER_NAME = "Skateboards"

--------------------------------------------------------------------------------
-- Asset Management
--------------------------------------------------------------------------------
local function ensureAssetFolder()
	local itemAssets = ReplicatedStorage:FindFirstChild(ITEM_ASSETS_NAME)
	if not itemAssets then
		itemAssets = Instance.new("Folder")
		itemAssets.Name = ITEM_ASSETS_NAME
		itemAssets.Parent = ReplicatedStorage
	end
	
	local boardsFolder = itemAssets:FindFirstChild(SKATEBOARDS_FOLDER_NAME)
	if not boardsFolder then
		boardsFolder = Instance.new("Folder")
		boardsFolder.Name = SKATEBOARDS_FOLDER_NAME
		boardsFolder.Parent = itemAssets
	end
	
	return boardsFolder
end

-- 仮モデル（BasicSkateboard）をコードで生成
local function ensureBasicSkateboardModel()
	local folder = ensureAssetFolder()
	if folder:FindFirstChild(Constants.DEFAULT_BOARD_NAME) then
		return folder[Constants.DEFAULT_BOARD_NAME]
	end
	
	-- Create Model
	local model = Instance.new("Model")
	model.Name = Constants.DEFAULT_BOARD_NAME
	
	-- Main Part (Board)
	local board = Instance.new("Part")
	board.Name = "BoardPart"
	board.Size = Vector3.new(2, 0.4, 6) -- W, H, L
	board.Color = Color3.fromRGB(80, 50, 20) -- Wood color
	board.Material = Enum.Material.Wood
	board.Anchored = false
	board.CanCollide = false
	board.Massless = true
	board.Parent = model
	
	-- PrimaryPart
	model.PrimaryPart = board
	
	model.Parent = folder
	print("[EquipmentService] Created BasicSkateboard asset.")
	return model
end

--------------------------------------------------------------------------------
-- Equip Logic
--------------------------------------------------------------------------------
local function equipSkateboard(player: Player)
	if not player.Character or not player.Character.Parent then return end
	
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then return end
	
	-- 多重装備防止
	if character:FindFirstChild(Constants.DEFAULT_BOARD_NAME) then
		-- 既に装備済みなら何もしない（あるいは再装備？）
		-- 今回は「既に持っていたらスキップ」
		return
	end
	
	-- アセット取得
	local template = ensureBasicSkateboardModel()
	local clone = template:Clone()
	clone.Name = Constants.DEFAULT_BOARD_NAME
	
	-- 位置合わせ (背中に背負う、あるいは足元？「装備」なので足元とする)
	-- R15/R6 両対応のため HumanoidRootPart 基準
	clone:SetPrimaryPartCFrame(rootPart.CFrame * CFrame.new(0, -2, 0) * CFrame.Angles(0, math.rad(90), 0))
	
	clone.Parent = character
	
	-- Weld
	local w = Instance.new("WeldConstraint")
	w.Part0 = rootPart
	w.Part1 = clone.PrimaryPart
	w.Parent = clone.PrimaryPart
	
	-- Attribute更新
	player:SetAttribute(Constants.ATTR_IS_EQUIPPED, true)
	player:SetAttribute(Constants.ATTR_EQUIPPED_ID, Constants.DEFAULT_BOARD_NAME)
	
	print("[EquipmentService] Equipped skateboard found on " .. player.Name)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- Remote Request
RequestEquipSkateboard.OnServerEvent:Connect(function(player)
	equipSkateboard(player)
end)

-- Respawn Listener
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- 少し待つ（ヒューマノイド等のロード待ち）
		task.wait(0.5) 
		
		-- 装備状態だったら再装備
		if player:GetAttribute(Constants.ATTR_IS_EQUIPPED) then
			equipSkateboard(player)
		end
	end)
end)

-- 既存プレイヤー対応 (Reload時など)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if player:GetAttribute(Constants.ATTR_IS_EQUIPPED) then
			equipSkateboard(player)
		end
	end)
end

ensureBasicSkateboardModel() -- 起動時にアセット生成確認
print("[EquipmentService] Initialized")
