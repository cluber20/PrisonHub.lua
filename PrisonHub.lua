--[[
    Prison Life Hub - Mobile Optimized
    UI: Built-in ScreenGui (No external libraries needed)
    Works on Delta mobile executor
    Made by xtel
]]

-- Services
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
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

-- ═══════════════════════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════════════════════

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
-- AIMBOT
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
            if part and not Toggles.AimbotSilent then
                local targetCF = CFrame.new(Camera.CFrame.Position, part.Position)
                Camera.CFrame  = Camera.CFrame:Lerp(targetCF, Settings.AimbotSmoothing)
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
-- NAMECALL HOOK
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
    local RP, Conn
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
-- CUSTOM UI (No external libraries - pure ScreenGui)
-- ═══════════════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PrisonHubUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

-- Colors
local C = {
    BG        = Color3.fromRGB(15, 15, 20),
    Header    = Color3.fromRGB(20, 20, 28),
    Accent    = Color3.fromRGB(80, 120, 255),
    AccentDim = Color3.fromRGB(50, 80, 180),
    Toggle_ON  = Color3.fromRGB(60, 200, 100),
    Toggle_OFF = Color3.fromRGB(60, 60, 75),
    Text      = Color3.fromRGB(240, 240, 255),
    SubText   = Color3.fromRGB(150, 150, 175),
    Button    = Color3.fromRGB(35, 35, 50),
    ButtonHov = Color3.fromRGB(50, 50, 70),
    Section   = Color3.fromRGB(25, 25, 35),
    Tab_ON    = Color3.fromRGB(80, 120, 255),
    Tab_OFF   = Color3.fromRGB(25, 25, 38),
}

-- Helpers
local function make(class, props, parent)
    local inst = Instance.new(class)
    for k,v in pairs(props) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function stroke(color, thickness, p)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(60,60,80)
    s.Thickness = thickness or 1
    s.Parent = p
    return s
end

local function notify(msg)
    local notif = make("Frame", {
        Size = UDim2.new(0, 220, 0, 40),
        Position = UDim2.new(1, -230, 1, -60),
        BackgroundColor3 = C.Header,
        BackgroundTransparency = 0.1,
        ZIndex = 100,
    }, ScreenGui)
    corner(8, notif)
    stroke(C.Accent, 1, notif)
    make("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = msg,
        TextColor3 = C.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 101,
    }, notif)
    task.delay(2.5, function()
        TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
        task.wait(0.3)
        notif:Destroy()
    end)
end

-- ── Main Frame ──
local isOpen = true
local MainFrame = make("Frame", {
    Size = UDim2.new(0, 300, 0, 400),
    Position = UDim2.new(0.5, -150, 0.5, -200),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0,
    ZIndex = 2,
}, ScreenGui)
corner(10, MainFrame)
stroke(C.Accent, 1.5, MainFrame)

-- Make draggable (mobile & PC)
do
    local dragging, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(0, startPos.X + delta.X, 0, startPos.Y + delta.Y)
    end
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Vector2.new(MainFrame.AbsolutePosition.X, MainFrame.AbsolutePosition.Y)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

-- ── Header ──
local Header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = C.Header,
    BorderSizePixel = 0,
    ZIndex = 3,
}, MainFrame)
corner(10, Header)

make("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "🔒 Prison Life Hub",
    TextColor3 = C.Text,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, Header)

-- Close/Minimize button
local CloseBtn = make("TextButton", {
    Size = UDim2.new(0, 28, 0, 20),
    Position = UDim2.new(1, -34, 0.5, -10),
    BackgroundColor3 = Color3.fromRGB(200,60,60),
    Text = "✕",
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    ZIndex = 5,
}, Header)
corner(4, CloseBtn)
CloseBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    MainFrame.Size = isOpen and UDim2.new(0,300,0,400) or UDim2.new(0,300,0,36)
    CloseBtn.Text = isOpen and "✕" or "▼"
end)

