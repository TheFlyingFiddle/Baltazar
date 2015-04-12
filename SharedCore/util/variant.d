module util.variant;

import util.hash;
import util.traits;
import collections.table;

struct VariantN(size_t size)
{
	void[size - TypeHash.sizeof] data;
	TypeHash id;

	this(T)(auto ref T t) if(T.sizeof <= size - TypeHash.sizeof)
	{
		alias U = FullyUnqual!T;
		this.id  = typeHash!U;
		*cast(T*)(this.data.ptr) = t;
	}

	this(size_t N)(VariantN!(N) value) if(N <= size - TypeHash.sizeof)
	{
		this.id = value.id;
		this.data[0 .. N] = value.data[];
	}

	this(TypeHash hash, const(void)[] data)
	{
		assert(data.length <= size - TypeHash.sizeof);
		this.id = hash;
		this.data[0 .. data.length] = data;
	}

	void opAssign(T)(auto ref T t) if(T.sizeof <= size - TypeHash.sizeof)
	{
		alias U = FullyUnqual!T;
		this.id  = typeHash!U;
		*cast(T*)(this.data.ptr) = t; 
	}

	void opAssign(size_t N)(VariantN!N other) if(N <= size - TypeHash.sizeof)
	{
		this.data[0 .. N] = other.data[];
		this.id			  = other.id;
	}

	ref inout(T) get(T)() inout
	{
		import std.conv;
		assert(typeHash!T == id, text("Wrong typeid id! Expected: ", typeHash!T, "Actual: ", id));

		auto ptr = peek!T;
		assert(ptr);
		return *ptr;
	}

	inout(T)* peek(T)() inout
	{
		if(typeHash!T == id) return cast(T*)(data.ptr);
		else return null;
	}
}

VariantN!(size) variant(size_t size, T)(T t)
{
	return VariantN!size(t);
}

struct VariantTable(size_t size)
{
	private Table!(HashID, string) _map;
	private Table!(string, VariantN!size) _rep;
	this(A)(ref A allocator, size_t count)
	{
		_map = Table!(HashID, string)(allocator, count);
		_rep = Table!(string, VariantN!size)(allocator, count);
	}

	ref VariantN!size opIndex(string name)
	{
		import std.conv;
		auto ptr = name in _rep;
		assert(ptr, text("Value not present in table! ", name));
		return *ptr;
	}

	ref VariantN!size opIndex(HashID hash)
	{
		import std.conv;
		auto ptr = hash in _map;
		assert(ptr, text("Value not present in table! ", hash));
		return this[*ptr];
	}

	void clear()
	{
		_rep.clear();
		_map.clear();
	}

	void opIndexAssign(T)(auto ref T value, string name)
	{
		_map[bytesHash(name)] = name;
		static if(is(T == VariantN!(size)))		
			_rep[name] = value;
		else
			_rep[name] = VariantN!(size)(value);		
	}	

	ref VariantN!size opDispatch(string name)()
	{
		return _rep[name];
	}

	void opDispatch(string name, T)(auto ref T t)
	{
		this[name] = t;
	}

	void add(T)(string name, auto ref T t)
	{
		this[name] = t;
	}

	bool containsKey(string name)
	{
		return (name in _rep) !is null;
	}

	int opApply(int delegate(string, ref VariantN!size) dg)
	{
		return _rep.opApply(dg);
	}
}

unittest
{
	import allocation;
	VariantTable!(64) variant = VariantTable!(64)(Mallocator.it, 100);
	variant.button = 32;

	auto s = variant.button;
}