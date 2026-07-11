-- BagTags v0.7.3 (Text Wrapping & Multi-Panel Fixed Layout)
local ADDON_NAME, addonTable = ...

-- 1. VARIABLES AND TAG CONFIGURATION
local GRAY_QUALITY = 0
local UNCOMMON_QUALITY = 2
local RARE_QUALITY = 3

local SOULBOUND_BORDER_COLOR = { r = 0.53, g = 0.12, b = 0.77, a = 1 } 
local SOULBOUND_LABEL_COLOR  = { r = 0.90, g = 0.60, b = 1.0, a = 1 }
local QUEST_BORDER_COLOR = { r = 1, g = 0.9, b = 0.1, a = 1 }
local QUEST_LABEL_COLOR  = { r = 1, g = 0.95, b = 0.4, a = 1 }
local AH_BORDER_COLOR    = { r = 0.1, g = 1, b = 0.1, a = 1 }
local AH_LABEL_COLOR     = { r = 0.4, g = 1, b = 0.4, a = 1 }
local VEND_BORDER_COLOR  = { r = 0.9, g = 0.8, b = 0.2, a = 1 }
local VEND_LABEL_COLOR   = { r = 1, g = 0.9, b = 0.4, a = 1 }
local DE_BORDER_COLOR    = { r = 0.8, g = 0.3, b = 0.8, a = 1 }
local DE_LABEL_COLOR     = { r = 1.0, g = 0.5, b = 1.0, a = 1 }

local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE = 16
local FONT_FLAGS = "THICKOUTLINE"

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == ADDON_NAME then
        if not BagTagsConfig then
            BagTagsConfig = { showVendor = true, showQuest = true, showSoulbound = true, showMarket = true, showDisenchant = true }
        end
        if not BagTagsButtonPosition then BagTagsButtonPosition = 190 end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- HELPER FUNCTIONS
local function HasEnchanting()
    for i = 1, GetNumSkillLines() do
        local skillName = GetSkillLineInfo(i)
        if skillName == "Enchanting" or skillName == "Zaklinanie" then return true end
    end
    return false
end

local function FormatMoneyString(copper)
    if not copper or copper <= 0 then return "0g 0s 0c" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cp = copper % 100
    return string.format("%dg %ds %dc", gold, silver, cp)
end

local function GetAuctionatorPrice(link, itemName)
    if not link then return 0 end
    local nameOnly = itemName or GetItemInfo(link)
    if not nameOnly then return 0 end

    if Atr_GetAuctionPrice then
        local price = Atr_GetAuctionPrice(nameOnly)
        if price and type(price) == "number" and price > 0 then return price end
    end
    return 0
end

local function GetAuctionatorDEPrice(link, itemName)
    if not link then return 0 end
    local nameOnly = itemName or GetItemInfo(link)
    if not nameOnly then return 0 end

    if Atr_GetDisenchantValue then
        local dePrice = Atr_GetDisenchantValue(nameOnly)
        if dePrice and type(dePrice) == "number" and dePrice > 0 then return dePrice end
    end
    return 0
end

-- 2. OVERLAY FUNCTIONS
local function GetOrCreateOverlay(button)
    if button.BagTagsOverlay then return button.BagTagsOverlay end
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 10)
    overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT_PATH, FONT_SIZE, FONT_FLAGS)
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

