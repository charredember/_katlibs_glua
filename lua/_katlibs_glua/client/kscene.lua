local MESH_MAX_BONES = 52
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
local r_SetBlend = render.SetBlend
local r_SetColorModulation = render.SetColorModulation
local STUDIO_RENDER = STUDIO_RENDER
local STUDIO_DRAWTRANSLUCENTSUBMODELS = STUDIO_DRAWTRANSLUCENTSUBMODELS

local kmr_DrawMesh
hook.Add("KatLibsLoaded","KScene",function()
	kmr_DrawMesh = KMeshUtils.DrawMesh
end)

local function splitSequentialTableByCount(tableToSplit,desiredCount)
	if #tableToSplit < desiredCount then return {tableToSplit} end
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

local getPriv
---SHARED<br/>
---A container object for IMeshes created from KModelData.
---@class KScene
---@overload fun(modelDataTable: KModelData[]): KScene
KScene,getPriv = KClass(function(modelDataTable)
	return {
		MeshData = KMeshUtils.GetMeshVertexesFromModelData(modelDataTable,{}),
		BoneIndexes = {},

		Meshes = {},
		RenderOpaque = {},
		RenderBoth = {},
		RenderTransluscent = {},
	}
end)

local getFactory = getPriv(KScene).GetFactory

local jsonConstructor = getFactory(function(priv)
	priv.Meshes = {}
	priv.RenderOpaque = {}
	priv.RenderBoth = {}
	priv.RenderTransluscent = {}

	return priv
end)

---SHARED<br/>
---Creates a new KScene with bones from named groups of KModelData.
---@type fun(kModelDataGroups: {[string] : KModelData[]} ): KScene
KScene.CreateWithBones = getFactory(function(kModelDataBoneGroups)
	local kModelDataTable = {}
	local modelBoneLookup = {}
	local boneNameIndexLookup = {}
	local boneMatrices = {}

	local emptyMatrix = Matrix()
	local boneCount = 0
	for boneName,group in pairs(kModelDataBoneGroups) do
		KError.ValidateKVArg("kModelDataBoneGroups",KVarConditions.String(boneName),KVarConditions.Table(group))
		boneCount = boneCount + 1
		boneNameIndexLookup[boneName] = boneCount
		boneMatrices[boneCount] = emptyMatrix

		for k,modelData in pairs(group) do
			KError.ValidateKVArg(
				string.format("kModelDataBoneGroups[%s]",boneName),
				KVarConditions.Number(k),
				KVarConditions.KClass(modelData,KModelData,modelData))

			modelBoneLookup[modelData] = boneCount
			t_insert(kModelDataTable,modelData)
		end
	end
	assert(boneCount < MESH_MAX_BONES,"Too many bones! Max: " .. MESH_MAX_BONES)

	return {
		--serialized
		MeshData = KMeshUtils.GetMeshVertexesFromModelData(kModelDataTable,modelBoneLookup),
		BoneIndexes = boneNameIndexLookup,

		--runtime
		Meshes = {},
		RenderOpaque = {},
		RenderBoth = {},
		RenderTransluscent = {},
		BoneMatrices = boneMatrices,
	}
end)

function KScene:Destroy()
	local priv = getPriv(self)

	local meshes = priv.Meshes
	for i = 1,#meshes do
		im_Destroy(meshes[i])
	end

	priv.Meshes = {}
	priv.RenderOpaque = {}
	priv.RenderBoth = {}
	priv.RenderTransluscent = {}
end
local ksc_Destroy = KScene.Destroy

local function buildRenderFunction(newMesh,material,colorRed,colorGreen,colorBlue,colorAlpha)
	return function(boneData)
		r_SetColorModulation(colorRed,colorGreen,colorBlue)
		r_SetBlend(colorAlpha)
		kmr_DrawMesh(newMesh,material,boneData)
	end
end

