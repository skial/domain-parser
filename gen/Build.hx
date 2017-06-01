package gen;

import haxe.macro.Expr;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.Constraints.IMap;
import uhx.types.AssociativeArray;

using Lambda;
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
        icannTlds = ~/(\/\/.+)\r?\n/gi.replace(icannTlds, "");
        icannTlds = ~/[\r?\n]+/g.replace(icannTlds, "|");
        icannTlds = ~/\./g.replace(icannTlds, ".");
        //icannTlds = ~/\./g.replace(icannTlds, "\\.");
        //icannTlds = ~/\*/g.replace(icannTlds, "[^.]+");
        icannTlds = icannTlds.substring(1, icannTlds.length-1);
        var icannItems = icannTlds.split('|');
        var tldMap = new Map<String, Mapped>();
        
        for (item in icannItems) {
            var access = '';
            var next = tldMap;
            var parts = item.split('.');
            
            parts.reverse();

            for (i in 0...parts.length) {
                var part = parts[i];

                if (part == '*' || part.startsWith('!')) continue;
                if (access == '') access = part;

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

        var td = macro class Domain {

            private static var empty = haxe.ds.Option.None;
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
            public static var icann:uhx.types.Recursive = $e{processMap(tldMap)};

        }

        td.pack = ['uhx', 'types'];
        var output = new haxe.macro.Printer().printTypeDefinition(td, true);
        var parts = output.split(' uhx.types;');
        parts[0] += ' uhx.types;\r\nimport haxe.ds.Option;\r\nimport uhx.types.domains.DomainParts;\r\n// Autogenerated by the build macro `gen.Build`.';
        parts[1] = parts[1].replace('haxe.ds.Option.', '').replace('uhx.types.domains.DomainParts.', '');
        '${Sys.getCwd()}/src/uhx/types/Domain.hx'.saveContent(parts.join(''));
    }

    private static function processArray(maps:AssociativeArray<Map<String, Mapped>>):Array<Expr> {
        var results = [];

        for (map in maps) {
            var expr = processMap(map);
            switch expr {
                case macro null:
                case _:
                    results.push(macro $expr);
            }
            
        };

        return results;
    }

    private static function processMap(map:Map<String, Mapped>):Expr {
        var results = [];

        for (key in map.keys()) {
            var values = processArray(map.get(key));
            var exprs = switch values.length {
                case 0: macro new Map();
                case 1: 
                    var e = switch values[0] {
                        case macro []: macro empty;
                        case _: macro haxe.ds.Option.Some($e{values[0]});
                    }
                    e;
                    //trace(values[0].toString());
                    
                case _: macro new uhx.types.AssociativeArray($a{values});
            }
            //macro $v{key} => $exprs;
            results.push( macro $v{key} => $exprs );
        };
        return macro $a{results};
    }

}