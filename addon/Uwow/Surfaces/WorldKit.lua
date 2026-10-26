-- Uwow · Surfaces/WorldKit.lua — спільні помічники поверхонь світу (квести, трекер, мапа, тексти NPC).
-- Тут немає власних хуків: лише функції, якими користуються World*.lua, Quest.lua, Gossip.lua, Chat.lua.
-- Таблиця живе в U.WK (поле UWOW, не глобал).
local U = UWOW
local K = {}
U.WK = K

-- Midnight: «секретні» значення не можна порівнювати — будь-яка операція кидає помилку.
function K.secret(v)
    if v == nil then return false end
    local ok = pcall(function() return v == "" end)
    return not ok
end

-- Текст напису, якщо він звичайний рядок (не секрет, не порожній).
function K.text(fs)
    if not fs or not fs.GetText then return nil end
    local ok, t = pcall(fs.GetText, fs)
    if not ok or type(t) ~= "string" or t == "" or K.secret(t) then return nil end
    return t
end

local function inCombat() return InCombatLockdown and InCombatLockdown() end
K.inCombat = inCombat

-- Пошук тексту (лише переклад, без хешу промаху). Буквальні «\n» в EN сховища розекрановує compile.py.
function K.T(dom, text, speaker)
    return (U.T(dom, text, speaker))
end

-- Перший влучний домен зі списку.
function K.Tany(doms, text, speaker)
    for _, d in ipairs(doms) do
        local ua = K.T(d, text, speaker)
        if ua then return ua, d end
    end
end

