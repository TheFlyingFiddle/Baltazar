module common.components;

import math.vector;
import graphics.color;
import window.gamepad;
import common.identifiers;
import common.attributes;

@EntityComponent struct Transform
{
	float2 position	= float2.zero;
	float2 scale	= float2.one;
	float  rotation	= 0;
}

@EntityComponent struct Sprite
{
	Color tint			= Color.white;
	TextureID texture;
}

@EntityComponent struct Text
{
	Color color		= Color.black;
	FontID font		= FontID("");
	float2 thresh	= float2(0.25, 0.75);
	string text		= "";
}

@EntityComponent struct Input
{
	PlayerIndex gamepad		 = PlayerIndex.zero;
	string jumpSpeed		 = "Hello World";
	string walkSpeed		 = "Dance Monkey Dance!";
}

@EntityComponent struct Fan
{
	float force		= 0;
	float effect	= 0;
	bool active		= false;
}

@EntityComponent struct Switch
{
	EntityRef fan;
}	

@EntityComponent struct Elevator
{
	float interval		= 0;
	float sleep			= 0;
	float2 direction	= float2.zero;
	bool active			= false;
	float elapsed		= 0;
}

@EntityComponent struct PressurePlate
{
	EntityRef elev;
}

@EntityComponent struct Door
{
	int moreOpen;
	bool open;
	TextureID openImage;
	TextureID closedImage;
}

@EntityComponent struct ParticleEffect
{
	ParticleID id;
	bool active;
}

@EntityComponent struct Weapon
{
	ArchetypeID bulletID;
}

@EntityComponent struct Physics
{
	float friction		= 0.0f;
	float density		= 1.0f;
	float bouncyness	= 0.0f;
	float damping		= 0.0f;
	float gravity		= 1.0f;
	bool rotation		= false;

	float2 velocity		= float2.zero;
	PhysType type		= PhysType.static_;
}

enum PhysType
{
	static_,
	dynamic,
	kinematic,
	sensor
}