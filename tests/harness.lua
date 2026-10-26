-- tests/harness.lua — офлайн-середовище WoW для Uwow (Lua 5.1): заглушки API і завантаження аддонів зі збірки.
-- H.load(buildDir) вантажить Uwow за .toc; C_AddOns.LoadAddOn вантажить пакети Uwow_* з тієї ж збірки.
local H = {}
H.hooks, H.events, H.filters, H.tooltipPost = {}, {}, {}, {}
H.globalWrites = {}

local function noop() end
-- напис: зберігає текст і шрифт (для перевірок підміни й кириличного шрифту)
local fsMT = {}
fsMT.__index = function(t, k)
    if k == "SetText" then return function(self, s) rawset(self, "_text", s) end end
    if k == "GetText" then return function(self) return rawget(self, "_text") end end
    if k == "SetFont" then return function(self, p, sz, fl) rawset(self, "_font", { p, sz, fl }); return true end end
    if k == "GetFont" then return function(self)
        local f = rawget(self, "_font") or { rawget(self, "_baseFont") or "Fonts\\FRIZQT__.TTF", 12, "" }
        return f[1], f[2], f[3]
    end end
    if k == "GetStringWidth" then return function(self) return #(rawget(self, "_text") or "") * 6 end end
    if k == "GetNumLines" then return function() return 1 end end
    if k == "GetWidth" or k == "GetHeight" or k == "GetStringHeight" then return function() return 100 end end
    if k == "IsShown" then return function() return true end end
    if k == "GetParent" then return function(self) return rawget(self, "_parent") end end
    return noop
end
function H.fontString(parent) return setmetatable({ _parent = parent }, fsMT) end

