-- Uwow · Surfaces/CharItems.lua — предмети й економіка поза тултіпами: вікно здобичі, сповіщення про здобич,
-- торговець і викуп,
-- список валют (оверлей: свій напис поверх рідного, бо гра читає текст рядка при виборі валюти),
-- титули (список вибору і заголовок вікна персонажа), репутації (назви фракцій за factionID, опис, ранг).
local U = UWOW
local K

-- ── здобич ─────────────────────────────────────────────────────────────────────────────────────────────
local function lootSlotItemID(slot)
    if type(slot) ~= "number" or not GetLootSlotLink then return nil end
    local ok, link = pcall(GetLootSlotLink, slot)
    return ok and K.linkID(link) or nil
end

-- сповіщення «Здобуто»/«Покращення предмета»: черга тримає посилання на функцію, тож хук — на поле підсистеми
local function toastName(fs, link, isCurrency)
    local en = K.text(fs)
    if not en or K.cyr(en) or type(link) ~= "string" or K.secret(link) then return end
    if isCurrency or link:find("currency:", 1, true) then
        local cid = tonumber(link:match("currency:(%d+)"))
        if cid then K.byID(fs, "currency", cid, "name", "loot-toast") end
    else
        local id = K.linkID(link)
        if id then K.byID(fs, "item", id, "name", "loot-toast") end
    end
end

U.Surface("loot", function()
    K = U.CharKit
    K.hook(rawget(_G, "LootAlertSystem"), "setUpFunction", function(self, link, _, _, _, _, isCurrency)
        if self.Label then K.label(self.Label, "loot-toast", "ui", 40) end
        toastName(self.ItemName, link, isCurrency)
    end, "loot-toast")
    K.hook(rawget(_G, "LootUpgradeAlertSystem"), "setUpFunction", function(self, link)
        for _, k in ipairs({ "BaseQualityItemName", "UpgradeQualityItemName", "WhiteText", "WhiteText2" }) do
            if self[k] then toastName(self[k], link) end
        end
    end, "loot-upgrade-toast")
    -- LootFrameItemElementMixin:Init кличе LootFrameElementMixin.Init через глобальну таблицю — хук на базовий ловить обидва
    K.hook(LootFrameElementMixin, "Init", function(self)
        local slot = self.GetSlotIndex and self:GetSlotIndex()
        local id = lootSlotItemID(slot)
        if id then K.byID(self.Text, "item", id, "name", "loot") else K.label(self.Text, "loot", { "ui", "collections" }) end
    end, "loot")
    K.hook(LootFrameItemElementMixin, "Init", function(self)
        if self.QualityText then K.label(self.QualityText, "loot-quality") end
    end, "loot-quality")
end)

