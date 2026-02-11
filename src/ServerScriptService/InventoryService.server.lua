-- ServerScriptService/InventoryService.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes folder（無ければ作成）
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

local function getOrCreate(name, className)
    local r = Remotes:FindFirstChild(name)
    if not r then
        r = Instance.new(className)
        r.Name = name
        r.Parent = Remotes
    end
    return r
end

-- 必須Remotes
local PurchaseItem = getOrCreate("PurchaseItem", "RemoteFunction")
local GetInventory = getOrCreate("GetInventory", "RemoteFunction")
getOrCreate("EquipItem", "RemoteEvent")       -- 今後用（無ければ作るだけ）
getOrCreate("NpcShop_Open", "RemoteEvent")    -- 無ければ作る（NpcShopService用）
getOrCreate("NpcShop_Close", "RemoteEvent")
local InventoryUpdated = getOrCreate("InventoryUpdated", "RemoteEvent")

-- 所持データ（MVP：メモリ）
local stateByUserId = {} -- userId -> { owned = { [itemId]=true }, equipped = string? }

local function getState(player)
    local s = stateByUserId[player.UserId]
    if not s then
        s = { owned = {}, equipped = nil }
        stateByUserId[player.UserId] = s
    end
    return s
end

local function serialize(s)
    local ownedItems = {}
    for itemId, v in pairs(s.owned) do
        if v then table.insert(ownedItems, itemId) end
    end
    table.sort(ownedItems)
    return {
        ownedItems = ownedItems,
        equippedItem = s.equipped,
    }
end

local function isValidItemId(itemId)
    return itemId == "skateboard"
end

-- 他スクリプトから参照できるグローバルインターフェース
_G.InventoryGetState = getState
_G.InventorySerialize = serialize

local function notify(player)
    InventoryUpdated:FireClient(player, serialize(getState(player)))
end
_G.InventoryNotify = notify

print("[InventoryService] Ready:", Remotes:GetFullName())

PurchaseItem.OnServerInvoke = function(player, itemId)
    print("[PurchaseItem] invoked", player.Name, itemId)

    if typeof(itemId) ~= "string" or not isValidItemId(itemId) then
        warn("[PurchaseItem] rejected itemId:", itemId)
        return { success = false, reason = "not_allowed" }
    end

    local s = getState(player)

    -- 既に所持していても success（UI安定）
    if s.owned[itemId] then
        return { success = true, alreadyOwned = true, inventory = serialize(s) }
    end

    -- MVP：確実に付与（通貨チェックは後で）
    s.owned[itemId] = true
    print("[PurchaseItem] granted", player.Name, itemId)
    notify(player) -- ★購入直後にUIへ反映

    return { success = true, alreadyOwned = false, inventory = serialize(s) }
end

GetInventory.OnServerInvoke = function(player)
    local inv = serialize(getState(player))
    print("[GetInventory]", player.Name, table.concat(inv.ownedItems, ","))
    return inv
end

Players.PlayerAdded:Connect(function(player)
    getState(player)
end)

Players.PlayerRemoving:Connect(function(player)
    stateByUserId[player.UserId] = nil
end)
