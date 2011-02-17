package Ocsinventory::Agent::Backend::OS::Generic::Packaging::Tazpkg;

use strict;
use warnings;

sub check { can_run("tazpkg") }

sub run {
	my $params = shift;
	my $inventory = $params->{inventory};

	# use tazpkg list\n'
	foreach (`tazpkg list `){
		next if (/List of/);
		next if (/packages installed/);
		
		if (/^(\S+)\[24G\s+(\S+)\[42G\s+(\S+)/) {
		  $inventory->addSoftware({
		  'NAME'    	=> $1,
		  'VERSION'     => $2,
		  'COMMENTS'	=> $3	
		  });
	   }
	}

}

1;
