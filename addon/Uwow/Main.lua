-- Uwow · Main.lua — реєстр поверхонь, налаштування, разова міграція збережених даних попередньої версії,
-- прогрів пакетів, хуки на завантаження модулів Blizzard (U.OnAddon), списки імен для фільтра збору, команда /uw.
local U = UWOW
-- npcNames — імена NPC на неймплейтах (Surfaces/WorldNpc.lua, агент world); типово вимкнено
local DEFAULTS = { enabled = true, original = false, capture = true, font = "auto", npcNames = false }
U.DEFAULTS = DEFAULTS

local surfaces, order = {}, {}
function U.Surface(name, install)                 -- поверхні реєструються під час завантаження файлів
    surfaces[name] = { install = install, ok = nil }
    order[#order + 1] = name
end

function U.Enabled() return U.Settings and U.Settings.enabled and not U.Settings.original end

local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff4fb3ffUwow|r: " .. tostring(msg)) end
U.Say = say

-- Зміна налаштування з будь-якого місця (вікно параметрів, /uw) з миттєвим ефектом, без /reload.
function U.SetOption(key, value)
    if not U.Settings then return end
    U.Settings[key] = value
    if key == "enabled" or key == "original" then U.Refresh()
    elseif key == "font" then U.RefreshFonts() end
end

-- Хук на модуль, що вантажиться пізніше (Blizzard_* LoadOnDemand): fn виконується одразу, якщо модуль уже
-- завантажений (або ready() уже повертає істину — наприклад, потрібний фрейм існує), інакше — на його ADDON_LOADED.
-- Помилки не ламають решту: лягають у /uw stats.
local addonHooks, hookErrors = {}, {}
U.hookErrors = hookErrors
local function runHook(name, fn)
    local ok, err = pcall(fn)
    if not ok then hookErrors[#hookErrors + 1] = name .. ": " .. tostring(err) end
end
function U.OnAddon(name, fn, ready)
    if (ready and ready()) or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)) then
        runHook(name, fn); return
    end
    local l = addonHooks[name]
    if not l then l = {}; addonHooks[name] = l end
    l[#l + 1] = fn
end

-- ── хто «свій» для фільтра збору (Core: U.people, U.peoplePhrases, U.realms, U.addonNames) ─────────────
-- Імена групи й друзів, назва своєї гільдії, реалми (свій і з'єднані) — щоб у UwowMiss не потрапляли ніки й гільдії.
-- Реалми — лише як частина «Ім'я-Реалм», не окремим словом: назви реалмів — це слова лору (Draenor, Silvermoon).
-- Склад гільдії свідомо не беремо: сотні ніків-слів («Shadow», «Light») відсіювали б звичайні рядки UI; від ніків у
-- шаблонних повідомленнях захищає те, що поверхні збирають шаблон GlobalString, а не готовий текст.
local function clear(t) for k in pairs(t) do t[k] = nil end end
local function rebuildPeople()
    local people, phrases, realms = U.people, U.peoplePhrases, U.realms
    local me = U.Player()
    clear(people); clear(phrases)
    local function addRealm(r)
        if type(r) == "string" and r ~= "" and not U.IsSecret(r) then realms[(r:gsub("[%s%-']", ""))] = true end
    end
    local function add(n, realm)
        if type(n) ~= "string" or n == "" or U.IsSecret(n) then return end
        local nm, r = n:match("^([^%-]+)%-(.+)$")
        if nm then n, realm = nm, r end
        if n ~= me and #n >= 3 then people[n] = true end
        addRealm(realm)
    end
    addRealm(GetRealmName and GetRealmName()); addRealm(GetNormalizedRealmName and GetNormalizedRealmName())
    if GetAutoCompleteRealms then for _, r in ipairs(GetAutoCompleteRealms() or {}) do addRealm(r) end end
    if UnitName then
        for i = 1, 4 do add(UnitName("party" .. i)) end
        if IsInRaid and IsInRaid() then for i = 1, 40 do add(UnitName("raid" .. i)) end end
    end
    local g = GetGuildInfo and GetGuildInfo("player")
    if type(g) == "string" and #g >= 4 and not U.IsSecret(g) then phrases[#phrases + 1] = g end
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local f = C_FriendList.GetFriendInfoByIndex(i)
            if f then add(f.name) end
        end
    end
end
U.RebuildPeople = rebuildPeople

local KNOWN_FOREIGN = { "dbm", "bigwigs", "littlewigs", "wa", "weakauras", "details", "rio", "raiderio", "msuf", "bbf",
                        "elvui", "plater", "mrt", "nsrt", "tsm", "auctionator", "rematch", "wim", "prat", "omnicd" }
local function rebuildAddons()
    local t = U.addonNames
    for _, n in ipairs(KNOWN_FOREIGN) do t[n] = true end
    if not (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo) then return end
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if type(name) == "string" and not name:find("^Blizzard_") and name ~= U.name and not name:find("^UwowData") then
            t[name:lower()] = true
            if type(title) == "string" then
                title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
                if #title >= 2 then t[title:lower()] = true end
            end
        end
    end
end

-- Разова міграція: попередня версія лишала в тому самому файлі SavedVariables таблиці UwowSettingsDB
-- (налаштування) і UwowCaptureDB (зібрані неперекладені рядки). Беремо звідти вимикач перекладу й показ
-- оригіналу, а зібрані рядки переносимо в UwowMiss, щоб сервер їх отримав. Потім обидві таблиці видаляємо.
local CAT_DOM = { broadcast = "dialog", gossip = "dialog", playerchoice = "dialog", books = "dialog",
                  objLines = "questui", ejmiss = "journal", npc = "names", subnames = "dialog" }
local SKIP = { meta = true, errors = true, diag = true, quests = true, npcSex = true, spellCapture = true, keystone = true,
               profdebug = true, ejloot = true, ejsuggest = true, uierr = true, globalStrings = true }

local function migrateOld()
    local db = U.Settings
    if db.migrated then return end
    local old = rawget(_G, "UwowSettingsDB")
    if type(old) == "table" then
        if old.enabled == false then db.enabled = false end
        if old.showOriginal then db.original = true end
    end
    local cap, n = rawget(_G, "UwowCaptureDB"), 0
    if type(cap) == "table" then
        local function take(cat, t)
            if type(t) ~= "table" then return end
            for k, v in pairs(t) do
                if type(k) == "string" then
                    local spk = type(v) == "table" and type(v.val) == "string" and (tostring(v.ctx or ""):find("^monster") or v.ctx == "cinematic") and v.val or nil
                    U.Miss(CAT_DOM[cat] or "ui", "v1:" .. cat, k, type(v) == "table" and v.id or nil, spk)
                    n = n + 1
                end
            end
        end
        for cat, t in pairs(cap) do
            if not SKIP[cat] and type(t) == "table" then
                if cat == "miss" or cat == "mail" then
                    for sub, st in pairs(t) do take(sub, st) end
                else
                    take(cat, t)
                end
            end
        end
    end
    UwowSettingsDB, UwowCaptureDB = nil, nil
    db.migrated = date and date("%Y-%m-%d %H:%M") or true
    if n > 0 then say(("перенесено %d зібраних рядків попередньої версії"):format(n)) end
end

-- ── нагадування завантажити збір (Ігор 26.10.2026: тестери просто грають, решта — само) ─────────────────────────
-- UwowMiss.d[домен].n — скільки різних неперекладених текстів записано у файл. Після входу в гру (раз за сесію Lua),
-- якщо від останнього нагадування додалось ≥ U.REMIND_EVERY, — один рядок у чат. Точка відліку — UwowDB.remindAt.
U.REMIND_EVERY = 100
function U.MissTotal()
    local n = 0
    if type(UwowMiss) == "table" and type(UwowMiss.d) == "table" then
        for _, t in pairs(UwowMiss.d) do
            if type(t) == "table" then n = n + (tonumber(t.n) or 0) end
        end
    end
    return n
end

function U.MissSinceRemind()
    local total = U.MissTotal()
    local at = U.Settings and tonumber(U.Settings.remindAt) or 0
    if at > total then at = total end              -- файл збору почистили — рахуємо заново
    return total - at, total
end

-- U.remindedSession: нагадування вже було в цій сесії Lua (після /reload — нова сесія, але remindAt не дасть повтору)
local function remindUpload()
    if U.remindedSession or not U.Settings then return end
    U.remindedSession = true
    local new, total = U.MissSinceRemind()
    if (tonumber(U.Settings.remindAt) or 0) > total then U.Settings.remindAt = total end
    if new < U.REMIND_EVERY then return end
    U.Settings.remindAt = total
    say(("зібрано %d нових текстів без перекладу — завантаж файл Uwow.lua на uwow.wearebob.dev/capture (/uw help — де він лежить)"):format(new))
end
U.RemindUpload = remindUpload

local WARM = { "quest", "spell", "item", "names", "journal", "collections" }

local function warmup(i)
    i = i or 1
    if i > #WARM then return end
    if InCombatLockdown and InCombatLockdown() then C_Timer.After(2, function() warmup(i) end) return end
    U.Need(WARM[i])
    C_Timer.After(0.5, function() warmup(i + 1) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:RegisterEvent("FRIENDLIST_UPDATE")
ev:SetScript("OnEvent", function(_, e, arg)
    if e == "ADDON_LOADED" and arg ~= U.name then
        local l = addonHooks[arg]
        if l then
            addonHooks[arg] = nil
            for _, fn in ipairs(l) do runHook(arg, fn) end
        end
    elseif e == "ADDON_LOADED" and arg == U.name then
        UwowDB = UwowDB or {}
        for k, v in pairs(DEFAULTS) do if UwowDB[k] == nil then UwowDB[k] = v end end
        U.Settings = UwowDB
        UwowMiss = UwowMiss or {}
        UwowMiss.build = select(4, GetBuildInfo and GetBuildInfo() or nil)
        UwowMiss.v = U.version
        migrateOld()
    elseif e == "PLAYER_LOGIN" then
        pcall(rebuildAddons)
        pcall(rebuildPeople)
        for _, name in ipairs(order) do
            local s = surfaces[name]
            s.ok, s.err = pcall(s.install)
        end
    elseif e == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, warmup)
        if not U.remindedSession then C_Timer.After(10, remindUpload) end
        if not U.Settings.welcomed then
            U.Settings.welcomed = U.version
            C_Timer.After(6, function()
                say(("v%s — українська для World of Warcraft. Команди: /uw help · налаштування: /uw options"):format(U.version))
            end)
        end
    elseif e == "GROUP_ROSTER_UPDATE" or e == "PLAYER_GUILD_UPDATE" or e == "FRIENDLIST_UPDATE" then
        pcall(rebuildPeople)
    elseif e == "PLAYER_REGEN_ENABLED" then
        U.FlushPending()
    end
end)

local HELP = {
    "/uw — перемкнути оригінал / переклад",
    "/uw on | off — увімкнути або вимкнути переклад",
    "/uw options — вікно налаштувань (також Esc → Параметри → AddOns → Uwow)",
    "/uw font auto | friz | arial | off — шрифт перекладених написів",
    "/uw capture — збір неперекладених рядків (зараз: %s)",
    "/uw npc — імена NPC на неймплейтах українською (увімк./вимк.)",
    "/uw stats — версія, влучання/промахи, стан поверхонь",
    "/uw selftest — самоперевірка даних збірки",
    "/uw fix [слово] — запропонувати свій переклад: останні тексти, пошук, текст під курсором",
    "  зібрані тексти й пропозиції лежать у WTF/Account/<акаунт>/SavedVariables/Uwow.lua — після /reload або виходу завантаж цей файл на uwow.wearebob.dev/capture",
}

SLASH_UWOW1 = "/uw"
SlashCmdList.UWOW = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "toggle" then
        U.ShowOriginal(not U.Settings.original)
        say(U.Settings.original and "показую оригінал" or "показую переклад")
    elseif cmd == "off" or cmd == "on" then
        U.SetOption("enabled", cmd == "on")
        say("переклад " .. (U.Settings.enabled and "увімкнено" or "вимкнено"))
    elseif cmd == "capture" then
        U.SetOption("capture", not U.Settings.capture); say("збір пропусків: " .. (U.Settings.capture and "так" or "ні"))
    elseif cmd == "npc" then
        U.SetOption("npcNames", not U.Settings.npcNames)
        say("імена NPC на неймплейтах: " .. (U.Settings.npcNames and "українською" or "оригінал"))
    elseif cmd == "font" then
        local ok = false
        for _, m in ipairs(U.FONT_MODES or {}) do if m == rest then ok = true end end
        if ok then U.SetOption("font", rest); say("шрифт перекладу: " .. rest)
        else say("шрифт: " .. tostring(U.Settings.font) .. " · варіанти: " .. table.concat(U.FONT_MODES or {}, ", ")) end
    elseif cmd == "options" or cmd == "opt" or cmd == "config" then
        if U.OpenOptions then U.OpenOptions() else say("вікно налаштувань недоступне") end
    elseif cmd == "stats" then
        local n = 0
        for _ in pairs(U.packs) do n = n + 1 end
        say(("v%s · доменів %d · влучань %d · промахів %d · відсіяно збором %d"):format(U.version, n, U.stats.hit,
            U.stats.miss, type(UwowMiss) == "table" and UwowMiss.filtered or 0))
        local new, total = U.MissSinceRemind()
        say(("зібрано текстів без перекладу: %d (нових від останнього нагадування: %d; збір %s)"):format(total, new,
            U.Settings.capture and "увімкнено" or "вимкнено"))
        for _, name in ipairs(order) do
            local s = surfaces[name]
            say(("  %s: %s"):format(name, s.ok and "ok" or ("помилка " .. tostring(s.err))))
        end
        for _, e in ipairs(hookErrors) do say("  помилка хука " .. e) end
    elseif cmd == "fix" then
        if U.OpenFix then U.OpenFix(rest) else say("вікно виправлень недоступне") end
    elseif cmd == "selftest" and U.SelfTest then
        U.SelfTest()
    else
        for i, l in ipairs(HELP) do say(i == 5 and l:format(U.Settings.capture and "так" or "ні") or l) end
    end
end