-- ── торговець ──────────────────────────────────────────────────────────────────────────────────────────
local function merchantItemID(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" and info.itemID and not K.secret(info.itemID) then return info.itemID end
    end
    if GetMerchantItemID then
        local ok, id = pcall(GetMerchantItemID, index)
        if ok and id and not K.secret(id) then return id end
    end
    if GetMerchantItemLink then
        local ok, link = pcall(GetMerchantItemLink, index)
        if ok then return K.linkID(link) end
    end
end

local function merchantPage(buyback)
    local per = rawget(_G, "MERCHANT_ITEMS_PER_PAGE") or 10
    local mf = _G.MerchantFrame
    local page = mf and mf.page or 1
    for i = 1, (buyback and (rawget(_G, "BUYBACK_ITEMS_PER_PAGE") or 12) or per) do
        local fs = _G["MerchantItem" .. i .. "Name"]
        if fs and K.text(fs) then
            local id
            if buyback then
                local ok, link = pcall(GetBuybackItemLink, i)
                id = ok and K.linkID(link)
            else
                id = merchantItemID((page - 1) * per + i)
            end
            if id then K.byID(fs, "item", id, "name", "merchant") end
        end
    end
end

U.Surface("merchant", function()
    K = U.CharKit
    K.hookG("MerchantFrame_UpdateMerchantInfo", function() merchantPage(false) end)
    K.hookG("MerchantFrame_UpdateBuybackInfo", function() merchantPage(true) end)
end)

-- ── валюти (TokenFrame) ────────────────────────────────────────────────────────────────────────────────
-- TokenEntryMixin:OnClick бере self.Content.Name:GetText() і порівнює з elementData.name — підміна тексту
-- зламала б вибір валюти й вікно її параметрів. Тому рідний напис лишаємо (alpha 0), а поверх — свій.
local overlays = setmetatable({}, { __mode = "k" })

local function overlayFor(entry, name)
    local o = overlays[entry]
    if o then return o end
    local parent = name.GetParent and name:GetParent() or entry
    if not parent.CreateFontString then return nil end
    o = parent:CreateFontString(nil, "OVERLAY")
    if not o then return nil end
    local font, size, flags = name:GetFont()
    if font then o:SetFont(font, size, flags) end
    o:SetAllPoints(name)
    if name.GetJustifyH then o:SetJustifyH(name:GetJustifyH()) end
    if name.GetJustifyV then o:SetJustifyV(name:GetJustifyV()) end
    if name.GetWordWrap then o:SetWordWrap(name:GetWordWrap()) end
    overlays[entry] = o
    return o
end

local function tokenEntry(self)
    local name = self.Content and self.Content.Name
    if not name then return end
    local o = overlays[self]
    local ed = self.elementData
    local en = K.text(name)
    local ua = U.Enabled() and en and not K.cyr(en) and type(ed) == "table" and ed.currencyID
        and not K.secret(ed.currencyID) and U.ID("currency", ed.currencyID, "name")
    if not ua then
        if en and U.Enabled() and type(ed) == "table" then U.Miss("currency", "currency-list", en, ed.currencyID) end
        if o then o:Hide(); name:SetAlpha(1) end
        return
    end
    o = o or overlayFor(self, name)
    if not o then return end
    o:SetText(en)                                   -- U.Apply поставить переклад і запам'ятає пару для /uw
    U.Apply(o, ua, en)
    o:SetTextColor(name:GetTextColor())
    o:Show()
    name:SetAlpha(0)
end

local function tokenColor(self)
    local o = overlays[self]
    local name = self.Content and self.Content.Name
    if o and name and o:IsShown() then o:SetTextColor(name:GetTextColor()) end
end

U.Surface("currency-list", function()
    K = U.CharKit
    K.onAddon("Blizzard_TokenUI", function()
        if type(TokenEntryMixin) ~= "table" then return end
        hooksecurefunc(TokenEntryMixin, "Initialize", function(self) pcall(tokenEntry, self) end)
        hooksecurefunc(TokenEntryMixin, "RefreshTextColor", function(self) pcall(tokenColor, self) end)
        K.hook(TokenHeaderMixin, "Initialize", function(self)
            local t = self.GetTitleRegion and self:GetTitleRegion()
            if t then K.label(t, "currency-header") end
        end, "currency-header")
        K.hook(TokenSubHeaderMixin, "Initialize", function(self)
            if self.Text then K.label(self.Text, "currency-header") end
        end, "currency-subheader")
    end)
end)

-- ── титули ─────────────────────────────────────────────────────────────────────────────────────────────
local function titleUA(t)
    t = t and t:gsub("^%s+", ""):gsub("%s+$", "")
    if not t or t == "" then return nil end
    return K.str(t, "ui") or K.str(", " .. t, "ui")
end

U.Surface("titles", function()
    K = U.CharKit
    K.hookG("PaperDollTitlesPane_InitButton", function(button)
        local fs = button and button.text
        local en = K.text(fs)
        if not en or K.cyr(en) or not en:find("%a") then return end
        local ua = titleUA(en)
        if ua then K.set(fs, ua, en) else U.Miss("ui", "titles", en) end
    end)
    -- заголовок вікна персонажа: «<Титул> Ім'я» або «Ім'я <титул>» (UnitPVPName)
    local cf = _G.CharacterFrame
    K.hook(cf, "SetTitle", function(self)
        local fs = self.GetTitleText and self:GetTitleText()
        local en = K.text(fs)
        local me = U.Player()
        if not en or not me or K.cyr(en) or #en <= #me then return end
        local ua
        if en:sub(-#me) == me then
            local t = titleUA(en:sub(1, #en - #me))
            if t then ua = t .. " " .. me end
        elseif en:sub(1, #me) == me then
            local rest = en:sub(#me + 1)
            local t = titleUA(rest)
            if t then ua = me .. (rest:find("^,") and "" or " ") .. t end
        end
        if ua then K.set(fs, ua, en) end
    end, "char-title")
end)

-- ── репутації ──────────────────────────────────────────────────────────────────────────────────────────
local function factionName(fs, id, surf)
    if id and not K.secret(id) and id > 0 and U.ID("faction", id, "n") then return K.byID(fs, "faction", id, "n") end
    return K.label(fs, surf, "ui", 60)
end

U.Surface("reputation", function()
    K = U.CharKit
    -- ReputationSubHeaderMixin:Initialize кличе ReputationEntryMixin.Initialize через глобальну таблицю
    K.hook(ReputationEntryMixin, "Initialize", function(self)
        factionName(self.Content and self.Content.Name, self.factionID, "reputation")
    end, "reputation-entry")
    K.hook(ReputationHeaderMixin, "Initialize", function(self)
        factionName(self.Name, self.factionID, "reputation-header")
    end, "reputation-header")
    K.hook(ReputationBarMixin, "UpdateReputationStandingText", function(self)
        if self.BarText then K.label(self.BarText, "reputation-standing", "ui", 40) end
    end, "reputation-standing")
    K.hook(ReputationBarMixin, "TryShowReputationStandingText", function(self)
        if self.BarText then K.label(self.BarText, nil, "ui") end
    end, "reputation-standing2")
    local df = _G.ReputationFrame and _G.ReputationFrame.ReputationDetailFrame
    K.hook(df, "Refresh", function(self)
        local idx = C_Reputation and C_Reputation.GetSelectedFaction and C_Reputation.GetSelectedFaction()
        local data = idx and C_Reputation.GetFactionDataByIndex(idx)
        local id = type(data) == "table" and data.factionID
        if not id or K.secret(id) then return end
        factionName(self.Title, id, "reputation-detail")
        local sd = self.ScrollingDescription
        local fs = sd and sd.GetFontString and sd:GetFontString()
        local en = K.text(fs)
        if en and not K.cyr(en) then
            local ua = U.ID("faction", id, "d")
            if ua then
                K.set(fs, ua, en)
                pcall(sd.SetText, sd, fs:GetText())          -- перерахувати висоту прокрутки
            else
                U.Miss("faction", "reputation-detail", en, id)
            end
        end
    end, "reputation-detail")
end)