local scanTooltip = CreateFrame("GameTooltip", "BagTagsScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

function addonTable:IsItemSoulbound(bag, slot)
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)
    for i = 2, scanTooltip:NumLines() do
        local line = _G["BagTagsScanTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and (text == "Soulbound" or text == "Przypisany" or text == "Binds when picked up") then return true end
    end
    return false
end

local function IsQuestItem(link)
    if not link then return false end
    local _, _, _, _, _, itemType = GetItemInfo(link)
    return itemType == "Quest"
end

local function GetBagAndSlot(button)
    if button.GetBag then
        local ok, bag = pcall(button.GetBag, button)
        if ok and type(bag) == "number" and button.GetID then return bag, button:GetID() end
    end
    local parent = button.GetParent and button:GetParent()
    if parent and parent.GetID then return parent:GetID(), button:GetID() end
    return nil, nil
end

local function UpdateButton(button)
    if not button then return end
    local bag, slot = GetBagAndSlot(button)
    if not bag or not slot then return end

    local link = GetContainerItemLink(bag, slot)
    if not link or not BagTagsConfig then
        if button.BagTagsOverlay then button.BagTagsOverlay:Hide() end
        return
    end

    local itemName, _, quality, _, _, itemType, itemSubtype, _, _, _, itemVendorPrice = GetItemInfo(link)
    if not quality then quality = GRAY_QUALITY end

    if IsQuestItem(link) and BagTagsConfig.showQuest then
        local overlay = GetOrCreateOverlay(button)
        SetOverlayStyle(overlay, QUEST_BORDER_COLOR, QUEST_LABEL_COLOR, "Q")
        return
    end

    if IsItemSoulbound(bag, slot) and BagTagsConfig.showSoulbound then
        local overlay = GetOrCreateOverlay(button)
        SetOverlayStyle(overlay, SOULBOUND_BORDER_COLOR, SOULBOUND_LABEL_COLOR, "S")
        return
    end

    if BagTagsConfig.showMarket then
        local ahPrice = GetAuctionatorPrice(link, itemName)
        local vendorPrice = itemVendorPrice or 0
        local deValue = GetAuctionatorDEPrice(link, itemName)

        local realAhPrice = ahPrice * 0.95
        local realDeValue = deValue * 0.95

        local depositRisk = 0
        if itemType == "Armor" or itemType == "Weapon" then
            depositRisk = vendorPrice * 0.60
        end

        local currentTag = "NONE"
        local maxEffectiveValue = vendorPrice

        if realAhPrice > 0 and (realAhPrice - depositRisk) > maxEffectiveValue then
            maxEffectiveValue = realAhPrice - depositRisk
            currentTag = "A"
        end

        if BagTagsConfig.showDisenchant and HasEnchanting() and (quality == UNCOMMON_QUALITY or quality == RARE_QUALITY) and (itemType == "Armor" or itemType == "Weapon") then
            if realDeValue > maxEffectiveValue and realDeValue > vendorPrice then
                maxEffectiveValue = realDeValue
                currentTag = "D"
            end
        end

        if currentTag == "NONE" and vendorPrice > 0 then
            currentTag = "V"
        end

        if currentTag == "A" then
            local overlay = GetOrCreateOverlay(button)
            SetOverlayStyle(overlay, AH_BORDER_COLOR, AH_LABEL_COLOR, "A")
            return
        elseif currentTag == "D" then
            local overlay = GetOrCreateOverlay(button)
            SetOverlayStyle(overlay, DE_BORDER_COLOR, DE_LABEL_COLOR, "D")
            return
        elseif currentTag == "V" and BagTagsConfig.showVendor then
            local overlay = GetOrCreateOverlay(button)
            SetOverlayStyle(overlay, VEND_BORDER_COLOR, VEND_LABEL_COLOR, "V")
            return
        end
    end

    if quality == GRAY_QUALITY and BagTagsConfig.showVendor then
        local overlay = GetOrCreateOverlay(button)
        SetOverlayStyle(overlay, VEND_BORDER_COLOR, VEND_LABEL_COLOR, "V")
    elseif button.BagTagsOverlay then
        button.BagTagsOverlay:Hide()
    end
end

local function RefreshAllBags()
    for i = 1, 12 do
        local frame = _G["ContainerFrame"..i]
        if frame and frame:IsShown() then
            for j = 1, MAX_CONTAINER_ITEMS do
                local button = _G["ContainerFrame"..i.."Item"..j]
                if button then UpdateButton(button) end
            end
        end
    end
    if Bagnon and Bagnon.Frames and Bagnon.Frames.UpdateFrames then
        Bagnon.Frames:UpdateFrames()
    elseif Bagnon and Bagnon.UpdateFrames then
        Bagnon:UpdateFrames()
    end
end

-- NATIVE 3.3.5a ASYNCHRONOUS BAG SORTER ENGINE
local sortQueue = {}
local sortFrame = CreateFrame("Frame")
sortFrame:Hide()
sortFrame:SetScript("OnUpdate", function(self, elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < 0.05 then return end
    self.throttle = 0
    
    if #sortQueue == 0 then
        self:Hide()
        print("|cff00ff00[BagTags]: Sorting finished safely!|r")
        RefreshAllBags()
        return
    end
    
    local action = sortQueue[1]
    local _, _, l1 = GetContainerItemInfo(action.fB, action.fS)
    local _, _, l2 = GetContainerItemInfo(action.tB, action.tS)
    if l1 or l2 then return end
    
    table.remove(sortQueue, 1)
    PickupContainerItem(action.fB, action.fS)
    PickupContainerItem(action.tB, action.tS)
end)

local function RunCustomBagSort()
    if InCombatLockdown() then return end
    table.wipe(sortQueue)
    
    local slots = {}
    for bag = 0, 4 do
        local _, family = GetContainerNumFreeSlots(bag)
        if not family or family == 0 then
            for slot = 1, GetContainerNumSlots(bag) do
                table.insert(slots, {bag = bag, slot = slot})
            end
        end
    end
    
    local items = {}
    for _, s in ipairs(slots) do
        local link = GetContainerItemLink(s.bag, s.slot)
        if link then
            local name, _, rarity, _, _, iType = GetItemInfo(link)
            table.insert(items, {bag = s.bag, slot = s.slot, rarity = rarity or 0, name = name or "", iType = iType or ""})
        end
    end
    
    table.sort(items, function(a, b)
        if a.rarity ~= b.rarity then return a.rarity > b.rarity end
        if a.iType ~= b.iType then return a.iType < b.iType end
        return a.name < b.name
    end)
    
    for i, item in ipairs(items) do
        local targetSlot = slots[i]
        if targetSlot and (item.bag ~= targetSlot.bag or item.slot ~= targetSlot.slot) then
            table.insert(sortQueue, {fB = item.bag, fS = item.slot, tB = targetSlot.bag, tS = targetSlot.slot})
            for j = i + 1, #items do
                if items[j].bag == targetSlot.bag and items[j].slot == targetSlot.slot then
                    items[j].bag = item.bag
                    items[j].slot = item.slot
                    break
                end
            end
            item.bag = targetSlot.bag
            item.slot = targetSlot.slot
        end
    end
    
    if #sortQueue > 0 then
        print("|cff00ff00[BagTags]: Processing inventory sort queue...|r")
        sortFrame:Show()
    else
        print("|cff00ff00[BagTags]: Backpack is already perfectly ordered.|r")
    end
end

-- 3. CHAT REPORT LOGIC
local function HandleReport(subCommand)
    if subCommand == "sort" then
        RunCustomBagSort()
        return
    end

    if subCommand == "debug" then
        print("|cff00ff00[BagTags Debug]: Scanning main bag, slot 1...|r")
        local link = GetContainerItemLink(0, 1)
        if not link then
            print("|cffff0000[Error]: Slot 1 is empty!|r")
            return
        end
        local itemName, _, _, _, _, itemType = GetItemInfo(link)
        local ah = GetAuctionatorPrice(link, itemName)
        local de = GetAuctionatorDEPrice(link, itemName)
        print("Item Name: ", itemName or "nil")
        print("Atr_GetAuctionPrice: ", ah)
        print("Atr_GetDisenchantValue: ", de)
        return
    end

    local totalFreeSlots, totalMaxSlots = 0, 0
    local vendorCount, vendorValue = 0, 0
    local ahCount, ahValue = 0, 0
    local matsReportList = {}
    local classReportList = {}
    local ahReportList = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            totalMaxSlots = totalMaxSlots + numSlots
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if not link then
                    totalFreeSlots = totalFreeSlots + 1
                else
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    itemCount = itemCount or 1
                    local itemName, _, rarity, _, _, itemType, itemSubtype, _, _, _, itemVendorPrice = GetItemInfo(link)
                    if itemName then
                        local isSoulbound = IsItemSoulbound(bag, slot)
                        local isQuest = IsQuestItem(link)
                        local ahPrice = GetAuctionatorPrice(link, itemName)
                        local dePrice = GetAuctionatorDEPrice(link, itemName)
                        local singleVendorPrice = itemVendorPrice or 0

                        if not rarity then rarity = GRAY_QUALITY end

                        local realAhPrice = ahPrice * 0.95
                        local realDeValue = dePrice * 0.95
                        local depositRisk = (itemType == "Armor" or itemType == "Weapon") and (singleVendorPrice * 0.60) or 0

                        local maxVal = singleVendorPrice
                        local chosen = "V"

                        if realAhPrice > 0 and (realAhPrice - depositRisk) > maxVal then
                            maxVal = realAhPrice - depositRisk
                            chosen = "A"
                        end

                        if BagTagsConfig.showDisenchant and HasEnchanting() and (rarity == UNCOMMON_QUALITY or rarity == RARE_QUALITY) and (itemType == "Armor" or itemType == "Weapon") then
                            if realDeValue > maxVal and realDeValue > singleVendorPrice then
                                maxVal = realDeValue
                                chosen = "D"
                            end
                        end

                        if isSoulbound or isQuest then
                            -- Ignoruj
                        elseif chosen == "V" or rarity == GRAY_QUALITY then
                            vendorCount = vendorCount + itemCount
                            vendorValue = vendorValue + (singleVendorPrice * itemCount)
                        elseif chosen == "D" then
                            table.insert(ahReportList, { name = link .. " (DE)", count = itemCount, singleAh = dePrice })
                        else
                            ahCount = ahCount + itemCount
                            ahValue = ahValue + (ahPrice * 0.95 * itemCount)
                            table.insert(ahReportList, { name = link, count = itemCount, singleAh = ahPrice })
                        end

                        if itemType == "Tradeskill" or itemType == "Material" then
                            matsReportList[itemName] = (matsReportList[itemName] or 0) + itemCount
                        elseif itemSubtype == "Soul Shard" or itemName == "Soul Shard" or itemType == "Reagent" then
                            classReportList[itemName] = (classReportList[itemName] or 0) + itemCount
                        end
                    end
                end
            end
        end
    end

    if subCommand == "vendor" then
        print("|cff00ff00[BagTags]: Inventory Cleanup Analysis:|r")
        print(string.format("Trash & Safe Vendor items: %d pcs. (Value: %s)", vendorCount, FormatMoneyString(vendorValue)))
    elseif subCommand == "mats" then
        print("|cff00ff00[BagTags]: Bag Stock Status:|r")
        local matsStr = ""
        for name, count in pairs(matsReportList) do matsStr = matsStr .. name .. " (" .. count .. "x), " end
        if matsStr == "" then matsStr = "No crafting materials, " end
        print("Crafting: " .. string.sub(matsStr, 1, -3) .. ".")
        local alert = (totalFreeSlots < 5) and " (|cffff0000Time to empty your bags!|r)" or ""
        print(string.format("Free space: %d / %d slots.%s", totalFreeSlots, totalMaxSlots, alert))
    elseif subCommand == "ah" then
        print("|cff00ff00[BagTags]: Smart Market Actions (Fees Accounted):|r")
        if #ahReportList == 0 then
            print("No items currently clear the deposit & auction house fee risk threshold.")
        else
            for _, data in ipairs(ahReportList) do
                print(string.format("%s x%d (Gross Market: %s)", data.name, data.count, FormatMoneyString(data.singleAh)))
            end
        end
    else
        print("|cff00ff00[BagTags]|r Usage: /bg [vendor | mats | ah | sort | debug]")
    end
end

SLASH_BAGTAGS1 = "/bg"
SLASH_BAGTAGS2 = "/bagtags"
SlashCmdList["BAGTAGS"] = function(msg) HandleReport(string.lower(string.trim(msg or ""))) end

-- 4. INTERFACE OPTIONS UI - MAIN WINDOW (MANAGE TAGS)
local optionsPanel = CreateFrame("Frame", "BagTagsOptionsPanel", UIParent)
optionsPanel.name = "BagTags"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("BagTags Configuration")

local function CreateCheckboxWithDesc(parent, labelText, descText, configKey, yOffset)
    local name = "BagTags_" .. configKey
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, yOffset)
    _G[name .. "Text"]:SetText("|cffffffff" .. labelText .. "|r")
    
    -- Czysty FontString bez wadliwego szablonu single-line
    local desc = parent:CreateFontString(nil, "ARTWORK")
    desc:SetFont("Fonts\\FRIZQT__.TTF", 10)
    desc:SetTextColor(0.65, 0.65, 0.65, 1)
    desc:SetPoint("TOPLEFT", 45, yOffset - 22)
    desc:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
    desc:SetHeight(30) -- Dajemy przestrzeń na drugą linię
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetText(descText)

    cb:SetScript("OnShow", function(self) self:SetChecked(BagTagsConfig[configKey]) end)
    cb:SetScript("OnClick", function(self)
        BagTagsConfig[configKey] = not not self:GetChecked()
        RefreshAllBags()
    end)
    return cb
end

local function CreateDivider(parent, yOffset)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetTexture(0.25, 0.25, 0.25, 0.6)
    line:SetPoint("TOPLEFT", 20, yOffset)
    line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
end

-- Zwiększone yOffset z -55 na -65 dla idealnego rozłożenia pionowego dwuliniowych opisów
CreateCheckboxWithDesc(optionsPanel, "Enable Vendor & Trash Tags (V)", "Marks gray quality trash items and equipment pieces whose direct merchant sell value safely outclasses active Auction House listings.", "showVendor", -50)
CreateDivider(optionsPanel, -105)

CreateCheckboxWithDesc(optionsPanel, "Enable Quest Tags (Q)", "Highlights essential active quest inventory items with a distinct border to prevent accidental deleting or misplacing.", "showQuest", -125)
CreateDivider(optionsPanel, -180)

CreateCheckboxWithDesc(optionsPanel, "Enable Soulbound Tags (S)", "Displays a subtle label over soulbound equipment items, ensuring easy visually tracked character progression inventory slots.", "showSoulbound", -200)
CreateDivider(optionsPanel, -255)

CreateCheckboxWithDesc(optionsPanel, "Enable Auctionator Integration (A)", "Filters active marketplace items by analyzing continuous deposit risks against real-time 24-hour database prices.", "showMarket", -275)
CreateDivider(optionsPanel, -330)

CreateCheckboxWithDesc(optionsPanel, "Enable Disenchant Suggestions (D)", "Triggers contextual overlay markers for characters with the Enchanting profession when projected materials valuation yields reliable profit.", "showDisenchant", -350)

InterfaceOptions_AddCategory(optionsPanel)

-- 5. INTERFACE OPTIONS UI - SUB WINDOW (ABOUT)
local docPanel = CreateFrame("Frame", "BagTagsDocPanel", UIParent)
docPanel.name = "About"
docPanel.parent = optionsPanel.name

local docTitle = docPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
docTitle:SetPoint("TOPLEFT", 16, -16)
docTitle:SetText("About BagTags")

local docText = docPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
docText:SetPoint("TOPLEFT", 16, -50)
docText:SetPoint("RIGHT", docPanel, "RIGHT", -20, 0)
docText:SetJustifyH("LEFT")
docText:SetJustifyV("TOP")
docText:SetText("Type /bg or /bagtags in chat to generate explicit real-time status breakdowns:\n\n" ..
                "|cff00ff00/bg vendor|r - Performs inventory analysis on merchantable junk.\n" ..
                "|cff00ff00/bg mats|r - Generates immediate craft stock and materials audit.\n" ..
                "|cff00ff00/bg ah|r - Lists high valuation targets viable for active auction trades.\n" ..
                "|cff00ff00/bg sort|r - Triggers native asynchronous container sorting routines.\n" ..
                "|cff00ff00/bg debug|r - Troubleshoots internal database cross-reference bindings.\n\n" ..
                "Author: grombor\nVersion: 0.7.3")
InterfaceOptions_AddCategory(docPanel)

-- 6. MINIMAP BUTTON WITH DIRECT DRAG SUPPORT
local minimapBtn = CreateFrame("Button", "BagTagsMinimapButton", Minimap)
minimapBtn:SetWidth(32)
minimapBtn:SetHeight(32)
minimapBtn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")
icon:SetPoint("CENTER", 0, 0)

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetWidth(54)
border:SetHeight(54)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT", 0, 0)

local function UpdateButtonPosition()
    local currentAngle = BagTagsButtonPosition or 190
    minimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(currentAngle)), (80 * sin(currentAngle)) - 52)
