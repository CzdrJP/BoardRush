---
description: How to add visual effects (Particles or Trails) to a Skateboard in BoardRush
---
# スケートボードへのエフェクト追加ワークフロー

BoardRushにおけるスケートボードのバリエーションとして、走行時に表示されるパーティクル（火花や星など）やトレイル（軌跡）のエフェクトを追加する際の標準手順です。

## 1. 対象ボードの選択
エフェクトを追加する対象のボードをユーザーに確認します。
**必ず `ServerStorage` 内の `SkateboardTemplate*` と名前のつくすべてのモデルを検索してリストアップし、どれに追加するかユーザーに選ばせます。**
（例：「対象のボードを以下から選んでください：SkateboardTemplate2, SkateboardTemplate_Blue...」）

## 2. エフェクトの種類と方針の決定
ユーザーにどのようなエフェクトにしたいか（色、形、大きさ、動き）をヒアリングします。
- **ParticleEmitter**: 火花、煙、星、オーラなどの「放出される」エフェクト。
- **Trail**: 剣の軌跡やスピード線など「走行や空中トリックの軌道」を描くエフェクト。

## 3. アタッチメントの追加
エフェクトを発生させるには、基準点となる `Attachment` が必要です。
対象ボードの `Part` (メインのボードパーツ) に `Attachment` を追加します。

例 (ParticleEmitterの場合):
```json
{
  "className": "Attachment",
  "name": "EffectAttachment",
  "properties": {
    "Position": [0, -0.2, -2.5] // 後輪付近はZ軸を -2.5 (機種によっては 2.5)に設定します
  }
}
```

## 4. 走行時のみエフェクトを出す場合 / 高度なランダム演出 (TrailControl の更新)
RojoのJSON同期では、`ParticleEmitter` の**寿命(Lifetime)やサイズ(Size)のNumberSequence設定がStudioに正しく反映されないバグ**が起きることがあります。
また、常にエフェクトを出し続けるのではなく走っている時だけ出すため、該当ボードの `Part` 内にある `TrailControl.server.luau` を以下のように編集し、**スクリプトから直接値を上書き設定**します。

以下は「走行時のみ、後方へ円錐状に、明暗とサイズがバラバラな火花を噴射する」設定例です：

```lua
local runService = game:GetService("RunService")
local part = script.Parent
local trailL = part:WaitForChild("TrailL")
local trailR = part:WaitForChild("TrailR")
local effectAttachment = part:FindFirstChild("EffectAttachment")

if effectAttachment then
    -- アタッチメントの初期位置もRojoバグでズレる場合があるため強制移動
    effectAttachment.Position = Vector3.new(0, -0.2, -2.5) 
end

runService.Heartbeat:Connect(function()
    local speed = part.AssemblyLinearVelocity.Magnitude
    local isMoving = (speed > 5)
    
    trailL.Enabled = isMoving
    trailR.Enabled = isMoving
    
    for _, desc in pairs(part:GetDescendants()) do
        if desc:IsA("ParticleEmitter") then
            -- Rojoの同期バグ回避のため、念のためスクリプトから設定を上書き
            desc.Lifetime = NumberRange.new(0.4, 0.7) -- 寿命
            desc.Speed = NumberRange.new(15, 25) -- 噴射速度
            desc.EmissionDirection = Enum.NormalId.Back -- 後方へ噴射
            desc.SpreadAngle = Vector2.new(45, 45) -- 円錐状の広がり角(X, Y)
            
            desc.LightEmission = 1.0 -- 発光の強さ（基本最大）
            -- 透過度を粒子ごとにランダム化し、明暗（光の強さ）のバラツキを演出
            desc.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.4, 0.4), -- (基準0.4, 分散0.4 = 0〜0.8のランダム)
                NumberSequenceKeypoint.new(1, 1, 0)
            })
            
            -- サイズを発生時は 0.5 ~ 1.5 の完全ランダム、消える時は 0になるよう設定
            desc.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1.0, 0.5), -- (基準値1.0, 分散0.5 = 0.5〜1.5)
                NumberSequenceKeypoint.new(1, 0, 0)
            })
            
            desc.Enabled = isMoving
        end
    end
end)
```

## 5. エフェクトのベーススクリプト生成 (JSON)
Roblox LSP / Rojo で認識されるように、`init.meta.json` や `.json` ファイルとしてエフェクトのパラーメタを定義します。

**ParticleEmitterの重要なプロパティ:**
- `Texture`: `rbxasset://textures/particles/sparkles_main.dds` や `Smoke.dds` など
- `Color`: `ColorSequence` (配列としてRGBAやTimeを指定。Rojoの形式に注意)
- `Size`: `NumberSequence`
- `EmissionDirection`: `Back` や `Bottom` にしてボードの後ろに飛ばす
- `Rate`: 発生量 (10 ~ 100くらいが適度)
- `Speed`: `NumberRange`
- `Lifetime`: `NumberRange`

**JSONファイルの作成例 (`ParticleEmitter.json`):**
```json
{
  "className": "ParticleEmitter",
  "properties": {
    "Texture": "rbxasset://textures/particles/sparkles_main.dds",
    "EmissionDirection": "Back",
    "Rate": 50,
    "Lifetime": { "Min": 0.5, "Max": 1.0 },
    "Speed": { "Min": 5, "Max": 15 },
    "Size": {
      "Envelope": 0,
      "Keypoints": [
        { "Time": 0, "Value": 0.5, "Envelope": 0 },
        { "Time": 1, "Value": 0, "Envelope": 0 }
      ]
    },
    "LightEmission": 0.8
  }
}
```

## 5. 同期とテスト
1. JSONファイルを生成した後、Rojoで同期できているか確認します。
2. 同期が完了したら、ローカルサーバーでテストプレイし、選択したボードを装備します。
3. 走行時（またはトリック中）に意図したエフェクトが表示されるかをユーザーと一緒に確認します。
