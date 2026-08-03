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

	-- Po odświeżeniu nakładek, odśwież przycisk Sell Vendor (jeśli dostępny)
	if BT and type(BT.UpdateSellButton) == "function" then
		C_Timer.After(0.03, function()
			BT:UpdateSellButton()
		end)
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
	local item = BT:GetItemData(link)

	local itemClass = item.itemType

	local quality = item.quality
	local itemType = item.itemType
	local vendorPrice = item.vendorPrice

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

			if info.itemBindType and (info.itemBindType == "BIND_ON_PICKUP" or info.itemBindType == "BOP") then
				return true
			end

			-- Czasem jest pole bindType lub podobne
			if info.bindType and (info.bindType == "BIND_ON_PICKUP" or info.bindType == "BOP") then
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
			if
				(type(ITEM_SOULBOUND) == "string" and text == ITEM_SOULBOUND)
				or (type(ITEM_BIND_ON_PICKUP) == "string" and text == ITEM_BIND_ON_PICKUP)
			then
				return true
			end

			-- Account Bound nie traktujemy jako przypisane do postaci
			if type(ITEM_BIND_TO_ACCOUNT) == "string" and text == ITEM_BIND_TO_ACCOUNT then
				return false
			end

			-- Dodatkowe dopasowania dla różnych lokalizacji
			if string.find(text, "Soulbound") or string.find(text, "Przypisany") or string.find(text, "Przypisane") then
				if not (type(ITEM_BIND_TO_ACCOUNT) == "string" and text == ITEM_BIND_TO_ACCOUNT) then
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
	local tag = self:GetBestValueTag(bag, slot)
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

	local texture = select(1, self:GetContainerItemInfo(bagID, slotID))

	if not texture then
		return
	end

	local tag = self:GetBestValueTag(bagID, slotID)

	if not tag then
		return
	end

	local overlay = GetOrCreateOverlay(slotFrame)

	if tag == "S" then
		SetOverlayStyle(overlay, { r = 0.53, g = 0.12, b = 0.77, a = 1 }, { r = 0.90, g = 0.60, b = 1.00, a = 1 }, "S")
		return
	elseif tag == "N" then
		SetOverlayStyle(overlay, { r = 1.00, g = 0.50, b = 0.00, a = 1 }, { r = 1.00, g = 0.95, b = 0.60, a = 1 }, "N")
		return
	elseif tag == "A" then
		if not BagTagsConfig.showAuction then
			return
		end

		SetOverlayStyle(overlay, { r = 0.10, g = 1.00, b = 0.10, a = 1 }, { r = 0.40, g = 1.00, b = 0.40, a = 1 }, "A")
		return
	elseif tag == "D" then
		if not BagTagsConfig.showDisenchant then
			return
		end

		SetOverlayStyle(overlay, { r = 0.80, g = 0.30, b = 0.80, a = 1 }, { r = 1.00, g = 0.50, b = 1.00, a = 1 }, "D")
		return
	elseif tag == "V" then
		if not BagTagsConfig.showVendor then
			return
		end

		SetOverlayStyle(overlay, { r = 0.90, g = 0.80, b = 0.20, a = 1 }, { r = 1.00, g = 0.90, b = 0.40, a = 1 }, "V")
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

-- ===== Sell Vendor: functions & UI (REPLACE existing Sell Vendor block with this) =====

-- Helper: rozpoznaje vendor tag przy użyciu BT:GetValueTag / BT:GetItemTag
function BT:GetTagForSlot(bag, slot)
	local ok, tag = pcall(self.GetValueTag, self, bag, slot)

	if ok then
		return tag
	end

	return nil
end

function BT:IsVendorTag(tag)
	if not tag then
		return false
	end
	if type(tag) ~= "string" then
		return false
	end
	local t = tag:lower()
	return t == "v" or t == "vendor"
end

-- Stack count helper (z BT:GetContainerItemInfo fallback na globalne API)
function BT:GetStackCountAt(bag, slot)
	if type(self.GetContainerItemInfo) == "function" then
		local ok, texture, count = pcall(self.GetContainerItemInfo, self, bag, slot)
		if ok then
			return count or 1
		end
	end
	local _, count = GetContainerItemInfo(bag, slot)
	return count or 1
