-- Uwow · Surfaces/CollCollections.lua — вікно «Колекції»: маунти (список, картка: назва, джерело, лор),
-- вихованці (список, картка, підказка картки з джерелом і описом), здібності вихованців (спільна підказка
-- журналу й бою), бої вихованців (імена на рамках), скриня іграшок (назви + підказка іграшки),
-- вкладка «Набори» гардеробу (назви сетів, групи/складність, панель деталей).
-- Дані: «mount» (mountID: n, d), «pet» (speciesID: n, d), «item» (itemID іграшки: name), «collections»
-- (текстовий: джерела, описи за EN, здібності вихованців, назви сетів і груп), «ui» (мітки).
-- Межа з агентом char: вікно трансмогрифікатора (Blizzard_Transmog) — його; вкладка «Колекції → Набори» — тут.
local U = UWOW
local K = U.CollKit

local function C(text) return K.Any(text, "collections", "ui") end

-- ── маунти ─────────────────────────────────────────────────────────────────────────────────────────────
local function mountName(id) return function(t) return U.ID("mount", id, "n") or (U.Miss("mount", "mount-journal", t, id)) end end

local function installMounts()
    if MountJournal_InitMountButton then
        hooksecurefunc("MountJournal_InitMountButton", function(button, elementData)
            if not U.Enabled() or not button or type(elementData) ~= "table" then return end
            local id = select(12, C_MountJournal.GetDisplayedMountInfo(elementData.index))
            if id and button.name then K.FollowNow(button.name, mountName(id)) end
        end)
    end
    if MountJournal_UpdateMountDisplay then
        hooksecurefunc("MountJournal_UpdateMountDisplay", function()
            local mj = MountJournal
            if not U.Enabled() or not mj or not mj.selectedMountID then return end
            local id = mj.selectedMountID
            local ib = mj.MountDisplay and mj.MountDisplay.InfoButton
            if not ib then return end
            K.FollowNow(ib.Name, mountName(id))
            K.FollowNow(ib.Lore, function(t) return U.ID("mount", id, "d") or C(t) or (U.Miss("mount", "mount-lore", t, id)) end)
            K.FollowNow(ib.Source, function(t) return K.Source(t) or (U.Miss("collections", "mount-source", t, id)) end)
        end)
    end
end

-- ── вихованці ──────────────────────────────────────────────────────────────────────────────────────────
local function petName(sid) return function(t) return U.ID("pet", sid, "n") or (U.Miss("pet", "pet-journal", t, sid)) end end

local function cardSpecies()
    local card = PetJournalPetCard
    if not card then return nil end
    if card.petID and C_PetJournal then return (C_PetJournal.GetPetInfoByPetID(card.petID)) end
    return card.speciesID
end

local function installPets()
    if PetJournal_InitPetButton then
        hooksecurefunc("PetJournal_InitPetButton", function(pet, elementData)
            if not U.Enabled() or type(elementData) ~= "table" or not C_PetJournal then return end
            local _, sid, _, custom = C_PetJournal.GetPetInfoByIndex(elementData.index)
            if not sid then return end
            local fs = custom and pet.subName or pet.name    -- власне ім'я гравця не чіпаємо
            if fs then K.FollowNow(fs, petName(sid)) end
        end)
    end
    if PetJournal_UpdatePetCard then
        hooksecurefunc("PetJournal_UpdatePetCard", function(card)
            if not U.Enabled() or not card or not card.PetInfo then return end
            local sid = cardSpecies()
            if not sid then
                local en = K.Text(card.PetInfo.name)
                if en then K.Put(card.PetInfo.name, en, K.Any(en, "ui")) end      -- «Вибери вихованця»
                return
            end
            local custom = card.petID and select(2, C_PetJournal.GetPetInfoByPetID(card.petID))
            local fs = custom and card.PetInfo.subName or card.PetInfo.name
            if fs then K.FollowNow(fs, petName(sid)) end
        end)
    end
    -- підказка картки: назва виду, джерело, «опис у лапках» (тексти лежать у полях кнопки; міняємо рядки підказки)
    local info = PetJournalPetCard and PetJournalPetCard.PetInfo
    if info and info.HookScript then
        info:HookScript("OnEnter", function(self)
            if not U.Enabled() or not GameTooltip:IsOwned(self) then return end
            local sid = cardSpecies()
            if not sid then return end
            local changed = false
            for i = 1, GameTooltip:NumLines() do
                local fs = K.TipLine(GameTooltip, i)
                local en = K.Text(fs)
                if en and not K.Cyr(en) then
                    local ua
                    if i == 1 then ua = U.ID("pet", sid, "n")
                    elseif en == self.sourceText then ua = K.Source(en, "collections", "ui", "names")
                    elseif en == self.description then
                        local d = U.ID("pet", sid, "d") or C(en:match('^"(.*)"$') or en)
                        ua = d and ('"' .. d .. '"')
                    else ua = K.Any(en, "ui") end
                    if ua then U.Apply(fs, ua, en); changed = true end
                end
            end
            if changed then GameTooltip:Show() end
        end)
    end
end

