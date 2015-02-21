module bridge.state;

//@DontReflect
//struct WorldItem
//{
//    string name;
//    uint   id;
//    List!StateComponent components;
//
//    this(string name)
//    {
//        this.name = name;
//        components = List!StateComponent(GlobalAlloc, 20);
//
//        import std.random;
//        id = uniform(0, uint.max);
//    }
//
//    void deallocate()
//    {
//        components.deallocate(GlobalAlloc);
//    }
//
//    WorldItem clone()
//    {
//        auto other = WorldItem(name);
//        other.components ~= this.components;
//        return other;
//    }
//
//    //Needed to preserv entity references;
//    WorldItem copy()
//    {
//        auto other = WorldItem(name);
//        other.components ~= this.components;
//        other.id		= this.id;
//        return other;
//    }
//
//    T* get(T)()
//    {
//        auto p = peek!T;
//        if(p) return p;
//
//        assert(0, "Component not found found! " ~ T.stringof);
//    }
//
//    T* peek(T)()
//    {
//        foreach(ref c; components)
//        {
//            auto p = c.peek!T;
//            if(p)
//                return p;
//        }
//
//        return null;
//    }
//
//    StateComponent* peekComponent(const(RTTI)* type)
//    {
//        foreach(ref c; components)
//        {
//            if(type.isTypeOf(c))
//            {
//                return &c;
//            }
//        }
//
//        return null;
//    }
//
//    import reflection;
//    bool hasComponent(const(RTTI)* type)
//    {	
//        foreach(ref c; components)
//        {
//            if(type.isTypeOf(c))
//            {
//                return true;
//            }
//        }
//
//        return false;
//    }
//}

//@DontReflect
//struct EditorStateContent
//{
//    List!WorldItem items;
//    List!WorldItem archetypes;
//}

//@DontReflect
//struct EditorClipboard
//{
//    bool empty;
//    WorldItem item;
//}

//@DontReflect
//struct EditorState
//{
//    import bridge.plugins;
//    import bridge.do_undo;
//    import framework.core;
//    import graphics.textureatlas;
//    import std.algorithm;
//
//    Plugins* plugin;
//
//    DoUndoCommands!(EditorState*) doUndo;
//    EditorClipboard clipboard;
//    Camera camera;
//
//    GrowingList!WorldItem items;
//    GrowingList!WorldItem archetypes;
//
//    int idCount;
//
//    //This is assets really...
//    //Should be able to do this in an automatic way:
//    //Other Assets include particle_effects, sounds etc.
//    List!(Named!Frame)    images;
//    List!(Named!(Font*))  fonts;
//    List!(string)		  particleSystems;
//    int archetype;
//
//    void delegate(EditorState*) selectedChanged;
//    int selected_;
//
//    this(void delegate(EditorState*) selectedChanged, Application* app)
//    {
//        plugin			= app.locate!Plugins;
//        doUndo			= DoUndoCommands!(EditorState*)(2000);
//        clipboard		= EditorClipboard(true);
//        camera			= Camera(float4.zero, float2.zero, 64);
//
//        archetypes      = GrowingList!WorldItem(Mallocator.cit, 20);
//        items		    = GrowingList!WorldItem(Mallocator.cit, 1000);
//        images	     	= List!(Named!Frame)(Mallocator.it, 100);
//        fonts		    = List!(Named!(Font*))(Mallocator.it, 100);
//        particleSystems = List!string(Mallocator.it, 100);
//
//        this.selectedChanged = selectedChanged;
//
//        import content, std.path;
//        auto loader = app.locate!AsyncContentLoader;
//    }
//
//    void initialize(EditorStateContent c)
//    {
//        selected_ = -1;
//        archetype = 0;
//
//        doUndo.clear();
//        clipboard = EditorClipboard(true);
//        camera = Camera(float4.zero, float2.zero, 64);
//
//        foreach(ref a; archetypes)
//            a.deallocate();
//        foreach(ref i; items)
//            i.deallocate();
//
//        archetypes.clear();
//        items.clear();
//
//        archetypes ~= c.archetypes;
//        items	   ~= c.items.map!(x => x.copy());
//
//        selected_ = -1;
//        archetype = 0;
//        this.selectedChanged = selectedChanged;
//
//    }
//
//    ref int selected() @property
//    {
//        return selected_;
//    }
//
//    void selected(int value) @property
//    {
//        this.selected_ = value;
//        if(selectedChanged !is null)
//            selectedChanged(&this);
//    }
//
//    auto item(int idx)
//    {
//        if(idx < 0 || idx >= items.length) return null;
//        return &items[idx];
//    }
//
//    auto itemNames()
//    {
//        import std.algorithm;
//        return items.array.map!(x => x.name);
//    }
//}