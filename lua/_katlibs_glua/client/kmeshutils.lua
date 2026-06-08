local VERTEX_MAX_DECIMALS = 4

---@class Entity
local ent_meta = FindMetaTable("Entity")
local e_SetupBones = ent_meta.SetupBones
local e_DrawModel = ent_meta.DrawModel
local e_SetPos = ent_meta.SetPos
local e_SetAngles = ent_meta.SetAngles
---@class VMatrix
local vm_meta = FindMetaTable("VMatrix")
local vm_GetTranslation = vm_meta.GetTranslation
local vm_GetAngles = vm_meta.GetAngles
local vm_Identity = vm_meta.Identity
local vm_SetTranslation = vm_meta.SetTranslation
local vm_SetAngles = vm_meta.SetAngles
local vm_Rotate = vm_meta.Rotate
local vm_SetScale = vm_meta.SetScale
---@class Color
local clr_meta = FindMetaTable("Color")
local clr_ToHex = clr_meta.ToHex
---@class Vector
local v_meta = FindMetaTable("Vector")
local v_Dot = v_meta.Dot
---@class IMesh
local im_meta = FindMetaTable("IMesh")
---function is only on dev branch, does not exist in documentation yet
---@diagnostic disable-next-line: undefined-field
local im_DrawSkinned = im_meta.DrawSkinned or im_meta.Draw

local cam_GetModelMatrix = cam.GetModelMatrix
local r_ModelMaterialOverride = render.ModelMaterialOverride
local IsValid = IsValid
local m_Round = math.Round
local util_SHA256 = util.SHA256
local util_IntersectRayWithPlane = util.IntersectRayWithPlane
local t_insert = table.insert

local kmd_GetPos,kmd_GetAngles,kmd_GetScale,kmd_GetModel,kmd_GetColor,kmd_GetMaterial,kmd_GetRenderGroup,kmd_GetRenderMode,kmd_GetClips
hook.Add("KatLibsLoaded","KMeshUtils",function()
	kmd_GetPos = KModelData.GetPos
	kmd_GetAngles = KModelData.GetAngles
	kmd_GetScale = KModelData.GetScale
	kmd_GetModel = KModelData.GetModel
	kmd_GetColor = KModelData.GetColor
	kmd_GetMaterial = KModelData.GetMaterial
	kmd_GetRenderGroup = KModelData.GetRenderGroup
	kmd_GetRenderMode = KModelData.GetRenderMode
	kmd_GetClips = KModelData.GetClips
	kmr_DrawMesh = KMeshUtils.DrawMesh
end)

local ENTITY_CLASS = "kat_meshrenderbase"

local currMesh,currMaterial,currBoneTable
local meshRenderEntitySingleton
local sortTriangleToSide, appendTriangleData
local writeNullable,readNullable,writeUserdata,readUserdata,writeWeights,readWeights

---@class KMeshUtils
---CLIENT, STATIC<br/>
---Utility class for mesh related functions.<br/>
KMeshUtils = {}

---Garry's mod datatype for holding triangle data.<br/>
---https://wiki.facepunch.com/gmod/Structures/MeshVertex
---@class MeshVertex
---@field pos Vector
---@field u number
---@field v number
---@field normal Vector
---@field binormal Vector?
---@field tangent Vector?
---@field color Color?
---@field u1 number?
---@field v1 number?
---@field userdata number[]?
---@field weights BoneWeight[]?

---MeshVertexes grouped by visual properties
---@class KVisualPropertyGroup
---@field MeshVertexes MeshVertex[]
---@field Color Color
---@field Material string
---@field RenderGroup number?
---@field RenderMode number?

