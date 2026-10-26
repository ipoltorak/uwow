-- Uwow · Surfaces/UiHelp.lua — підказки HelpTip (Blizzard_SharedXML/HelpTip.lua) і навчальні банери
-- (Blizzard_TutorialManager: TutorialMainFrame_Frame, TutorialPointerFrame).
-- HelpTip: пост-хук ApplyText кожного фрейму з пулу — його кличе Layout ДО розрахунку висоти, тож рамка сама
-- підлаштовується під український текст. Нові фрейми пулу підхоплюємо пост-хуком HelpTip:Show.
-- Банери навчання: пост-хук _SetContent / TutorialPointerFrame:Show; розмір напису після підміни перераховуємо
-- так само, як Blizzard, і лише поза боєм (у бою лишаємо англійський текст, щоб не чіпати геометрію).
local U = UWOW

-- ── HelpTip ─────────────────────────────────────────────────────────────────────────────────────────────
local hookedTip = setmetatable({}, { __mode = "k" })

local function tipText(frame)
    if not U.Enabled() then return end
    local info = frame.info
    local fs = frame.Text
    local en = U.GetText(fs)
    if not en then return end
    local parent = frame.GetParent and frame:GetParent()
    -- підказка буває загорнута в колір: шукаємо без обгортки, повертаємо обгортку навколо перекладу
    local pre, body, post = en:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if not pre then pre, body, post = en:match("^(|cn[%w_]+:)(.-)(|r)$") end
    local ua = U.T("ui", body or en)
    if ua then
        U.Apply(fs, body and (pre .. ua .. post) or ua, en)
        if type(info) == "table" and not info.textJustifyH and fs.GetNumLines then
            fs:SetJustifyH(fs:GetNumLines() == 1 and "CENTER" or "LEFT")
        end
    else
        U.Miss("ui", "helptip", body or en, type(info) == "table" and info.system or nil, nil, parent)
    end
    local ok = frame.OkayButton
    if ok and ok.IsShown and ok:IsShown() then
        local bfs = ok.GetFontString and ok:GetFontString()
        local bt = U.GetText(bfs)
        local ub = bt and U.T("ui", bt)
        if ub then U.Apply(bfs, ub, bt) end
    end
end

local mixinApply                                       -- HelpTipTemplateMixin.ApplyText після нашого хука
local function hookTip(frame)
    if hookedTip[frame] or not frame.ApplyText then return end
    hookedTip[frame] = true
    -- фрейми, створені після хука міксину, уже мають хукнутий ApplyText; старі хукаємо поштучно
    if frame.ApplyText ~= mixinApply then hooksecurefunc(frame, "ApplyText", tipText) end
    tipText(frame)                                     -- уже показаний текст цього разу
end

U.Surface("ui-helptip", function()
    if not (HelpTip and HelpTip.Show and HelpTip.framePool) then return end
    if HelpTipTemplateMixin and HelpTipTemplateMixin.ApplyText then
        hooksecurefunc(HelpTipTemplateMixin, "ApplyText", tipText)
        mixinApply = HelpTipTemplateMixin.ApplyText
    end
    local function hookActive()
        for frame in HelpTip.framePool:EnumerateActive() do hookTip(frame) end
    end
    hookActive()
    hooksecurefunc(HelpTip, "Show", hookActive)
end)

-- ── навчальні банери ────────────────────────────────────────────────────────────────────────────────────
local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function mainBanner(frame)
    if not U.Enabled() or inCombat() then return end
    local text = frame.ContainerFrame and frame.ContainerFrame.Text
    local en = U.GetText(text)
    if not en then return end
    local ua = U.T("ui", en)
    if not ua then U.Miss("ui", "tutorial", en, nil, nil, frame); return end
    U.Apply(text, ua, en)
    text:SetSize(0, 0)
    text:SetWidth(text:GetStringWidth())
    text:SetHeight(text:GetStringHeight())
    if frame.ContainerFrame.MarkDirty then frame.ContainerFrame:MarkDirty() end
end

local function pointer(tpf)
    if not U.Enabled() or inCombat() or type(tpf.InUseFrames) ~= "table" or not tpf.NextID then return end
    local frame = tpf.InUseFrames[tpf.NextID - 1]
    local content = frame and frame.Content
    local text = content and content.Text
    local en = U.GetText(text)
    if not en then return end
    local ua = U.T("ui", en)
    if not ua then U.Miss("ui", "tutorial-pointer", en, nil, nil, frame); return end
    U.Apply(text, ua, en)
    local maxWidth = text:GetWidth()
    local w = math.min(text:GetStringWidth(), maxWidth) + 40
    content:SetHeight(text:GetHeight() + 40)
    content:SetWidth(w)
end

U.Surface("ui-tutorial", function()
    U.OnAddon("Blizzard_TutorialManager", function()
        for _, name in ipairs({ "TutorialMainFrame_Frame", "TutorialSingleKey_Frame", "TutorialDoubleKey_Frame" }) do
            local f = _G[name]
            if f and f._SetContent then hooksecurefunc(f, "_SetContent", mainBanner) end
        end
        if TutorialPointerFrame and TutorialPointerFrame.Show then hooksecurefunc(TutorialPointerFrame, "Show", pointer) end
    end, function() return TutorialMainFrame_Frame ~= nil end)
end)
