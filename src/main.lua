--[========================================================================]
--[       Noxir Cheat v1 - All Skin Unlocker + Mobile UI Menu          ]
--[========================================================================]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local controllers = playerScripts:WaitForChild("Controllers")

-- ==========================================
-- 1. 올스킨 및 인벤토리 언락커 코어 로직
-- ==========================================

local EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
if EnumLibrary then pcall(function() EnumLibrary:WaitForEnumBuilder() end) end

local CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
local ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
local DataController = require(controllers:WaitForChild("PlayerDataController", 10))

local equipped, favorites = {}, {}
local constructingWeapon, viewingProfile = nil, nil
local lastUsedWeapon = nil

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
    if options then
        if options.inverted ~= nil then data.Inverted = options.inverted end
        if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
    end
    return data
end

local saveFile = "noxir_unlockall/config.json"
local function saveConfig()
    if not writefile then return end
    pcall(function()
        local config = {equipped = {}, favorites = favorites}
        for weapon, cosmetics in pairs(equipped) do
            config.equipped[weapon] = {}
            for cosmeticType, cosmeticData in pairs(cosmetics) do
                if cosmeticData and cosmeticData.Name then
                    config.equipped[weapon][cosmeticType] = {
                        name = cosmeticData.Name, seed = cosmeticData.Seed, inverted = cosmeticData.Inverted
                    }
                end
            end
        end
        makefolder("noxir_unlockall")
        writefile(saveFile, HttpService:JSONEncode(config))
    end)
end

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

local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if name:find("MISSING_") then return originalOwnsCosmetic(self, inventory, name, weapon) end
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic then
        local cType = cosmetic.Type
        if cType == "Skin" or cType == "Charm" or cType == "Dance" or cType == "Emote" or cType == "Wrap" or cType == "Wrapping" or name:lower():find("charm") or name:lower():find("dance") or name:lower():find("emote") or name:lower():find("wrap") then
            return true
        end
    end
    return originalOwnsCosmetic(self, inventory, name, weapon)
end

CosmeticLibrary.OwnsCosmeticNormally = function(...) return true end
CosmeticLibrary.OwnsCosmeticUniversally = function(...) return true end
CosmeticLibrary.OwnsCosmeticForWeapon = function(...) return true end

local originalGet = DataController.Get
DataController.Get = function(self, key)
    local data = originalGet(self, key)
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then for k, v in pairs(data) do 
            local cosmetic = CosmeticLibrary.Cosmetics[k]
            if cosmetic then proxy[k] = v end
        end end
        return setmetatable(proxy, {__index = function(t, k)
            local cosmetic = CosmeticLibrary.Cosmetics[k]
            if cosmetic then return true end
            return nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and table.clone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do 
                result[weapon][name] = isFav
            end
        end
        return result
    end
    return data
end

local originalGetWeaponData = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponData(self, weaponName)
    if not data then return nil end
    local merged = {}
    for key, value in pairs(data) do merged[key] = value end
    merged.Name = weaponName
    if equipped[weaponName] then
        for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do 
            merged[cosmeticType] = cosmeticData
        end
    end
    return merged
end

local FighterController
pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)

if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    local replicationRemotes = remotes and remotes:FindFirstChild("Replication")
    local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter")
    local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
        local args = {...}
        
        if useItemRemote and self == useItemRemote then
            local objectID = args[1]
            if FighterController then
                pcall(function()
                    local fighter = FighterController:GetFighter(player)
                    if fighter and fighter.Items then
                        for _, item in pairs(fighter.Items) do
                            if item:Get("ObjectID") == objectID then lastUsedWeapon = item.Name break end
                        end
                    end
                end)
            end
        end
        
        if self == equipRemote then
            local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
            
            if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                local inventory = originalGet(DataController, "CosmeticInventory")
                if inventory and rawget(inventory, cosmeticName) then 
                    return oldNamecall(self, ...) 
                end
            end
            
            if cosmeticType == "Dance" or cosmeticType == "Emote" or (cosmeticName and (cosmeticName:lower():find("dance") or cosmeticName:lower():find("emote"))) then
                equipped.Dances = equipped.Dances or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped.Dances[cosmeticType] = nil
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                    if cloned then equipped.Dances[cosmeticType] = cloned end
                end
                task.defer(function()
                    pcall(function() DataController.CurrentData:Replicate("CosmeticInventory") end)
                    task.wait(0.1)
                    saveConfig()
                end)
                return
            end
            
            equipped[weaponName] = equipped[weaponName] or {}
            if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                equipped[weaponName][cosmeticType] = nil
                if not next(equipped[weaponName]) then equipped[weaponName] = nil end
            else
                local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                if cloned then equipped[weaponName][cosmeticType] = cloned end
            end
            
            task.defer(function()
                pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end)
                task.wait(0.1)
                saveConfig()
            end)
            return
        end
        
        if self == favoriteRemote then
            local wName, cName, isFav = args[1], args[2], args[3]
            local cosmetic = CosmeticLibrary.Cosmetics[cName]
            if cosmetic then
                favorites[wName] = favorites[wName] or {}
                favorites[wName][cName] = isFav or nil
                saveConfig()
                task.spawn(function() pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end) end)
            end
            return
        end
        
        return oldNamecall(self, ...)
    end)
end

local ClientItem
pcall(function() ClientItem = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)

