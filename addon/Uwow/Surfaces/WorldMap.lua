-- Uwow · Surfaces/WorldMap.lua — мапа світу й польотів: тултіпи пінів квестів, світових квестів, віньєток
-- (рідкісні моби, скарби), точок інтересу (AreaPOI) і точок польоту; тултіпи блоків трекера (бонусні цілі, світові
-- квести, етап сценарію, прогрес групи); підпис зони/точки інтересу вгорі мапи (AreaLabel); старе вікно TaxiFrame.
--
-- Тултіпи: post-хуки (hooksecurefunc) на GameTooltip:SetText і :AddLine. Вони спрацьовують усередині OnMouseEnter
-- піна чи блоку, до GameTooltip:Show(), тож розмір тултіпа рахується вже з UA; самі ми Show() не кличемо, полів
-- GameTooltip не пишемо. Post-хук не переносить taint у код, що його викликав, тож далі AreaPoiUtil.TryShowTooltip /
-- GameTooltip_AddWidgetSet (AreaPoiUtil.lua:44, GameTooltip.lua:588) виконуються чисто.
-- У v1 taint ішов не від самої правки тексту, а від того, що Blizzard-код після неї продовжував виконуватись
-- тейнтнутим (пост-виклик TooltipDataProcessor типу Quest + Show() з аддона) — і віджети читали секретні розміри.
-- Запобіжник: щойно до тултіпа приєднано набір віджетів (widgetContainer.widgetSetID) або вставлено фрейм
-- (insertedFrames: GameTooltip_InsertFrame, SharedTooltipTemplates.lua:197), подальші рядки не чіпаємо — їхня
-- висота вже врахована у розкладці віджетів. Заголовок і опис додаються до віджетів, тож перекладаються.
local U = UWOW
local K = U.WK

local function tipLine(i)
    return _G["GameTooltipTextLeft" .. i]
end

local function hasWidgets(tt)
    local wc = rawget(tt, "widgetContainer")
    if type(wc) == "table" and wc.widgetSetID ~= nil then return true end
    local ins = rawget(tt, "insertedFrames")
    return type(ins) == "table" and #ins > 0
end

-- Тип власника: "quest" (квест/світовий квест, блок трекера квесту), "vignette", "poi", "taxi", "tracker" або nil.
local function ownerKind(owner)
    if type(owner) ~= "table" then return nil end
    if owner.taxiNodeData then return "taxi" end
    local ok, name = pcall(function() return owner.GetName and owner:GetName() end)
    if ok and type(name) == "string" and name:find("^TaxiButton%d") then return "taxi" end
    local sc = _G.ScenarioObjectiveTracker
    if sc and owner == sc.StageBlock then return "tracker" end
    if type(owner.parentModule) == "table" and owner.id ~= nil then          -- блок трекера
        local id = tonumber(owner.id)
        if id and id > 0 and owner.HeaderText then return "tracker", id end
        return "tracker"
    end
    if type(owner.GetMap) ~= "function" then return nil end                  -- далі лише піни мапи
    if owner.poiInfo then return "poi" end
    if owner.vignetteGUID or owner.vignetteInfo then return "vignette" end
    local id = owner.questID
    if type(id) == "number" and not K.secret(id) then return "quest", id end
end

local function generic(en)
    return K.Tany({ "ui", "questui", "dialog" }, en) or K.Objective(en)
end

local function translateLine(tt, fs, first)
    if not fs or hasWidgets(tt) then return end
    local en = K.text(fs)
    if not en then return end
    local k, id = ownerKind(tt:GetOwner())
    if not k then return end
    local ua
    if k == "quest" then
        if first then
            ua = K.QuestTitle(id)
            if not ua then U.Miss("quest", "map:quest-title", en, id) end
        else
            ua = K.Objective(en)
        end
    elseif k == "vignette" then
        ua = first and K.Tany({ "ui", "names" }, en) or K.Objective(en)
        if not ua and first then U.Miss("ui", "map:vignette", en) end
    elseif k == "poi" then
        ua = generic(en)
        if not ua and first then U.Miss("ui", "map:poi", en) end
    elseif k == "taxi" then
        ua = K.Tany({ "ui" }, en)
        if not ua and first then U.Miss("ui", "map:taxi", en) end
    elseif k == "tracker" then
        if first and id then
            local t = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
            if t == en then ua = K.QuestTitle(id) end
        end
        ua = ua or generic(en)
    end
    if ua then U.Apply(fs, ua, en) end
end

U.Surface("map-pin-tooltips", function()
    local tt = _G.GameTooltip
    if not tt then return end
    hooksecurefunc(tt, "SetText", function(self)
        if not U.Enabled() then return end
        translateLine(self, tipLine(1), true)
    end)
    hooksecurefunc(tt, "AddLine", function(self)
        if not U.Enabled() then return end
        local n = self:NumLines()
        if n and n > 0 then translateLine(self, tipLine(n), n == 1) end
    end)
end)

-- ── підпис зони/точки інтересу вгорі мапи ────────────────────────────────────────────────────────────────────
local function areaLabel(self)
    if not U.Enabled() then return end
    for _, k in ipairs({ "Name", "Description" }) do
        local fs = self[k]
        local en = K.text(fs)
        if en then
            local ua = K.Tany({ "ui", "questui" }, en)
            if ua then U.Apply(fs, ua, en) elseif k == "Name" then U.Miss("ui", "map:area-label", en) end
        end
    end
end

local function hookAreaLabels(map)
    if not (map and map.dataProviders) then return end
    for provider in pairs(map.dataProviders) do
        if type(provider) == "table" and provider.Label and provider.Label.EvaluateLabels then
            K.HookOnce(provider.Label, "EvaluateLabels", areaLabel)
        end
    end
end

U.Surface("map-area-label", function()
    if _G.AreaLabelFrameMixin then K.HookOnce(_G.AreaLabelFrameMixin, "EvaluateLabels", areaLabel) end
    hookAreaLabels(_G.WorldMapFrame)
    K.OnAddon("Blizzard_FlightMap", function() hookAreaLabels(_G.FlightMapFrame) end)
end)
