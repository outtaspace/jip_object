package JIP::Object;

use 5.006;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use English qw(-no_match_vars);

our $VERSION = '0.01';
our $AUTOLOAD;

my $maybe_set_subname = sub { $ARG[1]; };

# Will be shipping with Perl 5.22
eval {
    require Sub::Util;

    if (my $set_subname = Sub::Util->can('set_subname')) {
        $maybe_set_subname = $set_subname;
    }
};

sub new {
    my ($class, %param) = @ARG;

    croak q{Class already blessed} if blessed $class;

    my $proto;
    if (exists $param{'proto'}) {
        $proto = $param{'proto'};

        croak q{Bad argument "proto"}
            unless (blessed $proto || q{}) eq __PACKAGE__;
    }

    return bless({}, $class)
        ->_set_stash({})
        ->_set_meta({})
        ->set_proto($proto);
}

sub attr {
    my ($self, $attr, %param) = @ARG;

    croak q{Can't call "attr" as a class method} unless blessed $self;

    croak q{Attribute not defined} unless defined $attr and length $attr;

    if (exists $param{'get'}) {
        my ($method_name, $getter) = (q{}, $param{'get'});

        if ($getter eq q{+}) {
            $method_name = $attr;
        }
        elsif ($getter eq q{-}) {
            $method_name = q{_}. $attr;
        }
        else {
            $method_name = $getter;
        }

        $self->_meta->{$method_name} = $maybe_set_subname->($method_name, sub {
            my $self = shift;
            return $self->_stash->{$attr};
        });
    }

    if (exists $param{'set'}) {
        my ($method_name, $setter) = (q{}, $param{'set'});

        if ($setter eq q{+}) {
            $method_name = q{set_}. $attr;
        }
        elsif ($setter eq q{-}) {
            $method_name = q{_set_}. $attr;
        }
        else {
            $method_name = $setter;
        }

        if (exists $param{'default'}) {
            my $default_value = $param{'default'};

            $self->_meta->{$method_name} = $maybe_set_subname->($method_name, sub {
                my $self = shift;

                if (@ARG == 1) {
                    $self->_stash->{$attr} = shift;
                }
                elsif (ref $default_value eq 'CODE') {
                    $self->_stash->{$attr} = $maybe_set_subname->(
                        'default_value',
                        $default_value,
                    )->($self);
                }
                else {
                    $self->_stash->{$attr} = $default_value;
                }

                return $self;
            });
        }
        else {
            $self->_meta->{$method_name} = $maybe_set_subname->($method_name, sub {
                my ($self, $value) = @ARG;
                $self->_stash->{$attr} = $value;
                return $self;
            });
        }
    }

    return $self;
}

sub method {
    my ($self, $method_name, $code) = @ARG;

    croak q{Can't call "method" as a class method}
        unless blessed $self;

    croak q{First argument must be a non empty string}
        unless defined $method_name and length $method_name;

    croak q{Second argument must be a code ref}
        unless ref($code) eq 'CODE';

    $self->_meta->{$method_name} = $maybe_set_subname->($method_name, $code);

    return $self;
}

sub own_method {
    my ($self, $method_name) = @ARG;

    return unless exists $self->_meta->{$method_name};

    return $self->_meta->{$method_name};
}

# http://perldoc.perl.org/perlobj.html#Default-UNIVERSAL-methods
sub isa {
    no warnings 'misc';
    goto &UNIVERSAL::isa;
}

sub DOES {
    # DOES is equivalent to isa by default
    goto &isa;
}

sub VERSION {
    no warnings 'misc';
    goto &UNIVERSAL::VERSION;
}

sub can {
    my ($self, $method_name) = @ARG;

    if (blessed $self) {
        no warnings 'misc';
        goto &UNIVERSAL::can;
    }
    else {
        my $code;
        no warnings 'misc';
        $code = UNIVERSAL::can($self, $method_name);

        return $code;
    }
}

sub DESTROY {}

sub AUTOLOAD {
    my ($self) = @ARG;

    croak q{Can't call "AUTOLOAD" as a class method} unless blessed $self;

    my ($package, $method_name) = ($AUTOLOAD =~ m{^(.+)::([^:]+)$}x);
    undef $AUTOLOAD;

    if (defined(my $code = $self->own_method($method_name))) {
        goto &$code;
    }
    elsif (defined(my $proto = $self->proto)) {
        shift @ARG;
        $proto->$method_name(@ARG);
    }
    else {
        croak(sprintf q{Can't locate object method "%s" in this instance}, $method_name);
    }
}

# private methods
sub proto {
    return $ARG[0]->{'proto'};
}
sub set_proto {
    $ARG[0]->{'proto'} = $ARG[1];
    return $ARG[0];
}

sub _meta {
    return $ARG[0]->{'meta'};
}
sub _set_meta {
    $ARG[0]->{'meta'} = $ARG[1];
    return $ARG[0];
}

sub _stash {
    return $ARG[0]->{'stash'};
}
sub _set_stash {
    $ARG[0]->{'stash'} = $ARG[1];
    return $ARG[0];
}

1;

__END__

=head1 NAME

JIP::Object - A simple object system.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use Test::More;
    use JIP::Object;

    my $obj = JIP::Object->new;
    ok $obj, 'got object';

    # Public access to the "foo"
    $obj->attr('foo', (get => '+', set => '+'));
    is($obj->set_foo(42)->foo, 42);

    # Private access to the "bar"
    $obj->attr('bar', (get => '-', set => '-'));
    is($obj->_set_bar(42)->_bar, 42);

    # Create user-defined names for getters/setters
    $obj->attr('wtf' => (get => 'wtf_getter', set => 'wtf_setter'));
    is($obj->wtf_setter(42)->wtf_getter, 42);

    # Pass an optional first argument of setter to set
    # a default value, it should be a constant or callback.
    $obj->attr('baz' => (get => '+', set => '+', default => 42));
    is($self->set_baz->baz, 42);

    $obj->attr('qux' => (get => '+', set => '+', default => sub {
        my $self = shift;
        return $self->baz;
    }));
    is($self->set_qux->qux, 42);

    # Define a new method
    $obj->method('say_foo', sub {
        my $self = shift;
        print $self->foo, "\n";
    });

    done_testing();

=head1 METHODS

=head2 new

    my $obj = JIP::Object->new;
    my $obj = JIP::Object->new(proto => JIP::Object->new);;

Construct a new L<JIP::Object> object.

=head2 attr

    $obj = $obj->attr('x', get => 'x', set => 'set_x');

Define a new property.

=head2 method

    $obj = $obj->method('get_x', sub {
        my $self = shift;
        return $self->x;
    });

Define a new method.

=head2 proto

A getter function.

=head2 set_proto

A setter function.

=head2 own_method

    $code = $obj->own_method('string value of a method name');

The own_method returns CODE if object has a method of the specified name, undef if it does not.

=head1 SEE ALSO

Mock::Quick::Object.

=head1 AUTHOR

Vladimir Zhavoronkov, C<< <flyweight at yandex.ru> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Vladimir Zhavoronkov.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut


