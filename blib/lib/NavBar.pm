package Apache::NavBar;

# file Apache/NavBar.pm

use strict;
use Apache::Constants qw(:common);
use Apache::File;
use vars qw($VERSION);

# $Id: NavBar.pm,v 0.01 2001/11/14 15:50:27 barracode Exp $
$VERSION = '0.01';

my %Bars = ();

sub handler
{
 	my $r = shift;

   my $bar = read_configuration($r) || return DECLINED;

   $r->content_type eq 'text/html' || return DECLINED;
   my $fh = Apache::File->new($r->filename) || return DECLINED;

   # header
   my $header = $r->dir_config('Header');
   my $headerhtml;
   open (FILE, "$header");
   while (<FILE>)
   {
     $headerhtml .= $_;
   }
   close FILE;

   # footer
   my $footer = $r->dir_config('Footer');
   my $footerhtml;
   open (FILE, "$footer");
   while (<FILE>)
   {
     $footerhtml .= $_;
   }
   close FILE;

	my $navbar = make_bar($r, $bar);

	$r->send_http_header;
	return OK if $r->header_only;

	local $/ = "";

	while (<$fh>)
	{
	  	s/(<\!--header-->)/$headerhtml$1/oi;
	  	s/(<\!--start-->)/$navbar$1/oi;
	  	s/(<\!--footer-->)/$footerhtml$1/oi;
	}
	continue
	{
		$r->print($_);
	}
	return OK;
}

sub make_bar
{
	my ($r, $bar) = @_;

	my $current_url = $r->uri;

	my @cells;

	# Loop through the config lines.
	for my $i ($bar->urls)
	{
		my $label = $bar->label ($i);
		my $label2 = $bar->label2 ($i);
		my $is_current = $current_url =~ /^$i/;

		# Should we highlight?
		my $cell = $is_current ? qq ($label): qq ($label2);

		push @cells, qq ($cell);
	}
	return qq (@cells);
}

sub read_configuration
{
	my %BARS = ();
	my $r = shift;

	my $conf_file;

   return unless $conf_file = $r->dir_config('NavConf');

	return unless -e ($conf_file = $r->server_root_relative($conf_file));

	my $mod_time = (stat _)[9];
	return $BARS{$conf_file} if $BARS{$conf_file}
		&& $BARS{$conf_file}->modified >= $mod_time;

	return $BARS{$conf_file} = NavBar->new($conf_file);
}

package NavBar;

sub new
{
	my ($class, $conf_file) = @_;
	my (@c, %c, %d);

	my $fh = Apache::File->new($conf_file) || return;

	# Read the config 
	while (<$fh>)
	{
		chomp;

		# Trim the whitespace.
		s/^\s+//; s/\s+$//;

		# Skip comments.
		next if /^#/ || /^$/;

		# Format correct? /NavBar/index.html Home 
		next unless my ($url, $label, $label2) = /^(\S+)\t+(.+)\t+(.+)/;
		push @c, $url;
		$c{$url} = $label;
		$d{$url} = $label2;
	}
	return bless {	'urls' 	  => \@c,
					   'labels'   => \%c,
					   'labels2'  => \%d,
					   'modified' => (stat $conf_file)[9]}, $class; }
}

sub urls
{
	return @{shift->{'urls'}};
}

sub label
{
	return $_[0]->{'labels'}->{$_[1]} || $_[1];
}

sub label2
{
	return $_[0]->{'labels2'}->{$_[1]} || $_[1];
}

sub modified
{
	return $_[0]->{'modified'};
}

1;

__END__

=head1 PACKAGE
	
=head1 DESCRIPTION

	Straight from the Eagle book, with a couple minor additions.
	Looks for  <!--header--> <!--start--> <!--footer-->  
	in your html code.  A sample nav.conf, header, and footer is 
	included in the distribution.


	#######################################
	#                                     #
	# httpd.conf                          #
	#                                     #
	#######################################

	<Directory /home/httpd/html/>
	 SetHandler perl-script
 	 Options +ExecCGI
 	 allow from all
	 PerlHandler Apache::NavBar
 	 PerlSetVar Header /home/httpd/html/header
	 PerlSetVar NavConf /home/httpd/html/nav.conf
	 PerlSetVar Footer /home/httpd/html/footer
	</Directory>

	A working demo is at http://www.s1te.com

=head1 AUTHOR

	Writing Apache Modules with Perl and C, by Lincoln Stein
	and Doug MacEachern (Eagle book).

=cut
