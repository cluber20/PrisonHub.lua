--[[
    Prison Life Hub - Mobile Optimized
    UI: Rayfield | Mobile Aimbot included
    Made by xtel
]]

-- Services
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local LocalPlayer       = Players.LocalPlayer
local Teams             = game:GetService("Teams")
local Camera            = workspace.Camera

-- Mobile Detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- State
local Character, RootPart, Humanoid
local AlreadyFound       = {}
local CamCFrame          = Camera.CFrame
local HasHammerEquipped  = false
local LastArrestAttempt  = {}
local ARREST_COOLDOWN    = 1
local AimbotTarget       = nil
local AimbotConnection   = nil

local Toggles = {
    AutoArrest      = false,
    AutoGuns        = false,
    InfiniteStamina = false,
    AntiArrest      = false,
    BreakToilets    = false,
    OpenDoors       = false,
    NoClipDoors     = false,
    AntiTase        = true,
    Aimbot          = false,
    AimbotSilent    = false,
}

local Settings = {
    AimbotFOV       = 150,
    AimbotSmoothing = 0.3,
    AimbotPart      = "Head",
    AimbotTeamCheck = true,
}

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Remotes (safe pcall wrapped)
local TeamEvent, isArrested, ArrestPlayer, PlayerTased

pcall(function()
    TeamEvent    = workspace:WaitForChild("Remote"):WaitForChild("TeamEvent")
    isArrested   = LocalPlayer.Status.isArrested
    ArrestPlayer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ArrestPlayer")
    PlayerTased  = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("PlayerTased")
    local Fake   = PlayerTased:Clone()
    Fake.Parent  = PlayerTased.Parent
    PlayerTased:Destroy()
end)

local TeamAPI = {
    Teams = {
        Criminals = Teams:FindFirstChild("Criminals"),
        Guards    = Teams:FindFirstChild("Guards"),
        Neutral   = Teams:FindFirstChild("Neutral"),
    },
    ChangeTeam = function(team)
        if team and TeamEvent then
            pcall(function() TeamEvent:FireServer(team.Name) end)
        end
    end,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- AIMBOT SYSTEM (Mobile Optimised)
-- ═══════════════════════════════════════════════════════════════════════════

local function GetAimbotPart(targetChar)
    return targetChar:FindFirstChild(Settings.AimbotPart)
        or targetChar:FindFirstChild("HumanoidRootPart")
end

local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    local hum = player.Character:FindFirstChild("Humanoid")
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end
    if Settings.AimbotTeamCheck then
        if LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    end
    if player.Character:FindFirstChildOfClass("ForceField") then return false end
    return true
end

local function GetClosestPlayerToCenter()
    local closestPlayer = nil
    local closestDist   = Settings.AimbotFOV
    local screenCenter  = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if IsValidTarget(player) then
            local part = GetAimbotPart(player.Character)
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist < closestDist then
                        closestDist   = dist
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function StartAimbot()
    if AimbotConnection then AimbotConnection:Disconnect() end
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if not Toggles.Aimbot then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myHum = myChar:FindFirstChild("Humanoid")
        if not myHum or myHum.Health <= 0 then return end
        AimbotTarget = GetClosestPlayerToCenter()
        if AimbotTarget and AimbotTarget.Character then
            local part = GetAimbotPart(AimbotTarget.Character)
            if part then
                if not Toggles.AimbotSilent then
                    local targetCF = CFrame.new(Camera.CFrame.Position, part.Position)
                    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, Settings.AimbotSmoothing)
                end
            end
        end
    end)
end

local function StopAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
    AimbotTarget = nil
end

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible      = false
FOVCircle.Radius       = Settings.AimbotFOV
FOVCircle.Color        = Color3.fromRGB(255, 80, 80)
FOVCircle.Thickness    = 1.5
FOVCircle.Filled       = false
FOVCircle.Transparency = 0.6

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius   = Settings.AimbotFOV
    FOVCircle.Visible  = Toggles.Aimbot
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NAMECALL HOOK (GetAttributes + Silent Aim)
-- ═══════════════════════════════════════════════════════════════════════════

