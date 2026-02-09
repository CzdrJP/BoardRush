--[[
    LaunchPadService.server.lua
    ----------------------------
    Map中心基準でLaunchPad(Weak/Medium/Strong)を3つ生成・配置し、
    Touchedで上方向にImpulse打ち上げを行うサーバースクリプト。

    修正A: Raycastで地面Y取得（地面吸着）
    修正B: ApplyImpulseでY方向のみ加速（水平速度維持）
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

---------------------------------------------------------------------------
-- 定数（TBD値は調整可能）
---------------------------------------------------------------------------
local PAD_SPACING       = 20                          -- TBD: パッド間隔(studs)
local PAD_SIZE          = Vector3.new(10, 1, 10)
local PAD_Y_OFFSET      = 0.5                         -- Raycast失敗時フォールバック高さ
local COOLDOWN_SEC      = 2                            -- TBD: 打ち上げクールダウン(s)

local LAUNCH_SPEED = {
    Weak   = 80,   -- TBD
    Medium = 130,  -- TBD
    Strong = 200,  -- TBD
}

local RAY_ORIGIN_HEIGHT = 100   -- Raycast開始: 中心Y + この値
local RAY_DISTANCE      = 200   -- Raycast最大距離

-- パッド定義（-X → 中心 → +X）
local PAD_DEFS = {
    { name = "LaunchPad_Weak",   strength = "Weak",   offsetX = -1, color = BrickColor.new("Bright green")  },
    { name = "LaunchPad_Medium", strength = "Medium", offsetX =  0, color = BrickColor.new("Bright yellow") },
    { name = "LaunchPad_Strong", strength = "Strong", offsetX =  1, color = BrickColor.new("Bright red")    },
}

---------------------------------------------------------------------------
-- 共有状態テーブル初期化
---------------------------------------------------------------------------
if not _G.BoardRush_PlayerState then
    _G.BoardRush_PlayerState = {}
end

local playerState = _G.BoardRush_PlayerState

---------------------------------------------------------------------------
-- Map中心取得
---------------------------------------------------------------------------
local function getMapCenter(): Vector3
    local map = workspace:FindFirstChild("Map")
    if map then
        if map.PrimaryPart then
            return map.PrimaryPart.Position
        end
        return map:GetPivot().Position
    end
    warn("[LaunchPadService] Workspace.Map not found — using origin (0,0,0)")
    return Vector3.zero
end

---------------------------------------------------------------------------
-- Raycastで地面Y取得
---------------------------------------------------------------------------
local function getGroundY(x: number, z: number, centerY: number, ignoreList: {Instance}): number
    local origin    = Vector3.new(x, centerY + RAY_ORIGIN_HEIGHT, z)
    local direction = Vector3.new(0, -RAY_DISTANCE, 0)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = ignoreList

    local result = workspace:Raycast(origin, direction, rayParams)
    if result then
        return result.Position.Y
    end

    warn(string.format(
        "[LaunchPadService] Raycast miss at (%.1f, %.1f) — using fallback Y=%.1f",
        x, z, centerY + PAD_Y_OFFSET
    ))
    return centerY + PAD_Y_OFFSET
end

---------------------------------------------------------------------------
-- LaunchPad生成
---------------------------------------------------------------------------
local createdPads: {Part} = {}

local function createPads()
    local center = getMapCenter()

    for _, def in ipairs(PAD_DEFS) do
        local padX = center.X + def.offsetX * PAD_SPACING
        local padZ = center.Z

        local pad = Instance.new("Part")
        pad.Name = def.name
        pad.Size = PAD_SIZE
        pad.Anchored = true
        pad.CanCollide = true
        pad.BrickColor = def.color
        pad.Material = Enum.Material.Neon
        pad.TopSurface = Enum.SurfaceType.Smooth
        pad.BottomSurface = Enum.SurfaceType.Smooth

        -- 修正A: Raycastで地面Y取得
        local groundY = getGroundY(padX, padZ, center.Y, createdPads)
        pad.Position = Vector3.new(padX, groundY + PAD_SIZE.Y / 2, padZ)

        -- タグ・属性
        CollectionService:AddTag(pad, "LaunchPad")
        pad:SetAttribute("LaunchSpeed", LAUNCH_SPEED[def.strength])

        pad.Parent = workspace
        table.insert(createdPads, pad)
    end
end

---------------------------------------------------------------------------
-- Debounce管理
---------------------------------------------------------------------------
local cooldowns: {[Player]: number} = {}

local function isOnCooldown(player: Player): boolean
    local last = cooldowns[player]
    if last and (tick() - last) < COOLDOWN_SEC then
        return true
    end
    return false
end

local function setCooldown(player: Player)
    cooldowns[player] = tick()
end

---------------------------------------------------------------------------
-- Touched打ち上げ
---------------------------------------------------------------------------
local function onPadTouched(pad: Part, hit: BasePart)
    -- キャラクター判定
    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    -- Debounce
    if isOnCooldown(player) then return end
    setCooldown(player)

    -- 打ち上げ速度取得
    local launchSpeed = pad:GetAttribute("LaunchSpeed") or LAUNCH_SPEED.Medium

    -- 修正B: ApplyImpulse — Y方向のみ、水平速度維持
    local mass = hrp.AssemblyMass
    local impulse = Vector3.new(0, launchSpeed * mass, 0)
    hrp:ApplyImpulse(impulse)

    -- Airborne状態セット
    if not playerState[player] then
        playerState[player] = { Airborne = false, TrickActive = false, LastRequestTime = 0 }
    end
    playerState[player].Airborne = true
end

---------------------------------------------------------------------------
-- パッドにTouchedイベント接続
---------------------------------------------------------------------------
local function setupTouchEvents()
    for _, pad in ipairs(createdPads) do
        pad.Touched:Connect(function(hit)
            onPadTouched(pad, hit)
        end)
    end
end

---------------------------------------------------------------------------
-- プレイヤー離脱時クリーンアップ
---------------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    playerState[player] = nil
    cooldowns[player] = nil
end)

---------------------------------------------------------------------------
-- 初期化
---------------------------------------------------------------------------
createPads()
setupTouchEvents()

print("[LaunchPadService] Initialized — " .. #createdPads .. " pads created")
