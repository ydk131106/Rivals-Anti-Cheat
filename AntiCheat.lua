--==================================================================================================
--  Rivals Anti-Cheat Full Bypass
--  Stealth + Performance + Maximum Coverage
--  Version: 2.2 Clean | 2026
--==================================================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Stats             = game:GetService("Stats")
local LocalPlayer       = Players.LocalPlayer

--==================================================================================================
--  CONFIG
--==================================================================================================
local CONFIG = {
    SpoofWalkSpeed          = 16,
    SpoofJumpPower          = 50,
    SpoofHipHeight          = 2,
    SpoofMaxSlopeAngle      = 89,
    EnablePositionSpoof     = true,
    EnableStateSpoof        = true,
    EnableMemorySpoof       = true,
    EnableAnimationSpoof    = true,
    GCRescanInterval        = 4,
    PositionUpdateInterval  = 0.45,
    BlockKick               = true,
    BlockAnalytics          = true,
    BlockSuspiciousRemotes  = true,
    ProtectPlayerRemoving   = true,
    HookInstanceNew         = true,
    SpoofCheckCaller        = true,
    SpoofGetCallingScript   = true,
}

--==================================================================================================
--  UTILS
--==================================================================================================
local function safeHookFunction(original, replacement)
    local ok, result = pcall(function()
        return hookfunction(original, newcclosure(replacement))
    end)
    return ok and result or original
end

local function isSuspiciousRemote(remote)
    local name = string.lower(tostring(remote))
    local keywords = {
        "analytics", "report", "detect", "ban", "anticheat", "ac_", "security",
        "pipeline", "telemetry", "log", "flag", "punish", "kick", "moderation"
    }
    for _, key in ipairs(keywords) do
        if string.find(name, key) then
            return true
        end
    end
    return false
end

--==================================================================================================
--  1. ANALYTICS PIPELINE KILL
--==================================================================================================
local function killAnalyticsController()
    for _, obj in getgc(true) do
        if typeof(obj) == "function" then
            local ok, source = pcall(debug.info, obj, "s")
            if ok and source then
                if string.find(source, "AnalyticsPipelineController")
                or string.find(source, "AnalyticsPipeline")
                or string.find(source, "AntiCheat")
                or string.find(source, "SecurityController") then
                    safeHookFunction(obj, function(...)
                        return task.wait(9e9)
                    end)
                end
            end
        end
    end
end

local function killAnalyticsRemote()
    local success, remote = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then return nil end
        local pipeline = remotes:FindFirstChild("AnalyticsPipeline")
        if not pipeline then return nil end
        return pipeline:FindFirstChild("RemoteEvent") or pipeline:FindFirstChildWhichIsA("RemoteEvent")
    end)

    if success and remote then
        for _, conn in getconnections(remote.OnClientEvent) do
            if conn.Function then
                safeHookFunction(conn.Function, function() end)
            end
            pcall(function() conn:Disable() end)
            pcall(function() conn:Disconnect() end)
        end
    end
end

--==================================================================================================
--  2. NAMECALL HOOK (Kick + Remote Filter)
--==================================================================================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if CONFIG.BlockKick and method == "Kick" then
        return
    end

    if CONFIG.BlockSuspiciousRemotes and (method == "FireServer" or method == "InvokeServer") then
        if isSuspiciousRemote(self) then
            return
        end
    end

    return oldNamecall(self, ...)
end))

--==================================================================================================
--  3. HUMANOID SPOOFING
--==================================================================================================
local spoofTable = {
    WalkSpeed       = CONFIG.SpoofWalkSpeed,
    JumpPower       = CONFIG.SpoofJumpPower,
    HipHeight       = CONFIG.SpoofHipHeight,
    MaxSlopeAngle   = CONFIG.SpoofMaxSlopeAngle,
}

local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
        if spoofTable[key] ~= nil then
            return spoofTable[key]
        end
    end
    return oldIndex(self, key)
end))

local oldNewIndex
oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
    if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
        if spoofTable[key] ~= nil then
            return oldNewIndex(self, key, value)
        end
    end
    return oldNewIndex(self, key, value)
end))

--==================================================================================================
--  4. POSITION SPOOF
--==================================================================================================
local lastSafeCFrame = nil
local lastSafePosition = nil

if CONFIG.EnablePositionSpoof then
    task.spawn(function()
        while task.wait(CONFIG.PositionUpdateInterval) do
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    lastSafeCFrame = hrp.CFrame
                    lastSafePosition = hrp.Position
                end
            end
        end
    end)

    local oldIndexPos
    oldIndexPos = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if not checkcaller() and typeof(self) == "Instance" and self:IsA("BasePart") then
            if self.Name == "HumanoidRootPart" or self.Name == "Torso" or self.Name == "UpperTorso" then
                if key == "Position" and lastSafePosition then
                    return lastSafePosition
                elseif key == "CFrame" and lastSafeCFrame then
                    return lastSafeCFrame
                end
            end
        end
        return oldIndexPos(self, key)
    end))
end

--==================================================================================================
--  5. CHECKCALLER / GETCALLINGSCRIPT SPOOF
--==================================================================================================
if CONFIG.SpoofCheckCaller and checkcaller then
    checkcaller = newcclosure(function()
        return false
    end)
end

if CONFIG.SpoofGetCallingScript and getcallingscript then
    getcallingscript = newcclosure(function()
        return nil
    end)
end

--==================================================================================================
--  6. PLAYERREMOVING PROTECTION
--==================================================================================================
if CONFIG.ProtectPlayerRemoving then
    pcall(function()
        for _, conn in getconnections(Players.PlayerRemoving) do
            if conn.Function then
                safeHookFunction(conn.Function, function() end)
            end
            pcall(function() conn:Disable() end)
        end
    end)
end

--==================================================================================================
--  7. INSTANCE.NEW HOOK
--==================================================================================================
if CONFIG.HookInstanceNew then
    local oldNew = Instance.new
    Instance.new = newcclosure(function(className, parent)
        return oldNew(className, parent)
    end)
end

--==================================================================================================
--  8. MEMORY USAGE SPOOF
--==================================================================================================
if CONFIG.EnableMemorySpoof then
    pcall(function()
        local oldNamecallMem
        oldNamecallMem = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == Stats and method == "GetMemoryUsageMbForTag" then
                local tag = ...
                if tag == "Script" or tag == "LuaHeap" then
                    return 12 + math.random() * 3
                end
            end
            return oldNamecallMem(self, ...)
        end))
    end)
end

--==================================================================================================
--  9. ANIMATION SPOOF
--==================================================================================================
if CONFIG.EnableAnimationSpoof then
    pcall(function()
        local oldIndexAnim
        oldIndexAnim = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if not checkcaller() and typeof(self) == "Instance" and self:IsA("AnimationTrack") then
                if key == "Speed" then
                    return 1
                end
            end
            return oldIndexAnim(self, key)
        end))
    end)
end

--==================================================================================================
--  10. PERIODIC RESCAN
--==================================================================================================
task.spawn(function()
    while true do
        task.wait(CONFIG.GCRescanInterval)
        killAnalyticsController()
        killAnalyticsRemote()
    end
end)

--==================================================================================================
--  INIT
--==================================================================================================
killAnalyticsController()
killAnalyticsRemote()
