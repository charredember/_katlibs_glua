
---@class KPropertyParameters
---@field Required boolean?
---@field Sanitizer fun(value: any)?

---SHARED<br/>
---Data struct implementation. Sanitization for setting values without the overhead of a KClass.<br/>
---@class KDataType
---@overload fun(setupTable: {[string]: KPropertyParameters}) : (class: table, getPriv: KClassPrivGetter)
KDataType = setmetatable({},{
	__call = function(_,setupTable)
		local classMetatable = {}
		local class = setmetatable({},classMetatable)

		local sanitizers = {}
		local required = {}
		for propertyName,propertyInfo in pairs(setupTable) do
			local indexName = "setupTable." .. propertyName

			KError.ValidateKVArg(indexName,
				KVarConditions.String(propertyName),
				KVarConditions.Table(propertyInfo))

			if propertyInfo.Required == true then
				required[propertyName] = true
			end

			local sanitizer = KError.ValidateNullableArg(indexName .. ".Sanitizer",KVarConditions.Function(propertyInfo.Sanitizer))
			sanitizers[propertyName] = sanitizer
		end

		classMetatable.__call = function(_,setProperties)
			setProperties = setProperties or {}

			local structMetatable = {}
			local struct = setmetatable({},structMetatable)

			local structPriv = {}
			structMetatable.__index = structPriv
			structMetatable.__newindex = function(_,k,v)
				local sanitizer = sanitizers[k]
				if sanitizer then sanitizer(v) end
				structPriv[k] = v
			end

			for propertyName,_ in pairs(required) do
				local value = setProperties[propertyName]
				assert(value ~= nil,string.format("Missing required property [%s]!",propertyName))
				struct[propertyName] = value
			end

			return struct
		end

		return class
	end
})
