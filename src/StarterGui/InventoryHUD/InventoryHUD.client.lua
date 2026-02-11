local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local screenGui = script.Parent

-- 二重起動ガード（InventoryHUDが複数あっても1つだけ動かす）
local playerGui = player:WaitForChild("PlayerGui")
local ownerTag = playerGui:FindFirstChild("InventoryHUD_Owner")
if not ownerTag then
	ownerTag = Instance.new("ObjectValue")
	ownerTag.Name = "InventoryHUD_Owner"
	ownerTag.Parent = playerGui
end
if ownerTag.Value and ownerTag.Value ~= screenGui and ownerTag.Value.Parent then
	return
end
ownerTag.Value = screenGui

if screenGui:IsA("ScreenGui") then
	screenGui.ResetOnSpawn = false
end

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetInventory = Remotes:WaitForChild("GetInventory") -- RemoteFunction
local PurchaseItem = Remotes:WaitForChild("PurchaseItem") -- RemoteFunction
local EquipItem = Remotes:WaitForChild("EquipItem")       -- RemoteEvent (★マージ)
local InventoryUpdated = Remotes:FindFirstChild("InventoryUpdated") -- RemoteEvent（無くてもOK）

-- 既に残っていたら削除
local old = screenGui:FindFirstChild("InventoryRoot")
if old then
	old:Destroy()
end

---------------------------------------------------------------------------
-- UI構築
---------------------------------------------------------------------------

local root = Instance.new("Frame")
root.Name = "InventoryRoot"
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundTransparency = 1
root.Parent = screenGui

local hudBtn = Instance.new("TextButton")
hudBtn.Name = "ItemsButton"
hudBtn.Size = UDim2.new(0, 120, 0, 38)
hudBtn.Position = UDim2.new(0, 18, 1, -56)
hudBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hudBtn.BackgroundTransparency = 0.15
hudBtn.BorderSizePixel = 0
hudBtn.Text = "Items"
hudBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hudBtn.TextSize = 16
hudBtn.Font = Enum.Font.GothamBold
hudBtn.Parent = root

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 10)
hudCorner.Parent = hudBtn

local win = Instance.new("Frame")
win.Name = "InventoryWindow"
win.Size = UDim2.new(0, 360, 0, 350)
win.Position = UDim2.new(0.5, 0, 0.55, 0)
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
win.BackgroundTransparency = 0.12
win.BorderSizePixel = 0
win.Visible = false
win.Parent = root

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 12)
winCorner.Parent = win

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -44, 0, 28)
title.Position = UDim2.new(0, 12, 0, 10)
title.BackgroundTransparency = 1
title.Text = "Inventory"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = win

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = win

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeBtn

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 18)
status.Position = UDim2.new(0, 12, 0, 42)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = Color3.fromRGB(255, 210, 140)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = win

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 92, 0, 28)
refreshBtn.Position = UDim2.new(1, -108, 0, 40)
refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
refreshBtn.BorderSizePixel = 0
refreshBtn.Text = "Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.TextSize = 12
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.Parent = win

local refCorner = Instance.new("UICorner")
refCorner.CornerRadius = UDim.new(0, 10)
refCorner.Parent = refreshBtn

-- Reset UI Button
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetUI"
resetBtn.Size = UDim2.new(0, 92, 0, 28)
resetBtn.Position = UDim2.new(1, -208, 0, 40) -- Refreshの左
resetBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "Reset UI"
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.TextSize = 12
resetBtn.Font = Enum.Font.GothamBold
resetBtn.Parent = win

local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 10)
resetCorner.Parent = resetBtn

-- Buy button（未所持が確定するまで「表示」がデフォルト）
local buyBtn = Instance.new("TextButton")
buyBtn.Name = "BuySkateboard"
buyBtn.Size = UDim2.new(1, -24, 0, 32)
buyBtn.Position = UDim2.new(0, 12, 0, 66)
buyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
buyBtn.BorderSizePixel = 0
buyBtn.Text = "Buy Skateboard"
buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyBtn.TextSize = 14
buyBtn.Font = Enum.Font.GothamBold
buyBtn.Visible = true -- ★最重要：初期は表示（未所持想定）
buyBtn.Parent = win

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent = buyBtn

local listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "List"
listFrame.Size = UDim2.new(1, -24, 1, -118)
listFrame.Position = UDim2.new(0, 12, 0, 106)
listFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
listFrame.BackgroundTransparency = 0.2
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.Parent = win

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 10)
listCorner.Parent = listFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = listFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 10)
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.PaddingLeft = UDim.new(0, 10)
listPadding.PaddingRight = UDim.new(0, 10)
listPadding.Parent = listFrame

---------------------------------------------------------------------------
-- ロジック
---------------------------------------------------------------------------

local busy = false
local lastData = nil
local ownedSkateboardKnown = false
local ownedSkateboard = false
local refresh -- forward declaration

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- ★マージ: ボタン付き行生成
local function addRowWithButton(itemId, labelText, buttonText, onClick)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.Parent = listFrame

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 10)
	rCorner.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -120, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	if buttonText then
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 96, 0, 26)
		btn.Position = UDim2.new(1, -106, 0.5, 0)
		btn.AnchorPoint = Vector2.new(0, 0.5)
		btn.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
		btn.BorderSizePixel = 0
		btn.Text = buttonText
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 12
		btn.Font = Enum.Font.GothamBold
		btn.Parent = row

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 10)
		bCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			onClick(btn)
		end)
	end
end

local function updateCanvas()
	task.defer(function()
		local h = layout.AbsoluteContentSize.Y
			+ listPadding.PaddingTop.Offset
			+ listPadding.PaddingBottom.Offset
		listFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(h, listFrame.AbsoluteSize.Y))
	end)
end

-- ownedItems 形式揺れ対応：
-- 1) 配列 {"skateboard", ...}
-- 2) 辞書 {skateboard=true}
local function hasItem(data, itemId)
	if not data or not data.ownedItems then return false end
	if typeof(data.ownedItems) ~= "table" then return false end

	-- 配列
	for _, v in ipairs(data.ownedItems) do
		if v == itemId then return true end
	end
	-- 辞書
	if data.ownedItems[itemId] == true then
		return true
	end
	return false
end

-- ★マージ: Equipボタンロジック込み
local function applyInventoryData(data)
	lastData = data
	ownedSkateboardKnown = true
	ownedSkateboard = hasItem(data, "skateboard")

	-- ★最重要：未所持なら必ずBuyを出す／所持なら隠す
	buyBtn.Visible = not ownedSkateboard

	-- list
	clearList()
	local ownedItems = {}
	if data and data.ownedItems and typeof(data.ownedItems) == "table" then
		-- 配列優先で表示、無ければ辞書キーを並べる
		for _, v in ipairs(data.ownedItems) do
			table.insert(ownedItems, v)
		end
		if #ownedItems == 0 then
			for k, v in pairs(data.ownedItems) do
				if v == true then table.insert(ownedItems, k) end
			end
		end
	end

	if #ownedItems == 0 then
		-- ボタンなし
		addRowWithButton(nil, "No items.", nil, function() end)
	else
		local equippedItem = data.equippedItem
		for _, itemId in ipairs(ownedItems) do
			local isEquipped = (equippedItem == itemId)
			local label = tostring(itemId)
			if isEquipped then
				label = label .. "  (Equipped)"
			end
            
            local btnText = isEquipped and "Unequip" or "Equip"

            -- ボタンクリック時の処理
            addRowWithButton(itemId, label, btnText, function(btn)
                if busy then return end
                busy = true
                status.Text = "Updating..."

                pcall(function()
                    EquipItem:FireServer(itemId, "toggle")
                end)

                -- 念のため即時リフレッシュ
				task.wait(0.1) -- 少し待ってから更新
                refresh()
                status.Text = ""
                busy = false
            end)
		end
	end
	updateCanvas()
end

-- GetInventory リトライ（最大3回）
local function fetchInventoryWithRetry()
	local delays = {0, 0.25, 0.6}
	for i = 1, #delays do
		if delays[i] > 0 then task.wait(delays[i]) end
		local ok, data = pcall(function()
			return GetInventory:InvokeServer()
		end)
		if ok and data then
			return true, data
		end
	end
	return false, nil
