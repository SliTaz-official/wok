package Ocsinventory::Agent::Backend::OS::Linux::Distro::NonLSB::Slitaz;
use strict;

sub check {-f "/etc/slitaz-release"}

#####
sub findRelease {
  my $v;

  open V, "</etc/slitaz-release" or warn;
  chomp ($v=<V>);
  close V;
  return "SliTaz GNU/Linux $v";
}

sub run {
  my $params = shift;
  my $inventory = $params->{inventory};

  my $OSComment;
  chomp($OSComment =`uname -v`);

  $inventory->setHardware({ 
      OSNAME => findRelease(),
      OSCOMMENTS => "$OSComment"
    });
}

1;
