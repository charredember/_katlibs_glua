--A lot of this is directly based on code from my dear friend and mentor Xayr.
--https://github.com/XAYRGA

local NULL_TERMINATOR = "\x00"
local INT8_MAX = 127
local INT16_MAX = 32767
local INT32_MAX = 2147483647

local TRUE = 1
local FALSE = 0

local math_huge = math.huge
local math_ldexp = math.ldexp
local math_frexp = math.frexp
local math_floor = math.floor
local math_modf = math.modf
local bit_rshift = bit.rshift
local string_char = string.char
local string_byte = string.byte
local string_rep = string.rep
local string_sub = string.sub

local convertBytesToInt,convertToBytesFromInt,unpackIEEE754Double,packIEEE754Double

local getPriv
---SHARED<br/>
---@class KBinaryStream
---@overload fun(str?: string): KBinaryStream
KBinaryStream,getPriv = KClass(function(str)
	KError.ValidateNullableArg("str",KVarConditions.String(str))

	return {
		ByteStream = str or "",
		Position = 1,
	}
end)

do -- static
	---SHARED, STATIC<br/>
	---Converts the 8-bit integer to bytes. (litte endian)
	---@param int integer
	function KBinaryStream.Int8ToBytesLE(int)
		local _,_,_,d  = convertToBytesFromInt(int)
		return string_char(d)
	end

	---SHARED, STATIC<br/>
	---Converts the 8-bit integer to bytes. (big endian)
	---@param int integer
	function KBinaryStream.Int8ToBytesBE(int)
		local a,_,_,_ = convertToBytesFromInt(int)
		return string_char(a)
	end

	---SHARED, STATIC<br/>
	---Converts the 16-bit integer to bytes. (litte endian)
	---@param int integer
	function KBinaryStream.Int16ToBytesLE(int)
		local _,_,c,d  = convertToBytesFromInt(int)
		return string_char(d,c)
	end

	---SHARED, STATIC<br/>
	---Converts the 16-bit integer to bytes. (big endian)
	---@param int integer
	function KBinaryStream.Int16ToBytesBE(int)
		local a,b,_,_ = convertToBytesFromInt(int)
		return string_char(a,b)
	end

	---SHARED, STATIC<br/>
	---Converts the 32-bit integer to bytes. (little endian)
	---@param int integer
	function KBinaryStream.Int32ToBytesLE(int)
		local a,b,c,d = convertToBytesFromInt(int)
		return string_char(d,c,b,a)
	end

	---SHARED, STATIC<br/>
	---Converts the 32-bit integer to bytes. (big endian)
	---@param int integer
	function KBinaryStream.Int32ToBytesBE(int)
		local a,b,c,d = convertToBytesFromInt(int)
		return string_char(a,b,c,d)
	end
end

do --set/get properties
	---SHARED<br/>
	---Sets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@param int integer
	function KBinaryStream:Seek(int)
		getPriv(self).Position = 1 + int
	end

	---SHARED<br/>
	---Skips the current read/write position forward by the specified amount of bytes.<br/>
	---@param int integer
	function KBinaryStream:Skip(int)
		local priv = getPriv(self)
		priv.Position = priv.Position + int
	end

	---SHARED<br/>
	---Resets the current read/write position back to zero.<br/>
	function KBinaryStream:Reset()
		getPriv(self).Position = 1
	end

	---SHARED<br/>
	---Gets the current size of the byte stream.<br/>
	---@return integer
	function KBinaryStream:GetSize()
		return #getPriv(self).ByteStream
	end

	---SHARED<br/>
	---Gets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@return integer
	function KBinaryStream:GetPosition()
		return getPriv(self).Position
	end

	---SHARED<br/>
	---Returns the byte stream.
	---@return string
	function KBinaryStream:GetStream()
		return getPriv(self).ByteStream
	end
end

