local NULL_TERMINATOR = "\x00"

local TRUE = 1
local FALSE = 0

local math_huge = math.huge
local math_ldexp = math.ldexp
local math_frexp = math.frexp
local math_floor = math.floor
local string_char = string.char
local table_concat = table.concat

local byteToChar = {}
for i = 0, 255 do
	byteToChar[i] = string_char(i)
end

local write,writeUInt8,writeUInt16,writeUInt32,writeIEEE754Float,writeIEEE754Double

local getPriv
---SHARED<br/>
---In-memory bit buffer.
---@class KBinaryWriteStream : KWriteStream
---@overload fun(str?: string): KBinaryWriteStream
KBinaryWriteStream,getPriv = KClass(function()
	return {[0] = 0}
end)

do --set/get properties
	---SHARED, OVERRIDE<br/>
	---Discards the current stream object and reopens it as its KReadStream variant.<br/>
	---Zero indexed.
	---@return KReadStream
	function KBinaryWriteStream:ReopenAsReadStream()
		local priv = getPriv(self)
		return KBinaryReadStream(table_concat(priv,nil,1,priv[0]))
    end

	---SHARED<br/>
	---Returns the byte stream.
	---@return string
	function KBinaryWriteStream:GetStream()
		local priv = getPriv(self)
		return table_concat(priv,nil,1,priv[0])
	end
end

