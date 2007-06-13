package EasyCGI;
use strict;
use warnings(FATAL=>'all');

our $VERSION = '2.0.4';

#===================================
#===Module  : Framework::EasyCGI
#===File    : lib/Framework/EasyCGI.pm
#===Comment : a lib to support cgi
#===Require : File::Basename MIME::Base64 FileHandle CGI Encode
#===Require2: HTML::Template HTML::FillInForm Template EasySession EasyDBAccess
#===================================

#===================================
#===Author  : qian.yu            ===
#===Email   : foolfish@cpan.org  ===
#===MSN     : qian.yu@adways.net ===
#===QQ      : 19937129           ===
#===Homepage: www.lua.cn         ===
#===================================

#=======================================
#===Author  : huang.shuai            ===
#===Email   : huang.shuai@adways.net ===
#===MSN     : huang.shuai@adways.net ===
#=======================================

#TODO support TT

#===2.0.4(2007-03-20): add xml type, can output without header
#===2.0.3(2006-08-23): modified in use
#===2.0.2(2006-08-17): fix tt bugs
#===2.0.1(2006-08-09): support TT
#===2.0.0(2006-08-03): release, add document

use CGI;
use Encode;
use FileHandle;
use MIME::Base64;
use File::Basename;

our $_pkg_name=__PACKAGE__;
sub foo{1};

our $_return_type = ['redirect','txt','html','file','xml'];
our $_encoding    = ['utf-8','ascii','gb2312','gbk','gb18030','euc_jp','shift_jis','iso_2022_jp'];
our $_name_utf8   = 'utf-8';
our $_max_file_len = 100000000;
our $language_encoding = {un=>'utf-8','utf8'=>'utf-8',cn=>'gb2312',jp=>'shift-jis' };

#EasyCGI->new();

#access
#cgi_path
#dba_path

#cgi
#dba

#source code(.cgi) encoding
#web page encoding


sub new{
	my ($class,$option)=@_;

	my $self=bless {},$class;

	#access cgi_path dba_path
	$self->{access}= $option->{access};
	if(defined($self->{access})){
		$self->{cgi_path}=$option->{cgi_path};
		$self->{dba_path}=$option->{dba_path};
	}else{
		$self->{cgi_path}=undef
		$self->{dba_path}=undef;
	}

	#cgi dba
	$self->{cgi}= $option->{cgi};
	$self->{dba}= $option->{dba};

	#language: un cn jp
	my $language=$option->{language};
	if(!defined($language)){$language='un';}
	$self->{language}=$language;
	
	#source code(.cgi) encoding
	my $src_encoding=$option->{src_encoding};
	if(!defined($src_encoding)){$src_encoding=$_name_utf8;}
	$self->{src_encoding}=$src_encoding;

	#web page encoding
	my $web_encoding=$option->{web_encoding};
	if(!defined($web_encoding)){$web_encoding=$language_encoding->{$language};}
	$self->{web_encoding}=$web_encoding;

	#if null, use absolute file path
	$self->{template_file_base_path}=$option->{template_file_base_path};

	#disable cookie
	my $disable_cookie=$option->{disable_cookie};
	if(!defined($disable_cookie)){$disable_cookie=''};
	$self->{disable_cookie}=$disable_cookie;
	#to store cookies
	$self->{cookie}=[];

	#session support
	$self->{session_group}='';
	$self->{session_expire}=3600;
	$self->{session_ip_check}=1;

	#if locked, then cannot read param any more
	$self->{lock}=0;

	#one of $_return_type, must set one
	$self->{return_type}='html';
	$self->{return_type_set_flag}='';

#==2.0.1==
	$self->{tmpl_type}	=	'tmpl';
	$self->{tmpl_type_set_flag}='';
#===end===

	#REDIRECT
	$self->{redirect_url}	  = undef;

	#TXT
	$self->{txt_encoding}	  = $web_encoding;
	$self->{txt_content}      = undef;
	$self->{txt_tmpl_scalar}  = undef;
	$self->{txt_tmpl}         = undef;
	$self->{txt_tmpl_var}     = undef;
	$self->{txt_fill_var}     = undef;

	#HTML
	$self->{html_encoding}    = $web_encoding;
	$self->{html_content}     = undef;
	$self->{html_tmpl_scalar} = undef;
	$self->{html_tmpl}        = undef;
	$self->{html_tmpl_var}    = undef;
	$self->{html_fill_var}    = undef;

	#XML
	$self->{xml_content}      = undef;
	$self->{xml_tmpl_scalar}  = undef;
	$self->{xml_tmpl}         = undef;
	$self->{xml_tmpl_var}     = undef;

	#FILE
	$self->{file_encoding}	  = $language_encoding->{$language};
	$self->{file}             = undef;
	
	$self->{need_output}	  = 0;	

	return $self;
}

sub set_option{
#TODO set some option in new function
}

#cgi for normal use
sub cgi{
	my $self=shift;
	if (!defined($self->{cgi})){
		if(defined($self->{access})&&defined($self->{cgi_path})){
			$self->{cgi}=$self->{access}->func($self->{cgi_path},&Framework::Common::FETCH);
		}else{
			$self->{cgi}=CGI->new();
		}
	}
	return $self->{cgi};
}

sub dba{
	my $self=shift;
	if (!defined($self->{dba})&&defined($self->{dba_path})){
		$self->{dba}=$self->{access}->func($self->{dba_path},&Framework::Common::FETCH);
	}
	return $self->{dba};
}

sub set_dba{
	my $self=shift;
	my ($dba)=@_;
	$self->{dba}=$dba;
	return 1;
}


sub lock{
	my $self=shift;
	$self->{lock}=1;
}

