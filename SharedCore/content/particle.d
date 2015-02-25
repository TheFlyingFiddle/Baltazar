module content.particle;

import allocation;
import particles.system;
struct ParticleLoader
{
	static ParticleSystem* load(IAllocator allocator, string path, bool async)
	{
		import content.sdl;
		import particles.bindings;
		
		auto mem = cast(ParticleSystem*)allocator.allocateRaw(ParticleSystem.sizeof, ParticleSystem.alignof).ptr;
		
		//Can't deallocate this memory. This is a problem.
		*mem =  fromSDLFile!ParticleSystem(allocator, path, ParticleSDLContext());

		mem.particles.allocate(allocator);
		return mem;
	}
 
	static void unload(IAllocator allocator, ParticleSystem* item)
	{
		allocator.deallocate(item);
	}
}