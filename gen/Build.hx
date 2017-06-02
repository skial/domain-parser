package gen;

import haxe.macro.Expr;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.Constraints.IMap;
import uhx.types.AssociativeArray;

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
            
            parts.reverse();

            for (i in 0...parts.length) {
                var part = parts[i];

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

                }
                
                if (i == 0 && part.uCharCodeAt(0) > 128) {
                    // Its not ascii
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
        
        var fields = toFields(tldMap, idnMap);
        var mapExpression = toMapExpression(tldMap, true, idnMap);

        var td = macro class Domain {

            public static function parse(domain:String):haxe.ds.Option<Array<uhx.types.domains.DomainParts>> {
                var result = haxe.ds.Option.None;

                var parts = domain.split('.');
                var idx = parts.length-1;
                var map = icann;

                while (idx != -1) {
                    var part = parts[idx];
                    
                    if (map.exists(part)) {
                        var value = map.get(part);

                        if (result.match(haxe.ds.Option.None)) {
                            result = haxe.ds.Option.Some([uhx.types.domains.DomainParts.Tld([part])]);

                        } else {
                            switch result {
                                case haxe.ds.Option.Some(results):
                                    for (result in results) switch result {
                                        case uhx.types.domains.DomainParts.Tld(parts): parts.push(part);
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
                            case uhx.types.domains.DomainParts.Tld(parts) if (parts.length > 1):
                                parts.reverse();

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
            }
            public static var icann:uhx.types.Recursive = $mapExpression;

        }

        td.pack = ['uhx', 'types'];
        td.fields = (macro class Tmp {
                // This needs to be the first field.
                private static var empty = haxe.ds.Option.None;
            }).fields
            .concat( fields )
            .concat( td.fields );
        var output = new haxe.macro.Printer().printTypeDefinition(td, true);
        var parts = output.split(' uhx.types;');
        parts[0] += ' uhx.types;\r\nimport haxe.ds.Option;\r\nimport uhx.types.domains.DomainParts;\r\n// Autogenerated by the build macro `gen.Build`.';
        parts[1] = parts[1].replace('haxe.ds.Option.', '').replace('uhx.types.domains.DomainParts.', '');
        '${Sys.getCwd()}/src/uhx/types/Domain.hx'.saveContent(parts.join(''));
    }

    private static function toArrayExpression(maps:AssociativeArray<Map<String, Mapped>>):Array<Expr> {
        var results = [];

        for (map in maps) {
            var expr = toMapExpression(map);
            switch expr {
                case macro null:
                case _:
                    results.push(macro $expr);
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
            //macro $v{key} => $exprs;
            results.push( macro $v{key} => $exprs );
            if (toplevel && idnMap != null && idnMap.exists(key)) {
                var t = map.get(key);
                if (t.count() == 0) continue;
                var l = t.get(0);
                var m = idnMap.get(key);
                if (l.count() > 0) for (k in m.keys()) {
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
                var m = idnMap.get(key);
                //trace([for(k in m.keys()) k]);
                var printer = new haxe.macro.Printer();
                for (key in m.keys()) {
                    //trace( new haxe.macro.Printer().printExprs(toArrayExpression(m.get(key)), '::') );
                    for (v in toArrayExpression(m.get(key))) {
                        var vs = [];
                        switch v {
                            case macro []:continue;
                            case macro [$a{exprs}]: vs = exprs;
                            case _:
                        }

                        if (vs.length > 0) switch values[0] {
                            case macro [$a{exprs}]:
                                var strings = exprs.map( printer.printExpr );
                                for (v in vs) if (strings.indexOf(printer.printExpr(v)) == -1) exprs.push(v);
                                
                            case _:
                        }
                        

                    }

                }
                //trace( key, m );
                //trace( new haxe.macro.Printer().printExpr(toMapExpression(idnMap.get(key))) );
                /*switch toMapExpression(m) {
                    case macro [$a{vs}]:
                        //trace(key, new haxe.macro.Printer().printExprs(vs, ','));
                        var printer = new haxe.macro.Printer();
                        switch values[0] {
                            case macro [$a{exprs}] if(exprs.length > 0):
                                var strings = exprs.map( printer.printExpr );
                                for (v in vs) if (strings.indexOf(printer.printExpr(v)) == -1) exprs.push(v);

                            case _:

                        }

                    case x:
                        trace( 'failed' );

                }*/

            }
            
            var exprs = switch values.length {
                case 1: 
                    var e = switch values[0] {
                        case macro []: null;
                        case _: macro $e{values[0]};
                    }
                    e;
                    
                case _: null;
            }
            var temp = macro class Temp {
                public static var $name:uhx.types.Recursive = $exprs; 
            }
            if (exprs != null) {
                fields.push( temp.fields[0] );
                //trace( new haxe.macro.Printer().printField(temp.fields[0]) );

            } else {
                //trace( key, values.length );
                //trace( new haxe.macro.Printer().printExprs(values, '::::'));

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