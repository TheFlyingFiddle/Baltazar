module common.identifiers;

struct TextureID
{
	string atlas;
	string image;
}

struct FontID
{
	string atlas;
	string font;
}

struct ArchetypeID
{
	string name;
}

struct ParticleID
{
	string name;
}

struct EntityRef
{
	uint id;
}

struct ComponentID(T)
{
	uint entityID;
}