package uhx.types.domains;

enum DomainParts {
    Tld(parts:Array<String>);
    Domain(name:String);
    Subdomain(parts:Array<String>);
}