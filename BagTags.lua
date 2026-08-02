local addonName, BT = ...

-- Inicjalizacja struktur
BT.InventoryModule = BT.InventoryModule or {}
BT.knownItems = BT.knownItems or {}
BT.hasEnchanting = false

local isInitialized = false

-- ============================================================================
-- KONFLIKTY I OPCJE
-- ============================================================================

function BT:CheckConflicts()
	-- Nie pokazuj ostrzeżenia więcej niż raz
	if self.conflictsChecked then
		return
	end

	local detected = {}

	local conflictingAddons = {
		"AdiBags",
		"Bagnon",
		"ArkInventory",
		"OneBag3",
		"Inventorian",
		"Combuctor",
	}

	for _, addonName in ipairs(conflictingAddons) do
		if IsAddOnLoaded(addonName) then
			detected[#detected + 1] = addonName
		end
	end

	if #detected == 0 then
		return
	end

	self.conflictsChecked = true

	local msg = string.format(
		"|cff00ffcc[BagTags]|r |cffff0000Ostrzeżenie:|r Wykryto addon(y) modyfikujące torby: |cff00ffff%s|r. Mogą powodować konflikty z BagTags.",
		table.concat(detected, ", ")
	)

	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end

	if UIErrorsFrame then
		UIErrorsFrame:AddMessage("BagTags: wykryto konflikt addonów do toreb!", 1.0, 0.1, 0.1)
	end
end

function BT:RefreshTags()
	if self.InventoryModule and self.InventoryModule.RefreshAllOverlays then
		self.InventoryModule:RefreshAllOverlays()
	end
end

-- Replace BT.InventoryModule:RefreshAllOverlays
function BT.InventoryModule:RefreshAllOverlays()
	-- Zbuduj mapę aktualnych ilości itemów (slot-count) raz na początku odświeżania
	if BT and BT.BuildCurrentItemCounts then
		BT:BuildCurrentItemCounts()
	end

	for frameIndex = 1, (NUM_CONTAINER_FRAMES or 13) do
		local frame = _G["ContainerFrame" .. frameIndex]

		if frame and frame:IsShown() then
			local size = frame.size or 0
			local bagID = frame:GetID()

			for itemIndex = 1, size do
				local button = _G[frame:GetName() .. "Item" .. itemIndex]

				if button and button:IsShown() then
					local slotID = button:GetID()

					if slotID and slotID > 0 then
						BT:UpdateSlotOverlay(button, bagID, slotID)
					end
				end
			end
		end
	end
end

function BT:SetupOptions()
	if isInitialized then
		return
	end
	BagTagsConfig = BagTagsConfig or {}

	local panel = CreateFrame("Frame", "BagTagsOptionsPanel", UIParent)
	panel.name = "BagTags"

	local tagsPanel = CreateFrame("Frame", "BagTagsTagsPanel", UIParent)
	tagsPanel.name = "Tags"
	tagsPanel.parent = "BagTags"

	local soulboundCheck =
		CreateFrame("CheckButton", "BagTagsShowSoulbound", tagsPanel, "InterfaceOptionsCheckButtonTemplate")

	soulboundCheck:SetPoint("TOPLEFT", 16, -20)
	local text = _G[soulboundCheck:GetName() .. "Text"]
	if text then
		text:SetText("Show tag S (Soulbound)")
	end

	soulboundCheck:SetChecked(BagTagsConfig.showSoulbound)

	soulboundCheck:SetScript("OnClick", function(self)
		BagTagsConfig.showSoulbound = self:GetChecked()
		BT:RefreshTags()
	end)

	local auctionCheck =
		CreateFrame("CheckButton", "BagTagsShowAuction", tagsPanel, "InterfaceOptionsCheckButtonTemplate")

	auctionCheck:SetPoint("TOPLEFT", soulboundCheck, "BOTTOMLEFT", 0, -10)

	local auctionText = _G[auctionCheck:GetName() .. "Text"]
	if auctionText then
		auctionText:SetText("Show tag A (Auction House)")
	end

	auctionCheck:SetChecked(BagTagsConfig.showAuction)

	auctionCheck:SetScript("OnClick", function(self)
		BagTagsConfig.showAuction = self:GetChecked()
		BT:RefreshTags()
	end)

	local vendorCheck =
		CreateFrame("CheckButton", "BagTagsShowVendor", tagsPanel, "InterfaceOptionsCheckButtonTemplate")

	vendorCheck:SetPoint("TOPLEFT", auctionCheck, "BOTTOMLEFT", 0, -10)

	local vendorText = _G[vendorCheck:GetName() .. "Text"]
	if vendorText then
		vendorText:SetText("Show tag V (Vendor)")
	end

	vendorCheck:SetChecked(BagTagsConfig.showVendor)

	vendorCheck:SetScript("OnClick", function(self)
		BagTagsConfig.showVendor = self:GetChecked()
		BT:RefreshTags()
	end)

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("BagTags Configuration")

	local inventoryCheck =
		CreateFrame("CheckButton", "BagTagsUseInventoryWindow", panel, "InterfaceOptionsCheckButtonTemplate")

	inventoryCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)

	local inventoryText = _G[inventoryCheck:GetName() .. "Text"]
	if inventoryText then
		inventoryText:SetText("Use grouped inventory window")
	end

	inventoryCheck:SetChecked(BagTagsConfig.useInventoryWindow)

	inventoryCheck:SetScript("OnClick", function(self)
		BagTagsConfig.useInventoryWindow = not not self:GetChecked()
	end)

	local opacitySlider = CreateFrame("Slider", "BagTagsOpacitySlider", panel, "OptionsSliderTemplate")

	-- Opacity
	opacitySlider:SetPoint("TOPLEFT", inventoryCheck, "BOTTOMLEFT", 0, -40)
	opacitySlider:SetWidth(140)
	opacitySlider:SetMinMaxValues(0.1, 1.0)
	opacitySlider:SetValueStep(0.05)
	opacitySlider:SetValue(BagTagsConfig.opacity or 0.9)

	_G[opacitySlider:GetName() .. "Text"]:SetText("Opacity")
	_G[opacitySlider:GetName() .. "Low"]:SetText("0.1")
	_G[opacitySlider:GetName() .. "High"]:SetText("1.0")

	opacitySlider:SetScript("OnValueChanged", function(self, value)
		BagTagsConfig.opacity = value

		if BT.InventoryModule and BT.InventoryModule.ApplyOpacity then
			BT.InventoryModule:ApplyOpacity()
		end
	end)

	local scaleSlider = CreateFrame("Slider", "BagTagsScaleSlider", panel, "OptionsSliderTemplate")
	-- Scale
	scaleSlider:SetPoint("TOPLEFT", inventoryCheck, "BOTTOMLEFT", 220, -40)
	scaleSlider:SetWidth(140)
	scaleSlider:SetMinMaxValues(0.5, 1.5)
	scaleSlider:SetValueStep(0.05)
	scaleSlider:SetValue(BagTagsConfig.scale or 1.0)

	_G[scaleSlider:GetName() .. "Text"]:SetText("Skala okna")
	_G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
	_G[scaleSlider:GetName() .. "High"]:SetText("1.5")

	scaleSlider:SetScript("OnValueChanged", function(self, value)
		BagTagsConfig.scale = value
		if BT.InventoryModule and BT.InventoryModule.ApplyScale then
			BT.InventoryModule:ApplyScale()
		end
	end)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
		InterfaceOptions_AddCategory(tagsPanel)
	elseif Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, "BagTags")
		Settings.RegisterAddOnCategory(category)

		local tagsCategory = Settings.RegisterCanvasLayoutCategory(tagsPanel, "Tags")
		tagsCategory.parent = category
		Settings.RegisterAddOnCategory(tagsCategory)
	end

	isInitialized = true