sub output{
	my $self=shift;
	my $q=$self->cgi();

	my $return_type=$self->{return_type};

	my $output=undef;
	#write type
	if(in($return_type,'redirect')){
		if(!defined($self->{redirect_url})){
			CORE::die $_pkg_name."::output: redirect_url not set";
		}
		$output=$q->redirect(-url=>$self->{redirect_url},-cookie=>$self->{cookie});
	}elsif(in($return_type,'txt')){
		if(defined($self->{txt_content})){
			$output =$q->header(-type=>'text/plain',-charset=>$self->{txt_encoding},-cookie=>$self->{cookie});
			$output.=$self->{txt_content};
			if(defined($self->{txt_fill_var})){
				require HTML::FillInForm; #=2.0.2==
				my $fif = HTML::FillInForm->new();
				$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
			}
		}elsif(defined($self->{txt_tmpl_scalar})){
#==2.0.1==
				if ($self->{tmpl_type} eq 'tmpl'){
#===end===
						require HTML::Template; #==2.0.2==
						my $t=HTML::Template->new(
							scalarref         =>\$self->{txt_tmpl_scalar},
							global_vars       => 1,
							die_on_bad_params => 0,
						);
						if(defined($self->{txt_tmpl_var})){
							$t->param(%{$self->{txt_tmpl_var}});
						}
						$output =$q->header(-type=>'text/plain',-charset=>$self->{txt_encoding},-cookie=>$self->{cookie});
						$output.=$t->output();
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t=Template->new();
						my $tt_out = '';
						$t->process($self->{txt_tmpl_scalar}, $self->{txt_tmpl_var}, \$tt_out); #==2.0.2==
						$output =$q->header(-type=>'text/plain',-charset=>$self->{txt_encoding},-cookie=>$self->{cookie});
						$output.=$tt_out;
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}elsif(defined($self->{txt_tmpl})){
#==2.0.1==
				if ($self->{tmpl_type} eq 'tmpl'){
#===end===
						require HTML::Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){
							$t=HTML::Template->new(
								filename          => $self->{txt_tmpl},
								path              => [$self->{template_file_base_path}],
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);
						}else{
							$t=HTML::Template->new(
								filename          => $self->{txt_tmpl},
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);			
						}
						if(defined($self->{txt_tmpl_var})){
							$t->param(%{$self->{txt_tmpl_var}});
						}
						$output =$q->header(-type=>'text/plain',-charset=>$self->{txt_encoding},-cookie=>$self->{cookie});
						$output.=$t->output();
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){ #==2.0.3==
							$t=Template->new(
									INCLUDE_PATH => $self->{template_file_base_path},  #==2.0.3==
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}else{
							$t=Template->new(
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}
						my $tt_out = '';
						$t->process($self->{txt_tmpl}, $self->{txt_tmpl_var}, \$tt_out); #==2.0.2==
						$output =$q->header(-type=>'text/plain',-charset=>$self->{txt_encoding},-cookie=>$self->{cookie});
						$output.=$tt_out;
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}else{
			CORE::die $_pkg_name."::output: cannot generate txt content";
		}
	}elsif(in($return_type,'html')){
		if(defined($self->{html_content})){
			$output =$q->header(-type=>'text/html',-charset=>$self->{html_encoding},-cookie=>$self->{cookie});
			$output.=$self->{html_content};
			if(defined($self->{html_fill_var})){
				require HTML::FillInForm; #=2.0.2==
				my $fif = HTML::FillInForm->new();
				$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
			}
		}elsif(defined($self->{html_tmpl_scalar})){
				if ($self->{tmpl_type} eq 'ht'){  #==2.0.3==
						require HTML::Template; #==2.0.2==
						my $t=HTML::Template->new(
							scalarref         =>\$self->{html_tmpl_scalar},
							global_vars       => 1,
							die_on_bad_params => 0,
						);
						if(defined($self->{html_tmpl_var})){
							$t->param(%{$self->{html_tmpl_var}});
						}
						$output =$q->header(-type=>'text/html',-charset=>$self->{html_encoding},-cookie=>$self->{cookie});
						$output.=$t->output();
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t=Template->new();
						my $tt_out = '';
						$t->process($self->{html_tmpl_scalar}, $self->{html_tmpl_var}, \$tt_out); #==2.0.2==
						$output =$q->header(-type=>'text/html',-charset=>$self->{html_encoding},-cookie=>$self->{cookie});
						$output.=$tt_out;
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}elsif(defined($self->{html_tmpl})){
				if ($self->{tmpl_type} eq 'ht'){  #==2.0.3==
						require HTML::Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){
							$t=HTML::Template->new(
								filename          => $self->{html_tmpl},
								path              => [$self->{template_file_base_path}],
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);
						}else{
							$t=HTML::Template->new(
								filename          => $self->{html_tmpl},
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);			
						}
						if(defined($self->{html_tmpl_var})){
							$t->param(%{$self->{html_tmpl_var}});
						}
						$output =$q->header(-type=>'text/html',-charset=>$self->{html_encoding},-cookie=>$self->{cookie});
						$output.=$t->output();
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){  #==2.0.3==
							$t=Template->new(
									INCLUDE_PATH => $self->{template_file_base_path},  #==2.0.3==
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}else{
							$t=Template->new(
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}
						my $tt_out = '';
						$t->process($self->{html_tmpl}, $self->{html_tmpl_var}, \$tt_out); #==2.0.2==
						$output =$q->header(-type=>'text/html',-charset=>$self->{html_encoding},-cookie=>$self->{cookie});
						$output.=$tt_out;
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}else{
#==2.0.1==
#			CORE::die $_pkg_name."::output: cannot generate txt content";
			CORE::die $_pkg_name."::output: cannot generate html content";
#===end===
		}
	}elsif(in($return_type,'file')){
		if(defined($self->{file})){
			my ($file,$src_encoding,$dst_encoding)=($self->{file},$self->{src_encoding},$self->{file_encoding});
			if($file->{content_disposion} eq 'attachment'){
				#Content-Disposition: attachment; filename="bazs.cert"
				#Content-Type: application/octet-stream;
				my $file_name_str=change_encoding($file->{file_name},$src_encoding,$dst_encoding);
				$output=$q->header(-type=>$file->{content_type},-cookie=>$self->{cookie},-attachment=>$file_name_str);
				
			}elsif($file->{content_disposion} eq 'inline'){
				#Content-Type: application/octet-stream;
				$output=$q->header(-type=>$file->{content_type},-cookie=>$self->{cookie});
			}else{
				CORE::die $_pkg_name."::output:BUG  please report it";
			}
			$output.=$file->{file_bin};
		}else{
			CORE::die $_pkg_name."::output: cannot generate file content";
		}
	}elsif(in($return_type,'xml')){
		if(defined($self->{xml_content})){
			$output =$q->header(-type=>'text/xml');
			$output.=$self->{xml_content};
		}elsif(defined($self->{xml_tmpl_scalar})){
				if ($self->{tmpl_type} eq 'tmpl'){
						require HTML::Template; #==2.0.2==
						my $t=HTML::Template->new(
							scalarref         =>\$self->{xml_tmpl_scalar},
							global_vars       => 1,
							die_on_bad_params => 0,
						);
						if(defined($self->{xml_tmpl_var})){
							$t->param(%{$self->{xml_tmpl_var}});
						}
						$output =$q->header(-type=>'text/xml');
						$output.=$t->output();
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template;
						my $t=Template->new();
						my $tt_out = '';
						$t->process($self->{xml_tmpl_scalar}, $self->{xml_tmpl_var}, \$tt_out);
						$output =$q->header(-type=>'text/xml');
						$output.=$tt_out;
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
		}elsif(defined($self->{xml_tmpl})){
				if ($self->{tmpl_type} eq 'tmpl'){
						require HTML::Template; 
						my $t;
						if(defined($self->{template_file_base_path})){
							$t=HTML::Template->new(
								filename          => $self->{xml_tmpl},
								path              => [$self->{template_file_base_path}],
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);
						}else{
							$t=HTML::Template->new(
								filename          => $self->{xml_tmpl},
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);			
						}
						if(defined($self->{xml_tmpl_var})){
							$t->param(%{$self->{xml_tmpl_var}});
						}
						$output =$q->header(-type=>'text/xml');
						$output.=$t->output();
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; 
						my $t;
						if(defined($self->{template_file_base_path})){ 
							$t=Template->new(
									INCLUDE_PATH => $self->{template_file_base_path}, 
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}else{
							$t=Template->new(
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}
						my $tt_out = '';
						$t->process($self->{xml_tmpl}, $self->{xml_tmpl_var}, \$tt_out);
						$output =$q->header(-type=>'text/xml');
						$output.=$tt_out;
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
		}else{
			CORE::die $_pkg_name."::output: cannot generate xml content";
		}
	}else{
		CORE::die $_pkg_name."::output: return_type not set";
	}
	return $output;
}

sub output_without_header{
	my $self=shift;
	my $q=$self->cgi();

	my $return_type=$self->{return_type};

	my $output=undef;
	#write type
	if(in($return_type,'redirect')){
		if(!defined($self->{redirect_url})){
			CORE::die $_pkg_name."::output: redirect_url not set";
		}
		$output=$q->redirect(-url=>$self->{redirect_url},-cookie=>$self->{cookie});
	}elsif(in($return_type,'txt')){
		if(defined($self->{txt_content})){
			$output ='';
			$output.=$self->{txt_content};
			if(defined($self->{txt_fill_var})){
				require HTML::FillInForm; #=2.0.2==
				my $fif = HTML::FillInForm->new();
				$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
			}
		}elsif(defined($self->{txt_tmpl_scalar})){
#==2.0.1==
				if ($self->{tmpl_type} eq 'tmpl'){
#===end===
						require HTML::Template; #==2.0.2==
						my $t=HTML::Template->new(
							scalarref         =>\$self->{txt_tmpl_scalar},
							global_vars       => 1,
							die_on_bad_params => 0,
						);
						if(defined($self->{txt_tmpl_var})){
							$t->param(%{$self->{txt_tmpl_var}});
						}
						$output ='';
						$output.=$t->output();
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t=Template->new();
						my $tt_out = '';
						$t->process($self->{txt_tmpl_scalar}, $self->{txt_tmpl_var}, \$tt_out); #==2.0.2==
						$output ='';
						$output.=$tt_out;
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}elsif(defined($self->{txt_tmpl})){
#==2.0.1==
				if ($self->{tmpl_type} eq 'tmpl'){
#===end===
						require HTML::Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){
							$t=HTML::Template->new(
								filename          => $self->{txt_tmpl},
								path              => [$self->{template_file_base_path}],
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);
						}else{
							$t=HTML::Template->new(
								filename          => $self->{txt_tmpl},
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);			
						}
						if(defined($self->{txt_tmpl_var})){
							$t->param(%{$self->{txt_tmpl_var}});
						}
						$output ='';
						$output.=$t->output();
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){ #==2.0.3==
							$t=Template->new(
									INCLUDE_PATH => $self->{template_file_base_path},  #==2.0.3==
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}else{
							$t=Template->new(
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}
						my $tt_out = '';
						$t->process($self->{txt_tmpl}, $self->{txt_tmpl_var}, \$tt_out); #==2.0.2==
						$output ='';
						$output.=$tt_out;
						if(defined($self->{txt_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{txt_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}else{
			CORE::die $_pkg_name."::output: cannot generate txt content";
		}
	}elsif(in($return_type,'html')){
		if(defined($self->{html_content})){
			$output ='';
			$output.=$self->{html_content};
			if(defined($self->{html_fill_var})){
				require HTML::FillInForm; #=2.0.2==
				my $fif = HTML::FillInForm->new();
				$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
			}
		}elsif(defined($self->{html_tmpl_scalar})){
				if ($self->{tmpl_type} eq 'ht'){  #==2.0.3==
						require HTML::Template; #==2.0.2==
						my $t=HTML::Template->new(
							scalarref         =>\$self->{html_tmpl_scalar},
							global_vars       => 1,
							die_on_bad_params => 0,
						);
						if(defined($self->{html_tmpl_var})){
							$t->param(%{$self->{html_tmpl_var}});
						}
						$output ='';
						$output.=$t->output();
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t=Template->new();
						my $tt_out = '';
						$t->process($self->{html_tmpl_scalar}, $self->{html_tmpl_var}, \$tt_out); #==2.0.2==
						$output ='';
						$output.=$tt_out;
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}elsif(defined($self->{html_tmpl})){
				if ($self->{tmpl_type} eq 'ht'){  #==2.0.3==
						require HTML::Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){
							$t=HTML::Template->new(
								filename          => $self->{html_tmpl},
								path              => [$self->{template_file_base_path}],
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);
						}else{
							$t=HTML::Template->new(
								filename          => $self->{html_tmpl},
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);			
						}
						if(defined($self->{html_tmpl_var})){
							$t->param(%{$self->{html_tmpl_var}});
						}
						$output ='';
						$output.=$t->output();
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
#==2.0.1==
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; #==2.0.2==
						my $t;
						if(defined($self->{template_file_base_path})){  #==2.0.3==
							$t=Template->new(
									INCLUDE_PATH => $self->{template_file_base_path},  #==2.0.3==
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}else{
							$t=Template->new(
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}
						my $tt_out = '';
						$t->process($self->{html_tmpl}, $self->{html_tmpl_var}, \$tt_out); #==2.0.2==
						$output ='';
						$output.=$tt_out;
						if(defined($self->{html_fill_var})){
							require HTML::FillInForm; #=2.0.2==
							my $fif = HTML::FillInForm->new();
							$output=$fif->fill(scalarref => \$output, fdat=>$self->{html_fill_var});
						}
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
#===end===
		}else{
#==2.0.1==
#			CORE::die $_pkg_name."::output: cannot generate txt content";
			CORE::die $_pkg_name."::output: cannot generate html content";
#===end===
		}
	}elsif(in($return_type,'file')){
		if(defined($self->{file})){
			my ($file,$src_encoding,$dst_encoding)=($self->{file},$self->{src_encoding},$self->{file_encoding});
			if($file->{content_disposion} eq 'attachment'){
				#Content-Disposition: attachment; filename="bazs.cert"
				#Content-Type: application/octet-stream;
				my $file_name_str=change_encoding($file->{file_name},$src_encoding,$dst_encoding);
				$output='';
				
			}elsif($file->{content_disposion} eq 'inline'){
				#Content-Type: application/octet-stream;
				$output='';
			}else{
				CORE::die $_pkg_name."::output:BUG  please report it";
			}
			$output.=$file->{file_bin};
		}else{
			CORE::die $_pkg_name."::output: cannot generate file content";
		}
	}elsif(in($return_type,'xml')){
		if(defined($self->{xml_content})){
			$output ='';
			$output.=$self->{xml_content};
		}elsif(defined($self->{xml_tmpl_scalar})){
				if ($self->{tmpl_type} eq 'tmpl'){
						require HTML::Template; #==2.0.2==
						my $t=HTML::Template->new(
							scalarref         =>\$self->{xml_tmpl_scalar},
							global_vars       => 1,
							die_on_bad_params => 0,
						);
						if(defined($self->{xml_tmpl_var})){
							$t->param(%{$self->{xml_tmpl_var}});
						}
						$output ='';
						$output.=$t->output();
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template;
						my $t=Template->new();
						my $tt_out = '';
						$t->process($self->{xml_tmpl_scalar}, $self->{xml_tmpl_var}, \$tt_out);
						$output ='';
						$output.=$tt_out;
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
		}elsif(defined($self->{xml_tmpl})){
				if ($self->{tmpl_type} eq 'tmpl'){
						require HTML::Template; 
						my $t;
						if(defined($self->{template_file_base_path})){
							$t=HTML::Template->new(
								filename          => $self->{xml_tmpl},
								path              => [$self->{template_file_base_path}],
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);
						}else{
							$t=HTML::Template->new(
								filename          => $self->{xml_tmpl},
								global_vars       => 1,
								die_on_bad_params => 0,
								cache             => 1,
							);			
						}
						if(defined($self->{xml_tmpl_var})){
							$t->param(%{$self->{xml_tmpl_var}});
						}
						$output ='';
						$output.=$t->output();
				} elsif ($self->{tmpl_type} eq 'tt'){
						require Template; 
						my $t;
						if(defined($self->{template_file_base_path})){ 
							$t=Template->new(
									INCLUDE_PATH => $self->{template_file_base_path}, 
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}else{
							$t=Template->new(
									ABSOLUTE => 1, 
									RELATIVE => 1
							);
						}
						my $tt_out = '';
						$t->process($self->{xml_tmpl}, $self->{xml_tmpl_var}, \$tt_out);
						$output ='';
						$output.=$tt_out;
				} else{
						CORE::die $_pkg_name."::output: tmpl_type not set";
				}
		}else{
			CORE::die $_pkg_name."::output: cannot generate xml content";
		}
	}else{
		CORE::die $_pkg_name."::output: return_type not set";
	}
	return $output;
}

#first  look up in url    param
#second look up in post   param
#third  look up in cookie param
sub query_param{
	my $self=shift;
	if($self->{lock}){
		CORE::die $_pkg_name."::query_param: the object is locked, read param is not allowed";
	}
	my $cgi=$self->cgi();
	my $param_count=scalar(@_);
	if($param_count==0){
		return $cgi->param();
	}elsif($param_count==1){
		local $_=$_[0];
		if(defined($_)&&(ref $_ eq '')){
			if(defined($cgi->url_param($_))){
				return $cgi->url_param($_);
			}elsif(defined($cgi->param($_))){
				return $cgi->param($_);
			}elsif(defined($cgi->cookie($_))){
				return wantarray?($cgi->cookie($_)):$cgi->cookie($_);
			}else{
#==2.0.0==
#				return wantarray?($cgi->cookie($_)):$cgi->cookie($_);
				return wantarray?(undef):undef;
#===end===
			}
		}else{
			CORE::die $_pkg_name."::query_param: $1 must be a scalar not null";
		}
	}else{
		CORE::die $_pkg_name."::query_param: param count should be 1";
	}
}

#look up in url    param
sub url_param{
	my $self=shift;
	if($self->{lock}){
		CORE::die $_pkg_name."::url_param: the object is locked, read param is not allowed";
	}
	my $cgi=$self->cgi();
	my $param_count=scalar(@_);
	if($param_count==1){
		local $_=$_[0];
		if(defined($_)&&(ref $_ eq '')){
			return $cgi->url_param($_);
		}else{
			CORE::die $_pkg_name."::url_param: $1 must be a scalar not null";
		}
	}else{
		CORE::die $_pkg_name."::url_param: param count should be 1";
	}
}

#first  look up in post   param
#second look up in url    param
sub post_param{
	my $self=shift;
	if($self->{lock}){
		CORE::die $_pkg_name."::post_param: the object is locked, read param is not allowed";
	}
	my $cgi=$self->cgi();
	my $param_count=scalar(@_);
	if($param_count==1){
		local $_=$_[0];
		if(defined($_)&&(ref $_ eq '')){
			return $cgi->param($_);
		}else{
			CORE::die $_pkg_name."::post_param: $1 must be a scalar not null";
		}
	}else{
		CORE::die $_pkg_name."::post_param: param count should be 1";
	}
}

sub cookie_param{
	my $self=shift;
	if($self->{lock}){
		CORE::die $_pkg_name."::cookie_param: the object is locked, read param is not allowed";
	}
	my $cgi=$self->cgi();
	my $param_count=scalar(@_);
	if($param_count==1){
		local $_=$_[0];
		if(defined($_)&&(ref $_ eq '')){
			return $cgi->cookie($_);
		}else{
			CORE::die $_pkg_name."::cookie_param: $1 must be a scalar not null";
		}
	}else{
		CORE::die $_pkg_name."::cookie_param: param count should be 1";
	}
}

sub file{
	my $self=shift;
	if($self->{lock}){
		CORE::die $_pkg_name."::file: the object is locked, read param is not allowed";
	}
	my $cgi=$self->cgi();
	my $param_count=scalar(@_);
	if($param_count==1){
		local $_=$_[0];
		if(defined($_)&&(ref $_ eq '')){
			my $files=[];
			my $file_names=[$cgi->upload($_)];
			foreach(@$file_names){
				my $file_bin;
				binmode($_);
				read($_,$file_bin,$_max_file_len);
				push @$files,{file_name=>[/^((?:.*[:\\\/])?)(.*)/s]->[1],file_bin=>$file_bin};
			}
			return wantarray?@$files:$files->[0];
		}else{
			CORE::die $_pkg_name."::file: $1 must be a scalar not null";
		}
	}else{
		CORE::die $_pkg_name."::file: param count should be 1";
	}
}

sub push_cookie{
	my $self=shift;
	my $cgi=$self->cgi();
	my $param_count=scalar(@_);
	if($param_count==1){
		local $_=$_[0];
		my $cookies=$self->{cookie};
		if($self->{disable_cookie}){
			CORE::die $_pkg_name."::push_cookie: cookie is disable";
		}
		push @$cookies,$_;
	}else{
		CORE::die $_pkg_name."::push_cookie: param count should be 1";
	}
}

sub cookie{
	my $self=shift;
	my $cgi=$self->cgi();
	return $cgi->cookie(@_);
}


sub set_return_type{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($return_type,$param2)=@_;
	if($self->{return_type_set_flag}){
		CORE::die $_pkg_name."::set_return_type: cannot set return_type more than once";
	}
	#['redirect','txt','html','file','xml']
	if(in($return_type,'html')){
		$self->{return_type}=$return_type;
		$self->{return_type_set_flag}=1;
		$self->{need_output}=1;
		if(defined($param2)){
			$self->{html_encoding}=$param2;
		}
	}elsif(in($return_type,'txt')){
		$self->{return_type}=$return_type;
		$self->{return_type_set_flag}=1;
		$self->{need_output}=1;
		if(defined($param2)){
#==2.0.0==
#			$self->{html_encoding}=$param2;
			$self->{txt_encoding}=$param2;
#===end===
		}
	}elsif(in($return_type,'redirect')){
		$self->{return_type}=$return_type;
		$self->{return_type_set_flag}=1;
		$self->{need_output}=1;
	}elsif(in($return_type,'file') ){
		$self->{return_type}=$return_type;
		$self->{return_type_set_flag}=1;
		$self->{need_output}=1;
	}elsif(in($return_type,'xml') ){
		$self->{return_type}=$return_type;
		$self->{return_type_set_flag}=1;
		$self->{need_output}=1;
	}else{
		CORE::die $_pkg_name."::set_return_type: unknown return_type";
	}
}

#==2.0.1==
sub set_tmpl_type{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($tmpl_type)=@_;
	if($self->{tmpl_type_set_flag}){
		CORE::die $_pkg_name."::set_tmpl_type: cannot set tmpl_type more than once";
	}
	#['ht','tt']  #==2.0.3==
	if(in($tmpl_type,'ht')){  #==2.0.3==
		$self->{tmpl_type}=$tmpl_type;
		$self->{tmpl_type_set_flag}=1;
	}elsif(in($tmpl_type,'tt')){
		$self->{tmpl_type}=$tmpl_type;
		$self->{tmpl_type_set_flag}=1;
	}else{
		CORE::die $_pkg_name."::set_tmpl_type: unknown tmpl_type";
	}
}
#===end===

sub set_url{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($url)=@_;
	if(!(defined($url)&&(length($url)>=1))){
		CORE::die $_pkg_name."::set_url: url must be a string length>0";
	}
	if(in($self->{return_type},'redirect')){
		if(defined($self->{redirect_url})){
			CORE::die $_pkg_name."::set_url: cannot set redirect_url more than once";
		}else{
			$self->{redirect_url}=$url;
		}
	}else{
		CORE::die $_pkg_name."::set_url: these kind of return_type cannot set url";
	}
}

sub set_content{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($content)=@_;
	if(!defined($content)){
		CORE::die $_pkg_name."::set_content: content must be a string";
	}
	if(in($self->{return_type},'txt')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{txt_content})){
			CORE::die $_pkg_name."::set_content: cannot set txt_content more than once";
		}elsif(defined($self->{txt_tmpl_scalar})||defined($self->{txt_tmpl})){
			CORE::die $_pkg_name."::set_content: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{txt_content}=$content;
		}	
	}elsif(in($self->{return_type},'html')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{html_content})){
			CORE::die $_pkg_name."::set_content: cannot set html_content more than once";
		}elsif(defined($self->{html_tmpl_scalar})||defined($self->{html_tmpl})){
			CORE::die $_pkg_name."::set_content: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{html_content}=$content;
		}
	}elsif(in($self->{return_type},'xml')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{xml_content})){
			CORE::die $_pkg_name."::set_content: cannot set xml_content more than once";
		}else{
			$self->{xml_content}=$content;
		}
	}else{
		CORE::die $_pkg_name."::set_content: these kind of return_type cannot set content";
	}
}

sub set_tmpl{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($tmpl)=@_;
	if(!(defined($tmpl)&&(length($tmpl)>=1))){
		CORE::die $_pkg_name."::set_tmpl: tmpl must be a string length>0";
	}
	if(in($self->{return_type},'txt')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{txt_tmpl})){
			CORE::die $_pkg_name."::set_tmpl: cannot set txt_tmpl more than once";
		}elsif(defined($self->{txt_tmpl_scalar})||defined($self->{txt_content})){
			CORE::die $_pkg_name."::set_tmpl: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{txt_tmpl}=$tmpl;
		}	
	}elsif(in($self->{return_type},'html')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{html_tmpl})){
			CORE::die $_pkg_name."::set_tmpl: cannot set html_tmpl more than once";
		}elsif(defined($self->{html_tmpl_scalar})||defined($self->{html_content})){
			CORE::die $_pkg_name."::set_tmpl: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{html_tmpl}=$tmpl;
		}	
	}elsif(in($self->{return_type},'xml')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{xml_tmpl})){
			CORE::die $_pkg_name."::set_tmpl: cannot set xml_tmpl more than once";
		}elsif(defined($self->{xml_tmpl_scalar})||defined($self->{xml_content})){
			CORE::die $_pkg_name."::set_tmpl: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{xml_tmpl}=$tmpl;
		}	
	}else{
		CORE::die $_pkg_name."::set_tmpl: these kind of return_type cannot set tmpl";
	}
}

sub set_tmpl_scalar{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($tmpl_scalar)=@_;
	if(!defined($tmpl_scalar)){
#==2.0.1==
#		CORE::die $_pkg_name."::set_tmpl: tmpl_scalar must be a string";
		CORE::die $_pkg_name."::set_tmpl_scalar: tmpl_scalar must be a string";
#===end===
	}
	if(in($self->{return_type},'txt')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{txt_tmpl_scalar})){
			CORE::die $_pkg_name."::set_tmpl_scalar: cannot set txt_tmpl_scalar more than once";
		}elsif(defined($self->{txt_tmpl})||defined($self->{txt_content})){
			CORE::die $_pkg_name."::set_tmpl: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{txt_tmpl_scalar}=$tmpl_scalar;
		}
	}elsif(in($self->{return_type},'html')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{html_tmpl_scalar})){
			CORE::die $_pkg_name."::set_tmpl_scalar: cannot set html_tmpl_scalar more than once";
		}elsif(defined($self->{html_tmpl})||defined($self->{html_content})){
			CORE::die $_pkg_name."::set_tmpl: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{html_tmpl_scalar}=$tmpl_scalar;
		}
	}elsif(in($self->{return_type},'xml')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{xml_tmpl_scalar})){
			CORE::die $_pkg_name."::set_tmpl_scalar: cannot set xml_tmpl_scalar more than once";
		}elsif(defined($self->{xml_tmpl})||defined($self->{xml_content})){
			CORE::die $_pkg_name."::set_tmpl: u can set only one of 'content'/'tmpl'/'tmpl_scalar'";
		}else{
			$self->{xml_tmpl_scalar}=$tmpl_scalar;
		}
	}else{
		CORE::die $_pkg_name."::set_tmpl_scalar: these kind of return_type cannot set tmpl_scalar";
	}
}

sub set_tmpl_var{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($tmpl_var)=@_;
	if(ref($tmpl_var) ne 'HASH'){
		CORE::die $_pkg_name.'::set_tmpl_var: param $1 must be an HASH';
	}
	if(in($self->{return_type},'txt')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{txt_tmpl_var})){
			CORE::die $_pkg_name."::set_tmpl_var: cannot set txt_tmpl_var more than once";
		}elsif(defined($self->{txt_tmpl})||defined($self->{txt_tmpl_scalar})){
			$self->{txt_tmpl_var}=$tmpl_var;
		}else{
			CORE::die $_pkg_name."::set_tmpl_var: cannot set tmpl_var";
		}
	}elsif(in($self->{return_type},'html')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{html_tmpl_var})){
#==2.0.1==
#			CORE::die $_pkg_name."::set_tmpl_var: cannot set txt_tmpl_var more than once";
			CORE::die $_pkg_name."::set_tmpl_var: cannot set html_tmpl_var more than once";
#===end===
		}elsif(defined($self->{html_tmpl})||defined($self->{html_tmpl_scalar})){
			$self->{html_tmpl_var}=$tmpl_var;
		}else{
			CORE::die $_pkg_name."::set_tmpl_var: cannot set tmpl_var";
		}
	}elsif(in($self->{return_type},'xml')){
		$self->{return_type_set_flag}=1;
		if(defined($self->{xml_tmpl_var})){
			CORE::die $_pkg_name."::set_tmpl_var: cannot set xml_tmpl_var more than once";
		}elsif(defined($self->{xml_tmpl})||defined($self->{xml_tmpl_scalar})){
			$self->{xml_tmpl_var}=$tmpl_var;
		}else{
			CORE::die $_pkg_name."::set_tmpl_var: cannot set tmpl_var";
		}
	}else{
#==2.0.1==
#		CORE::die $_pkg_name."::set_tmpl_scalar: these kind of return_type cannot set tmpl_scalar";
		CORE::die $_pkg_name."::set_tmpl_var: these kind of return_type cannot set tmpl_var";
#===end===
	}
}

