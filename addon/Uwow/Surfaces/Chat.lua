-- Uwow · Surfaces/Chat.lua — чат і репліки: NPC у чаті (say/yell/emote/whisper, емоції босів), «говоряча голова»,
-- текстові емоції (/wave тощо), системні повідомлення про квести й відкриття, власний лут і валюта, назви в
-- посиланнях (квест, предмет, валюта, закляття, досягнення). Усе — через фільтри подій чату (заміна рядка перед
-- показом), без підміни методів фрейму чату.
local U = UWOW
local K = U.WK

-- 12.x: фільтри живуть у ChatFrameUtil; глобальна ChatFrame_AddMessageEventFilter — лише в Deprecated-аддоні.
local function addFilter(event, fn)
    local f = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if f then f(event, fn) end
    return f ~= nil
end

local function plain(v) return type(v) == "string" and v ~= "" and not K.secret(v) end

-- ── назви в посиланнях |Htype:id…|h[Назва]|h ─────────────────────────────────────────────────────────────────
local LINK = {
    quest = function(id) return K.QuestTitle(id) end,
    item = function(id) return U.ID("item", id, "name") end,
    currency = function(id) return U.ID("currency", id, "name") end,
    spell = function(id) return U.ID("spell", id, "name") end,
    achievement = function(id) return U.ID("ach", id, "name") end,
}

function K.Links(msg)
    if not msg:find("|H", 1, true) then return msg end
    return (msg:gsub("(|H(%a+):(%d+)([^|]*)|h)%[(.-)%](|h)", function(head, kind, id, _, name, tail)
        local f = LINK[kind]
        local ua = f and f(tonumber(id))
        if not ua then return nil end
        -- предмети з якістю: «[Назва |A:…|a]» — лишаємо хвіст розмітки
        local mark = name:match("(%s*|A.-|a)$") or ""
        return head .. "[" .. ua .. mark .. "]" .. tail
    end))
end

-- ── NPC у чаті ─────────────────────────────────────────────────────────────────────────────────────────────
local NPC_EVENTS = { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_WHISPER",
                     "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_RAID_BOSS_WHISPER" }

local function npcFilter(_, _, msg, sender, ...)
    if not U.Enabled() or not plain(msg) or K.secret(sender) then return false end
    local ua = K.T("dialog", msg, sender)
    if not ua then U.Miss("dialog", "chat", msg, nil, sender); return false end
    return false, ua, U.TranslateName(sender) or sender, ...
end

U.Surface("chat-npc", function()
    for _, e in ipairs(NPC_EVENTS) do addFilter(e, npcFilter) end
end)

