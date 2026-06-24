local NULL_TERMINATOR = "\x00"
local INT8_MAX = 127
local INT16_MAX = 32767
local INT32_MAX = 2147483647

local FALSE = 0

local math_ldexp = math.ldexp
local math_floor = math.floor
local string_byte = string.byte
local string_sub = string.sub
local string_find = string.find

local read,readBytes

local getPriv
---SHARED<br/>
---In-memory bit buffer.
---@class KBinaryReadStream : KReadStream
---@overload fun(str?: string): KBinaryReadStream
KBinaryReadStream,getPriv = KClass(function(str)
	KError.ValidateNullableArg("str",KVarConditions.String(str))

	return {
		ByteStream = str or "",
		Position = 1,
	}
end)

do --set/get properties
	---SHARED, OVERRIDE<br/>
	---Sets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@param int integer
	function KBinaryReadStream:Seek(int)
		getPriv(self).Position = 1 + int
	end

	---SHARED, OVERRIDE<br/>
	---Skips the current read/write position forward by the specified amount of bytes.<br/>
	---@param int integer
	function KBinaryReadStream:Skip(int)
		local priv = getPriv(self)
		priv.Position = priv.Position + int
	end

	---SHARED, OVERRIDE<br/>
	---Resets the current read/write position back to zero.<br/>
	function KBinaryReadStream:Reset()
		getPriv(self).Position = 1
	end

	---SHARED, OVERRIDE<br/>
	---Gets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@return integer
	function KBinaryReadStream:Tell()
		return getPriv(self).Position
	end

	---SHARED<br/>
	---Gets the current size of the byte stream.<br/>
	---@return integer
	function KBinaryReadStream:GetSize()
		return #getPriv(self).ByteStream
	end

	---SHARED<br/>
	---Returns the byte stream.
	---@return string
	function KBinaryReadStream:GetStream()
		return getPriv(self).ByteStream
	end

	---SHARED, OVERRIDE<br/>
	---Discards the current stream object and reopens it as its KWriteStream variant.<br/>
	---Zero indexed.
	---@return KWriteStream
	function KBinaryReadStream:ReopenAsWriteStream()
		local stream = KBinaryWriteStream()
		stream:Write(getPriv(self).ByteStream)
		return stream
    end
end

