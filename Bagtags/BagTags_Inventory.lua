-- Inicjalizacja przestrzeni nazw addonu
local addonName, BT = ...
BT.InventoryModule = {}

-- Domyślna konfiguracja (jeśli nie istnieje w SavedVariables)
BT.Config = BT.Config or {
    enabled = true,
    fontSize = 10, -- Mniejsze literki dla tagów zgodnie z życzeniem
    disabledTags = {},
}

-- Tworzenie głównego okna ("Inventory") niezależnego od Bagnona
local mainFrame = CreateFrame("Frame", "BagTagsInventoryFrame", UIParent, "ButtonFrameTemplate")
mainFrame:SetSize(450, 500)
mainFrame:SetPoint("CENTER", UIParent, "CENTER")
mainFrame:Hide()
_G[mainFrame:GetName() .. "Title"]:SetText("Inventory")

-- Przycisk sortowania w nagłówku
local sortButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
sortButton:SetSize(70, 22)
sortButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -40, -40)
sortButton:SetText("Sort")
sortButton:SetScript("OnClick", function()
    -- Wywołanie funkcji sortującej Blizzard API dla 3.3.5 (lub autorski algorytm)
    SortBags() 
    BT.InventoryModule:UpdateLayout()
end)

-- Kontener na dynamiczne sekcje (grupy tagów)
local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -75)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(400, 1)
scrollFrame:SetScrollChild(contentFrame)

-- Słownik tagów / priorytetów
-- System dynamicznie zbuduje sekcje na podstawie przedmiotów w plecaku
local function GetItemTag(bag, slot)
    local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
    if not itemLink then return nil end
    
    local itemID = GetContainerItemID(bag, slot)
    local _, _, _, _, _, itemType = GetItemInfo(itemLink)
    
    -- 1. Sprawdzanie czy to Quest Item
    local isQuestItem, _, _ = GetContainerItemQuestInfo(bag, slot)
    if isQuestItem or itemType == "Quest" then
        return "Quest Items"
    end
    
    -- 2. Sprawdzanie Soulbound (w 3.3.5 wymaga skanowania Tooltipu)
    -- Tutaj uproszczona logika poglądowa
    if BT.IsItemSoulbound and BT:IsItemSoulbound(bag, slot) then
        return "Soulbound"
    end
    
    -- 3. Pozostałe domyślne tagi oparte na typach przedmiotów
    return itemType or "Miscellaneous"
end

