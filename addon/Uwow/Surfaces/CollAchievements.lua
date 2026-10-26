-- Uwow · Surfaces/CollAchievements.lua — досягнення: вікно (категорії, список, критерії, зведення, статистика,
-- порівняння, пошук), підказка посилання на досягнення і спливні сповіщення (досягнення, прогрес критерію,
-- нові маунт/вихованець/іграшка/декор житла, журнал мандрівника, гарнізон). Сумісність із Krowi_AchievementFilter.
-- Дані: «ach» (achievementID: title, desc), назви категорій — «achcat» (categoryID), потім «ui»; мітки — «ui»,
-- критерії — за типом (див. criteria()).
local U = UWOW
local K = U.CollKit

local function ach(id, field) return U.ID("ach", id, field) end

local function achResolver(getID, field)
    return function(text)
        local id = getID()
        local ua = id and ach(id, field)
        if not ua then
            ua = K.Any(text, "ui")
            if not ua then U.Miss("ach", "ach:" .. field, text, id) end
        end
        return ua
    end
end

-- Назва категорії/мітка інтерфейсу.
local function ui(text) return K.Any(text, "ui", "journal", "collections") end

-- Рядок критерію за його типом (CriteriaType): 0 — убити істоту, 8 — досягнення, 27 — квест,
-- 36/41/42/57 — предмет. Інакше — текстові домени.
local ITEM_TYPES = { [36] = true, [41] = true, [42] = true, [57] = true }
local function criteria(text, ctype, asset)
    text = K.Str(text)
    if not text or K.Cyr(text) then return nil end
    local ua
    if asset and asset > 0 then
        if ctype == 8 then ua = ach(asset, "title")
        elseif ctype == 27 then ua = U.ID("quest", asset, "title")
        elseif ITEM_TYPES[ctype] then ua = U.ID("item", asset, "name") end
    end
    if not ua and ctype == 0 then ua = U.TranslateName(text) end
    ua = ua or K.Any(text, "ui", "names", "collections", "journal")
    if not ua then U.Miss("ach", "ach:criteria", text) end
    return ua
end

-- Рядок «- текст» (невиконаний критерій) — перекладаємо без префікса.
local function criteriaFS(fs, ctype, asset)
    local en = K.Text(fs)
    if not en or K.Cyr(en) then return end
    local pre, body = en:match("^(%- )(.+)$")
    local ua = criteria(body or en, ctype, asset)
    if ua then U.Apply(fs, (pre or "") .. ua, en) end
end

-- ── кнопка досягнення (Blizzard і Krowi мають однакові написи Description/HiddenDescription/Reward) ──
local function followButton(btn, labelKey)
    local getID = function() return btn.id or (btn.Achievement and btn.Achievement.Id) end
    K.FollowNow(btn[labelKey], achResolver(getID, "title"))
    K.FollowNow(btn.Description, achResolver(getID, "desc"))
    K.FollowNow(btn.HiddenDescription, achResolver(getID, "desc"))
    if btn.Reward then K.FollowNow(btn.Reward, function(text) return ui(text) or K.Source(text, "ui") end) end
end

