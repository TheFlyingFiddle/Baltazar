module bridge.data;

import std.bitmanip;
import util.traits;
import math.vector;
import collections.map;
import reflection.data : DontReflect;
import allocation;

alias Guid = uint;


//Could be interesting to add small string optimization
//For string 0-11 bytes large.
enum DataTag : ubyte
{
	int_,
	float_,
	vector_,
	string_,
	array_,
}

enum ArrayElementTag : ubyte
{
	byte_,
	short_,
	int_,
	long_,
	float_,
	double_,
	float2_,
	int2_,
}

auto elementSize(ArrayElementTag tag) nothrow
{
	final switch(tag) with(ArrayElementTag)
	{
		case byte_:   return 1;
		case short_:  return 2;
		case int_:    return 4;
		case long_:   return 8;
		case float_:  return 4;
		case double_: return 8;
		case float2_: return 8;
		case int2_:  return 8;
	}
}

ubyte[T.sizeof] toByteArray(T)(ref T t)
{
	return cast(ubyte[T.sizeof])(cast(ubyte*)(&t))[0 .. T.sizeof];
}

template elementTag(T)
{
	static if(is(T == ubyte) || is(T == byte))
		enum elementTag = ArrayElementTag.byte_;
	else static if(is(T == ushort) || is(T == short))
		enum elementTag = ArrayElementTag.short_;
	else static if(is(T == int) || is(T == uint))
		enum elementTag = ArrayElementTag.int_;
	else static if(is(T == ulong) || is(T == long))
		enum elementTag = ArrayElementTag.long_;
	else static if(is(T == float))
		enum elementTag = ArrayElementTag.float_;
	else static if(is(T == double))
		enum elementTag = ArrayElementTag.double_;
	else static if(is(T == float2))
		enum elementTag = ArrayElementTag.float2_;
	else static if(is(T == int2))
		enum elementTag = ArrayElementTag.int2_;
	else static if(T.sizeof == 1)
		enum elementTag = ArrayElementTag.byte_;
	else static if(T.sizeof == 2)
		enum elementTag = ArrayElementTag.short_;
	else static if(T.sizeof == 4)
		enum elementTag = ArrayElementTag.int_;
	else static if(T.sizeof == 8)
		enum elementTag = ArrayElementTag.long_;
	else 
		static assert(0, "Cannot use type " ~ T.stringof ~ " as an arraytype!");
}


//Should be 12 bytes max. 
@DontReflect
align(4) struct Data
{
	align(1):
	mixin(bitfields!(uint, "tag", 8, uint, "meta", 24));
	private struct arr_t
	{
		void* buffer;
		mixin(bitfields!(uint, "elementTag", 8, uint, "capacity", 24));
	}

	union
	{
		ulong		int_;
		double		float_;
		float2		vector_;
		string		string_;	
		arr_t		array_;
		ubyte[8]    unkown_;
	}

	static Data create(T)(auto ref T t)
	{
		alias ints   = TypeTuple!(ubyte, byte, ushort, short, int, uint, long, ulong);
		alias floats = TypeTuple!(float, double);

		import log;

		Data d;
		static if(staticIndexOf!(T, ints) != -1)
		{
			d.tag  = DataTag.int_;
			d.int_ = cast(ulong)t;
		}
		else static if(staticIndexOf!(T, floats) != -1)
		{
			d.tag = DataTag.float_;
			d.float_ = cast(double)t;
		}
		else static if(isSomeString!T)
		{
			d.tag		= DataTag.string_;
			d.string_	= t;
		}
		else static if(is(T == float2))
		{
			d.tag		= DataTag.vector_;
			d.vector_	= t;
		}
		else static if(T.sizeof <= 8)
		{
			d.tag				   = DataTag.int_;
			*cast(T*)d.unkown_.ptr = t;
		}
		else static assert(0, T.stringof ~ " cannot be placed inside a datastore!");

		return d;
	}

	bool opEquals(const ref Data other) nothrow
	{
		if(this.tag == other.tag)
		{
			return this.meta == other.meta && 
				   this.int_ == other.int_;
		}

		return false;
	}

	void opAssign(Data other) nothrow
	{
		import std.c.string;
		memcpy(&this, &other, Data.sizeof);
	}


	T get(T)() if(isArray!T && !isSomeString!T)
	{
		assert(tag == DataTag.array_);
		alias ET = typeof(T.init[0]);
		return cast(T)array_.buffer[0 .. ET.sizeof * meta];
	}	

	T get(T)() if(!isArray!T || isSomeString!T)
	{
		assert(tag != DataTag.array_);
		return *cast(T*)(unkown_.ptr);
	}
}

