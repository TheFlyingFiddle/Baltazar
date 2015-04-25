module common.components;

public import math.vector;
public import graphics.color;
public import common.identifiers;
public import common.attributes;
import util.traits;

template id(T...)
{
	enum id = Identifier!T;
}

alias ComponentTypes = Structs!(common.components);
static string[] ComponentIDs = [staticMap!(id, ComponentTypes) ];

struct Transform
{
	float2 position	= float2.zero;
	float2 scale	= float2.one;
	float  rotation	= 0;
}

struct Sprite
{
	Color tint	= Color.white;
	TextureID texture;
}

struct Text
{
	Color color		= Color.black;
	FontID font		= FontID("");
	float2 thresh	= float2(0.25, 0.75);
	string text		= "";
}

struct Bounds
{
	int something;
}