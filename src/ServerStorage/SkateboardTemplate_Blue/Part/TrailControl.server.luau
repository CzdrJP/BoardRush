local runService = game:GetService("RunService")
local part = script.Parent
local trailL = part:WaitForChild("TrailL")
local trailR = part:WaitForChild("TrailR")
local effectAttachment = part:FindFirstChild("EffectAttachment")

if effectAttachment then
    -- Rojoのバグ回避のため、パーティクル発生位置を強制的に後輪のZ軸へ移動させる
    effectAttachment.Position = Vector3.new(0, -0.2, -2.5) -- 前輪(2.5)へ行ったので後輪(-2.5)に変更
end

runService.Heartbeat:Connect(function()
    -- 速度が5以上ならトレイル・パーティクル有効
    local speed = part.AssemblyLinearVelocity.Magnitude
    local isMoving = (speed > 5)
    
    trailL.Enabled = isMoving
    trailR.Enabled = isMoving
    
    -- ボード内のすべてのParticleEmitterを探してオンオフ切り替え
    for _, desc in pairs(part:GetDescendants()) do
        if desc:IsA("ParticleEmitter") then
            -- Rojoの同期バグ回避のため、念のためスクリプトから設定を上書き
            desc.Lifetime = NumberRange.new(0.4, 0.7) -- ★寿命を少し伸ばす
            desc.Speed = NumberRange.new(15, 25)
            desc.EmissionDirection = Enum.NormalId.Back -- 前回のFrontではなくBackで明確に指定
            desc.SpreadAngle = Vector2.new(45, 45) -- ★円錐状の広がりをさらに大きく
            
            -- ★発光度（より明るく）とサイズのランダム化を追加
            desc.LightEmission = 1.0  -- 発光自体は最大に固定し、透過度で明かさのバラツキを演出
            
            -- 個々の粒子の「明るさ」をランダムに見せるため、出現時のTransparencyを完全ランダム化(0.0 ~ 0.8)
            desc.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.4, 0.4), -- 基準0.4, 分散0.4 = 0(超明るい)〜0.8(暗い)
                NumberSequenceKeypoint.new(1, 1, 0)
            })
            
            -- サイズを発生時は 0.5 ~ 1.5 の完全ランダム（基本サイズを大きく）、消える時は 0になるよう設定
            desc.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1.0, 0.5), -- 基準値1.0, 分散0.5 = 0.5〜1.5
                NumberSequenceKeypoint.new(1, 0, 0) -- 時間1で消滅
            })
            
            desc.Enabled = isMoving
        end
    end
end)
