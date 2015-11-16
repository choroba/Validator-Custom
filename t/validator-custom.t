use Test::More 'no_plan';

use strict;
use warnings;
use utf8;
use Validator::Custom;
use Validator::Custom::Rule;

{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(Int => sub{$_[0] =~ /^\d+$/});
  my $data = { k1 => 1, k2 => [1,2], k3 => [1,'a', 'b'], k4 => 'a'};
  my $rule = $vc->create_rule;
  $rule->topic('k1')->each(1)->check('Int')->message("k1Error1");
  $rule->topic('k2')->each(1)->check('Int')->message("k2Error1");
  $rule->topic('k3')->each(1)->check('Int')->message("k3Error1");
  $rule->topic('k4')->each(1)->check('Int')->message("k4Error1");

  my $messages = $vc->validate($data, $rule)->messages;

  is_deeply($messages, [qw/k3Error1 k4Error1/], 'array validate');
}

my $vc_common = Validator::Custom->new;
$vc_common->register_constraint(
  Int => sub{$_[0] =~ /^\d+$/},
  Num => sub{
      require Scalar::Util;
      Scalar::Util::looks_like_number($_[0]);
  },
  C1 => sub {
      my ($value, $args, $options) = @_;
      return [1, $value * 2];
  },
  aaa => sub {$_[0] eq 'aaa'},
  bbb => sub {$_[0] eq 'bbb'}
);

# to_array_remove_blank filter
{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 1, key2 => [1, 2], key3 => '', key4 => [1, 3, '', '']};
  my $rule = $vc->create_rule;
  $rule->topic('key1')->filter('to_array_remove_blank');
  $rule->topic('key2')->filter('to_array_remove_blank');
  $rule->topic('key3')->filter('to_array_remove_blank');
  $rule->topic('key4')->filter('to_array_remove_blank');
  
  my $vresult = $vc->validate($data, $rule);
  is_deeply($vresult->data->{key1}, [1]);
  is_deeply($vresult->data->{key2}, [1, 2]);
  is_deeply($vresult->data->{key3}, []);
  is_deeply($vresult->data->{key4}, [1, 3]);
}

# Validator::Custom::Resut filter method
{
  my $vc = Validator::Custom->new;
  my $data = {
    k1 => ' 123 ',
  };
  my $rule = $vc->create_rule;
  $rule->topic('k1')->filter('trim');

  my $vresult= Validator::Custom->new->validate($data, $rule)->data;

  is_deeply($vresult, {k1 => '123'});
}

# array validation new syntax
{
  my $vc = Validator::Custom->new;
  my $rule = $vc->create_rule;
  my $data = { k1 => 1, k2 => [1,2], k3 => [1,'a', 'b'], k4 => 'a', k5 => []};
  $rule->topic('k1')->filter('to_array')->check({selected_at_least => 1})->each(1)->check('int')->message('k1Error1');
  $rule->topic('k2')->filter('to_array')->check({selected_at_least => 1})->each(1)->check('int')->message('k2Error1');
  $rule->topic('k3')->filter('to_array')->check({selected_at_least => 1})->each(1)->check('int')->message('k3Error1');
  $rule->topic('k4')->filter('to_array')->check({selected_at_least => 1})->each(1)->check('int')->message('k4Error1');
  $rule->topic('k5')->filter('to_array')->check({selected_at_least => 1})->each(1)->check('int')->message('k5Error1');
  
  my $messages = $vc->validate($data, $rule)->messages;

  is_deeply($messages, [qw/k3Error1 k4Error1 k5Error1/], 'array validate');
}

# check_or
{
  my $vc = Validator::Custom->new;

  # check_or - basic
  {
    my $rule = $vc->create_rule;
    my $data = {k1 => '3', k2 => '', k3 => 'a'};
    $rule->topic('k1')
      ->check_or('blank', 'int');
    $rule->topic('k2')
      ->check_or('blank', 'int');
    $rule->topic('k3')
      ->check_or('blank', 'int');
    
    my $vresult = $vc->validate($data, $rule);
    ok($vresult->is_valid('k1'));
    ok($vresult->is_valid('k2'));
    ok(!$vresult->is_valid('k3'));
  }

  # check_or - args
  {
    my $rule = $vc->create_rule;
    my $data = {k1 => '2', k2 => '7', k3 => '4'};
    $rule->topic('k1')
      ->check_or({greater_than => 5}, {less_than => 3});
    $rule->topic('k2')
      ->check_or({greater_than => 5}, {less_than => 3});
    $rule->topic('k3')
      ->check_or({greater_than => 5}, {less_than => 3})->message('k3_error');
    
    my $vresult = $vc->validate($data, $rule);
    ok($vresult->is_valid('k1'));
    ok($vresult->is_valid('k2'));
    ok(!$vresult->is_valid('k3'));
    ok($vresult->message('k3'), 'k3_error');
  }
}

{
  my $vc = Validator::Custom->new;
  my $data = {k1 => 1, k2 => 2, k3 => 3};
  my $rule = $vc->create_rule;
  $rule->topic('k1')
    ->check(sub{$_[0] == 1})->message("k1Error1")
    ->check(sub{$_[0] == 2})->message("k1Error2")
    ->check(sub{$_[0] == 3})->message("k1Error3");
  $rule->topic('k2')
    ->check(sub{$_[0] == 2})->message("k2Error1")
    ->check(sub{$_[0] == 3})->message("k2Error2");

  my $vresult   = $vc->validate($data, $rule);
  
  my $messages      = $vresult->messages;
  my $messages_hash = $vresult->messages_to_hash;
  
  is_deeply($messages, [qw/k1Error2 k2Error2/], 'rule');
  is_deeply($messages_hash, {k1 => 'k1Error2', k2 => 'k2Error2'}, 'rule errors hash');
  
  my $messages_hash2 = $vresult->messages_to_hash;
  is_deeply($messages_hash2, {k1 => 'k1Error2', k2 => 'k2Error2'}, 'rule errors hash');
  
  $messages = Validator::Custom->new(rule => $rule)->validate($data)->messages;
  is_deeply($messages, [qw/k1Error2 k2Error2/], 'rule');
}

{
  ok(!Validator::Custom->new->rule, 'rule default');
}

{
  my $result = Validator::Custom::Result->new;
  $result->data({k => 1});
  is_deeply($result->data, {k => 1}, 'data attribute');
}

{
  my $vc = $vc_common;
  my $data = { k1 => 1, k2 => 'a', k3 => 3.1, k4 => 'a' };
  my $rule = $vc->create_rule;
  $rule->topic('k1')->check('Int')->message("k1Error1");
  $rule->topic('k2')->check('Int')->message("k2Error1");
  $rule->topic('k3')->check('Num')->message("k3Error1");
  $rule->topic('k4')->check('Num')->message("k4Error1");
  my $result= $vc->validate($data, $rule);
  is_deeply($result->messages, [qw/k2Error1 k4Error1/], 'Custom validator');
  is_deeply($result->invalid_rule_keys, [qw/k2 k4/], 'invalid keys hash');
  ok(!$result->is_ok, 'is_ok');
  
  {
    my $vc = $vc_common;
    my $constraints = $vc->constraints;
    ok(exists($constraints->{Int}), 'get constraints');
    ok(exists($constraints->{Num}), 'get constraints');
  }
}

