local s_format = string.format

---@class KPropertyParameters
---@field Required boolean?
---@field ReadOnly boolean?
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
		local readOnly = {}
		for propertyName,propertyInfo in pairs(setupTable) do
			local indexName = "setupTable." .. propertyName

			KError.ValidateKVArg(indexName,
				KVarConditions.String(propertyName),
				KVarConditions.Table(propertyInfo))

			if propertyInfo.Required == true then
				required[propertyName] = true
			end

			if propertyInfo.ReadOnly == true then
				readOnly[propertyName] = true
			end

			local sanitizer = KError.ValidateNullableArg(indexName .. ".Sanitizer",KVarConditions.Function(propertyInfo.Sanitizer))
			sanitizers[propertyName] = sanitizer
		end

		local structPrivLookup = setmetatable({},{__mode = "k"})

		classMetatable.__call = function(_,setProperties)
			setProperties = setProperties or {}

			local structMetatable = {}
			local struct = setmetatable({},structMetatable)

			local structPriv = {}
			structPrivLookup[struct] = structPriv

			for propertyName,_ in pairs(required) do
				local value = setProperties[propertyName]
				assert(value ~= nil,string.format("Missing required property [%s]!",propertyName))

				local sanitizer = sanitizers[propertyName]
				if sanitizer then sanitizer(value) end

				structPriv[propertyName] = value
			end

			structMetatable.__index = structPriv
			structMetatable.__newindex = function(_,k,v)
				assert(readOnly[k] == nil,s_format("Property [%s] is read-only!",k))

				local sanitizer = sanitizers[k]
				if sanitizer then sanitizer(v) end
				structPriv[k] = v
			end

			return struct
		end

		local function unwrap(struct)
			return structPrivLookup[struct]
		end

		return class,unwrap
	end
})
