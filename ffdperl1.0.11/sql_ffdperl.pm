package sql_ffdperl;
#############################################################
# Project: Flat-File databse for perl
#
# File name: sql_ffdperl.pm
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
require ffdperl_error;
require sql_filehandle;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(QUERY $VERSION);

sub new
{
    my $self = shift;
        
    my $data = {db_dir => $_[0],};
    
    bless $data,$self;
    
    return $data;
}

##############################
# SUB: QUERY
# USEAGE: $db->QUERY("SQL STATEMENT");
# DESC: This captures the SQL queries and handles the work to the sub's.
sub QUERY
{
    my $self = shift;
    my $statement = $_[0];
    my $return;
    
    chomp $statement;
    my $SUPPORTED = {FUNCTIONS => ["CREATE TABLE,UPDATE,SELECT,INSERT,DROP TABLE"],
                     ATTRIBUTES => ["INT,VARCHAR,AUTO_INCREMENT,NOT NULL"],
                     };
    
    #REGEX match function and handle it. Make sure function is supported.
    my $support = check_supported_functions($SUPPORTED->{FUNCTIONS},$statement);
    if($support ne 0){
        if ($statement =~ /CREATE\s*TABLE\s*(\w+)\s*\w+\s*\((.*)\)$/i){
           $return = CREATE_TABLE($self->{db_dir},$statement,$1,$2);
        }elsif($statement =~ /UPDATE\s*(\w+)\s*SET\s*(.*)\s*WHERE\s*(.*)/i or
	       $statement =~ /UPDATE\s*(\w+)\s*SET\s*\((.*)\)\s*WHERE\s*\((.*)\)/i){
            $return = UPDATE($self->{db_dir},$statement,$1,$2,$3);
        }elsif($statement =~ /^SELECT\s*(\W{1})\s*FROM\s*(.*)\s*/i or
               $statement =~ m/SELECT\s*(\w+)\s*FROM\s*(\w+)\s*WHERE\s*(.*)/i){
            $return = SELECT($self->{db_dir},$1,$2,$3);
        }elsif($statement =~ /^INSERT\s*INTO\s*(\w*)\s*\((.*)\)\s*VALUES\s*\((.*)\)$/i){
            $return = INSERT($self->{db_dir},$1,$2,$3,$SUPPORTED->{ATTRIBUTES});
        }elsif($statement =~ /^DROP\s*TABLE\s*(\w+)$/i) {
			$return = DROP_TABLE($self->{db_dir},$1);
		}
    }else {
        ffdperl_error::ffdperl_error("QUERY: $statement, not understood.");
    }
    return $return;
}