-- Algorytm pozycjonowania i dystrybucji grup (Styl AdiBags)
function BT.InventoryModule:UpdateLayout()
    if not BT.Config.enabled then mainFrame:Hide(); return end
    
    -- Czyszczenie starych danych
    local groups = {}
    
    -- Skonstruowanie grup na podstawie zawartości toreb (Bags 0-4)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local tag = GetItemTag(bag, slot)
            if tag and not BT.Config.disabledTags[tag] then
                if not groups[tag] then groups[tag] = {} end
                table.insert(groups[tag], {bag = bag, slot = slot})
            end
        end
    end
    
    -- Konwersja do tabeli indeksowanej w celu sortowania po liczebności
    local sortedGroups = {}
    for tagName, items in pairs(groups) do
        table.insert(sortedGroups, {name = tagName, items = items, count = #items})
    end
    
    -- Sortowanie grup według Twoich kryteriów:
    table.sort(sortedGroups, function(a, b)
        -- Reguła 1: Quest Items zawsze na pierwszym miejscu (z prawej/góry)
        if a.name == "Quest Items" then return true end
        if b.name == "Quest Items" then return false end
        
        -- Reguła 2: Soulbound na drugim miejscu
        if a.name == "Soulbound" then return true end
        if b.name == "Soulbound" then return false end
        
        -- Reguła 3: Pozostałe sortowane po największej liczebności
        return a.count > b.count
    end)
    
    -- Renderowanie layoutu (Układ siatki wewnątrz contentFrame)
    -- Pierwsza grupa startuje od prawego górnego rogu (TOPRIGHT)
    local offsetX, offsetY = -10, -10
    local maxColumns = 4
    local currentColumn = 0
    
    -- Ukryj wszystkie poprzednie item buttony dla czystego redrawu
    if not contentFrame.sections then contentFrame.sections = {} end
    for _, section in pairs(contentFrame.sections) do section:Hide() end
    
    for i, groupData in ipairs(sortedGroups) do
        local section = contentFrame.sections[groupData.name]
        if not section then
            section = CreateFrame("Frame", nil, contentFrame)
            -- Mniejsze literki w Tagach przedmiotów (nagłówkach grup)
            local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetFont("Fonts\\FRIZQT__.TTF", BT.Config.fontSize, "OUTLINE") 
            title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
            title:SetText(groupData.name)
            section.title = title
            contentFrame.sections[groupData.name] = section
        end
        
        section:Show()
        -- Dynamiczne dopasowanie wielkości sekcji oraz kotwiczenie w siatce (Layouting)
        -- [Tutaj następuje pętla tworząca/przypisująca ContainerFrameItemButtonTemplate dla każdego itemu]
        -- Dla zachowania struktury zaczynamy od TOPRIGHT i schodzimy w dół/lewo.
    end
end

-- Rejestracja zdarzeń gry (Otwieranie plecaka)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" and mainFrame:IsShown() then
        BT.InventoryModule:UpdateLayout()
    end
end)

-- Hookowanie standardowych klawiszy otwierania toreb
ToggleBackpack = function()
    if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show(); BT.InventoryModule:UpdateLayout() end
end
ToggleBag = function(bagID) ToggleBackpack() end
OpenAllBags = ToggleBackpack

-- ==========================================
-- HOOKOWANIE I OBSŁUGA ZDARZEŃ (OTWIERANIE TORBY)
-- ==========================================

ToggleBackpack = function()
    if BagTagsInventoryFrame:IsShown() then 
        BagTagsInventoryFrame:Hide() 
    else 
        BagTagsInventoryFrame:Show() 
        BT.InventoryModule:UpdateLayout() 
    end
end
ToggleBag = function(bagID) ToggleBackpack() end
OpenAllBags = ToggleBackpack

-- ==========================================
-- INTEGRACJA Z BLIZZARD INTERFACE OPTIONS
-- ==========================================

-- 1. Tworzenie głównego panelu konfiguracji
local optionsPanel = CreateFrame("Frame", "BagTagsOptionsPanel", UIParent)
optionsPanel.name = "BagTags"

-- Tytuł wewnątrz panelu
local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("BagTags - AdiBags Mode Config")

-- 2. Checkbox: Włącz/Wyłącz cały moduł okna Inventory
local enabledCheck = CreateFrame("CheckButton", "BT_EnableModCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
enabledCheck:SetPoint("TOPLEFT", 16, -50)
_G[enabledCheck:GetName() .. "Text"]:SetText("Enable Inventory Frame (AdiBags Style)")
enabledCheck:SetChecked(BT.Config.enabled)
enabledCheck:SetScript("OnClick", function(self)
    BT.Config.enabled = self:GetChecked()
    if not BT.Config.enabled then
        BagTagsInventoryFrame:Hide()
    else
        if BagTagsInventoryFrame:IsShown() then BT.InventoryModule:UpdateLayout() end
    end
end)

-- 3. Checkbox: Włącz/Wyłącz grupę przedmiotów zadań (Quest Items)
local disableQuestCheck = CreateFrame("CheckButton", "BT_DisableQuestCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
disableQuestCheck:SetPoint("TOPLEFT", 16, -90)
_G[disableQuestCheck:GetName() .. "Text"]:SetText("Show Quest Items Group")
disableQuestCheck:SetChecked(not BT.Config.disabledTags["Quest Items"])
disableQuestCheck:SetScript("OnClick", function(self)
    BT.Config.disabledTags["Quest Items"] = not self:GetChecked()
    if BagTagsInventoryFrame:IsShown() then
        BT.InventoryModule:UpdateLayout()
    end
end)

-- 4. Rejestracja panelu w systemie gry (ESC -> Interface -> AddOns)
InterfaceOptions_AddCategory(optionsPanel)