local unpack = unpack
local setmetatable = setmetatable
local getmetatable = getmetatable
local newproxy = newproxy
local ProtectedCall = ProtectedCall

local classInternalsLookup = setmetatable({},{__mode = "k"})

---@class _KClassParams
---@field InheritedClass any? A class that this new class will derive from.
---@field Destructor fun(priv: table)? A destructor for objects of this class to be called when they are cleaned by the GC.
---@field Abstract boolean? Whether this class is abstract.

---@class _KClassPriv A table that holds the private members of a class or object.
---@field GetFactory any A method that returns a new constructor for this class.

---@alias KClassPrivGetter (fun(any: any): any) A function that is used to access the private table of a class or object.
---@alias KClassConstructor (fun(...): table?) A constructor for a KClass.

local baseClassArgs,currObj
local function implementInheritance(classInternals)
	local class = classInternals.Class
	local classMetatable = classInternals.Metatable
	local classPrivDirectory = classInternals.PrivDirectory
	local inheritedClass = classInternals.InheritedClass

	if inheritedClass then
		local inheritedInternals = classInternalsLookup[inheritedClass]
		classMetatable.__index = inheritedClass

		local inheritedPublicConstructor = inheritedInternals.PublicConstructor
		if not inheritedPublicConstructor then error("Cannot inherit from a KClass without a public constructor!") end

		local basePopulateObjectPriv = inheritedInternals.PopulateObjectPriv
		function classInternals.PopulateObjectPriv(object,constructor,...)
			baseClassArgs = nil
			local priv = constructor(...) or {}
			classPrivDirectory[object] = priv
			if not baseClassArgs then error("Failed to call KClass.CallBaseConstructor in inherited class!") end
			basePopulateObjectPriv(object,inheritedPublicConstructor,unpack(baseClassArgs))
			return priv
		end

		classInternals.ParentClasses = setmetatable({
			[class] = true,
		},{
			__mode = "k",
			__index = inheritedInternals.ParentClasses
		})
	else
		function classInternals.PopulateObjectPriv(object,constructor,...)
			local priv = constructor(...) or {}
			classPrivDirectory[object] = priv
			return priv
		end

		classInternals.ParentClasses = setmetatable({
			[class] = true,
		},{__mode = "k"})
	end
end

local destructors = setmetatable({},{__mode = "k"})
local function addDestructorToTable(tab,destructor,paramsTab)
	local userData = newproxy(true)
	destructors[tab] = userData
	getmetatable(tab).destructorUserData = userData
	getmetatable(userData).__gc = function()
		ProtectedCall(destructor,paramsTab)
	end
end

local function createObjectFactory(classInternals,constructor)
	local populateObjectPriv = classInternals.PopulateObjectPriv
	local destructor = classInternals.Destructor

	if destructor then
		return function(...)
			local object = setmetatable({},{__index = classInternals.Class})
			currObj = object
			local priv = populateObjectPriv(object,constructor,...)
			currObj = nil
			addDestructorToTable(object,destructor,priv)
			return object
		end
	end

	return function(...)
		local object = setmetatable({},{__index = classInternals.Class})
		currObj = object
		populateObjectPriv(object,constructor,...)
		currObj = nil
		return object
	end
end

local function implementPublicConstructor(classInternals)
	local classMetatable = classInternals.Metatable
	local publicConstructor = classInternals.PublicConstructor
	local abstract = classInternals.Abstract

	if not publicConstructor then return end

	if abstract then
		classMetatable.__call = function(_,...)
			error("This KClass is abstract and is not meant to be instantiated at this level!")
		end
		return
	end

	local publicFactory = createObjectFactory(classInternals,publicConstructor)
	classMetatable.__call = function(_,...)
		return publicFactory(...)
	end
end

---SHARED<br/>
---OOP implementation<br/>
---@class KClass
---@overload fun(publicConstructor?: KClassConstructor, params?: _KClassParams) : (class: table, getPriv: KClassPrivGetter)
KClass = setmetatable({},{
	__call = function(_,publicConstructor,params)
		params = params or {}
		KError.ValidateNullableArg("publicConstructor",KVarConditions.Function(publicConstructor))
		KError.ValidateNullableArg("params.Destructor",KVarConditions.Function(params.Destructor))
		KError.ValidateNullableArg("params.Abstract",KVarConditions.Bool(params.Abstract))
		assert(params.InheritedClass == nil or classInternalsLookup[params.InheritedClass] ~= nil,"params.InheritedClass is not a KClass!")

		local classMetatable = {}
		local class = setmetatable({},classMetatable)
		local classPrivDirectory = setmetatable({},{__mode = "k"})
		local classInternals = {
			Class = class,
			Metatable = classMetatable,
			PrivDirectory = classPrivDirectory,
			PublicConstructor = publicConstructor,
			InheritedClass = params.InheritedClass,
			Destructor = params.Destructor,
			Abstract = params.Abstract,
			--PopulateObjectPriv
		}
		classInternalsLookup[class] = classInternals

		implementInheritance(classInternals)
		implementPublicConstructor(classInternals)

		classPrivDirectory[class] = {
			GetFactory = function(constructor) return createObjectFactory(classInternals,constructor) end,
		}

		local function getPriv(obj)
			return classPrivDirectory[obj]
		end

		return class,getPriv
	end
})

---SHARED, STATIC<br/>
---Calls the baseclass constructor for inheritance.<br/>
---<b><u>Can only be called inside constructors!<u/><b/>
function KClass.CallBaseConstructor(...)
	baseClassArgs = {...}
end

---SHARED, STATIC<br/>
---Get the current public object being instantiated.<br/>
---<b><u>Can only be called inside constructors!<u/><b/>
function KClass.GetSelf()
	return currObj
end

---SHARED, STATIC<br/>
---Check if object is a KClass object instance.
---@param object any
---@param comparisonClass? any If supplied, checks if the object is or is derived from this class.
function KClass.Is(object,comparisonClass)
	if not istable(object) then return false end

	local objectClass = getmetatable(object).__index
	if not objectClass then return false end

	local classInternals = classInternalsLookup[objectClass]
	if not classInternals then return false end

	if not comparisonClass then return true end
	if not classInternals.ParentClasses[comparisonClass] then return false end
	return true
end

---SHARED, STATIC<br/>
---Get the stack traversal amount needed to reference the lua chunk where a KClass constructor is called.
function KClass.ConstructorStackSize() return 4 end
