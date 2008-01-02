# $Id$
package Catalyst::Helper::Mango;
use strict;
use warnings;

BEGIN {
    use base qw/Catalyst::Helper/;
    use Catalyst::Utils;
    use DateTime;
    use Path::Class qw/file dir/;
    use YAML;
    use Mango::Schema;
};

=head1 NAME

Catalyst::Helper::Mango - Catalyst Helper for Mango applications

=head1 SYNOPSIS

    ## for a new application
    $ mango.pl MyApp
    
    ## in an existing Catalyst application
    $ cd MyApp
    $ script/myapp_create.pl Mango

=head1 DESCRIPTION

Creates a new Mango application, or adds a Mango application into an existing Catalyst application.

=head1 METHODS

=head2 mk_app

Creates the entire Mango application from scratch using mango.pl and the Catalyst mk_app (catalyst.pl).

=cut

sub mk_app {
    my ($self, $name) = @_;

    ## make the Catalyst app
    $self->SUPER::mk_app($name);

    ## make everything
    $self->mk_all;

    return;
};

=head2 mk_stuff

Adds the entire Mango application to an existing Catalyst application using C<myapp_create.pl Mango>.

=cut

sub mk_stuff {
    my ($self, $helper) = @_;
    my @app = (split(/\:\:/, $helper->{'app'}));

    $self = bless {%{$helper}}, ref $self || $self;
    $self->{'dir'} = '.';
    $self->{'app'} = dir(@app)->stringify;
    $self->{'mod'} = dir('lib', @app)->stringify;
    $self->{'name'} = $helper->{'app'};
    $self->{'appprefix'} = Catalyst::Utils::appprefix($helper->{'app'});
    $self->{'c'} = dir('lib', @app, 'Controller')->stringify;
    $self->{'m'} = dir('lib', @app, 'Model')->stringify;
    $self->{'v'} = dir('lib', @app, 'View')->stringify;

    ## make everything
    $self->mk_all;


    return $self;
};

=head2 mk_all

Creates the various Mango bits when called by mk_app or mk_stuff.

=cut

sub mk_all {
    my $self = shift;
    my $c = $self->{'c'};
    my $m = $self->{'m'};
    my $v = $self->{'v'};

    ## set defaults
    $self->{'adminuser'} ||= 'admin';
    $self->{'adminpass'} ||= 'admin';
    $self->{'adminrole'} ||= 'admin';

    ## add database
    $self->mk_database;

    ## inject plugins
    $self->mk_plugins;

    # add config
    $self->mk_config;

    ## add contollers/models/views
    $self->mk_models;
    $self->mk_views;
    $self->mk_controllers;

};

=head2 mk_database

Adds the data directory and mango.db SQLite database if they don't already exist.

=cut

sub mk_database {
    my $self = shift;
    my $dir = dir($self->{'dir'}, 'data');
    my $file = file($dir, 'mango.db');

    if (! -e $file) {
        $self->mk_dir($dir);
        my $adminuser = $self->{'adminuser'};
        my $adminpass = $self->{'adminpass'};
        my $adminrole = $self->{'adminrole'};

        my $schema = Mango::Schema->connect("dbi:SQLite:$file");
        $schema->deploy;
        print "created \"$file\"\n";

        $schema->resultset('Users')->create({
            id => 1,
            username => $adminuser,
            password => $adminpass,
            created => DateTime->now,
            updated => DateTime->now
        });
        print "created admin user/pass ($adminuser:$adminpass)\n";

        $schema->resultset('Roles')->create({
            id => 1,
            name => $adminrole,
            description => 'Administrators',
            created => DateTime->now,
            updated => DateTime->now
        });
        print "created admin role ($adminrole)\n";

        $schema->resultset('UsersRoles')->create({
            user_id => 1,
            role_id => 1
        });
    };

    return;
};

=head2 mk_plugins

Adds the necessary plugins into MyApp.pm 'use Catalyst' code.

=cut

sub mk_plugins {
    my $self = shift;
    my $file = file($self->{'mod'} . '.pm');
    my $contents = $file->slurp;

    if ($contents !~ /\+Mango::Catalyst::Plugin/i) {
        $contents =~ s/-Debug ConfigLoader/\n    -Debug\n    ConfigLoader\n    Session\n    Session::Store::File\n    Session::State::Cookie\n    Cache\n    Cache::Store::Memory\n    +Mango::Catalyst::Plugin::Application\n   /;

        my $io = $file->open('>');
        $io->print($contents);
        $io->close;
        undef $io;
    };

    return;
};

=head2 mk_config

Adds the necessary config changes to myapp.yml.

=cut

sub mk_config {
    my $self = shift;
    my $file = file($self->{'dir'}, $self->{'appprefix'} . '.yml');
    my $config = YAML::LoadFile($file);

    $config->{'authentication'} = {
        default_realm => 'mango',
        realms => {
            mango => {
                credential => {
                    class => 'Password',
                    password_field => 'password',
                    password_type => 'clear'
                },
                store => {
                    class => '+Mango::Catalyst::Plugin::Authentication::Store'
                },
            }
        }
    };
    $config->{'connection_info'} = ['dbi:SQLite:data/mango.db'];
    $config->{'default_view'} = 'XHTML';
    $config->{'authorization'}->{'mango'}->{'admin_role'} = $self->{'adminrole'};
    $config->{'cache'}->{'backend'}->{'store'} = 'Memory';

    YAML::DumpFile($file, $config);

    return;
};

