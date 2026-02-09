--[[
    InputClient.client.lua
    -----------------------
    クリック/タップ入力を検出し、RequestTrick RemoteEventをサーバーへ送信する。
    サーバー側で全バリデーションを行うため、クライアントは入力事実のみ送信。
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local RequestTrick = Remotes:WaitForChild("RequestTrick")
local TrickStarted = Remotes:WaitForChild("TrickStarted")
local TrickEnded   = Remotes:WaitForChild("TrickEnded")

---------------------------------------------------------------------------
-- 定数
---------------------------------------------------------------------------
local CLIENT_RATE_LIMIT = 0.2  -- クライアント側簡易レート制限(s)、サーバーが正

---------------------------------------------------------------------------
-- 状態
---------------------------------------------------------------------------
local lastSendTime = 0

---------------------------------------------------------------------------
-- 入力ハンドラ
---------------------------------------------------------------------------
local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
    -- UIクリック等は無視
    if gameProcessedEvent then return end

    -- マウスクリック or タッチ
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    -- クライアント側レート制限（連打防止、サーバーが最終判定）
    local now = tick()
    if (now - lastSendTime) < CLIENT_RATE_LIMIT then
        return
    end
    lastSendTime = now

    -- サーバーへトリック要求送信（引数なし、事実のみ）
    RequestTrick:FireServer()
end

UserInputService.InputBegan:Connect(onInputBegan)

---------------------------------------------------------------------------
-- TrickStarted / TrickEnded 受信（演出フック）
---------------------------------------------------------------------------
TrickStarted.OnClientEvent:Connect(function(data)
    -- 将来: トリック開始演出（SE/VFX/カメラ等）
    -- data.kind     = "Spin90" or "Spin180"
    -- data.duration = 0.5 or 0.75
end)

TrickEnded.OnClientEvent:Connect(function(_data)
    -- 将来: トリック終了演出
end)

print("[InputClient] Initialized")
