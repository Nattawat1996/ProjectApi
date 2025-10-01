-- decrypted from locker

 --==============================================================
--                      INITIALIZATION V2.1
--==============================================================

--== Game/Guard Checks
if game.PlaceId ~= 105555311806207 then return end
if getgenv().MeowyBuildAZoo then getgenv().MeowyBuildAZoo:Destroy() end
repeat task.wait(1) until game:IsLoaded()

--== Libraries
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

--==============================================================
--                      SERVICES & GLOBALS
--==============================================================

--== Services
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
--== Player & Game Globals
local Player = Players.LocalPlayer
local PlayerUserID = Player.UserId
local GameName = (MarketplaceService:GetProductInfo(game.PlaceId)["Name"]) or "None"
local RunningEnvirontments = true

--== Game Data Paths
local Data = Player:WaitForChild("PlayerGui", 60):WaitForChild("Data", 60)
local ServerTime = ReplicatedStorage:WaitForChild("Time")
local InGameConfig = ReplicatedStorage:WaitForChild("Config")
local ServerReplicatedDict = ReplicatedStorage:WaitForChild("ServerDictReplicated")
local GameRemoteEvents = ReplicatedStorage:WaitForChild("Remote", 30)
local InventoryData = Data:WaitForChild("Asset", 30)
local OwnedPetData = Data:WaitForChild("Pets")
local OwnedEggData = Data:WaitForChild("Egg")
local FoodListData = Data:WaitForChild("FoodStore", 30):WaitForChild("LST", 30)

--== Workspace Paths
local Pet_Folder = workspace:WaitForChild("Pets")
local BlockFolder = workspace:WaitForChild("PlayerBuiltBlocks")
local IslandName = Player:GetAttribute("AssignedIslandName")
local Island = workspace:WaitForChild("Art"):WaitForChild(IslandName)
local Egg_Belt_Folder = ReplicatedStorage:WaitForChild("Eggs"):WaitForChild(IslandName)

--== Remote Events
local PetRE = GameRemoteEvents:WaitForChild("PetRE", 30)
local CharacterRE = GameRemoteEvents:WaitForChild("CharacterRE", 30)
local ConveyorRE = GameRemoteEvents:WaitForChild("ConveyorRE")
local FoodStoreRE = GameRemoteEvents:WaitForChild("FoodStoreRE")
local LotteryRE = GameRemoteEvents:WaitForChild("LotteryRE")
local GiftRE = GameRemoteEvents:WaitForChild("GiftRE")

--==============================================================
--                      GAME DATA TABLES
--==============================================================

local Eggs_InGame = require(InGameConfig:WaitForChild("ResEgg"))["__index"]
local Mutations_InGame = require(InGameConfig:WaitForChild("ResMutate"))["__index"]
local Mutations_With_None = {"None"}
for _, muta in ipairs(Mutations_InGame) do
    table.insert(Mutations_With_None, muta)
end
local PetFoods_InGame = require(InGameConfig:WaitForChild("ResPetFood"))["__index"]
local Pets_InGame = require(InGameConfig:WaitForChild("ResPet"))["__index"]
local ResPetDatabase = require(InGameConfig:WaitForChild("ResPet"))
local ResEggDatabase = require(InGameConfig:WaitForChild("ResEgg"))
local conveyorConfig = {}

-- Load Conveyor Config
pcall(function()
    local module = InGameConfig:WaitForChild("ResConveyor")
    conveyorConfig = require(module)
end)

--==============================================================
--                 SCRIPT STATE & CONFIGURATION
--==============================================================

--== Script State Variables
local IsLoadingConfig = false
local EnvirontmentConnections = {}
local Players_InGame = {}
local MyPets = {}
local MyPets_List = {}
local MyBigPets = {}
local OwnedPets = {}
local Egg_Belt = {}
local bigPetSlotMap = {}
local bigPetUpdateThread = nil
local lastKnownBigPetUIDs = {}
local shopStatus = { upgradesDone = 0, lastAction = "Inactive" }
local fishingState = { lockedPos = nil, didFocus = false }
--== UI Element Placeholders
local shopParagraph, petPlaceParagraph, eggPlaceParagraph, giftSummaryParagraph, sellSummaryParagraph
local bigPetSlot1_Label, bigPetSlot2_Label, bigPetSlot3_Label

--== Script Configuration Table
local Configuration = {
    Main = { AutoCollect=false, Collect_Delay=3, Collect_Type="Delay",AutoUpgradeConveyor = false,AutoUnlockTiles = false },
    Fishing = {
        Auto = false,
        Bait = "FishingBait1"
    },
    Pet  = {
    AutoFeed=false, AutoFeed_Delay=10, SmartFeed=false, SmartFeed_Delay=15,
    SmartFeed_Blacklist = {},
    AutoPlacePet=false, AutoPlacePet_Delay=1.0,
    AutoCollectPet=false, CollectPet_Delay=5,
    SmartPet=false, 
        Filters = {
            PlaceMode = "All",      
            CollectMode = "All",   
            Area = "Any",
            Types = {},
            Mutations = {},
            IncomeAbove = 0,
            IncomeBelow = 0,
        },
    BigPetSlots = { [1] = {}, [2] = {}, [3] = {} },
    },
    Egg = {
    AutoHatch=false,
    AutoBuyEgg=false,
    AutoPlaceEgg=false,
    Filters = {
        Types = {},
        Mutations = {},
    },
    CheckMinCoin=false, 
    MinCoin=0,
    AutoBuyEgg_Delay=3,
    PlaceArea="Any",
    AutoPlaceEgg_Delay=1.0,
    HatchArea="Any",
    Hatch_Delay=15,
},
    Shop = { Food = { AutoBuy=false, AutoBuy_Delay=10, Foods={} } },
    Players = {
    SelectPlayer = "",
    GiftType = "Pet",
    GiftLimit = "",

    PetFilters = {
        Mode = "All",
        Types = {},
        Mutations = {},
        MinIncome = 0,
        MaxIncome = 1000000,
    },
    EggFilters = {
        Mode = "All",
        Types = {},
        Mutations = {},
    },
    FoodFilters = {
        Mode = "All",
        Selected = {},
    },
},
    Sell = { Mode="", Egg_Types={}, Egg_Mutations={}, Pet_Income_Threshold=0 },
    Perf = { Disable3D=false, FPSLock=false, FPSValue=60, HidePets=false, HideEggs=false, HideEffects=false, HideGameUI=false },
    Lottery = { Auto=false, Delay=1800, Count=1 },
    DiscordSync = {
        Enabled = false,
        WebhookURL = "",
        Interval = 60
    },
    Event = { AutoClaim=false, AutoClaim_Delay=3, AutoLottery=false, AutoLottery_Delay=3 },
    AntiAFK=false, Waiting=false,
}
local Options -- Will be assigned by Fluent

--==============================================================
--                 DEBUG & UTILITY FUNCTIONS
--==============================================================

