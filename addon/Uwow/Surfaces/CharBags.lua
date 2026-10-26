-- Uwow · Surfaces/CharBags.lua — пошук у сумках і банку українською назвою предмета.
-- Рідний пошук Blizzard (EN-назва й тултіп) не чіпаємо: на кириличний запит він не знаходить нічого й тьмянить усі
-- комірки. Ми ж беремо itemID кожної показаної комірки, нашу назву предмета і, якщо в ній є запит, кладемо поверх
-- кнопки власну текстуру-підсвітку. Комірки, які Blizzard не притемнив (поза нашим запитом), притемнюємо своєю
-- текстурою. SetMatchesSearch і будь-яких методів захищених кнопок не викликаємо, геометрію кнопок не міняємо;
-- у бою нічого не створюємо й не показуємо — оновлення чекає PLAYER_REGEN_ENABLED.
local U = UWOW
local K

local query                                   -- нормалізований запит (лише з кирилицею) або nil
local marks = setmetatable({}, { __mode = "k" })  -- кнопка → { hi = текстура, dim = текстура }
local pending = false

local function norm(s)
    s = K.lower(s):gsub("\226\128\153", "'"):gsub("\202\188", "'"):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function setQuery(text)
    if type(text) ~= "string" or K.secret(text) then query = nil; return end
    local q = norm(text)
    query = (q ~= "" and K.cyr(q)) and q or nil
end

local function itemIDOf(b)
    local bag, slot
    if b.GetBankTabID and b.GetContainerSlotID then
        local ok, t, s = pcall(function() return b:GetBankTabID(), b:GetContainerSlotID() end)
        if ok then bag, slot = t, s end
    end
    if not bag and b.GetBagID and b.GetID then
        local ok, t, s = pcall(function() return b:GetBagID(), b:GetID() end)
        if ok then bag, slot = t, s end
    end
    if not bag or not slot or K.secret(bag) or K.secret(slot) or not C_Container then return nil end
    local ok, id = pcall(C_Container.GetContainerItemID, bag, slot)
    if ok and id and not K.secret(id) then return id end
end

local function texturesFor(b)
    local m = marks[b]
    if m then return m end
    if not b.CreateTexture then return nil end
    m = { hi = b:CreateTexture(nil, "OVERLAY", nil, 7), dim = b:CreateTexture(nil, "OVERLAY", nil, 6) }
    m.hi:SetAllPoints(b)
    m.hi:SetColorTexture(1, 0.82, 0.2, 0.4)
    if m.hi.SetBlendMode then m.hi:SetBlendMode("ADD") end
    m.dim:SetAllPoints(b)
    m.dim:SetColorTexture(0, 0, 0, 0.65)
    m.hi:Hide(); m.dim:Hide()
    marks[b] = m
    return m
end

local function paintButton(b)
    if type(b) ~= "table" or (b.IsForbidden and b:IsForbidden()) then return end
    local m = marks[b]
    if not query or not U.Enabled() then
        if m then m.hi:Hide(); m.dim:Hide() end
        return
    end
    local id = itemIDOf(b)
    if not id then
        if m then m.hi:Hide(); m.dim:Hide() end
        return
    end
    local ua = U.ID("item", id, "name")
    local hit = ua and norm(ua):find(query, 1, true) ~= nil
    m = m or texturesFor(b)
    if not m then return end
    m.hi:SetShown(hit)
    m.dim:SetShown(not hit and b.matchesSearch ~= false)      -- Blizzard уже притемнив — вдруге не темнимо
end

-- усі показані комірки: сумки (окремі й об'єднана) і банк
local function eachButton(fn)
    if type(ContainerFrameUtil_EnumerateContainerFrames) == "function" then
        local ok, it, st, c0 = pcall(ContainerFrameUtil_EnumerateContainerFrames)
        if ok and it then
            for _, frame in it, st, c0 do
                if type(frame) == "table" and frame.EnumerateValidItems and (not frame.IsShown or frame:IsShown()) then
                    for _, b in frame:EnumerateValidItems() do fn(b) end
                end
            end
        end
    end
    local bp = _G.BankPanel or (_G.BankFrame and _G.BankFrame.BankPanel)
    if type(bp) == "table" and bp.EnumerateValidItems and (not bp.IsShown or bp:IsShown()) then
        for b in bp:EnumerateValidItems() do fn(b) end
    end
end

local function paint()
    if InCombatLockdown and InCombatLockdown() then pending = true; return end
    pending = false
    eachButton(paintButton)
end

local function onText(box)
    local ok, t = pcall(box.GetText, box)
    if ok then setQuery(t) end
    paint()
end

U.Surface("bag-search", function()
    K = U.CharKit
    if C_Container and type(C_Container.SetItemSearch) == "function" then
        hooksecurefunc(C_Container, "SetItemSearch", function(text) setQuery(text); paint() end)
    end
    for _, n in ipairs({ "BagItemSearchBox", "BankItemSearchBox" }) do
        local box = _G[n]
        if box and box.HookScript then box:HookScript("OnTextChanged", function(self) pcall(onText, self) end) end
    end
    -- перемальовування комірок (відкриття сумки, зміна вмісту, вкладка банку) — після рідного оновлення
    local ok, it, st, c0 = pcall(ContainerFrameUtil_EnumerateContainerFrames or function() end)
    if ok and it then
        for _, frame in it, st, c0 do
            K.hook(frame, "UpdateSearchResults", paint, "bag-search")
            K.hook(frame, "Update", paint, "bag-search")
        end
    end
    local bp = _G.BankPanel or (_G.BankFrame and _G.BankFrame.BankPanel)
    K.hook(bp, "UpdateSearchResults", paint, "bag-search")
    K.hook(bp, "RefreshAllItemsForSelectedTab", paint, "bag-search")
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "INVENTORY_SEARCH_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED" }) do ev:RegisterEvent(e) end
    ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" and not pending then return end
        local okp, err = pcall(paint)
        if not okp then K.errors["bag-search"] = tostring(err) end
    end)
end)
