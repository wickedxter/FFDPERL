package ffdperl_error;

use strict;
use Carp;

#############################################################
# Project: Flat-File databse for perl
#
# File name: ffdperl_error.pm
# Date Created: 04/08/2009
# Version: 1.0.10 Beta
# Creator: Wickedxter
############################################################
#       Flat_file database for perl is free software: you can 
#   redistribute it and/or modify it under the terms of the GNU General Public License 
#   as published by the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

############################################################
my $VERSION = "1.0.10 Beta";

#use strict;


require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ffdperl_error $VERSION);
our @EXPOPT = qw(ffdperl_error);

########################################
# SUB: ffdperl_error
# USEAGE: ffdperl_error("message");
##
sub ffdperl_error
{
    
    carp @_;
}

1;
