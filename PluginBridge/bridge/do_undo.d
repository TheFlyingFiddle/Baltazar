module bridge.do_undo;

import std.traits;
import allocation;
import log;
import collections.list;
import util.traits;
import util.hash;

struct DoUndo
{
	template isCommand(U)
	{
		enum isCommand = is(U == struct) &&
			__traits(compiles, 
					 {
						 U u;
						 u.apply();
						 u.revert();
					 });
	}

	struct ICommand
	{
		void apply() { }
		void revert() { }

		@Optional void clear() { }
	}

	alias Command = ClassN!(ICommand, 64);
	GrowingList!Command commands;
	private size_t redoCount;

	this(size_t initialSize)
	{
		redoCount  = 0;
		commands   = GrowingList!(Command)(Mallocator.cit, initialSize);
	}

	bool canRedo()
	{
		return redoCount > 0;
	}

	void add(U)(auto ref U u) if(isCommand!U)
	{
		if(redoCount > 0)
		{
			foreach(i; commands.length - redoCount .. commands.length)
				commands[i].clear();

			commands.length = commands.length - redoCount;
			redoCount = 0;
		}

		commands ~= Command(u);
	}

	void apply(U)(auto ref U u) if(isCommand!U)
	{
		add!(U)(u);
		commands[$ - 1].apply();
	}

	void undo()
	{
		if(commands.length > redoCount)
		{
			commands[$ - redoCount - 1].revert();
			redoCount++;
		}
	}

	void redo()
	{
		if(redoCount > 0)
		{
			commands[$ - redoCount].apply();
			redoCount--;
		}
	}

	void clear()
	{
		foreach(ref cmd; commands)
			cmd.clear();

		commands.clear();
		redoCount = 0;
	}
}


struct Optional { }
struct ClassN(Interface, size_t N)
{
	__gshared static ClassHelper!(Interface, N) helper;

	void[N - 1] data;
	ubyte		type;

	this(T, Args...)(Args a) if(implementsI!T)
	{
		emplace!(T)(cast(T*)(v.data.ptr), a);
		type = helper.typeID!T;

	}

	this(T)(ref T t) if(implementsI!T)
	{
		import std.c.string;
		*cast(T*)(data.ptr) = t;
		type = helper.typeID!T;
	}

	auto ref opDispatch(string s, Args...)(Args args)
	{
		return call!(s, Args)(args);
	}	

	auto ref call(string s, Args...)(Args args)
	{
		return helper.call!(s, Args)(this, args);
	}

	T* opCast(T)() if(implementsI!(T))
	{
		assert(helper.typeID!T == type);
		return cast(T*)data.ptr;
	}

	template implementsI(T)
	{
		enum implementsI = T.sizeof <= N - 1;
	}

}

struct ClassHelper(Interface, size_t N)
{
	alias Class = ClassN!(Interface, N);
	enum maxFunctions = Methods!(Interface).length;

	private void*[ubyte.max * maxFunctions]    vtable;
	private TypeHash[ubyte.max] types;
	private ubyte typeCount;

	ubyte typeID(T)() if(T.sizeof <= N - 1)
	{
		enum thash = typeHash!T;
		import std.algorithm;
		auto index = types[0 .. typeCount].countUntil!(x => x == thash);
		if(index == -1)
		{
			assert(typeCount < ubyte.max, "Failed to crete new type!");
			index = setupType!T();
		}

		return cast(ubyte)index;
	}

	template isOptional(alias method)
	{
		enum isOptional = exists!(Optional, __traits(getAttributes, method));
	}

	ubyte setupType(T)()
	{
		T t = T.init;

		types[typeCount] = typeHash!T;
		alias methods = Methods!(Interface);
		auto index = typeCount * maxFunctions;
		foreach(i, method; methods)
		{

			enum id = Identifier!method;
			static if(isOptional!method)
			{
				static if(hasMember!(T, id))
					mixin("vtable[index + i] = cast(void*)(&t." ~ id ~ ").funcptr;");
				else 
					vtable[index + i] = cast(void*)null;
			}
			else 
			{
				mixin("vtable[index + i] = cast(void*)(&t." ~ id ~ ").funcptr;");
			}
		}

		return typeCount++;
	}

	template methodIndex(string name)
	{
		template isName(T...)
		{
			enum id = Identifier!T;
			enum isName = id == name;
		}

		enum methodIndex = staticIndexOf!(true, staticMap!(isName, Methods!Interface));
	}

	auto ref opDispatch(string s, Args...)(ref Virtual v, Args args)
	{
		call!(s, Args)(v, args);
	}

	auto ref call(string s, Args...)(ref Class data, Args args)
	{
		enum idx = methodIndex!s;
		static assert(idx != -1, "Failed to find method " ~ s);

		import std.traits;
		alias R = ReturnType!((Methods!Interface)[idx]);
		return dispatch!(R, Args)(data, idx, args);
	}

	auto ref dispatch(R, Args...)(ref Class data, int functionIndex, Args args)
	{
		auto ptr = vtable[data.type  * maxFunctions  + functionIndex];	
		if(ptr !is null)
		{
			alias del = R delegate(Args);

			del d;
			d.ptr	  = data.data.ptr;
			d.funcptr = cast(R function(Args))(ptr);
			return d(args);
		}
		else 
		{
			//Was an optional method do nothing!
		}
	}
}