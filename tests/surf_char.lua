-- tests/surf_char.lua — поверхні агента char: заглушки фреймів/міксинів Blizzard (12.x) і перевірка на реальних
-- даних збірки, що хуки стоять і текст підміняється українським.
--   M.stubs(H)          — до завантаження аддона (після H.install): API, міксини, глобальні функції.
--                         hooksecurefunc, Enum, EventRegistry, GameTooltip/ItemRefTooltip, TooltipDataProcessor — з harness.
--   M.run(H, U, check)  — після завантаження: ADDON_LOADED аддонів Blizzard, сценарії поверхонь.
local M = {}
local TD

-- ── заглушки ───────────────────────────────────────────────────────────────────────────────────────────
local function FS(text, parent)
    local o = { t = text, a = 1, font = { "Fonts\\FRIZQT__.TTF", 12, "" }, c = { 1, 0.82, 0 }, shown = true, parent = parent }
    function o:GetText() return self.t end
    function o:SetText(t) self.t = t end
    function o:SetFormattedText(f, ...) self.t = f:format(...) end
    function o:GetFont() return self.font[1], self.font[2], self.font[3] end
    function o:SetFont(f, s, fl) self.font = { f, s, fl }; return true end
    function o:SetTextColor(r, g, b) self.c = { r, g, b } end
    function o:GetTextColor() return self.c[1], self.c[2], self.c[3] end
    function o:SetAlpha(a) self.a = a end
    function o:GetAlpha() return self.a end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:GetParent() return self.parent end
    function o:GetJustifyH() return "LEFT" end
    function o:GetJustifyV() return "MIDDLE" end
    function o:GetWordWrap() return false end
    o.SetAllPoints, o.SetJustifyH, o.SetJustifyV, o.SetWordWrap, o.SetPoint = function() end, function() end,
        function() end, function() end, function() end
    return o
end
M.FS = FS

local function Frame(t)
    t = t or {}
    function t:CreateFontString() local f = FS(nil, self); return f end
    t.GetParent = t.GetParent or function() return nil end
    t.IsForbidden = t.IsForbidden or function() return false end
    return t
end

-- «створити фрейм із міксина» — як шаблон із mixin="…": копія методів на момент створення
local function fromMixin(mx, extra)
    local f = Frame(extra)
    for k, v in pairs(mx) do if f[k] == nil then f[k] = v end end
    return f
end

local tip

M.state = { itemSpell = {}, lootLink = {}, merchant = {}, recipeOut = {}, itemNameByID = {}, currencyDesc = {}, mountDesc = {} }

