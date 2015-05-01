module types;

import std.bitmanip;
import util.hash;

public import math.vector;
public import graphics.color;

struct Entity
{
	//EntityStuff here
	mixin(bitfields!(
		  uint, "index", 24,
		  uint, "generation",   8));
}


struct Transform
{
	float2 position;
	float2 scale;
}

struct TextureID
{
	HashID atlas;
	HashID image;
}