---
description: How to create a Pop and Dynamic UI in BoardRush
---
# Pop UI 作成・改修ワークフロー

BoardRushにおける、ポップでリッチなUI（ユーザーインターフェース）を作成、または既存UIを改修する際の標準的な手順とコーディングパターンです。

## 1. デザインの基本原則 (POP & DYNAMIC)
シンプルで味気ない四角形のUIを避けるため、以下の要素を必ず組み込みます。

- **角丸 (`UICorner`)**: すべてのボタン、パネル、画像背景に適用する（推奨Radius: 6〜12）。真っ四角な要素は作らない。
- **アウトライン (`UIStroke`)**: ボタンやパネルの外枠に、少し明るめ／暗めの同系色でフチ取りをつける（Thickness: 2〜4）。
- **鮮やかな配色 (`Color3.fromRGB`)**: 完全な黒（0,0,0）や白（255,255,255）のみの使用を避け、少し色味を帯びたオフホワイトや、パステル/ビビッドカラーを使う。

## 2. インタラクション（動き）の追加
プレイヤーがUIを操作した際の視覚的なフィードバックを、`TweenService` を使って必ず実装します。

### ボタンのホバーアニメーション
マウスをボタンに乗せた時（PC）に、少しだけボタンが拡大する演出です。この関数を定義しておき、作成したボタンすべてに適用します。

```lua
local TweenService = game:GetService("TweenService")

local function addHoverAnimation(guiObject, scaleTarget)
	scaleTarget = scaleTarget or 1.05
	local originalSize = guiObject.Size
	
	guiObject.MouseEnter:Connect(function()
		TweenService:Create(guiObject, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * scaleTarget, originalSize.Y.Scale, originalSize.Y.Offset * scaleTarget)
		}):Play()
	end)
	
	guiObject.MouseLeave:Connect(function()
		TweenService:Create(guiObject, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize
		}):Play()
	end)
end
```

## 3. ウィンドウ開閉アニメーション（ボタン連動）
ウィンドウが画面中央に「パッ」と出現するのではなく、**開くきっかけとなったボタンの位置から、拡大しながら飛び出してくる** 演出を作ります。

1. メインのウィンドウを `Frame` ではなく **`CanvasGroup`** にする。
2. `CanvasGroup` の中に **`UIScale`** を追加する。
3. アニメーション処理を以下のように記述する。

```lua
-- mainFrame は CanvasGroup
local uiScale = Instance.new("UIScale", mainFrame)
uiScale.Scale = 0

local isOpen = false

local function toggleUI()
	isOpen = not isOpen
	if isOpen then
		mainFrame.Visible = true
		
		-- 出発地点（開くきっかけのボタン位置）
		mainFrame.Position = openButton.Position
		uiScale.Scale = 0
		
		-- 中央へ移動しつつ、不透明になる
		TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0), -- 最終的な画面中央位置
			GroupTransparency = 0
		}):Play()
		
		-- 同時にスケールを1に戻す
		TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1
		}):Play()
	else
		-- 閉じる時はボタンの位置に向かって縮小・透明化する
		local closePosition = openButton.Position
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = closePosition,
			GroupTransparency = 1
		})
		local scaleTween = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0
		})
		
		closeTween:Play()
		scaleTween:Play()
		
		closeTween.Completed:Connect(function()
			if not isOpen then mainFrame.Visible = false end
		end)
	end
end
```

## 4. グリッドレイアウトの活用
リスト要素を扱う場合、縦に文字だけが並ぶのは味気ないため、`UIGridLayout` を使ったカード型の並びを推奨します。

1. `ScrollingFrame` などのコンテナに `UIGridLayout` を追加。
2. `CellSize` は正方形〜やや縦長の長方形（`UDim2.new(0, 110, 0, 145)` など）にする。
3. アイテム1枠を `TextButton` 等とし、その中にアイコン（絵文字・画像）を大きく配置し、下部にアイテム名を配置する。
