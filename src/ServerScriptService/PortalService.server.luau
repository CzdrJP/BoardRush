-- PortalService.server.luau
-- ロビーからメインステージへのテレポートを管理するサービス

local Players = game:GetService("Players")

-- デバウンスを管理（連続テレポート防止用）
local teleportDebounce = {}

local function setupPortal(portalPart: BasePart, destinationPosition: Vector3)
    if not portalPart then return end
    
    portalPart.Touched:Connect(function(hit)
        local character = hit.Parent
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                -- デバウンスチェック (1秒間)
                if teleportDebounce[player] and (tick() - teleportDebounce[player]) < 1.0 then
                    return
                end
                teleportDebounce[player] = tick()
                
                print("[PortalService] Teleporting player:", player.Name, "to Main Stage")
                
                -- 少し上空にテレポートさせる（めり込み防止）
                local targetCFrame = CFrame.new(destinationPosition + Vector3.new(0, 5, 0))
                
                -- スケボー等の乗り物(Physics)ごと移動させるため、SetPrimaryPartCFrameかPivotToを使用
                character:PivotTo(targetCFrame)
                
                -- 念のため落下速度などをリセットする
                if rootPart.AssemblyLinearVelocity.Magnitude > 0 then
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)
end

-- 初期化: ワークスペース内に配置されるポータルを待機して接続する
task.spawn(function()
    -- サーバー起動時にフォルダが作られるのを待つ
    local stagesFolder = workspace:WaitForChild("Stages", 10)
    if not stagesFolder then return end
    
    local lobbyFolder = stagesFolder:WaitForChild("Lobby", 10)
    if not lobbyFolder then return end
    
    local portal = lobbyFolder:WaitForChild("MainStagePortal", 10)
    local mainStageFolder = stagesFolder:WaitForChild("MainStage", 10)
    local spawnLocation = mainStageFolder and mainStageFolder:WaitForChild("StageSpawn", 10)
    
    if portal and spawnLocation then
        setupPortal(portal, spawnLocation.Position)
        print("[PortalService] Successfully linked MainStagePortal to MainStage spawn.")
    else
        warn("[PortalService] Could not find Portal or SpawnLocation.")
    end
end)