end

minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", function(self)
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        local scale = Minimap:GetEffectiveScale()
        local x = (xmin * scale) - xpos + 70
        local y = ypos - (ymin * scale) - 70
        BagTagsButtonPosition = math.deg(math.atan2(y, x))
        UpdateButtonPosition()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(fself) self.isDragging = false fself:SetScript("OnUpdate", nil) end)
end)

minimapBtn:RegisterForClicks("AnyUp")
minimapBtn:SetScript("OnClick", function(self, button)
    if self.isDragging then return end
    
    if button == "LeftButton" then
        if InterfaceOptionsFrame_OpenToCategory then 
            InterfaceOptionsFrame_OpenToCategory(optionsPanel) 
        end
    elseif button == "RightButton" then
        RunCustomBagSort()
    end
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function() UpdateButtonPosition() end)

-- 7. UPDATE HOOKS FOR STANDARD BAGS AND BAGNON
if ContainerFrameItemButton_Update then hooksecurefunc("ContainerFrameItemButton_Update", UpdateButton) end
local function HookBagnon()
    if not Bagnon then return false end
    if Bagnon.Item and Bagnon.Item.Update then
        hooksecurefunc(Bagnon.Item, "Update", UpdateButton)
        return true
    elseif Bagnon.ItemSlot and Bagnon.ItemSlot.Update then
        hooksecurefunc(Bagnon.ItemSlot, "Update", UpdateButton)
        return true
    end
    return false
end
if not HookBagnon() then
    local waitFrame = CreateFrame("Frame")
    waitFrame:RegisterEvent("ADDON_LOADED")
    waitFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Bagnon" then HookBagnon() self:UnregisterEvent("ADDON_LOADED") end
    end)
end
