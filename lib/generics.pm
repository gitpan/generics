package generics;

use strict;
use warnings;

our $VERSION = '0.02';

sub import {
	my ($self) = shift;
	# return if they dont pass anything in (use generics;)
	return unless @_;
	# otherwise ...
	my ($class, @params) = @_;
	# turn off strict refs cause we are messing with stuff
	no strict 'refs';
	# turn off warnings, so we dont get
	# the function redefinition warning
	# or the prototype mismatch as well
	no warnings qw(redefine prototype once);
	# find out who called us
	my ($calling_package, $file, $line) = caller();
	# this is for:
	# 	use generics params => (*params*);
	# it just pre-initializes the sub routines 
	# so they can be called like constants
	# if you do not then define those params
	# later on, the methods will just return undefined
	if ($class eq "params") {
		# create a hash for to hold the 
		# valid parameters
		%{"${calling_package}::GENERIC_PARAMS"} = () unless %{"${calling_package}::GENERIC_PARAMS"};
		map {
			# check for duplicate parameters
			# basically just see if the param 
			# already exists in the hash of 
			# valid params
			(!exists(${"${calling_package}::GENERIC_PARAMS"}{$_})) ||  die "generics exception: attempted duplicate parameter creation in $calling_package in file: $file on line: $line.\n";
			# this creates a subroutine that returns undef.
			# this prevents Perl from thinking that this 
			# subroutine doesnt exist, but allows you to
			# to catch it as an error.
			my $name = $_;
			*{"${calling_package}::$_"} = sub { die "generics exception: ${calling_package}::$name is an undefined parameter (and has no default)\n" };
			# add the latest param as a key in the valid
			# params hash, and increment it by one
			${"${calling_package}::GENERIC_PARAMS"}{$_}++;
			} @params;
		return;
	}
	elsif ($class eq "inherit") {
		# if you want to inherit generic params, 
		# but still have your own, then you need
		# to do this:
		# 	use generics inherit => "My::Base::Class";
		# and it will allow one to inherit from
		# the base class. it can be called alone
		# or in conjunction with other calls to generics
		# which therby either create or overwrite the
		# generic params alreay inherited.
		# NOTE:
		# we create a function in the calling package which 
		# returns the value of the function from the base 
		# packages so that we are truely inheriting from it. 
		# But keep in mind that this all happens at runtime,
		# so if the generic parameters are changed in 
		# the calling package then it will override these 
		# parameters, because that change will happen at
		# compile time and therefore override this function.
		# NOTE:
		# any changes made to the params of the base package 
		# will be reflected in the calling package since the 
		# inheritance is performed at runtime.
		my $base_package = $params[0];
		%{"${calling_package}::GENERIC_PARAMS"} = %{"${base_package}::GENERIC_PARAMS"};
		foreach my $param_key (keys %{"${base_package}::GENERIC_PARAMS"}) {
			*{"${calling_package}::${param_key}"} = sub { &{"${base_package}::${param_key}"}() };
		}
		return;
	}
	# before we go any further lets make sure 
	# the parameters are even key value pairs
 	(@params && ($#params % 2) != 0) || die "generics exception: uneven parameter assigments of generics in $calling_package in file: $file on line: $line.\n";
	my %params = @params;
	# this is for:
	# 	use generics default_params => (*params and default values*);
	# it sets up the generic parameters and 
	# fills them with a default value.
	# NOTE: 
	# there is no need to check for
	# duplicate params here, because they 
	# will get swallowed up by the hash 
	# assignment. 
	if ($class eq "default_params") {
		# create a hash for to hold the 
		# valid parameters, unless we already
		# have one (meaning someone has done
		# and "inherit" somewhere.
		%{"${calling_package}::GENERIC_PARAMS"} = () unless %{"${calling_package}::GENERIC_PARAMS"};
		while (my ($key, $value) = each %params) {
			# add the latest param as a key in the valid
			# params hash, and increment it by one
			${"${calling_package}::GENERIC_PARAMS"}{$key}++;
			*{"${calling_package}::$key"} = $value if (ref($value) eq "CODE");
			*{"${calling_package}::$key"} = sub { $value } if (!ref($value) || (ref($value) ne "CODE"));
		}
	}
	# this is for:
	#	use generics *package* => (*params and values*);
	# this is when the module is loaded and 
	# before you use it in any code. It populates
	# the generic parameters with the new 
	# values that are passed.
	else {
		# get the hash of valid params
		my %valid_params = %{"${class}::GENERIC_PARAMS"};
		while (my ($key, $value) = each %params) {
			# before we assign anything, check
			# to see that the key we are assigning
			# is a valid param in the generic module
			(exists($valid_params{$key})) || die "generics exception: $key is not a valid generic parameter for $class in $calling_package in file: $file on line: $line.\n";
			# if we get past the exception, then all
			# is cool and we can assign the parameter
			*{"${class}::$key"} = $value if (ref($value) eq "CODE");
			*{"${class}::$key"} = sub () { $value } if (!ref($value) || (ref($value) ne "CODE"));
		}
	}
}

## NOTE:
# if ever you need to change the module configuration
# you will need to re-import the the configuration. Here
# is a way to do that (without having to say import which
# wouldnt make as much sense semanticaly).
# Keep in mind though that this will not restore the default
# values originally assigned in the class, it will just overwrite
# the current ones. 
# 
# this will be needed very rarely. If you find yourself using it
# you should question the reason first, and only use it as a last 
# resort.
*change_params = \&import;

# to support module reloading

sub has_generic_params {
	my ($self, $package_name) = @_;
	no strict 'refs';
	return exists ${"${package_name}::"}{GENERIC_PARAMS} ? 1 : 0;
}

sub dump_params {
	my ($self, $package_name) = @_;
	no strict 'refs';
	return map {
			($_ => &{"${package_name}::$_"}())
			} keys %{"${package_name}::GENERIC_PARAMS"};
}

1;
__END__

=head1 NAME

generics - pragma for adding generic parameters to modules

=head1 SYNOPSIS

    use generics;
    
    # for use from within a class
    use generics params => qw(PARAMETER);
    
    # another use from within a class
    use generics default_params => (PARAMETER => "A value");
    
    # using it from outside a class 
    # to change the classes parameters
    use generics MyModule => (PARAMETER => "A new value");
    
    # see DESCRIPTION below for a better understanding of this module

=head1 DESCRIPTION

Many languages incorporate the concept of generic programming, specifically C++ and Ada. The generics pragma was inspired by these languages, but because of Perl's existing type flexibility it does not need generic programming per say. Instead I took the idea of passing generic parameters into a pre-existing class as a form of class configuration. The same generic programming can be accomplished to a certain degree, although because generics parameters are assigned at compile time they become part of the class rather than the instance (as in most generics situations). 

So all this said, at their heart, generics are class configuration parameters. They can get trickier depending on how you choose to use them. The easiest example is that of a "Session" object. Here is some sample code:

    # be sure to load the 
    # object's module
    use Session;
    
    # set the generic params
    use generics Session => (
                SESSION_TIMEOUT => 30, 
                SESSION_ID_LENGTH => 20
                );
    
    # create a Session object instance
    my $s = Session->new();

Generics are used here as a way of configuring the Session object to have a 30 minute timeout period and generate a session id that is 20 characters long. Any Session object you create after the use generics  declaration will have those configuration parameters available to them. 

The generics module is actually what is called a compiler pragma. Traditionally a pragma is kind of a suggestion made to the compiler so that it might perform some certain kind of optimizations on the code it is compiling. In Perl, pragmas are usually specialized modules that the compiler executes during the compilation process, and are more akin to macros.

While it would be just as simple to just add the parameters to the Session object constructor (new) and configure it each time, this way is cleaner and faster. It is cleaner, because you need not have to remember the parameters each time you create a new Session object (especially since they are unlikely to change throughout the life of your application). And it is faster because the use generics declaration will actually set the parameters during the compilation of the Session object, and not at run-time when you create the object.

The only drawback to the compilation time configuration is that once the module is compiled, those values are set. Of course this is not a drawback if you do not plan on changing the parameters, and want them to stay as they are through the life of your application. If your classes are designed well you will never have a need to change the parameters during runtime. 

If however you do need to change things are runtime, there is a way. This method should only be used as a last resort however. Here is an example:

    generics->change_params(Session => (
                SESSION_TIMEOUT => 10, 
                SESSION_ID_LENGTH => 20
                ));

You do not have to re-use the generics module, as a matter of fact, if you do, you will get some weird results. This should only be used in extreme circumstances, when you have determined there is no other way that will work. It does not restore the default params either, it just changes the already existing ones.

There is also another side to generics. The side that lives within the actual class you are attempting to configure.

Here are 2 examples:

    package Session;
    
    use generics params  => qw(
		SESSION_TIMEOUT
        SESSION_ID_LENGTH
        );

In order for a class to be configured with generics, you must first specify what those parameters are in the class itself. The above statement does just that. The Session object will now only accept those two parameters, and throw an exception otherwise.

Here is the other example:

    package Session;
    
    use generics default_params => (
        SESSION_TIMEOUT => 30,
        SESSION_ID_LENGTH => 20
        );

This example does just what the previous one does in terms of setting up the valid parameters for the Session object, with one difference. It assigns default parameters. Without the default parameters, the Session object would not work, and throw an exception at runtime. With the defaults, you can skip the use generics Session part and the class would just use the installed default values. Also, with defaults, you can choose to only set as many params as you need. Here is an example:

    use generics Session => (SESSION_TIMEOUT => 120);

This code will utilize the default setting for the SESSION_ID_LENGTH param, but change the SESSION_TIMEOUT param to be 120 minutes. 

Another important note is that you can make anything a generic parameter. The following bit of code is a  valid use of generics:

    use generics Session => (
		SESSION_TIMEOUT => sub {
                if (Date->now()->getDayOfWeek() eq "Wednesday") {
                    return 30;
                }
                else {
                    return 120;
                }
        },
        SESSION_ID_LENGTH => 20
        );

The above code uses an anonymous subroutine and the Date object (which can be found in the Utilities category in the iI::Framework) to get the day of the week and if it is Wednesday, it sets the session timeout to 30 minutes, otherwise it sets it to 120. This of course is kind of silly, but it just illustrates that you have alot of flexibility with generics. It is even possible to have an entire method of your class defined with generics if you are so inclined.

The parameters of the Session object can be used much like constants within the class code itself. So for example you might do something like this:

    sub createSessionId {
        my @chars = (a .. z, A .. Z, 0 .. 9);
        return map { $chars[rand()] } (0 .. SESSION_ID_LENGTH);
    }

Now whenever you call createSessionId you can be confident that it will return a string exactly as long as you specified (or not specified if the default_params was used).

=head1 METHODS

=over 4

=item B<change_params ($package, @generic_params)>

If ever you need to change the module configuration you will need to re-import the the configuration. Here is a way to do that (without having to say import which wouldnt make as much sense semanticaly). Keep in mind though that this will not restore the default values originally assigned in the class, it will just overwrite the current ones. 

This will be needed very rarely. If you find yourself using it you should question the reason first, and only use it as a last resort.

=item B<has_generic_params ($package)>

This method is a predicate, returning true (1) if the C<$package> has generic parameters and false (0) otherwise.

=item B<dump_params ($package)>

This will dump a hash of the generic parameters. One important thing to note is that it will execute the parameters, so this may not be very useful for subtroutine ref parameters.

=back

=head1 BUGS

None that I am aware of. The code is pretty thoroughly tested (see L<CODE COVERAGE> below) and is based on an (non-publicly released) module which I had used in production systems for about 2 years without incident. Of course, if you find a bug, let me know, and I will be sure to fix it. 

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, below is the B<Devel::Cover> report on this module's test suite.

 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 File                           stmt branch   cond    sub    pod   time  total
 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 /generics.pm                   98.8  100.0  100.0   92.3  100.0   11.6   98.5
 t/10_generics_test.t          100.0    n/a    n/a  100.0    n/a   19.1  100.0
 t/20_generics_inherit_test.t  100.0    n/a    n/a  100.0    n/a   44.7  100.0
 t/30_generics_errors_test.t   100.0    n/a    n/a  100.0    n/a   19.4  100.0
 t/test_lib/Base.pm            100.0    n/a   33.3  100.0    0.0    0.7   85.0
 t/test_lib/Broken.pm          100.0    n/a    n/a  100.0    n/a    0.2  100.0
 t/test_lib/BrokenThree.pm     100.0    n/a    n/a  100.0    n/a    0.2  100.0
 t/test_lib/BrokenTwo.pm       100.0    n/a    n/a  100.0    n/a    0.2  100.0
 t/test_lib/Derived.pm         100.0    n/a    n/a  100.0    n/a    0.3  100.0
 t/test_lib/Session.pm         100.0    n/a   33.3  100.0    n/a    3.6   91.3
 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 Total                          99.6  100.0   73.3   98.4   66.7  100.0   98.1
 ---------------------------- ------ ------ ------ ------ ------ ------ ------


=head1 SEE ALSO

Nothing I can think of yet. But this module was inspired by the 'constant' pragma, and the desire to assign those constants across module lines. It borrows some of its ideas from other languages, in particular Ada and C++/STL, although our generics are not instance oriented as theirs are. 

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