sub set_fill_var{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($fill_var)=@_;
	if(ref($fill_var) ne 'HASH'){
		CORE::die $_pkg_name.'::set_fill_var: param $1 must be an HASH';
	}
	if(in($self->{return_type},'txt')){
		if(defined($self->{txt_fill_var})){
			CORE::die $_pkg_name."::set_fill_var: cannot set txt_fill_var more than once";
		}else{
			$self->{txt_fill_var}=$fill_var;
		}
	}elsif(in($self->{return_type},'html')){
		if(defined($self->{html_fill_var})){
			CORE::die $_pkg_name."::set_fill_var: cannot set html_fill_var more than once";
		}else{
			$self->{html_fill_var}=$fill_var;
		}
	}else{
		CORE::die $_pkg_name."::set_tmpl_scalar: these kind of return_type cannot set tmpl_scalar";
	}
}

sub set_fill_back{
	my $self=shift;
	my $cgi=$self->cgi();
	my ($ra_keys)=@_;
	if(ref($ra_keys) ne 'ARRAY'){
		CORE::die $_pkg_name.'::set_fill_var: param $1 must be an ARRAY';
	}
	if(in($self->{return_type},'txt')){
		if(defined($self->{txt_fill_var})){
			my $fill_var=$self->{txt_fill_var};
			foreach(@$ra_keys){
				$fill_var->{$_}=$self->query_param($_);
			}
		}else{
			my $fill_var={};
			foreach(@$ra_keys){
				$fill_var->{$_}=$self->query_param($_);
			}
			$self->{txt_fill_var}=$fill_var;
		}
	}elsif(in($self->{return_type},'html')){
		if(defined($self->{html_fill_var})){
			my $fill_var=$self->{html_fill_var};
			foreach(@$ra_keys){
				$fill_var->{$_}=$self->query_param($_);
			}
		}else{
			my $fill_var={};
			foreach(@$ra_keys){
				$fill_var->{$_}=$self->query_param($_);
			}
			$self->{html_fill_var}=$fill_var;
		}
	}else{
		CORE::die $_pkg_name."::set_tmpl_scalar: these kind of return_type cannot set tmpl_scalar";
	}
}



