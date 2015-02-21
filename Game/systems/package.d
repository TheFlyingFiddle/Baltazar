module systems;

import systems.box2d;
import systems.systems;

import framework.core;
import rendering.combined;
import particles.system;


template filter(T...) if(T.length == 1)
{
	import std.typetuple;
	import util.traits;
	import framework.entity;

	enum result = hasValueAttribute!(T[0], EntitySystem) || 
				  hasValueAttribute!(T[0], EntityInitializer);

	enum filter = result;
}

import reflection;
mixin GenerateMetaData!(filter,
						systems.box2d,
  					    systems.systems);