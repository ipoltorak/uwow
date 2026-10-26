-- tests/run_tests.lua — офлайн-тести Uwow у Lua 5.1.
-- lua5.1 tests/run_tests.lua <build_dir> <testdata_dir> [addon_src_dir]
-- 1) паритет нормалізації/хешу з Python  2) золотий набір перекладів  3) поверхні встановлюються, хуки на місці
-- 4) рендер токенів і рід  5) бюджет ядра  6) статичний скан: жодних записів у глобали Blizzard  7) покриття промахів v1
package.path = arg[0]:gsub("[^/]+$", "") .. "?.lua;" .. package.path
local H = require("harness")
local SI = require("surf_infra")                     -- ядро й загальний інтерфейс (агент infra)
local SF = require("surf_fix")                       -- /uw fix: останні тексти й пропозиції перекладу (агент fix)
H.setup = { SI.setup, SF.setup }
local BUILD, TD, SRC = arg[1], arg[2], arg[3]
local fails, report = 0, {}

local function check(name, ok, detail)
    report[#report + 1] = ("%s %s%s"):format(ok and "PASS" or "FAIL", name, detail and (" — " .. detail) or "")
    if not ok then fails = fails + 1 end
end

local function unesc(s)
    return (s:gsub("\\(.)", function(c) return ({ n = "\n", t = "\t", r = "\r" })[c] or c end))
end

local SURF_COLL = dofile(arg[0]:gsub("[^/]+$", "") .. "surf_coll.lua")   -- агент coll
local SC = require("surf_char")                                           -- агент char
local U = H.boot(BUILD, function(h) SURF_COLL.pre(h); SC.stubs(h) end)

-- 1. паритет
do
    local n, bad, ex = 0, 0, nil
    for line in io.lines(TD .. "/vectors.tsv") do
        local inp, pl, exp, h, nums = line:match("^(.-)\t(.-)\t(.-)\t(%d+)\t(.*)$")
        if inp then
            n = n + 1
            local got, gn = U.Norm.norm(unesc(inp), nil, pl ~= "" and pl or nil)
            if got ~= unesc(exp) or U.Norm.hash(got) ~= tonumber(h) or table.concat(gn, ",") ~= nums then
                bad = bad + 1
                ex = ex or ("%q → lua %q, py %q"):format(unesc(inp):sub(1, 60), got:sub(1, 60), unesc(exp):sub(1, 60))
            end
        end
    end
    check("norm-parity", bad == 0, ("%d рядків, розбіжностей %d%s"):format(n, bad, ex and (": " .. ex) or ""))
end

-- 2. золотий набір
do
    local n, bad, ex = 0, 0, nil
    for line in io.lines(TD .. "/golden.tsv") do
        local dom, id, fld, en, want = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
        if dom then
            n = n + 1
            local got
            en, want = unesc(en), unesc(want)
            if dom == "journal" and id == "-" and en:find("#", 1, true) then
                -- «#» у джерелі путівника — місце числа (compile.py journal_hash): у грі там живе число
                local i, j = 100, 100
                en = en:gsub("#", function() i = i + 1; return tostring(i) end)
                want = want:gsub("#", function() j = j + 1; return tostring(j) end)
            end
            if id ~= "-" then got = U.ID(dom, id, fld) else got = U.T(dom, en) end
            if got ~= want then
                bad = bad + 1
                ex = ex or ("%s %s %q: %q ≠ %q"):format(dom, id, en:sub(1, 40), tostring(got):sub(1, 40), want:sub(1, 40))
            end
        end
    end
    check("golden", bad == 0, ("%d записів, невлучань %d%s"):format(n, bad, ex and (": " .. ex) or ""))
end

-- 2б. описи заклять: шаблон EN ↔ показаний текст → український текст зі значеннями
do
    local n, bad, ex = 0, 0, nil
    U.Need("sdesc")
    for line in io.lines(TD .. "/spells.tsv") do
        local id, aura, en, want = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
        if id then
            n = n + 1
            local got = U.SpellText.Render(id, unesc(en), aura == "1")
            -- $@spellnameN тепер дає НАШУ назву закляття N (у testdata — EN «Fireball»); «сек..» → «сек.» (агент char)
            local tpl = U.packs.sdesc_en[tonumber(id) * 16 + (aura == "1" and 4 or 3)] or ""
            local w2 = unesc(want):gsub(" сек%.%.", " сек."):gsub(" дн%.%.", " дн.")
            if got ~= w2 and not (got and tpl:find("$@spellname", 1, true) and not got:find("$", 1, true)) then
                bad = bad + 1
                ex = ex or ("%s %q: %q ≠ %q"):format(id, unesc(en):sub(1, 50), tostring(got):sub(1, 50), unesc(want):sub(1, 50))
            end
        end
    end
    check("spell-desc", n > 0 and bad <= n * 0.02, ("%d описів, невлучань %d%s"):format(n, bad, ex and (": " .. ex) or ""))
end

-- 3. поверхні
do
    SlashCmdList.UWOW("stats")
    local okAll, failed = true, {}
    for _, m in ipairs(H.chat or {}) do
        if m:find("помилка") then okAll = false; failed[#failed + 1] = m end
    end
    check("surfaces", okAll and #H.hooks >= 3 and H.filters["CHAT_MSG_MONSTER_SAY"] ~= nil and H.tooltipPost[0] ~= nil,
        ("хуків %d, фільтрів чату %s, тултіп-обробників %s %s"):format(#H.hooks, H.filters["CHAT_MSG_MONSTER_SAY"] and "так" or "ні",
            H.tooltipPost[0] and "так" or "ні", table.concat(failed, "; ")))
end

-- 3б. разова міграція збережених даних попередньої версії
do
    local ok = type(UwowMiss) == "table" and UwowMiss.d and UwowMiss.d.dialog and UwowSettingsDB == nil and UwowCaptureDB == nil
        and UwowDB.migrated and UwowDB.original == true
    local n = 0
    if ok then for _ in pairs(UwowMiss.d.dialog) do n = n + 1 end end
    check("migrate-v1", ok and n >= 3, ("dialog-промахів %d, старі таблиці %s"):format(n, UwowCaptureDB == nil and "прибрано" or "лишились"))
    UwowDB.original = false
end

-- 4. рендер
do
    local r1 = U.Render("Вітаю, {p}! Ти зібра$p(в:ла) {#1} із {#2}, {c:v}.", { "3", "5" })
    H.sex = 3
    local r2 = U.Render("Ти зібра$p(в:ла) їх.")
    H.sex = 2
    check("render", r1 == "Вітаю, Rinss! Ти зібрав 3 із 5, воїне." and r2 == "Ти зібрала їх.", r1 .. " | " .. r2)
end

-- 5. бюджет ядра (Lua 5.1 стенду; гра — інша VM, тут лише регресія)
check("core-budget", H.coreMs <= 150 and H.coreMb <= 35, ("ядро %.0f мс, %.1f МБ"):format(H.coreMs, H.coreMb))

-- 6. статичний скан байткоду (luac -l): SETGLOBAL лише для дозволених імен, без _G[...] = і setglobal
if SRC then
    local allowed = { UWOW = true, UwowDB = true, UwowMiss = true, SLASH_UWOW1 = true, UwowSettingsDB = true, UwowCaptureDB = true }
    local bad = {}
    local p = io.popen('find "' .. SRC .. '" -name "*.lua"')
    for f in p:lines() do
        local l = io.popen('luac5.1 -p -l "' .. f .. '" 2>&1')
        for line in l:lines() do
            local g = line:match("SETGLOBAL%s.-;%s*(%S+)")
            if g and not allowed[g] then bad[#bad + 1] = f:match("[^/]+$") .. ":" .. g end
        end
        l:close()
        for line in io.lines(f) do
            local code = line:gsub("%-%-.*$", "")
            if code:find("_G%s*%[[^%]]*%]%s*=[^=]") or code:find("setglobal") then bad[#bad + 1] = f:match("[^/]+$") .. ": _G[...]=" end
        end
    end
    p:close()
    check("no-global-writes", #bad == 0, #bad > 0 and table.concat(bad, ", ") or "лише UWOW, UwowDB, UwowMiss, SLASH_UWOW1 і обнулення таблиць попередньої версії")
end

-- 7. покриття промахів v1 (не тест, замір)
do
    local tot, hit, byDom = 0, 0, {}
    for line in io.lines(TD .. "/replay.tsv") do
        local dom, kind, key, fld, spk = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
        if dom then
            tot = tot + 1
            local got
            if kind == "id" then got = U.ID(dom, key, fld) else got = U.T(dom, unesc(key), spk ~= "" and unesc(spk) or nil) end
            local b = byDom[dom] or { 0, 0 }; byDom[dom] = b
            b[1] = b[1] + 1
            if got then hit = hit + 1; b[2] = b[2] + 1 end
        end
    end
    local parts = {}
    for d, b in pairs(byDom) do parts[#parts + 1] = ("%s %d/%d"):format(d, b[2], b[1]) end
    table.sort(parts)
    report[#report + 1] = ("INFO replay-v1-misses: закрито %d з %d (%s)"):format(hit, tot, table.concat(parts, ", "))
end

-- 8. ядро й загальний інтерфейс: компактні пакети, формати, шрифти, фільтр збору, StaticPopup, UIErrors, HelpTip,
-- навчання, меню гри, заголовки вікон, налаштування, відсік аддонів, /uw (tests/surf_infra.lua)
SI.run(H, U, check)

-- 9. поверхні світу (агент world)
dofile(arg[0]:gsub("[^/]+$", "") .. "surf_world.lua")(H, U, check)

-- 10. досягнення, путівник, колекції, житло, гарнізон (агент coll)
SURF_COLL.run(H, U, check)

-- 11. персонаж, закляття, предмети, економіка (агент char)
SC.run(H, U, check, TD)

-- 12. /uw fix: кільце останніх текстів, вікно, запис у UwowMiss.fix, ліміти, бій (агент fix)
SF.run(H, U, check)

-- 13. нагадування завантажити збір і лічильник у /uw stats (агент cycle)
require("surf_cycle").run(H, U, check)

for _, l in ipairs(report) do print(l) end
print(fails == 0 and "ALL PASS" or ("FAILED: " .. fails))
os.exit(fails == 0 and 0 or 1)