local namecall
namecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "GetAttributes" then
        local ok, result = pcall(namecall, self, ...)
        if ok and result then
            result.AutoFire = true
            result.FireRate = 0.075
            result.Range    = 999999999
            result.Spread   = 999999999
            return result
        end
    end
    if Toggles.AimbotSilent and AimbotTarget and method == "FindPartOnRayWithIgnoreList" then
        if AimbotTarget.Character then
            local part = GetAimbotPart(AimbotTarget.Character)
            if part then
                return part, part.Position, Vector3.new(0,1,0), part.Material
            end
        end
    end
    return namecall(self, ...)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CORE SYSTEMS
-- ═══════════════════════════════════════════════════════════════════════════

local function DisconnectStamina(TargetHumanoid)
    task.wait(1)
    pcall(function()
        for _, c in pairs(getconnections(TargetHumanoid.Jumping)) do c:Disconnect() end
    end)
end

local function HandleChar(Char)
    local Hum = Char:WaitForChild("Humanoid", 10)
    if Hum and Toggles.InfiniteStamina then DisconnectStamina(Hum) end
end

local function QuickSetup(Char)
    local Hum = Char:WaitForChild("Humanoid")
    local Conn
    Conn = Hum.Died:Connect(function()
        pcall(function() TeamAPI.ChangeTeam(LocalPlayer.Team) end)
        Conn:Disconnect()
    end)
end

local function JapaDo()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        c.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
    end
end

local function Teleport(TargetCFrame, Char)
    CamCFrame = Camera.CFrame
    if not Char then Char = LocalPlayer.Character end
    if Char and Char:FindFirstChild("Humanoid") then
        Char.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        Char.Humanoid.Name = "Valid"
    end
    local RP
    local Conn
    Conn = LocalPlayer.CharacterAdded:Connect(function(NewChar)
        RP = NewChar:WaitForChild("HumanoidRootPart")
        RP.CFrame = TargetCFrame
        Conn:Disconnect()
    end)
    LocalPlayer.CharacterAdded:wait()
    repeat task.wait() until RP and (RP.Position - TargetCFrame.Position).Magnitude < 1
end

local function DoorsHandler()
    for _, name in pairs({"Doors","CellDoors"}) do
        local f = workspace:FindFirstChild(name)
        if f then
            for _, v in pairs(f:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide   = false
                    v.Transparency = 0.6
                end
            end
        end
    end
end

local CharPart
local function AutoOpenDoors()
    local Doors = workspace:FindFirstChild("Doors")
    if not Doors then return end
    RunService.Heartbeat:Connect(function()
        Character = LocalPlayer.Character
        if Character and Toggles.OpenDoors then
            CharPart = Character:FindFirstChild("Right Arm")
            if CharPart and Character:FindFirstChild("Humanoid") and Character.Humanoid.Health > 0 then
                for _, obj in pairs(Doors:GetDescendants()) do
                    if obj.Name == "hitbox" then
                        task.spawn(function()
                            firetouchinterest(CharPart, obj, 0)
                            firetouchinterest(CharPart, obj, 1)
                        end)
                    end
                end
            end
        end
    end)
end

local function GetTool(name)
    return (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild(name))
        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(name))
end

local function FindGunSpawner(GunName)
    if AlreadyFound[GunName] then return AlreadyFound[GunName], true end
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name == "TouchGiver" and v:GetAttribute("ToolName") == GunName then
            local tp = v:FindFirstChild("TouchGiver")
            if tp then AlreadyFound[GunName] = tp; return tp, false end
        end
    end
end

local function GetGun(GunName)
    local Giver, Found = FindGunSpawner(GunName)
    if not Giver then return end
    if not Found then
        local Clone = Giver:Clone()
        Clone.Parent = Giver.Parent
        Giver.Parent = workspace:FindFirstChild("Folder") or workspace
        Giver.CanCollide   = false
        Giver.Transparency = 1
    end
    repeat task.wait()
        if RootPart then
            Giver.CFrame = RootPart.CFrame * CFrame.new(math.random(-2,2),0,0)
        end
    until GetTool(GunName)
end

local function BreakAllToilets()
    local meleeEvent = ReplicatedStorage:FindFirstChild("meleeEvent")
    if not meleeEvent then return end
    for _, toilet in pairs(workspace:GetDescendants()) do
        if toilet.Name == "Toilet" and toilet:IsA("Model") then
            for i = 1, 15 do pcall(function() meleeEvent:FireServer(toilet, 1) end) end
        end
    end
