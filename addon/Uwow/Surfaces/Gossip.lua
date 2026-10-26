-- Uwow · Surfaces/Gossip.lua — розмова з NPC: привітання (мовець — ім'я NPC), варіанти відповіді, назви квестів
-- у списку NPC (доступні й активні). ScrollBox міряє висоту елементів окремими «вимірювальними» кнопками й рамкою
-- привітання через ті самі методи Setup/SetText — тому переклад стоїть у них, і висота рахується вже з UA.
local U = UWOW
local K = U.WK

local function npcName()
    local n = UnitName and UnitName("npc")
    return type(n) == "string" and not K.secret(n) and n or nil
end

local function greetingUA(text)
    local who = npcName()
    local ua = K.T("dialog", text, who)
    if not ua then U.Miss("dialog", "gossip-greeting", text, nil, who) end
    return ua
end

U.Surface("gossip-options", function()
    if not GossipOptionButtonMixin then return end
    hooksecurefunc(GossipOptionButtonMixin, "Setup", function(btn, info)
        if not U.Enabled() or type(info) ~= "table" then return end
        local fs = btn.GetFontString and btn:GetFontString()
        local en, full = info.name, K.text(fs)
        if not full or type(en) ~= "string" or K.secret(en) then return end
        local ua = K.T("dialog", en)
        if ua then
            U.Apply(fs, K.Swap(full, en, ua) or ua, full)
            if btn.Resize then pcall(btn.Resize, btn) end
        else
            U.Miss("dialog", "gossip-option", en, info.gossipOptionID)
        end
    end)
end)

-- Назви квестів: Setup → UpdateTitleForQuest(SetFormattedText(NORMAL_QUEST_DISPLAY, title)) → Resize.
local function questButton(btn, info)
    if not U.Enabled() or type(info) ~= "table" then return end
    local fs = btn.GetFontString and btn:GetFontString()
    local full = K.text(fs)
    local ua = K.QuestTitle(info.questID)
    if not full then return end
    if not ua then U.Miss("quest", "gossip-quest", info.title or full, info.questID) return end
    U.Apply(fs, K.Swap(full, info.title, ua) or ua, full)
    if btn.Resize then pcall(btn.Resize, btn) end
end

U.Surface("gossip-quests", function()
    for _, m in ipairs({ _G.GossipAvailableQuestButtonMixin, _G.GossipActiveQuestButtonMixin,
                         _G.GossipSharedAvailableQuestButtonMixin, _G.GossipSharedActiveQuestButtonMixin }) do
        K.HookOnce(m, "Setup", questButton)
    end
end)

U.Surface("gossip-greeting", function()
    if not GossipGreetingTextMixin then return end
    hooksecurefunc(GossipGreetingTextMixin, "Setup", function(self, text)
        if not U.Enabled() or type(text) ~= "string" or K.secret(text) then return end
        local fs = self.GreetingText
        local en = K.text(fs)
        if not en then return end
        local ua = greetingUA(en)
        if ua then
            U.Apply(fs, ua, en)
            if not K.inCombat() then self:SetSize(270, fs:GetHeight()) end
        end
    end)
    -- Вимірювальна рамка привітання — пряма дитина GossipFrame, створюється в першому Update. Висоту рядка
    -- ScrollBox бере з її GreetingText:SetText(text):GetHeight(), тож хукаємо SetText саме цього напису.
    local gf = _G.GossipFrame
    if not gf then return end
    local function hookMeasure()
        for _, c in ipairs({ gf:GetChildren() }) do
            if c.GreetingText then K.HookText(c.GreetingText, function(_, t) return greetingUA(t) end) end
        end
    end
    hookMeasure()
    local first = true
    K.HookOnce(gf, "Update", function(self)
        if not first then return end
        first = false
        hookMeasure()
        -- перший показ уже виміряно англійським текстом — перемальовуємо один раз (поза боєм)
        if U.Enabled() and not K.inCombat() and self:IsShown() then pcall(self.Update, self) end
    end)
end)