--== Debug Printer
getgenv().MEOWY_DBG = getgenv().MEOWY_DBG or { on = true, toast = false }
local function _tos(v)
    local ok, t = pcall(function() return typeof(v) end)
    t = ok and t or type(v)
    if t == "Vector3" then return string.format("(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z) end
    if t == "Instance" then return string.format("<%s:%s>", v.ClassName, v.Name) end
    if t == "table" then
        local parts = {}
        for k, val in pairs(v) do table.insert(parts, string.format("[%s]=%s", tostring(k), tostring(val))) end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return tostring(v)
end

local function dprint(...)
    if not (getgenv().MEOWY_DBG and getgenv().MEOWY_DBG.on) then return end
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = _tos(select(i, ...)) end
    local msg = table.concat(parts, " ")
    print("[DEBUG] " .. msg)
    if getgenv().MEOWY_DBG.toast then
        pcall(function() Fluent:Notify({ Title = "Debug", Content = string.sub(msg, 1, 190), Duration = 4 }) end)
    end
end

--== General Helpers
local function getPlayerCash()
    return InventoryData and (InventoryData:GetAttribute("Coin") or 0) or 0
end

local function _cloneFoodMap(t)
    local m = {}
    if type(t) == "table" then
        if rawget(t, 1) ~= nil then
            for _, v in ipairs(t) do m[tostring(v)] = true end
        else
            for k, v in pairs(t) do if v then m[tostring(k)] = true end end
        end
    end
    return m
end
--== Gift Counter Helpers
local function safeGetAttribute(obj, attrName, default)
    if not obj then return default end
    local success, result = pcall(function() return obj:GetAttribute(attrName) end)
    return success and (result ~= nil and result or default) or default
end

--== Data Refresh Helpers (บางครั้งเกม recreate โฟลเดอร์ Data)
local function EnsureDataRefs()
    if not (Data and Data.Parent) then return end
    local eg = Data:FindFirstChild("Egg")
    if eg and eg ~= OwnedEggData then OwnedEggData = eg; dprint("[Data] OwnedEggData refreshed.") end
    local pt = Data:FindFirstChild("Pets")
    if pt and pt ~= OwnedPetData then OwnedPetData = pt; dprint("[Data] OwnedPetData refreshed.") end
    local inv = Data:FindFirstChild("Asset")
    if inv and inv ~= InventoryData then InventoryData = inv; dprint("[Data] InventoryData refreshed.") end
end

local function getTodayGiftCount()
    local pg = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    if not Data then return 0 end

    local userFlag = Data:FindFirstChild("UserFlag")
    if not userFlag then return 0 end

    local v = safeGetAttribute(userFlag, "TodaySendGiftCount", 0)
    return tonumber(v) or 0
end
--== UI Status Updaters
local _APP_last, _APP_lastAt = "", 0
local function _setPetPlaceStatus(s, force)
    if not petPlaceParagraph or not petPlaceParagraph.SetDesc then return end
    local now = os.clock()
    if force or s ~= _APP_last or (now - _APP_lastAt) > 0.25 then
        petPlaceParagraph:SetDesc(s)
        _APP_last, _APP_lastAt = s, now
    end
end

local function setShopStatus(msg)
    shopStatus.lastAction = msg
    if shopParagraph and shopParagraph.SetDesc then
        shopParagraph:SetDesc(string.format("Upgrades: %d done\nLast: %s", shopStatus.upgradesDone, shopStatus.lastAction))
    end
end

--== Teleport Helper
local function TeleportToPlayer(targetPlayer)
    if not targetPlayer or not Player then return false, "Invalid player specified" end
    local localCharacter = Player.Character
    local targetCharacter = targetPlayer.Character
    if not localCharacter or not targetCharacter then return false, "Character not found" end
    local localHRP = localCharacter:FindFirstChild("HumanoidRootPart")
    local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not localHRP or not targetHRP then return false, "HumanoidRootPart not found" end
    
    local targetPosition = targetHRP.Position
    local offset = targetHRP.CFrame.LookVector * 5
    local destination = targetPosition + offset
    local newCFrame = CFrame.new(destination, targetPosition)
    
    localHRP.CFrame = newCFrame
    dprint(("[Teleport] Warped to %s successfully"):format(targetPlayer.Name))
    return true, "Success"
end

--==============================================================
--                    INCOME CACHE & HELPERS
--==============================================================

local IncomeCache = { map = {}, built = false, last = 0 }

local function _buildIncomeIndex()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return end
    local s = pg:FindFirstChild("ScreenStorage")
    if not s then return end
    local f = s:FindFirstChild("Frame")
    if not f then return end
    local cp = f:FindFirstChild("ContentPet")
    if not cp then return end
    local sc = cp:FindFirstChild("ScrollingFrame")
    if not sc then return end
    
    IncomeCache.map = {}
    for _, item in ipairs(sc:GetChildren()) do
        local uid = item.Name
        local btn = item:FindFirstChild("BTN") or item:FindFirstChildWhichIsA("Frame")
        local stat = btn and (btn:FindFirstChild("Stat") or btn:FindFirstChildWhichIsA("Frame"))
        local price = stat and (stat:FindFirstChild("Price") or stat:FindFirstChildWhichIsA("Frame"))
        local valueObj = price and price:FindFirstChild("Value")
        local val
        
        if valueObj then
            if valueObj:IsA("NumberValue") or valueObj:IsA("IntValue") then
                val = tonumber(valueObj.Value)
            elseif valueObj:IsA("StringValue") then
                val = tonumber((tostring(valueObj.Value or ""):gsub("[^%d%.]", "")))
            end
        end
        
        if not val and price then
            local function readText(inst)
                local ok, txt = pcall(function() return inst.Text end)
                if ok and txt then return tonumber((tostring(txt):gsub("[^%d%.]", ""))) end
            end
            val = readText(price) or (price:FindFirstChildWhichIsA("TextLabel") and readText(price:FindFirstChildWhichIsA("TextLabel")))
            if not val then
                for _, d in ipairs(price:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then val = readText(d); if val then break end end
                end
            end
        end
        IncomeCache.map[uid] = tonumber(val or 0) or 0
    end
    IncomeCache.last = os.clock()
    IncomeCache.built = true
end

function GetInventoryIncomePerSecByUID(uid)
    if not uid or uid == "" then return 0 end
    local pg = Player:FindFirstChild("PlayerGui"); if not pg then return 0 end
    local screenStorage = pg:FindFirstChild("ScreenStorage"); if not screenStorage then return 0 end
    local frame = screenStorage:FindFirstChild("Frame"); if not frame then return 0 end
    local contentPet = frame:FindFirstChild("ContentPet"); if not contentPet then return 0 end
    local scrolling = contentPet:FindFirstChild("ScrollingFrame"); if not scrolling then return 0 end
    local item = scrolling:FindFirstChild(uid)
    if not item then
        for _, ch in ipairs(scrolling:GetChildren()) do if ch.Name == uid then item = ch break end end
    end
    if not item then return 0 end
    local btn = item:FindFirstChild("BTN") or item:FindFirstChildWhichIsA("Frame")
    if not btn then return 0 end
    local stat = btn:FindFirstChild("Stat") or btn:FindFirstChildWhichIsA("Frame")
    if not stat then return 0 end
    local price = stat:FindFirstChild("Price") or stat:FindFirstChildWhichIsA("Frame")
    if not price then return 0 end
    local valueObj = price:FindFirstChild("Value")
    if valueObj then
        if valueObj:IsA("NumberValue") or valueObj:IsA("IntValue") then return tonumber(valueObj.Value) or 0
        elseif valueObj:IsA("StringValue") then return tonumber((tostring(valueObj.Value or ""):gsub("[^%d%.]", ""))) or 0 end
    end
    local function readText(inst)
        local ok, txt = pcall(function() return inst.Text end)
        if ok and txt then return tonumber((tostring(txt):gsub("[^%d%.]", ""))) end
    end
    local n = readText(price); if n then return n end
    local textLike = price:FindFirstChildWhichIsA("TextLabel") or price:FindFirstChildWhichIsA("TextButton")
    if textLike then n = readText(textLike); if n then return n end end
    for _, d in ipairs(price:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then n = readText(d); if n then return n end end
    end
    return 0
end

local function GetIncomeFast(uid)
    if not IncomeCache.built or (os.clock() - IncomeCache.last > 5) then
        pcall(_buildIncomeIndex)
    end
    local v = IncomeCache.map[uid]
    if v == nil then
        v = GetInventoryIncomePerSecByUID(uid)
        IncomeCache.map[uid] = v or 0
    end
    return v or 0
end

local function SortPetUidsByIncome(petUidList)
    if not petUidList or #petUidList == 0 then return {} end
    local incomeMap = {}
    for _, uid in ipairs(petUidList) do incomeMap[uid] = GetIncomeFast(uid) or 0 end
    table.sort(petUidList, function(a, b) return (incomeMap[a] or 0) > (incomeMap[b] or 0) end)
    return petUidList
end

--==============================================================
--                 PET & EGG HABITAT HELPERS
--==============================================================

local PetHabitatCache = {}
local EggHabitatCache = {}

local function _petTypeByUID(uid)
    local node = OwnedPetData and OwnedPetData:FindFirstChild(uid)
    return node and node:GetAttribute("T") or nil
end

local function GetPetHabitat(petTypeName)
    if not petTypeName then return "Land" end
    if PetHabitatCache[petTypeName] then return PetHabitatCache[petTypeName] end
    local petData = ResPetDatabase[petTypeName]
    if petData and petData.Category == "Ocean" then
        PetHabitatCache[petTypeName] = "Water"
        return "Water"
    end
    PetHabitatCache[petTypeName] = "Land"
    return "Land"
end

local function GetEggHabitat(eggTypeName)
    if not eggTypeName then return "Land" end
    if EggHabitatCache[eggTypeName] then return EggHabitatCache[eggTypeName] end
    local eggData = ResEggDatabase[eggTypeName]
    if eggData and eggData.Category == "Ocean" then
        EggHabitatCache[eggTypeName] = "Water"
        return "Water"
    end
    EggHabitatCache[eggTypeName] = "Land"
    return "Land"
end

local function _rebuildEggQueue()
    EnsureDataRefs()
    local out = {}
    if not OwnedEggData then return out end
    local areaSetting = Configuration.Egg.PlaceArea or "Any" -- "Any","Land","Water"
    for _, eggNode in ipairs(OwnedEggData:GetChildren()) do
        if eggNode and not eggNode:FindFirstChild("DI") then
            local t = eggNode:GetAttribute("T") or "BasicEgg"
            local m = eggNode:GetAttribute("M") or "None"
            local typePicked = (not next(Configuration.Egg.Filters.Types)) or (Configuration.Egg.Filters.Types[t] == true)
            local mutPicked  = (not next(Configuration.Egg.Filters.Mutations)) or (Configuration.Egg.Filters.Mutations[m] == true)
            -- ถ้า Area เป็น Land/Water ให้รับเฉพาะไข่ที่ habitat ตรงกัน
            local areaMatch = (areaSetting == "Any") or (GetEggHabitat(t) == areaSetting)
            if typePicked and mutPicked and areaMatch then
                table.insert(out, eggNode.Name)
            end
        end
    end
    return out
end
--==============================================================
--                 EGG Data To Discord
--==============================================================
-- ฟังก์ชันสำหรับนับไข่ (นำมาจากสคริปต์นับ Inventory ของคุณ)
local function collectEggsForDiscord()
    local counter = {}
    if OwnedEggData then
        for _, egg in ipairs(OwnedEggData:GetChildren()) do
            if egg and not egg:FindFirstChild("DI") then
                local eggType  = egg:GetAttribute("T") or "Unknown"
                local mutation = egg:GetAttribute("M") or "None"
                local key = string.format("%s | %s", tostring(eggType), tostring(mutation))
                counter[key] = (counter[key] or 0) + 1
            end
        end
    end
    local items = {}
    for key, count in pairs(counter) do
        table.insert(items, string.format("%s — x%d", key, count))
    end
    table.sort(items)
    return items
end


--==============================================================
--                 REMOTE EVENT WRAPPERS
--==============================================================

local function SellEgg(uid)
    if not uid or uid == "" then return false, "no uid" end
    CharacterRE:FireServer("Focus", uid) task.wait(0.1)
    local ok, err = pcall(function() PetRE:FireServer("Sell", uid, true) end)
    CharacterRE:FireServer("Focus")
    return ok, err
end

local function SellPet(uid)
    if not uid or uid == "" then return false, "no uid" end
    CharacterRE:FireServer("Focus", uid) task.wait(0.1)
    local ok, err = pcall(function() PetRE:FireServer("Sell", uid) end)
    CharacterRE:FireServer("Focus")
    return ok, err
end

local function fireConveyorUpgrade(index)
    return pcall(function()
        ConveyorRE:FireServer("Upgrade", tonumber(index) or index)
    end)
end

local function fireUnlockTile(lockInfo)
    if not (lockInfo and lockInfo.farmPart) then return false end
    return pcall(function()
        CharacterRE:FireServer("Unlock", lockInfo.farmPart)
    end)
end

local function feedFruitToPet(fruitName, petUID)
    if not petUID then dprint("[SmartFeed] Pet UID not found for feeding!") return false end
    local petCfg = OwnedPetData:FindFirstChild(petUID)
    if petCfg and (not petCfg:GetAttribute("Feed")) then
        dprint(("[SmartFeed] Feeding '%s' to Pet UID: %s"):format(fruitName, petUID))
        CharacterRE:FireServer("Focus", fruitName) 
        task.wait(0.3)
        PetRE:FireServer("Feed", petUID) 
        task.wait(0.3)
        CharacterRE:FireServer("Focus")
        return true
    else
        dprint("[SmartFeed] Pet is on cooldown, skipping feed.")
        return false
    end
end

--==============================================================
--                 GRID & PLOT MANAGEMENT
--==============================================================

--== Plot Index Cache (for area detection)
local PlotIndex = {}              -- "x,z" -> {part=..., area=..}
local SortedPlots = { Any={}, Land={}, Water={} }

do
    for _,p in ipairs(Island:GetDescendants()) do
        if p:IsA("BasePart") and (p.Name:match("^Farm_split_") or p.Name:match("^WaterFarm_split_")) then
            local ic = p:GetAttribute("IslandCoord")
            if ic then
                local k = ("%d,%d"):format(ic.X, ic.Z)
                local area = p.Name:match("^Water") and "Water" or "Land"
                PlotIndex[k] = { part=p, area=area }
                table.insert(SortedPlots[area], p)
                table.insert(SortedPlots.Any, p)
            end
        end
    end
    for _,arr in pairs(SortedPlots) do
        table.sort(arr, function(a,b)
            if a.Position.Z ~= b.Position.Z then return a.Position.Z < b.Position.Z end
            return a.Position.X < b.Position.X
        end)
    end
    dprint("Plot counts -> Any=", #SortedPlots.Any, "Land=", #SortedPlots.Land, "Water=", #SortedPlots.Water)
end

--== Grid Helper Functions
local function Grid_round(n) return math.floor((tonumber(n) or 0) + 0.5) end
local function Grid_keyXZ(x, z) return string.format("%d,%d", Grid_round(x), Grid_round(z)) end

local function _areaFromXZ(x, z)
    local n = PlotIndex[Grid_keyXZ(x, z)]
    return n and n.area or "Any"
end

local function Grid_TileCenterPos(tilePart)
    local p = tilePart
    local cx = math.floor(p.Position.X + 0.5)
    local cz = math.floor(p.Position.Z + 0.5)
    local cy = p.Position.Y + (p.Size.Y * 0.5)
    return Vector3.new(cx, cy, cz)
end

--== Free/Occupied Tile Functions
local function Grid_OccupiedKeys()
    EnsureDataRefs()
    local keys = {}
    -- From placed pets
    for _, m in ipairs(MyPets_List) do
        local root = m.PrimaryPart or m:FindFirstChild("RootPart")
        local gcp = root and root:GetAttribute("GridCenterPos") or m:GetAttribute("GridCenterPos")
        if gcp then
            local v = typeof(gcp)=="Vector3" and gcp or Vector3.new(gcp.X or 0, gcp.Y or 0, gcp.Z or 0)
            keys[Grid_keyXZ(v.X, v.Z)] = true
        end
    end
    if OwnedEggData then
        for _, eggNode in ipairs(OwnedEggData:GetChildren()) do
            local di = eggNode:FindFirstChild("DI")
            if di then
                keys[Grid_keyXZ(di:GetAttribute("X") or 0, di:GetAttribute("Z") or 0)] = true
            end
        end
    end
    -- From placed eggs (workspace)
    for _, model in ipairs(BlockFolder:GetChildren()) do
        -- ใช้ OwnedEggData ปัจจุบันยืนยันว่าเป็นไข่ของเรา
        if OwnedEggData and OwnedEggData:FindFirstChild(model.Name) then
            keys[Grid_keyXZ(model:GetPivot().Position.X, model:GetPivot().Position.Z)] = true
        end
    end
    return keys
end

local function getSpatiallyLockedTileKeys()
    local lockedKeys = {}
    local locksFolder = Island:FindFirstChild("ENV") and Island.ENV:FindFirstChild("Locks")
    if not locksFolder then return lockedKeys end

    local activeLockParts = {}
    for _, lockModel in ipairs(locksFolder:GetChildren()) do
        local farmPart = lockModel:FindFirstChild("Farm")
        if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
            table.insert(activeLockParts, farmPart)
        end
    end

    if #activeLockParts == 0 then return lockedKeys end

    for _, tilePart in ipairs(SortedPlots.Any) do
        local tilePosition = tilePart.Position
        for _, lockPart in ipairs(activeLockParts) do
            local relativePos = lockPart.CFrame:PointToObjectSpace(tilePosition)
            if math.abs(relativePos.X) <= lockPart.Size.X / 2 and math.abs(relativePos.Z) <= lockPart.Size.Z / 2 then
                lockedKeys[Grid_keyXZ(tilePosition.X, tilePosition.Z)] = true
                break
            end
        end
    end
    return lockedKeys
end

local function _waitForEggPlacementData(uid, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 6)
    EnsureDataRefs()
    local eggNode = OwnedEggData and OwnedEggData:FindFirstChild(uid)

    -- ถ้าข้อมูลใน Data หาย ให้ลองดูที่ workspace ก่อน
    if not eggNode and BlockFolder:FindFirstChild(uid) then
        return true
    elseif not eggNode then
        return false
    end

    while os.clock() < deadline do
        -- เงื่อนไขสำเร็จ: DI โผล่ใน Data หรือมีโมเดลใน workspace
        if eggNode:FindFirstChild("DI") or BlockFolder:FindFirstChild(uid) then
            return true
        end
        -- ถ้าโฟลเดอร์ถูก recreate กลางทาง ให้ reacquire node ใหม่
        if not eggNode.Parent or eggNode.Parent ~= OwnedEggData then
            EnsureDataRefs()
            eggNode = OwnedEggData and OwnedEggData:FindFirstChild(uid)
            if not eggNode and BlockFolder:FindFirstChild(uid) then return true end
            if not eggNode then return false end
        end
        task.wait(0.1)
    end
    dprint(("[_waitForEggPlacementData] Timed out waiting for UID: %s"):format(uid))
    return false
end

local function _waitForPetPlacementData(uid, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 5) -- Wait max 5 seconds

    while os.clock() < deadline do
        local petModel = Pet_Folder:FindFirstChild(uid)
        -- ตรวจสอบว่าโมเดลมีอยู่จริง และเป็นของเราจริงๆ (เช็ค UserId)
        if petModel and petModel:GetAttribute("UserId") == PlayerUserID then
            return true -- Confirmation received!
        end
        task.wait(0.1)
    end
    
    dprint(("[_waitForPetPlacementData] Timed out waiting for pet model UID: %s"):format(uid))
    return false -- Timed out
end

local function Grid_FreeList(area)
    local occ = Grid_OccupiedKeys()
    local locked = getSpatiallyLockedTileKeys()
    local pool = (area == "Land" or area == "Water") and SortedPlots[area] or SortedPlots.Any
    local free = {}
    for _, part in ipairs(pool) do
        local k = Grid_keyXZ(part.Position.X, part.Position.Z)
        if not occ[k] and not locked[k] then
            table.insert(free, { part = part, pos = part.Position, key = k })
        end
    end
    return free
end

local function petArea(uid)
    if not uid or uid == "" then return "Any" end
    local petNode = OwnedPetData:FindFirstChild(uid)
    if petNode then
        local di = petNode:FindFirstChild("DI")
        if di then return _areaFromXZ(di:GetAttribute("X") or 0, di:GetAttribute("Z") or 0) end
    end
    local P = OwnedPets[uid]
    if P and P.GridCoord then return _areaFromXZ(P.GridCoord.X or 0, P.GridCoord.Z or 0) end
    return "Any"
end

local function eggArea(eggInst)
    if not eggInst then return "Any" end
    local di = eggInst:FindFirstChild("DI")
    if not di then return "Any" end
    return _areaFromXZ(di:GetAttribute("X") or 0, di:GetAttribute("Z") or 0)
end

--==============================================================
--                  GAME OBJECT STATE MANAGEMENT
--==============================================================

--== Player List Management
local Players_List_Updated = Instance.new("BindableEvent")
table.insert(EnvirontmentConnections, Players.PlayerRemoving:Connect(function(plr)
    local idx = table.find(Players_InGame, plr.Name)
    if idx then table.remove(Players_InGame, idx) end
    Players_List_Updated:Fire(Players_InGame)
end))
table.insert(EnvirontmentConnections, Players.PlayerAdded:Connect(function(plr)
    table.insert(Players_InGame, plr.Name)
    Players_List_Updated:Fire(Players_InGame)
end))
for _, plr in pairs(Players:GetPlayers()) do table.insert(Players_InGame, plr.Name) end

--== Egg Belt Management
table.insert(EnvirontmentConnections,Egg_Belt_Folder.ChildRemoved:Connect(function(egg)
    task.wait(0.1); local eggUID = tostring(egg) or "None"
    if egg and Egg_Belt[eggUID] then Egg_Belt[eggUID] = nil end
end))
table.insert(EnvirontmentConnections,Egg_Belt_Folder.ChildAdded:Connect(function(egg)
    task.wait(0.1); local eggUID = tostring(egg) or "None"
    if egg then
        Egg_Belt[eggUID] = {
            UID = eggUID,
            Mutate = (egg:GetAttribute("M") or "None"),
            Type = (egg:GetAttribute("T") or "BasicEgg")
        }
    end
end))
for _,egg in pairs(Egg_Belt_Folder:GetChildren()) do
    task.spawn(function()
        pcall(function()
            local eggUID = tostring(egg) or "None"
            if egg then
                Egg_Belt[eggUID] = {
                    UID = eggUID,
                    Mutate = (egg:GetAttribute("M") or "None"),
                    Type = (egg:GetAttribute("T") or "BasicEgg")
                }
            end
        end)
    end)
end

--== Pet Management
local function _isOwnedPetModel(model)
    if not (model and model:IsA("Model")) then return false end
    return model:GetAttribute("UserId") == PlayerUserID
end

local function _addMyPet(m)
    if _isOwnedPetModel(m) and not MyPets[m] then
        MyPets[m] = true
        table.insert(MyPets_List, m)
    end
end

local function _buildOwnedPetEntry(pet, petUID)
    if not _isOwnedPetModel(pet) then return end

    local root = pet and (pet.PrimaryPart or pet:FindFirstChild("RootPart"))
    local _cashTxtRef
    local function _getCashTxt()
        if _cashTxtRef and _cashTxtRef.Parent then return _cashTxtRef end
        if not root then return nil end
        local gui = root:FindFirstChild("GUI") or root:FindFirstChildWhichIsA("BillboardGui", true)
        local idle = gui and (gui:FindFirstChild("IdleGUI") or gui:FindFirstChildWhichIsA("Frame", true))
        local cf = idle and (idle:FindFirstChild("CashF") or idle:FindFirstChildWhichIsA("Frame", true))
        _cashTxtRef = cf and (cf:FindFirstChild("TXT") or cf:FindFirstChildWhichIsA("TextLabel", true))
        return _cashTxtRef
    end
    
    local diNode = OwnedPetData:FindFirstChild(petUID)
    diNode = diNode and diNode:FindFirstChild("DI")
    local GridCoord = diNode and Vector3.new(diNode:GetAttribute("X"), diNode:GetAttribute("Y"), diNode:GetAttribute("Z")) or nil

    OwnedPets[petUID] = setmetatable({
        GridCoord = GridCoord, UID = petUID,
        Type = root and root:GetAttribute("Type"),
        Mutate = root and root:GetAttribute("Mutate"),
        Model = pet, RootPart = root,
        RE = root and root:FindFirstChild("RE", true),
        IsBig = root and (root:GetAttribute("BigValue") ~= nil),
        _getCashTxt = _getCashTxt
    }, {
        __index = function(tb, ind)
            if ind == "Coin" then
                local t = tb._getCashTxt()
                if t and t.Text then return tonumber((t.Text:gsub("[^%d%.]", ""))) or 0 end
                return 0
            elseif ind == "ProduceSpeed" or ind == "PS" then
                local rp = rawget(tb, "RootPart")
                local model = rawget(tb, "Model")
                return (rp and rp:GetAttribute("ProduceSpeed")) or (model and model:GetAttribute("ProduceSpeed")) or 0
            end
            return rawget(tb, ind)
        end
    })

    if OwnedPets[petUID].IsBig then
        MyBigPets[petUID] = OwnedPets[petUID]
        dprint("[BigPet tracking] Added:", petUID)
    end
end

local function _removeMyPet(petModel)
    if not petModel then return end
    local petUID = tostring(petModel)
    if OwnedPets[petUID] then OwnedPets[petUID] = nil end
    if MyPets[petModel] then
        MyPets[petModel] = nil
        local index = table.find(MyPets_List, petModel)
        if index then table.remove(MyPets_List, index) end
    end
    if MyBigPets[petUID] then
        MyBigPets[petUID] = nil
        dprint("[BigPet tracking] Removed:", petUID)
    end
end

local function _forceRefreshPetData()
    dprint("[State Refresh] Forcing a full refresh of pet data...")
    table.clear(MyPets); table.clear(MyPets_List); table.clear(OwnedPets); table.clear(MyBigPets)
    for _, pet in ipairs(Pet_Folder:GetChildren()) do
        if _isOwnedPetModel(pet) then
            local petUID = tostring(pet)
            _addMyPet(pet)
            _buildOwnedPetEntry(pet, petUID)
        end
    end
    dprint("[State Refresh] Refresh complete.")
end

-- Initial scan
for _, m in ipairs(Pet_Folder:GetChildren()) do _addMyPet(m) end
for _, pet in pairs(Pet_Folder:GetChildren()) do task.spawn(_buildOwnedPetEntry, pet, tostring(pet)) end

--== Big Pet Specific Management
function getBigPetSlotMapping()
    local slotMapping = {}
    local islandModel = workspace.Art:FindFirstChild(IslandName)
    local bigPetFolder = islandModel and islandModel:FindFirstChild("ENV", true) and islandModel.ENV:FindFirstChild("BigPet")
    if not bigPetFolder then return {} end

    local slotAnchorPositions = {}
    for i = 1, 3 do
        local slotAnchor = bigPetFolder:FindFirstChild(tostring(i))
        local activeModel = slotAnchor and slotAnchor:FindFirstChild("Active")
        if activeModel and activeModel.WorldPivot then
            slotAnchorPositions[i] = activeModel.WorldPivot.Position
        end
    end

    local myPlacedBigPets = {}
    for _, petModel in ipairs(workspace.Pets:GetChildren()) do
        if petModel:GetAttribute("UserId") == PlayerUserID then
            local rootPart = petModel.PrimaryPart or petModel:FindFirstChild("RootPart")
            if rootPart and rootPart:FindFirstChild("GUI/BigPetGUI") then
                table.insert(myPlacedBigPets, { UID = petModel.Name, Position = petModel:GetPivot().Position })
            end
        end
    end

    for slot, anchorPos in pairs(slotAnchorPositions) do
        local closestPetUID, closestDistance = nil, math.huge
        for _, pet in ipairs(myPlacedBigPets) do
            local distance = (Vector2.new(pet.Position.X, pet.Position.Z) - Vector2.new(anchorPos.X, anchorPos.Z)).Magnitude
            if distance < closestDistance then
                closestDistance, closestPetUID = distance, pet.UID
            end
        end
        if closestDistance < 10 then slotMapping[slot] = closestPetUID else slotMapping[slot] = nil end
    end
    return slotMapping
end

local function updateBigPetSlots()
    if not bigPetSlot1_Label or not Options["BigPetSlot1_Foods"] then
        dprint("[updateBigPetSlots] UI is not fully ready, skipping.")
        return
    end

    local Labels = {bigPetSlot1_Label, bigPetSlot2_Label, bigPetSlot3_Label}
    local Dropdowns = {Options["BigPetSlot1_Foods"], Options["BigPetSlot2_Foods"], Options["BigPetSlot3_Foods"]}
    local physicalSlots = getBigPetSlotMapping() 

    bigPetSlotMap = {}
    for slot, uid in pairs(physicalSlots) do
        if uid then bigPetSlotMap[uid] = slot end
    end
    
    for i = 1, 3 do
        local petUID_in_slot = physicalSlots[i]
        if petUID_in_slot and MyBigPets[petUID_in_slot] then
            local petData = MyBigPets[petUID_in_slot]
            Labels[i]:SetDesc(string.format("Detected: [%s|%s]", petData.Type, petData.Mutate or "None"))
            local savedFoods = Configuration.Pet.BigPetSlots[i] or {}
            pcall(function() Dropdowns[i]:SetValue(savedFoods) end)
        else
            Labels[i]:SetDesc("No Big Pet Detected")
            pcall(function() Dropdowns[i]:SetValue({}) end)
        end
    end
end

local function onBigPetListChanged()
    if bigPetUpdateThread then task.cancel(bigPetUpdateThread); bigPetUpdateThread = nil end
    
    bigPetUpdateThread = task.delay(1, function()
        local currentBigPetUIDs = {}
        for uid in pairs(MyBigPets) do table.insert(currentBigPetUIDs, uid) end
        table.sort(currentBigPetUIDs)

        local currentKey = table.concat(currentBigPetUIDs, ",")
        local lastKey = table.concat(lastKnownBigPetUIDs, ",")

        if currentKey ~= lastKey then
            dprint("[UI] Big Pet list has changed. Updating UI.")
            pcall(updateBigPetSlots)
            lastKnownBigPetUIDs = currentBigPetUIDs
        else
            dprint("[UI] No actual change in Big Pet list. Skipping update.")
        end
        bigPetUpdateThread = nil
    end)
end

local function handlePossibleBigPetChange_OnAdd(petModel)
    if not _isOwnedPetModel(petModel) then return end
    local root = petModel.PrimaryPart or petModel:FindFirstChild("RootPart")
    if root and root:GetAttribute("BigValue") ~= nil then
        onBigPetListChanged()
    end
end

--==============================================================
--                  PERFORMANCE HELPERS
--==============================================================

--== FPS Locker
local function _pick_fps_setter()
    local candidates = {
        rawget(getgenv(), "setfpscap"), rawget(getgenv(), "set_fps_cap"),
        rawget(_G, "setfpscap"), rawget(_G, "set_fps_cap"),
        (syn and syn.set_fps_cap), (syn and syn.setfpscap),
        (typeof(setfpscap) == "function" and setfpscap), (typeof(set_fps_cap) == "function" and set_fps_cap),
    }
    for _, fn in ipairs(candidates) do if type(fn) == "function" then return fn end end
    return nil
end
local _setFPSCap = _pick_fps_setter()

getgenv().MEOWY_FPS = getgenv().MEOWY_FPS or { locked = false, cap = 60 }
local function ApplyFPSLock()
    if not _setFPSCap then
        Fluent:Notify({ Title = "FPS", Content = "Executor does not support setfpscap", Duration = 5 })
        return
    end
    if Configuration.Perf.FPSLock then
        local cap = math.max(5, math.floor(tonumber(Configuration.Perf.FPSValue) or 60))
        getgenv().MEOWY_FPS.locked = true; getgenv().MEOWY_FPS.cap = cap
        _setFPSCap(cap)
        Fluent:Notify({ Title = "FPS Locked", Content = tostring(cap), Duration = 5 })
    else
        getgenv().MEOWY_FPS.locked = false
        _setFPSCap(1000)
        Fluent:Notify({ Title = "FPS", Content = "Unlocked", Duration = 5 })
    end
end

--== Visibility Toggles (Hide Pets, Eggs, Effects, UI)
local _partPrev, _particlePrev, _togglePrev, _uiPrev =
    setmetatable({}, { __mode="k" }), setmetatable({}, { __mode="k" }),
    setmetatable({}, { __mode="k" }), setmetatable({}, { __mode="k" })
local _effectsConn, _petsConn, _eggsConn, _uiConn

local function _setPartVisible(part, visible)
    if visible then
        part.LocalTransparencyModifier = _partPrev[part] or 0
        _partPrev[part] = nil
    else
        if _partPrev[part] == nil then _partPrev[part] = part.LocalTransparencyModifier end
        part.LocalTransparencyModifier = 1
    end
end

local function _applyModelVisible(model, visible)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            _setPartVisible(d, visible)
            d.CastShadow = visible
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            if _togglePrev[d] == nil then _togglePrev[d] = d.Enabled end
            d.Enabled = visible and (_togglePrev[d] ~= false)
        end
    end
end

local function ApplyHidePets(on)
    for _, m in ipairs(Pet_Folder:GetChildren()) do _applyModelVisible(m, not on) end
    if _petsConn then _petsConn:Disconnect(); _petsConn = nil end
    if on then
        _petsConn = Pet_Folder.ChildAdded:Connect(function(m) task.wait(); _applyModelVisible(m, false) end)
        table.insert(EnvirontmentConnections, _petsConn)
    end
end

local function ApplyHideEggs(on)
    for _, m in ipairs(BlockFolder:GetChildren()) do
        if OwnedEggData:FindFirstChild(m.Name) then _applyModelVisible(m, not on) end
    end
    if _eggsConn then _eggsConn:Disconnect(); _eggsConn = nil end
    if on then
        _eggsConn = BlockFolder.ChildAdded:Connect(function(m) task.wait(); if OwnedEggData:FindFirstChild(m.Name) then _applyModelVisible(m, false) end end)
        table.insert(EnvirontmentConnections, _eggsConn)
    end
end

local function _applyEffectInst(inst, enable)
    if inst:IsA("ParticleEmitter") then
        if enable then
            inst.Rate = _particlePrev[inst] or inst.Rate
            _particlePrev[inst] = nil
        else
            if _particlePrev[inst] == nil then _particlePrev[inst] = inst.Rate end
            inst.Rate = 0
        end
    elseif inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Highlight") then
        if _togglePrev[inst] == nil then _togglePrev[inst] = inst.Enabled end
        inst.Enabled = enable and (_togglePrev[inst] ~= false)
    elseif inst:IsA("Explosion") then
        pcall(function() inst.Visible = enable end)
    end
end

local function ApplyHideEffects(on)
    if _effectsConn then _effectsConn:Disconnect(); _effectsConn = nil end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Highlight") or d:IsA("Explosion") then
            _applyEffectInst(d, not on)
        end
    end
    if on then
        _effectsConn = workspace.DescendantAdded:Connect(function(d) _applyEffectInst(d, false) end)
        table.insert(EnvirontmentConnections, _effectsConn)
    end
end

local function ApplyHideGameUI(on)
    local pg = Player:FindFirstChild("PlayerGui"); if not pg then return end
    local fluentGui = (Fluent and Fluent.GuiObject) or (Fluent and Fluent.ScreenGui) or (Fluent and Fluent.Root) or nil
    local windowRoot = nil; pcall(function() windowRoot = _G.Fluent and _G.Fluent.ScreenGui end)
    local myGui = windowRoot or (fluentGui and fluentGui:FindFirstAncestorOfClass("ScreenGui")) or pg:FindFirstChildOfClass("ScreenGui")
    local whitelistNames = { PerfWhite = true }
    local whitelistInst  = {}; if myGui then whitelistInst[myGui] = true end
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local popupDropGui = playerGui:FindFirstChild("PopupDrop")
    local _popupHBConn
    _popupHBConn = RunService.Heartbeat:Connect(function()
        if popupDropGui then            
            local controllerScript = popupDropGui:FindFirstChild("PopupDrop")
            if controllerScript and controllerScript:IsA("LocalScript") and controllerScript.Disabled == false then                
                controllerScript.Disabled = true
                print("Permanently disabled 'PopupDrop' LocalScript.")
                if _popupHBConn then _popupHBConn:Disconnect() _popupHBConn = nil end
            end
        end
    end)
    table.insert(EnvirontmentConnections, _popupHBConn)
    for _,ch in ipairs(pg:GetChildren()) do
        if ch:IsA("ScreenGui") and not (whitelistInst[ch] or whitelistNames[ch.Name]) then
            if on then if _uiPrev[ch] == nil then _uiPrev[ch] = ch.Enabled end; ch.Enabled = false
            else if _uiPrev[ch] ~= nil then ch.Enabled = _uiPrev[ch]; _uiPrev[ch] = nil end end
        end
    end
    if _uiConn then _uiConn:Disconnect(); _uiConn = nil end
    if on then
        _uiConn = pg.ChildAdded:Connect(function(ch)
            task.wait()
            if ch:IsA("ScreenGui") and not (whitelistInst[ch] or whitelistNames[ch.Name]) and Configuration.Perf.HideGameUI then
                if _uiPrev[ch] == nil then _uiPrev[ch] = ch.Enabled end
                ch.Enabled = false
            end
        end)
        table.insert(EnvirontmentConnections, _uiConn)
    end
end
--== 3D Rendering Toggle
local function _toggleWhiteOverlay(show)
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return end
    local gui = pg:FindFirstChild("PerfWhite") or Instance.new("ScreenGui", pg)
    gui.Name = "PerfWhite"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 1e9; gui.ResetOnSpawn = false
    local frame = gui:FindFirstChild("F") or Instance.new("Frame", gui)
    frame.Name = "F";
    frame.Size = UDim2.fromScale(1,1); frame.BackgroundColor3 = Color3.new(0,0,0)
    frame.BackgroundTransparency = show and 0 or 1
    gui.Enabled = show
end

local function Perf_Set3DEnabled(enable3D)
    local ok = pcall(function() RunService:Set3dRenderingEnabled(enable3D) end)
    _toggleWhiteOverlay(not enable3D)
end
--==============================================================
--                       TASK MANAGER
--==============================================================

local TaskMgr = {}
do
    local registry = {}
    function TaskMgr.start(name, runnerFn, ...) -- [MODIFIED] Added ... to accept more arguments
        TaskMgr.stop(name)
        local token = { alive = true, name = name }
        local args = {...} -- [NEW] Pack the extra arguments into a table
        local co = task.spawn(function()
            -- [MODIFIED] Pass the arguments when calling the runner function
            local ok, err = pcall(function() runnerFn(token, table.unpack(args)) end) 
            if not ok then warn(("[Task:%s] crashed: %s"):format(name, tostring(err))) end
        end)
        registry[name] = { token = token, co = co }
        dprint("Task start:", name)
    end
    function TaskMgr.stop(name)
        local h = registry[name]
        if h then if h.token then h.token.alive = false end; registry[name] = nil; dprint("Task stop:", name) end
    end
    function TaskMgr.isRunning(name) return registry[name] ~= nil end
    function TaskMgr.stopAll()
        for _,h in pairs(registry) do if h.token then h.token.alive = false end end
        registry = {}; dprint("Task stopAll()")
    end
end

-- Helper for tasks to wait while checking the alive token
local function _waitAlive(tok, sec)
    local t = tonumber(sec) or 0
    if t <= 0 then task.wait(); return tok.alive end
    local deadline = os.clock() + t
    while tok.alive and os.clock() < deadline do task.wait() end
    return tok.alive
end

--==============================================================
--                 TASK RUNNERS: MAIN & SHOP
--==============================================================

local function runAutoCollect(tok)
    while tok.alive do
        for _, pet in pairs(OwnedPets) do
            if not tok.alive then break end
            if pet and pet.RE then
                pcall(function() pet.RE:FireServer("Claim") end)
                task.wait(0.5) -- Added delay
            else
                task.wait()
            end
        end
        local d = tonumber(Configuration.Main.Collect_Delay) or 3
        if not _waitAlive(tok, d) then break end
    end
end

local function runAutoUpgradeConveyor(tok)
    shopStatus = { upgradesDone = 0, lastAction = "Starting..." }
    setShopStatus("Ready to upgrade!")
    
    while tok.alive do
        if not next(conveyorConfig) then
            setShopStatus("Waiting for config...")
            if not _waitAlive(tok, 2) then break end
            continue
        end

        local function findNextUpgradeData()
            local conveyorFolder = Island:FindFirstChild("ENV") and Island.ENV:FindFirstChild("Conveyor")
            if not conveyorFolder then return nil end
            local highestIndex = 0
            for _, conveyor in ipairs(conveyorFolder:GetChildren()) do
                local index = tonumber(tostring(conveyor.Name):match("(%d+)"))
                if index and index > highestIndex then highestIndex = index end
            end
            local nextIndex = highestIndex == 0 and 1 or highestIndex + 1
            local nextConveyorName = "Conveyor" .. tostring(nextIndex)
            if conveyorConfig and conveyorConfig[nextConveyorName] then
                local upgradeData = conveyorConfig[nextConveyorName]
                local cost = upgradeData.Cost
                if type(cost) == "string" then cost = tonumber(tostring(cost):gsub("[^%d%.]", "")) end
                return { idx = nextIndex, cost = cost or math.huge }
            end
            return nil
        end
        
        local nextUpgrade = findNextUpgradeData()

        if not nextUpgrade then
            setShopStatus("Conveyor maxed out! Stopping.")
            Fluent:Notify({ Title = "Auto Upgrade", Content = "Conveyor is maxed out. Stopping.", Duration = 5 })
            pcall(function() Options["AutoUpgradeConveyor"]:SetValue(false) end)
            TaskMgr.stop("AutoUpgradeConveyor"); return
        end

        if getPlayerCash() >= nextUpgrade.cost then
            setShopStatus(string.format("Upgrading to Conveyor #%d...", nextUpgrade.idx))
            if fireConveyorUpgrade(nextUpgrade.idx) then
                task.wait(2)
                shopStatus.upgradesDone = shopStatus.upgradesDone + 1
            end
            task.wait(0.5)
        else
            setShopStatus("Waiting for money for next conveyor...")
            if not _waitAlive(tok, 2) then break end
        end
    end
    setShopStatus("Stopped.")
end

local function runAutoUnlockTiles(tok)
    setShopStatus("Auto Unlock Tiles: running")

    local function getLockedTiles()
        local locked = {}
        local locksFolder = Island:FindFirstChild("ENV") and Island.ENV:FindFirstChild("Locks")
        if not locksFolder then return {} end
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            local farmPart = lockModel:FindFirstChild("Farm")
            if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                table.insert(locked, {
                    model = lockModel, farmPart = farmPart,
                    cost = tonumber(farmPart:GetAttribute("LockCost")) or math.huge
                })
            end
        end
        return locked
    end

    while tok.alive do
        local lockedTiles = getLockedTiles()
        if #lockedTiles == 0 then
            setShopStatus("All tiles unlocked! Stopping.")
            Fluent:Notify({ Title = "Auto Unlock", Content = "All tiles unlocked. Stopping.", Duration = 5 })
            pcall(function() Options["AutoUnlockTiles"]:SetValue(false) end)
            TaskMgr.stop("AutoUnlockTiles"); return
        end

        local cash = getPlayerCash()
        local didSomething = false
        table.sort(lockedTiles, function(a, b) return (a.cost or math.huge) < (b.cost or math.huge) end)

        for _, tileInfo in ipairs(lockedTiles) do
            if not tok.alive or cash < (tileInfo.cost or math.huge) then break end
            setShopStatus(("Unlocking %s (%d)..."):format(tileInfo.model.Name, tileInfo.cost or 0))
            if fireUnlockTile(tileInfo) then
                didSomething = true
                cash = cash - (tileInfo.cost or 0)
            end
            if not _waitAlive(tok, 0.2) then break end
        end

        if not tok.alive then break end
        if not didSomething then
            setShopStatus("Waiting for money for next tile...")
            if not _waitAlive(tok, 1.0) then break end
        else
            if not _waitAlive(tok, 0.2) then break end
        end
    end
    setShopStatus("Stopped.")
end

local function runAutoBuyFood(tok)
    while tok.alive do
        for foodName, stockAmount in pairs(FoodListData:GetAttributes()) do
            if not tok.alive then break end
            if stockAmount > 0 and Configuration.Shop.Food.Foods[foodName] then
                pcall(function() FoodStoreRE:FireServer(foodName) end)
                task.wait(0.12 + math.random() * 0.12)
            end
        end
        local delay = (tonumber(Configuration.Shop.Food.AutoBuy_Delay) or 10) + math.random() * 0.35
        if not _waitAlive(tok, delay) then break end
    end
end


--==============================================================
--                 TASK RUNNERS: PET FEATURES
--==============================================================

local function pickFoodPerPet(slotNumber, invAttrs)
    local allowedFoodsConfig = Configuration.Pet.BigPetSlots[slotNumber]
    if not allowedFoodsConfig or not next(allowedFoodsConfig) then return nil end

    local allowedFoods = {}
    for food, isAllowed in pairs(allowedFoodsConfig) do
        if isAllowed then table.insert(allowedFoods, food) end
    end
    table.sort(allowedFoods)

    for _, name in ipairs(allowedFoods) do
        if (tonumber(invAttrs[name]) or 0) > 0 then return name end
    end
    return nil
end

local function runAutoFeed(tok)
    local Data_OwnedPets = Data:WaitForChild("Pets",30)
    while tok.alive do
        if not InventoryData then InventoryData = Data:FindFirstChild("Asset") end
        local Data_Inventory = (InventoryData and InventoryData:GetAttributes()) or {}
        for uid, petModel in pairs(MyBigPets) do
            if not tok.alive then break end

            local slot = bigPetSlotMap[uid]
            if slot then
                local petCfg = Data_OwnedPets:FindFirstChild(uid)
                if petCfg and (not petCfg:GetAttribute("Feed")) then
                    local Food = pickFoodPerPet(slot, Data_Inventory)
                    if Food and Food ~= "" then
                        CharacterRE:FireServer("Focus", Food) task.wait(0.3)
                        PetRE:FireServer("Feed", uid) task.wait(0.3)
                        CharacterRE:FireServer("Focus")
                        Data_Inventory[Food] = math.max(0, (tonumber(Data_Inventory[Food] or 0) or 0) - 1)
                    end
                end
            end
        end
        if not _waitAlive(tok, tonumber(Configuration.Pet.AutoFeed_Delay) or 10) then break end
    end
end

--== SmartFeed Helpers
local SmartFeedConfig = {
    { Fruit = "Pear", UnlockType = "MUTATION", UnlockTarget = "Golden", Slots={1,2,3} },
    { Fruit = "Pineapple", UnlockType = "MUTATION", UnlockTarget = "Diamond", Slots={1,2,3} },
    { Fruit = "DragonFruit", UnlockType = "MUTATION", UnlockTarget = "Electirc", Slots={1,2,3} },
    { Fruit = "GoldMango", UnlockType = "MUTATION", UnlockTarget = "Fire", Slots={1,2,3} },
    { Fruit = "VoltGinkgo", UnlockType = "MUTATION", UnlockTarget = "Dino", Slots={1,2,3} },
    { Fruit = "Durian", UnlockType = "MUTATION", UnlockTarget = "Snow", Slots={1,2,3} },
    { Fruit = "BloodstoneCycad", UnlockType = "PET", UnlockTarget = {"Ankylosaurus","Velociraptor","Stegosaurus","Triceratops","Pachycephalosaur","Pterosaur"}, Slots = {1, 2} },
    { Fruit = "ColossalPinecone", UnlockType = "PET", UnlockTarget = {"Tyrannosaurus","Brontosaurus","Plesiosaur"}, Slots = {1, 2} },
    { Fruit = "DeepseaPearlFruit", UnlockType = "PET", UnlockTarget = {"Manta","Shark","Anglerfish"}, Slots = {3} },
}

local function isMutationUnlocked(mutationName)
    local playerGui = Player:WaitForChild("PlayerGui", 5)
    local screenGui = playerGui and playerGui:WaitForChild("ScreenBigPetSwitch", 5)
    local rootFrame = screenGui and screenGui:WaitForChild("Root", 5)
    local mutsFrame = rootFrame and rootFrame:WaitForChild("Muts", 5)
    if not mutsFrame then return false end
    local mutationFrame = mutsFrame:FindFirstChild(mutationName)
    local lockFrame = mutationFrame and mutationFrame:FindFirstChild("lock")
    return lockFrame and not lockFrame.Visible
end

local function isBigPetUnlocked(petName)
    local playerGui = Player:WaitForChild("PlayerGui", 5)
    local screenGui = playerGui and playerGui:WaitForChild("ScreenBigPetSwitch", 5)
    local rootFrame = screenGui and screenGui:WaitForChild("Root", 5)
    local mainFrame = rootFrame and rootFrame:WaitForChild("Frame", 5)
    local scrollingFrame = mainFrame and mainFrame:WaitForChild("ScrollingFrame", 5)
    if not scrollingFrame then return false end
    local BLACK_COLOR = Color3.new(0, 0, 0)
    for _, petInstance in ipairs(scrollingFrame:GetChildren()) do
        if petInstance.Name == petName then
            local btn = petInstance:FindFirstChild("BTN")
            local vpf = btn and btn:FindFirstChild("VPF")
            if vpf and vpf.Ambient ~= BLACK_COLOR then return true end
        end
    end
    return false
end

function openBigPetUIForSlot(slotNumber)
    local TIMEOUT = 5 

    -- 1. ใช้ WaitForChild เพื่อรอแต่ละส่วนของ Path
    local islandName = Player:GetAttribute("AssignedIslandName")
    local islandModel = workspace.Art:WaitForChild(islandName, TIMEOUT)
    if not islandModel then warn("หา Island Model ไม่เจอ: " .. islandName); return false end

    local envFolder = islandModel:WaitForChild("ENV", TIMEOUT)
    if not envFolder then warn("หาโฟลเดอร์ ENV ไม่เจอ"); return false end

    local bigPetFolder = envFolder:WaitForChild("BigPet", TIMEOUT)
    if not bigPetFolder then warn("หาโฟลเดอร์ BigPet ไม่เจอ"); return false end

    local slotAnchor = bigPetFolder:WaitForChild(tostring(slotNumber), TIMEOUT)
    if not slotAnchor then warn("หา Anchor ของ Slot " .. slotNumber .. " ไม่เจอ"); return false end

    local activeModel = slotAnchor:WaitForChild("Active", TIMEOUT)
    if not activeModel then warn("หา Model 'Active' ใน Slot " .. slotNumber .. " ไม่เจอ"); return false end

    local switchModel = activeModel:WaitForChild("Switch", TIMEOUT)
    
    -- ▼▼▼ [ส่วนที่แก้ไข] ตรวจสอบว่าเป็น Model ก็พอ ▼▼▼
    if not (switchModel and switchModel:IsA("Model")) then
        warn("หาปุ่ม Switch ของ Slot " .. slotNumber .. " ไม่เจอ หรือไม่ใช่ Model!")
        return false
    end
    
    -- 2. วาร์ปตัวละคร
    local character = Players.LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then warn("หา HumanoidRootPart ไม่เจอ!"); return false end
    
    dprint("กำลังวาร์ปไปที่ Switch ของ Slot " .. slotNumber .. " เพื่อเปิด UI...")
    
    -- ▼▼▼ [ส่วนที่แก้ไข] ดึง CFrame จาก GetPivot() แทน PrimaryPart ▼▼▼
    local pivotCFrame = switchModel:GetPivot()
    hrp.CFrame = pivotCFrame * CFrame.new(0, 15, 0)
    task.wait(1)
    
    return true
end

--== SmartFeed Runner
-- ================== runSmartFeed  ==================
local function runSmartFeed(tok)
    local Data_OwnedPets = Data:WaitForChild("Pets", 30)

    while tok.alive do
        dprint("[SmartFeed] Starting new check cycle...")
        local invAttrs = (InventoryData and InventoryData:GetAttributes()) or {}
        local currentPetSlots = {}
        for uid, slot in pairs(bigPetSlotMap) do
            currentPetSlots[slot] = uid
        end
        
        local actionTakenThisCycle = false

        for slotNumber = 1, 3 do
            if not tok.alive or actionTakenThisCycle then break end
            
            local petUID = currentPetSlots[slotNumber]
            if not petUID then
                dprint(("[SmartFeed] Slot %d is empty, skipping..."):format(slotNumber))
                continue
            end

            local petCfg = Data_OwnedPets:FindFirstChild(petUID)
            if not petCfg or petCfg:GetAttribute("Feed") then
                dprint(("[SmartFeed] Pet in Slot %d (%s) is on cooldown, skipping..."):format(slotNumber, petUID))
                continue
            end
            
            if not openBigPetUIForSlot(slotNumber) then
                warn(("[SmartFeed] Failed to open UI for Slot %d, skipping..."):format(slotNumber))
                continue
            end
            task.wait(2.5)

            -- [Priority 1] Check for "Pet Unlocks"
            dprint(("[SmartFeed] Checking for 'Pet Unlock' for Slot %d"):format(slotNumber))
            for _, config in ipairs(SmartFeedConfig) do
                -- [MODIFIED] Added blacklist check
                local isBlacklisted = Configuration.Pet.SmartFeed_Blacklist[config.Fruit] == true
                
                if config.UnlockType == "PET" and table.find(config.Slots, slotNumber) and (invAttrs[config.Fruit] or 0) > 0 and not isBlacklisted then
                    local targets = (type(config.UnlockTarget) == "table") and config.UnlockTarget or {config.UnlockTarget}
                    for _, petName in ipairs(targets) do
                        if not isBigPetUnlocked(petName) then
                            dprint(("[SmartFeed] PET target found! Feeding '%s' to Pet in Slot %d to unlock '%s'"):format(config.Fruit, slotNumber, petName))
                            if feedFruitToPet(config.Fruit, petUID) then
                                actionTakenThisCycle = true
                            end
                            break
                        end
                    end
                elseif isBlacklisted and (invAttrs[config.Fruit] or 0) > 0 then
                     dprint(("[SmartFeed] Skipped feeding '%s' because it is blacklisted."):format(config.Fruit))
                end
                if actionTakenThisCycle then break end
            end

            -- [Priority 2] Check for "Mutation Unlocks"
            if not actionTakenThisCycle then
                dprint(("[SmartFeed] Checking for 'Mutation Unlock' for Slot %d"):format(slotNumber))
                for _, config in ipairs(SmartFeedConfig) do
                    if config.UnlockType == "MUTATION" then
                        local target = config.UnlockTarget
                        local fruit = config.Fruit
                        local hasFruit = (invAttrs[fruit] or 0) > 0
                        local isUnlocked = isMutationUnlocked(target)
                        -- [MODIFIED] Added blacklist check
                        local isBlacklisted = Configuration.Pet.SmartFeed_Blacklist[fruit] == true
                        
                        dprint(("[SmartFeed] - Checking: %s, Needs: %s, Has Fruit: %s, Is Unlocked: %s, Blacklisted: %s"):format(target, fruit, tostring(hasFruit), tostring(isUnlocked), tostring(isBlacklisted)))

                        if hasFruit and not isUnlocked and not isBlacklisted then
                            dprint(("[SmartFeed] MUTA target found! Feeding '%s' to Pet in Slot %d to unlock '%s'"):format(fruit, slotNumber, target))
                            if feedFruitToPet(fruit, petUID) then
                                actionTakenThisCycle = true
                                break 
                            end
                        end
                    end
                end
            end
            
            local screenGui = Players.LocalPlayer.PlayerGui:FindFirstChild("ScreenBigPetSwitch")
            if screenGui then screenGui.Enabled = false end
        end

        local delay = tonumber(Configuration.Pet.SmartFeed_Delay) or 15
        dprint(("[SmartFeed] Cycle complete, waiting %d seconds..."):format(delay))
        if not _waitAlive(tok, delay) then break end
    end
end

local function runAutoCollectPet(tok)
    local function passArea(uid)
        local want = Configuration.Pet.Filters.Area or "Any"
        return want == "Any" or petArea(uid) == want
    end

    while tok.alive do
        local CollectMode = Configuration.Pet.Filters.CollectMode or "All"
        local function claimDel(UID, PetData)
            if PetData.RE then pcall(function() PetData.RE:FireServer("Claim") end) end
            pcall(function() CharacterRE:FireServer("Del", UID) end)
        end

        for UID, PetData in pairs(OwnedPets) do
            if not tok.alive then break end
            if not (PetData and not PetData.IsBig and passArea(UID)) then continue end
            
            local shouldCollect = false
            if CollectMode == "All" then
                shouldCollect = true
            elseif CollectMode == "Match" then
                local petType = PetData.Type
                local petMuta = PetData.Mutate or "None"
                
                local passTypeCheck = not next(Configuration.Pet.Filters.Types) or Configuration.Pet.Filters.Types[petType]
                local passMutaCheck = not next(Configuration.Pet.Filters.Mutations) or Configuration.Pet.Filters.Mutations[petMuta]

                if passTypeCheck and passMutaCheck then
                    shouldCollect = true
                end
            elseif CollectMode == "Income <=" then
                local threshold = tonumber(Configuration.Pet.Filters.IncomeBelow) or 0
                local ps = tonumber(PetData.ProduceSpeed) or 0
                shouldCollect = (ps <= threshold)
            end
            
            if shouldCollect then
                claimDel(UID, PetData)
                task.wait(0.2)
            end
        end
        
        local delay = tonumber(Configuration.Pet.CollectPet_Delay) or 5
        if not _waitAlive(tok, delay) then break end
    end
end
--==============================================================
--                 TASK RUNNERS: Discord
--==============================================================
-- Task Runner ใหม่สำหรับส่งข้อมูลไป Discord อัตโนมัติ
local function runAutoSyncToDiscord(tok)
    local _request = (syn and syn.request) or (http and http.request) or request
    if not _request then
        warn("[DiscordSync] Executor request function not found. Stopping task.")
        pcall(function() Options["DiscordSyncToggle"]:SetValue(false) end)
        return
    end

    local function sendDiscordMessage(webhook, message)
         local success, err = pcall(function()
             local body = HttpService:JSONEncode({ content = message })
             _request({
                 Url = webhook,
                 Method = "POST",
                 Headers = { ["Content-Type"] = "application/json" },
                 Body = body
             })
         end)
         if not success then
             warn("[DiscordSync] Failed to send message:", err)
             Fluent:Notify({ Title = "Discord Sync", Content = "ส่งข้อมูลล้มเหลว!", Duration = 5 })
         else
             dprint("[DiscordSync] Message sent successfully.")
             Fluent:Notify({ Title = "Discord Sync", Content = "ส่งข้อมูลไข่สำเร็จ!", Duration = 5 })
         end
    end

    while tok.alive do
        dprint("[DiscordSync] Starting sync cycle.")
        local webhookURL = Configuration.DiscordSync.WebhookURL
        
        if not webhookURL or #webhookURL < 20 or not (webhookURL:match("discord.com") or webhookURL:match("discordapp.com")) then
            warn("[DiscordSync] Webhook URL is invalid or not set. Waiting for next cycle.")
        else
            local eggLines = collectEggsForDiscord()
            local body = (#eggLines > 0) and table.concat(eggLines, "\n") or "ไม่มีไข่ที่ยังไม่วางในกระเป๋า"
            local message = string.format("🥚 **Egg Inventory Update for %s**\n```\n%s\n```", Player.Name, body)
            sendDiscordMessage(webhookURL, message)
        end

        local delayInMinutes = tonumber(Configuration.DiscordSync.Interval) or 60
        dprint(("[DiscordSync] Sync complete. Waiting for %d minutes."):format(delayInMinutes))
        if not _waitAlive(tok, delayInMinutes * 60) then break end
    end
end



--==============================================================
--                 TASK RUNNERS: FISHING FEATURES
--==============================================================
    local function getFishingThrowPos()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        -- หากหาตัวละครไม่เจอ ให้ใช้ตำแหน่งกล้องแทนชั่วคราว
        local pos = hrp and hrp.Position or workspace.CurrentCamera.CFrame.Position
        -- ตำแหน่ง Y+10 ตามที่กำหนด
        return pos + Vector3.new(2, 10, 0)
    end
    local function runAutoFishing(tok)
    local FishingRE = GameRemoteEvents:WaitForChild("FishingRE")
    if not FishingRE then
        warn("[AutoFishing] ไม่พบ FishingRE! กำลังหยุดการทำงาน")
        pcall(function() Options["AutoFishingToggle"]:SetValue(false) end)  
        return
    end

    -- ยิง Focus แค่ครั้งแรกสุดที่เริ่ม Task
    if not fishingState.didFocus then
        local CharacterRE = GameRemoteEvents:WaitForChild("CharacterRE", 5)
        if CharacterRE then
            dprint("[AutoFishing] กำลังส่งคำสั่ง Focus เริ่มต้น...")
            pcall(function() CharacterRE:FireServer("Focus", "FishRob") end)
        end
        fishingState.didFocus = true
    end

    dprint("[AutoFishing] เริ่มสแปมการตกปลา...")
    while tok.alive do
        -- ตรวจสอบว่ามีตำแหน่งที่ล็อคไว้หรือไม่
        if not fishingState.lockedPos then
            warn("[AutoFishing] ไม่พบตำแหน่งที่ล็อคไว้! กำลังหยุด...")
            pcall(function() Options["AutoFishingToggle"]:SetValue(false) end)
            break
        end

        local selectedBait = Configuration.Fishing.Bait
        -- ยิง RemoteEvent ตามลำดับที่ถูกต้อง
        CharacterRE:FireServer("Focus", "FishRob")
        FishingRE:FireServer("Start")
        FishingRE:FireServer("Throw", {NoMove = true, Bait = selectedBait, Pos = fishingState.lockedPos})
        FishingRE:FireServer("POUT", {NoMove = true, SUC = 1})
        if not _waitAlive(tok, 0.01) then break end
    end
    dprint("[AutoFishing] หยุดการทำงานแล้ว")
end

--==============================================================
--                 TASK RUNNERS: EGG FEATURES
--==============================================================

local function runAutoHatch(tok)
    while tok.alive do
        local wantArea = Configuration.Egg.HatchArea or "Any"
        for _, egg in pairs(OwnedEggData:GetChildren()) do
            if not tok.alive then break end
            local di = egg:FindFirstChild("DI")
            if di and egg:GetAttribute("D") and (ServerTime.Value >= egg:GetAttribute("D")) then
                if (wantArea == "Any") or (eggArea(egg) == wantArea) then
                    local EggModel = BlockFolder:FindFirstChild(egg.Name)
                    local RootPart = EggModel and (EggModel.PrimaryPart or EggModel:FindFirstChild("RootPart"))
                    local RF = RootPart and RootPart:FindFirstChild("RF")
                    if RF then task.spawn(function() RF:InvokeServer("Hatch") end) end
                end
            end
        end
        local delay = tonumber(Configuration.Egg.Hatch_Delay) or 15
        if not _waitAlive(tok, delay) then break end
    end
end

local function runAutoBuyEgg(tok)
    while tok.alive do
        local minCoin = tonumber(Configuration.Egg.MinCoin) or 0
        local passMoney = (not Configuration.Egg.CheckMinCoin) or (getPlayerCash() >= minCoin)
        
        if passMoney then
            for _, egg in pairs(Egg_Belt) do
                if not tok.alive then break end
                local okType = Configuration.Egg.Filters.Types[egg.Type]
                local okMut  = Configuration.Egg.Filters.Mutations[egg.Mutate]
                if okType and okMut then
                    pcall(function() CharacterRE:FireServer("BuyEgg", egg.UID) end)
                    task.wait(0.15 + math.random() * 0.15)
                end
            end
        end

        local delay = (tonumber(Configuration.Egg.AutoBuyEgg_Delay) or 3) + math.random() * 0.4
        if not _waitAlive(tok, delay) then break end
    end
end

--==============================================================
--                 TASK RUNNERS: EVENT & MISC
--==============================================================

local function runAutoClaim(tok)
    local EventTaskData, ResEvent
    for _, Data_Folder in pairs(Data:GetChildren()) do
        if tostring(Data_Folder):match("^(.*)EventTaskData$") then EventTaskData = Data_Folder; break end
    end
    for _, v in pairs(ReplicatedStorage:GetChildren()) do
        if tostring(v):match("^(.*)Event$") then ResEvent = v; break end
    end
    
    local EventRE = ResEvent and GameRemoteEvents:FindFirstChild(tostring(ResEvent) .. "RE")
    local Tasks = EventTaskData and EventTaskData:FindFirstChild("Tasks")

    while tok.alive do
        if Tasks and EventRE then
            for _, Quest in pairs(Tasks:GetChildren()) do
                if not tok.alive then break end
                EventRE:FireServer({event = "claimreward", id = Quest:GetAttribute("Id")})
                task.wait(0.5)
            end
        end
        local delay = tonumber(Configuration.Event.AutoClaim_Delay) or 3
        if not _waitAlive(tok, delay) then break end
    end
end

local function runAutoLottery(tok)
    while tok.alive do
        -- ตรวจสอบก่อนว่า InventoryData พร้อมใช้งานหรือไม่
        if InventoryData then
            -- อ่านค่า Attribute ที่ชื่อว่า "LotteryTicket" จากกระเป๋าโดยตรง
            local ticketCount = InventoryData:GetAttribute("LotteryTicket")

            -- แปลงค่าที่อ่านได้เป็นตัวเลข (ถ้าไม่มีค่าหรือแปลงไม่ได้ ให้เป็น 0)
            -- แล้วตรวจสอบว่ามีตั๋วมากกว่า 0 ใบหรือไม่
            if (tonumber(ticketCount) or 0) > 0 then
                dprint(("[AutoLottery] พบตั๋ว %d ใบในกระเป๋า, กำลังใช้งาน..."):format(ticketCount))
                LotteryRE:FireServer({ event = "lottery", count = 1 })
            else
                dprint("[AutoLottery] ไม่พบตั๋วในกระเป๋า, กำลังรอ...")
            end
        else
            warn("[AutoLottery] ไม่พบ InventoryData, ไม่สามารถตรวจสอบตั๋วได้")
        end

        -- หน่วงเวลาก่อนตรวจสอบรอบถัดไป (เหมือนเดิม)
        local delay = tonumber(Configuration.Event.AutoLottery_Delay) or 60
        if not _waitAlive(tok, delay) then break end
    end
end

local function runAntiAFK(tok)
    while tok.alive do
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        if not _waitAlive(tok, 30) then break end
    end
end

local function runEnforceFPSLock(tok)
    while tok.alive do
        -- 1. รอ 3 วินาทีก่อนที่จะทำงานครั้งแรก
        -- การล็อกครั้งแรกเกิดขึ้นตอนกด Toggle ไปแล้ว
        if not _waitAlive(tok, 3) then break end
        if not tok.alive then break end -- ตรวจสอบอีกครั้งหลังจากการรอ

        if Configuration.Perf.FPSLock then
            -- 2. ทำการล็อก FPS ซ้ำแบบเงียบๆ โดยไม่แสดง Notification
            if _setFPSCap then
                local cap = math.max(5, math.floor(tonumber(Configuration.Perf.FPSValue) or 60))
                _setFPSCap(cap)
            end
        else
            -- หากผู้ใช้ปิด Toggle ฟังก์ชันนี้จะหยุดทำงานเองโดยอัตโนมัติจาก Callback
            TaskMgr.stop("EnforceFPSLock")
            break
        end
    end
end
--==============================================================
--           TASK RUNNERS: Gift
--==============================================================
local function resetGiftUIState()
    if giftSummaryParagraph then
        giftSummaryParagraph:SetTitle("Send Gift Complete!")
        giftSummaryParagraph:SetDesc("Press 'Preview Items' to start a new gift.")
    end
    Configuration.Players.IsGifting = false
    currentGiftingList = {} -- Clear the list
end
--==============================================================
--          NEW FUNCTION: GATHER ITEMS FOR GIFTING PREVIEW (v2)
--==============================================================
local function gatherItemsForGifting()
    local targetPlayer = Players:FindFirstChild(Configuration.Players.SelectPlayer)
    if not targetPlayer then
        Fluent:Notify({ Title = "Error", Content = "Selected player not found.", Duration = 5 })
        return nil
    end

    local giftType = Configuration.Players.GiftType
    local limit = (tonumber(Configuration.Players.GiftLimit) or math.huge)
    local itemsToSend = {} -- Will hold raw UIDs
    local itemSummary = {} 

    -- ... (โค้ดส่วนที่ค้นหา Pet, Egg, Food จะยังคงเหมือนเดิมทุกประการ) ...
    -- ... (You don't need to change the item finding logic inside this function) ...
    if giftType == "Pet" then
        local filters = Configuration.Players.PetFilters
        local petsToFilter = {}
        for _, pet in ipairs(OwnedPetData:GetChildren()) do
            if not pet:GetAttribute("D") then table.insert(petsToFilter, pet.Name) end
        end
        local sortedPets = SortPetUidsByIncome(petsToFilter)

        for _, uid in ipairs(sortedPets) do
            if #itemsToSend >= limit then break end
            local pet = OwnedPetData:FindFirstChild(uid)
            if pet then
                local shouldAdd = false
                if filters.Mode == "All" then shouldAdd = true
                elseif filters.Mode == "Match" then
                    local t, m = pet:GetAttribute("T"), pet:GetAttribute("M") or "None"
                    if (not next(filters.Types) or filters.Types[t]) and (not next(filters.Mutations) or filters.Mutations[m]) then shouldAdd = true end
                elseif filters.Mode == "Range" then
                    local income = GetIncomeFast(uid) or 0
                    if income >= (filters.MinIncome or 0) and income <= (filters.MaxIncome or math.huge) then shouldAdd = true end
                end
                if shouldAdd then
                    table.insert(itemsToSend, uid)
                    local petType = pet:GetAttribute("T") or "Unknown"
                    local petMuta = pet:GetAttribute("M") or "None"
                    local name = ("%s (%s)"):format(petType, petMuta)
                    itemSummary[name] = (itemSummary[name] or 0) + 1
                end
            end
        end
    -- ... (rest of the egg and food logic is the same)
    elseif giftType == "Egg" then
        local filters = Configuration.Players.EggFilters
        for _, egg in ipairs(OwnedEggData:GetChildren()) do
            if #itemsToSend >= limit then break end
            if not egg:FindFirstChild("DI") then
                local shouldAdd = false
                if filters.Mode == "All" then shouldAdd = true
                elseif filters.Mode == "Match" then
                    local t, m = egg:GetAttribute("T") or "BasicEgg", egg:GetAttribute("M") or "None"
                    if (not next(filters.Types) or filters.Types[t]) and (not next(filters.Mutations) or filters.Mutations[m]) then shouldAdd = true end
                end
                if shouldAdd then
                    table.insert(itemsToSend, egg.Name)
                    local eggType = egg:GetAttribute("T") or "UnknownEgg"
                    local eggMuta = egg:GetAttribute("M") or "None"
                    local name = ("%s (%s)"):format(eggType, eggMuta)
                    itemSummary[name] = (itemSummary[name] or 0) + 1
                end
            end
        end
    elseif giftType == "Food" then
        local filters = Configuration.Players.FoodFilters
        local inv = InventoryData and InventoryData:GetAttributes() or {}
        for foodName, amount in pairs(inv) do
            if #itemsToSend >= limit then break end
            if table.find(PetFoods_InGame, foodName) then
                local shouldAdd = false
                if filters.Mode == "All" then shouldAdd = true
                elseif filters.Mode == "Select" then
                    if filters.Selected[foodName] then shouldAdd = true end
                end
                if shouldAdd then
                    local countToAdd = math.min(amount, limit - #itemsToSend)
                    for i = 1, countToAdd do
                        table.insert(itemsToSend, foodName)
                    end
                    itemSummary[foodName] = (itemSummary[foodName] or 0) + countToAdd
                end
            end
        end
    end
    
    if #itemsToSend == 0 then return nil end
    
    local sortedSummary = {}
    for name, count in pairs(itemSummary) do
        table.insert(sortedSummary, {name = name, count = count})
    end
    table.sort(sortedSummary, function(a, b) return a.name < b.name end)
    
    -- [MODIFIED] Return the raw list of UIDs as the 4th value
    return sortedSummary, #itemsToSend, targetPlayer.Name, itemsToSend
end

local function runGifting(tok, giftList)
    local targetPlayer = Players:FindFirstChild(Configuration.Players.SelectPlayer)
    if not targetPlayer then 
        resetGiftUIState(); return 
    end
    
    if not giftList then
        warn("[Task:Gifting] crashed: giftList is nil.")
        resetGiftUIState()
        return
    end
    TeleportToPlayer(targetPlayer) 
    task.wait(3)
    local sent = 0
    local totalToSend = #giftList

        for i, uid in ipairs(giftList) do
        -- guard: หยุดเมื่อแตะ daily cap
        local today = getTodayGiftCount()
        if today >= 500 then
           Fluent:Notify({Title="Gifting", Content="Daily cap reached. Stopping.", Duration=4})
           break
        end
        if not tok.alive then break end
        
        -- [MODIFIED] Find item name by Type and Mutation
        local giftType = Configuration.Players.GiftType
        local itemDisplayName = "UID: " .. tostring(uid) -- Default display

        if giftType == "Pet" then
            local pet = OwnedPetData:FindFirstChild(uid)
            if pet then
                local t = pet:GetAttribute("T") or "Unknown"
                local m = pet:GetAttribute("M") or "None"
                itemDisplayName = ("Pet: %s (%s)"):format(t, m)
            end
        elseif giftType == "Egg" then
            local egg = OwnedEggData:FindFirstChild(uid)
            if egg then
                local t = egg:GetAttribute("T") or "UnknownEgg"
                local m = egg:GetAttribute("M") or "None"
                itemDisplayName = ("Egg: %s (%s)"):format(t, m)
            end
        elseif giftType == "Food" then
            itemDisplayName = "Food: " .. tostring(uid)
        end
        
        -- Update UI to show progress with the new display name
        giftSummaryParagraph:SetTitle( ("Sending item %d of %d..."):format(i, totalToSend) )
        giftSummaryParagraph:SetDesc(itemDisplayName) -- [MODIFIED] Use the new formatted name

        -- Send the item
        CharacterRE:FireServer("Focus", uid); task.wait(0.75)
        GiftRE:FireServer(targetPlayer); task.wait(0.75)
        CharacterRE:FireServer("Focus")
        task.wait(0.5)
        sent = sent + 1
    end
    
    task.wait(1)
    resetGiftUIState()
end
--==============================================================
--          NEW FUNCTION: GATHER ITEMS FOR SELLING PREVIEW (v2)
--==============================================================
local itemsToSellList = {}
local sellSummaryParagraph -- Forward declare for the task runner

local function gatherItemsForSelling()
    local items = {}
    local summary = {}
    local mode = Configuration.Sell.Mode
    
    if mode == "All_Unplaced_Pets" then
        for _, pet in ipairs(OwnedPetData:GetChildren()) do
            if not Pet_Folder:FindFirstChild(pet.Name) then
                table.insert(items, {uid = pet.Name, type = "Pet"})
                local name = ("%s (%s)"):format(pet:GetAttribute("T") or "?", pet:GetAttribute("M") or "None")
                summary[name] = (summary[name] or 0) + 1
            end
        end
    elseif mode == "All_Unplaced_Eggs" then
        for _, egg in ipairs(OwnedEggData:GetChildren()) do
            if not egg:FindFirstChild("DI") then
                table.insert(items, {uid = egg.Name, type = "Egg"})
                local name = ("%s (%s)"):format(egg:GetAttribute("T") or "?", egg:GetAttribute("M") or "None")
                summary[name] = (summary[name] or 0) + 1
            end
        end
    elseif mode == "Filter_Eggs" then
        for _, egg in ipairs(OwnedEggData:GetChildren()) do
            if not egg:FindFirstChild("DI") then
                local t, m = egg:GetAttribute("T") or "BasicEgg", egg:GetAttribute("M") or "None"
                local typeMatch = not next(Configuration.Sell.Egg_Types) or Configuration.Sell.Egg_Types[t]
                local mutaMatch = (not next(Configuration.Sell.Egg_Mutations) and m == "None") or (next(Configuration.Sell.Egg_Mutations) and Configuration.Sell.Egg_Mutations[m])
                if typeMatch and mutaMatch then
                    table.insert(items, {uid = egg.Name, type = "Egg"})
                    local name = ("%s (%s)"):format(t, m)
                    summary[name] = (summary[name] or 0) + 1
                end
            end
        end
    elseif mode == "Pets_Below_Income" then
        local threshold = tonumber(Configuration.Sell.Pet_Income_Threshold) or 0
        for _, pet in ipairs(OwnedPetData:GetChildren()) do
            if not Pet_Folder:FindFirstChild(pet.Name) then
                local income = GetIncomeFast(pet.Name) or 0
                if income < threshold and income > 0 then
                    table.insert(items, {uid = pet.Name, type = "Pet"})
                    local name = ("%s (%s) [Inc: %d]"):format(pet:GetAttribute("T") or "?", pet:GetAttribute("M") or "None", income)
                    summary[name] = (summary[name] or 0) + 1
                end
            end
        end
    end
    
    return items, summary
end

local function runSelling(tok, sellList)
    if not sellList then return end
    local totalToSell = #sellList
    for i, item in ipairs(sellList) do
        -- ถ้ากดหยุด (tok.alive กลายเป็น false) ให้ออกจากลูปทันที
        if not tok.alive then break end
        
        sellSummaryParagraph:SetTitle( ("Selling item %d of %d..."):format(i, totalToSell) )
        if item.type == "Pet" then
            SellPet(item.uid)
        elseif item.type == "Egg" then
            SellEgg(item.uid)
        end
        task.wait(0.2)
    end
    
    -- [FIX] หลังจากลูปจบ, ให้ตรวจสอบว่าจบเพราะทำงานเสร็จ หรือเพราะถูกสั่งให้หยุด
    if tok.alive then
        -- ถ้า tok.alive ยังเป็น true แปลว่าทำงานจนครบ
        sellSummaryParagraph:SetTitle("Sell Complate!")
        sellSummaryParagraph:SetDesc("Press 'Preview Items' to see what will be sold.")
    end
    
    -- ไม่ว่าจะจบแบบไหน ให้ล้างรายการที่จะขายทิ้งเสมอ
    itemsToSellList = {}
end

local function resetSellUIState(title)
    if sellSummaryParagraph then
        sellSummaryParagraph:SetTitle(title or "No items listed")
        sellSummaryParagraph:SetDesc("Press 'Preview Items' to see what will be sold.")
    end
    itemsToSellList = {}
end
--==============================================================
--           TASK RUNNERS: AUTO PLACE EGG FEATURE
--==============================================================
local function runAutoPlaceEgg(tok)
    -- [1] เตรียมข้อมูล & รีเฟรช reference
    EnsureDataRefs()
    Fluent:Notify({ Title = "Auto Place Egg", Content = "Gathering eggs to place...", Duration = 3 })

    -- Helper สำหรับอัปเดตสถานะ (throttle)
    local _last, _lastAt = "", 0
    local function _setEggPlaceStatus(s, force)
        if not eggPlaceParagraph or not eggPlaceParagraph.SetDesc then return end
        local now = os.clock()
        if force or s ~= _last or (now - _lastAt) > 0.2 then
            eggPlaceParagraph:SetDesc(s)
            _last, _lastAt = s, now
        end
    end

    -- รวบรวมไข่ที่ยังไม่ถูกวางทั้งหมด
    local allUnplacedEggs = {}
    if OwnedEggData then
        for _, eggNode in ipairs(OwnedEggData:GetChildren()) do
            if eggNode and not eggNode:FindFirstChild("DI") then
                table.insert(allUnplacedEggs, eggNode.Name)
            end
        end
    end

    local areaSetting = Configuration.Egg.PlaceArea or "Any"  -- "Any" | "Land" | "Water"

    -- ฟังก์ชันตรวจผ่านเงื่อนไขกรอง (ชนิด/มิวเทชัน/พื้นที่)
    local function passFilters(uid)
        local eggNode = OwnedEggData and OwnedEggData:FindFirstChild(uid)
        if not eggNode then return false end
        local t = eggNode:GetAttribute("T") or "BasicEgg"
        local m = eggNode:GetAttribute("M") or "None"
        local okType = (not next(Configuration.Egg.Filters.Types)) or (Configuration.Egg.Filters.Types[t] == true)
        local okMut  = (not next(Configuration.Egg.Filters.Mutations)) or (Configuration.Egg.Filters.Mutations[m] == true)
        if not (okType and okMut) then return false end
        if areaSetting == "Any" then return true end
        return GetEggHabitat(t) == areaSetting
    end

    -- กรองรายการไข่ตาม Filters + Area
    local eggsToPlace = {}
    for _, uid in ipairs(allUnplacedEggs) do
        if passFilters(uid) then table.insert(eggsToPlace, uid) end
    end

    if #eggsToPlace == 0 then
        local msg = "No eggs match the current filters/area."
        _setEggPlaceStatus(msg, true)
        Fluent:Notify({ Title = "Auto Place Egg", Content = msg, Duration = 4 })
        return
    end

    dprint(("[AutoPlaceEgg] Eggs to place: %d"):format(#eggsToPlace))

    -- [2] วนวางไข่ตามลำดับ พร้อมสถิติ/สถานะ
    local stats = { total = #eggsToPlace, placed = 0, failed = 0, noTile = 0 }
    for i = 1, #eggsToPlace do
        if not tok.alive then break end
        EnsureDataRefs()

        local uid = eggsToPlace[i]
        local eggNode = OwnedEggData and OwnedEggData:FindFirstChild(uid)
        if eggNode then
            local t = eggNode:GetAttribute("T") or "BasicEgg"
            local m = eggNode:GetAttribute("M") or "None"
            -- ถ้า Area=Any → เลือกพื้นที่จากถิ่นอาศัยของฟองนั้น, มิฉะนั้นใช้ค่าที่ผู้ใช้กำหนด
            local targetArea = (areaSetting == "Any") and GetEggHabitat(t) or areaSetting

            -- สถิติพื้นที่ (free/total/occupied)
            local pool = (targetArea == "Land" or targetArea == "Water") and SortedPlots[targetArea] or SortedPlots.Any
            local totalTiles = #pool
            local freeList = Grid_FreeList(targetArea)
            local freeCount = #freeList
            local occCount = math.max(0, totalTiles - freeCount)

            local left = stats.total - (i - 1)
            _setEggPlaceStatus(
                string.format(
                    "▶ Placing %d/%d (left %d)\nArea: %s | Free %d / %d (Occ %d)\nEgg: %s - %s",
                    i, stats.total, left, targetArea, freeCount, totalTiles, occCount, t, m
                ),
                true
            )

            if freeCount == 0 then
                stats.noTile = stats.noTile + 1
                Fluent:Notify({
                    Title = "Auto Place Egg",
                    Content = ("No free %s tiles (%d/%d used)."):format(targetArea, occCount, totalTiles),
                    Duration = 3
                })
            else
                -- พยายามวางได้หลายช่องต่อฟอง (สูงสุด 4)
                local placedThis, tries, maxTries = false, 0, math.min(freeCount, 4)
                while tok.alive and tries < maxTries do
                    local node = table.remove(freeList, 1)
                    if not node then break end

                    local dst = Grid_TileCenterPos(node.part)
                    CharacterRE:FireServer("Focus", uid)
                    task.wait(0.25)
                    CharacterRE:FireServer("Place", { DST = dst, ID = uid })

                    local ok = _waitForEggPlacementData(uid, 6) -- ยืนยันสำเร็จจาก Data/Workspace
                    task.wait(0.2)
                    CharacterRE:FireServer("Focus")

                    if ok then
                        placedThis = true
                        break
                    end
                    tries = tries + 1
                    _setEggPlaceStatus(
                        string.format("… Retrying %d/%d | %s - %s", tries + 1, maxTries, t, m)
                    )
                    EnsureDataRefs()
                end

                if placedThis then
                    stats.placed = stats.placed + 1
                    _setEggPlaceStatus(
                        string.format("✅ Placed: %s - %s | Remaining %d", t, m, stats.total - i),
                        true
                    )
                    if not _waitAlive(tok, tonumber(Configuration.Egg.AutoPlaceEgg_Delay) or 1) then break end
                else
                    stats.failed = stats.failed + 1
                    _setEggPlaceStatus(
                        string.format("❌ Failed: %s - %s on %s | Remaining %d", t, m, targetArea, stats.total - i),
                        true
                    )
                end
            end
        end
    end

    -- สรุปผลเมื่อเสร็จ
    local summary = string.format("Placed: %d | Failed: %d | No tile: %d | Total: %d",
                                  stats.placed, stats.failed, stats.noTile, stats.total)
    _setEggPlaceStatus("✅ Completed\n" .. summary, true)
    Fluent:Notify({ Title = "Auto Place Egg — Result", Content = summary, Duration = 6 })
end

--==============================================================
--           TASK RUNNERS: AUTO PLACE PET FEATURE
--==============================================================

--== Helper: Filter inventory pets based on UI settings
local function __filterPetsForPlacing(list, inc_map)
    local mode = Configuration.Pet.Filters.PlaceMode or "All"
    if mode == "All" then return list end

    local out = {}
    for _, uid in ipairs(list) do
        local petNode = OwnedPetData:FindFirstChild(uid)
        if petNode then
            if mode == "Match" then
                local t = petNode:GetAttribute("T")
                local m = petNode:GetAttribute("M") or "None"
                if (not next(Configuration.Pet.Filters.Types) or Configuration.Pet.Filters.Types[t]) and 
                   (not next(Configuration.Pet.Filters.Mutations) or Configuration.Pet.Filters.Mutations[m]) then
                    table.insert(out, uid)
                end
            elseif mode == "Income >=" then
                local inc = inc_map and inc_map[uid] or GetIncomeFast(uid)
                local threshold = tonumber(Configuration.Pet.Filters.IncomeAbove) or 0
                if inc >= threshold then
                    table.insert(out, uid)
                end
            end
        end
    end
    return out
end

--== Helper: Get and sort all placeable pets from inventory
local function __getFilteredInventoryUidsSortedDesc()
    local uids = {}
    for _, node in ipairs(OwnedPetData:GetChildren()) do
        if not Pet_Folder:FindFirstChild(node.Name) then
            table.insert(uids, node.Name)
        end
    end
    if #uids == 0 then return {}, {} end

    local inc_map = {}
    for _, uid in ipairs(uids) do inc_map[uid] = GetIncomeFast(uid) or 0 end

    local filtered_uids = __filterPetsForPlacing(uids, inc_map)
    table.sort(filtered_uids, function(a, b) return (inc_map[a] or 0) > (inc_map[b] or 0) end)
    
    return filtered_uids, inc_map
end

--== Helper: Execute the remote events to place one pet
local function __placeOnePetToPos(uid, worldPos)
    task.wait(0.2)
    CharacterRE:FireServer("Focus", uid)
    task.wait(0.25)
    CharacterRE:FireServer("Place", { DST = worldPos, ID = uid })
    task.wait(1)
    CharacterRE:FireServer("Focus")
    return Pet_Folder:WaitForChild(uid, 3) ~= nil
end

--== Helper: Find the weakest pet currently placed in a specific area
local function __findWorstPlacedPetInArea(areaWant)
    local worstUid, worstInc, worstTileKey, worstTilePart = nil, nil, nil, nil
    for uid, petData in pairs(OwnedPets) do
        if petData and not petData.IsBig and (areaWant == "Any" or petArea(uid) == areaWant) then
            local incPlaced = tonumber(petData.ProduceSpeed) or 0
            local key, part = nil, nil
            if petData.GridCoord then
                key = Grid_keyXZ(petData.GridCoord.X, petData.GridCoord.Z)
            else
                key = Grid_keyXZ(petData.RootPart.Position.X, petData.RootPart.Position.Z)
            end
            local node = PlotIndex[key]
            if node then
                if worstInc == nil or incPlaced < worstInc then
                    worstInc, worstUid, worstTileKey, worstTilePart = incPlaced, uid, key, node.part
                end
            end
        end
    end
    return worstUid, worstInc or 0, worstTileKey, worstTilePart
end

--== Helper: Replace a weak pet with a stronger one
local function __replacePetAtTile(oldUid, newUid, tilePart)
    local Pold = OwnedPets[oldUid]
    if (Pold and Pold.IsBig) or not tilePart then
        return false -- ไม่สามารถแทนที่ได้ (อาจเป็น Big Pet หรือไม่มีพื้นที่)
    end
    
    local destination = Grid_TileCenterPos(tilePart)

    -- สั่งเก็บเงินและลบตัวเก่า
    if Pold and Pold.RE then pcall(function() Pold.RE:FireServer("Claim") end) end
    CharacterRE:FireServer("Del", oldUid)
    task.wait(1.2) -- รอให้เซิร์ฟเวอร์ประมวลผลการลบ

    -- วางตัวใหม่
    CharacterRE:FireServer("Focus", newUid); task.wait(0.5)
    CharacterRE:FireServer("Place", { DST = destination, ID = newUid })
    
    -- << [ส่วนสำคัญ] >>
    -- รอการยืนยันว่าวางตัวใหม่สำเร็จจริงๆ โดยใช้ฟังก์ชันที่เราเพิ่งสร้าง
    local success = _waitForPetPlacementData(newUid, 5)

    task.wait(0.2)
    CharacterRE:FireServer("Focus")

    if success then
        dprint(("[SmartPet] Successfully replaced %s with %s"):format(oldUid, newUid))
    else
        dprint(("[SmartPet] Failed to place new pet %s after removing %s"):format(newUid, oldUid))
    end

    return success -- คืนค่าแค่ true (สำเร็จ) หรือ false (ล้มเหลว)
end

--== Main Runner for Auto Place Pet (SmartPet)
local function runAutoPlacePet(tok)
    _setPetPlaceStatus("Starting...")
    Fluent:Notify({ Title = "Auto Place Pet", Content = "Starting...", Duration = 3 })

    while tok.alive do
        -- STEP 1: Full rescan of inventory and plots
        _setPetPlaceStatus("Scanning inventory & plots...")
        _forceRefreshPetData()
        local uidsToPlace, incMap = __getFilteredInventoryUidsSortedDesc()

        if #uidsToPlace == 0 then
            _setPetPlaceStatus("Stopped: No matching pets in inventory", true)
            pcall(function() Options["Auto Place Pet"]:SetValue(false) end)
            TaskMgr.stop("AutoPlacePet"); return
        end

        local placeAreaSetting = Configuration.Pet.Filters.Area or "Any"

        local freeLandTiles = {}
        if placeAreaSetting == "Any" or placeAreaSetting == "Land" then
            freeLandTiles = Grid_FreeList("Land")
        end

        local freeWaterTiles = {}
        if placeAreaSetting == "Any" or placeAreaSetting == "Water" then
            freeWaterTiles = Grid_FreeList("Water")
        end

        if #freeLandTiles > 0 or #freeWaterTiles > 0 then
            local tempUidsToPlace = table.clone(uidsToPlace)

            for _, uid in ipairs(tempUidsToPlace) do
                if not tok.alive or (#freeLandTiles == 0 and #freeWaterTiles == 0) then break end

                local petHabitat = GetPetHabitat(_petTypeByUID(uid))
                local targetTilePart

                if petHabitat == "Land" and #freeLandTiles > 0 then
                    targetTilePart = table.remove(freeLandTiles, 1).part
                elseif petHabitat == "Water" and #freeWaterTiles > 0 then
                    targetTilePart = table.remove(freeWaterTiles, 1).part
                end

                if targetTilePart then
                    _setPetPlaceStatus(("Placing on empty %s tile..."):format(petHabitat))
                    if __placeOnePetToPos(uid, Grid_TileCenterPos(targetTilePart)) then
                        local idx = table.find(uidsToPlace, uid)
                        if idx then table.remove(uidsToPlace, idx) end
                    end
                    if not _waitAlive(tok, tonumber(Configuration.Pet.AutoPlacePet_Delay) or 1) then break end
                end
            end
            _setPetPlaceStatus("All empty plots filled. Checking for SmartPet...")
            if not _waitAlive(tok, 2.0) then break end
        end
        
        -- STEP 3: SmartPet logic (if enabled)
        if not Configuration.Pet.SmartPet then
            _setPetPlaceStatus("Stopped: No free tiles and SmartPet is off", true)
            pcall(function() Options["Auto Place Pet"]:SetValue(false) end)
            TaskMgr.stop("AutoPlacePet"); return
        end

        local replacementFound = false
        local swapSucceeded = false
        local placeAreaSetting = Configuration.Pet.Filters.Area or "Any"

        -- Function to find and execute a replacement for a given area (Land/Water)
        local function attemptReplacement(area)
            if swapSucceeded then return end -- Don't run if a swap already happened
            local worstUid, worstInc, _, tilePart = __findWorstPlacedPetInArea(area)
            if worstUid then
                local candidateUid, candidateInc, cType
                for _, uid in ipairs(uidsToPlace) do
                    if GetPetHabitat(_petTypeByUID(uid)) == area then
                        local inc = incMap[uid] or GetIncomeFast(uid) or 0
                        if inc > (candidateInc or worstInc) then
                            candidateUid, candidateInc, cType = uid, inc, _petTypeByUID(uid)
                        end
                    end
                end
                if candidateUid then
                    replacementFound = true
                    _setPetPlaceStatus(("Replacing %s: %s (%d/s) <- %s (%d/s)"):format(area:upper(), tostring(cType), candidateInc, tostring(worstUid), worstInc))
                    local ok = __replacePetAtTile(worstUid, candidateUid, tilePart)
                    if ok then 
                        swapSucceeded = true 
                    else
                        replacementFound = true 
                        swapSucceeded = false
                        return 
                    end
                end
            end
        end

        if placeAreaSetting == "Any" or placeAreaSetting == "Land" then attemptReplacement("Land") end
        if placeAreaSetting == "Any" or placeAreaSetting == "Water" then attemptReplacement("Water") end

        -- STEP 4: Decide what to do next
        if swapSucceeded then
                  _setPetPlaceStatus("Successful replace! Re-scanning for next best pet...")
                  -- ปล่อยให้ลูปใหญ่ (while tok.alive) ทำงานต่อเพื่อเริ่มสแกนใหม่ทั้งหมด
            elseif replacementFound and not swapSucceeded then
                  _setPetPlaceStatus("Placement failed! Forcing a full rescan of inventory and plots...")
            Fluent:Notify({ Title = "Auto Place Pet", Content = "Placement failed. Rescanning...", Duration = 4 })
                  -- ไม่ต้องรอ แค่ปล่อยให้ลูปใหญ่ทำงานรอบถัดไป มันจะรีเฟรชเอง
            else -- not replacementFound
                  _setPetPlaceStatus("SmartPet: No better pets found. Stopping.", true)
                  pcall(function() Options["Auto Place Pet"]:SetValue(false) end)
                  TaskMgr.stop("AutoPlacePet"); return
            end
             
            if not _waitAlive(tok, 0.5) then break end
    end
end

--==============================================================
--                       UI DEFINITION
--==============================================================

--== Window Creation
local Window = Fluent:CreateWindow({
    Title = GameName,
    SubTitle = "by DemiGodz",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 414),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

--== Tab Creation
local Home = Window:AddTab({ Title = "🏠 Home"})
local Tabs = {
    Main = Window:AddTab({ Title = "⚡ Main"}),
    Pet = Window:AddTab({ Title = "🐾 Pet"}),
    Egg = Window:AddTab({ Title = "🥚 Egg"}),
    Shop = Window:AddTab({ Title = "🍅 Food"}),
    Players = Window:AddTab({ Title = "🧑‍🤝‍🧑 Players"}),
    Inv = Window:AddTab({ Title = "📦 Inventory"}),
    Settings = Window:AddTab({ Title = "⚙️ Settings"}),
    About = Window:AddTab({ Title = "ℹ️ About"}),
}
Options = Fluent.Options -- Assign global reference

--============================== [TAB] Main ==============================
Tabs.Main:AddSection("Coin Collection")
Tabs.Main:AddToggle("AutoCollect",{ Title="Auto Collect", Default=false, Callback=function(v)
    Configuration.Main.AutoCollect = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoCollect", runAutoCollect) else TaskMgr.stop("AutoCollect") end
end })
Tabs.Main:AddSlider("AutoCollect Delay",{ Title = "Collect Delay (sec)", Default = 3, Min = 3, Max = 180, Rounding = 0, Callback = function(v) Configuration.Main.Collect_Delay = v end })

Tabs.Main:AddSection("Unlocks")
shopParagraph = Tabs.Main:AddParagraph({ Title = "Upgrade Status", Content = "Upgrades: 0 done\nLast: Inactive" })
Tabs.Main:AddToggle("AutoUpgradeConveyor",{ Title="Auto Upgrade Conveyor", Default=false, Callback=function(v)
    Configuration.Main.AutoUpgradeConveyor = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoUpgradeConveyor", runAutoUpgradeConveyor) else TaskMgr.stop("AutoUpgradeConveyor") end
end })

Tabs.Main:AddToggle("AutoUnlockTiles",{ Title = "Auto Unlock Tiles", Default = false, Callback = function(v)
    Configuration.Main.AutoUnlockTiles = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoUnlockTiles", runAutoUnlockTiles) else TaskMgr.stop("AutoUnlockTiles"); setShopStatus("Stopped.") end
end })

Tabs.Main:AddSection("🎣 Fishing")

Tabs.Main:AddDropdown("BaitSelection", {
    Title = "Select Bait",
    Values = {"FishingBait1", "FishingBait2", "FishingBait3"},
    Default = Configuration.Fishing.Bait,
    Callback = function(v)
        Configuration.Fishing.Bait = v
    end
})

Tabs.Main:AddToggle("AutoFishingToggle", {
    Title = "Auto Fishing",
    Default = Configuration.Fishing.Auto,
    Callback = function(v)
        Configuration.Fishing.Auto = v
        if IsLoadingConfig then return end
        
        local character = Player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        
        if v then -- ตอนกดเปิด
            if hrp then
                hrp.Anchored = true -- << แช่แข็งตัวละคร
                dprint("[AutoFishing] Character Anchored.")
            end

            fishingState.lockedPos = getFishingThrowPos()
            dprint("[AutoFishing] Position locked at:", fishingState.lockedPos)
            
            fishingState.didFocus = false
            
            TaskMgr.start("AutoFishing", runAutoFishing)
        else -- ตอนกดปิด
            TaskMgr.stop("AutoFishing")
            
            if hrp then
                hrp.Anchored = false -- << ปลดการแช่แข็งตัวละคร
                dprint("[AutoFishing] Character Unanchored.")
            end
            
            fishingState.lockedPos = nil
            dprint("[AutoFishing] Position unlocked.")
        end
    end
})

Tabs.Main:AddSection("🎟️ Event & Lottery")

-- Find current event name
local eventName = "None"
for _,v in pairs(ReplicatedStorage:GetChildren()) do
    local isEvent = tostring(v):match("^(.*)Event$")
    if isEvent then eventName = isEvent; break end
end
Tabs.Main:AddParagraph({ Title = "Event Information", Content = string.format("Current Event : %s", eventName) })

Tabs.Main:AddToggle("Auto Claim Event Quest",{ Title="Auto Claim Quest", Default=false, Callback=function(v)
    Configuration.Event.AutoClaim = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoClaim", runAutoClaim) else TaskMgr.stop("AutoClaim") end
end })

Tabs.Main:AddToggle("Auto Lottery Ticket",{ Title="Auto Use Lottery Ticket", Default=false, Callback=function(v)
    Configuration.Event.AutoLottery = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoLottery", runAutoLottery) else TaskMgr.stop("AutoLottery") end
end })

--============================== [TAB] Pet ===============================
Tabs.Pet:AddSection("Automation")
Tabs.Pet:AddToggle("Auto Collect Pet",{ Title="Auto Collect Pet", Default=false, Callback=function(v)
    Configuration.Pet.AutoCollectPet = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoCollectPet", runAutoCollectPet) else TaskMgr.stop("AutoCollectPet") end
end })
Tabs.Pet:AddToggle("Auto Place Pet",{ Title="Auto Place Pet", Default=false, Callback=function(v)
    Configuration.Pet.AutoPlacePet = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoPlacePet", runAutoPlacePet) else _setPetPlaceStatus("Inactive", true); TaskMgr.stop("AutoPlacePet") end
end })
Tabs.Pet:AddToggle("SmartPet", { Title = "Enable SmartPet (Replacement)", Default = false, Callback = function(v) Configuration.Pet.SmartPet = v end })
Tabs.Pet:AddSlider("AutoPlacePet Delay", { Title = "Place Delay", Default = 1, Min = 0.1, Max = 5, Rounding = 1, Callback = function(v) Configuration.Pet.AutoPlacePet_Delay = v end })
petPlaceParagraph = Tabs.Pet:AddParagraph({ Title = "Auto Place Status", Content = "Inactive" })


--================== [ UNIFIED FILTER SETTINGS ] ==================
Tabs.Pet:AddSection("PlacePet Settings")

Tabs.Pet:AddDropdown("PlacePet Mode", { Title = "Place Filter Mode", Values = {"All", "Match", "Income >="}, Default = "All", 
    Callback = function(v) Configuration.Pet.Filters.PlaceMode = v end 
})
Tabs.Pet:AddInput("PlacePet_IncomeAbove", { Title = "Place pets with income >=", Default = "0", Numeric = true, Finished = true, 
    Callback = function(v) Configuration.Pet.Filters.IncomeAbove = tonumber(v) or 0 end 
})
Tabs.Pet:AddSection("Collect Pet Settings")

Tabs.Pet:AddDropdown("CollectPet Mode",{ Title = "Collect Filter Mode", Values = {"All", "Match", "Income <="}, Default = "All", 
    Callback = function(v) Configuration.Pet.Filters.CollectMode = v end 
})
Tabs.Pet:AddSection("Filter Settings")
Tabs.Pet:AddDropdown("Filter Area", { Title = "Area", Values = {"Any","Land","Water"}, Default = "Any", 
    Callback = function(v) Configuration.Pet.Filters.Area = v end 
})
Tabs.Pet:AddDropdown("Filter Types", { Title = "Select Types", Values = Pets_InGame, Multi = true, Default = {}, 
    Callback = function(v) Configuration.Pet.Filters.Types = v end 
})
Tabs.Pet:AddDropdown("Filter Mutations", { Title = "Select Mutations", Values = Mutations_With_None, Multi = true, Default = {}, 
    Callback = function(v) Configuration.Pet.Filters.Mutations = v end 
})


Tabs.Pet:AddInput("CollectPet_IncomeBelow",{ Title = "Collect pets with income <=", Default = "0", Numeric = true, Finished = true,
    Callback = function(v) Configuration.Pet.Filters.IncomeBelow = tonumber(v) or 0 end 
})
Tabs.Pet:AddButton({
    Title = "Reset Filters",
    Description = "Resets all filter settings above to their default values.",
    Callback = function()
        -- การเรียก SetValue จะไปกระตุ้น Callback ของแต่ละอันให้ทำงาน และอัปเดตค่าใน Configuration เอง
        Options["PlacePet Mode"]:SetValue("All")
        Options["CollectPet Mode"]:SetValue("All")
        Options["Filter Area"]:SetValue("Any")
        Options["Filter Types"]:SetValue({})
        Options["Filter Mutations"]:SetValue({})
        Options["PlacePet_IncomeAbove"]:SetValue("0")
        Options["CollectPet_IncomeBelow"]:SetValue("0")
        
        Fluent:Notify({ Title = "Filters", Content = "All pet filters have been reset.", Duration = 4 })
    end
})

--============================== [TAB] Egg ==============================

------------------ [ BUY-SPECIFIC SETTINGS ] ------------------
Tabs.Egg:AddSection("Buy Egg")
Tabs.Egg:AddToggle("Auto Buy Egg",{ Title="Auto Buy Egg", Default=false, Callback=function(v)
    Configuration.Egg.AutoBuyEgg = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoBuyEgg", runAutoBuyEgg) else TaskMgr.stop("AutoBuyEgg") end
end })

Tabs.Egg:AddToggle("CheckMinCoin",{ Title = "Only buy if coin is above:", Default = false, Callback = function(v) Configuration.Egg.CheckMinCoin = v end })
Tabs.Egg:AddInput("Min Coin to Buy", { Title = "Min Coin", Default = "0", Numeric = true, Finished = true, Callback = function(v) Configuration.Egg.MinCoin = tonumber(v) or 0 end })
------------------ [ PLACE-SPECIFIC SETTINGS ] ------------------
Tabs.Egg:AddSection("Place Egg")
Tabs.Egg:AddToggle("Auto Place Egg",{ Title="Auto Place Egg", Default=false, Callback=function(v)
    Configuration.Egg.AutoPlaceEgg = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoPlaceEgg", runAutoPlaceEgg) else TaskMgr.stop("AutoPlaceEgg") end
end })
Tabs.Egg:AddDropdown("PlaceEgg Area", { Title = "Area", Values = {"Any","Land","Water"}, Default = "Any", Callback = function(v) Configuration.Egg.PlaceArea = v end })
Tabs.Egg:AddSlider("AutoPlaceEgg Delay",{ Title = "Place Delay", Default = 1.5, Min = 0.1, Max = 5, Rounding = 1, Callback = function(v) Configuration.Egg.AutoPlaceEgg_Delay = v end })

-- แสดงสถานะระหว่างวางไข่
eggPlaceParagraph = Tabs.Egg:AddParagraph({
    Title = "Auto Place Egg — Status",
    Content = "Inactive"
})

------------------ [ HATCH-SPECIFIC SETTINGS ] ------------------
Tabs.Egg:AddSection("Hatch Egg")
Tabs.Egg:AddToggle("Auto Hatch",{ Title="Auto Hatch", Default=false, Callback=function(v)
    Configuration.Egg.AutoHatch = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoHatch", runAutoHatch) else TaskMgr.stop("AutoHatch") end
end })
Tabs.Egg:AddDropdown("Hatch Area",{ Title = "Area", Values = {"Any","Land","Water"}, Default = "Any", Callback = function(v) Configuration.Egg.HatchArea = v end })
Tabs.Egg:AddSlider("AutoHatch Delay",{ Title = "Hatch Delay", Default = 15, Min = 15, Max = 60, Rounding = 0, Callback = function(v) Configuration.Egg.Hatch_Delay = v end })
------------------ [ SHARED FILTERS ] ------------------
Tabs.Egg:AddSection("Egg Filters")
Tabs.Egg:AddDropdown("Egg Filter Types", { 
    Title = "Types (for Buy & Place)",
    Values = Eggs_InGame,
    Multi = true,
    Default = {},
    Callback = function(v) Configuration.Egg.Filters.Types = v end 
})
Tabs.Egg:AddDropdown("Egg Filter Mutations", { 
    Title = "Mutations (for Buy & Place)",
    Values = Mutations_With_None, -- Assumes Mutations_With_None table from previous request exists
    Multi = true,
    Default = {},
    Callback = function(v) Configuration.Egg.Filters.Mutations = v end 
})
Tabs.Egg:AddButton({ Title = "Reset Egg Filters", Callback = function()
    Options["Egg Filter Types"]:SetValue({})
    Options["Egg Filter Mutations"]:SetValue({})
    Fluent:Notify({ Title="Filters", Content="Egg filters have been reset.", Duration=3 })
end})


--============================== [TAB] Food ==============================
Tabs.Shop:AddSection("Buy")
Tabs.Shop:AddDropdown("Foods Dropdown",{ Title = "Foods to Buy", Values = PetFoods_InGame, Multi = true, Default = {}, Callback = function(v) Configuration.Shop.Food.Foods = v end })
Tabs.Shop:AddToggle("Auto BuyFood",{ Title="Auto Buy Food", Default=false, Callback=function(v)
    Configuration.Shop.Food.AutoBuy = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoBuyFood", runAutoBuyFood) else TaskMgr.stop("AutoBuyFood") end
end })
Tabs.Shop:AddSection("Big Pet Feed")
Tabs.Shop:AddToggle("Auto Feed",{ Title="Auto Feed", Default=false, Callback=function(v)
    Configuration.Pet.AutoFeed = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AutoFeed", runAutoFeed) else TaskMgr.stop("AutoFeed") end
end })

Tabs.Shop:AddToggle("SmartFeed",{ Title="Smart Feed", Content = "Auto Unlock Pet&Mutations", Default=false, Callback=function(v)
    Configuration.Pet.SmartFeed = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("SmartFeed", runSmartFeed) else TaskMgr.stop("SmartFeed") end
end })
Tabs.Shop:AddDropdown("SmartFeed Blacklist", { 
    Title = "SmartFeed Blacklist", 
    Description = "Select foods for SmartFeed to ignore, even if needed for unlocks.",
    Values = PetFoods_InGame, 
    Multi = true, 
    Default = {}, 
    Callback = function(v) 
        Configuration.Pet.SmartFeed_Blacklist = v 
    end 
})
Tabs.Shop:AddSlider("SmartFeed Delay",{ Title = "SmartFeed Delay", Default = 15, Min = 15, Max = 300, Rounding = 0, Callback = function(v) Configuration.Pet.SmartFeed_Delay = v end })
Tabs.Shop:AddSection("Auto Feed Settings")
bigPetSlot1_Label = Tabs.Shop:AddParagraph({ Title = "Slot 1:", Content = "No Big Pet Detected" })
Tabs.Shop:AddDropdown("BigPetSlot1_Foods", { Title = "Food for Slot 1", Values = PetFoods_InGame, Multi = true, Default = {}, Callback = function(s) Configuration.Pet.BigPetSlots[1] = _cloneFoodMap(s); SaveManager:Save() end })
bigPetSlot2_Label = Tabs.Shop:AddParagraph({ Title = "Slot 2:", Content = "No Big Pet Detected" })
Tabs.Shop:AddDropdown("BigPetSlot2_Foods", { Title = "Food for Slot 2", Values = PetFoods_InGame, Multi = true, Default = {}, Callback = function(s) Configuration.Pet.BigPetSlots[2] = _cloneFoodMap(s); SaveManager:Save() end })
bigPetSlot3_Label = Tabs.Shop:AddParagraph({ Title = "Slot 3:", Content = "No Big Pet Detected" })
Tabs.Shop:AddDropdown("BigPetSlot3_Foods", { Title = "Food for Slot 3", Values = PetFoods_InGame, Multi = true, Default = {}, Callback = function(s) Configuration.Pet.BigPetSlots[3] = _cloneFoodMap(s); SaveManager:Save() end })

--============================== [TAB] Players ===========================
Tabs.Players:AddSection("📦 Gifting")
local dailyGiftParagraph = Tabs.Players:AddParagraph({
    Title   = "🎁 Today Gifts: loading...",
    Content = "The daily limit is 500 gifts per day."
})

local function refreshDailyGiftUI()
    local n    = getTodayGiftCount()
    local maxv = 500
    local note = (n >= maxv and " (limit reached)")
             or  (n >= maxv - 50 and " (almost at limit)")
             or  ""
    dailyGiftParagraph:SetTitle( string.format("🎁 Today Gifts: %d / %d%s", n, maxv, note) )
    dailyGiftParagraph:SetDesc( "The daily limit is 500 gifts per day. Gifting will stop at the cap." )
end

-- อัปเดตรอบแรก
refreshDailyGiftUI()

-- ผูกสัญญาณเมื่อค่าเปลี่ยนใน UserFlag
do
    local pg   = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    local UF   = Data and Data:FindFirstChild("UserFlag")
    if UF then
        table.insert(EnvirontmentConnections,
            UF:GetAttributeChangedSignal("TodaySendGiftCount"):Connect(refreshDailyGiftUI)
        )
    end
end

local currentGiftingList = {} -- State variable to hold the list of UIDs to send

-- 2. สร้าง UI Elements (ไม่ต้องเก็บตัวแปรปุ่ม เพื่อลดจำนวน local)
Tabs.Players:AddButton({ Title = "1. Preview Items to Send", Description = "Displays a list of items to be sent based on filters",
    Callback = function()
        -- [MODIFIED] gatherItemsForGifting now returns the raw list of UIDs too
        local sortedSummary, totalItems, targetName, rawUIDList = gatherItemsForGifting()
        
        if not sortedSummary then 
            giftSummaryParagraph:SetTitle("No items match the filters")
            giftSummaryParagraph:SetDesc("Please check your filter settings and try again.")
            currentGiftingList = {} -- Clear the list
            return 
        end

        currentGiftingList = rawUIDList -- [MODIFIED] Save the raw list for sending
        
        -- Build and display the summary directly here
        local summaryLines = {}
        for _, item in ipairs(sortedSummary) do
            table.insert(summaryLines, ("- %s x %d"):format(item.name, item.count))
        end
        giftSummaryParagraph:SetTitle(("Items to send to %s (%d total):"):format(targetName, totalItems))
        giftSummaryParagraph:SetDesc(table.concat(summaryLines, "\n"))
    end
})

giftSummaryParagraph = Tabs.Players:AddParagraph({ Title = "No items listed", Content = "Press 'Preview Items' to see what will be sent." })
Tabs.Players:AddButton({ Title = "2. Confirm and Start Sending",
    Callback = function()
        if #currentGiftingList == 0 then
            Fluent:Notify({Title="Gifting", Content="Please preview items before sending.", Duration=4})
            return
        end
        giftSummaryParagraph:SetTitle("Sending in progress...")
        giftSummaryParagraph:SetDesc("Press 'Cancel / Stop' to abort.")
        
        -- [MODIFIED] Pass currentGiftingList directly to the task
        TaskMgr.start("Gifting", runGifting, currentGiftingList) 
    end
})

Tabs.Players:AddButton({ Title = "3. Cancel / Stop Gifting",
    Callback = function()
        TaskMgr.stop("Gifting")
        currentGiftingList = {} -- Clear the list
        
        giftSummaryParagraph:SetTitle("No items listed")
        giftSummaryParagraph:SetDesc("Press 'Preview Items' to see what will be sent.")
    end
})



local Players_Dropdown = Tabs.Players:AddDropdown("Players Dropdown",{ Title = "Select Player", Values = Players_InGame, Multi = false, Default = "", Callback = function(v) Configuration.Players.SelectPlayer = v end })
table.insert(EnvirontmentConnections, Players_List_Updated.Event:Connect(function(newList) Players_Dropdown:SetValues(newList) end))

Tabs.Players:AddInput("Gift Count Limit", { Title = "Amount to send (blank=all)", Default = "", Numeric = true, Finished = true, Callback = function(v) Configuration.Players.GiftLimit = v end })

Tabs.Players:AddDropdown("GiftType Dropdown",{ 
    Title = "Gift Type", 
    Values = {"Pet", "Egg", "Food"}, 
    Default = "Pet", 
    Callback = function(v) 
        Configuration.Players.GiftType = v
    end 
})

-- Pet Filters Section
local petFilterSection = Tabs.Players:AddSection("🐾 Gift Pet Filters")
petFilterSection:AddDropdown("PetFilterMode", { Title = "Mode", Values = {"All", "Match", "Range"}, Default = "All", Callback = function(v) Configuration.Players.PetFilters.Mode = v end })
petFilterSection:AddDropdown("PetFilterTypes", { Title = "Select Pet Types", Values = Pets_InGame, Multi = true, Default = {}, Callback = function(v) Configuration.Players.PetFilters.Types = v end }) -- << แก้ไขแล้ว
petFilterSection:AddDropdown("PetFilterMutations",{ Title = "Select Mutations", Values = Mutations_With_None, Multi = true, Default = {}, Callback = function(v) Configuration.Players.PetFilters.Mutations = v end })
petFilterSection:AddInput("PetFilterMinIncome", { Title = "Min income/s (for Range)", Default = "0", Numeric = true, Finished = true, Callback = function(v) Configuration.Players.PetFilters.MinIncome = tonumber(v) or 0 end })
petFilterSection:AddInput("PetFilterMaxIncome", { Title = "Max income/s (for Range)", Default = "1000000", Numeric = true, Finished = true, Callback = function(v) Configuration.Players.PetFilters.MaxIncome = tonumber(v) or 1000000 end })

-- Egg Filters Section
local eggFilterSection = Tabs.Players:AddSection("🥚 Gift Egg Filters")
eggFilterSection:AddDropdown("EggFilterMode", { Title = "Mode", Values = {"All", "Match"}, Default = "All", Callback = function(v) Configuration.Players.EggFilters.Mode = v end })
eggFilterSection:AddDropdown("EggFilterTypes", { Title = "Egg Types", Values = Eggs_InGame, Multi = true, Default = {}, Callback = function(v) Configuration.Players.EggFilters.Types = v end }) -- << แก้ไขแล้ว
eggFilterSection:AddDropdown("EggFilterMutations", { Title = "Egg Mutations", Values = Mutations_With_None, Multi = true, Default = {}, Callback = function(v) Configuration.Players.EggFilters.Mutations = v end })

-- Food Filters Section
local foodFilterSection = Tabs.Players:AddSection("🍅 Gift Food Filters")
foodFilterSection:AddDropdown("FoodFilterMode", { Title = "Mode", Values = {"All", "Select"}, Default = "All", Callback = function(v) Configuration.Players.FoodFilters.Mode = v end })
foodFilterSection:AddDropdown("FoodFilterSelected", { Title = "Foods (for Select)", Values = PetFoods_InGame, Multi = true, Default = {}, Callback = function(v) Configuration.Players.FoodFilters.Selected = v end }) -- << แก้ไขแล้ว

-- ปุ่ม Reset และ Send Gift
Tabs.Players:AddButton({ Title = "Reset All Gift Filters", Description = "Resets all pet, egg, and food filters.", Callback = function()
    -- Reset Pet Filters
    Options["Gift Count Limit"]:SetValue("")
    Options["PetFilterMode"]:SetValue("All")
    Options["PetFilterTypes"]:SetValue({})
    Options["PetFilterMutations"]:SetValue({})
    Options["PetFilterMinIncome"]:SetValue("0")
    Options["PetFilterMaxIncome"]:SetValue("1000000")
    -- Reset Egg Filters
    Options["EggFilterMode"]:SetValue("All")
    Options["EggFilterTypes"]:SetValue({})
    Options["EggFilterMutations"]:SetValue({})
    -- Reset Food Filters
    Options["FoodFilterMode"]:SetValue("All")
    Options["FoodFilterSelected"]:SetValue({})
    Fluent:Notify({Title="Filters", Content="All gift filters have been reset.", Duration=3})
end})


--============================== [TAB] Inventory =========================
local MUTA_EMOJI = { ["None"]="🥚", ["Fire"]="🔥", ["Electirc"]="⚡", ["Diamond"]="💎", ["Golden"]="✨", ["Dino"]="🦖",["Snow"]="❄️" }
local MUTA_ORDER = { "None","Fire","Electirc","Diamond","Golden","Dino","Snow" }
local ORDER_SET = {}; for _,k in ipairs(MUTA_ORDER) do ORDER_SET[k]=true end

Tabs.Inv:AddParagraph({ Title = "Unplaced Eggs", Content = "View all eggs currently in your inventory." })
local ResultPara = Tabs.Inv:AddParagraph({ Title = "Summary", Content = "Press Refresh to get the latest data..." })
local function renderSummary()
    -- ... (the original renderSummary function remains unchanged)
    local map = {}
    for _, egg in ipairs(OwnedEggData:GetChildren()) do
        if not egg:FindFirstChild("DI") then
            local t, m = egg:GetAttribute("T") or "BasicEgg", egg:GetAttribute("M") or "None"
            map[t] = map[t] or {}; map[t][m] = (map[t][m] or 0) + 1
        end
    end
    local lines, shown = {}, {}
    local function addLineFor(typeName, mutaCounts)
        table.insert(lines, "\n• " .. tostring(typeName))
        for _, key in ipairs(MUTA_ORDER) do
            if (mutaCounts[key] or 0) > 0 then table.insert(lines, ("   - %s %s: %d"):format(MUTA_EMOJI[key] or "🔹", key, mutaCounts[key])) end
        end
        for m, n in pairs(mutaCounts) do
            if not ORDER_SET[m] and (n or 0) > 0 then table.insert(lines, ("   - %s %s: %d"):format(MUTA_EMOJI[m] or "🔹", m, n)) end
        end
    end
    for _, t in ipairs(Eggs_InGame) do if map[t] then addLineFor(t, map[t]); shown[t]=true end end
    for t, counts in pairs(map) do if not shown[t] then addLineFor(t, counts) end end
    return #lines > 0 and table.concat(lines, "\n") or "No unplaced eggs in inventory."
end

Tabs.Inv:AddButton({ Title = "Refresh", Description = "Refresh the list of unplaced eggs", Callback = function()
    ResultPara:SetDesc(renderSummary())
    Fluent:Notify({ Title = "Inventory", Content = "List updated.", Duration = 4 })
end })

Tabs.Inv:AddSection("Discord Sync (Egg Inventory)")

Tabs.Inv:AddInput("DiscordWebhookURL", {
    Title = "Discord Webhook URL",
    Default = Configuration.DiscordSync.WebhookURL,
    Placeholder = "วาง URL ของคุณที่นี่",
    Finished = true,
    Callback = function(v)
        Configuration.DiscordSync.WebhookURL = v
    end
})

Tabs.Inv:AddSlider("DiscordSyncInterval", {
    Title = "ส่งข้อมูลทุกๆ (นาที)",
    Default = Configuration.DiscordSync.Interval,
    Min = 1,
    Max = 180, -- 3 ชั่วโมง
    Rounding = 0,
    Callback = function(v)
        Configuration.DiscordSync.Interval = v
    end
})

Tabs.Inv:AddToggle("DiscordSyncToggle", {
    Title = "เปิดใช้งานการส่งข้อมูลอัตโนมัติ",
    Default = Configuration.DiscordSync.Enabled,
    Callback = function(v)
        Configuration.DiscordSync.Enabled = v
        if IsLoadingConfig then return end
        if v then
            TaskMgr.start("AutoSyncToDiscord", runAutoSyncToDiscord)
        else
            TaskMgr.stop("AutoSyncToDiscord")
        end
    end
})


Tabs.Inv:AddSection("Sell Items from Inventory")

-- [NEW] Declare UI variables for the Sell feature
Tabs.Inv:AddButton({ Title = "1. Preview Items to Sell",
    Callback = function()
        local items, summary = gatherItemsForSelling()
        if #items == 0 then
            Fluent:Notify({Title="Sell", Content="No items were found matching the criteria.", Duration=4})
            sellSummaryParagraph:SetTitle("No items to sell")
            sellSummaryParagraph:SetDesc("Please check your filter settings and try again.")
            itemsToSellList = {} -- Clear list
            return
        end
        
        itemsToSellList = items -- Save the list for the sell button
        
        local summaryLines = {}
        for name, count in pairs(summary) do
            table.insert(summaryLines, ("- %s x %d"):format(name, count))
        end
        
        sellSummaryParagraph:SetTitle(("About to sell %d items:"):format(#items))
        sellSummaryParagraph:SetDesc(table.concat(summaryLines, "\n"))
    end
})

sellSummaryParagraph = Tabs.Inv:AddParagraph({ Title = "No items listed", Content = "Press 'Preview Items' to see what will be sold." })

Tabs.Inv:AddButton({ Title = "2. Confirm and Start Selling",
    Callback = function()
        if #itemsToSellList == 0 then
            Fluent:Notify({Title="Sell", Content="No items to sell. Please press Preview first.", Duration=4})
            return
        end
        TaskMgr.start("Selling", runSelling, itemsToSellList)
    end
})

Tabs.Inv:AddButton({ Title = "3. Cancel / Stop Selling",
    Callback = function()
        TaskMgr.stop("Selling") -- สั่งให้ Task หยุดทำงาน
        sellSummaryParagraph:SetTitle("Sale Cancelled")
        sellSummaryParagraph:SetDesc("Press 'Preview Items' to see what will be sent.")
        itemsToSellList = {}
    end
})
Tabs.Inv:AddDropdown("Sell Mode", { Title = "Sell Mode", Values = { "All_Unplaced_Pets", "All_Unplaced_Eggs", "Filter_Eggs", "Pets_Below_Income" }, Default = "", Callback = function(v) Configuration.Sell.Mode = v end })
Tabs.Inv:AddDropdown("Sell Egg Types", { Title = "Egg Types (for Filter_Eggs)", Values = Eggs_InGame, Multi  = true, Default = {}, Callback = function(v) Configuration.Sell.Egg_Types = v end })
Tabs.Inv:AddDropdown("Sell Egg Mutations", { Title = "Egg Mutations (for Filter_Eggs)", Values = Mutations_With_None, Multi  = true, Default = {}, Callback = function(v) Configuration.Sell.Egg_Mutations = v end })
Tabs.Inv:AddInput("Pet Income Threshold", { Title = "Sell pets with income below:", Default = "0", Numeric = true, Finished = true, Callback = function(v) Configuration.Sell.Pet_Income_Threshold = tonumber(v) or 0 end })
--============================== [TAB] Settings & About =================
Tabs.Settings:AddSection("General")
Tabs.Settings:AddToggle("AntiAFK",{ Title="Anti AFK", Default=false, Callback=function(v)
    ServerReplicatedDict:SetAttribute("AFK_THRESHOLD", v and 9e9 or 1080)
    Configuration.AntiAFK = v
    if IsLoadingConfig then return end
    if v then TaskMgr.start("AntiAFK", runAntiAFK) else TaskMgr.stop("AntiAFK") end
end })

Tabs.Settings:AddSection("Performance")
Tabs.Settings:AddToggle("FPS_Lock", { Title = "Lock FPS", Default = false, Callback = function(v)
    Configuration.Perf.FPSLock = v
    if IsLoadingConfig then return end
    ApplyFPSLock()
    if v then TaskMgr.start("EnforceFPSLock", runEnforceFPSLock) else TaskMgr.stop("EnforceFPSLock") end
end })
Tabs.Settings:AddInput("FPS_Value", { Title = "FPS Cap", Default = "60", Numeric = true, Finished = true, Callback = function(v)
    Configuration.Perf.FPSValue = tonumber(v) or 60; if Configuration.Perf.FPSLock then ApplyFPSLock() end
end })
Tabs.Settings:AddToggle("Hide Pets", { Title = "Hide Pets", Default = false, Callback = function(v) Configuration.Perf.HidePets = v; ApplyHidePets(v) end })
Tabs.Settings:AddToggle("Hide Eggs", { Title = "Hide Eggs", Default = false, Callback = function(v) Configuration.Perf.HideEggs = v; ApplyHideEggs(v) end })
Tabs.Settings:AddToggle("Hide Effects", { Title = "Hide Effects", Default = false, Callback = function(v) Configuration.Perf.HideEffects = v; ApplyHideEffects(v) end })
Tabs.Settings:AddToggle("Hide Game UI", { Title = "Hide Other UI", Default = false, Callback = function(v) Configuration.Perf.HideGameUI = v; ApplyHideGameUI(v) end })
Tabs.Settings:AddToggle("Disable3DOnly", { Title = "Disable 3D Rendering", Default = false, Callback = function(v) Configuration.Perf.Disable3D = v; Perf_Set3DEnabled(not v) end })

Tabs.Settings:AddSection("Debug")
Tabs.Settings:AddToggle("DebugOn", { Title = "Enable Debug Log", Default = true, Callback = function(v) getgenv().MEOWY_DBG.on = v end })
Tabs.Settings:AddToggle("DebugToast", { Title = "Show Debug as Toast", Default = false, Callback = function(v) getgenv().MEOWY_DBG.toast = v end })

Tabs.About:AddParagraph({ Title = "Credit", Content = "Script created by DemiGodz" })
--==============================================================
--               HOME TAB UI & UX SETUP
--==============================================================

local StatusPara = Home:AddParagraph({ Title = "Status", Content = "Reading status..." })
-- ลดจำนวน local บน top-level เพื่อลดโอกาสชนลิมิต 200 registers ของ Luau
Window.RefreshStatus = function()
  local function mark(name) return TaskMgr.isRunning(name) and "🟢" or "⚪" end
  local function markAny(a, b) return ((TaskMgr.isRunning(a) or TaskMgr.isRunning(b)) and "🟢") or "⚪" end
  local lines = {
    string.format("%s Auto Collect", mark("AutoCollect")),
    string.format("%s Auto Upgrade / Unlock", markAny("AutoUpgradeConveyor","AutoUnlockTiles")),
    string.format("%s Auto Feed", markAny("AutoFeed","SmartFeed")),
    string.format("%s Auto Place Pet", mark("AutoPlacePet")),
    string.format("%s Auto Collect Pet", mark("AutoCollectPet")),
    string.format("%s Auto Hatch", mark("AutoHatch")),
    string.format("%s Auto Buy Egg", mark("AutoBuyEgg")),
    string.format("%s Auto Buy Food", mark("AutoBuyFood")),
    string.format("%s Auto Claim", mark("AutoClaim")),
    string.format("%s AntiAFK", mark("AntiAFK")),
  }
  StatusPara:SetDesc(table.concat(lines, "\n"))
end

Home:AddSection("Quick Actions")
Home:AddButton({ Title = "Start Auto Collect", Description = "Instantly enables the auto collect feature.", Callback = function()
    Options["AutoCollect"]:SetValue(true)
    Fluent:Notify({ Title = "Quick Action", Content = "Auto Collect started.", Duration = 3 })
end })

Home:AddButton({ Title = "Stop All Tasks", Description = "Stops all running automations in one click.", Callback = function()
    TaskMgr.stopAll()
    -- This is a generic way to try and turn off all toggles
    for key, option in pairs(Options) do
        if option.Type == "Toggle" then pcall(function() option:SetValue(false) end) end
    end
    Window.RefreshStatus()
    Fluent:Notify({ Title = "Quick Action", Content = "All tasks have been stopped.", Duration = 3 })
end })

Home:AddSection("Performance Presets")
Home:AddButton({ Title = "AFK Mode", Description = "Hides models/effects, disables 3D, and locks FPS for best performance.", Callback = function()
    Options["Hide Pets"]:SetValue(true)
    Options["Hide Eggs"]:SetValue(true)
    Options["Hide Effects"]:SetValue(true)
    Options["Disable3DOnly"]:SetValue(true)
    Options["FPS_Lock"]:SetValue(true)
    Options["FPS_Value"]:SetValue(5)
    Fluent:Notify({ Title = "Preset", Content = "AFK Mode enabled.", Duration = 4 })
end })

Home:AddButton({ Title = "Visual Mode", Description = "Enables 3D, shows everything, and unlocks FPS.", Callback = function()
    Options["Hide Pets"]:SetValue(false)
    Options["Hide Eggs"]:SetValue(false)
    Options["Hide Effects"]:SetValue(false)
    Options["Disable3DOnly"]:SetValue(false)
    Options["FPS_Lock"]:SetValue(false)
    Fluent:Notify({ Title = "Preset", Content = "Visual Mode enabled.", Duration = 4 })
end })

--==============================================================
--              INITIALIZATION & FINAL SETUP
--==============================================================

--== Save Manager Setup
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/"..game.PlaceId)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

getgenv().MeowyBuildAZoo = Window -- Global reference for potential re-runs

--== Final Event Connections
table.insert(EnvirontmentConnections, Pet_Folder.ChildAdded:Connect(function(pet)
    task.defer(function()
        if not _isOwnedPetModel(pet) then return end
        _addMyPet(pet)
        _buildOwnedPetEntry(pet, tostring(pet))
        handlePossibleBigPetChange_OnAdd(pet) 
    end)
end))

table.insert(EnvirontmentConnections, Pet_Folder.ChildRemoved:Connect(function(pet)
    task.defer(function()
        if not MyPets[pet] then return end -- Check if it was one of ours
        local petUID = tostring(pet)
        local wasBigPet = MyBigPets[petUID] ~= nil 
        _removeMyPet(pet)
        if wasBigPet then
            onBigPetListChanged()
        end
    end)
end))

--== Auto-Start function (called after config is loaded)
local function _autostart()
    -- Apply Performance Settings First
    if Configuration.Perf.FPSLock then ApplyFPSLock(); TaskMgr.start("EnforceFPSLock", runEnforceFPSLock) end
    if Configuration.Perf.HidePets then ApplyHidePets(true) end
    if Configuration.Perf.HideEggs then ApplyHideEggs(true) end
    if Configuration.Perf.HideEffects then ApplyHideEffects(true) end
    if Configuration.Perf.HideGameUI then ApplyHideGameUI(true) end
    if Configuration.Perf.Disable3D then Perf_Set3DEnabled(false) end

    -- Start Auto Tasks based on loaded config
    if Configuration.AntiAFK then TaskMgr.start("AntiAFK", runAntiAFK) end
    if Configuration.Main.AutoCollect then TaskMgr.start("AutoCollect", runAutoCollect) end
    if Configuration.Main.AutoUpgradeConveyor then TaskMgr.start("AutoUpgradeConveyor", runAutoUpgradeConveyor) end
    if Configuration.Main.AutoUnlockTiles then TaskMgr.start("AutoUnlockTiles", runAutoUnlockTiles) end
    if Configuration.Pet.AutoFeed then TaskMgr.start("AutoFeed", runAutoFeed) end
    if Configuration.Pet.SmartFeed then TaskMgr.start("SmartFeed", runSmartFeed) end
    if Configuration.Pet.CollectPet_Auto then TaskMgr.start("AutoCollectPet", runAutoCollectPet) end
    if Configuration.Pet.AutoPlacePet then TaskMgr.start("AutoPlacePet", runAutoPlacePet) end
    if Configuration.Egg.AutoHatch then TaskMgr.start("AutoHatch", runAutoHatch) end
    if Configuration.Egg.AutoBuyEgg then TaskMgr.start("AutoBuyEgg", runAutoBuyEgg) end
    if Configuration.Egg.AutoPlaceEgg then TaskMgr.start("AutoPlaceEgg", runAutoPlaceEgg) end
    if Configuration.Shop.Food.AutoBuy then TaskMgr.start("AutoBuyFood", runAutoBuyFood) end
    if Configuration.Event.AutoClaim then TaskMgr.start("AutoClaim", runAutoClaim) end
    if Configuration.Event.AutoLottery then TaskMgr.start("AutoLottery", runAutoLottery) end
    if Configuration.DiscordSync.Enabled then TaskMgr.start("AutoSyncToDiscord", runAutoSyncToDiscord) end
end

--== Main Execution Flow
task.spawn(function()
      Fluent:Notify({ Title = "Fluent", Content = "Script Loaded! Initializing...", Duration = 4 })
      task.wait(4) 

      IsLoadingConfig = true
      Fluent:Notify({ Title = "System", Content = "Loading saved settings...", Duration = 3 })
      SaveManager:LoadAutoloadConfig()

      updateBigPetSlots()
      task.defer(function() ResultPara:SetDesc(renderSummary()) end)
      IsLoadingConfig = false
      Fluent:Notify({ Title = "System", Content = "Starting enabled tasks...", Duration = 3 })
      _autostart()
        task.spawn(function()
            while RunningEnvirontments do
                Window.RefreshStatus()
                task.wait(4)
            end
        end)
end)

Window:SelectTab(Home) -- Open to the Home tab by default

--==============================================================
--                        CLEANUP
--==============================================================
Window.Root.Destroying:Once(function()
    RunningEnvirontments = false
    TaskMgr.stopAll()
    
    -- Revert all performance changes
    ApplyHidePets(false)
    ApplyHideEggs(false)
    ApplyHideEffects(false)
    ApplyHideGameUI(false)
    Perf_Set3DEnabled(true)

    pcall(function()
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.Anchored = false
            print("Failsafe: Character Unanchored.")
        end
    end)

    -- Unlock FPS if it wasn't locked by another script
    if _setFPSCap and not (getgenv().MEOWY_FPS and getgenv().MEOWY_FPS.locked) then
        _setFPSCap(1000)
    end
    
    -- Disconnect all events
    for _, connection in pairs(EnvirontmentConnections) do
        if connection then pcall(function() connection:Disconnect() end) end
    end

    print("Script cleaned up successfully.")
end)
