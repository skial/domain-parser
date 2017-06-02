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

```Haxe
class Domain {
    public static var icann:Recursive;
    public static function parse(domain:String):haxe.ds.Option<Array<DomainParts>>;
}
```
