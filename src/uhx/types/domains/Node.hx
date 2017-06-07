package uhx.types.domains;

@:enum abstract NodeType(Bool) from Bool to Bool {
    public var Root = true;
    public var Node = false;
}

@:structInit class Node {
    public var val:String;
    public var type:NodeType;
    public var segments:Int;
    public var maxLength:Int;
    public var length(get, never):Int;

    public inline function get_length():Int {
        return this.val.length;
    }

    public inline function new(val:String, ?type:NodeType = false, ?max:Int = 0, ?segments:Int = 0) {
        this.val = val;
        this.type = type;
        this.maxLength = max;
        this.segments = segments;
    }

    public inline function toString():String {
        return (type ? 'Root' : 'Node') + '($val' + (type ? ', l=$maxLength, s=$segments' : '') + ')';
    }

}