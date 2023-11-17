#!/bin/bash
#first install harrierv2_main

#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
GREEN4read=$'\033[0;32m';
YELLOW4read=$'\033[1;33m';
NC4read=$'\033[0m';
NC='\033[0m' # No Color
FUS120=0
FCYCLES=0
FAILFLAG=0
BOARDSIZE=10
    while read -N 1 -t 0.01
	do :
    done
spd-say "к прошивке готов, мой генерал"
while read -n1 -r -p "${GREEN4read}Ready?${NC4read} Press any key or ${YELLOW4read}[q]${NC4read}uit"
do
    FUS120=0
    if [[ $REPLY == q ]] || [[ $REPLY == й ]]
    then
        break
    elif [[ $REPLY == d ]] || [[ $REPLY == в ]]
    then
        let "FCYCLES--"
        echo -e "${YELLOW}Done: $FCYCLES${NC}"
    else
	spd-say "старт"
	FUSSTART=$(./STM32_Programmer_CLI -c port=SWD -startfus)
	FUSIDLETEXT="FUS_STATE_IDLE
startfus command execution finished"
	if [[ "$?" == "0" ]] && [[ "$FUSSTART" == *"$FUSIDLETEXT"* ]]
	then
		echo "FUS state idle, started OK."
		spd-say "фус старт"
	else
		echo "Something went wrong during FUSstart attempt, trying again..."
#		echo -e "$FUSSTART"
		FUSSTART=$(./STM32_Programmer_CLI -c port=SWD -startfus)
		if [[ "$?" == "0" ]] && [[ "$FUSSTART" == *"$FUSIDLETEXT"* ]]
		then
			echo "Now FUS state idle, started OK."
			spd-say "фус старт"
		else
			echo "Something went wrong twice during FUSstart attempt, check output..."
			echo -e "$FUSSTART"
			FAILFLAG=1
		fi
	fi
#FUS STARTED-----------------------
	if [[ "$FAILFLAG" == "0" ]]
	then
#		Checking FUS version
	    FUSVER="error"
	    while [ "$FUSVER" == "error" ]
	    do
		FUSVER=$(./STM32_Programmer_CLI -c port=SWD -r32 0x20010010 4 | tail -n 4)
		#echo $FUSVER
		FUSVER=$(echo -e "$FUSVER" | cut -d ' ' -f3)
		echo "'"$FUSVER"'"
	    done
	    if [[ $FUSVER == *"01020000"* ]]
	    then
		    echo "FUS ver 1.2.0 - OK."
		    FUS120=1
	    else
#		If FUS == 0.5.3 upgrade with FUSfwforfus053
		if [[ $FUSVER == *"00050300"* ]]
		then
		    echo "Attention! 0.5.3 FUS version! Trying to upgrade..."
		    CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -fwupgrade harrierv2_main/1_stm32wb5x_FUS_fw_for_fus_0_5_3.bin 0x080ec000 firstinstall=0)
		    SUCCESSCODE="Firmware Upgrade Success"
		    if [[ "$?" == "0" ]] || [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]]
		    then
			echo "1. FUS for 0.5.3 Upgrade Success."
		    else
			echo "Something went wrong during FUS for 0.5.3, check output..."
			echo -e "$CUBEOUTPUT"
			FAILFLAG=1
		    fi
		fi
	    fi
	    if [[ "$FAILFLAG" == "0" ]]
	    then
#		If FUS 1.x.x then upgrade
		if [[ "$FUS120" == "0" ]]
		then
		    CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -fwupgrade harrierv2_main/2_stm32wb5x_FUS_fw.bin 0x080ec000 firstinstall=0)
		fi
	        SUCCESSCODE="Firmware Upgrade Success"
		    if [[ "$FUS120" == "1" ]]
		    then
			echo -e "2. FUS upgrade ${YELLOW}SKIPPED${NC}."
		    elif [[ "$?" == "0" ]] && [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]]
		    then
			echo "2. FUS upgrade success."
   		    	spd-say "фус"
		    else
		    	echo "Something went wrong during FUS upgrade, check output..."
			echo -e "$CUBEOUTPUT"
			echo -e "${RED}Flashing failed. Done: $FCYCLES${NC}"
			FAILFLAG=0
			spd-say "внимание, ошибка, повторить"
			while read -N 1 -t 0.01
			do :
			done
			continue
		    fi
		    CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -fwupgrade harrierv2_main/3_stm32wb5x_BLE_Stack_full_fw.bin 0x080ca000 firstinstall=0)
		    if [[ "$?" == "0" ]] && [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]]
		    then
			echo "3. BLE upgrade success."
			spd-say "б, л, е"
			CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -startwirelessstack)
			SUCCESSCODE="FusStartWS activated successfully
