-- Uwow · Core.lua — ядро: пакети даних, пошук перекладу, рендер токенів, застосування до написів, збір промахів.
-- Єдиний глобал аддона — UWOW (API для пакетів LoadOnDemand). Глобали Blizzard не пишемо.
local ADDON = ...
local U = {}
UWOW = U
U.name = ADDON
U.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

-- ── пакети ─────────────────────────────────────────────────────────────────────────────────────────────
-- Домен → LoadOnDemand-аддон. Домени ядра (ui, questui, dialog) лежать у Uwow/Data і вже завантажені.
U.PACK_ADDON = {
    quest = "UwowData_Quests", spell = "UwowData_Spells", sdesc = "UwowData_Spells", sdesc_en = "UwowData_Spells",
    item = "UwowData_Items",
    journal = "UwowData_Journal", names = "UwowData_Names",
    collections = "UwowData_Collections", ach = "UwowData_Collections", mount = "UwowData_Collections",
    pet = "UwowData_Collections", faction = "UwowData_Collections", currency = "UwowData_Collections",
    jsec = "UwowData_Journal", jsec_en = "UwowData_Journal",
    achcat = "UwowData_Collections",                 -- назви категорій досягнень за categoryID
}
-- поля ID-доменів: ключ = id * 16 + номер поля (одне число замість вкладених таблиць)
U.FIELD = { title = 1, objectives = 2, description = 3, progress = 4, completion = 5, completionLog = 6,
            greeting = 7, portraitGiverText = 8, portraitGiverName = 9, portraitTurnInText = 10,
            portraitTurnInName = 11, areaDescription = 12,
            name = 1, flavor = 2, desc = 3, aura = 4, n = 1, d = 3, reward = 5 }
U.TEXT_FALLBACK = { "ui", "questui", "dialog", "names", "journal", "collections" }

local packs, loaded, pending = {}, {}, {}
U.packs = packs

function U.Pack(dom)                         -- викликають файли даних: local t = UWOW.Pack("ui")
    local t = packs[dom]
    if not t then t = {}; packs[dom] = t end
    return t
end

-- Компактний текстовий домен (домени ядра, див. compile.py write_compact): дані лежать у ~1–2 тис. рядках-кошиках,
-- запис «\n<hi>.<lo>=<ua>», де hi/lo — старші й молодші 26 біт хешу. Таблицю записів не будуємо на вході: перше
-- звернення p[h] шукає ключ у своєму кошику (string.find plain) і кешує знайдене в самій таблиці (rawset), промах —
-- в окремому обмеженому кеші. Зовні це звичайна таблиця пакета (p[h]); лише pairs() бачить тільки вже знайдене.
local T26 = 67108864
local DEC = { n = "\n", r = "\r", ["\\"] = "\\" }
local sfind, ssub, sgsub, sformat = string.find, string.sub, string.gsub, string.format

function U.PackCompact(dom, nb, buckets)
    local t = U.Pack(dom)
    local miss, nmiss = {}, 0
    setmetatable(t, { __index = function(_, k)
        if type(k) ~= "number" or miss[k] then return nil end
        local lo = k % T26
        local b = buckets[lo % nb + 1]
        local s, e
        if b then s, e = sfind(b, sformat("\n%x.%x=", (k - lo) / T26, lo), 1, true) end
        if not s then
            if nmiss >= 20000 then miss, nmiss = {}, 0 end
            miss[k] = true; nmiss = nmiss + 1
            return nil
        end
        local stop = sfind(b, "\n", e + 1, true)
        local v = ssub(b, e + 1, stop and stop - 1 or -1)
        if sfind(v, "\\", 1, true) then v = sgsub(v, "\\(.)", DEC) end
        rawset(t, k, v)
        return v
    end })
    return t
end

local function inCombat() return InCombatLockdown and InCombatLockdown() end

