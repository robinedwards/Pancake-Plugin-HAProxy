package Pancake::Plugin::HAProxy;
use Moose;
extends 'Pancake::Plugin';
use JSON;
use Net::HAProxy;
use List::Util 'first';
use Plack::Request;
use namespace::autoclean;

has '+name'     => (default => 'haproxy');
has socket      => (is => 'ro', isa => 'Str', required => 1);
has haproxy     => (is => 'ro', isa => 'Net::HAProxy', lazy_build => 1);

sub BUILD { shift->haproxy }

sub _build_haproxy { Net::HAProxy->new(socket => $_[0]->socket) }

sub dispatch_request {
    my ($self, $service, $env) = @_;

    my $r = Plack::Request->new($env);

    return (
        '/enable_server'  => sub { $self->enable_server($r)  },
        '/disable_server' => sub { $self->disable_server($r) },
        '/stats'          => sub { $self->stats($r)          },
        '/info'           => sub { $self->info($r)           },
    );
}

sub enable_server {
    my ($self, $r) = @_;

    die "missing parameter pxname" unless length ($r->param('pxname'));
    die "missing parameter svname" unless length ($r->param('svname'));

    $self->haproxy->enable_server(
        $r->param('pxname'),
        $r->param('svname'),
    );

    [ 200, ['Content-Type' => 'text/html'], ['OK'] ];
}

sub disable_server {
    my ($self, $r) = @_;

    die "Missing parameter pxname" unless length ($r->param('pxname'));
    die "Missing parameter svname" unless length ($r->param('svname'));

    $self->haproxy->disable_server(
        $r->param('pxname'),
        $r->param('svname'),
    );

    [ 200, ['Content-Type' => 'text/html'], ['OK'] ];
}

sub stats {
    my ($self, $r) = @_;

    my $res;

    if (length($r->param('svname')) && length($r->param('pxname'))) {

        $res = first {
            $_->{svname} eq $r->param('svname') && $_->{pxname} eq $r->param('pxname')
        } @{$self->haproxy->stats};
    }
    elsif ( length($r->param('svname')) xor length($r->param('pxname'))) {
        die "Please provide both svname and pxname";
    }
    else {
        my $p = {};

        for (qw/iid sid type/) {
            $p->{$_} = $r->param($_) if defined $r->param($_)
        }

        $res = $self->haproxy->stats($p)
    }

    [ 200, ['Content-Type' => 'application/json'], [ $self->json_view($res) ] ];
}

sub info {
    my ($self) = @_;
    [ 200, ['Content-Type' => 'application/json'], [ $self->json_view(shift->haproxy->info) ] ];
}

__PACKAGE__->meta->make_immutable;

1;
