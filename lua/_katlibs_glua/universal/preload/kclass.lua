local t_Merge = table.Merge

local classDirectory = setmetatable({},{__mode = "k"})
local currObj,baseClassArgs

local function getObjectFactory(class,private_directory,constructor,inheritedClass)
	local class_private = private_directory[class]
	if inheritedClass and getmetatable(inheritedClass).__call == nil then
		error("Inheriting from a class without a public constructor is currently unsupported!")
	end

	return function(...)
		local object = setmetatable({},{__index = class})
		currObj = object
		baseClassArgs = nil

		local object_private = constructor(...) or {}
		setmetatable(object_private,{__index = class_private})

		if inheritedClass then
			if not baseClassArgs then error("Failed to call KClass.CallBaseConstructor in inherited class!") end

			local inheritedObject = inheritedClass(unpack(baseClassArgs))
			for name,member in pairs(inheritedClass) do
				if not isfunction(member) then continue end

				class[name] = function(arg1,...)
					if arg1 == object then arg1 = inheritedObject end
					return member(arg1,...)
				end
			end
		end

		private_directory[object] = object_private
		currObj = nil
		return object
	end
end

---SHARED<br>
---OOP implementation<br>
---@class KClass
---@overload fun(publicConstructor?: (fun(...): table), inheritedClass?: KClass) : (table, fun(any: any): table?)
KClass = setmetatable({},{
	__call = function(_,publicConstructor,inheritedClass)
		if publicConstructor then KError.ValidateArg(1,"constructor",KVarCondition.Function(publicConstructor)) end
		if inheritedClass then KError.ValidateArg(2,"inheritedClass",KVarCondition.Table(inheritedClass)) end

		local private_directory = {}
		local function getPriv(obj) return private_directory[obj] end

		local class_meta = {}
		local class = setmetatable({},class_meta)
		private_directory[class] = {
			GetFactory = function(privateConstructor)
				local instantiate = getObjectFactory(class,private_directory,privateConstructor,inheritedClass)
				return function(...)
					return instantiate(...)
				end
			end,
		}

		if publicConstructor then
			local instantiate = getObjectFactory(class,private_directory,publicConstructor,inheritedClass)
			class_meta.__call = function(_,...) return instantiate(...) end
		end

		classDirectory[class] = getPriv
		return class,getPriv
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
	print("setbaseclassargs",...)
	baseClassArgs = {...}
end