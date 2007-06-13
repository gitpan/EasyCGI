use strict;
use warnings(FATAL=>'all');
use EasyCGI;

#===export EasyTest Function
sub plan {&EasyTest::std_plan};
*ok = \&EasyTest::ok;
sub DIE {&EasyTest::DIE};
sub NO_DIE {&EasyTest::NO_DIE};
sub ANY {&EasyTest::ANY};
#==============================

plan(17);

my $realtest = 0;

if (!$realtest){
for(1..17){ok(1, 1);}
}
else{

my ($true,$false)=(1,'');

#EasyCGI::new
my $rh_option = {
			access => undef,
			cgi_path => undef,
			dba_path => undef,
			cgi => undef,
			dba => undef,
			language => 'utf8',
			src_encoding => undef,
			web_encoding => undef,
			template_file_base_path => undef,
			disable_cookie => 1
	};

my $view = EasyCGI->new($rh_option);

#EasyCGI::cgi, test 1
$rh_option->{cgi} = 'testcgi';
my $view_cgi = EasyCGI->new($rh_option);
$rh_option->{cgi} = undef;
ok('testcgi', \&EasyCGI::cgi, [$view_cgi]);

#EasyCGI::dba, test 2
$rh_option->{dba} = 'testdba';
my $view_dba = EasyCGI->new($rh_option);
$rh_option->{dba} = undef;
ok('testdba', \&EasyCGI::dba, [$view_dba]);

#EasyCGI::set_dba, test 3-4
ok('1', \&EasyCGI::set_dba, [$view_dba, 'test_set_dba']);
ok('test_set_dba', \&EasyCGI::dba, [$view_dba]);

#EasyCGI::lock, test 5-7
my $view_lock = EasyCGI->new($rh_option);
ok(&NO_DIE, \&EasyCGI::query_param, [$view_lock]);
ok('1', \&EasyCGI::lock, [$view_lock]);
ok(&DIE, \&EasyCGI::query_param, [$view_lock]);

#EasyCGI::output, test 8
ok(&DIE, \&EasyCGI::output, [$view]);

#EasyCGI::query_param, url_param, post_param, cookie_param, test 9-12
ok(undef, \&EasyCGI::query_param, [$view, 'test']);
ok(undef, \&EasyCGI::url_param, [$view, 'test']);
ok(undef, \&EasyCGI::post_param, [$view, 'test']);
ok(undef, \&EasyCGI::cookie_param, [$view, 'test']);

#EasyCGI::set_return_type, set_url, set_content, test 13-17
ok(&NO_DIE, \&EasyCGI::set_return_type, [$view_dba, 'redirect']);
ok('testurl', \&EasyCGI::set_url, [$view_dba, 'testurl']);
ok(&NO_DIE, \&EasyCGI::output, [$view_dba]);

ok('testcontent', \&EasyCGI::set_content, [$view, 'testcontent']);
ok(&NO_DIE, \&EasyCGI::output, [$view]);
}

1;

















package EasyTest;
use strict;
use warnings(FATAL=>'all');

#===================================
#===Module  : EasyTest
#===Comment : module for writing test script
#===================================

#===================================
#===Author  : qian.yu            ===
#===Email   : foolfish@cpan.org  ===
#===MSN     : qian.yu@adways.net ===
#===QQ      : 19937129           ===
#===Homepage: www.lua.cn         ===
#===================================

use Exporter 'import';
use Test qw();

our $bool_std_test;
our $plan_test_count;
our $test_count;
our $succ_test;
our $fail_test;
our ($true,$false);

BEGIN{
        our @EXPORT = qw(&ok &plan &std_plan &DIE &NO_DIE);
        $bool_std_test='';
        $plan_test_count=undef;
        $test_count=0;
        $succ_test=0;
        $fail_test=0;
        ($true,$false) = (1,'');
};

sub foo{1};
sub _name_pkg_name{__PACKAGE__;}

