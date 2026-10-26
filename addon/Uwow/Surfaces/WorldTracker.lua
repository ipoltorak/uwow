-- Uwow · Surfaces/WorldTracker.lua — трекер цілей праворуч (ObjectiveTrackerFrame): назви квестів, кампаній,
-- світових квестів і бонусних цілей, рядки цілей, «Готово до здачі», заголовки модулів, сценарії (назва, етап,
-- критерії), досягнення, щомісячні активності.
--
-- Як хукаємо: міксини блоків копіюються в кожен блок під час створення (CreateFromMixins/XML mixin), тому хук
-- на ObjectiveTrackerBlockMixin не дійде до вже похідних міксинів. Натомість ставимо post-хук на GetBlock
-- кожного модуля (екземпляр), а з нього — по одному post-хуку SetHeader/AddObjective на кожен новий блок.
-- Геометрію трекера не чіпаємо (він у керованому контейнері UIParent, поряд із захищеними панелями): довший
-- переклад стискається масштабом тексту, у крайньому разі обрізається до кількості рядків оригіналу.
local U = UWOW
local K = U.WK

local QUEST_MODULES = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "WorldQuestObjectiveTracker",
                        "BonusObjectiveTracker" }
local OTHER_MODULES = { "AchievementObjectiveTracker", "ScenarioObjectiveTracker", "MonthlyActivitiesObjectiveTracker",
                        "InitiativeTasksObjectiveTracker", "AdventureObjectiveTracker", "ProfessionsRecipeTracker",
                        "UIWidgetObjectiveTracker" }
local kind = {}                              -- модуль → "quest" | "ach" | "recipe" | "text"

local function headerUA(block, en)
    local m = block.parentModule
    local k = m and kind[m] or "text"
    local id = tonumber(block.id)
    if k == "quest" and id and id > 0 then return K.QuestTitle(id), "quest", id end
    if k == "ach" and id then return U.ID("ach", id, "name"), "ach", id end
    if k == "recipe" and id then return U.ID("spell", id, "name"), "spell", id end
    return K.Tany({ "questui", "ui" }, en), "questui", nil
end

local function onHeader(block, text)
    if not U.Enabled() or type(text) ~= "string" or K.secret(text) then return end
    local fs = block.HeaderText
    local en = K.text(fs)
    if not en then return end
    local ua, dom, id = headerUA(block, text)
    if ua then K.Fit(fs, K.Swap(en, text, ua) or ua, en) else U.Miss(dom, "tracker:header", text, id) end
end

local function onObjective(block, key, text)
    if not U.Enabled() or type(text) ~= "string" or K.secret(text) then return end
    local line = block.usedLines and block.usedLines[key]
    local fs = line and line.Text
    local en = K.text(fs)
    if not en then return end
    local ua = K.Objective(en)
    if not ua and key == "QuestComplete" then
        local id = tonumber(block.id)
        ua = id and U.ID("quest", id, "completionLog")
    end
    if ua then K.Fit(fs, ua, en) else U.Miss("questui", "tracker:objective", en, tonumber(block.id)) end
end

-- Автопопап («Квест завершено! Клікни, щоб завершити», «Нове завдання — клікни, щоб переглянути»):
-- AutoQuestPopupBlockMixin:Update(questTitle, questID, popUpType) ставить TopText/BottomText/QuestName.
local function onPopup(block, questTitle, questID)
    if not U.Enabled() then return end
    local c = block.Contents
    if not c then return end
    K.Label(c.TopText)
    K.Label(c.BottomText)
    local fs = c.QuestName
    local en = K.text(fs)
    local ua = en and K.QuestTitle(questID or block.questID)
    if ua then K.Fit(fs, K.Swap(en, questTitle, ua) or ua, en)
    elseif en then U.Miss("quest", "tracker:popup", en, questID) end
end

local function hookBlock(block)
    if type(block) ~= "table" then return end
    K.HookOnce(block, "SetHeader", onHeader)
    K.HookOnce(block, "AddObjective", onObjective)
    if block.Contents and block.Contents.QuestName then K.HookOnce(block, "Update", onPopup) end
end

