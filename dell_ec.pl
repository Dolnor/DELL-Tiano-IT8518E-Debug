#!/usr/bin/perl -w

# Copyright (C) 2007  Michael Kurz     michi.kurz (at) googlemail.com
# Copyright (C) 2007  Petr Tomasek     tomasek (#) etf,cuni,cz
# Copyright (C) 2007  Carlos Corbacho  cathectic (at) gmail.com
# Copyright (C) 2014  TimeWalker       timewalker75a (at) gmail.com
#
# This work is based on acer_ec.pl from https://code.google.com/p/aceracpi/
# implementing knowledge about registers on DELL Vostro 3450 and Inspiron N4110 laptops
# that support an ITE IT8518E Embedded Controller (closed datasheet)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 5.004;

use strict;
use Fcntl;
use POSIX;
use File::Basename;

sub initialize_ioports
{
  sysopen (IOPORTS, "/dev/port", O_RDWR)
    or die "/dev/port: $!\n";
  binmode IOPORTS;
}

sub close_ioports
{
  close (IOPORTS)
    or print "Warning: $!\n";
}

sub inb
{
  my ($res,$nrchars);
  sysseek IOPORTS, $_[0], 0 or return -1;
  $nrchars = sysread IOPORTS, $res, 1;
  return -1 if not defined $nrchars or $nrchars != 1;
  $res = unpack "C",$res ;
  return $res;
}

sub outb
{
  if ($_[0] > 0xff)
  {
    my ($package, $filename, $line, $sub) = caller(1);
    print "\n*** Called outb with value=$_[1] from line $line\n",
          "*** (in $sub). PLEASE REPORT!\n",
          "*** Terminating.\n";
    exit(-1);
  }
  my $towrite = pack "C", $_[0];
  sysseek IOPORTS, $_[1], 0 or return -1;
  my $nrchars = syswrite IOPORTS, $towrite, 1;
  return -1 if not defined $nrchars or $nrchars != 1;
  return 0;
}

sub wait_write
{
	my $i = 0;
	while ((inb($_[0]) & 0x02) && ($i < 10000)) {
		sleep(0.01);
		$i++;
	}
	return -($i == 10000);
}

sub wait_read
{
	my $i = 0;
	while (!(inb($_[0]) & 0x01) && ($i < 10000)) {
		sleep(0.01);
		$i++;
	}
	return -($i == 10000);
}

sub wait_write_ec
{
	wait_write(0x66);
}

sub wait_read_ec
{
	wait_read(0x66);
}

sub send_ec
{
	if (!wait_write_ec()) { outb($_[0], 0x66); }
	if (!wait_write_ec()) { outb($_[1], 0x62); }
}

sub write_ec
{
	if (!wait_write_ec()) { outb(0x81, 0x66 ); }
	if (!wait_write_ec()) { outb($_[0], 0x62); }
	if (!wait_write_ec()) { outb($_[1], 0x62); }
}

sub read_ec
{
	if (!wait_write_ec()) { outb(0x80, 0x66 ); }
	if (!wait_write_ec()) { outb($_[0], 0x62); }
	if (!wait_read_ec())  { inb(0x62); }
}

sub read_temps
{
	initialize_ioports();

	print "------------ Abbreviations ------------\n";
	print "OTC - Optical Thermocouple\nHSA - Heatsink Assembly\n";
	print "DTS - Digital Thermal Sensor\nTHR - Thermistor\n";
	print "----------- Sensor Readings -----------\n";
	my @s = ("CPU Package  \t[OTC]","D-GPU Die \t[DTS]","Chipset \t[HSA]",
		 "CPU Heatsink \t[HSA]","Mainboard \t[THR]","CPU Die \t[DTS]", 
	         "PCH Die \t[DTS]","Memory Modules \t[THR]");
	my $i = 0;
	my $t = 0;	
	for ($i = 0; $i < 8; $i++)
	{
		$t = read_ec(0x55+$i);
		if ($t != 0x00) { printf ("$s[$i]\t\t %d C\n",$t); }
	}	
	close_ioports();
}