end

function BT:SaveFramePosition(name, point, relPoint, x, y)
	BagTagsConfig = BagTagsConfig or {}
	BagTagsConfig.positions = BagTagsConfig.positions or {}
	BagTagsConfig.positions[name] = { point, relPoint, x, y }
end

-- ============================================================================
-- MINIMAPA
-- ============================================================================

function BT:UpdateMinimapPosition()
	local minimapButton = _G["BagTagsMinimapButton"]
	if not minimapButton or not BagTagsConfig or not BagTagsConfig.minimapPos then
		return
	end
	local angle = math.rad(BagTagsConfig.minimapPos)
	local x = math.cos(angle) * 80
	local y = math.sin(angle) * 80
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function BT:SetupMinimap()
	local minimapButton = _G["BagTagsMinimapButton"]
		or CreateFrame("Button", "BagTagsMinimapButton", Minimap, "MinimapButtonTemplate")
	minimapButton:SetSize(31, 31)
	minimapButton:SetFrameLevel(8)
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local icon = _G["BagTagsMinimapButtonIcon"] or minimapButton:CreateTexture("BagTagsMinimapButtonIcon", "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")

	if not minimapButton.border then
		local border = minimapButton:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		border:SetSize(53, 53)
		border:SetPoint("TOPLEFT")
		minimapButton.border = border
	end

	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", function()
			local xpos, ypos = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()

			-- Obliczamy środek minimapy na ekranie
			local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
			local mX = xmin + (Minimap:GetWidth() / 2)
			local mY = ymin + (Minimap:GetHeight() / 2)

			-- Wektor OD środka DO kursora (poprawny zwrot):
			local x = (xpos / scale) - mX
			local y = (ypos / scale) - mY

			BagTagsConfig.minimapPos = math.deg(math.atan2(y, x))
			BT:UpdateMinimapPosition()
		end)
	end)

	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end)

	minimapButton:RegisterForClicks("AnyUp")

	minimapButton:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			if BagTagsConfig and BagTagsConfig.useInventoryWindow then
				BT:ToggleBagTags()
			else
				if OpenAllBags then
					OpenAllBags()
				elseif ToggleAllBags then
					ToggleAllBags()
				else
					ToggleBackpack()
				end
			end
		else
			if InterfaceOptionsFrame_OpenToCategory then
				InterfaceOptionsFrame_OpenToCategory("BagTags")
			elseif Settings then
				Settings.OpenToCategory("BagTags")
			end
		end
	end)

	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cff00ffccBagTags|r")
		GameTooltip:AddLine("|cffffffffLeft MB:|r Open Bags")
		GameTooltip:AddLine("|cffffffffRigth MB:|r Settings")
		GameTooltip:Show()
	end)
	minimapButton:SetScript("OnLeave", GameTooltip_Hide)

	BT:UpdateMinimapPosition()
