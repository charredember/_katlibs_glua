local defaultValues = {
    --Pos - REQUIRED,
    --Ang - REQUIRED,
    --Model - REQUIRED,
    Color = Color(255,255,255,255),
    Material = "",
    Scale = Vector(1,1,1),
    --RenderGroup - NULLABLE,
    --RenderMode = NULLABLE,
    --Clip = NULLABLE,
    Submaterial = "",
}

local getPriv
---SHARED<br>
---Stores visual characteristics that express how to render a model in space.
---@class KModelData
---@overload fun(pos: Vector, ang: Angle, model: string): KModelData
KModelData,getPriv = KClass(function(pos,ang,model)
    KError.ValidateArg(1,"pos",KVarCondition.Vector(pos))
    KError.ValidateArg(2,"ang",KVarCondition.Angle(ang))
    KError.ValidateArg(3,"model",KVarCondition.String(model))

    return {
        Model = model,
        Pos = pos,
        Ang = ang,
    }
end)

---SHARED<br>
---@param value Vector
function KModelData:SetPos(value)
    KError.ValidateArg(1,"value",KVarCondition.Vector(value))
    getPriv(self).Pos = value
end

---SHARED<br>
---@return Vector
function KModelData:GetPos()
    return getPriv(self).Pos
end

---SHARED<br>
---@param value Angle
function KModelData:SetAng(value)
    KError.ValidateArg(1,"value",KVarCondition.Angle(value))
    getPriv(self).Ang = value
end

---SHARED<br>
---@return Angle
function KModelData:GetAng()
    return getPriv(self).Ang
end

---SHARED<br>
---@param value string
function KModelData:SetModel(value)
    KError.ValidateArg(1,"value",KVarCondition.String(value))
    getPriv(self).Model = value
end

---SHARED<br>
---@return string
function KModelData:GetModel()
    return getPriv(self).Model
end

---SHARED<br>
---@param value Color
function KModelData:SetColor(value)
    if value == defaultValues.Color then
        getPriv(self).Color = nil
        return
    end

    KError.ValidateArg(1,"value",KVarCondition.Color(value))
    getPriv(self).Color = value
end

---SHARED<br>
---@return Color
function KModelData:GetColor()
    return getPriv(self).Color or defaultValues.Color
end

---SHARED<br>
---@param value string
function KModelData:SetMaterial(value)
    if value == defaultValues.Material then
        getPriv(self).Material = nil
        return
    end

    KError.ValidateArg(1,"value",KVarCondition.String(value))
    getPriv(self).Material = value
end

---SHARED<br>
---@return string
function KModelData:GetMaterial()
    return getPriv(self).Material or defaultValues.Material
end

---SHARED<br>
---@param value Vector
function KModelData:SetScale(value)
    KError.ValidateArg(1,"value",KVarCondition.Vector(value))
    if value == defaultValues.Scale then
        getPriv(self).Scale = nil
        return
    end

    getPriv(self).Scale = value
end

---SHARED<br>
---@return Vector
function KModelData:GetScale()
    return getPriv(self).Scale or defaultValues.Scale
end

---SHARED<br>
---Allowed values:
--- - RENDERGROUP_OPAQUE
--- - RENDERGROUP_TRANSLUCENT
--- - RENDERGROUP_BOTH
---
---Set nil to unset specified RenderGroup
---@param value number?
function KModelData:SetRenderGroup(value)
    if value == nil then
        getPriv(self).RenderGroup = nil
        return
    end

    KError.ValidateArg(1,"value",KVarCondition.NumberInRange(value,7,9))
    getPriv(self).RenderGroup = value
end

---SHARED<br>
---**CAN RETURN NIL BECAUSE THERE IS NO DEFAULT RENDERGROUP**
---@return number?
function KModelData:GetRenderGroup()
    return getPriv(self).RenderGroup
end

---SHARED<br>
---Set nil to unset specified RenderMode
---@param value number?
function KModelData:SetRenderMode(value)
    if value == nil then
        getPriv(self).RenderMode = nil
        return
    end

    KError.ValidateArg(1,"value",KVarCondition.NumberInRange(value,0,10))
    getPriv(self).RenderMode = value