end

-- Liczy łączną wartość vendor (copper)
function BT:ComputeVendorTotal()
	local total = 0
	local maxBag = 4
	for bag = 0, maxBag do
		local slots = (type(self.GetContainerNumSlots) == "function" and self:GetContainerNumSlots(bag))
			or GetContainerNumSlots(bag)
			or 0
		if slots and slots > 0 then
			for slot = 1, slots do
				local link = (
					type(self.SafeGetContainerItemLink) == "function" and self:SafeGetContainerItemLink(bag, slot)
				) or GetContainerItemLink(bag, slot)
				if link then
					local tag = self:GetTagForSlot(bag, slot)
					if self:IsVendorTag(tag) then
						local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
						vendorPrice = vendorPrice or 0
						local stack = self:GetStackCountAt(bag, slot) or 1
						total = total + (vendorPrice * stack)
					end
				end
			end
		end
	end
	return total
end

-- Kolejka sprzedaży: z BT.VendorSellQueue i BT.VendorSellFrame
function BT:StartVendorSellQueue()
	if not MerchantFrame or not MerchantFrame:IsShown() then
		UIErrorsFrame:AddMessage("Open a merchant first to sell items.")
		return
	end

	if not self.VendorSellQueue or #self.VendorSellQueue == 0 then
		UIErrorsFrame:AddMessage("No vendor-tagged items found.")
		return
	end

	self.VendorSelling = true
	self.VendorSellTimer = 0
	self.VendorSellFrame = self.VendorSellFrame or CreateFrame("Frame")
	local interval = 0.12

	self.VendorSellFrame:SetScript("OnUpdate", function(frame, elapsed)
		self.VendorSellTimer = self.VendorSellTimer + elapsed
		if self.VendorSellTimer >= interval then
			self.VendorSellTimer = 0
			local entry = table.remove(self.VendorSellQueue, 1)
			if not entry then
				frame:SetScript("OnUpdate", nil)
				self.VendorSelling = false
				return
			end
			-- verify item still exists in slot
			local currentLink = (
				type(self.SafeGetContainerItemLink) == "function"
				and self:SafeGetContainerItemLink(entry.bag, entry.slot)
			) or GetContainerItemLink(entry.bag, entry.slot)
			if currentLink then
				UseContainerItem(entry.bag, entry.slot)
			end
		end
	end)
end