sub read_fan_status
{
	initialize_ioports();
	# read level of rpm
	my $flvl = read_ec(0x63);
	print "Fan Auto Level ";
	if ($flvl == 0x00) {
		print "#0 \tDisabled\n"; 
	} elsif ($flvl  == 0x01) {
		print "#1 \t3000-3900rpm\n"; 
	} elsif ($flvl == 0x02) {
		print "#2 \t4200-4500rpm\n";
	} elsif ($flvl  == 0x03) {
		print "#3 \t4500-5300rpm\n";
	} elsif ($flvl  == 0xFF) {
		print "#X \tOverridden\n";
	}
	# read opeation mode
	print "Fan Operation Mode";
	if (read_ec(0x60) == 0x40) {
		print "\tAutomatic\n";
	} elsif (read_ec(0x60) == 0x00) {
		print "\tManual\n";
	} 
	# read actual fan speed
	my $fs = read_ec(0x68) <<8 | read_ec(0x69);
	if ($fs != 0x00) {
	 	printf ("Fan Rotation Speed\t%drpm\n",$fs);
	}

	close_ioports();
}

sub read_battery_info
{
	initialize_ioports();
	
	print "-------------------- Details -----------------\n";
	my $bd1 = read_ec(0xcb);
	my $bd2 = read_ec(0xcc);
	if ($bd1 & 0x01) {
		print "Battery is Installed\n";
		if ($bd1 & 0x32) {
			print "\t - Charge Low\n";
		} 
		if ($bd1 & 0x16) {
			print "\t - Charge Critical\n";
		}
		if ($bd2 & 0x01) {
			print "\t - Fully Charged\n";
		}
		if ($bd1 & 0x64) {
			print "\t - Discharging\n";
		}
		if ($bd2 & 0x32) {
			print "\t - Capable of Charging\n";
		} else {
			print "\t - Not Capable of Charging\n";
		}

		print "---------------- OEM Information ------------\n";
		my $dcap = read_ec(0xb1) <<8 | read_ec(0xb0);
		my $dvol = read_ec(0xb3) <<8 | read_ec(0xb2);	
		printf ("Designed Battery Capacity\t %d\tmWh\n", $dcap);
		printf ("Designed Battery Voltage\t %d\tmV\n",  $dvol);	

		my $boem = read_ec(0xc4);
		SWITCH: {
	    		print "Battery Manufacturer\t\t ";
	    		$boem == 0x09 && do { print "LG Chem\n";  last SWITCH;};
	    		$boem == 0x08 && do { print "Motorola\n"; last SWITCH;};
	    		$boem == 0x07 && do { print "Simplo\n";   last SWITCH;};
	    		$boem == 0x06 && do { print "Samsung SDI\n";last SWITCH;};
	    		$boem == 0x05 || $boem == 0x02 && do { print "Sony\n";last SWITCH;};
	    		$boem == 0x04 && do { print "Panasonic\n";last SWITCH;};
	    		$boem == 0x03 && do { print "Sanyo\n";    last SWITCH;};
	    		$boem == 0x01 && do { print "Dell\n";     last SWITCH;};
	    		$boem == 0x00 && do { print "Unknown\n";  last SWITCH;};
		}
		my $bser = read_ec(0xb9) <<8 | read_ec(0xb8);	
		my $bmod = read_ec(0xc5);
		print "Battery Model Number \t\t ";
		if ($bmod == 0xFF) {
			printf ("Dell-%d\n",$bser);
		}
		else {
			printf ("Unknown-%d\n",$bser);
		}
		my $btyp = read_ec(0xc6);
		SWITCH: {
	    		print "Battery Chemistry\t\t ";
	    		$btyp == 0x08 && do { print "Li-P\n";    last SWITCH;};
	    		$btyp == 0x07 && do { print "Zn-Air\n";  last SWITCH;};
	    		$btyp == 0x06 && do { print "RAM\n";     last SWITCH;};
	    		$btyp == 0x05 && do { print "Ni-Zn\n";   last SWITCH;};
	    		$btyp == 0x04 && do { print "Ni-MH\n";   last SWITCH;};
	    		$btyp == 0x03 && do { print "NI-Cd\n";   last SWITCH;};
	    		$btyp == 0x02 && do { print "Li-ION\n";	 last SWITCH;};
	    		$btyp == 0x01 && do { print "Pb-Ac\n";   last SWITCH;};
	    		$btyp == 0x00 && do { print "Unknown\n"; last SWITCH;};
		}

		my $bcap = read_ec(0xa1) <<8 | read_ec(0xa0);
		my $bvol = read_ec(0xa5) <<8 | read_ec(0xa4);
		my $bcur = read_ec(0xa7) <<8 | read_ec(0xa6);
		my $bper = read_ec(0xac);
		my $blfc = read_ec(0xaf) <<8 | read_ec(0xae);

		print "-------------------- Status -----------------\n";
		printf ("Battery Charge\t\t\t %d%%\n", $bper);
		printf ("Battery Capacity\t\t %d\tmWh\n", $bcap);
		printf ("Battery Voltage \t\t %d\tmV\n", $bvol);
		if ($bcur != 0) { printf ("Battery Current Flow\t\t %d\tmW\n", $bcur);}
		printf ("Last Charge Capacity\t\t %d\tmWh\n", $blfc);

		print "-------------------- Health -----------------\n";
	
		my $ccnt = ($dcap - $blfc) / 5.8;
		my $bhlt = 0x64 * $blfc / $dcap;
		printf ("Battery Cycle Count\t\t %d\n", $ccnt);
		printf ("Battery Health State\t\t %d%%\n", $bhlt);

	}
	else {
		print "Battery not Installed\n";
	}

	close_ioports();
}

