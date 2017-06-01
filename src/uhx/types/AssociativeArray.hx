package uhx.types;

import haxe.Constraints.IMap;

class AssociativeArray<V> implements IMap<Int, V> {

    private var array:Array<V> = [];
    private var intkeys(get, never):Array<Int>;

    private function get_intkeys():Array<Int> {
        return [for (i in 0...array.length) i];
    }

    public function new(?a:Array<V>) {
        if (a != null) this.array = a;
    }

    public function exists(k:Int):Bool {
        return k < array.length;
    }

    public function get(k:Int):Null<V> {
        return array[k];
    }

    public function iterator():Iterator<V> {
        return array.iterator();
    }

    public function keys():Iterator<Int> {
        return intkeys.iterator();
    }

    public function remove(k:Int):Bool {
        return array.splice(k, 1).length > 0;
    }

    public function set(k:Int, v:V):Void {
        array[k] = v;
    }

    public function toString() {
        return array.toString();
    }

}