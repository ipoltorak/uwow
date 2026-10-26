-- Uwow · Surfaces/UiFix.lua — /uw fix: тестер пропонує свій переклад. Вікно (наш фрейм без шаблонів Blizzard —
-- шаблони з $parent на анонімному батьку дали б глобальні імена) зі списком останніх текстів ядра (U.recent: що
-- аддон переклав або не зміг), пошуком, полем «твій варіант» і коментарем. «Зберегти» дописує запис у UwowMiss.fix
-- (контракт docs/feedback-brief.md): { t, d, id, f, h, en, ua, s, c, v }, ≤500 записів, рядки ≤2000 символів.
-- Текст під курсором: рядки GameTooltip, якщо він показаний, інакше написи фрейму під мишею (GetMouseFoci) — лише
-- читання, без хуків і без змін чужих фреймів. У бою вікно не відкривається, а відкрите ховається.
local U = UWOW

local FIX_MAX, STR_MAX, ROWS, ROW_H = 500, 2000, 9, 18
local W, H = 600, 470
U.FIX_MAX, U.FIX_STR_MAX = FIX_MAX, STR_MAX

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function cyrText(s) return s:find("[\208\209\210]") ~= nil end

-- Перші n символів UTF-8 (не ріже літеру посередині).
local function cut(s, n)
    if type(s) ~= "string" then return "" end
    if #s <= n then return s end
    local i, c = 1, 0
    while i <= #s do
        c = c + 1
        if c > n then return s:sub(1, i - 1) end
        local b = s:byte(i)
        i = i + (b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1)
    end
    return s
end
U.FixCut = cut

local function trim(s) return type(s) == "string" and (s:gsub("^%s+", ""):gsub("%s+$", "")) or "" end

-- Хеш ключа v2 рядком (52 біти не влазять у %.14g tostring): лише для текстових записів, ID-записи мають id+f.
local function keyHash(r)
    if r.id then return nil end
    local key = U.Norm.norm(r.k or r.en, r.a, U.Player())
    if key == "" then return nil end
    return string.format("%.0f", U.Norm.hash(key))
end

