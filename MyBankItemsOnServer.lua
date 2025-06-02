--MyBankItemsOnServer.lua
--by LQI

-- init addon
local addonName = ...
-- get metadata version addon
local version = GetAddOnMetadata(addonName, "Version")
-- init the local texts commands
local cmd = {"/bankitems"}
local cmdInfos = {"Ouvre l'écran de bank."}

-- display in print console the addon informations
print(color("green",addonName) .. " v" .. version)
for i = #cmd, 1, -1 do
   print(" |-> " .. color("yellow",cmd[i]) .. " : " .. cmdInfos[i])
end

-- SavedVariables Global
local addonTable = ...
local f = CreateFrame("Frame")
local playerKey = UnitName("player") .. "-" .. GetRealmName()
local currentFilter = "Tous"
local currentSearchText = ""

MyBankItemsOnServerDB = MyBankItemsOnServerDB or {}

-- API Compatibility Layer (Retail / Classic)
local UseContainerAPI = C_Container and C_Container.GetContainerNumSlots
local function GetNumSlots(bag)
    return UseContainerAPI and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots(bag)
end

-- GET item link
local function GetItemLink(bag, slot)
    return UseContainerAPI and C_Container.GetContainerItemLink(bag, slot) or GetContainerItemLink(bag, slot)
end

-- GET item category
local function GetItemCategory(itemID)
    local _, _, _, _, _, itemType = GetItemInfo(itemID)
    return itemType or "Autres"
end

-- Info detail bag
local function GetItemInfoDetail(bag, slot)
   if UseContainerAPI then
      local info = C_Container.GetContainerItemInfo(bag, slot)
      return info and info.hyperlink, info and info.stackCount
   else
      local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
      return GetContainerItemLink(bag, slot), count
   end
end

-- Scan player bags (0-4)
local function ScanBags()
   if not IsLoggedIn() then return end
   MyBankItemsOnServerDB[playerKey] = MyBankItemsOnServerDB[playerKey] or {}
   local data = {}

   for bag = 0, 4 do
      local numSlots = GetNumSlots(bag)
      if numSlots then
         for slot = 1, numSlots do
            local itemLink, count = GetItemInfoDetail(bag, slot)
            if itemLink then
               local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
               if itemID then
                  data[itemID] = (data[itemID] or 0) + (count or 1)
               end
            end
         end
      end
   end

   MyBankItemsOnServerDB[playerKey].bags = data
end

-- Scan bank (-1, 5–11)
local function ScanBank()
   if not IsLoggedIn() or not BankFrame or not BankFrame:IsShown() then return end
   MyBankItemsOnServerDB[playerKey] = MyBankItemsOnServerDB[playerKey] or {}
   local data = {}

	-- reinit data bank
	MyBankItemsOnServerDB[playerKey].bank = {}

	-- separate bags for compare the bags in bank and in bags characters.
	local function IsBankBag(bag)
	    return bag == -1 or (bag >= 5 and bag <= 11)
	end

	for bag = -1, 11 do
	    if IsBankBag(bag) then
	        local numSlots = GetNumSlots(bag)
	        if numSlots then
	            for slot = 1, numSlots do
	                local itemLink, count = GetItemInfoDetail(bag, slot)
	                if itemLink then
	                    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
	                    if itemID then
	                        MyBankItemsOnServerDB[playerKey].bank[itemID] = (MyBankItemsOnServerDB[playerKey].bank[itemID] or 0) + (count or 1)
	                    end
	                end
	            end
	        end
	    end
	end
end

-- Event listeners
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

f:SetScript("OnEvent", function(self, event)
   if event == "BAG_UPDATE" then
      ScanBags()
   elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
      C_Timer.After(0.5, ScanBank)
   end
end)

