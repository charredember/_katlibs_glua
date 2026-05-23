---@meta

local getPriv
---SHARED, ABSTRACT<br/>
---@class KStream
---@overload fun(str?: string): KStream
KStream = {}

do --set/get properties
	---SHARED, ABSTRACT<br/>
	---Sets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@param int integer
	function KStream:Seek(int) end

	---SHARED, ABSTRACT<br/>
	---Skips the current read/write position forward by the specified amount of bytes.<br/>
	---@param int integer
	function KStream:Skip(int) end

	---SHARED, ABSTRACT<br/>
	---Resets the current read/write position back to zero.<br/>
	function KStream:Reset() end

	---SHARED, ABSTRACT<br/>
	---Gets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@return integer
	function KStream:Tell() end
end

do --read/write
	---SHARED, ABSTRACT<br/>
	---Reads the specified amount of bytes from the stream.
	---@param amount integer
	---@return string
	function KStream:Read(amount) end

	---SHARED, ABSTRACT<br/>
	---Writes the specified bytes to the stream.
	---@param bytes string
	function KStream:Write(bytes) end

	---SHARED, ABSTRACT<br/>
	---Reads from the byte stream until the specified character is read.
	---@param byte string
	---@return string
	function KStream:ReadUntil(byte) end

	---SHARED, ABSTRACT<br/>
	---Reads an 8-bit unsigned integer from the byte stream.
	---@return integer
	function KStream:ReadUInt8() end

	---SHARED, ABSTRACT<br/>
	---Writes an 8-bit unsigned integer to the byte stream.
	---@param int integer
	function KStream:WriteUInt8(int) end

	---SHARED, ABSTRACT<br/>
	---Reads a 16-bit unsigned integer from the byte stream.
	---@return integer
	function KStream:ReadUInt16() end

	---SHARED, ABSTRACT<br/>
	---Writes a 16-bit unsigned integer to the byte stream.
	---@param int integer
	function KStream:WriteUInt16(int) end

	---SHARED, ABSTRACT<br/>
	---Reads a 32-bit unsigned integer from the byte stream.
	---@return integer
	function KStream:ReadUInt32() end

	---SHARED, ABSTRACT<br/>
	---Writes a 32-bit unsigned integer from the byte stream.
	---@param int integer
	function KStream:WriteUInt32(int) end

	---SHARED, ABSTRACT<br/>
	---Reads an 8-bit signed integer from the byte stream.
	---@return integer
	function KStream:ReadInt8() end

	---SHARED, ABSTRACT<br/>
	---Writes an 8-bit signed integer to the byte stream.
	---@param int integer
	function KStream:WriteInt8(int) end

	---SHARED, ABSTRACT<br/>
	---Reads a 16-bit signed integer from the byte stream.
	---@return integer
	function KStream:ReadInt16() end

	---SHARED, ABSTRACT<br/>
	---Writes a 16-bit signed integer to the byte stream.
	---@param int integer
	function KStream:WriteInt16(int) end

	---SHARED, ABSTRACT<br/>
	---Reads a 32-bit signed integer from the byte stream.
	---@return integer
	function KStream:ReadInt32() end

	---SHARED, ABSTRACT<br/>
	---Writes a 32-bit signed integer to the byte stream.
	---@param int integer
	function KStream:WriteInt32(int) end

	---SHARED, ABSTRACT<br/>
	---Writes a 64-bit IEEE754 double to the byte stream.
	---@return number
	function KStream:ReadDouble() end

	---SHARED, ABSTRACT<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param double number
	function KStream:WriteDouble(double) end

	---SHARED, ABSTRACT<br/>
	---Reads a string from the byte stream.
	---@return string
	function KStream:ReadString() end

	---SHARED, ABSTRACT<br/>
	---Writes a string to the byte stream.
	---@param str string
	function KStream:WriteString(str) end

	---SHARED, ABSTRACT<br/>
	---Writes a bool to the byte stream.
	---@param bool boolean
	function KStream:WriteBool(bool) end

	---SHARED, ABSTRACT<br/>
	---Reads a bool from the byte stream.
	---@return boolean
	function KStream:ReadBool() end

	---SHARED, ABSTRACT<br/>
	---Writes a Vector to the byte stream.
	---@param vec Vector
	function KStream:WriteVector(vec) end

	---SHARED, ABSTRACT<br/>
	---Reads a Vector from the byte stream.
	---@return Vector
	function KStream:ReadVector() end

	---SHARED, ABSTRACT<br/>
	---Writes a Color to the byte stream.
	---@param color Color
	function KStream:WriteColor(color) end

	---SHARED, ABSTRACT<br/>
	---Reads a Color from the byte stream.
	---@return Color
	function KStream:ReadColor() end
end