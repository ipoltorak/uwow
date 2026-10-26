-- tests/surf_coll.lua — поверхні зони coll: досягнення, сповіщення, путівник, колекції, житло, гарнізон.
-- Заглушки фреймів Blizzard (імена й ключі — з wow-ui-source live 12.1.5), подія ADDON_LOADED відповідного
-- LoD-аддона, далі — те, що робить Blizzard (SetText англійського, ініціалізація рядка ScrollBox), і перевірка,
-- що напис став українським і дорівнює даним збірки.
local M = {}

-- До завантаження аддона (як у грі на PLAYER_LOGIN): глобали FrameXML, які є завжди.
function M.pre(H)
    AchievementAlertSystem, NewMountAlertSystem, CriteriaAlertSystem = {}, {}, {}
    -- AlertFrame — з harness (спільний для coll і world)
    SharedPetBattleAbilityTooltip_SetAbility = function(tip) tip.Name:SetText("Double Zap") end
end

function M.run(H, U, check)
    local function cyr(s) return type(s) == "string" and s:find("[\208\209\210]") ~= nil end

    local function FS(text)
        local fs = { t = text, shown = true }
        function fs.SetText(self, v) self.t = v end
        function fs.GetText(self) return self.t end
        function fs.GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
        function fs.SetFont() return true end
        function fs.GetObjectType() return "FontString" end
        function fs.IsTruncated() return false end
        function fs.GetContentHeight() return 12 end
        function fs.Hide(self) self.shown = false end
        function fs.Show(self) self.shown = true end
        function fs.IsShown(self) return self.shown end
        return fs
    end
    local function Frame(t)
        t = t or {}
        local regions, children = t._regions or {}, t._children or {}
        t._regions, t._children = nil, nil
        function t.GetRegions() return unpack(regions) end
        function t.GetChildren() return unpack(children) end
        function t.HookScript(self, w, f)
            local l = rawget(self, "_hooks_" .. w) or {}; rawset(self, "_hooks_" .. w, l); l[#l + 1] = f
        end
        function t.IsShown() return false end
        function t.SetHeight() end
        function t.GetParent(self) return self._parent end
        return t
    end
    local function Box()
        local b = { cbs = {} }
        function b.RegisterCallback(self, ev, fn, owner) self.cbs[#self.cbs + 1] = function(...) fn(owner, ...) end end
        function b.ForEachFrame() end
        function b.init(self, frame, data) for _, f in ipairs(self.cbs) do f(frame, data) end end
        return b
    end
    local loaded = {}
    C_AddOns.IsAddOnLoaded = function(n) return n == "Uwow" or loaded[n] or false end
    local function load(name) loaded[name] = true; H.fire("ADDON_LOADED", name) end

    local errs = {}
    local function try(name, fn)
        local ok, e = pcall(fn)
        if not ok then errs[#errs + 1] = name .. ": " .. tostring(e) end
    end

    -- ── дані збірки, на які спираються перевірки ──────────────────────────────────────────────────────
    local A1, A2 = U.ID("ach", 10000, "title"), U.ID("ach", 10001, "title")
    local D1 = U.ID("ach", 10000, "desc")
    check("coll-data", cyr(A1) and cyr(A2) and cyr(D1) and cyr(U.ID("mount", 6, "n")) and cyr(U.ID("pet", 39, "n"))
        and cyr(U.T("journal", "Algeth'ar Academy")) and cyr(U.T("collections", "Double Zap")),
        "ach/mount/pet/journal/collections є у збірці")

    -- ── 1. вікно досягнень ───────────────────────────────────────────────────────────────────────────
    local catBox, achBox, statBox = Box(), Box(), Box()
    local function DisplayCriteria() end
    try("ach", function()
        AchievementFrame = Frame({ Header = { Title = FS("Achievements") }, numTabs = 2, SearchResults = { ScrollBox = Box() } })
        AchievementFrame.IsShown = function() return false end
        AchievementFrameTab1 = { Text = FS("Statistics") }
        AchievementFrameTab2 = { Text = FS("Guild") }
        AchievementFrameCategories = { ScrollBox = catBox }
        AchievementFrameAchievements = { ScrollBox = achBox }
        AchievementFrameStats = { ScrollBox = statBox }
        AchievementObjectives_DisplayCriteria = DisplayCriteria
        GetAchievementNumCriteria = function() return 2 end
        GetAchievementCriteriaInfo = function(id, i)
            if i == 1 then return "Some Meta", 8, true, 0, 0, nil, 0, 10001 end
            return "Arena", 99, false, 0, 0, nil, 0, 0
        end
        load("Blizzard_AchievementUI")
    end)
    local cat = { Button = { Label = FS("Arena") } }
    try("ach-cat", function() catBox:init(cat, { id = 1 }) end)
    check("ach-category", cyr(cat.Button.Label:GetText()), "категорія «Arena» → " .. tostring(cat.Button.Label:GetText()))

    local btn = { id = 10000, Label = FS("Guardian of the Horde"), Description = FS("End season"), HiddenDescription = FS("End season"),
                  Reward = FS("Reward: Title") }
    try("ach-btn", function() achBox:init(btn, { id = 10000 }) end)
    local first = btn.Label:GetText() == A1 and btn.Description:GetText() == D1 and btn.HiddenDescription:GetText() == D1
    -- повторне використання кнопки: Blizzard ставить нове id і англійський текст — супровід перекладає одразу
    btn.id = 10001
    btn.Label:SetText("Defender of the Horde")
    check("ach-button", first and btn.Label:GetText() == A2,
        ("назва %s, опис %s, після перевикористання %s"):format(tostring(first), tostring(btn.Description:GetText()):sub(1, 30), tostring(btn.Label:GetText())))

    local obj = { metas = { { id = 10001, Label = FS("Some Meta") } }, criterias = { { Name = FS("- Arena") } } }
    try("ach-crit", function() AchievementObjectives_DisplayCriteria(obj, 10000) end)
    check("ach-criteria", obj.metas[1].Label:GetText() == A2 and obj.criterias[1].Name:GetText():find("^%- ") and cyr(obj.criterias[1].Name:GetText()),
        "мета → " .. tostring(obj.metas[1].Label:GetText()) .. ", текст → " .. tostring(obj.criterias[1].Name:GetText()))

    local stat = { isHeader = false, id = 10000, Text = FS("Some statistic") }
    try("ach-stat", function() statBox:init(stat, {}) end)
    try("ach-show", function() H.script(AchievementFrame, "OnShow") end)
    check("ach-stats-tabs", stat.Text:GetText() == A1 and cyr(AchievementFrameTab1.Text:GetText()) and cyr(AchievementFrame.Header.Title:GetText()),
        "статистика " .. tostring(stat.Text:GetText()) .. ", вкладка " .. tostring(AchievementFrameTab1.Text:GetText()))

    -- ── 2. сповіщення ────────────────────────────────────────────────────────────────────────────────
    local aSys, mSys = AchievementAlertSystem, NewMountAlertSystem
    C_MountJournal = C_MountJournal or {}                 -- доповнюємо: GetMountInfoExtraByID ставить набір char
    C_MountJournal.GetMountInfoByID = function() return "Brown Horse" end
    C_MountJournal.GetDisplayedMountInfo = function() return "Brown Horse", 458, 0, false, true, 0, false, false, 0, false, true, 6 end
    C_MountJournal.GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID or function() end
    local af = { queue = aSys, id = 10000, Name = FS("Guardian of the Horde"), Unlocked = FS("Achievement Earned") }
    local mf = { queue = mSys, mountID = 6, Name = FS("|cffa335eeBrown Horse|r"), Label = FS("You Collected") }
    try("alerts", function() AlertFrame:AddAlertFrame(af); AlertFrame:AddAlertFrame(mf) end)
    local mount = U.ID("mount", 6, "n")
    check("alerts", af.Name:GetText() == A1 and cyr(af.Unlocked:GetText()) and mf.Name:GetText() == "|cffa335ee" .. mount .. "|r",
        "досягнення " .. tostring(af.Name:GetText()) .. " · маунт " .. tostring(mf.Name:GetText()) .. " · " .. tostring(af.Unlocked:GetText()))

    -- ── 3. путівник ──────────────────────────────────────────────────────────────────────────────────
    local instBox, bossBox, lootBox = Box(), Box(), Box()
    local loreFS = FS("")
    local EJ
    try("ej", function()
        EJ = Frame({
            instanceSelect = Frame({ ScrollBox = instBox }),
            encounter = {
                instance = { title = FS(""), LoreScrollingFont = { GetFontString = function() return loreFS end } },
                info = { instanceTitle = FS(""), encounterTitle = FS(""), BossesScrollBox = bossBox, LootContainer = { ScrollBox = lootBox } },
                overviewFrame = { loreDescription = FS(""), overviewDescription = { Text = FS("") } },
                infoFrame = { description = FS("") },
                usedHeaders = {},
            },
            navBar = {},
            JourneysFrame = { JourneysList = Box() },
            MonthlyActivitiesFrame = Frame({ ScrollBox = Box(), FilterList = { ScrollBox = Box() } }),
        })
        EJ.IsShown = function() return false end
        EncounterJournal = EJ
        EncounterJournal_SetBullets = function(object, description) object.Text:SetText(description) end
        EncounterJournal_ToggleHeaders = function() end
        load("Blizzard_EncounterJournal")
    end)
    local ib = { name = FS("Algeth'ar Academy") }
    try("ej-inst", function() instBox:init(ib, {}) end)
    local acad = U.T("journal", "Algeth'ar Academy")
    -- Blizzard показує інстанс: SetText назви — супровід міняє одразу (до виміру ширини)
    EJ.encounter.instance.title:SetText("Algeth'ar Academy")
    -- дерево секцій: новий заголовок із текстом у формі з числами
    local hdr = { button = { title = FS("Alyson silences all players within 8 yards for 4 sec.") }, description = FS("") }
    EJ.encounter.usedHeaders[1] = hdr
    try("ej-headers", function() EncounterJournal_ToggleHeaders(EJ.encounter.infoFrame) end)
    -- у джерелі секція збережена з «#» на місцях чисел; compile.py робить із них {#N}, тож живі числа стають на місця
    local want = U.T("journal", "Alyson silences all players within 8 yards for 4 sec.")
    local wantOk = want and cyr(want) and want:find("8", 1, true) and want:find("4", 1, true)
    check("ej", ib.name:GetText() == acad and EJ.encounter.instance.title:GetText() == acad and wantOk and hdr.button.title:GetText() == want,
        "інстанс " .. tostring(ib.name:GetText()) .. " · секція " .. tostring(hdr.button.title:GetText()))
    local ma = { TextContainer = { NameText = FS("Lorewalking: Complete 3 Campaigns"), ConditionsText = FS("") } }
    try("ej-monthly", function() EJ.MonthlyActivitiesFrame.ScrollBox:init(ma, {}) end)
    local jr = { JourneyCardName = FS("Shattrath refugees") }
    try("ej-journeys", function() EJ.JourneysFrame.JourneysList:init(jr, { factionID = 1011 }) end)
    check("ej-journeys-log", cyr(ma.TextContainer.NameText:GetText()) and jr.JourneyCardName:GetText() == U.ID("faction", 1011, "n"),
        "активність " .. tostring(ma.TextContainer.NameText:GetText()) .. " · подорож " .. tostring(jr.JourneyCardName:GetText()))

    -- ── 4. колекції ─────────────────────────────────────────────────────────────────────────────────
    local setsBox = Box()
    local details = { Name = FS(""), LongName = FS(""), Label = FS("") }
    try("coll", function()
        MountJournal_InitMountButton = function(button) button.name:SetText("Brown Horse") end
        MountJournal_UpdateMountDisplay = function() end
        PetJournal_InitPetButton = function(pet) pet.name:SetText("Mechanical Squirrel") end
        C_PetJournal = { GetPetInfoByIndex = function() return nil, 39, true, nil end, GetPetInfoByPetID = function() return 39 end }
        ToySpellButton_UpdateButton = function() end
        WardrobeCollectionFrame = { SetsCollectionFrame = { ListContainer = { ScrollBox = setsBox }, DetailsFrame = details,
                                                            DisplaySet = function(self) self.DetailsFrame.Name:SetText("Dreamwalker Raiment") end } }
        load("Blizzard_Collections")
    end)
    local mb = { name = FS("") }
    try("mount", function() MountJournal_InitMountButton(mb, { index = 1 }) end)
    local pb = { name = FS(""), subName = FS("") }
    try("pet", function() PetJournal_InitPetButton(pb, { index = 1 }) end)
    local tip = { Name = FS(""), Description = FS("") }
    try("pet-ability", function() SharedPetBattleAbilityTooltip_SetAbility(tip, {}) end)
    try("sets", function() WardrobeCollectionFrame.SetsCollectionFrame:DisplaySet(1) end)
    local srow = { Name = FS("Dreamwalker Raiment"), Label = FS("") }
    try("sets-row", function() setsBox:init(srow, {}) end)
    check("collections", mb.name:GetText() == mount and pb.name:GetText() == U.ID("pet", 39, "n") and cyr(tip.Name:GetText())
        and cyr(details.Name:GetText()) and cyr(srow.Name:GetText()),
        ("маунт %s · вихованець %s · здібність %s · сет %s"):format(tostring(mb.name:GetText()), tostring(pb.name:GetText()),
            tostring(tip.Name:GetText()), tostring(details.Name:GetText())))

    -- джерело іграшки й підказка Toy
    local lines = { FS("Some Toy"), FS("Vendor: Provisioner Stoutforge") }
    local TT = { GetName = function() return "UwowTestTip" end, NumLines = function() return #lines end }
    UwowTestTipTextLeft1, UwowTestTipTextLeft2 = lines[1], lines[2]
    local toyPost = H.tooltipPost[Enum.TooltipDataType.Toy]
    try("toy", function() toyPost(TT, { id = 6948 }) end)
    UwowTestTipTextLeft1, UwowTestTipTextLeft2 = nil, nil
    check("toy-tooltip", toyPost ~= nil and cyr(lines[2]:GetText()) and (U.ID("item", 6948, "name") == nil or lines[1]:GetText() == U.ID("item", 6948, "name")),
        "джерело " .. tostring(lines[2]:GetText()) .. " · назва " .. tostring(lines[1]:GetText()))

    -- ── 5. житло і гарнізон ──────────────────────────────────────────────────────────────────────────
    local hl = { FS('"A Bridge Over Calm Waters" Painting') }
    local HT = { GetName = function() return "UwowTestTip" end, NumLines = function() return #hl end, Show = function() end }
    UwowTestTipTextLeft1 = hl[1]
    try("housing", function() EventRegistry:TriggerEvent("HousingCatalogEntry.TooltipCreated", {}, HT) end)
    UwowTestTipTextLeft1 = nil
    local title = FS("Felblazer")
    try("garrison", function()
        GarrisonMissionList_InitButton = function(button) button.Title:SetText("Felblazer") end
        load("Blizzard_GarrisonUI")
        GarrisonMissionList_InitButton({ Title = title }, {})
    end)
    check("housing-garrison", cyr(hl[1]:GetText()) and cyr(title:GetText()),
        "декор " .. tostring(hl[1]:GetText()) .. " · місія " .. tostring(title:GetText()))

    -- ── 5б. Krowi's Achievement Filter і підказка посилання на досягнення ─────────────────────────────
    local kb = { Achievement = { Id = 10000 }, Header = FS(""), Description = FS(""), HiddenDescription = FS("") }
    local kc = { Label = FS("+ Arena") }
    try("krowi", function()
        KrowiAF_AchievementButtonMixin = { SetAchievementData = function(self) self.Header:SetText("Guardian"); self.Description:SetText("End") end }
        KrowiAF_CategoryButtonMixin = { SetCategory = function() end }
        load("Krowi_AchievementFilter")
        KrowiAF_AchievementButtonMixin.SetAchievementData(kb)
        KrowiAF_CategoryButtonMixin.SetCategory(kc)
    end)
    KrowiAF_AchievementButtonMixin, KrowiAF_CategoryButtonMixin = nil, nil
    local al = { FS("Guardian of the Horde"), FS("x"), FS("End Warlords PvP season 1") }
    GetAchievementInfo = function() return 10000, "Guardian of the Horde", 0, false, nil, nil, nil, "End Warlords PvP season 1" end
    local AT = { GetName = function() return "UwowTestTip" end, NumLines = function() return #al end }
    UwowTestTipTextLeft1, UwowTestTipTextLeft2, UwowTestTipTextLeft3 = al[1], al[2], al[3]
    try("ach-tooltip", function() H.tooltipPost[Enum.TooltipDataType.Achievement](AT, { id = 10000 }) end)
    UwowTestTipTextLeft1, UwowTestTipTextLeft2, UwowTestTipTextLeft3 = nil, nil, nil
    check("krowi-tooltip", kb.Header:GetText() == A1 and kb.Description:GetText() == D1 and kc.Label:GetText() == "+ Арена"
        and al[1]:GetText() == A1 and al[3]:GetText() == D1,
        "Krowi " .. tostring(kb.Header:GetText()) .. " / " .. tostring(kc.Label:GetText()) .. " · підказка " .. tostring(al[1]:GetText()))

    -- ── 6. перемикач /uw: оригінал повертається ──────────────────────────────────────────────────────
    U.ShowOriginal(true)
    local back = btn.Label:GetText() == "Defender of the Horde" and mb.name:GetText() == "Brown Horse"
    btn.Label:SetText("Defender of the Horde")        -- у режимі оригіналу супровід не перекладає
    back = back and btn.Label:GetText() == "Defender of the Horde"
    U.ShowOriginal(false)
    check("coll-toggle", back and btn.Label:GetText() == A2, "оригінал/переклад через /uw")

    -- ── 7. жодна поверхня не впала ───────────────────────────────────────────────────────────────────
    SlashCmdList.UWOW("stats")
    local bad = {}
    for _, m in ipairs(H.chat or {}) do if m:find("помилка") then bad[#bad + 1] = m end end
    for _, e in ipairs(errs) do bad[#bad + 1] = e end
    check("coll-install", #bad == 0, #bad == 0 and "усі поверхні зони встановились, хуки спрацювали без помилок" or table.concat(bad, "; "))
end

return M
