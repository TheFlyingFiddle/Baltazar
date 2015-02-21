module components.box2D;

import framework;
import dbox;
import math.vector;
import common.components;

alias void delegate(Entity*, Entity*) collision;
struct Box2DPhysics
{
	b2Body* body_;
	collision onCollision;

	@property float2 position()
	{
		return cast(float2)body_.GetPosition();
	}

	@property float2 position(float2 value)
	{
		float32 angle = body_.GetAngle();
		body_.SetTransform(cast(b2Vec2)value, angle);
		return cast(float2)body_.GetPosition();
	}

	@property float2 velocity()
	{
		return cast(float2)body_.GetLinearVelocity();
	}

	@property float2 velocity(float2 value)
	{
		body_.SetLinearVelocity(cast(b2Vec2)value);
		return cast(float2)body_.GetLinearVelocity;
	}

	@property float rotation()
	{
		return body_.GetAngle();
	}

	@property float rotation(float value)
	{
		body_.SetTransform(cast(b2Vec2)position, value);
		return value;
	}

	@property PhysType bodyType()
	{
		auto bType = body_.GetType();
		if(bType == b2BodyType.b2_staticBody)
		{
			b2Fixture* fixture = body_.GetFixtureList();
			if(fixture.IsSensor())
			{
				return PhysType.sensor;
			}
			else 
			{
				return PhysType.static_;
			}
		}
		else if(bType == b2BodyType.b2_kinematicBody)
		{		
			return PhysType.kinematic;
		}	
		else 
		{
			return PhysType.dynamic;
		}
	}

	@property void bodyType(PhysType type)
	{
		auto current = bodyType();
		if(current == type) return;

		if(type == PhysType.static_)
		{
			body_.SetType(b2BodyType.b2_staticBody);
			b2Fixture* fixture = body_.GetFixtureList();
			fixture.SetSensor(false);
		}
		else if(type == PhysType.sensor)
		{
			body_.SetType(b2BodyType.b2_staticBody);
			b2Fixture* fixture = body_.GetFixtureList();
			fixture.SetSensor(true);
		}
		else if(type == PhysType.kinematic)
		{
			body_.SetType(b2BodyType.b2_kinematicBody);
		}
		else 
		{
			body_.SetType(b2BodyType.b2_dynamicBody);
		}
	}
}