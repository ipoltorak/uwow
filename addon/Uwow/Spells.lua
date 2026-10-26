-- Uwow · Spells.lua — описи заклять і аур. У пакеті лежать англ. шаблон (з $-формулами) і український шаблон.
-- Показаний грою англійський текст зіставляємо з англ. шаблоном (кожна формула → захоплення), а значення формул
-- підставляємо в український шаблон.
-- Умовні конструкції $?умова[A][B] гра розв'язує сама (спек, аура, складність), а ми умову не знаємо: шаблон
-- розгортаємо в усі варіанти гілок, шукаємо варіант, що збігся з показаним текстом, і беремо ті самі гілки в UA.
-- $@spellnameN → наша назва закляття N; $@spelldescN → рекурсивно перекладений опис N; $gчол:жін; і $lодн:мн;
-- (і |4одн:мн;) в UA — за статтю гравця і за числом перед конструкцією.
local U = UWOW
local S = {}
U.SpellText = S

local cache, ncache = {}, 0              -- EN-шаблон без умов → {pat, toks} | false
local vcache, nvcache = {}, 0            -- EN-шаблон з умовами → {варіанти} | false
local MAX_VARIANTS = 128

-- Токени формул: $@spellname123 · ${вираз} · $/10;s1 · $*0.5;s1 · $<змінна> · $123s1 · $s1 · $d · $pri (кілька літер)
local TOKENS = { "^%$@%a+%d+", "^%${[^}]*}", "^%$[/%*][%d%.]+;%d*%a%d*", "^%$<[%w_]+>", "^%$%d*%a+%d*" }
-- форми за числом/статтю: $lодн:мн; $gчол:жін; |4одн:мн;
local FORMS = { "^%$[lLgG][^:;%$]*:[^;%$]*;", "^|4[^:;|]*:[^;|]*;" }