end

local function CheckHammerAndBreakToilets()
    if not LocalPlayer.Character then return end
    local hasNow = LocalPlayer.Character:FindFirstChild("Hammer") ~= nil
    if hasNow and not HasHammerEquipped and Toggles.BreakToilets then BreakAllToilets() end
    HasHammerEquipped = hasNow
end

local function AutoArrest()
    local character = LocalPlayer.Character
    if not character then return end
    local hum = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end
    local now = tick()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local tc   = player.Character
            local th   = tc:FindFirstChild("Humanoid")
            local tHRP = tc:FindFirstChild("HumanoidRootPart")
            if th and tHRP and th.Health > 0 then
                local dist = (hrp.Position - tHRP.Position).Magnitude
                if dist <= 15 then
                    local canArrest = false
                    if player.Team == Teams:FindFirstChild("Criminals") then
                        canArrest = true
                    elseif player.Team == Teams:FindFirstChild("Inmates") then
                        local attr = tc:GetAttributes()
                        if attr and (attr.Hostile or attr.Tased or attr.Trespassing) then
                            canArrest = true
                        end
                    end
                    if canArrest and not tc:FindFirstChildOfClass("ForceField") then
                        if not LastArrestAttempt[player] or (now - LastArrestAttempt[player]) > ARREST_COOLDOWN then
                            pcall(function() ArrestPlayer:InvokeServer(player) end)
                            LastArrestAttempt[player] = now
                        end
                    end
                end
            end
        end
    end
end

local function JoinLowestPingServer()
    local IGNORE_FILE = "ServerHop.txt"
    local HOUR = 3600
    local function getIgnored()
        if not isfile(IGNORE_FILE) then return {} end
        local ignored = {}
        local ok, content = pcall(readfile, IGNORE_FILE)
        if not ok then return {} end
        for _, line in ipairs(content:split("\n")) do
            local id, ts = line:match("([^|]+)|?(%d*)")
            local t = tonumber(ts)
            if id and t and (os.time()-t < HOUR) then ignored[id] = t end
        end
        return ignored
    end
    local function saveIgnored(servers)
        local lines = {}
        for id, t in pairs(servers) do table.insert(lines, id.."|"..tostring(t)) end
        pcall(writefile, IGNORE_FILE, table.concat(lines,"\n"))
    end
    local ignored = getIgnored()
    local cursor  = ""
    while true do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?limit=100&sortOrder=Asc&cursor=%s",
            game.PlaceId, cursor
        )
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not ok or not res or not res.data then return end
        table.sort(res.data, function(a,b) return a.ping < b.ping end)
        for _, server in ipairs(res.data) do
            if not ignored[server.id] then
                ignored[server.id] = os.time()
                saveIgnored(ignored)
                pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer) end)
                return
            end
        end
        if not res.nextPageCursor then break end
        cursor = res.nextPageCursor
        task.wait(0.5)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RAYFIELD UI
-- ═══════════════════════════════════════════════════════════════════════════

local Window = Rayfield:CreateWindow({
    Name                   = "Prison Life Hub",
    Icon                   = 0,
    LoadingTitle           = "Prison Life Hub",
    LoadingSubtitle        = "Mobile Ready | by xtel",
    Theme                  = "DarkBlue",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = false,
    ConfigurationSaving    = { Enabled = false },
    KeySystem              = false,
})

local AimbotTab  = Window:CreateTab("🎯 Aimbot",  4483362458)
local MainTab    = Window:CreateTab("⚔️ Combat",  4483362458)
local WeaponsTab = Window:CreateTab("🔫 Weapons", 4483362458)
local UtilityTab = Window:CreateTab("🔧 Utility", 4483362458)
local ServerTab  = Window:CreateTab("🌐 Server",  4483362458)

-- AIMBOT TAB
AimbotTab:CreateSection("Aimbot")

AimbotTab:CreateToggle({
    Name         = "Enable Aimbot",
    CurrentValue = false,
    Flag         = "Aimbot",
    Callback     = function(val)
        Toggles.Aimbot = val
        if val then StartAimbot() else StopAimbot() end
        Rayfield:Notify({ Title="Aimbot", Content=val and "Aimbot ON" or "Aimbot OFF", Duration=2 })
    end,
})

