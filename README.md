## DELL ITE IT8518E Debugging

This work is based on acer_ec.pl from https://code.google.com/p/aceracpi/

Script is meant for Dell laptop of Sandy Bridge and Ivy Bridge era with Phoenix SecureCore Tiano firmware and ITE8518E Embedded Controller (EC), such as Vostro 3450, 3750, Inspiron N4115, XPS L502x, Vostro 3360 … 

Perl script works under most flavors of Linux, OSX can’t provide IOPorts to EC. This script be used to manipulate values inside EC RAM (255 bytes) and read hardware configuration data from known registers. Registers on Vostro 3450 originally were deciphered by TimeWalker.


### Usage

		'dell_ec regs' 			dump all ec registers (reduce font in terminal)
		'dell_ec temps' 		display temperatures from sensors
		'dell_ec gettouch' 		show touchpad status (enabled|disabled)
		'dell_ec getfanstat' 		determine level, mode and speed of system fan
		'dell_ec getbatstat' 		display battery information and health
		'dell_ec getkbstat' 		show keyboard backlight level and timeout
		'dell_ec getacstat' 		determine ac adapter wattage & current power source
		'dell_ec ?= <reg>' 		read register value
		'dell_ec := <reg> <val>' 	write register value

### Sample output

* gettouch

		touchpad enabled

* getfanstat

		fan level 1 	[3000-3900rpm]
		fan mode auto
		fan speed is 3599rpm

* getkbstat

		keyboard backlight level:	 dim
		keyboard backlight timeout:	15min

* getacstat

		running on 65W ac adapter
