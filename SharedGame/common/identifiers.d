module common.identifiers;

struct TextureID
{
	string name;
}

struct FontID
{
	string name;
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