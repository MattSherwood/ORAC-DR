
#+
#  Name:
#     oracdr_wfcam5

#  Purpose:
#     Initialise ORAC-DR environment for use with the "fifth" WFCAM
#     chip.

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam5.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with WFCAM data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest. This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories. Assumes that the data are located in
#        a directory structure similar to that used at UKIRT.
#        Also sets an appropriate alias for ORAC-DR itself.
#        If no value is specified, the current UT is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given)
#        Root location of the data input and output directories.
#        If no value is set, "/ukirtdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/wfcam. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jac_sw/oracdr_cal".


#  Examples:
#     oracdr_wfcam5
#        Will set the variables assuming the current UT date.
#     oracdr_wfcam5 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/wfcam5/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.5  2006/11/15 20:18:17  bradc
#     set PERL5LIB to point to ukirt_sw for CIRDR stuff
#
#     Revision 1.4  2006/11/15 20:00:48  bradc
#     change ukirt_sw and/or jcmt_sw to jac_sw
#
#     Revision 1.3  2006/10/28 01:37:41  bradc
#     set PERL5LIB for CASU code
#
#     Revision 1.2  2006/10/23 18:59:40  bradc
#     set RTD_REMOTE_DIR back to be the same as ORAC_DATA_OUT
#
#     Revision 1.1  2006/10/03 00:20:08  bradc
#     replaced with ex-SWFCAM version
#
#     Revision 1.4  2006/07/21 02:09:08  bradc
#     set RTD_REMOTE_DIR to $ORAC_DATA_OUT/.., create ORAC_DATA_OUT directory if it does not exist and we are being run on a wfdr machine
#
#     Revision 1.3  2004/11/12 01:22:02  phirst
#      setenv RTD_REMOTE_DIR and HDS_MAP
#
#     Revision 1.2  2004/11/06 01:08:26  bradc
#     set ORAC_INSTRUMENT to WFCAMn
#
#     Revision 1.1  2004/11/05 20:01:56  bradc
#     initial addition, copy of oracdr_wfcam4.csh for "fifth" WFCAM chip
#
#     Revision 1.1  2004/09/14 21:17:37  bradc
#     initial addition for WFCAM
#
#     Revision 1.2  2004/05/05 11:38:57  jrl
#     Modified to add ORAC_DATA_CASU definition and a small tidy
#
#     Revision 1.1  2003/06/30 09:43:05  jrl
#     initial entry into CVS
#
#     Revision 1.1  2003/01/22 11:54:49  jrl
#     Initial Entry
#
#
#     21 Jan 2003 (jrl)
#        Original Version based on oracdr_wfcam.csh

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

setenv ORAC_INSTRUMENT WFCAM5

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh
