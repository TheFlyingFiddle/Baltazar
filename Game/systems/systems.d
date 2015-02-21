module systems.systems;

import math.vector;
import allocation;
import framework;
import dbox;

import common.components;
import components.box2D;
import collections.list;

alias Entities = List!Entity;

@EntitySystem(1)
struct SpriteSystem
{
	import rendering.combined, content;
	import rendering.shapes;
	import graphics;

	Renderer2D* renderer;
	AtlasHandle atlas;

	bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!(Transform) &&
			e.hasComp!(Sprite);
	}

	void initialize(IAllocator allocator, World* world)
	{
		import content;
		auto loader = world.app.locate!(AsyncContentLoader);
		atlas = loader.load!(TextureAtlas)("Atlas");

		renderer = world.app.locate!(Renderer2D);
	}

	void postStep(Time time, Entities entities, World* world)
	{
		foreach(ref e; entities)
		{
			auto trans  = e.getComp!(Transform);
			auto sprite = e.getComp!(Sprite);
			auto frame  = atlas[sprite.texture.name];

			float2 min = trans.position - trans.scale / 2;
			float2 max = trans.position + trans.scale / 2;

			min *= 64;
			max *= 64;

			renderer.drawQuad(float4(min.x, min.y, max.x, max.y), trans.rotation, frame, sprite.tint); 
		}
	}
}

@EntitySystem(1)
struct InputSystem
{
	import window.gamepad;
	GamePad* pad;
	b2World* bworld;

	void initialize(IAllocator allocator, World* world)
	{
		pad = world.app.locate!GamePad;
		bworld = world.app.locate!(b2World);
	}

	bool shouldAddEntity(ref Entity entity) 
	{
		return entity.hasComp!Input && entity.hasComp!Box2DPhysics;
	}

	void preStep(Time time, Entities entities, World* world)
	{
		foreach(e; entities)
		{
			auto input     = e.getComp!Input;
			auto phys	   = e.getComp!Box2DPhysics;

			if(pad.isActive(input.gamepad))
			{
				float2 leftThumb = pad.leftThumb(input.gamepad);
				phys.velocity = float2(leftThumb.x * input.walkSpeed, phys.velocity.y);

				if(pad.wasPressed(input.gamepad, GamePadButton.a))
				{
					if(hasGroundContact(e))
					{
						phys.velocity = float2(phys.velocity.x, input.jumpSpeed);
					}
				}
			}
		}
	}

	bool hasGroundContact(ref Entity e)
	{
		for(auto contact = bworld.GetContactList(); contact; contact = contact.GetNext())
		{
			auto fixA = contact.GetFixtureA();
			auto fixB = contact.GetFixtureB();

			auto bodyA = fixA.GetBody();
			auto bodyB = fixB.GetBody();

			if(cast(int)fixA.GetUserData() == e.id)
			{
				if(cast(int)bodyB.GetUserData() == e.id)
					continue;
				else if(contact.IsTouching())
					return true;
			}

			if(cast(int)fixB.GetUserData() == e.id)
			{
				if(cast(int)bodyA.GetUserData() == e.id)
					continue;
				else if(contact.IsTouching())
					return true;
			}
		}

		return false;
	}
}

@EntitySystem(1)
struct WeaponSystem
{
	import window.gamepad;
	GamePad* pad;
	void initialize(IAllocator allocator, World* world)
	{
		pad = world.app.locate!GamePad;
	}

	bool shouldAddEntity(ref Entity entity)
	{
		return entity.hasComp!(Input) && 
			   entity.hasComp!(Weapon) && 
			   entity.hasComp!(Transform);
	}

	void preStep(Time time, Entities entities, World* world)
	{
		foreach(e; entities)
		{
			auto input		   = e.getComp!Input;
			auto weapon		   = e.getComp!Weapon;
			auto transform	   = e.getComp!Transform;

			if(pad.isActive(input.gamepad))
			{
				if(pad.wasPressed(input.gamepad, GamePadButton.b))
				{
					shoot(world, transform, weapon);
				}
			}
		}
	}
	
