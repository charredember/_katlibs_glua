local MATERIAL_VAR_ALPHATEST = 256
local MATERIAL_VAR_TRANSLUCENT = 2097152

local getPriv
---CLIENT<br/>
---Properties that are relevant when rendering a Valve studio model.
---@class KStudioProperty
---@overload fun(renderMode?: integer, renderGroup?: integer): KStudioProperty
KStudioProperty,getPriv = KClass(function(renderMode,renderGroup)
    if renderMode == RENDERMODE_NORMAL then renderMode = nil end

    ---@class _KStudioPropertyPriv
    return {
        RenderMode = renderMode,
        RenderGroup = renderGroup,
    }
end)

---STATIC, CLIENT<br/>
---Extrapolates the studio properties based off given information.
---@param material string
---@param alpha number
---@return KStudioProperty
function KStudioProperty.Extrapolate(material,alpha)
    if alpha < 255 then return KStudioProperty(RENDERMODE_NORMAL,RENDERGROUP_TRANSLUCENT) end
    local materialFlags = Material(material):GetInt("$flags")
    if bit.band(materialFlags,MATERIAL_VAR_ALPHATEST) ~= 0 then return KStudioProperty(RENDERMODE_NORMAL,RENDERGROUP_BOTH) end
    if bit.band(materialFlags,MATERIAL_VAR_TRANSLUCENT) ~= 0 then return KStudioProperty(RENDERMODE_NORMAL,RENDERGROUP_BOTH) end
    return KStudioProperty(RENDERMODE_NORMAL,RENDERGROUP_OPAQUE)
end

---CLIENT<br/>
---Gets the render group of this studio property.
---@return integer?
function KStudioProperty:GetRenderGroup()
    return getPriv(self).RenderGroup
end

---CLIENT<br/>
---Gets the render mode of this studio property.
---@return integer?
function KStudioProperty:GetRenderMode()
    return getPriv(self).RenderMode
end

---CLIENT, STATIC<br/>
---Write KStudioProperty to a stream.
---@param stream KWriteStream
---@param studioProperty KStudioProperty
function KStudioProperty.WriteToStream(stream,studioProperty)
    local priv = getPriv(studioProperty)
    local renderMode = priv.RenderMode
    local renderGroup = priv.RenderGroup

    stream:WriteBool(renderMode ~= nil)
    if renderMode then stream:WriteUInt8(renderMode) end
    stream:WriteBool(renderGroup ~= nil)
    if renderGroup then stream:WriteUInt8(renderGroup) end
end

---CLIENT, STATIC<br/>
---Read KStudioProperty from a stream.
---@param stream KReadStream
---@return KStudioProperty
function KStudioProperty.ReadFromStream(stream)
    local renderMode = stream:ReadBool() and stream:ReadUInt8() or nil
    local renderGroup = stream:ReadBool() and stream:ReadUInt8() or nil
    return KStudioProperty(renderMode,renderGroup)
end

---STATIC, CLIENT<br/>
---Merges two KStudioProperties.
---Overwrites values in the destination with the source, unless the source values are nil.<br/>
---@param destination KStudioProperty
---@param source KStudioProperty
function KStudioProperty.Merge(destination,source)
    local destPriv = getPriv(destination)
    local sourcePriv = getPriv(source)

    if sourcePriv.RenderMode ~= nil then destPriv.RenderMode = sourcePriv.RenderMode end
    if sourcePriv.RenderGroup ~= nil then destPriv.RenderGroup = sourcePriv.RenderGroup end
end

local meta = getPriv(KStudioProperty).GetObjectMeta()
meta.__tostring = function(self)
    local priv = getPriv(self)
    return string.format("%i,%i",priv.RenderMode or RENDERMODE_NORMAL,priv.RenderGroup or RENDERMODE_NORMAL)
end