end

-- ============================================================================
-- REJESTRACJA I SKANOWANIE
-- ============================================================================

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, event, arg1)
	if arg1 ~= addonName then
		return
	end

	BagTagsConfig = BagTagsConfig or {}

	BagTagsConfig.positions = BagTagsConfig.positions or {}
	BagTagsConfig.minimapPos = BagTagsConfig.minimapPos or 45
	BagTagsConfig.opacity = BagTagsConfig.opacity or 0.9
	BagTagsConfig.scale = BagTagsConfig.scale or 1.0

	-- Migracja starych ustawień
	if BagTagsConfig.showAuction == nil and BagTagsConfig.showMarket ~= nil then
		BagTagsConfig.showAuction = BagTagsConfig.showMarket
	end

	-- Domyślne ustawienia
	if BagTagsConfig.showSoulbound == nil then
		BagTagsConfig.showSoulbound = true
	end

	if BagTagsConfig.showAuction == nil then
		BagTagsConfig.showAuction = true
	end

	if BagTagsConfig.showDisenchant == nil then
		BagTagsConfig.showDisenchant = true
	end

	if BagTagsConfig.showVendor == nil then
		BagTagsConfig.showVendor = true
	end

	-- NOWA OPCJA
	if BagTagsConfig.useInventoryWindow == nil then
		BagTagsConfig.useInventoryWindow = true
	end

	-- Usunięcie starej opcji po migracji
	BagTagsConfig.showMarket = nil

	BT:CheckConflicts()
	BT:SetupOptions()
	BT:SetupMinimap()
	BT:CheckProfessions()

	-- Ustaw baseline: traktujemy obecny stan ekwipunku jako "znany"
	BT:SnapshotCurrentItems()

	self:UnregisterEvent("ADDON_LOADED")
end)

-- Replace / Implement: BT:BuildCurrentItemCounts (slot-count) + last-seen timestamps
function BT:BuildCurrentItemCounts()
	BT._currentCounts = BT._currentCounts or {}
	BT._lastSeen = BT._lastSeen or {}
	table.wipe(BT._currentCounts)
	local now = GetTime()

	for bag = 0, 4 do
		local numSlots = self:GetContainerNumSlots(bag) or 0
		for slot = 1, numSlots do
			local link = self:SafeGetContainerItemLink(bag, slot)
			if link then
				local itemID = tonumber(string.match(link, "item:(%d+)"))
				if itemID then
					-- slot-count: każdy zajęty slot liczy jako 1
					BT._currentCounts[itemID] = (BT._currentCounts[itemID] or 0) + 1
					-- zapisz kiedy ostatnio widziano ten itemID
					BT._lastSeen[itemID] = now
				end
			end
		end
	end
end

-- Zwraca zawsze dwa argumenty: (texture, count)

function BT:GetContainerItemInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if not info then
			return nil, 0
		end
		return info.iconFileID, info.stackCount or 0
	elseif GetContainerItemInfo then
		local texture, itemCount = GetContainerItemInfo(bag, slot)
		return texture, itemCount or 0
	end
	return nil, 0
end

function BT:GetContainerItemLink(bag, slot)
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	end

	return GetContainerItemLink(bag, slot)
end

function BT:GetContainerNumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag)
	end

	return GetContainerNumSlots(bag) or 0
end

function BT:GetContainerNumFreeSlots(bag)
	if C_Container and C_Container.GetContainerNumFreeSlots then
		return C_Container.GetContainerNumFreeSlots(bag)
	end

	return GetContainerNumFreeSlots(bag)
