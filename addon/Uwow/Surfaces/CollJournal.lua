-- Uwow · Surfaces/CollJournal.lua — путівник (Encounter Journal): список підземель/рейдів, сторінка інстансу
-- (назва, лор), список босів, сторінка боса (назва, лор, огляд з булетами, дерево секцій здібностей), здобич,
-- вкладки й підписи; вкладка «Подорожі» (Journeys) і «Журнал мандрівника» (Traveler's Log / MonthlyActivities).
-- Дані: «journal» (текстовий: назви інстансів/босів, лор, секції), «item» (здобич за itemID), «faction»
-- (назви подорожей за factionID), «ui» (підписи, активності журналу мандрівника).
-- Описи переважно ставимо «супроводом» SetText: Blizzard міряє висоту блоку відразу після SetText, тож переклад
-- має стояти до виміру, інакше секції наїжджають одна на одну.
local U = UWOW
local K = U.CollKit

-- Секції з «#» на місцях чисел (форма v1) compile.py зберігає як {#N}: живі числа підставляє U.T.
local function J(text)
    text = K.Str(text)
    if not text or K.Cyr(text) then return nil end
    local ua = U.T("journal", text) or K.Any(text, "names", "ui")
    if not ua then U.Miss("journal", "ej", text) end
    return ua
end

local function UI(text) return K.Any(text, "ui", "journal") end

-- ── сторінка боса: огляд і булети (EncounterJournal_SetBullets) ───────────────────────────────────────────
local function fixBullets(object)
    local parent = object and object.GetParent and object:GetParent()
    if object and object.Text then K.FollowNow(object.Text, J) end
    for _, b in ipairs(parent and parent.Bullets or {}) do
        if b.Text then
            K.FollowNow(b.Text, J)
            if not (InCombatLockdown and InCombatLockdown()) and b.Text.GetContentHeight then
                local h = b.Text:GetContentHeight()
                if h and h > 0 then b:SetHeight(h) end
            end
        end
    end
    if object and object.Text and object.Text.GetContentHeight and not (InCombatLockdown and InCombatLockdown()) then
        local h = object.Text:GetContentHeight()
        if h and h > 0 then object:SetHeight(h) end
    end
end

local function header(h)
    if not h then return end
    if h.button and h.button.title then K.FollowNow(h.button.title, J) end
    if h.description then K.FollowNow(h.description, J) end
    if h.overviewDescription and h.overviewDescription.Text then K.FollowNow(h.overviewDescription.Text, J) end
end

local function installEJ()
    local EJ = EncounterJournal
    if not EJ then return end
    local enc = EJ.encounter
    -- список підземель/рейдів
    K.OnScroll(EJ.instanceSelect and EJ.instanceSelect.ScrollBox, function(button)
        if button.name then K.FollowNow(button.name, J) end
    end)
    if enc then
        local inst, info = enc.instance, enc.info
        -- сторінка інстансу
        if inst then
            K.FollowNow(inst.title, J)
            local lore = inst.LoreScrollingFont
            if lore and lore.GetFontString then K.FollowNow(lore:GetFontString(), J) end
        end
        if info then
            K.FollowNow(info.instanceTitle, J)
            K.FollowNow(info.encounterTitle, J)
            -- список босів (Button:SetText не проходить через FontString:SetText — тож перекладаємо в колбеку)
            K.OnScroll(info.BossesScrollBox, function(button)
                local fs = button.GetFontString and button:GetFontString()
                if fs then K.FollowNow(fs, J) end
            end)
            -- здобич: назва предмета (itemID), слот/тип броні — підписи інтерфейсу
            K.OnScroll(info.LootContainer and info.LootContainer.ScrollBox, function(row)
                if row.itemID and row.name then
                    local en = K.Text(row.name)
                    if en then K.Put(row.name, en, U.ID("item", row.itemID, "name"), "item", "ej-loot", row.itemID) end
                end
                if row.slot then K.FollowNow(row.slot, UI) end
                if row.armorType then K.FollowNow(row.armorType, UI) end
                if row.boss then K.FollowNow(row.boss, function(t)
                    local b = t:match("^Boss: (.+)$")
                    local ua = b and J(b)
                    local label = UI("Boss:")
                    return ua and ((label or "Boss:") .. " " .. ua) or nil
                end) end
                if row.name and not row.itemID then K.FollowNow(row.name, UI) end    -- роздільник-заголовок
            end)
        end
        -- сторінка боса: лор і опис
        local ov, inf = enc.overviewFrame, enc.infoFrame
        if ov then
            K.FollowNow(ov.loreDescription, J)
            if ov.overviewDescription then K.FollowNow(ov.overviewDescription.Text, J) end
        end
        if inf then K.FollowNow(inf.description, J) end
    end
    if EncounterJournal_SetBullets then
        hooksecurefunc("EncounterJournal_SetBullets", function(object)
            if U.Enabled() then fixBullets(object) end
        end)
    end
    -- дерево секцій: заголовки створюються й перевикористовуються — супровід на кожному
    if EncounterJournal_ToggleHeaders then
        hooksecurefunc("EncounterJournal_ToggleHeaders", function()
            if not U.Enabled() or not enc then return end
            for _, h in ipairs(enc.usedHeaders or {}) do header(h) end
        end)
    end
    if EncounterJournal_SetUpOverview then
        hooksecurefunc("EncounterJournal_SetUpOverview", function(self, _, index)
            if U.Enabled() and self and self.overviews then header(self.overviews[index]) end
        end)
    end
    -- навігація «хлібні крихти»: назви інстансу/боса
    if NavBar_AddButton then
        hooksecurefunc("NavBar_AddButton", function(nav)
            if not U.Enabled() or nav ~= EJ.navBar then return end
            local list = nav.navList
            local b = list and list[#list]
            local fs = b and (b.text or (b.GetFontString and b:GetFontString()))
            local en = K.Text(fs)
            local ua = en and J(en)
            if not ua then return end
            -- ширину кнопки Blizzard уже порахував за англійським — додаємо різницю довжин
            local w0 = fs.GetStringWidth and fs:GetStringWidth()
            U.Apply(fs, ua, en)
            if w0 and b.SetWidth and not (InCombatLockdown and InCombatLockdown()) then
                b:SetWidth(b:GetWidth() + fs:GetStringWidth() - w0)
            end
        end)
    end
    -- заголовок вкладки «Підземелля/Рейди» і вкладки знизу
    if EJInstanceSelect_UpdateTitle then
        hooksecurefunc("EJInstanceSelect_UpdateTitle", function()
            if U.Enabled() then K.Walk(EJ.instanceSelect, "ui", "journal") end
        end)
    end
    local tabs = {}
    for _, k in ipairs({ "MonthlyActivitiesTab", "suggestTab", "dungeonsTab", "raidsTab", "LootJournalTab", "JourneysTab", "TutorialsTab" }) do
        if EJ[k] then tabs[#tabs + 1] = EJ[k] end
    end
    if EJ.HookScript then EJ:HookScript("OnShow", function() K.Tabs(tabs) end) end
    if EJ:IsShown() then K.Tabs(tabs) end
    -- пропонований вміст (Suggested Content)
    if EJSuggestFrame_RefreshDisplay then
        hooksecurefunc("EJSuggestFrame_RefreshDisplay", function()
            if U.Enabled() and EJ.suggestFrame then K.Walk(EJ.suggestFrame, "ui", "journal", "collections") end
        end)
    end
    -- подорожі
    local jf = EJ.JourneysFrame
    if jf then
        K.OnScroll(jf.JourneysList, function(frame, data)
            if frame.CategoryName then K.FollowNow(frame.CategoryName, UI) end
            local fs = frame.RenownCardFactionName or frame.JourneyCardName
            local id = type(data) == "table" and data.factionID
            if fs and id then K.FollowNow(fs, function(t) return U.ID("faction", id, "n") or UI(t) end) end
        end)
        local prog = jf.JourneyProgress
        if prog and prog.Refresh then
            hooksecurefunc(prog, "Refresh", function(self)
                if not U.Enabled() then return end
                local id = self.majorFactionData and self.majorFactionData.factionID
                if id and self.JourneyName then K.FollowNow(self.JourneyName, function(t) return U.ID("faction", id, "n") or UI(t) end) end
                K.Walk(self, "ui", "collections")
            end)
        end
        local ovw = jf.JourneyOverview
        if ovw and ovw.HookScript then
            ovw:HookScript("OnShow", function(self)
                if not U.Enabled() then return end
                local id = self.majorFactionData and self.majorFactionData.factionID
                if id and self.JourneyName then K.FollowNow(self.JourneyName, function(t) return U.ID("faction", id, "n") or UI(t) end) end
                if self.JourneyDescription then K.FollowNow(self.JourneyDescription, function(t) return (id and U.ID("faction", id, "d")) or UI(t) end) end
                K.Walk(self, "ui", "collections")
            end)
        end
    end
    -- журнал мандрівника: активності (назва — текст «ui»), фільтри
    local ma = EJ.MonthlyActivitiesFrame
    if ma then
        K.OnScroll(ma.ScrollBox, function(frame)
            local tc = frame.TextContainer
            if tc then
                if tc.NameText then K.FollowNow(tc.NameText, UI) end
                if tc.ConditionsText then K.FollowNow(tc.ConditionsText, UI) end
            end
        end)
        local fl = ma.FilterList
        if fl then K.OnScroll(fl.ScrollBox, function(frame) if frame.Label then K.FollowNow(frame.Label, UI) end end) end
        if ma.HookScript then ma:HookScript("OnShow", function(self) K.Walk(self.HeaderContainer, "ui") end) end
    end
end

U.Surface("encounter-journal", function()
    K.OnAddon("Blizzard_EncounterJournal", installEJ)
end)
