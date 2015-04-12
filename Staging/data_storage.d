module data_storage;

import std.uuid;
import util.variant;
import collections.list;
import collections.map;
import allocation;



alias Guid = UUID;
alias Data = VariantN!20; //Big enough to fit any simple data. This includes GUIDs arrays etc.

struct DataStore
{
	HashMap!(Guid, HashMap!(string, Data)) data;
	this(IAllocator allocator)
	{
		data = HashMap!(Guid, HashMap!(string, Data))(allocator);
		data.add(Guid.init, HashMap!(string, Data)(allocator));
	}

	void deallocate()
	{
		foreach(ref k, ref v; data)
		{
			v.deallocate();
		}

		data.deallocate();
	}

	bool create(Guid guid)
	{
		return data.tryAdd(guid, HashMap!(string, Data)(data.allocator)) !is null;
	}

	bool destroy(Guid guid)
	{
		return data.remove(guid);
	}

	bool exists(Guid guid)
	{
		return data.has(guid);
	}

	bool hasProperty(Guid guid, string key)
	{
		return data[guid].has(key);
	}

	T getProperty(T)(Guid guid, string key)
	{
		auto map = data[guid];
		auto p   = map[key];

		return p.get!(T);
	}

	bool removeProperty(Guid guid, string key)
	{
		auto map = &data[guid];
		return map.remove(key); 
	}

	void setProperty(T)(Guid guid, string key, T t)
	{
		auto map = &data[guid];
		Data* p = key in *map;
		if(!p)
			p = map.add(key, Data());

		*p = t;
	}

	//Need to be fixed so that they use List / GrowingList instead!
	void addToSet(Guid guid, string key, Guid item)
	{
		auto map = &data[guid];
		Data* p = key in *map;
		if(!p)
		{
			Guid[] guids;
			p = map.add(key, Data(guids));
		}
		//Uses the gc... 
		auto guids = p.peek!(Guid[]);
		*guids ~= item;
	}

	void removeFromSet(Guid guid, string key, Guid item)
	{
		auto map = &data[guid];
		Data* p = key in *map;
		if(!p)
			return;

		auto guids = p.peek!(Guid[]);

		import std.algorithm;
		auto idx = (*guids).countUntil!(x => x == item);
		if(idx == -1) return;

		*guids = (*guids).remove(idx);
	}
}

enum CmdTag : byte
{
	create = 0,
	destroy,
	setProp,
	removeProp,
	addSet,
	removeSet

}

struct Command
{
	CmdTag tag;
	Guid guid;
	union
	{
		HashMap!(string, Data) values;
		struct 
		{
			string key;
			union
			{
				Guid   itemGuid;
				Data   data;
			}
		}	
	}

	this(CmdTag tag, Guid guid)
	{
		this.tag  = tag;
		this.guid = guid;
	}
}

struct EditorState
{
	private GrowingList!(Command) undoCmds;
	private GrowingList!(Command) redoCmds;
	private GrowingList!(uint)	  restorepoints;
	private uint restoreIdx;
	private uint cmdSinceRestore;
	
	private DataStore store;
	this(IAllocator allocator)
	{
		store			= DataStore(allocator);
		undoCmds		= GrowingList!(Command)(allocator, 1000);
		redoCmds		= GrowingList!(Command)(allocator, 1000);
		restorepoints	= GrowingList!(uint)(allocator, 100); 

	
		restoreIdx	    = 0;
		cmdSinceRestore = 0;
	}
		
	void deallocate()
	{
		undoCmds.deallocate();
		redoCmds.deallocate();
		restorepoints.deallocate();
		store.deallocate();
	}

	bool exists(Guid guid)
	{
		return store.exists(guid);
	}

	bool exists(Guid guid, string key)
	{
		return store.hasProperty(guid, key);
	}

	Guid createObject()
	{
		//Will be unique!
		auto guid = randomUUID();
		create(guid);
		return guid;
	}

	bool create(Guid guid)
	{
		auto res = store.create(guid);
		if(res)
			addCmd(Command(CmdTag.destroy, guid));
		
		return res;
	}

	bool destroy(Guid guid)
	{
		if(store.exists(guid))
		{
			auto cmd = Command(CmdTag.create, guid);
			cmd.values = store.data[guid];
			addCmd(cmd);

			return store.destroy(guid);
		}

		return false;
	}

	T getProperty(T)(Guid guid, string key)
	{
		return store.getProperty!(T)(guid, key);
	}

