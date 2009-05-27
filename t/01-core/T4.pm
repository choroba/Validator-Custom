package T4;
use base 'Validator::Custom';

__PACKAGE__->add_validator(
    {
        Num => sub{
            require Scalar::Util;
            Scalar::Util::looks_like_number($_[0]);
        }
    }
);

