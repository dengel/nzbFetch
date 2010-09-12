#!/usr/bin/perl
#
# Author: Daniel Engel (daniel.engel@gmail.com)
#
# License: None 2010.
#
# Information: 
#

use strict;
use LWP::Simple;

# Set Test Paths
my $basedir = "./";
my $logfile = $basedir . "nzbindex.db";
my $nzbdir  = $basedir . "nzbq/";

# Set the source URL. Visit http://nzbindex.nl/groups/ select a group.
# Tune the advanced settings, click on search for form URL and then
# locate the RSS link. Copy the RSS URL here.
my $url     = "http://nzbindex.nl/rss/alt.binaries.anime/?sort=agedesc&minsize=100&maxsize=1500&complete=1&max=100&more=1";

# Explude list. Use terms found on title.
my @exclude = ("One_Piece","Shinjuku");

my ( $command, $output );

sub main {

    print "*** Updating list...\n";
    $| = 1;
    my $content = get($url);

    if ( !defined $content ) {
        $output .= "*** Error: Unable to fetch nzb: $url\n";
        exit 1;
    }

    my @lines = split( /\n/, $content );

    my $subject;
    my $age;
    my $nzburl;
    my $pid;
    my $re;
    my @nzbs;

    foreach (@lines) {

        my $line = $_;

        $re='<title>(.*)<\/title>';
        if ($line =~ m/$re/is)
        {
            $subject=$1;
            $subject=~ s/&quote;//g;
            $subject=~ s/&quot;//g;
            $subject=~ s/&lt;//g;
            $subject=~ s/&gt;//g;
            $subject=~ s/ /_/g;
            $subject=~ s/\//_/g;
            $subject=~ s/\(//g;
            $subject=~ s/\)//g;
            $subject=~ s/\[//g;
            $subject=~ s/\]//g;
            $subject=~ s/_$//;
        }

        $re='<pubDate>(.*)<\/pubDate>';
        if ($line =~ m/$re/is)
        {
            $age=$1;
            $age="1d";
        }

        $re='<enclosure url="(.*)" ';
        if ($line =~ m/$re/is) 
        {
            $nzburl=$1;
            $nzburl=~ s/http:\/\///g;

            my $re1='.*?'; # Non-greedy match on filler
            my $re2='(\\d+)';  # Integer Number 1

            my $re=$re1.$re2;
            if ($nzburl =~ m/$re/is)
            {
                $pid=$1;
                if ( ($age ne undef) && ($pid ne undef) && ($subject ne undef) ) {
                    $subject =~ s/:/_/g;
                    #print "Age: $age Pid: $pid Url: $nzburl Subject: $subject\n";
                    push(@nzbs,"$age:$pid:$nzburl:$subject");
                }
            }
        }

    }

    open( LOGF, "$logfile" ) or die "Unable to open $logfile";
    my @done = <LOGF>;
    close(LOGF);

    foreach (@nzbs) {
        #print "Doing: $_ \n";
        my ($n_age, $n_pid, $n_url, $n_subject) = split(/:/,$_);

        # Is the basedir in the valid directory list?
        my $skip = 0;
        foreach my $entry (@exclude) {
            if ( $n_subject =~ /$entry/i ) {
                $skip = 1;
                last;
            }
        }

        # Don't let arbitrary directories to be changed.
        if ( $skip ) {
            print "*** Pass: ($n_pid): $n_subject\n";
            next;
        }

        if ( grep { /$n_pid/ } @done ) {
            print "*** Skip: ($n_pid): $n_subject\n";
            next;
        }

        print "*** Good: ($n_pid): $n_subject\n";
        $| = 1;
        my $nzb = get("http://".$n_url);
        if ( !defined $nzb ) {
            $output .= "*** Error: Unable to fetch nzb: $n_url\n";
            exit 1;
        }
        my $lfs = "$nzbdir/$n_subject.nzb";
        open( FETCHED, ">$lfs" ) or die "Unable to open $lfs";
        print FETCHED $nzb;
        close(FETCHED);

        open( LOGF, ">>$logfile" ) or die "Unable to open $logfile";
        print LOGF $n_pid . "\n";
        push(@done,$n_pid);;

        close(LOGF);
    }


    exit 0;

}

&main;
