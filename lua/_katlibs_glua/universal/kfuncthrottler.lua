if KFuncThrottler then return end

local uidItr = 0

local getPriv
---@class KFuncThrottler
---@overload fun(limiter: KRegenResourcePool): KFuncThrottler
---@return KFuncThrottler KFuncThrottler
---Controls how fast a function is executed based on a resource.
KFuncThrottler,getPriv = KClass(function(limiter)
    KError.ValidateArg(1,"limiter",KVarCondition.TableMeta(limiter,KRegenResourcePool,"KRegenResourcePool"))

    uidItr = uidItr + 1
    return {
        Limiter = limiter,
        Queue = KQueue(),
        UID = uidItr,
    }
end)

---Attempt to execute a function.<br>
---If resources do not allow, the function will instead be queued for when the resources are available.
---@param cost number
---@param func function
---@param ... any Arguments to pass.
function KFuncThrottler:Execute(cost,func,...)
    local priv = getPriv(self)
    local limiter = priv.Limiter
    local max = priv.Limiter:GetMax()
    KError.ValidateArg(1,"cost",KVarCondition.NumberInRange(cost,0,max))
    KError.ValidateArg(2,"func",KVarCondition.Function(func))

    local queue = priv.Queue

    if not queue:Any() and limiter:Use(cost) then
        func(...)
        return
    end

    queue:PushRight({cost,func,{...}})
    local hookName = "KFuncThrottler" .. priv.UID
    limiter:SetHook(hookName,function(currVal)
        local queued = queue:GetLeft()
        if not queued then
            limiter:SetHook(hookName,nil)
            return
        end

        local currCost = queued[1]
        if currCost > currVal then return end

        limiter:Use(currCost)
        queued[2](unpack(queued[3]))
        queue:PopLeft()
    end)
end