-- Create UI frame
local itemFrame = CreateFrame("Frame", "MyBankItemsFrame", UIParent, "BasicFrameTemplateWithInset")
itemFrame:SetSize(560, 400)
itemFrame:SetPoint("CENTER")
itemFrame:SetMovable(true)
itemFrame:EnableMouse(true)
itemFrame:RegisterForDrag("LeftButton")
itemFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
itemFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
itemFrame:Hide()
itemFrame.title = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
itemFrame.title:SetPoint("TOP", 0, -5)
itemFrame.title:SetText("Objets en banque et sacs - ".. color("green",GetRealmName()))

-- filters Items
local listFiltersItem = { "Tous", "Arme", "Armure", "Consommable", "Composant", "Autres" }
local filterButtons = {}

local filterFrame = CreateFrame("Frame", nil, itemFrame)
filterFrame:SetSize(40,40)
filterFrame:SetPoint("TOPLEFT", 0, 0)
filterFrame:Show()

-- Item frame content
local contentFrame = CreateFrame("Frame", nil, itemFrame)
contentFrame:SetSize(526,360)
contentFrame:SetPoint("TOPLEFT", 0, -42)
contentFrame:Show()

-- Scroll area
local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", 0, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

-- Items clicable
local function CreateItemButton(parent, itemID, totalCount)
   local btn = CreateFrame("Button", nil, parent)
   btn:SetSize(30, 30)

 	-- icon
   local icon = btn:CreateTexture(nil, "BACKGROUND")
   icon:SetAllPoints()
   icon:SetTexture(GetItemIcon(itemID))
   -- set icon and itemid
   btn.icon = icon
   btn.itemID = itemID

 	-- Fond noir transparent pour le texte
   local bg = btn:CreateTexture(nil, "ARTWORK")
   bg:SetColorTexture(0, 0, 0, 0.5)
   bg:SetPoint("BOTTOMRIGHT", -2, 2)
	bg:SetSize(20, 14)

	-- quantity text
	local countText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	countText:SetPoint("BOTTOMRIGHT", -3, 2)
	countText:SetText(totalCount or "")
	btn.countText = countText

	-- Tooltip
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink("item:" .. itemID)
      GameTooltip:AddLine(" ")

      for name, data in pairs(MyBankItemsOnServerDB) do
         local count = 0
         if data.bags and data.bags[itemID] then count = count + data.bags[itemID] end
         if data.bank and data.bank[itemID] then count = count + data.bank[itemID] end
         if count > 0 then
            GameTooltip:AddDoubleLine(name, count)
         end
      end

      GameTooltip:Show()
   end)

	btn:SetScript("OnClick", function(self, button)
		local itemID = self.itemID

		if button == "LeftButton" then
			local itemName, _, itemRarity = GetItemInfo(itemID)
			local total = 0

			print("|cffffff00[MyBankItemsOnServer]|r")

			if itemName then
				local color = select(4, GetItemQualityColor(itemRarity or 1))
				print(string.format("Objet : %s%s|r (ID: %d)", color, itemName, itemID))
			else
				print(string.format("Item ID: %d (nom inconnu, pas encore dans le cache)", itemID))
			end

			for name, data in pairs(MyBankItemsOnServerDB) do
				local bagCount = data.bags and data.bags[itemID] or 0
				local bankCount = data.bank and data.bank[itemID] or 0
				local charTotal = bagCount + bankCount

				if charTotal > 0 then
					print(string.format("- %s: %d (%d bags / %d bank)", name, charTotal, bagCount, bankCount))
					total = total + charTotal
				end
			end

			print("Total sur le compte :", total)

			elseif IsModifiedClick("CHATLINK") then
			local itemLink = select(2, GetItemInfo(itemID))
			if itemLink then
				ChatEdit_InsertLink(itemLink)
			end
		end
	end)

   btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
   end)

   return btn
end

