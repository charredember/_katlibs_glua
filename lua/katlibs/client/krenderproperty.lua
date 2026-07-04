local RENDERFUNCTION_TEMPLATE =
[[
%s

return function(drawCall)
%s
    drawCall()
%s
end
]]
local PARAMETER_LOCALIZATION = "local %s = Parameters.%s"
local FUNCTION_LOCALIZATION = "local %s = Functions.%s"
local FUNCTION_CALL = "    %s(%s)"

local t_count = table.Count
local t_concat = table.concat
local t_insert = table.insert
local t_sort = table.sort
local s_format = string.format
local util_TableToJSON = util.TableToJSON
local util_SHA256 = util.SHA256
local JSONToSequentialTable,compileRenderCall

---@class KVP_PropertyInfo
---@field SetupRenderCall function Called post-render to reset the renderstate.
---@field SetupParameters? any[] Parameters that will be passed into CleanupRenderCall post-render.
---@field CleanupRenderCall? function Called post-render to reset the renderstate.
---@field CleanupParameters? any[] Parameters that will be passed into CleanupRenderCall post-render.

local getPriv
---CLIENT<br/>
---Extendable readable and writable description of a rendering property.
---@class KRenderProperty
KRenderProperty,getPriv = KClass()

do --methods
    ---CLIENT<br/>
    ---Returns the property ID of this KRenderProperty.<br/>
    function KRenderProperty:GetPropertyID()
        return getPriv(self).PropertyID
    end

    ---CLIENT<br/>
    ---Returns the parameters saved in this KRenderProperty.<br/>
    function KRenderProperty:GetParameters()
        return table.Copy(getPriv(self).JsonParameters)
    end
end

do --static functions
    local jsonConstructors = {}
    local instantiate = getPriv(KRenderProperty).Instantiate
    ---CLIENT, STATIC<br/>
    ---Defines a new visual property that modifies a render call.<br/>
    --- - <b>Ensure all constructor arguments are JSON serializable!<b><br/>
    ---@param propertyID string
    ---@param constructor fun(...): KVP_PropertyInfo
    ---@return fun(...): KRenderProperty
    function KRenderProperty.Register(propertyID,constructor)
        jsonConstructors[propertyID] = constructor
        return function(...)
            local propertyInfo = constructor(...)
            if not propertyInfo.SetupParameters then error("Property implementation error: Missing required SetupRenderCall definition!",2) end

            return instantiate({
                PropertyID = propertyID,
                JsonParameters = {...},
                SetupRenderCall = propertyInfo.SetupRenderCall,
                SetupParameters = propertyInfo.SetupParameters,
                CleanupRenderCall = propertyInfo.CleanupRenderCall,
                CleanupParameters = propertyInfo.CleanupParameters,
            })
        end
    end

    ---STATIC, CLIENT<br/>
    ---Writes a KRenderProperty to a KWriteStream.
    ---@param stream KWriteStream
    ---@param properties KRenderProperty[]
    function KRenderProperty.WriteToStream(stream,properties)
        local count = #properties
        stream:WriteUInt8(count)
        for i = 1,count do
            local priv = getPriv(properties[i])
            stream:WriteString(priv.PropertyID)
            stream:WriteString(util_TableToJSON(priv.JsonParameters))
        end
    end

    ---STATIC, CLIENT<br/>
    ---Reads a KRenderProperty from a KReadStream.
    ---@param stream KReadStream
    ---@return KRenderProperty[]
    function KRenderProperty.ReadFromStream(stream)
        local count = stream:ReadUInt8()
        local result = {}

        for _ = 1,count do
            local propertyID = stream:ReadString()
            local constructor = jsonConstructors[propertyID]
            local parameters = JSONToSequentialTable(stream:ReadString())

            local propertyInfo = constructor(unpack(parameters))
            t_insert(result,instantiate({
                PropertyID = propertyID,
                JsonParameters = parameters,
                SetupRenderCall = propertyInfo.SetupRenderCall,
                SetupParameters = propertyInfo.SetupParameters,
                CleanupRenderCall = propertyInfo.CleanupRenderCall,
                CleanupParameters = propertyInfo.CleanupParameters,
            }))
        end

        return result
    end

    ---STATIC, CLIENT<br/>
    ---Hashes a set of KRenderProperties, ordering irrelevant.<br/>
    ---Useful for grouping geometry data that have the same render properties.
    ---@param properties KRenderProperty[]
    function KRenderProperty.GetUniqueHash(properties)
        local uniqueData = {}
        for _,property in ipairs(properties) do
            local priv = getPriv(property)
            t_insert(uniqueData,priv.PropertyID .. util_TableToJSON(priv.JsonParameters))
        end
        t_sort(uniqueData)
        return util_SHA256(t_concat(uniqueData))
    end

    ---STATIC, CLIENT<br/>
    ---Compiles multiple KRenderProperties into a single render function.
    ---@param properties KRenderProperty[]
    function KRenderProperty.Compile(properties)
        local env = {
            Parameters = {},
            Functions = {},
        }

        local localizations = {}
        local setupCalls = {}
        local cleanupCalls = {}

        local context = {}
        for _,property in ipairs(properties) do
            local priv = getPriv(property)

            context.FunctionName = "Setup" .. priv.PropertyID
            context.Function = priv.SetupRenderCall
            context.FunctionCalls = setupCalls
            context.Parameters = priv.SetupParameters
            compileRenderCall(env,localizations,context)

            context.FunctionName = "Cleanup" .. priv.PropertyID
            context.Function = priv.CleanupRenderCall
            context.FunctionCalls = cleanupCalls
            context.Parameters = priv.CleanupParameters
            compileRenderCall(env,localizations,context)
        end

        local code = s_format(RENDERFUNCTION_TEMPLATE,
            t_concat(localizations,"\n"),
            t_concat(setupCalls,"\n"),
            t_concat(cleanupCalls,"\n"))

        local renderFunc = CompileString(code,"KRenderProperty")
        setfenv(renderFunc,env)
        return renderFunc
    end