sub print_regs
{
	initialize_ioports();

	my @arr = ("00","10","20","30","40","50","60","70","80","90","A0","B0","C0","D0","E0","F0", "");

	my $i = 0;
	my $t = 0;
	print "\n  \t 00\t 01\t 02\t 03\t 04\t 05\t 06\t 07\t|\t 08\t 09\t 0A\t 0B\t 0C\t 0D\t 0E\t 0F\n";
	print "  \t----\t----\t----\t----\t----\t----\t----\t----\t|\t----\t----\t----\t----\t----\t----\t----\t----\n";
	print "00 |\t";
	for ($i = 0; $i < 256; $i++)
	{
		$t = read_ec($i);
		printf ("0x%02x",$t);
		print "\t";
		if ((($i + 1) % 8) == 0){
			if ((($i + 1) % 16) == 0) {
				if ($i != 255) { print "\n$arr[(($i-(($i + 1) % 16)) / 16) + 1] |\t"; }
			} else {
				print "|\t";
			}
		}
	}
	
	print "\n";
	
	close_ioports();
}

if (!$ARGV[0]){
	print "usage:\n";
	print "\'dell_ec regs\' \t\t\tdump all ec registers (reduce font in terminal!)\n";
	print "\'dell_ec temps\' \t\tdisplay temperatures from sensors\n";
	print "\'dell_ec gettouch\' \t\tshow touchpad status (enabled|disabled)\n";
	print "\'dell_ec getfanstat\' \t\tdetermine level, mode and speed of system fan\n";
	print "\'dell_ec getbatstat\' \t\tdisplay battery information and health\n";
	print "\'dell_ec getkbstat\' \t\tshow keyboard backlight level and timeout\n";
	print "\'dell_ec getacstat\' \t\tdetermine ac adapter wattage & current power source\n";
	print "\'dell_ec ?= <reg>\' \t\tread register value\n";
	print "\'dell_ec := <reg> <val>\' \twrite register value\n";
	print "\’dell_ec +f <reg> <val>\' \tOR register value with val (to set flags)\n";
	print "\’dell_ec -f <reg> <val>\' \tAND register value with ~val (to clear flags)\n";

} elsif ($ARGV[0] eq "regs") {
	print_regs();
} elsif ($ARGV[0] eq "temps") {
	read_temps();
} elsif ($ARGV[0] eq "?=") {
	initialize_ioports();
	my $r = hex($ARGV[1]);
	printf("Read  REG[0x%02x] == 0x%02x\n", $r, read_ec($r));
	close_ioports();
} elsif ($ARGV[0] eq ":=") {
	initialize_ioports();
	my $r = hex($ARGV[1]);
	my $f = hex($ARGV[2]);
	my $val = read_ec($r);
	printf("Read  REG[0x%02x] == 0x%02x\n", $r, $val);
	printf("Write REG[0x%02x] := 0x%02x\n", $r, $f);
        write_ec( $r, $f);
	printf("Read  REG[0x%02x] == 0x%02x\n", $r, read_ec($r));
	close_ioports();
} elsif ($ARGV[0] eq "+f") {
	initialize_ioports();
	my $r = hex($ARGV[1]);
	my $f = hex($ARGV[2]);
	my $val = read_ec($r);
	printf("Read REG[0x%02x] == 0x%02x\n", $r, $val);
	printf("OR   REG[0x%02x] := 0x%02x\n", $r, $val | $f);
        write_ec( $r, $val | $f);
	printf("Read REG[0x%02x] == 0x%02x\n", $r, read_ec($r));
	close_ioports();
} elsif ($ARGV[0] eq "-f") {
	initialize_ioports();
	my $r = hex($ARGV[1]);
	my $f = hex($ARGV[2]);
	my $val = read_ec($r);
	printf("Read REG[0x%02x] == 0x%02x\n", $r, $val);
	printf("AND  REG[0x%02x] := 0x%02x\n", $r, $val & ~$f);
        write_ec( $r, $val & ~$f);
	printf("Read REG[0x%02x] == 0x%02x\n", $r, read_ec($r));
	close_ioports();
} elsif ($ARGV[0] eq "gettouch") {
	initialize_ioports();
	if (read_ec(0x45) == 0x20) {
		print "Touchpad Enabled\n";
	} else {
		print "Touchpad Disabled\n"; }
	close_ioports();
} elsif ($ARGV[0] eq "getfanstat") {
	read_fan_status
} elsif ($ARGV[0] eq "getacstat") {
	initialize_ioports();
	if (read_ec(0x40) & 0x01) {
		my $w = read_ec(0x80);		
		printf ("Running on %dW AC Adapter\n",$w);
	} else {
		print "Running on Battery Power, \'getbatstat\' for Details\n";
	} 
	close_ioports();
} elsif ($ARGV[0] eq "getkbstat") {
	initialize_ioports();
	my $bkl = read_ec(0x8C);
	my $bkt = read_ec(0x8B);
    print "------------------- Backlight -----------------\n";
	SWITCH: {
	    	print "Keyboard Backlight Level\t ";
	    	$bkl == 0x01 && do { print "Dim\n";   last SWITCH;};
	    	$bkl == 0x02 && do { print "Bright\n";last SWITCH;};
	    	$bkl == 0x00 && do { print "Disabled\n";   last SWITCH;};
	}
	SWITCH: {
	    	print "Keyboard Backlight Timeout\t";
	    	$bkt == 0x01 && do { print " 5 sec\n"; last SWITCH;};
	    	$bkt == 0x03 && do { print " 15 sec\n";last SWITCH;};
	    	$bkt == 0x06 && do { print " 30 sec\n";last SWITCH;};
	    	$bkt == 0x0C && do { print " 1 min\n"; last SWITCH;};
	    	$bkt == 0x3C && do { print " 5 min\n"; last SWITCH;};
	    	$bkt == 0xB4 && do { print " 15 min\n";last SWITCH;};
 	    	$bkt == 0x00 && do { print " Never\n";last SWITCH;};
	}
    
    my $leds = read_ec(0x70);
	print "--------------------- LEDs --------------------\n";
	
	if ($leds != 0) {
		if ($leds & 0x02) {print "Keyboard Num Lock LED \t\t Enabled\n";}
		if ($leds & 0x04) {print "Keyboard Caps Lock LED \t\t Enabled\n";}
		if ($leds & 0x01) {print "Keyboard Scroll Lock LED \t\t Enabled\n";}
	}
	else {print "All Keyboard LEDs \t\t Disabled\n";}
    
	close_ioports();
} elsif ($ARGV[0] eq "getbatstat") {
	read_battery_info();
} else {
	print "wrong arguments!\n";
}
