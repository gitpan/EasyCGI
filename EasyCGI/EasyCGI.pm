#------------------------------------------------------------------------------- 
# 
# File: pk_cgi.pm
# Version: 0.4
# Author: Jeremy Wall
# Definition: Contains all the code to handle working in the CGI environment.
#             This includes building a page for transmitting to a browser,
#             retrieving form data, and setting and retrieving cookies.
#
#-------------------------------------------------------------------------------
package EasyCGI;

require Exporter;
use strict;

my $VERSION = 0.40;

our @ISA = qw(Exporter);
our @EXPORT = qw(cgi_request get_cookie_list get_cookie);

my $RequestType;

#get the request data, automatically determines the method and the encoding
#returns a hash of all the values or null on failure
sub cgi_request {
    my %get_vars;
    
    if (exists $ENV{REQUEST_METHOD}) {
        if ($ENV{REQUEST_METHOD} eq "GET") {
            %get_vars = $ENV{"QUERY_STRING"} =~ m/(?:\A|&)([^=]+)=([^&]+)/g;
            $get_vars{Method} = $ENV{REQUEST_METHOD};
            return %get_vars;
        } elsif ($ENV{REQUEST_METHOD} eq "POST") {
            my $buffer; #Buffer to hold STDIN
            my $boundary; # boundary string for multipart/form-data
            my @FormData; # array holding the form sections separated by the boundaries
            my $FormType;
            my %Elements;
            ($FormType, $boundary) = split(/; boundary=/, $ENV{'CONTENT_TYPE'});
            while (<STDIN>) { 
	            $buffer .= $_;
            }
            
            if ($FormType eq "multipart/form-data") {
                # deal with multipart/form-data uploads
                # eg. a file upload form
                @FormData = split(/$boundary/, $buffer);
                foreach my $FormElement (@FormData) {
                    (my $FormHeader, my $FormValue) = split(/\n\n/, $FormElement);
                    $FormValue =~ s/\n--//;
                    # preparing the Headers for parsing by stripping uneeded data out and 
                    # converting separation data to a more parsable form
                    $FormHeader =~ s/(Content-Disposition: form-data;)|(")|( )//g; #"
                    $FormHeader =~ s/Content-Type/;Content-Type/g;
                    $FormHeader =~ s/:/=/g;
                    $FormHeader =~ s/\nname=//g;
                    if ($FormHeader =~ m/filename=/) {
                       (my $Variable) = $FormHeader =~ m/([^;]+)/;
                       (my $FileName) = $FormHeader =~ m/[^(filename)]+filename=([^;|\n]+)/;
                       (my $FileContentType) = $FormHeader =~ m/[^(Content\-Type=)]+Content\-Type=([^;]+)/;
                       # in the case of File uploads they are stored in a hash containing their name
                       # content type and the contents of the file.
                       my $File = {"name" => $FileName,
                                   "content_type" => $FileContentType, 
                                   "file" => $FormValue};
                       $get_vars{$Variable} = $File                      
                    } else {
                       $get_vars{$FormHeader} = $FormValue if ($FormHeader =~ /[^(--)|(--\n)]/);
                    }
                }
                $get_vars{Method} = $ENV{REQUEST_METHOD};
                $get_vars{Encoding} = $FormType
            } else {
                #dealing with traditional post method
                %get_vars = $buffer =~ m/(?:\A|&)([^=]+)=([^&]+)/g;
                foreach my $key (sort (keys (%get_vars))) {
                     $get_vars{$key} =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
                     $get_vars{$key} =~ tr/+/ /;   
                }
            }
                
            return %get_vars;
        } 
    } else {
       return;
    }
}

#create and initialize our page object with a mime-type
#use the append_to_page and prepend_to_page methods
#to build the page and the print_page method to output it to the web browser
#be sure to add any cookies before you print the page though.
sub new_page {
   my $proto = shift;
   my $ContentType;
   $ContentType = shift or $ContentType = "html"; # we can specify the content type
                                                  # but if we don't then html is assumed.
   my $class = ref($proto) || $proto;
   my $Page = {Header => "Content-type: text/$ContentType\n\n", Page => ""}; 
   return bless($Page, $class); 
}

sub add_cookie {
    my $self = shift;
    my $Cookie = shift;
    
    my $String = "Set-Cookie: " . $$Cookie{Name} . "=";
    if (ref($$Cookie{Value}) eq "HASH") {
        my $CookieValue = $$Cookie{Value};
        foreach my $key (sort(keys(%$CookieValue))) {
            $String = $String . $key . ":" . $$CookieValue{$key} . ",";
        }
    } else {
        $String .= "$$Cookie{Name}:$$Cookie{Value}, ";
        
    }
    
    if (exists ($$Cookie{Path})) {
       ## set cookies path
       $String .= "; path=";
       $String .= $$Cookie{Path};
    }
    if (exists ($$Cookie{Expires})) {
       ## set cookies expiration
       $String .= "; expires=";
       $String .= $$Cookie{Expires};
    }
    if (exists ($$Cookie{Domain})) {
        ## set cookies domain
        $String .= "; domain=";
        $String .= $$Cookie{Domain};
    }
    
    $self->{Header} = $String . "\n" . $self->{Header};
    #print $self->{Header};
}

#use of the get_header Function is deprecated but included for those 
#few instances when it comes in handy.
sub get_header {
    my $self = shift;
 
    return $self->{Header}; 
}

# prints out our webpage after we've built it
sub print_page {
    my $self = shift;
 
    print $self->{Header};
    print  $self->{Page};
}

# Retrieves the page without printing. 
# Useful for debugging or examining the contents before displaying
sub get_page {
    my $self = shift;
 
    return ($self->{Header} . $self->{Page});
}

# method to append things to the end of the page
sub append_to_page {
    my $self = shift;
    my $PageContents = shift;
 
    $self->{Page} .= $PageContents;
}

# method to add things to the beginning of the page
sub prepend_to_page {
    my $self = shift;
    my $PageContents;
 
    $self->{Page} = $PageContents . $self->{Page};
}

sub get_cookie_list {
    my @buffer = split(/;/,$ENV{'HTTP_COOKIE'});
    my %cookies;
    if (exists $ENV{'HTTP_COOKIE'}) {
        foreach my $i (@buffer) {
            (my $Name, my $Value) = split(/=/,$i);
             my @CookieValues = split(/,/, $Value);
             my %CookieVars;
             foreach my $j (@CookieValues) {
                 (my $CookieVariable, my $CookieValue) = split(/:/, $j);
                 $CookieVars{$CookieVariable} = $CookieValue;
             }
             $cookies{$Name} = \%CookieVars;
        }
    return %cookies;
    } else {
        return;
    }
}

sub get_cookie {
    my $CookieId = shift;
    my %CookieVars;
    if (exists $ENV{'HTTP_COOKIE'}) {
        my @buffer = split(/;/,$ENV{'HTTP_COOKIE'});
        foreach my $i (@buffer) {
            #print $i;
            (my $Name, my $Value) = split(/=/,$i);
            if ($CookieId eq $Name) {
                my @buffer2 = split(/,/, $Value);
                foreach my $y (@buffer2) {
                    (my $CVar, my $CVal) = split(/:/, $y);
                    $CookieVars{$CVar} = $CVal;
                    #print "$CVar = $CVal <br>";
                }
                $CookieVars{Status} = 1;
                return %CookieVars;    
            }
        }
    } else {
        return;
    }
        
}

return 1;

=head1 Name

cgi::pk_cgi - Lightweight Perl module for handling the most common CGI functions. Simple to use, single file with no dependencies, and short learning curve
for those times when you don't want or need the swiss army knife of cgi modules.

=head1 Synopsis
    
use cgi::pk_cgi;
    
my $Page = pk_cgi->new_page("html");
    
my $Cookie = {Name => "pklogin", Value => {UserName => $Self->{Env}{username}, Password => $Self->{Env}{password}};
$Page->add_cookie($Cookie);
    
%PKEnv = pk_cgi::cgi_request() 
       or die "No Http Environment";
    
%Cookies = pk_cgi::get_cookie_list()
        or die "no cookies";  
$SomeCookie = $Cookies{SomeCookieName};
$SomeCookieValue = $$SomeCookie(SomeCookieVariable};
         
my $Html = "<html><head><head><body>hello world!!</body></html>";
$Page->append_to_page($Html);
    
$Page->print_page();

=head1 Description

This module handles all the details of sending a document of any content type to a WebBrowser.
It also handles retrieving form data from sent via "get" or "post" in regular or multipart/form-data
encodings(file uploads). It does this transparently to the user through a single interface. Finally it
handles setting and retrieving cookies. It does all this as a standalone module with no dependencies for
an easy install.

The following methods are are available for use in this module.

=head2 class methods

=over 4

=item cgi_request()

Retrieves the form data. It automatically detects the send method and the encoding. The return value is 
a hash with the variable names as keys. In the case of file uploads the value is another hash with the
file information and contents. The file hash contains the following keys (name, content_type, file).

=item get_cookie()

Retrieves a cookie by name. This method only reliably decodes cookies which were set by this script.
It returns a hash of the variables stored in the cookie. The variable names are the keys of the hash.
The method expects to a string containing the name of the cookie you wish to retrieve.

=item get_cookie_list()

Retrieves all the cookies sent by the Browser application. It returns a hash of all the cookies.
The keys of the hash are the names of the cookies. And the values of the keys are hashes of all the variables
in the cookie.


=back

=head3 A note on single value cookies

In the hashes returned for single value cookies the variable name in the hash is the same as the name of the cookie.

=head2 object methods

=over 4

=item new_page()

The constructor for the cgi object. There is an optional string argument which specifies the mime type of the document
html, xml, plain, and so on. IT should be called with the following syntax. pk_cgi->new_page("html");

=item add_cookie()

Sets a cookie in the document header. This function must be called before the print_page function or the
cookie will not be sent. It expects a hash as an argument in the following format:
{Name => "name", Value => "value"} where Value can be either a hash of values stored under
there variable names or a single scalar. You may also include the following optional keys in the hash
Expires, Path, and Domain each one corresponding to their conterpart in a cookie.

=item append_to_page()

Appends a string to the bottom of your document. It is used to build your page before sending with the print_page
method. It expects the string you wish to append as an argument.

=item prepend_to_page()

This is the same as the append_to_page method except it adds the string to the beginning of your document.
It also expects the string you wish to append as an argument.

=item get_header()

This can be used if you only wish to use the header building functionality. It retrieves only the headers for your document.
It is probably not of much use except in debugging perhaps.

=item get_page()

This retrieves your whole document including the headers. you can pring the returned string to send your document to the Browser.
Or you can use the print_page method instead to automatically print it.

=item print_page()

This sends your built page and any cookies set beforehand to your browser. This should be your last act since once called the page
cannot be changed and no more cookies can be set.

=back

=head1 Version

0.4
Written 02-04-2004

=head1 Author

(c) 2003 Jeremy Wall <Jeremy@marzhillstudios.com> http://jeremy.marzhillstudios.com

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 PREREQUISITES

This script requires the C<strict> module.
It also requires the C<Exporter> nmodule
 
=pod OSNAMES

Any

=pod SCRIPT CATEGORIES

CGI

=cut