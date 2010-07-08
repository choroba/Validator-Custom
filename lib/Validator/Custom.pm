package Validator::Custom;

use strict;
use warnings;

use base 'Object::Simple';

use Carp 'croak';
use Validator::Custom::Result;

__PACKAGE__->dual_attr('constraints', default => sub { {} },
                                      inherit => 'hash_copy');
__PACKAGE__->attr('rule');
__PACKAGE__->attr(shared_rule => sub { [] });
__PACKAGE__->attr(error_stock => 1);
__PACKAGE__->attr('data_filter');
__PACKAGE__->attr(syntax => <<'EOS');


### Syntax of validation rule
    my $rule = [                          # 1. Rule is array ref
        key1 => [                         # 2. Constraints is array ref
            'constraint1_1',              # 3. Constraint is string
            ['constraint1_2', 'error1_2'],#      or arrya ref (message)
            {'constraint1_3' => 'string'} #      or hash ref (arguments)
              
        ],
        key2 => [
            {'constraint2_1'              # 4. Argument is string
              => 'string'},               #
            {'constraint2_2'              #     or array ref
              => ['arg1', 'arg2']},       #
            {'constraint1_3'              #     or hash ref
              => {k1 => 'v1', k2 => 'v2'}}#
        ],
        key3 => [                           
            [{constraint3_1 => 'string'}, # 5. Combination argument
             'error3_1' ]                 #     and message
        ],
        { key4 => ['key4_1', 'key4_2'] }  # 6. Corelative validation
            => [
                'constraint4_1'
               ],
        key5 => [
            '@constraint5_1'              # 7. Multi-values validation
        ]
    ];

EOS

sub register_constraint {
    my $invocant = shift;
    
    # Merge
    my $constraints = ref $_[0] eq 'HASH' ? $_[0] : {@_};
    $invocant->constraints({%{$invocant->constraints}, %$constraints});
    
    return $invocant;
}

