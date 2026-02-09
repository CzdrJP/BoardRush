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
    { kind = "Spin90",  angle = math.pi / 2, duration = 0.5  },
    { kind = "Spin180", angle = math.pi,     duration = 0.75 },
}

local ROTATION_AXIS         = Vector3.new(0, 1, 0)  -- Y軸（定数化、後で切替可）
local REQUEST_COOLDOWN      = 0.3                    -- TBD: レート制限(s)
local GROUND_CHECK_INTERVAL = 0.05                   -- 接地チェック間隔(s)
local RESPAWN_DELAY         = 3                      -- TBD: バラバラ後リスポーン(s)
local SCATTER_FORCE         = 30                     -- TBD: パーツ散らし力

---------------------------------------------------------------------------
-- 共有状態テーブル参照
---------------------------------------------------------------------------
if not _G.BoardRush_PlayerState then
    _G.BoardRush_PlayerState = {}
end

local playerState = _G.BoardRush_PlayerState

---------------------------------------------------------------------------
-- ユーティリティ: プレイヤー状態の安全取得
---------------------------------------------------------------------------
local function getState(player: Player)
    if not playerState[player] then
        playerState[player] = { Airborne = false, TrickActive = false, LastRequestTime = 0 }
    end
    return playerState[player]
end

---------------------------------------------------------------------------
-- cleanupTrick: 全終了経路共通の復帰処理（修正D/E）
---------------------------------------------------------------------------
local function cleanupTrick(player: Player, character: Model?, humanoid: Humanoid?, root: BasePart?)
    -- 回転停止
    if root and root.Parent then
        root.AssemblyAngularVelocity = Vector3.zero
    end

    -- 修正E: AutoRotate復帰
    if humanoid and humanoid.Parent then
        humanoid.AutoRotate = true
    end

    -- 修正D: NetworkOwner復帰（プレイヤーに返す）
    if root and root.Parent then
        pcall(function()
            root:SetNetworkOwner(player)
        end)
    end

    -- 状態リセット
    local state = getState(player)
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

    -- 修正D: サーバーに所有権を寄せる
    pcall(function()
        root:SetNetworkOwner(nil)
    end)

    -- 修正E: AutoRotate OFF
    humanoid.AutoRotate = false

    -- 回転前のCFrame記録（補正用）
    local startCFrame = root.CFrame

    -- TrickStarted通知
    TrickStarted:FireClient(player, {
        kind     = trickDef.kind,
        duration = trickDef.duration,
    })

    -- 角速度を付与
    local angularSpeed = trickDef.angle / trickDef.duration
    root.AssemblyAngularVelocity = ROTATION_AXIS * angularSpeed

    -- 接地チェックループ（回転中）
    local elapsed = 0
    local gameOverTriggered = false

    while elapsed < trickDef.duration do
        task.wait(GROUND_CHECK_INTERVAL)
        elapsed += GROUND_CHECK_INTERVAL

        -- キャラクターが消えた場合
        if not character.Parent or not root.Parent or not humanoid.Parent then
            cleanupTrick(player, character, humanoid, root)
            return
        end

        -- 接地判定（サーバー正）
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            gameOverTriggered = true
            break
        end
    end

    if gameOverTriggered then
        -- 回転中に接地 → 即死
        triggerGameOver(player, character, humanoid, root)
        return
    end

    -- 正常終了: 回転完了
    -- キャラクター存在チェック
    if not character.Parent or not root.Parent then
        cleanupTrick(player, character, humanoid, root)
        return
    end

    -- 回転停止 & CFrame補正（最終角度をスナップ）
    root.AssemblyAngularVelocity = Vector3.zero
    local targetRotation = CFrame.Angles(0, trickDef.angle, 0)
    root.CFrame = CFrame.new(root.Position) * (startCFrame - startCFrame.Position) * targetRotation

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
