local addonName, BT = ...

BT.Merchant = {}
local Merchant = BT.Merchant

--------------------------------------------------
-- UI
--------------------------------------------------

local frame = CreateFrame("Frame", "BagTagsMerchantFrame", UIParent, "BackdropTemplate")

frame:SetSize(320, 140)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")

frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = {
		left = 4,
		right = 4,
		top = 4,
		bottom = 4,
	},
})

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")

title:SetPoint("TOP", 0, -12)
title:SetText("BagTags Merchant")

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")

closeButton:SetPoint("TOPRIGHT", -2, -2)

local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

infoText:SetPoint("TOP", 0, -45)
infoText:SetWidth(280)
infoText:SetJustifyH("CENTER")

local sellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

sellButton:SetSize(220, 24)
sellButton:SetPoint("BOTTOM", 0, 20)
sellButton:SetText("Sell Vendor Items")

--------------------------------------------------
-- Skany
--------------------------------------------------

function Merchant:GetVendorItems()
	local data = {
		items = {},
		count = 0,
		value = 0,
	}

	if BT.BuildCurrentItemCounts then
		BT:BuildCurrentItemCounts()
	end

	for bag = 0, 4 do
		local numSlots = BT:GetContainerNumSlots(bag)

		for slot = 1, numSlots do
			local link = BT:GetContainerItemLink(bag, slot)

			if link then
				local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)

				vendorPrice = vendorPrice or 0

				if vendorPrice > 0 and BT:GetValueTag(bag, slot) == "V" then
					local _, stackCount = BT:GetContainerItemInfo(bag, slot)

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

--------------------------------------------------
-- Sprzedaż
--------------------------------------------------

function Merchant:SellVendorItems()
	if not self.cache then
		return
	end

	local sold = 0
	local earned = 0

	for _, item in ipairs(self.cache.items) do
		local link = BT:GetContainerItemLink(item.bag, item.slot)

		if link then
			local _, count = BT:GetContainerItemInfo(item.bag, item.slot)

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
		string.format("|cff00ffcc[BagTags]|r Sold %d vendor items for %s", sold, BT:FormatMoney(earned))
	)

	frame:Hide()
end

--------------------------------------------------
-- Przycisk
--------------------------------------------------

sellButton:SetScript("OnClick", function()
	Merchant:SellVendorItems()
end)

--------------------------------------------------
-- Eventy Merchant
--------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_CLOSED" then
		frame:Hide()
		return
	end

	Merchant.cache = Merchant:GetVendorItems()

	if Merchant.cache.count == 0 then
		frame:Hide()
		return
	end

	infoText:SetText(
		string.format("Vendor Items\n%d items\n%s", Merchant.cache.count, BT:FormatMoney(Merchant.cache.value))
	)

	frame:Show()
end)
