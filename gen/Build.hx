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

    private static var clsDomain:String = '${Sys.getCwd()}/src/uhx/types/Domain.hx';
    private static var clsDomainSpec:String = '${Sys.getCwd()}/tests/uhx/types/DomainSpec.hx';

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
        var tests = [];
        
        for (item in icannItems) {
            var parts = item.split('.');
            var node:GraphNode<Node> = null;

            if (!item.startsWith('!') && !item.startsWith('::') && !item.startsWith('*')) {
                // TODO handle idn mapping to cctld.
                var methodName = ~/[-\\.\\*]+/gi.replace('test_' + item, '_');
                var domain = 'www.example.' + item;

                var tmp = '';
                for (i in 0...methodName.uLength()) if (methodName.uCharCodeAt(i) > 128) {
                    tmp += methodName.uCharCodeAt(i).hex();
                } else {
                    tmp += methodName.uCharAt(i);
                }

                tests.push( (macro class Tmp {

                    public function $tmp() {
                        var values = $v{domain}.parse();

                        switch values {
                            case haxe.ds.Option.Some(parts):
                                utest.Assert.equals( 3, parts.length );
                                switch parts[0] {
                                    case uhx.types.domains.DomainParts.Subdomain(s):
                                        utest.Assert.equals( 1, s.length );
                                        utest.Assert.equals('www', s[0]);

                                    case _:
                                        utest.Assert.fail('Subdomain should not be empty.');

                                }
                                //utest.Assert.isTrue( parts[0].match(uhx.types.domains.DomainParts.Subdomain(['www'])), 'Should be Subdomain containing `[www]`.' );
                                switch parts[1] {
                                    case uhx.types.domains.DomainParts.Domain(s):
                                        utest.Assert.equals('example', s);

                                    case _:
                                        utest.Assert.fail('Domain should not be empty.');

                                }
                                //utest.Assert.isTrue( parts[1].match(uhx.types.domains.DomainParts.Domain('example')), 'Should be Domain name `example`.' );
                                switch parts[2] {
                                    case uhx.types.domains.DomainParts.Tld(s):
                                        utest.Assert.equals( $v{parts.length}, s.length );
                                        utest.Assert.equals('' + $a{parts.map(s->macro$v{s})}, '' + s);

                                    case _:
                                        utest.Assert.fail('Tld should not be empty.');

                                }
                                //utest.Assert.isTrue( parts[2].match(uhx.types.domains.DomainParts.Tld([$a{parts.map(s->macro$v{s})}])), $v{'Should be Tld containing `[' + parts.join(', ') + ']`.'} );

                            case haxe.ds.Option.None:
                                utest.Assert.fail($v{'$domain should not have parsed into an empty result.'});

                        }

                    }

                }).fields[0] );

            }

            parts.reverse();

            for (i in 0...parts.length) {
                var part:String = parts[i];

                if (part == '*' || part.startsWith('!')) continue;
                
                if (part.startsWith('::')) {
                    var pair = part.substring(2).split('::');
                    var cc = pair[0].toLowerCase();
                    var idn = part = pair[1];

                    var ccnode = null;
                    var idnnode = null;
                    if (index.exists(cc)) {
                        ccnode = index.get( cc );

                    } else {
                        var key = new Node(cc, Root, cc.uLength(), parts.length);
                        hash.set(cc, key);
                        index.set(cc, ccnode = graph.add(key));

                    }

                    if (index.exists(idn)) {
                        idnnode = index.get(idn);
                        idnnode.val.maxLength = idnnode.val.val.uLength() + ccnode.val.maxLength - ccnode.val.val.uLength();
                        idnnode.val.segments = ccnode.val.segments;

                    } else {
                        var key = new Node(idn, Root, idn.uLength() + ccnode.val.maxLength - ccnode.val.val.uLength(), ccnode.val.segments/* idn.uLength(), parts.length*/);
                        hash.set(idn, key);
                        index.set(idn, idnnode = graph.add(key));

                    }

                    for (target in ccnode.iterator()) {
                        var gnode = graph.findNode(target);
                        if (!idnnode.isConnected(gnode)) graph.addSingleArc(idnnode, gnode);

                    }

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
                    
                    if (r.maxLength < item.uLength()) r.maxLength = parts.join('').uLength(); // TODO handle wildcards `*`
                    if (r.segments < parts.filter(s->s!='*').length) r.segments = parts.filter(s->s!='*').length; // Handle wildcards `*`

                    index.get(part).val = r;
                    hash.set(part, r);
                    node = index.get(part);

                } else {
                    var r = new Node(part, Root, part.uLength(), parts.length);
                    hash.set(part, r);
                    index.set(part, node = graph.add(r));
                }

                if (prevNode != null) graph.addSingleArc(prevNode, node);

            }
            
        }
        
        var graphExpr = convertGraph(graph, index);
        //'${Sys.getCwd()}/info.txt'.saveContent( new haxe.macro.Printer().printExpr(graphExpr).replace('de.polygonal.ds.Graph', 'Graph').replace('uhx.types.domains.Node', 'Node') );

        var tdDomainSpec = macro class DomainSpec {
            public function new() {

            }
        }

        tdDomainSpec.fields = tdDomainSpec.fields.concat( tests );

        var tdDomain = macro class Domain {
            public static function exists(tld:String):Bool {
                return map.exists(tld);
            }

            public static function get(tld:String):Null<de.polygonal.ds.GraphNode<uhx.types.domains.Node>> {
                return map.get(tld);
            }

            private static function search(node:de.polygonal.ds.GraphNode<uhx.types.domains.Node>, val:String):Null<de.polygonal.ds.GraphNode<uhx.types.domains.Node>> {
                var result = null;
				
				for (linked in node) {
					if (linked.val == val) {
						result = graph.findNode(linked);
						break;

					}

				}
				
				return result;
            }

            public static function parse(domain:String, ?tlds:Array<String->Bool>, ?slds:Array<String->Bool>):haxe.ds.Option<Array<uhx.types.domains.DomainParts>> {
                var results = {
                    tlds:[],
                    domain:'',
                    subdomains:[],
                }

                var segments = domain.split('.');
                var idx = segments.length-1;
                
                var segment = segments[idx];
                var exists = map.exists(segment);
                if (!exists && tlds != null && tlds.length > 0) {
                    for (custom in tlds) if (custom(segment)) {
                        results.tlds.push( segment );
                        idx--;
                        break;

                    }

                    if (slds != null && slds.length > 0) for (custom in slds) if (custom(segments[idx])) {
                        results.tlds.push( segments[idx] );
                        idx--;
                        break;

                    }

                } else {
                    var graphNode = map.get(segment);
                    var node = graphNode.val;
                    var depth = node.segments;
                        
                    if (segments.length-1 < depth) depth = segments.length;

                    results.tlds.push( segment );
                    idx--;
                    //depth--;

                    /*while (depth > 0) {
                        if (graphNode.numArcs > 0) for (linked in graphNode.iterator()) {
                            if (linked.val == segments[idx]) {
                                results.tlds.push( linked.val );
                                idx--;
                                depth--;
                                break;

                            } else {
                                depth = 0;
                            }

                        } else {
                            break;

                        }

                    }*/

                    
                    while (graphNode != null && graphNode.numArcs > 0) {
                        graphNode = search(graphNode, segments[idx--]);
                        if (graphNode != null) {
                            results.tlds.push( graphNode.val.val ); 

                        } else {
                            idx++;

                        }

                    }

                }

                if (results.tlds.length > 1) results.tlds.reverse();

                if (idx >= 0) {
                    results.domain = segments[idx--];

                }

                results.subdomains = (idx >= 0) ? segments.slice(0, idx+1) : [];

                return results.tlds.length == 0 ? haxe.ds.Option.None : {
                    var r = [];
                    if (results.subdomains.length > 0) r.push( uhx.types.domains.DomainParts.Subdomain(results.subdomains) );
                    r.push( uhx.types.domains.DomainParts.Domain(results.domain) );
                    r.push( uhx.types.domains.DomainParts.Tld(results.tlds) );
                    haxe.ds.Option.Some(r);
                }

            }
            
            public static var graph:de.polygonal.ds.Graph<uhx.types.domains.Node>;
            private static var nodes:Array<de.polygonal.ds.GraphNode<uhx.types.domains.Node>>;
            private static var map:Map<String, de.polygonal.ds.GraphNode<uhx.types.domains.Node>>;
            private static function singleLink(root:de.polygonal.ds.GraphNode<uhx.types.domains.Node>, indexes:Array<Int>):Void {
                map.set(root.val.val, root);
                for (i in indexes) graph.addSingleArc(root, nodes[i]);
            }

            private static function newNode(val:String, type:Bool = false, maxLength:Int = 0, segments = 0):de.polygonal.ds.GraphNode<uhx.types.domains.Node> {
                var gn = graph.add(new uhx.types.domains.Node(val, type, maxLength, segments));
                if (type) map.set(val, gn);
                return gn;
            }

            private static function __init__() $graphExpr;
            
        }
        
        tdDomain.pack = ['uhx', 'types'];
        
        var output = new haxe.macro.Printer().printTypeDefinition(tdDomain, true);
        var parts = output.split(' uhx.types;');

        parts[0] += ' uhx.types;\r\nimport haxe.ds.Option;\r\nimport uhx.types.domains.DomainParts;\r\n// Autogenerated by the build macro `gen.Build`.';
        parts[1] = parts[1].replace('haxe.ds.Option.', '').replace('uhx.types.domains.DomainParts.', '');

        var root = index.get('jp');
        trace( root.val, root.numArcs );
        for (linked in root) {
            if (linked.val == 'kanagawa') {
                var g = graph.findNode(linked);
                trace(g);
                for (linked in g) {
                    if (linked.val == 'aikawa') {
                        trace(graph.findNode(linked));
                        break;

                    }

                }
                break;

            }

        }
        clsDomain.saveContent(parts.join(''));
        clsDomainSpec.saveContent('package uhx.types;\r\nimport uhx.types.Domain;\r\nusing uhx.types.Domain;\r\n@:keep\r\n' + new haxe.macro.Printer().printTypeDefinition(tdDomainSpec, true));
    }

    private static function convertGraph(graph:Graph<Node>, root:Map<String, GraphNode<Node>>):Expr {
        var results:Array<Expr> = [];
        var creations:Array<Expr> = [];
        var rootArcs:Array<Expr> = [];
        var positionMap = new Map<String, Int>();

        graph.iter( function(node) {
            var index = creations.push( (node.type) ?
                macro newNode( $v{node.val}, $v{node.type}, $v{node.maxLength}, $v{node.segments}) 
                : macro newNode( $v{node.val} ) );
            positionMap.set( node.val, index-1 );

        } );

        graph.iter( function(node) {
            var g = graph.findNode(node);
            //if (node.type) {
                if (g.numArcs > 0) {
                    var targets = [];
                    
                    //for (target in root.get(node.val).iterator()) {
                    for (target in graph.findNode(node).iterator()) {                        
                        targets.push( macro $v{positionMap.get(target.val)} );

                    }
                    
                    if (targets.length > 0) {
                        rootArcs.push( macro singleLink(nodes[$v{positionMap.get(node.val)}], $a{targets}) );

                    }
                    
                }

            //}

        } );
        
        results = results.concat( creations );
        
        return macro {
            graph = new de.polygonal.ds.Graph<uhx.types.domains.Node>();
            map = new Map<String, de.polygonal.ds.GraphNode<uhx.types.domains.Node>>();
            nodes = $a{results};
            @:mergeBlock $b{rootArcs};
        }
    }

}