module entity;

import types;
import collections.list;
import collections.deque;
import collections.map;
import allocation;

enum minFreeIndices = 1024;

alias EntityDestroyedDG = void delegate(Entity);
alias EntityDestroyedFun  = void function(Entity);

struct EntityManager
{
	HashMap!(uint, EntityDestroyedDG) destructors;
	GrowingList!(ubyte)				  generations;
	Deque!uint						  freeIndices;

	this(IAllocator all, size_t initialSize)
	{
		destructors = HashMap!(uint, EntityDestroyedDG)(all);
		generations = GrowingList!(ubyte)(all, initialSize);
		freeIndices = Deque!(uint)(all, minFreeIndices);
	}

	Entity create(EntityDestroyedFun fun)
	{
		import std.functional;
		auto dg = toDelegate(fun);
		return create(dg);
	}

	Entity create(EntityDestroyedDG dg)
	{
		Entity e = create();
		destructors.add(e.index, dg);
		return e;
	}

	Entity create()
	{
		Entity e;
		if(freeIndices.length > minFreeIndices)
		{
			e.index = freeIndices.pop();
		}
		else 
		{
			generations ~= 0;
			e.index = generations.length - 1;
		}

		e.generation = generations[e.index];
		return e;
	}

	bool alive(Entity e)
	{
		return generations[e.index] == e.generation;
	}

	void destroy(Entity e)
	{
		uint idx = e.index;
		if(auto p = idx in destructors)
			(*p)(e);

		++generations[idx];
		freeIndices.push(idx);
	}
}