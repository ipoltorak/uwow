-- Uwow · Surfaces/CharProfessions.lua — вікно ремесла (Blizzard_Professions / Blizzard_ProfessionsTemplates):
--   список рецептів (назва — предмет, що виходить, або закляття-рецепт; категорії — рядки UI),
--   форма рецепта (назва результату, опис рецепта, назви реагентів).
local U = UWOW
local K

local function outputItemID(recipeID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData) then return nil end
    local ok, out = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
    if ok and type(out) == "table" and out.itemID and not K.secret(out.itemID) then return out.itemID end
    if C_TradeSkillUI.GetRecipeSchematic then
        local ok2, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        if ok2 and type(sch) == "table" and sch.outputItemID and not K.secret(sch.outputItemID) then return sch.outputItemID end
    end
end

-- назва рецепта: предмет-результат, інакше закляття-рецепт
local function recipeUA(recipeID)
    if type(recipeID) ~= "number" or K.secret(recipeID) then return nil end
    local item = outputItemID(recipeID)
    return (item and U.ID("item", item, "name")) or U.ID("spell", recipeID, "name")
end

local function recipeRow(self, node)
    local fs = self.Label
    local en = K.text(fs)
    if not en or K.cyr(en) then return end
    local data = node and node.GetData and node:GetData()
    local info = type(data) == "table" and data.recipeInfo
    local id = type(info) == "table" and info.recipeID
    local ua = recipeUA(id)
    if ua then K.set(fs, ua, en) else U.Miss("spell", "professions-recipe", en, id) end
end

local function schematicName(self)
    local tr = self.transaction
    local id = tr and tr.GetRecipeID and tr:GetRecipeID()
    local ua = recipeUA(id)
    for _, fs in ipairs({ self.OutputText, self.RecraftingOutputText }) do
        local en = K.text(fs)
        if en and not K.cyr(en) then
            if ua then
                local name = en:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local fmt = rawget(_G, "PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER")
                if fs == self.RecraftingOutputText and fmt then
                    local p = K.fmtPattern(fmt)
                    local full = p and name:match(p) and K.fmt(fmt, ua)
                    if full then K.set(fs, full, en) end
                else
                    K.set(fs, ua, en)                                   -- колір якості переносить K.wrap
                end
            else
                K.label(fs, nil, "ui")
            end
        end
    end
end

local function schematicDesc(self)
    local fs = self.Description
    local en = K.text(fs)
    if not en or K.cyr(en) then return end
    local info = self.currentRecipeInfo
    local id = type(info) == "table" and info.recipeID
    local ua = (id and U.SpellText.Render(id, en)) or K.str(en, "ui")
    if ua then K.set(fs, ua, en) else U.Miss("sdesc", "professions-desc", en, id) end
end

-- назва реагенту: «0/5 Назва» — назву шукаємо серед предметів цього слота
local function reagentSlot(self)
    local fs = self.Name
    local en = K.text(fs)
    if not en or K.cyr(en) then return end
    local sch = self.GetReagentSlotSchematic and self:GetReagentSlotSchematic()
    if type(sch) ~= "table" or type(sch.reagents) ~= "table" then return end
    local plain = en:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local count, name = plain:match("^(%s*[%d/]+%s+)(.+)$")
    name = name or plain
    for _, r in ipairs(sch.reagents) do
        local id = type(r) == "table" and r.itemID
        if id and not K.secret(id) then
            local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
            if n and n == name then
                local ua = U.ID("item", id, "name")
                if ua then
                    local c = en:match("^(|c%x%x%x%x%x%x%x%x)")
                    local out = (count or "") .. ua
                    K.set(fs, c and (c .. out .. "|r") or out, en)
                end
                return
            end
        end
    end
end

local function hookSchematic(t)
    K.hook(t, "UpdateOutputItem", schematicName, "professions-output")
    K.hook(t, "UpdateRecipeDescription", schematicDesc, "professions-desc")
end

U.Surface("professions", function()
    K = U.CharKit
    K.onAddon("Blizzard_ProfessionsTemplates", function()
        K.hook(ProfessionsRecipeListRecipeMixin, "Init", recipeRow, "professions-recipe")
        K.hook(ProfessionsRecipeListCategoryMixin, "Init", function(self)
            if self.Label then K.label(self.Label, "professions-category", "ui", 60) end
        end, "professions-category")
        hookSchematic(ProfessionsRecipeSchematicFormMixin)
        K.hook(ProfessionsReagentSlotMixin, "Update", reagentSlot, "professions-reagent")
    end)
    -- форми, створені до нашого хука на міксин (аддон уже був завантажений)
    K.onAddon("Blizzard_Professions", function()
        local pf = _G.ProfessionsFrame
        local cp = pf and pf.CraftingPage
        if cp and cp.SchematicForm then hookSchematic(cp.SchematicForm) end
    end)
end)
