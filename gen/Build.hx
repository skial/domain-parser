package gen;

import haxe.ds.Option;
import haxe.macro.Expr;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.Constraints.IMap;
import de.polygonal.ds.Graph;
import uhx.types.domains.Node;
import de.polygonal.ds.GraphNode;
import uhx.types.domains.Node.NodeType;
import uhx.types.domains.AssociativeArray;

using Lambda;
using gen.Build;
using StringTools;
using sys.io.File;
using sys.FileSystem;
using unifill.Unifill;

typedef Mapped = AssociativeArray<Map<String, Mapped>>;

// Based on https://github.com/peerigon/parse-domain/blob/master/lib/build/buildRegex.js
class Build {

    public static function generate() {
        var hash = new Map<String, Node>();
        var index = new Map<String, GraphNode<Node>>();
        var graph = new Graph<Node>();
        
        var content:String = '${Sys.getCwd()}/res/public_suffix_list.dat.txt'.getContent();
        var icann = content.substring( content.indexOf("// ===BEGIN ICANN DOMAINS==="), content.indexOf("// ===END ICANN DOMAINS===") );
        //var priv = content.substring( content.indexOf("// ===BEGIN PRIVATE DOMAINS==="), content.indexOf("// ===END PRIVATE DOMAINS===") );

        var icannTlds = icann;
        icannTlds = ~/\/\/[ ]xn-.+[ ]:[ ]([^\r\n0-9 ]+)\r?\n/gi.map(icann, function(e) {
            return '::' + e.matched(1) + '::';
        });
        icannTlds = ~/(\/\/.+)\r?\n/gi.replace(icannTlds, "");
        icannTlds = ~/[\r?\n]+/g.replace(icannTlds, "|");
        icannTlds = ~/\./g.replace(icannTlds, ".");
        icannTlds = icannTlds.substring(1, icannTlds.length-1);
        var icannItems = icannTlds.split('|');
        var tldMap = new Map<String, Mapped>();
        var idnMap = new Map<String, Map<String, Mapped>>();
        
        for (item in icannItems) {
            var next = tldMap;
            var parts = item.split('.');
            var node:GraphNode<Node> = null;
            
            parts.reverse();

            for (i in 0...parts.length) {
                var part:String = parts[i];

                if (part == '*' || part.startsWith('!')) continue;
                
                if (part.startsWith('::')) {
                    var pair = part.substring(2).split('::');
                    var cc = pair[0].toLowerCase();
                    var idn = part = pair[1];
                    
                    if (!idnMap.exists(cc)) {
                        idnMap.set( cc, next = [idn => new AssociativeArray( [new Map()] )] );

                    } else {
                        next = idnMap.get( cc );
                        next.set(idn, new AssociativeArray( [new Map()] ));

                    }

                    var ccnode = null;
                    var idnnode = null;
                    if (index.exists(cc)) {
                        ccnode = index.get( cc );

                    } else {
                        var key = new Node(cc, Root, cc.uLength(), parts.length);
                        hash.set(cc, key);
                        index.set(cc, ccnode = graph.add(key));
                        key;

                    }

                    if (index.exists(idn)) {
                        idnnode = index.get(idn);

                    } else {
                        var key = new Node(idn, Root, idn.uLength(), parts.length);
                        hash.set(idn, key);
                        index.set(idn, idnnode = graph.add(key));
                        key;

                    }

                    graph.addMutualArc(idnnode, ccnode);

                }

                var prevNode = node;

                if (i > 0) {
                    if (index.exists(part)) {
                        node = index.get(part);

                    } else {
                        index.set(part, node = graph.add( new Node(part) ));

                    }

                } else if (hash.exists(part)) {
                    var r = hash.get(part);
                    
                    if (r.maxLength < item.uLength()) r.maxLength = parts.join('').uLength();
                    if (r.segments < parts.length) r.segments = parts.length;

                    index.get(part).val = r;
                    hash.set(part, r);
                    node = index.get(part);

                } else {
                    //var info = {len:part.uLength(), seg:parts.length}
                    var r = new Node(part, Root, part.uLength(), parts.length);
                    hash.set(part, r);
                    index.set(part, node = graph.add(r));
                }

                if (prevNode != null) graph.addSingleArc(prevNode, node);
                
                if (i == 0 && part.uCharCodeAt(0) > 128) {
                    // Its not basic ascii
                    for (key in idnMap.keys()) {
                        if (idnMap.get(key).exists(part)) {
                            next = idnMap.get(key);
                            break;

                        }

                    }

                }

                switch i {
                    case x if (x <= 4):
                        if (!next.exists(part)) {
                            next.set( part, new AssociativeArray([next = new Map()]) );

                        } else {
                            next = next.get(part).get(0);

                        }

                    case _:
                        trace( part );
                        break;

                }

            }
            
        }
        
        var graphExpr = convertGraph(graph, index);
        '${Sys.getCwd()}/info.txt'.saveContent( new haxe.macro.Printer().printExpr(graphExpr).replace('de.polygonal.ds.Graph', 'Graph').replace('uhx.types.domains.Node', 'Node') );
        var fields = toFields(tldMap, idnMap);
        var mapExpression = toMapExpression(tldMap, true, idnMap);

        var td = macro class Domain {
/*
            public static function parse(domain:String, ?tlds:Array<String->Bool>, ?slds:Array<String->Bool>):haxe.ds.Option<Array<uhx.types.domains.DomainParts>> {
                var result = haxe.ds.Option.None;

                var parts = domain.split('.');
                var len = parts.length-1;
                var idx = len;
                var map = icann;

                while (idx != -1) {
                    var part = parts[idx];
                    var custom:Array<String->Bool> = null;

                    if (idx == len) custom = tlds;
                    else if (idx == len - 1) custom = slds;
                    
                    //if (idx == len) trace(idx, len, 'tlds');
                    //else if (idx == len - 1) trace(idx, len, 'slds');

                    var customMatched = false;
                    if (custom != null && custom.length > 0) {
                        for (method in custom) if ((customMatched = method(part))) {
                            if (result.match(haxe.ds.Option.None)) {
                                result = haxe.ds.Option.Some([uhx.types.domains.DomainParts.Tld([part])]);

                            } else {
                                switch result {
                                    case haxe.ds.Option.Some(results):
                                        for (result in results) switch result {
                                            case uhx.types.domains.DomainParts.Tld(p): p.push(part);
                                            case _:
                                        }

                                    case _:

                                }

                            }
                            break;
                            //result = haxe.ds.Option.Some([uhx.types.domains.DomainParts.Tld([part])]);

                        }

                        if (customMatched) {
                            idx--;
                            continue;

                        }

                    }
                    
                    if (!customMatched && map.exists(part)) {
                        var value = map.get(part);

                        if (result.match(haxe.ds.Option.None)) {
                            result = haxe.ds.Option.Some([uhx.types.domains.DomainParts.Tld([part])]);

                        } else {
                            switch result {
                                case haxe.ds.Option.Some(results):
                                    for (result in results) switch result {
                                        case uhx.types.domains.DomainParts.Tld(p): p.push(part);
                                        case _:
                                    }

                                case _:

                            }

                        }

                        switch value {
                            case haxe.ds.Option.Some(m): map = m;
                            case _:
                        }

                    } else {
                        break;

                    }

                    idx--;

                }

                switch result {
                    case haxe.ds.Option.Some(results):
                        switch results[0] {
                            case uhx.types.domains.DomainParts.Tld(p) if (p.length > 1):
                                p.reverse();

                            case _:

                        }

                        if (idx >= 0) {
                            results.push(uhx.types.domains.DomainParts.Domain(parts[idx--]));

                        }

                        var subdomains = [];
                        while (idx != -1) {
                            subdomains.push(parts[idx--]);

                        }
                        if (subdomains.length > 0) {
                            subdomains.reverse();
                            results.push(uhx.types.domains.DomainParts.Subdomain(subdomains));

                        }

                        results.reverse();

                    case _:

                }

                return result;
            }*/
            //public static var icann:uhx.types.Recursive = $mapExpression;
            public static var icannGraph = $graphExpr;
        }

        td.pack = ['uhx', 'types'];
        td.fields = (macro class Tmp {
                // This needs to be the first field.
                private static var empty = haxe.ds.Option.None;
            }).fields
            //.concat( fields )
            .concat( td.fields );
        
        var output = new haxe.macro.Printer().printTypeDefinition(td, true);
        var parts = output.split(' uhx.types;');

        parts[0] += ' uhx.types;\r\nimport haxe.ds.Option;\r\nimport uhx.types.domains.DomainParts;\r\n// Autogenerated by the build macro `gen.Build`.';
        parts[1] = parts[1].replace('haxe.ds.Option.', '').replace('uhx.types.domains.DomainParts.', '');

        '${Sys.getCwd()}/src/uhx/types/Domain.hx'.saveContent(parts.join(''));
    }