-- Create / ensure Sell button exists and register events
function BT:CreateSellVendorButton()
	if self.SellVendorBtn and self.SellVendorBtn.Create then
		return
	end

	-- choose parent: InventoryModule.frame -> BT.Frame -> ContainerFrame1 -> UIParent
	local parentForButton = (self.InventoryModule and self.InventoryModule.mainFrame)
		or self.Frame
		or _G["ContainerFrame1"]
		or UIParent

	local btn = CreateFrame("Button", "BagTags_SellVendorBtn", parentForButton, "UIPanelButtonTemplate")
	btn:ClearAllPoints()
	btn:SetSize(170, 22)
	btn:SetPoint("TOPRIGHT", parentForButton, "TOPRIGHT", -15, -58)
	btn:SetText(("Vendor (%s)"):format(self:FormatMoney(total)))
	btn:Hide()

	local nt = btn:GetNormalTexture()

	if nt then
		nt:SetVertexColor(0.20, 0.20, 0.20)
	end

	local pt = btn:GetPushedTexture()

	if pt then
		pt:SetVertexColor(0.35, 0.35, 0.35)
	end

	local ht = btn:GetHighlightTexture()

	if ht then
		ht:SetVertexColor(1.0, 0.85, 0.1)
	end

	-- frame level/strata to avoid being hidden under other UI
	if parentForButton and type(parentForButton.GetFrameLevel) == "function" then
		btn:SetFrameLevel(parentForButton:GetFrameLevel() + 5)
	end
	if parentForButton and type(parentForButton.GetFrameStrata) == "function" then
		btn:SetFrameStrata(parentForButton:GetFrameStrata())
	end

	-- OnClick: build queue and start selling
	btn:SetScript("OnClick", function()
		if not MerchantFrame or not MerchantFrame:IsShown() then
			UIErrorsFrame:AddMessage("Open a merchant first to sell items.")
			return
		end
		self.VendorSellQueue = {}
		local maxBag = 4
		for bag = 0, maxBag do
			local slots = (type(self.GetContainerNumSlots) == "function" and self:GetContainerNumSlots(bag))
				or GetContainerNumSlots(bag)
				or 0
			if slots and slots > 0 then
				for slot = 1, slots do
					local link = (
						type(self.SafeGetContainerItemLink) == "function" and self:SafeGetContainerItemLink(bag, slot)
					) or GetContainerItemLink(bag, slot)
					if link then
						local tag = self:GetTagForSlot(bag, slot)
						if self:IsVendorTag(tag) then
							table.insert(self.VendorSellQueue, { bag = bag, slot = slot, link = link })
						end
					end
				end
			end
		end

		if self.VendorSellQueue and #self.VendorSellQueue > 0 then
			self:StartVendorSellQueue()
		else
			UIErrorsFrame:AddMessage("No vendor-tagged items found.")
		end
	end)

	-- expose button reference
	self.SellVendorBtn = btn

	-- events: aktualizuj przycisk przy zmianach
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("BAG_UPDATE")
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("MERCHANT_SHOW")
	ev:RegisterEvent("MERCHANT_CLOSED")

	ev:SetScript("OnEvent", function(_, event, ...)
		if event == "MERCHANT_SHOW" then
			-- po otwarciu mercanta przycisk może się aktywować
			C_Timer.After(0.03, function()
				if type(self.UpdateSellButton) == "function" then
					self:UpdateSellButton()
				end
			end)
		elseif event == "MERCHANT_CLOSED" then
			-- przerwij ewentualną sprzedaż
			self.VendorSellQueue = {}
			if self.VendorSellFrame then
				self.VendorSellFrame:SetScript("OnUpdate", nil)
			end
			if type(self.UpdateSellButton) == "function" then
				self:UpdateSellButton()
			end
		else
			-- debounce drobnego opóźnienia aby GetItemInfo mógł zaktualizować
			C_Timer.After(0.06, function()
				if type(self.UpdateSellButton) == "function" then
					self:UpdateSellButton()
				end
			end)
		end
	end)

	-- hook parent show/hide if available (ustawienie pozycji i refresh)
	if
		parentForButton
		and type(parentForButton.IsObjectType) == "function"
		and parentForButton:IsObjectType("Frame")
	then
		parentForButton:HookScript("OnShow", function()
			C_Timer.After(0.02, function()
				if type(self.UpdateSellButton) == "function" then
					self:UpdateSellButton()
				end
			end)
		end)
		parentForButton:HookScript("OnHide", function()
			if self.SellVendorBtn then
				self.SellVendorBtn:Hide()
			end
		end)
	end
end

-- UpdateSellButton: pokazuje/ukrywa i ustawia tekst z sumą
function BT:UpdateSellButton()

    local mod = self.InventoryModule

    if not mod then
        return
    end

    if not mod.vendorBar then
        return
    end

    local total = self:ComputeVendorTotal()

if total <= 0 then

    mod.vendorBar.text:SetText("")
    mod.vendorBar:Hide()

    return
end

    mod.vendorBar.text:SetText(
        "|cffFFD700[V]|r " .. self:FormatMoney(total)
    )

    mod.vendorBar:Show()
end

-- Expose for other modules
BT.UpdateSellButton = BT.UpdateSellButton or BT.UpdateSellButton -- ensure reference exists after load

-- Safe initial delayed refresh (replace any bare C_Timer.After(1, UpdateSellButton) calls)
C_Timer.After(1, function()
	if type(BT.UpdateSellButton) == "function" then
		BT:UpdateSellButton()
	end
end)

-- ===== end Sell Vendor block =====

-- =======================================================================
-- KONIEC: Sell Vendor block
-- =======================================================================

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