-- ── бабли над головами NPC ───────────────────────────────────────────────────────────────────────────────────
-- Без OnUpdate/тікера: подія репліки → C_Timer.After(0) (бабл створюється наступним кадром) → C_ChatBubbles.
-- GetAllChatBubbles(false) → бабл із тим самим текстом отримує переклад; не знайшли — ще одна спроба через 0,1 с.
-- includeForbidden = false: у підземеллях і рейдах бабли «заборонені» (forbidden) і в список не потрапляють —
-- там нічого не робимо; секретні репліки відсіюються ще до пошуку. API є в 12.x
-- (Blizzard_APIDocumentationGenerated/ChatBubblesDocumentation.lua; аргумент — звичайний false, не секрет).
-- Бабл — фрейм світу, не захищений; напис — дитина з полем String (ChatBubbleTemplate, Blizzard_ChatBubble).
local BUBBLE_EVENTS = { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY" }
local BUBBLE_MAX_W = 300
local pendingBubbles, scheduled = {}, false

local function bubbleString(b)
    if type(b) ~= "table" then return nil end
    if b.String then return b.String end
    for _, c in ipairs({ b:GetChildren() }) do
        if type(c) == "table" and c.String then return c.String end
    end
end

local function scanBubbles()
    if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then return end
    local ok, list = pcall(C_ChatBubbles.GetAllChatBubbles, false)
    if not ok or type(list) ~= "table" then return end
    for _, b in ipairs(list) do
        local fs = bubbleString(b)
        local en = K.text(fs)
        local ua = en and pendingBubbles[en]
        if ua then
            pendingBubbles[en] = nil
            U.Apply(fs, ua, en)
            if not (U.Settings and U.Settings.original) and fs.GetUnboundedStringWidth then
                local okw, w = pcall(fs.GetWidth, fs)
                local oku, u = pcall(fs.GetUnboundedStringWidth, fs)
                if okw and oku and type(w) == "number" and type(u) == "number" and u > w + 1 then
                    pcall(fs.SetWidth, fs, math.min(u + 1, math.max(w, BUBBLE_MAX_W)))
                end
            end
        end
    end
end

local function onBubbleEvent(_, _, msg, sender)
    if not U.Enabled() or not plain(msg) or K.secret(sender) then return end
    if IsInInstance and IsInInstance() then return end
    local ua = K.T("dialog", msg, sender)
    if not ua then return end
    pendingBubbles[msg] = ua
    if scheduled then return end
    scheduled = true
    C_Timer.After(0, function()
        scanBubbles()
        if next(pendingBubbles) == nil then scheduled = false return end
        C_Timer.After(0.1, function()
            scanBubbles()
            pendingBubbles, scheduled = {}, false
        end)
    end)
end

U.Surface("chat-bubbles", function()
    if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then return end
    local f = CreateFrame("Frame")
    for _, e in ipairs(BUBBLE_EVENTS) do f:RegisterEvent(e) end
    f:SetScript("OnEvent", onBubbleEvent)
end)

-- ── говоряча голова ────────────────────────────────────────────────────────────────────────────────────────
-- Перший рядок ставиться в Reset(), наступні того самого мовця — таймером через 0,25 с. Хук SetText самих
-- написів ловить обидва шляхи.
local function headSpeaker()
    if not (C_TalkingHead and C_TalkingHead.GetCurrentLineInfo) then return nil end
    local name = select(7, C_TalkingHead.GetCurrentLineInfo())
    return plain(name) and name or nil
end

local function hookTalkingHead()
    local th = _G.TalkingHeadFrame
    local fs = th and th.TextFrame and th.TextFrame.Text
    local nf = th and th.NameFrame and th.NameFrame.Name
    if not fs then return false end
    K.HookText(fs, function(_, text)
        local who = headSpeaker()
        local ua = K.T("dialog", text, who)
        if not ua then U.Miss("dialog", "talking-head", text, nil, who) end
        return ua
    end)
    if nf then K.HookText(nf, function(_, text) return U.TranslateName(text) end) end
    return true
end

U.Surface("talking-head", function()
    if not hookTalkingHead() then K.OnAddon("Blizzard_TalkingHeadUI", hookTalkingHead) end
end)

-- ── текстові емоції ────────────────────────────────────────────────────────────────────────────────────────
-- «Bob waves at you.»: ім'я мовця нормалізація заміняє на {a}, ключ збігається з «%s waves at you.».
local function emoteFilter(_, _, msg, sender, ...)
    if not U.Enabled() or not plain(msg) or K.secret(sender) then return false end
    local ua = K.T("dialog", msg, sender)
    if not ua then return false end
    return false, ua, sender, ...
end

-- ── системні повідомлення ──────────────────────────────────────────────────────────────────────────────────
-- Назви квестів у системних рядках: questID із подій і журналу → назва.
local titleToID = {}
local function noteQuest(id)
    local t = id and C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if plain(t) then titleToID[t] = id end
end

local function questByTitle(t)
    local id = titleToID[t]
    if id then return id end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.title == t then titleToID[t] = info.questID; return info.questID end
        end
    end
end

local function questArg(_, v) local id = questByTitle(v); return id and K.QuestTitle(id) end
local function nameArg(_, v) return K.Tany({ "ui", "names" }, v) or U.TranslateName(v) end

local SYSTEM = {
    { "ERR_QUEST_ACCEPTED_S", questArg }, { "ERR_QUEST_COMPLETE_S", questArg }, { "ERR_QUEST_FAILED_S", questArg },
    { "ERR_QUEST_REWARD_EXP_I" }, { "ERR_ZONE_EXPLORED", nameArg }, { "ERR_ZONE_EXPLORED_XP", nameArg },
    { "ERR_NEWTAXIPATH" }, { "ERR_QUEST_OBJECTIVE_COMPLETE_S", function(_, v) return K.Objective(v) end },
}

local LOOT = { "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
               "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE", "CURRENCY_GAINED", "CURRENCY_GAINED_MULTIPLE",
               "CURRENCY_GAINED_MULTIPLE_BONUS", "LOOT_ITEM_REFUND", "LOOT_ITEM_REFUND_MULTIPLE" }

local function byTemplates(list, msg)
    for _, e in ipairs(list) do
        local g, argfn = e, nil
        if type(e) == "table" then g, argfn = e[1], e[2] end
        local fmt = _G[g]
        if type(fmt) == "string" then
            local ua = K.Template(fmt, msg, argfn)
            if ua then return ua end
        end
    end
end

local function systemFilter(_, _, msg, ...)
    if not U.Enabled() or not plain(msg) then return false end
    local ua = U.T("ui", msg) or byTemplates(SYSTEM, msg)
    if not ua then
        local l = K.Links(msg)
        if l ~= msg then return false, l, ... end
        return false
    end
    return false, K.Links(ua), ...
end

local function lootFilter(_, _, msg, ...)
    if not U.Enabled() or not plain(msg) then return false end
    local linked = K.Links(msg)
    local ua = byTemplates(LOOT, linked)
    if ua then return false, ua, ... end
    if linked ~= msg then return false, linked, ... end
    return false
end

-- Посилання на квести й предмети в розмовах гравців: лише назва всередині [ ], текст гравця не чіпаємо.
local function linkFilter(_, _, msg, ...)
    if not U.Enabled() or not plain(msg) or not msg:find("|H", 1, true) then return false end
    local l = K.Links(msg)
    if l ~= msg then return false, l, ... end
    return false
end

local PLAYER_CHAT = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
                      "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD",
                      "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
                      "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }

U.Surface("chat-system", function()
    if not addFilter("CHAT_MSG_TEXT_EMOTE", emoteFilter) then return end
    addFilter("CHAT_MSG_SYSTEM", systemFilter)
    addFilter("CHAT_MSG_LOOT", lootFilter)
    addFilter("CHAT_MSG_CURRENCY", lootFilter)
    for _, e in ipairs(PLAYER_CHAT) do addFilter(e, linkFilter) end
    local f = CreateFrame("Frame")
    f:RegisterEvent("QUEST_ACCEPTED")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("QUEST_REMOVED")
    f:SetScript("OnEvent", function(_, _, id) noteQuest(id) end)
end)
