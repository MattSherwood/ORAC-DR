package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Obs = new ORAC::Frame::JCMT("filename");
  $Obs->file("file")
  $Obs->readhdr;
  $Obs->configure;
  $value = $Obs->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to JCMT. It provides a class derived from ORAC::Frame.
All the methods available to ORAC::Frame objects are available
to ORAC::Frame::JCMT objects. Some additional methods are supplied.

=cut

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.004;
use ORAC::Frame;

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Frame::JCMT::ISA = qw/ORAC::Frame/;


# standard error module and turn on strict
use Carp;
use strict;

use NDF; # For fits reading

=head1 METHODS

Modifications to standard ORAC::Frame methods.

=over 4

=item new

Create a new instance of a ORAC::Frame::JCMT object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Obs = new ORAC::Frame::JCMT;
   $Obs = new ORAC::Frame::JCMT("file_name");
   $Obs = new ORAC::Frame::JCMT("UT","number");


This object has additional support for multiple sub-instruments.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $frame = {};  # Anon hash
 
  $frame->{RawName} = undef;
  $frame->{Header} = undef;
  $frame->{Group} = undef;
  $frame->{Files} = [];
  $frame->{Recipe} = undef;
  $frame->{Nsubs} = undef;
  $frame->{Subs} = [];
  $frame->{Filters} = [];
  $frame->{WaveLengths} = [];
  $frame->{RawSuffix} = ".sdf";
  $frame->{RawFixedPart} = '_dem_'; 
  $frame->{UserHeader} = {};

  bless($frame, $class);
 
  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  # This could be extended to include a reference to a hash holding the
  # header info but this may well compromise the object since
  # the best way to generate the header (including extensions) is to use the
  # readhdr method.
 
  if (@_) { 
    $frame->configure(@_);
  }
 
  return $frame;
 
}

=item file

This is a modified implementation of file() that can support multiple
file names (as generated by using more than one sub-instrument in a
SCUBA observation).

  $first_file = $Obj->file;     # As for ORAC::Frame
  $first_file = $Obj->file(1);  # First file name
  $second_file= $Obj->file(2);  # Second file name
  $Obj->file(1, value);         # Set the first file name
  $Obj->file(value);            # Set the first filename
  $Obj->file(10, value);        # Set the tenth file name

Note that counting starts at 1 (and not 0 as is normal for perl 
arrays) and that the filename can not be an integer (otherwise
it will be treated as an array index). Use files() to retrieve
all the values in an array context.

For simplicity primitive writers should probably make sure  that 
the file order matches the sub-instruments order.

If a file number is requested that does not exist, the first
member is returned.

=cut

sub file {

  # May be able to drop all the wacky returns if we let 
  

  my $self = shift;
 
  # Set it to point to first member by default
  my $index = 0;

  # Check the arguments
  if (@_) {

    my $firstarg = shift;

    # If this is an integer then proceed
    # Check for int and non-zero (since strings eval as 0)
    # Cant use int() since this extracts integers from the start of a 
    # string! Match a string containing only digits
    if ($firstarg =~ /^\d+$/ && $firstarg != 0) {

      # Decrement value so that we can use it as a perl array index
      $index = $firstarg - 1;

      # If we have more arguments we are setting a value
      # else wait until we return the specified value
      if (@_) {
         ${$self->aref}[$index] = $self->stripfname(shift);         
      } 
    } else {
      # Just set the first value
      ${$self->aref}[$index] = $self->stripfname($firstarg);
    }
  }

  # If index is greater than number of files stored in the
  # array return the first one
  $index = 0 if ($index > $self->num);

  # Nothing else of interest so return specified member
  return ${$self->aref}[$index];

}

=item configure

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), header(), group() and recipe() methods are
invoked by this command. Arguments are required.
If there is one argument it is assumed that this is the
raw filename. If there are two arguments the filename is
constructed assuming that arg 1 is the prefix and arg2 is the
observation number.

  $Obs->configure("fname");
  $Obs->configure("UT","num");

The sub-instrument configuration is also stored.

