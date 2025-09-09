# Hotfix to workaround known mac-learning issue with 8325. 


## Issue description

> **Aruba CR:**          90598
>
> **Affected platform:** 8325
>
>**Symptom:**           MAC learning stops.
>
>**Scenario:**          Under extremely rare DMA stress conditions, anL2 learning thread may timeout and exit preventing future MAC learning.
>
>**Workaround:**        Reboot the switch or monitor the L2 thread and restart it with an NAE script
>
>**Fixed in:**	       10.06.0130, 10.7.0010 and above. 
>
>[Aruba release notes](https://asp.arubanetworks.com/downloads;products=Aruba%20Switches;productSeries=Aruba%208325%20Switch%20Series) 

## To fix the issue without upgrading software:

	You can run a NAE script on the 8325 platform switches to resolve mac learning issue.

## Important information:

	- This NAE script creates a bash script in /tmp and runs every 60s.
	- The script writes file to a storage every 60s (NAE alert file)
	- There are no controls over alert status.
	- Event log is created when a problem is detected
	
	“BCML2X has quit unexpectedly, attempting to restart...”

	- You can also grep the error from /var/log/messages
	- REST-API URI = /rest/v10.04/logs/event?SYSLOG_IDENTIFIER=root&since=yesterday
	- Delete agent & script after upgrading to 10.06.0130+
	- Monitor eMMC health if you plan on running for a long time
	- show system resource | include utiliz

## Installing the NAE script:
 
**Step 1:**
 
	To get started, login to an AOS-CX device via the Web User Interface, and click on the Analytics section on the left, then click on the Scripts button on the top middle section.

**Step 2:** 

	On the Scripts page: 

	Install the script from your PC to your AOS-CX device by clicking the Upload button on the scripts page and navigating to the file location on your PC.

**Step 3:**
 
	After you have the script on the AOS-CX device, you now need to create an agent. On the Scripts page, you can click the Create Agent button and a Create Agent popup box will appear.

	Give the Agent a name (no spaces).

	NOTE: You can leave all other default values and click Create.

**Step 4:** 

	Navigate you to the Agents page, where you can click on the name of the Agent you made to confirm it is running and no errors are generated. 

	The Network Analytics Engine will monitor the switch and automatically fix the mac learning issue. 




