package STF::AdminWeb::Controller::Storage;
use strict;
use parent qw(STF::AdminWeb::Controller);
use STF::Utils;

sub load_storage {
    my ($self, $c) = @_;
    my $storage_id = $c->match->{storage_id};
    my $storage = $c->get('API::Storage')->lookup( $storage_id );
    if (! $storage) {
        $c->res->status(404);
        $c->abort;
    }
    $c->stash->{storage} = $storage;
    return $storage;
}

sub list {
    my ($self, $c) = @_;
    my $limit = $c->request->param('limit') || 100;
    my $pager = $c->pager( $limit );
    my @storages = $c->get( 'API::Storage' )->search(
        {},
        {
            limit    => $pager->entries_per_page + 1,
            offset   => $pager->skipped,
            order_by => { 'created_at' => 'DESC' },
        }
    );
    if ( @storages > $limit ) {
        $pager->total_entries( $limit * $pager->current_page + 1 );
        pop @storages;
    }
    my $stash = $c->stash;
    $stash->{storages} = \@storages;
    $stash->{pager} = $pager;
}

sub entities {
    my ($self, $c) = @_;

    my $storage_id = $c->match->{storage_id};

    my $storage = $self->load_storage($c);

    my $limit = 100;
    my $pager = $c->pager( $limit );
    my @entities = $c->get('API::Entity')->search_with_url(
        { storage_id => $storage_id },
        {
            offset   => $pager->skipped,
            limit    => $pager->entries_per_page + 1,
        }
    );
    if ( @entities > $limit ) {
        $pager->total_entries( $limit * $pager->current_page + 1 );
        pop @entities;
    }

    my $stash = $c->stash;
    $stash->{pager} = $pager;
    $stash->{entities} = \@entities;
}

sub add {}
sub add_post {
    my ($self, $c) = @_;

    my $params = $c->request->parameters->as_hashref;
    my $result = $self->validate( $c, storage_add => $params );
    if ($result->success) {
        my $valids = $result->valid;
        $c->get('API::Storage')->create( $valids );
        $c->redirect( $c->uri_for('/storage', {done => 1}) );
    } else {
        $c->stash->{template} = 'storage/add';
    }
}

sub edit {
    my ($self, $c) = @_;

    my $storage = $self->load_storage($c);
    $self->fillinform( $c, {
        %$storage,
        capacity => STF::Utils::human_readable_size( $storage->{capacity} )
    } );
}

sub edit_post {
    my ($self, $c) = @_;
    my $storage = $self->load_storage($c);

    my $params = $c->request->parameters->as_hashref;
    $params->{id} = $storage->{id};
    my $result = $self->validate( $c, storage_edit => $params );
    if ($result->success) {
        my $valids = $result->valid;
        delete $valids->{id};
        $c->get('API::Storage')->update( $storage->{id} => $valids );
        $c->redirect( $c->uri_for( "/storage/list", { done => 1 } ) );
    } else {
        $c->stash->{template} = 'storage/edit';
        $self->fillinform( $c, $params );
    }
}

sub delete_post {
    my ($self, $c) = @_;

    my $storage = $self->load_storage($c);
    my $params = { id => $storage->{id} };
    my $result = $self->validate( $c, storage_delete => $params );
    if ( $result->success ) {
        $c->get('API::Storage')->delete( $storage->{id} );
        $c->redirect( $c->uri_for( '/storage/list', {done => 1}) );
    } else {
        $c->stash->{template} = 'storage/edit';
        $self->fillinform( $c, $params );
    }
}

1;