end

local function hardResetUI()
	-- 強制リセット
	busy = false
	status.Text = "Resetting..."
	ownedSkateboardKnown = false
	ownedSkateboard = false
	lastData = nil

	if buyBtn then
		buyBtn.Visible = true
		buyBtn.AutoButtonColor = true
	end

	task.defer(function()
		refresh()
		-- refresh完了後にstatusが上書きされる可能性があるが、refresh内でクリアされるのでOK
	end)
end

refresh = function()
	if busy then return end
	busy = true
	status.Text = "Loading..."

	local ok, data = fetchInventoryWithRetry()
	busy = false

	if not ok then
		-- ★失敗時はBuyを隠さない（買えなくなるのを防ぐ）
		status.Text = "Inventory sync failed (retry later)."
		if not ownedSkateboardKnown then
			buyBtn.Visible = true
		end
		return
	end

	status.Text = ""
	applyInventoryData(data)
end

local function openWindow()
	win.Visible = true
	-- 開いた瞬間は安全側でBuyを見せる（同期前でも買える）
	if not ownedSkateboardKnown then
		buyBtn.Visible = true
	end
	refresh()
end

local function closeWindow()
	win.Visible = false
	status.Text = ""
end

---------------------------------------------------------------------------
-- イベント
---------------------------------------------------------------------------

hudBtn.MouseButton1Click:Connect(function()
	if win.Visible then
		closeWindow()
	else
		openWindow()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	closeWindow()
end)

refreshBtn.MouseButton1Click:Connect(function()
	refresh()
end)

resetBtn.MouseButton1Click:Connect(function()
	if busy then busy = false end
	hardResetUI()
end)

buyBtn.MouseButton1Click:Connect(function()
	if busy then return end

	-- 所持が確定していたら購入ボタンは消す
	if ownedSkateboardKnown and ownedSkateboard then
		status.Text = "Already owned."
		buyBtn.Visible = false
		return
	end

	busy = true
	status.Text = "Purchasing..."
	buyBtn.AutoButtonColor = false

	local function tryPurchase()
		local ok, result = pcall(function()
			return PurchaseItem:InvokeServer("skateboard")
		end)
		return ok, result
	end

	-- 1回目
	local ok, result = tryPurchase()

	-- 失敗したら1回だけリトライ
	if not ok or (result and result.success == false) then -- 通信失敗 or サーバー側拒否(在庫切れ等ではないが念のため)
		-- 今回は通信エラー(ok=false)またはresult=nilを失敗とみなすのが自然だが、
		-- result.successがfalseの場合は「購入条件を満たしていない」可能性が高いのでリトライしても無駄かも。
		-- しかし指示書には「失敗したら」とあるので、通信エラー(not ok)または結果不正(not result)を主眼に置く。
		
		if not ok or not result then
			status.Text = "Retrying..."
			task.wait(0.3)
			ok, result = tryPurchase()
		end
	end

	busy = false
	buyBtn.AutoButtonColor = true

	if not ok or not result then
		-- 2回とも失敗：Reset誘導（ユーザー復旧導線）
		status.Text = "Purchase failed. Press Reset UI."
		-- 失敗してもボタンは残して再試行可能にする
		buyBtn.Visible = true
		return
	end

	-- 成功：戻り値inventoryがあればそれで即確定（上書きしない）
	if result.inventory then
		status.Text = (result.success == false) and "Purchase rejected." or "Purchased!"
		applyInventoryData(result.inventory)
		return
	end

	-- inventoryが無ければ再同期
	status.Text = (result.success == false) and "Purchase rejected." or "Purchased!"
	refresh()
end)

if InventoryUpdated then
	InventoryUpdated.OnClientEvent:Connect(function(data)
		-- 受信したら即反映（開いてる時だけ描画）
		lastData = data
		ownedSkateboardKnown = true
		ownedSkateboard = hasItem(data, "skateboard")
		if win.Visible then
			status.Text = ""
			applyInventoryData(data)
		else
			-- 閉じていても次回の初期表示に効く
			buyBtn.Visible = not ownedSkateboard
		end
	end)
end

print("[InventoryHUD] Initialized (stable buy button + equip integrated)")
