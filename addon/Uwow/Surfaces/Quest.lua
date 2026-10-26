-- Uwow · Surfaces/Quest.lua — вікно квесту (NPC і панель деталей журналу/мапи): назва з декором, опис, цілі
-- (резюме й окремі рядки), текст завершення, нагороди (предмети, валюти, закляття, репутація, заголовки),
-- вікно прогресу (текст, потрібні предмети), список квестів NPC (QuestFrameGreetingPanel), підписи портрета,
-- статичні кнопки. Ключ тексту квесту — questID; рядки інтерфейсу — домен ui.
local U = UWOW
local K = U.WK

-- questID контексту QuestInfo: журнал/мапа → вибраний квест, вікно NPC → GetQuestID().
local function infoQuestID()
    local log = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog
    local id
    if log and C_QuestLog and C_QuestLog.GetSelectedQuest then id = C_QuestLog.GetSelectedQuest()
    elseif GetQuestID then id = GetQuestID() end
    return id and id > 0 and id or nil
end

local function npcQuestID()
    local id = GetQuestID and GetQuestID()
    return id and id > 0 and id or nil
end

-- Текстове поле квесту: за ID, інакше за текстом (questui).
local function tr(fs, id, field)
    local en = K.text(fs)
    if not en then return end
    local ua = id and U.ID("quest", id, field)
    if not ua then
        ua = K.Tany({ "questui", "dialog" }, en)
        if not ua then U.Miss("quest", "quest:" .. field, en, id) return end
    end
    U.Apply(fs, ua, en)
end

-- Назва з декором (іконки, «— провалено»): підміняємо лише сам заголовок усередині рядка.
local function trTitle(fs, id, enTitle)
    local full = K.text(fs)
    if not full or not id then return end
    local ua = K.QuestTitle(id)
    if not ua then U.Miss("quest", "quest:title", enTitle or full, id) return end
    U.Apply(fs, (enTitle and K.Swap(full, enTitle, ua)) or ua, full)
end

local function enTitleFor(id, log)
    if log and C_QuestLog and C_QuestLog.GetTitleForQuestID then return C_QuestLog.GetTitleForQuestID(id) end
    return GetTitleText and GetTitleText()
end

-- ── нагороди ───────────────────────────────────────────────────────────────────────────────────────────────
local function itemIDOf(btn, log)
    if btn.objectType == "questSessionBonusReward" then return 171305 end
    local idx = btn.GetID and btn:GetID()
    if not idx then return nil end
    local itemID
    if log then
        local f = btn.type == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
        if f then itemID = select(6, f(idx)) end
    elseif GetQuestItemInfo then
        itemID = select(6, GetQuestItemInfo(btn.type, idx))
    end
    if not itemID and C_Item and C_Item.GetItemInfoInstant then
        local en = K.text(btn.Name)
        if en then itemID = C_Item.GetItemInfoInstant(en) end
    end
    return itemID
end

local function rewardName(btn, text, log)
    if btn.objectType == "currency" then
        local c = btn.currencyInfo
        return c and c.currencyID and U.ID("currency", c.currencyID, "name")
    end
    local id = itemIDOf(btn, log)
    local ua = id and U.ID("item", id, "name")
    if not ua and id then U.Miss("item", "quest-reward", text, id) end
    return ua
end

local function hookRewardButton(btn, log)
    if not btn or not btn.Name then return end
    K.HookText(btn.Name, function(_, text)
        local l = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog
        return rewardName(btn, text, l)
    end)
    local en = K.text(btn.Name)
    if en and btn:IsShown() then
        local ua = rewardName(btn, en, log)
        if ua then U.Apply(btn.Name, ua, en) end
    end
end

local LABELS = { "Header", "ItemChooseText", "ItemReceiveText", "PlayerTitleText", "QuestSessionBonusReward" }

