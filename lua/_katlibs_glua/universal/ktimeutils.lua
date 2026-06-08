---SHARED, STATIC<br/>
---Time related utilities for program control flow and animation.
KTimeUtils = {}

local co_yield = coroutine.yield
local co_running = coroutine.running
local CurTime = CurTime
local SysTime = SysTime
local assert = assert

local KError_ValidateArg = KError.ValidateArg
local KVarConditions_NumberGreater = KVarConditions.NumberGreater
local KVarConditions_Function = KVarConditions.Function

---SHARED, STATIC<br/>
---A tween that runs inside a coroutine.<br/>
---Blocks the current thread until the duration has finished.
---@param duration number
---@param func fun(up: number)
function KTimeUtils.TweenAsync(duration,func)
    assert(co_running(),"TweenAsync called outside of coroutine!")
    KError_ValidateArg("duration",KVarConditions_NumberGreater(duration,0))
    KError_ValidateArg("func",KVarConditions_Function(func))

    local savedTime = CurTime()
    local DT

    while true do
        DT = CurTime() - savedTime

        if DT <= duration then
            func(DT / duration)
        else
            func(1)
            break
        end

        co_yield()
    end
end

---SHARED, STATIC<br/>
---Executes a function-wrapped coroutine until:
--- - A specified quota is reached.
--- - The coroutine returns a value that is not nil.
---
--- <br/>
--- Forwards the result from the called coroutine when the coroutine finishes.
---@param quota number
---@param coroutineFunc function
function KTimeUtils.RunWrappedCoroutineWithQuota(quota,coroutineFunc)
    local savedTime = SysTime()
    while true do
        local result = coroutineFunc()
        if result ~= nil then return result end
        if (SysTime() - savedTime) > quota then return end
    end
end