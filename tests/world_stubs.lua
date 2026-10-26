-- tests/world_stubs.lua — заглушки фреймів і API Blizzard для поверхонь світу (агент world): вікно квесту, журнал,
-- трекер, мапа, субтитри, книги, пошта, PlayerChoice, чат. Викликається з harness.install (до завантаження аддона),
-- бо поверхні ставлять хуки на PLAYER_LOGIN. Розміри написів імітуються: висота = рядки по 40 символів × 12.
return function(H)
    local W = {}
    H.W = W

    local function noop() end

    -- ── напис і фрейм ────────────────────────────────────────────────────────────────────────────────────
    local FS = {}
    FS.__index = FS
    function FS:SetText(t) self.text = t end
    function FS:GetText() return self.text end
    function FS:SetFormattedText(f, ...) self.text = f:format(...) end
    function FS:GetStringHeight()
        local n = math.max(1, math.ceil(#(self.text or "") * (self.scale or 1) / 40))
        if self.maxLines and self.maxLines > 0 then n = math.min(n, self.maxLines) end
        return n * 12
    end
    FS.GetHeight = FS.GetStringHeight
    function FS:GetStringWidth() return #(self.text or "") * 6 end
    function FS:SetTextScale(s) self.scale = s end
    function FS:SetMaxLines(n) self.maxLines = n end
    function FS:GetLineHeight() return 12 end
    function FS:GetNumLines() return math.ceil(self:GetStringHeight() / 12) end
    function FS:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
    function FS:SetFont(p) self.font = p; return true end
    function FS:IsShown() return self.shown ~= false end
    function FS:Show() self.shown = true end
    function FS:Hide() self.shown = false end
    function FS:GetObjectType() return "FontString" end
    FS.SetWidth, FS.SetHeight, FS.SetTextColor, FS.SetVertexColor, FS.SetPoint = noop, noop, noop, noop, noop
    function H.wfs(t) return setmetatable({ text = t }, FS) end

    local FR = {}
    FR.__index = FR
    function FR:IsShown() return self.shown ~= false end
    function FR:Show() self.shown = true end
    function FR:Hide() self.shown = false end
    function FR:GetID() return self.id end
    function FR:SetID(i) self.id = i end
    function FR:GetFontString() return self.fsObj end
    function FR:GetRegions() return unpack(self.regions or {}) end
    function FR:GetChildren() return unpack(self.children or {}) end
    function FR:HookScript(w, f) self["_hs" .. w] = f end
    function FR:GetTextHeight() return self.fsObj and self.fsObj:GetStringHeight() or 12 end
    function FR:GetHeight() return 12 end
    FR.SetHeight, FR.SetSize, FR.SetWidth, FR.Layout = noop, noop, noop, noop
    function H.wframe(t) return setmetatable(t or {}, FR) end

    local function pool(list)
        return { list = list, EnumerateActive = function(self)
            local i = 0
            return function() i = i + 1; return self.list[i] end
        end }
    end
    H.pool = pool

    -- ── глобальні рядки інтерфейсу ────────────────────────────────────────────────────────────────────────
    ERR_QUEST_ACCEPTED_S = "Quest accepted: %s"
    ERR_QUEST_COMPLETE_S = "%s completed."
    ERR_ZONE_EXPLORED = "Discovered: %s"
    SUBTITLE_FORMAT = "%s: %s"
    QUEST_STORY_STATUS = "Story Progress: %d/%d Chapters"
    ITEM_TEXT_FROM = "From:"
    MAX_REQUIRED_ITEMS = 6

    -- ── квести ────────────────────────────────────────────────────────────────────────────────────────────
    W.q = { id = 12470, en = "EN TITLE" }
    GetQuestID = function() return W.q.id end
    GetTitleText = function() return W.q.en end
    C_QuestLog = {
        GetSelectedQuest = function() return W.q.id end,
        GetTitleForQuestID = function(id) return W.q.titles and W.q.titles[id] or W.q.en end,
        IsComplete = function() return false end,
        GetNumQuestLogEntries = function() return 1 end,
        GetInfo = function() return { title = W.q.en, questID = W.q.id } end,
    }
    GetQuestItemInfo = function() return "Some Item", nil, 1, 1, true, 6948 end
    GetQuestLogRewardInfo = function() return "Some Item", nil, 1, 1, true, 6948 end
    GetQuestLogChoiceInfo = GetQuestLogRewardInfo

    QuestInfoTitleHeader, QuestInfoDescriptionText = H.wfs(), H.wfs()
    QuestInfoObjectivesText, QuestInfoRewardText = H.wfs(), H.wfs()
    QuestInfoDescriptionHeader, QuestInfoObjectivesHeader = H.wfs("Description"), H.wfs("Quest Objectives")
    W.objLine = H.wfs()
    QuestInfoObjectivesFrame = H.wframe({ Objectives = { W.objLine } })
    W.rewardBtn = H.wframe({ Name = H.wfs("Hearthstone"), objectType = "item", type = "reward", id = 1 })
    QuestInfoRewardsFrame = H.wframe({ Header = H.wfs("Rewards"), ItemChooseText = H.wfs("Choose your reward:"),
                                     ItemReceiveText = H.wfs("You will receive:"), RewardButtons = { W.rewardBtn } })
    QuestInfoFrame = { questLog = false, rewardsFrame = QuestInfoRewardsFrame }
    QuestInfo_ShowRewards = noop
    QuestProgressTitleText, QuestProgressText = H.wfs(), H.wfs()
    QuestFrameProgressItems_Update = noop
    QuestFrame_ShowQuestPortrait = noop
    QuestNPCModelText, QuestNPCModelNameText = H.wfs(), H.wfs()
    GreetingText = H.wfs()
    QuestFrameAcceptButton = H.wframe({ fsObj = H.wfs("Accept") })
    QuestFrameDeclineButton = H.wframe({ fsObj = H.wfs("Decline") })

    -- журнал квестів на мапі
    W.logTitle = H.wframe({ Text = H.wfs(), questID = 12470 })
    W.logObj = H.wframe({ Text = H.wfs(), questID = 12470 })
    W.logHeader = H.wframe({ ButtonText = H.wfs() })
    QuestScrollFrame = { titleFramePool = pool({ W.logTitle }), objectiveFramePool = pool({ W.logObj }),
                         headerFramePool = pool({ W.logHeader }), campaignHeaderFramePool = pool({}),
                         campaignHeaderMinimalFramePool = pool({}), Contents = {} }
    QuestLogQuests_Update = noop

    -- трекер цілей: модуль із GetBlock, блок із SetHeader/AddObjective як у ObjectiveTrackerBlockMixin
    local function newBlock()
        local b = { HeaderText = H.wfs(), usedLines = {} }
        function b:SetHeader(text) self.HeaderText:SetText(text) end
        function b:AddObjective(key, text)
            local line = self.usedLines[key] or { Text = H.wfs() }
            self.usedLines[key] = line
            line.Text:SetText(text)
            return line
        end
        return b
    end
    -- автопопап (AutoQuestPopupBlockMixin:Update ставить TopText/BottomText/QuestName)
    local function newPopup()
        local b = newBlock()
        b.Contents = { TopText = H.wfs(), BottomText = H.wfs(), QuestName = H.wfs() }
        function b:Update(questTitle, questID, popUpType)
            self.questID = questID
            self.Contents.TopText:SetText(popUpType == "COMPLETE" and "Quest Complete!" or "Quest Discovered!")
            self.Contents.BottomText:SetText("Click to view quest")
            self.Contents.QuestName:SetText(questTitle)
        end
        return b
    end
    QuestObjectiveTracker = { blockTemplate = "T", usedBlocks = {}, Header = { Text = H.wfs("Quests") } }
    function QuestObjectiveTracker:GetBlock(id, tmpl)
        local t = self.usedBlocks[tmpl or self.blockTemplate] or {}
        self.usedBlocks[tmpl or self.blockTemplate] = t
        local b = t[id] or (tmpl == "AutoQuestPopUpBlockTemplate" and newPopup() or newBlock())
        b.id, b.parentModule = id, self
        t[id] = b
        return b
    end
    function QuestObjectiveTracker:SetHeader(text) self.Header.Text:SetText(text) end
    ScenarioObjectiveTracker = { blockTemplate = "S", usedBlocks = {}, Header = { Text = H.wfs() },
                                 ObjectivesBlock = newBlock(), StageBlock = { Stage = H.wfs(), Name = H.wfs() } }
    ScenarioObjectiveTracker.GetBlock = QuestObjectiveTracker.GetBlock
    function ScenarioObjectiveTracker:LayoutContents() end
    function ScenarioObjectiveTracker.StageBlock:UpdateStageBlock() end

    -- тости (AlertFrame — з harness)
    ObjectiveTrackerTopBannerFrame = { Title = H.wfs(), Subtitle = H.wfs("World Quest"), PlayBanner = function() end }

    -- ── мапа ──────────────────────────────────────────────────────────────────────────────────────────────
    -- тултіп пінів — спільний GameTooltip із harness (рядки GameTooltipTextLeftN)
    W.areaLabel = { Name = H.wfs(), Description = H.wfs() }
    function W.areaLabel:EvaluateLabels() end
    WorldMapFrame = { dataProviders = { [{ Label = W.areaLabel }] = true } }

    -- ── субтитри, говоряча голова, кінематики ─────────────────────────────────────────────────────────────
    SubtitlesFrame = { Subtitles = { H.wfs(), H.wfs() } }
    function SubtitlesFrame:AddSubtitle(body) self.Subtitles[1]:SetText(body) end
    TalkingHeadFrame = { TextFrame = { Text = H.wfs() }, NameFrame = { Name = H.wfs() } }
    W.th = {}
    C_TalkingHead = { GetCurrentLineInfo = function() return 1, 1, 1, 1, 1, 1, W.th.name, W.th.text end }
    CinematicFrameCloseDialogText = H.wfs("Are you sure you want to skip this cinematic?")

    -- ── книги ─────────────────────────────────────────────────────────────────────────────────────────────
    ItemTextPageText = { SetText = function(self, t) self.text = t end }
    ItemTextGetText = function() return W.book end
    ItemTextGetPage = function() return 1 end

    -- ── PlayerChoice (LoD) ────────────────────────────────────────────────────────────────────────────────
    W.choiceOpt = H.wframe({ Header = { Contents = { Text = H.wfs() } }, OptionText = { SetText = function(self, t) self.text = t end },
                            optionInfo = {} })
    W.choice = { Title = { Text = H.wfs() }, optionPools = pool({ W.choiceOpt }) }
    function W.choice:TryShow()
        local ci = self.choiceInfo
        self.Title.Text:SetText(ci.questionText)
        W.choiceOpt.optionInfo = ci.options[1]
        W.choiceOpt.Header.Contents.Text:SetText(ci.options[1].header)
        W.choiceOpt.OptionText:SetText(ci.options[1].description)
    end

    -- ── бабли (C_ChatBubbles) ───────────────────────────────────────────────────────────────────────────────
    W.bubble = H.wframe({ children = { { String = H.wfs() } } })
    C_ChatBubbles = { GetAllChatBubbles = function(includeForbidden)
        W.bubbleArg = includeForbidden
        return W.bubbleHidden and {} or { W.bubble }
    end }
    IsInInstance = function() return W.inInstance or false end

    -- ── DialogueUI (сторонній аддон): API перекладача, міксин кнопки, головне вікно з пулом абзаців ─────────
    DialogueUIAPI = { SetTranslator = function(t) W.duiTranslator = t end }
    DUIDialogOptionButtonMixin = {}
    function DUIDialogOptionButtonMixin:SetButtonText(name) self.Name:SetText(name) end
    function DUIDialogOptionButtonMixin:SetGossip(data) self:SetButtonText("1. " .. data.name) end
    function DUIDialogOptionButtonMixin:SetQuest(info) self:SetButtonText(info.title) end
    DUIQuestFrame = { fontStringPool = { objects = {} } }
    function DUIQuestFrame:AcquireLeftFontString()
        local fs = H.wfs()
        table.insert(self.fontStringPool.objects, fs)
        return fs
    end
    function DUIQuestFrame:FormatParagraph(text)                  -- як у DialogueUI.lua: абзац за абзацом
        local out = {}
        for v in text:gmatch("[%C]+") do
            if v ~= " " then local fs = self:AcquireLeftFontString(); fs:SetText(v); out[#out + 1] = fs end
        end
        return out
    end
    C_GossipInfo = C_GossipInfo or {}
    C_GossipInfo.GetText = function() return W.gossipText end

    -- ── тултіпи: TooltipDataProcessor і GameTooltip — у harness ──────────────────────────────────────────
    UnitGUID = function() return "Creature-0-0-0-0-1234-0" end
    C_Item = C_Item or {}
    C_Item.GetItemInfoInstant = function() return nil end
end
