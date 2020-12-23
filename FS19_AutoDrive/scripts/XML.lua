function AutoDrive.loadStoredXML()
    if g_server == nil then
        return
    end

    local xmlFile = AutoDrive.getXMLFile()
    local xmlFile_new = AutoDrive.getXMLFile_new()

    if fileExists(xmlFile_new) then
        g_logManager:devInfo("[AutoDrive] Loading xml file from " .. xmlFile_new)
        AutoDrive.adXml = loadXMLFile("AutoDrive_XML", xmlFile_new)
        AutoDrive.readFromXML(AutoDrive.adXml)
    elseif fileExists(xmlFile) then
        g_logManager:devInfo("[AutoDrive] Loading xml file from " .. xmlFile)
        AutoDrive.adXml = loadXMLFile("AutoDrive_XML", xmlFile)
        AutoDrive.readFromXML(AutoDrive.adXml)
        AutoDrive.adXml = createXMLFile("AutoDrive_XML", xmlFile_new, "AutoDrive") -- use the new file name onwards
        saveXMLFile(AutoDrive.adXml)
    else
        AutoDrive.loadInitConfig(xmlFile_new)
    end
end

function AutoDrive.loadInitConfig(xmlFile, createNewXML)
    createNewXML = createNewXML or true

    local initConfFile = AutoDrive.directory .. "AutoDrive_init_config.xml"

    if fileExists(initConfFile) then
        g_logManager:devInfo("[AutoDrive] Loading init config from " .. initConfFile)
        local xmlId = loadXMLFile("AutoDrive_XML_temp", initConfFile)
        AutoDrive.readFromXML(xmlId)
        delete(xmlId)
    else
        g_logManager:devWarning("[AutoDrive] Can't load init config from " .. initConfFile)
        -- Loading custom init config from mod map
        initConfFile = g_currentMission.missionInfo.map.baseDirectory .. "AutoDrive_init_config.xml"
        if fileExists(initConfFile) then
            g_logManager:devInfo("[AutoDrive] Loading init config from " .. initConfFile)
            local xmlId = loadXMLFile("AutoDrive_XML_temp", initConfFile)
            AutoDrive.readFromXML(xmlId)
            delete(xmlId)
        else
            g_logManager:devWarning("[AutoDrive] Can't load init config from " .. initConfFile)
        end
    end

    ADGraphManager:markChanges()
    g_logManager:devInfo("[AutoDrive] Saving xml file to " .. xmlFile)
    if createNewXML then
        AutoDrive.adXml = createXMLFile("AutoDrive_XML", xmlFile, "AutoDrive")
        saveXMLFile(AutoDrive.adXml)
    end
end

function AutoDrive.getXMLFile()
    local path = g_currentMission.missionInfo.savegameDirectory
    if path ~= nil then
        return path .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml"
    else
        return getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/AutoDrive_" .. AutoDrive.loadedMap .. "_config.xml"
    end
end

function AutoDrive.getXMLFile_new()
    local path = g_currentMission.missionInfo.savegameDirectory
    if path ~= nil then
        return path .. "/AutoDrive_config.xml"
    else
        return getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/AutoDrive_config.xml"
    end
end

