-- tests/surf_world.lua — поверхні світу (агент world): хуки стоять, і на реальних рядках зі збірки текст
-- у заглушках Blizzard справді стає українським. Викликається з run_tests.lua: dofile(...)(H, U, check).
return function(H, U, check)
    local W = H.W
    U.ShowOriginal(false)              -- міграція з v1 увімкнула «оригінал» до встановлення поверхонь
    local cyr = function(s) return type(s) == "string" and s:find("[\208\209]") ~= nil end

    -- 0. поверхні встановились без помилок
    do
        local names = { "quest-info", "quest-progress", "quest-greeting", "quest-portrait", "quest-buttons", "gossip-options",
                        "gossip-quests", "gossip-greeting", "chat-npc", "talking-head", "chat-system", "quest-log",
                        "objective-tracker", "map-pin-tooltips", "map-area-label", "subtitles", "cinematic-dialogs",
                        "boss-emotes", "quest-toasts", "chat-bubbles", "books", "mail", "player-choice", "npc-subname", "npc-names", "dialogueui" }
        H.chat = {}
        SlashCmdList.UWOW("stats")
        local seen, bad = {}, {}
        for _, m in ipairs(H.chat) do
            local n, st = m:match("^.-  ([%w%-]+): (.*)$")
            if n then seen[n] = st end
        end
        for _, n in ipairs(names) do
            if seen[n] ~= "ok" then bad[#bad + 1] = n .. "=" .. tostring(seen[n]) end
        end
        check("world-install", #bad == 0, #bad == 0 and (#names .. " поверхонь ok") or table.concat(bad, ", "))
    end

    local QID = 12470
    local title = U.ID("quest", QID, "title")
    local obj = U.T("questui", "Cragbound Fox slain")

    -- 1. вікно квесту
    do
        W.q.id, W.q.en = QID, "EN TITLE"
        QuestInfoTitleHeader:SetText("|A:icon:12:12|a EN TITLE")
        QuestInfoDescriptionText:SetText("Some description")
        QuestInfoObjectivesText:SetText("Some objectives")
        W.objLine:SetText("0/8 Cragbound Fox slain")
        QuestInfo_Display()
        local ok = cyr(title) and QuestInfoTitleHeader:GetText() == "|A:icon:12:12|a " .. title
            and QuestInfoDescriptionText:GetText() == U.ID("quest", QID, "description")
            and QuestInfoObjectivesText:GetText() == U.ID("quest", QID, "objectives")
            and cyr(obj) and W.objLine:GetText() == "0/8 " .. obj
            and cyr(QuestInfoRewardsFrame.Header:GetText()) and cyr(QuestInfoDescriptionHeader:GetText())
            and cyr(QuestFrameAcceptButton.fsObj:GetText())
        local item = U.ID("item", 6948, "name")
        local okItem = not item or W.rewardBtn.Name:GetText() == item
        check("world-quest-info", ok and okItem, ("назва %q, опис %s, цілі %s, ціль %q, нагорода %q, заголовки %q/%q, кнопка %q"):format(
            tostring(QuestInfoTitleHeader:GetText()), tostring(QuestInfoDescriptionText:GetText() == U.ID("quest", QID, "description")),
            tostring(QuestInfoObjectivesText:GetText() == U.ID("quest", QID, "objectives")), tostring(W.objLine:GetText()),
            tostring(W.rewardBtn.Name:GetText()), tostring(QuestInfoRewardsFrame.Header:GetText()), tostring(QuestInfoDescriptionHeader:GetText()),
            tostring(QuestFrameAcceptButton.fsObj:GetText())))
    end

    -- 2. прогрес і журнал
    do
        QuestProgressText:SetText("Did you do it?")
        QuestProgressTitleText:SetText("EN TITLE")
        W.logTitle.Text:SetText("EN TITLE")
        W.logObj.Text:SetText("2/8 Cragbound Fox slain")
        W.logHeader.ButtonText:SetText("Quests")
        QuestLogQuests_Update()
        local ok = QuestProgressText:GetText() == U.ID("quest", QID, "progress") and QuestProgressTitleText:GetText() == title
            and W.logTitle.Text:GetText() == title and W.logObj.Text:GetText() == "2/8 " .. obj
            and cyr(W.logHeader.ButtonText:GetText())
        check("world-quest-log", ok, ("прогрес %q, журнал %q / %q / %q"):format(tostring(QuestProgressText:GetText()):sub(1, 30),
            tostring(W.logTitle.Text:GetText()), tostring(W.logObj.Text:GetText()), tostring(W.logHeader.ButtonText:GetText())))
    end

    -- 3. трекер
    do
        local b = QuestObjectiveTracker:GetBlock(QID)
        b:SetHeader("EN TITLE")
        local line = b:AddObjective(1, "5/8 Cragbound Fox slain")
        local ready = b:AddObjective("QuestComplete", "Ready for turn-in")
        local sb = ScenarioObjectiveTracker.ObjectivesBlock
        local sl = sb:AddObjective(1, "Defeat the Echo of Fyrakk")
        local toast = { QuestName = H.wfs("EN TITLE"), questID = QID, ToastText = H.wfs("World Quest Complete!") }
        AlertFrame:AddAlertFrame(toast)
        ObjectiveTrackerTopBannerFrame.questID = QID
        ObjectiveTrackerTopBannerFrame.Title:SetText("EN TITLE")
        ObjectiveTrackerTopBannerFrame:PlayBanner()
        local ok = toast.QuestName:GetText() == title and ObjectiveTrackerTopBannerFrame.Title:GetText() == title
            and b.HeaderText:GetText() == title and line.Text:GetText() == "5/8 " .. obj and cyr(ready.Text:GetText())
            and cyr(sl.Text:GetText()) and cyr(QuestObjectiveTracker.Header.Text:GetText())
        check("world-tracker", ok, ("%q · %q · %q · %q"):format(tostring(b.HeaderText:GetText()), tostring(line.Text:GetText()),
            tostring(ready.Text:GetText()), tostring(sl.Text:GetText())) .. " · модуль " .. tostring(QuestObjectiveTracker.Header.Text:GetText()))
    end

    -- 4. мапа: тултіп квест-піна, точки польоту, підпис зони
    do
        GameTooltip.owner = { GetMap = function() end, questID = QID }
        GameTooltip:SetText("EN TITLE")
        GameTooltip:AddLine("- 1/8 Cragbound Fox slain")
        local q1, q2 = GameTooltipTextLeft1:GetText(), GameTooltipTextLeft2:GetText()
        GameTooltip.owner = { taxiNodeData = {} }
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Desolation Hold, Southern Barrens")
        local tx = GameTooltipTextLeft1:GetText()
        -- AreaPOI: заголовок і опис до набору віджетів перекладаються; після GameTooltip_AddWidgetSet — ні
        GameTooltip.owner = { poiInfo = {}, GetMap = function() end }
        GameTooltip:SetText("Submerged Sign")
        local poi = GameTooltipTextLeft1:GetText()
        GameTooltip.widgetContainer = { widgetSetID = 123 }
        GameTooltip:AddLine("Submerged Sign")
        local poiW = GameTooltipTextLeft2:GetText()
        GameTooltip.widgetContainer = nil
        -- світовий квест із віджетами: те саме правило
        GameTooltip.owner = { GetMap = function() end, questID = QID }
        GameTooltip:SetText("EN TITLE")
        GameTooltip.insertedFrames = { {} }
        GameTooltip:AddLine("- 1/8 Cragbound Fox slain")
        local wq1, wq2 = GameTooltipTextLeft1:GetText(), GameTooltipTextLeft2:GetText()
        GameTooltip.insertedFrames = nil
        -- тултіп блоку трекера (бонусна ціль / прогрес групи): назва квесту й рядки
        GameTooltip.owner = QuestObjectiveTracker:GetBlock(QID)
        GameTooltip:SetText("EN TITLE")
        GameTooltip:AddLine("Rewards")
        local tb1, tb2 = GameTooltipTextLeft1:GetText(), GameTooltipTextLeft2:GetText()
        W.areaLabel.Name:SetText("Submerged Sign")
        W.areaLabel:EvaluateLabels()
        local ok = q1 == title and q2 == "- 1/8 " .. obj and cyr(tx) and cyr(poi) and poiW == "Submerged Sign"
            and wq1 == title and wq2 == "- 1/8 Cragbound Fox slain" and tb1 == title and cyr(tb2)
            and cyr(W.areaLabel.Name:GetText())
        poi = poi .. " / з віджетами " .. tostring(poiW) .. " · WQ " .. tostring(wq1) .. " / " .. tostring(wq2)
            .. " · трекер " .. tostring(tb1) .. " / " .. tostring(tb2)
        GameTooltip.owner = nil
        check("world-map", ok, ("%q · %q · %q · POI %q · підпис %q"):format(tostring(q1), tostring(q2), tostring(tx), tostring(poi),
            tostring(W.areaLabel.Name:GetText())))
    end

    -- 5. субтитри, говоряча голова, чат
    do
        local line = "Your heroic deeds have earned you this Frostwolf land."
        local want = U.T("dialog", line)
        SubtitlesFrame:AddSubtitle("Rrqzx: " .. line)
        local sub = SubtitlesFrame.Subtitles[1]:GetText()
        W.th.name = "Rrqzx"
        TalkingHeadFrame.TextFrame.Text:SetText(line)
        local th = TalkingHeadFrame.TextFrame.Text:GetText()
        local _, say = H.filters["CHAT_MSG_MONSTER_SAY"](nil, "CHAT_MSG_MONSTER_SAY", line, "Rrqzx")
        local _, sys = H.filters["CHAT_MSG_SYSTEM"](nil, "CHAT_MSG_SYSTEM", "Quest accepted: EN TITLE")
        local _, emo = H.filters["CHAT_MSG_TEXT_EMOTE"](nil, "CHAT_MSG_TEXT_EMOTE", "Rrqzx points at you.", "Rrqzx")
        local _, lnk = H.filters["CHAT_MSG_PARTY"](nil, "CHAT_MSG_PARTY", "go |cffffff00|Hquest:" .. QID .. ":60|h[EN TITLE]|h|r now")
        local ok = cyr(want) and sub == "Rrqzx: " .. want and th == want and say == want
            and type(sys) == "string" and sys:find(title, 1, true) and cyr(emo) and emo:find("Rrqzx", 1, true)
            and type(lnk) == "string" and lnk:find("[" .. title .. "]", 1, true) and lnk:find("^go ")
        check("world-dialog", ok, ("суб %q · голова %q · сист %q · емоція %q · лінк %q"):format(tostring(sub):sub(1, 30),
            tostring(th):sub(1, 20), tostring(sys), tostring(emo), tostring(lnk)))
    end

    -- 6. книга, PlayerChoice, підпис NPC у тултіпі
    do
        W.book = "19. Amidst the chaos, the forgotten one cried, \"When the last star fades, the emperor's crown will weigh heavy with the sins of a thousand years.\" The stalwart soldiers threw down their spears and wept tears of blood and burning anger."
        ItemTextPageText:SetText(W.book)
        local book = ItemTextPageText.text
        PlayerChoiceFrame = W.choice
        H.fire("ADDON_LOADED", "Blizzard_PlayerChoice")
        local desc = "Grants you the ability to see hiding Mischievous Faerie Dragons, so you can root them out before they damage the tree!"
        W.choice.choiceInfo = { questionText = "Some question?", options = { { header = "Gorgoneion Gaze", description = desc } } }
        PlayerChoiceFrame:TryShow()
        local pc = W.choiceOpt.OptionText.text
        PlayerChoiceFrame = nil
        GameTooltipTextLeft2 = H.wfs("The Speaker")
        H.tooltipPost[Enum.TooltipDataType.Unit](GameTooltip, { guid = "Creature-0-1-2-3-4-5" })
        local sub = GameTooltipTextLeft2:GetText()
        local ok = cyr(book) and book == U.T("dialog", W.book) and cyr(pc) and pc == U.T("dialog", desc) and cyr(sub)
        check("world-text", ok, ("книга %q · вибір %q · підпис %q"):format(tostring(book):sub(1, 30), tostring(pc):sub(1, 30), tostring(sub)))
    end

    -- 8. бабли над головами: подія → таймер → C_ChatBubbles (без заборонених), у підземеллі — нічого
    do
        local line = "Your heroic deeds have earned you this Frostwolf land."
        local want = U.T("dialog", line)
        local fs = W.bubble.children[1].String
        fs:SetText(line)
        H.fire("CHAT_MSG_MONSTER_SAY", line, "Rrqzx")
        H.runTimers(); H.runTimers()
        local got = fs:GetText()
        W.inInstance = true
        fs:SetText(line)
        H.fire("CHAT_MSG_MONSTER_SAY", line, "Rrqzx")
        H.runTimers(); H.runTimers()
        local inst = fs:GetText()
        W.inInstance = false
        check("world-bubbles", cyr(want) and got == want and inst == line and W.bubbleArg == false,
            ("бабл %q · у підземеллі %q · includeForbidden %s"):format(tostring(got):sub(1, 30), tostring(inst):sub(1, 20), tostring(W.bubbleArg)))
    end

    -- 9. автопопап трекера
    do
        local b = QuestObjectiveTracker:GetBlock(QID .. "COMPLETE", "AutoQuestPopUpBlockTemplate")
        b:Update("EN TITLE", QID, "COMPLETE")
        local c = b.Contents
        check("world-popup", c.QuestName:GetText() == title and cyr(c.TopText:GetText()),
            ("%q · %q · %q"):format(tostring(c.QuestName:GetText()), tostring(c.TopText:GetText()), tostring(c.BottomText:GetText())))
    end

    -- 10. DialogueUI: перекладач квестів, кнопки, привітання по абзацах
    do
        H.fire("ADDON_LOADED", "DialogueUI")
        local t = W.duiTranslator
        local qd = t and t.questDataGetter(QID)
        local btn = setmetatable({ Name = H.wfs() }, { __index = DUIDialogOptionButtonMixin })
        local opt = "(Delve) Go get the treasure while I handle whatever is about to attack us."
        btn:SetGossip({ name = opt })
        local gopt = btn.Name:GetText()
        W.gossipText = "Hey, hey!\n\nI'm sure you can land a ring on a slow-moving turtle.\n\nWhat do you say?"
        local ua = U.T("dialog", W.gossipText)
        local paras = DUIQuestFrame:FormatParagraph(W.gossipText)
        local got = {}
        for i, fs in ipairs(paras) do got[i] = fs:GetText() end
        local want = {}
        for v in (ua or ""):gmatch("[%C]+") do if v ~= " " then want[#want + 1] = v end end
        local okP = #got == 3 and #want == 3 and got[1] == want[1] and got[3] == want[3]
        check("world-dialogueui", t and qd and qd.title == title and gopt == "1. " .. tostring(U.T("dialog", opt)) and okP,
            ("перекладач %s, назва %q, кнопка %q, абзаци %q | %q"):format(tostring(t and t.name), tostring(qd and qd.title),
                tostring(gopt):sub(1, 30), tostring(got[1]), tostring(got[3])))
    end

    -- 7. довгий переклад у трекері стискається, а не налазить на сусідній рядок
    do
        local fs = H.wfs(("x"):rep(30))                                       -- 1 рядок
        U.WK.Fit(fs, ("ї"):rep(30), ("x"):rep(30))                          -- UA 60 байт → 2 рядки
        check("world-fit", fs:GetStringHeight() <= 12, ("висота %d, масштаб %s, рядків %s"):format(fs:GetStringHeight(),
            tostring(fs.scale), tostring(fs.maxLines)))
    end
end