sub set_file{
	my $self=shift;
	my ($file)=@_;
	if(ref($file) ne 'HASH'){
		CORE::die $_pkg_name.'::set_file: param $1 must be an HASH';
	}
	($file)=_process_file($file);
	
	if(in($self->{return_type},'file')){
		if(defined($self->{file})){
			CORE::die $_pkg_name."::set_file: cannot set file more than once";
		}else{
			$self->{file}=$file;
		}
	}else{
		CORE::die $_pkg_name."::set_file: these kind of return_type cannot set file";
	}
}

#====================================================================================
#CGI Utility, to be add
sub user_agent{
	my $self=shift;
	my $cgi=$self->cgi();
	return $cgi->user_agent();
}

sub remote_addr{
	my $self=shift;
	my $cgi=$self->cgi();
	return $cgi->remote_addr();
}

sub referer{
	my $self=shift;
	my $cgi=$self->cgi();
	return $cgi->referer();
}

sub url_encode{

}

sub url_decode{

}

sub html_encode{

}

sub inet_aton{
	local $_=shift;
	if(!defined($_)){return 0;}
	if(/^\s*(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\s*$/){
		if($1>=0&&$1<256&&$2>=0&&$2<256&&$3>=0&&$3<256&&$4>=0&&$4<256){
			return $1*16777216+$2*65536+$3*256+$4;
		};
	};
	return 0;
}

#====================================================================================


#====================================================================================
#Session Support
sub session_create{
	my $self=shift;
	return EasySession::create($self->dba(),@_);
}

sub session_load{
	my $self=shift;
	return EasySession::load($self->dba(),@_);
}

sub session_save{
	my $self=shift;
	return EasySession::save($self->dba(),@_);
}


sub session_delete{
	my $self=shift;
	return EasySession::delete($self->dba(),@_);
}


#$self->session
#$self->session('default');

sub session{
	my $self=shift;
	my $group_name;
	my $param_count=scalar(@_);
	if($param_count==0){
		$group_name=undef;
	}elsif($param_count==1){
		$group_name=$_[0];
	}else{
#==2.0.0==
#		CORE::die $_pkg_name."::session: param count must be 1 or 2";
		CORE::die $_pkg_name."::session: param count must be 0 or 1";
#===end===
	}

	my $session_name=&get_session_name($group_name);
	my $sid=$self->query_param($session_name);
	my $rh;
	if(defined($sid)){
		my $ip=$self->{session_ip_check}?&inet_aton($self->cgi()->remote_addr()):undef ;
		$rh=EasySession::load($self->dba(),$sid,{ip=>$ip});
	}
	if(!defined($rh)){
		my $expire=$self->{session_expire};
		my $ip=&inet_aton($self->cgi()->remote_addr());
		$rh=EasySession::create($self->dba(),{},{expire=>$expire,ip=>$ip});
		if(!$self->{disable_cookie}){
			$self->push_cookie($self->cgi()->cookie(-name=>&get_session_name($group_name),-value=>$rh->{_sid}));
		}
	}
	return $rh;
}


sub get_session_name{
	if(!defined($_[0])||$_[0] eq ''||$_[0] eq 'default'){
		return '_sid';
	}else{
		return '_sid_'.$_[0];
	}
}
#====================================================================================

#====================================================================================
#CGI Session Support





#====================================================================================

sub in {
	my $word=shift;
	foreach(@_){
		if(defined($word)&&defined($_)&&($word eq $_)){
			return 1;
		}elsif((!defined($word))&&(!defined($_))){
			return 1;	
		}else{
			next;
		}
	}
	return '';
}

sub _process_file($){
	my ($file)=@_;
	my $attachment={};
	my $tmp_file_name;
	if(defined($file->{file_bin})&&defined($file->{file_path})){
		CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'_process_file: file_bin and file_path can only set one');
	}elsif(defined($file->{file_path})){
		my $fh=FileHandle->new($file->{file_path},'r');
		if(!defined($fh)){
			CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'_process_file: open attach file failed');
		}
		my $buf;
		$fh->read($buf,$_max_file_len);
		$fh->close();
		$attachment->{file_bin}=$buf;
		undef $buf;
		if(exists($file->{file_name})&&defined($file->{file_name})){
			$attachment->{file_name}=trim($file->{file_name});
		}elsif(exists($file->{file_name})&&(!defined($file->{file_name}))){
			$attachment->{file_name}=undef;
			$tmp_file_name=File::Basename::basename(trim($file->{file_path}));
		}else{
			$attachment->{file_name}=File::Basename::basename(trim($file->{file_path}));
		}
	}elsif(defined($file->{file_bin})){
		$attachment->{file_bin}=$file->{file_bin};
		$attachment->{file_name}=trim($file->{file_name});
	}else{
		CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'_process_file: file_bin and file_path must set one');
	}

	#===if u don't set file_name please set content_type
	if(defined($file->{content_type})){
		$attachment->{content_type}=$file->{content_type};
	}elsif(defined($attachment->{file_name})){
		$attachment->{content_type}=guess_file_content_type($attachment->{file_name});
	}elsif(defined($tmp_file_name)){
		$attachment->{content_type}=guess_file_content_type($tmp_file_name);
	}else{
		CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'_process_file: if u don\'t set file_name please set content_type');
	}

	if(defined($attachment->{file_name})){
		$attachment->{content_disposion}='attachment';
	}else{
		$attachment->{content_disposion}='inline';
	}

	return $attachment;
}