@DontReflect
struct DataStore
{
	import collections.map, allocation, std.exception;

	HashMap!(Guid, HashMap!(string, Data)) data;
	this(IAllocator allocator)
	{
		data = HashMap!(Guid, HashMap!(string, Data))(allocator, 4);
		data.add(Guid.init, HashMap!(string, Data)(allocator, 4));
	}

	void deallocate()
	{
		foreach(ref k, ref v; data)
		{
			v.deallocate();
		}

		data.deallocate();
	}

	HashMap!(string, Data) getObject(Guid guid)
	{
		return data[guid];
	}

	ref IAllocator allocator()
	{
		return data.allocator;
	}	

	bool create(Guid guid) nothrow
	{
		return data.tryAdd(guid, HashMap!(string, Data)(data.allocator, 4)) !is null;
	}

	bool destroy(Guid guid) nothrow
	{
		return data.remove(guid);
	}

	bool exists(Guid guid) nothrow
	{
		return data.has(guid);
	}

	bool hasProperty(Guid guid, string key) nothrow
	{
		auto m = guid in data;
		if(m) return m.has(key);

		return false;
	}

	Data* getProperty(Guid guid, string key) nothrow
	{
		auto map = guid in data;
		if(!map) return null;

		return key in (*map);
	}

	bool removeProperty(Guid guid, string key) nothrow
	{
		auto map = &data[guid];
		return map.remove(key); 
	}

	void setProperty(T)(Guid guid, string key, T t) nothrow if((!isArray!T || is(FullyUnqual!T == char[])) && !is(T == Data)) 
	{
		Data d = Data.create(t);
		setProperty(guid, key, d);
	}

	void setProperty(Guid guid, string key, ref Data d) nothrow
	{
		auto map = &data[guid];
		Data* p = key in *map;
		if(!p)
			map.add(key, d);
		else
			*p = d;
	}
	void setArrayProperty(T)(Guid guid, string key, uint capacity = 8) nothrow
	{
		setArrayProperty(guid, key, elementTag!T, capacity);
	}

	void setArrayProperty(Guid guid, string key,ArrayElementTag element, uint capacity = 8) nothrow
	{
		scope(failure) return;

		Data d;
		d.tag			    = DataTag.array_;
		d.meta				= 0; //Used as length!
		d.array_.elementTag  = element;
		d.array_.capacity	= capacity;
		d.array_.buffer     = allocator.allocateRaw(capacity * elementSize(element), elementSize(element)).ptr;
		setProperty(guid, key, d);
	}

	void setArrayElement(T)(Guid guid, string key, uint index, ref T item) nothrow
	{
		setArrayElement(guid, key, index, cast(ubyte*)(&item)[0 .. T.sizeof]);
	}

	void setArrayElement(Guid guid, string key, uint index, ubyte[] item) nothrow
	{
		auto d = getProperty(guid, key);

		assert(d);
		assert(d.tag == DataTag.array_);
		assert(d.meta > index);

		auto elementSize = elementSize(cast(ArrayElementTag)d.array_.elementTag);
		d.array_.buffer[index * elementSize .. index * elementSize + elementSize] = (cast(void*)(&item))[0 .. elementSize];
	}

	ubyte[] getArrayElement(Guid guid, string key, uint index) nothrow
	{	
		auto d = getProperty(guid, key);

		assert(d);
		assert(d.tag == DataTag.array_);
		auto size = elementSize(cast(ArrayElementTag)d.array_.elementTag);
		return cast(ubyte[])d.array_.buffer[index * size .. index * size + size]; 
	}

