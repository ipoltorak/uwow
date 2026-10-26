-- Uwow · Surfaces/CollKit.lua — спільні помічники поверхонь «досягнення, путівник, колекції, житло, гарнізон».
-- Нічого не перекладає сам. Дає: очікування LoD-аддонів Blizzard, колбек ScrollBox на ініціалізацію рядка,
-- «супровід» напису (hooksecurefunc на SetText конкретного FontString — переклад стає до того, як Blizzard
-- міряє висоту/ширину), пошук у кількох доменах, переклад рядка «Мітка: значення» і обхід статичних написів.
local U = UWOW
local K = {}
U.CollKit = K

-- ── значення ───────────────────────────────────────────────────────────────────────────────────────────
-- Midnight: «секретні» рядки не можна порівнювати; такі не чіпаємо.
function K.Str(v)
    if type(v) ~= "string" then return nil end
    local ok, empty = pcall(function() return v == "" end)
    if not ok or empty then return nil end
    return v
end

function K.Cyr(s) return s:find("[\208\209\210]") ~= nil end

function K.Text(fs)
    if not fs or not fs.GetText then return nil end
    local ok, t = pcall(fs.GetText, fs)
    return ok and K.Str(t) or nil
end

-- Обгортка оригіналу, яку дані не містять: колір «|cffxxxxxx…|r», хвіст «|n|n» (булети путівника).
function K.Wrap(en, ua)
    if not ua then return nil end
    local c = en:match("^(|c%x%x%x%x%x%x%x%x)")
    if c and not ua:find("|c", 1, true) and en:sub(-2) == "|r" then ua = c .. ua .. "|r" end
    local tail = en:match("(|n|n)$") or en:match("(\n\n)$")
    if tail and ua:sub(-#tail) ~= tail then ua = ua .. tail end
    return ua
end

-- Поставити переклад; ua == nil → промах у domain dom (якщо miss заданий).
function K.Put(fs, en, ua, dom, surf, id)
    if ua then U.Apply(fs, K.Wrap(en, ua), en); return true end
    if dom then U.Miss(dom, surf, en, id) end
    return false
end

-- ── пошук ──────────────────────────────────────────────────────────────────────────────────────────────
-- Текст у першому домені зі списку, де він є. U.T сам пробує інші домени лише для фраз, тому для
-- однослівних назв (категорії, зони, мітки) перелік доменів задаємо явно.
function K.Any(text, ...)
    text = K.Str(text)
    if not text or K.Cyr(text) then return nil end
    for i = 1, select("#", ...) do
        local ua = U.T((select(i, ...)), text)
        if ua then return ua end
    end
end

-- Рядок «Мітка: значення» (джерело маунта/іграшки/вихованця): цілком, а якщо ні — кожен рядок окремо,
-- мітку (з кольором) і значення окремо. Повертає переклад або nil, якщо не перекладено жодної частини.
local function segment(seg, doms)
    local ua = K.Any(seg, unpack(doms))
    if ua then return K.Wrap(seg, ua), true end
    local pre, label, post, value = seg:match("^(|c%x%x%x%x%x%x%x%x)(.-:)%s*(|r)%s*(.*)$")
    if not label then label, value = seg:match("^([^:|]+:)%s+(.+)$"); pre, post = "", "" end
    if not label then return seg, false end
    local l = K.Any(label, "ui")
    local v = K.Any(value, unpack(doms))
    if not l and not v then return seg, false end
    return pre .. (l or label) .. post .. " " .. (v or value), true
end

function K.Source(text, ...)
    text = K.Str(text)
    if not text or K.Cyr(text) then return nil end
    local doms = { ... }
    if #doms == 0 then doms = { "collections", "ui", "names" } end
    local whole = K.Any(text, unpack(doms))
    if whole then return K.Wrap(text, whole) end
    local parts, any, sep = {}, false, text:find("|n", 1, true) and "|n" or "\n"
    for seg in (text .. sep):gmatch("(.-)" .. (sep == "|n" and "|n" or "\n")) do
        local out, ok = segment(seg, doms)
        parts[#parts + 1] = out
        any = any or ok
    end
    return any and table.concat(parts, sep) or nil
end

-- ── підключення ────────────────────────────────────────────────────────────────────────────────────────
local waiting = {}
local evf = CreateFrame("Frame")
evf:RegisterEvent("ADDON_LOADED")
evf:SetScript("OnEvent", function(_, _, name)
    local list = waiting[name]
    if not list then return end
    waiting[name] = nil
    for _, fn in ipairs(list) do pcall(fn) end
end)

local function isLoaded(name)
    return C_AddOns and C_AddOns.IsAddOnLoaded and (C_AddOns.IsAddOnLoaded(name)) and true or false
end
K.IsLoaded = isLoaded

-- fn — коли LoD-аддон Blizzard (або сторонній) завантажено; якщо вже — одразу.
function K.OnAddon(name, fn)
    if isLoaded(name) then return fn() end
    waiting[name] = waiting[name] or {}
    table.insert(waiting[name], fn)
end

-- Колбек ScrollBox на кожен ініціалізований рядок (подія CallbackRegistry, викликається через
-- securecallfunction — без тейнту). Плюс рядки, що вже на екрані.
local boxes = setmetatable({}, { __mode = "k" })
function K.OnScroll(box, fn)
    if not box or not box.RegisterCallback or boxes[box] then return false end
    boxes[box] = true
    local owner = {}
    box:RegisterCallback("OnInitializedFrame", function(_, frame, elementData)
        if U.Enabled() then pcall(fn, frame, elementData) end
    end, owner)
    if box.ForEachFrame then
        pcall(box.ForEachFrame, box, function(frame, elementData)
            if U.Enabled() then pcall(fn, frame, elementData) end
        end)
    end
    return true
end

-- Супровід напису: щоразу, коли Blizzard ставить у fs англійський текст, одразу ставимо переклад
-- (resolve(text) → ua | nil). Повторний SetText із хука не зациклюється. Ставиться один раз на напис.
local follow = setmetatable({}, { __mode = "k" })
local busy = false
function K.Follow(fs, resolve)
    if not fs or not fs.SetText then return end
    if follow[fs] then follow[fs] = resolve; return end
    follow[fs] = resolve
    hooksecurefunc(fs, "SetText", function(self, text)
        if busy or not U.Enabled() then return end
        text = K.Str(text)
        if not text or K.Cyr(text) then return end
        local r = follow[self]
        local ok, ua = pcall(r, text)
        if ok and ua and ua ~= text then
            busy = true
            pcall(U.Apply, self, K.Wrap(text, ua), text)
            busy = false
        end
    end)
end

-- Супровід + переклад поточного тексту (для написів, уже заповнених до встановлення хука).
function K.FollowNow(fs, resolve)
    if not fs then return end
    K.Follow(fs, resolve)
    if not U.Enabled() then return end
    local en = K.Text(fs)
    if not en or K.Cyr(en) then return end
    local ok, ua = pcall(resolve, en)
    if ok and ua and ua ~= en then
        busy = true
        pcall(U.Apply, fs, K.Wrap(en, ua), en)
        busy = false
    end
end

-- Обхід статичних написів фрейму (підписи з XML: вкладки, заголовки, кнопки) — разово на показ.
-- Лише FontString, лише точний збіг у доменах doms, без чисел-змінних; глибина й кількість обмежені.
local function walk(frame, doms, depth, budget)
    if depth > 7 or budget.n <= 0 or not frame then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if budget.n <= 0 then return end
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                budget.n = budget.n - 1
                local en = K.Text(r)
                if en and not K.Cyr(en) and #en <= 120 then
                    local ua = K.Any(en, unpack(doms))
                    if ua then U.Apply(r, K.Wrap(en, ua), en) end
                end
            end
        end
    end
    if frame.GetChildren then
        for _, c in ipairs({ frame:GetChildren() }) do walk(c, doms, depth + 1, budget) end
    end
end

function K.Walk(frame, ...)
    if not frame or not U.Enabled() or (InCombatLockdown and InCombatLockdown()) then return end
    local doms = { ... }
    if #doms == 0 then doms = { "ui" } end
    walk(frame, doms, 0, { n = 600 })
end

-- Обхід на кожен показ фрейму.
local walked = setmetatable({}, { __mode = "k" })
function K.WalkOnShow(frame, ...)
    if not frame or walked[frame] or not frame.HookScript then return end
    walked[frame] = true
    local doms = { ... }
    frame:HookScript("OnShow", function(self) K.Walk(self, unpack(doms)) end)
    if frame.IsShown and frame:IsShown() then K.Walk(frame, unpack(doms)) end
end

-- Вкладки (PanelTabButton): текст і ширина під переклад. list — фрейми вкладок або їхні глобальні імена.
function K.Tabs(list)
    if not U.Enabled() then return end
    for _, n in pairs(list) do
        local tab = type(n) == "string" and rawget(_G, n) or n
        local fs = tab and (tab.Text or (tab.GetFontString and tab:GetFontString()))
        local en = K.Text(fs)
        local ua = en and K.Any(en, "ui", "journal", "collections")
        if ua then
            U.Apply(fs, ua, en)
            if PanelTemplates_TabResize and not (InCombatLockdown and InCombatLockdown()) then pcall(PanelTemplates_TabResize, tab, 0) end
        end
    end
end

-- Рядок тултіпа i (ліворуч).
function K.TipLine(tt, i)
    local name = tt and tt.GetName and tt:GetName()
    return name and _G[name .. "TextLeft" .. i]
end
