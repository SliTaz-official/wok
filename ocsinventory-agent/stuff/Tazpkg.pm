package Ocsinventory::Agent::Backend::OS::Generic::Packaging::Tazpkg;

use strict;
use warnings;

sub check { can_run("tazpkg") }

sub run {
  my $params = shift;
  my $inventory = $params->{inventory};

# use dpkg-query -W -f='${Package}|||${Version}\n'
  foreach (`tazpkg list `){
    if (/^(\S+)\s+([0-9]+.*)\s+(.*)/) {
      $inventory->addSoftwares({
	  'NAME'          => $1,
	  'VERSION'       => $2,
	  });
    }
  }

}

1;