=head2 mk_models

Adds the necessary models.

=cut

sub mk_models {
    my $self = shift;
    my $m = $self->{'m'};

    $self->render_file('model_carts',     file($m, 'Carts.pm'));
    $self->render_file('model_orders',    file($m, 'Orders.pm'));
    $self->render_file('model_products',  file($m, 'Products.pm'));
    $self->render_file('model_profiles',  file($m, 'Profiles.pm'));
    $self->render_file('model_roles',     file($m, 'Roles.pm'));
    $self->render_file('model_users',     file($m, 'Users.pm'));
    $self->render_file('model_wishlists', file($m, 'Wishlists.pm'));
};

=head2 mk_views

Adds the necessary views.

=cut

sub mk_views {
    my $self = shift;
    my $v = $self->{'v'};

    $self->render_file('view_atom',  file($v, 'Atom.pm'));
    $self->render_file('view_html',  file($v, 'HTML.pm'));
    $self->render_file('view_rss',   file($v, 'RSS.pm'));
    $self->render_file('view_text',  file($v, 'Text.pm'));
    $self->render_file('view_xhtml', file($v, 'XHTML.pm'));
};

=head2 mk_controllers

Adds the necessary controllers.

=cut

sub mk_controllers {
    my $self = shift;
    my $c = $self->{'c'};

    $self->mk_dir(dir($c, 'Admin'));
    $self->mk_dir(dir($c, 'Admin', 'Products'));
    $self->mk_dir(dir($c, 'REST'));

    ## root
    unlink file($c, 'Root.pm');
    $self->render_file('controller_root',
        file($c, 'Root.pm'));

    ## admin
    $self->render_file('controller_admin',
        file($c, 'Admin.pm'));
    $self->render_file('controller_admin_roles',
        file($c, 'Admin', 'Roles.pm'));
    $self->render_file('controller_admin_users',
        file($c, 'Admin', 'Users.pm'));
    $self->render_file('controller_admin_products',
        file($c, 'Admin', 'Products.pm'));
    $self->render_file('controller_admin_products_attributes',
        file($c, 'Admin', 'Products', 'Attributes.pm'));

    ## public
    $self->render_file('controller_cart',
        file($c, 'Cart.pm'));
    $self->render_file('controller_login',
        file($c, 'Login.pm'));
    $self->render_file('controller_logout',
        file($c, 'Logout.pm'));
    $self->render_file('controller_products',
        file($c, 'Products.pm'));
    $self->render_file('controller_users',
        file($c, 'Users.pm'));

    ## rest
};

=head1 SEE ALSO

L<Mango::Manual>

=head1 AUTHOR

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/

=cut

1;
__DATA__
__model_carts__
package [% name %]::Model::Carts;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Carts/;
};

1;
__model_orders__
package [% name %]::Model::Orders;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Orders/;
};

1;
__model_products__
package [% name %]::Model::Products;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Products/;
};

1;
__model_profiles__
package [% name %]::Model::Profiles;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Profiles/;
};

1;
__model_roles__
package [% name %]::Model::Roles;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Roles/;
};

1;
__model_users__
package [% name %]::Model::Users;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Users/;
};

1;
__model_wishlists__
package [% name %]::Model::Wishlists;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Model::Wishlists/;
};

1;
__view_atom__
package [% name %]::View::Atom;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::View::Atom/;
};

1;
__view_html__
package [% name %]::View::HTML;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::View::HTML/;
};

1;
__view_rss__
package [% name %]::View::RSS;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::View::RSS/;
};

1;
__view_text__
package [% name %]::View::Text;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::View::Text/;
};

1;
__view_xhtml__
package [% name %]::View::XHTML;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::View::XHTML/;
};

1;
__controller_root__
package [% name %]::Controller::Root;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Root/;
};

1;
__controller_cart__
package [% name %]::Controller::Cart;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Cart/;
};

1;
__controller_user_wishlists__
package [% name %]::Controller::User::Wishlists;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::User::Wishlists/;
};

1;
__controller_login__
package [% name %]::Controller::Login;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Login/;
};

1;
__controller_logout__
package [% name %]::Controller::Logout;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Logout/;
};

1;
__controller_products__
package [% name %]::Controller::Products;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Products/;
};

1;
__controller_users__
package [% name %]::Controller::Users;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Users/;
};

1;
__controller_admin__
package [% name %]::Controller::Admin;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Admin/;
};

1;
__controller_admin_roles__
package [% name %]::Controller::Admin::Roles;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Admin::Roles/;
};

1;
__controller_admin_users__
package [% name %]::Controller::Admin::Users;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Admin::Users/;
};

1;
__controller_admin_products__
package [% name %]::Controller::Admin::Products;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Admin::Products/;
};

1;
__controller_admin_products_attributes__
package [% name %]::Controller::Admin::Products::Attributes;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller::Admin::Products::Attributes/;
};

1;