-- ── Tab Bar ──
local TabBar = make("Frame", {
    Size = UDim2.new(1, -10, 0, 30),
    Position = UDim2.new(0, 5, 0, 40),
    BackgroundColor3 = C.Section,
    BorderSizePixel = 0,
    ZIndex = 3,
}, MainFrame)
corner(6, TabBar)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 2)
TabLayout.Parent = TabBar
Instance.new("UIPadding", TabBar).PaddingLeft = UDim.new(0,3)

-- ── Content Area ──
local ContentArea = make("ScrollingFrame", {
    Size = UDim2.new(1, -10, 1, -82),
    Position = UDim2.new(0, 5, 0, 76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.Accent,
    CanvasSize = UDim2.new(0,0,0,0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 3,
}, MainFrame)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 4)
ContentLayout.Parent = ContentArea
Instance.new("UIPadding", ContentArea).PaddingTop = UDim.new(0,4)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI BUILDER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local Pages = {}
local CurrentPage = nil
local TabButtons = {}

local function ShowPage(name)
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
    end
    for n, btn in pairs(TabButtons) do
        btn.BackgroundColor3 = (n == name) and C.Tab_ON or C.Tab_OFF
        btn.TextColor3 = (n == name) and C.Text or C.SubText
    end
    CurrentPage = name
end

local function AddTab(name, icon)
    local page = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
        LayoutOrder = #Pages + 1,
    }, ContentArea)
    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0,4)
    pageLayout.Parent = page
    Pages[name] = page

    local tabNames = {"Aimbot","Combat","Weapons","Utility","Server"}
    local tabCount = #tabNames
    local btn = make("TextButton", {
        Size = UDim2.new(1/tabCount, -3, 0, 24),
        BackgroundColor3 = C.Tab_OFF,
        Text = icon,
        TextColor3 = C.SubText,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, TabBar)
    corner(5, btn)
    TabButtons[name] = btn

    btn.MouseButton1Click:Connect(function() ShowPage(name) end)

    return page
end

local function AddSection(page, title, order)
    local sec = make("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        ZIndex = 3,
        LayoutOrder = order or 0,
    }, page)
    make("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = C.Accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, sec)
    -- divider
    make("Frame", {
        Size = UDim2.new(1, -16, 0, 1),
        Position = UDim2.new(0, 8, 1, -1),
        BackgroundColor3 = C.AccentDim,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, sec)
end

local toggleOrder = 0
local function AddToggle(page, label, default, key, callback)
    toggleOrder = toggleOrder + 1
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = C.Section,
        BorderSizePixel = 0,
        ZIndex = 3,
        LayoutOrder = toggleOrder,
    }, page)
    corner(6, row)

    make("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)

    local pill = make("Frame", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -46, 0.5, -9),
        BackgroundColor3 = default and C.Toggle_ON or C.Toggle_OFF,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, row)
    corner(9, pill)

    local knob = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, pill)
    corner(7, knob)

    local val = default or false
    Toggles[key] = val

    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
    }, row)

    btn.MouseButton1Click:Connect(function()
        val = not val
        Toggles[key] = val
        TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = val and C.Toggle_ON or C.Toggle_OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = val and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
        if callback then callback(val) end
    end)
end

local btnOrder = 100
local function AddButton(page, label, callback)
    btnOrder = btnOrder + 1
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = C.Button,
        Text = label,
        TextColor3 = C.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        BorderSizePixel = 0,
        ZIndex = 4,
        LayoutOrder = btnOrder,
    }, page)
    corner(6, btn)
    stroke(C.AccentDim, 1, btn)

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=C.ButtonHov}):Play()
        task.delay(0.15, function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=C.Button}):Play()
        end)
        if callback then callback() end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD PAGES
-- ═══════════════════════════════════════════════════════════════════════════

local P_Aimbot  = AddTab("Aimbot",   "🎯")
local P_Combat  = AddTab("Combat",   "⚔️")
local P_Weapons = AddTab("Weapons",  "🔫")
local P_Utility = AddTab("Utility",  "🔧")
local P_Server  = AddTab("Server",   "🌐")

-- Fix tab button sizes after all tabs added
for name, btn in pairs(TabButtons) do
    btn.Size = UDim2.new(0.18, -2, 0, 24)
