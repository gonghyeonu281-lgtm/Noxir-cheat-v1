--[========================================================================]
--[  Noxir Cheat v1 - Ultimate Suite (Range Fix + Skin + Rage + ESP)      ]
--[========================================================================]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local controllers = playerScripts:WaitForChild("Controllers")

local features = {
    AntiCheatBypass = true,
    AllSkin = true,
    RageBot = true,
    VoidSpam = false,
    ESP = true,
    RapidFire = true
}

-- ==========================================
-- 0. 안티치트 우회
-- ==========================================
pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and (self.Name:lower():find("kick") or self.Name:lower():find("ban") or self.Name:lower():find("anticheat")) then
                return
            end
            return oldNamecall(self, ...)
        end)
    end
end)

-- ==========================================
-- 1. 올스킨 및 사격장 호환 언락커 코어
-- ==========================================
local EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
if EnumLibrary then pcall(function() EnumLibrary:WaitForEnumBuilder() end) end

local CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
local ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
local DataController = require(controllers:WaitForChild("PlayerDataController", 10))

local equipped, favorites = {}, {}

local function cloneCosmetic(name, cosmeticType, options)
    local base = CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = {}
    for key, value in pairs(base) do data[key] = value end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if EnumLibrary then
        local success, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
        if success and enumId then data.Enum, data.ObjectID = enumId, data.ObjectID or enumId end
    end
    return data
end

local saveFile = "noxir_unlockall/config.json"
local function loadConfig()
    if not readfile or not isfile or not isfile(saveFile) then return end
    pcall(function()
        local config = HttpService:JSONDecode(readfile(saveFile))
        if config.equipped then
            for weapon, cosmetics in pairs(config.equipped) do
                equipped[weapon] = {}
                for cosmeticType, cosmeticData in pairs(cosmetics) do
                    local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted})
                    if cloned then cloned.Seed = cosmeticData.seed equipped[weapon][cosmeticType] = cloned end
                end
            end
        end
        favorites = config.favorites or {}
    end)
end

CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if not features.AllSkin then return true end
    if name:find("MISSING_") then return false end
    return true
end
CosmeticLibrary.OwnsCosmeticNormally = function(...) return features.AllSkin end
CosmeticLibrary.OwnsCosmeticUniversally = function(...) return features.AllSkin end
CosmeticLibrary.OwnsCosmeticForWeapon = function(...) return features.AllSkin end

local originalGet = DataController.Get
DataController.Get = function(self, key)
    local data = originalGet(self, key)
    if key == "CosmeticInventory" and features.AllSkin then
        local proxy = {}
        if data then for k, v in pairs(data) do proxy[k] = v end end
        return setmetatable(proxy, {__index = function(t, k) return CosmeticLibrary.Cosmetics[k] and true or nil end})
    end
    return data
end

-- 사격장 및 일반 매치 모두에서 무기 데이터 오버라이드 강제 적용
local originalGetWeaponData = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponData(self, weaponName)
    if not data then
        -- 사격장에서 데이터가 간헐적으로 비어있을 경우 기본 구조 생성 후 스킨 강제 주입
        data = {Name = weaponName}
    end
    local merged = {}
    for key, value in pairs(data) do merged[key] = value end
    merged.Name = weaponName
    
    if features.AllSkin then
        if equipped[weaponName] then
            for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do merged[cosmeticType] = cosmeticData end
        else
            -- 저장된 커스텀 세팅이 없더라도 사격장에서 기본 스킨 하나를 자동 할당하여 적용
            for cName, cData in pairs(CosmeticLibrary.Cosmetics) do
                if cData.Type == "Skin" and cData.Weapon == weaponName then
                    merged.Skin = cloneCosmetic(cName, "Skin")
                    break
                end
            end
        end
    end
    return merged
end

loadConfig()

-- ==========================================
-- 2. 레이지 봇, 보이드 스팸, ESP, 래피드 파이어
-- ==========================================
local espBoxes = {}