sub validate {
    my ($self, $data, $rule) = @_;
    
    # Class
    my $class = ref $self;
    
    # Validation rule
    $rule ||= $self->rule;
    
    # Shared rule
    my $shared_rule = $self->shared_rule;
    
    # Data filter
    my $filter = $self->data_filter;
    $data = $filter->($data) if $filter;
    
    # Check data
    croak "First argument must be hash ref"
      unless ref $data eq 'HASH';
    
    # Check rule
    croak "Validation rule must be array ref\n" .
          "(see syntax of validation rule 1)\n" .
          $self->_rule_syntax($rule)
      unless ref $rule eq 'ARRAY';
    
    # Result
    my $result = Validator::Custom::Result->new;

    # Save raw data
    $result->raw_data($data);
    
    # Error is stock?
    my $error_stock = $self->error_stock;
    
    # Valid keys
    my $valid_keys = {};
    
    # Error position
    my $position = 0;
    
    # Process each key
    OUTER_LOOP:
    for (my $i = 0; $i < @{$rule}; $i += 2) {
        
        # Increment position
        $position++;
        
        # Key and constraints
        my ($key, $constraints) = @{$rule}[$i, ($i + 1)];
        
        # Check constraints
        croak "Constraints of validation rule must be array ref\n" .
              "(see syntax of validation rule 2)\n" .
              $self->_rule_syntax($rule)
          unless ref $constraints eq 'ARRAY';
        
        # Arrange key
        my $result_key = $key;
        if (ref $key eq 'HASH') {
            my $first_key = (keys %$key)[0];
            $result_key = $first_key;
            $key         = $key->{$first_key};
        }
        elsif (ref $key eq 'ARRAY') {
            $result_key = "$key";
        }
        
        # Already valid
        next if $valid_keys->{$result_key};
        
        # Add shared rule
        push @$constraints, @$shared_rule;
        
        # Validation
        my $value;
        foreach my $constraint (@$constraints) {
            
            # Arrange constraint information
            my ($constraint, $message)
              = ref $constraint eq 'ARRAY' ? @$constraint : ($constraint);
            
            # Data type
            my $data_type = {};
            
            # Arguments
            my $arg;
            
            # Arrange constraint
            if(ref $constraint eq 'HASH') {
                my $first_key = (keys %$constraint)[0];
                $arg        = $constraint->{$first_key};
                $constraint = $first_key;
            }
            
            # Constraint function
            my $constraint_function;
            
            # Sub reference
            if( ref $constraint eq 'CODE') {
                
                # Constraint function
                $constraint_function = $constraint;
            }
            
            # Constraint key
            else {
                
                # Array constraint
                if($constraint =~ /^\@(.+)$/) {
                    $data_type->{array} = 1;
                    $constraint = $1;
                }
                
                # Check constraint key
                croak "Constraint type '$constraint' must be [A-Za-z0-9_]"
                  if $constraint =~ /\W/;
                
                # Constraint function
                $constraint_function = $self->constraints->{$constraint};
                
                # Check constraint function
                croak "'$constraint' is not registered"
                  unless ref $constraint_function eq 'CODE'
            }
            
            # Is valid?
            my $is_valid;
            
            # Data is array
            if($data_type->{array}) {
                
                # Set value
                unless (defined $value) {
                    $value = ref $data->{$key} eq 'ARRAY' 
                           ? $data->{$key}
                           : [$data->{$key}]
                }
                
                # Validation loop
                my $elements;
                foreach my $data (@$value) {
                    
                    # Array element
                    my $element;
                    
                    # Validation
                    my $constraint_result
                      = $constraint_function->($data, $arg, $self);
                    
                    # Constrint result
                    if (ref $constraint_result eq 'ARRAY') {
                        ($is_valid, $element) = @$constraint_result;
                        
                        $elements ||= [];
                        push @$elements, $element;
                    }
                    else {
                        $is_valid = $constraint_result;
                    }
                    
                    # Validation error
                    last unless $is_valid;
                }
                
                # Update value
                $value = $elements if $elements;
            }
            
            # Data is scalar
            else {
                
                # Set value
                $value = ref $key eq 'ARRAY'
                       ? [map { $data->{$_} } @$key]
                       : $data->{$key}
                  unless defined $value;
                
                # Validation
                my $constraint_result
                  = $constraint_function->($value, $arg, $self);
                
                if (ref $constraint_result eq 'ARRAY') {
                    ($is_valid, $value) = @$constraint_result;
                }
                else {
                    $is_valid = $constraint_result;
                }
            }
            
            # Add error if it is invalid
            unless ($is_valid) {
                
                # Resist error info
                $result->add_error_info(
                    $result_key => {message      => $message,
                                    position     => $position,
                                    reason       => $constraint,
                                    original_key => $key})
                  unless exists $result->error_infos->{$result_key};
                
                # No Error strock
                unless ($error_stock) {
                    # Check rest constraint
                    my $found;
                    for (my $k = $i + 2; $k < @{$rule}; $k += 2) {
                        my $key = $rule->[$k];
                        $key = (keys %$key)[0] if ref $key eq 'HASH';
                        $found = 1 if $key eq $result_key;
                    }
                    last OUTER_LOOP unless $found;
                }
                next OUTER_LOOP;
            }
        }
        
        # Result data
        $result->data->{$result_key} = $value;
        
        # Key is valid
        $valid_keys->{$result_key} = 1;
        
        # Remove invalid key
        $result->remove_error_info($result_key);
    }
    
    return $result;
}

sub _rule_syntax {
    my ($self, $rule) = @_;
    
    my $message = $self->syntax;
    
    require Data::Dumper;
    $message .= "### Your validation rule:\n";
    $message .= Data::Dumper->Dump([$rule], ['$rule']);
    $message .= "\n";
    return $message;
}

=head1 NAME

Validator::Custom - Validates user input easily

=cut

our $VERSION = '0.1204';