end

function BT:CheckProfessions()
	BT.hasEnchanting = false
	local numSkills = GetNumSkillLines and GetNumSkillLines() or 0
	for i = 1, numSkills do
		local skillName = GetSkillLineInfo(i)
		if skillName == "Enchanting" or skillName == "Zaklinanie" then
			BT.hasEnchanting = true
			break
		end
	end
end

function BT:SafeGetContainerItemLink(bag, slot)
	if not BT or not BT.GetContainerItemLink then
		return nil
	end

	local ok, link = pcall(BT.GetContainerItemLink, BT, bag, slot)

	if ok then
		return link
	end

	return nil
end

function BT:SafeGetContainerItemInfo(bag, slot)
	if not BT or not BT.GetContainerItemInfo then
		return nil, 0
	end

	local ok, texture, count = pcall(BT.GetContainerItemInfo, BT, bag, slot)

	if ok then
		return texture, count
	end

	return nil, 0
end

function BT:GetSlotKey(bag, slot)
	local link = self:GetContainerItemLink(bag, slot)
	if not link then
		return nil
	end

	local itemID = string.match(link, "item:(%d+)")
	return string.format("%d_%d_%s", bag, slot, itemID or "0")
end

-- Replace / Implement: BT:SnapshotCurrentItems (slot-count baseline)
function BT:SnapshotCurrentItems()
	BT.knownItems = BT.knownItems or {}
	table.wipe(BT.knownItems)

	for bag = 0, 4 do
		local numSlots = self:GetContainerNumSlots(bag) or 0
		for slot = 1, numSlots do
			local link = self:SafeGetContainerItemLink(bag, slot)
			if link then
				local itemID = tonumber(string.match(link, "item:(%d+)"))
				if itemID then
					-- slot-count snapshot: liczymy ile slotów zawiera dany itemID
					BT.knownItems[itemID] = (BT.knownItems[itemID] or 0) + 1
				end
			end
		end
	end
end

function BT:GetItemTag(bag, slot)
	local link = self:GetContainerItemLink(bag, slot)
	if not link then
		return nil
	end

	-- Jeśli mamy itemID i policzone current/known, oznacz jako "New Items" gdy current > known
	local itemID = tonumber(string.match(link, "item:(%d+)"))
	if itemID then
		local current = (BT._currentCounts and BT._currentCounts[itemID]) or 0
		local known = BT.knownItems[itemID] or 0
		if current > known then
			return "New Items"
		end
	end

	-- dalej klasyfikacja według itemClass (bez zmian)
	local _, _, _, _, _, itemClass = GetItemInfo(link)
	if itemClass == "Consumable" or itemClass == "Materiały eksploatacyjne" then
		return "Consumables"
	end
	if itemClass == "Trade Goods" or itemClass == "Tradeskill" or itemClass == "Rzemiosło" then
		return "Tradeskill"
	end
	if itemClass == "Quest" or itemClass == "Misja" then
		return "Quest"
	end

	return itemClass or "Miscellaneous"
end

local scanner = CreateFrame("GameTooltip", "BagTagsScanner", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

function BT:IsItemSoulbound(bag, slot)
    -- Preferencyjny check przez C_Container.GetContainerItemInfo (jeśli dostępne)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)

        if info then
            -- Różne wersje API mogą wystawiać pola z bind info
            if info.itemIsBound == true or info.isBound == true then
                return true
            end

            if info.itemBindType and (
                info.itemBindType == "BIND_ON_PICKUP" or
                info.itemBindType == "BOP"
            ) then
                return true
            end

            -- Czasem jest pole bindType lub podobne
            if info.bindType and (
                info.bindType == "BIND_ON_PICKUP" or
                info.bindType == "BOP"
            ) then
                return true
            end
        end
    end

    -- Fallback: skanowanie tooltipu (działa niezależnie od lokalizacji)
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)

    for i = 1, scanner:NumLines() do
        local line = _G["BagTagsScannerTextLeft" .. i]
        local text = line and line:GetText()

        if text then
            -- Najpewniejsze: porównanie z lokalizowanymi stałymi
            if (type(ITEM_SOULBOUND) == "string" and text == ITEM_SOULBOUND)
                or (type(ITEM_BIND_ON_PICKUP) == "string" and text == ITEM_BIND_ON_PICKUP)
            then
                return true
            end

            -- Account Bound nie traktujemy jako przypisane do postaci
            if type(ITEM_BIND_TO_ACCOUNT) == "string" and text == ITEM_BIND_TO_ACCOUNT then
                return false
            end

            -- Dodatkowe dopasowania dla różnych lokalizacji
            if string.find(text, "Soulbound")
                or string.find(text, "Przypisany")
                or string.find(text, "Przypisane")
            then
                if not (
                    type(ITEM_BIND_TO_ACCOUNT) == "string"
                    and text == ITEM_BIND_TO_ACCOUNT
                ) then
                    return true
                end
            end
        end
    end

    return false
