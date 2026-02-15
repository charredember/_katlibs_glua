---SHARED, STATIC<br>
---Time related utilities for program control flow and animation.
KTimeUtils = {}

local co_yield = coroutine.yield
local co_running = coroutine.running
local CurTime = CurTime
local assert = assert

local KError_ValidateArg = KError.ValidateArg
local KVarCondition_NumberGreater = KVarCondition.NumberGreater
local KVarCondition_Function = KVarCondition.Function

---SHARED, STATIC<br>
---A tween that runs inside a coroutine.<br>
---Blocks the current thread until the duration has finished.
---@param duration number
---@param func fun(up: number)
function KTimeUtils.TweenAsync(duration,func)
    assert(co_running(),"TweenAsync called outside of coroutine!")
    KError_ValidateArg(1,"duration",KVarCondition_NumberGreater(duration,0))
    KError_ValidateArg(2,"func",KVarCondition_Function(func))

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