do --read/write
	---SHARED, OVERRIDE<br/>
	---Reads the specified amount of bytes from the stream.
	---@param amount integer
	function KBinaryReadStream:Read(amount)
		return read(getPriv(self),amount)
	end

	---SHARED, OVERRIDE<br/>
	---Reads from the byte stream until the specified character is read.
	---@param byte string
	function KBinaryReadStream:ReadUntil(byte)
		local priv = getPriv(self)
		local byteStream = priv.ByteStream
		local currPos = priv.Position
		local nullTerminatorPos = string_find(byteStream,byte,currPos,true)
		priv.Position = nullTerminatorPos + 1

		return string_sub(byteStream,currPos,nullTerminatorPos - 1)
	end

	local readUntil = KBinaryReadStream.ReadUntil

	---SHARED, OVERRIDE<br/>
	---Reads an 8-bit unsigned integer from the byte stream.
	---@return integer
	function KBinaryReadStream:ReadUInt8()
		local b1 = readBytes(getPriv(self),1)
		return b1
	end

	local readUInt8 = KBinaryReadStream.ReadUInt8

	--SHARED<br/>
	---Reads a 16-bit unsigned integer from the byte stream.
	---@return integer
	function KBinaryReadStream:ReadUInt16()
		local b1,b2 = readBytes(getPriv(self),2)
        return b1 * 0x100 + b2
	end

	local readUInt16 = KBinaryReadStream.ReadUInt16

	--SHARED<br/>
	---Reads a 32-bit unsigned integer from the byte stream.
	---@return integer
	function KBinaryReadStream:ReadUInt32()
		local b1,b2,b3,b4 = readBytes(getPriv(self),4)
        return b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
	end

	local readUInt32 = KBinaryReadStream.ReadUInt32

	---SHARED, OVERRIDE<br/>
	---Reads an 8-bit signed integer from the byte stream.
	function KBinaryReadStream:ReadInt8()
		local int = readUInt8(self)
		if int > INT8_MAX then int = int - 0x100 end
		return int
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 16-bit signed integer from the byte stream.
	function KBinaryReadStream:ReadInt16()
		local int = readUInt16(self)
		if int > INT16_MAX then int = int - 0x10000 end
		return int
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 32-bit signed integer from the byte stream.
	function KBinaryReadStream:ReadInt32()
		local int = readUInt32(self)
		if int > INT32_MAX then int = int - 0x100000000 end
		return int
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 32-bit IEEE754 double from the byte stream.
    function KBinaryReadStream:ReadFloat()
        local a = readUInt32(self)

        local sign = math_floor(a / (2 ^ 31)) % 2 == 1 and -1 or 1
        local exponentField = math_floor(a / (2 ^ 23)) % (2 ^ 8)
        local mantissa = a % (2 ^ 23)

        if exponentField == 0xFF then
            if mantissa == 0 then return sign * (1 / 0) end
            return 0 / 0
        end

        if exponentField == 0 and mantissa == 0 then
            return sign * 0
        end

        local mantissaScaled = mantissa / (2 ^ 23)
        if exponentField ~= 0 then
            mantissaScaled = mantissaScaled + 1
            local actualExponent = exponentField - 127
            return sign * math_ldexp(mantissaScaled, actualExponent)
        else
            return sign * math_ldexp(mantissaScaled, -126)
        end
    end

	---SHARED, OVERRIDE<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	function KBinaryReadStream:ReadDouble()
        local a = readUInt32(self)
        local b = readUInt32(self)

        local sign = math_floor(a / (2 ^ 31)) % 2 == 1 and -1 or 1
        local exponent = math_floor(a / (2 ^ 20)) % (2 ^ 11)
        local mantissaUpper = a % (2 ^ 20)

        if exponent == 0x7FF then
            if mantissaUpper == 0 and b == 0 then
                return sign * (1 / 0)
            end
            return 0 / 0
        end

        if exponent == 0 and mantissaUpper == 0 and b == 0 then
            return sign * 0
        end

        local mantissaScaled = mantissaUpper * (2 ^ 32) + b

        if exponent ~= 0 then
            mantissaScaled = (mantissaScaled / (2 ^ 52)) + 1
            return sign * math_ldexp(mantissaScaled,exponent - 1023)
        else
            mantissaScaled = mantissaScaled / (2 ^ 52)
            return sign * math_ldexp(mantissaScaled,-1022)
        end
	end

	local readFloat = KBinaryReadStream.ReadFloat
	local readDouble = KBinaryReadStream.ReadDouble

	---SHARED, OVERRIDE<br/>
	---Reads a string from the byte stream.
	function KBinaryReadStream:ReadString()
		return readUntil(self,NULL_TERMINATOR)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a bool from the byte stream.
	function KBinaryReadStream:ReadBool()
		if readUInt8(self) == FALSE then return false end
		return true
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Vector of 64-bit doubles from the byte stream.
	function KBinaryReadStream:ReadVector()
		return Vector(
			readDouble(self),
			readDouble(self),
			readDouble(self))
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Vector of 32-bit floats from the byte stream.
	function KBinaryReadStream:ReadVectorF()
		return Vector(
			readFloat(self),
			readFloat(self),
			readFloat(self))
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Color from the byte stream.
	function KBinaryReadStream:ReadColor()
		return Color(
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self))
	end
end

do --helper functions
	function read(priv,amount)
		local pos = priv.Position
		local bytes = string_sub(priv.ByteStream,pos,pos + amount - 1)

		priv.Position = pos + amount
		return bytes
	end

	function readBytes(priv,amount)
		local bytes = read(priv,amount)
		return string_byte(bytes,1,#bytes)
	end
end