=head1 SYNOPSYS
    
    # Load module and create object
    use Validator::Custom;
    my $vc = Validator::Custom->new;

    # Data used at validation
    my $data = {age => 19, name => 'Ken Suzuki'};
    
    # Register constraint
    $vc->register_constraint(
        int => sub {
            my $value    = shift;
            my $is_valid = $value =~ /^\d+$/;
            return $is_valid;
        },
        not_blank => sub {
            my $value = shift;
            my $is_valid = $value ne '';
            return $is_valid;
        },
        length => sub {
            my ($value, $args) = @_;
            my ($min, $max) = @$args;
            my $length = length $value;
            my $is_valid = $length >= $min && $length <= $max;
            return $is_valid;
        },
    );
    
    # Rule
    my $rule = [
        age => [
            'int'
        ],
        name => [
            ['not_blank',        "Name must be exists"],
            [{length => [1, 5]}, "Name length must be 1 to 5"]
        ]
    ];
    
    # Validate
    my $vresult = $vc->validate($data, $rule);
    
    ### Validator::Custom::Result
    
    # Chacke if the data is valid.
    my $is_valid = $vresult->is_valid;
    
    # Error messages
    my $messages = $vresult->messages;

    # Error messages to hash ref
    my $messages_hash = $vresult->messages_to_hash;
    
    # Error message
    my $message = $vresult->message('age');
    
    # Invalid parameter names
    my $invalid_params = $vresult->invalid_params;
    
    # Invalid rule keys
    my $invalid_rule_keys = $vresult->invalid_rule_keys;
    
    # Raw data
    my $raw_data = $vresult->raw_data;
    
    # Result data
    my $result_data = $vresult->data;
    
    ### Advanced featreus

    # Corelative validation
    $data = {password1 => 'xxx', password2 => 'xxx'};
    $vc->register_constraint(
        same => sub {
            my $values = shift;
            my $is_valid = $values->[0] eq $values->[1];
            return [$is_valid, $values->[0]];
        }
    );
    $rule = [
        {password_check => [qw/password1 password2/]} => [
            ['same', 'Two password must be equal']
        ]
    ];
    $vresult = $vc->validate($data, $rule);

    # "OR" validation
    $rule = [
        email => [
            'blank'
        ],
        email => [
            'not_blank',
            'emai_address'
        ]
    ];

    # Data filter
    $vc->data_filter(
        sub { 
            my $data = shift;
            
            # Convert data to hash reference
            
            return $data;
        }
    );
            
    # Register filter , instead of constraint
    $vc->register_constraint(
        trim => sub {
            my $value = shift;
            
            $value =~ s/^\s+//;
            $value =~ s/\s+$//;
            
            return [1, $value];
        }
    );
    
    ### Extending Validator:Custom
    
    package YourValidator;
    use base 'Validator::Custom';
    
    __PACKAGE__->register_constraint(
        defined  => sub { defined $_[0] }
    );
    
    1;

=head1 DESCRIPTIONS

L<Validator::Custom> validates user input easily.
and it is easy to create your class extending Validator::Custom.
(See L<Validator::Custom::HTMLForm>)

The syntax of validation is understandable and the rule can have message.
Validation result keeps the order of invalid parameter names.
and has friendly methods.

In advanced featrues, you can register filter(such as triming space),
and validate "OR" condition.

=head2 C<1. Basic usage>

At first, you load module and create object by B<new()>.

    use Validator::Custom;
    my $vc = Validator::Custom->new;

B<Data> used in validation must be hash reference.

    my $data = { 
        age => 19, 
        name => 'Ken Suzuki'
    };

you can register constraint by B<register_constraint()>.
constraint is sub reference to check if the value is valid.

    $vc->register_constraint(
        int => sub {
            my $value    = shift;
            my $is_valid = $value =~ /^\d+$/;
            return $is_valid;
        },
        not_blank => sub {
            my $value = shift;
            my $is_valid = $value ne '';
            return $is_valid;
        },
        length => sub {
            my ($value, $args) = @_;
            my ($min, $max) = @$args;
            my $length = length $value;
            my $is_valid = $length >= $min && $length <= $max;
            return $is_valid;
        },
    );

You have to define B<rule> for validation,
using I<key of data>, I<constraint name>, and I<message>.
Rule must be array reference>.

    my $rule = [
        age => [
            'int'
        ],
        name => [
            ['not_blank',        "Name must be exists"],
            [{length => [1, 5]}, "Name length must be 1 to 5"]
        ]
    ];

B<validate()> is validation method. you can validate the data by the rule.
this return L<Validator::Custom::Result> object.

    my $vresult = $vc->validate($data, $rule);

=head2 C<2. Validation result>

L<Validator::Custom::Result> object has the result of validation.
You can get various information by these methods.
    
    # Chacke if the date is valid.
    my $is_valid = $vresult->is_valid;
    
    # Error messages
    my $messages = $vresult->messages;

    # Error messages to hash ref
    my $messages_hash = $vresult->messages_to_hash;
    
    # A error message
    my $message = $vresult->message('age');
    
    # Invalid parameter names
    my $invalid_params = $vresult->invalid_params;
    
    # Invalid rule keys
    my $invalid_rule_keys = $vresult->invalid_rule_keys;
    
    # Raw data
    my $raw_data = $vresult->raw_data;
    
    # Result data
    my $result_data = $vresult->data;

Following examples show Validator::Custom::Result generally usage.

B<Example1:> Check the result and get error messages.

    unless ($vresult->is_valid) {
        my $messages = $vresult->messages;
        
        # Do something
    }

B<Example2:> Chack the result and get error messages as hash reference

    unless ($vresult->is_valid) {
        my $messages = $vresult->messages_to_hash;

        # Do something
    }

