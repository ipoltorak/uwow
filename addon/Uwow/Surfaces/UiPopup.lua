-- Uwow · Surfaces/UiPopup.lua — системні спливні вікна StaticPopup1..N (Blizzard_StaticPopup_Game, GameDialogMixin):
-- основний текст, підтекст і кнопки. Переклад ставимо в пост-хуку dialog:Init (до Show і Resize, тож вікно саме
-- підлаштовує розмір під український текст) і в HookScript("OnShow") — частина діалогів міняє текст у своєму OnShow.
-- Лише SetText на написах; полів діалогу не пишемо, Resize сами не кличемо.
-- Текст: точний збіг у домені ui → розбір за шаблоном StaticPopupDialogs[which].text («Delete %s?»).
-- Діалоги сторонніх аддонів (запис StaticPopupDialogs[which] зроблено незахищеним кодом) перекладаємо, але не збираємо.
local U = UWOW

local function foreignWhich(which)
    if not (issecurevariable and StaticPopupDialogs and type(which) == "string") then return false end
    local ok, sec = pcall(issecurevariable, StaticPopupDialogs, which)
    return ok and sec == false
end

local function templateOf(dialog, info)
    local data = dialog.data
    if type(data) == "table" and type(data.text) == "string" and not U.IsSecret(data.text) then return data.text end
    return type(info.text) == "string" and info.text or nil
end

local function translate(dialog)
    if not U.Enabled() then return end
    local which = dialog.which
    local info = type(which) == "string" and StaticPopupDialogs and StaticPopupDialogs[which]
    if type(info) ~= "table" then return end
    local foreign = foreignWhich(which)
    local fs = dialog.GetTextFontString and dialog:GetTextFontString() or dialog.Text
    local en = U.GetText(fs)
    if en then
        local fmt = templateOf(dialog, info)
        local ua = U.TF("ui", en, fmt)
        if ua then U.Apply(fs, ua, en)
        elseif not foreign then
            -- збираємо шаблон, а не екземпляр: у тексті екземпляра бувають ніки інших гравців
            local key = (fmt and U.Unformat(fmt, en)) and fmt or en
            U.Miss("ui", "popup", key, which, nil, dialog)
        end
    end
    local sub = dialog.SubText
    local st = sub and sub.IsShown and sub:IsShown() and U.GetText(sub)
    if st then
        local ua = U.TF("ui", st, type(info.subText) == "string" and info.subText or nil)
        if ua then U.Apply(sub, ua, st) elseif not foreign then U.Miss("ui", "popup-sub", st, which, nil, dialog) end
    end
    local buttons = dialog.GetButtons and dialog:GetButtons()
    if type(buttons) == "table" then
        for _, b in ipairs(buttons) do
            if b:IsShown() then
                local bfs = b.GetFontString and b:GetFontString()
                local bt = U.GetText(bfs)
                if bt and not bt:find("^%d+$") then                      -- лічильник acceptDelay лишаємо
                    local ua = U.T("ui", bt)
                    if ua then U.Apply(bfs, ua, bt) elseif not foreign then U.Miss("ui", "popup-button", bt, which, nil, dialog) end
                end
            end
        end
    end
end
U.TranslatePopup = translate

U.Surface("ui-popup", function()
    for i = 1, 10 do
        local d = _G["StaticPopup" .. i]
        if not d then break end
        if d.Init then hooksecurefunc(d, "Init", translate) end
        if d.HookScript then d:HookScript("OnShow", translate) end
    end
end)
