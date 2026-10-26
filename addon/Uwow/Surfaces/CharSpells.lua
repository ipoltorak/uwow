-- Uwow · Surfaces/CharSpells.lua — персонаж і закляття поза тултіпами:
--   книга заклять (назва за spellID, підпис «Пасивне»/ранг, «Доступно на рівні N», заголовки груп),
--   спеціалізації (назва, опис, основна характеристика, роль), назва героїчного дерева талантів,
--   рядок «Рівень 80 <спек> <клас>» у вікні персонажа, книга професій (назва професії, ранг, кнопки-закляття),
--   спливне «Вивчено рецепт» (назва за spellID рецепта).
-- Тултіпи талантів і заклять перекладає Surfaces/Tooltip.lua (TooltipDataProcessor).
local U = UWOW
local K

-- ── книга заклять ──────────────────────────────────────────────────────────────────────────────────────
local function bookItem(self)
    local info = self.spellBookItemInfo
    if type(info) ~= "table" then return end
    local id = info.spellID
    if self.Name then
        if id and not K.secret(id) then K.byID(self.Name, "spell", id, "name", "spellbook")
        else K.label(self.Name, "spellbook", "ui", 60) end
    end
    if self.SubName then K.label(self.SubName, "spellbook-sub", "ui", 40) end
    if self.RequiredLevel then K.label(self.RequiredLevel, "spellbook-level", "ui", 60) end
end

local function bookHeaders()
    local sb = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.SpellBookFrame
    local paged = sb and sb.PagedSpellsFrame
    if not (paged and paged.EnumerateFrames) then return end
    for _, f in paged:EnumerateFrames() do
        if type(f) == "table" and f.spellBookItemInfo == nil and f.Text then K.label(f.Text, "spellbook-header", "ui", 60) end
    end
end

-- ── спеціалізації ──────────────────────────────────────────────────────────────────────────────────────
local function specContent(f)
    if f.SpecName then K.label(f.SpecName, "spec-name", "ui", 40) end
    if f.RoleName then K.label(f.RoleName, "spec-role", "ui", 40) end
    local fs = f.Description
    local en = K.text(fs)
    if not en or K.cyr(en) then return end
    local desc, stat = en:match("^(.-)|n(.*)$")
    desc = desc or en
    local d = K.str(desc, "ui")
    if not d then U.Miss("ui", "spec-desc", desc); return end
    local s = ""
    if stat and stat ~= "" then
        local fmt = rawget(_G, "SPEC_FRAME_PRIMARY_STAT")
        local p = fmt and K.fmtPattern(fmt)
        local name = p and stat:match(p)
        s = "|n" .. (name and K.fmt(fmt, K.str(name, "ui") or name) or K.str(stat, "ui") or stat)
    end
    K.set(fs, d .. s, en)
end

local function specAll(sf)
    local pool = sf and sf.SpecContentFramePool
    if not (pool and pool.EnumerateActive) then return end
    for f in pool:EnumerateActive() do specContent(f) end
end

-- назва героїчного дерева: гра ставить string.upper(назва), тож UA теж великими літерами
local function heroLabel(self)
    local info = self.activeSubTreeInfo
    local fs = self.HeroSpecLabel
    local en = K.text(fs)
    if not en or K.cyr(en) or type(info) ~= "table" or type(info.name) ~= "string" then return end
    local ua = K.str(info.name, "ui")
    if ua then K.set(fs, K.upper(ua), en) else U.Miss("ui", "hero-talents", info.name) end
end

-- ── рядок рівня у вікні персонажа ──────────────────────────────────────────────────────────────────────
-- PLAYER_LEVEL = "Level %s |c%s%s %s|r" (рівень, колір класу, спек, клас). Формат — з даних (якщо є), спек — з
-- даних, клас — наш (People.lua, за статтю гравця).
local function capFirst(s)
    if not s or s == "" then return s end
    local b = s:byte(1)
    if b == 208 or b == 209 or b == 210 then return K.upper(s:sub(1, 2)) .. s:sub(3) end
    return s:sub(1, 1):upper() .. s:sub(2)
