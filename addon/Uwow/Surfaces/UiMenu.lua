-- Uwow · Surfaces/UiMenu.lua — меню гри (Esc, GameMenuFrame з Blizzard_GameMenu) і заголовки вікон-панелей
-- (TitledPanelMixin:SetTitle — PortraitFrame/DefaultPanel). Титули гравця і заголовок CharacterFrame — CharItems.lua.
-- Текст кнопок — GlobalStrings (GAMEMENU_OPTIONS, ADDONS…), ключ — хеш EN у домені ui.
-- Меню: пост-хук GameMenuFrame:InitButtons — кнопки з buttonPool і заголовок, лише SetText на їхніх написах
-- (жодних розмірів і методів Blizzard: у меню є «Вийти з гри», тож рамку меню не чіпаємо взагалі).
local U = UWOW

local function menuButtons(frame)
    if not U.Enabled() or not frame.buttonPool then return end
    for button in frame.buttonPool:EnumerateActive() do
        local fs = button.GetFontString and button:GetFontString()
        U.TrFS(fs, "ui", "game-menu", frame)
    end
    local header = frame.Header
    if header and header.Text then U.TrFS(header.Text, "ui", "game-menu", frame) end
end

U.Surface("ui-game-menu", function()
    U.OnAddon("Blizzard_GameMenu", function()
        local f = GameMenuFrame
        if not (f and f.InitButtons) then error("GameMenuFrame без InitButtons") end
        hooksecurefunc(f, "InitButtons", menuButtons)
    end, function() return GameMenuFrame ~= nil end)
end)

-- ── заголовки вікон ─────────────────────────────────────────────────────────────────────────────────────
-- Міксини копіюються у фрейм під час створення, тож хук міксинів ловить вікна модулів, що вантажаться пізніше
-- (Blizzard_* LoadOnDemand); вікна, створені до нас, хукаємо поштучно. Заголовок буває іменем NPC або гравця
-- (торговець, гравець у вікні персонажа), тому перекладаємо лише знайдене й не збираємо пропуски.
local PANELS = { "FriendsFrame", "MailFrame", "BankFrame", "PVEFrame", "AddonList", "DressUpFrame", "MerchantFrame" }

local function panelTitle(frame)
    if not U.Enabled() or type(frame) ~= "table" or not frame.GetTitleText then return end
    local ok, fs = pcall(frame.GetTitleText, frame)
    local en = ok and U.GetText(fs)
    if not en then return end
    local ua = U.T("ui", en)
    if ua then U.Apply(fs, ua, en) end
end

U.Surface("ui-panel-titles", function()
    if not TitledPanelMixin then return end
    for _, m in ipairs({ TitledPanelMixin, PortraitFrameMixin, DefaultPanelMixin }) do
        if m.SetTitle then hooksecurefunc(m, "SetTitle", panelTitle) end
        if m.SetTitleFormatted then hooksecurefunc(m, "SetTitleFormatted", panelTitle) end
    end
    for _, name in ipairs(PANELS) do
        local f = _G[name]
        if type(f) == "table" and f.SetTitle then
            hooksecurefunc(f, "SetTitle", panelTitle)
            panelTitle(f)
        end
    end
end)

-- титули (список і заголовок вікна персонажа) — Surfaces/CharItems.lua (агент char), тут не дублюємо