end

-- ============================================================================
-- OVERLAYS (A / D / V / S)
-- ============================================================================

local function GetOrCreateOverlay(button)
	if button.BagTagsOverlay then
		button.BagTagsOverlay:SetParent(button)
		return button.BagTagsOverlay
	end

	local overlay = CreateFrame("Frame", nil, button, "BackdropTemplate")
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 15)

	overlay:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})

	local label = overlay:CreateFontString(nil, "OVERLAY")
	label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	label:SetShadowColor(0, 0, 0, 1)
	label:SetShadowOffset(1, -1)
	label:SetPoint("TOPLEFT", overlay, "TOPLEFT", 2, -2)

	overlay.label = label
	button.BagTagsOverlay = overlay
	return overlay
end

local function SetOverlayStyle(overlay, borderColor, labelColor, letter)
	if letter == "S" then
		overlay:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
		labelColor = { r = 0.1, g = 0.6, b = 0.9, a = 1 }
	else
		overlay:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
	end

	overlay.label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, THICKOUTLINE")
	overlay.label:SetTextColor(labelColor.r, labelColor.g, labelColor.b, labelColor.a)
	overlay.label:SetText(letter)
	overlay:Show()
end

function BT:GetValueTag(bag, slot)
    local link = self:SafeGetContainerItemLink(bag, slot)

    if not link then
        return nil
    end

    local itemName,
        _,
        quality,
        _,
        _,
        itemType,
        _,
        _,
        _,
        _,
        itemVendorPrice = GetItemInfo(link)

    quality = quality or 0
    local vendorPrice = itemVendorPrice or 0

    if self:IsItemSoulbound(bag, slot) then
        return "S"
    end

    local itemID = tonumber(string.match(link, "item:(%d+)"))

    if itemID then
        local current = (BT._currentCounts and BT._currentCounts[itemID]) or 0
        local known = BT.knownItems[itemID] or 0

        if current > known then
            return "N"
        end
    end

    local ahPrice = 0
    local deValue = 0

    if itemName then
        if Atr_GetAuctionPrice then
            local ok, value = pcall(Atr_GetAuctionPrice, itemName)

            if ok then
                ahPrice = value or 0
            end
        end

        if Atr_GetDisenchantValue then
            local ok, value = pcall(Atr_GetDisenchantValue, itemName)

            if ok then
                deValue = value or 0
            end
        end
    end

    local netAhPrice = ahPrice - (ahPrice * 0.05)

    local bestValue = vendorPrice
    local tag = "V"

    if ahPrice > 0 and netAhPrice > vendorPrice then
        bestValue = netAhPrice
        tag = "A"
    end

    if BT.hasEnchanting
        and (quality == 2 or quality == 3)
        and (itemType == "Armor" or itemType == "Weapon")
        and deValue > bestValue
    then
        tag = "D"
    end

    return tag
end

