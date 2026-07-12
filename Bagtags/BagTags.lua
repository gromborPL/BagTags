-- ============================================================================
-- INTEGRACJA Z SYSTEMEM TAGOWANIA BAGTAGS + MODERN SCROLL & QUEST FIX
-- ============================================================================
local addonName, BT = ...
BT.InventoryModule = {}

if not BagTagsCategoryState then 
    BagTagsCategoryState = {} 
end
local knownItems = {}

local mainFrame = CreateFrame("Frame", "BagTagsInventoryFrame", UIParent)
mainFrame:SetSize(420, 520)
mainFrame:SetPoint("CENTER", UIParent, "CENTER")
mainFrame:SetFrameStrata("HIGH")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

mainFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
mainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
mainFrame:Hide()

local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -15)
title:SetText("Backpack")

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() 
    BT.InventoryModule:HideFrame() 
end)

-- Kontener na zawartość torby
local scrollFrame = CreateFrame("ScrollFrame", "BagTagsInventoryScrollFrame", mainFrame)
scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -45)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -30, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(355, 1)
scrollFrame:SetScrollChild(contentFrame)

-- MINIMALISTYCZNY, NOWOCZESNY SUWAK
local customScrollBar = CreateFrame("Slider", "BagTagsInventoryCustomScrollBar", mainFrame)
customScrollBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -55)
customScrollBar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 25)
customScrollBar:SetWidth(4) -- Bardzo cienki, nowoczesny pasek
customScrollBar:SetOrientation("VERTICAL")
customScrollBar:SetMinMaxValues(0, 0)
customScrollBar:SetValue(0)
customScrollBar:SetValueStep(1)

-- Tło suwaka (delikatna, ciemna linia prowadząca)
customScrollBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
customScrollBar:SetBackdropColor(1, 1, 1, 0.05)

-- Nowoczesny, zaokrąglony i półprzezroczysty uchwyt suwaka
local thumb = customScrollBar:CreateTexture(nil, "ARTWORK")
thumb:SetTexture("Interface\\AddOns\\BagTags\\media\\white") -- używa białej tekstury do pokolorowania (lub domyślnej wbudowanej)
if not thumb:GetTexture() then thumb:SetTexture("Interface\\Buttons\\WHITE8x8") end
thumb:SetColorTexture(0.4, 0.4, 0.4, 0.6) -- półprzezroczysty szary
thumb:SetSize(4, 40) -- dopasowany szerokością do linii paska
customScrollBar:SetThumbTexture(thumb)

-- Efekt hover dla suwaka (rozjaśnia się po najechaniu)
customScrollBar:SetScript("OnEnter", function() thumb:SetColorTexture(0.6, 0.6, 0.6, 0.8) end)
customScrollBar:SetScript("OnLeave", function() thumb:SetColorTexture(0.4, 0.4, 0.4, 0.6) end)

customScrollBar:SetScript("OnValueChanged", function(self, value)
    scrollFrame:SetVerticalScroll(value)
end)

-- Obsługa scrolla myszką
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local minVal, maxVal = customScrollBar:GetMinMaxValues()
    local current = customScrollBar:GetValue()
    local newValue = current - (delta * 28)
    if newValue < minVal then newValue = minVal end
    if newValue > maxVal then newValue = maxVal end
    customScrollBar:SetValue(newValue)
end)

contentFrame.sections = {}
local globalSlotCounter = 1

local internalScanTooltip = CreateFrame("GameTooltip", "BagTagsInventoryInternalScanTooltip", nil, "GameTooltipTemplate")
internalScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function FormatMoney(amount)
    if not amount or amount <= 0 then return "" end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    
    local result = ""
    if gold > 0 then result = result .. gold .. "|cffffd700g|r " end
    if silver > 0 or gold > 0 then result = result .. silver .. "|cffc7c7c7s|r " end
    if copper > 0 or result == "" then result = result .. copper .. "|cffb87333c|r" end
    return result
end

