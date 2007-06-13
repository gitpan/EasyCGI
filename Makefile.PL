require 5.004;
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME' => 'EasyCGI',
	'VERSION_FROM'	=>	'EasyCGI.pm',
	'PREREQ_PM'     => {
		'File::Basename' =>'0',
		'MIME::Base64'=>'0',
		'CGI'=>'0',
		'FileHandle'=>'0',
		'Encode'=>'0',
		'HTML::Template'=>'0',
		'Template'=>'0',
		'HTML::FillInForm'=>'0'
 	},
	dist		=>	{ COMPRESS => 'gzip -9f', SUFFIX => '.gz'}
);

