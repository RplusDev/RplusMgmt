package RplusMgmt::Controller::API::User;

use Mojo::Base 'Mojolicious::Controller';

use Rplus::Model::User;
use Rplus::Model::User::Manager;

sub list {
    my $self = shift;

    return $self->render(json => {error => 'Forbidden'}, status => 403) unless $self->has_permission(users => 'manage');

    my $res = {
        count => 0,
        list => [],
    };

    my $user_iter = Rplus::Model::User::Manager->get_objects_iterator(query => [delete_date => undef], sort_by => 'name');
    while (my $user = $user_iter->next) {
        my $x = {
            id => $user->id,
            login => $user->login,
            role => $user->role,
            role_loc => $self->ucfloc($user->role),
            name => $user->name,
            phone_num => $user->phone_num,
            description => $user->description,
            add_date => $self->format_datetime($user->add_date),
        };
        push @{$res->{list}}, $x;
    }

    $res->{count} = scalar @{$res->{list}};

    return $self->render(json => $res);
}

sub get {
    my $self = shift;

    return $self->render(json => {error => 'Forbidden'}, status => 403) unless $self->has_permission(users => 'manage');

    my $id = $self->param('id');

    my $user = Rplus::Model::User::Manager->get_objects(query => [id => $id, delete_date => undef])->[0];
    return $self->render(json => {error => 'Not Found'}, status => 404) unless $user;

    my $res = {
        id => $user->id,
        login => $user->login,
        role => $user->role,
        role_loc => $self->ucfloc($user->role),
        name => $user->name,
        phone_num => $user->phone_num,
        description => $user->description,
        add_date => $self->format_datetime($user->add_date),
        public_name => $user->public_name,
        public_phone_num => $user->public_phone_num,
    };

    return $self->render(json => $res);
}

sub save {
    my $self = shift;

    return $self->render(json => {error => 'Forbidden'}, status => 403) unless $self->has_permission(users => 'manage');

    # Retrieve user
    my $user;
    if (my $id = $self->param('id')) {
        $user = Rplus::Model::User::Manager->get_objects(query => [id => $id, delete_date => undef])->[0];
    } else {
        $user = Rplus::Model::User->new;
    }
    return $self->render(json => {error => 'Not Found'}, status => 404) unless $user;

    # Input validation
    $self->validation->required('login');
    $self->validation->required('role')->in(keys %{$self->config->{roles}});
    $self->validation->required('name');
    $self->validation->optional('phone_num')->is_phone_num;

    if ($self->validation->has_error) {
        my @errors;
        push @errors, {login => 'Invalid value'} if $self->validation->has_error('login');
        push @errors, {role => 'Invalid value'} if $self->validation->has_error('role');
        push @errors, {name => 'Invalid value'} if $self->validation->has_error('name');
        push @errors, {phone_num => 'Invalid value'} if $self->validation->has_error('phone_num');
        return $self->render(json => {errors => \@errors}, status => 400);
    }

    # Input params
    my $login = $self->param_n('login');
    my $password = $self->param_n('password');
    my $role = $self->param('role');
    my $name = $self->param_n('name');
    my $phone_num = $self->parse_phone_num(scalar $self->param('phone_num'));
    my $description = $self->param_n('description');
    my $public_name = $self->param_n('public_name');
    my $public_phone_num = $self->param_n('public_phone_num');

    # Save
    $user->login($login);
    $user->password($password) if $password;
    $user->role($role);
    $user->name($name);
    $user->phone_num($phone_num);
    $user->description($description);
    $user->public_name($public_name);
    $user->public_phone_num($public_phone_num);

    eval {
        $user->save($user->id ? (changes_only => 1) : (insert => 1));
        1;
    } or do {
        return $self->render(json => {error => $@}, status => 500);
    };

    return $self->render(json => {status => 'success', });
}

sub delete {
    my $self = shift;

    return $self->render(json => {error => 'Forbidden'}, status => 403) unless $self->has_permission(users => 'manage');

    my $id = $self->param('id');

    my $num_rows_updated = Rplus::Model::User::Manager->update_objects(
        set => {delete_date => \'now()'},
        where => [id => $id, delete_date => undef],
    );
    return $self->render(json => {error => 'Not Found'}, status => 404) unless $num_rows_updated;

    return $self->render(json => {status => 'success'});
}

1;