{
  my $vc = $vc_common;
  my $data = { k1 => 1, k2 => 'a', k3 => 3.1, k4 => 'a' };
  my $rule = $vc->create_rule;
  $rule->topic('k1')->check('Int')->message("k1Error1");
  $rule->topic('k2')->check('Int')->message("k2Error1");
  $rule->topic('k3')->check('Num')->message("k3Error1");
  $rule->topic('k4')->check('Num')->message("k4Error1");
  
  my $messages = $vc->validate($data, $rule)->messages;
  is_deeply($messages, [qw/k2Error1 k4Error1/], 'Custom validator one');
  
  $messages = $vc->validate($data, $rule)->messages;
  is_deeply($messages, [qw/k2Error1 k4Error1/], 'Custom validator two');
}

{
  my $vc = $vc_common;
  my $data = {k1 => 1};
  my $rule = $vc->create_rule;
  eval { $rule->topic('k1')->check('No')->message("k1Error1") };
  like($@, qr/"No" is not registered/, 'no custom type');
}

{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
    C1 => sub {
      my ($value, $args, $options) = @_;
      return [1, $value * 2];
    }
  );
  my $data = {k1 => [1,2]};
  my $rule = $vc->create_rule;
  $rule->topic('k1')->each(1)->check('C1')->message("k1Error1")
    ->check('C1')->message("k1Error1");

  my $result= $vc->validate($data, $rule);
  is_deeply(scalar $result->messages, [], 'no error');
  
  is_deeply(scalar $result->data, {k1 => [4,8]}, 'array validate2');
}


{
  my $vc = $vc_common;
  my $data = { k1 => 1};
  my $rule = $vc->create_rule;
  $rule->topic('k1')->check('Int')->message("k1Error1");
  my $messages = $vc->validate($data, $rule)->messages;
  is(scalar @$messages, 0, 'no error');
}

{
  my $vc = Validator::Custom->new;
  my $data = { k1 => 1, k2 => 'a', k3 => '  3  ', k4 => 4, k5 => 5, k6 => 5, k7 => 'a', k11 => [1,2]};

  $vc->register_constraint(
    C1 => sub {
      my ($value, $args) = @_;
      
      return [1, [$value, $args]];
    },
    
    C2 => sub {
      my ($value, $args) = @_;
      
      return [0, [$value, $args]];
    },
    
    TRIM_LEAD => sub {
      my $value = shift;
      
      $value =~ s/^ +//;
      
      return [1, $value];
    },
    
    TRIM_TRAIL => sub {
      my $value = shift;
      
      $value =~ s/ +$//;
      
      return [1, $value];
    },
    
    NO_ERROR => sub {
      return [0, 'a'];
    },
    
    C3 => sub {
      my ($values, $args) = @_;
      if ($values->[0] == $values->[1] && $values->[0] == $args->[0]) {
          return 1;
      }
      else {
          return 0;
      }
    },
    C4 => sub {
      my ($value, $arg) = @_;
      return defined $arg ? 1 : 0;
    },
    C5 => sub {
      my ($value, $arg) = @_;
      return [1, $arg];
    },
    C6 => sub {
      my $self = $_[2];
      return [1, $self];
    }
  );

  my $rule = $vc->create_rule;
  $rule->topic('k1')->check({'C1' => [3, 4]})->message("k1Error1");
  $rule->topic('k2')->check({'C2' => [3, 4]})->message("k2Error1");
  $rule->topic('k3')->filter('TRIM_LEAD')->filter('TRIM_TRAIL');
  $rule->topic('k4')->check('NO_ERROR');
  $rule->topic(['k5', 'k6'])->check({'C3' => [5]})->message('k5 k6 Error');
  $rule->topic('k7')->check({'C2' => [3, 4]});
  $rule->topic('k11')->each(1)->check('C6');
  
  {
    my $result= $vc->validate($data, $rule);
    is_deeply($result->messages, 
              ['k2Error1', 'Error message not specified',
               'Error message not specified'
              ], 'variouse options');
    
    is_deeply($result->invalid_rule_keys, [qw/k2 k4 k7/], 'invalid key');
    
    is_deeply($result->data->{k1},[1, [3, 4]], 'data');
    ok(!$result->data->{k2}, 'data not exist in error case');
    cmp_ok($result->data->{k3}, 'eq', 3, 'filter');
    ok(!$result->data->{k4}, 'data not set in case error');
  }
  {
    my $data = {k5 => 5, k6 => 6};
    my $rule = [
      [qw/k5 k6/] => [
        [{'C3' => [5]}, 'k5 k6 Error']
      ]
    ];
    
    my $result = $vc->validate($data, $rule);
    local $SIG{__WARN__} = sub {};
    ok(!$result->is_valid, 'corelative invalid_rule_keys');
    is(scalar @{$result->invalid_rule_keys}, 1, 'corelative invalid_rule_keys');
  }
}

{
  my $vc = Validator::Custom->new;
  my $data = { k1 => 1, k2 => 2};
  my $constraint = sub {
    my $values = shift;
    return $values->[0] eq $values->[1];
  };
  
  my $rule = $vc->create_rule;
  $rule->topic([qw/k1 k2/])->name('k1_2')->check($constraint)->message('error_k1_2');
  my $messages = $vc->validate($data, $rule)->messages;
  is_deeply($messages, ['error_k1_2'], 'specify key');
}

{
  eval{Validator::Custom->new->validate([])};
  like($@, qr/First argument must be hash ref/, 'Data not hash ref');
}

{
  eval{Validator::Custom->new->rule({})->validate({})};
  like($@, qr/Invalid rule structure/sm,
           'Validation rule not array ref');
}

{
  eval{Validator::Custom->new->rule([key => 'Int'])->validate({})};
  like($@, qr/Invalid rule structure/sm, 
           'Constraints of key not array ref');
}

{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
      length => sub {
          my ($value, $args) = @_;
          
          my $min;
          my $max;
          
          ($min, $max) = @$args;
          my $length  = length $value;
          return $min <= $length && $length <= $max ? 1 : 0;
      }
  );
  my $data = {
    name => 'zz' x 30,
    age => 'zz',
  };
  
  my $rule = $vc->create_rule;
  $rule->topic('name')->check({length => [1, 2]});
  
  my $vresult = $vc->validate($data, $rule);
  my $invalid_rule_keys = $vresult->invalid_rule_keys;
  is_deeply($invalid_rule_keys, ['name'], 'constraint argument first');
  
  my $messages_hash = $vresult->messages_to_hash;
  is_deeply($messages_hash, {name => 'Error message not specified'},
            'errors_to_hash message not specified');
  
  is($vresult->message('name'), 'Error message not specified', 'error default message');
  
  $invalid_rule_keys = $vc->validate($data, $rule)->invalid_rule_keys;
  is_deeply($invalid_rule_keys, ['name'], 'constraint argument second');
}

