#!/usr/bin/perl
use warnings;
use strict;

# if true, each simulation is shortcutted after one party gets 270,
# and we don't get to compute likely electoral vote totals.
my $quick = 0;

my $show_state_totals = 0;

# number of simulations to run.
my $runs = 100000;

my @swing;			# list of swing states
my %swing;			# whether each state is a swing state
my @state;			# list of states
my %votes;			# electoral votes by state
my %status;			# 'status' field of state: lc is 'swing' indicates swing
my %dem;			# probability that dem wins each state
my %rep;			# probability that rep wins each state
my $totalvotes;			# total number of electoral votes
while (<>) {
	chomp();
	next if /^\s*\#/;	# skip comments
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
		die("OH SHIT: Dem + Rep != 1:\t$_\n");
	}
}

printf("Total electoral votes: %d\n", $totalvotes);

my $demwins = 0;		# number of dem wins over all simulations
my $repwins = 0;		# "      "  rep "    "    "   "
my $ties = 0;			# number of ties     "    "   "

my @votecountdist = map { 0 } (0 .. $totalvotes); # for computing likeliest vote counts

# total number of electoral votes each party receives in each state,
# over all simulations
my $totaldemvotes = 0;
my $totalrepvotes = 0;
my %totaldemvotes = map { ($_, 0) } @state;		  
my %totalrepvotes = map { ($_, 0) } @state;		  

# sort states primarily by swinginess and secondarily by descending
# number of electoral votes
@state = sort { $swing{$b} <=> $swing{$a} || $votes{$b} <=> $votes{$a} } @state;

my $demvotes;			# number of dem votes each sim
my $repvotes;			# "      "  rep "     "    "
sub simulate {
	my ($run_number) = @_;

	my $quick = $quick;
	if ($run_number) {
		$quick = 0;	# so we can show final totals on these runs
	}

	$demvotes = 0;		# total number of dem votes this simulation run
	$repvotes = 0;		# "     "      "  rep "     "    "          "
	foreach my $state (@state) {
		my $votes = $votes{$state};
		if (rand() < $dem{$state}) {
			# this run only
			$demvotes += $votes;

			# over all simulation runs
			$totaldemvotes += $votes;
			$totaldemvotes{$state} += $votes;
		} else {
			# this run only
			$repvotes += $votes;

			# over all simulation runs
			$totalrepvotes += $votes;
			$totalrepvotes{$state} += $votes;
		}
		if ($quick) {
			# shortcut this simulation run maybe
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
		printf("  run %8d: Dem %3d Rep %3d\n",
		       $run_number, $demvotes, $repvotes);
	}
	$votecountdist[$demvotes] += 1;
}

# Run the simulations.
for (my $run = 1; $run <= $runs; $run += 1) {
	if ($run % 10000 == 0) {
		simulate($run);
	} else {
		simulate();
	}
}

# Show simulation results.
print("Results\n");
printf("  Dems are %7.3f%% likely to win.\n", 100 * $demwins / $runs);
printf("  Reps are %7.3f%% likely to win.\n", 100 * $repwins / $runs);
printf("  A tie is %7.3f%% likely.\n",        100 * $ties / $runs);

exit 0 if $quick;

print("Average electoral vote counts\n");
printf("  %7.3f Dem %7.3f Rep\n",
       $totaldemvotes / $runs,
       $totalrepvotes / $runs);

# sort (number of dem electoral votes) scenarios from most to least
# likely
my @likelydemtotals = sort { $votecountdist[$b] <=> $votecountdist[$a] }
	(0 .. $totalvotes);

print("Top 20 likely scenarios...\n");
foreach my $i (0..19) {
	my $demtotal = $likelydemtotals[$i];
	printf("  %2d.  Dem %3d Rep %3d %7.3f%%\n",
	       $i + 1, $demtotal, $totalvotes - $demtotal,
	       100 * $votecountdist[$demtotal] / $runs);
}

exit 0 unless $show_state_totals;

foreach my $state (@state) {
	my $dem = 100 * $totaldemvotes{$state} / $runs / $votes{$state};
	my $rep = 100 - $dem;
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

