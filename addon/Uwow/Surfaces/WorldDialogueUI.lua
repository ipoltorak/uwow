-- Uwow · Surfaces/WorldDialogueUI.lua — сумісність зі стороннім аддоном DialogueUI (YUI-Dialogue, Peterodox).
-- DialogueUI малює квести й розмови у власному вікні, тож хуки на фрейми Blizzard його не ловлять.
-- 1) Тексти квестів — через його публічний API DialogueUIAPI.SetTranslator{ name, font, questDataGetter }:
--    DialogueUI сам кличе questDataGetter(questID) і показує наш текст (поля title/description/objective/
--    progress/completion). Тіло, якого в нас немає, віддаємо порожнім рядком: тоді DialogueUI лишає англійське
--    тіло, але назву й цілі показує українською (без назви переклад квесту він не вмикає взагалі).
-- 2) Кнопки варіантів розмови й назви квестів у списку NPC — post-хуки на міксин кнопки DialogueUI
--    (DUIDialogOptionButtonMixin.SetGossip / SetQuest), після чого ставимо текст його ж методом SetButtonText,
--    який перераховує розмір кнопки. Це код стороннього аддона, не Blizzard — taint тут ні до чого не веде.
local U = UWOW
local K = U.WK

local FONT = "Fonts\\FRIZQT___CYR.TTF"

local function questData(questID)
    if not U.Enabled() then return nil end
    local id = tonumber(questID)
    if not id then return nil end
    local title = U.ID("quest", id, "title")
    if not title then return nil end
    return {
        title = title,
        description = U.ID("quest", id, "description") or "",
        objective = U.ID("quest", id, "objectives") or "",
        progress = U.ID("quest", id, "progress") or "",
        completion = U.ID("quest", id, "completion") or "",
    }
end

local function setText(btn, en, ua, bigPadding)
    local fs = btn.Name
    local full = K.text(fs)
    if not full or not ua then return end
    local new = K.Swap(full, en, ua) or ua
    if U.Settings and U.Settings.original then return end
    if btn.SetButtonText then pcall(btn.SetButtonText, btn, new, bigPadding) else U.Apply(fs, new, full) end
end

local function onGossip(btn, data)
    if not U.Enabled() or type(data) ~= "table" or type(data.name) ~= "string" or K.secret(data.name) then return end
    local ua = K.T("dialog", data.name)
    if ua then setText(btn, data.name, ua, false) else U.Miss("dialog", "dui:gossip-option", data.name, data.gossipOptionID) end
end

local function onQuest(btn, info)
    if not U.Enabled() or type(info) ~= "table" then return end
    local ua = K.QuestTitle(info.questID)
    if ua and type(info.title) == "string" then setText(btn, info.title, ua, true) end
end

-- 3) Привітання NPC (gossip і список квестів NPC). DialogueUI ділить текст на абзаци (API.SplitParagraph:
--    послідовності без керівних символів, окрім одиночного пробілу) і кожен ставить окремим написом із пулу
--    DUIQuestFrame.fontStringPool: AcquireLeftFontString() → fs:SetText(абзац) → fs:GetHeight() (DialogueUI.lua,
--    FormatParagraph). Post-хук AcquireLeftFontString ставить хук SetText на щойно взятий напис — до того, як
--    DialogueUI покладе в нього текст, тож висота абзацу міряється вже з UA. Відповідність абзаців EN → UA
--    будуємо з повного тексту (C_GossipInfo.GetText / GetGreetingText): однакова кількість — один до одного,
--    інакше весь переклад іде в перший абзац, решта порожні. Ім'я NPC на початку («Ім'я: …») зберігаємо.
local function paragraphs(text)
    local t = {}
    for v in text:gmatch("[%C]+") do if v ~= " " then t[#t + 1] = v end end
    return t
end

local cache, ncache = {}, 0
local function paraMap(src, who)
    local m = cache[src]
    if m then return m end
    m = {}
    local ua = K.Tany({ "dialog", "questui" }, src, who)
    if ua then
        local en, tr = paragraphs(src), paragraphs(ua)
        if #en == #tr then
            for i, p in ipairs(en) do m[p] = tr[i] end
        elseif #en > 0 then
            m[en[1]] = table.concat(tr, "\n\n")
            for i = 2, #en do m[en[i]] = "" end
        end
    else
        U.Miss("dialog", "dui:greeting", src, nil, who)
    end
    if ncache > 20 then cache, ncache = {}, 0 end
    cache[src], ncache = m, ncache + 1
    return m
end

local function npc()
    local n = UnitName and UnitName("npc")
    return type(n) == "string" and not K.secret(n) and n or nil
end

local function paragraphUA(fs, text)
    if fs.isTranslation or text:find("[\208\209\210]") then return nil end
    local who = npc()
    local body, prefix = text, ""
    if who and text:sub(1, #who + 2) == who .. ": " then
        prefix, body = (U.TranslateName(who) or who) .. ": ", text:sub(#who + 3)
    end
    local srcs = { C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText(), GetGreetingText and GetGreetingText() }
    for i = 1, 2 do
        local src = srcs[i]
        if type(src) == "string" and src ~= "" and not K.secret(src) and src:find(body, 1, true) then
            local ua = paraMap(src, who)[body]
            if ua then return prefix .. ua end
        end
    end
end

local function hookParagraphs(self)
    local pool = self.fontStringPool
    if type(pool) ~= "table" or type(pool.objects) ~= "table" then return end
    for _, fs in ipairs(pool.objects) do K.HookText(fs, paragraphUA) end
end

local function install()
    local api = _G.DialogueUIAPI
    if type(api) == "table" and type(api.SetTranslator) == "function" then
        pcall(api.SetTranslator, { name = "Uwow", font = FONT, questDataGetter = questData })
    end
    local m = _G.DUIDialogOptionButtonMixin
    if type(m) == "table" then
        K.HookOnce(m, "SetGossip", onGossip)
        K.HookOnce(m, "SetQuest", onQuest)
    end
    local f = _G.DUIQuestFrame
    if type(f) == "table" and f.AcquireLeftFontString then
        K.HookOnce(f, "AcquireLeftFontString", hookParagraphs)
        hookParagraphs(f)
    end
end

U.Surface("dialogueui", function()
    K.OnAddon("DialogueUI", install)
end)
