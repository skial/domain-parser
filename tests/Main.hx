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

    }

    public function testUniversityOfOxford() {
        var values = 'www.ox.ac.uk'.parse();

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

}