#===guess file content type from it's name
sub guess_file_content_type($){
	my($filename)=@_;
	if(!defined($filename)){return undef;}
	my $map={
		'au' 	=> 'audio/basic',
		'avi'	=> 'video/x-msvideo',
		'class'	=> 'application/octet-stream',
		'cpt'	=> 'application/mac-compactpro',
		'dcr'	=> 'application/x-director',
		'dir'	=> 'application/x-director',
		'doc'	=> 'application/msword',
		'exe'	=> 'application/octet-stream',
		'gif'	=> 'image/gif',
		'gtx'	=> 'application/x-gentrix',
		'jpeg'	=> 'image/jpeg',
		'jpg'	=> 'image/jpeg',
		'js'	=> 'application/x-javascript',
		'hqx'	=> 'application/mac-binhex40',
		'htm'	=> 'text/html',
		'html'	=> 'text/html',
		'mid'	=> 'audio/midi',
		'midi'	=> 'audio/midi',
		'mov'	=> 'video/quicktime',
		'mp2'	=> 'audio/mpeg',
		'mp3'	=> 'audio/mpeg',
		'mpeg'	=> 'video/mpeg',
		'mpg'	=> 'video/mpeg',
		'pdf'	=> 'application/pdf',
		'pm'	=> 'text/plain',
		'pl'	=> 'text/plain',
		'ppt'	=> 'application/powerpoint',
		'ps'	=> 'application/postscript',
		'qt'	=> 'video/quicktime',
		'ram'	=> 'audio/x-pn-realaudio',
		'rtf'	=> 'application/rtf',
		'tar'	=> 'application/x-tar',
		'tif'	=> 'image/tiff',
		'tiff'	=> 'image/tiff',
		'txt'	=> 'text/plain',
		'wav'	=> 'audio/x-wav',
		'xbm'	=> 'image/x-xbitmap',
		'zip'	=> 'application/zip'
	};
	my ($base,$path,$type) = File::Basename::fileparse($filename,qr{\..*});
	if($type){$type=lc(substr($type,1))};
	$map->{$type} or 'application/octet-stream';
}

