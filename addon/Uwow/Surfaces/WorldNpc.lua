-- Uwow · Surfaces/WorldNpc.lua — NPC у світі: підпис-рід занять у тултіпі істоти («Innkeeper», «Flight Master»),
-- імена NPC на неймплейтах і рамках цілі/фокуса.
--
-- Імена на рамках — лише за налаштуванням UwowDB.npcNames == true (типово вимкнено, як у v1: частина гравців
-- хоче бачити оригінальні імена) і лише поза боєм: у бою юніт-токени неймплейтів у Midnight секретні, а рамки —
-- захищені; там нічого не читаємо. Гравців не перекладаємо: перевіряємо GUID (Creature-/Vehicle-) без UnitIsPlayer.
-- Ім'я першим рядком тултіпа перекладає Surfaces/Tooltip.lua; тут — лише рядок підпису.
local U = UWOW
local K = U.WK

local function isCreatureGUID(guid)
    if type(guid) ~= "string" or K.secret(guid) then return false end
    return guid:find("^Creature%-") ~= nil or guid:find("^Vehicle%-") ~= nil
end

-- ── підпис у тултіпі ─────────────────────────────────────────────────────────────────────────────────────────
U.Surface("npc-subname", function()
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
        if not U.Enabled() or tt ~= GameTooltip or type(data) ~= "table" or not isCreatureGUID(data.guid) then return end
        local name = tt.GetName and tt:GetName()
        local fs = name and _G[name .. "TextLeft2"]
        local en = K.text(fs)
        if not en or en:find("%d") then return end                          -- рядок рівня/типу — не наш
        local ua = U.T("dialog", en)
        if ua then U.Apply(fs, ua, en) end
    end)
end)

-- ── імена на неймплейтах і рамках ────────────────────────────────────────────────────────────────────────────
local function on() return U.Enabled() and U.Settings and U.Settings.npcNames == true and not K.inCombat() end

local function nameFor(fs, unit)
    if not fs or K.secret(unit) or type(unit) ~= "string" then return end
    local en = K.text(fs)
    if not en then return end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not isCreatureGUID(guid) then return end
    local ua = U.TranslateName(en)
    if ua then U.Apply(fs, ua, en) end
end

U.Surface("npc-names", function()
    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if not on() or type(frame) ~= "table" or not frame.name then return end
            nameFor(frame.name, frame.unit)
        end)
    end
    if UnitFrame_Update then
        hooksecurefunc("UnitFrame_Update", function(frame)
            if not on() or (frame ~= _G.TargetFrame and frame ~= _G.FocusFrame) then return end
            nameFor(frame.name, frame.unit)
        end)
    end
end)
