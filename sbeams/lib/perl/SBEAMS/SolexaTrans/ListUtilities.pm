#!/usr/bin/env perl
use strict;
use warnings;

package SBEAMS::SolexaTrans::ListUtilities;
use base qw(Exporter);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(unique_sorted unique delete_elements union intersection subtract xor invert);
use Data::Dumper;
use Carp;


# A few utility list utility routines

# remove redundant elements from a SORTED list:
sub unique_sorted {
    my @answer;
    my $last = shift @_ or return ();
    push @answer, $last;	# now put it back

    for (@_) {
	push @answer, $_ unless $_ eq $last;
	$last = $_;
    }
    @answer;
}

# remove redundant elements from a list:
# takes either list of listref; returns either list or listref
sub unique_old {
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my %hash=map{($_,$_)} @$list;
    wantarray? values %hash : [values %hash];
}

sub unique {
    my $list = (ref $_[0] eq 'ARRAY'? $_[0] : \@_);
    my %hash=map{($_,$_)} @$list;
    wantarray? keys %hash : [keys %hash];
}

# remove elements from a list
# call as "delete_elements(\@list, @to_remove)"
sub delete_elements {
    my $list_ref = shift;
    my @new_list;
    foreach my $item (@$list_ref) {
	push @new_list, $item unless grep { $_ eq $item} @_;
    }
    @$list_ref = @new_list;
}

# takes 2 listrefs; returns list or list ref
sub union {
    my ($list1, $list2) = @_;
    my %hash;
    map { $hash{$_}=1 } @$list1;
    map { $hash{$_}=1 } @$list2;
    my @keys = keys %hash;
    wantarray? @keys : \@keys;
}

# takes 2 listrefs; returns list or list ref
sub intersection {
    my ($list1, $list2) = @_;
    my (%hash1, %hash2);

    map { $hash1{$_}=1 } @$list1; # gather list 1:
    map { $hash2{$_}=1 if $hash1{$_} } @$list2; # gather intersection(list1, list2)

    my @keys = keys %hash2;
    wantarray? @keys : \@keys;
}

# takes 2 listrefs; returns list or list ref
# returns $list1-$list2
sub subtract {
    my ($list1, $list2) = @_;
    my %hash=();
    map { $hash{$_}=$_ } @$list1; # gather list 1
    map { delete $hash{$_} if $_} @$list2 if @$list2; # remove list 2
    
    my @values = values %hash;
    wantarray? @values : \@values;
}

# return all genes in one list, but not both
# takes 2 listrefs; returns list or list ref
sub xor {
    my ($list1, $list2) = @_;
    my %hash;
    do {push @{$hash{$_}}, $_} foreach @$list1;
    do {push @{$hash{$_}}, $_} foreach @$list2;
    while (my ($k,$v)=each %hash) {
	delete $hash{$k} unless @{$hash{$_}}==1;
    }
    my @values = values %hash;
    wantarray? @values : \@values;
}

# invert a hash (ie, foreach k=>v, return a hash with v=>k)
# if there are duplicate values, they get randomly overwritten
# if there are undefined values, they get abandoned
sub invert {
    my %input=(@_==1 && ref $_[0] eq 'HASH')?%{$_[0]}:@_;
    my %output;
    while (my ($k,$v)=each %input) {
	defined $v and $output{$v}=$k;
    }
    wantarray? %output:\%output;
}

1;
