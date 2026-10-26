-- Uwow · Surfaces/WorldText.lua — книги, листи й таблички (ItemTextFrame) і пошта від NPC (скринька й відкритий лист).
-- Книга: ItemTextPageText — SimpleHTML; Blizzard ставить сторінку одним SetText і лише потім міряє прокрутку,
-- тож post-хук SetText цього екземпляра підміняє текст до вимірювання. Пошта: лише листи, на які не можна
-- відповісти (NPC і система); особисту пошту гравців не чіпаємо й не збираємо.
local U = UWOW
local K = U.WK

-- ── книги ──────────────────────────────────────────────────────────────────────────────────────────────────
local busy = false

local function pageUA(raw)
    local ua = K.T("dialog", raw)
    if ua then return ua end
    local body = raw:match("^%s*<[Hh][Tt][Mm][Ll]>.-<[Bb][Oo][Dd][Yy]>(.-)</[Bb][Oo][Dd][Yy]>")
    if body then                                                     -- HTML-сторінка: абзаци <P> по одному
        local hit = false
        local out = body:gsub("(<[Pp][^>]*>)(.-)(</[Pp]>)", function(a, t, b)
            local u = K.T("dialog", t)
            if u then hit = true; return a .. u .. b end
        end)
        if hit then return (raw:gsub("<[Bb][Oo][Dd][Yy]>.-</[Bb][Oo][Dd][Yy]>", function() return "<BODY>" .. out .. "</BODY>" end, 1)) end
    end
end

U.Surface("books", function()
    local page = _G.ItemTextPageText
    if not page then return end
    hooksecurefunc(page, "SetText", function(self, text)
        if busy or not U.Enabled() or type(text) ~= "string" or text == "" or K.secret(text) then return end
        local raw = ItemTextGetText and ItemTextGetText()
        if type(raw) ~= "string" or raw == "" or K.secret(raw) then return end
        local ua = pageUA(raw)
        if not ua then U.Miss("dialog", "book", raw, ItemTextGetPage and ItemTextGetPage()) return end
        local tail = text:sub(#raw + 1)                              -- «Від: <автор>», якщо Blizzard додав
        if text:sub(1, #raw) ~= raw then tail = "" end
        local from = _G.ITEM_TEXT_FROM
        local fromUA = from and U.T("ui", from)
        if fromUA and tail ~= "" then tail = K.Swap(tail, from, fromUA) or tail end
        busy = true
        if not (U.Settings and U.Settings.original) then pcall(self.SetText, self, ua .. tail) end
        busy = false
    end)
    -- назва книги в заголовку вікна (SetTitle при ITEM_TEXT_BEGIN)
    local f = _G.ItemTextFrame
    if f and f.SetTitle then
        K.HookOnce(f, "SetTitle", function(self, title)
            if not U.Enabled() or type(title) ~= "string" or K.secret(title) then return end
            local fs = (self.TitleContainer and self.TitleContainer.TitleText) or self.TitleText
            local en = K.text(fs)
            if not en then return end
            local ua = K.Tany({ "dialog", "ui" }, title)
            if not ua and C_Item and C_Item.GetItemInfoInstant then
                local id = C_Item.GetItemInfoInstant(title)
                ua = id and U.ID("item", id, "name")
            end
            if ua then U.Apply(fs, ua, en) end
        end)
    end
end)

-- ── пошта ──────────────────────────────────────────────────────────────────────────────────────────────────
local function mailText(text, field)
    if type(text) ~= "string" or text == "" or K.secret(text) then return nil end
    if field == "sender" then return U.TranslateName(text) or K.T("dialog", text) end
    local ua = K.T("dialog", text)
    if ua then return ua end
    -- аукціонні теми: «Auction won: <предмет>» тощо — шаблон GlobalStrings + назва предмета
    for _, g in ipairs({ "AUCTION_WON_MAIL_SUBJECT", "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_OUTBID_MAIL_SUBJECT",
                         "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT" }) do
        local fmt = _G[g]
        local p = fmt and K.Pattern(fmt)
        local arg = p and text:match(p)
        local tpl = arg and U.T("ui", fmt)
        if tpl then return K.Fill(tpl, { arg }) end
    end
end

local function inbox()
    if not U.Enabled() or not GetInboxHeaderInfo then return end
    local per = _G.INBOXITEMS_TO_DISPLAY or 7
    local base = ((_G.InboxFrame and _G.InboxFrame.pageNum or 1) - 1) * per
    for i = 1, per do
        local idx = base + i
        local b = _G["MailItem" .. i .. "Button"]
        if b and b:IsShown() and b.index == idx then
            local canReply = select(12, GetInboxHeaderInfo(idx))
            if not canReply then
                for _, pair in ipairs({ { _G["MailItem" .. i .. "Subject"], "subject" }, { _G["MailItem" .. i .. "Sender"], "sender" } }) do
                    local fs = pair[1]
                    local en = K.text(fs)
                    local ua = en and mailText(en, pair[2])
                    if ua then U.Apply(fs, ua, en) end
                end
            end
        end
    end
end

local function openMail()
    if not U.Enabled() or not (_G.InboxFrame and _G.InboxFrame.openMailID) then return end
    local id = _G.InboxFrame.openMailID
    local _, _, sender, _, _, _, _, _, _, _, _, canReply = GetInboxHeaderInfo(id)
    if canReply then return end
    local pairs_ = { { _G.OpenMailSender and _G.OpenMailSender.Name, "sender" }, { _G.OpenMailSubject, "subject" } }
    for _, p in ipairs(pairs_) do
        local fs = p[1]
        local en = K.text(fs)
        local ua = en and mailText(en, p[2])
        if ua then U.Apply(fs, ua, en) elseif en and p[2] == "subject" then U.Miss("dialog", "mail:subject", en) end
    end
    local body = GetInboxText and GetInboxText(id)
    local page = _G.OpenMailBodyText
    if page and type(body) == "string" and body ~= "" and not K.secret(body) then
        local ua = mailText(body, "body")
        if ua then
            if not (U.Settings and U.Settings.original) then pcall(page.SetText, page, ua, true) end
        else
            U.Miss("dialog", "mail:body", body, nil, sender)
        end
    end
end

U.Surface("mail", function()
    K.OnAddon("Blizzard_MailFrame", function()
        if InboxFrame_Update then hooksecurefunc("InboxFrame_Update", inbox) end
        if OpenMail_Update then hooksecurefunc("OpenMail_Update", openMail) end
    end)
end)
