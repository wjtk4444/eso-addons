Teleport.SurveyMaps = { }

local info = Teleport.info
local dbg  = Teleport.dbg

-------------------------------------------------------------------------------    

local SURVEY_PATTERN = ".- Survey: (.+)"
local MAP_PATTERN = "(.-) Treasure Map"

function Teleport.SurveyMaps:teleportToNext()
    for index = 1, GetBagSize(BAG_BACKPACK) do 
        local name = GetItemName(BAG_BACKPACK, index)
        local zone = string.match(name, SURVEY_PATTERN)
        if zone == nil then
            zone = string.match(name, MAP_PATTERN)
        end
        if zone ~= nil then
            while string.sub(zone, -1) == 'I' do
                zone = string.sub(zone, 1, -2)
            end
            
            if Teleport.Zones:teleportToZone(zone) then return end
        end    
    end
    info("No more crafting surveys found")
end
