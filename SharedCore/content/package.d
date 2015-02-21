module content;

public import content.content;
public import content.textureatlas;
public import content.sdl;
public import content.font;
public import content.texture;
public import content.particle;
public import content.sound;


import allocation, graphics.font, graphics.textureatlas;
import graphics.frame;
import particles.system;
import sound;

alias FontHandle     = ContentHandle!FontAtlas;
alias AtlasHandle    = ContentHandle!TextureAtlas;
alias FrameHandle    = ContentHandle!Frame;
alias ParticleHandle = ContentHandle!ParticleSystem;
alias SoundHandle    = ContentHandle!Sound;

ContentLoader createStandardLoader(A)(ref A allocator, IAllocator itemAllocator,
									  size_t maxResources, string resourceFolder)
{
	auto c = ContentLoader(allocator, itemAllocator, maxResources, resourceFolder);
	
	//As time goes by we change this.
	c.addFileLoader(makeLoader!(TextureAtlasLoader, ".atl"));
	c.addFileLoader(makeLoader!(FontLoader, ".fnt"));
	c.addFileLoader(makeLoader!(FrameLoader, ".png"));
	c.addFileLoader(makeLoader!(ParticleLoader, ".psys"));
	c.addFileLoader(makeLoader!(SoundLoader, ".wav"));

	return c;
}