	void appendArrayElement(T)(Guid guid, string key, ref T item) nothrow
	{
		appendArrayElement(guid, key, (cast(ubyte*)(&item))[0 .. T.sizeof]);
	}

	void appendArrayElement(Guid guid, string key, ubyte[] item) nothrow 
	{
		scope(failure) return;
		auto d = getProperty(guid, key);

		assert(d);
		assert(d.tag == DataTag.array_);

		auto length = d.meta;
		auto cap	= d.array_.capacity;
		if(length == d.array_.capacity)
		{
			auto nBuffer = allocator.allocateRaw(cap * item.length * 2, item.length).ptr;
			nBuffer[0 .. cap * item.length] = d.array_.buffer[0 .. cap * item.length];
			allocator.deallocate(d.array_.buffer[0 .. cap * item.length]);
			d.array_.buffer = nBuffer;
			d.array_.capacity = cap * 2;
		}

		d.meta = d.meta + 1;
		d.array_.buffer[length * item.length .. length * item.length + item.length] = item[];
	}

	void insertArrayElement(T)(Guid guid, string key, uint index, ref T item) nothrow
	{
		insertArrayElement(guid, key, index, cast(ubyte*)(&item)[0 .. T.sizeof], elementTag!T);
	}

	void insertArrayElement(Guid guid, string key, uint index, ubyte[] item) nothrow
	{
		scope(failure) return;

		auto d = getProperty(guid, key);

		assert(d);
		assert(d.tag == DataTag.array_);
		assert(d.meta >= index);

		auto length = d.meta;
		auto cap	= d.array_.capacity;
		if(length == d.array_.capacity)
		{
			auto nBuffer = allocator.allocateRaw(cap * item.length * 2, item.length).ptr;
			nBuffer[0 .. cap * item.length] = d.array_.buffer[0 .. cap * item.length];
			allocator.deallocate(d.array_.buffer[0 .. cap * item.length]);
			d.array_.buffer = nBuffer;
			d.array_.capacity = cap * 2;
		}

		auto ridx = index * item.length;
		auto end  = d.meta * item.length;

		import std.c.string;
		memmove(&d.array_.buffer[ridx + item.length], &d.array_.buffer[ridx], end - ridx);
		d.array_.buffer[ridx .. ridx + item.length] = item[];
		d.meta = d.meta + 1;
	}

	void removeArrayElementAt(Guid guid, string key, uint index) nothrow
	{
		auto d = getProperty(guid, key);
		assert(d);
		assert(d.tag == DataTag.array_);
		assert(d.meta > index);

		auto size = elementSize(cast(ArrayElementTag)d.array_.elementTag);
		auto ridx = index * size;
		auto end  = d.meta * size;

		import std.c.string;
		memmove(&d.array_.buffer[ridx], &d.array_.buffer[ridx + size], size * (d.meta - index - 1));
		d.meta = d.meta - 1;
	}

	bool removeArrayElement(Guid guid, string key, ubyte[] item) nothrow
	{
		import std.c.string;
		auto d = getProperty(guid, key);
		assert(d);
		assert(d.tag == DataTag.array_);

		void* buffer = d.array_.buffer;
		foreach(i; 0 .. d.meta)
		{
			if(memcmp(buffer, item.ptr, item.length) == 0)
			{
				removeArrayElementAt(guid, key, i);
				return true;
			}

			buffer += item.length;
		}

		return false;
	}

	int indexOfArrayElement(Guid guid, string key, ubyte[] item) nothrow
	{
		import std.c.string;
		auto d = getProperty(guid, key);
		assert(d);
		assert(d.tag == DataTag.array_);
		void* buffer = d.array_.buffer;
		foreach(i; 0 .. d.meta)
		{
			if(memcmp(buffer, item.ptr, item.length) == 0)
			{
				return i; 
			}

			buffer += item.length;
		}

		return -1;
	}
}

@DontReflect
interface IEditorState
{
	Data* getProperty(Guid guid, string key) nothrow;
	ubyte[] getArrayElement(Guid guid, string key, uint index) nothrow;
	void setProperty(Guid guid, string key, Data data) nothrow;

