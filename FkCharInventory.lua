--FKCharInventory.lua
-- Assure-toi que la table globale existe
FKCI_DB = FKCI_DB or {}
local realm = GetRealmName()
FKCI_DB[realm] = FKCI_DB[realm] or {}

local slots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot",
    "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

local function CISaveCharacter()
    local name = UnitName("player")
    FKCI_DB[realm][name] = FKCI_DB[realm][name] or {}

    local charData = FKCI_DB[realm][name]
    charData.faction = UnitFactionGroup("player")
    charData.class = select(2, UnitClass("player"))
    charData.race = UnitRace("player")
    charData.sex = UnitSex("player")

    charData.items = {}

    for _, slotName in ipairs(slots) do
        local slotId = GetInventorySlotInfo(slotName)
        local itemLink = GetInventoryItemLink("player", slotId)
        charData.items[slotId] = itemLink
    end

    print("MultiCharacterViewer: personnage sauvegardé avec équipement")
    UIErrorsFrame:AddMessage("Char Inventory : personnage sauvegardé", 0, 1, 0, 1, 3)
end

-- Commande simple pour tester la sauvegarde
SLASH_FKCISAVE1 = "/fkcisave"
SlashCmdList["FKCISAVE"] = CISaveCharacter

-- Appelle CISaveCharacter automatiquement à la connexion
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", CISaveCharacter)

local frame = CreateFrame("Frame", "MCV_MainFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(450, 230)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetFrameStrata("HIGH")
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlightLarge")
frame.title:SetPoint("TOP", 0, -5)
frame.title:SetText("Fk Characters Inventories")

-- Dropdown menu pour choisir le personnage
local dropdown = CreateFrame("Frame", "MCV_CharDropdown", frame, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", 15, -40)

local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
infoText:SetPoint("TOPLEFT", 15, -80)
infoText:SetJustifyH("LEFT")
infoText:SetSize(400, 60)

local itemList = CreateFrame("Frame", nil, frame)
itemList:SetPoint("TOPLEFT", 15, -140)
itemList:SetSize(420, 320)

local function CIClearItems()
    for _, child in ipairs({itemList:GetChildren()}) do
        child:Hide()
    end
end

local itemButtons = {}

-- Display character
local function DisplayCharacter(name)
    local realm = GetRealmName()
    local charData = FKCI_DB and FKCI_DB[realm] and FKCI_DB[realm][name]
    if not charData then
        infoText:SetText("Pas de données pour ce personnage.")
        CIClearItems()
        return
    end

    infoText:SetText(string.format("Nom: %s\nFaction: %s\nRace: %s\nClasse: %s\nSexe: %s",
        name,
        charData.faction or "N/A",
        charData.race or "N/A",
        charData.class or "N/A",
        (charData.sex == 2 and "Homme") or (charData.sex == 3 and "Femme") or "Inconnu"
    ))

    CIClearItems()

    local row = 0
    for slotId, itemLink in pairs(charData.items or {}) do
        if itemLink then
            local btn = itemButtons[row + 1]
            if not btn then
                btn = CreateFrame("Button", nil, itemList)
                btn:SetSize(32, 32)
                btn.icon = btn:CreateTexture(nil, "BACKGROUND")
                btn.icon:SetAllPoints()
                btn:SetPoint("TOPLEFT", (row % 12) * 34, -math.floor(row / 12) * 34)
                itemButtons[row + 1] = btn
            end
            btn.icon:SetTexture(select(10, GetItemInfo(itemLink)) or 134400) -- icône de l'item ou un fallback
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:Show()
            row = row + 1
        end
    end
end

local function CIInitializeDropdown()
    local realm = GetRealmName()
    local charList = {}
    if FKCI_DB and FKCI_DB[realm] then
        for name in pairs(FKCI_DB[realm]) do
            table.insert(charList, name)
        end
        table.sort(charList)
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, name in ipairs(charList) do
            info.text = name
            info.func = function()
                UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
                DisplayCharacter(name)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    if #charList > 0 then
        UIDropDownMenu_SetSelectedName(dropdown, charList[1])
        DisplayCharacter(charList[1])
    else
        infoText:SetText("Aucun personnage enregistré.")
    end
end

-- accessor UI show/hide
function ShowCharInventory()
    if frame:IsShown() then
        frame:Hide()
    else
        CIInitializeDropdown()
        frame:Show()
    end
end

-- Commande pour afficher la fenêtre
SLASH_FKCI1 = "/fkci"
SlashCmdList["FKCI"] = ShowCharInventory()