	bool removeProperty(Guid guid, string key)
	{
		if(store.hasProperty(guid, key))
		{
			auto cmd = Command(CmdTag.setProp, guid);
			cmd.key  = key;
			cmd.data = store.data[guid][key];
			addCmd(cmd);

			return store.removeProperty(guid, key);
		}

		return false;
	}

	void setProperty(T)(Guid guid, string key, T t)
	{
		if(store.hasProperty(guid, key))
		{
			auto cmd = Command(CmdTag.setProp, guid);
			cmd.key  = key;
			cmd.data = store.data[guid][key];
			addCmd(cmd);
		}
		else 
		{
			auto cmd = Command(CmdTag.removeProp, guid);
			cmd.key  = key;
			addCmd(cmd);
		}

		store.setProperty(guid, key, t);
	}

	void addToSet(Guid guid, string key, Guid item)
	{
		auto cmd = Command(CmdTag.removeSet, guid);
		cmd.key  = key;
		cmd.itemGuid = item;
		addCmd(cmd);

		store.addToSet(guid, key, item);
	}

	void removeFromSet(Guid guid, string key, Guid item)
	{
		auto cmd = Command(CmdTag.removeSet, guid);
		cmd.key  = key;
		cmd.itemGuid = item;
		addCmd(cmd);

		store.removeFromSet(guid, key, item);
	}

	private void addCmd(Command command)
	{
		cleanMemory();
		undoCmds ~= command;
		cmdSinceRestore++;
	}

	private void cleanMemory()
	{
		foreach(ref cmd; redoCmds)
		{
			if(cmd.tag == CmdTag.create)
			{
				cmd.values.deallocate();
			}	
		}

		if(redoCmds.length != 0)
		{
			redoCmds.length = 0;
			restorepoints.length = restoreIdx + 1;
		}
	}

	private void excecute(Command command, ref GrowingList!Command stack)
	{
		Command inverse;

		final switch(command.tag)
		{
			case CmdTag.create: 
				inverse = Command(CmdTag.destroy, command.guid);

				store.data.add(command.guid, command.values);
				break;
			case CmdTag.destroy: 
				inverse = Command(CmdTag.create, command.guid);
				inverse.values = store.data[command.guid];

				store.destroy(command.guid);
				break;
			case CmdTag.addSet:
				inverse = Command(CmdTag.removeSet, command.guid);
				inverse.key  = command.key;
				inverse.itemGuid = command.itemGuid;

				store.addToSet(command.guid, command.key, command.itemGuid);
				break;
			case CmdTag.removeSet: 
				inverse = Command(CmdTag.addSet, command.guid);
				inverse.key  = command.key;
				inverse.itemGuid = command.itemGuid;

				store.removeFromSet(command.guid, command.key, command.itemGuid);
				break;
			case CmdTag.setProp: 
				if(store.hasProperty(command.guid, command.key))
				{
					inverse = Command(CmdTag.setProp, command.guid);
					inverse.key  = command.key;
					inverse.data = store.data[command.guid][command.key];
				}
				else 
				{
					inverse = Command(CmdTag.removeProp, command.guid);
					inverse.key  = command.key;
				}
				
				store.setProperty(command.guid, command.key, command.data);
				break;
			case CmdTag.removeProp: 
				inverse = Command(CmdTag.setProp, command.guid);
				inverse.key  = command.key;
				inverse.data = store.data[command.guid][command.key];

				store.removeProperty(command.guid, command.key);
				break;
		}

		stack ~= inverse;
	}

	void undo()
	{
		if(restoreIdx == -1) return;

		if(cmdSinceRestore != 0)
			setRestorePoint();

		foreach(i; 0 .. restorepoints[restoreIdx])
		{
			excecute(undoCmds[$ - i - 1], redoCmds);
		}

		undoCmds.length -= restorepoints[restoreIdx--];
	}

	void redo()
	{
		if(restoreIdx == restorepoints.length - 1) return;

		foreach(i; 0 .. restorepoints[++restoreIdx])
		{
			excecute(redoCmds[$ - i - 1], undoCmds);
		}

		redoCmds.length -= restorepoints[restoreIdx];
	}

	void setRestorePoint()
	{
		restorepoints ~= cmdSinceRestore;
		restoreIdx	  = restorepoints.length - 1;

		cmdSinceRestore = 0;
	}

	//Proxy
	auto proxy(T)(Guid guid) if(is(T == struct))
	{
		return EditorStateProxy!(T)(guid, &this);
	}
}


struct EditorStateProxy(T, string s = "")
{
	private Guid __guid;
	private EditorState* __state;