-- Zastąp istniejącą funkcję BT:UpdateSlotOverlay tą wersją (prosta, deterministyczna logika merchant)
function BT:UpdateSlotOverlay(slotFrame, bagID, slotID)
    if not slotFrame then
        return
    end

    if slotFrame.BagTagsOverlay then
        slotFrame.BagTagsOverlay:Hide()
    end

    local texture = select(1, BT:GetContainerItemInfo(bagID, slotID))
    if not texture then
        return
    end

    local link = BT:SafeGetContainerItemLink(bagID, slotID)
    if not link or not BagTagsConfig then
        return
    end

    local itemName, _, quality, _, _, itemType, _, _, _, _, itemVendorPrice = GetItemInfo(link)
    quality = quality or 0
    local vendorPrice = itemVendorPrice or 0

    -- Soulbound ma najwyższy priorytet (bez zmian)
    if BagTagsConfig.showSoulbound and BT:IsItemSoulbound(bagID, slotID) then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.53, g = 0.12, b = 0.77, a = 1 }, { r = 0.90, g = 0.60, b = 1.0, a = 1 }, "S")
        return
    end

    -- Ensure counts exist for "New Items"
    if not BT._currentCounts then
        BT:BuildCurrentItemCounts()
    end

    -- New Items (bez zmian)
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if itemID then
        local current = (BT._currentCounts and BT._currentCounts[itemID]) or 0
        local known = BT.knownItems[itemID] or 0
        if current > known then
            local overlay = GetOrCreateOverlay(slotFrame)
            SetOverlayStyle(overlay, { r = 1.0, g = 0.5, b = 0.0, a = 1 }, { r = 1.0, g = 0.95, b = 0.6, a = 1 }, "N")
            return
        end
    end

    -- Pobierz ceny (zewnętrzne funkcje, bez zmian)
    local ahPrice = 0
    local deValue = 0
    if itemName then
        if Atr_GetAuctionPrice then
            local ok, value = pcall(Atr_GetAuctionPrice, itemName)
            if ok then ahPrice = value or 0 end
        end
        if Atr_GetDisenchantValue then
            local ok, value = pcall(Atr_GetDisenchantValue, itemName)
            if ok then deValue = value or 0 end
        end
    end

    -- Prosta, jednoznaczna reguła wyboru taga:
    -- 1) Porównaj trzech kandydatów: vendorPrice, netAhPrice (95%), deValue.
    -- 2) Wybierz najwyższą efektywną wartość, z zastrzeżeniami:
    --    - D można brać pod uwagę tylko gdy mamy enchanting i item jest Armor/Weapon i quality w [2,3].
    --    - Pokazuj tylko te tagi, które są w ustawieniach (showAuction/showDisenchant/showVendor).
    local netAh = (ahPrice or 0) * 0.95
    local bestValue = vendorPrice or 0
    local chosen = nil

    -- Auction
    if BagTagsConfig.showAuction and netAh > bestValue and netAh > 0 then
        bestValue = netAh
        chosen = "A"
    end

    -- Disenchant (tylko gdy sensowne)
    if BagTagsConfig.showDisenchant and BT.hasEnchanting and (quality == 2 or quality == 3)
       and (itemType == "Armor" or itemType == "Weapon")
       and deValue > bestValue and deValue > 0 then
        bestValue = deValue
        chosen = "D"
    end

    -- Vendor fallback (wybierz Vendor gdy nic lepszego nie było)
    if BagTagsConfig.showVendor and chosen == nil and vendorPrice > 0 then
        chosen = "V"
    end

    -- Rysowanie prostych tagów
    if chosen == "A" then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.1, g = 1, b = 0.1, a = 1 }, { r = 0.4, g = 1, b = 0.4, a = 1 }, "A")
        return
    elseif chosen == "D" then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.8, g = 0.3, b = 0.8, a = 1 }, { r = 1.0, g = 0.5, b = 1.0, a = 1 }, "D")
        return
    elseif chosen == "V" then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.9, g = 0.8, b = 0.2, a = 1 }, { r = 1.0, g = 0.9, b = 0.4, a = 1 }, "V")
        return
    end

    -- Opcjonalny fallback: poor quality -> Vendor (jeśli włączone)
    if quality == 0 and BagTagsConfig.showVendor then
        local overlay = GetOrCreateOverlay(slotFrame)
        SetOverlayStyle(overlay, { r = 0.9, g = 0.8, b = 0.2, a = 1 }, { r = 1.0, g = 0.9, b = 0.4, a = 1 }, "V")
        return
    end
end

function BT:FormatMoney(amount)
	if not amount or amount <= 0 then
		return "|cffeda55f0c|r"
	end
	local gold = math.floor(amount / 10000)
	local silver = math.floor((amount % 10000) / 100)
	local copper = amount % 100
	local text = ""
	if gold > 0 then
		text = text .. "|cffffd700" .. gold .. "g |r"
	end
	if silver > 0 then
		text = text .. "|cffc7c7c7" .. silver .. "s |r"
	end
	if copper > 0 or text == "" then
		text = text .. "|cffeda55f" .. copper .. "c|r"
	end
	return text
end

local overlayEvents = CreateFrame("Frame")
overlayEvents:RegisterEvent("BAG_UPDATE")
overlayEvents:RegisterEvent("BAG_UPDATE_DELAYED")

local pendingRefresh = false
local THROTTLE_SECONDS = 0.15

local function ScheduleRefresh()
	if pendingRefresh then
		return
	end
	pendingRefresh = true
	C_Timer.After(THROTTLE_SECONDS, function()
		pendingRefresh = false
		if BT.InventoryModule and BT.InventoryModule.RefreshAllOverlays then
			BT.InventoryModule:RefreshAllOverlays()
		end
	end)
end

overlayEvents:SetScript("OnEvent", function(self, event, ...)
	-- Throttleujemy pełne odświeżenie, aby uniknąć wielokrotnych skanów podczas szybkich zdarzeń
	ScheduleRefresh()
end)

if type(OpenBackpack) == "function" then
	hooksecurefunc("OpenBackpack", function()
		C_Timer.After(0.1, function()
			if BT.InventoryModule and BT.InventoryModule.RefreshAllOverlays then
				BT.InventoryModule:RefreshAllOverlays()
			end
		end)
	end)