	//Arrays
	void setArrayProperty(Guid guid, string key, uint capacity, ArrayElementTag tag) nothrow;
	void setArrayElement (Guid guid, string key, uint index, ubyte[] value) nothrow;
	void appendArrayElement(Guid guid, string key, ubyte[] value, ArrayElementTag tag) nothrow;
	void insertArrayElement(Guid guid, string key, uint index, ubyte[] value) nothrow;
	void removeArrayElementAt(Guid guid, string key, uint index) nothrow;
	void removeArrayElement(Guid guid, string key, ubyte[] item) nothrow;


	void appendArrayElement(T)(Guid guid, string key, T value)
	{
		appendArrayElement(guid, key, toByteArray(value), elementTag!T);
	}

	bool exists(Guid guid) nothrow;
	bool exists(Guid guid, string key) nothrow;
	HashMap!(string, Data) object(Guid guid) nothrow;
	Guid createObject() nothrow;
	bool create(Guid guid) nothrow;
	bool destroy(Guid guid) nothrow;
	bool removeProperty(Guid guid, string key) nothrow;

	void undo();
	void redo();
	void setRestorePoint();

	auto proxy(T, string s = "")(Guid guid) 
	{
		static if(s == "")
			static if(is(T == float2))
				enum s2 = "float2";
			else 
				enum s2 = T.stringof;
		else 
			enum s2 = s;

		return EditorStateProxy!(T, s2)(guid, this);
	}
}


@DontReflect
struct EditorStateProxy(T, string s) if(is(T == struct))
{
	enum  isBasic(T) = T.sizeof <= 8 && (!isArray!T || isSomeString!T);
	private Guid __guid;
	private IEditorState __state;

	mixin(fields());

	this(Guid __guid, IEditorState __state)
	{
		this.__guid  = __guid;
		this.__state = __state;
	}

	this(Guid __guid, IEditorState __state, T t)
	{
		this.__guid  = __guid;
		this.__state = __state;

		set(t);	
	}

	bool opEquals(ref const T other)
	{
		return get == other;
	}

	bool opEquals(const T other)
	{
		return get == other;
	}

	void removeFields()
	{
		foreach(i, dummy; T.init.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);
			enum name = T.tupleof[i].stringof;
			enum pname = s ~ "." ~ name;
			static if(FT.sizeof <= 8)
				__state.removeProperty(__guid, pname);
			else 
				EditorStateProxy!(FT, pname)(__guid, __state).removeFields();
		}
	}

	import log;
	void set(T t) 
	{
		foreach(i, ref field; t.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);
			static if(!isArray!FT || isSomeString!FT) // Not ideal.
			{
				enum name = T.tupleof[i].stringof;
				mixin("this." ~ name ~ " = field;");
			}
		}
	}

	T get()
	{
		T t;
		foreach(i, ref field; t.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);
			enum name = T.tupleof[i].stringof;
			static if(isBasic!(FT))
				mixin("field = this." ~ T.tupleof[i].stringof ~ ";");
			else 
				mixin("field = this." ~ T.tupleof[i].stringof ~ ".get;");
		}

		return t;
	}

	private static string fields()
	{
		import std.conv, std.traits;
		string str = "";
		str ~= "import " ~ moduleName!(T) ~ ";\n";
		foreach(i, dummy; T.init.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);

			enum name = T.tupleof[i].stringof;
			enum pname = s ~ "." ~ name;
			enum type = typeof(T.tupleof[i]).stringof;
			static if(isBasic!FT)
			{
				str ~= 
					"
					@property void " ~ name ~ "(" ~ type ~ " value)
					{
						Data d = Data.create(value);
						__state.setProperty(__guid, \"" ~ pname ~ "\", d);
					}
					@property " ~ type ~ " " ~ name ~ "()
					{
						auto p = __state.getProperty(__guid, \"" ~ pname ~ "\");
						if(p) return *cast(" ~ type ~ "*)(p.unkown_);
						return T.init.tupleof[" ~ i.to!string ~ "];
					}
					";
			}
			else 
			{
				enum ptype = "EditorStateProxy!(" ~ typeof(T.tupleof[i]).stringof ~ ", \"" ~ pname ~ "\")";

				static if(!isArray!FT || isSomeString!T)
				{
					str ~=
						"
						@property void " ~ name ~ "(" ~ type ~ " value)
						{
						" ~ ptype ~ "(__guid, __state, value);
						}
						";
				}

				str ~= "
					@property " ~ ptype ~ " " ~ name ~ "()
					{
					return " ~ ptype ~ "(__guid, __state);
					}
					";
			}
		}

		return str;
	}

}