sub change_encoding($$$){
	if(defined(&utf8::is_utf8)&&utf8::is_utf8($_[0])){
		return Encode::encode($_[2],$_[0]);
	}elsif($_[0]=~/^[\040-\176\r\t\n]*$/){
		#no need to do anything if all ascii
		return $_[0];
	}elsif(defined($_[1])&&defined($_[2])&&($_[1] eq $_[2])){
		#no need to do anything if $src_encoding=$dst_encoding
		return $_[0];
	}elsif(defined($_[1])&&defined($_[2])&&($_[1] ne $_[2])){
		return Encode::encode($_[2],Encode::decode($_[1],$_[0]));
	}else{
		CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'change_encoding: you must set src_encoding');
	}
}

#===delete the blank before and after string
sub trim($) {
	my $param_count=scalar(@_);
	if($param_count==1){
		local $_=$_[0];
		unless(defined($_)){return undef;}
		s/^\s+//,s/\s+$//;
		return $_ ;
	}else{
		CORE::die((defined(&_name_pkg_name)?&_name_pkg_name.'::':'').'trim: param count should be 1');
	}
}

1;
__END__


=head1 NAME

EasyCGI - Perl CGI Interface

=head1 SYNOPSIS

  use EasyCGI;
  
  if(defined(&EasyCGI::foo)){
    print "lib is included";
  }else{
    print "lib is not included";
  }
  
	my $view=EasyCGI->new({
			access => undef,				# set true if u have own cgi interface
			cgi_path => undef,			# position of your own cgi interface
			dba_path => undef,			# position of database interface
			cgi => undef,						# cgi handler
			dba => undef,						# database handler
			language => 'utf8', 		# language: un cn jp utf8, default is utf8
			src_encoding => undef,	# source code(.cgi) encoding, default is utf-8
			web_encoding => undef,	# web page encoding, default is utf-8
			template_file_base_path => undef,	# if null, use absolute file path
			disable_cookie => 1			# disable for not support cookie, default is ''
	});
	
	############### TXT ################
	# $view->set_return_type('txt');
	#
	# my $content='remote_addr: '.$view->remote_addr()."\n";
	#
	# $view->set_content($content);
	####################################
	
	############### HTML ################
	# $view->set_return_type('html');
	#
	# my $content='<p>remote_addr: '.$view->remote_addr().'</p>';
	#
	# $view->set_content($content);
	#####################################
	
	############### REDIRECT ################
	# $view->set_return_type('redirect');
	#
	# my $url='test.html';
	#
	# $view->set_url($url);
	#########################################
	
	############### FILE ################
	# $view->set_return_type('file');
	#
	# my $file='test.txt';
	#
	# $view->set_file($file);
	#####################################
	
	print $view->output();
  
