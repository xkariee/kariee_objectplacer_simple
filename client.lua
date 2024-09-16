local mapCreating = false
local placeMode = true
local controlsDisable = {38, 46, 51, 54, 86, 103, 119, 153, 184, 206, 350, 351, 355, 356,   -- E
                        45, 81, 140, 250, 263, 310,                                         -- R
                        14, 15, 16, 17, 27, 50, 99, 115, 180, 181, 198, 241, 242, 261, 262, 335, -- Scroll wheel stuff
                        191,                                                                -- Enter
                        47,                                                                 -- G
                        36,                                                                 -- LControl
                        }
local color = {r = 255, g = 255, b = 255, a = 200}
local editorCoords = {}
local editorHeading = 45
local editorModel = nil
local editorObject = nil
local count = 0
local hasResult = false
local DeleteObjectMode = false -- Change to true if you want to be able to permanently remove world props with "R"


RegisterNetEvent('kariee_objectplacer:ClientConfirm', function(model)
    if not mapCreating then
        mapCreating = true
        editorModel = GetHashKey(model)
        StartEditor()
    else
        mapCreating = false
    end
end)

SpawnObject = function(model, coords, heading)
    local model = model
    local coords = coords
    local heading = heading
    local ped = PlayerPedId()
    
    if model then
        model = GetHashKey(model)
        if coords then
            if heading then
                TriggerServerEvent('kariee_objectplacer:SpawnObject', model, coords, heading, true)
            else
                TriggerServerEvent('kariee_objectplacer:SpawnObject', model, coords, 0, true)
            end
        else
            coords = GetEntityCoords(ped)
            heading = GetEntityHeading(ped)

            TriggerServerEvent('kariee_objectplacer:SpawnObject', model, coords, heading, true)
        end
    end
end

StartEditor = function()

    if not IsModelInCdimage(editorModel) then
        return
    end
    
    LoadModel(editorModel)
    
    Citizen.CreateThread(function() -- Main thread
        local ped = PlayerPedId()
        local editorHeading = GetGameplayCamRot()
        local outlined = {}
        
        while mapCreating do
            Wait(0)
            if placeMode or count < 2 then
                count = count + 1
            end

            DisableControls()

            if placeMode and count >= 3 or not placeMode and count ~= 0 then -- Will catch if for some reason switching from place mode to remove mode messes up the count
                DeleteEntity(editorObject)
                count = 0
            end

            local position = GetEntityCoords(ped)
            local hit, coords, entity = RayCastGamePlayCamera(1000.0)
            
            if placeMode then
                color = {r = 255, g = 255, b = 255, a = 200}
            else
                color = {r = 199, g = 34, b = 34, a = 200}
            end
            DrawLine(position.x, position.y, position.z + 0.5, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)

            -- Handle control input
            local scrollAmount = 5
            if IsControlPressed(1, 21) then -- LShift
                scrollAmount = 25
            elseif IsDisabledControlPressed(1, 36) then -- LControl
                scrollAmount = 1
            end
            if IsDisabledControlJustPressed(1, 16) then -- Scrollwheel down
                editorHeading = editorHeading + scrollAmount
            elseif IsDisabledControlJustPressed(1, 17) then -- Scrollwheel up
                editorHeading = editorHeading - scrollAmount
            end

            if not placeMode then
                if NetworkGetEntityIsNetworked(entity) then
                    local netid = NetworkGetNetworkIdFromEntity(entity)
                    if netid then
                        local ent = entity
                        for k, v in pairs(outlined) do
                            if k ~= ent then
                                SetEntityDrawOutline(k, false)
                                outlined[k] = nil
                            end
                        end
                        
                        if netid ~= 20282 then
                            SetEntityDrawOutline(ent, true)
                            outlined[ent] = true
                        end
                    end
                else
                    for k, v in pairs(outlined) do
                        SetEntityDrawOutline(k, false)
                        outlined[k] = nil
                    end
                end
            end

            if IsControlJustReleased(0, 177) then
                mapCreating = false
            end

            if IsDisabledControlJustReleased(1, 38) then -- E
                if placeMode then
                    TriggerServerEvent('kariee_objectplacer:SpawnObject', editorModel, editorCoords, editorHeading, true)
                    mapCreating = false
                else
                    if NetworkGetEntityIsNetworked(entity) then
                        local netid = NetworkGetNetworkIdFromEntity(entity)
                        if not netid then
                            local ent = entity
                            SetEntityAsMissionEntity(ent, 1, 1)
                            DeleteObject(ent)
                            SetEntityAsNoLongerNeeded(ent)
                        end
                        TriggerServerEvent('kariee_objectplacer:DeleteObject', netid)
                    end
                end
            end

            if IsDisabledControlJustPressed(1, 47) then -- G
                placeMode = not placeMode
                count = 0
            end

            if IsDisabledControlJustPressed(1, 191) then -- Enter
                GetUserInput()
            end
            
            -- Handle the drawing of the object
            if placeMode and count == 0 then
                editorCoords = coords
                editorObject = CreateTempObject(editorModel, editorCoords, editorHeading)
            end
        end
        
        SetModelAsNoLongerNeeded(editorModel)
        DeleteEntity(editorObject)
        editorObject = nil
    end)
end

CreateTempObject = function(model, coords, heading)
    local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true)
    SetEntityHeading(obj, heading)
    SetEntityAlpha(obj, 200, false)
    SetEntityDrawOutline(obj, true)
    return obj
end

CreatePermObject = function(model, coords, heading)
    local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true) -- client sided creation because it's less prone to breaking
    SetEntityHeading(obj, heading)
    FreezeEntityPosition(obj, true)
end
RegisterNetEvent('kariee_objectplacer:CreateObject_cl', CreatePermObject)

RayCastGamePlayCamera = function(distance)
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
    local adjustedRotation = {
		x = (math.pi / 180) * cameraRotation.x,
		y = (math.pi / 180) * cameraRotation.y,
		z = (math.pi / 180) * cameraRotation.z
	}
	local direction = {
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	local destination = {
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}
	local a, b, c, d, e = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
	return b, c, e
end

DisableControls = function()
    for k,v in pairs(controlsDisable) do
        DisableControlAction(2, v, true)
    end
end

LoadModel = function(modelHash) -- from qb-core
    if not HasModelLoaded(modelHash) then
		-- If the model isnt loaded we request the loading of the model and wait that the model is loaded
		RequestModel(modelHash)

		while not HasModelLoaded(modelHash) do
			Citizen.Wait(1)
		end
	end
end
