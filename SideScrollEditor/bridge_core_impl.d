module bridge_core_impl;

import bridge.core;
import collections.list;
import reflection;
import allocation;

import util.variant;
import util.hash;
import util.servicelocator;

struct SaveData
{
	VariantN!(64)[] data;
	this(EditorData data)
	{
		this.data = cast(VariantN!64[])data.data.array;
	}
}

class EditorData : IEditorData
{
	IAllocator allocator;
	List!(const(MetaType)*) types;
	List!(VariantN!64) data;

	this(IAllocator all, size_t num)
	{
		this.allocator = all;
		this.data  = List!(VariantN!64)(all, num);
		this.types = List!(const(MetaType)*)(all, num);
	}

	~this()
	{
		clear();
		data.deallocate(allocator);
	}

	void addData(const(MetaType)* dataType)
	{
		types ~= dataType;
		data  ~= dataType.create!64(allocator);
	}

	void addData(const(MetaType)* dataType, ref VariantN!64 data)
	{
		this.types ~= dataType;
		this.data  ~= data;
	}

	void clear()
	{
		foreach(i, ref d; data)
		{
			auto type = types[i];
			auto p    = type.tryBind!(void delegate(IAllocator))(d, "deallocate");
			if(p)
				p(allocator);
		}

		types.clear();
		data.clear();
	}

	override void* locateData(TypeHash hash) nothrow
	{
		scope(failure) return null;

		import std.algorithm;
		auto d = data.find!(x => x.id == hash);
		if(!d.empty)
			return d[0].data.ptr;

		return null;
	}
}

class EditorServiceLocator : IServiceLocator
{
	ServiceLocator* locator;
	this(ServiceLocator* locator)
	{
		this.locator = locator;
	}

	override void* locateService(TypeHash th, string name) nothrow
	{
		return locator.tryFind(th, name);
	}

	override void addService(void* service, TypeHash hash, string name) nothrow
	{
		locator.add(service, hash, name);
	}
}

class Assets : IAssets
{
	import std.algorithm;
	import content;

	struct TypedAssets
	{
		string type;
		List!Asset assets;
	}

	AsyncContentLoader* loader;
	List!(TypedAssets) typed;
	this(IAllocator allocator, AsyncContentLoader* loader)
	{
		import std.path;
		this.loader = loader;
		this.typed = List!TypedAssets(allocator, 15);
		
		auto files = loader.avalibleResources;
		foreach(item; files.dependencies)
		{
			string ext  = item.name.extension[1 .. $];
			string name = item.name.stripExtension;
			auto idx = typed.countUntil!(x => x.type == ext);
			if(idx == -1)
			{
				typed ~= TypedAssets(ext, List!Asset(allocator, 100));
				idx = typed.length - 1;
			}	

			Asset a;
			a.name		= name;
			a.subitems  = List!(string)(allocator, item.deps.length);
			a.subitems ~= item.deps.map!(x => x.stripExtension);

			typed[idx].assets ~= a;
		}

		import log;
		foreach(loaded; typed)
		{
			logInfo("Assets of type: ", loaded.type);
			logInfo(loaded.assets);
		}
	}

	override List!Asset loadedAssets(string type) nothrow
	{
		scope (failure) return List!(Asset).init;

		import std.algorithm;
		return typed.find!(x => x.type == type)[0].assets;
	}

	override void* locateAsset(TypeHash type, string asset) nothrow
	{
		auto a = loader.getItem(asset);
		if(a.typeHash == type)
			return a.item;
		else 
			return null;
	}
}