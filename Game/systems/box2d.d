module systems.box2d;

import allocation;
import framework;
import dbox;

//Gotta fix this one!
import common.components;
import components.box2D;

import collections.list;
import math.vector, math.matrix;

alias Entities = List!Entity;

@EntityInitializer(1)
struct Box2DInitializer 
{
	b2World* bworld;
	b2PolygonShape	  poShape;
	b2CircleShape	  ciShape;
	b2EdgeShape		  edShape;
	b2ChainShape	  chShape;

	void initialize(IAllocator allocator, World* world)
	{
		poShape = allocator.allocate!(b2PolygonShape);
		ciShape = allocator.allocate!(b2CircleShape);
		edShape = allocator.allocate!(b2EdgeShape);
		chShape = allocator.allocate!(b2ChainShape);
		bworld	  = world.app.locate!(b2World);
	}
	void deinitialize(IAllocator allocator, World* world)
	{
		allocator.deallocate(poShape);
		allocator.deallocate(ciShape);
		allocator.deallocate(edShape);
		allocator.deallocate(chShape);
	}

	bool shouldInitializeEntity(ref Entity e)
	{
		return e.hasComp!(Physics) && e.hasComp!(Transform);
	}

	void initializeEntity(ref Entity e)
	{
		auto trans = *e.getComp!(Transform);
		auto phys  = *e.getComp!(Physics);
		e.removeComp!(Physics);


		b2Body* body_ = bodyFromConfig(phys, &trans);
		body_.SetUserData(cast(void*)e.id);


		if(e.hasComp!(Input))
		{
			//Foot Fixture
			poShape.SetAsBox(trans.scale.x / 2.3 , 0.04, b2Vec2(0, -trans.scale.y / 2), 0);

			b2FixtureDef fixtureDef;
			fixtureDef.shape         = poShape;
			fixtureDef.friction      = 0;
			fixtureDef.restitution   = 0;
			fixtureDef.density	     = 0;
			fixtureDef.isSensor	     = true;
			fixtureDef.userData      = cast(void*)e.id;

			body_.CreateFixture(&fixtureDef);
		}


		//collision col = collisionFromConfig(config);

		auto p = Box2DPhysics(body_, null);
		e.addComp(p);		
	}	

	b2BodyType fromPhysType(PhysType type)
	{
		final switch(type)
		{
			case PhysType.static_: return b2BodyType.b2_staticBody;
			case PhysType.dynamic: return b2BodyType.b2_dynamicBody;
			case PhysType.kinematic: return b2BodyType.b2_kinematicBody;
			case PhysType.sensor: return b2BodyType.b2_staticBody;
		}
	}

	b2Body* bodyFromConfig(ref Physics phys, Transform* trans)
	{
		b2BodyDef bodyDef;
		bodyDef.type		   = fromPhysType(phys.type);
		bodyDef.position       = cast(b2Vec2)trans.position;
		bodyDef.linearVelocity = cast(b2Vec2)phys.velocity;
		bodyDef.angle		   = trans.rotation;
		bodyDef.linearDamping  = phys.damping;
		bodyDef.angularDamping = phys.damping;
		bodyDef.allowSleep	   = true;
		bodyDef.awake		   = true;
		bodyDef.fixedRotation  = phys.rotation;
		bodyDef.bullet		   = false;
		bodyDef.active		   = true;
		bodyDef.gravityScale   = phys.gravity;

		b2FixtureDef fixtureDef;
		fixtureDef.friction      = phys.friction;
		fixtureDef.restitution   = phys.bouncyness;
		fixtureDef.density	     = phys.density;
		fixtureDef.isSensor	     = phys.type == PhysType.sensor;

		poShape.SetAsBox(trans.scale.x / 2, trans.scale.y / 2);
		fixtureDef.shape = poShape;

		//final switch(config.shape.type) with(Box2DShapeType)
		//{
		//    case rect: 
		//        poShape.SetAsBox(config.shape.hx, config.shape.hy);
		//        fixtureDef.shape = poShape;
		//        break;
		//    case polygon:
		//        poShape.Set(cast(b2Vec2*)config.shape.vertices.ptr,
		//                    config.shape.vertices.length);
		//        fixtureDef.shape = poShape;
		//        break;
		//    case circle:
		//        ciShape.m_radius = config.shape.radius;
		//        fixtureDef.shape = ciShape;
		//        break;
		//    case chain:
		//        chShape.CreateChain(cast(b2Vec2*)config.shape.vertices.ptr, 
		//                            config.shape.vertices.length);
		//        fixtureDef.shape = chShape;
		//        break;
		//    case edge:
		//        edShape.Set(cast(b2Vec2)config.shape.vertices[0],
		//                    cast(b2Vec2)config.shape.vertices[1]);
		//        fixtureDef.shape = edShape;
		//        break;
		//}	

		auto body_ = bworld.CreateBody(&bodyDef);
		body_.CreateFixture(&fixtureDef);
		return body_;
	}

}

@EntitySystem(1)
struct Box2DPhys
{
	b2World* boxWorld;
	List!Collision collisions;

	struct Collision
	{
		EntityID a, b;
	}

	bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!Box2DPhysics && e.hasComp!Transform;
	}

	void entityRemoved(ref Entity e)
	{
		auto phys = e.getComp!Box2DPhysics;
		phys.body_.m_userData = null;
		boxWorld.DestroyBody(phys.body_);
	}

	void preInitialize(IAllocator all, World* world)
	{
		boxWorld = all.allocate!b2World(b2Vec2(0.0, -10.0f));
		world.app.addService(boxWorld);

		b2ContactListener cListener;
		cListener.BeginContact = &onContactEnter;
		cListener.EndContact   = &onContactExit;

		boxWorld.SetContactListener(cListener);
		collisions = List!Collision(all, 1000);
	}

	void deinitialize(IAllocator allocator, World* world)
	{
		collisions.deallocate(allocator);
		world.app.removeService!b2World;

		allocator.deallocate(boxWorld);
	}

	void onContactEnter(b2Contact c)
	{
		if(collisions.length <= collisions.capacity)
		{
			auto bodyA = c.m_fixtureA.GetBody();
			auto bodyB = c.m_fixtureB.GetBody();

			auto entityA = cast(int)bodyA.m_userData;
			auto entityB = cast(int)bodyB.m_userData;

			collisions ~= Collision(entityA, entityB);
		}			
	}

	void onContactExit(b2Contact contact)
	{
	}

	void step(Time time, Entities entities, World* world)
	{
		boxWorld.Step(time.deltaSec, 6, 2);
		foreach(ref e; entities)
		{
			auto t = e.getComp!(Transform);
			auto p = e.getComp!(Box2DPhysics);

			t.position = p.position;
			t.rotation = p.rotation;
		}

		foreach(ref c; collisions)
		{
			auto entityA = world.findEntity(c.a);
			auto entityB = world.findEntity(c.b);

			if(entityA !is null && entityA.hasComp!(Box2DPhysics))
			{
				auto physA = entityA.getComp!(Box2DPhysics);
				if(physA.onCollision !is null)
				{
					physA.onCollision(entityA, entityB);
				}
			}

			if(entityB !is null && entityB.hasComp!(Box2DPhysics))
			{
				auto physB = entityB.getComp!(Box2DPhysics);
				if(physB.onCollision !is null)
				{
					physB.onCollision(entityB, entityA);
				}
			}
		}


		collisions.clear();
	}
}

@EntitySystem(2)
struct Box2DRender
{
	import rendering, content;
	import rendering.combined;
	import graphics;

	Renderer2D*     renderer;
	AtlasHandle	   atlas;

	void initialize(IAllocator allocator, World* world)
	{
		renderer = world.app.locate!Renderer2D;

		auto loader = world.app.locate!AsyncContentLoader;
		atlas		= loader.load!TextureAtlas("Atlas");
	}

	bool shouldAddEntity(ref Entity e)
	{
		return false;
	}

	void postStep(Time time, Entities entities, World* world)
	{
		auto bworld = world.app.locate!(b2World);
		for(auto b = bworld.GetBodyList(); b !is null; b = b.GetNext)
		{
			for(auto fix = b.GetFixtureList; fix !is null; fix = fix.GetNext)
			{
				auto shape = fix.GetShape();
				switch(shape.GetType) with(b2Shape.Type)
				{
				    case e_circle:
						renderCircle(cast(b2CircleShape)shape, b);
						break;
				    case e_edge:
						renderEdge(cast(b2EdgeShape)shape, b);
						break;
				    case e_polygon:
						renderPolygon(cast(b2PolygonShape)shape, b);
						break;
				    case e_chain:
						renderChain(cast(b2ChainShape)shape, b);
						break;
					default:
						import std.conv;
						assert(0, text("Invalid box2D shape", cast(int)shape.GetType()));
				}
			}
		}
	}

	void renderCircle(b2CircleShape shape, b2Body* b)
	{
		renderer.drawNGonOutline!(50)(cast(float2)b.GetPosition,
									  shape.m_radius - 1.5,
									  shape.m_radius + 0.5,
									  atlas["pixel"], Color.blue);
	}

	void renderEdge(b2EdgeShape shape, b2Body* b)
	{
		float2 v0 = cast(float2)(shape.m_vertex1);
		float2 v1 = cast(float2)(shape.m_vertex2);
		renderLine(v0, v1, b);
	}

	void renderChain(b2ChainShape shape, b2Body* b)
	{
		foreach(i; 0 .. shape.GetChildCount())
		{
			float2 v0 = cast(float2)(shape.m_vertices[i]);
			float2 v1 = cast(float2)(shape.m_vertices[i + 1]);
			renderLine(v0, v1, b);	
		}
	}

	void renderPolygon(b2PolygonShape shape, b2Body* b)
	{
		foreach(i; 0 .. shape.GetVertexCount())
		{
			float2 v0 = cast(float2)shape.GetVertex(i);
			float2 v1 = cast(float2)shape.GetVertex((i + 1) % shape.GetVertexCount);
			renderLine(v0, v1, b);
		}
	}

	void renderLine(float2 v0, float2 v1, b2Body* b)
	{
		mat2 rot = mat2.rotation(b.GetAngle());
		v0 = rot * v0;
		v1 = rot * v1;

		v0 += cast(float2)b.GetPosition();
		v1 += cast(float2)b.GetPosition();

		v0 *= 64;
		v1 *= 64;

		renderer.drawLine(v0, v1, 1, atlas["pixel"], Color.blue);
	}
}