-- Підставити аргументи в UA-шаблон: {a1} {a2} … за номером, {a} — по черзі; {#} — числа по черзі.
function K.Fill(ua, args, nums)
    if type(ua) ~= "string" then return nil end
    local k = 0
    ua = ua:gsub("{a(%d*)}", function(n)
        if n ~= "" then return args[tonumber(n)] or "" end
        k = k + 1
        return args[k] or ""
    end)
    if nums then
        local j = 0
        ua = ua:gsub("{#}", function() j = j + 1; return nums[j] or "" end)
    end
    return ua
end

-- Шаблон GlobalStrings («Quest accepted: %s») → Lua-патерн із захопленнями (кеш).
-- Другим значенням — типи захоплень по порядку: { "s", "d", … }.
local pcache, tcache = {}, {}
function K.Pattern(fmt)
    local p = pcache[fmt]
    if p ~= nil then return p, tcache[fmt] end
    if type(fmt) ~= "string" then return false end
    local types = {}
    local s = fmt:gsub("%%%d+%$([sd])", "%%%1")                             -- %1$s → %s
    s = s:gsub("%%([sd])", function(c) types[#types + 1] = c; return c == "s" and "\1" or "\2" end)
    s = s:gsub("%%%%", "%%")                                                -- %% → %
    s = s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    s = s:gsub("\1", "(.-)"):gsub("\2", "(%%d+)")
    p = "^" .. s .. "$"
    pcache[fmt], tcache[fmt] = p, types
    return p, types
end

-- Розібрати рядок за шаблоном GlobalStrings і зібрати UA: argfn(i, value, type) перекладає аргумент (або nil).
function K.Template(fmt, text, argfn)
    local p, types = K.Pattern(fmt)
    if not p then return nil end
    local caps = { text:match(p) }
    if #caps == 0 then return nil end
    local tpl = U.T("ui", fmt)
    if not tpl then return nil end
    local s, d = {}, {}
    for i, v in ipairs(caps) do
        if types[i] == "d" then d[#d + 1] = v
        else s[#s + 1] = (argfn and argfn(#s + 1, v)) or v end
    end
    return K.Fill(tpl, s, d)
end

-- Замінити в повному тексті EN-фрагмент (звичайний пошук, без патернів) на UA.
function K.Swap(full, en, ua)
    if type(full) ~= "string" or type(en) ~= "string" or en == "" or not ua then return nil end
    local a, b = full:find(en, 1, true)
    if not a then return nil end
    return full:sub(1, a - 1) .. ua .. full:sub(b + 1)
end

-- Назва квесту за ID.
function K.QuestTitle(id)
    id = tonumber(id)
    return id and id > 0 and U.ID("quest", id, "title") or nil
end

-- ── цілі квестів: «0/8 Cragbound Fox slain», «Wolf Pelt: 3/10», «45% Area cleared», «X (Optional)» ──────────
local function tbase(base)
    return K.Tany({ "questui", "ui" }, base)
end

local SUFFIX_KEYS = { "Complete", "Optional", "Failed" }
local suffixUA
local function suffixes()
    if suffixUA then return suffixUA end
    suffixUA = {}
    for _, en in ipairs(SUFFIX_KEYS) do
        local ua = U.T("ui", en)
        if ua then suffixUA[en] = ua end
    end
    return suffixUA
end

function K.Objective(text)
    if type(text) ~= "string" or text == "" or K.secret(text) or text:find("[\208\209\210]") then return nil end
    local ua = U.T("questui", text)
    if ua then return ua end
    local dash, rest = text:match("^(%- )(.+)$")
    if dash then
        ua = K.Objective(rest)
        return ua and dash .. ua or nil
    end
    -- «… (Complete)» / «… (Optional)»
    local base, suf = text:match("^(.-) %(([^%(%)]+)%)$")
    if base and suffixes()[suf] then
        local b = K.Objective(base)
        return b and ("%s (%s)"):format(b, suffixUA[suf]) or nil
    end
    local cnt
    cnt, base = text:match("^(%d+/%d+) (.+)$")
    if cnt then ua = tbase(base); return ua and (cnt .. " " .. ua) or nil end
    base, cnt = text:match("^(.+): (%d+/%d+)$")
    if base then ua = tbase(base); return ua and (ua .. ": " .. cnt) or nil end
    cnt, base = text:match("^(%d+%%) (.+)$")
    if cnt then ua = tbase(base); return ua and (cnt .. " " .. ua) or nil end
    base, cnt = text:match("^(.+) %((%d+%%)%)$")
    if base then ua = tbase(base); return ua and (ua .. " (" .. cnt .. ")") or nil end
    return U.T("ui", text)
end

-- ── застосування з урахуванням розміру ────────────────────────────────────────────────────────────────────
-- Геометрію Blizzard-фреймів не чіпаємо (трекер і журнал входять у керовані контейнери UIParent). Якщо UA
-- виходить вищим за EN у тому самому написі, трохи зменшуємо масштаб тексту (SetTextScale — властивість напису,
-- не фрейму); не влазить і при 0.8 — обрізаємо до кількості рядків оригіналу (MaxLines), щоб не налазити на
-- сусідній рядок. Масштаб скидаємо при кожному наступному застосуванні.
local scaled = setmetatable({}, { __mode = "k" })

local function lineCount(fs, h)
    local lh = select(2, pcall(fs.GetLineHeight, fs))
    if type(lh) ~= "number" or lh <= 0 then return nil end
    return math.max(1, math.floor(h / lh + 0.5))
end

function K.Fit(fs, ua, en)
    if not fs or not ua or ua == en then return end
    if scaled[fs] and fs.SetTextScale then pcall(fs.SetTextScale, fs, 1); scaled[fs] = nil end
    local ok, h0 = pcall(fs.GetStringHeight, fs)
    U.Apply(fs, ua, en)
    if not ok or type(h0) ~= "number" or h0 <= 0 or (U.Settings and U.Settings.original) then return end
    local ok2, h1 = pcall(fs.GetStringHeight, fs)
    if not ok2 or type(h1) ~= "number" or h1 <= h0 + 0.5 or not fs.SetTextScale then return end
    for _, s in ipairs({ 0.92, 0.85, 0.8 }) do
        pcall(fs.SetTextScale, fs, s); scaled[fs] = true
        local _, h = pcall(fs.GetStringHeight, fs)
        if type(h) == "number" and h <= h0 + 0.5 then return end
    end
    local n = lineCount(fs, h0)
    if n and fs.SetMaxLines then pcall(fs.SetMaxLines, fs, n) end
end

-- ── хуки ───────────────────────────────────────────────────────────────────────────────────────────────────
local hooked = setmetatable({}, { __mode = "k" })
-- Один post-хук на метод об'єкта (екземпляра чи міксина), повторні виклики ігноруються.
function K.HookOnce(obj, method, fn)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return false end
    local h = hooked[obj]
    if not h then h = {}; hooked[obj] = h end
    if h[method] then return true end
    h[method] = true
    hooksecurefunc(obj, method, fn)
    return true
end

-- Post-хук SetText конкретного напису з захистом від рекурсії: fn(fs, text) повертає UA або nil.
local busy = setmetatable({}, { __mode = "k" })
function K.HookText(fs, fn)
    return K.HookOnce(fs, "SetText", function(self, text)
        if busy[self] or not U.Enabled() or type(text) ~= "string" or text == "" or K.secret(text) then return end
        local ok, ua = pcall(fn, self, text)
        if not ok or not ua or ua == text then return end
        busy[self] = true
        U.Apply(self, ua, text)
        busy[self] = nil
    end)
end

-- Виконати fn, коли аддон Blizzard завантажено (LoadOnDemand), один раз.
local waiting, waiter = {}, nil
function K.OnAddon(name, fn)
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then return fn() end
    waiting[name] = waiting[name] or {}
    table.insert(waiting[name], fn)
    if not waiter then
        waiter = CreateFrame("Frame")
        waiter:RegisterEvent("ADDON_LOADED")
        waiter:SetScript("OnEvent", function(_, _, n)
            local list = waiting[n]
            if not list then return end
            waiting[n] = nil
            for _, f in ipairs(list) do pcall(f) end
        end)
    end
end

-- Обійти написи фрейму (рекурсивно, з обмеженням глибини) і для кожного викликати fn(fs, text).
function K.Walk(frame, fn, depth)
    depth = depth or 0
    if not frame or depth > 8 then return end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" and r:IsShown() then
                local t = K.text(r)
                if t then fn(r, t) end
            end
        end
    end
    if frame.GetChildren then
        for _, c in ipairs({ frame:GetChildren() }) do
            if c.IsShown and c:IsShown() then K.Walk(c, fn, depth + 1) end
        end
    end
end

-- Статичний напис UI (GlobalStrings): U.T("ui") з фолбеком на questui.
function K.Label(fs)
    local en = K.text(fs)
    if not en then return end
    local ua = K.Tany({ "ui", "questui" }, en)
    if ua then U.Apply(fs, ua, en) end
end
