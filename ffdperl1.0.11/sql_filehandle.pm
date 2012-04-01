package sql_filehandle;
#############################################################
# Project: Flat-File databse for perl
#
# File name: sql_filehandle.pm
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
use warnings;
use Fcntl qw(:DEFAULT :flock);
require ffdperl_error;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(CREATEDIR CREATEFILE FileLock FileUnlock UPDATEFILE READFILE $VERSION);


#############################
# SUB: CREATEDIR
# USEAGE: CREATEDIR('dir/to/new/dirname');
# DESC: Creates new folers needed 
sub CREATEDIR
{
    my $dir = $_[0];
    
    mkdir($dir) or ffdperl_error::ffdperl_error("Failed to create table.");
}

#############################
# SUB: DELETEDIR
# USEAGE: DELETEDIR('dir/to/new/dirname');
# DESC: Deletes existing folers  
sub DELETEDIR
{
    `rm -rf $_[0]` or ffdperl_error::ffdperl_error("Failed to delete table.");
}


#############################
# SUB: CREATEFILE
# USEAGE: CREATEFILE('dir/to/folder',["file1,file2"]);
# DESC: Creates new files
sub CREATEFILE
{
    my $dir = $_[0];
    my @files = split(/,/,$_[1]);
    
    for my $file (@files){
        open FILE,">$dir/$file" || ffdperl_error::ffdperl_error("Failed to create file: $file");
        close FILE;
    }
}
#############################
# SUB: FileLock
# USEAGE: FileLock(<file>);
# DESC: Creates a lock on the open file so nothing else can write to it till this lock is done
sub FileLock
{
    flock($_[0],LOCK_EX);
}
#############################
# SUB: FileUnlock
# USEAGE: FileUnlock(<file>);
# DESC: Unlocks the file
sub FileUnlock
{
    flock($_[0],LOCK_UN);
}
#############################
# SUB: UPDATEFILE
# USEAGE: UPDATEFILE('dir/to/foler/filename.data','Mode',$data);
# DESC: Writes data to specified
# MODE: A = Append; W = Write over entire file, this ereases the file.
sub UPDATEFILE
{
    my $dirFile = $_[0];
    my $mode = $_[1];
    my $data = $_[2];
    
    
    if($mode eq "A"){
        
        open( my $file,'>>',"$dirFile");
        #FileLock($file);
        print $file "$data\n";
       # FileUnlock($file);
        close $file;
    }elsif($mode eq "W"){
        
        open( my $file,'>',"$dirFile");
       # FileLock($file);
        print $file "$data\n";
       # FileUnlock($file);
        close $file;
    }elsif($mode eq "RW") {
		#Read the tableNames from master table
		open( my $file,'<',"$dirFile");
		my @tableNames = <$file>;
		close($file);
		#Remove the $tableName from @tableNames
		my @tnames_update;
		for (@tableNames) {
			if($_ ne $data) {
				push(@tnames_update, $_."\n");
			}
		}

		#Open in write mode and update the remaining tablenames
		open my $file1,'>',"$dirFile";
        #FileLock($file1);
        print $file1 "@tnames_update";
        #FileUnlock($file1);
        close $file1;
	}
}
#############################
# SUB: READFILE
# USEAGE: READFILE('dir/to/filename.data');
# DESC: Reads the entire file and sends back.
sub READFILE
{
   
    my $loc = $_[0];
    my @data;
     
   
    open( my $file, '<', "$loc");
    #FileLock($file);
    @data = <$file>;
    #chomp(@data);
    #FileUnlock($file);
    close $file;
    
    
    return @data;

}
1;
