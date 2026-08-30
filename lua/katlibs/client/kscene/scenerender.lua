---@class _KSceneInternal
local internal = {}

---@type {[string]: _KRenderPropertySet}
local propertySets = {}

---@type {[integer]: {[string]: boolean}}
local uidHashLookup = {}

local function callAll(functions)
    for _,func in pairs(functions) do
        func()
    end
end

hook.Add("PostDrawOpaqueRenderables","KScene",function()
    for _,propertySet in pairs(propertySets) do
        local renderPropertiesWrapper = propertySet.RenderPropertiesWrapper
        renderPropertiesWrapper(callAll,propertySet.Opaque)
    end
end)

hook.Add("PostDrawTranslucentRenderables","KScene",function()
    for _,propertySet in pairs(propertySets) do
        local renderPropertiesWrapper = propertySet.RenderPropertiesWrapper
        renderPropertiesWrapper(callAll,propertySet.Translucent)
    end
end)

---@class _KDrawGroup
---@field Meshes IMesh[]
---@field RenderProperties KRenderProperty
---@field StudioProperties KStudioProperty

---@param renderProperties KRenderProperty[]
local function getPropertySetOrNew(hash,renderProperties)
    local propertySet = propertySets[hash]
    if propertySet then return propertySet end

    local renderPropertiesWrapper = KRenderProperty.Compile(renderProperties)
    ---@class _KRenderPropertySet
    propertySet = {
        Opaque = {},
        Translucent = {},
        RenderPropertiesWrapper = renderPropertiesWrapper,
    }
    propertySets[hash] = propertySet
    return propertySet
end

---@param uid integer
local function getRegisteredHashesOrNew(uid)
    local registeredHashes = uidHashLookup[uid]
    if registeredHashes then return registeredHashes end
    registeredHashes = {}
    uidHashLookup[uid] = registeredHashes
    return registeredHashes
end

local switchAdd = {
    [RENDERGROUP_BOTH] = function(propertySet,uid,renderFunction)
        propertySet.Opaque[uid] = renderFunction
        propertySet.Translucent[uid] = renderFunction
    end,
    [RENDERGROUP_OPAQUE] = function(propertySet,uid,renderFunction)
        propertySet.Opaque[uid] = renderFunction
    end,
    [RENDERGROUP_TRANSLUCENT] = function(propertySet,uid,renderFunction)
        propertySet.Translucent[uid] = renderFunction
    end,
}

---@param uid integer
---@param renderProperties KRenderProperty[]
---@param renderGroup integer
---@param renderFunction fun()
function internal.AddToRenderStack(uid,renderProperties,renderGroup,renderFunction)
    local hash = KRenderProperty.GetUniqueHash(renderProperties)
    local propertySet = getPropertySetOrNew(hash,renderProperties)

    local switch = switchAdd[renderGroup]
    if switch then switch(propertySet,uid,renderFunction) end

    local registeredHashes = getRegisteredHashesOrNew(uid)
    registeredHashes[hash] = true
end

---@param uid integer
function internal.RemoveFromRenderStack(uid)
    local registeredHashes = getRegisteredHashesOrNew(uid)

    for hash,_ in pairs(registeredHashes) do
        local propertySet = propertySets[hash]

        local opaque = propertySet.Opaque
        propertySet.Opaque[uid] = nil

        local translucent = propertySet.Translucent
        propertySet.Translucent[uid] = nil

        if next(opaque) or next(translucent) then continue end
        propertySets[hash] = nil
    end

    uidHashLookup[uid] = nil
end

return internal