end

if type(OpenAllBags) == "function" then
	hooksecurefunc("OpenAllBags", function()
		C_Timer.After(0.1, function()
			if BT.InventoryModule and BT.InventoryModule.RefreshAllOverlays then
				BT.InventoryModule:RefreshAllOverlays()
			end
		end)
	end)
end

local autoSnapshotFrame = CreateFrame("Frame")
autoSnapshotFrame:RegisterEvent("LOOT_CLOSED")
autoSnapshotFrame:RegisterEvent("MAIL_SHOW")
autoSnapshotFrame:RegisterEvent("MERCHANT_CLOSED")

autoSnapshotFrame:SetScript("OnEvent", function(self, event, ...)
	if BT and BT.SnapshotCurrentItems then
		-- ustaw baseline i odśwież counts + nakładki
		BT:SnapshotCurrentItems()
		if BT.BuildCurrentItemCounts then
			BT:BuildCurrentItemCounts()
		end
		if BT.InventoryModule and BT.InventoryModule.RefreshAllOverlays then
			BT.InventoryModule:RefreshAllOverlays()
		end
	end
end)

-- prosty CLI do testów i ręcznego ustawiania snapshotu
SLASH_BAGTAGS1 = "/bagtags"
SlashCmdList["BAGTAGS"] = function(msg)
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")
	if cmd == "snapshot" or cmd == "markread" then
		if BT and BT.SnapshotCurrentItems then
			BT:SnapshotCurrentItems()
			print("BagTags: snapshot wykonany (wszystkie przedmioty oznaczone jako znane).")
			if BT.BuildCurrentItemCounts then
				BT:BuildCurrentItemCounts()
			end
			if BT.InventoryModule and BT.InventoryModule.RefreshAllOverlays then
				BT.InventoryModule:RefreshAllOverlays()
			end
		else
			print("BagTags: funkcja SnapshotCurrentItems nieznaleziona.")
		end
		return
	end

	if cmd == "refresh" then
		if BT and BT.InventoryModule and BT.InventoryModule.RefreshAllOverlays then
			BT.InventoryModule:RefreshAllOverlays()
			print("BagTags: odświeżono nakładki.")
		else
			print("BagTags: RefreshAllOverlays niedostępne.")
		end
		return
	end

	if cmd == "show" and tonumber(arg) then
		local id = tonumber(arg)
		local cur = (BT._currentCounts and BT._currentCounts[id]) or 0
		local known = (BT.knownItems and BT.knownItems[id]) or 0
		print(("BagTags: itemID=%d current=%d known=%d"):format(id, cur, known))
		return
	end

	print("/bagtags snapshot|markread  — oznacz aktualne jako znane")
	print("/bagtags refresh              — wymuś odświeżenie nakładek")
	print("/bagtags show <itemID>        — pokaż current/known dla itemID")
end

-- Sell Vendor button - dopasowane do BT API (BT:GetValueTag)
local DEBUG = true
local NUM_BAG_SLOTS_MAX = 4 -- dostosuj jeśli masz inne baki

local function Log(msg)
  if DEBUG and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99BagTagsSell:|r " .. tostring(msg))
  end
end

-- Odczyt taga — najpierw BT:GetValueTag, potem fallbacky
local function GetTagForSlot(bag, slot)
  local link = nil
  if BT and type(BT.SafeGetContainerItemLink) == "function" then
    link = BT:SafeGetContainerItemLink(bag, slot)
  else
    link = GetContainerItemLink(bag, slot)
  end

  -- 1) preferuj BT:GetValueTag jeśli dostępne
  if BT and type(BT.GetValueTag) == "function" then
    local ok, tag = pcall(BT.GetValueTag, BT, bag, slot)
    if ok and tag then return tag end
  end

  -- 2) jeśli istnieje metoda BT.GetTag (rzadko), spróbuj
  if BT and type(BT.GetTag) == "function" then
    local ok, tag = pcall(BT.GetTag, BT, bag, slot)
    if ok and tag then return tag end
  end

  -- 3) fallback: BagTags global (stare nazwisko)
  if BagTags then
    -- możliwe API BagTags:GetTag / GetItemTag / tags table
    local try = function(fn, ...)
      if type(fn) == "function" then
        local ok, res = pcall(fn, ...)
        if ok and res then return res end
      end
      return nil
    end

    local tag = try(function(...) return BagTags.GetTag and BagTags.GetTag(BagTags, ...) end, bag, slot)
    if tag then return tag end
    tag = try(BagTags.GetItemTag, link)
    if tag then return tag end

    if link then
      local itemId = tonumber(link:match("item:(%d+):"))
      if itemId then
        if BagTags.tags and BagTags.tags[itemId] then return BagTags.tags[itemId] end
        if BagTags.items and BagTags.items[itemId] and BagTags.items[itemId].tag then return BagTags.items[itemId].tag end
        if BagTags.db and BagTags.db.global and BagTags.db.global.tags and BagTags.db.global.tags[itemId] then
          return BagTags.db.global.tags[itemId]
        end
      end
    end
  end

  return nil
