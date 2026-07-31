local addonName, BT = ...

SLASH_BAGTAGS1 = "/bts"

SlashCmdList["BAGTAGS"] = function()
	BT:ToggleBagTags()
end

BT.InventoryModule = BT.InventoryModule or {}
local module = BT.InventoryModule

local UpdateTitleText

BagTagsCategoryState = BagTagsCategoryState or {}

local poolButtons = {}

-------------------------------------------------------
-- Tworzenie i Inicjalizacja Okna
-------------------------------------------------------
function module:InitializeFrame()
	if self.mainFrame then
		return
	end

	local frame = CreateFrame("Frame", "BagTagsInventoryFrame", UIParent, "BackdropTemplate")
	self.mainFrame = frame

	tinsert(UISpecialFrames, "BagTagsInventoryFrame")

	frame:SetSize(420, 520)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("HIGH")

	frame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0.10, 0.10, 0.10, 0.90)
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 15, -15)
	title:SetText("BagTags")
	self.title = title

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -5, -5)
	close:SetScript("OnClick", function()
		module:HideFrame()
	end)

	local money = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	money:SetPoint("RIGHT", close, "LEFT", -5, -1)
	self.moneyDisplay = money

	local scrollFrame = CreateFrame("ScrollFrame", "BagTagsInventoryScrollFrame", frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(380, 400)
	scrollFrame:SetScrollChild(content)

	content.sections = {}
	self.scrollFrame = scrollFrame
	self.contentFrame = content

	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		if BT.SaveFramePosition then
			BT:SaveFramePosition("inventory", point, relPoint, x, y)
		end
	end)

	frame:SetScript("OnShow", function()
		module:ApplyOpacity()
		module:ApplyScale()
		module:UpdateLayout()
		UpdateTitleText()
	end)
end

local initEventFrame = CreateFrame("Frame")
initEventFrame:RegisterEvent("ADDON_LOADED")
initEventFrame:SetScript("OnEvent", function(self, event, arg1)
	if arg1 == addonName then
		module:InitializeFrame()
		module:RestoreLayoutPositions()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

UpdateTitleText = function()
	local mod = BT.InventoryModule

	if not mod then
		return
	end

	local totalFree = 0
	local totalSlots = 0

	for bag = 0, 4 do
		local freeSlots, bagType

		if C_Container and C_Container.GetContainerNumFreeSlots then
			freeSlots, bagType = C_Container.GetContainerNumFreeSlots(bag)
		elseif GetContainerNumFreeSlots then
			freeSlots, bagType = GetContainerNumFreeSlots(bag)
		end

		local numSlots = BT:GetContainerNumSlots(bag)

		totalFree = totalFree + (freeSlots or 0)
		totalSlots = totalSlots + numSlots
	end

	if mod.title then
		mod.title:SetText(string.format("Free space %d/%d", totalFree, totalSlots))
	end

	if mod.moneyDisplay then
		local money = GetMoney()

		local gold = math.floor(money / 10000)
		local silver = math.floor((money % 10000) / 100)
		local copper = money % 100

		local moneyText = string.format(
			"|cffffffff%d|r|cffffd700g|r" .. "|cffffffff%d|r|cffc7c7c7s|r" .. "|cffffffff%d|r|cffeda55fc|r",
			gold,
			silver,
			copper
		)

		mod.moneyDisplay:SetText(moneyText)
	end
end

-------------------------------------------------------
-- Zdarzenia i Aktualizacja Interfejsu
-------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		local mod = BT.InventoryModule

		if mod and mod.mainFrame and mod.mainFrame:IsShown() then
			mod:HideFrame()
		end

		return
	end

	if event == "SKILL_LINES_CHANGED" then
		if BT.CheckProfessions then
			BT:CheckProfessions()
		end
		return
	end

	local mod = BT.InventoryModule
	if not mod or not mod.mainFrame then
		return
	end

	if mod.mainFrame:IsShown() then
		if event == "BAG_UPDATE" or event == "PLAYER_MONEY" or event == "BAG_UPDATE_DELAYED" then
			UpdateTitleText()
		end
	end

	if event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" or event == "BAG_UPDATE" then
		if not BT.updateTimer then
			BT.updateTimer = C_Timer.NewTimer(0.1, function()
				if mod.mainFrame and mod.mainFrame:IsShown() then
					mod:UpdateLayout()
				end

				BT.updateTimer = nil
			end)
		end
	end
end)