I<The synopsis above only lists the major methods and parameters.>

=head1 Basic Function

=head2 foo - check whether this module is be used

  if(defined(&EasyCGI::foo)){
    print "lib is included";
  }else{
    print "lib is not included";
  }
  
=head2 new - new a instance
		
	my $view=EasyCGI->new($rh_option);

	$rh_option is a hash_ref has below option:
			
			access : set true if u have own cgi interface
			cgi_path : position of your own cgi interface
			dba_path : position of database access
			cgi : cgi handler
			dba : database access
			language : language: un cn jp utf8, default is utf8
			src_encoding : source code(.cgi) encoding, default is utf-8
			web_encoding : web page encoding, default is utf-8
			template_file_base_path : if null, use absolute file path
			disable_cookie : disable for not support cookie, default is ''

=head2 cgi - get the cgi handler
		
		my $cgi = $view->cgi();
		
=head2 dba - get the database access
		
		my $dba = $view->dba();
		
=head2 set_dba - set the database access
		
		$view->set_dba($dba);
		
=head2 lock - cannot read param any more when locked
		
		$view->lock();
		
=head2 output - generate the page content
		
		$print $view->output();
		
=head2 query_param - read params
		
		#first  look up in url param
		#second look up in post param
		#third  look up in cookie param
		
		my $id = $view->query_param('id');
		
