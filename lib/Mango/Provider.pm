# $Id$
package Mango::Provider;
use strict;
use warnings;

BEGIN {
    use base qw/Class::Accessor::Grouped/;
    use Class::Inspector ();
    use Scalar::Util ();
    use DateTime ();
    use Mango::Exception ();

    __PACKAGE__->mk_group_accessors('component_class', qw/result_class/);
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;

    $self->setup($args);

    return $self;
};

sub create {
    my ($self, $data) = @_;

    throw Mango::Exception('VIRTUAL_METHOD');
};

sub delete {
    my ($self, $filter) = @_;

    throw Mango::Exception('VIRTUAL_METHOD');
};

sub get_by_id {
    my $self = shift;
    my $object = shift;
    my $id = Scalar::Util::blessed($object) ? $object->id : $object ;

    return $self->search({id => $id}, @_)->first;
};

sub get_component_class {
    my ($self, $field) = @_;

    return $self->get_inherited($field);
};

sub set_component_class {
    my ($self, $field, $value) = @_;

    if ($value) {
        if (!Class::Inspector->loaded($value)) {
            eval "use $value"; ## no critic

            throw Mango::Exception('COMPCLASS_NOT_LOADED', $field, $value) if $@;
        };
    };

    $self->set_inherited($field, $value);

    return;
};

sub search {
    my ($self, $filter, $options) = @_;

    throw Mango::Exception('VIRTUAL_METHOD');
};

sub setup {
    my ($self, $args) = @_;

    if (ref $args eq 'HASH') {
        map {$self->$_($args->{$_})} keys %{$args};
    };

    return;
};

sub update {
    my ($self, $object) = @_;

    $object->updated(DateTime->now);

    throw Mango::Exception('VIRTUAL_METHOD');
};

1;
__END__

=head1 NAME

Mango::Provider - Provider base class

=head1 SYNOPSIS

    package MyApp::Provider::Users;
    use strict;
    use warnings;
    
    BEGIN {
        use base qw/Mango::Provider/;
    };
    __PACKAGE__->result_class('MyClass');
    
    my $object = $provider->create(\%data);

=head1 DESCRIPTION

Mango::Provider is a base abstract class for all providers used in Mango.

=head1 CONSTRUCTOR

=head2 new

=over

=item Arguments: \%options

=back

Creates a new provider object. If options are passed to new, those are
sent to C<setup>.

    my $provider = Mango::Provider->new({
        result_class => 'MyResultClass'
    });

The following options are available at the class level, to new/setup and take
the same data as their method counterparts:

    result_class

=head1 METHODS

=head2 create

=over

=item Arguments: \%data

=back

Creates a new result of type C<result_class> using the supplied data.

    my $object = $provider->create({
        id => 23,
        thingy => 'value'
    });

=head2 delete

=over

=item Arguments: \%filter

=back

Deletes objects from the store matching the supplied filter.

    $provider->delete({
        col => 'value'
    });

=head2 get_by_id

=over

=item Arguments: $id

=back

Retrieves an object from the provider matching the specified id.

    my $object = $provider->get_by_id(23);

Returns undef if no matching result can be found.

=head2 result_class

=over

=item Arguments: $class

=back

Gets/sets the name of the result class results should be returned as.

    $provider->result_class('MyClass');
    my $object = $provider->search->first;
    print ref $object; # MyClass

An exception will be thrown if the specificed class can not be loaded.

=head2 search

=over

=item Arguments: \%filter, \%options

=back

Returns a list of objects in list context, or a Mango::Iterator in scalar
context matching the specified filter.

    my @objects = $provider->search({
        col => 'value'
    });
    
    my $iterator = $provider->search({
        col => 'value'
    });

The list of supported options are at the disgression each individual provider.

=head2 setup

=over

=item Arguments: \%options

=back

Calls each key as a method with the supplied value. C<setup> is automatically
called by C<new>.

    my $provider = Mango::Provider->new({
        result_class => 'MyResultClass'
    });

This is the same as:

    my $provider = Mango::Provider->new;
    $provider->setup({
        result_class => 'MyResultClass'
    });

which is the same as:

    my $provider = Mango::Provider->new;
    $provider->result_class('MyResultClass');

=head2 update

=over

=item Arguments: $object

=back

Saves any changes made to the object back to the underlying store.

    my $object = $provider->create(\%data);
    $object->col('value');
    
    $provider->update($object);

=head1 SEE ALSO

L<Mango::Iterator>

=head1 AUTHOR

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/