@DontReflect
struct EditorStateProxy(T, string s) if(isArray!T && !isSomeString!T)
{
	import std.range;
	alias ET = ElementType!T;

	private Guid __guid;
	private IEditorState __state;

	this(Guid __guid, IEditorState __state)
	{
		this.__guid  = __guid;
		this.__state = __state;
	}

	void create(uint capacity = 8)
	{
		__state.setArrayProperty(__guid, s, capacity, elementTag!ET);
	}

	void opIndexAssign(ref ET value, size_t index)
	{
		__state.setArrayElement(__guid, s, index,  (cast(ubyte*)(&value))[0 .. ET.sizeof]);
	}

	void opIndexAssign(ET value, size_t index)
	{
		__state.setArrayElement(__guid, s, index, (cast(ubyte*)(&value))[0 .. ET.sizeof]);
	}

	void opOpAssign(string op : "~")(ET value)
	{
		__state.appendArrayElement(__guid, s, (cast(ubyte*)(&value))[0 .. ET.sizeof], elementTag!(ET));
	}

	void insert(uint index, ET value)
	{
		__state.insertArrayElement(__guid, s, index, (cast(ubyte*)(&value))[0 .. ET.sizeof]);
	}	

	void removeAt(uint index)
	{
		__state.removeArrayElementAt(__guid, s, index);
	}

	void remove(ET value)
	{
		__state.removeArrayElement(__guid, s, (cast(ubyte*)(&value))[0 .. ET.sizeof]);
	}

	T get()
	{
		auto res = __state.getProperty(__guid, s);
		if(res)
		{
			auto buffer = res.array_.buffer[0 .. res.meta * ET.sizeof];
			return cast(T)buffer;
		}
		else 
		{
			return T.init;
		}
	}

	ET opIndex(size_t index)
	{
		auto array = __state.getProperty(__guid, s);
		if(array) 
		{
			return *cast(ET*)__state.getArrayElement(__guid, s, index).ptr;
		}

		return ET.init;
	}
}




import content.sdl;
struct DataStoreContext
{
	T read(T, C)(SDLIterator!(C)* iter) if(is(T == Data))
	{
		auto type = iter.objType;
		final switch(type) with(SDLObject.Type)
		{
			case _float: 
				return Data.create(iter.readFloat());
			case _int:
				return Data.create(iter.readInt());
			case _string:
				import allocation;
				auto str = iter.readString();
				auto mem = GC.it.allocate!(char[])(str.length, 1);
				mem[] = str;
				return Data.create(cast(string)mem);
			case _parent:
			{
				auto idx = iter.currentIndex;
				iter.goToChild();
				auto name = iter.readName();
				if(name == "x" || name == "y")
				{
					iter.currentIndex = idx;
					return Data.create(iter.as!(float2));
				}
				else 
				{
					auto tag = iter.as!(ArrayElementTag);
					iter.goToNext();
					final switch(tag) with (ArrayElementTag)
					{
						case byte_:		return fromSDLArray!(ubyte)(byte_, iter);
						case short_:	return fromSDLArray!(ushort)(short_, iter);
						case int_:		return fromSDLArray!(uint)(int_, iter);
						case long_:		return fromSDLArray!(ulong)(long_, iter);
						case float_:	return fromSDLArray!(float)(float_, iter);
						case double_:	return fromSDLArray!(double)(double_, iter);
						case float2_:	return fromSDLArray!(float2)(float2_, iter);
						case int2_:		return fromSDLArray!(int2)(int2_, iter);
					}
				}
			}
		}
	}

