package ;

import utest.Assert;
import utest.Runner;
import haxe.ds.Option;
import utest.ui.Report;
import uhx.types.Domain.*;

using uhx.types.Domain;

@:keep class Main {

    public static function main() {
        var runner = new Runner();
        runner.addCase(new Main());
        Report.create(runner);
        runner.run();
    }

    public function new() {
        //trace( uhx.types.Domain.graph );
    }

    public function testUniversityOfOxford() {
        var values = 'www.ox.ac.uk'.parse();
        //trace(values);
        switch values {
            case Some(parts):
                Assert.equals( 3, parts.length );
                Assert.isTrue( parts[0].match(Subdomain(['www'])), 'Should be Subdomain containing `[www]`.' );
                Assert.isTrue( parts[1].match(Domain('ox')), 'Should be Domain name `ox`.' );
                Assert.isTrue( parts[2].match(Tld(['ac', 'uk'])), 'Should be Tld containing `[ac, uk]`.' );

            case None:
                Assert.fail('Result should not be empty.');

        }

    }

    public function testAwsS3() {
        var values = 'cdn.blah.com.s3.amazonaws.com'.parse();
        //trace( values );
        switch values {
            case Some(parts):
                Assert.equals( 3, parts.length );
                Assert.isTrue( parts[0].match(Subdomain(['cdn', 'blah', 'com', 's3'])), 'Should be Subdomain containing `[cdn, blah, com, s3]`.' );
                Assert.isTrue( parts[1].match(Domain('amazonaws')), 'Should be Domain name `amazonaws`.' );
                Assert.isTrue( parts[2].match(Tld(['com'])), 'Should be Tld containing `[com]`.' );

            case None:
                Assert.fail('Result should not be empty.');

        }
    }

    public function testChinaIDN_TLD() {
        var values = 'sub.random.中国'.parse();
        //trace( values );
        switch values {
            case Some(parts):
                Assert.equals( 3, parts.length );
                Assert.isTrue( parts[0].match(Subdomain(['sub'])), 'Should be Subdomain containing `[sub]`.' );
                Assert.isTrue( parts[1].match(Domain('random')), 'Should be Domain name `random`.' );
                Assert.isTrue( parts[2].match(Tld(['中国'])), 'Should be Tld containing `[中国]`.' );

            case None:
                Assert.fail('Result should not be empty.');
        }
    }

    public function testFetchChinaIDN_TLD() {
        var cn_idn = '中国';
        var cn_cc = 'cn';
        Assert.isTrue( Domain.exists(cn_cc),  'China\'s ccTLD should exist in the toplevel list.' );
        Assert.isTrue( Domain.exists(cn_idn), 'China\'s IDN ccTLD should exist in the toplevel list.' );
        var cn_idnNode = Domain.get(cn_idn);

        if (cn_idnNode != null) {
            Assert.isTrue(cn_idnNode.numArcs > 0, 'The IDN should not be empty.');
        } else {
            Assert.fail('The IDN map was empty.');
        }

        var cn_tldNode = Domain.get(cn_cc);
        
        if (cn_tldNode != null) {
            Assert.isTrue(cn_tldNode.numArcs > 0, 'The TLD should not be empty.');
        
        } else {
            Assert.fail('The TLD map was empty.');
            
        }

        for (n in cn_tldNode) {
            var g = @:privateAccess Domain.graph.findNode(n);
            Assert.isTrue( cn_idnNode.isConnected(g), '${n.val} should be connected to ${cn_idnNode.val.val}.' );

        }
    }

    public function testCustom() {
        var uri1 = 'sub.haxe.custom.*';
        var uri2 = 'www.haxe.org';
        var value1 = uri1.parse([s -> s == '*'], [s -> s == 'custom']);
        var value2 = uri2.parse([s -> s == '*'], [s -> s == 'custom']);
        //trace( value1 );
        //trace( value2 );
        switch value1 {
            case Some(parts):
                Assert.equals( 3, parts.length );
                Assert.isTrue( parts[0].match( Subdomain(['sub']) ) );
                Assert.isTrue( parts[1].match( Domain('haxe') ) );
                Assert.isTrue( parts[2].match( Tld(['custom', '*']) ) );

            case None:
                Assert.fail('The result should not be empty.');

        }
        
        switch value2 {
            case Some(parts):
                Assert.equals( 3, parts.length );
                Assert.isTrue( parts[0].match( Subdomain(['www']) ) );
                Assert.isTrue( parts[1].match( Domain('haxe') ) );
                Assert.isTrue( parts[2].match( Tld(['org']) ) );

            case None:
                Assert.fail('The result should not be empty.');

        }

    }

}