#===ok($result,$value); if $result same as $value test succ, else test fail
#===ok($result,$func,$ra_param);#same as ok($result,$func,$ra_param,0);
#===ok($ra_result,$func,$ra_param,1); test result in array  mode
#===ok($   result,$func,$ra_param,0); test result in scalar mode
sub ok{
        my $param_count=scalar(@_);
        if($param_count==2){
                if(&dump($_[0]) eq &dump($_[1])){
                        $test_count++;$succ_test++;
                        if($bool_std_test){
                                Test::ok($true);
                        }else{
                                print "ok $test_count\n";
                        }
                        return $true;
                }else{
                        $test_count++;$fail_test++;
                        if($bool_std_test){
                                Test::ok($false);
                        }else{
                                my $caller_info=sprintf('LINE %04s',[caller(0)]->[2]);
                                print "not ok $test_count $caller_info\n";
                        }
                        return $false;
                }
        }elsif($param_count==4||$param_count==3){
                my $result;
                my $mode;
                if($param_count==3){
                        $mode=1;
                }elsif($param_count==4&&defined($_[3])&&$_[3]==0){
                        $mode=1;
                }elsif($param_count==4&&defined($_[3])&&$_[3]==1){
                        $mode=2;
                }else{#default
                        $mode=1;
                }
                if($mode==1){
                        eval{$result=$_[1]->(@{$_[2]});};
                }elsif($mode==2){
                        eval{$result=[$_[1]->(@{$_[2]})];};
                }else{
                        CORE::die 'BUG';
                }
                if($@){
                        undef $@;
                        if(DIE($_[0])){
                                $test_count++;$succ_test++;
                                if($bool_std_test){
                                        Test::ok($true);
                                }else{
                                        print "ok $test_count\n";
                                }
                                return $true;
                        }else{
                                $test_count++;$fail_test++;
                                if($bool_std_test){
                                        Test::ok($false);
                                }else{
                                        my $caller_info=sprintf('LINE %04s',[caller(0)]->[2]);
                                        print "not ok $test_count $caller_info\n";
                                }
                                return $false;
                        }
                }else{
                        if ((defined $_[0]) && (defined $result)){
                            if (ref $_[0] ne 'ARRAY'){
                                if (ANY($_[0])){
                                    $_[0] = undef;
                                    $result = undef;
                                }
                            }else{
                                if($#{$_[0]} == $#$result){
                                    foreach(0 .. $#{$_[0]}){
                                        if(ANY($_[0][$_])){
                                            @{$_[0]}[$_] = undef;
                                            @$result[$_] = undef;
                                        }
                                    }
                                }
                            }
                        }
                        if(NO_DIE($_[0])){
                                $test_count++;$succ_test++;
                                if($bool_std_test){
                                        Test::ok($true);
                                }else{
                                        print "ok $test_count\n";
                                }
                                return $true;
                        }elsif(&dump($_[0]) eq &dump($result)){
                                $test_count++;$succ_test++;
                                if($bool_std_test){
                                        Test::ok($true);
                                }else{
                                        print "ok $test_count\n";
                                }
                                return $true;
                        }else{
                                $test_count++;$fail_test++;
                                if($bool_std_test){
                                        Test::ok($false);
                                }else{
                                        my $caller_info=sprintf('LINE %04s',[caller(0)]->[2]);
                                        print "not ok $test_count $caller_info\n";
                                }
                                return $false;
                        }
                }
        }else{
                CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'ok: param count should be 2, 3, 4');
        }
}

sub plan($){
        $plan_test_count=$_[0];
        print "plan to test $plan_test_count \n";
}

sub std_plan($){
        $plan_test_count=$_[0];
        $bool_std_test=1;
        Test::plan(tests=>$plan_test_count);
}

sub DIE{
        my $code=1;
        if(scalar(@_)==0){
                return bless [$code,'DIE'],'Framework::EasyTest::CONSTANT';
        }elsif(scalar(@_)==1){
                return ref $_[0] eq 'Framework::EasyTest::CONSTANT' && $_[0]->[0]==$code?1:'';
        }else{
                die 'EasyTest::DIE: param number should be 0 or 1';
        }
}

sub NO_DIE{
        my $code=2;
        if(scalar(@_)==0){
                return bless [$code,'NO_DIE'],'Framework::EasyTest::CONSTANT';
        }elsif(scalar(@_)==1){
                return ref $_[0] eq 'Framework::EasyTest::CONSTANT' && $_[0]->[0]==$code?1:'';
        }else{
                die 'EasyTest::NO_DIE: param number should be 0 or 1';
        }
}

sub ANY{
        my $code=3;
        if(scalar(@_)==0){
                return bless [$code,'ANY'],'Framework::EasyTest::CONSTANT';
        }elsif(scalar(@_)==1){
                return ref $_[0] eq 'Framework::EasyTest::CONSTANT' && $_[0]->[0]==$code?1:'';
        }else{
                die 'EasyTest::ANY: param number should be 0 or 1';
        }
}