	mixin(fields());

	this(Guid __guid, EditorState* __state)
	{
		this.__guid  = __guid;
		this.__state = __state;
	}

	this(Guid __guid, EditorState* __state, T t)
	{
		this.__guid  = __guid;
		this.__state = __state;

		foreach(i, ref field; t.tupleof)
		{
			enum name = T.tupleof[i].stringof;
			mixin("this." ~ name ~ " = field;");
		}
	}

	bool opEquals(ref const T other)
	{
		return get == other;
	}


	bool opEquals(const T other)
	{
		return get == other;
	}

	T get()
	{
		T t;
		foreach(i, ref field; t.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);
			enum name = T.tupleof[i].stringof;
			static if(FT.sizeof <= 16)
				mixin("field = this." ~ T.tupleof[i].stringof ~ ";");
			else 
				mixin("field = this." ~ T.tupleof[i].stringof ~ ".get;");
		}

		return t;
	}

	private static string fields()
	{
		import std.conv;
		string str = "";
		foreach(i, dummy; T.init.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);
			enum name = T.tupleof[i].stringof;
			enum type = typeof(T.tupleof[i]).stringof;
			static if(FT.sizeof <= 16)
			{
			
				str ~= 
"
@property void " ~ name ~ "(" ~ type ~ " value)
{
	__state.setProperty!(" ~ type ~ ")(__guid, \"" ~ name ~ "\", value);
}

@property " ~ type ~ " " ~ name ~ "()
{
	if(__state.exists(__guid, \"" ~ name ~ "\"))
		return __state.getProperty!(" ~ type ~ ")(__guid, \"" ~ name ~ "\");				
	return T.init.tupleof[" ~ i.to!string ~ "];
}
";
			}
			else 
			{
				enum ptype = "EditorStateProxy!(" ~ typeof(T.tupleof[i]).stringof ~ ", \"" ~ s ~ name ~ "_\")";
				str ~= 
"
@property void " ~ name ~ "(" ~ type ~ " value)
{
	" ~ ptype ~ "(__guid, __state, value);
}

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




unittest
{
	auto guid = randomUUID();

	EditorState state = EditorState(Mallocator.cit);
	scope (exit) state.deallocate();
	assert(!state.exists(guid));
	state.create(guid);
	assert(state.exists(guid));

	state.setRestorePoint();

	assert(!state.exists(guid, "Test"));
	state.setProperty(guid, "Test", 123456);
	assert(state.getProperty!int(guid, "Test") == 123456);
	
	state.undo();
	assert(!state.exists(guid, "Test"));

	state.redo();
	assert(state.getProperty!int(guid, "Test") == 123456);

	state.undo();
	assert(!state.exists(guid, "Test"));

	state.redo();
	assert(state.getProperty!int(guid, "Test") == 123456);

	state.undo();
	state.undo();
	assert(!state.exists(guid));
	state.redo();
	assert(state.exists(guid));
	assert(!state.exists(guid, "Test"));
	state.redo();
	assert(state.getProperty!int(guid, "Test") == 123456);
}

unittest
{
	EditorState state = EditorState(Mallocator.cit);
	scope (exit) state.deallocate();

	assert(state.exists(Guid.init));
	state.setProperty(Guid.init, "RootInt", 123456);
	assert(state.getProperty!int(Guid.init, "RootInt") == 123456);
}


//Gonna test object functions!
import math.vector;
struct Transform
{
	float2 position = float2.zero;
	float2 scale	= float2.zero;
	float  rotation = 0;
}

unittest
{
	EditorState state = EditorState(Mallocator.cit);
	scope(exit) state.deallocate();

	auto guid  = state.createObject();
	auto proxy = state.proxy!(Transform)(guid);

	assert(proxy.position == float2.zero);
	assert(proxy.scale == float2.zero);
	assert(proxy.rotation == 0);

	proxy.position = float2(123, 456);
	assert(proxy.position == float2(123, 456));
	assert(state.getProperty!(float2)(guid, "position") == proxy.position);
}

struct Problems
{
	Transform test;
	int dummy = 3;
}

unittest
{
	EditorState state = EditorState(Mallocator.cit);
	scope(exit) state.deallocate();

	auto guid  = state.createObject();
	auto proxy = state.proxy!(Problems)(guid);

	assert(proxy.test == Transform.init);

	auto t = Transform(float2.one, float2.one, 3);
	proxy.test = t;
	assert(proxy.test == t);

	proxy.test.position = float2(123, 456);
	assert(proxy.test.position == float2(123, 456));
}