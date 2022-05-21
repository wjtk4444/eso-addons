function ZO_SocialManager:ProcessDisplayName(stringSearch, data, searchTerm, cache)
    local lowerSearchTerm = searchTerm:lower()

    if(zo_plainstrfind(data.displayName:lower(), lowerSearchTerm)) then
        return true
    end

    if(data.characterName ~= nil and zo_plainstrfind(data.characterName:lower(), lowerSearchTerm)) then
        return true
    end

	if(data.note ~= nil and zo_plainstrfind(data.note:lower(), lowerSearchTerm)) then
		return true
	end
end