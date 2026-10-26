-- Uwow · Surfaces/WorldChoice.lua — вікно вибору гравця (PlayerChoiceFrame: вибір історії, дарів, сил тощо):
-- питання, заголовки й підзаголовки варіантів, опис (рядок або SimpleHTML), підписи кнопок.
-- Аддон Blizzard_PlayerChoice вантажиться за потреби — хук ставимо після його завантаження.
-- Post-хук TryShow спрацьовує після ShowUIPanel, тож панельний менеджер UIParent наш код не зачіпає.
-- Опис ставимо через метод самого варіанта (OptionText:SetText), він сам перераховує висоту; далі — Layout
-- варіанта й вікна (поза боєм).
local U = UWOW
local K = U.WK

local function tr(text)
    if type(text) ~= "string" or text == "" or K.secret(text) then return nil end
    return K.Tany({ "dialog", "questui", "ui" }, text)
end

local function apply(fs, en)
    local cur = K.text(fs)
    if not cur then return end
    local ua = tr(en or cur)
    if ua then U.Apply(fs, ua, cur) elseif en then U.Miss("dialog", "playerchoice", en) end
end

local function buttons(container)
    if not container or not container.GetChildren then return end
    for _, wrap in ipairs({ container:GetChildren() }) do
        local b = wrap.Button or wrap
        local fs = b.Text or (b.GetFontString and b:GetFontString())
        if fs then apply(fs) end
    end
end

local function translate(self)
    if not U.Enabled() then return end
    local info = self.choiceInfo
    if self.Title and self.Title.Text then apply(self.Title.Text, info and info.questionText) end
    if not self.optionPools then return end
    local relayout = not K.inCombat()
    for opt in self.optionPools:EnumerateActive() do
        local oi = opt.optionInfo or {}
        if opt.Header and opt.Header.Contents and opt.Header.Contents.Text then apply(opt.Header.Contents.Text, oi.header) end
        if opt.SubHeader and opt.SubHeader.Text then apply(opt.SubHeader.Text, oi.subHeader) end
        local ot = opt.OptionText
        if ot and ot.SetText and oi.description and oi.description ~= "" then
            local ua = tr(oi.description)
            if ua then
                if not (U.Settings and U.Settings.original) then pcall(ot.SetText, ot, ua) end
            else
                U.Miss("dialog", "playerchoice", oi.description)
            end
        end
        buttons(opt.OptionButtonsContainer)
        if relayout and opt.Layout then pcall(opt.Layout, opt) end
    end
    if relayout and self.Layout then pcall(self.Layout, self) end
end

U.Surface("player-choice", function()
    K.OnAddon("Blizzard_PlayerChoice", function()
        local f = _G.PlayerChoiceFrame
        if f then K.HookOnce(f, "TryShow", translate) end
    end)
end)
