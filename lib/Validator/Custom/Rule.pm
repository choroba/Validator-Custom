package Validator::Custom::Rule;
use Object::Simple -base;
use Carp 'croak';

has 'topic';
has 'rule' => sub { [] };
has 'validator';

sub array {
  my $self = shift;
  
  if (@_) {
    $self->topic->{array} = $_[0];
    return $self;
  }
  else {
    return $self->topic->{array};
  }
  
  return $self;
}

sub check_or {
  my ($self, @constraints) = @_;
  
  my $constraint_h = {};
  $constraint_h->{constraint} = \@constraints;
  
  my $cinfo = $self->validator->_parse_constraint($constraint_h);
  $cinfo->{array} = $self->topic->{array};
  
  $self->topic->{constraints} ||= [];
  push @{$self->topic->{constraints}}, $cinfo;
  
  return $self;
}

sub check {
  my ($self, @constraints) = @_;

  my $constraints_h = [];
  for my $constraint (@constraints) {
    my $constraint_h = {};
    if (ref $constraint eq 'ARRAY') {
      $constraint_h->{constraint} = $constraint->[0];
      $constraint_h->{message} = $constraint->[1];
    }
    else {
      $constraint_h->{constraint} = $constraint;
    }
    my $cinfo = $self->validator->_parse_constraint($constraint_h);
    $cinfo->{array} = $self->topic->{array};
    push @$constraints_h, $cinfo;
  }

  $self->topic->{constraints} ||= [];
  $self->topic->{constraints} = [@{$self->topic->{constraints}}, @{$constraints_h}];
  
  return $self;
}

sub copy {
  my ($self, $copy) = @_;
  
  $self->topic->{option}{copy} = $copy;
  
  return $self;
}

sub default {
  my ($self, $default) = @_;
  
  $self->topic->{option}{default} = $default;
  
  return $self;
}

sub message {
  my ($self, $message) = @_;
  
  my $constraints = $self->topic->{constraints} || [];
  for my $constraint (@$constraints) {
    $constraint->{message} ||= $message;
  }
  
  return $self;
}

sub name {
  my ($self, $result_key) = @_;
  
  my $key = $self->topic->{key};
  $self->topic->{key} = {$result_key => $key};
  
  return $self;
}

sub optional {
  my ($self, $key) = @_;

  # Create topic
  my $topic = {};
  $topic->{key} = $key;
  $self->topic($topic);
  
  # Value is optional
  $topic->{option}{require} = 0;
  
  # Add topic to rule
  push @{$self->rule}, $topic;
  
  return $self;
}

sub require {
  my ($self, $key) = @_;
  
  # Create topic
  my $topic = {};
  $topic->{key} = $key;
  $self->topic($topic);
  
  # Add topic to rule
  push @{$self->rule}, $topic;

  return $self;
}

sub parse {
  my ($self, $rule, $shared_rule) = @_;
  
  $shared_rule ||= [];
  
  my $normalized_rule = [];
  
  for (my $i = 0; $i < @{$rule}; $i += 2) {
    
    my $r = {};
    
    # Key, options, and constraints
    my $key = $rule->[$i];
    my $option = $rule->[$i + 1];
    my $constraints;
    if (ref $option eq 'HASH') {
      $constraints = $rule->[$i + 2];
      $i++;
    }
    else {
      $constraints = $option;
      $option = {};
    }
    my $constraints_h = [];
    
    if (ref $constraints eq 'ARRAY') {
      for my $constraint (@$constraints, @$shared_rule) {
        my $constraint_h = {};
        if (ref $constraint eq 'ARRAY') {
          $constraint_h->{constraint} = $constraint->[0];
          $constraint_h->{message} = $constraint->[1];
        }
        else {
          $constraint_h->{constraint} = $constraint;
        }
        push @$constraints_h, $self->validator->_parse_constraint($constraint_h);
      }
    } else {
      $constraints_h = {
        'ERROR' => {
          value => $constraints,
          message => 'Constraints must be array reference'
        }
      };
    }
    
    $r->{key} = $key;
    $r->{constraints} = $constraints_h;
    $r->{option} = $option;
    
    push @$normalized_rule, $r;
  }
  
  $self->rule($normalized_rule);
  
  return $self;
}

1;

=head1 NAME

Validator::Custom::Rule - Rule object

=head1 SYNOPSYS
  
  use Validator::Custom;
  my $vc = Validator::Custom->new;
  
  # Create rule object
  my $rule = $vc->create_rule;
  $rule->require('id')->check(
    'ascii'
  );
  $rule->optional('name')->check(
   'not_blank'
  );
  
  # Validate
  my $data = {id => '001', name => 'kimoto'};
  my $result = $vc->validate($data, $rule);
  
  # Option
  $rule->require('id')->default(4)->copy(0)->message('Error')->check(
    'not_blank'
  );

=head1 DESCRIPTION

Validator::Custom::Rule is the class to parse rule and store it as object.

=head1 ATTRIBUTES

=head2 rule

  my $content = $rule_obj->rule;
  $rule_obj = $rule->rule($content);

Content of rule object.

=head1 METHODS

=head2 array

  $rule->array(1);

Tell current topic data structure is array.

=head2 check

  $rule->check('not_blank')->check('ascii');

Add constraints to current topic.

=head2 check_or

  $rule->check_or('not_blank', 'ascii');

Add "or" condition constraints to current topic.

=head2 copy

  $rule->copy(0);

Set copy option

=head2 default

  $rule->default(0);

Set default option

=head2 message

  $rule->require('name')
    ->check('not_blank')->message('should be not blank')
    ->check('int')->message('should be int');

Set message for each check.

Message is fallback to before check
so you can write the following way.

  $rule->require('name')
    ->check('not_blank')
    ->check('int')->message('should be not blank and int');

=head2 name

  $rule->name('key1');

Set result key name

=head2 optional

  $rule->optional('id');

Set key and set require option to 0.

=head2 require

  $rule->require('id');
  $rule->require(['id1', 'id2']);

Set key.

=head2 parse

  $rule_obj = $rule_obj->parse($rule);

Parse rule and store it to C<rule> attribute.
