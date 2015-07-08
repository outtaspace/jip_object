#!/usr/bin/env perl

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use English qw(-no_match_vars);

plan tests => 7;

subtest 'Require some module' => sub {
    plan tests => 4;

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
};

subtest 'new()' => sub {
    plan tests => 2;

    eval { JIP::Object->new->new } or do {
        like $EVAL_ERROR, qr{^Class \s already \s blessed}x;
    };

    my $obj = JIP::Object->new;

    isa_ok $obj, qw(JIP::Object);
};

subtest 'attr()' => sub {
    plan tests => 14;

    eval { JIP::Object->attr } or do {
        like $EVAL_ERROR, qr{^Can't \s call \s "attr" \s as \s a \s class \s method}x;
    };

    my $obj = JIP::Object->new;

    eval { $obj->attr } or do {
        like $EVAL_ERROR, qr{^Attribute \s not \s defined}x;
    };
    eval { $obj->attr(q{}) } or do {
        like $EVAL_ERROR, qr{^Attribute \s not \s defined}x;
    };

    is $obj->attr(attr_1 => (get => q{-}, set => q{-}))->_set_attr_1(1)->_attr_1, 1;
    is $obj->attr(attr_2 => (get => q{+}, set => q{-}))->_set_attr_2(2)->attr_2,  2;
    is $obj->attr(attr_3 => (get => q{-}, set => q{+}))->set_attr_3(3)->_attr_3,  3;
    is $obj->attr(attr_4 => (get => q{+}, set => q{+}))->set_attr_4(4)->attr_4,   4;

    is $obj->attr(attr_5 => (get => q{getter}, set => q{setter}))->setter(5)->getter, 5;

    is $obj->attr(attr_6 => (
        get     => q{+},
        set     => q{+},
        default => q{default_value},
    ))->set_attr_6(42)->attr_6, '42';
    is $obj->set_attr_6(undef)->attr_6, undef;
    is $obj->set_attr_6->attr_6, q{default_value};

    is $obj->attr(attr_7 => (
        get     => q{+},
        set     => q{+},
        default => sub { shift->attr_6 },
    ))->set_attr_7(42)->attr_7, '42';
    is $obj->set_attr_7(undef)->attr_7, undef;
    is $obj->set_attr_7->attr_7, q{default_value};
};

subtest 'method()' => sub {
    plan tests => 6;

    eval { JIP::Object->method } or do {
        like $EVAL_ERROR, qr{^Can't \s call \s "method" \s as \s a \s class \s method}x;
    };

    my $obj = JIP::Object->new;

    eval { $obj->method(undef) } or do {
        like $EVAL_ERROR, qr{^First \s argument \s must \s be \s a \s non \s empty \s string}x;
    };
    eval { $obj->method(q{}) } or do {
        like $EVAL_ERROR, qr{^First \s argument \s must \s be \s a \s non \s empty \s string}x;
    };
    eval { $obj->method(q{foo}, undef) } or do {
        like $EVAL_ERROR, qr{^Second \s argument \s must \s be \s a \s code \s ref}x;
    };

    is ref($obj->method('foo', sub {
        pass 'foo() method is invoked';
    })), 'JIP::Object';

    $obj->foo;
};

subtest 'AUTOLOAD()' => sub {
    plan tests => 6;

    eval { JIP::Object->AUTOLOAD } or do {
        like $EVAL_ERROR, qr{^Can't \s call \s "AUTOLOAD" \s as \s a \s class \s method}x;
    };

    my $obj = JIP::Object->new->attr('foo', get => '+', set => '+')->set_foo(42);

    my $bar_result = $obj->method('bar', sub {
        my ($self, $param) = @ARG;

        is ref($self), 'JIP::Object';
        is $param, 'Hello';
        is $self->foo, 42;

        return 'tratata';
    })->bar('Hello');

    is $bar_result, 'tratata';

    eval { $obj->wtf } or do {
        like $EVAL_ERROR, qr{
            ^
            Can't \s locate \s object \s method \s "wtf"
            \s in \s this \s instance
        }x;
    };
};

subtest 'The Universal class' => sub {
    plan tests => 6;

    my $obj = JIP::Object->new;

    is $obj->VERSION, '0.01';

    ok $obj->isa('JIP::Object');
    ok not $obj->isa('JIP::ClassField');

    is $obj->DOES('JIP::Object'),     $obj->isa('JIP::Object');
    is $obj->DOES('JIP::ClassField'), $obj->isa('JIP::ClassField');

    is ref $obj->can('new'), 'CODE';
};

subtest 'cleanup_namespace()' => sub {
    plan tests => 3;

    ok(not JIP::Object->can('has'));
    ok(not JIP::Object->can('croak'));
    ok(not JIP::Object->can('blessed'));
};