end

local function levelText()
    local fs = _G.CharacterLevelText
    local en = K.text(fs)
    if not en or K.cyr(en) then return end
    local fmt = rawget(_G, "PLAYER_LEVEL")
    local fmt2 = rawget(_G, "PLAYER_LEVEL_NO_SPEC")
    local level = en:match("(%d+)")
    local color = en:match("|c(%x%x%x%x%x%x%x%x)") or en:match("|c(n[%w_]+:)")
    local cls = capFirst(U.ClassName and U.ClassName() or "")
    if not level or cls == "" then return end
    local specName
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    if spec then
        local ok, _, name = pcall(C_SpecializationInfo.GetSpecializationInfo, spec, false, false, nil, UnitSex and UnitSex("player"))
        specName = ok and name or nil
    end
    local ua
    if specName and specName ~= "" then
        local su = K.str(specName, "ui")
        if not su then U.Miss("ui", "character-level", specName); return end
        ua = K.fmt(fmt, level, color or "ffffffff", su, cls)
    else
        ua = K.fmt(fmt2, level, color or "ffffffff", cls)
    end
    if ua then K.set(fs, ua, en) else U.Miss("ui", "character-level", specName and fmt or fmt2) end
end

-- ── книга професій ─────────────────────────────────────────────────────────────────────────────────────
local function profButton(self)
    local parent = self.GetParent and self:GetParent()
    if not (parent and parent.professionInitialized and self.GetID and C_SpellBook) then return end
    local idx = self:GetID() + (parent.spellOffset or 0)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, idx, bank)
    local id = ok and type(info) == "table" and info.spellID
    if id and self.spellString then K.byID(self.spellString, "spell", id, "name", "professions-book") end
    if self.subSpellString then K.label(self.subSpellString, nil, "ui") end
end

local function profFrame(frame)
    if type(frame) ~= "table" then return end
    for _, k in ipairs({ "professionName", "rank", "specialization" }) do
        if frame[k] then K.label(frame[k], "professions-book", "ui", 60) end
    end
    for _, k in ipairs({ "SpellButton1", "SpellButton2" }) do
        local b = frame[k]
        if b then
            K.hook(b, "UpdateButton", profButton, "professions-book-button")
            profButton(b)
        end
    end
end

U.Surface("spellbook", function()
    K = U.CharKit
    K.onAddon("Blizzard_PlayerSpells", function()
        K.hook(SpellBookItemMixin, "UpdateVisuals", bookItem, "spellbook")
        K.hook(SpellBookItemMixin, "UpdateSubName", function(self)
            if self.SubName then K.label(self.SubName, "spellbook-sub", "ui", 40) end
        end, "spellbook-sub")
        if EventRegistry and EventRegistry.RegisterCallback then
            EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged",
                K.guard("spellbook-header", bookHeaders), K)
        end
        local psf = _G.PlayerSpellsFrame
        local sf = psf and psf.SpecFrame
        if sf then
            K.hook(sf, "UpdateSpecContents", specAll, "spec")
            K.hook(sf, "UpdateSpecFrame", specAll, "spec")
            if U.Enabled() then pcall(specAll, sf) end
        end
        K.hook(ClassSpecContentFrameMixin, "Setup", specContent, "spec")      -- кадри, створені після завантаження
        local hero = psf and psf.TalentsFrame and psf.TalentsFrame.HeroTalentsContainer
        K.hook(hero, "UpdateHeroSpecButton", heroLabel, "hero-talents")
        K.hook(HeroTalentsContainerMixin, "UpdateHeroSpecButton", heroLabel, "hero-talents")
    end)
end)

U.Surface("character-level", function()
    K = U.CharKit
    K.hookG("PaperDollFrame_SetLevel", levelText)
end)

U.Surface("professions-book", function()
    K = U.CharKit
    K.onAddon("Blizzard_ProfessionsBook", function()
        K.hookG("FormatProfession", profFrame)
    end)
end)

