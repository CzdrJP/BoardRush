--[[
    ScoreClient.client.lua
    -----------------------
    画面右上にスコアを表示するUI。
    player:GetAttribute("TrickScore") の変化を監視してリアルタイム更新。
    TrickEnded イベントで獲得スコアをキャラ頭上にポップ表示。
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrickEnded = Remotes:WaitForChild("TrickEnded")

---------------------------------------------------------------------------
-- UI作成（リスポーン時の重複防止: 古いGUIを削除してから作成）
---------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("ScoreGui")
if oldGui then
    oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScoreGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- メインスコア表示（右上）
local scoreFrame = Instance.new("Frame")
scoreFrame.Name = "ScoreFrame"
scoreFrame.Size = UDim2.new(0, 220, 0, 70)
scoreFrame.Position = UDim2.new(1, -20, 0, 20)
scoreFrame.AnchorPoint = Vector2.new(1, 0)
scoreFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
scoreFrame.BackgroundTransparency = 0.3
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = screenGui

local scoreCorner = Instance.new("UICorner")
scoreCorner.CornerRadius = UDim.new(0, 12)
scoreCorner.Parent = scoreFrame

local scoreStroke = Instance.new("UIStroke")
scoreStroke.Color = Color3.fromRGB(255, 200, 50)
scoreStroke.Thickness = 2
scoreStroke.Transparency = 0.3
scoreStroke.Parent = scoreFrame

-- "💰 MONEY" ラベル
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -16, 0, 24)
titleLabel.Position = UDim2.new(0, 8, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "💰 MONEY"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = scoreFrame

-- スコア値
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreLabel"
scoreLabel.Size = UDim2.new(1, -16, 0, 34)
scoreLabel.Position = UDim2.new(0, 8, 0, 28)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "0"
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.TextSize = 32
scoreLabel.Font = Enum.Font.GothamBlack
scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
scoreLabel.Parent = scoreFrame

---------------------------------------------------------------------------
-- スコア更新
---------------------------------------------------------------------------
local isDrainAnimating = false -- 前方宣言（ゲームオーバー演出で使用）

local function updateScore()
    if isDrainAnimating then return end -- アニメ中は更新しない
    local score = player:GetAttribute("TrickScore") or 0
    scoreLabel.Text = tostring(score)
end

-- 初期表示
updateScore()

-- 属性変更を監視
player:GetAttributeChangedSignal("TrickScore"):Connect(updateScore)

---------------------------------------------------------------------------
-- 獲得スコア演出（キャラクター頭上にポップアップ）
---------------------------------------------------------------------------
local function showEarnedScore(amount: number)
    if amount <= 0 then return end
    
    local character = player.Character
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    -- BillboardGui をキャラ頭上に作成（スコアテキスト）
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EarnedScorePopup"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head
    
    local label = Instance.new("TextLabel")
    label.Name = "PopupLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "+" .. tostring(amount) .. "💰!"
    label.TextColor3 = Color3.fromRGB(255, 220, 50)
    label.TextStrokeColor3 = Color3.fromRGB(40, 20, 0)
    label.TextStrokeTransparency = 0.3
    label.TextSize = 32
    label.Font = Enum.Font.GothamBlack
    label.TextTransparency = 0
    label.Parent = billboard
    
    -- 上に浮かびながらフェードアウト
    local tweenInfo = TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(billboard, tweenInfo, {
        StudsOffset = Vector3.new(0, 8, 0)
    }):Play()
    TweenService:Create(label, tweenInfo, {
        TextTransparency = 1,
        TextStrokeTransparency = 1
    }):Play()
    
    -- 演出終了後に削除
    task.delay(2.1, function()
        if billboard and billboard.Parent then
            billboard:Destroy()
        end
    end)
    
    -- 💰 コイン散らばりエフェクト（GUI）
    local camera = workspace.CurrentCamera
    local screenPos, onScreen = camera:WorldToScreenPoint(head.Position)
    if not onScreen then return end
    
    local COIN_COUNT = 12
    local COIN_EMOJIS = {"💰", "💵", "💰", "💵", "💰", "💵"}
    
    for i = 1, COIN_COUNT do
        local coin = Instance.new("TextLabel")
        coin.Name = "CoinEffect_" .. i
        coin.Size = UDim2.new(0, 30, 0, 30)
        coin.Position = UDim2.new(0, screenPos.X - 15, 0, screenPos.Y - 15)
        coin.BackgroundTransparency = 1
        coin.Text = COIN_EMOJIS[math.random(1, #COIN_EMOJIS)]
        coin.TextSize = math.random(18, 28)
        coin.Font = Enum.Font.GothamBold
        coin.TextTransparency = 0
        coin.ZIndex = 100
        coin.Parent = screenGui
        
        -- ランダムな方向に飛ばす
        local angle = (i / COIN_COUNT) * math.pi * 2 + math.random() * 0.5
        local dist = math.random(80, 180)
        local endX = screenPos.X - 15 + math.cos(angle) * dist
        local endY = screenPos.Y - 15 + math.sin(angle) * dist - math.random(30, 80) -- 上方向バイアス
        
        local coinTween = TweenInfo.new(
            0.8 + math.random() * 0.6, -- 0.8~1.4秒
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )
        TweenService:Create(coin, coinTween, {
            Position = UDim2.new(0, endX, 0, endY),
            TextTransparency = 1,
            Rotation = math.random(-180, 180)
        }):Play()
        
        -- 削除
        task.delay(1.5, function()
            if coin and coin.Parent then
                coin:Destroy()
            end
        end)
    end
end

---------------------------------------------------------------------------
-- ゲームオーバー時マネー減少演出
---------------------------------------------------------------------------
local function playMoneyDrainAnimation(fromScore: number)
    if fromScore <= 0 then return end
    isDrainAnimating = true
    
    local digits = #tostring(fromScore)
    
    -- UIを少し大きくする演出
    TweenService:Create(scoreFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 260, 0, 82)
    }):Play()
    
    -- スコアラベルを赤くする
    TweenService:Create(scoreLabel, TweenInfo.new(0.2), {
        TextColor3 = Color3.fromRGB(255, 80, 80)
    }):Play()
    
    -- パラパラ減少アニメーション
    local totalDuration = 2.0
    local steps = 30
    local stepInterval = totalDuration / steps
    
    task.spawn(function()
        for i = 1, steps do
            -- 進行率に基づいた大まかな減少
            local progress = i / steps
            local baseValue = math.floor(fromScore * (1 - progress))
            
            -- ランダムなブレを加える（桁数は維持）
            local maxForDigits = math.pow(10, digits) - 1
            local jitter = math.random(0, math.max(1, math.floor(fromScore * 0.1)))
            local displayed = math.clamp(baseValue + jitter, 0, maxForDigits)
            
            -- 最後の数ステップは0に近づける
            if i >= steps - 3 then
                displayed = math.floor(fromScore * (1 - progress) * math.random() * 0.5)
            end
            if i == steps then
                displayed = 0
            end
            
            -- 桁数を合わせてゼロ埋め（最初の桁が0なら通常表示）
            local text = tostring(displayed)
            
            scoreLabel.Text = text
            task.wait(stepInterval)
        end
        
        -- 最終値を0に確定
        scoreLabel.Text = "0"
        
        -- UIを元のサイズに戻す
        TweenService:Create(scoreFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 220, 0, 70)
        }):Play()
        
        -- テキスト色を戻す
        TweenService:Create(scoreLabel, TweenInfo.new(0.5), {
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        
        isDrainAnimating = false
    end)
end

-- TrickEndedハンドラ
TrickEnded.OnClientEvent:Connect(function(data)
    if data and data.earnedScore and data.earnedScore > 0 then
        showEarnedScore(data.earnedScore)
    end
    
    -- ゲームオーバー時マネー減少演出
    if data and data.gameOver and data.lostScore and data.lostScore > 0 then
        playMoneyDrainAnimation(data.lostScore)
    end
end)

print("[ScoreClient] Initialized")