=cut

sub configure {
  my $self = shift;
 
  # If two arguments (prefix and number) 
  # have to find the raw filename first
  # else assume we are being given the raw filename
  my $fname;
  if (scalar(@_) == 1) {
    $fname = shift;
  } elsif (scalar(@_) == 2) {
    $fname = $self->file_from_bits(@_);
  } else {
    croak 'Wrong number of arguments to configure: 1 or 2 args only';
  }

  # Set the filename
  $self->file($fname);
 
  # Set the raw data file name
  $self->raw($fname);
 
  # Populate the header
  $self->header($self->readhdr);
 
  # Find the group name and set it
  $self->group($self->findgroup);
 
  # Find the recipe name
  $self->recipe($self->findrecipe);
 
  # Find number of sub-instruments from header
  # and store this value along with all sub-instrument info.
  # Do this so that the header can be changed without us
  # losing the original state information
  $self->nsubs($self->findnsubs);
  $self->subs($self->findsubs);
  $self->filters($self->findfilters);
  $self->wavelengths($self->findwavelengths);

  # Return something
  return 1;
}


=item file_from_bits

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Obs->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes
  my $padnum = '0'x(4-length($obsnum)) . $obsnum;

  # SCUBA naming
  return $prefix . $self->rawfixedpart . $padnum . $self->rawsuffix;
}


=item readhdr

Reads the header from the observation file (the filename is stored
in the object). The reference to the header hash is returned.
This method does not set the header in the object (in general that
is done by configure() ).

    $hashref = $Obj->readhdr;

If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no input arguments.

=cut

sub readhdr {
 
  my $self = shift;
  
  # Just read the NDF fits header
  my ($ref, $status) = fits_read_header($self->file);
 
  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);
 
  return $ref;
}


=item findgroup

Return the group associated with the Frame. 
This group is constructed from header information.

=cut

# Supply a new method for finding a group

sub findgroup {

  my $self = shift;

  # construct group name
  my $group = $self->hdr('MODE') . 
    $self->hdr('OBJECT'). 
      $self->hdr('FILTER');
 
  return $group;

}

=item findrecipe

Return the recipe associated with the frame.
Currently returns undef for all frames except 
skydips. This is because it is not yet decided
how the command line override facility (provided
in the pipeline manager) will know what it can override
and what it can leave alone.

In future we may want to have a separate text file containing
the mapping between observing mode and recipe so that
we dont have to hard wire the relationship.

=cut

sub findrecipe {
  my $self = shift;

  my $recipe = undef;

  if ($self->hdr('MODE') eq 'SKYDIP') {
    $recipe = 'SCUBA_SKYDIP';
  } elsif ($self->hdr('MODE') eq 'NOISE') {
    $recipe = 'SCUBA_NOISE';
  } elsif ($self->hdr('MODE') eq 'POINTING') {
    $recipe = 'SCUBA_POINTING';
  } elsif ($self->hdr('MODE') eq 'PHOTOM') {
    $recipe = 'SCUBA_STD_PHOTOM';
  } elsif ($self->hdr('MODE') eq 'ALIGN') {
    $recipe = 'SCUBA_ALIGN';
  } elsif ($self->hdr('MODE') eq 'MAP') {
    if ($self->hdr('SAM_MODE') eq 'JIGGLE') {
      $recipe = 'SCUBA_JIGMAP';
    } else {
      if ($self->hdr('CHOP_CRD') eq 'LO') {
	$recipe = 'SCUBA_EM2SCAN';
      }
    }
  }

  return $recipe;
}



=item inout

Method to return the current input filename and the 
new output filename given a suffix and a sub-instrument
number.
Currently the suffix is simply appended to the input.

Returns $in and $out in an array context:

  ($in, $out) = $Obs->inout($suffix, $num);

The second argument indicates the sub-instrument number
and is optional (defaults to first sub-instrument).
If only one file is present then that is used as $infile.
(handled by the file() method.)

=cut