U.Surface("recipe-toast", function()
    K = U.CharKit
    -- черга сповіщень тримає посилання на функцію, тож хук — на поле підсистеми, а не на глобальну функцію
    local sys = rawget(_G, "NewRecipeLearnedAlertSystem")
    K.hook(sys, "setUpFunction", function(frame, recipeID)
        local fs = frame and frame.Name
        local en = K.text(fs)
        if not en or K.cyr(en) or not recipeID or K.secret(recipeID) then return end
        local ua = U.ID("spell", recipeID, "name")
        if not ua then U.Miss("spell", "recipe-toast", en, recipeID); return end
        local tail = en:match("(%s*|T.*)$") or ""                       -- іконка рангу рецепта
        K.set(fs, ua .. tail, en)
    end, "recipe-toast")
end)

-- ── рядки, які Blizzard дописує в GameTooltip кодом (AddLine/SetText), а не даними ──────────────────────
-- Тултіп таланту (інструкції «Click to learn», вимоги, «Next Rank:»), тултіпи статів у вікні персонажа
-- («Critical Strike: 861 [+18.72%]», пояснення), вузли GenericTraitFrame. Перекладаємо рядок одразу після
-- AddLine — до tooltip:Show(), який Blizzard кличе в кінці, тож розмір тултіпа рахується вже з перекладом.
-- Власник тултіпа визначає контекст; чужі тултіпи (предмети, NPC, аддони) не чіпаємо.
local function under(f, target, depth)
    for _ = 1, depth do
        if f == target then return true end
        if type(f) ~= "table" or not f.GetParent then return false end
        f = f:GetParent()
    end
    return f == target
end

local function context(tt)
    local ok, ctx = pcall(function()
        local owner = tt.GetOwner and tt:GetOwner()
        if type(owner) ~= "table" or (owner.IsForbidden and owner:IsForbidden()) then return nil end
        if type(owner.GetTalentFrame) == "function" then return "talent" end
        local sp = _G.CharacterStatsPane
        if sp and sp.IsShown and sp:IsShown() and under(owner, sp, 5) then return "stats" end
        local gt = _G.GenericTraitFrame
        if gt and gt.IsShown and gt:IsShown() and under(owner, gt, 8) then return "trait" end
    end)
    return ok and ctx or nil
end

local function tipLine(tt, i, ctx, title)
    local name = tt.GetName and tt:GetName()
    if not name then return end
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
        local fs = _G[name .. side .. i]
        local en = K.text(fs)
        if en and not K.cyr(en) and en:find("%a") then
            local ua = K.str(en, "ui")
            if ua then K.set(fs, ua, en)
            -- промах: назва таланту — це закляття (не ui); довгі рядки таланту — опис із даних (sdesc)
            elseif not title and #en <= (ctx == "talent" and 40 or 80) then U.Miss("ui", "tooltip-" .. ctx, en) end
        end
    end
end

U.Surface("tooltip-lines", function()
    K = U.CharKit
    local tt = _G.GameTooltip
    if not tt then return end
    local function added(self)
        local ctx = context(self)
        if ctx then tipLine(self, self:NumLines(), ctx) end
    end
    K.hook(tt, "AddLine", added, "tooltip-lines")
    K.hook(tt, "AddDoubleLine", added, "tooltip-lines")
    K.hook(tt, "SetText", function(self)
        local ctx = context(self)
        if ctx then tipLine(self, 1, ctx, ctx == "talent") end
    end, "tooltip-lines")
    -- заголовок рамки GenericTraitFrame (дерева на кшталт «Благословень лоа»)
    K.onAddon("Blizzard_GenericTraitUI", function()
        K.hook(_G.GenericTraitFrame, "ApplyLayout", function(self)
            local h = self.Header and self.Header.Title
            if h then K.label(h, "generic-trait", "ui", 60) end
        end, "generic-trait")
    end)
end)
