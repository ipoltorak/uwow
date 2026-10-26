-- Uwow · Surfaces/CharKit.lua — спільні дрібниці поверхонь персонажа (закляття, предмети, професії, економіка):
-- безпечне читання напису, переклад напису за текстом або ID, хук міксина/методу, очікування LoD-аддона Blizzard,
-- переклад форматного рядка, кириличні великі літери. Глобалів не пише: усе в U.CharKit.
local U = UWOW
local K = {}
U.CharKit = K

-- ── значення ───────────────────────────────────────────────────────────────────────────────────────────
function K.secret(v)                         -- Midnight: «секретні» значення не можна порівнювати
    return not pcall(function() return v == "" end)
end

function K.cyr(s) return type(s) == "string" and s:find("[\208\209\210]") ~= nil end

-- Текст напису або nil (порожній, секретний, недоступний).
function K.text(fs)
    if type(fs) ~= "table" or not fs.GetText then return nil end
    local ok, t = pcall(fs.GetText, fs)
    if not ok or type(t) ~= "string" or K.secret(t) or t == "" then return nil end
    return t
end

-- Перенести на переклад обгортку оригіналу: відступ на початку і колір |cXXXXXXXX…|r, якщо переклад їх не має.
function K.wrap(en, ua)
    if type(ua) ~= "string" then return nil end
    local lead, core = en:match("^(%s*)(.-)$")
    local c = core:match("^(|c%x%x%x%x%x%x%x%x)") or core:match("^(|cn[%w_]+:)")
    if c and core:sub(-2) == "|r" and not ua:find("|c", 1, true) then ua = c .. ua .. "|r" end
    if lead ~= "" and not ua:find("^%s") then ua = lead .. ua end
    return ua
end

-- Поставити переклад на напис (з обгорткою оригіналу). true, якщо щось змінилось.
function K.set(fs, ua, en)
    if not ua or ua == en then return false end
    U.Apply(fs, K.wrap(en, ua), en)
    return true
end

-- Переклад напису за його текстом: домен(и) по черзі; промах — у збір (якщо surf задано).
-- doms: рядок або список; перший домен — домен промаху.
function K.label(fs, surf, doms, maxMiss)
    local en = K.text(fs)
    if not en or K.cyr(en) then return false end
    doms = type(doms) == "table" and doms or { doms or "ui" }
    for _, d in ipairs(doms) do
        local ua = U.T(d, en)
        if ua then return K.set(fs, ua, en) end
    end
    if surf and #en <= (maxMiss or 120) then U.Miss(doms[1], surf, en) end
    return false
end

-- Те саме для рядка (без напису): переклад або nil.
function K.str(en, doms)
    if type(en) ~= "string" or en == "" or K.cyr(en) or K.secret(en) then return nil end
    doms = type(doms) == "table" and doms or { doms or "ui" }
    for _, d in ipairs(doms) do
        local ua = U.T(d, en)
        if ua then return ua end
    end
end

-- Напис за ID (домен item/spell/currency/faction…); промах — у збір із ID.
function K.byID(fs, dom, id, field, surf)
    local en = K.text(fs)
    if not en or K.cyr(en) or not id or K.secret(id) then return false end
    local ua = U.ID(dom, id, field)
    if ua then return K.set(fs, ua, en) end
    if surf then U.Miss(dom, surf, en, id) end
    return false
end

function K.itemName(id) return id and not K.secret(id) and U.ID("item", id, "name") or nil end
function K.spellName(id) return id and not K.secret(id) and U.ID("spell", id, "name") or nil end

-- itemID із посилання на предмет
function K.linkID(link)
    if type(link) ~= "string" or K.secret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- ── форматні рядки ─────────────────────────────────────────────────────────────────────────────────────
-- Переклад форматного рядка Blizzard (GlobalStrings) і підстановка аргументів: у даних %s → {a}, %d → {#},
-- %1$s → {a1}. Позиційні беремо за номером, решту — по черзі. nil, якщо формату немає в даних.
function K.fmt(fmtEN, ...)
    if type(fmtEN) ~= "string" then return nil end
    local ua = U.T("ui", fmtEN)
    if not ua then return nil end
    local args, k = { ... }, 0
    ua = ua:gsub("{([a#])(%d*)}", function(_, n)
        if n ~= "" then return tostring(args[tonumber(n)] or "") end
        k = k + 1
        return tostring(args[k] or "")
    end)
    return ua
end

-- Шаблон Lua з форматного рядка: "Keystone: %s" → "^Keystone: (.-)$"
function K.fmtPattern(fmtEN)
    if type(fmtEN) ~= "string" then return nil end
    local p = fmtEN:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("%%%%%d?%$?[sd]", "(.-)")
    return "^" .. p .. "$"
end

-- ── великі літери з кирилицею (string.upper її не знає) ────────────────────────────────────────────────
local UP = { ["\209\150"] = "\208\134", ["\209\151"] = "\208\135", ["\209\148"] = "\208\132", ["\210\145"] = "\210\144" }
function K.upper(s)
    s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end)
    s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("[\209\210][\128-\191]", function(c) return UP[c] end)
    return s:upper()
end

local LOW = { ["\208\134"] = "\209\150", ["\208\135"] = "\209\151", ["\208\132"] = "\209\148", ["\210\144"] = "\210\145" }
function K.lower(s)
    s = s:gsub("\208([\144-\175])", function(c)
        local b = c:byte()
        if b < 160 then return "\208" .. string.char(b + 32) end
        return "\209" .. string.char(b - 32)
    end)
    s = s:gsub("[\208\210][\128-\191]", function(c) return LOW[c] end)
    return s:lower()
end

-- ── хуки ───────────────────────────────────────────────────────────────────────────────────────────────
K.errors = {}
local function guard(name, fn)
    return function(...)
        if not U.Enabled() then return end
        local ok, err = pcall(fn, ...)
        if not ok then K.errors[name] = tostring(err) end
    end
end
K.guard = guard

-- hooksecurefunc на метод таблиці (міксин або конкретний фрейм), якщо метод існує. Один раз на пару.
local hooked = setmetatable({}, { __mode = "k" })
function K.hook(t, method, fn, name)
    if type(t) ~= "table" or type(t[method]) ~= "function" then return false end
    local h = hooked[t]
    if not h then h = {}; hooked[t] = h end
    if h[method] then return true end
    h[method] = true
    hooksecurefunc(t, method, guard(name or method, fn))
    return true
end

-- hooksecurefunc на глобальну функцію Blizzard, якщо вона є.
local hookedG = {}
function K.hookG(fname, fn)
    if hookedG[fname] or type(_G[fname]) ~= "function" then return false end
    hookedG[fname] = true
    hooksecurefunc(fname, guard(fname, fn))
    return true
end

-- Виконати fn, коли завантажиться аддон Blizzard (одразу, якщо вже завантажений).
local waiting = {}
local loader
function K.onAddon(name, fn)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
    if loaded then
        local ok, err = pcall(fn)
        if not ok then K.errors["load:" .. name] = tostring(err) end
        return
    end
    if not loader then
        loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(_, _, a)
            local list = waiting[a]
            if not list then return end
            waiting[a] = nil
            for _, f in ipairs(list) do
                local ok, err = pcall(f)
                if not ok then K.errors["load:" .. a] = tostring(err) end
            end
        end)
    end
    waiting[name] = waiting[name] or {}
    table.insert(waiting[name], fn)
end
K.waiting = waiting

-- Читання поля фрейму без помилки на заборонених об'єктах.
function K.forbidden(f)
    return type(f) ~= "table" or (f.IsForbidden and f:IsForbidden())
end