###############################
# SUB: INSERT
# USEAGE: $check = INSERT();
sub INSERT
{
    my ($db,$table,$columns,$values,$attributes) = @_;
    my $temp;
    $columns =~ s/\)|\(|\n|\r|//g;
    $values =~ s/\)|\(|\n|\r//g;
    $columns =~ s/\s+$//;

    
    #check table if exists?
    my $tableCheck = CHECKTABLE("$db/$table",$table);
    
    if ($tableCheck eq 0){
        #get data from columns and values and temp. save data.
        @{$temp->{column}} = split(/,/,$columns);
        @{$temp->{values}} = split(/,/,$values);
    
        for (0..scalar(@{$temp->{column}})){
            chomp $temp->{column}[$_];
            chomp $temp->{values}[$_];
            $temp->{data}{$temp->{column}[$_]} = $temp->{values}[$_];
        }
        #delete old data
        delete $temp->{column};
        delete $temp->{values};
        
        #load master table def. in order
        @{$temp->{masterdef}} = sql_filehandle::READFILE("$db/$table/column.def");
        for my $a (@{$temp->{masterdef}}){
            my @def = split(/;/,$a);
            for my $aa (@def){
                my ($c,$att) = split(/\|/,$aa);
                $temp->{def}{$c} = $att;
                $temp->{def}{AUTO_INCREMENT} = $c if $att eq "AUTO_INCREMENT";
                push(@{$temp->{def_order}},$c);
            }
        }
        
        # go through master file and compair the order in which to save the data
        # so that is corrosponds to the correct column. Also need to check to make sure
        # that the attributes match the added data. Must Find all AUTO_INCREMENT and INCREMENT
        my $save_data;
        my $pass=0;
        for my $order (@{$temp->{def_order}}){ # array of master file in order
            next if $order eq "";
            #AUTO_INCREMENTAL data get found here.
            if ($temp->{def}{$order} eq "AUTO_INCREMENT"){
                my @data = sql_filehandle::READFILE("$db/$table/$temp->{def}{AUTO_INCREMENT}_AUTO_INCREMENT.data");
                $data[0]++;
                sql_filehandle::UPDATEFILE("$db/$table/$temp->{def}{AUTO_INCREMENT}_AUTO_INCREMENT.data","W",$data[0]);
                $save_data .= "$data[0]|";
                next;
            }else {
                for my $data_keys (keys %{$temp->{data}}){ #HOH of data to be added
                    if ($order eq $data_keys){
                        $save_data .= "$temp->{data}{$data_keys}|";
                    }
                }
            }
            
        }
        sql_filehandle::UPDATEFILE("$db/$table/column.data","A",$save_data);
    }else {
        ffdperl_error::ffdperl_error("Table $table doesn't exist, you must create it first.");
    }
    
    
    return 1;
}
###############################
# SUB: SELECT
# USEAGE: $check = SELECT();
# NOTES: This is copied over from the alpha release
#        some modifications made to work with the other modules.
#VERSION: 1.0.0 Aplha
#SUPPORTED MATCHES: = < >
# EX: coulmn=data
sub SELECT
{
    my ($db,$Selection,$Table,$Where) = @_;
    $Selection =~ s/\s//g;
    chomp ($Table);
    #Space used for int of variables
    #saved
    my $temp = {columnRows => 0,
                coldef => [],
                coldata => [],
                returnData => {
                COLROWS => 0,},};
    
    #read and load master def
    @{$temp->{coldef}} = sql_filehandle::READFILE("$db/$Table/column.def");
    #load column data
    @{$temp->{coldata}} = sql_filehandle::READFILE("$db/$Table/column.data");
    
    #Seperate column name and attributes
    for my $a (@{$temp->{coldef}}){
        $a =~ s/\s\r\n//;
        my @attr = split(/\;/,$a);
        
        for my $aa (@attr){
            $aa =~ s/\s\r\n//;
            $temp->{columnRows}++;
            $temp->{returnData}{COLROWS}++;
            my ($col,$attribute) = split(/\|/,$aa);
            $temp->{$col} = $attribute;
            push(@{$temp->{Column}},$col);
            }
        }
    
    #depending on if where exist in query
    
    if($Where){
        #since multi-matches can exist must split them up.
        my $matchOpt;
        my @matches;
        
        @matches = split(/\,/,$Where);
        #since only = & > is supported then keep it simple
        for my $match (@matches){
            $match =~ /(=)/i;
	    $match =~ m/(\>|\<)/;
	    #$match = m/(\<)/;
            $matchOpt = $1;
        }
        
        
        #This is where the different matches happen
        if ($matchOpt eq "="){
            #locate match or matches
            my (@se,@ma,$column,$matchTo);
            
            #setup matches
            @se = split(/\,/,$Selection);
            @ma = split(/\,/,$Where);
            for my $mat (@ma){
                ($column,$matchTo) = split(/=/,$mat);
                $temp->{matchTo}{$column} = $matchTo;
            }
            
            
            #setup data in to its respective columns
            my $odd = 1;
            if($odd eq 1){
                my $dataCount = scalar(@{$temp->{coldata}});
                for my $b (0..$dataCount){
                    my @capture = split(/\|/,$temp->{coldata}[$b]);
                    for my $bb (0..$temp->{columnRows}){
                        $temp->{Data}{$b}{$temp->{Column}[$bb]} = $capture[$bb];
                }
               
                
            }
            #garbage clean up
            delete $temp->{coldef};
            delete $temp->{coldata};
                
                
            #Search threw data and match
            my ($num,$columnN,$matc);
            my $count=0;
            for $num (keys %{$temp->{Data}}){
                for $columnN (keys %{$temp->{Data}{$num}}){
                    next if $columnN eq "";
                    for $matc (keys %{$temp->{matchTo}}){
                        #next unless $columnN eq $matc;
                        if($columnN eq $matc){
                            if($temp->{Data}{$num}{$columnN} eq $temp->{matchTo}{$matc}){
                                $count++;
                                
                                foreach my $sel1 (@se){
                                    $temp->{returnData}{$count}{$sel1} = $temp->{Data}{$num}{$sel1};
                                }
                            }
                        }
                    }
                }
            }
            
        } #########################################
		#### Select statement where > is used
        }elsif($matchOpt eq '>' or $matchOpt eq '<'){
			#locate match or matches
            my (@se,@ma,$column,$matchTo);
            
            #setup matches
            @se = split(/\,/,$Selection);
            @ma = split(/\,/,$Where);
            for my $mat (@ma){
                ($column,$matchTo) = split(/\>/,$mat) if $matchOpt eq '>';
		($column,$matchTo) = split(/\</,$mat) if $matchOpt eq '<';
                $temp->{matchTo}{$column} = $matchTo;
            }
            chomp $column;
            
            #setup data in to its respective columns
            my $odd = 1;
            if($odd eq 1){
                my $dataCount = scalar(@{$temp->{coldata}});
                for my $b (0..$dataCount){
                    my @capture = split(/\|/,$temp->{coldata}[$b]);
                    for my $bb (0..$temp->{columnRows}){
                        $temp->{Data}{$b}{$temp->{Column}[$bb]} = $capture[$bb];
					}
               
                }
            }
            #garbage clean up
            delete $temp->{coldef};
            delete $temp->{coldata};	
		
			#Search threw data and match
            my ($num,$columnN,$matc);
            my $count=0;
            for $num (keys %{$temp->{Data}}){
                for $columnN (keys %{$temp->{Data}{$num}}){
 		    chomp $columnN;
                    next if $columnN eq "";
                    #for $matc (keys %{$temp->{matchTo}}){
			#chomp $matc;
                        #next unless $columnN eq $matc;
                        if($column =~ /$columnN/){
			    if($matchOpt eq '>'){
				if($temp->{Data}{$num}{$columnN} > $matchTo){
				    $count++;
                                
				    foreach my $sel1 (@se){
				      $temp->{returnData}{$count}{$sel1} = $temp->{Data}{$num}{$sel1};
				    }
				}
			    }elsif($matchOpt eq '<'){
				if($temp->{Data}{$num}{$columnN} < $matchTo){
				 $count++;
                                
				    foreach my $sel1 (@se){
				      $temp->{returnData}{$count}{$sel1} = $temp->{Data}{$num}{$sel1};
				    }
				}
			    }
                        }
                   #}
                }
            }
		
		}else {
            ffdperl_error::ffdperl_error("fuction $matchOpt isnt supported just yet.");
        }
        
    }else {
        #if where isn't found load all column's
        $temp->{returnData}{ColRows} = $temp->{columnRows};
        if($Selection eq "*"){
            my $dataCount = scalar(@{$temp->{coldata}});
            for my $b (0..$dataCount){
                my @capture = split(/\|/,$temp->{coldata}[$b]);
                for my $bb (0..$temp->{columnRows}){
                    $temp->{returnData}{$b}{$temp->{Column}[$bb]} = $capture[$bb];
                }
            }
            
        }else {
            ffdperl_error::ffdperl_error("Secletion query for other then WHERE matches must contain * to select all");
        }
    }
    delete $temp->{returnData}{COLROWS};
    delete $temp->{returnData}{ColRows};
    return $temp->{returnData};
}
###############################
# SUB: UPDATE
# USEAGE: $UD_CHECK = UPDATE(dir,$statement,$tableName,$Changes,$Match);
# RETURNS: 1    ::::   if no errors don't get caught
sub UPDATE
{    
    my ($db,$statem,$table,$set,$match) = @_;
    
    my @old;
    my $data2;
    
    my @dataa;
    my $count = 0;
    my $master = {columnRows => 0,
                  col_id => {},
                  CT => {},
                  MATCH => {},
                  column => [],};
    
    
    #read table colum master def
    my @coldef = sql_filehandle::READFILE("$db/$table/column.def");
    
    #load master
    foreach my $mas (@coldef){
        my @db = split(/\;/,$mas);
        for my $mast (@db){
            my ($ColName,$Attr) = split(/\|/,$mast);
            $ColName =~ s/\n|\r//;
            $Attr =~ s/\n|\r//;
            $master->{data}{$ColName} = $Attr;
            $master->{columnRows}++;
            $master->{col_id}{$ColName} = $master->{columnRows};
            push(@{$master->{column}},"$ColName");
        }
    }
    
    #go through set and match
    my @ChangeTo = split(/,/,$set);
    my @Matches = split(/,/,$match);
    
    #remove unwanted and save.
    my $CT1=0;
    my $MAT1=0;
    foreach my $CT (@ChangeTo){
        $CT =~ s/'|"|\s|\n|\r//g;
        my ($Col,$value) = split(/=/,$CT);
        $master->{CT}{$Col} = $value;
        $CT1++;
    }
    foreach my $Mat (@Matches){
        $Mat =~ s/'|"|\s|\n|\r//g;
        #$Mat =~ /(=|>|<)/;
        my ($Col2,$value2) = split(/=/,$Mat);
        $master->{MATCH}{$Col2} = $value2;
        $MAT1++;
    }
    
    #Compare set and matches to master def (only for id of column name)
    my $CT_count=0;
    my $MATCH_count=0;
    foreach my $d (keys %{$master->{data}}){
        foreach my $dd (keys %{$master->{CT}}){
            if($d eq $dd){
                $CT_count++;
            }
        }
        foreach my $dd1 (keys %{$master->{MATCH}}){
            if($d eq $dd1){
                $MATCH_count++;
            }
        }
    }
    if($CT_count ne $CT1 && $MATCH_count ne $MAT1){
        ffdperl_error::ffdperl_error("The column data your trying to change doesnt match whats set in the master def. file");
    }
    
    
    
    #Hopefully one check before going on is enough to catch errors.
    #check value matches master for Att. For (INT. & AUTO_INCREACEMENT) mostly
    foreach my $data1 (keys %{$master->{data}}){
        foreach my $ct (keys %{$master->{CT}}){
            #find auto_increment
            if($master->{data}{$data1} eq "AUTO_INCREMENT"){
                if($ct eq $data1){
                    ffdperl_error::fsql_error("AUTO_INCREMENT Error!");
                }
            }
            if($master->{data}{$data1} eq "INT"){
                if($ct eq $data1 && $master->{CT}{$data1} =~ /[a-zA-Z]/){
                    ffdperl_error::fsql_error("Column $ct must only contain number.");
                }
            }
        }
    }
    
    #Read data file
    
    @old = sql_filehandle::READFILE("$db/$table/column.data");
    my $times = scalar(@old);
    
    #columnize the rows to master def.
    for my $dx (0..$times){
        (@dataa) = split(/\|/,$old[$dx]);
        for my $ddx (0..$master->{columnRows}){
            #print "$d ::: $dd :::::= $dataa[$dd]\n";
            $data2->{$dx}{$master->{column}[$ddx]} = $dataa[$ddx];
        }
    }
    
    
    ## Match: column=value
    #match the query to the database info and change
    my $made_matches=0;
    foreach my $n (keys %{$data2}){
        foreach my $nn (keys %{$data2->{$n}}){
            foreach my $m1 (keys %{$master->{MATCH}}){
                if ($nn eq $m1 && $data2->{$n}{$nn} eq $master->{MATCH}{$m1}){
                    foreach my $change (keys %{$master->{CT}}){
                        $data2->{$n}{$change} = $master->{CT}{$change};
                        $made_matches++;
                    }
                }
            }
        }
    }
    
    #Write data to file
    my $return;
    
    open MATCH,">$db/$table/column.data";
    sql_filehandle::FileLock("MATCH");
    for my $da (keys %{$data2}){
        for my $order (@{$master->{column}}){
            next if $data2->{$da}{$order} eq "";
            $return .= "$data2->{$da}{$order}|";
        }
        $return .= "\n";
    }
    print MATCH $return;
    sql_filehandle::FileUnlock("MATCH");
    close MATCH;
    
   
   return 1;
}