do --read/write
	local getInt8BytesLE = KBinaryStream.Int8ToBytesLE
	local getInt16BytesLE = KBinaryStream.Int16ToBytesLE
	local getInt32BytesLE = KBinaryStream.Int32ToBytesLE

	---SHARED<br/>
	---Reads the specified amount of bytes from the stream.
	---@param amount integer
	function KBinaryStream:Read(amount)
		local priv = getPriv(self)
		local pos = priv.Position
		local bytes = string_sub(priv.ByteStream,pos,pos + amount - 1)

		priv.Position = pos + amount
		return bytes
	end

	---SHARED<br/>
	---Writes the specified bytes to the stream.
	---@param bytes string
	function KBinaryStream:Write(bytes)
		local priv = getPriv(self)

		local startPos = priv.Position
		local endPos = priv.Position + #bytes
		local stream = priv.ByteStream
		local streamLength = #stream

		if endPos > streamLength then
			local paddingAmount = endPos - streamLength
			stream = stream .. string_rep("\x00",paddingAmount)
		end

		priv.Position = endPos
		priv.ByteStream = string_sub(stream,0,startPos - 1) .. bytes .. string_sub(stream,endPos)
	end

	local read = KBinaryStream.Read
	local write = KBinaryStream.Write

	---SHARED<br/>
	---Reads from the byte stream until the specified character is read.
	---@param byte string
	function KBinaryStream:ReadUntil(byte)
		local bytes = ""
		if type(byte) == "number" then
			byte = string_char(byte)
		end

		local lastread
		while lastread ~= byte do
			lastread = read(self,1)
			bytes = bytes .. lastread
		end

		return string_sub(bytes,1,-2)
	end

	local readUntil = KBinaryStream.ReadUntil

	---SHARED<br/>
	---Reads an 8-bit unsigned integer from the byte stream.
	---@return integer
	function KBinaryStream:ReadUInt8()
		return convertBytesToInt(read(self,1))
	end

	---SHARED<br/>
	---Writes an 8-bit unsigned integer to the byte stream.
	---@param int integer
	function KBinaryStream:WriteUInt8(int)
		write(self,getInt8BytesLE(int))
	end

	local readUInt8 = KBinaryStream.ReadUInt8
	local writeUInt8 = KBinaryStream.WriteUInt8

	--SHARED<br/>
	---Reads a 16-bit unsigned integer from the byte stream.
	---@return integer
	function KBinaryStream:ReadUInt16()
		return readUInt8(self)
			+ readUInt8(self) * 0x100
	end

	---SHARED<br/>
	---Writes a 16-bit unsigned integer to the byte stream.
	---@param int integer
	function KBinaryStream:WriteUInt16(int)
		write(self,getInt16BytesLE(int))
	end

	local readUInt16 = KBinaryStream.ReadUInt16

	--SHARED<br/>
	---Reads a 32-bit unsigned integer from the byte stream.
	---@return integer
	function KBinaryStream:ReadUInt32()
		return readUInt8(self)
			+ readUInt8(self) * 0x100
			+ readUInt8(self) * 0x10000
			+ readUInt8(self) * 0x1000000
	end

	--SHARED<br/>
	---Writes a 32-bit unsigned integer from the byte stream.
	---@param int integer
	function KBinaryStream:WriteUInt32(int)
		write(self,getInt32BytesLE(int))
	end

	local readUInt32 = KBinaryStream.ReadUInt32

	---SHARED<br/>
	---Reads an 8-bit signed integer from the byte stream.
	function KBinaryStream:ReadInt8()
		local int = readUInt8(self)
		if int > INT8_MAX then int = int - 0x100 end
		return int
	end

	---SHARED<br/>
	---Writes an 8-bit signed integer to the byte stream.
	---@param int integer
	function KBinaryStream:WriteInt8(int)
		write(self,getInt8BytesLE(int))
	end

	---SHARED<br/>
	---Reads a 16-bit signed integer from the byte stream.
	function KBinaryStream:ReadInt16()
		local int = readUInt16(self)
		if int > INT16_MAX then int = int - 0x10000 end
		return int
	end

	---SHARED<br/>
	---Writes a 16-bit signed integer to the byte stream.
	---@param int integer
	function KBinaryStream:WriteInt16(int)
		write(self,getInt16BytesLE(int))
	end

	---SHARED<br/>
	---Reads a 32-bit signed integer from the byte stream.
	function KBinaryStream:ReadInt32()
		local int = readUInt32(self)
		if int > INT32_MAX then int = int - 0x100000000 end
		return int
	end

	---SHARED<br/>
	---Writes a 32-bit signed integer to the byte stream.
	---@param int integer
	function KBinaryStream:WriteInt32(int)
		write(self,getInt32BytesLE(int))
	end

	---SHARED<br/>
	---Writes a 64-bit IEEE754 double to the byte stream.
	function KBinaryStream:ReadDouble()
		return unpackIEEE754Double(
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self))
	end

	---SHARED<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param double number
	function KBinaryStream:WriteDouble(double)
		write(self,string_char(packIEEE754Double(double)))
	end

	local readDouble = KBinaryStream.ReadDouble
	local writeDouble = KBinaryStream.WriteDouble

	---SHARED<br/>
	---Reads a string from the byte stream.
	function KBinaryStream:ReadString()
		return readUntil(self,NULL_TERMINATOR)
	end

	---SHARED<br/>
	---Writes a string to the byte stream.
	---@param str string
	function KBinaryStream:WriteString(str)
		write(self,str .. NULL_TERMINATOR)
	end

	---SHARED<br/>
	---Writes a bool to the byte stream.
	---@param bool boolean
	function KBinaryStream:WriteBool(bool)
		writeUInt8(self,bool and TRUE or FALSE)
	end

	---SHARED<br/>
	---Reads a bool from the byte stream.
	function KBinaryStream:ReadBool()
		return readUInt8(self) == TRUE and true or false
	end

	---SHARED<br/>
	---Writes a Vector to the byte stream.
	---@param vec Vector
	function KBinaryStream:WriteVector(vec)
		writeDouble(self,vec.x)
		writeDouble(self,vec.y)
		writeDouble(self,vec.z)
	end

	---SHARED<br/>
	---Reads a Vector from the byte stream.
	function KBinaryStream:ReadVector()
		return Vector(
			readDouble(self),
			readDouble(self),
			readDouble(self))
	end

	---SHARED<br/>
	---Writes a Color to the byte stream.
	---@param color Color
	function KBinaryStream:WriteColor(color)
		writeUInt8(self,color.r)
		writeUInt8(self,color.g)
		writeUInt8(self,color.b)
		writeUInt8(self,color.a)
	end

	---SHARED<br/>
	---Reads a Color from the byte stream.
	function KBinaryStream:ReadColor()
		return Color(
			readUInt8(self),
			readUInt8(self),
			readUInt8(self),
			readUInt8(self))
	end