do --public static functions
	---CLIENT, STATIC<br/>
	---Draw a mesh with the specified arguments using an entity draw call.<br/>
	---https://github.com/Facepunch/garrysmod-issues/issues/4070#issuecomment-761080930
	---@param mesh IMesh
	---@param material IMaterial
	function KMeshUtils.DrawMesh(mesh,material,boneTable)
		currMesh = mesh
		currMaterial = material
		currBoneTable = boneTable

		local currMatrix = cam_GetModelMatrix()
		e_SetPos(meshRenderEntitySingleton,vm_GetTranslation(currMatrix))
		e_SetAngles(meshRenderEntitySingleton,vm_GetAngles(currMatrix))
		e_SetupBones(meshRenderEntitySingleton)
		e_DrawModel(meshRenderEntitySingleton)
	end

	---CLIENT, STATIC<br/>
	---Splits a mesh along a plane and returns the two halves.
	---@param meshVertexTab MeshVertex[]
	---@param planeOrigin Vector
	---@param planeNormal Vector
	function KMeshUtils.SplitMesh(meshVertexTab,planeOrigin,planeNormal)
		local splitA = {}
		local splitB = {}

		assert(#meshVertexTab % 3 == 0,"meshVertexTab not a multiple of 3!")
		local triCount = #meshVertexTab / 3

		for i = 0,triCount - 1 do
			local offset = i * 3
			sortTriangleToSide(splitA,splitB,
				meshVertexTab[offset + 1],meshVertexTab[offset + 2],meshVertexTab[offset + 3],
				planeOrigin,planeNormal
			)
		end

		return splitA, splitB
	end

	---Converts KModelData into MeshVertexes grouped by visual property.
	---@param kModelDataTable KModelData[]
	---@param modelBoneLookup? {[string]: number}
	---@return KVisualPropertyGroup[]
	function KMeshUtils.GetMeshVertexesFromModelData(kModelDataTable,modelBoneLookup)
		local meshData = {}

		for i = 1,#kModelDataTable do
			local currModelData = kModelDataTable[i]

			local material = kmd_GetMaterial(currModelData)
			local color = kmd_GetColor(currModelData)
			local renderGroup = kmd_GetRenderGroup(currModelData)
			local renderMode = kmd_GetRenderMode(currModelData)
			local boneIndex = modelBoneLookup and modelBoneLookup[currModelData]

			local visualPropertyKey = util_SHA256(
				material
				.. clr_ToHex(color,true)
				.. (renderGroup or "")
				.. (renderMode or ""))

			local visualPropertyGroup = meshData[visualPropertyKey]
			if not visualPropertyGroup then
				visualPropertyGroup = {
					MeshVertexes = {},
					Color = color,
					Material = material,
					RenderGroup = renderGroup,
					RenderMode = renderMode,
				}
				meshData[visualPropertyKey] = visualPropertyGroup
			end

			appendTriangleData(visualPropertyGroup.MeshVertexes,currModelData,boneIndex)
		end

		return table.ClearKeys(meshData)
	end

	---Writes a MeshVertex to a KWriteStream.
	---@param stream KWriteStream
	---@param meshVertex MeshVertex
	function KMeshUtils.WriteVertexToStream(stream,meshVertex)
		local st = SysTime()

		stream:WriteVector(meshVertex.pos)
		stream:WriteDouble(meshVertex.u)
		stream:WriteDouble(meshVertex.v)
		stream:WriteVector(meshVertex.normal)

		writeNullable(stream,stream.WriteVector,meshVertex.binormal)
		writeNullable(stream,stream.WriteVector,meshVertex.tangent)
		writeNullable(stream,stream.WriteColor,meshVertex.color)
		writeNullable(stream,stream.WriteDouble,meshVertex.u1)
		writeNullable(stream,stream.WriteDouble,meshVertex.v1)
		writeNullable(stream,writeUserdata,meshVertex.userdata)
		writeNullable(stream,writeWeights,meshVertex.weights)
	end

	---Reads a MeshVertex from a KReadStream.
	---@param stream KReadStream
	---@return MeshVertex
	function KMeshUtils.ReadVertexFromStream(stream)
		local meshVertex = {}
		meshVertex.pos = stream:ReadVector()
		meshVertex.u = stream:ReadDouble()
		meshVertex.v = stream:ReadDouble()
		meshVertex.normal = stream:ReadVector()

		meshVertex.binormal = readNullable(stream,stream.ReadVector)
		meshVertex.tangent = readNullable(stream,stream.ReadVector)
		meshVertex.color = readNullable(stream,stream.ReadColor)
		meshVertex.u1 = readNullable(stream,stream.ReadDouble)
		meshVertex.v1 = readNullable(stream,stream.ReadDouble)
		meshVertex.userdata = readNullable(stream,readUserdata)
		meshVertex.weights = readNullable(stream,readWeights)

		return meshVertex
	end

	local writeVertex = KMeshUtils.WriteVertexToStream
	local readVertex = KMeshUtils.ReadVertexFromStream

	---Writes a KVisualPropertyGroup to a KWriteStream.
	---@param stream KWriteStream
	---@param visualPropertyGroup KVisualPropertyGroup
	---@param taskToken KTaskToken?
	function KMeshUtils.WriteVisualPropertyGroupToStream(stream,visualPropertyGroup,taskToken)
		stream:WriteColor(visualPropertyGroup.Color)
		stream:WriteString(visualPropertyGroup.Material)
		writeNullable(stream,stream.WriteUInt8,visualPropertyGroup.RenderGroup)
		writeNullable(stream,stream.WriteUInt8,visualPropertyGroup.RenderMode)

		local vertexes = visualPropertyGroup.MeshVertexes
		local numVertexes = #vertexes
		stream:WriteUInt32(numVertexes)

		for i = 1,numVertexes do
			writeVertex(stream,vertexes[i])
			if taskToken then taskToken:YieldAndReportProgress(i / numVertexes) end
		end
	end

	---Reads a KVisualPropertyGroup from a KReadtream.
	---@param stream KReadStream
	---@param taskToken KTaskToken?
	---@return KVisualPropertyGroup
	function KMeshUtils.ReadVisualPropertyGroupFromStream(stream,taskToken)
		local visualPropertyGroup = {MeshVertexes = {}}

		visualPropertyGroup.Color = stream:ReadColor()
		visualPropertyGroup.Material = stream:ReadString()
		visualPropertyGroup.RenderGroup = readNullable(stream,stream.ReadUInt8)
		visualPropertyGroup.RenderMode = readNullable(stream,stream.ReadUInt8)

		local vertexes = visualPropertyGroup.MeshVertexes
		local numVertexes = stream:ReadUInt32()

		for i = 1,numVertexes do
			vertexes[i] = readVertex(stream)
			if taskToken then taskToken:YieldAndReportProgress(i / numVertexes) end
		end

		return visualPropertyGroup
	end
end

do --helper functions: mesh splitting
	local function isOnSideA(meshVertex,planeOrigin,planeNormal)
		local vector = meshVertex.pos
		local toPointFromPlane = vector - planeOrigin
		return v_Dot(toPointFromPlane,planeNormal) < 0
	end

	local function splitTriangle(splitPoint,splitBase,meshVertexPoint,meshVertexBase1,meshVertexBase2,planeOrigin,planeNormal)
		--[[
				  	      /\ point					planeNormal	^
					     /  \									|
		--intersection1-o----o-intersection2--------planeOrigin-o--
				  base1/______\ base2
		]]
		local vectorPoint,normalPoint,binormalPoint,tangentPoint,uPoint,vPoint = meshVertexPoint.pos,meshVertexPoint.normal,meshVertexPoint.binormal,meshVertexPoint.tangent,meshVertexPoint.u,meshVertexPoint.v
		local vectorBase1,uBase1,vBase1 = meshVertexBase1.pos,meshVertexBase1.u,meshVertexBase1.v
		local vectorBase2,uBase2,vBase2 = meshVertexBase2.pos,meshVertexBase2.u,meshVertexBase2.v
		local vectorIntersection1 = util_IntersectRayWithPlane(vectorPoint,vectorBase1 - vectorPoint,planeOrigin,planeNormal)
		local vectorIntersection2 = util_IntersectRayWithPlane(vectorPoint,vectorBase2 - vectorPoint,planeOrigin,planeNormal)
		local uIntersection1,vIntersection1 = (uPoint + uBase1) / 2, (vPoint + vBase1) / 2
		local uIntersection2,vIntersection2 = (uPoint + uBase2) / 2, (vPoint + vBase2) / 2

		local meshVertexIntersection1 = { pos = vectorIntersection1, normal = normalPoint, binormal = binormalPoint, tangent = tangentPoint, u = uIntersection1, v = vIntersection1 }
		local meshVertexIntersection2 = { pos = vectorIntersection2, normal = normalPoint, binormal = binormalPoint, tangent = tangentPoint, u = uIntersection2, v = vIntersection2 }

		--add point triangle
		t_insert(splitPoint,meshVertexPoint)
		t_insert(splitPoint,meshVertexIntersection1)
		t_insert(splitPoint,meshVertexIntersection2)

		--split base into two triangles
		t_insert(splitBase,meshVertexIntersection1)
		t_insert(splitBase,meshVertexBase1)
		t_insert(splitBase,meshVertexBase2)

		t_insert(splitBase,meshVertexBase2)
		t_insert(splitBase,meshVertexIntersection2)
		t_insert(splitBase,meshVertexIntersection1)
	end

	function sortTriangleToSide(splitA,splitB,meshVertex1,meshVertex2,meshVertex3,planeOrigin,planeNormal)
		local IsV1OnSideA = isOnSideA(meshVertex1,planeOrigin,planeNormal)
		local IsV2OnSideA = isOnSideA(meshVertex2,planeOrigin,planeNormal)
		local IsV3OnSideA = isOnSideA(meshVertex3,planeOrigin,planeNormal)

		if IsV1OnSideA and IsV2OnSideA and IsV3OnSideA then --111
			t_insert(splitA,meshVertex1)
			t_insert(splitA,meshVertex2)
			t_insert(splitA,meshVertex3)
			return
		end

		if not IsV1OnSideA and not IsV2OnSideA and not IsV3OnSideA then
			t_insert(splitB,meshVertex1)
			t_insert(splitB,meshVertex2)
			t_insert(splitB,meshVertex3)
			return
		end

		--find which one is the "point"
		--it is imperative that the vertices retain the same order
		if IsV1OnSideA ~= IsV2OnSideA and IsV1OnSideA ~= IsV3OnSideA then
			local splitPoint = IsV1OnSideA and splitA or splitB
			local splitBase = IsV1OnSideA and splitB or splitA
			splitTriangle(splitPoint,splitBase,meshVertex1,meshVertex2,meshVertex3,planeOrigin,planeNormal)
			return
		end

		if IsV2OnSideA ~= IsV1OnSideA and IsV2OnSideA ~= IsV3OnSideA then
			local splitPoint = IsV2OnSideA and splitA or splitB
			local splitBase = IsV2OnSideA and splitB or splitA
			splitTriangle(splitPoint,splitBase,meshVertex2,meshVertex3,meshVertex1,planeOrigin,planeNormal)
			return
		end

		if IsV3OnSideA ~= IsV1OnSideA and IsV3OnSideA ~= IsV2OnSideA then
			local splitPoint = IsV3OnSideA and splitA or splitB
			local splitBase = IsV3OnSideA and splitB or splitA
			splitTriangle(splitPoint,splitBase,meshVertex3,meshVertex1,meshVertex2,planeOrigin,planeNormal)
			return
		end
	end
end

do -- helper functions: KModelData -> MeshVertex conversion
	local function modelExists(path)
		if string.find(path,"models/",1,true) ~= 1 then return false end
		return file.Exists(path,"GAME")
	end

	local function roundVector(vec)
		vec.x = m_Round(vec.x,VERTEX_MAX_DECIMALS)
		vec.y = m_Round(vec.y,VERTEX_MAX_DECIMALS)
		vec.z = m_Round(vec.z,VERTEX_MAX_DECIMALS)
		return vec
	end

	local normalMatrix = Matrix()
	local modelMatrix = Matrix()
	local ANG_FIX = Angle(0,90,0)
	local splitMesh = KMeshUtils.SplitMesh

	function appendTriangleData(triangles,modelData,boneIndex)
		vm_Identity(normalMatrix)
		vm_SetAngles(normalMatrix,kmd_GetAngles(modelData))
		vm_Rotate(modelMatrix,ANG_FIX)

		modelMatrix:Set(normalMatrix)
		vm_SetTranslation(modelMatrix,kmd_GetPos(modelData))
		vm_SetScale(modelMatrix,kmd_GetScale(modelData))

		local modelPath = kmd_GetModel(modelData)
		if not modelExists(modelPath) then
			return
		end

		local modelTriangles = util.GetModelMeshes(modelPath)[1].triangles

		for _,clip in pairs(kmd_GetClips(modelData)) do
			_,modelTriangles = splitMesh(modelTriangles,clip.Pos,clip.Normal)
		end

		for _,meshVertex in pairs(modelTriangles) do
			local normal = roundVector(normalMatrix * meshVertex.normal)
			local binormal = meshVertex.binormal and roundVector(normalMatrix * meshVertex.binormal)
			local tangent = meshVertex.tangent and roundVector(normalMatrix * meshVertex.tangent)
			local pos = roundVector(modelMatrix * meshVertex.pos)
			local weights = boneIndex and {{bone = boneIndex, weight = 1}}
			t_insert(triangles,{
				pos = pos,
				normal = normal,
				binormal = binormal,
				tangent = tangent,
				userdata = meshVertex.userdata,
				u = meshVertex.u,
				v = meshVertex.v,
				weights = weights,
			})
		end
	end
end

do --helper functions: mesh render entity singleton
	hook.Add("Think","KMeshUtils",function()
		if IsValid(meshRenderEntitySingleton) then return end

		meshRenderEntitySingleton = ents.CreateClientside(ENTITY_CLASS)
		meshRenderEntitySingleton:SetModel("models/squad/sf_bars/sf_bar1.mdl")
		meshRenderEntitySingleton:Spawn()
		meshRenderEntitySingleton:Activate()
	end)

	local ENT = {
		Type = "anim",
		Base = "base_anim",
		Author = "ember",
		Spawnable = false,
		Mins = Vector(-999999,-999999,-999999),
		Maxs = Vector(999999,999999,999999),
	}

	function ENT:Initialize()
		self:SetRenderBounds(self.Mins,self.Maxs)
		self:DrawShadow(false)
		self:SetNoDraw(true)
	end

	--TODO: None of this fuckass hacky bullshit needs be done if ENT:GetRenderMesh() is updated to actually pass a fucking bone table back
	local invisibleMesh = Mesh()
	invisibleMesh:BuildFromTriangles({
		{pos = Vector(0.000,0.000,0.000)},
		{pos = Vector(0.000,0.000,0.002)},
		{pos = Vector(0.000,0.002,0.000)},
	})

	local empty = {}
	function ENT:Draw()
		if not IsValid(currMesh) then return end
		r_ModelMaterialOverride(currMaterial)
		e_DrawModel(self)

		---function is only on dev branch, does not exist in documentation yet
		---@diagnostic disable-next-line: redundant-parameter
		im_DrawSkinned(currMesh,currBoneTable or empty,true)

		---documentation is straight up wrong
		---@diagnostic disable-next-line: missing-parameter
		r_ModelMaterialOverride()
	end

	function ENT:GetRenderMesh()
		return {Mesh = invisibleMesh, Material = currMaterial}
	end

	scripted_ents.Register(ENT,ENTITY_CLASS)
end

do --helper functions: read and write meshvertex structures to KBinaryStream
	function writeNullable(stream,writeFunc,value,...)
		local null = (value == nil)
		stream:WriteBool(null)
		if not null then writeFunc(stream,value,...) end
	end

	function readNullable(stream,readFunc,...)
		if stream:ReadBool() then return nil end
		return readFunc(stream,...)
	end

	---@param stream KWriteStream
	function writeUserdata(stream,userdata)
		stream:WriteDouble(userdata[1])
		stream:WriteDouble(userdata[2])
		stream:WriteDouble(userdata[3])
		stream:WriteDouble(userdata[4])
	end

	---@param stream KReadStream
	function readUserdata(stream)
		local userdata = {}
		userdata[1] = stream:ReadDouble()
		userdata[2] = stream:ReadDouble()
		userdata[3] = stream:ReadDouble()
		userdata[4] = stream:ReadDouble()
		return userdata
	end

	---@param stream KWriteStream
	---@param weights BoneWeight[]
	function writeWeights(stream,weights)
		local numWeights = #weights
		stream:WriteUInt8(numWeights)

		for i = 1,numWeights do
			local weight = weights[i]

			stream:WriteUInt8(weight.bone)
			stream:WriteDouble(weight.weight)
		end
	end

	---@param stream KReadStream
	function readWeights(stream)
		local weights = {}
		local numWeights = stream:ReadUInt8()

		local totalWeight = 0
		for i = 1,numWeights do
			local bone = stream:ReadUInt8()
			local weight = stream:ReadDouble()
			totalWeight = totalWeight + weight

			weights[i] = {
				bone = bone,
				weight = weight,
			}
		end

		assert(totalWeight == 1,"BoneWeights on mesh vertex do not add up to 1!")

		return weights
	end
end