local function rewards()
    local qif = _G.QuestInfoFrame
    local rf = qif and qif.rewardsFrame
    if not rf then return end
    local log = qif.questLog
    for _, k in ipairs(LABELS) do if rf[k] then K.Label(rf[k]) end end
    if rf.XPFrame and rf.XPFrame.ReceiveText then K.Label(rf.XPFrame.ReceiveText) end
    for _, btn in ipairs(rf.RewardButtons or {}) do
        if btn:IsShown() then hookRewardButton(btn, log) end
    end
    if rf.spellHeaderPool then
        for h in rf.spellHeaderPool:EnumerateActive() do K.Label(h) end
    end
    if rf.spellRewardPool then
        for f in rf.spellRewardPool:EnumerateActive() do
            local en = K.text(f.Name)
            local ua = en and f.rewardSpellID and U.ID("spell", f.rewardSpellID, "name")
            if ua then U.Apply(f.Name, ua, en) end
        end
    end
    if rf.followerRewardPool then
        for f in rf.followerRewardPool:EnumerateActive() do
            local en = K.text(f.Name)
            local ua = en and U.TranslateName(en)
            if ua then U.Apply(f.Name, ua, en) end
        end
    end
    if rf.reputationRewardPool then
        for f in rf.reputationRewardPool:EnumerateActive() do
            local en = K.text(f.Name)
            local fname = f.factionID and U.ID("faction", f.factionID, "n")
            local tpl = fname and _G.QUEST_REPUTATION_REWARD_TITLE and U.T("ui", _G.QUEST_REPUTATION_REWARD_TITLE)
            if en and fname then U.Apply(f.Name, tpl and K.Fill(tpl, { fname }) or (K.Swap(en, f.factionName, fname) or en), en) end
        end
    end
end

local function objectiveLines()
    local of = _G.QuestInfoObjectivesFrame
    for _, fs in ipairs(of and of.Objectives or {}) do
        if fs:IsShown() then
            local en = K.text(fs)
            local ua = en and K.Objective(en)
            if ua then U.Apply(fs, ua, en) elseif en then U.Miss("questui", "quest:objective", en, infoQuestID()) end
        end
    end
end