-- Завантажити пакет домену. У бою — у чергу до PLAYER_REGEN_ENABLED (LoadAddOn у бою дає фриз).
function U.Need(dom)
    local addon = U.PACK_ADDON[dom]
    if not addon or loaded[addon] then return packs[dom] end
    if inCombat() then pending[addon] = true; return packs[dom] end
    loaded[addon] = true
    local ok = C_AddOns and C_AddOns.LoadAddOn and pcall(C_AddOns.LoadAddOn, addon)
    if not ok then loaded[addon] = "fail" end
    return packs[dom]
end

function U.FlushPending()
    for addon in pairs(pending) do
        pending[addon] = nil
        for dom, a in pairs(U.PACK_ADDON) do if a == addon then U.Need(dom); break end end
    end
end

-- ── гравець ────────────────────────────────────────────────────────────────────────────────────────────
local player
function U.Player()
    if not player then
        local n = UnitName and UnitName("player")
        if type(n) == "string" and n ~= "" then player = n end
    end
    return player
end

local function female() return UnitSex and UnitSex("player") == 3 end

-- Живе EN-число → запис, яким воно стояло в перекладі (прапорець токена {#N<прапорець>}, compile.py number_template):
-- s/n/t/e — розділювач тисяч пробіл / нерозривний / вузький нерозривний / без нього; d — десяткова кома.
local SEP = { s = " ", n = "\194\160", t = "\226\128\175", e = "" }
function U.NumFmt(n, fl)
    if not n then return "" end
    if fl == nil or fl == "" then return n end
    if fl == "d" then return (n:gsub("%.", ",")) end
    local sep = SEP[fl]
    if sep and n:find("^%d%d?%d?,%d%d%d") then return (n:gsub(",", sep)) end
    return n
end

-- ── рендер токенів перекладу ───────────────────────────────────────────────────────────────────────────
-- {#1}… — числа з живого рядка за номером ({#1s} тощо — у записі перекладу, див. U.NumFmt); {#} — по черзі; {p} ім'я; {c} {c:v} {r} {r:v} клас/раса; {a} мовець;
-- $p(чол:жін) — за статтю гравця. who — ім'я для {p} замість гравця (дійова особа з живого тексту, див. U.T).
function U.Render(ua, nums, speaker, who)
    if type(ua) ~= "string" then return nil end
    if nums and #nums > 0 then
        ua = ua:gsub("{#(%d+)(%a?)}", function(i, fl) return U.NumFmt(nums[tonumber(i)], fl) end)
        local k = 0
        ua = ua:gsub("{#}", function() k = k + 1; return nums[k] or "" end)
    end
    if ua:find("{", 1, true) then
        ua = ua:gsub("{p}", who or U.Player() or "")
        -- лише {c} {c:форма} {r} {r:форма}; {caster}, {rank} тощо — чужі плейсхолдери, лишаємо як є
        if U.ClassName then
            ua = ua:gsub("{([cr])(:?)(%a*)}", function(t, colon, form)
                if form ~= "" and colon == "" then return nil end
                return (t == "c" and U.ClassName or U.RaceName)(form)
            end)
        end
        if speaker then ua = ua:gsub("{a}", U.TranslateName(speaker) or speaker) end
    end
    if ua:find("$p(", 1, true) then
        local f = female()
        ua = ua:gsub("%$p%(([^:%)]*):([^%)]*)%)", function(m, w) return f and w or m end)
    end
    return ua
end

-- ── пошук ──────────────────────────────────────────────────────────────────────────────────────────────
local stats = { hit = 0, miss = 0 }
U.stats = stats

-- ── останні тексти (для /uw fix, Surfaces/UiFix.lua) ────────────────────────────────────────────────────
-- Кільце з RECENT записів { d = домен, id, f = поле, en, ua (nil — промах), a = мовець, k = текст ключа, якщо він
-- інший за показаний EN, n = порядковий номер }. Слоти перевикористовуються, хеш не рахуємо: ключ рахує вікно
-- /uw fix під час збереження. Повтор того самого EN оновлює запис і піднімає його нагору.
local RECENT = 50
local recent, byEn, rpos, rseq = {}, {}, 0, 0
U.recent, U.recentByEn = recent, byEn

local function remember(dom, id, f, en, ua, speaker, k)
    if type(en) ~= "string" or #en < 2 then return end
    rseq = rseq + 1
    local r = byEn[en]
    if not r then
        rpos = rpos % RECENT + 1
        r = recent[rpos]
        if r then byEn[r.en] = nil else r = {}; recent[rpos] = r end
        r.d, r.id, r.f, r.ua, r.a, r.k = nil, nil, nil, nil, nil, nil
        r.en = en
        byEn[en] = r
    end
    if dom and dom ~= r.d then r.d, r.id, r.f, r.k = dom, nil, nil, nil end
    if id then r.id, r.f = id, f end
    if ua then r.ua = ua end
    if speaker then r.a = speaker end
    if k and k ~= en then r.k = k end
    r.n = rseq
end
U.Remember = remember

-- Остання вдала знахідка без показаного тексту (U.ID, U.Fmt, U.T): U.Apply прив'язує її до напису, якщо поставлений
-- переклад містить знайдений.
local cDom, cId, cF, cEn, cUa
local function found(dom, id, f, en, ua) cDom, cId, cF, cEn, cUa = dom, id, f, en, ua end
U.Found = found

local function rememberApplied(en, ua)
    if cUa and sfind(ua, cUa, 1, true) then
        if cEn and cEn ~= en and byEn[cEn] and not byEn[en] then      -- запис знахідки → на показаний напис
            local r = byEn[cEn]
            byEn[cEn] = nil; r.en = en; byEn[en] = r
        end
        remember(cDom, cId, cF, en, ua, nil, cEn)
    else
        remember(nil, nil, nil, en, ua)
    end
    cUa = nil
end

-- Фраза (кілька слів або мітка з числом «Horde: {#}») — для неї дозволено шукати в інших текстових доменах.
local function multiword(key)
    return #key >= 8 and (key:find("%a[^%a]+%a") ~= nil or (key:find("%a%a%a") ~= nil and key:find("{[#a]}") ~= nil))
end

-- Текст про іншого гравця («Yuber has disturbed an Amani Ritual Skull.»): у даних на місці імені {p} ($n / {NAME}).
-- Пробуємо слова з великої літери як ім'я дійової особи; рендеримо з цим самим іменем. Лише ui/dialog, до 3 слів.
local ACTOR_DOMS = { ui = true, dialog = true }
local function actor(dom, p, text, speaker)
    if not ACTOR_DOMS[dom] or not p or #text > 300 then return nil end
    local me, tried = U.Player(), 0
    for w in text:gmatch("%u[%l\128-\255']+") do
        if #w >= 3 and w ~= me then
            tried = tried + 1
            -- мовцем буває сама дійова особа (емоція «Yuber places…» від Yuber): тоді без підстановки {a}
            local key, nums = U.Norm.norm(text, w ~= speaker and speaker or nil, w)
            if key:find("{p}", 1, true) then
                local ua = p[U.Norm.hash(key)]
                if ua then return U.Render(ua, nums, speaker, w) end
            end
            if tried >= 3 then break end
        end
    end
end

-- Текст → переклад. Спершу домен поверхні, потім інші текстові домени (лише для фраз, не для одного слова).
function U.T(dom, text, speaker)
    if type(text) ~= "string" or text == "" then return nil end
    if text:find("[\208\209\210]") then return nil end             -- уже кирилиця (наш вивід)
    -- форматний рядок («a %d%% loss»): «%%» у грі — «%», так само зібрано ключ (compile.py fmt_percent)
    if text:find("%%", 1, true) and text:find("%%%d*%$?[sd]") then text = text:gsub("%%%%", "%%") end
    local key, nums = U.Norm.norm(text, speaker, U.Player())
    if key == "" then return nil end
    local h = U.Norm.hash(key)
    local p = packs[dom] or U.Need(dom)
    local ua = p and p[h]
    if not ua and multiword(key) then
        for _, d in ipairs(U.TEXT_FALLBACK) do
            if d ~= dom and packs[d] then ua = packs[d][h]; if ua then break end end
        end
    end
    if not ua and #nums > 0 then                                     -- запис без шаблону чисел
        local k2 = U.Norm.norm(text, speaker, U.Player(), true)
        ua = p and p[U.Norm.hash(k2)]
        nums = nil
    end
    if ua then
        stats.hit = stats.hit + 1
        ua = U.Render(ua, nums, speaker)
        remember(dom, nil, nil, text, ua, speaker); found(dom, nil, nil, text, ua)
        return ua
    end
    local ua2 = actor(dom, p, text, speaker)
    if ua2 then
        stats.hit = stats.hit + 1
        remember(dom, nil, nil, text, ua2, speaker); found(dom, nil, nil, text, ua2)
        return ua2
    end
    stats.miss = stats.miss + 1
    return nil, h, key
end

-- ID → переклад: U.ID("quest", 12345, "description")
function U.ID(dom, id, field)
    id = tonumber(id)
    if not id then return nil end
    local p = packs[dom] or U.Need(dom)
    if not p then return nil end
    local ua = p[id * 16 + (U.FIELD[field] or 1)]
    if ua then
        stats.hit = stats.hit + 1
        ua = U.Render(ua)
        found(dom, id, field, nil, ua)
        return ua
    end
    stats.miss = stats.miss + 1
end

function U.TranslateName(name)
    if type(name) ~= "string" then return nil end
    local p = packs.names or U.Need("names")
    local h = U.Norm.hash((U.Norm.norm(name)))
    -- імена босів живуть у путівнику (journalEncounterNames): дивимось, якщо пакет уже завантажено
    return (p and p[h]) or (packs.ui and packs.ui[h]) or (packs.journal and packs.journal[h])
end

-- ID-домен із EN-шаблоном формул (пара <dom> / <dom>_en, як sdesc / sdesc_en): показаний грою текст зіставляється
-- з EN-шаблоном, значення формул підставляються в UA (рушій Spells.lua). Напр. описи здібностей путівника:
-- U.TemplateText("jsec", sectionID, shownText).
local tplCache, nTpl = {}, 0
function U.TemplateText(dom, id, text, field)
    local S = U.SpellText
    id = tonumber(id)
    if not (S and S.Compile and id) or type(text) ~= "string" then return nil end
    local p = packs[dom] or U.Need(dom)
    local pe = packs[dom .. "_en"]
    if not (p and pe) then return nil end
    local k = id * 16 + (U.FIELD[field or "desc"] or 3)
    local ua, en = p[k], pe[k]
    if not ua or not en then stats.miss = stats.miss + 1; return nil end
    local c = tplCache[en]
    if c == nil then
        c = S.Compile(en)
        if nTpl > 3000 then tplCache, nTpl = {}, 0 end
        tplCache[en] = c; nTpl = nTpl + 1
    end
    if not c then return nil end
    local caps = { (text:gsub("\r\n", "\n")):match(c.pat) }
    if caps[1] == nil then return nil end
    local vals = {}
    for i, t in ipairs(c.toks) do vals[t] = caps[i] end
    local out = S.Fill(ua, vals)
    if out then
        stats.hit = stats.hit + 1
        remember(dom, id, field or "desc", text, out); found(dom, id, field or "desc", text, out)
    end
    return out
end

-- ── секретні значення (12.x) ───────────────────────────────────────────────────────────────────────────
-- Midnight віддає частину рядків як «секретні»: їх не можна порівнювати, індексувати чи зберігати. Перевірка —
-- issecretvalue, якщо є, інакше спроба порівняння під pcall.
function U.IsSecret(v)
    if issecretvalue then
        local ok, r = pcall(issecretvalue, v)
        if ok then return r and true or false end
    end
    return not pcall(function() return v == "" end)
end

-- Текст напису, якщо його можна читати: рядок, не секретний, не порожній.
function U.GetText(fs)
    if not fs or not fs.GetText then return nil end
    local ok, t = pcall(fs.GetText, fs)
    if not ok or type(t) ~= "string" or U.IsSecret(t) or t == "" then return nil end
    return t
end

-- ── форматні рядки GlobalStrings («Delete %s?», «%s slain: %d/%d») ──────────────────────────────────────
-- Ключ у даних — шаблон EN (norm: %s → {a}, %d → {#}); UA має {a} {aN} {#} (compile.py ua_canon) або сирі %s/%d.
local SPEC = "%%(%d*%$?)([%-%+ #0]*%d*%.?%d*)([sdfgiuxc])"

local function specs(fmt)                 -- → { {kind, argIndex}, … } у порядку появи
    local out, seq = {}, 0
    local i = 1
    while true do
        local a, b, pos, _, conv = fmt:find(SPEC, i)
        if not a then break end
        if fmt:sub(a - 1, a - 1) ~= "%" then
            local n
            if pos ~= "" then n = tonumber(pos:sub(1, -2)) else seq = seq + 1; n = seq end
            out[#out + 1] = { conv == "s" and "s" or "n", n }
        end
        i = b + 1
    end
    return out
end

-- Показаний текст + EN-шаблон → аргументи (за номером) або nil, якщо текст не з цього шаблону.
local patCache, nPat = {}, 0
function U.Unformat(fmt, text)
    if type(fmt) ~= "string" or type(text) ~= "string" or not fmt:find("%", 1, true) then return nil end
    local c = patCache[fmt]
    if c == nil then
        local parts, order, i = { "^" }, {}, 1
        local sp = specs(fmt)
        local k = 0
        while i <= #fmt do
            local a, b, _, _, conv = fmt:find(SPEC, i)
            local pct = fmt:find("%%", i, true)
            if pct and (not a or pct < a) then
                parts[#parts + 1] = fmt:sub(i, pct - 1):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "%%"
                i = pct + 2
            elseif a then
                parts[#parts + 1] = fmt:sub(i, a - 1):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
                k = k + 1
                order[k] = sp[k] and sp[k][2] or k
                parts[#parts + 1] = conv == "s" and "(.-)" or "(%-?[%d%.,]+)"
                i = b + 1
            else
                parts[#parts + 1] = fmt:sub(i):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
                break
            end
        end
        parts[#parts + 1] = "$"
        c = { pat = table.concat(parts):gsub("|4[^;]*;", ".-"), order = order }
        if nPat > 2000 then patCache, nPat = {}, 0 end
        patCache[fmt] = c; nPat = nPat + 1
    end
    local caps = { text:match(c.pat) }
    if caps[1] == nil then return nil end
    local args = {}
    for i, n in ipairs(c.order) do args[n] = caps[i] end
    return args
end

-- Сирий пошук без рендеру: → ua, nums (числа живого рядка для {#N}) або nil.
local function rawT(dom, text)
    if type(text) ~= "string" or text == "" or text:find("[\208\209\210]") then return nil end
    if text:find("%%", 1, true) and text:find("%%%d*%$?[sd]") then text = text:gsub("%%%%", "%%") end
    local key, nums = U.Norm.norm(text, nil, U.Player())
    if key == "" then return nil end
    local p = packs[dom] or U.Need(dom)
    local ua = p and p[U.Norm.hash(key)]
    if not ua and #nums > 0 and p then ua = p[U.Norm.hash((U.Norm.norm(text, nil, U.Player(), true)))]; nums = {} end
    return ua, nums
end

-- EN-шаблон + аргументи → український рядок або nil. argT(arg, kind) — необов'язковий перекладач аргументів
-- (назва квесту, ціль); аргумент без перекладу лишається як є.
function U.Fmt(dom, fmt, args, argT)
    local ua, nums = rawT(dom, fmt)
    if not ua then stats.miss = stats.miss + 1; return nil end
    stats.hit = stats.hit + 1
    args = args or {}
    local sp = specs(fmt)
    local sList, nList = {}, {}
    for _, s in ipairs(sp) do
        local v = args[s[2]]
        if s[1] == "s" then
            if argT and type(v) == "string" then v = argT(v, s) or v end
            sList[#sList + 1] = v
        else
            nList[#nList + 1] = v
        end
    end
    if nums and #nums > 0 then ua = ua:gsub("{#(%d+)(%a?)}", function(i, fl) return U.NumFmt(nums[tonumber(i)], fl) end) end
    local si, ni = 0, 0
    ua = ua:gsub("{a(%d*)}", function(n)
        if n ~= "" then local v = args[tonumber(n)]; return v ~= nil and tostring(v) or "" end
        si = si + 1; return sList[si] ~= nil and tostring(sList[si]) or ""
    end)
    ua = ua:gsub("{#}", function() ni = ni + 1; return nList[ni] ~= nil and tostring(nList[ni]) or "" end)
    ua = ua:gsub("%%(%d*%$?)[%-%+ #0]*%d*%.?%d*([sdf])", function(pos, conv)
        if pos ~= "" then local v = args[tonumber(pos:sub(1, -2))]; return v ~= nil and tostring(v) or "" end
        if conv == "s" then si = si + 1; return sList[si] ~= nil and tostring(sList[si]) or "" end
        ni = ni + 1; return nList[ni] ~= nil and tostring(nList[ni]) or ""
    end)
    ua = U.Render(ua)
    found(dom, nil, nil, fmt, ua)
    return ua
end

-- Показаний текст за відомим EN-шаблоном: точний збіг → розбір за шаблоном → nil.
function U.TF(dom, text, fmt, argT)
    local ua = U.T(dom, text)
    if ua or not fmt then return ua end
    local args = U.Unformat(fmt, text)
    if args then return U.Fmt(dom, fmt, args, argT) end
end

-- ── застосування до напису ─────────────────────────────────────────────────────────────────────────────
local orig = setmetatable({}, { __mode = "k" })   -- напис → {en, ua}
U.orig = orig

function U.Apply(fs, ua, en)
    if not fs or not ua or ua == en then return end
    orig[fs] = { en = en, ua = ua }
    if type(en) == "string" then rememberApplied(en, ua) end
    if not U.Enabled() then return end
    if U.Font then U.Font(fs) end
    fs:SetText(ua)
end

-- Переклад напису «на місці»: текст напису → домен → Apply або збір пропуску. owner — фрейм для фільтра чужих аддонів.
-- → true, якщо перекладено.
function U.TrFS(fs, dom, surf, owner, fmt)
    local en = U.GetText(fs)
    if not en then return false end
    local ua = U.TF(dom, en, fmt)
    if ua then U.Apply(fs, ua, en); return true end
    U.Miss(dom, surf, fmt or en, nil, nil, owner or fs)
    return false
end

-- Повернути всі запам'ятовані написи у стан, що відповідає налаштуванням (переклад / оригінал / вимкнено).
function U.Refresh()
    local on = U.Enabled()
    for fs, p in pairs(orig) do
        local ok, cur = pcall(fs.GetText, fs)
        if ok and not U.IsSecret(cur) then
            if not on and cur == p.ua then fs:SetText(p.en)
            elseif on and cur == p.en then
                if U.Font then U.Font(fs) end
                fs:SetText(p.ua)
            end
        end
    end
end

function U.ShowOriginal(on)
    U.Settings.original = on and true or false
    U.Refresh()
end

-- ── фільтр збору: чужі імена, гільдії, реалми, тексти інших аддонів ─────────────────────────────────────
-- people — імена інших гравців (група, гільдія, друзі), phrases — назви гільдій, realms — реалми (лише як «Ім'я-Реалм»);
-- оновлює Main.lua за подіями.
local people, phrases, realms = {}, {}, {}
U.people, U.peoplePhrases, U.realms = people, phrases, realms
local addonNames = {}                     -- назви й заголовки сторонніх аддонів (нижній регістр)
U.addonNames = addonNames

local function personal(text)
    if text:find("|Hplayer:", 1, true) or text:find("|HBNplayer", 1, true) or text:find("|K", 1, true) then return true end
    for w in text:gmatch("[%a\128-\255][%w\128-\255']*") do
        if people[w] then return true end
    end
    for _, b in text:gmatch("([%a\128-\255]+)%-(%u[%a\128-\255']+)") do
        if realms[b] or people[b] or b:find("%l%u") then return true end              -- Ім'я-Реалм; реалм без пробілів — ArgentDawn
    end
    for i = 1, #phrases do
        if text:find(phrases[i], 1, true) then return true end
    end
    if text:find("^<.+>$") then return true end                             -- <Гільдія> у тултіпі
    return false
end
U.IsPersonal = personal

local function foreignText(text)
    local head = text:match("^%[([^%]]+)%]") or text:match("^([%w_%-%. !']+):%s")
    if head and addonNames[head:lower()] then return true end
    for name in text:gmatch("|c%x%x%x%x%x%x%x%x([^|]+)|r") do
        if addonNames[name:lower():gsub("[:%s]+$", "")] then return true end
    end
    if text:find("Interface\\AddOns\\", 1, true) or text:find("https?://") then return true end
    return false
end
U.IsForeignText = foreignText

-- Фрейм належить сторонньому аддону: хтось із батьків має глобальне ім'я, записане незахищеним кодом.
function U.IsForeign(region)
    if not issecurevariable then return false end
    for _ = 1, 12 do
        if type(region) ~= "table" then return false end
        local ok, name = pcall(region.GetName, region)
        if ok and type(name) == "string" and not U.IsSecret(name) then
            local ok2, sec = pcall(issecurevariable, name)
            if ok2 and sec == false then return true end
        end
        local ok3, parent = pcall(region.GetParent, region)
        region = ok3 and parent or nil
    end
    return false
end

-- ── збір промахів (лише поверхні, які ми хукаємо) ──────────────────────────────────────────────────────
local CAP_MAX = 20000
function U.Miss(dom, surf, text, id, speaker, owner)
    if type(text) ~= "string" or text == "" or U.IsSecret(text) or text:find("[\208\209\210]") then return end
    local capture = U.Settings and U.Settings.capture
    local db = UwowMiss
    -- без збору — лише дешевий фільтр тексту для списку /uw fix (обхід батьків фрейму — коли збір увімкнено)
    if personal(text) or foreignText(text) or (capture and owner and U.IsForeign(owner)) then
        if capture and type(db) == "table" then db.filtered = (db.filtered or 0) + 1 end
        return
    end
    remember(dom, tonumber(id), nil, text, nil, speaker)
    if not capture or type(db) ~= "table" then return end
    local key, _ = U.Norm.norm(text, speaker, U.Player())
    if #key < 2 or not key:find("%a") then return end
    local h = U.Norm.hash(key)
    db.d = db.d or {}
    local t = db.d[dom]
    if not t then t = { n = 0 }; db.d[dom] = t end
    local r = t[h]
    if r then r.c = (r.c or 1) + 1; return end
    if t.n >= CAP_MAX then db.overflow = (db.overflow or 0) + 1; return end
    t.n = t.n + 1
    t[h] = { en = text:sub(1, 600), s = surf, id = id, a = speaker, c = 1 }
end
