---
name: heaps-hxbit
description: Save and load game state, and synchronize objects over the network, with HxBit (binary serialization for Haxe, used with Heaps) - Serializable classes with @:s fields, versioned saves that survive adding or removing fields, saves on disk or in the browser, NetworkSerializable objects, NetworkHost / hxd.net.SocketHost and @:rpc calls. Use it whenever a Heaps game needs save slots or a world state to persist (beyond a few options), a level or replay format, a multiplayer mode, or when code uses hxbit.Serializable, hxbit.Serializer, @:s, @:rpc or NetworkHost.
---

# HxBit: saves and networking

`hxd.Save` (see heaps-game) is enough for a few values: level reached, options. Use HxBit when
the state is a graph of objects (a world, its characters, their inventories), when its format
must survive new versions of the game, or for networking. HxBit generates the serialization code
at compile time from `@:s` fields: fast, compact, typed.

```hxml
-lib hxbit
```

## Serializable classes

```haxe
enum Item {
	Key(color : Int);
	Coins(n : Int);
}

class Player implements hxbit.Serializable {
	@:s public var name : String;
	@:s public var level : Int = 1;
	@:s public var items : Array<Item> = [];
	@:s public var friend : Player;          // references, even cycles: each object is stored once
	public var sprite : h2d.Bitmap;          // no @:s: not saved, rebuild it after loading
	public function new( name ) {
		this.name = name;
	}
}
```

- Saved types: `Int`, `Float` (as 32 bits), `Bool`, `String`, enums (with arguments), `Bytes`,
  `Array`, `haxe.ds.Vector`, `Map`, `Null<T>`, anonymous structures, other `Serializable`
  objects. Anything else (a Heaps object, a function) is not saved: keep it without `@:s` and
  rebuild it after loading. `customSerialize` / `customUnserialize` handle special cases.
- **The constructor is not called when loading.** Initializers of fields still run, so
  non-saved fields such as `var cache : Array<Int> = []` are set; anything the constructor
  creates (sprites, listeners) must be created again after loading.
- Keep the saved classes in the model (see heaps-game): the view is rebuilt from them.

## Saving and loading

Use the **versioned** form for saves: the schema of each class is stored with the data, so a
save still loads after fields are added or removed.

```haxe
var bytes = hxbit.Serializer.save(world);                // versioned
var world = hxbit.Serializer.load(bytes, World);
```

- A field removed since the save is ignored. A field **added** since the save gets a default
  value, not always the initializer of the class: in a test, `@:s var gold : Int = 100` loaded
  as `100` but `@:s var items : Array<String> = ["start"]` loaded as `[]`. Set the values that
  matter after loading.
- `new hxbit.Serializer().serialize(obj)` / `.unserialize(bytes, Class)` are the unversioned
  form: smaller, for data written and read by the same build (network messages, undo, caches).
  The two forms do not read each other's data.

Where to put the bytes:

```haxe
// HashLink (sys): a file
sys.io.File.saveBytes("slot1.sav", hxbit.Serializer.save(world));
var world = hxbit.Serializer.load(sys.io.File.getBytes("slot1.sav"), World);

// Everywhere, browser included: as text in hxd.Save (localStorage on the web)
hxd.Save.save(haxe.crypto.Base64.encode(hxbit.Serializer.save(world)), "slot1");
var text : String = hxd.Save.load(null, "slot1");
if( text != null )
	world = hxbit.Serializer.load(haxe.crypto.Base64.decode(text), World);
```

Wrap loading in `try` when the data comes from an older version or from the disk: a corrupt or
foreign file must not crash the game, it should offer a new game.

## Networking

HxBit replicates objects between a server (the authority) and clients, and calls methods
remotely. Heaps provides the TCP host `hxd.net.SocketHost` (HashLink); the Heaps sample
`samples/Network.hx` is a complete example (run it twice: the first instance hosts, the
second connects).

```haxe
class Cursor implements hxbit.NetworkSerializable {
	@:s public var x : Float;                 // changes are sent at the next host.flush()
	@:s public var color : Int;

	public function new( color ) {
		this.color = color;
		enableReplication = true;              // share this object
	}

	// Called on every node when the object exists there, fully initialized: create its view here.
	public function alive() { ... }

	@:rpc public function blink( time : Float ) { ... }   // runs on the server and the clients
}
```

- The host: `host.wait(address, port, onClient)` on the server, `host.connect(address, port,
  ok -> ...)` on a client; `host.flush()` every frame sends the changed fields; `client.sync()`
  sends the whole state to a client that just connected; `host.makeAlive()` calls the pending
  `alive()`. `host.isAuth` tells if this side is the server.
- Only the authority (server) changes `@:s` fields and calls RPCs, unless `networkAllow(op,
  propId, client)` grants it (ownership: a client moving its own cursor).
- RPC modes: `@:rpc` (all), `@:rpc(server)` (client asks the server), `@:rpc(clients)`,
  `@:rpc(owner)`, `@:rpc(immediate)`, `@:rpc(checked)` (generates `canXxx` / `checkXxx`). An RPC
  can return a value, received through a callback (`sendAction("x", result -> ...)`), except in
  `all` mode.
- `@:increment(10)` and `@:condSend(cond)` reduce what is sent; `networkLocalChange(() -> ...)`
  changes fields without sending them.
- `host.saveState()` / `host.loadSave(bytes)` (older HxBit READMEs say `loadState`, the method is
  `loadSave`), then `host.makeAlive()`, save and restore all the shared objects.

The full rules (modes, proxies of arrays and maps, visibility) are in the README of HxBit:
`$(haxelib libpath hxbit)README.md`, and the API through the **heaps-docs** skill
(`lookup.sh --page hxbit.NetworkHost`).
