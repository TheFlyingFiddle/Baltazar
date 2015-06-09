module pluginshared.components;

import pluginshared.componentmeta;
public import pluginshared.types;
public import math.vector;
public import graphics.color : Color;

@Component struct Transform 
{
	float2 position	= float2.zero;
	float2 scale	= float2.one;
	float  rotation	= 0;
}

@Component struct Sprite
{
	Color tint	= Color.white;
	TextureID texture;
}

@Component struct Text
{
	Color color		= Color.black;
	FontID font		= FontID("");
	float2 thresh	= float2(0.25, 0.75);
	string text		= "";
}

@Component struct Bounds
{
	int something;
}

mixin ComponentBindings!(pluginshared.components);