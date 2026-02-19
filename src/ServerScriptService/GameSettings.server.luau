--[[
    GameSettings.server.lua
    -----------------------
    ゲーム全体のグローバル設定を適用するスクリプト。
]]

local Workspace = game:GetService("Workspace")

-- 重力調整: デフォルト(196.2) * 0.8 = 156.96
local DEFAULT_GRAVITY = 196.2
local GRAVITY_SCALE = 0.8

Workspace.Gravity = DEFAULT_GRAVITY * GRAVITY_SCALE

print("[GameSettings] Gravity set to " .. Workspace.Gravity .. " (x" .. GRAVITY_SCALE .. ")")