sub inout {
  my $num;

  my $self = shift;

  my $suffix = shift;

  # Find the sub-instrument
  if (@_) { 
    $num = shift;
  } else {
    $num = 1;
  }

  my $infile = $self->file($num);
  my $outfile = $infile . $suffix;

  return ($infile, $outfile);

}


=item template

This method is identical to the base class template method
except that only files matching the specified sub-instrument
are affected.

  $Frm->template($template, $sub);

If no sub-instrument is specified then the first file name
is modified

=cut

sub template {
  my $self = shift;

  my $template = shift;

  my $sub = undef;
  if (@_) { $sub = shift; }

  # Now get a list of all the subs
  my @subs = $self->subs;

  # If sub has not been specified then we only process one file
  my $nfiles;
  if (defined $sub) {
    $nfiles = $self->num_files;
  } else {
    $nfiles =1;
  }

  # Get the observation number
  my $num = $self->number;

  # loop through each file
  # (assumes that we actually have the same number of files as subs
  # Not the case before EXTINCTION  

  for (my $i = 0; $i < $nfiles; $i++) {

    # Do nothing if sub is defined but not equal to the current
    if (defined $sub) { next unless $sub eq $subs[$i]; }

    # Okay we get to here if the subs match or if sub was not
    # defined
    # Now repeat the code in the base class
    # Could we use SUPER::template here? No - since the base
    # class does not understand numbers passed to file
    
    # Change the first number
    # Wont work if 0004 replaced by 45
    $template =~ s/\d+_/${num}_/;

    # Update the filename
    $self->file($i+1, $template);

  }

}





=item num_files

Number of files associated with the current state.
This is in fact the number of files stored in files().
Cf num().

  $nfiles = $Frm->num_files;

=cut

sub num_files {

  my $self = shift;
  my $num = $#{$self->aref} + 1;
  return $num;
}

=item gui_id

Return the identification tag that will be used by the display
system for comparison with a display definition file.

This method accepts an argument that can be used to specify
the ID associated with the nth file stored in the frame (
max value is num_files(); counting starts at 1)

The returned ID is therefore a combination of the file number
and the suffix.

For example, if the frame contains two files named

  o36_lon_ext and o37_lon_ext

The ID returned from N=1 will be  s1ext and when N=2: s2ext
(ie sN for the sub instrument number followed by the final extension).
The sub-instrument name is not used since that would result in
having to setup a display device for each sub-instrument.

THIS CONVENTION MAY CHANGE WITH USAGE.

=cut

sub gui_id {

  my $self = shift;

  my $num = 1;
  if (@_) { $num = shift; }

  # Retrieve the Nth file  (start counting at 1)
  my $fname = $self->file($num);
  
  # Split on underscore
  my (@split) = split(/_/,$fname);
 
  return "s$num" . $split[-1];
}


=item calc_orac_headers

This method calculates header values that are required by the
pipeline by using values stored in the header.

ORACTIME is calculated - this is the time of the observation in
hours. Currently is UT.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  my %new = ();  # Hash containing the derived headers
 
  # ORACTIME
  my $time = $self->hdr('UTSTART');
  if (defined $time) {
    # Need to split on :
    my ($h,$m,$s) = split(/:/,$time);
    $time = $h + $m/60 + $s/3600;
  } else {
    $time = 0;
  }

  # Update the header
  $self->hdr('ORACTIME', $time);
 
  $new{'ORACTIME'} = $time;
  return %new;



}



=back

=head1 NEW METHODS FOR JCMT

This section describes methods that are available in addition
to the standard methods found in ORAC::Frame.

=over 4

=item files

Set or retrieve the array containing the current file names
associated with the frame object.

    $Obj->members(@files);
    @files = $Obj->files;

=cut
 
sub files {
  my $self = shift;
  if (@_) { @{ $self->{Files} } = @_;}
  return @{ $self->{Files} };
}


=item aref

Set or retrieve the reference to the array containing the members of the
frame.

    $Obj->aref(\@files);
    $arrayref = $Obj->aref;