-------------------------------------------------------
-- Układ Siatki (UpdateLayout)
-------------------------------------------------------
function module:UpdateLayout()
	local mainFrame = self.mainFrame
	if not mainFrame or not mainFrame:IsShown() then
		return
	end
	local contentFrame = self.contentFrame
	if not contentFrame then
		return
	end

	for _, section in pairs(contentFrame.sections) do
		section:Hide()
	end
	for _, btn in pairs(poolButtons) do
		btn:Hide()

		if btn.BagTagsOverlay then
			btn.BagTagsOverlay:Hide()
		end
	end

	local groups = {}
	local categoryValues = {}
	local orderedCategories = { "New Items", "Consumables", "Tradeskill", "Quest", "Miscellaneous" }

	for _, cat in ipairs(orderedCategories) do
		categoryValues[cat] = 0
	end

	for bag = 0, 4 do
		local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag))
			or (GetContainerNumSlots and GetContainerNumSlots(bag))
			or 0
		for slot = 1, numSlots do
			local link = BT:GetContainerItemLink(bag, slot)
			if link then
				local tag = BT:GetItemTag(bag, slot) or "Miscellaneous"
				if not groups[tag] then
					groups[tag] = {}
				end
				if not categoryValues[tag] then
					categoryValues[tag] = 0
				end

				table.insert(groups[tag], { bag = bag, slot = slot })

				local _, _, _, _, _, _, _, _, _, _, itemVendorPrice = GetItemInfo(link)
				categoryValues[tag] = categoryValues[tag] + (itemVendorPrice or 0)

				local found = false
				for _, name in ipairs(orderedCategories) do
					if name == tag then
						found = true
						break
					end
				end
				if not found then
					table.insert(orderedCategories, tag)
				end
			end
		end
	end

	-- Sortowanie przedmiotów w obrębie kategorii
	for tag, itemList in pairs(groups) do
		local decoratedList = {}
		for i, item in ipairs(itemList) do
			local link = BT:GetContainerItemLink(item.bag, item.slot)
			local name, quality, itemType, itemSubType = "", 0, "", ""
			local stackCount = 0

			if link then
				local itemName, _, itemQuality, _, _, iType, iSubType = GetItemInfo(link)
				name = itemName or ""
				quality = itemQuality or 0
				itemType = iType or ""
				itemSubType = iSubType or ""

				local _, count = BT:GetContainerItemInfo(item.bag, item.slot)
				stackCount = count or 0
			end

			table.insert(decoratedList, {
				bag = item.bag,
				slot = item.slot,
				name = name,
				quality = quality,
				itemType = itemType,
				itemSubType = itemSubType,
				stackCount = stackCount,
			})
		end

		table.sort(decoratedList, function(a, b)
			if a.itemSubType ~= b.itemSubType then
				return a.itemSubType < b.itemSubType
			end
			if a.name ~= b.name then
				return a.name < b.name
			end
			if a.quality ~= b.quality then
				return a.quality > b.quality
			end
			if a.stackCount ~= b.stackCount then
				return a.stackCount > b.stackCount
			end
			return a.itemType < b.itemType
		end)

		groups[tag] = decoratedList
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

				local header = CreateFrame("Button", nil, section)
				header:SetSize(355, 20)
				header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)

				local fontString = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				fontString:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
				fontString:SetPoint("LEFT", header, "LEFT", 2, 0)
				header.text = fontString

				header:SetScript("OnClick", function()
					BagTagsCategoryState[catName] = not BagTagsCategoryState[catName]
					module:UpdateLayout()
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

			local goldText = ""
			local totalValue = categoryValues[catName] or 0
			if totalValue > 0 and catName ~= "Quest" then
				goldText = "  |cff808080(Vendor: " .. BT:FormatMoney(totalValue) .. ")|r"
			end

			section.header.text:SetText(prefix .. catName .. " (" .. count .. ")" .. goldText)

			section:ClearAllPoints()
			section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, currentY)
			section:Show()

			local sectionHeight = 20
			if not isCollapsed then
				for index, itemInfo in ipairs(itemDataList) do
					local bID = itemInfo.bag
					local sID = itemInfo.slot

					local slotKey = catName .. "_" .. index

					local slotFrame = poolButtons[slotKey]

					if not slotFrame then
						local slotName = "BagTagsSlotButton_" .. slotKey

						-- TWORZENIE BEZPIECZNEGO PRZYCISKU (SecureActionButtonTemplate)
						slotFrame = CreateFrame("Button", slotName, section, "ItemButtonTemplate, SecureActionButtonTemplate")

						-- Rejestrujemy kliknięcia; zachowaj PPM jako secure "item" (umożliwia użycie)
						slotFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
						slotFrame:SetAttribute("type2", "item")

						-- OnMouseUp: obsługa LPM (pickup), umieszczania z kursora i modified-click
						slotFrame:SetScript("OnMouseUp", function(self, button)
							-- upewnij się, że bag/slot są znane (ustawiane później przy aktualizacji)
							local bID = self.bagID or self.bag
							local sID = self.slotID or self.slot
							if not bID or not sID then
								return
							end

							-- link z tego slotu (może być nil)
							local link = BT and BT.SafeGetContainerItemLink and BT:SafeGetContainerItemLink(bID, sID)

							-- modified-click (Shift/Ctrl/Alt) -> standardowe zachowanie
							if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
								if link then HandleModifiedItemClick(link) end
								return
							end

							-- co jest aktualnie na kursore (nil gdy pusty)
							local cursorType = select(1, GetCursorInfo())

							-- sprawdzamy, czy na kursore jest item (unikamy innych typów kursora)
							if cursorType == "item" then
								-- jest item na kursore: włóż go do tego slotu (swap/put)
								if C_Container and C_Container.PickupContainerItem then
									C_Container.PickupContainerItem(bID, sID)
								else
									PickupContainerItem(bID, sID)
								end
								return
							end

							-- kursor pusty: LPM pobiera item na kursor; PPM pozostawiamy secure "item"
							if button == "LeftButton" then
								if C_Container and C_Container.PickupContainerItem then
									C_Container.PickupContainerItem(bID, sID)
								else
									PickupContainerItem(bID, sID)
								end
								return
							end

							-- RightButton + pusty kursor -> nic tu, secure type2="item" wykona użycie
						end)

						-- Drag oraz tooltipy
						slotFrame:SetScript("OnDragStart", function(self)
							if self.bagID and self.slotID then
								if C_Container and C_Container.PickupContainerItem then
									C_Container.PickupContainerItem(self.bagID, self.slotID)
								else
									PickupContainerItem(self.bagID, self.slotID)
								end
							end
						end)

						slotFrame:SetScript("OnEnter", function(self)
							local link = BT and BT.SafeGetContainerItemLink and BT:SafeGetContainerItemLink(self.bagID, self.slotID)
							if link then
								GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
								GameTooltip:SetHyperlink(link)
								GameTooltip:Show()
							end
						end)

						slotFrame:SetScript("OnLeave", function()
							GameTooltip:Hide()
						end)

						poolButtons[slotKey] = slotFrame
					end

					slotFrame:SetParent(section)

					slotFrame.bagID = bID
					slotFrame.slotID = sID
					slotFrame:SetID(sID)

					slotFrame:SetAttribute("bag", bID)
					slotFrame:SetAttribute("slot", sID)

					-- Przypisanie danych do bezpiecznego przycisku silnika WoW
					slotFrame:SetAttribute("bag", bID)
					slotFrame:SetAttribute("slot", sID)

					local row = math.floor((index - 1) / COLUMNS)
					local col = (index - 1) % COLUMNS

					slotFrame:ClearAllPoints()
					slotFrame:SetPoint("TOPLEFT", section, "TOPLEFT", col * SLOT_SIZE, -(20 + (row * SLOT_SIZE)))

					slotFrame:SetSize(32, 32)
					slotFrame:SetFrameLevel(section:GetFrameLevel() + 2)

					-- Pobranie danych itemu
					local texture, itemCount = BT:GetContainerItemInfo(bID, sID)

					-- Emulacja pól Blizzardowego slotu
					slotFrame.bag = bID
					slotFrame.slot = sID
					slotFrame.hasItem = texture and 1 or nil
					slotFrame.count = itemCount or 0

					-- Ustawienie ikony
					if texture then
						SetItemButtonTexture(slotFrame, texture)
					else
						SetItemButtonTexture(slotFrame, nil)
					end

					-- Ustawienie stack count
					if itemCount and itemCount > 1 then
						SetItemButtonCount(slotFrame, itemCount)
					else
						SetItemButtonCount(slotFrame, 0)
					end

					if BT.UpdateSlotOverlay then
						BT:UpdateSlotOverlay(slotFrame, bID, sID)
					end

					local iconTex = _G[slotFrame:GetName() .. "IconTexture"]

					if iconTex then
						iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					end

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
end