local function hookModule(m, k)
    if type(m) ~= "table" or type(m.GetBlock) ~= "function" then return end
    kind[m] = k
    K.HookOnce(m, "GetBlock", function(self, id, template)
        local t = self.usedBlocks and self.usedBlocks[template or self.blockTemplate]
        local b = t and t[id]
        if b then hookBlock(b) end
    end)
    -- уже створені блоки
    if m.usedBlocks then
        for _, t in pairs(m.usedBlocks) do for _, b in pairs(t) do hookBlock(b) end end
    end
    -- заголовок модуля: ставиться в OnLoad (до нас) і далі через SetHeader
    if m.Header and m.Header.Text and U.Settings.enabled then K.Label(m.Header.Text) end
    K.HookOnce(m, "SetHeader", function(self) if U.Enabled() and self.Header then K.Label(self.Header.Text) end end)
end

-- Сценарій: назва (Header.Text), етап (StageBlock.Stage/Name), критерії — через ObjectivesBlock.
local function scenario(self)
    if not U.Enabled() then return end
    if self.Header and self.Header.Text then
        local fs = self.Header.Text
        local en = K.text(fs)
        local ua = en and K.Tany({ "questui", "ui" }, en)
        if ua then U.Apply(fs, ua, en) elseif en then U.Miss("questui", "scenario:name", en) end
    end
    local sb = self.StageBlock
    if sb then
        for _, k in ipairs({ "Stage", "Name", "CompleteLabel" }) do
            local fs = sb[k]
            local en = K.text(fs)
            local ua = en and K.Tany({ "questui", "ui" }, en)
            if ua then K.Fit(fs, ua, en) elseif en and k == "Name" then U.Miss("questui", "scenario:stage", en) end
        end
    end
end

U.Surface("objective-tracker", function()
    for _, n in ipairs(QUEST_MODULES) do hookModule(_G[n], "quest") end
    hookModule(_G.AchievementObjectiveTracker, "ach")
    hookModule(_G.ProfessionsRecipeTracker, "recipe")
    for _, n in ipairs(OTHER_MODULES) do
        if not kind[_G[n] or 0] then hookModule(_G[n], "text") end
    end
    local sc = _G.ScenarioObjectiveTracker
    if sc then
        hookBlock(sc.ObjectivesBlock)
        K.HookOnce(sc, "LayoutContents", scenario)
        if sc.StageBlock then
            K.HookOnce(sc.StageBlock, "UpdateStageBlock", function() scenario(sc) end)
        end
    end
    local otf = _G.ObjectiveTrackerFrame
    if otf and otf.Header and otf.Header.Text and U.Settings.enabled then K.Label(otf.Header.Text) end
end)

-- ── квестові тости й банер ───────────────────────────────────────────────────────────────────────────────────
-- Тост «Світове завдання виконано» / «Сценарій завершено» (AlertFrame:AddAlertFrame викликається вже після
-- функції налаштування тосту) і банер на початку світового квесту чи бонусної цілі (TopBannerManager → PlayBanner).
-- Тости досягнень і колекцій перекладає агент coll у своєму файлі; тут лише квестові.
local function questToast(_, frame)
    if not U.Enabled() or type(frame) ~= "table" then return end
    if frame.QuestName and frame.questID then                               -- WorldQuestCompleteAlertFrameTemplate
        local en = K.text(frame.QuestName)
        local ua = en and K.QuestTitle(frame.questID)
        if ua then K.Fit(frame.QuestName, ua, en) elseif en then U.Miss("quest", "toast:world-quest", en, frame.questID) end
        if frame.ToastText then K.Label(frame.ToastText) end
    elseif frame.dungeonName and frame.rewardData then                      -- ScenarioAlertFrameTemplate
        local en = K.text(frame.dungeonName)
        local ua = en and K.Tany({ "questui", "ui" }, en)
        if ua then K.Fit(frame.dungeonName, ua, en) end
    end
end

local function topBanner(self)
    if not U.Enabled() then return end
    local en = K.text(self.Title)
    local ua = en and K.QuestTitle(self.questID)
    if ua then U.Apply(self.Title, ua, en) end
    if self.Subtitle then K.Label(self.Subtitle) end
end

U.Surface("quest-toasts", function()
    if _G.AlertFrame and _G.AlertFrame.AddAlertFrame then K.HookOnce(_G.AlertFrame, "AddAlertFrame", questToast) end
    local b = _G.ObjectiveTrackerTopBannerFrame
    if b and b.PlayBanner then K.HookOnce(b, "PlayBanner", topBanner) end
end)