	Data fromSDLArray(T, C)(ArrayElementTag tag, SDLIterator!(C)* iter)
	{
		T[] data = iter.as!(T[]);

		Data d;
		d.tag = DataTag.array_;
		d.array_.elementTag = tag;
		d.meta = data.length;
		d.array_.buffer = data.ptr;
		return d;
	}

	void write(T, Sink)(ref T t, ref Sink sink, int level) if(is(T == Data))
	{
		final switch(cast(DataTag)t.tag) with(DataTag)
		{
			case DataTag.int_:	
				toSDL(t.int_, sink, &this, level);
			break;
			case DataTag.float_:
				toSDL(t.float_, sink, &this, level);
			break;
			case DataTag.string_:
				toSDL(t.string_, sink, &this, level);
			break;
			case DataTag.array_:
				final switch(cast(ArrayElementTag)t.array_.elementTag) with (ArrayElementTag)
				{
					case byte_:		toSDLArray!(ubyte)(byte_, sink, level, t);		break;
					case short_:	toSDLArray!(ushort)(short_, sink, level, t);	break;
					case int_:		toSDLArray!(uint)(int_, sink, level, t);      break;
					case long_:		toSDLArray!(ulong)(long_, sink, level, t);     break;
					case float_:	toSDLArray!(float)(float_, sink, level, t);	  break;
					case double_:	toSDLArray!(double)(double_, sink, level, t); break;
					case float2_:	toSDLArray!(float2)(float2_, sink, level, t); break;
					case int2_:		toSDLArray!(int2)(int2_, sink, level, t);	break;
				}
			break;
			case DataTag.vector_:
				toSDL(t.vector_, sink, &this, level);
			break;
		}
	}

	void toSDLArray(T, Sink)(ArrayElementTag tag, ref Sink sink, int level, ref Data data)
	{
		struct Tmp
		{
			ArrayElementTag tag;
			T[] data;
		}

		Tmp t;
		t.tag = cast(ArrayElementTag)tag;
		t.data = cast(T[])(data.array_.buffer[0 .. data.meta * T.sizeof]);
		
		toSDL(t, sink, &this, level);
	}
}


unittest
{
	import graphics.color;
	struct Test
	{
		byte a;
		short b;
		int c;
		long d;
		float e;
		double f;
		float2 g;
		byte[] h;
		short[] i;
		int[]	j;
		long[]  k;
		float[] l;
		double[] m;
		float2[] n;
		int2[]	 o;
		Color[]  p;
		Color	 q;
	}

	Test t = Test
		(0, 1, 2, 3, 4.0f, 5.0f, float2(1, 2),
		 [0, 1, 2, 3], [0, 1, 2, 3, 4],
		 [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5, 6],
		 [0.0f, 0.5f, 1.0f, 1.5f], [0.0, 0.5, 1.0, 1.5, 2.0],
		 [float2.zero, float2(0.4, 1.3), float2.one], [int2.zero, int2.one],
		 [Color.red, Color.blue, Color.green],  Color.blue);

	//Testing;
	DataStore store = DataStore(Mallocator.cit);
	store.create(Guid.init);

	foreach(i, field; t.tupleof)
	{
		alias FT  = typeof(field);
		enum name = Identifier!(Test.tupleof[i]); 
		static if(isArray!FT)
		{
			alias ET = typeof(field[0]);
			store.setArrayProperty!ET(Guid.init, name);
			foreach(ref item; field)
				store.appendArrayElement(Guid.init, name, item);
		}
		else 
		{
			store.setProperty(Guid.init, name, field);
		}
	}


	import collections.list;
	char[8096] buf;
	List!char buffer = List!char(buf[]);
	DataStoreContext context;	
	import log, std.stdio;


	try
	{
		toSDL(store, buffer,  &context, 0);
		logInfo(buffer.array);
		
		auto t2 = fromSDLSource!DataStore(GC.cit, cast(string)buffer.array, context);
		buffer.length = 0;
		toSDL(t2, buffer, &context, 0);
		logInfo(buffer.array);


	}
	catch(Throwable t)
	{
		logInfo(t);
	}
	readln;
}
