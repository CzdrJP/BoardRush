--[[
    SkateboardService.server.lua
    -----------------------------
    スケボーの見た目適用 + EquipItem ハンドラ
    
    責務:
    - Remote ハンドラ（EquipItem のみ）
    - 装備時の見た目適用 / 解除時の復帰（Motor6D.Transform + ボードWeld）
    - 所有/所持データは InventoryService に委譲（_G.InventoryGetState 経由で参照）
    
    安全設計:
    - R15前提 + R6フォールバック（HRP基準配置）
    - Motor6D存在差の吸収（見つかったものだけ適用/復帰）
    - クローンのサニタイズ（Script/Prompt除去）
    - 物理影響ゼロ（Massless/NoCollide/NoTouch/NoQuery）
    - リスポーン時は装備維持＋自動再装備
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local EquipItem    = Remotes:WaitForChild("EquipItem")

---------------------------------------------------------------------------
-- 設定定数
---------------------------------------------------------------------------
local SOURCE_NAME          = "skateboard"         -- Workspace内の元アセット名
local EQUIPPED_MODEL_NAME  = "SkateboardEquipped" -- Character内の装備モデル名

-- ボード配置オフセット（TBD：現場で微調整）
local BOARD_OFFSET    = CFrame.new(0, -2.6, -0.1) * CFrame.Angles(0, math.rad(90), 0)  -- R15: LowerTorso基準
local BOARD_OFFSET_R6 = CFrame.new(0, -3.0, -0.1) * CFrame.Angles(0, math.rad(90), 0)  -- R6: HRP基準

local SIDEWAYS_Y_DEG = 90  -- 横向き角度

---------------------------------------------------------------------------
-- 内部状態（見た目管理用: SavedTransforms のみ）
-- 所有/装備データは InventoryService (_G.InventoryGetState) を参照
---------------------------------------------------------------------------
local transformsByUserId = {}  -- userId -> { [Motor6D] = CFrame }

local function getTransforms(player)
    local t = transformsByUserId[player.UserId]
    if not t then
        t = {}
        transformsByUserId[player.UserId] = t
    end
    return t
end

--- InventoryService の state を取得（起動順で遅延する場合に備え待機）
local function getInventoryState(player)
    -- _G.InventoryGetState が InventoryService から公開される
    local fn = _G.InventoryGetState
    if not fn then
        warn("[SkateboardService] InventoryService not ready yet")
        return nil
    end
    return fn(player)
end

local function getCharacterParts(player)
    local character = player.Character
    if not character then return nil end
    local humanoid   = character:FindFirstChildOfClass("Humanoid")
    local hrp        = character:FindFirstChild("HumanoidRootPart")
    local lowerTorso = character:FindFirstChild("LowerTorso")
    return character, humanoid, hrp, lowerTorso
end

---------------------------------------------------------------------------
-- ユーティリティ: クローン安全化
---------------------------------------------------------------------------

--- クローン後のサニタイズ: Script系・ProximityPrompt を除去
local function sanitizeClone(model)
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("ProximityPrompt")
            or inst:IsA("Script")
            or inst:IsA("LocalScript")
            or inst:IsA("ModuleScript") then
            inst:Destroy()
        end
    end
end

--- 全BasePartに物理影響ゼロ設定を適用
local function configureBoardParts(model)
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            inst.Anchored    = false
            inst.CanCollide  = false
            inst.CanTouch    = false
            inst.CanQuery    = false
            inst.Massless    = true
            inst.CastShadow  = false
        end
    end
end

---------------------------------------------------------------------------
-- ユーティリティ: Motor6D Transform
---------------------------------------------------------------------------

--- Motor6D検索（存在差を吸収: 見つからなければnil）
local function findMotor(character, name)
    local m = character:FindFirstChild(name, true)
    if m and m:IsA("Motor6D") then
        return m
    end
    return nil
end

--- Motor6D.Transform の保存→適用（存在する場合のみ）
local function saveAndApplyTransform(transforms, motor, transformCFrame)
    if not motor then return end
    if transforms[motor] == nil then
        transforms[motor] = motor.Transform
    end
    motor.Transform = transformCFrame
end

--- 保存テーブルの全Motor6D.Transform を復帰（復帰漏れゼロ）
local function restoreAllTransforms(transforms)
    if not transforms then return end
    for motor, original in pairs(transforms) do
        if motor and motor.Parent then
            motor.Transform = original
        end
    end
    -- テーブルをクリア
    for k in pairs(transforms) do transforms[k] = nil end
end

---------------------------------------------------------------------------
-- R15 姿勢適用（横向き + 乗ってるスタンス）
---------------------------------------------------------------------------
local function setSidewaysPoseR15(transforms, character)
    -- RootJoint を横向きにする（R15では "RootJoint" または "Root"）
    local rootJoint = findMotor(character, "RootJoint") or findMotor(character, "Root")
    if rootJoint then
        saveAndApplyTransform(transforms, rootJoint, CFrame.Angles(0, math.rad(SIDEWAYS_Y_DEG), 0))
    end

    -- 脚: 存在するMotor6Dだけ適用
    local rightHip   = findMotor(character, "RightHip")
    local leftHip    = findMotor(character, "LeftHip")
    local rightKnee  = findMotor(character, "RightKnee")
    local leftKnee   = findMotor(character, "LeftKnee")
    local rightAnkle = findMotor(character, "RightAnkle")
    local leftAnkle  = findMotor(character, "LeftAnkle")

    -- 股関節：少し開いて少し前に
    if rightHip then
        saveAndApplyTransform(transforms, rightHip, CFrame.Angles(math.rad(-10), math.rad(8), math.rad(10)))
    end
    if leftHip then
        saveAndApplyTransform(transforms, leftHip, CFrame.Angles(math.rad(-10), math.rad(-8), math.rad(-10)))
    end

    -- 膝：少し曲げる
    if rightKnee then
        saveAndApplyTransform(transforms, rightKnee, CFrame.Angles(math.rad(18), 0, 0))
    end
    if leftKnee then
        saveAndApplyTransform(transforms, leftKnee, CFrame.Angles(math.rad(18), 0, 0))
    end

    -- 足首
    if rightAnkle then
        saveAndApplyTransform(transforms, rightAnkle, CFrame.Angles(math.rad(-8), 0, 0))
    end
    if leftAnkle then
        saveAndApplyTransform(transforms, leftAnkle, CFrame.Angles(math.rad(-8), 0, 0))
    end

    -- 腰（Waist）
    local waist = findMotor(character, "Waist")
    if waist then
        saveAndApplyTransform(transforms, waist, CFrame.Angles(math.rad(-6), 0, 0))
    end
end

--- R6フォールバック: RootJointだけ横向き
local function setSidewaysPoseR6(transforms, character)
    local rootJoint = findMotor(character, "RootJoint")
    if rootJoint then
        saveAndApplyTransform(transforms, rootJoint, CFrame.Angles(0, math.rad(SIDEWAYS_Y_DEG), 0))
    end
end

---------------------------------------------------------------------------
-- ボード溶接
---------------------------------------------------------------------------
local function attachBoard(boardModel, character, anchorPart, offset)
    if not boardModel.PrimaryPart then
        local pp = boardModel:FindFirstChildWhichIsA("BasePart", true)
        if pp then boardModel.PrimaryPart = pp end
    end
    if not boardModel.PrimaryPart then return false end
    if not anchorPart then return false end

    boardModel.Name = EQUIPPED_MODEL_NAME
    boardModel.Parent = character

    boardModel:PivotTo(anchorPart.CFrame * offset)

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = anchorPart
    weld.Part1 = boardModel.PrimaryPart
    weld.Parent = boardModel.PrimaryPart

    return true
end

---------------------------------------------------------------------------
-- 装備チェック・除去
---------------------------------------------------------------------------
local function isEquipped(character)
    return character:FindFirstChild(EQUIPPED_MODEL_NAME) ~= nil
end

local function removeBoard(character)
    local m = character:FindFirstChild(EQUIPPED_MODEL_NAME)
    if m and m:IsA("Model") then
        m:Destroy()
    end
end

---------------------------------------------------------------------------
-- ソースモデル取得
---------------------------------------------------------------------------
local function getSourceModel()
    local src = workspace:FindFirstChild(SOURCE_NAME)
    if not src then return nil end
    if src:IsA("Model") then return src end
    if src:IsA("BasePart") then
        local wrap = Instance.new("Model")
        wrap.Name = SOURCE_NAME
        src.Parent = wrap
        wrap.Parent = workspace
        return wrap
    end
    return nil
end

---------------------------------------------------------------------------
-- 装備（見た目適用）
---------------------------------------------------------------------------
local function equipSkateboard(player)
    local character, _, hrp, lowerTorso = getCharacterParts(player)
    if not character then return false end
    if isEquipped(character) then return true end  -- 既に装備済み

    local src = getSourceModel()
    if not src then
        warn("[SkateboardService] Workspace." .. SOURCE_NAME .. " not found")
        return false
    end

    local transforms = getTransforms(player)

    -- クローン → サニタイズ → 物理ゼロ化
    local clone = src:Clone()
    sanitizeClone(clone)
    configureBoardParts(clone)

    -- R15判定: LowerTorsoの有無で分岐
    local ok
    if lowerTorso then
        ok = attachBoard(clone, character, lowerTorso, BOARD_OFFSET)
        if ok then setSidewaysPoseR15(transforms, character) end
    elseif hrp then
        ok = attachBoard(clone, character, hrp, BOARD_OFFSET_R6)
        if ok then setSidewaysPoseR6(transforms, character) end
    end

    if not ok then
        clone:Destroy()
        warn("[SkateboardService] Failed to attach board for " .. player.Name)
        return false
    end

    return true
end

---------------------------------------------------------------------------
-- 解除（見た目復帰）
---------------------------------------------------------------------------
local function unequipSkateboard(player)
    local character = player.Character
    if not character then return end

    local transforms = getTransforms(player)
    removeBoard(character)
    restoreAllTransforms(transforms)
end

-- PurchaseItem / GetInventory は InventoryService に委譲済み

---------------------------------------------------------------------------
-- Remote ハンドラ: EquipItem
-- 所有チェックは InventoryService の state を参照
---------------------------------------------------------------------------
EquipItem.OnServerEvent:Connect(function(player, itemId, action)
    if type(itemId) ~= "string" then return end
    if type(action) ~= "string" then return end

    local invState = getInventoryState(player)
    if not invState then return end

    -- 所有チェック（InventoryService の owned テーブルを参照）
    if not invState.owned[itemId] then
        warn("[SkateboardService] " .. player.Name .. " does not own: " .. itemId)
        return
    end

    -- 現在 skateboard のみ対応
    if itemId ~= "skateboard" then
        warn("[SkateboardService] Unknown item: " .. itemId)
        return
    end

    -- action 処理
    if action == "equip" then
        if invState.equipped == itemId then return end
        local ok = equipSkateboard(player)
        if ok then
            invState.equipped = itemId
            if _G.InventoryNotify then _G.InventoryNotify(player) end
        end

    elseif action == "unequip" then
        if invState.equipped ~= itemId then return end
        unequipSkateboard(player)
        invState.equipped = nil
        if _G.InventoryNotify then _G.InventoryNotify(player) end

    elseif action == "toggle" then
        if invState.equipped == itemId then
            unequipSkateboard(player)
            invState.equipped = nil
        else
            local ok = equipSkateboard(player)
            if ok then
                invState.equipped = itemId
            end
        end
        if _G.InventoryNotify then _G.InventoryNotify(player) end
    end
end)

---------------------------------------------------------------------------
-- ライフサイクル: リスポーン時は装備維持＋自動再装備
---------------------------------------------------------------------------
local function onCharacterAdded(player)
    task.defer(function()
        -- SavedTransforms をクリア（古いMotor6D参照が無効になるため）
        local transforms = getTransforms(player)
        for k in pairs(transforms) do transforms[k] = nil end

        -- 装備中なら自動で再適用（InventoryService の state を参照）
        local invState = getInventoryState(player)
        if invState and invState.equipped == "skateboard" then
            task.wait(0.1)
            if player.Character and player.Character.Parent then
                equipSkateboard(player)
            end
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        onCharacterAdded(player)
    end)
end)

-- 既にいるプレイヤー対応（Studioテスト用）
for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        onCharacterAdded(player)
    end)
    -- 既にキャラがいる場合
    if player.Character then
        onCharacterAdded(player)
    end
end

-- プレイヤー離脱時: transforms クリア
Players.PlayerRemoving:Connect(function(player)
    transformsByUserId[player.UserId] = nil
end)

print("[SkateboardService] Initialized (EquipItem + visuals only)")