-- Запис-пропозиція → UwowMiss.fix. → запис або nil, причина.
function U.FixSave(r, suggestion, comment)
    if type(r) ~= "table" or type(r.en) ~= "string" then return nil, "не вибрано текст" end
    local s, c = trim(suggestion), trim(comment)
    if s == "" then return nil, "порожній варіант" end
    local ua = r.ua or ""
    if s == ua and c == "" then return nil, "варіант збігається з поточним перекладом" end
    if type(UwowMiss) ~= "table" then return nil, "збережені дані ще не завантажені" end
    local fix = UwowMiss.fix
    if type(fix) ~= "table" then fix = {}; UwowMiss.fix = fix end
    local e = {
        t = time and time() or 0, d = r.d or "ui", id = tonumber(r.id), f = r.f, h = keyHash(r),
        en = cut(r.en, STR_MAX), ua = cut(ua, STR_MAX), s = cut(s, STR_MAX), c = cut(c, STR_MAX),
        v = tostring(U.version),
    }
    fix[#fix + 1] = e
    while #fix > FIX_MAX do table.remove(fix, 1) end
    return e
end

-- Останні тексти, новіші нагорі (копії записів кільця: кільце ядро перевикористовує).
function U.FixRecent()
    local out = {}
    for _, r in ipairs(U.recent or {}) do
        if r.en then out[#out + 1] = { d = r.d, id = r.id, f = r.f, en = r.en, ua = r.ua, a = r.a, k = r.k, n = r.n } end
    end
    table.sort(out, function(a, b) return (a.n or 0) > (b.n or 0) end)
    return out
end

-- Тексти під курсором: рядки тултіпа або написи фрейму під мишею. Наш переклад — з U.orig (EN ↔ UA), контекст
-- (домен, id) — з кільця ядра. Лише читання; усе під pcall.
local win
local function hovered()
    local out, seen = {}, {}
    local function add(fs)
        if #out >= 12 or type(fs) ~= "table" then return end
        local cur = U.GetText(fs)
        if not cur then return end
        local o = U.orig[fs]
        local en, ua
        if o and (cur == o.ua or cur == o.en) then en, ua = o.en, o.ua
        elseif not cyrText(cur) then en = cur
        else return end
        if seen[en] or #trim(en) < 2 then return end
        seen[en] = true
        local r = U.recentByEn and U.recentByEn[en]
        out[#out + 1] = { en = en, ua = ua or (r and r.ua), d = r and r.d, id = r and r.id, f = r and r.f,
                          a = r and r.a, k = r and r.k, hover = true }
    end
    pcall(function()
        local tt = GameTooltip
        if tt and not (tt.IsForbidden and tt:IsForbidden()) and tt:IsShown() then
            local name = tt:GetName() or "GameTooltip"
            for i = 1, math.min(tt:NumLines() or 0, 30) do
                add(_G[name .. "TextLeft" .. i]); add(_G[name .. "TextRight" .. i])
            end
        end
    end)
    if #out == 0 and GetMouseFoci then
        pcall(function()
            for _, f in ipairs(GetMouseFoci() or {}) do
                if type(f) == "table" and f ~= win and not (f.IsForbidden and f:IsForbidden()) then
                    if f.GetFontString then add(f:GetFontString()) end
                    if f.GetRegions then
                        for _, r in ipairs({ f:GetRegions() }) do
                            if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" then add(r) end
                        end
                    end
                end
            end
        end)
    end
    return out
end
U.FixHovered = hovered

-- ── вікно ──────────────────────────────────────────────────────────────────────────────────────────────
-- Наш напис завжди кириличний: U.Font, а в режимі «не змінювати шрифт» — Arial Narrow (у ньому є кирилиця).
local function cyr(fs)
    if U.Settings and U.Settings.font == "off" then
        local ok, _, size, flags = pcall(fs.GetFont, fs)
        if ok then pcall(fs.SetFont, fs, U.FONT_FILE.arial, size or 12, flags) end
    else
        U.Font(fs)
    end
end

local function text(parent, template, s)
    local fs = parent:CreateFontString(nil, "ARTWORK", template)
    fs:SetJustifyH("LEFT")
    if s then fs:SetText(s) end
    cyr(fs)
    return fs
end

local function fill(f, r, g, b, a, layer)
    local t = f:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

local function button(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 110, 22)
    fill(b, 0.25, 0.22, 0.12, 0.95)
    fill(b, 1, 1, 1, 0.15, "HIGHLIGHT")
    b.label = text(b, "GameFontNormal", label)
    b.label:SetPoint("CENTER")
    return b
end

local function editBox(parent, multi)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetMaxLetters(STR_MAX)
    if multi then e:SetMultiLine(true) end
    e:SetTextInsets(4, 4, 2, 2)
    cyr(e)
    e:SetScript("OnEscapePressed", function() U.CloseFix() end)
    return e
end

local st = { list = {}, view = {}, off = 0, sel = nil }

local function oneLine(s, n)
    s = (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("[\r\n]+", " ")
    return cut(s, n)
end

local function rowLabel(r)
    local mark = r.hover and "|cffffd100[під курсором]|r " or ""
    local ua = r.ua and oneLine(r.ua, 60) or "|cff888888немає перекладу|r"
    return mark .. oneLine(r.en, 60) .. "  |cff888888→|r  " .. ua
end

local function filtered()
    local q = trim(win and win.search:GetText() or ""):lower()
    if q == "" then return st.list end
    local out = {}
    for _, r in ipairs(st.list) do
        if r.en:lower():find(q, 1, true) or (r.ua and r.ua:lower():find(q, 1, true)) then out[#out + 1] = r end
    end
    return out
end

local function redraw()
    if not win then return end
    st.view = filtered()
    local maxOff = math.max(0, #st.view - ROWS)
    if st.off > maxOff then st.off = maxOff end
    for i, b in ipairs(win.rows) do
        local r = st.view[st.off + i]
        b.rec = r
        if r then
            b.text:SetText(rowLabel(r)); b:Show()
            if r == st.sel then b.sel:Show() else b.sel:Hide() end
        else
            b.text:SetText(""); b:Hide()
        end
    end
    win.count:SetText(("Останні тексти: %d%s"):format(#st.view, #st.view > ROWS and " · коліщатко — гортати" or ""))
end

local function choose(r)
    st.sel = r
    if r then
        win.en:SetText(oneLine(r.en, 400))
        win.ua:SetText(r.ua and oneLine(r.ua, 400) or "|cff888888(перекладу немає)|r")
        win.edit:SetText(r.ua or "")
        win.comment:SetText("")
        win.edit:SetFocus()
    else
        win.en:SetText(""); win.ua:SetText(""); win.edit:SetText(""); win.comment:SetText("")
    end
    redraw()
end

local function status(s) if win then win.status:SetText(s) end end

local function save()
    local e, why = U.FixSave(st.sel, win.edit:GetText(), win.comment:GetText())
    if not e then status("|cffff6060Не збережено: " .. why .. "|r"); return end
    status(("|cff60ff60Збережено|r (усього %d). Після /reload або виходу завантаж WTF/Account/<акаунт>/SavedVariables/"
        .. "Uwow.lua на uwow.wearebob.dev/capture"):format(#UwowMiss.fix))
    U.Say("виправлення збережено: «" .. oneLine(e.en, 40) .. "»")
end

local function build()
    local f = CreateFrame("Frame", nil, UIParent)
    win = f
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    fill(f, 0.05, 0.05, 0.07, 0.94)

    local title = text(f, "GameFontNormalLarge", "Uwow — запропонувати переклад")
    title:SetPoint("TOPLEFT", 14, -12)
    local close = button(f, "X", 24)
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() U.CloseFix() end)

    local sl = text(f, "GameFontHighlightSmall", "Пошук:")
    sl:SetPoint("TOPLEFT", 14, -42)
    local search = editBox(f)
    search:SetSize(W - 90, 20)
    search:SetPoint("LEFT", sl, "RIGHT", 8, 0)
    fill(search, 1, 1, 1, 0.08)
    search:SetScript("OnTextChanged", function() st.off = 0; redraw() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.search = search

    f.count = text(f, "GameFontDisableSmall")
    f.count:SetPoint("TOPLEFT", 14, -66)

    local list = CreateFrame("Frame", nil, f)
    list:SetSize(W - 28, ROWS * ROW_H)
    list:SetPoint("TOPLEFT", 14, -80)
    fill(list, 1, 1, 1, 0.04)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, d)
        st.off = math.max(0, math.min(st.off - d * 3, math.max(0, #st.view - ROWS)))
        redraw()
    end)
    f.rows = {}
    for i = 1, ROWS do
        local b = CreateFrame("Button", nil, list)
        b:SetSize(W - 28, ROW_H)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        b.sel = fill(b, 0.3, 0.6, 1, 0.25)
        b.sel:Hide()
        fill(b, 1, 1, 1, 0.10, "HIGHLIGHT")
        b.text = text(b, "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", 4, 0); b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self) if type(self.rec) == "table" then choose(self.rec) end end)
        f.rows[i] = b
    end

    local y = -88 - ROWS * ROW_H
    local l1 = text(f, "GameFontNormalSmall", "Оригінал:")
    l1:SetPoint("TOPLEFT", 14, y)
    f.en = text(f, "GameFontHighlightSmall")
    f.en:SetPoint("TOPLEFT", 90, y); f.en:SetWidth(W - 104); f.en:SetMaxLines(2)
    local l2 = text(f, "GameFontNormalSmall", "Зараз:")
    l2:SetPoint("TOPLEFT", 14, y - 30)
    f.ua = text(f, "GameFontHighlightSmall")
    f.ua:SetPoint("TOPLEFT", 90, y - 30); f.ua:SetWidth(W - 104); f.ua:SetMaxLines(2)

    local l3 = text(f, "GameFontNormalSmall", "Твій варіант:")
    l3:SetPoint("TOPLEFT", 14, y - 60)
    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:SetSize(W - 28, 64)
    sf:SetPoint("TOPLEFT", 14, y - 74)
    fill(sf, 1, 1, 1, 0.08)
    local edit = editBox(sf, true)
    edit:SetWidth(W - 36)
    sf:SetScrollChild(edit)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() edit:SetFocus() end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local v = (self:GetVerticalScroll() or 0) - d * 14
        self:SetVerticalScroll(math.max(0, math.min(v, self:GetVerticalScrollRange() or 0)))
    end)
    edit:SetScript("OnCursorChanged", function(_, _, cy, _, ch)           -- курсор завжди видно
        local top, h, cur = -(cy or 0), sf:GetHeight() or 64, sf:GetVerticalScroll() or 0
        if top < cur then sf:SetVerticalScroll(top)
        elseif top + (ch or 0) > cur + h then sf:SetVerticalScroll(top + (ch or 0) - h) end
    end)
    f.edit = edit

    local l4 = text(f, "GameFontNormalSmall", "Коментар:")
    l4:SetPoint("TOPLEFT", 14, y - 148)
    local comment = editBox(f)
    comment:SetSize(W - 104, 20)
    comment:SetPoint("TOPLEFT", 90, y - 144)
    fill(comment, 1, 1, 1, 0.08)
    comment:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.comment = comment

    local sv = button(f, "Зберегти", 120)
    sv:SetPoint("BOTTOMRIGHT", -14, 12)
    sv:SetScript("OnClick", save)
    f.saveButton = sv
    f.status = text(f, "GameFontHighlightSmall",
        "Вибери рядок, впиши свій варіант і збережи. Файл для сайту: WTF/Account/<акаунт>/SavedVariables/Uwow.lua")
    f.status:SetPoint("BOTTOMLEFT", 14, 14); f.status:SetWidth(W - 160); f.status:SetMaxLines(3)
    f:Hide()
    return f
end

function U.CloseFix()
    if win then win:Hide(); win.uwShown = false; win.edit:ClearFocus(); win.search:ClearFocus(); win.comment:ClearFocus() end
end

-- /uw fix [слово]: список останніх текстів (тексти під курсором — нагорі й одразу вибрані), пошук за словом.
function U.OpenFix(query)
    if inCombat() then U.Say("вікно виправлень не відкривається в бою — набери /uw fix після бою"); return false end
    local hov = hovered()
    if not win then build() end
    local list, seen = {}, {}
    for _, r in ipairs(hov) do list[#list + 1] = r; seen[r.en] = true end
    for _, r in ipairs(U.FixRecent()) do if not seen[r.en] then list[#list + 1] = r end end
    st.list, st.off, st.sel = list, 0, nil
    win.search:SetText(query or "")
    status(#list == 0 and "Список порожній: відкрий квест, діалог чи тултіп і набери /uw fix знову."
        or "Вибери рядок, впиши свій варіант і збережи. Файл для сайту: WTF/Account/<акаунт>/SavedVariables/Uwow.lua")
    win:Show(); win.uwShown = true
    choose(hov[1])
    return true
end

function U.FixShown() return win ~= nil and win.uwShown == true end
function U.FixWindow() return win end
U.FixState = st

U.Surface("ui-fix", function()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() if U.FixShown() then U.CloseFix() end end)
end)