    private static function convertGraph(graph:Graph<Node>, root:Map<String, GraphNode<Node>>):Expr {
        var results:Array<Expr> = [];///[macro graph = new de.polygonal.ds.Graph<uhx.types.domains.Node>(), macro map = new Map<String, de.polygonal.ds.GraphNode<uhx.types.domains.Node>>()];
        var rootCreations:Array<Expr> = [];
        var nodeCreations:Array<Expr> = [];
        var rootArcs:Array<Expr> = [];
        var nodeArcs:Array<Expr> = [];
        var positionMap = new Map<String, Int>();

        graph.iter( function(node) {
            var arcs = (node.type) ? rootArcs : nodeArcs;
            var creations = (node.type) ? rootCreations : nodeCreations;
            //if (node.type) {
                var index = (node.type) ?
                    creations.push( macro graph.add( new uhx.types.domains.Node($v{node.val}, $v{node.type}, $v{node.maxLength}, $v{node.segments}) )) 
                    : creations.push( macro graph.add( new uhx.types.domains.Node($v{node.val} )) );
                positionMap.set( node.val, index );
                //creations.push( macro map.set( $v{node.val}, graph.add( new uhx.types.domains.Node($v{node.val}, $v{node.type}, $v{node.maxLength}, $v{node.segments})) ) );

            //} else {
                //creations.push( macro graph.add( new uhx.types.domains.Node($v{node.val}, $v{node.type}, $v{node.maxLength}, $v{node.segments}) ) );

            //}
            //if (processed.lastIndexOf( node.val ) == -1) processed.push( node.val );

        } );

        graph.iter( function(node) {
            if (node.type && node.segments > 1) {
                for (target in root.get(node.val).iterator()) {
                    rootArcs.push( macro graph.addSingleArc( nodes[$v{positionMap.get(node.val)}], nodes[$v{positionMap.get(target.val)}] ) );

                }

            }

        } );

        results = results.concat( rootCreations ).concat( nodeCreations );
        trace( results.length, rootCreations.length, nodeCreations.length );
        return macro @:mergeBlock {
            var graph = new de.polygonal.ds.Graph<uhx.types.domains.Node>();
            var map = new Map<String, de.polygonal.ds.GraphNode<uhx.types.domains.Node>>();
            var nodes:Array<de.polygonal.ds.GraphNode<uhx.types.domains.Node>> = $a{results};
            for (node in nodes) {
                if (node.val.type) map.set(node.val.val, node);
                //graph.addNode(node);

            }
            @:mergeBlock $b{rootArcs};
            graph;
        }
    }

