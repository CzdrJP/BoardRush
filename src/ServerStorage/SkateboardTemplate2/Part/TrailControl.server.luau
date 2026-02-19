local runService = game:GetService("RunService")
local part = script.Parent
local trailL = part:WaitForChild("TrailL")
local trailR = part:WaitForChild("TrailR")

runService.Heartbeat:Connect(function()
    -- 速度が5以上ならトレイル有効
    local speed = part.AssemblyLinearVelocity.Magnitude
    if speed > 5 then
        trailL.Enabled = true
        trailR.Enabled = true
    else
        trailL.Enabled = false
        trailR.Enabled = false
    end
end)
