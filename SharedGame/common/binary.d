module common.binary;

import util.traits;
import allocation;

struct BinaryWriter(Backing) //Need to do this in memory! 
{
	Backing b; //Could be a file or a list or somthing else entierly.
	void write(T)(T t) if(isNumeric!T)
	{
		b.put((cast(ubyte*)&t)[0 .. T.sizeof]);
	}

	void write(T)(T t) if(is(Unqual!T == char))
	{
		b.put(cast(ubyte)t);
	}

	void write(T)(T t) if(isArray!T)
	{
		uint len = t.length;
		b.put((cast(ubyte*)&len)[0 .. uint.sizeof]);
		foreach(ref elem; t)
			write(elem);
	}

	void write(T)(T t) if(is(T == struct))
	{
		import util.traits;
		static if(hasMember!(T, "save"))
		{
			t.save(this);
		}
		else static if(!hasIndirections!(T))
		{
			b.put((cast(ubyte*)&t)[0 .. T.sizeof]);
		}
		else static assert(0, "Structs with indirections need to have a save method!");
	}
}

struct BinaryReader
{
	IAllocator allocator;
	ubyte[] data;
	size_t  offset;

	T read(T)() if(isNumeric!T || is(Unqual!T == char))
	{
		T t = *cast(T*)(&data[offset]);
		offset += T.sizeof;
		return t;
	}

	T read(T)() if(isArray!T)
	{
		alias U = FullyUnqual!T;
		uint size = read!uint;
		U	 items = allocator.allocate!(U)(size);

		foreach(i; 0 .. size)
		{
			items[i] = read!(typeof(U.init[0]));
		}

		return cast(T)items;
	}

	T read(T)() if(is(T == struct))
	{
		import util.traits;
		static if(hasMember!(T, "load"))
		{
			t.load(this);
		}
		else static if(!hasIndirections!(T))
		{
			T t = *cast(T*)(&data[offset]);
			offset += T.sizeof;
			return t;
		}
		else static assert(0, "Structs with indirections need to have a load method!");
	}

	void skip(uint count)
	{
		offset += count;
	}
}

auto writer(Backing)(Backing backing)
{
	return BinaryWriter!(Backing)(backing);
}