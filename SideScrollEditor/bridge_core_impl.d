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

	override void* locateService(TypeHash th, string name) 
	{
		return locator.tryFind(th, name);
	}

	override void addService(void* service, TypeHash hash, string name) 
	{
		locator.add(service, hash, name);
	}
}

class Assets : IAssets
{
	void* locateAsset(TypeHash type, HashID asset)
	{
		//No assets yet!
		return null;
	}
}