{
  my $result = Validator::Custom->new->rule([])->validate({key => 1});
  ok($result->is_ok, 'is_ok ok');
}

{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
   'C1' => sub {
      my $value = shift;
      return $value > 1 ? 1 : 0;
    },
   'C2' => sub {
      my $value = shift;
      return $value > 5 ? 1 : 0;
    }
  );
  
  my $data = {k1_1 => 1, k1_2 => 2, k2_1 => 5, k2_2 => 6};
  
  my $rule = $vc->create_rule;
  $rule->topic('k1_1')->check('C1');
  $rule->topic('k1_2')->check('C1');
  $rule->topic('k2_1')->check('C2');
  $rule->topic('k2_2')->check('C2');
  
  is_deeply($vc->validate($data, $rule)->invalid_rule_keys, [qw/k1_1 k2_1/], 'register_constraints object');
}

# Validator::Custom::Result raw_invalid_rule_keys'
{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(p => sub {
    my $values = shift;
    return $values->[0] eq $values->[1];
  });
  $vc->register_constraint(q => sub {
    my $value = shift;
    return $value eq 1;
  });
  
  my $data = {k1 => 1, k2 => 2, k3 => 3, k4 => 1};
  my $rule = $vc->create_rule;
  $rule->topic(['k1', 'k2'])->check('p')->name('k12');
  $rule->topic('k3')->check('q');
  $rule->topic('k4')->check('q');
  my $vresult = $vc->validate($data, $rule);

  is_deeply($vresult->invalid_rule_keys, ['k12', 'k3'], 'invalid_rule_keys');
  is_deeply($vresult->invalid_params, ['k1', 'k2', 'k3'],
          'invalid_params');
}

# constraints default;

my @infos = (
  [
    'not_defined',
    {
      k1 => undef,
      k2 => 'a',
    },
    [
      k1 => [
        'not_defined'
      ],
      k2 => [
        'not_defined'
      ],
    ],
    [qw/k2/]
  ],
  [
    'defined',
    {
      k1 => undef,
      k2 => 'a',
    },
    [
      k1 => [
        'defined'
      ],
      k2 => [
        'defined'
      ],
    ],
    [qw/k1/]
  ],
  [
    'not_space',
    {
      k1 => '',
      k2 => ' ',
      k3 => ' a '
    },
    [
      k1 => [
        'not_space'
      ],
      k2 => [
        'not_space'
      ],
      k3 => [
        'not_space'
      ],
    ],
    [qw/k1 k2/]
  ],
  [
    'not_blank',
    {
      k1 => '',
      k2 => 'a',
      k3 => ' '
    },
    [
      k1 => [
        'not_blank'
      ],
      k2 => [
        'not_blank'
      ],
      k3 => [
        'not_blank'
      ],
    ],
    [qw/k1/]
  ],
  [
    'blank',
    {
      k1 => '',
      k2 => 'a',
      k3 => ' '
    },
    [
      k1 => [
        'blank'
      ],
      k2 => [
        'blank'
      ],
      k3 => [
        'blank'
      ],
    ],
    [qw/k2 k3/]
  ],    
  [
    'int',
    {
      k8  => '19',
      k9  => '-10',
      k10 => 'a',
      k11 => '10.0',
    },
    [
      k8 => [
        'int'
      ],
      k9 => [
        'int'
      ],
      k10 => [
        'int'
      ],
      k11 => [
        'int'
      ],
    ],
    [qw/k10 k11/]
  ],
  [
    'uint',
    {
      k12  => '19',
      k13  => '-10',
      k14 => 'a',
      k15 => '10.0',
    },
    [
      k12 => [
        'uint'
      ],
      k13 => [
        'uint'
      ],
      k14 => [
        'uint'
      ],
      k15 => [
        'uint'
      ],
    ],
    [qw/k13 k14 k15/]
  ],
  [
    'ascii',
    {
      k16 => '!~',
      k17 => ' ',
      k18 => "\0x7f",
    },
    [
      k16 => [
        'ascii'
      ],
      k17 => [
        'ascii'
      ],
      k18 => [
        'ascii'
      ],
    ],
    [qw/k17 k18/]
  ],
  [
    'length',
    {
      k19 => '111',
      k20 => '111',
    },
    [
      k19 => [
        {'length' => [3, 4]},
        {'length' => [2, 3]},
        {'length' => [3]},
        {'length' => 3},
      ],
      k20 => [
        {'length' => [4, 5]},
      ]
    ],
    [qw/k20/],
  ],
  [
    'duplication',
    {
      k1_1 => 'a',
      k1_2 => 'a',
      
      k2_1 => 'a',
      k2_2 => 'b'
    },
    [
      {k1 => [qw/k1_1 k1_2/]} => [
        'duplication'
      ],
      {k2 => [qw/k2_1 k2_2/]} => [
        'duplication'
      ]
    ],
    [qw/k2/]
  ],
  [
    'regex',
    {
      k1 => 'aaa',
      k2 => 'aa',
    },
    [
      k1 => [
        {'regex' => "a{3}"}
      ],
      k2 => [
        {'regex' => "a{4}"}
      ]
    ],
    [qw/k2/]
  ],
  [
    'http_url',
    {
      k1 => 'http://www.lost-season.jp/mt/',
      k2 => 'iii',
    },
    [
      k1 => [
        'http_url'
      ],
      k2 => [
        'http_url'
      ]
    ],
    [qw/k2/]
  ],
  [
    'selected_at_least',
    {
      k1 => 1,
      k2 =>[1],
      k3 => [1, 2],
      k4 => [],
      k5 => [1,2]
    },
    [
      k1 => [
        {selected_at_least => 1}
      ],
      k2 => [
        {selected_at_least => 1}
      ],
      k3 => [
        {selected_at_least => 2}
      ],
      k4 => [
        'selected_at_least'
      ],
      k5 => [
        {'selected_at_least' => 3}
      ]
    ],
    [qw/k5/]
  ],
  [
    'greater_than',
    {
      k1 => 5,
      k2 => 5,
      k3 => 'a',
    },
    [
      k1 => [
        {'greater_than' => 5}
      ],
      k2 => [
        {'greater_than' => 4}
      ],
      k3 => [
        {'greater_than' => 1}
      ]
    ],
    [qw/k1 k3/]
  ],
  [
    'less_than',
    {
      k1 => 5,
      k2 => 5,
      k3 => 'a',
    },
    [
      k1 => [
        {'less_than' => 5}
      ],
      k2 => [
        {'less_than' => 6}
      ],
      k3 => [
        {'less_than' => 1}
      ]
    ],
    [qw/k1 k3/]
  ],
  [
    'equal_to',
    {
      k1 => 5,
      k2 => 5,
      k3 => 'a',
    },
    [
      k1 => [
        {'equal_to' => 5}
      ],
      k2 => [
        {'equal_to' => 4}
      ],
      k3 => [
        {'equal_to' => 1}
      ]
    ],
    [qw/k2 k3/]
  ],
  [
    'between',
    {
      k1 => 5,
      k2 => 5,
      k3 => 5,
      k4 => 5,
      k5 => 'a',
    },
    [
      k1 => [
        {'between' => [5, 6]}
      ],
      k2 => [
        {'between' => [4, 5]}
      ],
      k3 => [
        {'between' => [6, 7]}
      ],
      k4 => [
        {'between' => [5, 5]}
      ],
      k5 => [
        {'between' => [5, 5]}
      ]
    ],
    [qw/k3 k5/]
  ],
  [
    'decimal',
    {
      k1 => '12.123',
      k2 => '12.123',
      k3 => '12.123',
      k4 => '12',
      k5 => '123',
      k6 => '123.a',
      k7 => '1234.1234',
      k8 => '',
      k9 => 'a',
      k10 => '1111111.12',
      k11 => '1111111.123',
      k12 => '12.1111111',
      k13 => '123.1111111'
    },
    [
      k1 => [
        {'decimal' => [2,3]}
      ],
      k2 => [
        {'decimal' => [1,3]}
      ],
      k3 => [
        {'decimal' => [2,2]}
      ],
      k4 => [
        {'decimal' => [2]}
      ],
      k5 => [
        {'decimal' => 2}
      ],
      k6 => [
        {'decimal' => 2}
      ],
      k7 => [
        'decimal'
      ],
      k8 => [
        'decimal'
      ],
      k9 => [
        'decimal'
      ],
      k10 => [
        {'decimal' => [undef, 2]}
      ],
      k11 => [
        {'decimal' => [undef, 2]}
      ],
      k12 => [
        {'decimal' => [2, undef]}
      ],
      k13 => [
        {'decimal' => [2, undef]}
      ]
    ],
    [qw/k2 k3 k5 k6 k8 k9 k11 k13/]
  ],
  [
    'in_array',
    {
      k1 => 'a',
      k2 => 'a',
      k3 => undef
    },
    [
      k1 => [
        {'in_array' => [qw/a b/]}
      ],
      k2 => [
        {'in_array' => [qw/b c/]}
      ],
      k3 => [
        {'in_array' => [qw/b c/]}
      ]
    ],
    [qw/k2 k3/]
  ],
  [
    'shift array',
    {
      k1 => [1, 2]
    },
    [
      k1 => [
        'shift'
      ]
    ],
    [],
    {k1 => 1}
  ],
  [
    'shift scalar',
    {
      k1 => 1
    },
    [
      k1 => [
        'shift'
      ]
    ],
    [],
    {k1 => 1}
  ],
);

