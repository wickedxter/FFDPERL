package ffdperl;

#############################################################
# Project: Flat-File databse for perl
#
# File name: ffdperl.pm
# Date Created: 04/08/2009
# Version: 1.0.11 Beta
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
my $VERSION = "1.0.11 Beta";


use strict;
#use sql_filehandle;
use lib qw(./);
use sql_ffdperl;
use ffdperl_error;



require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw($VERSION CREATE_DB QUERY);



my $db_dir;
sub new
{
    my $self = shift;
    my $database_type = $_[0];
    $db_dir = $_[1];
    ffdperl_error::ffdperl_error("Unsupported database type: $database_type") if $database_type !~ /^SQL$/;
    
    my $data = {type => $database_type,
                dir => $db_dir,};
    
    bless $data,$self;
    
    return $data;
}


sub QUERY {
    my $self = shift;
    my $state = $_[0];
    my $SQL = sql_ffdperl->new($db_dir);
    my $query = $SQL->QUERY($state);
    
    return $query;
}

#############
# Creates new dtabases
# useage: $db->CREATE_DB("new_database");
# rules: no spaces, any will be removed
sub CREATE_DB
{
    my $self = shift;
    my $new_db = shift;

    
    #if no base_dir is supplied use the supplied dir
    
         
    
    #check if db exist
    my $db_check = 0;
    opendir DIR, "$self->{dir}" or ffdperl_error::ffdperl_error("Can't open dir: $self->{dir}");
    my @contents = readdir(DIR);
    closedir DIR;
    
    for my $dir (@contents){
        next if $dir eq '.' || $dir eq '..';
        $db_check++  if $dir =~ /$new_db/;
    }
    ##check if db file exists if not create the db file
    if ($db_check eq 0){
        
        open FILE, ">$self->{dir}/$new_db";
        close FILE;
    }else {
        ffdperl_error::ffdperl_error("Database: $new_db already exist.");
    }
    
    return 1;
}


1;