AimbotTab:CreateToggle({
    Name         = "Silent Aim (No Camera Snap)",
    CurrentValue = false,
    Flag         = "AimbotSilent",
    Callback     = function(val) Toggles.AimbotSilent = val end,
})

AimbotTab:CreateToggle({
    Name         = "Team Check (skip teammates)",
    CurrentValue = true,
    Flag         = "AimbotTeamCheck",
    Callback     = function(val) Settings.AimbotTeamCheck = val end,
})

AimbotTab:CreateSection("Settings")

AimbotTab:CreateSlider({
    Name         = "FOV Radius",
    Range        = {50, 500},
    Increment    = 10,
    Suffix       = "px",
    CurrentValue = Settings.AimbotFOV,
    Flag         = "AimbotFOV",
    Callback     = function(val) Settings.AimbotFOV = val end,
})

AimbotTab:CreateSlider({
    Name         = "Smoothing",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = "",
    CurrentValue = 3,
    Flag         = "AimbotSmooth",
    Callback     = function(val) Settings.AimbotSmoothing = val / 10 end,
})

AimbotTab:CreateDropdown({
    Name          = "Target Part",
    Options       = {"Head", "HumanoidRootPart", "Torso", "Upper Torso"},
    CurrentOption = {"Head"},
    Flag          = "AimbotPart",
    Callback      = function(option) Settings.AimbotPart = option[1] end,
})

-- COMBAT TAB
MainTab:CreateSection("Combat")

MainTab:CreateToggle({
    Name         = "Auto Arrest",
    CurrentValue = false,
    Flag         = "AutoArrest",
    Callback     = function(val) Toggles.AutoArrest = val end,
})

MainTab:CreateToggle({
    Name         = "Anti-Arrest (JapaDo)",
    CurrentValue = false,
    Flag         = "AntiArrest",
    Callback     = function(val) Toggles.AntiArrest = val end,
})

MainTab:CreateToggle({
    Name         = "Anti-Tase",
    CurrentValue = true,
    Flag         = "AntiTase",
    Callback     = function(val) Toggles.AntiTase = val end,
})

MainTab:CreateSection("Teams")

MainTab:CreateButton({
    Name     = "Join Criminals",
    Callback = function()
        TeamAPI.ChangeTeam(TeamAPI.Teams.Criminals)
        Rayfield:Notify({ Title="Team", Content="Joined Criminals!", Duration=3 })
    end,
})

MainTab:CreateButton({
    Name     = "Join Guards",
    Callback = function()
        TeamAPI.ChangeTeam(TeamAPI.Teams.Guards)
        Rayfield:Notify({ Title="Team", Content="Joined Guards!", Duration=3 })
    end,
})

-- WEAPONS TAB
WeaponsTab:CreateSection("Auto Guns")

WeaponsTab:CreateToggle({
    Name         = "Auto Get Guns (AK-47, Remington, M9)",
    CurrentValue = false,
    Flag         = "AutoGuns",
    Callback     = function(val) Toggles.AutoGuns = val end,
})

WeaponsTab:CreateButton({ Name="Get AK-47 Now",         Callback=function() GetGun("AK-47") end })
WeaponsTab:CreateButton({ Name="Get Remington 870 Now",  Callback=function() GetGun("Remington 870") end })
WeaponsTab:CreateButton({ Name="Get M9 Now",             Callback=function() GetGun("M9") end })

WeaponsTab:CreateSection("Melee")

WeaponsTab:CreateButton({
    Name     = "Break All Toilets",
    Callback = function()
        BreakAllToilets()
        Rayfield:Notify({ Title="Toilets", Content="Attempted to break all toilets!", Duration=3 })
    end,
})

WeaponsTab:CreateToggle({
    Name         = "Auto Break on Hammer Equip",
    CurrentValue = false,
    Flag         = "BreakToilets",
    Callback     = function(val) Toggles.BreakToilets = val end,
})

-- UTILITY TAB
UtilityTab:CreateSection("Movement")

UtilityTab:CreateToggle({
    Name         = "Infinite Stamina",
    CurrentValue = false,
    Flag         = "InfiniteStamina",
    Callback     = function(val)
        Toggles.InfiniteStamina = val
        if val and LocalPlayer.Character then
            local Hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if Hum then DisconnectStamina(Hum) end
        end
    end,
})

