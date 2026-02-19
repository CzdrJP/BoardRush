--[[
    TrickService.server.lua
    ------------------------
    空中クリック回転トリックの処理を行うサーバースクリプト。
    RequestTrick受信 → 回転処理 → 接地チェック → ゲームオーバー。

    修正C: BreakJoints必須
    修正D: トリック中 SetNetworkOwner(nil)
    修正E: トリック中 AutoRotate=false
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EquipmentConstants = require(Shared:WaitForChild("EquipmentConstants"))

---------------------------------------------------------------------------
-- スコア定数
---------------------------------------------------------------------------
local BOARD_MULTIPLIERS = {
    equipped = 1,      -- スケボー装備時
    unequipped = 0,    -- 未装備時
}
local BASE_SCORE = 100  -- 基本スコア

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local RequestTrick = Remotes:WaitForChild("RequestTrick")
local TrickStarted = Remotes:WaitForChild("TrickStarted")
local TrickEnded   = Remotes:WaitForChild("TrickEnded")

---------------------------------------------------------------------------
-- 定数（TBD値は調整可能）
---------------------------------------------------------------------------
local TRICK_DEFS = {
    { kind = "Spin360", angle = math.pi * 2, duration = 0.25, scoreMultiplier = 1 },
    { kind = "Spin720", angle = math.pi * 4, duration = 0.45, scoreMultiplier = 2 },
    { kind = "Flip360", angle = math.pi * 2, duration = 1.5, slowMotion = true, zoom = true, scoreMultiplier = 3.5 },
}

local ROTATION_AXIS         = Vector3.new(0, 1, 0)  -- Y軸（定数化、後で切替可）
local REQUEST_COOLDOWN      = 0.3                    -- TBD: レート制限(s)
local GROUND_CHECK_INTERVAL = 0.02                   -- 接地チェック間隔(s)（0.25s回転に対応）
local RESPAWN_DELAY         = 3                      -- TBD: バラバラ後リスポーン(s)
local SCATTER_FORCE         = 30                     -- TBD: パーツ散らし力

local USE_PHYSICS_DURING_TRICK = true  -- false で Physics 化を完全無効化（即戻せる）
local GROUND_RAY_LENGTH = 5  -- TBD: 接地判定の下方向Ray長さ(studs)

---------------------------------------------------------------------------
-- 共有状態テーブル参照
---------------------------------------------------------------------------
if not _G.BoardRush_PlayerState then
    _G.BoardRush_PlayerState = {}
end

local playerState = _G.BoardRush_PlayerState

---------------------------------------------------------------------------
-- ユーティリティ: Raycast接地判定
---------------------------------------------------------------------------
local function isGroundedRaycast(character, root)
    if not character or not root or not root.Parent then
        return false
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.IgnoreWater = true

    local origin = root.Position
    local direction = Vector3.new(0, -GROUND_RAY_LENGTH, 0)

    local result = workspace:Raycast(origin, direction, params)
    return result ~= nil
end

---------------------------------------------------------------------------
-- ユーティリティ: プレイヤー状態の安全取得
---------------------------------------------------------------------------
local function getState(player: Player)
    if not playerState[player] then
        playerState[player] = { Airborne = false, TrickActive = false, LastRequestTime = 0, PrevPlatformStand = nil }
    end
    return playerState[player]
end

---------------------------------------------------------------------------
-- Physics状態切替（USE_PHYSICS_DURING_TRICK で無効化可能）
---------------------------------------------------------------------------
local function applyTrickPhysics(state, humanoid)
    if not USE_PHYSICS_DURING_TRICK then return end
    if not state or not humanoid or not humanoid.Parent then return end

    if state.PrevPlatformStand == nil then
        state.PrevPlatformStand = humanoid.PlatformStand
    end

    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

local function restoreTrickPhysics(state, humanoid)
    if not USE_PHYSICS_DURING_TRICK then return end
    if not state then return end
    if not humanoid or not humanoid.Parent then
        state.PrevPlatformStand = nil
        return
    end

    if state.PrevPlatformStand ~= nil then
        humanoid.PlatformStand = state.PrevPlatformStand
        state.PrevPlatformStand = nil
    else
        humanoid.PlatformStand = false
    end

    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

---------------------------------------------------------------------------
-- cleanupTrick: 全終了経路共通の復帰処理
---------------------------------------------------------------------------
local function cleanupTrick(player: Player, character: Model?, humanoid: Humanoid?, root: BasePart?)
    -- 回転停止
    if root and root.Parent then
        root.AssemblyAngularVelocity = Vector3.zero
        -- スローモーション（反重力）があれば削除
        local vf = root:FindFirstChild("SlowMoForce")
        if vf then vf:Destroy() end
    end

    -- AutoRotate復帰
    if humanoid and humanoid.Parent then
        humanoid.AutoRotate = true
    end

    -- Physics状態復帰（フラグ制御）
    local state = getState(player)
    restoreTrickPhysics(state, humanoid)

    -- NetworkOwner復帰: 着地済み（Airborne=false）の場合のみ戻す
    -- 空中のままトリック終了した場合は着地時に戻す（フリーズ回避）
    if root and root.Parent and (not state.Airborne) then
        pcall(function()
            root:SetNetworkOwner(player)
        end)
    end

    -- 状態リセット
    state.TrickActive = false
end

---------------------------------------------------------------------------
-- ゲームオーバー（修正C: BreakJoints必須）
---------------------------------------------------------------------------
local function triggerGameOver(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
    -- 復帰処理を先に実行
    cleanupTrick(player, character, humanoid, root)

    -- Airborne も解除
    local state = getState(player)
    state.Airborne = false

    -- スコアリセット（スケボー装備時のみ）
    local oldScore = player:GetAttribute("TrickScore") or 0
    local shouldReset = player:GetAttribute(EquipmentConstants.ATTR_IS_EQUIPPED) and oldScore > 0

    -- クライアントへゲームオーバー演出通知（リセット前にスコア情報を送る）
    TrickEnded:FireClient(player, { gameOver = true, lostScore = shouldReset and oldScore or 0 })

    -- スコアリセット（クライアント演出と同時進行、UIは演出側が制御）
    if shouldReset then
        player:SetAttribute("TrickScore", 0)
    end

    -- 修正C: 全ジョイント切断
    character:BreakJoints()

    -- 各パーツにランダムImpulseで散らす（コミカル演出・血なし）
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
            local dir = Vector3.new(
                math.random() - 0.5,
                math.random() * 0.5 + 0.5,  -- 上方向寄り
                math.random() - 0.5
            ).Unit
            part:ApplyImpulse(dir * SCATTER_FORCE * part.AssemblyMass)
        end
    end

    -- リスポーン
    task.delay(RESPAWN_DELAY, function()
        if player and player.Parent then
            player:LoadCharacter()
        end
    end)
end

---------------------------------------------------------------------------
-- トリック実行（コルーチン内で動作）
-- 回転方式: 一定角速度で +方向に回し続け、指定角度分だけ回す
-- CFrame補正なし / NetworkOwner切替はLaunchPad側で実施
---------------------------------------------------------------------------
local function executeTrick(player: Player, trickDef)
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local state = getState(player)
    state.TrickActive = true

    -- NetworkOwner切替はLaunchPad打ち上げ時に実施済み（クリック時フリーズ回避）

    -- AutoRotate OFF
    humanoid.AutoRotate = false

    -- Physics状態適用（フラグ制御）
    applyTrickPhysics(state, humanoid)

    -- スローモーション（反重力）適用
    local vf = nil
    if trickDef.slowMotion then
        vf = Instance.new("VectorForce")
        vf.Name = "SlowMoForce"
        vf.Attachment0 = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
        vf.Force = Vector3.new(0, workspace.Gravity * root.AssemblyMass * 0.85, 0) -- 85%相殺
        vf.RelativeTo = Enum.ActuatorRelativeTo.World
        vf.Parent = root
    end

    -- TrickStarted通知
    TrickStarted:FireClient(player, {
        kind     = trickDef.kind,     -- "Spin360" or "Spin720" or "Flip360"
        duration = trickDef.duration, 
        isSlowMotion = trickDef.slowMotion,
        isZoom = trickDef.zoom
    })

    -- 回転パラメータ（一定角速度で +方向回転を継続し、指定角度分だけ回す）
    local A = trickDef.angle       -- 360°=2π / 720°=4π
    local T = trickDef.duration    -- 0.25s
    local omega = A / T            -- rad/s（一定）
    local applied = 0              -- 回転積算量(rad)

    local elapsed = 0
    local gameOverTriggered = false
    local heartbeatConn  -- Heartbeat接続

    -- Heartbeat: 接地監視のみ（物理回転はクライアントに委譲）
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt

        -- 開始直後の猶予時間（0.15秒）は接地判定しない
        -- 打ち上げ直後の足の高さなどの誤判定を防ぐ
        if elapsed < 0.15 then
            return
        end

        -- 指定時間経過で終了
        if elapsed >= T then
            heartbeatConn:Disconnect()
            return
        end
    end)

    -- 接地チェックループ（回転中、別途task.waitで監視）
    while elapsed < T do
        task.wait(GROUND_CHECK_INTERVAL)

        -- キャラクターが消えた場合
        if not character.Parent or not root.Parent or not humanoid.Parent then
            if heartbeatConn.Connected then heartbeatConn:Disconnect() end
            cleanupTrick(player, character, humanoid, root)
            return
        end

        -- 接地判定（Raycast方式: Physics/PlatformStand中でも確実に検知）
        if isGroundedRaycast(character, root) then
            gameOverTriggered = true
            if heartbeatConn.Connected then heartbeatConn:Disconnect() end
            break
        end
    end

    -- 安全: Heartbeatがまだ接続中なら切断
    if heartbeatConn.Connected then
        heartbeatConn:Disconnect()
    end

    if gameOverTriggered then
        -- 回転中に接地 → 即死
        triggerGameOver(player, character, humanoid, root)
        return
    end

    -- 正常終了: CFrame補正なし（スナップ防止）
    -- 角速度はHeartbeat内で既に0にされている
    if not character.Parent or not root.Parent then
        cleanupTrick(player, character, humanoid, root)
        return
    end

    -- 復帰処理
    cleanupTrick(player, character, humanoid, root)

    -- スコア計算
    local boardMul = BOARD_MULTIPLIERS.unequipped
    if player:GetAttribute(EquipmentConstants.ATTR_IS_EQUIPPED) then
        boardMul = BOARD_MULTIPLIERS.equipped
    end
    local earned = math.floor(BASE_SCORE * (trickDef.scoreMultiplier or 1) * boardMul)
    if earned > 0 then
        local current = player:GetAttribute("TrickScore") or 0
        player:SetAttribute("TrickScore", current + earned)
    end

    -- TrickEnded通知（獲得スコア付き）
    TrickEnded:FireClient(player, { earnedScore = earned })
end

---------------------------------------------------------------------------
-- RequestTrick ハンドラ
---------------------------------------------------------------------------
RequestTrick.OnServerEvent:Connect(function(player: Player)
    local state = getState(player)

    -- レート制限
    local now = tick()
    if (now - state.LastRequestTime) < REQUEST_COOLDOWN then
        -- print("Rate limited")
        return
    end
    state.LastRequestTime = now

    -- サーバー側 Airborne 確認（クライアント申告は信用しない）
    if not state.Airborne then
        -- print("[TrickService] Rejected: Not Airborne", player.Name, "State:", state.Airborne)
        return
    end

    -- トリック中は再発動不可
    if state.TrickActive then
        -- print("[TrickService] Rejected: TrickActive is true", player.Name)
        return
    end

    -- ランダムでトリック選出
    local trickDef = TRICK_DEFS[math.random(1, #TRICK_DEFS)]

    -- 非同期で実行（メインスレッドをブロックしない）
    task.spawn(function()
        executeTrick(player, trickDef)
    end)
end)

---------------------------------------------------------------------------
-- 空中状態の管理: Humanoid.StateChanged
---------------------------------------------------------------------------
local function onCharacterAdded(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid")
    local state = getState(player)

    -- キャラ追加時はリセット
    state.Airborne = false
    state.TrickActive = false

    humanoid.StateChanged:Connect(function(_oldState, newState)
        local s = getState(player)

        if newState == Enum.HumanoidStateType.Freefall then
             -- print("[TrickService] State Changed: Freefall", player.Name)
            -- Freefallに入った（LaunchPad以外のケースもキャッチ）
        elseif newState == Enum.HumanoidStateType.Landed
            or newState == Enum.HumanoidStateType.Running then
            -- 接地
            -- print("[TrickService] State Changed: Landed/Running", player.Name, newState, "Floor:", humanoid.FloorMaterial)
            
            if s.TrickActive then
                -- TrickActive中に接地 → 即死（最優先）
                local root = character:FindFirstChild("HumanoidRootPart")
                if root then
                    triggerGameOver(player, character, humanoid, root)
                end
            else
                if s.Airborne then
                     -- print("[TrickService] Landed - Airborne reset (was true)", player.Name)
                end
                s.Airborne = false
                -- 着地時: NetworkOwnerをプレイヤーに復帰（フリーズ回避）
                local root = character:FindFirstChild("HumanoidRootPart")
                if root and root.Parent then
                    pcall(function()
                        root:SetNetworkOwner(player)
                    end)
                end
            end
        end
    end)


    -- キャラ消失時の安全cleanup
    character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanupTrick(player, character, humanoid, character:FindFirstChild("HumanoidRootPart"))
            local s = getState(player)
            s.Airborne = false
        end
    end)
end

---------------------------------------------------------------------------
-- プレイヤー接続
---------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    -- スコア属性初期化
    if not player:GetAttribute("TrickScore") then
        player:SetAttribute("TrickScore", 0)
    end

    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
    -- 既にキャラがいる場合
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end)

-- 既にいるプレイヤー対応（Studioテスト用）
for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

---------------------------------------------------------------------------
-- プレイヤー離脱時クリーンアップ
---------------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    playerState[player] = nil
end)

print("[TrickService] Initialized")
