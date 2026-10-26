-- Uwow · Surfaces/WorldCinematic.lua — субтитри роликів і внутрішньоігрових кінематиків (SubtitlesFrame),
-- діалоги «пропустити ролик?» (MovieFrame, CinematicFrame), емоції й шепіт босів по центру екрана
-- (RaidWarningFrame і BossEmoteFrame кінематика).
local U = UWOW
local K = U.WK

-- «Ім'я: репліка» → переклад репліки (мовець — ім'я) і самого імені.
local function subtitleUA(body)
    local fmt = _G.SUBTITLE_FORMAT or "%s: %s"
    local p = K.Pattern(fmt)
    local sender, msg = body:match(p)
    if sender and msg then
        local ua = K.T("dialog", msg, sender)
        if not ua then U.Miss("dialog", "subtitle", msg, nil, sender) return nil end
        return fmt:format(U.TranslateName(sender) or sender, ua)
    end
    local ua = K.T("dialog", body)
    if not ua then U.Miss("dialog", "subtitle", body) end
    return ua
end

U.Surface("subtitles", function()
    local sf = _G.SubtitlesFrame
    if not sf then return end
    K.HookOnce(sf, "AddSubtitle", function(self, body)
        if not U.Enabled() or type(body) ~= "string" or K.secret(body) then return end
        for i = #(self.Subtitles or {}), 1, -1 do
            local fs = self.Subtitles[i]
            if K.text(fs) == body then
                local ua = subtitleUA(body)
                if ua then U.Apply(fs, ua, body) end
                return
            end
        end
    end)
end)

-- ── діалоги закриття ролика ────────────────────────────────────────────────────────────────────────────────
local function label(b)
    local fs = b and (b.GetFontString and b:GetFontString() or b.Text)
    if fs then K.Label(fs) end
end

U.Surface("cinematic-dialogs", function()
    local mf = _G.MovieFrame
    if mf and mf.CloseDialog then
        K.HookOnce(mf, "ShowCloseDialog", function(self)
            if not U.Enabled() then return end
            local d = self.CloseDialog
            K.Label(d.Title)
            local en = K.text(d.Summary)
            local ua = en and K.Tany({ "dialog", "ui" }, en)
            if ua then U.Apply(d.Summary, ua, en) end
            if d.Buttons then label(d.Buttons.ConfirmButton); label(d.Buttons.ResumeButton) end
            if not K.inCombat() and d.Layout then pcall(d.Layout, d) end
        end)
    end
    if U.Settings.enabled then
        K.Label(_G.CinematicFrameCloseDialogText)
        label(_G.CinematicFrameCloseDialogConfirmButton)
        label(_G.CinematicFrameCloseDialogResumeButton)
    end
end)

-- ── емоції й шепіт босів по центру екрана ────────────────────────────────────────────────────────────────────
local BOSS = { RAID_BOSS_EMOTE = true, RAID_BOSS_WHISPER = true }

local function bossEmote(self, event, message, sender)
    if not BOSS[event] or not U.Enabled() or type(message) ~= "string" or K.secret(message) or K.secret(sender) then return end
    local ok, body = pcall(format, message, sender or "", sender or "")
    if not ok or not self.fontStringPool then return end
    for fs in self.fontStringPool:EnumerateActive() do
        if K.text(fs) == body then
            local ua = K.T("dialog", message, sender)
            if ua then U.Apply(fs, ua, body) else U.Miss("dialog", "boss-emote", message, nil, sender) end
            return
        end
    end
end

U.Surface("boss-emotes", function()
    for _, f in ipairs({ _G.RaidWarningFrame, _G.CinematicFrame and _G.CinematicFrame.BossEmoteFrame }) do
        if f and f.OnEvent then K.HookOnce(f, "OnEvent", bossEmote) end
    end
end)
