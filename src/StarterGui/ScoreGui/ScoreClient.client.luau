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

local scoreFrame = Instance.new("Frame")
scoreFrame.Name = "ScoreFrame"
scoreFrame.Size = UDim2.new(0, 220, 0, 70) -- 元のサイズに戻す
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

-- 1回のジャンプで獲得したスコア（フローティングテキスト）
local jumpScoreLabel = Instance.new("TextLabel")
jumpScoreLabel.Name = "JumpScoreLabel"
jumpScoreLabel.Size = UDim2.new(0, 220, 0, 24) -- ScoreFrameと同じ幅
jumpScoreLabel.Position = UDim2.new(1, -20, 0, 100) -- ScoreFrameのすぐ下
jumpScoreLabel.AnchorPoint = Vector2.new(1, 0)
jumpScoreLabel.BackgroundTransparency = 1
jumpScoreLabel.Text = ""
jumpScoreLabel.TextColor3 = Color3.fromRGB(150, 255, 100)
jumpScoreLabel.TextSize = 28 -- 20から28へ拡大
jumpScoreLabel.Font = Enum.Font.GothamBold
jumpScoreLabel.TextXAlignment = Enum.TextXAlignment.Right
jumpScoreLabel.TextTransparency = 1
jumpScoreLabel.Parent = screenGui -- ScoreFrameの外（下）に出す

---------------------------------------------------------------------------
-- ジャンプスコア状態
---------------------------------------------------------------------------
local currentJumpScore = 0
local resetJumpScoreTask = nil

---------------------------------------------------------------------------
-- スコア更新
---------------------------------------------------------------------------
local isDrainAnimating = false -- 前方宣言（ゲームオーバー演出で使用）
local isAddAnimating = false   -- 加算時の演出用

local function updateScore()
    if isDrainAnimating or isAddAnimating then return end -- アニメ中は更新しない
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
-- スコア加算演出（ガチャガチャ増える）
---------------------------------------------------------------------------
local function playMoneyAddAnimation(earned: number)
    if earned <= 0 then return end
    isAddAnimating = true
    
    local targetScore = player:GetAttribute("TrickScore") or 0
    local startScore = math.max(0, targetScore - earned)
    
    -- UIを少し大きくする演出
    TweenService:Create(scoreFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 260, 0, 82)
    }):Play()
    
    -- スコアラベルを黄色（ゴールド）っぽくする
    TweenService:Create(scoreLabel, TweenInfo.new(0.2), {
        TextColor3 = Color3.fromRGB(255, 255, 100)
    }):Play()
    
    -- パラパラ増加アニメーション
    local totalDuration = 1.0
    local steps = 20
    local stepInterval = totalDuration / steps
    
    task.spawn(function()
        for i = 1, steps do
            local progress = i / steps
            local baseValue = math.floor(startScore + earned * progress)
            
            -- ガチャガチャ感を出すためのランダムブレ
            local jitter = math.random(0, math.max(1, math.floor(earned * 0.2)))
            local displayed = baseValue + jitter
            
            -- 最後は合わせる
            if i >= steps - 2 then
                displayed = targetScore
            end
            
            scoreLabel.Text = tostring(displayed)
            task.wait(stepInterval)
        end
        
        -- 最終値をターゲットに確定
        scoreLabel.Text = tostring(targetScore)
        
        -- UIを元のサイズに戻す
        TweenService:Create(scoreFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 220, 0, 70)
        }):Play()
        
        -- テキスト色を戻す
        TweenService:Create(scoreLabel, TweenInfo.new(0.5), {
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        
        isAddAnimating = false
        updateScore() -- 念のため同期
    end)
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
        -- 1ジャンプの合計スコア更新とアニメーション（ここは空中のトリック完了時）
        if resetJumpScoreTask then
            task.cancel(resetJumpScoreTask)
            resetJumpScoreTask = nil
        end
        currentJumpScore += data.earnedScore
        jumpScoreLabel.Text = "+ " .. tostring(currentJumpScore)
        jumpScoreLabel.TextTransparency = 0
        jumpScoreLabel.Position = UDim2.new(1, -20, 0, 100)
        
        -- ポップアニメーション
        jumpScoreLabel.TextSize = 34
        TweenService:Create(jumpScoreLabel, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
            TextSize = 28
        }):Play()
    end
    
    -- ジャンプサイクル完了（着地時）の処理
    if data and data.cycleCompleted then
        if data.totalEarned and data.totalEarned > 0 then
            -- 着地時に頭上ポップアップとコイン散らばり演出を実行
            showEarnedScore(data.totalEarned)
            
            -- フローティングUIを scoreLabel(右上) へ吸い込まれるように移動・フェードアウト
            TweenService:Create(jumpScoreLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Position = UDim2.new(1, -20, 0, 60), -- scoreFrame付近へ
                TextTransparency = 1
            }):Play()
            
            -- 吸い込まれた直後にガチャガチャ演出開始
            task.delay(0.4, function()
                currentJumpScore = 0
                jumpScoreLabel.Text = ""
                jumpScoreLabel.Position = UDim2.new(1, -20, 0, 100)
                playMoneyAddAnimation(data.totalEarned)
            end)
        else
            -- フローティングUIを即座に消去
            currentJumpScore = 0
            jumpScoreLabel.Text = ""
            jumpScoreLabel.TextTransparency = 1
            jumpScoreLabel.Position = UDim2.new(1, -20, 0, 100)
        end
    end
    
    -- ゲームオーバー時マネー減少演出
    if data and data.gameOver and data.lostScore and data.lostScore > 0 then
        playMoneyDrainAnimation(data.lostScore)
        -- フローティングUIもリセット
        currentJumpScore = 0
        jumpScoreLabel.Text = ""
        jumpScoreLabel.TextTransparency = 1
    end
end)

print("[ScoreClient] Initialized")
