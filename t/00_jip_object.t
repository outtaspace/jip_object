#!/usr/bin/env perl

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use English qw(-no_match_vars);

plan tests => 1;

subtest 'Require some module' => sub {
    plan tests => 5;

    use_ok 'JIP::Object', '0.01';

    require_ok 'JIP::Object';
    is $JIP::Object::VERSION, '0.01';

    diag(
        sprintf 'Testing JIP::Object %s, Perl %s, %s',
            $JIP::Object::VERSION,
            $PERL_VERSION,
            $EXECUTABLE_NAME,
    );

    can_ok 'JIP::Object', qw(new attr method);

    isa_ok(JIP::Object->new, 'JIP::Object');
};

