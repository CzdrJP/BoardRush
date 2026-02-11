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
    { kind = "Spin360", angle = math.pi * 2, duration = 0.25 }, -- 360° / 0.25s
    { kind = "Spin720", angle = math.pi * 4, duration = 0.25 }, -- 720° / 0.25s
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

    -- TrickStarted通知
    TrickStarted:FireClient(player, {
        kind     = trickDef.kind,     -- "Spin360" or "Spin720"
        duration = trickDef.duration, -- 0.25
    })

    -- 回転パラメータ（一定角速度で +方向回転を継続し、指定角度分だけ回す）
    local A = trickDef.angle       -- 360°=2π / 720°=4π
    local T = trickDef.duration    -- 0.25s
    local omega = A / T            -- rad/s（一定）
    local applied = 0              -- 回転積算量(rad)

    local elapsed = 0
    local gameOverTriggered = false
    local heartbeatConn  -- Heartbeat接続

    -- Heartbeat: 一定角速度で +方向に回し続ける
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt

        -- dtで回したぶんを積算（+方向のみ）
        local step = omega * dt
        applied += step

        -- 回転を継続（+方向固定）
        if root and root.Parent then
            root.AssemblyAngularVelocity = ROTATION_AXIS * omega
        end

        -- 指定角度分回したら終了（または念のため時間でも終了）
        if applied >= A or elapsed >= T then
            if root and root.Parent then
                root.AssemblyAngularVelocity = Vector3.zero
            end
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

    -- TrickEnded通知
    TrickEnded:FireClient(player, {})
end

---------------------------------------------------------------------------
-- RequestTrick ハンドラ
---------------------------------------------------------------------------
RequestTrick.OnServerEvent:Connect(function(player: Player)
    local state = getState(player)

    -- レート制限
    local now = tick()
    if (now - state.LastRequestTime) < REQUEST_COOLDOWN then
        return
    end
    state.LastRequestTime = now

    -- サーバー側 Airborne 確認（クライアント申告は信用しない）
    if not state.Airborne then
        return
    end

    -- トリック中は再発動不可
    if state.TrickActive then
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
            -- Freefallに入った（LaunchPad以外のケースもキャッチ）
            -- 注: LaunchPadServiceでもAirborne=trueをセットしているが、
            --      自然落下等でFreefallに入った場合もカバー
            -- LaunchPad起点のみトリック可能にしたい場合はここを調整
        elseif newState == Enum.HumanoidStateType.Landed
            or newState == Enum.HumanoidStateType.Running then
            -- 接地

            if s.TrickActive then
                -- TrickActive中に接地 → 即死（最優先）
                local root = character:FindFirstChild("HumanoidRootPart")
                if root then
                    triggerGameOver(player, character, humanoid, root)
                end
            else
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
