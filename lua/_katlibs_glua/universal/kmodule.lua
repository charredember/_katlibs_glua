if KModule then KModule.DisposeAll() end

local NETSTRING_KMODULE = "KModule"
if SERVER then util.AddNetworkString(NETSTRING_KMODULE) end

local NETSTRING_KMODULE_SETUP = "KModuleSetup"
local NET_ENUMS_SETUP = {
    --SV TO CL
    INITIALIZE_WITH_NETSTRING_UIDS = 1,
    NEW_NETSTRING_UID = 2,

    --CL TO SV
    AWAITING_NETSTRING_UIDS = 1,
    INITIALIZED = 2,
}

local netStartSetup,netReceiveSetup

local function getOrAddChildTable(parentTab,childTabKey,callbackIfAdd)
    local childTable = parentTab[childTabKey]
    if childTable ~= nil then return childTable end

    childTable = {}
    if callbackIfAdd then callbackIfAdd(childTable) end
    parentTab[childTabKey] = childTable
    return childTable
end

local function removeChildTableKey(parentTab,childTabKey,childKey,callbackIfChildTabEmpty)
    local childTable = parentTab[childTabKey]
    if not childTable then return end

    childTable[childKey] = nil
    if not table.IsEmpty(parentTab) then return end
    if not callbackIfChildTabEmpty then return end
    callbackIfChildTabEmpty()
end

local function obscureGlobalFunctionsInEnv(moduleEnv,globalLibraryName,functionTable)
    moduleEnv[globalLibraryName] = setmetatable(functionTable,{__index = _G[globalLibraryName]})
end

local function addGlobalHook(hookFunctionsTable,hookType,onHookError)
    hook.Add(hookType,"KModule",function(...)
        for key,func in pairs(hookFunctionsTable) do
            local worked,value
            if isstring(key) then
                worked,value = xpcall(func,onHookError,...)
            elseif not IsValid(key) then
                hookFunctionsTable[key] = nil
                continue
            else
                worked,value = xpcall(func,onHookError,key,...)
            end

            if not worked then
                hookFunctionsTable[key] = nil
                continue
            end

            if value ~= nil then return value end
        end
    end)
end

local function removeGlobalHook(hookType)
    hook.Remove(hookType,"KModule")
end

local activeModules = {}
local moduleHooks = {}
local netstringItr = -1
local netReceivers = {}

local getPriv
---@class KModule
---A pcall wrapper for code that allows for modular code that can be stopped at any time.
---@overload fun(moduleName: string, entryPoint: fun(...), env : table?): KModule
---@return KModule KModule
KModule,getPriv = KClass(function(moduleName,entryPoint,env)
    KError.ValidateArg(1,"moduleName",KVarCondition.String(moduleName))
    KError.ValidateArg(2,"entryPoint",KVarCondition.Function(entryPoint))
    if env then KError.ValidateArg(3,"env",KVarCondition.Table(env)) end

    if activeModules[moduleName] then activeModules[moduleName]:Dispose() end

    local valid = true
    local this = KClass.GetSelf()
    activeModules[moduleName] = this
    local localHooks = {}
    local disposeCBs = {}
    local localNetUIDLookup = {}

    local reportError,dispose,addDisposeCB,isValid
    local removeLocalHook,addLocalHook,onHookError
    local sendAllNetStringsToClient,updateWithNewNetstring,getNetUID
    local addNetworkString,netStartLocal,netReceiveLocal

    do --general
        function reportError(trace)
            hook.Run("KModuleError",moduleName,debug.traceback(trace,5))
        end

        function dispose()
            for hookType,tab in pairs(localHooks) do
                for hookName,_ in pairs(tab) do
                    removeLocalHook(hookType,hookName)
                end
            end

            for key,func in pairs(disposeCBs) do
                if istable(key) and not IsValid(key) then continue end
                xpcall(func,reportError)
            end

            for _,netUID in pairs(localNetUIDLookup) do
                netReceivers[netUID] = nil
            end

            valid = false
            activeModules[this] = nil
        end

        function addDisposeCB(key,callback)
            if callback then KError.ValidateArg(1,"key",KVarCondition.Function(callback)) end
            disposeCBs[key] = callback
        end

        function isValid() return valid end
    end

    do --hooks
        function onHookError(trace)
            dispose()
            reportError(trace)
        end

        function addLocalHook(hookType,hookName,callback)
            local function callbackIfNewHook(hookFunctionsTable)
                addGlobalHook(hookFunctionsTable,hookType,onHookError)
            end

            getOrAddChildTable(moduleHooks,hookType,callbackIfNewHook)[hookName] = callback
            getOrAddChildTable(localHooks,hookType)[hookName] = true
        end

        function removeLocalHook(hookType,hookName)
            local function callbackIfLastHook()
                removeGlobalHook(hookType)
            end

            removeChildTableKey(moduleHooks,hookType,hookName,callbackIfLastHook)
            removeChildTableKey(localHooks,hookType,hookName)
        end

        function runLocalHook(hookType,...)
            local hookTable = getOrAddChildTable(localHooks,hookType)
            local returns = {}
            for _,func in pairs(hookTable) do
                table.insert(returns,func(...))
                if #returns >= 6 then break end
            end
            return unpack(returns)
        end
    end

    do --net
        if SERVER then
            function sendAllNetStringsToClient(ply)
                netStartSetup(NET_ENUMS_SETUP.INITIALIZE_WITH_NETSTRING_UIDS)
                net.WriteString(moduleName)
                net.WriteUInt(table.Count(localNetUIDLookup),32)
                for netstring,netUID in pairs(localNetUIDLookup) do
                    net.WriteString(netstring)
                    net.WriteUInt(netUID,32)
                end
                net.Send(ply)
            end

            function addNetworkString(netstring)
                if localNetUIDLookup[netstring] then return end

                netstringItr = netstringItr + 1
                updateWithNewNetstring(netstring,netstringItr)

                netStartSetup(NET_ENUMS_SETUP.NEW_NETSTRING_UID)
                net.WriteString(moduleName)
                net.WriteString(netstring)
                net.WriteUInt(netstringItr,32)
                net.Broadcast()
            end
        elseif CLIENT then
            netStartSetup(NET_ENUMS_SETUP.AWAITING_NETSTRING_UIDS)
            net.WriteString(moduleName)
            net.SendToServer()
        end

        function updateWithNewNetstring(netstring,netUID)
            localNetUIDLookup[netstring] = netUID
        end

        function getNetUID(netstring)
            local netUID = localNetUIDLookup[netstring]
            if not netUID then error("Didn't pool network string using util.AddNetworkString serverside!") end
            return netUID
        end

        function netStartLocal(netstring)
            net.Start(NETSTRING_KMODULE)
            net.WriteUInt(getNetUID(netstring),32)
        end

        function netReceiveLocal(netstring,callback)
            netReceivers[getNetUID(netstring)] = callback
        end
    end

    local moduleEnv = setmetatable(env or {},{__index = _G})
    do --env setup
        if SERVER then
            obscureGlobalFunctionsInEnv(moduleEnv,"util",{
                AddNetworkString = addNetworkString,
            })
        end

        obscureGlobalFunctionsInEnv(moduleEnv,"hook",{
            Add = addLocalHook,
            Remove = removeLocalHook,
            Run = runLocalHook,
        })

        obscureGlobalFunctionsInEnv(moduleEnv,"net",{
            Start = netStartLocal,
            Receive = netReceiveLocal,
        })

        moduleEnv.CurrKModule = {
            AddDisposeCB = addDisposeCB,
            Dispose = dispose,
        }

        moduleEnv.CompileString = function(code,id,handleError)
            return setfenv(CompileString(code,id,handleError),moduleEnv)
        end
    end

    local function run()
        setfenv(entryPoint,moduleEnv)
        xpcall(entryPoint,onHookError)
    end
    if SERVER then run() end

    return {
        Name = moduleName,
        Dispose = dispose,
        IsValid = isValid,
        SendAllNetStringsToClient = sendAllNetStringsToClient,
        UpdateWithNewNetstring = updateWithNewNetstring,
        RunLocalHook = runLocalHook,
        Run = run,
    }
end)