foreach my $info (@infos) {
  validate_ok(@$info);
}

# exception
my @exception_infos = (
  [
    'length need parameter',
    {
      k1 => 'a',
    },
    [
      k1 => [
        'length'
      ]
    ],
    qr/\QConstraint 'length' needs one or two arguments/
  ],
  [
    'greater_than target undef',
    {
      k1 => 1
    },
    [
      k1 => [
        'greater_than'
      ]
    ],
    qr/\QConstraint 'greater_than' needs a numeric argument/
  ],
  [
    'greater_than not number',
    {
      k1 => 1
    },
    [
      k1 => [
        {'greater_than' => 'a'}
      ]
    ],
    qr/\QConstraint 'greater_than' needs a numeric argument/
  ],
  [
    'less_than target undef',
    {
      k1 => 1
    },
    [
      k1 => [
        'less_than'
      ]
    ],
    qr/\QConstraint 'less_than' needs a numeric argument/
  ],
  [
    'less_than not number',
    {
      k1 => 1
    },
    [
      k1 => [
        {'less_than' => 'a'}
      ]
    ],
    qr/\QConstraint 'less_than' needs a numeric argument/
  ],
  [
    'equal_to target undef',
    {
      k1 => 1
    },
    [
      k1 => [
        'equal_to'
      ]
    ],
    qr/\QConstraint 'equal_to' needs a numeric argument/
  ],
  [
    'equal_to not number',
    {
      k1 => 1
    },
    [
      k1 => [
        {'equal_to' => 'a'}
      ]
    ],
    qr/\QConstraint 'equal_to' needs a numeric argument/
  ],
  [
    'between target undef',
    {
      k1 => 1
    },
    [
      k1 => [
        {'between' => [undef, 1]}
      ]
    ],
    qr/\QConstraint 'between' needs two numeric arguments/
  ],
  [
    'between target undef or not number1',
    {
      k1 => 1
    },
    [
      k1 => [
        {'between' => ['a', 1]}
      ]
    ],
    qr/\QConstraint 'between' needs two numeric arguments/
  ],
  [
    'between target undef or not number2',
    {
      k1 => 1
    },
    [
      k1 => [
        {'between' => [1, undef]}
      ]
    ],
    qr/\QConstraint 'between' needs two numeric arguments/
  ],
  [
    'between target undef or not number3',
    {
      k1 => 1
    },
    [
      k1 => [
        {'between' => [1, 'a']}
      ]
    ],
    qr/\Qbetween' needs two numeric arguments/
  ],
);

foreach my $exception_info (@exception_infos) {
  validate_exception(@$exception_info)
}

sub validate_ok {
  my ($test_name, $data, $validation_rule, $invalid_rule_keys, $result_data) = @_;
  my $vc = Validator::Custom->new;
  my $r = $vc->validate($data, $validation_rule);
  is_deeply($r->invalid_rule_keys, $invalid_rule_keys, "$test_name invalid_rule_keys");
  
  if (ref $result_data eq 'CODE') {
      $result_data->($r);
  }
  elsif($result_data) {
      is_deeply($r->data, $result_data, "$test_name result data");
  }
}

sub validate_exception {
  my ($test_name, $data, $validation_rule, $error) = @_;
  my $vc = Validator::Custom->new;
  eval{$vc->validate($data, $validation_rule)};
  like($@, $error, "$test_name exception");
}

# trim;
{
  my $data = {
    int_param => ' 123 ',
    collapse  => "  \n a \r\n b\nc  \t",
    left      => '  abc  ',
    right     => '  def  '
  };

  my $validation_rule = [
    int_param => [
      ['trim']
    ],
    collapse  => [
      ['trim_collapse']
    ],
    left      => [
      ['trim_lead']
    ],
    right     => [
      ['trim_trail']
    ]
  ];

  my $result_data= Validator::Custom->new->validate($data,$validation_rule)->data;

  is_deeply(
    $result_data, 
    { int_param => '123', left => "abc  ", right => '  def', collapse => "a b c"},
    'trim check'
  );
}

