table.sort(ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData[2], function(a, b) return a.rawName < b.rawName end)
table.sort(ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData[3], function(a, b) return a.rawName < b.rawName end)
ZO_ACTIVITY_FINDER_ROOT_MANAGER:UpdateLocationData()