	void shoot(World* world, Transform* trans, Weapon* weapon)
	{
		import std.algorithm;
		auto archetypes = world.app.locate!(List!EntityArchetype);
		auto arch		= (*archetypes).find!(x => x.name == weapon.bulletID.name)[0];
		auto entity		= world.entities.create(arch);
		
		if(entity.hasComp!(Transform))
		{
			auto t = entity.getComp!Transform;
			t.position = trans.position + float2(trans.scale.x, 0);
		}
		else 
		{
			assert(0, "Bullet must have a position!!!");
		}


		world.addEntity(*entity);
	}
}



@EntitySystem(1)
struct FanSystem
{
	b2World* bworld;
	bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!(Fan) && e.hasComp!(Transform);
	}

	void initialize(IAllocator allocator, World* world)
	{
		bworld = world.app.locate!(b2World);
	}	

	void step(Time time, Entities entities, World* world)
	{
		foreach(ref e; entities)
		{
			auto trans = e.getComp!(Transform);
			auto fan   = e.getComp!(Fan);

			if(!fan.active) continue;

			bool queryCallback(b2Fixture* fixture)
			{
				import math, math.polar;

				auto b = fixture.GetBody();
				auto dist = b.GetPosition().y - trans.position.y;

				auto scale = (fan.effect - dist) / fan.effect;
				if(scale < 0) return true;

				auto polar = Polarf(trans.rotation + TAU / 4, fan.force * scale);
				b.ApplyForce(cast(b2Vec2)polar.toCartesian, b.GetPosition(), true);

				return true;
			}


			b2AABB aabb;
			aabb.lowerBound = cast(b2Vec2)(trans.position + float2(-trans.scale.x /2, 0));
			aabb.upperBound = cast(b2Vec2)(trans.position + float2(trans.scale.x / 2, fan.effect));
			bworld.QueryAABB(&queryCallback, aabb);
		}
	}
}

@EntityInitializer(1)
struct SwitchInitializer 
{
	World* world;

	void initialize(IAllocator allocator, World* world)
	{
		this.world = world;
	}

	bool shouldInitializeEntity(ref Entity e)
	{
		return e.hasComp!(Switch) && e.hasComp!(Box2DPhysics);
	}

	void initializeEntity(ref Entity e)
	{
		auto bp = e.getComp!(Box2DPhysics);
		bp.onCollision = &onCollision;
	}

	void onCollision(Entity* this_, Entity* other)
	{
		auto sw = this_.getComp!(Switch);
		foreach(ref e; world.entities)
		{
			if(e.hasComp!(Fan) && e.uniqueID == sw.fan.entityID)
			{
				auto fan = e.getComp!(Fan);
				fan.active = !fan.active;
			}
		}
	}
}

@EntitySystem(1)
struct ElevatorSystem
{
	bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!(Box2DPhysics) &&
			e.hasComp!(Elevator); 
	}

	void step(Time time, Entities entities, World* world)
	{
		foreach(ref e; entities)
		{
			auto elev  = e.getComp!(Elevator);
			auto phys  = e.getComp!(Box2DPhysics);

			if(!elev.active) 
			{
				phys.velocity = float2.zero;
				continue;
			}

			float2 moveVel = float2.zero;
			elev.elapsed += time.deltaSec;
			if(elev.elapsed >= (elev.interval + elev.sleep) * 2)
				elev.elapsed -= (elev.interval + elev.sleep) * 2;

			if(elev.elapsed < elev.sleep || 
			   (elev.elapsed > elev.interval + elev.sleep &&
			    elev.elapsed < elev.interval + elev.sleep * 2))
			{
				moveVel = float2.zero;
			}
			else if(elev.elapsed > elev.sleep && elev.elapsed < elev.sleep + elev.interval)
			{
				moveVel = elev.direction / elev.interval;
			}
			else 
			{
				moveVel = -elev.direction / elev.interval;
			}

			phys.velocity = moveVel;
		}
	}
}