##############################
# SUB: CREATE_TABLE
# USEAGE: $CT_CHECK = CREATE_TABLE($dir,$statement,$tableName,$coulmns);
# DESC: Checks, Creates Tables.
sub CREATE_TABLE
{
    my ($db_dir,$statement,$tableName,$colums) = @_;
    #my $save;
    $colums =~ s/\(\)//g;
    # Check for teable existance.
    my  $table_name_check=0;
    $table_name_check = CHECKTABLE($db_dir,$tableName);
    
    if ($table_name_check ne 1){
        #Make dir and needed files.
        sql_filehandle::CREATEDIR("$db_dir/$tableName") or ffdperl_error::ffdperl_error("Couldn't Create dir: $tableName");
        sql_filehandle::CREATEFILE("$db_dir/$tableName","column.def,column.data");
        sql_filehandle::UPDATEFILE("$db_dir/Table.names.def",'A',$tableName) or ffdperl_error::ffdperl_error("Couldn't update file: tablenames master file.");
        
        
        my @columns = subAttr($colums);
        
        for my $col (@columns){
            my @each = split(/;/,$col);
            for my $blah (@each){
                my @attr = split(/\|/,$blah);
                for my $a (@attr){
                    sql_filehandle::CREATEFILE("$db_dir/$tableName","$blah"."_AUTO_INCREMENT.data") if $a =~ /AUTO_INCREMENT/;
                    sql_filehandle::UPDATEFILE("$db_dir/$tableName","$blah"."_AUTO_INCREMENT.data",'W',0);
                }
            }
        }
        
        sql_filehandle::UPDATEFILE("$db_dir/$tableName/column.def",'W',@columns);
    }else {
        ffdperl_error::ffdperl_error("Table with $tableName already exist.");
    }
    return $table_name_check;
}

