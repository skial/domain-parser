# Domain

> A domain name parser.

This expects only the domain, `www.google.com`, not `http://www.google.com/?query#hash`, use a URI parser first.

## Data

[`public_suffix_list.dat.txt`](https://publicsuffix.org/list/public_suffix_list.dat) is from [publicsuffix.org](https://publicsuffix.org/) site. This is used to generate `uhx.types.Domain.hx`.

## Api

### [DomainParts](https://github.com/skial/domain-parser/blob/master/src/uhx/types/domains/DomainParts.hx) API

```Haxe
enum DomainParts {
    Tld(parts:Array<String>);
    Domain(name:String);
    Subdomain(parts:Array<String>);
}
```

### [Recursive](https://github.com/skial/domain-parser/blob/master/src/uhx/types/Recursive.hx) Type

```Haxe
typedef Recursive = Map<String, haxe.ds.Option<Recursive>>;
```

### [Domain](https://github.com/skial/domain-parser/blob/master/src/uhx/types/Domain.hx) API

International ccTLD's, like `中国` for China, _simplified_, return the same list as `cn` would.

```Haxe
class Domain {
    public static var icann:Recursive;
    public static function parse(domain:String, ?tlds:Array<String->Bool>, ?slds:Array<String->Bool>):haxe.ds.Option<Array<DomainParts>>;
    // ccTLD's that have known descenants can be accessed directly.
    public static var UK:Recursive;
    public static var CN:Recursive;
    public static var RU:Recursive;
    public static var US:Recursive;
}
```