function M.stubs(H)
    local S = M.state
    ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONPROC = "Use:", "Equip:", "Chance on hit:"
    CHALLENGE_MODE_KEYSTONE_NAME = "Keystone: %s"
    ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
    PLAYER_LEVEL, PLAYER_LEVEL_NO_SPEC = "Level %s |c%s%s %s|r", "Level %s |c%s%s|r"
    SPEC_FRAME_PRIMARY_STAT = "Primary Stat: %s"
    MERCHANT_ITEMS_PER_PAGE = 10
    UnitLevel = function() return 80 end
    tip = GameTooltip
    C_Item = C_Item or {}
    C_Item.GetItemSpell = function(id) local s = S.itemSpell[id]; if s then return "x", s end end
    C_Item.GetItemNameByID = function(id) return S.itemNameByID[id] end
    C_Spell = { GetSpellName = function(id) return S.spellNameEN and S.spellNameEN[id] end }
    C_CurrencyInfo = { GetCurrencyInfo = function(id) return { description = S.currencyDesc[id] } end }
    C_MountJournal = C_MountJournal or {}
    C_MountJournal.GetMountInfoExtraByID = function(id) return nil, S.mountDesc[id] end
    GetLootSlotLink = function(slot) return S.lootLink[slot] end
    C_MerchantFrame = { GetItemInfo = function(i) local id = S.merchant[i]; return id and { itemID = id } or nil end }
    GetBuybackItemLink = function() return nil end
    C_TradeSkillUI = { GetRecipeOutputItemData = function(id) return { itemID = S.recipeOut[id] } end }
    C_SpellBook = { GetSpellBookItemInfo = function(idx) return { spellID = S.bookSpell and S.bookSpell[idx] } end }
    C_SpecializationInfo = { GetSpecialization = function() return 1 end,
                             GetSpecializationInfo = function() return 73, "Protection" end }
    C_Reputation = { GetSelectedFaction = function() return 1 end,
                     GetFactionDataByIndex = function() return { factionID = S.factionID } end }

    -- міксини Blizzard (у грі — з LoD-аддонів; тут — одразу, ADDON_LOADED шлемо в M.run)
    SpellBookItemMixin = {
        UpdateVisuals = function(self) self.Name:SetText(self.spellBookItemInfo.name) end,
        UpdateSubName = function(self, t) self.SubName:SetText(t) end,
    }
    ClassSpecContentFrameMixin = { Setup = function(self) self.SpecName:SetText("Protection"); self.RoleName:SetText("Tank")
        self.Description:SetText("A stalwart protector.|nPrimary Stat: Strength") end }
    HeroTalentsContainerMixin = { UpdateHeroSpecButton = function(self) self.HeroSpecLabel:SetText(self.activeSubTreeInfo.name:upper()) end }
    PaperDollFrame_SetLevel = function() CharacterLevelText:SetText("Level 80 |cffc69b6dProtection Warrior|r") end
    CharacterLevelText = FS("")
    LootFrameElementMixin = { GetSlotIndex = function(self) return self.slot end,
                              Init = function(self) self.Text:SetText(self.en) end }
    LootFrameItemElementMixin = { Init = function(self) LootFrameElementMixin.Init(self); self.QualityText:SetText("Epic") end }
    for k, v in pairs(LootFrameElementMixin) do if LootFrameItemElementMixin[k] == nil then LootFrameItemElementMixin[k] = v end end
    MerchantFrame = Frame({ page = 1 })
    MerchantFrame_UpdateMerchantInfo = function()
        for i = 1, 10 do local n = _G["MerchantItem" .. i .. "Name"]; if n and S.merchantEN[i] then n:SetText(S.merchantEN[i]) end end
    end
    MerchantFrame_UpdateBuybackInfo = function() end
    TokenEntryMixin = { Initialize = function(self, ed) self.elementData = ed; self.Content.Name:SetText(ed.name) end,
                        RefreshTextColor = function(self) self.Content.Name:SetTextColor(0.5, 0.5, 0.5) end }
    TokenHeaderMixin = { Initialize = function(self, ed) self.T:SetText(ed.name) end, GetTitleRegion = function(self) return self.T end }
    TokenSubHeaderMixin = { Initialize = function(self, ed) self.Text:SetText(ed.name) end }
    PaperDollTitlesPane_InitButton = function(button, ed) button.text:SetText(ed.playerTitle.name) end
    CharacterFrame = Frame({ TT = FS(""), SetTitle = function(self, t) self.TT:SetText(t) end,
                             GetTitleText = function(self) return self.TT end })
    ReputationEntryMixin = { Initialize = function(self, ed) self.factionID = ed.factionID; self.Content.Name:SetText(ed.name) end }
    ReputationHeaderMixin = { Initialize = function(self, ed) self.factionID = ed.factionID; self.Name:SetText(ed.name) end }
    ReputationBarMixin = { UpdateReputationStandingText = function(self, t) self.BarText:SetText(t) end,
                           TryShowReputationStandingText = function() end }
    ReputationFrame = Frame({ ReputationDetailFrame = Frame({ Title = FS(""),
        Refresh = function(self) self.Title:SetText(M.state.factionEN) end }) })
    ProfessionsRecipeListRecipeMixin = { Init = function(self, node) self.Label:SetText(node:GetData().recipeInfo.name) end }
    ProfessionsRecipeListCategoryMixin = { Init = function(self, node) self.Label:SetText(node:GetData().categoryInfo.name) end }
    ProfessionsRecipeSchematicFormMixin = {
        UpdateOutputItem = function(self) self.OutputText:SetText("|cffa335ee" .. self.enName .. "|r") end,
        UpdateRecipeDescription = function(self) self.Description:SetText(self.enDesc) end }
    ProfessionsReagentSlotMixin = { Update = function(self) self.Name:SetText("|cffffffff0/5 " .. self.enName .. "|r") end,
                                    GetReagentSlotSchematic = function(self) return { reagents = { { itemID = self.itemID } } } end }
    FormatProfession = function(frame) frame.professionName:SetText(frame.enName) end
    TransmogSituationMixin = { Init = function(self, d) self.Title:SetText(d.name) end }
    LootAlertSystem = { setUpFunction = function(self, link) self.ItemName:SetText("Toast EN"); self.Label:SetText("You Won!"); return true end }
    LootUpgradeAlertSystem = { setUpFunction = function(self) self.WhiteText:SetText("Toast EN"); return true end }
    CustomizationDropdownWithSteppersAndLabelMixin = { SetupOption = function(self, o) self.Label:SetText(o.name) end }
    CustomizationOptionCheckButtonMixin = { SetupOption = function(self, o) self.Label:SetText(o.name) end }
    CustomizationOptionSliderMixin = { SetupOption = function() end }
    CustomizationElementDetailsMixin = { UpdateText = function(self, c) self.SelectionName:SetText(c.name) end }
    CharCustomizeAlteredFormDropdownItemMixin = { Init = function(self, c) self.Text:SetText(c.name) end }
    PerksProgramProductButtonMixin = { SetItemInfo = function(self, info) self.itemInfo = info; self.ContentsContainer.Label:SetText(info.name) end }
    PerksProgramProductDetailsFrameMixin = { Refresh = function(self) self.ProductNameText:SetText(self.data.name) end }
    PerksProgramToyDetailsFrameMixin = { UpdateDetails = function(self, d) self.ProductNameText:SetText(d.name) end }
    NewRecipeLearnedAlertSystem = { setUpFunction = function(frame) frame.Name:SetText(frame.en); return true end }
    -- сумки: дві комірки, поле пошуку, рідний SetItemSearch
    local function tex()
        local t = { shown = false }
        function t:Show() self.shown = true end
        function t:Hide() self.shown = false end
        function t:SetShown(v) self.shown = v and true or false end
        function t:IsShown() return self.shown end
        t.SetAllPoints, t.SetColorTexture, t.SetBlendMode = function() end, function() end, function() end
        return t
    end
    local function bagButton(slot)
        local b = { slot = slot, tex = {} }
        function b:GetBagID() return 0 end
        function b:GetID() return self.slot end
        function b:CreateTexture() local t = tex(); self.tex[#self.tex + 1] = t; return t end
        return b
    end
    S.bagItems, S.bagButtons = {}, { bagButton(1), bagButton(2) }
    C_Container = { SetItemSearch = function() end, GetContainerItemID = function(_, slot) return S.bagItems[slot] end }
    local bagFrame = { IsShown = function() return true end }
    function bagFrame:EnumerateValidItems()
        local i = 0
        return function() i = i + 1; local b = S.bagButtons[i]; if b then return i, b end end
    end
    function bagFrame:Update() end
    function bagFrame:UpdateSearchResults() end
    S.bagFrame = bagFrame
    ContainerFrameUtil_EnumerateContainerFrames = function()
        local done = false
        return function() if not done then done = true; return 1, bagFrame end end
    end
    BagItemSearchBox = { t = "", GetText = function(self) return self.t end, hooks = {},
                         HookScript = function(self, w, f) self.hooks[w] = f end }
    -- тултіпи з рядками, дописаними кодом: власник-кнопка таланту і рядок статів
    CharacterStatsPane = { IsShown = function() return true end }
    S.statFrame = { GetParent = function() return CharacterStatsPane end }
    S.talentButton = { GetTalentFrame = function() return {} end }
    GenericTraitFrame = { Header = { Title = FS("") }, IsShown = function() return true end,
                          ApplyLayout = function(self, l) self.Header.Title:SetText(l.Title) end }
    GetActionInfo = function() return "macro", 1 end
    GetMacroSpell = function() return M.state.macroSpell end
end

-- ── сценарії ───────────────────────────────────────────────────────────────────────────────────────────
local function unesc(s) return (s:gsub("\\(.)", function(c) return ({ n = "\n", t = "\t", r = "\r" })[c] or c end)) end

-- перший запис пакета ID-домену з потрібним полем (і, за потреби, другим полем)
local function pickID(U, dom, f1, f2)
    U.Need(dom)
    local p = U.packs[dom]
    local best
    for k, v in pairs(p or {}) do
        if type(k) == "number" and k % 16 == U.FIELD[f1] then
            local id = math.floor(k / 16)
            if not f2 or p[id * 16 + U.FIELD[f2]] then
                if not best or id < best then best = id end
            end
        end
    end
    return best
end

local function spellSample(U)
    for line in io.lines(TD .. "/spells.tsv") do
        local id, aura, en, want = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
        if id and aura == "0" and not en:find("Fireball", 1, true) and #en < 150 then
            local got = U.SpellText.Render(id, unesc(en))
            if got and U.ID("spell", id, "name") then return tonumber(id), unesc(en), got end
        end
    end
end

function M.run(H, U, check, td)
    TD = td
    local S = M.state
    local ID = U.ID
    for _, a in ipairs({ "Blizzard_PlayerSpells", "Blizzard_ProfessionsBook", "Blizzard_ProfessionsTemplates", "Blizzard_Professions",
                         "Blizzard_TokenUI", "Blizzard_Transmog", "Blizzard_CustomizationUI", "Blizzard_CharacterCustomize",
                         "Blizzard_PerksProgram", "Blizzard_GenericTraitUI" }) do H.fire("ADDON_LOADED", a) end
    local K = U.CharKit
    local errs = {}
    local function results(name, ok, detail)
        check("char:" .. name, ok, detail)
    end

    -- 1. тултіп предмета: назва, опис, службові рядки, ефект «Use:» (spellID з API), праві написи, набір
    do
        local itemID = pickID(U, "item", "flavor", "name")
        local sid, en, want = spellSample(U)
        S.itemSpell[itemID] = sid
        local LT = Enum.TooltipDataLineType
        tip:Fill({ { "Some Item" }, { "Item Level 315" }, { "Soulbound" }, { "Two-Hand", "Plate" }, { "+47 Strength" },
                   { "Use: " .. en .. " (1 Min Cooldown)" }, { '"Some flavor text."' } })
        local data = { id = itemID, lines = {
            { type = LT.ItemName, lineIndex = 1 }, { type = LT.ItemLevel, lineIndex = 2 }, { type = LT.ItemBinding, lineIndex = 3 },
            { type = LT.EquipSlot, lineIndex = 4 }, { type = LT.None, lineIndex = 5 }, { type = LT.ItemSpellTriggerOnUse, lineIndex = 6 },
            { type = LT.FlavorText, lineIndex = 7 } } }
        H.tooltipPost[Enum.TooltipDataType.Item](tip, data)
        local g = function(i, side) return _G["GameTooltipText" .. (side or "Left") .. i]:GetText() end
        local okName = g(1) == ID("item", itemID, "name")
        local okIL = g(2) == (U.T("ui", "Item Level 315") or "Item Level 315")
        local okSB = g(3) == U.T("ui", "Soulbound")
        local okR = g(4, "Right") == U.T("ui", "Plate") and g(4) == U.T("ui", "Two-Hand")
        local okStat = g(5) == (U.T("ui", "+47 Strength") or "+47 Strength")
        local wantFx = (U.T("ui", "Use:") or "Use:") .. " " .. want
        local okFx = g(6):sub(1, #wantFx) == wantFx
        local okFl = g(7) == '"' .. ID("item", itemID, "flavor") .. '"'
        results("tooltip-item", okName and okIL and okSB and okR and okStat and okFx and okFl,
            ("назва %s, ilvl %s, прив'язка %s, слот/тип %s, стат %s, ефект %s, опис %s | %s | %s | %s"):format(
            tostring(okName), tostring(okIL), tostring(okSB), tostring(okR), tostring(okStat), tostring(okFx), tostring(okFl),
            g(2), g(5), g(6):sub(1, 90)))
        -- /uw: оригінал повертається
        U.ShowOriginal(true)
        local back = g(1) == "Some Item" and g(6):sub(1, 4) == "Use:"
        U.ShowOriginal(false)
        results("tooltip-toggle", back and g(1) == ID("item", itemID, "name"), "перемикач /uw повертає EN і назад UA")
    end

    -- 2. тултіп закляття: назва + опис; аура; заголовок до AppendInfo (талант)
    do
        local sid, en, want = spellSample(U)
        local LT = Enum.TooltipDataLineType
        tip:Fill({ { "Spell EN" }, { "Instant", "40 yd range" }, { en } })
        H.tooltipPost[Enum.TooltipDataType.Spell](tip, { id = sid, lines = {
            { type = LT.SpellName, lineIndex = 1 }, { type = LT.None, lineIndex = 2 }, { type = LT.SpellDescription, lineIndex = 3 } } })
        local g = function(i, side) return _G["GameTooltipText" .. (side or "Left") .. i]:GetText() end
        local ok1 = g(1) == ID("spell", sid, "name") and g(3) == want and g(2) == (U.T("ui", "Instant") or "Instant")
        -- талант: рядок 1 поставлено до вставки даних, дані — з рядка 2
        S.spellNameEN = { [sid] = "Talent EN" }
        tip:Fill({ { "Talent EN" }, { "" }, { en } })
        H.tooltipPost[Enum.TooltipDataType.Spell](tip, { id = sid, lines = { { type = LT.SpellDescription, lineIndex = 3 } } })
        local ok2 = g(1) == ID("spell", sid, "name") and g(3) == want
        -- макрос #showtooltip
        S.macroSpell = sid
        tip.owner = { action = 5 }
        tip:Fill({ { "Spell EN" }, { en } })
        H.tooltipPost[Enum.TooltipDataType.Macro](tip, { id = 1, lines = { { type = LT.SpellName, lineIndex = 1 }, { type = LT.SpellDescription, lineIndex = 2 } } })
        local ok3 = g(1) == ID("spell", sid, "name") and g(2) == want
        results("tooltip-spell", ok1 and ok2 and ok3, ("закляття %s, талант %s, макрос %s: %s"):format(tostring(ok1), tostring(ok2), tostring(ok3), tostring(g(1))))
    end

    -- 3. валюта й маунт: назва за ID, опис за збігом з EN-описом API
    do
        local cid = pickID(U, "currency", "desc", "name")
        S.currencyDesc[cid] = "Currency EN description."
        tip:Fill({ { "Cur EN" }, { "Currency EN description." }, { "Total: 5" } })
        H.tooltipPost[Enum.TooltipDataType.Currency](tip, { id = cid })
        local g = function(i) return _G["GameTooltipTextLeft" .. i]:GetText() end
        local okC = g(1) == ID("currency", cid, "name") and g(2) == ID("currency", cid, "desc")
        local mid = pickID(U, "mount", "d", "n")
        S.mountDesc[mid] = "Mount EN description."
        tip:Fill({ { "Mount EN" }, { "Mount EN description." } })
        H.tooltipPost[Enum.TooltipDataType.Mount](tip, { id = mid })
        local okM = g(1) == ID("mount", mid, "n") and g(2) == ID("mount", mid, "d")
        results("tooltip-currency-mount", okC and okM, ("валюта %s (%d), маунт %s (%d)"):format(tostring(okC), cid, tostring(okM), mid))
    end

    -- 3б. NPC: ім'я за GUID Creature-; гравця (Player-) не чіпаємо; UnitIsPlayer не кличемо
    do
        local nm = "Locked Door"
        local want = U.TranslateName(nm)
        local called = false
        local saved = UnitIsPlayer
        UnitIsPlayer = function() called = true; return false end
        tip:Fill({ { nm } })
        H.tooltipPost[Enum.TooltipDataType.Unit](tip, { guid = "Creature-0-1-2-3-4-5" })
        local okN = _G.GameTooltipTextLeft1:GetText() == (want or nm)
        tip:Fill({ { nm } })
        H.tooltipPost[Enum.TooltipDataType.Unit](tip, { guid = "Player-1-0ABC" })
        local okP = _G.GameTooltipTextLeft1:GetText() == nm
        UnitIsPlayer = saved
        results("tooltip-unit", okN and okP and not called, ("NPC %s, гравець недоторканий %s, UnitIsPlayer не викликано %s"):format(
            tostring(okN), tostring(okP), tostring(not called)))
    end

    -- 4. книга заклять, спеки, героїчне дерево, рядок рівня
    do
        local sid = spellSample(U)
        local item = fromMixin(SpellBookItemMixin, { Name = FS(""), SubName = FS(""), RequiredLevel = FS(""),
            spellBookItemInfo = { name = "Spell EN", spellID = sid } })
        item:UpdateVisuals()
        item:UpdateSubName("Passive")
        local okB = item.Name:GetText() == ID("spell", sid, "name") and item.SubName:GetText() == (U.T("ui", "Passive") or "Passive")
        local spec = fromMixin(ClassSpecContentFrameMixin, { SpecName = FS(""), RoleName = FS(""), Description = FS("") })
        spec:Setup(1)
        local okS = spec.SpecName:GetText() == U.T("ui", "Protection") and spec.RoleName:GetText() == U.T("ui", "Tank")
        local hero = fromMixin(HeroTalentsContainerMixin, { HeroSpecLabel = FS(""), activeSubTreeInfo = { name = "Colossus" } })
        hero:UpdateHeroSpecButton()
        local okH = hero.HeroSpecLabel:GetText() == K.upper(U.T("ui", "Colossus"))
        PaperDollFrame_SetLevel()
        local lvl = CharacterLevelText:GetText()
        local okL = lvl:find("[\208\209]") ~= nil or (UwowMiss.d.ui and true)     -- переклад або промах формату
        results("spellbook-spec", okB and okS and okH and okL, ("книга %s, спек %s, герой %s (%s), рівень «%s»"):format(
            tostring(okB), tostring(okS), tostring(okH), hero.HeroSpecLabel:GetText(), lvl))
    end

    -- 5. здобич, торговець, валюти (оверлей), титули, репутація
    do
        local iid = pickID(U, "item", "name")
        S.lootLink[1] = "|cffffffff|Hitem:" .. iid .. "::::|h[Loot EN]|h|r"
        local le = fromMixin(LootFrameItemElementMixin, { Text = FS(""), QualityText = FS(""), slot = 1, en = "Loot EN" })
        le:Init()
        local okLoot = le.Text:GetText() == ID("item", iid, "name") and le.QualityText:GetText() == (U.T("ui", "Epic") or "Epic")
        S.merchant[1] = iid
        S.merchantEN = { "Merchant EN" }
        _G.MerchantItem1Name = FS("")
        MerchantFrame_UpdateMerchantInfo()
        local okMer = MerchantItem1Name:GetText() == ID("item", iid, "name")
        local cid = pickID(U, "currency", "name")
        local entry = fromMixin(TokenEntryMixin, { Content = Frame({ Name = FS("") }) })
        entry.Content.Name.parent = entry.Content
        entry:Initialize({ name = "Cur EN", currencyID = cid })
        entry:RefreshTextColor()
        -- рідний напис лишився англійським (гра його читає), видно — оверлей
        local okTok = entry.Content.Name:GetText() == "Cur EN" and entry.Content.Name:GetAlpha() == 0
        local ov
        for fs, p in pairs(U.orig) do if p.en == "Cur EN" and p.ua == ID("currency", cid, "name") then ov = fs end end
        okTok = okTok and ov ~= nil and ov:GetText() == ID("currency", cid, "name") and ov:IsShown()
        local btn = { text = FS("") }
        PaperDollTitlesPane_InitButton(btn, { playerTitle = { name = "Headmistress" } })
        local okT = btn.text:GetText() == U.T("ui", "Headmistress")
        CharacterFrame:SetTitle("Rinss the Elite Druid")
        local okT2 = CharacterFrame.TT:GetText() == "Rinss " .. (U.T("ui", "the Elite Druid") or "?")
        local fid = pickID(U, "faction", "n")
        local re = fromMixin(ReputationEntryMixin, { Content = { Name = FS("") } })
        re:Initialize({ factionID = fid, name = "Faction EN" })
        local okRep = re.Content.Name:GetText() == ID("faction", fid, "n")
        S.factionID, S.factionEN = fid, "Faction EN"
        ReputationFrame.ReputationDetailFrame:Refresh()
        okRep = okRep and ReputationFrame.ReputationDetailFrame.Title:GetText() == ID("faction", fid, "n")
        results("items-economy", okLoot and okMer and okTok and okT and okT2 and okRep,
            ("здобич %s, торговець %s, валюти %s, титули %s/%s, репутація %s"):format(tostring(okLoot), tostring(okMer),
            tostring(okTok), tostring(okT), tostring(okT2), tostring(okRep)))
    end

    -- 6. професії: рядок рецепта (предмет-результат), назва в формі, реагент, книга професій, тост рецепта
    do
        local iid = pickID(U, "item", "name")
        local sid = spellSample(U)
        S.recipeOut[sid] = iid
        local row = fromMixin(ProfessionsRecipeListRecipeMixin, { Label = FS("") })
        row:Init({ GetData = function() return { recipeInfo = { recipeID = sid, name = "Recipe EN" } } end })
        local okRow = row.Label:GetText() == ID("item", iid, "name")
        local form = fromMixin(ProfessionsRecipeSchematicFormMixin, { OutputText = FS(""), Description = FS(""), enName = "Out EN",
            transaction = { GetRecipeID = function() return sid end } })
        form:UpdateOutputItem()
        local okOut = form.OutputText:GetText() == "|cffa335ee" .. ID("item", iid, "name") .. "|r"
        S.itemNameByID[iid] = "Reagent EN"
        local slot = fromMixin(ProfessionsReagentSlotMixin, { Name = FS(""), enName = "Reagent EN", itemID = iid })
        slot:Update()
        local okReag = slot.Name:GetText() == "|cffffffff0/5 " .. ID("item", iid, "name") .. "|r"
        local pf = { professionName = FS(""), enName = "Classic Tailoring", rank = FS(""), specialization = FS("") }
        FormatProfession(pf)
        local okBook = pf.professionName:GetText() == U.T("ui", "Classic Tailoring")
        local toast = { Name = FS(""), en = "Recipe EN |T123:0|t" }
        NewRecipeLearnedAlertSystem.setUpFunction(toast, sid)
        local okToast = toast.Name:GetText() == ID("spell", sid, "name") .. " |T123:0|t"
        results("professions", okRow and okOut and okReag and okBook and okToast,
            ("рецепт %s, результат %s, реагент %s, книга %s, тост %s"):format(tostring(okRow), tostring(okOut), tostring(okReag),
            tostring(okBook), tostring(okToast)))
    end

    -- 7. трансмогрифікатор, тости луту, перукарня, Торговий пост
    do
        local sit = fromMixin(TransmogSituationMixin, { Title = FS("") })
        sit:Init({ name = "Specializations" })
        local okW = sit.Title:GetText() == U.T("ui", "Specializations")
        local iid0 = pickID(U, "item", "name")
        local toast = { ItemName = FS(""), Label = FS("") }
        LootAlertSystem.setUpFunction(toast, "|cff0070dd|Hitem:" .. iid0 .. "::|h[Toast EN]|h|r", 1, nil, nil, nil, false)
        local up = { WhiteText = FS("") }
        LootUpgradeAlertSystem.setUpFunction(up, "|Hitem:" .. iid0 .. "::|h")
        okW = okW and toast.ItemName:GetText() == ID("item", iid0, "name") and up.WhiteText:GetText() == ID("item", iid0, "name")
        local o = fromMixin(CustomizationDropdownWithSteppersAndLabelMixin, { Label = FS("") })
        o:SetupOption({ name = "Hair Highlight Color" })
        local c = fromMixin(CustomizationElementDetailsMixin, { SelectionName = FS("") })
        c:UpdateText({ name = "Jade Studs" })
        local okB = o.Label:GetText() == U.T("ui", "Hair Highlight Color") and c.SelectionName:GetText() == U.T("ui", "Jade Studs")
        local iid = pickID(U, "item", "name")
        local pb = fromMixin(PerksProgramProductButtonMixin, { ContentsContainer = { Label = FS("") } })
        pb:SetItemInfo({ itemID = iid, name = "Product EN" })
        local okP = pb.ContentsContainer.Label:GetText() == ID("item", iid, "name")
        results("looks", okW and okB and okP, ("трансмогрифікатор+тости луту %s, перукарня %s, пост %s"):format(tostring(okW), tostring(okB), tostring(okP)))
    end

    -- 8. описи з умовами $?…[…][…]: синтетичний показ (перша/остання гілка, числа = 37), UA без службових токенів
    do
        local pe, p = U.packs.sdesc_en, U.packs.sdesc
        local n, ok, bad = 0, 0, nil
        local keys = {}
        for k, en in pairs(pe) do if en:find("$?", 1, true) and p[k] then keys[#keys + 1] = k end end
        table.sort(keys)
        local function chainEnd(s, a)                         -- спрощений показ: беремо першу гілку кожного ланцюжка
            local out, i = {}, 1
            while true do
                local q = s:find("$?", i, true)
                if not q then out[#out + 1] = s:sub(i); break end
                local br = s:find("[", q, true)
                local e
                if br then _, e = s:find("%b[]", br) end
                if not e then out[#out + 1] = s:sub(i); break end
                out[#out + 1] = s:sub(i, q - 1) .. s:sub(br + 1, e - 1)
                i = e + 1
                while s:sub(i, i) == "?" or s:sub(i, i) == "[" do                 -- решта гілок ланцюжка
                    local b2 = s:find("[", i, true)
                    local _, e2 = s:find("%b[]", b2)
                    if not e2 then break end
                    i = e2 + 1
                end
            end
            return table.concat(out)
        end
        for idx = 1, #keys, math.max(1, math.floor(#keys / 400)) do
            local k = keys[idx]
            local en = pe[k]
            local shown = chainEnd(en)
            if not shown:find("$?", 1, true) and not shown:find("$@", 1, true) and not shown:find("%$[lLgG]") then
                shown = shown:gsub("%${[^}]*}%.?%d*", "37"):gsub("%$[/%*][%d%.]+;%d*%a%d*", "37"):gsub("%$<[%w_]+>", "37")
                             :gsub("%$%d*[dD]%d*", "37 sec"):gsub("%$%d*%a+%d*", "37")
                n = n + 1
                local got = U.SpellText.Render(math.floor(k / 16), shown, k % 16 == 4)
                if got and not got:find("$", 1, true) and not got:find("%?%a%d") then ok = ok + 1
                elseif not bad then bad = ("%d %q → %s"):format(math.floor(k / 16), shown:sub(1, 70), tostring(got):sub(1, 60)) end
            end
        end
        results("spell-cond", n > 50 and ok >= n * 0.85, ("умовних описів %d, перекладено %d%s"):format(n, ok, bad and (", приклад промаху: " .. bad) or ""))
    end

    -- 9. пошук у сумках українською: власна підсвітка/затемнення, рідні кнопки не чіпаємо; у бою — відкладено
    do
        local a = pickID(U, "item", "name")
        local b
        for k in pairs(U.packs.item) do
            local id = math.floor(k / 16)
            if k % 16 == 1 and id ~= a and not U.ID("item", id, "name"):find(U.ID("item", a, "name"), 1, true) then b = id; break end
        end
        S.bagItems[1], S.bagItems[2] = a, b
        local uaA = U.ID("item", a, "name")
        local q = K.upper(uaA:sub(1, 6)):sub(1, 6)                           -- перші літери, великими (пошук без регістру)
        local b1, b2 = S.bagButtons[1], S.bagButtons[2]
        local function shown(btn, k) return btn.tex[k] and btn.tex[k].shown or false end   -- 1 = підсвітка, 2 = затемнення
        BagItemSearchBox.t = q
        C_Container.SetItemSearch(q)
        local ok1 = shown(b1, 1) and not shown(b1, 2) and not shown(b2, 1) and shown(b2, 2)
        b2.matchesSearch = false                                             -- Blizzard уже притемнив — своєї тіні не додаємо
        H.fire("INVENTORY_SEARCH_UPDATE")
        local ok2 = not shown(b2, 2) and shown(b1, 1)
        local saved = InCombatLockdown
        InCombatLockdown = function() return true end
        C_Container.SetItemSearch("")                                        -- у бою: нічого не міняємо
        local ok3 = shown(b1, 1)
        InCombatLockdown = saved
        H.fire("PLAYER_REGEN_ENABLED")                                       -- після бою — оновлення
        local ok4 = not shown(b1, 1) and not shown(b2, 1)
        BagItemSearchBox.t = q
        BagItemSearchBox.hooks.OnTextChanged(BagItemSearchBox)                -- поле пошуку банку/сумок
        local ok5 = shown(b1, 1)
        C_Container.SetItemSearch("sword")                                   -- латиниця — рідний пошук, ми не втручаємось
        local ok6 = not shown(b1, 1) and not shown(b2, 2)
        results("bag-search", ok1 and ok2 and ok3 and ok4 and ok5 and ok6,
            ("запит «%s»: підсвітка/тінь %s, без подвійної тіні %s, бій %s, після бою %s, поле %s, латиниця %s"):format(
            q, tostring(ok1), tostring(ok2), tostring(ok3), tostring(ok4), tostring(ok5), tostring(ok6)))
    end

    -- 10. рядки, дописані кодом у GameTooltip: талант (до Show), стати, заголовок GenericTraitFrame
    do
        local t = GameTooltip
        t:SetOwner(S.talentButton)
        t:SetText("Talent EN")
        t:AddLine("Specializations")
        local okT = _G.GameTooltipTextLeft1:GetText() == "Talent EN" and _G.GameTooltipTextLeft2:GetText() == U.T("ui", "Specializations")
        t:SetOwner(S.statFrame)
        t:SetText("Haste")
        t:AddLine("+47 Strength")
        local okS = _G.GameTooltipTextLeft1:GetText() == U.T("ui", "Haste") and _G.GameTooltipTextLeft2:GetText() == (U.T("ui", "+47 Strength") or "+47 Strength")
        t:SetOwner({})                                                       -- чужий тултіп не чіпаємо
        t:SetText("Haste")
        local okO = _G.GameTooltipTextLeft1:GetText() == "Haste"
        GenericTraitFrame:ApplyLayout({ Title = "Specializations" })
        local okG = GenericTraitFrame.Header.Title:GetText() == U.T("ui", "Specializations")
        results("tooltip-lines", okT and okS and okO and okG, ("талант %s, стати %s, чужий недоторканий %s, GenericTrait %s"):format(
            tostring(okT), tostring(okS), tostring(okO), tostring(okG)))
    end

    local e = {}
    for k, v in pairs(K.errors) do e[#e + 1] = k .. ": " .. v end
    results("no-hook-errors", #e == 0, #e == 0 and "помилок у хуках немає" or table.concat(e, " | "))
end

return M