end

---SHARED<br>
---**CAN RETURN NIL BECAUSE THERE IS NO DEFAULT RENDERMODE**
---@return number?
function KModelData:GetRenderMode()
    return getPriv(self).RenderMode
end

---SHARED<br>
---Set localPos and localNormal to nil to remove a clip.
---@param key string
---@param localPos Vector?
---@param localNormal Vector?
function KModelData:SetClip(key,localPos,localNormal)
    KError.ValidateArg(1,"key",KVarCondition.String(key))

    local priv = getPriv(self)
    if localPos == nil and localNormal == nil then
        if not priv.Clip then return end
        priv.Clip[key] = nil
        if not next(priv.Clip) then priv.Clip = nil end
    else
        KError.ValidateArg(2,"localPos",KVarCondition.Vector(localPos))
        KError.ValidateArg(3,"localNormal",KVarCondition.Vector(localNormal))
        if not priv.Clip then priv.Clip = {} end

        priv.Clip[key] = {
            Pos = localPos,
            Normal = localNormal,
        }
    end
end

---SHARED<br>
---@param key string
---@return clip?
function KModelData:GetClip(key)
    local priv = getPriv(self)
    if not priv.Clip then return end
    return table.Copy(priv.Clip[key])
end

---@class clip
---@field Pos Vector
---@field Normal Vector

---SHARED<br>
---@return { [string]: clip }
function KModelData:GetClips()
    return table.Copy(getPriv(self).Clip or {})
end

---SHARED<br>
---@param index number
---@param value string
function KModelData:SetSubmaterial(index,value)
    KError.ValidateArg(1,"index",KVarCondition.NumberGreater(index,0))
    KError.ValidateArg(2,"value",KVarCondition.String(value))

    local priv = getPriv(self)

    if value == defaultValues.Submaterial then
        if not priv.Submaterial then return end
        priv.Submaterial[index] = nil
        if not next(priv.Submaterial) then priv.Submaterial = nil end
    else
        if not priv.Submaterial then priv.Submaterial = {} end
        priv.Submaterial[index] = value
    end
end

---SHARED<br>
---@param index number
function KModelData:GetSubmaterial(index)
    local priv = getPriv(self)
    if not priv.Submaterial then return "" end
    return priv.Submaterial[index] or ""
end

---SHARED<br>
---NOTE: The returned table has an __index metamethod that automatically <br>
---returns an empty string if there is no data at that index.
---@return table
function KModelData:GetSubmaterials()
    local defaultSubMatTable = setmetatable({},{__index = function()
        return defaultValues.Submaterial
    end})

    local submaterialTab = getPriv(self).Submaterial
    if not submaterialTab then return defaultSubMatTable end

    for k,v in pairs(submaterialTab) do
        rawset(defaultSubMatTable,k,v)
    end

    return defaultSubMatTable
end

---SHARED<br>
---Gets a JSON-serializable table representing this object that can be used to recreate this object later.
---@return table
function KModelData:GetSerializable()
    local priv = getPriv(self)
    ---@cast priv table
    return table.Copy(priv)
end

---SHARED,STATIC<br>
---Creates a new object populated with values from a table generated by GetSerializable().
---@param serializable table
---@return KModelData
function KModelData.FromSerializable(serializable)
    local newObject = KModelData(serializable.Pos,serializable.Ang,serializable.Model)

    if serializable.Color then newObject:SetColor(serializable.Color) end
    if serializable.Material then newObject:SetMaterial(serializable.Material) end
    if serializable.Scale then newObject:SetScale(serializable.Scale) end
    if serializable.RenderGroup then newObject:SetRenderGroup(serializable.RenderGroup) end
    if serializable.RenderMode then newObject:SetRenderMode(serializable.RenderMode) end

    if serializable.Clip then
        for key,clipData in pairs(serializable.Clip) do
            newObject:SetClip(key,clipData.Pos,clipData.Normal)
        end
    end

    if serializable.Submaterial then
        for key,subMaterial in pairs(serializable.Submaterial) do
            local index = tonumber(key)
            if not index then continue end
            newObject:SetSubmaterial(index,subMaterial)
        end
    end

    return newObject
end