B<Example3:> Combination with L<HTML::FillInForm>

    unless ($vresult->is_valid) {
        
        my $html = get_something_way();
        
        # Fill in form
        $html = HTML::FillInForm->fill(
            \$html, $vresult->raw_data,
            ignore_fields => $vresult->invalid_params
        );
        
        # Do something
    }

=head2 C<3. Syntax of rule>

B<Rule> must be array reference. This is for keeping the order of
invalid parameter names.

    my $rule = [
    
    ];

Rule contains the pairs of B<parameter name> and B<constraint list>.
constraint list must be array reference even if constraint name is one.

    my $rule = [
        name => [
            'not_blank'
        ],
        age => [
            'not_blank',
            'int'
        ]
    ];

Constraint list contains B<constraint expression>.
constraint expression is one of I<1. constraint name>,
I<2. constraint name and message>, I<3. constraint name and argument>
I<4. constraint name and argument and message>,

    my $rule = [
        age => [
            # 1. constraint name
            'defined',
            
            # 2. constraint name and message
            ['not_blank', 'Must be not blank'],
            
            # 3. constraint name and argument
            {length => [1, 5]},
            
            # 4. constraint name and argument and message
            [{regex => qr/\d+/}, 'Invalid string']
    ];

B<Corelative validation> is available.

    $data = {password1 => 'xxx', password2 => 'xxx'};

    $rule = [
        {password_check => [qw/password1 password2/]} => [
            ['duplication', 'Two password must be equal']
        ]
    ];

In this example, "password1" and "password2" is parameter names.
"password_check" is result key. You must specify result key.

You can B<Multi-values validation> when the values in data is
array reference. B<@> mark is added to constraint name.

    $data = {
        nums => [1, 2, 3]
    };
    
    $rule = [
        'nums' => [
            '@int'
        ]
    ];

This module provides B<"OR" validation>.
In "OR" valdation, parameter name is written repeatedly.

    $rule = [
        email => [
            'blank'
        ],
        email => [
            'not_blank',
            'emai_address'
        ]
    ];

(experimental feature). If you share some rule,
you can use B<shared_rule>. Shared rule is added to the
head of each constraint expression.

    $vc->shared_rule([
        ['defined',   'Must be defined'],
        ['not_blank', 'Must be not blank']
    ]);


=head2 C<4. Specification of constraint>

I explain the specification of constraint.

Constraint function receive three arguments,
I<1. value>, I<2. argument>, I<3. Validator::Custom object>.

And this function must return value to check if the value is valid.

    # Register constraint
    $vc->register_constraint(
        consrtaint_name => sub {
            my ($value, $args, $vc) = @_;
            
            # Do something
            
            return $is_valid;
        }
    )

B<Three argument details:>

=over 4

=item C<1. value>

This is the value of data.

    my $data = {name => 'Ken Suzuki'};

In this example, value is I<'Ken Suzuki'>

=item C<2. argument>

You can pass argument to consraint in the rule.

    my $rule = [
        name => [
            {length => [1, 5]}
        ]
    ];
In this example, argument is I<[1, 5]>.

=item C<3. Validator::Custom::Object>

This is Validator::Custom::Object.

=back

In B<corelative validation>, values is packed to array reference,
I<value> is ['xxx', 'xxx'].

    $data = {password1 => 'xxx', password2 => 'xxx'};

    $rule = [
        {password_check => [qw/password1 password2/]} => [
            ['duplication', 'Two password must be equal']
        ]
    ];

Constraint function can be also return B<converted value>. If you return converted value, you must return array reference, which contains two
element, I<value to check if the value is valid>,
and B<converted value>.

    $vc->register_constraint(
        trim => sub {
            my $value = shift;
            
            $value =~ s/^\s+//;
            $value =~ s/\s+$//;
            
            return [1, $value];
        }
    );

=head2 C<5. Extend Validator::Custom>

Validator::Custom is easy to extend. You can register constraint
to Your class by B<register_constraint()>.
    
    package YourValidator;
    use base 'Validator::Custom';
    
    __PACKAGE__->register_constraint(
        defined  => sub { defined $_[0] }
    );
    
    1;
    

L<Validator::Custom::Trim>, L<Validator::Custom::HTMLForm> is good examples.

=head2 C<6. Advanced features>

If data is not hash reference, you can converted data to hash reference
by B<data_filter()>.

    $vc->data_filter(
        sub { 
            my $data = shift;
            
            # Convert data to hash reference
            
            return $data;
        }
    );

By default, all parameters is checked by validate(). If you want to
check only if the data is valid, it is good to finish validation when
the invalid value is found. If you set B<error_stock> to 0, Validation is
finished soon after invalid value is found.

    $vc->error_stock(0);

=head1 ATTRIBUTES

=head2 C<constraints>

Constraint functions

    $vc          = $vc->constraints(\%constraints);
    $constraints = $vc->constraints;

=head2 C<error_stock>

Validation error is stocked or not.

    $vc          = $vc->error_stock(1);
    $error_stock = $vc->error_stcok;

If error_stock is set to 1, all validation error is stocked.

If error_stock is set 0, Validation is finished after one error is occured.
This is faster than all error is stocked.

Default to 1. 

=head2 C<data_filter>

Data filter

    $vc     = $vc->data_filter($filter);
    $filter = $vc->data_filter;

If data is not hash reference, you can convert the data to hash reference.

    $vc->data_filter(
        sub {
            my $data = shift;
            
            # Convert data to hash reference.
            
            return $data;
        }
    )

=head2 C<rule>

Validation rule

    $vc   = $vc->rule($rule);
    $rule = $vc->rule;

Validation rule has the following syntax.

    # Rule syntax
    my $rule = [                          # 1. Validation rule is array ref
        key1 => [                         # 2. Constraints is array ref
            'constraint1_1',              # 3. Constraint is string
            ['constraint1_2', 'error1_2'],#      or arrya ref (message)
            {'constraint1_3' => 'string'} #      or hash ref (arguments)
              
        ],
        key2 => [
            {'constraint2_1'              # 4. Argument is string
              => 'string'},               #
            {'constraint2_2'              #     or array ref
              => ['arg1', 'arg2']},       #
            {'constraint1_3'              #     or hash ref
              => {k1 => 'v1', k2 => 'v2'}}#
        ],
        key3 => [                           
            [{constraint3_1 => 'string'}, # 5. Combination argument
             'error3_1' ]                 #     and message
        ],
        { key4 => ['key4_1', 'key4_2'] }  # 6. Corelative validation
            => [
                'constraint4_1'
               ],
        key5 => [
            '@constraint5_1'              # 7. Multi-values validation
        ]
    ];

=head2 C<(experimental) shared_rule>

Shared rule. Shared rule is added the head of normal rule in validation.

    $vc          = $vc->shared_rule(\@rule);
    $shared_rule = $vc->shared_rule;

Example

    $vc->shared_rule([
        ['defined',   'Must be defined'],
        ['not_blank', 'Must be not blank']
    ]);

=head2 C<syntax>

Validation rule syntax

    $vc     = $vc->syntax($syntax);
    $syntax = $vc->syntax;

=head1 MEHTODS

=head2 C<new>

Create L<Validator::Custom> object.

    $vc = Validator::Costom->new;
    $vc = Validator::Costom->new(%attributes);
    $vc = Validator::Costom->new(\%attributes);

=head2 C<register_constraint>

Register constraint function.

    $vc->register_constraint(%constraint);
    $vc->register_constraint(\%constraint);
    
Example:
    
    $vc->register_constraint(
        int => sub {
            my $value    = shift;
            my $is_valid = $value =~ /^\-?[\d]+$/;
            return $is_valid;
        },
        ascii => sub {
            my $value    = shift;
            my $is_valid = $value =~ /^[\x21-\x7E]+$/;
            return $is_valid;
        }
    );

=head2 C<validate>

Validate data.

    $vresult = $vc->validate($data, $rule);
    $vresult = $vc->validate($data);

If the rule is ommited, attribute's rule is used,

This method return L<Validator::Custom::Result> object.

=head1 STABILITY

This module is stable. The following attribute and method keep backword compatible in the future.

    # Validator::Custom
    constraints
    error_stock
    data_filter
    rule
    syntax
    
    new
    register_constraint
    validate

    # Validator::Custom::Result
    data
    raw_data
    error_infos
    
    is_valid
    messages
    message
    messages_to_hash
    invalid_params
    invalid_rule_keys
    error_reason
    add_error_info
    remove_error_info
    
    (deprecated) errors
    (deprecated) errors_to_hash
    (deprecated) error
    (deprecated) invalid_keys

=head1 AUTHOR

Yuki Kimoto, C<< <kimoto.yuki at gmail.com> >>

L<http://github.com/yuki-kimoto/Validator-Custom>

=head1 COPYRIGHT & LICENCE

Copyright 2009 Yuki Kimoto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