U.Surface("quest-info", function()
    if not QuestInfo_Display then return end
    hooksecurefunc("QuestInfo_Display", function()
        if not U.Enabled() then return end
        local id = infoQuestID()
        local log = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog
        trTitle(_G.QuestInfoTitleHeader, id, id and enTitleFor(id, log))
        tr(_G.QuestInfoDescriptionText, id, "description")
        tr(_G.QuestInfoObjectivesText, id, "objectives")
        tr(_G.QuestInfoRewardText, id, "completion")
        objectiveLines()
        for _, n in ipairs({ "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader", "QuestInfoSpellObjectiveLearnLabel",
                             "QuestInfoRequiredMoneyText", "QuestInfoGroupSize", "QuestInfoQuestType" }) do
            if _G[n] then K.Label(_G[n]) end
        end
        rewards()
    end)
    -- QUEST_ITEM_UPDATE перемальовує лише нагороди (виклик через глобальне ім'я)
    if QuestInfo_ShowRewards then
        hooksecurefunc("QuestInfo_ShowRewards", function() if U.Enabled() then rewards() end end)
    end
end)

-- ── вікно прогресу ─────────────────────────────────────────────────────────────────────────────────────────
local function progressItems()
    for i = 1, (_G.MAX_REQUIRED_ITEMS or 6) do
        local b, fs = _G["QuestProgressItem" .. i], _G["QuestProgressItem" .. i .. "Name"]
        if b and fs and b:IsShown() then
            local en, ua = K.text(fs), nil
            if en and b.objectType == "currency" and C_QuestOffer and C_QuestOffer.GetQuestRequiredCurrencyInfo then
                local c = C_QuestOffer.GetQuestRequiredCurrencyInfo(b:GetID())
                ua = c and c.currencyID and U.ID("currency", c.currencyID, "name")
            elseif en and GetQuestItemInfo then
                local itemID = select(6, GetQuestItemInfo("required", b:GetID()))
                ua = itemID and U.ID("item", itemID, "name")
            end
            if ua then U.Apply(fs, ua, en) end
        end
    end
    K.Label(_G.QuestProgressRequiredItemsText)
    K.Label(_G.QuestProgressRequiredMoneyText)
end

U.Surface("quest-progress", function()
    if _G.QuestProgressTitleText then
        K.HookText(_G.QuestProgressTitleText, function(_, text)
            local id = npcQuestID()
            local ua = K.QuestTitle(id)
            if not ua then U.Miss("quest", "quest:title", text, id) end
            return ua
        end)
    end
    if _G.QuestProgressText then
        K.HookText(_G.QuestProgressText, function(_, text)
            local id = npcQuestID()
            local ua = (id and U.ID("quest", id, "progress")) or K.T("questui", text)
            if not ua then U.Miss("quest", "quest:progress", text, id) end
            return ua
        end)
    end
    if QuestFrameProgressItems_Update then
        hooksecurefunc("QuestFrameProgressItems_Update", function() if U.Enabled() then progressItems() end end)
    end
end)

-- ── список квестів NPC (кілька квестів в одного NPC) ─────────────────────────────────────────────────────────
local function greetingPanel()
    if not U.Enabled() then return end
    local p = _G.QuestFrameGreetingPanel
    K.Label(_G.CurrentQuestsText)
    K.Label(_G.AvailableQuestsText)
    if not (p and p.titleButtonPool) then return end
    for b in p.titleButtonPool:EnumerateActive() do
        local fs = b.GetFontString and b:GetFontString()
        local full = K.text(fs)
        local i, id, en = b:GetID(), nil, nil
        if full and i then
            if b.isActive == 1 then
                id = GetActiveQuestID and GetActiveQuestID(i)
                en = GetActiveTitle and GetActiveTitle(i)
            else
                id = GetAvailableQuestInfo and select(5, GetAvailableQuestInfo(i))
                en = GetAvailableTitle and GetAvailableTitle(i)
            end
            local ua = K.QuestTitle(id)
            if ua then
                U.Apply(fs, K.Swap(full, en, ua) or ua, full)
                if not K.inCombat() and b.Icon then
                    b:SetHeight(math.max(b:GetTextHeight() + 2, b.Icon:GetHeight()))
                end
            elseif en then
                U.Miss("quest", "quest:title", en, id)
            end
        end
    end
end

U.Surface("quest-greeting", function()
    local p = _G.QuestFrameGreetingPanel
    if p and p.HookScript then p:HookScript("OnShow", greetingPanel) end
    if QuestFrameGreetingPanel_OnShow then hooksecurefunc("QuestFrameGreetingPanel_OnShow", greetingPanel) end
    if _G.GreetingText then
        K.HookText(_G.GreetingText, function(_, text)
            local who = UnitName and UnitName("questnpc")
            local ua = K.Tany({ "dialog", "questui" }, text, who)
            if not ua then U.Miss("dialog", "quest-greeting", text, nil, who) end
            return ua
        end)
    end
end)

-- ── портрет NPC біля вікна квесту ──────────────────────────────────────────────────────────────────────────
U.Surface("quest-portrait", function()
    if not QuestFrame_ShowQuestPortrait then return end
    hooksecurefunc("QuestFrame_ShowQuestPortrait", function(parent)
        if not U.Enabled() then return end
        local npc = parent == _G.QuestFrame
        local id = npc and npcQuestID() or (C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest())
        if not id or id == 0 then return end
        local turnIn = npc and _G.QuestFrameRewardPanel and _G.QuestFrameRewardPanel:IsShown()
        local tf, nf = _G.QuestNPCModelText, _G.QuestNPCModelNameText
        local en, ua = K.text(tf), U.ID("quest", id, turnIn and "portraitTurnInText" or "portraitGiverText")
        if en and ua then U.Apply(tf, ua, en) end
        en = K.text(nf)
        ua = en and (U.ID("quest", id, turnIn and "portraitTurnInName" or "portraitGiverName") or U.TranslateName(en))
        if en and ua then U.Apply(nf, ua, en) end
    end)
end)

-- ── статичні кнопки вікна квесту й деталей журналу ───────────────────────────────────────────────────────────
local BUTTONS = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton",
                  "QuestFrameCompleteQuestButton", "QuestFrameGoodbyeButton", "QuestFrameGreetingGoodbyeButton" }

local function buttonLabel(b)
    local fs = b and b.GetFontString and b:GetFontString()
    if fs then K.Label(fs) end
end

U.Surface("quest-buttons", function()
    if not U.Settings.enabled then return end
    for _, n in ipairs(BUTTONS) do buttonLabel(_G[n]) end
    local function details()
        if not U.Settings.enabled then return end
        for _, f in ipairs({ _G.QuestMapFrame and _G.QuestMapFrame.DetailsFrame, _G.QuestLogPopupDetailFrame }) do
            if f then
                for _, k in ipairs({ "TrackButton", "AbandonButton", "ShareButton", "BackFrame" }) do
                    local b = f[k]
                    if b and b.BackButton then b = b.BackButton end
                    buttonLabel(b)
                end
            end
        end
    end
    if QuestMapFrame_UpdateQuestDetailsButtons then hooksecurefunc("QuestMapFrame_UpdateQuestDetailsButtons", details) end
    details()
end)
