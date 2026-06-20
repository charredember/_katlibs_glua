---@class Entity
local ent_meta = FindMetaTable("Entity")
local e_SetPos = ent_meta.SetPos
local e_SetAngles = ent_meta.SetAngles
local e_SetupBones = ent_meta.SetupBones
local e_DrawModel = ent_meta.DrawModel
local e_EnableMatrix = ent_meta.EnableMatrix
---@class VMatrix
local vm_meta = FindMetaTable("VMatrix")
local vm_SetScale = vm_meta.SetScale
local vm_GetTranslation = vm_meta.GetTranslation
local vm_GetAngles = vm_meta.GetAngles
local vm_GetScale = vm_meta.GetScale

local cam_GetModelMatrix = cam.GetModelMatrix
local IsValid = IsValid

local function modelExists(path)
	if string.find(path, "models/", 1, true) ~= 1 then return false end
	return file.Exists(path, "GAME")
end

---@class KAllocatedModel
---@field ClientsideEntity Entity
---@field Keys {[number] : boolean}

--not in priv table so we can change the clientside model when it goes invalid without having to update all private tables
local allocatedModelObjectLookup = setmetatable({},{__mode = "k"})
local allocatedModelsPathLookup = {}
local uidItr = 0

---CLIENT<br/>
---A wrapper class for clientside models that automatically handles memory management.
---@class KClientsideModel
---@overload fun(model: string): KClientsideModel
KClientsideModel = KClass(function(model)
	KError.ValidateArg("model",KVarConditions.StringNotEmpty(model))
	assert(modelExists(model),"Model does not exist!")

	local allocatedModel = allocatedModelsPathLookup[model]
	if not allocatedModel then
		allocatedModel = {
			Model = model,
			--ClientsideEntity
			Keys = {},
		}
		allocatedModelsPathLookup[model] = allocatedModel
	end

	uidItr = uidItr + 1
	local uid = uidItr

	allocatedModel.Keys[uid] = true
	allocatedModelObjectLookup[KClass.GetSelf()] = allocatedModel

	return setmetatable({
		UID = uid,
		Model = model,
	},allocatedModel)
end,{
	Destructor = function(priv)
		local model = priv.Model
		local allocatedModel = allocatedModelsPathLookup[model]
		local keys = allocatedModel.Keys

		keys[priv.UID] = nil
		if next(keys) then return end

		local csm = allocatedModel.ClientsideEntity
		if IsValid(csm) then csm:Remove() end
		allocatedModelsPathLookup[model] = nil
	end,
})

local scaleMatrix = Matrix()
local defaultScale = Vector(1,1,1)

---CLIENT<br/>
---Draws the clientside model.<br/>
---@param flags STUDIO?
function KClientsideModel:Draw(flags)
	local csm = allocatedModelObjectLookup[self].ClientsideEntity

	local currMatrix = cam_GetModelMatrix()

	local scale = vm_GetScale(currMatrix)
	if scale ~= defaultScale then
		vm_SetScale(scaleMatrix,scale)
		e_EnableMatrix(csm,"RenderMultiply",scaleMatrix)
	end

	e_SetPos(csm,vm_GetTranslation(currMatrix))
	e_SetAngles(csm,vm_GetAngles(currMatrix))
	e_SetupBones(csm)
	e_DrawModel(csm,flags)
end

---CLIENT,STATIC<br/>
---Gets the a table of model strings for all active KClientsideModels.<br/>
function KClientsideModel.GetActiveList()
	return table.GetKeys(allocatedModelsPathLookup)
end

hook.Add("PreRender","KClientsideModel",function()
	for _,allocatedModel in pairs(allocatedModelsPathLookup) do
		if IsValid(allocatedModel.ClientsideEntity) then continue end

		local csm = ClientsideModel(allocatedModel.Model)
		if not csm then continue end
		csm:SetNoDraw(true)
		allocatedModel.ClientsideEntity = csm
	end
end)