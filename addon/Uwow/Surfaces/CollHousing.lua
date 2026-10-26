-- Uwow · Surfaces/CollHousing.lua — житло (12.x): підказки декору в каталозі й у редакторі (назва — «collections»,
-- рядки інтерфейсу — «ui»), статичні підписи вікон житла (панель, наріжний камінь, дошка оголошень, список
-- будинків, пошук ділянки, хартія/створення сусідства, налаштування будинку, панель керування) — разово на показ.
-- Сповіщення «отримано декор» — у CollAchievements (спільний хук сповіщень).
local U = UWOW
local K = U.CollKit

-- Рядки підказки: перший — назва декору/кімнати, решта — підписи інтерфейсу або «Мітка: значення».
local function tip(tt)
    if not U.Enabled() or not tt or not tt.NumLines then return end
    local changed = false
    for i = 1, tt:NumLines() do
        local fs = K.TipLine(tt, i)
        local en = K.Text(fs)
        if en and not K.Cyr(en) then
            local ua
            if i == 1 then
                ua = K.Any(en, "collections", "ui")
                if not ua then U.Miss("collections", "housing-tooltip", en) end
            else
                ua = K.Any(en, "ui", "collections") or K.Source(en, "ui", "collections")
            end
            if ua then U.Apply(fs, K.Wrap(en, ua), en); changed = true end
        end
    end
    return changed
end

local owner = {}
local function onEvent(event, pick, reshow)
    if not (EventRegistry and EventRegistry.RegisterCallback) then return end
    EventRegistry:RegisterCallback(event, function(_, ...)
        local tt = select(pick, ...)
        if tt and tip(tt) and reshow and tt.Show then tt:Show() end
    end, owner)
end

local FRAMES = {
    Blizzard_HousingDashboard = { "HousingDashboardFrame" },
    Blizzard_HousingCornerstone = { "HousingCornerstoneFrame", "HousingCornerstoneHouseInfoFrame",
                                    "HousingCornerstonePurchaseFrame", "HousingCornerstoneVisitorFrame" },
    Blizzard_HousingBulletinBoard = { "HousingBulletinBoardFrame" },
    Blizzard_HousingHouseSettings = { "HousingHouseSettingsFrame" },
    Blizzard_HouseList = { "HouseListFrame" },
    Blizzard_HousingHouseFinder = { "HouseFinderFrame" },
    Blizzard_HousingCharter = { "HousingCharterFrame" },
    Blizzard_HousingCreateNeighborhood = { "HousingCreateGuildNeighborhoodFrame", "HousingCreateNeighborhoodCharterFrame" },
    Blizzard_HousingControls = { "HousingControlsFrame" },
}

U.Surface("housing", function()
    -- каталог: подія після заповнення підказки, до GameTooltip:Show() (Show робить сам Blizzard)
    onEvent("HousingCatalogEntry.TooltipCreated", 2, false)
    -- редактор будинку: підказка вже показана — після заміни рядків перераховуємо розмір
    onEvent("HousingDecorInstance.MouseOver", 2, true)
    onEvent("HousingRoomComponentInstance.MouseOver", 2, true)
    onEvent("HousingFixtureInstance.MouseOver", 2, true)
    for addon, names in pairs(FRAMES) do
        K.OnAddon(addon, function()
            for _, n in ipairs(names) do
                local f = rawget(_G, n)
                if f then K.WalkOnShow(f, "ui", "collections") end
            end
        end)
    end
end)
