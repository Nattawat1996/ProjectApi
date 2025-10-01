-- momhelp.lua (Latest, with ACK/Receipt & Slim/Full snapshots)

print("กำลังโหลด Library...")
local HttpService = game:GetService("HttpService")
local json = loadstring(game:HttpGet("https://raw.githubusercontent.com/rxi/json.lua/master/json.lua"))()
if not json then print("!!! ERROR: ไม่สามารถโหลด JSON Library ได้ !!!"); return end

local _request = (syn and syn.request) or (http and http.request) or request
if not _request then print("!!! ERROR: ไม่พบฟังก์ชัน request ที่รองรับ !!!"); return end
print("โหลด Library สำเร็จ!")

-- =======================
-- 1) CONFIG
-- =======================
local config = {
    serverUrl      = "https://opportunity-fallen-everyone-content.trycloudflare.com", -- แก้เป็น URL ของคุณ
    updateInterval = 2,       -- วินาที: รอบส่ง Slim
    fullInterval   = 20,      -- วินาที: ส่ง Full ตามรอบ (ลดโหลด)
    ackTimeout     = 3.0,     -- วินาที: รอผลแต่ละชิ้น
}


-- =======================
-- 2) GAME REFERENCES
-- =======================
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockFolder = workspace:WaitForChild("PlayerBuiltBlocks")
local PetsFolder  = workspace:WaitForChild("Pets")

local GameRemoteEvents = ReplicatedStorage:WaitForChild("Remote", 30)
local InGameConfig     = ReplicatedStorage:WaitForChild("Config")

local PetFoods_InGame  = require(InGameConfig:WaitForChild("ResPetFood"))["__index"]
local Eggs_InGame      = require(InGameConfig:WaitForChild("ResEgg"))["__index"]
local Mutations_InGame = require(InGameConfig:WaitForChild("ResMutate"))["__index"]

local GiftRE       = GameRemoteEvents:WaitForChild("GiftRE", 30)
local CharacterRE  = GameRemoteEvents:WaitForChild("CharacterRE", 30)

-- Mutation list with "None"
local Mutations_With_None = {"None"}
for _, m in ipairs(Mutations_InGame) do table.insert(Mutations_With_None, m) end

local getServerTimeObj

-- =======================
-- 3) HELPERS
-- =======================
local function safeGetAttribute(inst, name, default)
    if not inst then return default end
    local ok, v = pcall(function() return inst:GetAttribute(name) end)
    if ok and v ~= nil then return v end
    return default
end

local function nowSec() return os.time() end

local function TeleportToPlayer(targetPlayer)
    if not targetPlayer or not Player then return false, "Invalid player" end
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
    print(("[Teleport] วาร์ปไปที่ %s สำเร็จ"):format(targetPlayer.Name))
    return true, "Success"
end

-- ===== User/Gift helpers =====
local function getTodayGiftCount()
    local pg = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    if not Data then return 0 end
    local userFlag = Data:FindFirstChild("UserFlag")
    if not userFlag then return 0 end
    local v = safeGetAttribute(userFlag, "TodaySendGiftCount", 0)
    return tonumber(v) or 0
end

local function getFoodQty(name)
    local pg = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    local Asset = Data and Data:FindFirstChild("Asset")
    if not Asset then return 0 end
    local all = Asset:GetAttributes()
    return tonumber(all[name]) or 0
end

local function getTotalFarmIncomePerSecond()
    local total = 0
    for _, petModel in ipairs(PetsFolder:GetChildren()) do
        if petModel:GetAttribute("UserId") == Player.UserId then
            local root = petModel.PrimaryPart or petModel:FindFirstChild("RootPart")
            if root then
                local produceSpeed = root:GetAttribute("ProduceSpeed")
                if type(produceSpeed) ~= "number" then
                    produceSpeed = tonumber(produceSpeed) or 0
                end
                if produceSpeed and produceSpeed > 0 then
                    total += produceSpeed
                end
            end
        end
    end
    return total
end

local function hasEggUID(uid)
    local pg = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    local Egg = Data and Data:FindFirstChild("Egg")
    if not Egg then return false end
    return Egg:FindFirstChild(uid) ~= nil
end

local function hasPetUID(uid)
    local pg = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    local Pets = Data and Data:FindFirstChild("Pets")
    if not Pets then return false end
    return Pets:FindFirstChild(uid) ~= nil
end

local function postReportChunk(commandId, chunkResults)
    local payload = json.encode({
        playerName = Player.Name,
        commandId  = commandId,
        results    = chunkResults -- [{uid=..., ok=true/false, reason=...}]
    })
    local ok, err = pcall(function()
        _request({
            Url = config.serverUrl .. "/report",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end)
    if not ok then
        warn("[report] ส่งผลลัพธ์ไม่สำเร็จ:", tostring(err))
    end
end
-- =======================
-- 4) COMMAND EXECUTORS
-- =======================
local function getReadyEggUIDs(preferredUIDs)
    local result = {}
    if type(preferredUIDs) == "table" then
        for _, uid in ipairs(preferredUIDs) do
            if type(uid) == "string" and #uid > 0 then
                table.insert(result, uid)
            end
        end
        if #result > 0 then return result end
        result = {}
    end

    local pg = Player:FindFirstChild("PlayerGui")
    local Data = pg and pg:FindFirstChild("Data")
    local OwnedEggData = Data and Data:FindFirstChild("Egg")
    if not OwnedEggData then return result end

    local serverTimeObj = getServerTimeObj()
    local nowValue = serverTimeObj and tonumber(serverTimeObj.Value) or nil

    for _, egg in ipairs(OwnedEggData:GetChildren()) do
        local placed = egg:FindFirstChild("DI") ~= nil
        if placed then
            local deadline = egg:GetAttribute("D")
            if deadline then
                if nowValue and nowValue >= deadline then
                    table.insert(result, egg.Name)
                elseif not nowValue then
                    -- หากไม่มีเวลาเซิร์ฟเวอร์ ให้ถือว่าไข่ที่มี deadline แล้วเป็นพร้อมฟัก
                    table.insert(result, egg.Name)
                end
            end
        end
    end

    return result
end

local function hatchEgg(uid)
    local EggModel = BlockFolder:FindFirstChild(uid)
    if not EggModel then return false, "egg_model_missing" end
    local RootPart = EggModel.PrimaryPart or EggModel:FindFirstChild("RootPart")
    if not RootPart then return false, "missing_root" end
    local RF = RootPart:FindFirstChild("RF")
    if not (RF and RF:IsA("RemoteFunction")) then return false, "no_remote" end

    local okInvoke, err = pcall(function()
        return RF:InvokeServer("Hatch")
    end)
    if not okInvoke then
        return false, "invoke_fail: " .. tostring(err)
    end

    local start = tick()
    while tick() - start < config.ackTimeout do
        task.wait(0.3)
        if not hasEggUID(uid) then return true end
        if not BlockFolder:FindFirstChild(uid) then return true end
    end
    return false, "timeout"
end

local function executeHatchCommand(uid)
    print("ได้รับคำสั่งให้ฟักไข่ UID: " .. tostring(uid))
    task.spawn(function()
        local ok, reason = hatchEgg(uid)
        if not ok then
            warn(string.format("[Hatch] ฟักไข่ %s ไม่สำเร็จ: %s", tostring(uid), tostring(reason)))
        end
    end)
end

local function executeHatchReadyCommand(command)
    task.spawn(function()
        local commandId = command.id
        local readyUIDs = getReadyEggUIDs(command.uids)
        if #readyUIDs == 0 then
            if commandId then
                postReportChunk(commandId, { { uid = "", ok = false, reason = "no_ready" } })
            end
            print("[HatchReady] ไม่มีไข่ที่พร้อมฟัก")
            return
        end

        print(string.format("[HatchReady] พบไข่พร้อมฟัก %d ใบ", #readyUIDs))
        local batch = {}
        local function flush()
            if commandId and #batch > 0 then
                postReportChunk(commandId, batch)
                batch = {}
            else
                batch = {}
            end
        end

        for _, uid in ipairs(readyUIDs) do
            local ok, reason = hatchEgg(uid)
            table.insert(batch, { uid = uid, ok = ok, reason = ok and nil or reason })
            if #batch >= 5 then flush() end
        end
        flush()

        mustSendFull = true
    end)
end

function executeSendItemsCommand(commandId, targetPlayerName, itemUIDs)
    print("[DEBUG] เริ่มส่งของ cmd:", commandId, "to:", targetPlayerName, "count:", #itemUIDs)

    local targetPlayer = Players:FindFirstChild(targetPlayerName)
    if not targetPlayer then
        print("[ERROR] ไม่พบผู้เล่นเป้าหมาย:", targetPlayerName)
        return
    end

    local okTp = TeleportToPlayer(targetPlayer)
    if not okTp then print("[WARN] วาร์ปล้มเหลว แต่ลองส่งต่อ") end
    task.wait(2)

    for i, uid in ipairs(itemUIDs) do
        local isEgg = hasEggUID(uid)
        local isPet = (not isEgg) and hasPetUID(uid)
        local isFood = (not isEgg) and (not isPet)

        local beforeGift = getTodayGiftCount()
        local beforeFoodQty = isFood and getFoodQty(uid) or nil

        pcall(function() CharacterRE:FireServer("Focus", uid) end)
        task.wait(0.5)
        pcall(function() GiftRE:FireServer(targetPlayer) end)

        local success = false
        local reason = "timeout"
        local t0 = tick()
        while tick() - t0 < config.ackTimeout do
            task.wait(0.25)
            local afterGift = getTodayGiftCount()

            if isEgg then
                if not hasEggUID(uid) then success = true; reason = nil; break end
            elseif isPet then
                if not hasPetUID(uid) then success = true; reason = nil; break end
            else
                local nowQty = getFoodQty(uid)
                if beforeFoodQty and nowQty < beforeFoodQty then success = true; reason = nil; break end
            end

            if afterGift > beforeGift then success = true; reason = nil; break end
        end

        pcall(function() CharacterRE:FireServer("Focus") end)

        -- 🔴 รายงานผล "ทันที" ต่อชิ้น เพื่อให้ progress วิ่งบนหน้าเว็บ
        postReportChunk(commandId, { { uid = uid, ok = success, reason = reason } })

        print(string.format("[DEBUG] [%d/%d] %s -> %s", i, #itemUIDs, tostring(uid), success and "OK" or ("FAIL:"..tostring(reason))))
    end
end


-- =======================
-- 5) INVENTORY BUILDERS
-- =======================
local function getAllPlayersInServer()
    local playerNames = {}
    for _, p in ipairs(Players:GetPlayers()) do table.insert(playerNames, p.Name) end
    return playerNames
end

local function getFullInventory(Data, ServerTime)
    local inventory = { eggs = {}, pets = {}, foods = {} }

    -- (1) Eggs
    local OwnedEggData = Data and Data:FindFirstChild("Egg")
    if OwnedEggData and ServerTime then
        for _, egg in ipairs(OwnedEggData:GetChildren()) do
            local isPlaced = egg:FindFirstChild("DI") ~= nil
            local isReady = false
            if isPlaced then
                local deadline = egg:GetAttribute("D")
                if deadline and ServerTime.Value >= deadline then isReady = true end
            end
            table.insert(inventory.eggs, {
                uid = egg.Name,
                type = egg:GetAttribute("T"),
                mutation = egg:GetAttribute("M") or "None",
                placed = isPlaced,
                readyToHatch = isReady
            })
        end
    end

    -- (2) Pets
    local OwnedPetData = Data and Data:FindFirstChild("Pets")
    if OwnedPetData then
        local placedPetUIDs = {}
        for _, model in ipairs(PetsFolder:GetChildren()) do
            if model:GetAttribute("UserId") == Player.UserId then
                placedPetUIDs[model.Name] = true
                local root = model.PrimaryPart or model:FindFirstChild("RootPart")
                if root then
                    table.insert(inventory.pets, {
                        uid = model.Name,
                        type = root:GetAttribute("Type"),
                        mutation = root:GetAttribute("Mutate") or "None",
                        income = root:GetAttribute("ProduceSpeed") or 0,
                        placed = true
                    })
                end
            end
        end
        for _, petNode in ipairs(OwnedPetData:GetChildren()) do
            if not placedPetUIDs[petNode.Name] then
                table.insert(inventory.pets, {
                    uid = petNode.Name,
                    type = petNode:GetAttribute("T"),
                    mutation = petNode:GetAttribute("M") or "None",
                    income = 0,
                    placed = false
                })
            end
        end
    end

    -- (3) Foods
    local InventoryData = Data and Data:FindFirstChild("Asset")
    if InventoryData then
        local allAttrs = InventoryData:GetAttributes()
        for _, foodName in ipairs(PetFoods_InGame) do
            local qty = tonumber(allAttrs[foodName]) or 0
            if qty > 0 then
                table.insert(inventory.foods, { name = foodName, quantity = qty })
            end
        end
    end
    return inventory
end

local function buildSlimFromFull(inv)
    local slim = { eggsAgg = {}, foods = {}, eggsUnplaced = 0, petsUnplaced = 0 }
    if not inv then return slim end

    -- eggsAgg (เฉพาะยังไม่วาง)
    local map = {}
    for _, e in ipairs(inv.eggs or {}) do
        if not e.placed then
            local key = (e.type or "?") .. "|" .. (e.mutation or "None")
            map[key] = (map[key] or 0) + 1
            slim.eggsUnplaced = slim.eggsUnplaced + 1
        end
    end
    for k, c in pairs(map) do
        local s, e = string.find(k, "|")
        local t = string.sub(k, 1, s-1)
        local m = string.sub(k, e+1)
        table.insert(slim.eggsAgg, { type = t, muta = m, count = c })
    end
    table.sort(slim.eggsAgg, function(a,b)
        if a.type == b.type then return (a.muta or "") < (b.muta or "") end
        return (a.type or "") < (b.type or "")
    end)

    -- foods
    for _, f in ipairs(inv.foods or {}) do
        local q = tonumber(f.quantity) or 0
        if q > 0 then
            table.insert(slim.foods, { name = f.name, qty = q })
        end
    end
    table.sort(slim.foods, function(a,b) return a.name < b.name end)

    -- petsUnplaced
    for _, p in ipairs(inv.pets or {}) do
        if not p.placed then slim.petsUnplaced = slim.petsUnplaced + 1 end
    end

    return slim
end

-- =======================
-- 6) MAIN LOOP (Slim/Full + Commands)
-- =======================
local mustSendFull = true
local lastFullAt   = 0

local function processCommands(commands)
    if not commands or #commands == 0 then return end
    for _, command in ipairs(commands) do
        if command.action == "hatch" and command.uid then
            executeHatchCommand(command.uid)

        elseif command.action == "hatch_ready" then
            executeHatchReadyCommand(command)

        elseif command.action == "send_items" and command.target and command.uids then
            -- รองรับ ACK: มี command.id มาจากเซิร์ฟเวอร์
            executeSendItemsCommand(command.id, command.target, command.uids)

        elseif command.action == "request_full" then
            -- หน้าเว็บร้องขอ Full snapshot รอบถัดไป
            mustSendFull = true
        end
    end
end

getServerTimeObj = function()
    return ReplicatedStorage:FindFirstChild("Time")
end

local function sendDataAndCheckCommands()
    local PlayerGui = Player:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    local Data = PlayerGui:FindFirstChild("Data")
    if not Data then return end

    local ServerTime = getServerTimeObj()
    local Asset      = Data:FindFirstChild("Asset")

    local coin = 0
    if Asset then coin = tonumber(Asset:GetAttribute("Coin")) or 0 end

    local fullInventory = nil
    local mode = "slim"
    -- ส่ง Full เมื่อถึงเวลา หรือถูกขอ
    if mustSendFull or (nowSec() - lastFullAt >= config.fullInterval) then
        fullInventory = getFullInventory(Data, ServerTime)
        lastFullAt = nowSec()
        mustSendFull = false
        mode = "full"
    end

    local slim = nil
    if fullInventory then
        slim = buildSlimFromFull(fullInventory)
    else
        -- หากไม่ส่ง Full รอบนี้ ให้คำนวณ Slim แบบรวดเร็ว (อ่านเฉพาะ Data ที่จำเป็น)
        -- เพื่อความง่ายและประหยัด เราอ่านจาก Full เท่านั้นในสคริปต์นี้
        -- (ถ้าต้องการ super-optimize เพิ่มเติม สามารถเขียนตัวอ่าน Slim โดยตรงจาก Data ได้)
        fullInventory = getFullInventory(Data, ServerTime)
        slim = buildSlimFromFull(fullInventory)
        -- หมายเหตุ: เพื่อให้ UI แม่นยำ แนะนำส่ง Slim เสมอ (เราทำอยู่)
        -- แต่จะไม่ส่ง 'inventory' เมื่อ mode = 'slim'
        mode = "slim"
        fullInventory = nil
    end

    local allData = {
        playerName       = Player.Name,
        coin             = coin,
        todayGiftCount   = getTodayGiftCount(),
        farmIncomePerSec = getTotalFarmIncomePerSecond(),
        updateInterval   = config.updateInterval,
        serverPlayerList = getAllPlayersInServer(),
        inventorySlim    = slim,         -- ส่ง Slim ทุกครั้ง
        mode             = mode,
        fullTS           = (mode == "full") and lastFullAt or nil,
        inventory        = fullInventory -- ส่งเมื่อ mode == 'full' เท่านั้น
    }

    local ok, responseBody = pcall(function()
        local response = _request({
            Url = config.serverUrl .. "/update",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = json.encode(allData)
        })
        return response.Body
    end)

    if ok and responseBody then
        local commands = nil
        pcall(function() commands = json.decode(responseBody) end)
        if commands then processCommands(commands) end
    else
        print("!!! ERROR: ส่ง/รับข้อมูลล้มเหลว: " .. tostring(responseBody))
    end
end

print("เริ่มต้นการทำงานของสคริปต์ (Slim/Full + ACK/Receipt)...")
while true do
    pcall(sendDataAndCheckCommands)
    task.wait(config.updateInterval)
end