@EntitySystem(1)
struct PressurePlateSystem
{
	bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!(PressurePlate) && 
			e.hasComp!(Transform);
	}

	b2World* bworld;
	void initialize(IAllocator allocator, World* world)
	{
		bworld = world.app.locate!(b2World);
	}	

	void step(Time time, Entities entities, World* world)
	{
		foreach(ref e; entities)
		{
			auto trans  = e.getComp!(Transform);
			auto plate  = e.getComp!(PressurePlate);

			bool isDown = false;
			bool queryCallback(b2Fixture* fixture)
			{
				import math, math.polar;
				isDown = true;
				return false;
			}

			b2AABB aabb;
			aabb.lowerBound = cast(b2Vec2)(trans.position - trans.scale / 2);
			aabb.upperBound = cast(b2Vec2)(trans.position + trans.scale / 2);
			bworld.QueryAABB(&queryCallback, aabb);

			import log;
			logInfo(isDown);

			foreach(ref other; world.entities)
			{
				if(other.uniqueID == plate.elev.id)
				{
					if(other.hasComp!(Elevator))
					{
						auto elevator = other.getComp!(Elevator);
						elevator.active = isDown;
					}

					if(other.hasComp!(Fan))
					{
						auto fan = other.getComp!(Fan);
						fan.active = isDown;
					}

					if(other.hasComp!(Door))
					{
						auto door = other.getComp!(Door);
						door.open = !isDown;
					}
				}
			}
		}
	}
}

@EntitySystem(1)
struct DoorSystem
{
	bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!(Door) && 
			e.hasComp!(Sprite) &&
			e.hasComp!(Box2DPhysics);
	}

	b2World* bworld;
	void initialize(IAllocator allocator, World* world)
	{
		bworld = world.app.locate!(b2World);
	}	

	void step(Time time, Entities entities, World* world)
	{
		foreach(ref e; entities)
		{
			auto door   = e.getComp!(Door);
			auto sprite = e.getComp!(Sprite);
			auto phys   = e.getComp!(Box2DPhysics);


			sprite.texture = door.open ? door.openImage : door.closedImage;
			phys.bodyType  = door.open ? PhysType.static_ : PhysType.sensor;
		}
	}
}

@EntitySystem(1)
struct ParticleEffectSystem
{
	import content;
	import particles;
	import rendering;
	import rendering.combined;
	import graphics;
	import particles.bindings;

	Renderer2D*     renderer;
	AtlasHandle	   atlas;
	ParticleHandle particle;

	void initialize(IAllocator allocator, World* world)
	{

		renderer = world.app.locate!Renderer2D;
		auto loader = world.app.locate!AsyncContentLoader;
		atlas		= loader.load!TextureAtlas("Atlas");

		particle = loader.load!ParticleSystem("particlesystem0");

	}

	bool shouldAddEntity(ref Entity entity) 
	{
		return entity.hasComp!(ParticleEffect) && entity.hasComp!(Transform);
	}

	void preStep(Time time, Entities entities, World* world)
	{
		foreach(e; entities)
		{
			auto t  = e.getComp!Transform;
			auto em = e.getComp!ParticleEffect;

			if(!em.active) continue;

			particle.variable!(Origin)(t.position);
			particle.update(time.deltaSec);
		}
	}

	void postStep(Time time)
	{
		auto pos = particle.particles.variable!(PosVar);
		auto col = particle.particles.variable!(ColorVar);

		foreach(i; 0 .. particle.particles.alive)
		{
			float2 min = pos[i] - float2(0.05, 0.05);
			float2 max = pos[i] + float2(0.05, 0.05);

			min *= 64;
			max *= 64;

			renderer.drawQuad(float4(min.x, min.y, max.x, max.y),
							  atlas["circle"], col[i]);
		}
	}
}