sub DROP_TABLE
{
	my($db_dir,$tableName) = @_;

	my $table_name_check =0;
	$table_name_check = CHECKTABLE($db_dir,$tableName);

	if($table_name_check eq 1) {
		#Deleting the $tableName dir from $db_dir
		sql_filehandle::DELETEDIR("$db_dir/$tableName");
		#Remove the $tableName from Master Table
		sql_filehandle::UPDATEFILE("$db_dir/Table.name.def","RW",$tableName) || ffdperl_error::ffdperl_error("couldn't update file: Table Names master file.");
	}
	else {
		ffdperl_error::ffdperl_error("Table with $tableName doesn't exist.");	
	}
}
sub subAttr
{
    my @arrt = split(/,/,$_[0]);
    my $retn;
    
    foreach my $a (@arrt){
        $a =~ s/\s\|//g;
        $retn .= "$a;";   
    }
    
    return $retn;
}
sub CHECKTABLE
{
    my ($dir,$tableName) = @_;
    my $check = 0;
    
    my @tables = sql_filehandle::READFILE("$dir/Table.names.def");
        
        
    for my $b (@tables){
        if(lc($b) eq lc($tableName)){
            $check = 1;
        }
    }
    
       
    
    return $check;
}
#############################
# SUB: CHECK_SUPPORTED_FUNCTIONS
# USEAGE: $db = check_supported_functions(@functions,$statement);
# DESC: Check for supported functions if its exits and returns 0 or 1
sub check_supported_functions
{
    my ($SUPPORTED,$statement) = @_;
    
    my $support = 0;
    foreach my $fuc (@{$SUPPORTED}){
       my ($CT,$UD,$SEL,$INC) = split(/,/,$fuc);
       $support++ if($statement =~ /$CT/ ||
                     $statement =~ /$UD/ ||
                     $statement =~ /$SEL/ ||
                     $statement =~ /$INC/);
    }
    
    return $support;
    
}

1;
