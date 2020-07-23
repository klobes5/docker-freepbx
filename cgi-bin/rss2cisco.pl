#!/usr/bin/env perl

#############################################################################
# @(#) RSS2cisco, An RSS feed to Cisco IP Phone Script version 2.0
# Copyright 2004, Joshua Cantara <jcantara@grappone.com>
#
# then heavily hacked in 2005 by Dirk Jagdmann <doj@cubic.org> to support
# caching and better RSS parsing and new title overview.
#
# Then in 2008, Nic Tjirkalli <nictjir@gmail.com> hacked some more to
# make it work with SIP images on a range of CISCO IP Phones
# and translate German Characters
# Some basic info on the script is available at :-
# http://www.tjir.za.net/rss.html

#
# This program is licensed under the GPL: http://www.gnu.org/licenses/gpl.txt



# Needs a whole wack of perl modules to work - I needed :-
# If you need them, you can search/download them from http://search.cpan.org
#
# LWP::Simple
# HTML::Parser
# HTML::Tagset
# URI
# XML::RAI
# Date::Format
# XML::RSS::Parser
# XML::Elemental
# XML::NamespaceSupport
# Class::ErrorHandler
# Class::XPath
use Encode; #for decoding characters
use utf8;
# Some global variable initialisation
# Do Not alter these Global definitions
my $DEBUG = "NO";
my $FixGerman = "NO";


#
# =============================================================
# Variables/items taht are user changeable or customisable
# =============================================================
#


# Add the URL of the RSS feed and a title to the array bellow

	#	'http://www.sportal.de/rss/sportal.rss', 'German Test',
my @feeds = (
	     'http://w1.weather.gov/xml/current_obs/KALB.rss', 'Albany Weather',
	     'http://www.lemonde.fr/rss/une.xml', 'Le Monde International',
	     'http://www.nytimes.com/services/xml/rss/nyt/World.xml', 'NYT World',
	     'https://www.reddit.com/r/InfoSecNews.rss ', 'InfoSec News',
	     'https://fedscoop.com/rss', 'FedScoop',
	     'https://news.ycombinator.com/rss', 'Hacker News',
	     'https://lobste.rs/rss', 'Lobsters',
	     'http://www.nytimes.com/services/xml/rss/nyt/US.xml', 'NYT National',
             );

# Static sites that are not RSS feeds - just sites that have static content
my @sites = (
             );



# Change any of these menu strings etc as required
my $menutitle='News of the World';
my $menuprompt='Choose your propaganda';
my $defaultrefresh=600;

# If you want strange characters in German RSS feeds to be translated to
# hopefully correct German leave this uncomented. might break other
# character sets.
#my $FixGerman = "YES";


# Comment out if you do not want a menu option that displays the HTTP
# environment variables sent by the phone when making a request
# my $DEBUG="YES";


####################################################################
## There should be nothing to change after here
## Unless you wanna rewrite the internals
####################################################################

use strict;
use LWP::Simple qw($ua get);
use XML::RAI;
use CGI;
use URI::Escape;

my %property;

# construct url to script
$ENV{SERVER_NAME} =~ s!/+$!!;
$ENV{SCRIPT_NAME} =~ s!^/+!!;
#my $pathto = "http://192.168.1.4/cgi-bin/rss2cisco.pl$ENV{SCRIPT_NAME}";
my $pathto = "http://192.168.1.4/$ENV{SCRIPT_NAME}";



# Get environment variables returned by phone web browser
getenv();    

# Get phone model
my $model = $property{'HTTP_X_CISCOIPPHONEMODELNAME'};


# Determine if phone supports XML 3.1 (only newer 7970s do this
# From what we can see, 7960s with SIP iamges do XML 3.0
# XML 3.0 dose not support SoftKeyItem directive

my $age = "OLD";

if ($model =~ /79[4,6]0/) {
  $age =  "OLD";
}

my $query = new CGI;
my $item=$query->param('item');
my $url=$query->param('opts');

if ($url && $item)
{
    printitem($url, $item, $query->param('maxitem'));
}
elsif ($url)
{
    if ($url eq "DEBUG") { printenv() ; }
    else { printtitles($url); }
}
else
{
    printmenu();
}

sub getenv {

my $var;
my $val;

foreach $var (sort(keys(%ENV))) {
    $val = $ENV{$var};
    $val =~ s|\n|\\n|g;
    $val =~ s|"|\\"|g;
    $property{$var} = $val;
}
}