function AutoDrive.readFromXML(xmlFile)
    if xmlFile == nil then
        return
    end

    AutoDrive.HudX = getXMLFloat(xmlFile, "AutoDrive.HudX")
    AutoDrive.HudY = getXMLFloat(xmlFile, "AutoDrive.HudY")
    AutoDrive.showingHud = getXMLBool(xmlFile, "AutoDrive.HudShow")

    AutoDrive.currentDebugChannelMask = getXMLInt(xmlFile, "AutoDrive.currentDebugChannelMask") or 0

    for settingName, setting in pairs(AutoDrive.settings) do
        if not setting.isVehicleSpecific then
            local value = getXMLFloat(xmlFile, "AutoDrive." .. settingName)
            if value ~= nil then
                AutoDrive.settings[settingName].current = value
            end
        end
    end

    for feature, _ in pairs(AutoDrive.experimentalFeatures) do
        AutoDrive.experimentalFeatures[feature] = Utils.getNoNil(getXMLBool(xmlFile, "AutoDrive.experimentalFeatures." .. feature .. "#enabled"),
                                                                 AutoDrive.experimentalFeatures[feature])
    end

    ADGraphManager:resetMapMarkers()

    local mapMarker = {}
    local mapMarkerCounter = 1

    while mapMarker ~= nil do
        local path = "AutoDrive.mapmarker.mm" .. tostring(mapMarkerCounter)

        if not hasXMLProperty(xmlFile, path) then
            mapMarker = nil
            break
        end

        mapMarker.id = getXMLFloat(xmlFile, path .. ".id")
        mapMarker.name = getXMLString(xmlFile, path .. ".name")
        mapMarker.group = getXMLString(xmlFile, path .. ".group") or "All"
        mapMarker.markerIndex = mapMarkerCounter
        mapMarker.restriction_mode = getXMLString(xmlFile, path .. ".restriction#mode") or "whitelist"
        g_logManager:info("[ADAH] Loaded restriction for map marker " .. mapMarker.name .. " with mode: " .. tostring(mapMarker.restriction_mode))
        mapMarker.restrictions = {}
        local vname = ""
        while vname ~= nil do
            local id = #mapMarker.restrictions + 1
            vname = getXMLString(xmlFile, path .. ".restriction.vehicle-" .. id)
            if vname ~= nil then
                mapMarker.restrictions[id] = vname
                g_logManager:info("[ADAH] Added restriction for map marker " .. mapMarker.name .. ": " .. vname)
            end
        end

        ADGraphManager:setMapMarker(mapMarker)

        if ADGraphManager:getGroupByName(mapMarker.group) == nil then
            ADGraphManager:addGroup(mapMarker.group)
        end

        mapMarkerCounter = mapMarkerCounter + 1
        mapMarker = {}
    end
    -- done loading map markers and restrictionsrestrictions

    local idString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.id")
    if idString == nil or idString == "" then
        idString = getXMLString(xmlFile, "AutoDrive.waypoints.id")
    end

    -- maybe map was opened and saved, but no waypoints recorded with AutoDrive!
    if idString == nil then
        return
    end

    ADGraphManager:resetWayPoints()

    local idTable = idString:split(",")

    local xString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.x")
    if xString == nil or xString == "" then
        xString = getXMLString(xmlFile, "AutoDrive.waypoints.x")
    end
    local xTable = xString:split(",")

    local yString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.y")
    if yString == nil or yString == "" then
        yString = getXMLString(xmlFile, "AutoDrive.waypoints.y")
    end
    local yTable = yString:split(",")

    local zString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.z")
    if zString == nil or zString == "" then
        zString = getXMLString(xmlFile, "AutoDrive.waypoints.z")
    end
    local zTable = zString:split(",")

    local outString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.out")
    if outString == nil or outString == "" then
        outString = getXMLString(xmlFile, "AutoDrive.waypoints.out")
    end
    local outTable = outString:split(";")

    local outSplitted = {}
    for i, outer in pairs(outTable) do
        local out = outer:split(",")
        outSplitted[i] = out
        if out == nil then
            outSplitted[i] = {outer}
        end
    end

    local incomingString = getXMLString(xmlFile, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.incoming")
    if incomingString == nil or incomingString == "" then
        incomingString = getXMLString(xmlFile, "AutoDrive.waypoints.incoming")
    end

    local incomingTable = incomingString:split(";")
    local incomingSplitted = {}
    for i, outer in pairs(incomingTable) do
        local incoming = outer:split(",")
        incomingSplitted[i] = incoming
        if incoming == nil then
            incomingSplitted[i] = {outer}
        end
    end

    local wp_counter = 0
    for i, id in pairs(idTable) do
        if id ~= "" then
            wp_counter = wp_counter + 1
            local wp = {}
            wp["id"] = tonumber(id)
            wp["out"] = {}
            local out_counter = 1
            if outSplitted[i] ~= nil then
                for _, outStr in pairs(outSplitted[i]) do
                    local number = tonumber(outStr)
                    if number ~= -1 then
                        wp["out"][out_counter] = tonumber(outStr)
                        out_counter = out_counter + 1
                    end
                end
            end

            wp["incoming"] = {}
            local incoming_counter = 1
            if incomingSplitted[i] ~= nil then
                for _, incomingID in pairs(incomingSplitted[i]) do
                    if incomingID ~= "" then
                        local number = tonumber(incomingID)
                        if number ~= -1 then
                            wp["incoming"][incoming_counter] = tonumber(incomingID)
                            incoming_counter = incoming_counter + 1
                        end
                    end
                end
            end

            wp.x = tonumber(xTable[i])
            wp.y = tonumber(yTable[i])
            wp.z = tonumber(zTable[i])

            ADGraphManager:setWayPoint(wp)
        end
    end

    if ADGraphManager:getWayPointById(wp_counter) ~= nil then
        g_logManager:devInfo("[AutoDrive] Loaded %s waypoints", wp_counter)
    end

    for markerIndex, marker in pairs(ADGraphManager:getMapMarkers()) do
        if ADGraphManager:getWayPointById(marker.id) == nil then
            g_logManager:devInfo("[AutoDrive] mapMarker[" .. markerIndex .. "] : " .. marker.name ..
                                     " points to a non existing waypoint! Please repair your config file!")
        end
    end

    if AutoDrive.getDebugChannelIsSet(AutoDrive.DC_ROADNETWORKINFO) then
        -- if debug channel for road network was saved and loaded, the debug wayPoints shall be created
        ADGraphManager:createMarkersAtOpenEnds()
    end
    g_logManager:info("[AD] AutoDrive.readFromXML waypoints: %s", tostring(ADGraphManager:getWayPointsCount()))
    g_logManager:info("[AD] AutoDrive.readFromXML markers: %s", tostring(#ADGraphManager:getMapMarkers()))
    g_logManager:info("[AD] AutoDrive.readFromXML groups: %s", tostring(table.count(ADGraphManager:getGroups())))
end

function AutoDrive.saveToXML(xmlFile)
    if xmlFile == nil then
        g_logManager:devInfo("[AutoDrive] No valid xml file for saving the configuration")
        return
    end

    setXMLString(xmlFile, "AutoDrive.version", AutoDrive.version)
    setXMLString(xmlFile, "AutoDrive.MapName", AutoDrive.loadedMap)

    setXMLFloat(xmlFile, "AutoDrive.HudX", AutoDrive.HudX)
    setXMLFloat(xmlFile, "AutoDrive.HudY", AutoDrive.HudY)
    setXMLBool(xmlFile, "AutoDrive.HudShow", AutoDrive.Hud.showHud)

    setXMLInt(xmlFile, "AutoDrive.currentDebugChannelMask", AutoDrive.currentDebugChannelMask)

    for settingName, setting in pairs(AutoDrive.settings) do
        if not setting.isVehicleSpecific then
            setXMLFloat(xmlFile, "AutoDrive." .. settingName, AutoDrive.settings[settingName].current)
        else
            -- axel TODO - check if not used vehicle specific properties may be removed from config.xml
            -- removeXMLProperty(xmlFile, "AutoDrive." .. settingName)
        end
    end

    for feature, enabled in pairs(AutoDrive.experimentalFeatures) do
        setXMLBool(xmlFile, "AutoDrive.experimentalFeatures." .. feature .. "#enabled", enabled)
    end

    removeXMLProperty(AutoDrive.adXml, "AutoDrive." .. AutoDrive.loadedMap .. ".waypoints.markerID")

    removeXMLProperty(AutoDrive.adXml, "AutoDrive.waypoints.markerID")

    local idFullTable = {}

    local xTable = {}

    local yTable = {}

    local zTable = {}

    local outTable = {}

    local incomingTable = {}

    for i, p in pairs(ADGraphManager:getWayPoints()) do
        idFullTable[i] = p.id
        xTable[i] = string.format("%.3f", p.x)
        yTable[i] = string.format("%.3f", p.y)
        zTable[i] = string.format("%.3f", p.z)

        outTable[i] = table.concat(p.out, ",")
        if outTable[i] == nil or outTable[i] == "" then
            outTable[i] = "-1"
        end

        incomingTable[i] = table.concat(p.incoming, ",")
        if incomingTable[i] == nil or incomingTable[i] == "" then
            incomingTable[i] = "-1"
        end
    end

    if idFullTable[1] ~= nil then
        setXMLString(xmlFile, "AutoDrive.waypoints.id", table.concat(idFullTable, ","))
        setXMLString(xmlFile, "AutoDrive.waypoints.x", table.concat(xTable, ","))
        setXMLString(xmlFile, "AutoDrive.waypoints.y", table.concat(yTable, ","))
        setXMLString(xmlFile, "AutoDrive.waypoints.z", table.concat(zTable, ","))
        setXMLString(xmlFile, "AutoDrive.waypoints.out", table.concat(outTable, ";"))
        setXMLString(xmlFile, "AutoDrive.waypoints.incoming", table.concat(incomingTable, ";"))
    end

    local markerIndex = 1 -- used for clean index in saved config xml
    for i, marker in pairs(ADGraphManager:getMapMarkers()) do
        if not marker.isADDebug then -- do not save debug map marker
            local path = "AutoDrive.mapmarker.mm" .. tostring(markerIndex)
            setXMLFloat(xmlFile, path .. ".id", marker.id)
            setXMLString(xmlFile, path .. ".name", marker.name)
            setXMLString(xmlFile, path .. ".group", marker.group)
            -- setXMLBool(xmlFile, path .. ".restriction", (marker.restriction or false))
            markerIndex = markerIndex + 1
        end
    end

    saveXMLFile(xmlFile)
    if g_client == nil then
        g_logManager:info("[AD] AutoDrive.saveToXML waypoints: %s", tostring(ADGraphManager:getWayPointsCount()))
        g_logManager:info("[AD] AutoDrive.saveToXML markers: %s", tostring(#ADGraphManager:getMapMarkers()))
        g_logManager:info("[AD] AutoDrive.saveToXML groups: %s", tostring(table.count(ADGraphManager:getGroups())))
    end
end

function AutoDrive.writeGraphToXml(xmlId, rootNode, waypoints, markers, groups)
    -- writing waypoints
    removeXMLProperty(xmlId, rootNode .. ".waypoints")
    do
        local key = string.format("%s.waypoints", rootNode)
        setXMLInt(xmlId, key .. "#c", #waypoints)

        local xt = {}
        local yt = {}
        local zt = {}
        local ot = {}
        local it = {}

        -- localization for better performances
        local frmt = string.format
        local cnl = table.concatNil

        for i, w in pairs(waypoints) do
            xt[i] = frmt("%.2f", w.x)
            yt[i] = frmt("%.2f", w.y)
            zt[i] = frmt("%.2f", w.z)
            ot[i] = cnl(w.out, ",") or "-1"
            it[i] = cnl(w.incoming, ",") or "-1"
        end

        setXMLString(xmlId, key .. ".x", table.concat(xt, ";"))
        setXMLString(xmlId, key .. ".y", table.concat(yt, ";"))
        setXMLString(xmlId, key .. ".z", table.concat(zt, ";"))
        setXMLString(xmlId, key .. ".out", table.concat(ot, ";"))
        setXMLString(xmlId, key .. ".in", table.concat(it, ";"))
    end

    -- writing markers
    removeXMLProperty(xmlId, rootNode .. ".markers")
    for i, m in pairs(markers) do
        local key = string.format("%s.markers.m(%d)", rootNode, i - 1)
        setXMLInt(xmlId, key .. "#i", m.id)
        setXMLString(xmlId, key .. "#n", m.name)
        setXMLString(xmlId, key .. "#g", m.group)
    end

    -- writing groups
    removeXMLProperty(xmlId, rootNode .. ".groups")
    do
        local i = 0
        for name, id in pairs(groups) do
            local key = string.format("%s.groups.g(%d)", rootNode, i)
            setXMLString(xmlId, key .. "#n", name)
            setXMLInt(xmlId, key .. "#i", id)
            i = i + 1
        end
    end
end

function AutoDrive.readGraphFromXml(xmlId, rootNode)
    local wayPoints = {}
    local mapMarkers = {}
    local groups = {}
    -- reading waypoints
    do
        local key = string.format("%s.waypoints", rootNode)
        local waypointsCount = getXMLInt(xmlId, key .. "#c")
        local xt = getXMLString(xmlId, key .. ".x"):split(";")
        local yt = getXMLString(xmlId, key .. ".y"):split(";")
        local zt = getXMLString(xmlId, key .. ".z"):split(";")
        local ot = getXMLString(xmlId, key .. ".out"):split(";")
        local it = getXMLString(xmlId, key .. ".in"):split(";")

        -- localization for better performances
        local tnum = tonumber
        local tbin = table.insert
        local stsp = string.split

        for i = 1, waypointsCount do
            local wp = {id = i, x = tnum(xt[i]), y = tnum(yt[i]), z = tnum(zt[i]), out = {}, incoming = {}}
            if ot[i] ~= "-1" then
                for _, out in pairs(stsp(ot[i], ",")) do
                    tbin(wp.out, tnum(out))
                end
            end
            if it[i] ~= "-1" then
                for _, incoming in pairs(stsp(it[i], ",")) do
                    tbin(wp.incoming, tnum(incoming))
                end
            end
            wayPoints[i] = wp
            i = i + 1
        end
    end

    -- reading markers
    do
        local i = 0
        while true do
            local key = string.format("%s.markers.m(%d)", rootNode, i)
            if not hasXMLProperty(xmlId, key) then
                break
            end
            local id = getXMLInt(xmlId, key .. "#i")
            local name = getXMLString(xmlId, key .. "#n")
            local group = getXMLString(xmlId, key .. "#g")

            i = i + 1
            mapMarkers[i] = {id = id, name = name, group = group, markerIndex = i}
        end
    end

    -- reading groups
    do
        local i = 0
        while true do
            local key = string.format("%s.groups.g(%d)", rootNode, i)
            if not hasXMLProperty(xmlId, key) then
                break
            end
            local groupName = getXMLString(xmlId, key .. "#n")
            local groupNameId = Utils.getNoNil(getXMLInt(xmlId, key .. "#i"), i + 1)
            groups[groupName] = groupNameId
            i = i + 1
        end
    end

    -- fix group 'All' index (make sure it's always 1)
    if groups["All"] ~= 1 then
        groups["All"] = nil
        local newGroups = {}
        newGroups["All"] = 1
        local index = 2
        for name, _ in pairs(groups) do
            newGroups[name] = index
            index = index + 1
        end
        groups = newGroups
    end

    return wayPoints, mapMarkers, groups
end
