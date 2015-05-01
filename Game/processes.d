module processes;

import types;
import soa;
import collections.list;
import allocation;
import rendering;
import rendering.combined;
import graphics.textureatlas;

//For now.
struct Sprite
{
	Transform	transform; //It could be that this should not be here.
	Color		color;
	TextureID	texture; //Cold as hell outside of the renderer.
}

//Processes - Transform - Renderer - Input - Physics/Collision?
struct SpriteRenderer
{
	struct TextureIndex
	{
		ushort atlas;
		ushort image;

		this(size_t atl, size_t img)
		{
			atlas = cast(ushort)atl;
			image = cast(ushort)img;
		}
	}

	struct SpriteRep
	{
		Entity			owner;
		Transform		transform;
		Color			color;
		TextureIndex	texture;
	}

	import content;
	List!AtlasHandle atlases;
	SOA!SpriteRep sprites;
	size_t	   length;

	void addSprite(Entity e, Sprite s)
	{	
		SpriteRep rep;
		rep.owner		  = e;
		rep.transform	  = s.transform;
		rep.color		  = s.color;
		rep.texture		  = indexed(s.texture);
		sprites[length++] = rep;
	}

	TextureIndex indexed(TextureID id)
	{
		foreach(i, atlas; atlases)
		{
			if(atlas.resourceID == id.atlas)
			{
				return TextureIndex(i, atlas.asset.idToIndex(id.image));
			}
		}

		assert(0, "Image does not exist!"); //Could also use default image.
	}

	void render(Renderer2D* renderer)
	{
		foreach(i; 0 .. length)
		{
			auto trans = sprites.transform[i];
			auto color = sprites.color[i];
			auto tex   = sprites.texture[i];
			auto frame = atlases[tex.atlas].asset[tex.image];

			float2 min = trans.position - trans.scale;
			float2 max = trans.position + trans.scale;
			renderer.drawQuad(float4(min.x, min.y, max.x, max.y), 0, frame, color);
		}
	}

}