local function GetItemVendorPrice(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return 0 end
    
    local _, count = GetContainerItemInfo(bag, slot)
    count = count or 1
    
    local price = 0
    if GetSellValue then
        price = GetSellValue(link) or 0
    else
        local _, _, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(link)
        price = itemSellPrice or 0
    end
    
    return price * count
end

local function GetSlotKey(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return nil end
    local itemID = string.match(link, "item:(%d+)")
    return string.format("%d_%d_%s", bag, slot, itemID or "0")
end

local function SnapshotCurrentItems()
    table.wipe(knownItems)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local key = GetSlotKey(bag, slot)
            if key then knownItems[key] = true end
        end
    end
end

local function GetItemTag(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return nil end
    
    local key = GetSlotKey(bag, slot)
    if key and not knownItems[key] then return "New Items" end

    local _, _, _, _, _, itemClass = GetItemInfo(link)
    
    if itemClass == "Consumable" then return "Consumables" end
    if itemClass == "Trade Goods" or itemClass == "Tradeskill" then return "Tradeskill" end
    if itemClass == "Quest" then return "Quest" end

    return itemClass or "Miscellaneous"
end

local function GetOrCreateOverlay(button)
    if button.BagTagsOverlay then return button.BagTagsOverlay end
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 10)
    overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    
    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 14, "THICKOUTLINE")
    label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    overlay.label = label
    
    button.BagTagsOverlay = overlay
    return overlay
end

local function SetOverlayStyle(overlay, borderColor, labelColor, letter)
    overlay:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    overlay.label:SetTextColor(labelColor.r, labelColor.g, labelColor.b, labelColor.a)
    overlay.label:SetText(letter)
    overlay:Show()
end

local function CustomItemButton_Update(slotFrame, bagID, slotID)
    local texture, count = GetContainerItemInfo(bagID, slotID)
    local iconTex = _G[slotFrame:GetName().."IconTexture"]
    local countTex = _G[slotFrame:GetName().."Count"]
    
    if texture then iconTex:SetTexture(texture) iconTex:Show() else iconTex:Hide() end
    if count and count > 1 then countTex:SetText(count) countTex:Show() else countTex:Hide() end

    local link = GetContainerItemLink(bagID, slotID)
    if not link or not BagTagsConfig then
        if slotFrame.BagTagsOverlay then slotFrame.BagTagsOverlay:Hide() end
        return
    end

    -- USUNIĘTO TAGOWANIE LITERKĄ "Q" DLA PRZEDMIOTÓW QUESTOWYCH (KATEGORIA WYSTARCZY)
    local itemName, _, quality, _, _, itemType, _, _, _, _, itemVendorPrice = GetItemInfo(link)
    if not quality then quality = 0 end

    local isSoulbound = false
    internalScanTooltip:ClearLines()
    internalScanTooltip:SetBagItem(bagID, slotID)
    for i = 2, internalScanTooltip:NumLines() do
        local line = _G["BagTagsInventoryInternalScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and (text == "Soulbound" or text == "Przypisany" or text == "Binds when picked up") then 
            isSoulbound = true 
            break
        end
    end

    if isSoulbound and BagTagsConfig.showSoulbound then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.53, g = 0.12, b = 0.77, a = 1 }, { r = 0.90, g = 0.60, b = 1.0, a = 1 }, "S")
        return
    end

    if BagTagsConfig.showMarket then
        local ahPrice = 0
        if Atr_GetAuctionPrice then ahPrice = Atr_GetAuctionPrice(itemName) or 0 end
        
        local deValue = 0
        if Atr_GetDisenchantValue then deValue = Atr_GetDisenchantValue(itemName) or 0 end
        
        local vendorPrice = itemVendorPrice or 0
        local realAhPrice = ahPrice * 0.95
        local realDeValue = deValue * 0.95
        local depositRisk = (itemType == "Armor" or itemType == "Weapon") and (vendorPrice * 0.60) or 0

        local currentTag = "NONE"
        local maxEffectiveValue = vendorPrice

        if realAhPrice > 0 and (realAhPrice - depositRisk) > maxEffectiveValue then
            maxEffectiveValue = realAhPrice - depositRisk
            currentTag = "A"
        end

        local hasEnchanting = false
        for i = 1, GetNumSkillLines() do
            local skillName = GetSkillLineInfo(i)
            if skillName == "Enchanting" or skillName == "Zaklinanie" then hasEnchanting = true break end
        end

        if BagTagsConfig.showDisenchant and hasEnchanting and (quality == 2 or quality == 3) and (itemType == "Armor" or itemType == "Weapon") then
            if realDeValue > maxEffectiveValue and realDeValue > vendorPrice then
                maxEffectiveValue = realDeValue
                currentTag = "D"
            end
        end

        if currentTag == "NONE" and vendorPrice > 0 then
            currentTag = "V"
        end

        if currentTag == "A" then
            local overlay = GetOrCreateOverlay(slotFrame)
            SetOverlayStyle(overlay, { r = 0.1, g = 1, b = 0.1, a = 1 }, { r = 0.4, g = 1, b = 0.4, a = 1 }, "A")
            return
        elseif currentTag == "D" then
            local overlay = GetOrCreateOverlay(slotFrame)
            SetOverlayStyle(overlay, { r = 0.8, g = 0.3, b = 0.8, a = 1 }, { r = 1.0, g = 0.5, b = 1.0, a = 1 }, "D")
            return
        elseif currentTag == "V" and BagTagsConfig.showVendor then
            local overlay = GetOrCreateOverlay(slotFrame)
            SetOverlayStyle(overlay, { r = 0.9, g = 0.8, b = 0.2, a = 1 }, { r = 1.0, g = 0.9, b = 0.4, a = 1 }, "V")
            return
        end
    end

    if quality == 0 and BagTagsConfig.showVendor then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.9, g = 0.8, b = 0.2, a = 1 }, { r = 1.0, g = 0.9, b = 0.4, a = 1 }, "V")
    elseif slotFrame.BagTagsOverlay then
        slotFrame.BagTagsOverlay:Hide()
    end
