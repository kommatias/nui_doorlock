ESX = nil
local doorInfo = {}

Citizen.CreateThread(function()
	local xPlayers = #ESX.GetPlayers()
	local path = GetResourcePath(GetCurrentResourceName())
	path = path:gsub('//', '/')..'/server/states.json'
	local file = io.open(path, 'r')
	if not file or xPlayers == 0 then
		file = io.open(path, 'a')
		for k,v in pairs(Config.DoorList) do
			doorInfo[k] = v.locked
		end
	else
		local data = file:read('*a')
		file:close()
		if #json.decode(data) > #Config.DoorList then -- Config.DoorList contains less doors than states.json, so don't restore states
			return
		elseif #json.decode(data) > 0 then
			for k,v in pairs(json.decode(data)) do
				doorInfo[k] = v
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
	  return
	end
	local path = GetResourcePath(resourceName)
	path = path:gsub('//', '/')..'/server/states.json'
	local file = io.open(path, 'r+')
	if file and doorInfo then
		local json = json.encode(doorInfo)
		file:write(json)
		file:close()
	end
end)

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('nui_doorlock:updateState')
AddEventHandler('nui_doorlock:updateState', function(doorID, locked, src)
	local xPlayer = ESX.GetPlayerFromId(source)

	if type(doorID) ~= 'number' then
		print(('nui_doorlock: %s didn\'t send a number!'):format(xPlayer.identifier))
		return
	end

	if type(locked) ~= 'boolean' then
		print(('nui_doorlock: %s attempted to update invalid state! (%s)'):format(xPlayer.identifier), locked)
		return
	end

	if not Config.DoorList[doorID] then
		print(('nui_doorlock: %s attempted to update invalid door!'):format(xPlayer.identifier))
		return
	end

	if not Config.DoorList[doorID].lockpick and not IsAuthorized(xPlayer.job.name, xPlayer.job.grade, Config.DoorList[doorID]) then
		print(('nui_doorlock: %s was not authorized to open a locked door!'):format(xPlayer.identifier))
		return
	end

	doorInfo[doorID] = locked
	if not src then TriggerClientEvent('nui_doorlock:setState', -1, doorID, locked)
	else TriggerClientEvent('nui_doorlock:setState', -1, doorID, locked, src) end
end)

ESX.RegisterServerCallback('nui_doorlock:getDoorInfo', function(source, cb)
	cb(doorInfo)
end)

function IsAuthorized(jobName, grade, doorID)
	for job,rank in pairs(doorID.authorizedJobs) do
		if job == jobName and rank <= grade then
			return true
		end
	end

	return false
end

RegisterCommand('newdoor', function(playerId, args, rawCommand)
	TriggerClientEvent('nui_doorlock:newDoorSetup', playerId, args)
end, true)

RegisterServerEvent('nui_doorlock:newDoorCreate')
AddEventHandler('nui_doorlock:newDoorCreate', function(model, heading, coords, jobs, doorLocked, maxDistance, slides, garage, doubleDoor)
	xPlayer = ESX.GetPlayerFromId(source)
	if not IsPlayerAceAllowed(source, 'command.newdoor') then print(xPlayer.getName().. 'attempted to create a new door but does not have permission') return end
	doorLocked = tostring(doorLocked)
	slides = tostring(slides)
	garage = tostring(garage)
	local doorConfig = [[
	{
		authorizedJobs = { ]]..jobs..[[ },
		locked = ]]..doorLocked..[[,
		maxDistance = ]]..maxDistance..[[,]]
	if not doubleDoor then
		doorConfig = doorConfig..[[

		objHash = ]]..model..[[,
		objHeading = ]]..heading..[[,
		objCoords = ]]..coords..[[,
		fixText = false,
		garage = ]]..garage..[[,
	]]
	else
		doorConfig = doorConfig..[[

		doors = {
			{objHash = ]]..model[1]..[[, objHeading = ]]..heading[1]..[[, objCoords = ]]..coords[1]..[[},
			{objHash = ]]..model[2]..[[, objHeading = ]]..heading[2]..[[, objCoords = ]]..coords[2]..[[}
		},
	]]
	end
	doorConfig = doorConfig..[[
	slides = ]]..slides..[[,
		audioLock = nil,
		audioUnlock = nil,
		audioRemote = false
	}]]
	local path = GetResourcePath(GetCurrentResourceName())
	path = path:gsub('//', '/')..'/config.lua'

	file = io.open(path, 'a+')
	file:write('\n\n-- UNNAMED DOOR CREATED BY '..xPlayer.getName()..'\n	table.insert(Config.DoorList,'..doorConfig..')')
	file:close()
end)


-- Test command that causes all doors to change state
--[[RegisterCommand('testdoors', function(playerId, args, rawCommand)
	for k, v in pairs(doorInfo) do
		if v == true then lock = false else lock = true end
		doorInfo[k] = lock
		TriggerClientEvent('nui_doorlock:setState', -1, k, lock)
	end
end, true)
--]]


-- VERSION CHECK
CreateThread(function()
    local resourceName = GetCurrentResourceName()
    local currentVersion, latestVersion = GetResourceMetadata(resourceName, 'version')
    local outdated = '^6[%s]^3 Version ^2%s^3 is available! You are using version ^1%s^7'
    Citizen.Wait(2000)
    while Config.CheckVersion do
        Citizen.Wait(0)
        PerformHttpRequest(GetResourceMetadata(resourceName, 'versioncheck'), function (errorCode, resultData, resultHeaders)
            if errorCode ~= 200 then print("Returned error code:" .. tostring(errorCode)) else
                local data, version = tostring(resultData)
                for line in data:gmatch("([^\n]*)\n?") do
                    if line:find('^version') then version = line:sub(10, (line:len(line) - 1)) break end
                end         
                latestVersion = version
            end
        end)
        if latestVersion then 
            if currentVersion ~= latestVersion then
                print(outdated:format(resourceName, latestVersion, currentVersion))
            end
            Citizen.Wait(60000*Config.CheckVersionDelay)
        end
    end
end)
