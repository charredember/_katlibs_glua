---@meta

local getPriv
---SHARED, ABSTRACT<br/>
---Defines common behavior for write stream classes.
---@class KWriteStream
---@overload fun(str?: string): KWriteStream
KWriteStream = {}

do --set/get properties
	---SHARED, ABSTRACT<br/>
	---Discards the current stream object and reopens it as its KReadStream variant.<br/>
	---Zero indexed.
	---@return KReadStream
	function KWriteStream:ReopenAsReadStream() end
end

do --read/write
	---SHARED, ABSTRACT<br/>
	---Writes the specified bytes to the stream.
	---@param bytes string
	function KWriteStream:Write(bytes) end

	---SHARED, ABSTRACT<br/>
	---Writes an 8-bit unsigned integer to the byte stream.
	---@param int integer
	function KWriteStream:WriteUInt8(int) end

	---SHARED, ABSTRACT<br/>
	---Writes a 16-bit unsigned integer to the byte stream.
	---@param int integer
	function KWriteStream:WriteUInt16(int) end

	---SHARED, ABSTRACT<br/>
	---Writes a 32-bit unsigned integer from the byte stream.
	---@param int integer
	function KWriteStream:WriteUInt32(int) end

	---SHARED, ABSTRACT<br/>
	---Writes an 8-bit signed integer to the byte stream.
	---@param int integer
	function KWriteStream:WriteInt8(int) end

	---SHARED, ABSTRACT<br/>
	---Writes a 16-bit signed integer to the byte stream.
	---@param int integer
	function KWriteStream:WriteInt16(int) end

	---SHARED, ABSTRACT<br/>
	---Writes a 32-bit signed integer to the byte stream.
	---@param int integer
	function KWriteStream:WriteInt32(int) end

	---SHARED, ABSTRACT<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param double number
	function KWriteStream:WriteDouble(double) end

	---SHARED, ABSTRACT<br/>
	---Writes a string to the byte stream.
	---@param str string
	function KWriteStream:WriteString(str) end

	---SHARED, ABSTRACT<br/>
	---Writes a bool to the byte stream.
	---@param bool boolean
	function KWriteStream:WriteBool(bool) end

	---SHARED, ABSTRACT<br/>
	---Writes a Vector to the byte stream.
	---@param vec Vector
	function KWriteStream:WriteVector(vec) end

	---SHARED, ABSTRACT<br/>
	---Writes a Color to the byte stream.
	---@param color Color
	function KWriteStream:WriteColor(color) end
end