UtilityTab:CreateToggle({
    Name         = "Auto Open Doors",
    CurrentValue = false,
    Flag         = "OpenDoors",
    Callback     = function(val) Toggles.OpenDoors = val end,
})

UtilityTab:CreateToggle({
    Name         = "Doors NoClip",
    CurrentValue = false,
    Flag         = "NoClipDoors",
    Callback     = function(val)
        Toggles.NoClipDoors = val
        if val then DoorsHandler() end
    end,
})

UtilityTab:CreateSection("Teleport")

UtilityTab:CreateButton({
    Name     = "Teleport → Crim Base",
    Callback = function()
        Teleport(CFrame.new(-927,94,2055))
        Rayfield:Notify({ Title="Teleport", Content="Going to Criminal Base!", Duration=3 })
    end,
})

UtilityTab:CreateButton({
    Name     = "Teleport → Yard",
    Callback = function()
        Teleport(CFrame.new(832,98,2510))
        Rayfield:Notify({ Title="Teleport", Content="Going to Yard!", Duration=3 })
    end,
})

-- SERVER TAB
ServerTab:CreateSection("Server Management")

ServerTab:CreateButton({
    Name     = "Hop to Lowest Ping Server",
    Callback = function()
        Rayfield:Notify({ Title="Server Hop", Content="Finding best server...", Duration=4 })
        task.spawn(JoinLowestPingServer)
    end,
})

ServerTab:CreateLabel(isMobile and "📱 Mobile device detected" or "🖥️ PC device detected")

-- ═══════════════════════════════════════════════════════════════════════════
-- HEARTBEAT LOOPS
-- ═══════════════════════════════════════════════════════════════════════════

RunService.Heartbeat:Connect(function()
    Character = LocalPlayer.Character
    if not Character then return end
    RootPart  = Character:FindFirstChild("HumanoidRootPart")
    Humanoid  = Character:FindFirstChild("Humanoid")
    if not Humanoid then return end
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    if Toggles.AutoGuns then
        if not GetTool("AK-47")         then task.spawn(GetGun,"AK-47") end
        if not GetTool("Remington 870") then task.spawn(GetGun,"Remington 870") end
        if not GetTool("M9")            then task.spawn(GetGun,"M9") end
    end
    if Toggles.NoClipDoors then DoorsHandler() end
end)

RunService.Heartbeat:Connect(function()
    if Toggles.AntiArrest and isArrested and isArrested.Value then JapaDo() end
end)

RunService.Heartbeat:Connect(function()
    if Toggles.BreakToilets then CheckHammerAndBreakToilets() end
end)

RunService.Heartbeat:Connect(function()
    if Toggles.AutoArrest then AutoArrest() end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARACTER EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

LocalPlayer.CharacterAdded:Connect(function(Char)
    QuickSetup(Char)
    HandleChar(Char)
    HasHammerEquipped = false
    if Toggles.Aimbot then StartAimbot() end
end)

LocalPlayer.CharacterRemoving:Connect(function(Char)
    if Char:FindFirstChild("Humanoid") and Char.Humanoid.Name ~= "Valid" then
        pcall(function() Teleport(Char.HumanoidRootPart.CFrame, Char) end)
        task.wait()
        Camera.CFrame = CamCFrame
    end
end)

game:GetService("CoreGui").DescendantAdded:Connect(function(Descendant)
    if Descendant.Name == "ErrorPrompt" then task.spawn(JoinLowestPingServer) end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- STARTUP
-- ═══════════════════════════════════════════════════════════════════════════

task.spawn(function()
    if LocalPlayer.Character then
        QuickSetup(LocalPlayer.Character)
        HandleChar(LocalPlayer.Character)
    end
end)

pcall(function() TeamAPI.ChangeTeam(TeamAPI.Teams.Criminals) end)
AutoOpenDoors()

Rayfield:Notify({
    Title    = "Prison Life Hub",
    Content  = (isMobile and "📱 Mobile mode active! " or "🖥️ PC mode active! ") .. "Loaded by xtel",
    Duration = 5,
})

print("Prison Life Hub loaded | Mobile: " .. tostring(isMobile) .. " | user: 2_ll1 | 🇧🇷")
