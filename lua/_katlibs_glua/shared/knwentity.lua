local activeEnts = {}

local n_Start = net.Start
local n_WriteUInt = net.WriteUInt
local n_ReadUInt = net.ReadUInt
local n_Broadcast = net.Broadcast
local IsValid = IsValid
local t_Simple = timer.Simple
local Entity = Entity
---@class Entity
local ent_meta = FindMetaTable("Entity")
local e_EntIndex = ent_meta.EntIndex

local NETSTRING_ENTREMOVED = "KEntityNetworking"

if SERVER then
    util.AddNetworkString(NETSTRING_ENTREMOVED)

    ---SERVER,STATIC<br>
    ---Writes an entity to the net message to be read as a KNWEntity clientside.
    ---@param ent Entity
    function net.WriteKNWEntity(ent)
        KError.ValidateArg(2,"ent",KVarCondition.Entity(ent))

        n_WriteUInt(e_EntIndex(ent),13)
        activeEnts[ent] = true
    end

    hook.Add("EntityRemoved","KNWEntity",function(ent)
        if not activeEnts[ent] then return end
        activeEnts[ent] = nil

        n_Start(NETSTRING_ENTREMOVED)
        n_WriteUInt(e_EntIndex(ent),13)
        n_Broadcast()
    end)
elseif CLIENT then
    local function callHooks(priv,hooktype,...)
        for _,func in pairs(priv.Hooks[hooktype]) do
            func(...)
        end
    end

    ---CLIENT<br>
    ---Gets an entity's KNWEntity.
    ---@return KNWEntity?
    function ent_meta:GetKNWEntity()
        return activeEnts[e_EntIndex(self)]
    end

    local getPriv
    ---CLIENT,STATIC<br>
    ---A clientside container for data about an entity that does not clear on clientside PVS deletion
    ---@class KNWEntity
    KNWEntity,getPriv = KClass()

    local privateConstructor = getPriv(KNWEntity).GetFactory(function(eid)
        return {
            EntIndex = eid,
            NWTime = SysTime(),
            IsFirstTimeNetworked = true,
            Active = false,
            Hooks = {
                OnInitialize = {},
                OnRemove = {},
            },
        }
    end)

    ---CLIENT<br>
    ---Reads a KNWEntity from a net message.
    ---@return KNWEntity
    function net.ReadKNWEntity()
        local eid = n_ReadUInt(13)
        local knwEnt = activeEnts[eid]

        if knwEnt then
            ---@class KNWEntity
            local priv = getPriv(knwEnt)
            priv.IsFirstTimeNetworked = false
            return knwEnt
        end

        knwEnt = privateConstructor(eid)
        activeEnts[eid] = knwEnt

        t_Simple(0,function()
            if not activeEnts[eid] then return end

            local ent = Entity(eid)
            if not IsValid(ent) then return end

            local priv = getPriv(knwEnt)
            priv.Active = true
            callHooks(priv,"OnInitialize",eid,ent)
        end)

        return knwEnt
    end

    ---CLIENT<br>
    ---Gets an KNWEntity's by its entity index, if it exists.
    ---@param eid KNWEntity?
    ---@return KNWEntity?
    function KNWEntity.GetByEntIndex(eid)
        return activeEnts[eid]
    end

    ---CLIENT<br>
    ---Gets an KNWEntity's Entity.
    ---@return Entity
    function KNWEntity:GetEntity()
        return Entity(getPriv(self).EntIndex)
    end

    ---CLIENT<br>
    ---Gets an KNWEntity's entity index.
    ---@return number
    function KNWEntity:EntIndex()
        return getPriv(self).EntIndex
    end

    ---CLIENT<br>
    ---Returns the time in seconds since this KNWEntity was registered.
    ---@return number
    function KNWEntity:GetNWLifetime()
        return SysTime() - getPriv(self).NWTime
    end

    ---CLIENT<br>
    ---Returns if this KNWEntity has only been registered once.
    ---@return boolean
    function KNWEntity:IsFirstTimeNetworked()
        return getPriv(self).IsFirstTimeNetworked
    end

    ---CLIENT<br>
    ---Register a hook with this KNWEntity.
    ---Hooks:
    --- - OnInitialize(number entIndex, Entity ent)
    --- - OnRemove(number entIndex)
    --- @param hooktype any
    --- @param id any
    --- @param func function?
    function KNWEntity:AddHook(hooktype,id,func)
        if func then KError.ValidateArg(3,"func",KVarCondition.Function(func)) end

        local hookTab = getPriv(self).Hooks[hooktype]
        if not hookTab then return end
        hookTab[id] = func
    end

    ---CLIENT<br>
    ---Calls a function if the KNWEntity's Entity is currently valid.
    --- @param func function
    function KNWEntity:CallIfValid(func,...)
        KError.ValidateArg(1,"func",KVarCondition.Function(func))
        if not IsValid(Entity(getPriv(self).EntIndex)) then return end
        func(...)
    end

    hook.Add("NetworkEntityCreated","KNWEntity",function(ent)
        if not IsValid(ent) then return end

        local eid = e_EntIndex(ent)
        local knwEnt = activeEnts[eid]
        if not knwEnt then return end

        callHooks(getPriv(knwEnt),"OnInitialize",eid,ent)
    end)

    net.Receive(NETSTRING_ENTREMOVED, function()
        local eid = n_ReadUInt(13)
        local knwEnt = activeEnts[eid]
        if not knwEnt then return end

        ---@class table
        local priv = getPriv(knwEnt)

        callHooks(priv,"OnRemove",eid)
        activeEnts[eid] = nil
        table.Empty(priv)
    end)
end