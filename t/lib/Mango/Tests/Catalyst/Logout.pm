# $Id$
package Mango::Tests::Catalyst::Logout;
use strict;
use warnings;

BEGIN {
    use base 'Mango::Test::Class';

    use Test::More;
    use Path::Class ();
}

sub path {'logout'};

sub tests : Test(27) {
    my $self = shift;
    my $m = $self->client;

    ## not logged in
    $m->get_ok('http://localhost/');
    $self->validate_markup($m->content);
    $m->follow_link_ok({text => 'Login'});
    $m->title_like(qr/login/i);
    $m->content_unlike(qr/already logged in/i);
    $m->content_unlike(qr/welcome anonymous/i);
    ok(! $m->find_link(text => 'Logout'));
    $self->validate_markup($m->content);


    ## login
    $m->submit_form_ok({
        form_id => 'login',
        fields    => {
            username => 'admin',
            password => 'admin'
        }
    });
    $m->title_like(qr/login/i);
    $m->content_like(qr/login successful/i);
    $m->content_like(qr/welcome admin/i);
    ok(! $m->find_link(text => 'Login'));
    ok($m->find_link(text => 'Logout'));
    $self->validate_markup($m->content);


    ## no form, already logged in
    $m->reload;
    {
        local $SIG{__WARN__} = sub {};
        ok(! $m->form_with_fields(qw/username password/));
    };
    $m->title_like(qr/login/i);
    $m->content_like(qr/already logged in/i);
    ok($m->find_link(text => 'Logout'));
    $self->validate_markup($m->content);


    ## logout
    $m->follow_link_ok({text => 'Logout'});
    $m->content_like(qr/logout successful/i);
    $m->content_unlike(qr/welcome admin/i);
    ok($m->find_link(text => 'Login'));
    ok(! $m->find_link(text => 'Logout'));
    is($m->uri->path, '/' . $self->path . '/');
    $self->validate_markup($m->content);
};

sub tests_not_found : Test(2) {
    my $self = shift;
    my $m = $self->client;

    $m->get('http://localhost/logout/');

    if ($self->path eq 'logout') {
        is( $m->status, 200 );
    } else {
        is( $m->status, 404 );
    }
    $self->validate_markup($m->content);
}

1;