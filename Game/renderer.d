module renderer;

import graphics, collections.list, math;
import rendering.asyncrenderbuffer;

alias short4 = Vector!(4, short);

struct Vertex
{
	float2 pos;
	float2 size;
	short4 texCoord;
	@Normalized Color  color;
}

//Supports sorting on texture?
struct Renderer
{
	struct Uniform
	{
		float2 invViewport;
		int sampler;
	}

	struct RenderData
	{
		uint count;
		Texture2D texture;
	}

	private SubBufferRenderBuffer!Vertex renderBuffer;
	private Program!(Uniform, Vertex) program;
	private List!RenderData renderData;

	private Sampler sampler;

	this(A)(ref A allocator, uint batchSize)
	{
		this.renderData	  = List!RenderData(allocator, batchSize);
		Shader vShader = Shader(ShaderType.vertex, vs), 
			   fShader = Shader(ShaderType.fragment, fs),
			   gShader = Shader(ShaderType.geometry, gs);

		program = Program!(Uniform, Vertex)(vShader, fShader, gShader);
		program.uniforms.sampler = 0;

		sampler = Sampler.create();
		sampler.minFilter(TextureMinFilter.linear);
		sampler.magFilter(TextureMagFilter.linear);

		renderBuffer = SubBufferRenderBuffer!Vertex(allocator, batchSize, program);
	}

	void viewport(float2 viewport)
	{
		float2 invViewport = float2(1 / viewport.x, 1 / viewport.y);
		program.uniforms.invViewport = invViewport;
	}

	void drawQuad(F)(float2 pos, float2 size, auto ref F frame, Color color)
	{
		Vertex v = void;
		v.pos		 = pos;
		v.size		 = size;
		v.texCoord   = frame.coords;
		v.color		 = color;

		renderBuffer.add(v);
		
		//Guessing this is the bottleneck now. This would be removed anyways.
		if(renderData.back.texture == frame.texture)
			renderData.back.count++;
		else
			renderData ~= RenderData(1, frame.texture);
	}

	void draw()
	{
		renderBuffer.pushToGL();

		int start = 0;
		context[TextureUnit.zero] = sampler;
		foreach(data; renderData)
		{
			context[TextureUnit.zero] = data.texture;
			renderBuffer.render(start, data.count, program);
			start += data.count;
		}

		renderData.clear();
	}
}


struct SubBufferRenderBuffer(Vertex)
{
	private VAO!Vertex vao;
	private VBO vbo;
	private int numVertices;
	private Vertex[] vertices;

	this(A, U)(ref A all, uint batchSize,  ref Program!(U, Vertex) program)
	{
		import allocation;

		this.numVertices = 0;
		this.vertices   = all.allocate!(Vertex[])(batchSize);

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vbo.bind();
		this.vbo.initialize(cast(uint)(Vertex.sizeof * batchSize));

		this.vao = VAO!Vertex.create();
		setupVertexBindings(vao, program, vbo);
		vao.unbind();
	}

	void add(ref Vertex vertex)
	{
		import std.c.string;
		memcpy(&this.vertices[numVertices++], &vertex, Vertex.sizeof);
	}

	void add(Vertex[] vertices)
	{
		this.vertices.ptr[numVertices .. numVertices + vertices.length] = vertices.ptr[0 .. vertices.length];
		numVertices += vertices.length;
	}

	void pushToGL()
	{
		vbo.bind();
		vbo.bufferSubData(vertices[0 .. numVertices], 0);
		numVertices = 0;
	}

	void render(U)(uint start, uint count, ref Program!(U,Vertex) program)
	{
		drawArrays!(Vertex, U)(this.vao, program, PrimitiveType.points, start, count);
	}
}	

enum vs =
"#version 330
in vec2  pos;
in vec2  size;
in vec4  texCoord;
in vec4  color;
out vertexAttrib
{ 
vec4        pos;
vec4  texCoord;
vec4  color;
vec2  origin;
float rotation;
} vertex;


uniform vec2 invViewport;
uniform sampler2D sampler;

void main() 
{
	vec4 p;
	p.xy  = (pos - size / 2) * invViewport * 2- vec2(1,1);
	p.zw  = (pos + size / 2) * invViewport * 2 - vec2(1,1);

	ivec2 tSize = textureSize(sampler, 0);

	vec4 coords;
	coords.x = texCoord.x / tSize.x;
	coords.y = texCoord.y / tSize.y;
	coords.z = (texCoord.x + texCoord.z) / tSize.x;
	coords.w = (texCoord.y + texCoord.w) / tSize.y;

	vertex.pos		= p;
    vertex.texCoord = coords;
    vertex.color    = color;
}
	";

enum gs =
"#version 330
layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

in vertexAttrib
{
     vec4 pos;
     vec4 texCoord;
     vec4 color;
     vec2 origin;
     float rotation;
} vertex[];
	
out vertData 
{
      vec4 color;
      vec2 texCoord;
} vertOut;
	
   
void emitCorner(in vec2 pos, in vec2 coord)
{
    gl_Position      = vec4(pos, 0.0, 1.0);
    vertOut.color    = vertex[0].color;
    vertOut.texCoord = coord;
    EmitVertex();
}

void main()
{
    vec4 pos      =  vertex[0].pos;
    vec4 texCoord =  vertex[0].texCoord;
    emitCorner(pos.xy, texCoord.xy);
    emitCorner(pos.xw, texCoord.xw);
    emitCorner(pos.zy, texCoord.zy);
    emitCorner(pos.zw, texCoord.zw);
}
";

enum fs =
"#version 330
in vertData {
   vec4 color;
   vec2 texCoord;
} vertIn;
out vec4 fragColor;

uniform sampler2D sampler;
void main()
{
	vec4 c = texture2D(sampler, vertIn.texCoord);
	if(c.a < 0.1) discard;

	fragColor = c * vertIn.color;
}
";