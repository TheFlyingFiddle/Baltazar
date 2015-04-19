module bridge.core;

import bridge.attributes;
import util.hash;
import util.variant;
import collections.list;
import collections.map;

import reflection;

@DontReflect
interface IServiceLocator
{
	void addService(void*, TypeHash, string) nothrow;
	void* locateService(TypeHash, string) nothrow;

	final void add(T)(T* service, string s = "") nothrow if(is(T == struct))
	{
		addService(cast(void*)service, typeHash!T, s);
	}

	final T* locate(T)(string s ="") nothrow if(is(T == struct))
	{
		return cast(T*)locateService(typeHash!T, s);
	}

	final void add(T)(T service, string s = "") nothrow if(is(T == class) || is(T == interface))
	{
		addService(cast(void*)service, typeHash!T, s);
	}

	final T locate(T)(string s ="") nothrow if(is(T == class) || is(T == interface))
	{
		return cast(T)locateService(typeHash!T, s);
	}

}

template isData(T)
{
	import util.traits;
	enum isData = util.traits.hasAttribute!(T, Data);
}

@DontReflect
interface IAssets
{
	void* locateAsset(TypeHash type, string asset) nothrow;
	List!Asset loadedAssets(string type) nothrow;
	
	final T* locate(T)(string item) nothrow
	{
		return cast(T*)locateAsset(typeHash!T, item);
	}
}

@DontReflect
struct Asset
{
	string   name;
	List!string subitems;
}	

@DontReflect
interface IEditor
{
	nothrow void create();
	nothrow void open(string path);
	nothrow void save(string path);
	nothrow void runGame();
	nothrow void close();

	nothrow IServiceLocator	services();
	nothrow IAssets			assets();
	nothrow IEditorState	state();
}

@DontReflect
interface IFileFinder
{
	string findOpenProjectPath() nothrow;
	string openProjectPath() nothrow;

	string findSaveProjectPath() nothrow;
	string saveProjectPath() nothrow;
}

alias Guid = ulong;
alias Data = VariantN!12; //Big enough to fit any simple data. This includes GUIDs arrays etc.

@DontReflect
interface IEditorState
{
	void setPropertyTyped(Guid guid, string key, Data data) nothrow;
	Data* getPropertyTyped(Guid guid, string key) nothrow;

	bool exists(Guid guid) nothrow;
	bool exists(Guid guid, string key) nothrow;
	HashMap!(string, Data) object(Guid guid) nothrow;
	Guid createObject() nothrow;
	bool create(Guid guid) nothrow;
	bool destroy(Guid guid) nothrow;
	bool removeProperty(Guid guid, string key) nothrow;
	void addToSet(Guid guid, string key, Guid item) nothrow;
	void removeFromSet(Guid guid, string key, Guid item) nothrow;

	void setProperty(T)(Guid guid, string key, T t)
	{
		setPropertyTyped(guid, key, Data(t));
	}
	T* getProperty(T)(Guid guid, string key)
	{
		auto dat = getPropertyTyped(guid, key);
		if(!dat) return null;
		return dat.peek!T;
	}

	
	

	void undo();
	void redo();
	void setRestorePoint();

	auto proxy(T)(Guid guid) 
	{
		import math.vector;
		static if(is(T == float2))
			enum s = "float2";
		else 
			enum s = T.stringof;

		return EditorStateProxy!(T, s ~ "_")(guid, this);
	}
}

@DontReflect
struct EditorStateProxy(T, string s = "")
{
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
			enum pname = s ~ name;
			static if(FT.sizeof <= 8)
				__state.removeProperty(__guid, pname);
			else 
				EditorStateProxy!(FT, pname ~ "_")(__guid, __state).removeFields();
		}
	}

	void set(T t)
	{
		foreach(i, ref field; t.tupleof)
		{
			enum name = T.tupleof[i].stringof;
			mixin("this." ~ name ~ " = field;");
		}
	}

	T get()
	{
		T t;
		foreach(i, ref field; t.tupleof)
		{
			alias FT = typeof(T.tupleof[i]);
			enum name = T.tupleof[i].stringof;
			static if(FT.sizeof <= 8)
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
			enum pname = s ~ name;
			enum type = typeof(T.tupleof[i]).stringof;
			static if(FT.sizeof <= 8)
			{

				str ~= 
					"
					@property void " ~ name ~ "(" ~ type ~ " value)
					{
					__state.setProperty!(" ~ type ~ ")(__guid, \"" ~ pname ~ "\", value);
					}

					@property " ~ type ~ " " ~ name ~ "()
					{
					auto p = __state.getProperty!(" ~ type ~ ")(__guid, \"" ~ pname ~ "\");
					if(p) return *p;				
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


@DontReflect
struct Editor
{
	private __gshared static IEditor	editor;

	static void create()
	{
		editor.create();
	}

	static void open(string path)
	{
		editor.open(path);
	}

	static void save(string path)
	{
		editor.save(path);
	}

	static void runGame()
	{
		editor.runGame();
	}

	static void close()
	{
		editor.close();
	}

	static IEditorState state() nothrow
	{
		return editor.state;	
	}

	static IAssets assets() nothrow
	{
		return editor.assets;
	}

	static IServiceLocator services() nothrow
	{
		return editor.services;
	}
}

void setupEditorConnection(IEditor editor) nothrow
{
	import log;
	logInfo("Setup called!");
	Editor.editor		   = editor;
}

__gshared static this()
{
	genFunction!(setupEditorConnection)();
}