end

do --helper functions
	local function bytesToIntRecursive(exp, num, digit, ...)
		if not digit then return num end
		return bytesToIntRecursive(exp * 256, num + digit * exp, ...)
	end

	function convertBytesToInt(str)
		if str == nil then return 0 end
		return bytesToIntRecursive(256, string_byte(str, 1, -1))
	end

	function convertToBytesFromInt(n)
		assert(math_floor(n),"number is not a int!")
		n = (n < 0) and (4294967296 + n) or n -- adjust for 2's complement
		return (math_modf(n / 16777216)) % 256, (math_modf(n / 65536)) % 256, (math_modf(n / 256)) % 256, n % 256
	end

	function unpackIEEE754Double(b8, b7, b6, b5, b4, b3, b2, b1)
		local exponent = (b1 % 0x80) * 0x10 + bit_rshift(b2, 4)
		local mantissa = math_ldexp(((((((b2 % 0x10) * 0x100 + b3) * 0x100 + b4) * 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8, -52)
		if exponent == 0x7FF then
			if mantissa > 0 then
				return 0 / 0
			else
				if b1 >= 0x80 then
					return -math_huge
				else
					return math_huge
				end
			end
		elseif exponent > 0 then
			mantissa = mantissa + 1
		else
			exponent = exponent + 1
		end
		if b1 >= 0x80 then
			mantissa = -mantissa
		end
		return math_ldexp(mantissa, exponent - 0x3FF)
	end

	function packIEEE754Double(number)
		if number == 0 then
			return 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
		elseif number == math_huge then
			return 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x7F
		elseif number == -math_huge then
			return 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xFF
		elseif number ~= number then
			return 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF8, 0xFF
		else
			local sign = 0x00
			if number < 0 then
				sign = 0x80
				number = -number
			end
			local mantissa, exponent = math_frexp(number)
			exponent = exponent + 0x3FF

			if exponent <= 0 then
				mantissa = math_ldexp(mantissa, exponent - 1)
				exponent = 0
			elseif exponent > 0 then
				if exponent >= 0x7FF then
					return 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, sign + 0x7F
				elseif exponent == 1 then
					exponent = 0
				else
					mantissa = mantissa * 2 - 1
					exponent = exponent - 1
				end
			end

			mantissa = math_floor(math_ldexp(mantissa, 52) + 0.5)

			return mantissa % 0x100,
				math_floor(mantissa / 0x100) % 0x100,
				math_floor(mantissa / 0x10000) % 0x100,
				math_floor(mantissa / 0x1000000) % 0x100,
				math_floor(mantissa / 0x100000000) % 0x100,
				math_floor(mantissa / 0x10000000000) % 0x100,
				(exponent % 0x10) * 0x10 + math_floor(mantissa / 0x1000000000000),
				sign + bit_rshift(exponent, 4)
		end
	end
end