local function updateESP()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            if features.ESP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local box = espBoxes[p]
                if not box then
                    box = Drawing.new("Square")
                    box.Visible = false
                    box.Color = Color3.fromRGB(255, 50, 50)
                    box.Thickness = 1.5
                    box.Filled = false
                    espBoxes[p] = box
                end
                
                local hrp = p.Character.HumanoidRootPart
                local vector, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    box.Size = Vector2.new(2000 / vector.Z, 3500 / vector.Z)
                    box.Position = Vector2.new(vector.X - box.Size.X / 2, vector.Y - box.Size.Y / 2)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                if espBoxes[p] then
                    espBoxes[p].Visible = false
                    espBoxes[p]:Remove()
                    espBoxes[p] = nil
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    pcall(updateESP)

    if features.RageBot then
        pcall(function()
            local camera = Workspace.CurrentCamera
            local myChar = player.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local closestTarget = nil
                local shortestDist = math.huge
                
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                        local hrp = p.Character.HumanoidRootPart
                        local dist = (hrp.Position - myChar.HumanoidRootPart.Position).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closestTarget = p.Character
                        end
                    end
                end
                
                if closestTarget and closestTarget:FindFirstChild("Head") and closestTarget:FindFirstChild("HumanoidRootPart") then
                    local targetHrp = closestTarget.HumanoidRootPart
                    local targetHead = closestTarget.Head
                    
                    local offsetPos = targetHrp.CFrame * CFrame.new(0, 2, 3).Position
                    if features.VoidSpam then
                        local randX = math.random(-4, 4)
                        local randZ = math.random(-4, 4)
                        offsetPos = targetHrp.CFrame * CFrame.new(randX, math.random(1, 3), randZ).Position
                    end
                    
                    myChar.HumanoidRootPart.CFrame = CFrame.new(offsetPos, targetHead.Position)
                    camera.CFrame = CFrame.new(camera.CFrame.Position, targetHead.Position)
                end
            end
        end)
    end
    
    if features.RapidFire then
        pcall(function()
            local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
            if tool then
                for _, v in pairs(tool:GetDescendants()) do
                    if v:IsA("NumberValue") and (v.Name:lower():find("cooldown") or v.Name:lower():find("firerate") or v.Name:lower():find("delay")) then
                        v.Value = 0
                    end
                end
            end
        end)
    end
end)


-- ==========================================
-- 3. UI 메뉴 시스템
-- ==========================================
if CoreGui:FindFirstChild("NoxirCheatGUI") then
    CoreGui.NoxirCheatGUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NoxirCheatGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
ToggleButton.Position = UDim2.new(1, -110, 0, 15)
ToggleButton.Size = UDim2.new(0, 95, 0, 35)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "Noxir UI"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 13
ToggleButton.Active = true
ToggleButton.Draggable = true

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = ToggleButton

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(80, 160, 100)
BtnStroke.Thickness = 1.5
BtnStroke.Parent = ToggleButton

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -165)
MainFrame.Size = UDim2.new(0, 400, 0, 340)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(80, 80, 100)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

local TitleBar = Instance.new("TextLabel")
TitleBar.Name = "TitleBar"
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.Font = Enum.Font.GothamBold
TitleBar.Text = "  Noxir Cheat v1 | Range Fix"
TitleBar.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleBar.TextSize = 13
TitleBar.TextXAlignment = Enum.TextXAlignment.Left

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local Container = Instance.new("ScrollingFrame")
Container.Name = "Container"
Container.Parent = MainFrame
Container.BackgroundTransparency = 1
Container.Position = UDim2.new(0, 15, 0, 45)
Container.Size = UDim2.new(1, -30, 1, -65)
Container.CanvasSize = UDim2.new(0, 0, 0, 340)
Container.ScrollBarThickness = 4

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = Container
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)

local function createToggle(name, text, initialState, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Parent = Container
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    local state = initialState
    local function updateVisual()
        if state then
            btn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = "  " .. text .. ": [ ON ]"
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            btn.Text = "  " .. text .. ": [ OFF ]"
        end
    end
    updateVisual()
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        pcall(function() callback(state) end)
    end)
end

createToggle("RageBotToggle", "Rage Bot", true, function(enabled) features.RageBot = enabled end)
createToggle("VoidSpamToggle", "Void Spam", false, function(enabled) features.VoidSpam = enabled end)
createToggle("ESPToggle", "ESP", true, function(enabled) features.ESP = enabled end)
createToggle("RapidFireToggle", "Rapid Fire", true, function(enabled) features.RapidFire = enabled end)
createToggle("AllSkinToggle", "All Skins Unlocked", true, function(enabled) features.AllSkin = enabled end)

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

print("[Noxir] Ultimate Suite (Range Fix) Loaded!")