do --read/write
	---SHARED, OVERRIDE<br/>
	---Writes the specified bytes to the stream.
	---@param bytes string
	function KBinaryWriteStream:Write(bytes)
		write(getPriv(self),bytes)
	end

	---SHARED, OVERRIDE<br/>
	---Writes an 8-bit unsigned integer to the byte stream.
	---@param int integer
	function KBinaryWriteStream:WriteUInt8(int)
        writeUInt8(getPriv(self),int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 16-bit unsigned integer to the byte stream.
	---@param int integer
	function KBinaryWriteStream:WriteUInt16(int)
        writeUInt16(getPriv(self),int)
	end

	--SHARED<br/>
	---Writes a 32-bit unsigned integer from the byte stream.
	---@param int integer
	function KBinaryWriteStream:WriteUInt32(int)
        writeUInt32(getPriv(self),int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes an 8-bit signed integer to the byte stream.
	---@param int integer
	function KBinaryWriteStream:WriteInt8(int)
		int = int % 0x100
        writeUInt8(getPriv(self),int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 16-bit signed integer to the byte stream.
	---@param int integer
	function KBinaryWriteStream:WriteInt16(int)
		int = int % 0x10000
        writeUInt16(getPriv(self),int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 32-bit signed integer to the byte stream.
	---@param int integer
	function KBinaryWriteStream:WriteInt32(int)
		int = int % 0x100000000
        writeUInt32(getPriv(self),int)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 32-bit IEEE754 float from the byte stream.
	---@param float number
	function KBinaryWriteStream:WriteFloat(float)
		writeIEEE754Float(getPriv(self),float)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param double number
	function KBinaryWriteStream:WriteDouble(double)
		writeIEEE754Double(getPriv(self),double)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a string to the byte stream.
	---@param str string
	function KBinaryWriteStream:WriteString(str)
		write(getPriv(self),str .. NULL_TERMINATOR)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a bool to the byte stream.
	---@param bool boolean
	function KBinaryWriteStream:WriteBool(bool)
		writeUInt8(getPriv(self),bool == false and FALSE or TRUE)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Vector to the byte stream using 64-bit doubles.
	---@param vec Vector
	function KBinaryWriteStream:WriteVector(vec)
		local priv = getPriv(self)
		writeIEEE754Double(priv,vec.x)
		writeIEEE754Double(priv,vec.y)
		writeIEEE754Double(priv,vec.z)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Vector to the byte stream using 32-bit floats.
	---@param vec Vector
	function KBinaryWriteStream:WriteVectorF(vec)
		local priv = getPriv(self)
		writeIEEE754Float(priv,vec.x)
		writeIEEE754Float(priv,vec.y)
		writeIEEE754Float(priv,vec.z)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Color to the byte stream.
	---@param color Color
	function KBinaryWriteStream:WriteColor(color)
		local priv = getPriv(self)
		writeUInt8(priv,color.r)
		writeUInt8(priv,color.g)
		writeUInt8(priv,color.b)
		writeUInt8(priv,color.a)
	end
end

do --helper functions
	function write(priv,bytes)
        local i = priv[0] + 1
        priv[0], priv[i] = i, bytes
	end

    function writeUInt8(priv,val)
        write(priv,byteToChar[val])
    end

    function writeUInt16(priv,val)
        writeUInt8(priv,math_floor(val / 0x100))
        writeUInt8(priv,val % 0x100)
    end

    function writeUInt32(priv,val)
        writeUInt16(priv,math_floor(val / 0x10000))
        writeUInt16(priv,val % 0x10000)
    end

	function writeIEEE754Float(priv,number)
        local a = 0

        if number == 0 then
            a = 0x00000000
            if 1 / number < 0 then a = 0x80000000 end
            return writeUInt32(priv,a)
        elseif number ~= number then
            a = 0x7FFFFFFF
            return writeUInt32(priv,a)
        end

        local sign = number < 0 and 1 or 0
        number = sign == 1 and -number or number

        if number == 1 / 0 then
            a = (sign * (2 ^ 31)) + (0xFF * (2 ^ 23))
            return writeUInt32(priv, a)
        end

        local mantissa, exponent = math_frexp(number)
        mantissa = mantissa * 2
        exponent = exponent - 1

        local ieeeExponent = exponent + 127 -- IEEE 754 bias
        if ieeeExponent <= 0 then
            mantissa = math_ldexp(mantissa, ieeeExponent - 1)
            ieeeExponent = 0
        elseif ieeeExponent >= 255 then
            ieeeExponent = 255
            mantissa = 0
        end

        local mantissaBits = math_floor(((mantissa - 1) * (2 ^ 23)) + 0.5)
        mantissaBits = mantissaBits % (2 ^ 23)
        u32 = (sign * (2 ^ 31)) + (ieeeExponent * (2 ^ 23)) + mantissaBits

        return writeUInt32(priv,u32)
	end

	function writeIEEE754Double(priv,number)
		--sign|exponent|mantissa

		if number == 0 then
			--DENORMALISED: Exponent == 0, Mantissa != 0
			--0|000 0000, 0000|..(0000 x12) 0001
			--0x00000000 0x00000001
			if 1 / number < 0 then
				writeUInt32(priv,0x01000000)
            	writeUInt32(priv,0x00000000)
			else
            	writeUInt32(priv,0x00000000)
            	writeUInt32(priv,0x00000000)
			end

			return
		end

		--NAN: Exponent == 255, Mantissa != 0
		--0|000 1111, 1111|..(0000 x12) 0001
		--0x7FF00000 0x00000001
		if number ~= number then
            writeUInt32(priv,0x01000000)
            writeUInt32(priv,0x00000F7F)
			return
		end

		--INFINITY+: Exponent == 255, Mantissa == 0
		--0|000 1111, 1111|..(0000 x12) 0000
		--0x7F400000 0x00000000
		if number == math_huge then
			writeUInt32(priv,0x00000000)
            writeUInt32(priv,0x0000407F)
			return
		end

		--INFINITY+: Exponent == 255, Mantissa == 0
		--1|000 1111, 1111|..(0000 x12) 0000
		--0xFF400000 0x00000000
		if number == -math_huge then
			writeUInt32(priv,0x00000000)
            writeUInt32(priv,0x000040FF)
			return
		end

        local a = 0
        local b = 0

        local sign = number < 0 and 1 or 0
        number = sign == 1 and -number or number

        local mantissa, exponent = math_frexp(number)
        exponent = exponent + 1022

        if exponent > 0 then
            local mantissa_scaled = (mantissa * 2 - 1) * (2 ^ 52)
            local mantissa_upper = math_floor(mantissa_scaled / (2 ^ 32))
            local mantissa_lower = mantissa_scaled % (2 ^ 32)

            a = (sign * (2 ^ 31)) + (exponent * (2 ^ 20)) + (mantissa_upper % (2 ^ 20))
            b = mantissa_lower
        else
            local mantissa_scaled = mantissa * math_ldexp(1,52 + exponent)
            local mantissa_upper = math_floor(mantissa_scaled / (2 ^ 32))
            local mantissa_lower = mantissa_scaled % (2 ^ 32)

            a = (sign * (2 ^ 31)) + (mantissa_upper % (2 ^ 20))
            b = mantissa_lower
        end

        writeUInt32(priv,a)
        writeUInt32(priv,b)
	end
end