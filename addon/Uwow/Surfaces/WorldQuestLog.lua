-- Uwow · Surfaces/WorldQuestLog.lua — журнал квестів на мапі світу (QuestScrollFrame): назви квестів, рядки цілей
-- і тексту завершення під ними, заголовки зон, заголовки кампаній і сюжетних ліній, «прогрес історії».
-- Панель деталей квесту на мапі малює QuestInfo_Display — її перекладає Quest.lua.
-- Один post-хук на глобальну QuestLogQuests_Update (її кличуть через глобальне ім'я). Розміри кнопок не
-- змінюємо: якщо переклад вищий, напис трохи стискається (U.WK.Fit).
local U = UWOW
local K = U.WK

local function title(b)
    local fs, id = b.Text, b.questID
    local full = K.text(fs)
    if not full or not id then return end
    local ua = K.QuestTitle(id)
    if not ua then
        U.Miss("quest", "questlog:title", C_QuestLog.GetTitleForQuestID(id) or full, id)
        return
    end
    local en = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    K.Fit(fs, K.Swap(full, en, ua) or ua, full)
end

local function objective(f)
    local fs = f.Text
    local en = K.text(fs)
    if not en then return end
    local ua = K.Objective(en)
    if not ua and f.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(f.questID) then
        ua = U.ID("quest", f.questID, "completionLog")
    end
    if ua then K.Fit(fs, ua, en) else U.Miss("questui", "questlog:objective", en, f.questID) end
end

local function header(b)
    local fs = b.ButtonText or (b.GetFontString and b:GetFontString()) or b.Text
    local en = K.text(fs)
    if not en then return end
    local ua = K.Tany({ "ui", "questui" }, en)
    if ua then K.Fit(fs, ua, en) else U.Miss("ui", "questlog:header", en) end
end

local function campaignHeader(h)
    local fs = h.Text
    local en = K.text(fs)
    if not en then return end
    local ua = K.Tany({ "questui", "ui" }, en)
    if not ua then U.Miss("questui", "questlog:campaign", en) return end
    U.Apply(fs, ua, en)
    if not (U.Settings and U.Settings.original) then
        local max = _G.CAMPAIGN_TITLE_MAX_WIDTH or 220
        fs:SetWidth(max)
        fs:SetWidth(math.min(max, fs:GetStringWidth() + 1))
    end
    if h.Progress then K.Label(h.Progress) end
end

local function storyHeader()
    local sh = QuestScrollFrame and QuestScrollFrame.Contents and QuestScrollFrame.Contents.StoryHeader
    if not (sh and sh:IsShown()) then return end
    K.Label(sh.Text)
    local en = K.text(sh.Progress)
    local fmt = _G.QUEST_STORY_STATUS
    local p = en and fmt and K.Pattern(fmt)
    local a, b = p and en:match(p)
    local tpl = a and U.T("ui", fmt)
    if tpl then U.Apply(sh.Progress, K.Fill(tpl, {}, { a, b }), en) end
end

local function update()
    if not U.Enabled() or not QuestScrollFrame then return end
    local sf = QuestScrollFrame
    if sf.titleFramePool then for b in sf.titleFramePool:EnumerateActive() do title(b) end end
    if sf.objectiveFramePool then for f in sf.objectiveFramePool:EnumerateActive() do objective(f) end end
    if sf.headerFramePool then for b in sf.headerFramePool:EnumerateActive() do header(b) end end
    for _, pool in ipairs({ sf.campaignHeaderFramePool, sf.campaignHeaderMinimalFramePool }) do
        if pool then for h in pool:EnumerateActive() do campaignHeader(h) end end
    end
    storyHeader()
end

U.Surface("quest-log", function()
    if not QuestLogQuests_Update then return end
    hooksecurefunc("QuestLogQuests_Update", update)
end)