=head2 url_param - read url params
		
		my $id = $view->url_param('id');
		
=head2 post_param - read post params
		
		#first  look up in post param
		#second look up in url param
		
		my $id = $view->post_param('id');
		
=head2 cookie_param - read cookie params
		
		my $id = $view->cookie_param('id');
		
=head2 file - get files
		
		my ($file_1, $file_2, $file_3) = $view->file();
		my $file_1 = $view->file();
		
=head2 push_cookie - add cookie param
		
		$view->push_cookie($cookie);
		
=head2 cookie - get cookies
		
		$cookie = $view->cookie();
		
=head2 set_return_type - set the return type
		
		$view->set_return_type('redirect');
		$view->set_return_type('html', 'utf-8');
		
		return type can be:
			'redirect', 'txt', 'html', 'file'
		if you set return type to 'txt' or 'html', you can have the second param for the web page encoding.
				
=head2 set_tmpl_type - set the template type
		
		$view->set_tmpl_type('ht');
		$view->set_tmpl_type('tt');
		
		template type can be:
			'ht'(default), 'tt'
				
=head2 set_url - set the redirect url
		
		$view->set_url($url);
		
		you can set url only if the return type is 'redirect'
				
=head2 set_content - set page content
		
		$view->set_content($content);
		
		you can set content only if the return type is 'txt' or 'html', and have not set tmpl and tmpl_scalar
				
=head2 set_tmpl - set page template from a .tmpl file
		
		$view->set_tmpl($tmpl);
		
		you can set tmpl only if the return type is 'txt' or 'html', and have not set content and tmpl_scalar
		
=head2 set_tmpl_scalar - set page template from a string in memory
		
		$view->set_tmpl_scalar($tmpl);
		
		you can set tmpl_scalar only if the return type is 'txt' or 'html', and have not set content and tmpl
		
=head2 set_tmpl_var - set tmpl_var
		
		$view->set_tmpl_var($rh_tmpl_var);
		
		you can set tmpl_var only if the return type is 'txt' or 'html', and have set tmpl or tmpl_scalar
		
=head2 set_fill_var - set fill_var
		
		$view->set_fill_var($rh_fill_var);
		
		you can set fill_var only if the return type is 'txt' or 'html'
		
=head2 set_fill_back - set fill back varaibles
		
		$view->set_fill_back($ra_keys);
		
		you can set fill_back only if the return type is 'txt' or 'html'
		
=head2 set_file - set file
		
		$view->set_file($rh_file);
		
		you can set file only if the return type is 'file'

=head2 session - get sessions
		
		my $rh=$view->session();
		
=head2 session_create - create session
		
		$rh_session = $view->session_create($rh);
		
=head2 session_load - load session
		
		$rh_session = $view->session_load($rh);
		
=head2 session_save - save session
		
		$view->session_save($rh);
		
=head2 session_delete - delete session
		
		$view->session_delete($rh);

=head1 COPYRIGHT

The EasyCGI module is Copyright (c) 2003-2005 QIAN YU.
All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

