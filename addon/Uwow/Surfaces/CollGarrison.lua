-- Uwow · Surfaces/CollGarrison.lua — гарнізон і столи місій (WoD, оплот класу, BfA, ковенанти): список місій,
-- сторінка місії (назва, місце, опис), списки соратників, звіт на сторінці гарнізону, підказки соратників і
-- їхніх здібностей, статичні підписи вікон на показ. Дані: «ui» (таблиця v1 garrison лягла в текстовий домен).
-- Сповіщення гарнізону (будівля, місія, соратник) — у CollAchievements.
local U = UWOW
local K = U.CollKit

local function G(text)
    local ua = K.Any(text, "ui", "names")
    if not ua and text and not K.Cyr(text) then U.Miss("ui", "garrison", text) end
    return ua
end

local MISSION_FRAMES = { "GarrisonMissionFrame", "OrderHallMissionFrame", "BFAMissionFrame", "CovenantMissionFrame" }
local SHOWN = { "GarrisonMissionFrame", "OrderHallMissionFrame", "BFAMissionFrame", "CovenantMissionFrame",
                "GarrisonLandingPage", "GarrisonBuildingFrame", "GarrisonShipyardFrame", "GarrisonCapacitiveDisplayFrame" }

local function followerRow(button)
    local f = button.Follower or button
    if f.Name then K.FollowNow(f.Name, G) end
    if button.Category then K.FollowNow(button.Category, G) end
end

local function installUI()
    if GarrisonMissionList_InitButton then
        hooksecurefunc("GarrisonMissionList_InitButton", function(button)
            if U.Enabled() and button and button.Title then K.FollowNow(button.Title, G) end
        end)
    end
    for _, n in ipairs({ "GarrisonLandingPageReportList_InitButton", "GarrisonLandingPageReportList_InitButtonAvailable" }) do
        if rawget(_G, n) then
            hooksecurefunc(n, function(button)
                if U.Enabled() and button and button.Title then K.FollowNow(button.Title, G) end
            end)
        end
    end
    for _, n in ipairs(MISSION_FRAMES) do
        local f = rawget(_G, n)
        if f then
            local page = f.GetMissionPage and f:GetMissionPage() or (f.MissionTab and f.MissionTab.MissionPage)
            local stage = page and page.Stage
            if stage then
                K.FollowNow(stage.Title, G)
                K.FollowNow(stage.Location, G)
                K.FollowNow(stage.MissionDescription, G)
            end
            local list = f.FollowerList
            if list then K.OnScroll(list.ScrollBox, followerRow) end
        end
    end
    local lp = rawget(_G, "GarrisonLandingPage")
    if lp and lp.FollowerList then K.OnScroll(lp.FollowerList.ScrollBox, followerRow) end
    for _, n in ipairs(SHOWN) do
        local f = rawget(_G, n)
        if f then K.WalkOnShow(f, "ui") end
    end
end

local function installTooltips()
    if GarrisonFollowerTooltip_ShowWithData then
        hooksecurefunc("GarrisonFollowerTooltip_ShowWithData", function(_, tooltipFrame)
            if U.Enabled() then K.Walk(tooltipFrame or rawget(_G, "GarrisonFollowerTooltip"), "ui", "names") end
        end)
    end
    if GarrisonFollowerAbilityTooltip_Show then
        hooksecurefunc("GarrisonFollowerAbilityTooltip_Show", function(tooltip)
            if U.Enabled() then K.Walk(tooltip, "ui") end
        end)
    end
end

U.Surface("garrison", function()
    K.OnAddon("Blizzard_GarrisonBase", installTooltips)
    K.OnAddon("Blizzard_GarrisonUI", installUI)
end)
