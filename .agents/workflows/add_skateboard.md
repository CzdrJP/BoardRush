---
description: How to add a new skateboard to BoardRush
---
# 新規スケートボード追加手順 (BoardRush)

このワークフローは、色付きトレイルを持つ新しいスケートボードを追加する際の全手順（Roblox Studio側の操作とスクリプト設定）を記録したものです。

## 1. Studio上でテンプレートを複製＆色変更する

RojoでのファイルコピーではUnionデータやメッシュが欠落するため、**必ずRoblox Studio上（Command Bar）から生成**するか、手動で複製する必要があります。

以下のスクリプトを Roblox Studio の **コマンドバー (Command Bar)** に貼り付けて実行してください。
※ `Color3.fromRGB()` の数値を変更することで好きな色を作れます。

```lua
local ss = game:GetService("ServerStorage")
local baseTemplate = ss:FindFirstChild("SkateboardTemplate2")

if not baseTemplate then
    warn("SkateboardTemplate2が見つかりません！")
    return
end

-- 追加したいボードの設定をここに書く
local configs = {
    { suffix = "_Red",  color = Color3.fromRGB(255, 50, 50) },
    -- 複数追加する場合は下に追加していく
}

for _, cfg in ipairs(configs) do
    local newName = "SkateboardTemplate" .. cfg.suffix
    
    local existing = ss:FindFirstChild(newName)
    if existing then existing:Destroy() end
    
    local newBoard = baseTemplate:Clone()
    newBoard.Name = newName
    
    -- ボードの本体色とTrailの色を一括変更
    for _, desc in ipairs(newBoard:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Color = cfg.color
        elseif desc:IsA("Trail") then
            desc.Color = ColorSequence.new(cfg.color)
        end
    end
    
    newBoard.Parent = ss
    print("作成完了: " .. newName)
end
```

実行後、`ServerStorage` 内に新しいボード（例: `SkateboardTemplate_Red`）が作成されていることを確認します。

## 2. EquipmentConstants へのデータ登録

モデルの準備ができたら、ショップ設定などに認識させるためデータを登録します。

**ファイル:** `src/ReplicatedStorage/Shared/EquipmentConstants.luau`

`BOARD_LIST` テーブルの中に、新しい要素を追加します。

```lua
	BOARD_LIST = {
		{ id = "Skateboard",  displayName = "Skateboard",  templateName = "SkateboardTemplate",  price = 0, scoreMultiplier = 1.0 },
		{ id = "Skateboard2", displayName = "Skateboard2", templateName = "SkateboardTemplate2", price = 100, scoreMultiplier = 1.2 },
		-- 以下、新規追加分のフォーマット
		{ 
			id = "Skateboard_Red", -- 一意のID
			displayName = "Skateboard (Red)", -- UIに表示される名前
			templateName = "SkateboardTemplate_Red", -- 先ほど作成したモデル名
			price = 2000, -- ショップでの販売価格
			scoreMultiplier = 3.0 -- トリック時の獲得Money倍率
		},
	},
```

これでショップUIとアイテムUIに自動的に追加され、装備・購入が可能になります！
