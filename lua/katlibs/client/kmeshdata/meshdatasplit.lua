---@class _KMeshDataInternal
local internal = {}

---@class Vector
local v_meta = FindMetaTable("Vector")
local v_Dot = v_meta.Dot
local v_Distance = v_meta.Distance
local Lerp = Lerp
local util_IntersectRayWithPlane = util.IntersectRayWithPlane
local t_insert = table.insert

local function isOnSideA(meshVertex,planeOrigin,planeNormal)
    local vector = meshVertex.pos
    local toPointFromPlane = vector - planeOrigin
    return v_Dot(toPointFromPlane,planeNormal) < 0
end

local function unpackMeshVertex(meshVertex)
    local binormal = meshVertex.binormal
    local tangent = meshVertex.tangent
    return
        Vector(meshVertex.pos),
        Vector(meshVertex.normal),
        binormal and Vector(meshVertex.binormal) or nil,
        tangent and Vector(meshVertex.tangent) or nil,
        meshVertex.u,
        meshVertex.v
end

local function cloneMeshVertex(meshVertex)
    local binormal = meshVertex.binormal
    local tangent = meshVertex.tangent
    local color = meshVertex.color
    local userdata = meshVertex.userdata
    local weights = meshVertex.weights
    return
    {
        pos = Vector(meshVertex.pos),
        normal = Vector(meshVertex.normal),
        binormal = binormal and Vector(meshVertex.binormal) or nil,
        tangent = tangent and Vector(meshVertex.tangent) or nil,
        u = meshVertex.u,
        v = meshVertex.v,
        u1 = meshVertex.u1,
        v1 = meshVertex.v1,
        color = color and Color(color.r, color.g, color.b, color.a) or nil,
        userdata = userdata and table.Copy(meshVertex.userdata) or nil,
        weights = weights and table.Copy(meshVertex.weights) or nil,
    }
end

---@param splitPoint Vector
---@param splitBase Vector
---@param meshVertexPoint MeshVertex
---@param meshVertexBase1 MeshVertex
---@param meshVertexBase2 MeshVertex
---@param planeOrigin Vector
---@param planeNormal Vector
local function splitTriangle(splitPoint,splitBase,meshVertexPoint,meshVertexBase1,meshVertexBase2,planeOrigin,planeNormal)
    --[[
                        /\ point				  planeNormal ^
                       /  \									  |
    ----intersection1-o----o-intersection2--------planeOrigin-o--
                base1/______\ base2
    ]]
    local vectorPoint,normalPoint,binormalPoint,tangentPoint,uPoint,vPoint = unpackMeshVertex(meshVertexPoint)
    local vectorBase1,_,_,_,uBase1,vBase1 = unpackMeshVertex(meshVertexBase1)
    local vectorBase2,_,_,_,uBase2,vBase2 = unpackMeshVertex(meshVertexBase2)
    local vectorIntersection1 = util_IntersectRayWithPlane(vectorPoint,vectorBase1 - vectorPoint,planeOrigin,planeNormal)
    local vectorIntersection2 = util_IntersectRayWithPlane(vectorPoint,vectorBase2 - vectorPoint,planeOrigin,planeNormal)

    local distPointToIntersection1 = v_Distance(vectorPoint,vectorIntersection1) / v_Distance(vectorPoint,vectorBase1)
    local distPointToIntersection2 = v_Distance(vectorPoint,vectorIntersection2) / v_Distance(vectorPoint,vectorBase2)

    local uIntersection1 = Lerp(distPointToIntersection1,uPoint,uBase1)
    local vIntersection1 = Lerp(distPointToIntersection1,vPoint,vBase1)
    local uIntersection2 = Lerp(distPointToIntersection2,uPoint,uBase2)
    local vIntersection2 = Lerp(distPointToIntersection2,vPoint,vBase2)

    local meshVertexIntersection1 = { pos = vectorIntersection1, normal = normalPoint, binormal = binormalPoint, tangent = tangentPoint, u = uIntersection1, v = vIntersection1 }
    local meshVertexIntersection2 = { pos = vectorIntersection2, normal = normalPoint, binormal = binormalPoint, tangent = tangentPoint, u = uIntersection2, v = vIntersection2 }

    --add point triangle
    t_insert(splitPoint,meshVertexPoint)
    t_insert(splitPoint,meshVertexIntersection1)
    t_insert(splitPoint,meshVertexIntersection2)

    --split base into two triangles
    t_insert(splitBase,cloneMeshVertex(meshVertexIntersection1))
    t_insert(splitBase,meshVertexBase1)
    t_insert(splitBase,meshVertexBase2)

    t_insert(splitBase,cloneMeshVertex(meshVertexBase2))
    t_insert(splitBase,cloneMeshVertex(meshVertexIntersection2))
    t_insert(splitBase,cloneMeshVertex(meshVertexIntersection1))
end

local function sortTriangleToSide(splitA,splitB,meshVertex1,meshVertex2,meshVertex3,planeOrigin,planeNormal)
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

---@param meshVertexes MeshVertex[]
---@param origin Vector
---@param normal Vector
function internal.SplitMesh(meshVertexes,origin,normal)
    local splitA = {}
    local splitB = {}

    assert(#meshVertexes % 3 == 0,"meshVertexTab not a multiple of 3!")
    local triCount = #meshVertexes / 3

    for i = 0,triCount - 1 do
        local offset = i * 3
        sortTriangleToSide(splitA,splitB,
            meshVertexes[offset + 1],meshVertexes[offset + 2],meshVertexes[offset + 3],
            origin,normal
        )
    end

    return splitA,splitB
end

return internal