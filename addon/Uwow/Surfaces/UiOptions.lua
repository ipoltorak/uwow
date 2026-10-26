-- Uwow · Surfaces/UiOptions.lua — сторінка «Uwow» у вікні налаштувань гри (Settings API 12.x, канва:
-- Settings.RegisterCanvasLayoutCategory) і пункт у відсіку аддонів біля мінімапи (AddonCompartmentFrame:RegisterAddon —
-- таблиця з функцією, тож глобальна функція для поля .toc AddonCompartmentFunc не потрібна й нових глобалів немає).
-- Канва, а не вертикальна розкладка: написи вертикальної розкладки — спільні фрейми з пулу панелі зі шрифтом без
-- кирилиці; на канві всі написи наші й отримують кириличний шрифт через U.Font. Шаблони з $parent не вживаємо
-- (анонімний батько дав би глобальні імена) — прапорці збираємо з CheckButton і стандартних текстур.
-- Значення живуть в UwowDB; кожна зміна — через U.SetOption (миттєвий ефект).
local U = UWOW

local ICON = "Interface\\Icons\\INV_Misc_Book_09"

local OPTIONS = {
    { "enabled", "Увімкнути переклад", "Знята галочка — увесь текст мовою оригіналу. Діє одразу, без /reload." },
    { "original", "Показувати оригінал", "Тимчасово показати англійський текст замість перекладу (те саме, що /uw)." },
    { "capture", "Збирати неперекладене",
      "Запам'ятовувати рядки без перекладу для наступного оновлення. Ніки, гільдії, реалми й тексти інших аддонів не збираються." },
    { "npcNames", "Імена NPC на неймплейтах", "Показувати імена NPC над головами українською (те саме, що /uw npc)." },
}
local FONT_LABEL = {
    auto = "Як у грі (кирилична версія того самого шрифту)", friz = "Friz Quadrata (кирилиця)",
    arial = "Arial Narrow", off = "Не змінювати шрифт",
}

function U.OpenOptions()
    if InCombatLockdown and InCombatLockdown() then U.Say("налаштування відкриються після бою"); return end
    local cat = U.optionsCategory
    if cat and Settings and Settings.OpenToCategory then Settings.OpenToCategory(cat:GetID()) end
end

local function label(parent, template, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", template)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    U.Font(fs)
    return fs
end

local function checkbox(parent, text, tip)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(26, 26)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb.label = label(cb, "GameFontHighlight", text)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    if tip then
        cb.tip = label(cb, "GameFontDisableSmall", tip)
        cb.tip:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -3)
        cb.tip:SetWidth(520)
    end
    return cb
end

-- Будує сторінку; повертає фрейм канви з OnRefresh/OnDefault (їх кличе панель налаштувань).
function U.BuildOptionsPanel()
    local f = CreateFrame("Frame")
    local title = label(f, "GameFontNormalLarge", "Uwow — українська для World of Warcraft")
    title:SetPoint("TOPLEFT", 16, -16)
    local ver = label(f, "GameFontDisableSmall", ("версія %s · /uw help — список команд"):format(tostring(U.version)))
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    local y, boxes = -64, {}
    for _, o in ipairs(OPTIONS) do
        local key = o[1]
        local cb = checkbox(f, o[2], o[3])
        cb:SetPoint("TOPLEFT", 16, y)
        cb:SetScript("OnClick", function(self) U.SetOption(key, self:GetChecked() and true or false) end)
        boxes[key] = cb
        y = y - 52
    end
    local fl = label(f, "GameFontNormal", "Шрифт перекладених написів")
    fl:SetPoint("TOPLEFT", 16, y - 6)
    y = y - 30
    local radios = {}
    for _, m in ipairs(U.FONT_MODES) do
        local rb = checkbox(f, FONT_LABEL[m] or m)
        rb:SetPoint("TOPLEFT", 24, y)
        rb:SetScript("OnClick", function()
            U.SetOption("font", m)
            for mm, r in pairs(radios) do r:SetChecked(mm == m) end
        end)
        radios[m] = rb
        y = y - 28
    end
    local help = label(f, "GameFontHighlightSmall", "Команди: /uw — оригінал або переклад · /uw on | off · /uw options · "
        .. "/uw font auto | friz | arial | off · /uw capture · /uw npc · /uw stats · /uw selftest · /uw fix")
    help:SetPoint("TOPLEFT", 16, y - 12)
    help:SetWidth(560)
    local fix = label(f, "GameFontHighlightSmall", "Поганий або відсутній переклад? /uw fix — вибери текст зі списку останніх "
        .. "(або наведи курсор на тултіп), впиши свій варіант і збережи. Після /reload чи виходу з гри завантаж файл "
        .. "WTF/Account/<акаунт>/SavedVariables/Uwow.lua на uwow.wearebob.dev/capture.")
    fix:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
    fix:SetWidth(560)
    f.fixHelp = fix

    function f.OnRefresh()
        local db = U.Settings or {}
        for key, cb in pairs(boxes) do cb:SetChecked(db[key] and true or false) end
        for m, r in pairs(radios) do r:SetChecked((db.font or "auto") == m) end
    end
    function f.OnDefault()
        for _, o in ipairs(OPTIONS) do U.SetOption(o[1], U.DEFAULTS[o[1]]) end
        U.SetOption("font", U.DEFAULTS.font)
        f.OnRefresh()
    end
    f:SetScript("OnShow", f.OnRefresh)
    f.boxes, f.radios = boxes, radios
    return f
end

local function registerSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return false end
    local panel = U.BuildOptionsPanel()
    local cat = Settings.RegisterCanvasLayoutCategory(panel, "Uwow")
    Settings.RegisterAddOnCategory(cat)
    U.optionsCategory, U.optionsPanel = cat, panel
    return true
end

local function registerCompartment()
    local f = AddonCompartmentFrame
    if not (f and f.RegisterAddon) then return false end
    f:RegisterAddon({
        text = "Uwow", icon = ICON, notCheckable = true,
        func = function(_, input)
            if input and input.buttonName == "RightButton" then
                U.ShowOriginal(not U.Settings.original)
                U.Say(U.Settings.original and "показую оригінал" or "показую переклад")
            else
                U.OpenOptions()
            end
        end,
        funcOnEnter = function(button)
            if not GameTooltip then return end
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:SetText("Uwow " .. tostring(U.version))
            GameTooltip:AddLine("Клік — налаштування", 1, 1, 1)
            GameTooltip:AddLine("Правий клік — оригінал / переклад", 1, 1, 1)
            for i = 1, 3 do U.Font(_G["GameTooltipTextLeft" .. i]) end           -- рядки тултіпа: кириличний шрифт
            GameTooltip:Show()
        end,
        funcOnLeave = function() if GameTooltip then GameTooltip:Hide() end end,
    })
    return true
end

U.Surface("ui-options", function()
    registerSettings()
    registerCompartment()
end)
