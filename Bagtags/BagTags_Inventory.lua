-- ============================================================================
-- BagTags_Inventory.lua
-- Niezależny moduł zarządzania ekwipunkiem w stylu AdiBags dla BagTags (Patch 3.3.5)
-- ============================================================================

local addonName, BT = ...
BT.InventoryModule = {}

-- Domyślna konfiguracja w przestrzeni nazw addonu
BT.Config = BT.Config or {}
BT.Config.enabled = (BT.Config.enabled ~= nil) and BT.Config.enabled or true
BT.Config.fontSize = BT.Config.fontSize or 10 -- Mniejsze literki dla tagów grup
BT.Config.disabledTags = BT.Config.disabledTags or {}

-- ============================================================================
-- 1. TWORZENIE OKNA GŁÓWNEGO ("INVENTORY")
-- ============================================================================

local mainFrame = CreateFrame("Frame", "BagTagsInventoryFrame", UIParent, "ButtonFrameTemplate")
mainFrame:SetSize(450, 500)
mainFrame:SetPoint("CENTER", UIParent, "CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:Hide()

-- Ustawienie tytułu okna
_G[mainFrame:GetName() .. "Title"]:SetText("Inventory")

-- Przycisk sortowania w nagłówku okna
local sortButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
sortButton:SetSize(70, 22)
sortButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -45, -40)
sortButton:SetText("Sort")
sortButton:SetScript("OnClick", function()
    SortBags() -- Natywne sortowanie Blizzard API
    BT.InventoryModule:UpdateLayout()
end)