function BT:GetVendorItems()
	local data = {
		items = {},
		count = 0,
		value = 0,
	}

	if self.BuildCurrentItemCounts then
		self:BuildCurrentItemCounts()
	end

	for bag = 0, 4 do
		local numSlots = self:GetContainerNumSlots(bag)

		for slot = 1, numSlots do
			local link = self:GetContainerItemLink(bag, slot)

			if link then
				local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
				vendorPrice = vendorPrice or 0

				if vendorPrice > 0 and self:GetValueTag(bag, slot) == "V" then
					local _, stackCount = self:GetContainerItemInfo(bag, slot)

					stackCount = stackCount or 1

					table.insert(data.items, {
						bag = bag,
						slot = slot,
					})

					data.count = data.count + 1
					data.value = data.value + (vendorPrice * stackCount)
				end
			end
		end
	end

	return data
end

function BT:SellVendorItems()
	local cache = self:GetVendorItems()

	if not cache or cache.count == 0 then
		UIErrorsFrame:AddMessage("No vendor items found.")
		return
	end

	local sold = 0
	local earned = 0

	for _, item in ipairs(cache.items) do
		local link = self:GetContainerItemLink(item.bag, item.slot)

		if link then
			local _, count = self:GetContainerItemInfo(item.bag, item.slot)

			count = count or 1

			local vendorPrice = select(11, GetItemInfo(link)) or 0

			earned = earned + (vendorPrice * count)

			if C_Container and C_Container.UseContainerItem then
				C_Container.UseContainerItem(item.bag, item.slot)
			else
				UseContainerItem(item.bag, item.slot)
			end

			sold = sold + 1
		end
	end

	DEFAULT_CHAT_FRAME:AddMessage(
    string.format(
        "|cff00ffcc[BagTags]|r Sold %d vendor items for %s",
        sold,
        self:FormatMoney(earned)
    )
)

C_Timer.After(0.25, function()

    if BT.BuildCurrentItemCounts then
        BT:BuildCurrentItemCounts()
    end

    if BT.UpdateSellButton then
        BT:UpdateSellButton()
    end

    if BT.InventoryModule and BT.InventoryModule.UpdateLayout then
        BT.InventoryModule:UpdateLayout()
    end

end)

return sold, earned

	return sold, earned
end

BT.ItemCache = BT.ItemCache or {}

function BT:GetItemData(link)
	if not link then
		return nil
	end

	local cached = self.ItemCache[link]

	if cached then
		return cached
	end

	local name, _, quality, level, reqLevel, itemType, itemSubType, stackSize, equipLoc, icon, vendorPrice =
		GetItemInfo(link)

	cached = {
		name = name,
		quality = quality or 0,
		level = level or 0,
		reqLevel = reqLevel or 0,
		itemType = itemType,
		itemSubType = itemSubType,
		stackSize = stackSize or 1,
		equipLoc = equipLoc,
		icon = icon,
		vendorPrice = vendorPrice or 0,
	}

	self.ItemCache[link] = cached

	return cached
end

function BT:GetBestValueTag(bag, slot)
	local link = self:SafeGetContainerItemLink(bag, slot)

	if not link then
		return nil, 0
	end

	local item = nil

	if self.GetItemData then
		item = self:GetItemData(link)
	end

	local itemName
	local quality
	local itemType
	local vendorPrice

	if item then
		itemName = item.name
		quality = item.quality
		itemType = item.itemType
		vendorPrice = item.vendorPrice
	else
		itemName, _, quality, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(link)
		quality = quality or 0
		vendorPrice = vendorPrice or 0
	end

	if self:IsItemSoulbound(bag, slot) then
		return "S", vendorPrice
	end

	if not self._currentCounts then
		self:BuildCurrentItemCounts()
	end

	local itemID = tonumber(string.match(link, "item:(%d+)"))

	if itemID then
		local current = (self._currentCounts and self._currentCounts[itemID]) or 0
		local known = self.knownItems[itemID] or 0

		if current > known then
			return "N", vendorPrice
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

	local netAh = ahPrice * 0.95

	local bestValue = vendorPrice
	local bestTag = "V"

	if netAh > bestValue then
		bestValue = netAh
		bestTag = "A"
	end

	if
		self.hasEnchanting
		and (quality == 2 or quality == 3)
		and (itemType == "Armor" or itemType == "Weapon")
		and deValue > bestValue
	then
		bestValue = deValue
		bestTag = "D"
	end

	return bestTag, bestValue
end