function KModule:GetName() return getPriv(self).Name end
function KModule:Dispose() getPriv(self).Dispose() end
function KModule:IsValid() return getPriv(self).IsValid() end

function KModule.GetActiveModules()
    local result = {}
    for k,v in pairs(activeModules) do
        result[k] = v
    end

    return result
end

function KModule.DisposeAll()
    for _,v in pairs(activeModules) do
        v:Dispose()
    end
end

hook.Add("KatLibsLoaded","KModule",function()
    netStartSetup,netReceiveSetup = KEnumNetMsg(NETSTRING_KMODULE_SETUP,NET_ENUMS_SETUP)

    if SERVER then
        netReceiveSetup(NET_ENUMS_SETUP.AWAITING_NETSTRING_UIDS,function(ply)
            local moduleName = net.ReadString()
            local module = activeModules[moduleName]
            if not IsValid(module) then return end

            getPriv(module).SendAllNetStringsToClient(ply)
        end)

        netReceiveSetup(NET_ENUMS_SETUP.INITIALIZED,function(ply)
            local moduleName = net.ReadString()
            local module = activeModules[moduleName]
            if not IsValid(module) then return end

            getPriv(module).RunLocalHook("KModulePlayerInitialized",ply)
        end)
    elseif CLIENT then
        netReceiveSetup(NET_ENUMS_SETUP.INITIALIZE_WITH_NETSTRING_UIDS,function(ply)
            local moduleName = net.ReadString()
            local module = activeModules[moduleName]
            if not IsValid(module) then return end

            local priv = getPriv(module)
            local count = net.ReadUInt(32)

            for _ = 1,count do
                local netstring = net.ReadString()
                local netUID = net.ReadUInt(32)
                priv.UpdateWithNewNetstring(netstring,netUID)
            end
            priv.Run()
        end)

        netReceiveSetup(NET_ENUMS_SETUP.NEW_NETSTRING_UID,function(ply)
            local moduleName = net.ReadString()
            local module = activeModules[moduleName]
            if not IsValid(module) then return end

            local netstring = net.ReadString()
            local netUID = net.ReadUInt(32)
            getPriv(module).UpdateWithNewNetstring(netstring,netUID)
        end)
    end
end)

net.Receive(NETSTRING_KMODULE,function(len,ply)
    local netUID = net.ReadUInt(32)
    local netCallback = netReceivers[netUID]
    if not netCallback then return end
    netCallback(len,ply)
end)