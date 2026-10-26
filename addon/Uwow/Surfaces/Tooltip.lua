-- Uwow · Surfaces/Tooltip.lua — тултіпи через TooltipDataProcessor: дані Blizzard (data.lines із типами рядків і
-- lineIndex), без tooltip:Show() — пост-обробник іде до Show, тож розмір тултіп рахує вже з перекладом.
--   предмет: назва (itemID), художній опис (itemID), ефекти «Використання/Якщо одягнено» (опис закляття за spellID
--            через U.SpellText), службові рядки (прив'язка, слот, тип, стати, рівень, міцність…) і праві написи,
--            суфікси, чари, назви наборів «(2/5)», предмети набору, бонуси набору;
--   закляття й аура: назва (spellID), опис (U.SpellText; шаблон EN ↔ показаний текст), службові рядки;
--            заголовок, поставлений до AppendInfo (тултіп таланту), — за EN-назвою закляття;
--   макрос «#showtooltip» → закляття; валюта: назва й опис (currencyID); маунт (mountID);
--   (іграшки й досягнення — поверхні агента coll);
--   NPC: лише ім'я (рядок 1), гравці відсіюються за GUID; рядок 2 (заняття) — агент world.
local U = UWOW
local K

local function secret(v) return not pcall(function() return v == "" end) end

-- тултіпи, які перекладаємо: основний, посилання з чату, порівняння
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
               "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
local allowed = setmetatable({}, { __mode = "k" })
local function refreshAllowed()
    for _, n in ipairs(TIPS) do
        local t = _G[n]
        if t then allowed[t] = n end
    end
end

local function tipName(tt)
    if not tt or (tt.IsForbidden and tt:IsForbidden()) then return nil end
    local n = allowed[tt]
    if not n then refreshAllowed(); n = allowed[tt] end
    return n
end

local function fsAt(name, side, i) return _G[name .. side .. i] end

local LT = {}                                -- Enum.TooltipDataLineType (заповнюється при встановленні)

-- Рядки тултіпа з даних: { i = індекс напису, t = тип, d = дані рядка }. Без даних — усі рядки по порядку.
local function linesOf(tt, data)
    local out = {}
    local dl = type(data) == "table" and data.lines
    if type(dl) == "table" and #dl > 0 then
        for k, d in ipairs(dl) do
            if type(d) == "table" then out[#out + 1] = { i = d.lineIndex or k, t = d.type, d = d } end
        end
    else
        for i = 1, (tt.NumLines and tt:NumLines() or 0) do out[#out + 1] = { i = i } end
    end
    return out
end

-- службовий рядок (праві написи, ціна, «Унікальний», стати…): переклад за текстом, промах — у ui
local function plainLine(fs, surf, maxMiss)
    return K.label(fs, surf, { "ui", "collections" }, maxMiss or 80)
end

-- ── предмет ────────────────────────────────────────────────────────────────────────────────────────────
local EFFECT_TYPES, EFFECT_PREFIX = {}, {}

-- spellID-кандидати для рядка ефекту предмета: з даних рядка, з пакета ефектів (якщо компілятор його дасть),
-- закляття «Використання» предмета з API.
local function effectSpells(itemID, d)
    local list, seen = {}, {}
    local function add(s)
        s = tonumber(s)
        if s and s > 0 and not seen[s] then seen[s] = true; list[#list + 1] = s end
    end
    if type(d) == "table" and not secret(d.spellID) then add(d.spellID) end
    local fx = U.PACK_ADDON.itemfx and (U.packs.itemfx or U.Need("itemfx"))
    local v = fx and fx[itemID]
    if type(v) == "string" then for s in v:gmatch("%d+") do add(s) end end
    if C_Item and C_Item.GetItemSpell then
        local ok, _, sid = pcall(C_Item.GetItemSpell, itemID)
        if ok and not secret(sid) then add(sid) end
    end
    return list
end

local function splitEffect(en)
    for _, p in ipairs(EFFECT_PREFIX) do
        if en:sub(1, #p) == p then
            return p, (en:sub(#p + 1):gsub("^%s+", ""))
        end
    end
    return nil, en
end

-- «Використання: …» / «Якщо одягнено: …»: тіло — опис закляття з живими числами; префікс і хвіст «(Перезарядка …)» —
-- рядки UI. Переклад тіла — лише через шаблон закляття (числа з показаного тексту), без тіла не чіпаємо нічого.
local function effectLine(fs, en, itemID, d)
    local ua = U.T("ui", en)
    if ua then return K.set(fs, ua, en) end
    local prefix, body = splitEffect(en)
    local tail
    local b2, cd = body:match("^(.-)%s*(%b())%s*$")
    if cd and cd:lower():find("cooldown", 1, true) then body, tail = b2, cd end
    local sids = effectSpells(itemID, d)
    local tr
    for _, sid in ipairs(sids) do
        tr = U.SpellText.Render(sid, body) or U.SpellText.Render(sid, body, true)
        if tr then break end
    end
    if not tr then
        if #body > 3 then U.Miss("sdesc", "tooltip-item-effect", body, sids[1] or itemID) end
        return false
    end
    local p = prefix and (K.str(prefix) or prefix)
    local t = tail and (K.str(tail) or tail)
    return K.set(fs, (p and (p .. " ") or "") .. tr .. (t and (" " .. t) or ""), en)
end

-- назва предмета; «Keystone: <підземелля>» — формат + назва підземелля (статична назва ключа стерла б підземелля)
local function itemNameLine(fs, en, itemID)
    local kfmt = rawget(_G, "CHALLENGE_MODE_KEYSTONE_NAME")
    local kp = kfmt and K.fmtPattern(kfmt)
    local dungeon = kp and en:match(kp)
    if dungeon then
        local core, tail = dungeon:match("^(.-)(%s*%b())$")
        core = core or dungeon
        local d = K.str(core, { "journal", "questui", "ui" })
        local ua = K.fmt(kfmt, (d or core) .. (tail or ""))
        if ua then return K.set(fs, ua, en) end
        U.Miss("ui", "tooltip-item", kfmt)
        return false
    end
    local ua = U.ID("item", itemID, "name") or K.str(en, "collections")     -- предмет-маунт/улюбленець
    if ua then return K.set(fs, ua, en) end
    U.Miss("item", "tooltip-item", en, itemID)
    return false
end

-- художній опис: у грі в лапках, у даних — без них
local function flavorLine(fs, en, itemID)
    local q1, core, q2 = en:match('^(%s*"?)(.-)("?%s*)$')
    local ua = U.ID("item", itemID, "flavor") or K.str(core, "ui")
    if ua then return K.set(fs, q1 .. ua .. q2, en) end
    U.Miss("item", "tooltip-item-flavor", core, itemID)
    return false
end

-- Набори: «Назва набору (2/5)», предмети набору з відступом, «(2) Set: …» / «Set: …».
local function setLine(fs, en)
    local base, tail = en:match("^(.-)%s*(%(%d+/%d+%))$")
    if base then
        local ua = K.str(base, { "collections", "ui" })
        if ua then return K.set(fs, ua .. " " .. tail, en) end
        return nil
    end
    local lead, core = en:match("^(%s+)(%S.*)$")
    if lead then
        local ua = K.str(core, { "collections", "ui" })
        if ua then return K.set(fs, lead .. ua, en) end
        return nil
    end
end

-- рядок «- Назва» у блоці порівняння (If you replace this item…)
local function dashLine(fs, en)
    local dash, rest = en:match("^(%s*%-%s+)(.+)$")
    if not rest then return nil end
    local ua = K.str(rest, { "ui", "collections" })
    if ua then return K.set(fs, dash .. ua, en) end
end

-- чари «Enchanted: X»: увесь рядок, інакше префікс і назва чару окремо (лише якщо перекладено назву)
local function enchantLine(fs, en)
    local ua = K.str(en, { "ui", "collections" })
    if ua then return K.set(fs, ua, en) end
    local p = rawget(_G, "ENCHANTED_TOOLTIP_LINE")
    local pat = p and K.fmtPattern(p)
    local name = pat and en:match(pat)
    if not name then return nil end
    local nu = K.str(name, { "collections", "ui" })
    local full = nu and K.fmt(p, nu)
    if full then return K.set(fs, full, en) end
    if not nu then U.Miss("collections", "tooltip-item-enchant", name) end
end

local function infoLine(fs, en)
    local r = setLine(fs, en)
    if r ~= nil then return r end
    local ua = K.str(en, { "ui", "collections" })
    if ua then return K.set(fs, ua, en) end
    if dashLine(fs, en) then return true end
    -- промах: лише короткі рядки без розмітки; відступ — це предмети набору (назви, домен item)
    if #en <= 160 and not en:find("^%s") and not en:find("|[TH]") then U.Miss("ui", "tooltip-item-line", en) end
    return false
end

local function itemTip(tt, data)
    local name = tipName(tt)
    if not name or type(data) ~= "table" or secret(data.id) then return end
    local itemID = tonumber(data.id)
    if not itemID then return end
    for _, L in ipairs(linesOf(tt, data)) do
        local fs = fsAt(name, "TextLeft", L.i)
        local en = K.text(fs)
        if en and not K.cyr(en) then
            local t = L.t
            if L.i == 1 or t == LT.ItemName or t == LT.ToyName then
                itemNameLine(fs, en, itemID)
            elseif t == LT.FlavorText or t == LT.ToyDescription then
                flavorLine(fs, en, itemID)
            elseif EFFECT_TYPES[t] or (t == nil and splitEffect(en)) or (t == LT.ToyEffect) then
                effectLine(fs, en, itemID, L.d)
            elseif t == LT.ItemEnchantmentPermanent then
                enchantLine(fs, en)
            elseif t ~= LT.SellPrice and t ~= LT.Blank and t ~= LT.Separator then
                infoLine(fs, en)
            end
        end
        local fr = fsAt(name, "TextRight", L.i)
        local er = K.text(fr)
        if er and not K.cyr(er) then plainLine(fr, "tooltip-item-right", 40) end
    end
    -- «Sell Price:» — префікс грошового фрейму, не рядок тултіпа
    for i = 1, 4 do
        local pf = _G[name .. "MoneyFrame" .. i .. "PrefixText"]
        if pf then plainLine(pf, "tooltip-item-money", 40) end
    end
end

-- ── закляття / аура ────────────────────────────────────────────────────────────────────────────────────
local function spellNameEN(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" and not secret(n) then return n end
    end
end

local function spellTip(tt, data, aura, sid)
    local name = tipName(tt)
    if not name or type(data) ~= "table" then return end
    local id = sid or data.id
    if secret(id) then return end
    id = tonumber(id)
    if not id then return end
    local lines = linesOf(tt, data)
    local first = lines[1] and lines[1].i or 1
    -- заголовок, поставлений до AppendInfo (тултіп таланту): перекладаємо, якщо це EN-назва цього закляття
    if first > 1 then
        local fs = fsAt(name, "TextLeft", 1)
        local en = K.text(fs)
        if en and not K.cyr(en) and en == spellNameEN(id) then
            local ua = U.ID("spell", id, "name")
            if ua then K.set(fs, ua, en) end
        end
        for i = 2, first - 1 do                                     -- «Наступний ранг:» тощо між вставками
            local f2 = fsAt(name, "TextLeft", i)
            local e2 = K.text(f2)
            if e2 and not K.cyr(e2) then K.label(f2, nil, "ui") end
        end
    end
    local missCand
    for _, L in ipairs(lines) do
        local fs = fsAt(name, "TextLeft", L.i)
        local en = K.text(fs)
        if en and not K.cyr(en) then
            if L.i == 1 or L.t == LT.SpellName then
                local ua = U.ID("spell", id, "name")
                if ua then K.set(fs, ua, en) else U.Miss("spell", "tooltip-spell", en, id) end
            else
                local ua = (#en >= 3) and (U.SpellText.Render(id, en, aura) or U.SpellText.Render(id, en, not aura))
                if ua then
                    K.set(fs, ua, en)
                else
                    ua = K.str(en, "ui")
                    if ua then
                        K.set(fs, ua, en)
                    elseif L.t == LT.SpellDescription or (#en > 20 and en:find("%a.-%s.-%a")) then
                        if not missCand or #en > #missCand then missCand = en end
                    elseif #en <= 60 and not en:find("|[TH]") then
                        U.Miss("ui", "tooltip-spell-line", en)
                    end
                end
            end
        end
        local fr = fsAt(name, "TextRight", L.i)
        local er = K.text(fr)
        if er and not K.cyr(er) then plainLine(fr, "tooltip-spell-right", 40) end
    end
    if missCand then U.Miss("sdesc", aura and "tooltip-aura-desc" or "tooltip-spell-desc", missCand, id) end
end

local function macroTip(tt, data)
    if not tipName(tt) or not GetActionInfo then return end
    local owner = tt.GetOwner and tt:GetOwner()
    local slot = type(owner) == "table" and owner.action
    if not slot or secret(slot) then return end
    local ok, kind, id = pcall(GetActionInfo, slot)
    if not ok or kind ~= "macro" or secret(id) then return end
    local sid = GetMacroSpell and GetMacroSpell(id)
    if sid and not secret(sid) then spellTip(tt, data, false, sid) end
end

-- ── валюта, маунт ──────────────────────────────────────────────────────────────────────────────────────
local function stripColor(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- назва (рядок 1), опис (рядок, що дорівнює EN-опису з API), решта — рядки UI
local function idTip(tt, data, dom, nameF, descF, descEN, surf)
    local name = tipName(tt)
    if not name or type(data) ~= "table" or secret(data.id) then return end
    local id = tonumber(data.id)
    local den = id and descEN(id)
    for _, L in ipairs(linesOf(tt, data)) do
        local fs = fsAt(name, "TextLeft", L.i)
        local en = K.text(fs)
        if en and not K.cyr(en) then
            if L.i == 1 then
                if id then K.byID(fs, dom, id, nameF, surf) end
            elseif den and stripColor(en) == den then
                local ua = U.ID(dom, id, descF)
                if ua then K.set(fs, ua, en) else U.Miss(dom, surf .. "-desc", den, id) end
            else
                plainLine(fs, surf .. "-line", 60)
            end
        end
        local fr = fsAt(name, "TextRight", L.i)
        if K.text(fr) then plainLine(fr, surf .. "-right", 40) end
    end
end

local function currencyDesc(id)
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    local d = ok and type(info) == "table" and info.description
    return type(d) == "string" and d ~= "" and not secret(d) and stripColor(d) or nil
end

local function mountDesc(id)
    if not (C_MountJournal and C_MountJournal.GetMountInfoExtraByID) then return nil end
    local ok, _, d = pcall(C_MountJournal.GetMountInfoExtraByID, id)
    return ok and type(d) == "string" and d ~= "" and not secret(d) and stripColor(d) or nil
end

U.Surface("tooltip", function()
    if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then return end
    K = U.CharKit
    local T = Enum.TooltipDataType
    for k, v in pairs(Enum.TooltipDataLineType or {}) do LT[k] = v end
    for _, k in ipairs({ "ItemSpellTriggerOnUse", "ItemSpellTriggerOnEquip", "ItemSpellTriggerOnProc", "ItemSpellTriggerLearn" }) do
        if LT[k] then EFFECT_TYPES[LT[k]] = true end
    end
    for _, g in ipairs({ "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONPROC", "ITEM_SPELL_TRIGGER_ONLEARN" }) do
        local v = rawget(_G, g)
        if type(v) == "string" and v ~= "" then EFFECT_PREFIX[#EFFECT_PREFIX + 1] = v end
    end
    refreshAllowed()

    local function post(t, fn)
        if t ~= nil then TooltipDataProcessor.AddTooltipPostCall(t, K.guard("tooltip:" .. tostring(t), fn)) end
    end
    post(T.Item, itemTip)
    post(T.Spell, function(tt, data) spellTip(tt, data, false) end)
    post(T.UnitAura, function(tt, data) spellTip(tt, data, true) end)
    post(T.Macro, macroTip)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        post(T.Currency, function(tt, data) idTip(tt, data, "currency", "name", "desc", currencyDesc, "tooltip-currency") end)
    end
    post(T.Mount, function(tt, data) idTip(tt, data, "mount", "n", "d", mountDesc, "tooltip-mount") end)

    -- NPC: лише рядок 1 (ім'я). Рядок 2 (заняття) — поверхня агента world. Юніт-токен у Midnight буває
    -- секретним, тож гравців відсіюємо за GUID з даних тултіпа (Creature-/Vehicle-), без UnitIsPlayer.
    post(T.Unit, function(tt, data)
        if tt ~= GameTooltip or type(data) ~= "table" then return end
        local guid = data.guid
        if type(guid) ~= "string" or secret(guid) or not (guid:find("^Creature%-") or guid:find("^Vehicle%-")) then return end
        local fs = _G[(tt:GetName() or "GameTooltip") .. "TextLeft1"]
        local en = K.text(fs)
        if not en or K.cyr(en) then return end
        local ua = U.TranslateName(en)
        if ua then U.Apply(fs, ua, en) else U.Miss("names", "tooltip-unit", en) end
    end)
end)
