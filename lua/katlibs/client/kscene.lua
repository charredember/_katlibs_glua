local MAX_TRIS_PER_MESH = 65535

---@class IMesh
local im_meta = FindMetaTable("IMesh")
local im_Destroy = im_meta.Destroy
local mesh_Begin = mesh.Begin
local mesh_Position = mesh.Position
local mesh_Normal = mesh.Normal
local mesh_TexCoord = mesh.TexCoord
local mesh_TangentS = mesh.TangentS
local mesh_TangentT = mesh.TangentT
local mesh_UserData = mesh.UserData
local mesh_BoneData = mesh.BoneData
local mesh_Color = mesh.Color
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End
local m_ceil = math.ceil
local t_insert = table.insert
---@class _KSceneInternal
local internal = {}
table.Inherit(internal,include("kscene/handle.lua"))
table.Inherit(internal,include("kscene/studiorender.lua"))
table.Inherit(internal,include("kscene/scenerender.lua"))
local drawMesh = internal.DrawMesh
local newHandle = internal.NewHandle
local addToRenderStack = internal.AddToRenderStack
local removeFromRenderStack = internal.RemoveFromRenderStack

local destroy,createMeshes,splitSequentialTableByCount

local MAX_VERTS_PER_MESH = math.floor(MAX_TRIS_PER_MESH / 3)

local getPriv
---CLIENT<br/>
---Dynamically generated mesh data.
---@class KScene
---@overload fun(meshData: KMeshData): KScene
KScene,getPriv = KClass(function(meshData)
	local drawGroups = {}

	for _,meshVertexes,renderProperties,studioProperties in meshData:Iterator() do
		local meshes = createMeshes(meshVertexes)

		t_insert(drawGroups,{
			Meshes = meshes,
			RenderProperties = renderProperties,
			StudioProperties = studioProperties,
		})
	end

	return {
		DrawGroups = drawGroups,
		Valid = true
	}
end,{ Destructor = destroy })

---CLIENT<br/>
---Returns whether this KScene is valid or not.
function KScene:IsValid() return getPriv(self).Valid end

function KScene:Destroy() destroy(getPriv(self)) end

local testModel = KClientsideModel("models/props_lab/cactus.mdl")

function KScene:GetDrawHandle()
	local priv = getPriv(self)

	local bones = {}
	local handle = newHandle(bones,removeFromRenderStack)
	local uid = handle:GetUID()

	for _,drawGroup in pairs(priv.DrawGroups) do
		local studioProperties = drawGroup.StudioProperties
		local meshes = drawGroup.Meshes
		local meshCount = #meshes
		local renderGroup = studioProperties:GetRenderGroup()
		local renderMode = studioProperties:GetRenderGroup()
		local modelMatrix = handle:GetModelMatrix()

		---@cast drawGroup _KDrawGroup
		local function draw()
			for i = 1,meshCount do
				drawMesh(meshes[i],modelMatrix,bones,renderMode)
				testModel:Draw()
			end
		end

		addToRenderStack(uid,drawGroup.RenderProperties,renderGroup,draw)
	end

	return handle
end

do --helper functions
	function destroy(priv)
		local groups = priv.DrawGroups
		for i = 1,#groups do
			local meshes = groups[i].Meshes
			if not meshes then continue end
			for j = 1,#meshes do
				local mesh = meshes[j]
				if not IsValid(mesh) then continue end
				im_Destroy(mesh)
			end
		end
		priv.Valid = false
	end

	---@param unsplitMeshVertexes MeshVertex[]
	---@return IMesh[]
	function createMeshes(unsplitMeshVertexes)
		local meshes = {}

		for _,meshVertexes in pairs(splitSequentialTableByCount(unsplitMeshVertexes,MAX_VERTS_PER_MESH)) do
			local newMesh = Mesh(nil,2)

			local vertexCount = #meshVertexes
			mesh_Begin(newMesh,MATERIAL_TRIANGLES,vertexCount)
			for j = 1, vertexCount do
				---@type MeshVertex
				local meshVertex = meshVertexes[j]

				mesh_Position(meshVertex.pos)
				mesh_Normal(meshVertex.normal)
				mesh_TexCoord(0,meshVertex.u,meshVertex.v)

				local binormal = meshVertex.binormal
				if binormal then mesh_TangentS(binormal) end

				local tangent = meshVertex.tangent
				if tangent then mesh_TangentT(tangent) end

				local userdata = meshVertex.userdata
				if userdata then mesh_UserData(userdata[1],userdata[2],userdata[3],userdata[4]) end

				local weights = meshVertex.weights
				if weights then
					for _,weight in pairs(weights) do
						mesh_BoneData(0,weight.bone,weight.weight)
						mesh_BoneData(1,weight.bone,0)
					end
				end

				mesh_Color(255,255,255,255)

				mesh_AdvanceVertex()
			end

			mesh_End()
			t_insert(meshes,newMesh)
		end

		return meshes
	end

	function splitSequentialTableByCount(tableToSplit,desiredCount)
		if #tableToSplit <= desiredCount then return {tableToSplit} end

		local result = {}
		local currCount = #tableToSplit
		local tablesNeeded = m_ceil(currCount / desiredCount)

		local itr = 0
		for resultIndex = 1,tablesNeeded do
			local subTable = {}
			for newSubIndex = 1, desiredCount do
				itr = itr + 1
				local val = tableToSplit[itr]
				if val == nil then break end
				subTable[newSubIndex] = val
			end

			result[resultIndex] = subTable
		end

		return result
	end
end