-- Підказка здібності вихованця (журнал і бій): назва, опис.
local function abilityTooltip(tip)
    if not U.Enabled() or not tip then return end
    if tip.Name then K.FollowNow(tip.Name, function(t) return C(t) or (U.Miss("collections", "pet-ability", t)) end) end
    if tip.Description then K.FollowNow(tip.Description, function(t) return C(t) or (U.Miss("collections", "pet-ability-desc", t)) end) end
    for _, k in ipairs({ "StrongAgainstLabel", "WeakAgainstLabel", "AdditionalText" }) do
        if tip[k] then K.FollowNow(tip[k], function(t) return K.Any(t, "ui") end) end
    end
end

U.Surface("pet-abilities", function()
    if not SharedPetBattleAbilityTooltip_SetAbility then return end
    hooksecurefunc("SharedPetBattleAbilityTooltip_SetAbility", function(tip) abilityTooltip(tip) end)
end)

-- Бій вихованців: ім'я на рамці (якщо не власне ім'я гравця) і підказка юніта.
local function battleName(fs, owner, index)
    if not fs or not owner or not index or not C_PetBattles then return end
    local name, species = C_PetBattles.GetName(owner, index)
    name, species = K.Str(name), K.Str(species)
    if not name or (species and name ~= species) then return end
    local sid = C_PetBattles.GetPetSpeciesID and C_PetBattles.GetPetSpeciesID(owner, index)
    if sid then K.FollowNow(fs, petName(sid)) end
end

U.Surface("pet-battle", function()
    K.OnAddon("Blizzard_PetBattleUI", function()
        if PetBattleUnitFrame_UpdateDisplay then
            hooksecurefunc("PetBattleUnitFrame_UpdateDisplay", function(self)
                if U.Enabled() and self then battleName(self.Name, self.petOwner, self.petIndex) end
            end)
        end
        if PetBattleUnitTooltip_UpdateForUnit then
            hooksecurefunc("PetBattleUnitTooltip_UpdateForUnit", function(self, owner, index)
                if U.Enabled() and self then battleName(self.Name, owner, index) end
            end)
        end
    end)
end)

-- ── іграшки ────────────────────────────────────────────────────────────────────────────────────────────
local function installToys()
    if ToySpellButton_UpdateButton then
        hooksecurefunc("ToySpellButton_UpdateButton", function(self)
            if not U.Enabled() or not self or not self.itemID or self.itemID == -1 or not self.name then return end
            local id = self.itemID
            K.FollowNow(self.name, function(t) return U.ID("item", id, "name") or (U.Miss("item", "toybox", t, id)) end)
        end)
    end
end

U.Surface("toy-tooltip", function()
    local T = Enum and Enum.TooltipDataType
    if not (TooltipDataProcessor and T and T.Toy) then return end
    TooltipDataProcessor.AddTooltipPostCall(T.Toy, function(tt, data)
        if not U.Enabled() or not data then return end
        local ok, id = pcall(tonumber, data.id)
        if not ok or not id then return end
        local fs = K.TipLine(tt, 1)
        local en = K.Text(fs)
        if en then K.Put(fs, en, U.ID("item", id, "name"), "item", "tooltip-toy", id) end
        -- джерело («Vendor: …», «Achievement: …») і опис-флейвор (у лапках)
        local flavor = U.ID("item", id, "flavor")
        for i = 2, (tt.NumLines and tt:NumLines() or 0) do
            local l = K.TipLine(tt, i)
            local t = K.Text(l)
            if t and not K.Cyr(t) then
                local q = t:match('^"(.*)"$') or t:match('^|c%x%x%x%x%x%x%x%x"(.*)"|r$')
                if q and flavor then
                    U.Apply(l, (t:gsub('"(.*)"', function() return '"' .. flavor .. '"' end, 1)), t)
                else
                    local ua = K.Source(t, "collections", "ui")
                    if ua then U.Apply(l, ua, t) end
                end
            end
        end
    end)
end)

-- ── гардероб: вкладка «Набори» ─────────────────────────────────────────────────────────────────────────
local function setName(t) return C(t) or (U.Miss("collections", "transmog-set", t)) end

local function installSets()
    local wf = WardrobeCollectionFrame
    local sc = wf and wf.SetsCollectionFrame
    if not sc then return end
    K.OnScroll(sc.ListContainer and sc.ListContainer.ScrollBox, function(button)
        if button.Name then K.FollowNow(button.Name, setName) end
        if button.Label then K.FollowNow(button.Label, C) end
    end)
    if sc.DisplaySet then
        hooksecurefunc(sc, "DisplaySet", function(self)
            local d = self.DetailsFrame
            if not U.Enabled() or not d then return end
            K.FollowNow(d.Name, setName)
            K.FollowNow(d.LongName, setName)
            K.FollowNow(d.Label, C)
            -- довша українська назва: як і Blizzard, показуємо дворядкову, якщо коротка обрізана
            if d.Name and d.LongName and d.Name.IsTruncated and d.Name:IsShown() and d.Name:IsTruncated() then
                d.LongName:SetText(d.Name:GetText())
                d.Name:Hide(); d.LongName:Show()
            end
        end)
    end
end

U.Surface("collections", function()
    K.OnAddon("Blizzard_Collections", function()
        installMounts()
        installPets()
        installToys()
        installSets()
        local cj = CollectionsJournal
        if cj and cj.HookScript then
            local tabs = {}
            for i = 1, 8 do tabs[i] = "CollectionsJournalTab" .. i end
            cj:HookScript("OnShow", function() K.Tabs(tabs) end)
            if cj:IsShown() then K.Tabs(tabs) end
        end
    end)
end)
