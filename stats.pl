#!/usr/bin/perl
use warnings;
use strict;

my $quick = 0;
my $runs = 100000;

my @swing;
my %swing;
my @state;
my %votes;
my %status;
my %dem;
my %rep;
my $totalvotes;
while (<>) {
	chomp();
	next if /^\s*\#/;
	my ($state, $votes, $status, $dem, $rep) = split(/\t/);
	push(@state, $state);
	$votes{$state} = $votes;
	$status{$state} = $status;
	$dem{$state} = $dem;
	$rep{$state} = $rep;
	if (lc($status) eq "swing") {
		push(@swing, $state);
		$swing{$state} = 1;
	}
	else {
		$swing{$state} = 0;
	}
	$totalvotes += $votes;
	if (abs($dem + $rep - 1) > 0.00001) {
		die("Dem + Rep != 1:\t$_\n");
	}
}
printf("Total electoral votes: %d\n", $totalvotes);

my $demwins = 0;
my $repwins = 0;
my $ties = 0;
my @votecountdist = map { 0 } (0 .. $totalvotes);
my %demvotes = map { ($_, 0) } @state;
my %repvotes = map { ($_, 0) } @state;

@state = sort { $swing{$b} <=> $swing{$a} || $votes{$b} <=> $votes{$a} } @state;

my $demvotes;
my $repvotes;
sub simulate {
	my $quick = $quick;
	my ($run_number) = @_;
	if ($run_number) {
		$quick = 0;	# so we can show final totals on these runs
	}
	$demvotes = 0;
	$repvotes = 0;
	foreach my $state (@state) {
		if (rand() < $dem{$state}) {
			$demvotes += $votes{$state};
			$demvotes{$state} += $votes{$state};
		} else {
			$repvotes += $votes{$state};
			$repvotes{$state} += $votes{$state};
		}
		if ($quick) {
			if ($demvotes > ($totalvotes / 2)) {
				last;
			} elsif ($repvotes > ($totalvotes / 2)) {
				last;
			}
		}
	}
	if ($demvotes == $repvotes) {
		$ties += 1;
	} elsif ($demvotes < $repvotes) {
		$repwins += 1;
	} else {
		$demwins += 1;
	}
	if ($run_number) {
		printf("Run %8d: Dem %3d Rep %3d\n", $run_number, $demvotes, $repvotes);
	}
	$votecountdist[$demvotes] += 1;
}

for (my $run = 1; $run <= $runs; $run += 1) {
	if ($run % 10000 == 0) {
		simulate($run);
	} else {
		simulate();
	}
}
printf STDERR ("Done!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
printf STDERR ("  Dems are %7.3f%% likely to win.\n",
	       100 * $demwins / $runs);
printf STDERR ("  Reps are %7.3f%% likely to win.\n",
	       100 * $repwins / $runs);
printf STDERR ("  A tie is %7.3f%% likely.\n",
	       100 * $ties / $runs);

exit 0 if $quick;

my @likelydemtotals = sort { $votecountdist[$b] <=> $votecountdist[$a] }
	(0 .. $totalvotes);

print STDERR ("Top 20 likely scenarios...\n");
foreach my $demtotal (@likelydemtotals[0..19]) {
	printf("  Dem %3d Rep %3d %7.3f%%\n",
	       $demtotal, $totalvotes - $demtotal,
	       100 * $votecountdist[$demtotal] / $runs);
}

foreach my $state (@state) {
	my $dem = 100 * $demvotes{$state} / $runs / $votes{$state};
	my $rep = 100- $dem;
	my $sdem = $dem{$state};
	my $srep = $rep{$state};
	if ($dem == $rep) {
		printf("  %2s %7.3f%% (%7.3f%%)    \n", $state, $rep, $srep);
	} elsif ($dem < $rep) {
		printf("  %2s %7.3f%% (%7.3f%%) Rep\n", $state, $rep, $srep);
	} else {
		printf("  %2s %7.3f%% (%7.3f%%) Dem\n", $state, $dem, $sdem);
	}
}