-- Refresh Items in display
local function RefreshItemDisplay()
   for _, child in ipairs({content:GetChildren()}) do
      child:Hide()
   end

   local items = {}
   for _, data in pairs(MyBankItemsOnServerDB) do
      for src, list in pairs(data) do
         for itemID, count in pairs(list) do
            items[itemID] = (items[itemID] or 0) + count
         end
      end
   end

   local x, y = 0, 0.5
   local maxPerRow = 12
   local spacing = 44

	for itemID, totalCount in pairs(items) do
      local itemType = GetItemCategory(itemID)
      local itemName = GetItemInfo(itemID)
      local matchesSearch = true

      if currentSearchText ~= "" then
         if itemName then
            matchesSearch = string.find(string.lower(itemName), currentSearchText, 1, true)
         else
            matchesSearch = false
         end
      end

      local show = false
      if currentFilter == "Tous" then
         show = true
      elseif currentFilter == "Composant" then
         show = itemType == "Composants" or itemType == "Matière première"
      elseif currentFilter == "Autres" then
         show = not (itemType == "Arme" or itemType == "Armure" or itemType == "Consommable" or itemType == "Composants" or itemType == "Matière première")
      else
         show = itemType == currentFilter
      end

      -- generate list item
      if show and matchesSearch then
         local btn = CreateItemButton(content, itemID, totalCount)
         btn:SetPoint("TOPLEFT", x * spacing, -y * spacing)
         btn:Show()

         x = x + 1
         if x >= maxPerRow then
            x = 0
            y = y + 1
         end
      end
	end
end

for i, filter in ipairs(listFiltersItem) do
    local btn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    btn:SetSize(80, 20)
    btn:SetPoint("TOPLEFT", 10 + (i-1)*85, -28)
    btn:SetText(filter)

    btn:SetScript("OnClick", function()
        currentFilter = filter
        RefreshItemDisplay()
    end)

    filterButtons[filter] = btn
end

-- Search box filter
local inputBox = CreateFrame("EditBox", nil, filterFrame, "SearchBoxTemplate")
inputBox:SetSize(500, 20)
inputBox:SetPoint("TOPLEFT", 20, -50)
inputBox:SetText("")

-- Action filter by searchBox
inputBox:SetScript("OnTextChanged", function(self, userInput)
   SearchBoxTemplate_OnTextChanged(self)
   local text = self:GetText()
   --print("Text updated : " .. text) --Debug
   currentSearchText = string.lower(self:GetText() or "")
   RefreshItemDisplay()
end)

--================================
-- IMPORTANT : init minimap Button
local minimapButton = CreateFrame("Button", "MyBankItemsOnServerButton", Minimap)
minimapButton:SetSize(20, 20)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 20, -20)
minimapButton:SetNormalTexture("Interface\\Icons\\achievement_reputation_01")
-- Dragguable icone
minimapButton:SetMovable(true)
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", minimapButton.StartMoving)
minimapButton:SetScript("OnDragStop", minimapButton.StopMovingOrSizing)
-- Button effect
minimapButton:SetFrameStrata("TOOLTIP")
minimapButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

-- Minimap on click
minimapButton:SetScript("OnClick", function()
   -- show or hide interface
   if itemFrame:IsShown() then
      itemFrame:Hide()
   else
      itemFrame:Show()
   end
end)

minimapButton:SetScript("OnEnter", function(self)
   GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
   GameTooltip:SetText("Cliquez pour ouvrir ou ".. color("yellow",cmd[1]), 1, 1, 1)
   GameTooltip:AddLine("Serveur : " .. color("green",GetRealmName()), 0.8, 0.8, 0.8)
   GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
   GameTooltip:Hide()
end)

--==============
-- Slash command
SLASH_MYBANKITEMS1 = cmd[1]
SlashCmdList["MYBANKITEMS"] = function()
   if itemFrame:IsShown() then
      itemFrame:Hide()
   else
      -- set at empty the searchBar
      inputBox:SetText("")
      currentSearchText = ""
      -- refresh display items
      RefreshItemDisplay()
      -- show frame bankitems
      itemFrame:Show()
   end
end