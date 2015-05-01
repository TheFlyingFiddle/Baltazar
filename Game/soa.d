module soa;

import allocation;
import util.traits;

struct SOA(T)
{
	alias Fields = toPtr!(T.tupleof);
	Fields fields_;
	size_t length;

	this(IAllocator all, size_t size)
	{
		this.length = size;
		auto mem = all.allocateRaw(T.sizeof * size, 64).ptr;
		size_t current = 0;
		foreach(i, ref field; fields_)
		{
			alias FT = typeof(field);
			field = cast(FT)(mem + current);
			current += FT.sizeof * size;
		}
	}

	void reallocate(IAllocator all, size_t newSize)
	{
		assert(length <= newSize);

		auto mem = all.allocateRaw(T.sizeof * newSize, 64).ptr;
		size_t current = 0;
		foreach(i, ref field; fields_)
		{
			alias FT   = typeof(field);
			import std.c.string;
			memcpy(mem + current, fields_[i], FT.sizeof * length);
			field = cast(FT)(mem + current);
			current += FT.sizeof * newSize;
		}
		length = newSize;
	}

	void deallocate(IAllocator all)
	{
		uint size = T.sizeof * length;
		all.deallocate((cast(void*)fields_[0])[0 .. size]);
	}

	void opIndexAssign(T value, size_t index)
	{
		foreach(i, f; value.tupleof)
		{
			fields_[i][index] = f;
		}
	}

	void swap(size_t idx0, size_t idx1)
	{
		import std.algorithm;
		foreach(i, ref field; fields_)
		{
			swap(field[idx0], field[idx1]);
		}
	}

	template fieldMatch(string str)
	{
		template fieldMatch(int idx)
		{
			enum fieldMatch = Identifier!(T.tupleof[idx]) == str;
		}
	}

	auto opDispatch(string s)() if(anySatisfy!(fieldMatch!s, staticIota!(0, T.tupleof.length)))
	{
		foreach(i, f; T.init.tupleof)
		{
			static if(s == Identifier!(T.tupleof[i]))
			{
				return fields_[i];
			}
		}

		assert(0, "Can't happen!");
	}
}

private:

template helper(U)
{
	alias helper = U*;
}

template helper2(U...)
{
	alias helper2 = typeof(U[0]);
}

template toPtr(T...)
{
	alias toPtr = staticMap!(helper, staticMap!(helper2, T));
}
