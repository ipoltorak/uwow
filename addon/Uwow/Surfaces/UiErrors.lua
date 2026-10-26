-- Uwow · Surfaces/UiErrors.lua — повідомлення в центрі екрана (UIErrorsFrame, Blizzard_UIErrorsFrame):
-- червоні помилки UI_ERROR_MESSAGE і жовті UI_INFO_MESSAGE. AddMessage не підміняємо: пост-хук
-- UIErrorsMixin:TryDisplayMessage (екземпляр UIErrorsFrame) бере щойно показаний рядок через GetFontStringByID(messageType)
-- і ставить переклад у сам напис. Шаблон — GlobalString за GetGameMessageInfo(messageType) («Quest accepted: %s»):
-- аргументи розбираємо з показаного тексту, назви квестів і цілей перекладаємо окремо.
-- CheckAddMessage з ідентифікатором (AddExternalErrorMessage/AddExternalWarningMessage) — той самий шлях.
local U = UWOW

local questTitles, questScan = {}, -1000
local function questTitle(name)                         -- EN-назва квесту з журналу → UA (ID-домен quest)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return nil end
    local id = questTitles[name]
    local now = GetTime and GetTime() or 0
    if not id and now - questScan > 2 then
        questScan = now
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local q = C_QuestLog.GetInfo(i)
            if q and not q.isHeader and type(q.title) == "string" and q.questID then questTitles[q.title] = q.questID end
        end
        id = questTitles[name]
    end
    return id and U.ID("quest", id, "title")
end

local function argT(a)
    if U.IsSecret(a) or a:find("|H", 1, true) then return nil end                -- лінки (предмет, закляття) не чіпаємо
    return U.T("questui", a) or questTitle(a) or U.TranslateName(a) or U.T("ui", a)
end

local function templateFor(messageType)
    if not GetGameMessageInfo or type(messageType) ~= "number" then return nil end
    local ok, name = pcall(GetGameMessageInfo, messageType)
    if not ok or type(name) ~= "string" then return nil end
    local fmt = rawget(_G, name)
    return type(fmt) == "string" and fmt or nil, name
end

local function translate(frame, messageType, message)
    if not U.Enabled() or type(message) ~= "string" or U.IsSecret(message) or U.IsSecret(messageType) then return end
    if not frame.GetFontStringByID then return end
    local ok, fs = pcall(frame.GetFontStringByID, frame, messageType)
    if not ok or not fs then return end
    local en = U.GetText(fs)
    if en ~= message then return end                                            -- рядок не показано (чорний список)
    local fmt, gsName = templateFor(messageType)
    local ua = U.T("ui", en)
    if not ua and fmt then
        local args = U.Unformat(fmt, en)
        if args then ua = U.Fmt("ui", fmt, args, argT) end
    end
    if not ua then                                                               -- «Ціль: 3/6» без шаблону
        local obj, a, b = en:match("^(.-):%s*(%d+)%s*/%s*(%d+)$")
        local uo = obj and argT(obj)
        if uo then ua = ("%s: %s/%s"):format(uo, a, b) end
    end
    if ua then U.Apply(fs, ua, en); return end
    local key = (fmt and U.Unformat(fmt, en)) and fmt or en
    if key == "%s" then key = en end
    U.Miss("ui", "ui-error", key, gsName)
end

U.Surface("ui-errors", function()
    local f = UIErrorsFrame
    if not (f and f.TryDisplayMessage) then return end
    hooksecurefunc(f, "TryDisplayMessage", function(self, messageType, message) translate(self, messageType, message) end)
    if f.CheckAddMessage then
        hooksecurefunc(f, "CheckAddMessage", function(self, message, _, _, _, _, id)
            if id then translate(self, id, message) end
        end)
    end
end)