-- Kontener ze skrolowaniem na sekcje przedmiotów
local scrollFrame = CreateFrame("ScrollFrame", "BagTagsInventoryScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -75)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -35, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(400, 1)
scrollFrame:SetScrollChild(contentFrame)

-- ============================================================================
-- 2. LOGIKA TAGOWANIA I KATEGORYZACJI
-- ============================================================================

local function GetItemTag(bag, slot)
    local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
    if not itemLink then return nil end
    
    local _, _, _, _, _, itemType = GetItemInfo(itemLink)
    
    -- Priorytet 1: Przedmioty zadań (Quest Items)
    local isQuestItem = GetContainerItemQuestInfo(bag, slot)
    if isQuestItem or itemType == "Quest" then
        return "Quest Items"
    end
    
    -- Priorytet 2: Soulbound (Przedmioty przypisane)
    -- Wykorzystujemy wbudowaną funkcję BagTags, jeśli istnieje, lub sprawdzamy status bindu
    if BT.IsItemSoulbound and BT:IsItemSoulbound(bag, slot) then
        return "Soulbound"
    end
    
    -- Pozostałe kategorie oparte na typie przedmiotu z gry
    return itemType or "Miscellaneous"
end

-- ============================================================================
-- 3. ALGORYTM UKŁADU I POZYCJONOWANIA GRUP (STYL ADIBAGS)
-- ============================================================================

function BT.InventoryModule:UpdateLayout()
    if not BT.Config.enabled then mainFrame:Hide() return end
    if not mainFrame:IsShown() then return end
    
    local groups = {}
    
    -- Skanowanie toreb (0 to główny plecak, 1-4 to dodatkowe torby)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local tag = GetItemTag(bag, slot)
            if tag and not BT.Config.disabledTags[tag] then
                if not groups[tag] then groups[tag] = {} end
                table.insert(groups[tag], {bag = bag, slot = slot})
            end
        end
    end
    
    -- Konwersja do listy indeksowanej w celu sortowania
    local sortedGroups = {}
    for tagName, items in pairs(groups) do
        table.insert(sortedGroups, {name = tagName, items = items, count = #items})
    end
    
    -- Sortowanie grup według wytycznych użytkownika
    table.sort(sortedGroups, function(a, b)
        -- 1. Quest Items zawsze na samym początku (od prawego górnego rogu)
        if a.name == "Quest Items" then return true end
        if b.name == "Quest Items" then return false end
        
        -- 2. Soulbound zawsze na drugim miejscu
        if a.name == "Soulbound" then return true end
        if b.name == "Soulbound" then return false end
        
        -- 3. Reszta sortowana malejąco po największej liczebności przedmiotów
        return a.count > b.count
    end)
    
    -- Czyszczenie i rysowanie layoutu w oknie
    if not contentFrame.sections then contentFrame.sections = {} end
    for _, section in pairs(contentFrame.sections) do section:Hide() end
    
    -- Kotwiczenie sekcji: Zaczynamy od prawej strony od góry (TOPRIGHT)
    local startX, startY = -10, -10
    local currentY = startY
    
    for i, groupData in ipairs(sortedGroups) do
        local section = contentFrame.sections[groupData.name]
        if not section then
            section = CreateFrame("Frame", nil, contentFrame)
            
            -- Konfiguracja napisu Taga (mniejsza czcionka)
            local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetFont("Fonts\\FRIZQT__.TTF", BT.Config.fontSize, "OUTLINE")
            title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
            section.title = title
            
            contentFrame.sections[groupData.name] = section
        end
        
        section.title:SetText(groupData.name)
        section:ClearAllPoints()
        
        -- Ustawienie pozycji sekcji w oknie (układ kolumnowy/rzędowy od prawej)
        section:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", startX, currentY)
        
        -- Kalkulacja wysokości sekcji na podstawie liczby ikonek
        local rows = math.ceil(groupData.count / 4) -- Maksymalnie 4 ikonki w rzędzie grupy
        local sectionHeight = 20 + (rows * 39)       -- Margines tytułu + wielkość slotów
        section:SetSize(160, sectionHeight)
        section:Show()
        
        -- Przesunięcie w dół dla kolejnej grupy tagów
        currentY = currentY - (sectionHeight + 15)
    end
    
    -- Dopasowanie wysokości kontenera skrolla
    contentFrame:SetHeight(math.abs(currentY))
end

-- ============================================================================
-- 4. OBSŁUGA ZDARZEŃ GIER I HOOKOWANIE PLECAKA
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" and mainFrame:IsShown() then
        BT.InventoryModule:UpdateLayout()
    end
end)

-- Podmiana standardowych funkcji Blizzarda otwierających torby
ToggleBackpack = function()
    if not BT.Config.enabled then
        -- Jeśli nasz moduł jest wyłączony w menu, przywróć standardowe zachowanie gry
        if BackpackTokenFrame then ToggleBag(0) end
        return
    end

    if mainFrame:IsShown() then 
        mainFrame:Hide() 
    else 
        mainFrame:Show() 
        BT.InventoryModule:UpdateLayout() 
    end
end
ToggleBag = function(bagID) ToggleBackpack() end
OpenAllBags = ToggleBackpack

-- ============================================================================
-- 5. REJESTRACJA I INTEGRACJA W NATIVE OPTIONS PANEL (FIXED)
-- ============================================================================

local function InjectInventoryOptions()
    -- Pobieramy panel główny stworzony w Core.lua
    local mainOptionsPanel = _G["BagTagsOptionsPanel"]
    
    if mainOptionsPanel then
        -- Tworzymy dedykowany podpanel dla trybu Inventory (AdiBags)
        local invPanel = CreateFrame("Frame", "BagTagsInventoryOptionsPanel", UIParent)
        invPanel.name = "Inventory (AdiBags)"
        invPanel.parent = mainOptionsPanel.name -- Podpięcie jako dziecko pod główne "BagTags"

        local subTitle = invPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        subTitle:SetPoint("TOPLEFT", 16, -16)
        subTitle:SetText("BagTags: Inventory Configuration")

        -- 1. Checkbox włączający cały moduł
        local cbEnable = CreateFrame("CheckButton", "BagTags_Inventory_EnableCB", invPanel, "InterfaceOptionsCheckButtonTemplate")
        cbEnable:SetPoint("TOPLEFT", 20, -50)
        _G[cbEnable:GetName() .. "Text"]:SetText("|cffffffffWłącz niezależne okno Inventory (AdiBags Mode)|r")
        
        cbEnable:SetScript("OnShow", function(self) self:SetChecked(BT.Config.enabled) end)
        cbEnable:SetScript("OnClick", function(self)
            BT.Config.enabled = not not self:GetChecked()
            if not BT.Config.enabled then BagTagsInventoryFrame:Hide() end
        end)

        -- 2. Suwak wielkości czcionki tagów grup
        local sliderFont = CreateFrame("Slider", "BagTags_Inventory_FontSlider", invPanel, "OptionsSliderTemplate")
        sliderFont:SetPoint("TOPLEFT", 20, -100)
        sliderFont:SetMinMaxValues(8, 14)
        sliderFont:SetValueStep(1)
        _G[sliderFont:GetName() .. "Text"]:SetText("Wielkość czcionki tagów grup")
        _G[sliderFont:GetName() .. "Low"]:SetText("8")
        _G[sliderFont:GetName() .. "High"]:SetText("14")
        
        sliderFont:SetScript("OnShow", function(self) self:SetValue(BT.Config.fontSize) end)
        sliderFont:SetScript("OnValueChanged", function(self, value)
            BT.Config.fontSize = math.floor(value)
            BT.InventoryModule:UpdateLayout()
        end)

        -- Rejestracja podkategorii w menu Blizzarda
        InterfaceOptions_AddCategory(invPanel)
    end
end

-- Bezpieczna inicjalizacja opcji po pełnym załadowaniu interfejsu
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    InjectInventoryOptions()
end)