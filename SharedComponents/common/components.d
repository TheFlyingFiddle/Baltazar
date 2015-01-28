module common.components;

import common;
import window.gamepad;
import util.traits;
import ui.reflection;

struct Transform
{
	float2 position;
	float2 scale;
	@Optional(0.0f) float  rotation;

	static Transform ident()
	{
		return Transform(float2.zero, float2.one, 0);
	}
}

struct Sprite
{
	Color tint;
	@FromItems("images") string name;

	static Sprite ident()
	{
		return Sprite(Color.white);
	}
}

struct Font
{
	Color color;
	string text;
	@FromItems("fonts") string font;
}

enum PhysType
{
	static_,
	dynamic,
	kinematic,
	sensor
}

struct Physics
{
	float friction;
	float density;
	float bouncyness;
	float damping;
	float gravity;

	float2 velocity;
	PhysType type;

	static Physics ident()
	{
		return Physics(0.0f, 1.0f, 0.0f,  0.0f, 1.0f, float2.zero, PhysType.static_);
	}
}



struct Chain
{
	static Chain ident()
	{
		Chain c;
		c.vertices = GrowingList!(float2)(Mallocator.cit, 10);
		return c;
	}

	@Convert!(listToGrowing) GrowingList!float2 vertices;

	Chain clone()
	{
		Chain c;
		c.vertices = GrowingList!(float2)(Mallocator.cit, this.vertices.capacity);
		c.vertices ~= this.vertices.array;

		return c;
	}
}