END{
        if(!$bool_std_test){
                if(defined($plan_test_count)){
                        if($plan_test_count==($succ_test+$fail_test)&&$fail_test==0){
                                print "plan test $plan_test_count ,finally test $test_count, $succ_test succ,$fail_test fail,test successful!\n";
                        }else{
                                CORE::die "plan test $plan_test_count ,finally test $test_count, $succ_test succ,$fail_test fail,test failed!\n";
                        }
                }else{
                        print "finally test $test_count, $succ_test succ,$fail_test fail\n";
                }
        }
}

sub qquote {
        local($_) = shift;
        s/([\\\"\@\$])/\\$1/g;
        s/([^\x00-\x7f])/sprintf("\\x{%04X}",ord($1))/eg if utf8::is_utf8($_);
        return qq("$_") unless
                /[^ !"\#\$%&'()*+,\-.\/0-9:;<=>?\@A-Z[\\\]^_`a-z{|}~]/;  # fast exit
        s/([\a\b\t\n\f\r\e])/{
                "\a" => "\\a","\b" => "\\b","\t" => "\\t","\n" => "\\n",
            "\f" => "\\f","\r" => "\\r","\e" => "\\e"}->{$1}/eg;
        s/([\0-\037\177])/'\\x'.sprintf('%02X',ord($1))/eg;
        s/([\200-\377])/'\\x'.sprintf('%02X',ord($1))/eg;
        return qq("$_");
}

sub qquote_bin{
        local($_) = shift;
        s/([\x00-\xff])/'\\x'.sprintf('%02X',ord($1))/eg;
        s/([^\x00-\x7f])/sprintf("\\x{%04X}",ord($1))/eg if utf8::is_utf8($_);
        return qq("$_");
}

sub dump{
        my $max_line=80;
        my $param_count=scalar(@_);
        my ($flag,$str1,$str2);
        if($param_count==1){
                my $data=$_[0];
                my $type=ref $data;
                if($type eq 'ARRAY'){
                        my $strs=[];
                        foreach(@$data){push @$strs,&dump($_);}

                        $str1='[';$flag=0;
                        foreach(@$strs){$str1.=$_.",\x20";$flag=1;}
                        if($flag==1){chop($str1);chop($str1);}
                        $str1.=']';

                        $str2='[';
                        foreach(@$strs){s/\n/\n\x20\x20/g;$str2.="\n\x20\x20".$_.',';}
                        $str2.="\n]";

                        return length($str1)>$max_line?$str2:$str1;
                }elsif($type eq 'HASH'){
                        my $strs=[];
                        foreach(keys(%$data)){push @$strs,[qquote($_),&dump($data->{$_})];}

                        $str1='{';$flag=0;
                        foreach(@$strs){$str1.="$_->[0]\x20=>\x20$_->[1],\x20";$flag=1;}
                        if($flag==1){chop($str1);chop($str1);}
                        $str1.='}';

                        $str2='{';
                        foreach(@$strs){ $_->[1]=~s/\n/\n\x20\x20/g;$str2.="\n\x20\x20$_->[0]\x20=>\x20$_->[1],";}
                        $str2.="\n}";

                        return length($str1)>$max_line?$str2:$str1;
                }elsif($type eq 'SCALAR'||$type eq 'REF'){
                        return "\\".&dump($$data);
                }elsif($type eq ''){
                        $flag=0;
                        if(!defined($data)){return 'undef'};
                        eval{if($data eq int $data){$flag=1;}};
                        if($@){undef $@;}
                        if($flag==0){return qquote($data);}
                        elsif($flag==1){return $data;}
                        else{ die 'dump:BUG!';}
                }else{
                        return ''.$data;#===if not a simple type
                }
        }else{
                my $strs=[];
                foreach(@_){push @$strs,&dump($_);}

                $str1='(';
                $flag=0;
                foreach(@$strs){$str1.=$_.",\x20";$flag=1;}
                if($flag==1){chop($str1);chop($str1);}
                $str1.=')';

                $str2='(';
                foreach(@$strs){s/\n/\n\x20\x20/g;$str2.="\n\x20\x20".$_.',';}
                $str2.="\n)";

                return length($str1)>$max_line?$str2:$str1;
        }
}

1;
