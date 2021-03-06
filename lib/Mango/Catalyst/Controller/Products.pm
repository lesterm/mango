# $Id$
package Mango::Catalyst::Controller::Products;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller/;
    use Mango                    ();
    use HTML::TagCloud::Sortable ();
    use Path::Class::Dir         ();
    use DateTime                 ();

    __PACKAGE__->config(
        resource_name => 'mango/products',
        form_directory =>
          Path::Class::Dir->new( Mango->share, 'forms', 'products' )
    );
}

sub instance : Chained('/') PathPrefix CaptureArgs(1) {
    my ( $self, $c, $sku ) = @_;
    my $product = $c->model('Products')->get_by_sku($sku);

    if ( defined $product ) {
        $c->stash->{'product'} = $product;
    } else {
        $c->response->status(404);
        $c->detach;
    }

    return;
}

sub view : Chained('instance') PathPart('') Args(0) Template('products/view')
{
    my ( $self, $c ) = @_;

    return;
}

sub list : Chained('/') PathPrefix Args(0) Template('products/list') {
    my ( $self, $c ) = @_;
    my $tags = $c->model('Products')->tags( {}, { order_by => 'tag.name' } );
    $c->stash->{'tags'} = $tags;

    my $tagcloud = HTML::TagCloud::Sortable->new;
    foreach my $tag ( $tags->all ) {
        $tagcloud->add(
            {
                name  => $tag->name,
                count => $tag->count,
                url   => $c->uri_for_resource(
                    'mango/products', 'tags', $tag->name
                  )
                  . '/'
            }
        );
    }
    $c->stash->{'tagcloud'} = $tagcloud;

    return;
}

sub tags : Local Template('products/list') Feed('Atom') Feed('RSS') {
    my ( $self, $c, @tags ) = @_;

    if ( !scalar @tags ) {
        return;
    }

    my $products = $c->model('Products')->search(
        { tags => \@tags },
        {
            page => $self->current_page,
            rows => $self->entries_per_page
        }
    );
    my $pager = $products->pager;

    if ( $self->wants_feed ) {
        $self->entity(
            {
                id => $c->uri_for_resource( 'mango/products', 'tags', @tags )
                  . '/',
                title => 'Products: ' . join( '. ', @tags ),
                link =>
                  $c->uri_for_resource( 'mango/products', 'tags', @tags )
                  . '/',
                author => $c->config->{'email'} . ' ('
                  . $c->config->{'name'} . ')',
                modified => DateTime->now,
                entries  => [
                    map {
                        {
                            id =>
                              $c->uri_for_resource( 'mango/products', 'view',
                                [ $_->sku ] )
                              . '/',
                            title => $_->name,
                            title => $_->sku,
                            link =>
                              $c->uri_for_resource( 'mango/products', 'view',
                                [ $_->sku ] )
                              . '/',
                            summary => $_->description,
                            content => $c->view('HTML')->render(
                                $c,
                                'products/feed',
                                {
                                    %{ $c->stash },
                                    product         => $_,
                                    DISABLE_WRAPPER => 1
                                }
                            ),
                            issued   => $_->created,
                            modified => $_->updated
                        }
                      } $products->all
                ]
            }
        );
        $c->detach;
    } else {
        $c->stash->{'products'} = $products;
        $c->stash->{'pager'}    = $pager;

        my $tags =
          $c->model('Products')
          ->related_tags( { tags => \@tags }, { order_by => 'tag.name' } );
        $c->stash->{'tags'} = $tags;

        my $tagcloud = HTML::TagCloud::Sortable->new;
        foreach my $tag ( $tags->all ) {
            $tagcloud->add(
                {
                    name  => $tag->name,
                    count => $tag->count,
                    url =>
                      $c->uri_for_resource( 'mango/products', 'tags', @tags,
                        $tag->name )
                      . '/'
                }
            );
        }
        $c->stash->{'tagcloud'} = $tagcloud;
    }

    return;
}

1;
__END__

=head1 NAME

Mango::Catalyst::Controller::Products - Catalyst controller for displaying
products.

=head1 SYNOPSIS

    package MyApp::Controller::Products;
    use base 'Mango::Catalyst::Controller::Products';

=head1 DESCRIPTION

Mango::Catalyst::Controller::products provides the web interface for
displaying products.

=head1 ACTIONS

=head2 instance : /products/<sku>/

Loads a specific product.

=head2 list : /products/

Lists featured products and the tag cloud.

=head2 tags : /products/tags/@tags

Displays a list of products belonging to the specified set of tags.

=head2 view : /products/<sku>/

Displays details about the specified product.

=head1 SEE ALSO

L<Mango::Catalyst::Model::Products>, L<Mango::Provider::Products>

=head1 AUTHOR

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/