local frameMT = {}
frameMT.__index = function(t, k)
    if k == "RegisterEvent" then return function(self, e) H.events[e] = H.events[e] or {}; table.insert(H.events[e], self) end end
    if k == "SetScript" then return function(self, w, f) rawset(self, "_" .. w, f) end end
    if k == "HookScript" then return function(self, w, f)          -- список «_hooks_<скрипт>», як у копіях coll/world
        local l = rawget(self, "_hooks_" .. w) or {}; rawset(self, "_hooks_" .. w, l); l[#l + 1] = f
    end end
    if k == "CreateFontString" then return function(self) return H.fontString(self) end end
    if k == "CreateTexture" then return function(self) return H.frame(nil, self) end end   -- текстура: Show/Hide/SetColorTexture — заглушки
    if k == "GetFontString" then return function(self)
        local fs = rawget(self, "_fs") or H.fontString(self); rawset(self, "_fs", fs); return fs
    end end
    if k == "SetText" then return function(self, s) self:GetFontString():SetText(s) end end
    if k == "GetText" then return function(self) return self:GetFontString():GetText() end end
    if k == "SetChecked" then return function(self, v) rawset(self, "_checked", v and true or false) end end
    if k == "GetChecked" then return function(self) return rawget(self, "_checked") end end
    if k == "IsShown" then return function(self) return rawget(self, "_hidden") ~= true end end
    if k == "GetName" then return function(self) return rawget(self, "_name") end end
    if k == "GetParent" then return function(self) return rawget(self, "_parent") end end
    return noop
end
function H.frame(name, parent) return setmetatable({ _name = name, _parent = parent }, frameMT) end
-- виконати скрипт фрейму разом із HookScript-хуками
function H.script(frame, w, ...)
    local f = rawget(frame, "_" .. w)
    if f then f(frame, ...) end
    for _, h in ipairs(rawget(frame, "_hooks_" .. w) or {}) do h(frame, ...) end
end

-- тултіп: SetText/AddLine/AddDoubleLine/ClearLines ведуть рядки <ім'я>TextLeftN/TextRightN; Fill({ {ліво, право?}, … })
-- ставить готовий набір рядків (як після заповнення даними); owner — поле, GetOwner/SetOwner/IsOwned
function H.tooltip(name)
    local t = H.frame(name)
    t.n = 0
    function t:NumLines() return self.n end
    function t:GetOwner() return self.owner end
    function t:SetOwner(o) self.owner = o end
    function t:IsOwned(o) return self.owner == o end
    function t:GetUnit() return nil, nil end
    function t:IsForbidden() return false end
    -- методи не кличуть один одного через self: хук на AddLine не має спрацьовувати від SetText (як у грі)
    local function clear(self)
        for i = 1, math.max(self.n, 30) do _G[name .. "TextLeft" .. i] = nil; _G[name .. "TextRight" .. i] = nil end
        self.n = 0
    end
    local function add(self, l, r)
        self.n = self.n + 1
        local fl = H.fontString(self); fl:SetText(l)
        local fr = H.fontString(self); fr:SetText(r)
        _G[name .. "TextLeft" .. self.n], _G[name .. "TextRight" .. self.n] = fl, fr
    end
    t.ClearLines, t.AddDoubleLine = clear, add
    function t:AddLine(s) add(self, s) end
    function t:SetText(s) clear(self); add(self, s) end
    function t:Fill(lines) clear(self); for _, l in ipairs(lines) do add(self, l[1], l[2]) end end
    return t
end

function H.install(build)
    H.build = build
    CreateFrame = function(_, name, parent) return H.frame(name, parent) end
    -- як у грі: оригінал, потім хук; ціль без функції — хук усе одно викликається (заглушки поверхонь)
    hooksecurefunc = function(a, b, c)
        local t, m, f = a, b, c
        if type(a) ~= "table" then t, m, f = _G, a, b end
        H.hooks[#H.hooks + 1] = type(a) == "table" and ("tbl." .. tostring(m)) or tostring(m)
        local orig = t[m]
        if type(orig) ~= "function" then orig = noop end
        rawset(t, m, function(...)
            local r = (function(...) return { n = select("#", ...), ... } end)(orig(...))
            f(...)
            return unpack(r, 1, r.n)
        end)
    end
    C_Timer = { After = function(_, f) H.timers = H.timers or {}; table.insert(H.timers, f) end,
                NewTicker = function() return { Cancel = noop } end }
    InCombatLockdown = function() return false end
    UnitName = function(u) if u == "player" then return "Rinss" end return "Тест" end
    UnitSex = function() return H.sex or 2 end
    UnitClass = function() return "Warrior", "WARRIOR" end
    UnitRace = function() return "Tauren", "Tauren" end
    UnitIsPlayer = function() return false end
    GetBuildInfo = function() return "12.1.5", "70575", "Oct 2026", 120105 end
    ReloadUI = noop
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) H.chat = H.chat or {}; table.insert(H.chat, m) end }
    SlashCmdList = {}
    ChatFrame_AddMessageEventFilter = function(e, f) H.filters[e] = f end
    -- кілька обробників на тип (Unit реєструють і world, і char); H.tooltipPost[тип](tt, data) викликає всі
    local postMT = { __call = function(l, ...) for _, f in ipairs(l) do f(...) end end }
    TooltipDataProcessor = { AddTooltipPostCall = function(t, f)
        local l = H.tooltipPost[t] or setmetatable({}, postMT); H.tooltipPost[t] = l; l[#l + 1] = f
    end }
    -- одна таблиця Enum на всі набори (значення — 12.x); набори поверхонь її не перевизначають
    Enum = {
        TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Currency = 5, UnitAura = 7, Mount = 10, Achievement = 12, Toy = 19,
                            Macro = 25 },
        TooltipDataLineType = { None = 0, Blank = 1, SellPrice = 11, SpellName = 13, ItemEnchantmentPermanent = 15,
                                ItemBinding = 20, EquipSlot = 21, ItemName = 22, Separator = 23, ToyName = 24, ToyEffect = 26,
                                ToyDescription = 28, ItemLevel = 31, SpellPassive = 33, SpellDescription = 34, FlavorText = 37,
                                ItemSpellTriggerLearn = 38, ItemSpellTriggerOnUse = 44, ItemSpellTriggerOnEquip = 45,
                                ItemSpellTriggerOnProc = 46 },
        SpellBookSpellBank = { Player = 0 },
    }
    -- тултіпи: GameTooltip / ItemRefTooltip спільні для всіх наборів (рядки — глобали <ім'я>TextLeftN)
    GameTooltip, ItemRefTooltip = H.tooltip("GameTooltip"), H.tooltip("ItemRefTooltip")
    -- контейнер сповіщень (хукають coll і world)
    AlertFrame = { AddAlertFrame = noop }
    H.registry = {}
    EventRegistry = {
        RegisterCallback = function(_, ev, fn, owner)
            H.registry[ev] = H.registry[ev] or {}
            table.insert(H.registry[ev], function(...) return fn(owner, ...) end)
        end,
        TriggerEvent = function(_, ev, ...) for _, f in ipairs(H.registry[ev] or {}) do f(...) end end,
    }
    QuestInfo_Display = noop
    GossipOptionButtonMixin, GossipGreetingTextMixin = {}, {}
    C_AddOns = {
        GetAddOnMetadata = function() return "test" end,
        IsAddOnLoaded = function(n) return n == "Uwow" end,
        EnableAddOn = noop, DisableAddOn = noop,
        LoadAddOn = function(name) return H.loadAddon(name) end,
    }
end

local function readToc(dir, name)
    local files = {}
    for line in io.lines(dir .. "/" .. name .. "/" .. name .. ".toc") do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

function H.loadAddon(name)
    local f = io.open(H.build .. "/" .. name .. "/" .. name .. ".toc")
    if not f then return false end
    f:close()
    for _, fn in ipairs(readToc(H.build, name)) do
        local chunk = assert(loadfile(H.build .. "/" .. name .. "/" .. fn))
        chunk(name, {})
    end
    return true
end

function H.fire(e, ...)
    for _, fr in ipairs(H.events[e] or {}) do
        local f = rawget(fr, "_OnEvent")
        if f then f(fr, e, ...) end
    end
end

function H.runTimers()
    local t = H.timers or {}
    H.timers = {}
    for _, f in ipairs(t) do f() end
end

-- pre(H) і H.setup — заглушки фреймів Blizzard для тестів поверхонь (tests/surf_*.lua), до завантаження аддона
function H.boot(build, pre)
    H.install(build)
    for _, f in ipairs(H.setup or {}) do f(H) end
    if pre then pre(H) end
    local okw, ws = pcall(require, "world_stubs")              -- заглушки агента world, якщо файл є
    if okw and type(ws) == "function" then ws(H) end
    local t0, m0 = os.clock(), collectgarbage("count")
    H.loadAddon("Uwow")
    H.coreMs = (os.clock() - t0) * 1000
    collectgarbage("collect")
    H.coreMb = (collectgarbage("count") - m0) / 1024
    -- дані попередньої версії в тому самому файлі SavedVariables (для тесту міграції)
    UwowSettingsDB = { showOriginal = true }
    UwowCaptureDB = { broadcast = { ["Hello there."] = true, ["Bye now."] = { ctx = "monster_say", val = "Bob" },
                                    ["{name}, come here!"] = true }, meta = { x = 1 } }
    H.fire("ADDON_LOADED", "Uwow")
    H.fire("PLAYER_LOGIN")
    return UWOW
end

return H
