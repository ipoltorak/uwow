-- Uwow · Surfaces/CharLooks.lua — вигляд персонажа:
--   вікно трансмогрифікатора (назви ситуацій образу),
--   перукарня й кастомізація (назви опцій, варіантів, прапорців),
--   Торговий пост (назви товарів за itemID, категорія, опис).
local U = UWOW
local K

-- ── вікно трансмогрифікатора (Blizzard_Transmog) ─────────────────────────────────────────────────────
-- Вкладку «Колекції → Набори» веде агент coll; тут — лише вікно в NPC: назви ситуацій образу.
-- Тултіп набору в цьому вікні будується через GameTooltip:SetText уже після показу — без tooltip:Show()
-- його не перекласти коректно за розміром, тому не чіпаємо.
U.Surface("transmogrifier", function()
    K = U.CharKit
    K.onAddon("Blizzard_Transmog", function()
        K.hook(TransmogSituationMixin, "Init", function(self)
            if self.Title then K.label(self.Title, "transmog-situation", "ui", 60) end
        end, "transmog-situation")
    end)
end)

-- ── перукарня / кастомізація ───────────────────────────────────────────────────────────────────────────
-- Рамки кастомізації Blizzard свідомо не захищає від taint (коментар у SetupOption), але ми все одно лише
-- міняємо текст написів і нічого не пишемо в їхні таблиці.
local function custom(fs, surf)
    if fs then K.label(fs, surf, "ui", 60) end
end

U.Surface("barber", function()
    K = U.CharKit
    K.onAddon("Blizzard_CustomizationUI", function()
        K.hook(CustomizationDropdownWithSteppersAndLabelMixin, "SetupOption", function(self) custom(self.Label, "barber-option") end, "barber-option")
        K.hook(CustomizationOptionCheckButtonMixin, "SetupOption", function(self) custom(self.Label, "barber-option") end, "barber-check")
        K.hook(CustomizationOptionSliderMixin, "SetupOption", function(self) custom(self.Label or (self.Slider and self.Slider.Label), "barber-option") end, "barber-slider")
        K.hook(CustomizationElementDetailsMixin, "UpdateText", function(self) custom(self.SelectionName, "barber-choice") end, "barber-choice")
    end)
    K.onAddon("Blizzard_CharacterCustomize", function()
        K.hook(CharCustomizeAlteredFormDropdownItemMixin, "Init", function(self) custom(self.Text, "barber-form") end, "barber-form")
    end)
end)

-- ── Торговий пост ──────────────────────────────────────────────────────────────────────────────────────
local function perksName(fs, itemID, surf)
    local en = K.text(fs)
    if not en or K.cyr(en) then return end
    local id = tonumber(itemID)
    local ua = (id and id > 0 and U.ID("item", id, "name")) or K.str(en, { "collections", "ui" })
    if ua then K.set(fs, ua, en) else U.Miss(id and id > 0 and "item" or "collections", surf, en, id) end
end

local function perksDetails(self)
    local data = self.data
    if type(data) ~= "table" then return end
    perksName(self.ProductNameText, data.itemID, "perks-details")
    if self.CategoryText then K.label(self.CategoryText, "perks-category", "ui", 60) end
    local fs = self.DescriptionText
    local en = K.text(fs)
    if en and not K.cyr(en) then
        local ua = K.str(en, { "ui", "collections" })
        if ua then K.set(fs, ua, en) else U.Miss("ui", "perks-desc", en, data.itemID) end
    end
end

local function hookDetails(d)
    K.hook(d, "Refresh", perksDetails, "perks-details")
    K.hook(d, "UpdateDetails", function(self, data)
        if type(data) == "table" then perksName(self.ProductNameText, data.itemID, "perks-details") end
    end, "perks-toy")
end

U.Surface("perks-program", function()
    K = U.CharKit
    K.onAddon("Blizzard_PerksProgram", function()
        K.hook(PerksProgramProductButtonMixin, "SetItemInfo", function(self)
            local info = self.itemInfo
            local c = self.ContentsContainer
            if type(info) == "table" and c then perksName(c.Label, info.itemID, "perks-product") end
        end, "perks-product")
        hookDetails(PerksProgramProductDetailsFrameMixin)
        hookDetails(PerksProgramToyDetailsFrameMixin)
        local pf = _G.PerksProgramFrame and _G.PerksProgramFrame.ProductsFrame
        if pf and pf.GetChildren then
            for _, c in ipairs({ pf:GetChildren() }) do
                if type(c) == "table" and type(c.DetailsFrame) == "table" then hookDetails(c.DetailsFrame) end
            end
        end
    end)
end)