-------------------------------------------------------
-- Funkcje Pomocnicze i Podpięcia Systemowe
-------------------------------------------------------
function module:ApplyOpacity()
	local alpha = (BagTagsConfig and BagTagsConfig.opacity) or 0.9
	if self.mainFrame then
		self.mainFrame:SetBackdropColor(0.10, 0.10, 0.10, alpha)
	end
end

function module:ApplyScale()
	local scale = (BagTagsConfig and BagTagsConfig.scale) or 1.0
	if self.mainFrame then
		self.mainFrame:SetScale(scale)
	end
end

function module:ShowFrame()
	if InCombatLockdown and InCombatLockdown() then
		return
	end

	if not self.mainFrame then
		return
	end

	self:RestoreLayoutPositions()
	self.mainFrame:Show()
	UpdateTitleText()
	self:UpdateLayout()
end

function module:HideFrame()
	if InCombatLockdown and InCombatLockdown() then
		return
	end

	if not self.mainFrame then
		return
	end

	if BT.SnapshotCurrentItems then
		BT:SnapshotCurrentItems()
	end

	self.mainFrame:Hide()
end

function module:RestoreLayoutPositions()
	if BagTagsConfig and BagTagsConfig.positions then
		local inv = BagTagsConfig.positions.inventory
		if inv and self.mainFrame then
			self.mainFrame:ClearAllPoints()
			self.mainFrame:SetPoint(inv[1], UIParent, inv[2], inv[3], inv[4])
		end
	end
