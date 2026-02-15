local classes = setmetatable({},{__mode = "k"})

local currObj,baseClassArgs

local function getObjectFactory(inheritedClass,newClass,constructor,privateTable)
	return function(...)
		local newObj = setmetatable({},{__index = newClass})
		currObj = newObj
		baseClassArgs = nil

		local constructorPriv = constructor(...) or {}

		if inheritedClass then
			if not baseClassArgs then error("Failed to call baseclass constructor in inherited newClass!") end
			local priv = inheritedClass(unpack(baseClassArgs))
			table.Merge(priv,constructorPriv,true)
			privateTable[newObj] = priv
		else
			privateTable[newObj] = constructorPriv
		end

		currObj = nil
		return newObj
	end
end

---@class KClassParams
---@field Inherit KClass?
---@field PrivateConstructor boolean?

---SHARED<br>
---OOP implementation<br>
---
---params:
--- - boolean? privateConstructor
--- - table? Inherit
---@class KClass
---@overload fun(constructor: fun(...): table?, params: KClassParams) : (table, fun(any: any): table?)
KClass = setmetatable({},{
	__call = function(_,constructor,params)
		constructor = constructor or function(...) end
		KError.ValidateArg(1,"constructor",KVarCondition.Function(constructor))
		if params.Inherit then KError.ValidateArg(2,"params.Inherit",KVarCondition.Table(params.Inherit)) end

		local privateTable = setmetatable({},{_mode = "k"})
		local function getPriv(obj) return privateTable[obj] end

		local newClass = {}
		classes[newClass] = true

		local instantiateNewObject = getObjectFactory(params.Inherit,newClass,constructor,privateTable)
		privateTable[newClass].__constructor = instantiateNewObject

		local classMetaTable = {}
		classMetaTable.__index = params.Inherit
		if not params.PrivateConstructor then
			classMetaTable.__call = function(_,...) return instantiateNewObject(...) end
		end
		setmetatable(newClass,classMetaTable)
		return newClass,getPriv
	end
})

---SHARED<br>
---Get the current public object being instantiated.<br>
---<b><u>Can only be called inside constructors!<u/><b/>
function KClass.GetSelf()
	return currObj
end

---SHARED<br>
---Calls the baseclass constructor for inheritance.<br>
---<b><u>Can only be called inside constructors!<u/><b/>
function KClass.CallBaseConstructor(...)
	baseClassArgs = {...}
end