# Negative validation
{
  my $data = {key1 => 'a', key2 => 1};
  my $vc = Validator::Custom->new;
  my $rule = [
    key1 => [
      'not_blank',
      '!int',
      'not_blank'
    ],
    key2 => [
      'not_blank',
      '!int',
      'not_blank'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_params, ['key2'], "single value");
}

{
  my $data = {key1 => ['a', 'a'], key2 => [1, 1]};
  my $vc = Validator::Custom->new;
  my $rule = [
    key1 => [
      '@not_blank',
      '@!int',
      '@not_blank'
    ],
    key2 => [
      '@not_blank',
      '@!int',
      '@not_blank'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_params, ['key2'], "multi values");
}

{
  my $data = {key1 => 2, key2 => 1};
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
    one => sub {
      my $value = shift;
      
      if ($value == 1) {
        return [1, $value];
      }
      else {
        return [0, $value];
      }
    }
  );
  my $rule = [
    key1 => [
      '!one',
    ],
    key2 => [
      '!one'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_params, ['key2'], "filter value");
}

# missing_params
{
  my $data = {key1 => 1};
  my $vc = Validator::Custom->new;
  my $rule = [
    key1 => [
      'int'
    ],
    key2 => [
      'int'
    ],
    {rkey1 => ['key2', 'key3']} => [
      'duplication'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_ok, "invalid");
  is_deeply($result->missing_params, ['key2', 'key3'], "names");
}

# has_missing
{
  my $data = {};
  my $vc = Validator::Custom->new;
  my $rule = [
    key1 => [
      'int'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->has_missing, "missing");
}

{
  my $data = {key1 => 'a'};
  my $vc = Validator::Custom->new;
  my $rule = [
    key1 => [
      'int'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->has_missing, "missing");
}

# duplication result value
{
  my $data = {key1 => 'a', key2 => 'a'};
  my $rule = [
    {key3 => ['key1', 'key2']} => [
      'duplication'
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is($result->data->{key3}, 'a');
}

# message option
{
  my $data = {key1 => 'a'};
  my $rule = [
    key1 => {message => 'error'} => [
      'int'
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is($result->message('key1'), 'error');
}

# default option
{
  my $data = {};
  my $rule = [
    key1 => {default => 2} => [
    
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
  is($result->data->{key1}, 2, "data value");
}

{
  my $data = {};
  my $rule = [
    key1 => {default => 2, copy => 0} => [
    
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok, "has missing ");
  ok(!exists $result->data->{key1}, "missing : data value and no copy");
}

{
  my $data = {key1 => 'a'};
  my $rule = [
    key1 => {default => 2} => [
      'int'
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
  is($result->data->{key1}, 2, "invalid : data value");
}

{
  my $data = {key1 => 'a'};
  my $rule = [
    key1 => {default => 2, copy => 0} => [
      'int'
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
  ok(!exists $result->data->{key1}, "invalid : data value and no copy");
}

{
  my $data = {key1 => 'a', key3 => 'b'};
  my $rule = [
    key1 => {default => sub { return $_[0] }} => [
      'int'
    ],
    key2 => {default => sub { return 5 }} => [
      'int'
    ],
    key3 => {default => undef} => [
      'int'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is($result->data->{key1}, $vc, "data value");
  is($result->data->{key2}, 5, "data value");
  ok(exists $result->data->{key3} && !defined $result->data->{key3});
}

# copy
{
  my $data = {key1 => 'a', 'key2' => 'a'};
  my $rule = [
    {key3 => ['key1', 'key2']} => {copy => 0} => [
      'duplication'
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok, "ok");
  is_deeply($result->data, {}, "not copy");
}

# is_valid
{
  my $data = {key1 => 'a', key2 => 'b', key3 => 2};
  my $rule = [
    key1 => [
      'int'
    ],
    key2 => [
      'int'
    ],
    key3 => [
      'int'
    ]
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

# merge
{
  my $data = {key1 => 'a', key2 => 'b', key3 => 'c'};
  my $rule = [
    {key => ['key1', 'key2', 'key3']} => [
      'merge'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is($result->data->{key}, 'abc');
}

# Multi-Paramater validation using regex
{
  my $data = {key1 => 'a', key2 => 'b', key3 => 'c', p => 'd'};
  my $rule = [
    {key => qr/^key/} => [
      'merge'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  my $value = $result->data->{key};
  ok(index($value, 'a') > -1);
  ok(index($value, 'b') > -1);
  ok(index($value, 'c') > -1);
  ok(index($value, 'd') == -1);
}

{
  my $data = {key1 => 'a'};
  my $rule = [
    {key => qr/^key/} => [
      'merge'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  my $value = $result->data->{key};
  ok(index($value, 'a') > -1);
}

# or condition new syntax
{
  my $data = {key1 => '3', key2 => '', key3 => 'a'};
  my $rule = [
    key1 => [
      'blank || int'
    ],
    key2 => [
      'blank || int'
    ],
    key3 => [
      'blank || int'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_rule_keys, ['key3']);
}

# or condition new syntax
{
  my $data = {key1 => '3', key2 => '', key3 => 'a'};
  my $rule = [
    key1 => [
      'blank || !int'
    ],
    key2 => [
      'blank || !int'
    ],
    key3 => [
      'blank || !int'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_rule_keys, ['key1']);
}

# space
{
  my $data = {key1 => '', key2 => ' ', key3 => 'a'};
  my $rule = [
    key1 => [
      'space'
    ],
    key2 => [
      'space'
    ],
    key3 => [
      'space'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_rule_keys, ['key3']);
}

# or condition filter
{
  my $data = {key1 => '2010/11/04', key2 => '2010-11-04', key3 => '2010 11 04'};
  my $rule = [
    key1 => [
      'date1 || date2 || date3'
    ],
    key2 => [
      'date1 || date2 || date3'
    ],
    key3 => [
      'date1 || date2 || date3'
    ],
  ];
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
    date1 => sub {
      my $value = shift;
      if ($value =~ m#(\d{4})/(\d{2})/(\d{2})#) {
        return [1, "$1$2$3"];
      }
      else {
        return [0, undef];
      }
    },
    date2 => sub {
      my $value = shift;
      if ($value =~ /(\d{4})-(\d{2})-(\d{2})/) {
        return [1, "$1$2$3"];
      }
      else {
        return [0, undef];
      }
    },
    date3 => sub {
      my $value = shift;
      if ($value =~ /(\d{4}) (\d{2}) (\d{2})/) {
        return [1, "$1$2$3"];
      }
      else {
        return [0, undef];
      }
    }

  );
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
  is_deeply($result->data, {key1 => '20101104', key2 => '20101104',
                          key3 => '20101104'});
}

{
  my $vc = $vc_common;
  my $data = {key1 => 'aaa', key2 => 'bbb'};
  my $rule = [
    key1 => [
      'not_blank || blank'
    ],
    key2 => [
      'blank || not_blank'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
}

# or condition filter array
{
  my $data = {
    key1 => ['2010/11/04', '2010-11-04', '2010 11 04'],
    key2 => ['2010/11/04', '2010-11-04', 'xxx']
  };
  my $rule = [
    key1 => [
      '@ date1 || date2 || date3'
    ],
    key2 => [
      '@ date1 || date2 || date3'
    ],
  ];
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
    date1 => sub {
      my $value = shift;
      if ($value =~ m#(\d{4})/(\d{2})/(\d{2})#) {
        return [1, "$1$2$3"];
      }
      else {
        return [0, undef];
      }
    },
    date2 => sub {
      my $value = shift;
      if ($value =~ /(\d{4})-(\d{2})-(\d{2})/) {
        return [1, "$1$2$3"];
      }
      else {
        return [0, undef];
      }
    },
    date3 => sub {
      my $value = shift;
      if ($value =~ /(\d{4}) (\d{2}) (\d{2})/) {
        return [1, "$1$2$3"];
      }
      else {
        return [0, undef];
      }
    }

  );
  my $result = $vc->validate($data, $rule);
  is_deeply($result->invalid_params, ['key2']);
  is_deeply($result->data, {key1 => ['20101104', '20101104', '20101104'],
                          });
}

# _parse_random_string_rule
{
  my $rule = {
    name1 => '[ab]{3}@[de]{2}.com',
    name2 => '[ab]{2}c{2}p{1}',
    name3 => '',
    name4 => 'abc',
    name5 => 'a{10}'
  };
  my $vc = Validator::Custom->new;
  my $r = $vc->_parse_random_string_rule($rule);
  is_deeply(
    $r,
    {
      name1 => [['a', 'b'], ['a', 'b'], ['a', 'b'], ['@'], ['d', 'e'], ['d', 'e'], ['.'], ['c'], ['o'], ['m']],
      name2 => [['a', 'b'], ['a', 'b'], ['c'], ['c'], ['p']],
      name3 => [],
      name4 => [['a'], ['b'], ['c']],
      name5 => [['a'], ['a'], ['a'], ['a'], ['a'], ['a'], ['a'], ['a'], ['a'], ['a']]
    });
}

# any
{
  my $data = {
    key1 => undef, key2 => 1
  };
  my $rule = [
    key1 => [
      'any'
    ],
    key2 => [
      'any'
    ],
  ];
  my $vc = Validator::Custom->new;
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
}


# to_hash
{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 1, key2 => 'a', key3 => 'a'};
  my $rule = [
    key1 => [
      'int'
    ],
    key2 => {message => 'a'} => [
      'int'
    ],
    key3 => {message => 'b'} => [
      'int'
    ],
    key4 => {message => 'key4 must be int'} => [
      'int'
    ],
    key5 => {message => 'key5 must be int'} => [
      'int'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->to_hash, {
    ok => $result->is_ok, invalid => $result->has_invalid,
    missing => $result->has_missing,
    missing_params => $result->missing_params,
    messages => $result->messages_to_hash
  });
  is_deeply($result->to_hash, {
    ok => 0, invalid => 1,
    missing => 1,
    missing_params => ['key4', 'key5'],
    messages => {key2 => 'a', key3 => 'b', key4 => 'key4 must be int', key5 => 'key5 must be int'}
  });
}

# not_required
{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 1};
  my $rule = [
    key1 => [
      'int'
    ],
    key2 => {message => 'a'} => [
      'int'
    ],
    key3 => {require => 0} => [
      'int'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->missing_params, ['key2']);
  ok(!$result->is_ok);
}

{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 1};
  my $rule = [
    key1 => {require => 0} => [
      'int'
    ],
    key2 => {require => 0} => [
      'int'
    ],
    key3 => {require => 0} => [
      'int'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
  ok(!$result->has_invalid);
}

# to_array filter
{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 1, key2 => [1, 2]};
  my $rule = [
    key1 => [
      'to_array'
    ],
    key2 => [
      'to_array'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->data->{key1}, [1]);
  is_deeply($result->data->{key2}, [1, 2]);
}

# loose_data
{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 1, key2 => 2};
  my $rule = [
    key1 => [
      'to_array'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->loose_data->{key1}, [1]);
  is_deeply($result->loose_data->{key2}, 2);
}

{
  my $vc = Validator::Custom->new;
  my $data = {key1 => 'a'};
  my $rule = [
    key1 => {default => 5} => [
      'int'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->loose_data->{key1}, 5);
}

# undefined value
{
  my $vc = Validator::Custom->new;
  my $data = {key1 => undef, key2 => '', key3 => 'a'};
  my $rule = [
    key1 => [
      'ascii'
    ],
    key2 => [
      'ascii'
    ],
    key3 => [
      'ascii'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => '2'};
  my $rule = [
    key1 => [
      {between => [1, 3]}
    ],
    key2 => [
      {between => [1, 3]}
    ],
    key3 => [
      {between => [1, 3]}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => ''};
  my $rule = [
    key1 => [
      'blank'
    ],
    key2 => [
      'blank'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok($result->is_valid('key2'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => '2.1'};
  my $rule = [
    key1 => [
      {decimal => 1}
    ],
    key2 => [
      {decimal => 1}
    ],
    key3 => [
      {decimal => [1, 1]}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => 'a', key2 => 'a', key3 => '', key4 => '', key5 => undef, key6 => undef};
  my $rule = [
    {'key1-2' => ['key1', 'key2']} => [
      'duplication'
    ],
    {'key3-4' => ['key3', 'key4']} => [
      'duplication'
    ],
    {'key1-5' => ['key1', 'key5']} => [
      'duplication'
    ],
    {'key5-1' => ['key5', 'key1']} => [
      'duplication'
    ],
    {'key5-6' => ['key5', 'key6']} => [
      'duplication'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_valid('key1-2'));
  ok($result->is_valid('key3-4'));
  ok(!$result->is_valid('key1-5'));
  ok(!$result->is_valid('key5-1'));
  ok(!$result->is_valid('key5-6'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => '1'};
  my $rule = [
    key1 => [
      {equal_to => 1}
    ],
    key2 => [
      {equal_to => 1}
    ],
    key3 => [
      {equal_to => 1}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => '5'};
  my $rule = [
    key1 => [
      {greater_than => 1}
    ],
    key2 => [
      {greater_than => 1}
    ],
    key3 => [
      {greater_than => 1}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 'http://aaa.com'};
  my $rule = [
    key1 => [
      'http_url'
    ],
    key2 => [
      'http_url'
    ],
    key3 => [
      'http_url'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => '1'};
  my $rule = [
    key1 => [
      'int'
    ],
    key2 => [
      'int'
    ],
    key3 => [
      'int'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => '1'};
  my $rule = [
    key1 => [
      {'in_array' => [1, 2]}
    ],
    key2 => [
      {'in_array' => [1, 2]}
    ],
    key3 => [
      {'in_array' => [1, 2]}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 'aaa'};
  my $rule = [
    key1 => [
      {'length' => [1, 4]}
    ],
    key2 => [
      {'length' => [1, 4]}
    ],
    key3 => [
      {'length' => [1, 4]}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 3};
  my $rule = [
    key1 => [
      {'less_than' => 4}
    ],
    key2 => [
      {'less_than' => 4}
    ],
    key3 => [
      {'less_than' => 4}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 3};
  my $rule = [
    key1 => [
      'not_blank'
    ],
    key2 => [
      'not_blank'
    ],
    key3 => [
      'not_blank'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 3};
  my $rule = [
    key1 => [
      'not_space'
    ],
    key2 => [
      'not_space'
    ],
    key3 => [
      'not_space'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 3};
  my $rule = [
    key1 => [
      'uint'
    ],
    key2 => [
      'uint'
    ],
    key3 => [
      'uint'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => 3};
  my $rule = [
    key1 => [
      {'regex' => qr/3/}
    ],
    key2 => [
      {'regex' => qr/3/}
    ],
    key3 => [
      {'regex' => qr/3/}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key1 => undef, key2 => '', key3 => ' '};
  my $rule = [
    key1 => [
      'space'
    ],
    key2 => [
      'space'
    ],
    key3 => [
      'space'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok($result->is_valid('key2'));
  ok($result->is_valid('key3'));
}

{
  my $vc = $vc_common;
  my $data = {key2 => 2};
  my $rule = [
    key1 => {message => 'key1 is undefined'} => [
      'defined'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  is_deeply($result->missing_params, ['key1']);
  is_deeply($result->messages, ['key1 is undefined']);
  ok(!$result->is_valid('key1'));
}

# between 0-9
{
  my $vc = $vc_common;
  my $data = {key1 => 0, key2 => 9};
  my $rule = [
    key1 => [
      {between => [0, 9]}
    ],
    key2 => [
      {between => [0, 9]}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_ok);
}

# between decimal
{
  my $vc = $vc_common;
  my $data = {key1 => '-1.5', key2 => '+1.5', key3 => 3.5};
  my $rule = [
    key1 => [
      {between => [-2.5, 1.9]}
    ],
    key2 => [
      {between => ['-2.5', '+1.9']}
    ],
    key3 => [
      {between => ['-2.5', '+1.9']}
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_valid('key1'));
  ok($result->is_valid('key2'));
  ok(!$result->is_valid('key3'));
}

# equal_to decimal
{
  my $vc = $vc_common;
  my $data = {key1 => '+0.9'};
  my $rule = [
    key1 => [
      {equal_to => '0.9'}
    ]
  ];
  my $result = $vc->validate($data, $rule);
}

# greater_than decimal
{
  my $vc = $vc_common;
  my $data = {key1 => '+10.9'};
  my $rule = [
    key1 => [
      {greater_than => '9.1'}
    ]
  ];
  my $result = $vc->validate($data, $rule);
}

# int unicode
{
  my $vc = $vc_common;
  my $data = {key1 => 0, key2 => 9, key3 => '２'};
  my $rule = [
    key1 => [
      'int'
    ],
    key2 => [
      'int'
    ],
    key3 => [
      'int'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_valid('key1'));
  ok($result->is_valid('key2'));
  ok(!$result->is_valid('key3'));
}

# less_than decimal
{
  my $vc = $vc_common;
  my $data = {key1 => '+0.9'};
  my $rule = [
    key1 => [
      {less_than => '10.1'}
    ]
  ];
  my $result = $vc->validate($data, $rule);
}

# uint unicode
{
  my $vc = $vc_common;
  my $data = {key1 => 0, key2 => 9, key3 => '２'};
  my $rule = [
    key1 => [
      'uint'
    ],
    key2 => [
      'uint'
    ],
    key3 => [
      'uint'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_valid('key1'));
  ok($result->is_valid('key2'));
  ok(!$result->is_valid('key3'));
}

# space unicode
{
  my $vc = $vc_common;
  my $data = {key1 => ' ', key2 => '　'};
  my $rule = [
    key1 => [
      'space'
    ],
    key2 => [
      'space'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  ok($result->is_valid('key1'));
  ok(!$result->is_valid('key2'));
}

# not_space unicode
{
  my $vc = $vc_common;
  my $data = {key1 => ' ', key2 => '　'};
  my $rule = [
    key1 => [
      'not_space'
    ],
    key2 => [
      'not_space'
    ],
  ];
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1'));
  ok($result->is_valid('key2'));
}

# not_space unicode
{
  my $vc = $vc_common;
  my $data = {key1 => '　', key2 => '　', key3 => '　', key4 => '　'};
  my $rule = [
    key1 => [
      'trim'
    ],
    key2 => [
      'trim_lead'
    ],
    key3 => [
      'trim_collapse'
    ],
    key4 => [
      'trim_trail'
    ]
  ];
  my $result = $vc->validate($data, $rule);
  is($result->data->{key1}, '　');
  is($result->data->{key2}, '　');
  is($result->data->{key3}, '　');
  is($result->data->{key4}, '　');
}

# lenght {min => ..., max => ...}
{
  my $vc = $vc_common;
  my $data = {
    key1_1 => 'a',
    key1_2 => 'aa',
    key1_3 => 'aaa',
    key1_4 => 'aaaa',
    key1_5 => 'aaaaa',
    key2_1 => 'a',
    key2_2 => 'aa',
    key2_3 => 'aaa',
    key3_1 => 'aaa',
    key3_2 => 'aaaa',
    key3_3 => 'aaaaa'
  };
  my $rule = $vc->create_rule;
  $rule->topic('key1_1')->check({'length' => {min => 2, max => 4}});
  $rule->topic('key1_2')->check({'length' => {min => 2, max => 4}});
  $rule->topic('key1_3')->check({'length' => {min => 2, max => 4}});
  $rule->topic('key1_4')->check({'length' => {min => 2, max => 4}});
  $rule->topic('key1_5')->check({'length' => {min => 2, max => 4}});
  $rule->topic('key2_1')->check({'length' => {min => 2}});
  $rule->topic('key2_2')->check({'length' => {min => 2}});
  $rule->topic('key2_3')->check({'length' => {min => 2}});
  $rule->topic('key3_1')->check({'length' => {max => 4}});
  $rule->topic('key3_2')->check({'length' => {max => 4}});
  $rule->topic('key3_3')->check({'length' => {max => 4}});
  
  my $result = $vc->validate($data, $rule);
  ok(!$result->is_valid('key1_1'));
  ok($result->is_valid('key1_2'));
  ok($result->is_valid('key1_3'));
  ok($result->is_valid('key1_4'));
  ok(!$result->is_valid('key1_5'));
  ok(!$result->is_valid('key2_1'));
  ok($result->is_valid('key2_2'));
  ok($result->is_valid('key2_3'));
  ok($result->is_valid('key3_1'));
  ok($result->is_valid('key3_2'));
  ok(!$result->is_valid('key3_3'));
}

# trim_uni
{
  my $vc = Validator::Custom->new;
  my $data = {
    int_param => '　　123　　',
    collapse  => "　　\n a \r\n b\nc  \t　　",
    left      => '　　abc　　',
    right     => '　　def　　'
  };
  my $rule = $vc->create_rule;
  $rule->topic('int_param')->check('trim_uni');
  $rule->topic('collapse')->check('trim_uni_collapse');
  $rule->topic('left')->check('trim_uni_lead');
  $rule->topic('right')->check('trim_uni_trail');

  my $result_data= Validator::Custom->new->validate($data,$rule)->data;

  is_deeply(
    $result_data, 
    { int_param => '123', left => "abc　　", right => '　　def', collapse => "a b c"},
    'trim check'
  );
}

# Custom error message
{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
    c1 => sub {
      my $value = shift;
      
      if ($value eq 'a') {
        return 1;
      }
      else {
        return {result => 0, message => 'error1'};
      }
    },
    c2 => sub {
      my $value = shift;
      
      if ($value eq 'a') {
        return {result => 1};
      }
      else {
        return {message => 'error2'};
      }
    }
  );
  my $rule = $vc->create_rule;
  $rule->topic('k1')->check('c1');
  $rule->topic('k2')->each(1)->check('c2');
  my $vresult = $vc->validate({k1 => 'a', k2 => 'a'}, $rule);
  ok($vresult->is_ok);
  $vresult = $vc->validate({k1 => 'b', k2 => 'b'}, $rule);
  ok(!$vresult->is_ok);
  is_deeply($vresult->messages, ['error1', 'error2']);
}

# Filter hash representation
{
  my $vc = Validator::Custom->new;
  $vc->register_constraint(
    c1 => sub {
      my $value = shift;
      
      return {result => 1, output => $value * 2};
    }
  );
  my $rule = $vc->create_rule;
  $rule->topic('k1')->check('c1');
  $rule->topic('k2')->each(1)->check('c1');
  my $vresult = $vc->validate({k1 => 1, k2 => [2, 3]}, $rule);
  ok($vresult->is_ok);
  is($vresult->data->{k1}, 2);
  is_deeply($vresult->data->{k2}, [4, 6]);
}

# Use constraints function from $_
{
  my $vc = Validator::Custom->new;
  my $rule = $vc->create_rule;
  $rule->topic('k1')->check(sub { $_->blank(@_) || $_->regex($_[0], qr/[0-9]+/) });
  $rule->topic('k2')->check(sub { $_->blank(@_) || $_->regex($_[0], qr/[0-9]+/) });
  $rule->topic('k3')->check(sub { $_->blank(@_) || $_->regex($_[0], qr/[0-9]+/) });
  
  my $vresult = $vc->validate({k1 => '', k2 => '123', k3 => 'abc'}, $rule);
  ok($vresult->is_valid('k1'));
  ok($vresult->is_valid('k2'));
  ok(!$vresult->is_valid('k3'));
}

# new rule syntax
{
  my $vc = Validator::Custom->new;

  # new rule syntax - basic
  {
    my $rule = $vc->create_rule;
    $rule->topic('k1')->check('not_blank');
    $rule->topic('k2')->check('not_blank');
    $rule->topic('k3')->check('not_blank')->message('k3 is empty');
    $rule->topic('k4')->optional->check('not_blank')->default(5);
    my $vresult = $vc->validate({k1 => 'aaa', k2 => '', k3 => '', k4 => ''}, $rule);
    ok($vresult->is_valid('k1'));
    is($vresult->data->{k1}, 'aaa');
    ok(!$vresult->is_valid('k2'));
    ok(!$vresult->is_valid('k3'));
    is($vresult->messages_to_hash->{k3}, 'k3 is empty');
    is($vresult->data->{k4}, 5);
  }
  
  # new rule syntax - message option
  {
    my $rule = $vc->create_rule;
    $rule->topic('k1')->check('not_blank')->message('k1 is invalid');

    my $vresult = $vc->validate({k1 => ''}, $rule);
    ok(!$vresult->is_valid('k1'));
    is($vresult->message('k1'), 'k1 is invalid');
  }
}

# string constraint
{
  my $vc = Validator::Custom->new;

  {
    my $data = {
      k1 => '',
      k2 => 'abc',
      k3 => 3.1,
      k4 => undef,
      k5 => []
    };
    my $rule = $vc->create_rule;
    $rule->topic('k1')->check('string');
    $rule->topic('k2')->check('string');
    $rule->topic('k3')->check('string');
    $rule->topic('k4')->check('string');
    $rule->topic('k5')->check('string');
    
    my $vresult = $vc->validate($data, $rule);
    ok($vresult->is_valid('k1'));
    ok($vresult->is_valid('k2'));
    ok($vresult->is_valid('k3'));
    ok(!$vresult->is_valid('k4'));
    ok(!$vresult->is_valid('k5'));
  }
}

# call multiple check
{
  my $vc = Validator::Custom->new;
  
  {
    my $rule = $vc->create_rule;
    $rule->topic('k1')
      ->check(['string' => 'k1_string_error'])
      ->check(['not_blank' => 'k1_not_blank_error'])
      ->check([{'length' => {max => 3}} => 'k1_length_error']);
;
    $rule->topic('k2')
      ->check(['int' => 'k2_int_error'])
      ->check([{'greater_than' => 3} => 'k2_greater_than_error']);
    
    my $vresult = $vc->validate({k1 => 'aaaa', k2 => 2}, $rule);
    ok(!$vresult->is_valid('k1'));
    ok(!$vresult->is_valid('k2'));
    my $messages_h = $vresult->messages_to_hash;
    is($messages_h->{k1}, 'k1_length_error');
    is($messages_h->{k2}, 'k2_greater_than_error');
  }
}

# No constraint
{
  my $vc = Validator::Custom->new;
  
  # No constraint - valid
  {
    my $rule = $vc->create_rule;
    my $data = {k1 => 1, k2 => undef};
    $rule->topic('k1');
    $rule->topic('k2');
    my $vresult = $vc->validate($data, $rule);
    ok($vresult->is_ok);
  }
  
  # No constraint - invalid
  {
    my $rule = $vc->create_rule;
    my $data = {k1 => 1};
    $rule->topic('k1');
    $rule->topic('k2');
    my $vresult = $vc->validate($data, $rule);
    ok(!$vresult->is_ok);
  }
}

# call message by each constraint
{
  my $vc = Validator::Custom->new;
  
  # No constraint - valid
  {
    my $rule = $vc->create_rule;
    $rule->topic('k1')
      ->check('not_blank')->message('k1_not_blank_error')
      ->check('int')->message('k1_int_error');
    $rule->topic('k2')
      ->check('int')->message('k2_int_error');
    my $vresult1 = $vc->validate({k1 => '', k2 => 4}, $rule);
    is_deeply(
      $vresult1->messages_to_hash,
      {k1 => 'k1_not_blank_error'}
    );
    my $vresult2 = $vc->validate({k1 => 'aaa', k2 => 'aaa'}, $rule);
    is_deeply(
      $vresult2->messages_to_hash,
      {
        k1 => 'k1_int_error',
        k2 => 'k2_int_error'
      }
    );
  }
}

# message fallback
{
  my $vc = Validator::Custom->new;
  
  # No constraint - valid
  {
    my $rule = $vc->create_rule;
    $rule->topic('k1')
      ->check('not_blank')
      ->check('int')->message('k1_int_not_blank_error');
    my $vresult1 = $vc->validate({k1 => ''}, $rule);
    is_deeply(
      $vresult1->messages_to_hash,
      {k1 => 'k1_int_not_blank_error'}
    );
    my $vresult2 = $vc->validate({k1 => 'aaa'}, $rule);
    is_deeply(
      $vresult2->messages_to_hash,
      {k1 => 'k1_int_not_blank_error'}
    );
  }
}
