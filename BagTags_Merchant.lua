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
-- Przycisk
--------------------------------------------------

sellButton:SetScript("OnClick", function()
    BT:SellVendorItems()
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

	Merchant.cache = BT:GetVendorItems()

	if Merchant.cache.count == 0 then
		frame:Hide()
		return
	end

	infoText:SetText(
		string.format("Vendor Items\n%d items\n%s", Merchant.cache.count, BT:FormatMoney(Merchant.cache.value))
	)

	frame:Show()
end)