end

do --implementations
    ---CLIENT<br/>
    ---Forces all future draw operations to use a specific IMaterial.
    ---@type fun(materialName: string) : KRenderProperty
    KRenderProperty.ModelMaterialOverride = KRenderProperty.Register(
        "ModelMaterialOverride",
        function(materialName)
            return {
                SetupRenderCall = render.ModelMaterialOverride,
                SetupParameters = {Material(materialName)},
                CleanupRenderCall = render.ModelMaterialOverride,
            }
        end
    )

    ---CLIENT<br/>
    ---Sets the color modulation for upcoming render operations, such as rendering models.
    ---@type fun(red: number, green: number, blue: number) : KRenderProperty
    KRenderProperty.ColorModulation = KRenderProperty.Register(
        "ColorModulation",
        function(red,green,blue)
            return {
                SetupRenderCall = render.SetColorModulation,
                SetupParameters = {red,green,blue},
            }
        end
    )

    ---CLIENT<br/>
    ---Sets the alpha blending (or transparency) for upcoming render operations.
    ---@type fun(alpha: number) : KRenderProperty
    KRenderProperty.Blend = KRenderProperty.Register(
        "Blend",
        function(alpha)
            return {
                SetupRenderCall = render.SetBlend,
                SetupParameters = {alpha},
            }
        end
    )

    ---CLIENT<br/>
    ---Suppresses or enables any engine lighting for any upcoming render operation.
    ---@type fun() : KRenderProperty
    KRenderProperty.SuppressEngineLighting = KRenderProperty.Register(
        "SuppressEngineLighting",
        function()
            return {
                SetupRenderCall = render.SetBlend,
                SetupParameters = {true},
                CleanupRenderCall = render.ModelMaterialOverride,
                CleanupParameters = {true},
            }
        end
    )
end

do --helper functions
    function JSONToSequentialTable(json)
        local tab = util.JSONToTable(json)
        if not tab then error("Error deserializing JSON.") end

        local result = {}
        for k,v in pairs(tab) do
            result[tonumber(k)] = v
        end

        return result
    end

    function compileRenderCall(env,localizations,context)
        if not context.Function then return end

        local relevantParams = {}

        local parameterEnv = env.Parameters
        for _,param in ipairs(context.Parameters or {}) do
            local paramName = s_format("P%i",t_count(parameterEnv))

            --Localize the parameter at the top of the file.
            t_insert(localizations,s_format(PARAMETER_LOCALIZATION,paramName,paramName))

            --Where to access the parameter during localization.
            parameterEnv[paramName] = param

            --Used for stringbuilding function call.
            t_insert(relevantParams,paramName)
        end

        local funcName = context.FunctionName

        --Localize the function at the top of the file
        t_insert(localizations,s_format(FUNCTION_LOCALIZATION,funcName,funcName))

        --Where to access the function during localization
        env.Functions[funcName] = context.Function

        --Call the function during runtime.
        local args = t_concat(relevantParams,",")
        t_insert(context.FunctionCalls,s_format(FUNCTION_CALL,funcName,args))
    end
end