end

local function IsVendorTag(tag)
  if not tag then return false end
  if type(tag) == "string" then
    local t = tag:lower()
    return t == "v" or t == "vendor"
  end
  return false
end

local function ScanForVendorItems()
  local found = {}
  for bag = 0, NUM_BAG_SLOTS_MAX do
    local slots = GetContainerNumSlots(bag)
    if slots and slots > 0 then
      for slot = 1, slots do
        local link = (BT and type(BT.SafeGetContainerItemLink) == "function") and BT:SafeGetContainerItemLink(bag, slot) or GetContainerItemLink(bag, slot)
        if link then
          local tag = GetTagForSlot(bag, slot)
          if IsVendorTag(tag) then
            table.insert(found, {bag=bag, slot=slot, link=link, tag=tag})
          else
            if DEBUG then
              Log(("slot %d:%d tag=%s link=%s"):format(bag, slot, tostring(tag), link))
            end
          end
        end
      end
    end
  end
  return found
end

-- UI: przycisk
local sellBtn = CreateFrame("Button", "BagTags_SellVendorBtn", UIParent, "UIPanelButtonTemplate")
sellBtn:SetSize(130, 22)
sellBtn:SetPoint("CENTER", UIParent, "CENTER", 0, -200) -- dopasuj parent/pozycję do BagTagsFrame
sellBtn:SetText("Sell Vendor")
sellBtn:Hide()

-- Kolejka sprzedaży
local sellQueue = {}
local sellFrame = CreateFrame("Frame")
local sellInterval = 0.15
local sellTimer = 0

local function StartSellingQueue()
  if not MerchantFrame or not MerchantFrame:IsShown() then
    UIErrorsFrame:AddMessage("Open a merchant first to sell items.")
    Log("Merchant not open - cannot start selling")
    return
  end
  if #sellQueue == 0 then
    Log("Brak itemów do sprzedaży w kolejce")
    return
  end
  sellTimer = 0
  sellFrame:SetScript("OnUpdate", function(self, elapsed)
    sellTimer = sellTimer + elapsed
    if sellTimer >= sellInterval then
      sellTimer = 0
      local entry = table.remove(sellQueue, 1)
      if entry then
        local currentLink = (BT and type(BT.SafeGetContainerItemLink) == "function") and BT:SafeGetContainerItemLink(entry.bag, entry.slot) or GetContainerItemLink(entry.bag, entry.slot)
        if currentLink then
          UseContainerItem(entry.bag, entry.slot)
          Log(("Selling %s from %d:%d"):format(entry.link, entry.bag, entry.slot))
        else
          Log(("Item nie istnieje już w %d:%d"):format(entry.bag, entry.slot))
        end
      else
        sellFrame:SetScript("OnUpdate", nil)
        Log("Koniec sprzedaży")
      end
    end
  end)
end

sellBtn:SetScript("OnClick", function()
  if not MerchantFrame or not MerchantFrame:IsShown() then
    UIErrorsFrame:AddMessage("Open a merchant first to sell items.")
    return
  end
  sellQueue = {}
  local found = ScanForVendorItems()
  for _,e in ipairs(found) do table.insert(sellQueue, e) end
  if #sellQueue > 0 then
    StartSellingQueue()
  else
    UIErrorsFrame:AddMessage("No vendor-tagged items found.")
  end
end)

-- Widoczność kontrola
local function UpdateSellButtonVisibility()
  local found = ScanForVendorItems()
  if #found > 0 then
    sellBtn:Show()
    if MerchantFrame and MerchantFrame:IsShown() then
      sellBtn:Enable()
    else
      sellBtn:Disable()
    end
    Log(("Znaleziono %d itemów z tagiem V"):format(#found))
  else
    sellBtn:Hide()
    Log("Nie znaleziono itemów z tagiem V")
  end
end

-- Eventy
local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")

ev:SetScript("OnEvent", function(self, event, ...)
  if event == "MERCHANT_SHOW" then
    sellBtn:Enable()
    UpdateSellButtonVisibility()
  elseif event == "MERCHANT_CLOSED" then
    sellBtn:Disable()
    sellQueue = {}
    sellFrame:SetScript("OnUpdate", nil)
  else
    UpdateSellButtonVisibility()
  end
end)

C_Timer.After(1, UpdateSellButtonVisibility)
