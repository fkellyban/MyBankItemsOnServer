-- Color FKelly --
-- by LQI

FKColors  = {
    red     = "|cFFFF0000",
    green   = "|cFF00FF00",
    blue    = "|cFF0000FF",
    yellow  = "|cFFFFFF00",
    white   = "|cFFFFFFFF",
    orange  = "|cFFFFA500",
    purple  = "|cFF800080",
    grey    = "|cFFAAAAAA",
    black   = "|cFF000000",
}

-- function for colorate the text
function color(nom, texte)
    local code = FKColors[nom:lower()]
    if not code then
        return texte -- return the text if no color is retrieve
    end
    return code .. texte .. "|r"
end