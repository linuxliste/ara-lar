<?php

// mehmet Emin Akyüz <me_akyuz@yahoo.com>
// 2015.01.31
// Remzi AKYUZ icin hazirlanmistir

$dir = $argv[1];

function user( $id )
{
	static $users = array();
	
	if( !isset( $users[$id] ) ){
		$user = posix_getpwuid( $id );
		$users[$id] = $user['name'];
	}
	return $users[$id];
}

function group( $id )
{
	static $groups = array();
	
	if( !isset( $groups[$id] ) ){
		$group = posix_getgrgid( $id );
		$groups[$id] = $group['name'];
	}
	return $groups[$id];
}

function ls( $dir )
{
	$files = scandir( $dir );
	foreach( $files as $file ){
		if( $file == '.' || $file == '..' ){
			continue;
		} else {
			if( is_dir( $dir . '/' . $file ) ){
				ls( $dir . '/' . $file );
			} else {
				if( is_link( $dir . '/' . $file ) ){
					$s = lstat( $dir . '/' . $file );
				} else {
					$s = stat( $dir . '/' . $file );
				}
				echo decoct( $s[2] ) . ' '  . $dir . '/' . $file . "\n";
				echo  user( $s[5] ) . ':' . group( $s[4] ) . " " . $dir . '/' . $file . "\n";
#				echo decoct( $s[2] ) . ':' . group( $s[4] ) . ':' . user( $s[5] ) . ":" . $dir . '/' . $file . "\n";
			}
		}
	}
}

ls( $dir );
?>