end

function BT.InventoryModule:UpdateLayout()
    if not mainFrame:IsShown() then return end
    
    for _, section in pairs(contentFrame.sections) do
        section:Hide()
        if section.slots then 
            for _, slotFrame in pairs(section.slots) do slotFrame:Hide() end 
        end
    end
    
    local groups = {}
    local categoryValues = {} 
    local orderedCategories = { "New Items", "Consumables", "Tradeskill", "Quest", "Miscellaneous" }
    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            if GetContainerItemLink(bag, slot) then
                local tag = GetItemTag(bag, slot) or "Miscellaneous"
                if not groups[tag] then 
                    groups[tag] = {} 
                    categoryValues[tag] = 0
                end
                table.insert(groups[tag], {bag = bag, slot = slot})
                
                local itemPrice = GetItemVendorPrice(bag, slot)
                categoryValues[tag] = categoryValues[tag] + itemPrice
                
                local found = false
                for _, name in ipairs(orderedCategories) do
                    if name == tag then found = true break end
                end
                if not found then 
                    table.insert(orderedCategories, tag) 
                    categoryValues[tag] = itemPrice
                end
            end
        end
    end
    
    local currentY = -10
    local COLUMNS = 10 
    local SLOT_SIZE = 35
    
    for _, catName in ipairs(orderedCategories) do
        local itemDataList = groups[catName]
        local count = itemDataList and #itemDataList or 0
        
        if count > 0 then
            local section = contentFrame.sections[catName]
            
            if not section then
                section = CreateFrame("Frame", nil, contentFrame)
                section.slots = {}
                
                local header = CreateFrame("Button", nil, section)
                header:SetSize(355, 20)
                header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
                
                local fontString = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fontString:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                fontString:SetPoint("LEFT", header, "LEFT", 2, 0)
                header.text = fontString
                
                header:SetScript("OnClick", function()
                    BagTagsCategoryState[catName] = not BagTagsCategoryState[catName]
                    BT.InventoryModule:UpdateLayout()
                end)
                
                local highlight = header:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetTexture(1, 1, 1, 0.1)
                
                section.header = header
                contentFrame.sections[catName] = section
            end
            
            local isCollapsed = BagTagsCategoryState[catName]
            local prefix = isCollapsed and "[+] " or "[-] "
            
            if catName == "New Items" then 
                section.header.text:SetTextColor(0, 1, 0.5)
            elseif isCollapsed then 
                section.header.text:SetTextColor(0.6, 0.6, 0.6)
            else 
                section.header.text:SetTextColor(1, 0.82, 0) 
            end
            
            -- WYJĄTEK: Ukrywanie wartości Vendor dla kategorii "Quest"
            local goldText = ""
            local totalValue = categoryValues[catName] or 0
            if totalValue > 0 and catName ~= "Quest" then
                goldText = "  |cff808080(Vendor: " .. FormatMoney(totalValue) .. ")|r"
            end
            
            section.header.text:SetText(prefix .. catName .. " (" .. count .. ")" .. goldText)
            
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, currentY)
            section:Show()
            
            local sectionHeight = 20
            if not isCollapsed then
                for index, itemInfo in ipairs(itemDataList) do
                    local slotFrame = section.slots[index]
                    if not slotFrame then
                        local slotName = "BagTagsSlotButton_" .. globalSlotCounter
                        globalSlotCounter = globalSlotCounter + 1
                        slotFrame = CreateFrame("Button", slotName, section, "ContainerFrameItemButtonTemplate")
                        section.slots[index] = slotFrame
                    end
                    
                    slotFrame:SetID(itemInfo.slot)
                    local parentFrame = slotFrame:GetParent()
                    parentFrame:SetID(itemInfo.bag)
                    
                    local row = math.floor((index - 1) / COLUMNS)
                    local col = (index - 1) % COLUMNS
                    
                    slotFrame:ClearAllPoints()
                    slotFrame:SetPoint("TOPLEFT", section, "TOPLEFT", col * SLOT_SIZE, -(20 + (row * SLOT_SIZE)))
                    slotFrame:SetSize(32, 32)
                    
                    CustomItemButton_Update(slotFrame, itemInfo.bag, itemInfo.slot)
                    
                    local iconTex = _G[slotFrame:GetName().."IconTexture"]
                    if iconTex then iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                    slotFrame:Show()
                end
                local totalRows = math.ceil(count / COLUMNS)
                sectionHeight = 22 + (totalRows * SLOT_SIZE)
            end
            section:SetSize(355, sectionHeight)
            currentY = currentY - (sectionHeight + 10)
        end
    end
    
    contentFrame:SetHeight(math.abs(currentY))
    
    local maxScroll = math.max(0, math.abs(currentY) - scrollFrame:GetHeight())
    customScrollBar:SetMinMaxValues(0, maxScroll)
    
    if maxScroll > 0 then
        customScrollBar:Show()
    else
        customScrollBar:Hide()
        customScrollBar:SetValue(0)
    end
end

function BT.InventoryModule:ShowFrame() mainFrame:Show() self:UpdateLayout() end
function BT.InventoryModule:HideFrame() mainFrame:Hide() SnapshotCurrentItems() end
function BT.InventoryModule:ToggleFrame() if mainFrame:IsShown() then self:HideFrame() else self:ShowFrame() end end

local function CloseBlizz()
    for id = 1, 5 do
        local frame = _G["ContainerFrame"..id]
        if frame then frame:Hide() end
    end
end

hooksecurefunc("OpenAllBags", function() CloseBlizz() BT.InventoryModule:ShowFrame() end)
hooksecurefunc("OpenBackpack", function() CloseBlizz() BT.InventoryModule:ShowFrame() end)
hooksecurefunc("ToggleBag", function() CloseBlizz() BT.InventoryModule:ToggleFrame() end)
hooksecurefunc("CloseAllBags", function() BT.InventoryModule:HideFrame() end)
hooksecurefunc("CloseBackpack", function() BT.InventoryModule:HideFrame() end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function() table.wipe(knownItems) end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:SetScript("OnEvent", function() 
    if mainFrame:IsShown() then BT.InventoryModule:UpdateLayout() end 
end)