=cut

 
sub aref {
  my $self = shift;
 
  if (@_) { 
    my $arg = shift;
    croak("Argument is not an array reference") unless ref($arg) eq "ARRAY";
    $self->{Files} = $arg;
  }
 
  return $self->{Files};
}



=item file2sub

Given a file index, (see file()) returns the associated
sub-instrument.

  $sub = $Frm->file2sub(2)

Returns the first sub name if index is too large.

=cut

sub file2sub {
  my $self = shift;
  my $index = shift;
  
  # Look through subs()
  my @subs = @{$self->subs};
  
  # Decrement $index so that it matches an array lookup
  $index--;
  
  if ($index > $#subs) {
    return $subs[0];
  } else {
    return $subs[$index];
  }
}

=item sub2file

Given a sub instrument name returns the associated file
index. This is the revers of sub2file. The resulting value
can be used directly in file() to retrieve the file name.

  $file = $Frm->file($Frm->sub2file('LONG'));

A case insensitive comparison is performed.

Returns 1 if nothing matched (ie just returns the first file
in file(). This is probably a bug.

=cut

sub sub2file {
  my $self = shift;
  my $sub = lc(shift);
  
  # The index can be found by going thourgh @subs until
  # we find a match
  my @subs = $self->subs;
  
  my $index = 1; # return first file name at least
  for (my $i = 0; $i <= $#subs; $i++) {
    if ($sub eq lc($subs[$i])) {
      $index = $i + 1;
      last;
    }
  }
  
  return $index;
}



=item num

Return the number of files in a group minus one.
This is identical to the $# construct.

  $number_of_files = $Obj->num;

See also num_files()

=cut

sub num {
 
  my $self = shift;
 
  return $#{$self->aref};
 
}

=item nsubs

Return the number of sub-instruments associated with the Frame.

=cut

sub nsubs {
  my $self = shift;

  if (@_) { $self->{Nsubs} = shift; };

  return $self->{Nsubs};

}


=item subs

Return or set the names of the sub-instruments associated
with the frame.

=cut

sub subs {
  my $self = shift;
  
  if (@_) {
    @{$self->{Subs}} = @_;
  }

  return @{$self->{Subs}};

}

=item filters

Return or set the filter names associated with each sub-instrument
in the frame.

=cut

sub filters {
  my $self = shift;
  
  if (@_) {
    @{$self->{Filters}} = @_;
  }

  return @{$self->{Filters}};

}

=item wavelengths

Return or set the wavelengths associated with each  sub-instrument
in the frame.

=cut

sub wavelengths {
  my $self = shift;
  
  if (@_) {
    @{$self->{WaveLengths}} = @_;
  }

  return @{$self->{WaveLengths}};

}

=item findnsubs

Forces the object to determine the number of sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using nsubs().

Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findnsubs {
  my $self = shift;

  return $self->hdr('N_SUBS');
}



=item findsubs

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut

sub findsubs {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @subs = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'SUB_' . $i;

    push(@subs, $self->hdr($key));
  }

  # Should now set the value in the object!

  return @subs;
}



=item findfilters

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut


sub findfilters {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @filter = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'FILT_' . $i;

    push(@filter, $self->hdr($key));
  }

  return @filter;
}


=item findwavelengths

Forces the object to determine the names of all sub-instruments
associated with the data by looking in the header(). 
The result can be stored in the object using subs().

Unlike findgroup() this method will always search the header for
the current state.

=cut


sub findwavelengths {
  my $self = shift;

  # Dont use the nsubs method (derive all from header)
  my $nsubs = $self->hdr('N_SUBS');

  my @filter = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'WAVE_' . $i;

    push(@filter, $self->hdr($key));
  }

  return @filter;
}


=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item stripfname

Method to strip file extensions from the filename string. This method
is called by the file() method. For UKIRT we strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name.

=cut

sub stripfname {
 
  my $self = shift;
 
  my $name = shift;
 
  # Strip everything after the first dot
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//;
  
  return $name;
}
 

=back

=head1 REQUIREMENTS

This module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Frame>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut




1;
