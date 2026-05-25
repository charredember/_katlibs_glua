---@meta

local getPriv
---SHARED, ABSTRACT<br/>
---@class KReadStream
---@overload fun(str?: string): KReadStream
KReadStream = {}

do --set/get properties
	---SHARED, ABSTRACT<br/>
	---Sets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@param int integer
	function KReadStream:Seek(int) end

	---SHARED, ABSTRACT<br/>
	---Skips the current read/write position forward by the specified amount of bytes.<br/>
	---@param int integer
	function KReadStream:Skip(int) end

	---SHARED, ABSTRACT<br/>
	---Resets the current read/write position back to zero.<br/>
	function KReadStream:Reset() end

	---SHARED, ABSTRACT<br/>
	---Gets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@return integer
	function KReadStream:Tell() end

	---SHARED, ABSTRACT<br/>
	---Discards the current stream object and reopens it as its KWriteStream variant.<br/>
	---Zero indexed.
	---@return KWriteStream
	function KReadStream:ReopenAsWriteStream() end
end

do --read/write
	---SHARED, ABSTRACT<br/>
	---Reads the specified amount of bytes from the byte stream.
	---@param amount integer
	---@return string
	function KReadStream:Read(amount) end

	---SHARED, ABSTRACT<br/>
	---Reads from the byte stream until the specified character is read.
	---@param byte string
	---@return string
	function KReadStream:ReadUntil(byte) end

	---SHARED, ABSTRACT<br/>
	---Reads an 8-bit unsigned integer from the byte stream.
	---@return integer
	function KReadStream:ReadUInt8() end

	---SHARED, ABSTRACT<br/>
	---Reads a 16-bit unsigned integer from the byte stream.
	---@return integer
	function KReadStream:ReadUInt16() end

	---SHARED, ABSTRACT<br/>
	---Reads a 32-bit unsigned integer from the byte stream.
	---@return integer
	function KReadStream:ReadUInt32() end

	---SHARED, ABSTRACT<br/>
	---Reads an 8-bit signed integer from the byte stream.
	---@return integer
	function KReadStream:ReadInt8() end

	---SHARED, ABSTRACT<br/>
	---Reads a 16-bit signed integer from the byte stream.
	---@return integer
	function KReadStream:ReadInt16() end

	---SHARED, ABSTRACT<br/>
	---Reads a 32-bit signed integer from the byte stream.
	---@return integer
	function KReadStream:ReadInt32() end

	---SHARED, ABSTRACT<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@return number
	function KReadStream:ReadDouble() end

	---SHARED, ABSTRACT<br/>
	---Reads a string from the byte stream.
	---@return string
	function KReadStream:ReadString() end

	---SHARED, ABSTRACT<br/>
	---Reads a bool from the byte stream.
	---@return boolean
	function KReadStream:ReadBool() end

	---SHARED, ABSTRACT<br/>
	---Reads a Vector from the byte stream.
	---@return Vector
	function KReadStream:ReadVector() end

	---SHARED, ABSTRACT<br/>
	---Reads a Color from the byte stream.
	---@return Color
	function KReadStream:ReadColor() end
end