local function escPat(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
-- літерал шаблону: пробіли/переноси гнучкі (у джерелі буває «\n\n\n\n» чи два пробіли, у грі — менше)
local function lit(s) return (escPat(s):gsub("%s+", "%%s+")) end

local function tokenAt(en, a)
    for _, p in ipairs(FORMS) do
        local b, c = en:find(p, a)
        if b then return en:sub(b, c), true end
    end
    for _, p in ipairs(TOKENS) do
        local b, c = en:find(p, a)
        if b then
            local tok = en:sub(b, c)
            if tok:sub(2, 2) == "{" then                          -- ${…}.1 — точність формату, у тексті її нема
                local _, e2 = en:find("^%.%d+", c + 1)
                if e2 then tok = en:sub(b, e2) end
            end
            return tok, false
        end
    end
end

-- EN-шаблон без умов → {pat=Lua-патерн, toks={…}} або false
function S.Compile(en)
    if type(en) ~= "string" then return false end
    if en:find("$?", 1, true) then return false end
    en = en:gsub("\r\n", "\n"):gsub("%s+$", "")
    local parts, toks, i = { "^" }, {}, 1
    while i <= #en do
        local a = en:find("[%$|]", i)
        if not a then parts[#parts + 1] = lit(en:sub(i)); break end
        parts[#parts + 1] = lit(en:sub(i, a - 1))
        local tok, form = tokenAt(en, a)
        if not tok then
            parts[#parts + 1] = escPat(en:sub(a, a)); i = a + 1
        elseif form then                                          -- одна з форм — без захоплення
            parts[#parts + 1] = tok:find(" ", 1, true) and ".-" or "%S+"
            i = a + #tok
        else
            toks[#toks + 1] = tok
            parts[#parts + 1] = "(.-)"
            i = a + #tok
        end
    end
    parts[#parts + 1] = "%s*$"
    return { pat = table.concat(parts), toks = toks }
end

local UNITS = { { " sec", " сек." }, { " min", " хв" }, { " hrs", " год" }, { " hr", " год" }, { " hours", " год" },
                { " yds", " м" }, { " yd", " м" }, { " yards", " м" }, { " days", " дн." }, { " day", " дн." } }

local function localizeValue(v)
    for _, u in ipairs(UNITS) do
        if v:sub(-#u[1]) == u[1] then return v:sub(1, -#u[1] - 1) .. u[2] end
    end
    return v
end

local function lastNumber(s)
    local n
    for x in s:gmatch("%d[%d,%.]*") do n = x end
    return n and tonumber((n:gsub(",", ""))) or nil
end

local function female() return UnitSex and UnitSex("player") == 3 end

-- значення токена для UA: назва/опис вкладеного закляття — наші; решта — як показала гра
local function valueFor(t, v)
    local n = t:match("^%$@spellname(%d+)$")
    if n then return U.ID("spell", tonumber(n), "name") or v end
    n = t:match("^%$@spelldesc(%d+)$") or t:match("^%$@spellaura(%d+)$")
    if n then return S.Render(tonumber(n), v, t:find("aura", 1, true) ~= nil) or v end
    if t == "$pri" or t == "$Pri" then return U.T("ui", v) or v end      -- основна характеристика: «Strength»
    return localizeValue(v)
end

-- Підставити значення формул у UA-шаблон; $lодн:мн; і |4одн:мн; — за останнім числом перед ними
-- (1 → однина, інакше множина), $gчол:жін; — за статтю гравця.
function S.Fill(ua, vals)
    local forms = {}
    local function mark(kind, one, many)
        forms[#forms + 1] = { kind, one, many }
        return "\2" .. #forms .. "\3"
    end
    ua = ua:gsub("%$([lLgG])([^:;%$]*):([^;%$]*);", function(k, a, b) return mark(k:lower(), a, b) end)
    ua = ua:gsub("|4([^:;|]*):([^;|]*);", function(a, b) return mark("l", a, b) end)
    local missing = false
    local i, out = 1, {}
    while i <= #ua do
        local a = ua:find("$", i, true)
        if not a then out[#out + 1] = ua:sub(i); break end
        out[#out + 1] = ua:sub(i, a - 1)
        local tok = tokenAt(ua, a)
        if not tok then
            out[#out + 1] = "$"; i = a + 1
        else
            local v = vals[tok] or vals[(tok:gsub("%.%d+$", ""))]
            if v == nil then missing = true; break end
            out[#out + 1] = valueFor(tok, v)
            i = a + #tok
        end
    end
    if missing then return nil end
    ua = table.concat(out):gsub(" сек%.%.", " сек."):gsub(" дн%.%.", " дн.")   -- «12 сек.» + крапка речення
    local f = female()
    ua = ua:gsub("()\2(%d+)\3", function(pos, n)
        local fm = forms[tonumber(n)]
        if fm[1] == "g" then return f and fm[3] or fm[2] end
        return lastNumber(ua:sub(1, pos - 1)) == 1 and fm[2] or fm[3]
    end)
    return ua
end

local function compiled(en)
    local c = cache[en]
    if c == nil then
        c = S.Compile(en)
        if ncache > 5000 then cache, ncache = {}, 0 end
        cache[en] = c; ncache = ncache + 1
    end
    return c
end

-- зіставити показаний текст із шаблоном без умов → значення токенів або nil
local function match(en, text)
    local c = compiled(en)
    if not c then return nil end
    local caps = { text:match(c.pat) }
    if caps[1] == nil and #c.toks > 0 then return nil end
    if #c.toks == 0 and not text:find(c.pat) then return nil end
    local vals = {}
    for i, t in ipairs(c.toks) do
        if vals[t] ~= nil and vals[t] ~= caps[i] then return nil end    -- той самий токен двічі — те саме значення
        vals[t] = caps[i]
    end
    return vals
end

-- ── умовні гілки $?умова[A]?умова2[B][C] ───────────────────────────────────────────────────────────────
-- Розбір ланцюжка, що починається з «$?» на позиції s: → позиція після нього, {гілки}. Без явної «інакше»
-- гілки додаємо порожню (гра тоді нічого не показує). Літеральний «$?» без «[» → nil.
local function chain(str, s)
    local pos, branches = s + 1, {}
    while str:sub(pos, pos) == "?" do
        local br = str:find("[", pos, true)
        if not br then return nil end
        local cond = str:sub(pos + 1, br - 1)
        if cond:find("[%s%]]") then return nil end                 -- умова — суцільний вираз без пробілів
        local _, e = str:find("%b[]", br)
        if not e then return nil end
        branches[#branches + 1] = str:sub(br + 1, e - 1)
        pos = e + 1
    end
    if #branches == 0 then return nil end
    local q = pos
    while str:sub(q, q):find("%s") do q = q + 1 end
    if str:sub(q, q) == "[" then
        local _, e = str:find("%b[]", q)
        if e then branches[#branches + 1] = str:sub(q + 1, e - 1); pos = e + 1
        else branches[#branches + 1] = "" end
    else
        branches[#branches + 1] = ""
    end
    return pos, branches
end

-- усі варіанти шаблону: { {text=…, ch={номери гілок по порядку}} } або false (забагато)
local function expand(en)
    local out, stack = {}, { { text = en, ch = {}, from = 1 } }
    while #stack > 0 do
        local v = table.remove(stack)
        local s = v.text:find("$?", v.from, true)
        local after, br
        while s do
            after, br = chain(v.text, s)
            if after then break end
            s = v.text:find("$?", s + 2, true)
        end
        if not s then
            out[#out + 1] = v
            if #out > MAX_VARIANTS then return false end
        else
            for k = #br, 1, -1 do
                local ch = { unpack(v.ch) }
                ch[#ch + 1] = k
                stack[#stack + 1] = { text = v.text:sub(1, s - 1) .. br[k] .. v.text:sub(after), ch = ch, from = s }
            end
            if #stack > MAX_VARIANTS * 4 then return false end
        end
    end
    return out
end

-- ті самі гілки в UA-шаблоні; nil, якщо структура умов різна
local function choose(ua, ch)
    local idx, from = 1, 1
    while true do
        local s = ua:find("$?", from, true)
        if not s then break end
        local after, br = chain(ua, s)
        if not after then
            from = s + 2
        else
            local k = ch[idx]
            if not k or not br[k] then return nil end
            idx = idx + 1
            ua = ua:sub(1, s - 1) .. br[k] .. ua:sub(after)
            from = s
        end
    end
    if idx <= #ch then return nil end
    return ua
end

local function variants(en)
    local v = vcache[en]
    if v == nil then
        v = expand(en)
        if nvcache > 2000 then vcache, nvcache = {}, 0 end
        vcache[en] = v; nvcache = nvcache + 1
    end
    return v
end

-- Шаблон EN/UA + показаний текст → UA з живими числами або nil.
function S.RenderTemplate(en, ua, text)
    if type(en) ~= "string" or type(ua) ~= "string" or type(text) ~= "string" then return nil end
    en = en:gsub("\r\n", "\n")
    text = text:gsub("\r\n", "\n"):gsub("%s+$", "")
    if not en:find("$?", 1, true) then
        local vals = match(en, text)
        return vals and S.Fill(ua, vals) or nil
    end
    local vs = variants(en)
    if not vs then return nil end
    for _, v in ipairs(vs) do
        local vals = match(v.text, text)
        if vals then
            local u2 = choose(ua, v.ch)
            if u2 then return S.Fill(u2, vals) end
        end
    end
    return nil
end

-- spellID, показаний EN-текст, aura? → український текст або nil
function S.Render(id, text, aura)
    id = tonumber(id)
    if not id or type(text) ~= "string" then return nil end
    local p = U.packs.sdesc or U.Need("sdesc")
    local pe = U.packs.sdesc_en
    if not p or not pe then return nil end
    local k = id * 16 + (aura and 4 or 3)
    local ua, en = p[k], pe[k]
    if not ua or not en then return nil end
    local out = S.RenderTemplate(en, ua, text)
    if out and U.Remember then                              -- для /uw fix (Core: останні тексти)
        local f = aura and "aura" or "desc"
        U.Remember("sdesc", id, f, text, out); U.Found("sdesc", id, f, text, out)
    end
    return out
end