    private static function toArrayExpression(maps:AssociativeArray<Map<String, Mapped>>):Array<Expr> {
        var results = [];

        for (map in maps) {
            var expr = toMapExpression(map);
            switch expr {
                case macro null:
                case _: results.push(macro $expr);
            }
            
        };

        return results;
    }

    private static function toMapExpression(map:Map<String, Mapped>, toplevel:Bool = false, idnMap:Map<String, Map<String, Mapped>> = null):Expr {
        var results = [];

        for (key in map.keys()) {
            var values = toArrayExpression(map.get(key));

            var exprs = switch values.length {
                //case 0: macro new Map();
                case 1: 
                    var e = switch values[0] {
                        case macro []: macro empty;
                        case _: 
                            var name = key.toUpperCase();
                            if (toplevel && name.isAscii()) {
                                macro haxe.ds.Option.Some($i{name});

                            } else {
                                macro haxe.ds.Option.Some($e{values[0]});

                            }
                    }
                    e;
                    //trace(values[0].toString());
                    
                case _: macro haxe.ds.Option.Some($a{values});
            }
            
            results.push( macro $v{key} => $exprs );

            // Build links between IDN ccTLD's and ccTLD's.
            if (toplevel && idnMap != null && idnMap.exists(key)) {
                var top = map.get(key);
                if (top.count() == 0) continue;
                var topchild = top.get(0);
                var idn = idnMap.get(key);
                if (topchild.count() > 0) for (k in idn.keys()) {
                    // Adds the expression `'中国' => Some(CN)` to field `icann`.
                    results.push( macro $v{k} => haxe.ds.Option.Some($i{key.toUpperCase()}) );

                }
            }
        };

        return macro $a{results};
    }

    private static function toFields(map:Map<String, Mapped>, idnMap:Map<String, Map<String, Mapped>>):Array<Field> {
        var fields:Array<Field> = [];

        for (key in map.keys()) {
            var name = key.toUpperCase();
            
            // TODO
            // No unicode normalization exists for Haxe, afaik,
            // so poorly ignore non ascii names :(
            if (!name.isAscii()) {
                continue;

            }
            var values = toArrayExpression(map.get(key));

            if (idnMap.exists(key)) {
                var idn = idnMap.get(key);
                
                for (key in idn.keys()) {
                    
                    for (v in toArrayExpression(idn.get(key))) {
                        var vs = [];
                        switch v {
                            case macro []: continue;
                            case macro [$a{exprs}]: vs = exprs;
                            case _:
                        }

                        if (vs.length > 0) switch values[0] {
                            case macro [$a{exprs}]:
                                for (v in vs) exprs.push(v);
                                
                            case _:
                        }

                    }

                }

            }
            
            switch values.length {
                case 1: 
                    switch values[0] {
                        case macro []:

                        case _: 
                            // Only add non empty maps as fields.
                            var e = macro $e{values[0]};
                            var temp = macro class Temp {
                                public static var $name:uhx.types.Recursive = $e; 
                            }

                            fields.push( temp.fields[0] );

                    }
                    
                case _:

            }

        }
        
        return fields;
    }

    private static function isAscii(v:String):Bool {
        var result = true;

        for (i in 0...v.uLength()) {
            if (!(result = v.charCodeAt(i) <= 128)) break;
        }

        return result;
    }

}