function KScene:Compile()
	ksc_Destroy(self)
	local priv = getPriv(self)

	local meshes = priv.Meshes
	local renderOpaque = priv.RenderOpaque
	local renderBoth = priv.RenderBoth
	local renderTransluscent = priv.RenderTransluscent

	local meshData = priv.MeshData
	for i = 1, #meshData do
		---@type KVisualPropertyGroup
		local visualPropertyGroup = meshData[i]

		local material = Material(visualPropertyGroup.Material)
		local color = visualPropertyGroup.Color
		local colorRed = color.r / 255
		local colorGreen = color.g / 255
		local colorBlue = color.b / 255
		local colorAlpha = color.a / 255

		local renderGroup = visualPropertyGroup.RenderGroup
		local destination =
			(renderGroup == RENDERGROUP_TRANSLUCENT) and renderTransluscent or
			(renderGroup == RENDERGROUP_OPAQUE) and renderOpaque or
			renderBoth

		for _,meshVertexes in pairs(splitSequentialTableByCount(visualPropertyGroup.MeshVertexes,MAX_TRIS_PER_MESH)) do
			---parameter is only on dev branch, does not exist in documentation yet
			---@diagnostic disable-next-line: redundant-parameter
			local newMesh = Mesh(nil,2)

			mesh_Begin(newMesh,MATERIAL_TRIANGLES,#meshVertexes)
			for j = 1, #meshVertexes do
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
			t_insert(destination,buildRenderFunction(newMesh,material,colorRed,colorGreen,colorBlue,colorAlpha))
		end
	end
end

---@param flags STUDIO?
function KScene:Draw(flags)
	if flags == STUDIO_DRAWTRANSLUCENTSUBMODELS then return end
	local priv = getPriv(self)
	local renderOpaque = priv.RenderOpaque
	local boneMatrices = priv.BoneMatrices

	for i = 1,#renderOpaque do
		renderOpaque[i](boneMatrices)
	end
end
local ksc_Draw = KScene.Draw

---@param flags STUDIO?
function KScene:DrawTranslucent(flags)
	ksc_Draw(self,flags)
	if flags == STUDIO_RENDER then return end

	local priv = getPriv(self)
	local boneMatrices = priv.BoneMatrices

	local renderBoth = priv.RenderBoth
	for i = 1,#renderBoth do
		renderBoth[i](boneMatrices)
	end

	local renderTransluscent = priv.RenderTransluscent
	for i = 1,#renderTransluscent do
		renderTransluscent[i](boneMatrices)
	end
end

function KScene:SetBoneMatrix(boneName,matrix)
	local priv = getPriv(self)
	local boneIndexes = priv.BoneIndexes
	local index = boneIndexes[boneName]
	if not index then return end
	chat.AddText(tostring(index))
	priv.BoneMatrices[index] = matrix
end

function KScene:IsValid() return #getPriv(self).Meshes > 0 end

---SHARED<br/>
---Gets a JSON-serializable table representing this object that can be used to recreate this object later.
---@return table
function KScene:GetSerializable()
	local priv = getPriv(self)
	---@cast priv table

	return {
		MeshData = table.Copy(priv.MeshData),
		BoneIndexes = table.Copy(priv.BoneIndexes),
	}
end

---SHARED,STATIC<br/>
---Creates a new object populated with values from a table generated by GetSerializable().<br/>
---Returns nil if deserialization unsuccessful.
---@param serializable table
---@return KScene?
function KScene.FromSerializable(serializable)
	--TODO: Fix when this starts taking in user-provided data.
	--local sanitized,err = visualPropertyGroupSanitizer(serializable)
	--if not sanitized then print(err) return end
	return jsonConstructor(serializable)
end

function KScene.WriteToBinaryStream(stream,scene,threaded)
	local serializable = getPriv(scene)

	local visualPropertyGroups = serializable.MeshData
	local visualPropertyGroupCount = #visualPropertyGroups
	stream:WriteUInt16(visualPropertyGroupCount)

	for i = 1,visualPropertyGroupCount do
		print(i,visualPropertyGroupCount)
		KMeshUtils.WriteVisualPropertyGroupToBinaryStream(stream,visualPropertyGroups[i],threaded)
	end

	local bones = serializable.BoneIndexes
	stream:WriteUInt16(table.Count(bones))
	for bone,index in pairs(bones) do
		stream:WriteString(bone)
		stream:WriteUInt8(index)
	end
end

hook.Run("KatLibsLoaded")