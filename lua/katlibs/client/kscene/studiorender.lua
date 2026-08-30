
local ENTITY_CLASS = "kat_meshrenderbase"
local INVISIBLE_MESH = Mesh()
INVISIBLE_MESH:BuildFromTriangles({
    {pos = Vector(0.000,0.000,0.000)},
    {pos = Vector(0.000,0.000,0.002)},
    {pos = Vector(0.000,0.002,0.000)},
})
local NO_MAT = Material("models/debug/debugwhite")

---@class Entity
local ent_meta = FindMetaTable("Entity")
local e_SetupBones = ent_meta.SetupBones
local e_DrawModel = ent_meta.DrawModel
local e_SetPos = ent_meta.SetPos
local e_SetAngles = ent_meta.SetAngles
local e_SetRenderMode = ent_meta.SetRenderMode
---@class VMatrix
local vm_meta = FindMetaTable("VMatrix")
local vm_GetTranslation = vm_meta.GetTranslation
local vm_GetAngles = vm_meta.GetAngles
local IsValid = IsValid
---@class IMesh
local im_meta = FindMetaTable("IMesh")
local im_DrawSkinned = im_meta.DrawSkinned
local c_PushModelMatrix = cam.PushModelMatrix
local c_PopModelMatrix = cam.PopModelMatrix
local RENDERMODE_NORMAL = RENDERMODE_NORMAL

local singleton,currMesh,currModelMatrix,currBoneTable

---@class _KSceneInternal
local internal = {}

local testModel = KClientsideModel("models/props_junk/watermelon01.mdl")
---Draw a mesh with the specified arguments using an entity draw call.<br/>
---https://github.com/Facepunch/garrysmod-issues/issues/4070#issuecomment-761080930
---@param mesh IMesh
---@param modelMatrix VMatrix
---@param boneTable VMatrix[]
---@param renderMode? integer
function internal.DrawMesh(mesh,modelMatrix,boneTable,renderMode)
    currMesh = mesh
    currBoneTable = boneTable
	currModelMatrix = modelMatrix

	if renderMode then e_SetRenderMode(singleton,renderMode) end
    e_SetPos(singleton,vm_GetTranslation(modelMatrix))
    e_SetAngles(singleton,vm_GetAngles(modelMatrix))
    e_SetupBones(singleton)
    e_DrawModel(singleton)
	if renderMode then e_SetRenderMode(singleton,RENDERMODE_NORMAL) end
end

hook.Add("Think","KMeshRender",function()
	if IsValid(singleton) then return end

	singleton = ents.CreateClientside(ENTITY_CLASS)
	singleton:SetModel("models/squad/sf_bars/sf_bar1.mdl")
	singleton:Spawn()
	singleton:Activate()
end)

local ENT = {
	Type = "anim",
	Base = "base_anim",
	Author = "ember",
	Spawnable = false,
	RenderGroup = RENDERGROUP_BOTH,
	Mins = Vector(-999999,-999999,-999999),
	Maxs = Vector(999999,999999,999999),
}

function ENT:Initialize()
	self:SetRenderBounds(self.Mins,self.Maxs)
	self:DrawShadow(false)
	self:SetNoDraw(true)
end

local empty = {}
function ENT:Draw()
	--TODO: This fuckass hacky bullshit doesn't need to be done if ENT:GetRenderMesh() is updated to be able to pass up a fucking bone table
	if not IsValid(currMesh) then return end
	e_DrawModel(self)
	c_PushModelMatrix(currModelMatrix)
	im_DrawSkinned(currMesh,currBoneTable or empty,true)
	c_PopModelMatrix()
end

function ENT:GetRenderMesh()
	return {Mesh = INVISIBLE_MESH, Material = NO_MAT}
end

scripted_ents.Register(ENT,ENTITY_CLASS)

return internal