startwirelessStack command execution finished"
			if [[ "$?" == "0" ]] && [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]]
			then
				echo "FusStartWS activated, startwirelessStack OK."
				spd-say "wireless"
				CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -ob nSWboot0=1)
				NSWB_OK="0"
				SUCCESSCODE="Option Bytes successfully programmed"
				SUCCESSCODE2="Warning: Option Byte: nswboot0, value: 0x1, was not modified"
				if [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]] || [[ "$CUBEOUTPUT" == *"$SUCCESSCODE2"* ]]
				then
					NSWB_OK="1"
				fi
				if [[ "$?" == "0" ]] && [[ "$NSWB_OK" == "1" ]]
				then
				    echo "nSWboot0=0x1, OK"
				    spd-say "nswboot"
				    CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -d harrierv2_main/4_SRS_bootloader_v5.hex 0x8000000 -v)
				    SUCCESSCODE="Download verified successfully"
				    if [[ "$?" == "0" ]] && [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]]
					then
						echo "4. Bootloader verified successfully."
						spd-say "bootloader"
						CUBEOUTPUT=$(./STM32_Programmer_CLI -c port=SWD -d harrierv2_main/5_SRS_main_v204.hex 0x8010000 -v)
						if [[ "$?" == "0" ]] && [[ "$CUBEOUTPUT" == *"$SUCCESSCODE"* ]]
						then
							echo "5. Main program verified successfully."
#							spd-say "main"
							echo -e "${GREEN}Full Procedure completed.${NC}"
						else
							echo "Something went wrong during Main program download, check output..."
						        echo -e "$CUBEOUTPUT"
							FAILFLAG=1
						fi
					else
						echo "Something went wrong during Bootloader download, check output..."
						echo -e "$CUBEOUTPUT"
						FAILFLAG=1
					fi
				else
					echo "Something went wrong during nSWboot0 set, check output..."
					echo -e "$CUBEOUTPUT"
					FAILFLAG=1
				fi
			else
				echo "Something went wrong during start wirelessStack, check output..."
				echo -e "$CUBEOUTPUT"
				FAILFLAG=1
			fi
		    else
			echo "Something went wrong during BLE stack upgrade, check output..."
			echo -e "$CUBEOUTPUT"
		        FAILFLAG=1
		    fi
#		else
#			echo "Something went wrong during FUS upgrade, check output..."
#			echo -e "$CUBEOUTPUT"
#		    FAILFLAG=1
#		fi
	    fi
	fi
#FUS STARTED-----------------------

	if [[ "$FAILFLAG" == "0" ]]
	then
	    let "FCYCLES++"
	    let FCMOD=$FCYCLES+$BOARDSIZE
	    if [[ $(($FCMOD%$BOARDSIZE)) == "0" ]]
	    then
		echo -e "${YELLOW}Done: $FCYCLES${NC} ($BOARDSIZE | $(($FCMOD/$BOARDSIZE-1)))"
	    else
		echo -e "${YELLOW}Done: $FCYCLES${NC} ($(($FCMOD%$BOARDSIZE)) | $(($FCMOD/$BOARDSIZE)))"
	    fi
	    spd-say "окей, следующий"
	else
	    echo -e "${RED}Flashing failed. Done: $FCYCLES${NC}"
	    FAILFLAG=0
	    spd-say "внимание, ошибка, повторить"
	fi
    fi
    while read -N 1 -t 0.01
	do :
    done
done
