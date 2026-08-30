---@class _KMeshDataInternal
local internal = {}

---@param stream KWriteStream
local function writeNullable(stream,writeFunc,value,...)
    local null = (value == nil)
    stream:WriteBool(null)
    if not null then writeFunc(stream,value,...) end
end

---@param stream KReadStream
local function readNullable(stream,readFunc,...)
    if stream:ReadBool() then return nil end
    return readFunc(stream,...)
end

---@param stream KWriteStream
local function writeUserdata(stream,userdata)
    stream:WriteFloat(userdata[1])
    stream:WriteFloat(userdata[2])
    stream:WriteFloat(userdata[3])
    stream:WriteFloat(userdata[4])
end

---@param stream KReadStream
local function readUserdata(stream)
    local userdata = {}
    userdata[1] = stream:ReadFloat()
    userdata[2] = stream:ReadFloat()
    userdata[3] = stream:ReadFloat()
    userdata[4] = stream:ReadFloat()
    return userdata
end

---@param stream KWriteStream
---@param weights BoneWeight[]
local function writeWeights(stream,weights)
    local numWeights = #weights
    stream:WriteUInt8(numWeights)

    for i = 1,numWeights do
        local weight = weights[i]

        stream:WriteUInt8(weight.bone)
        stream:WriteFloat(weight.weight)
    end
end

---@param stream KReadStream
local function readWeights(stream)
    local weights = {}
    local numWeights = stream:ReadUInt8()

    local totalWeight = 0
    for i = 1,numWeights do
        local bone = stream:ReadUInt8()
        local weight = stream:ReadFloat()
        totalWeight = totalWeight + weight

        weights[i] = {
            bone = bone,
            weight = weight,
        }
    end

    assert(totalWeight == 1,"BoneWeights on mesh vertex do not add up to 1!")

    return weights
end

---@param stream KWriteStream
---@param meshVertexes MeshVertex[]
---@param taskToken KTaskToken?
function internal.WriteMesh(stream,meshVertexes,taskToken)
    local vertexCount = #meshVertexes
    stream:WriteUInt32(#meshVertexes)

    for i = 1,vertexCount do
        local meshVertex = meshVertexes[i]
        stream:WriteVectorF(meshVertex.pos)
        stream:WriteFloat(meshVertex.u)
        stream:WriteFloat(meshVertex.v)
        stream:WriteVectorF(meshVertex.normal)

        writeNullable(stream,stream.WriteVectorF,meshVertex.binormal)
        writeNullable(stream,stream.WriteVectorF,meshVertex.tangent)
        writeNullable(stream,stream.WriteColor,meshVertex.color)
        writeNullable(stream,stream.WriteFloat,meshVertex.u1)
        writeNullable(stream,stream.WriteFloat,meshVertex.v1)
        writeNullable(stream,writeUserdata,meshVertex.userdata)
        writeNullable(stream,writeWeights,meshVertex.weights)

        if taskToken then taskToken:YieldAndReportProgress(i / vertexCount) end
    end
end

---@param stream KReadStream
---@return MeshVertex[]
---@param taskToken KTaskToken?
function internal.ReadMesh(stream,taskToken)
    local meshVertexes = {}
    local vertexCount = stream:ReadUInt32()

    for i = 1,vertexCount do
        local meshVertex = {}
        meshVertex.pos = stream:ReadVectorF()
        meshVertex.u = stream:ReadFloat()
        meshVertex.v = stream:ReadFloat()
        meshVertex.normal = stream:ReadVectorF()

        meshVertex.binormal = readNullable(stream,stream.ReadVectorF)
        meshVertex.tangent = readNullable(stream,stream.ReadVectorF)
        meshVertex.color = readNullable(stream,stream.ReadColor)
        meshVertex.u1 = readNullable(stream,stream.ReadFloat)
        meshVertex.v1 = readNullable(stream,stream.ReadFloat)
        meshVertex.userdata = readNullable(stream,readUserdata)
        meshVertex.weights = readNullable(stream,readWeights)

        meshVertexes[i] = meshVertex

        if taskToken then taskToken:YieldAndReportProgress(i / vertexCount) end
    end

    return meshVertexes
end

return internal