end

-- ── AIMBOT PAGE ──
AddSection(P_Aimbot, "AIMBOT", 1)
AddToggle(P_Aimbot, "Enable Aimbot", false, "Aimbot", function(val)
    if val then StartAimbot() else StopAimbot() end
    notify("Aimbot: " .. (val and "ON ✅" or "OFF ❌"))
end)
AddToggle(P_Aimbot, "Silent Aim", false, "AimbotSilent", nil)
AddToggle(P_Aimbot, "Team Check", true, "AimbotTeamCheck", function(val)
    Settings.AimbotTeamCheck = val
end)

-- ── COMBAT PAGE ──
AddSection(P_Combat, "COMBAT", 1)
AddToggle(P_Combat, "Auto Arrest", false, "AutoArrest", nil)
AddToggle(P_Combat, "Anti-Arrest (JapaDo)", false, "AntiArrest", nil)
AddToggle(P_Combat, "Anti-Tase", true, "AntiTase", nil)
AddSection(P_Combat, "TEAMS", 10)
AddButton(P_Combat, "Join Criminals", function()
    TeamAPI.ChangeTeam(TeamAPI.Teams.Criminals)
    notify("Joined Criminals! 🔴")
end)
AddButton(P_Combat, "Join Guards", function()
    TeamAPI.ChangeTeam(TeamAPI.Teams.Guards)
    notify("Joined Guards! 🔵")
end)

-- ── WEAPONS PAGE ──
AddSection(P_Weapons, "AUTO GUNS", 1)
AddToggle(P_Weapons, "Auto Get Guns", false, "AutoGuns", nil)
AddButton(P_Weapons, "Get AK-47", function() task.spawn(GetGun, "AK-47") notify("Getting AK-47...") end)
AddButton(P_Weapons, "Get Remington 870", function() task.spawn(GetGun, "Remington 870") notify("Getting Remington 870...") end)
AddButton(P_Weapons, "Get M9", function() task.spawn(GetGun, "M9") notify("Getting M9...") end)
AddSection(P_Weapons, "MELEE", 20)
AddButton(P_Weapons, "Break All Toilets", function() BreakAllToilets() notify("Breaking toilets! 🚽") end)
AddToggle(P_Weapons, "Auto Break on Hammer", false, "BreakToilets", nil)

-- ── UTILITY PAGE ──
AddSection(P_Utility, "MOVEMENT", 1)
AddToggle(P_Utility, "Infinite Stamina", false, "InfiniteStamina", function(val)
    if val and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if Hum then DisconnectStamina(Hum) end
    end
end)
AddToggle(P_Utility, "Auto Open Doors", false, "OpenDoors", nil)
AddToggle(P_Utility, "Doors NoClip", false, "NoClipDoors", function(val)
    if val then DoorsHandler() end
end)
AddSection(P_Utility, "TELEPORT", 20)
AddButton(P_Utility, "Teleport → Crim Base", function()
    Teleport(CFrame.new(-927,94,2055))
    notify("Teleporting to Crim Base...")
end)
AddButton(P_Utility, "Teleport → Yard", function()
    Teleport(CFrame.new(832,98,2510))
    notify("Teleporting to Yard...")
end)

-- ── SERVER PAGE ──
AddSection(P_Server, "SERVER", 1)
AddButton(P_Server, "Hop to Lowest Ping", function()
    notify("Finding best server...")
    task.spawn(JoinLowestPingServer)
end)

-- Show first tab
ShowPage("Aimbot")

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
        if not GetTool("AK-47")         then task.spawn(GetGun, "AK-47") end
        if not GetTool("Remington 870") then task.spawn(GetGun, "Remington 870") end
        if not GetTool("M9")            then task.spawn(GetGun, "M9") end
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

notify("Prison Life Hub loaded! " .. (isMobile and "📱" or "🖥️"))
print("Prison Life Hub | Custom UI | Mobile: " .. tostring(isMobile) .. " | user: 2_ll1 | 🇧🇷")
