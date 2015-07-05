package JIP::Object;

use 5.006;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use English qw(-no_match_vars);

our $VERSION = '0.01';
our $AUTOLOAD;

sub new {
    my $class = shift;

    croak q{Class already blessed} if blessed($class);

    return bless({}, $class)->_set_stash({})->_set_meta({});
}

sub attr {
    my ($self, $attr, %param) = @ARG;

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

        $self->_meta->{$method_name} = sub {
            my $self = shift;
            return $self->_stash->{$attr};
        };
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

        $self->_meta->{$method_name} = sub {
            my ($self, $value) = @ARG;
            $self->_stash->{$attr} = $value;
            return $self;
        };
    }
}

sub method {
    my ($self, $method_name, $code) = @ARG;

    $self->_meta->{$method_name} = $code;
}

sub AUTOLOAD {
    my $self = shift;

    my ($package, $sub) = ($AUTOLOAD =~ m{^(.+)::([^:]+)$}x);
    undef $AUTOLOAD;

    croak(sprintf q{Can't locate object method "%s" via package "%s"}, $sub, $package)
        unless blessed($self);

    if (defined(my $code = $self->_meta->{$sub})) {
        $code->($self, @ARG);
    }
    else {
        croak(sprintf q{Can't locate object method "%s" in this instance}, $sub);
    }
}

# private methods
sub _stash {
    my $self = shift;
    return $self->{'stash'};
}

sub _set_stash {
    my ($self, $value) = @ARG;
    $self->{'stash'} = $value;
    return $self;
}

sub _meta {
    my $self = shift;
    return $self->{'meta'};
}

sub _set_meta {
    my ($self, $value) = @ARG;
    $self->{'meta'} = $value;
    return $self;
}

1;