if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModel = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == player) and weaponName or nil
        
        if weaponPlayer == player and equipped[weaponName] and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local targetTable = viewmodelRef[dataKey] or viewmodelRef.Data
            
            if targetTable then
                if equipped[weaponName].Skin then
                    targetTable[self:ToEnum("Skin") or "Skin"] = equipped[weaponName].Skin
                    targetTable[self:ToEnum("Name") or "Name"] = equipped[weaponName].Skin.Name
                end
                if equipped[weaponName].Charm then
                    targetTable[self:ToEnum("Charm") or "Charm"] = equipped[weaponName].Charm
                end
                if equipped[weaponName].Wrap then
                    targetTable[self:ToEnum("Wrap") or "Wrap"] = equipped[weaponName].Wrap
                end
            end
        end
        
        local result = originalCreateViewModel(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end

local viewModelModule = player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    
    if ClientViewModel.GetCharm then
        local originalGetCharmFunc = ClientViewModel.GetCharm
        ClientViewModel.GetCharm = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Charm then
                return equipped[weaponName].Charm
            end
            return originalGetCharmFunc(self)
        end
    end
    
    if ClientViewModel.GetWrap then
        local originalGetWrapFunc = ClientViewModel.GetWrap
        ClientViewModel.GetWrap = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap then
                return equipped[weaponName].Wrap
            end
            return originalGetWrapFunc(self)
        end
    end

    local originalNew = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if weaponPlayer == player and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            
            local cosmetics = equipped[weaponName]
            if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
            if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
            if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
        end
        
        local result = originalNew(replicatedData, clientItem)
        
        if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
            result:_UpdateWrap()
            task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
        end
        return result
    end
end

ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
    if not weaponData then return nil end
    local weaponName = weaponData.Name
    local shouldShowSkin = (weaponData.Skin and equipped[weaponName] and weaponData.Skin == equipped[weaponName].Skin) or (viewingProfile == player and equipped[weaponName] and equipped[weaponName].Skin)
    if shouldShowSkin and equipped[weaponName] and equipped[weaponName].Skin then
        local skinInfo = self.ViewModels[equipped[weaponName].Skin.Name]
        if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
    end
    return nil
end

pcall(function() 
    local EmoteController = require(controllers:WaitForChild("EmoteController", 10))
    if EmoteController and EmoteController.GetEmotes then
        local originalGetEmotes = EmoteController.GetEmotes
        EmoteController.GetEmotes = function(self)
            local emotes = originalGetEmotes(self)
            for name, cosmetic in pairs(CosmeticLibrary.Cosmetics) do
                if cosmetic and (cosmetic.Type == "Dance" or cosmetic.Type == "Emote" or name:lower():find("dance") or name:lower():find("emote")) then
                    if not emotes[name] then
                        emotes[name] = { Name = name, Type = cosmetic.Type, ObjectID = cosmetic.ObjectID, Enum = cosmetic.Enum }
                    end
                end
            end
            return emotes
        end
    end
end)

pcall(function()
    local ViewProfile = require(player.PlayerScripts.Modules.Pages.ViewProfile)
    if ViewProfile and ViewProfile.Fetch then
        local originalFetch = ViewProfile.Fetch
        ViewProfile.Fetch = function(self, targetPlayer)
            viewingProfile = targetPlayer
            return originalFetch(self, targetPlayer)
        end
    end
end)

loadConfig()


-- ==========================================
-- 2. Noxir Cheat v1 - Mobile UI & Toggle Button
-- ==========================================

if CoreGui:FindFirstChild("NoxirCheatGUI") then
    CoreGui.NoxirCheatGUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NoxirCheatGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- 우측 상단 토글 버튼 (드래그 가능)
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

-- 메인 프레임 (다크 모던 UI 창)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -130)
MainFrame.Size = UDim2.new(0, 400, 0, 260)
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

-- 상단 타이틀 바
local TitleBar = Instance.new("TextLabel")
TitleBar.Name = "TitleBar"
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.Font = Enum.Font.GothamBold
TitleBar.Text = "  Noxir Cheat v1 | Skin Unlocker"
TitleBar.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleBar.TextSize = 13
TitleBar.TextXAlignment = Enum.TextXAlignment.Left

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

-- 콘텐츠 컨테이너
local Container = Instance.new("ScrollingFrame")
Container.Name = "Container"
Container.Parent = MainFrame
Container.BackgroundTransparency = 1
Container.Position = UDim2.new(0, 15, 0, 45)
Container.Size = UDim2.new(1, -30, 1, -65)
Container.CanvasSize = UDim2.new(0, 0, 0, 200)
Container.ScrollBarThickness = 4

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = Container
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)

local function createToggle(name, text, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Parent = Container
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = "  " .. text .. ": [ ON ]"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    local state = true
    btn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            btn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = "  " .. text .. ": [ ON ]"
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            btn.Text = "  " .. text .. ": [ OFF ]"
        end
        pcall(function() callback(state) end)
    end)
end

createToggle("AllSkinToggle", "All Skins & Cosmetics Unlocked", function(enabled)
    print("[Noxir] All-Skin Status: ", enabled)
end)

createToggle("NotifyToggle", "Status Notifications", function(enabled)
    print("[Noxir] Notifications: ", enabled)
end)

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

print("[Noxir] UI Loaded Successfully!")