sub printenv {

my $k;

    print "Content-Type: text/xml\n\n";

    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";

    print "<CiscoIPPhoneText><Title>HTTP Header Environment</Title><Text>";

    foreach my $k (sort keys %property)
    {
          #print uri_escape($k).":".uri_escape($property{$k})."\n";
          my $value = $property{$k};
	  $value =~ s/\<|\>/ /g;
          print "$k:$value \n";
    }
    print "</Text>";

if ($age eq "NEW") {

    my $pth = substr($pathto,0,255);
#    print "<SoftKeyItem>";
#    print " <Name>Back</Name>";
#    print " <URL>$pth</URL>";
#    print " <Position>3</Position>";
#    print "</SoftKeyItem>";
}

    print "</CiscoIPPhoneText>";

}



sub printmenu {
    my $pth= "$pathto?opts=";

    print "Content-Type: text/xml\n\n";
    #foreach my $k (sort keys %ENV)
    #{
    #	print "$k: $ENV{$k}\n";
    #}

    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print "<CiscoIPPhoneMenu><Title>".substr($menutitle,0,31)."</Title><Prompt>".substr($menuprompt,0,31)."</Prompt>\n";

    for (my $i = 0; $i <= ($#feeds) && $i<=64*2;)
    {
        my $fe = $feeds[$i++];
        my $nm = $feeds[$i++];
	#regex feed to remove special characters
	#$nm =~ tr/a-zA-Z//dc;
	#See if the above works
	#
	print "<MenuItem>";
	print "<Name>".substr(cmxml_escape($nm), 0, 63)."</Name>";
	print "<URL>".substr($pth.uri_escape($fe), 0, 255)."</URL>";
	print "</MenuItem>\n";
    }

    for (my $i = 0; $i <= ($#sites) && $i<=64*2;)
    {
        my $fe = $sites[$i++];
        my $nm = $sites[$i++];
	$nm =~ tr/a-zA-Z//dc;
        print "<MenuItem>";
        print "<Name>".substr(cmxml_escape($nm), 0, 63)."</Name>";
        print "<URL>".substr($fe, 0, 255)."</URL>";
        print "</MenuItem>\n";
    }


    # If DEBUG set to YES print an option to display HTTP Header 
    # Environment variables
    if ($DEBUG eq "YES") {
	print "<MenuItem>";
	print "<Name>HTTP Header Variables</Name>";
	print "<URL>$pth"."DEBUG</URL>";
	print "</MenuItem>\n";
    }

    print "</CiscoIPPhoneMenu>\n";
    exit 0;
}

sub printitem
{
    my ($url, $item, $maxitem) = @_;

    my $maxlength=4000;

    my $rai=XML::RAI->parse(getfeed($url));
    printmenu() unless $rai;

    my $title=''; $title=substr(cmxml_escape($rai->channel->title),0,31) if $rai->channel->title;

    my $it=${$rai->items}[$item-1]; # get item
    my $date=''; $date=substr(cmxml_escape($it->issued),0,31) if $it->issued;

    my $txt='';
    $txt .= cmxml_escape("$item: ".$it->title) if $it->title;
    $txt .= "\n--------------------------------\n";
    $txt .= cmxml_escape($it->content) if $it->content;
    my $txt1 = $it->content;
    $txt=substr($txt,0,3999);

    print "Content-Type: text/xml\n\n";
    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print "<CiscoIPPhoneText>";
    print "<Title>$title</Title>" if $title;
    print "<Text>$txt</Text>";
    #print "<Text>$txt1</Text>";

if ($age eq "NEW") {
    if($item>1)
    {
	my $i=$item-1;
	my $pth = substr("$pathto?opts=".uri_escape($url)."\&amp;maxitem=$maxitem\&amp;item=$i",0,255);
#	print "<SoftKeyItem>";
#	print " <Name>&lt;&lt;</Name>";
#	print " <URL>$pth</URL>";
#	print " <Position>1</Position>";
#	print "</SoftKeyItem>";
    }
    if($item<$maxitem)
    {
	my $i=$item+1;
	my $pth = substr("$pathto?opts=".uri_escape($url)."\&amp;maxitem=$maxitem\&amp;item=$i",0,255);
#	print "<SoftKeyItem>";
#	print " <Name>&gt;&gt;</Name>";
#	print " <URL>$pth</URL>";
#	print " <Position>2</Position>";
#	print "</SoftKeyItem>";
    }

}

if ($age eq "NEW") {

    my $pth = substr("$pathto?opts=".uri_escape($url),0,255);
#    print "<SoftKeyItem>";
#    print " <Name>Back</Name>";
#    print " <URL>$pth</URL>";
#    print " <Position>3</Position>";
#    print "</SoftKeyItem>";
}

    print "</CiscoIPPhoneText>\n";
}

sub printtitles {
    my ($url) = @_;


    my $rai=XML::RAI->parse(getfeed($url));
    printmenu() unless $rai;

    my $title=''; $title=substr(cmxml_escape($rai->channel->title),0,31) if $rai->channel->title;
    my $date=''; $date=substr(cmxml_escape($rai->channel->issued),0,31) if $rai->channel->issued;

    my $refresh=$defaultrefresh;
    if($rai->channel->src->query('ttl'))
    {
	$refresh=$rai->channel->src->query('ttl')*60;
    }

    print "Content-Type: text/xml\nRefresh: $refresh\n\n";
    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print "<CiscoIPPhoneMenu>";
    print "<Title>$title</Title>" if $title;

    my $maxitem=0;
    foreach my $item (@{$rai->items}) { $maxitem++; } # todo: better array size detection

    my $pth = "$pathto?opts=".uri_escape($url)."\&amp;maxitem=$maxitem\&amp;item=";
    my $z=0;
    foreach my $item (@{$rai->items})
    {
	last if ++$z >99;
	print "<MenuItem>";
       # print "<Name>Item $z</Name>";
	print "<Name>".substr(cmxml_escape($item->title), 0, 63)."</Name>";
	print "<URL>".substr("$pth$z",0,255)."</URL>";
#	print "<URL>http://www.tjir.za.net</URL>";
	print "</MenuItem>\n";
    }

if ($age eq "NEW") {
#    print "<SoftKeyItem>";
#    print " <Name>Select</Name>";
#    print " <URL>SoftKey:Select</URL>";
#    print " <Position>1</Position>";
#    print "</SoftKeyItem>";

#    print "<SoftKeyItem>";
#    print " <Name>Reload</Name>";
#    print " <URL>".substr($pth,0,255)."</URL>";
#    print " <Position>2</Position>";
#    print "</SoftKeyItem>";

#    print "<SoftKeyItem>";
#    print " <Name>Back</Name>";
#    print " <URL>".substr($pathto,0,255)."</URL>";
#    print " <Position>3</Position>";
#    print "</SoftKeyItem>";
}

    print "</CiscoIPPhoneMenu>\n";
}

sub getfeed
{
    my ($url) = @_;
    my $feed;

    # construct cache filename
    my $fn=$url;
    $fn =~ s/[^\w\d]/_/g;
    $fn = "/tmp/$fn";

    # check if cached rss is valid
    if(-f $fn)
    {
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($fn);
	if($mtime > time()-($defaultrefresh-30) && $size>100)
	{
	    open(A, $fn);
	    $feed.=$_ while <A>;
	    close(A);
	    return $feed;
	}
    }

    # get RSS data
    $ua->timeout(15);
    $feed = get($url);

    printmenu() if length($feed)==0;

    # save into cache
    open(A, ">$fn");
    print A $feed;
    close(A);

    return $feed;
}

sub cmxml_escape
{
    ($_) = @_;
    return unless $_;

    $_=HTMLentity2latin1($_);

    s/\s+/ /g;			# strip ws
    s/<.+?>//g;			# strip html tags

    # escape special chars
#    s/</\&lt;/g;
#   s/>/\&gt;/g;
#   s/ß/\&szlig;/g;
#   s/ü/\&uuml;/g;
#
    #
    # Translating German characters fudged by web browser to 
    # hopefully real German - list is far from complete
    #
    if ($FixGerman eq "YES") {
    s/Ã/ü/g;
    s/ü¼/ü/g;
    s/ü¶/ö/g;
    s/ü¤/ä/g;
    s/üŸ/ß/g;
    s/üœ/Ü/g;
    s/Â//g;
    s/ü„u/Ä/g;
    s/©/é/g;
    }

    if ($age eq "NEW") {
    # Older phone's SIP iamge web browser appear to have an issue
    # with &apos and possibly &quot so we wont change this
    s/'/\&apos;/g; # '
    s/"/\&quot;/g; # "
    }

    s/\&(?!lt|gt|apos|quot|amp)/\&amp;/g;

    return $_;
}


sub HTMLentity2latin1
{
    ($_) = @_;
    return unless $_;
    #trying something here
     $_ =~ s/<(.|\n)+?>//g;
     $_ =~ s/&#8217;/'/g;
     $_ =~ s/&/and/g;
     $_ =~ s/&/&amp;/g;
     $_ =~ s/</&lt;/g;
     $_ =~ s/>/&gt;/g;  
    $_ =~ s/[^\x00-\x7f]//g;
    return $_;
}