end

-- ============================================================================
-- NADPISANIE SYSTEMU OTWIERANIA TOREB
-- ============================================================================

function BT:ToggleBagTags()
	if not BagTagsConfig or not BagTagsConfig.useInventoryWindow then
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		return
	end

	if not module.mainFrame and type(module.InitializeFrame) == "function" then
		module:InitializeFrame()
	end

	if module.mainFrame then
		if module.mainFrame:IsShown() then
			module:HideFrame()
		else
			module:ShowFrame()
		end
	else
		print("|cffff0000[BagTags]|r Failed to initialize inventory frame.")
	end
end

-- Nadpisanie standardowych skrótów klawiszowych (B / Shift+B / Torby na mikro-pasku)
-- Funkcja pomocnicza do ukrywania wszystkich podstawowych toreb Blizzarda (0-4)
local function HideBlizzardBags()
	for i = 1, NUM_CONTAINER_FRAMES or 13 do
		local frame = _G["ContainerFrame" .. i]
		if frame and frame:IsShown() then
			frame:Hide()
		end
	end
end

-- Nadpisanie skrótu "B" / Backpack
if type(ToggleBackpack) == "function" then
	hooksecurefunc("ToggleBackpack", function()
		if not (BagTagsConfig and BagTagsConfig.useInventoryWindow) then
			return
		end

		HideBlizzardBags()
		BT:ToggleBagTags()
	end)
end

-- Nadpisanie otwierania wszystkich toreb (dla nowszych API, jeśli istnieje)
if type(ToggleAllBags) == "function" then
	hooksecurefunc("ToggleAllBags", function()
		if not (BagTagsConfig and BagTagsConfig.useInventoryWindow) then
			return
		end

		HideBlizzardBags()

		if InCombatLockdown and InCombatLockdown() then
			return
		end

		BT:ToggleBagTags()
	end)
end

-- Nadpisanie otwierania wszystkich toreb (standard dla 3.3.5a)
if type(OpenAllBags) == "function" then
	hooksecurefunc("OpenAllBags", function() end)
end

if type(ToggleAllBags) == "function" then
	hooksecurefunc("ToggleAllBags", function() end)
end

-- Ukrywanie fabrycznych ramek toreb
if type(ContainerFrame_GenerateFrame) == "function" then
	hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
		if not (BagTagsConfig and BagTagsConfig.useInventoryWindow) then
			return
		end

		if frame then
			if frame.IsForbidden and frame:IsForbidden() then
				return
			end

			frame:Hide()
		end
	end)
end
