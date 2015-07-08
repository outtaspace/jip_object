package JIP::Object;

use 5.006;
use strict;
use warnings;
use JIP::ClassField 0.04;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use English qw(-no_match_vars);

our $VERSION = '0.01';
our $AUTOLOAD;

has 'meta'  => (get => '-', set => '-');
has 'stash' => (get => '-', set => '-');

my $maybe_set_subname = sub { $ARG[1]; };

# Will be shipping with Perl 5.22
eval {
    require Sub::Util;

    if (my $set_subname = Sub::Util->can('set_subname')) {
        $maybe_set_subname = $set_subname;
    }
};

sub new {
    my $class = shift;

    croak q{Class already blessed} if blessed $class;

    return bless({}, $class)->_set_stash({})->_set_meta({});
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

sub AUTOLOAD {
    my ($self) = @ARG;

    croak q{Can't call "AUTOLOAD" as a class method} unless blessed $self;

    my ($package, $sub) = ($AUTOLOAD =~ m{^(.+)::([^:]+)$}x);
    undef $AUTOLOAD;

    if (defined(my $code = $self->_meta->{$sub})) {
        goto &$code;
    }
    else {
        croak(sprintf q{Can't locate object method "%s" in this instance}, $sub);
    }
}

JIP::ClassField::cleanup_namespace(qw(has croak blessed));

1;

