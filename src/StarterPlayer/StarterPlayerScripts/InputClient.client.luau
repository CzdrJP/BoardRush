--[[
    InputClient.client.lua
    -----------------------
    クリック/タップ入力を検出し、RequestTrick RemoteEventをサーバーへ送信する。
    サーバー側で全バリデーションを行うため、クライアントは入力事実のみ送信。
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- デフォルトUIを非表示（ゲームオーバー時の灰色ヘルスバー対策）
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local RequestTrick = Remotes:WaitForChild("RequestTrick")
local TrickStarted = Remotes:WaitForChild("TrickStarted")
local TrickEnded   = Remotes:WaitForChild("TrickEnded")
local LaunchImpulse = Remotes:WaitForChild("LaunchImpulse")

-- サーバーが再作成する可能性があるため、RemoteEvent型を確認
if not LaunchImpulse:IsA("RemoteEvent") then
	warn("[InputClient] LaunchImpulse is not a RemoteEvent, waiting for correction...")
	while true do
		task.wait(0.5)
		local candidate = Remotes:FindFirstChild("LaunchImpulse")
		if candidate and candidate:IsA("RemoteEvent") then
			LaunchImpulse = candidate
			break
		end
	end
    print("[InputClient] LaunchImpulse RemoteEvent acquired.")
end

---------------------------------------------------------------------------
-- TrickStarted / TrickEnded 受信（物理回転演出）
---------------------------------------------------------------------------
local currentTrickConn = nil

local function resetFOV(duration)
    local camera = workspace.CurrentCamera
    if not camera then return end
    TweenService:Create(camera, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()
end

TrickStarted.OnClientEvent:Connect(function(data)
    -- data.kind     = "Spin360" or "Spin720"
    -- data.duration = 0.5
    
    local character = Players.LocalPlayer.Character
    if not character then return end
    local root = character:WaitForChild("HumanoidRootPart", 1)
    if not root then return end

    -- 既存の回転があれば停止
    if currentTrickConn then
        currentTrickConn:Disconnect()
        currentTrickConn = nil
        root.AssemblyAngularVelocity = Vector3.zero
        -- 中断時は即座に戻す（またはTweenで戻す）
        resetFOV(0.2)
    end

    -- 回転パラメータ
    local angle = (data.kind == "Spin720") and (math.pi * 4) or (math.pi * 2)
    local duration = data.duration or 0.25
    local omega = angle / duration
    
    -- "Flip360" はX軸回転(前方宙返り)、それ以外はY軸回転
    local axis = (data.kind == "Flip360") and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)

    -- カメラズーム演出（isZoomフラグ時）
    if data.isZoom then
        local camera = workspace.CurrentCamera
        if camera then
            -- ズームイン
            TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 30}):Play()
        end
    end

    local elapsed = 0
    
    -- 回転ループ開始
    currentTrickConn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        
        -- 回転速度適用（クライアント所有権なので即反映）
        root.AssemblyAngularVelocity = axis * omega
        
        -- 終了判定
        if elapsed >= duration then
            if currentTrickConn then
                currentTrickConn:Disconnect()
                currentTrickConn = nil
            end
            -- 慣性で少し回るのを防ぐため停止（または減衰させる？）
            -- ここではピタッと止める
            root.AssemblyAngularVelocity = Vector3.zero
            
            -- カメラFOV復帰
            if data.isZoom then
                resetFOV(0.5)
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- ゲームオーバー演出
---------------------------------------------------------------------------
local gameOverFlash: Frame? = nil

local function createFlashFrame()
    if gameOverFlash then return end
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local sg = pg:FindFirstChild("GameOverEffectsGui")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "GameOverEffectsGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 100
        sg.Parent = pg
    end
    gameOverFlash = Instance.new("Frame")
    gameOverFlash.Name = "RedFlash"
    gameOverFlash.Size = UDim2.new(1, 0, 1, 0)
    gameOverFlash.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    gameOverFlash.BackgroundTransparency = 1
    gameOverFlash.BorderSizePixel = 0
    gameOverFlash.ZIndex = 100
    gameOverFlash.Parent = sg
end
createFlashFrame()

local function playGameOverEffects()
    -- 赤フラッシュ
    if gameOverFlash then
        gameOverFlash.BackgroundTransparency = 0.6
        TweenService:Create(gameOverFlash, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1
        }):Play()
    end

    -- カメラシェイク
    task.spawn(function()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local shakeDuration = 0.7
        local shakeIntensity = 1.0
        local elapsed = 0
        local conn
        conn = RunService.RenderStepped:Connect(function(dt)
            elapsed += dt
            if elapsed >= shakeDuration then
                camera.CFrame = camera.CFrame -- 現在位置で止める
                conn:Disconnect()
                return
            end
            local fade = 1 - (elapsed / shakeDuration) -- 徐々に弱まる
            local offsetX = (math.random() - 0.5) * 2 * shakeIntensity * fade
            local offsetY = (math.random() - 0.5) * 2 * shakeIntensity * fade
            camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0)
        end)
    end)
end

---------------------------------------------------------------------------
-- TrickEnded ハンドラ
---------------------------------------------------------------------------
TrickEnded.OnClientEvent:Connect(function(data)
    -- FOVを必ずリセット
    resetFOV(0.2)

    if currentTrickConn then
        currentTrickConn:Disconnect()
        currentTrickConn = nil
        
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    -- ゲームオーバー演出
    if data and data.gameOver then
        playGameOverEffects()
    end
end)

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
-- Launch Impulse (サーバーからの打ち上げ通知)
---------------------------------------------------------------------------
LaunchImpulse.OnClientEvent:Connect(function(launchSpeed)
    local character = Players.LocalPlayer.Character
    if not character then
        character = Players.LocalPlayer.CharacterAdded:Wait()
    end
    local hrp = character:WaitForChild("HumanoidRootPart", 2) -- 2秒待つ
    if not hrp then
        warn("[InputClient] HRP not found for impulse!")
        return 
    end

    -- 水平速度維持 + Y方向インパルス
    local mass = hrp.AssemblyMass
    local impulse = Vector3.new(0, launchSpeed * mass, 0)
    hrp:ApplyImpulse(impulse)
    
    -- 空中制御の一時無効化などは不要（デフォルト物理で自然に飛ぶ）
end)



print("[InputClient] Initialized")
