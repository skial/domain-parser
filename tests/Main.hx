package ;

import haxe.ds.Option;
import uhx.types.Domain.*;

using uhx.types.Domain;

class Main {

    public static function main() {
        trace( icann.exists('uk'), switch icann.get('uk') {
            case None: None;
            case Some(m): m;
        } );
        trace( 'www.ox.ac.uk'.parse() );
        trace( 'www.gov.uk'.parse() );
        trace( 'unknown.cc.ll'.parse() );
    }

}