local function installWindow()
    -- категорії зліва
    -- (categoryID → «achcat»: однослівні назви на кшталт «Midnight», «Lorewalking» текстом не знаходяться)
    K.OnScroll(AchievementFrameCategories and AchievementFrameCategories.ScrollBox, function(frame)
        local b = frame.Button
        if b and b.Label then
            K.FollowNow(b.Label, function(text)
                local id = tonumber(frame.categoryID)
                return (id and U.ID("achcat", id, "name")) or ui(text)
            end)
        end
    end)
    -- список досягнень: назва, опис, нагорода — супровід, щоб висоту рядка Blizzard рахував за перекладом
    K.OnScroll(AchievementFrameAchievements and AchievementFrameAchievements.ScrollBox, function(frame)
        followButton(frame, "Label")
    end)
    -- критерії розгорнутого досягнення
    if AchievementObjectives_DisplayCriteria then
        hooksecurefunc("AchievementObjectives_DisplayCriteria", function(obj, id)
            if not U.Enabled() or not obj or not id then return end
            local n = GetAchievementNumCriteria and GetAchievementNumCriteria(id) or 0
            local text, meta, bar = 0, 0, 0
            for i = 1, n do
                local s, ctype, _, _, _, _, flags, asset = GetAchievementCriteriaInfo(id, i)
                if ctype == 8 and asset then
                    meta = meta + 1
                    local m = obj.metas and obj.metas[meta]
                    if m and m.Label then
                        local en = K.Text(m.Label)
                        if en then K.Put(m.Label, en, ach(m.id or asset, "title"), "ach", "ach:meta", m.id or asset) end
                    end
                elseif flags and EVALUATION_TREE_FLAG_PROGRESS_BAR and bit and bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR then
                    bar = bar + 1
                else
                    text = text + 1
                    local c = obj.criterias and obj.criterias[text]
                    if c and c.Name then criteriaFS(c.Name, ctype, asset) end
                end
            end
            if obj.RepCriteria then K.FollowNow(obj.RepCriteria, ui) end
        end)
    end
    -- зведення: нещодавні досягнення і смуги категорій
    if AchievementFrameSummary_UpdateAchievements then
        hooksecurefunc("AchievementFrameSummary_UpdateAchievements", function()
            if not U.Enabled() then return end
            local buttons = AchievementFrameSummaryAchievements and AchievementFrameSummaryAchievements.buttons
            for _, b in ipairs(buttons or {}) do
                local getID = function() return b.id end
                K.FollowNow(b.Label, achResolver(getID, "title"))
                K.FollowNow(b.Description, achResolver(getID, "desc"))
            end
        end)
    end
    if AchievementFrameSummary_UpdateSummaryProgressBars then
        hooksecurefunc("AchievementFrameSummary_UpdateSummaryProgressBars", function(categories)
            if not U.Enabled() then return end
            for i = 1, #(categories or {}) do
                local bar = _G["AchievementFrameSummaryCategoriesCategory" .. i]
                if bar and bar.Label then K.FollowNow(bar.Label, ui) end
            end
        end)
    end
    -- статистика: заголовок категорії або назва статистики (це теж achievementID)
    K.OnScroll(AchievementFrameStats and AchievementFrameStats.ScrollBox, function(frame)
        if frame.isHeader then
            if frame.Title then K.FollowNow(frame.Title, ui) end
        else
            local fs = frame.Text or (frame.GetFontString and frame:GetFontString())
            if fs then K.FollowNow(fs, achResolver(function() return frame.id end, "title")) end
        end
    end)
    -- порівняння з іншим гравцем
    local cmp = AchievementFrameComparison
    if cmp then
        K.OnScroll(cmp.AchievementContainer and cmp.AchievementContainer.ScrollBox, function(frame)
            local p = frame.Player
            if not p then return end
            local getID = function() return frame.id end
            K.FollowNow(p.Label, achResolver(getID, "title"))
            K.FollowNow(p.Description, achResolver(getID, "desc"))
        end)
        K.OnScroll(cmp.StatContainer and cmp.StatContainer.ScrollBox, function(frame)
            if frame.Title then K.FollowNow(frame.Title, ui) end
            if frame.Text then K.FollowNow(frame.Text, achResolver(function() return frame.id end, "title")) end
        end)
    end
    -- пошук: підказки під полем і повні результати (назва + шлях категорій «А > Б»)
    local function path(text)
        local out, any = {}, false
        for part in (text .. " > "):gmatch("(.-) > ") do
            local ua = ui(part)
            out[#out + 1] = ua or part
            any = any or ua ~= nil
        end
        return any and table.concat(out, " > ") or nil
    end
    if AchievementFrame_ShowSearchPreviewResults then
        hooksecurefunc("AchievementFrame_ShowSearchPreviewResults", function()
            if not U.Enabled() then return end
            local box = AchievementFrame.HeaderDetails and AchievementFrame.HeaderDetails.Filters
            local c = box and box.SearchBox and box.SearchBox.SearchPreviewContainer
            for _, b in ipairs(c and c.searchPreviews or {}) do
                if b.achievementID and b.Name then
                    local en = K.Text(b.Name)
                    if en then K.Put(b.Name, en, ach(b.achievementID, "title")) end
                end
            end
        end)
    end
    K.OnScroll(AchievementFrame.SearchResults and AchievementFrame.SearchResults.ScrollBox, function(frame)
        K.FollowNow(frame.Name, achResolver(function() return frame.achievementID end, "title"))
        if frame.Path then K.FollowNow(frame.Path, path) end
        if frame.ResultType then K.FollowNow(frame.ResultType, ui) end
    end)
    -- заголовок вікна і вкладки
    local function chrome()
        if not U.Enabled() then return end
        local h = AchievementFrame.Header
        if h and h.Title then K.FollowNow(h.Title, ui) end
        local tabs = {}
        for i = 1, (AchievementFrame.numTabs or 3) do tabs[i] = "AchievementFrameTab" .. i end
        K.Tabs(tabs)
    end
    if AchievementFrame.HookScript then AchievementFrame:HookScript("OnShow", chrome) end
    if AchievementFrame:IsShown() then chrome() end
end

U.Surface("ach-window", function()
    K.OnAddon("Blizzard_AchievementUI", installWindow)
end)

-- ── підказка посилання на досягнення ───────────────────────────────────────────────────────────────────
U.Surface("ach-tooltip", function()
    local T = Enum and Enum.TooltipDataType
    if not (TooltipDataProcessor and T and T.Achievement) then return end
    TooltipDataProcessor.AddTooltipPostCall(T.Achievement, function(tt, data)
        if not U.Enabled() or not data then return end
        local ok, id = pcall(tonumber, data.id)
        if not ok or not id then return end
        local fs = K.TipLine(tt, 1)
        local en = K.Text(fs)
        if en then K.Put(fs, en, ach(id, "title"), "ach", "tooltip-ach", id) end
        local desc = GetAchievementInfo and select(8, GetAchievementInfo(id))
        local ua = desc and ach(id, "desc")
        if not ua then return end
        for i = 2, (tt.NumLines and tt:NumLines() or 0) do
            local l = K.TipLine(tt, i)
            if K.Text(l) == desc then U.Apply(l, ua, desc); break end
        end
    end)
end)

-- ── спливні сповіщення (одна точка: контейнер AlertFrame отримує вже заповнений фрейм) ─────────────────
local function inner(fs, en, ua)                 -- назва в кольорі якості: міняємо лише саму назву
    local full = K.Text(fs)
    if not full or not ua or not en then return end
    local a, b = full:find(en, 1, true)
    if a then U.Apply(fs, full:sub(1, a - 1) .. ua .. full:sub(b + 1), full) end
end

local function labels(f)
    for _, k in ipairs({ "Unlocked", "Label", "Title" }) do
        local fs = f[k]
        local en = K.Text(fs)
        if en and not K.Cyr(en) then K.Put(fs, en, ui(en)) end
    end
end

local function criteriaAlert(f)
    local en = K.Text(f.Name)
    if not en or not f.id then return end
    local n = GetAchievementNumCriteria and GetAchievementNumCriteria(f.id) or 0
    for i = 1, n do
        local s, ctype, _, _, _, _, _, asset = GetAchievementCriteriaInfo(f.id, i)
        if s == en then return K.Put(f.Name, en, criteria(en, ctype, asset)) end
    end
    K.Put(f.Name, en, criteria(en))
end

local MINE                                       -- черги сповіщень цієї зони (лут/гроші/квести — не наші)
local function alert(f)
    local q = f.queue
    if not q or not MINE[q] then return end
    labels(f)
    if q == AchievementAlertSystem then
        local en = K.Text(f.Name)
        if en and f.id then K.Put(f.Name, en, ach(f.id, "title"), "ach", "alert-ach", f.id) end
    elseif q == CriteriaAlertSystem then
        criteriaAlert(f)
    elseif q == NewMountAlertSystem and f.mountID then
        local name = C_MountJournal and C_MountJournal.GetMountInfoByID(f.mountID)
        inner(f.Name, K.Str(name), U.ID("mount", f.mountID, "n"))
    elseif q == NewPetAlertSystem and f.petID and C_PetJournal then
        local sid, custom, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(f.petID)
        if sid and not custom then inner(f.Name, K.Str(name), U.ID("pet", sid, "n")) end
    elseif q == NewToyAlertSystem and f.toyID and C_ToyBox then
        local _, name = C_ToyBox.GetToyInfo(f.toyID)
        inner(f.Name, K.Str(name), U.ID("item", f.toyID, "name"))
    elseif q == HousingItemEarnedAlertFrameSystem then
        local en = K.Text(f.DecorName)
        if en then K.Put(f.DecorName, en, K.Any(en, "collections", "ui"), "collections", "alert-housing") end
    else
        local en = K.Text(f.Name)                  -- журнал мандрівника, гарнізон: назва — текст
        if en and not K.Cyr(en) then K.Put(f.Name, en, K.Any(en, "ui", "collections")) end
    end
end

U.Surface("alerts", function()
    if not (AlertFrame and AlertFrame.AddAlertFrame) then return end
    MINE = {}
    for _, n in ipairs({ "AchievementAlertSystem", "CriteriaAlertSystem", "NewMountAlertSystem", "NewPetAlertSystem",
                         "NewToyAlertSystem", "NewCosmeticAlertFrameSystem", "NewWarbandSceneAlertSystem",
                         "HousingItemEarnedAlertFrameSystem", "MonthlyActivityAlertSystem", "GarrisonBuildingAlertSystem",
                         "GarrisonMissionAlertSystem", "GarrisonShipMissionAlertSystem", "GarrisonRandomMissionAlertSystem",
                         "GarrisonFollowerAlertSystem", "GarrisonShipFollowerAlertSystem", "GarrisonTalentAlertSystem" }) do
        local q = rawget(_G, n)
        if q then MINE[q] = true end
    end
    hooksecurefunc(AlertFrame, "AddAlertFrame", function(_, f)
        if U.Enabled() and f then pcall(alert, f) end
    end)
end)

local krowiDone
-- ── Krowi's Achievement Filter (сторонній аддон; лише якщо завантажений) ────────────────────────────────
local function installKrowi()
    local m = rawget(_G, "KrowiAF_AchievementButtonMixin")
    if not m or krowiDone then return end
    krowiDone = true
    hooksecurefunc(m, "SetAchievementData", function(self)      -- Krowi тримає ID у self.Achievement.Id
        if not U.Enabled() then return end
        followButton(self, "Header")
    end)
    local sm = rawget(_G, "KrowiAF_SearchResultsButtonMixin")
    if sm and sm.SetAchievement then
        hooksecurefunc(sm, "SetAchievement", function(self, achievement)
            if not U.Enabled() or type(achievement) ~= "table" then return end
            local en = K.Text(self.Name)
            if en then K.Put(self.Name, en, ach(achievement.Id, "title")) end
        end)
    end
    local cm = rawget(_G, "KrowiAF_CategoryButtonMixin")
    if cm and cm.SetCategory then
        hooksecurefunc(cm, "SetCategory", function(self)
            if not U.Enabled() then return end
            local en = K.Text(self.Label)
            if not en then return end
            local pre, body = en:match("^([%+%-] )(.+)$")
            local ua = ui(body or en)
            if ua then U.Apply(self.Label, (pre or "") .. ua, en) end
        end)
    end
end

U.Surface("ach-krowi", function()
    K.OnAddon("Krowi_AchievementFilter", installKrowi)
end)
