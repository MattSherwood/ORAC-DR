package ORAC::Basic;

=head1 NAME

ORAC::Basic - some implementation subroutines

=head1 SYNOPSIS

  use ORAC::Basic;

  $Display = orac_setup_display;
  orac_exit_normally($message);
  orac_exit_abnormally($message);

=head1 DESCRIPTION

Routines that do not have a home elsewhere.

=cut

use Carp;
use vars qw($VERSION @EXPORT $Beep @ISA);
use strict;
use warnings;

require Exporter;
use File::Path;
use File::Copy;

use ORAC::Print;
use ORAC::Display;
use ORAC::Error qw/:try/;
use ORAC::Constants qw/:status/;

@ISA = qw(Exporter);

@EXPORT = qw/  orac_setup_display orac_exit_normally orac_exit_abnormally /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

$Beep    = 0;       # True if ORAC should make noises


#------------------------------------------------------------------------

=head1 FUNCTIONS

The following functions are provided:

=over 4

=item B<orac_setup_display>

Create a new Display object for use by the recipes. This includes
the association of this object with a specific display configuration
file (F<disp.dat>). If a configuration file is not in $ORAC_DATA_OUT
one will be copied there from $ORAC_DATA_CAL (or $ORAC_DIR
if no file exists in $ORAC_DATA_CAL).

If the $DISPLAY environment variable is not set, the display
subsystem will not be started.

The display object is returned.

  $Display = orac_setup_display;

=cut

# Simply create a display object
sub orac_setup_display {

  # Check for DISPLAY being set
  unless (exists $ENV{DISPLAY}) {
    warn 'DISPLAY environment variable unset - not starting Display subsystem';
    return;
  }

  # Set this global variable
  my $Display = new ORAC::Display;

  # Set the location of the display definition file
  # (we do not currently use NBS for that)

  # It is preferable for this to be instrument specific. The working
  # copy is in ORAC_DATA_OUT. There is a system copy in ORAC_DIR
  # but preferably there is an instrument-specific in ORAC_DATA_CAL
  # designed by the support scientist

  my $systemdisp = $ENV{ORAC_DIR}."/disp.dat";
  my $defaultdisp = $ENV{ORAC_DATA_CAL}."/disp.dat";
  my $dispdef = $ENV{ORAC_DATA_OUT}."/disp.dat";


  unless (-e $defaultdisp) {$defaultdisp = $systemdisp};

  unless (-e $dispdef) {copy($defaultdisp,$dispdef)};

  # Set the display filename 
  $Display->filename($dispdef);

  # GUI launching goes here....

  # orac_err('GUI not launched');
  return $Display;
}

=item B<orac_exit_normally>

Exit handler for oracdr.

=cut

sub orac_exit_normally {
  my $message = '';
  ( $message ) = shift if @_;

  # We are dying, and don't care about any further outstanding errors
  # flush the queue so we have a clean exit.
  my $error = ORAC::Error->prior;
  ORAC::Error->flush if defined $error; 

  # redefine the ORAC::Print bindings
  my $msg_prt  = new ORAC::Print; # For message system
  my $msgerr_prt = new ORAC::Print; # For errors from message system
  my $orac_prt = new ORAC::Print; # For general orac_print

  # Debug info
  orac_print ("Exiting...\n","red");

  rmtree $ENV{'ADAM_USER'}             # delete process-specific adam dir
    if defined $ENV{ADAM_USER};

  # Ring a bell when exiting if required
  if ($Beep) {
    for (1..5) {print STDOUT "\a"; select undef,undef,undef,0.2}
  }

  # Cleanup Tk window(s) if they are still hanging around
  ORAC::Event->destroy("Tk");
  ORAC::Event->unregister("Tk");

  # Flush the error stack if all we have is an ORAC::Error::UserAbort

  orac_print ("\nOrac says: $message","red") if $message ne '';
  orac_print ("\nOrac says: Goodbye\n","red");
  exit;
}

=item B<orac_exit_abnormally>

Exit handler when a problem has been encountered.

=cut

sub orac_exit_abnormally {
  my $signal = '';
  $signal = shift if @_;

  # redefine the ORAC::Print bindings
  my $msg_prt  = new ORAC::Print; # For message system
  my $msgerr_prt = new ORAC::Print; # For errors from message system
  my $orac_prt = new ORAC::Print; # For general orac_print

  # Try and cleanup, untested, I can't get it to exit abnormally
  ORAC::Event->destroy("Tk");
  ORAC::Event->unregister("Tk");

  # Dont delete tree since this routine is called from INSIDE recipes

  # ring my bell, baby
  if ($Beep) {
    for (1..10) {print STDOUT "\a"; select undef,undef,undef,0.2}
  }

  die "\n\nAborting from ORACDR - $signal recieved";

}

=back

=head1 REVISION

$Id$

=head1 SEE ALSO

L<ORAC::Core>, L<ORAC::General>

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
