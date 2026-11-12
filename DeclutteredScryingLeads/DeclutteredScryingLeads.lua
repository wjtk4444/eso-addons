local REWARD_TYPES = {
	["Motif Chapter"] = true,
	--["Furnishing"   ] = true,
	["Container"	] = true,
}

DeclutteredScryingLeadsData = {}

local function MatchAllAntiquitiesWithLeads(antiquityData)
	table.insert(DeclutteredScryingLeadsData, antiquityData)
	
	if antiquityData.numRecovered == 0 then return true end
	if antiquityData.requiresLead and not antiquityData.hasLead then return false end
	
	local rewardType = REWARDS_MANAGER:GetRewardContextualTypeString(antiquityData:GetRewardId())
    return REWARD_TYPES[rewardType]
end

ZO_SCRYABLE_ANTIQUITY_ALL_LEADS_SUBCATEGORY_DATA:SetAntiquityFilterFunction(MatchAllAntiquitiesWithLeads)