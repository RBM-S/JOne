#!/bin/bash
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'
clear
echo -e "${GREEN}Welcome to the JOne OS Setup, this will set your system up to use JOne OS through the Arch Linux Live CD${RESET}"
echo -e "${YELLOW}Current Build: JOne OS 1.0${RESET}"
echo -e "${YELLOW}Press any key to continue..${RESET}"

read -n 1 -s

echo -e "${GREEN}Sect 1: Disks and Partitioning${RESET}"
echo -e "${RED}This will erase all data on your disk, so make sure to backup your data, otherwise, continue.${RESET}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

echo -e -n ""

echo -e -n "${YELLOW}Would you like to partition your disk? (OPTIONAL) (y/n): ${RESET}"
read -n 1 PARTCONFIRM

if [[ "$PARTCONFIRM" == "y" || "$PARTCONFIRM" == "Y" ]]; then
    echo -e "${YELLOW}What type of partitioning are you seeking?${RESET}"
    echo -e "${GREEN}1. Automatic Partitioning (Recommended for Beginners)${RESET}"
    echo -e "${YELLOW}2. Manual Partitioning${RESET}"
    read -p "${YELLOW}Select a number: ${RESET}" PARTYPSEL
    if [[ "$PARTYPSEL" == 1 || "$PARTYPSEL" == "One" ]]; then
        echo -e "${GREEN}Automatic Partitioning selected!${RESET}"
        echo -e -n "${YELLOW}Select the Disk to partition: ${RESET}"
        read PARTON2
        if [[ ! -e "$PARTON2" ]]; then
            echo -e "${RED}ERROR: Disk $PARTON2 does not exist."
            exit 1
        fi
        echo -e "${YELLOW}NOTE: Use G for Gigabytes and T for Terabytes.${RED}"
        echo -e -n "${YELLOW}Enter the size for the new partition: "
        read GTSIZE
        if [[ "$GTSIZE" =~ ^[0-9]+(G|T)$ ]]; then
            SIZE=${GTSIZE%[GT]}
            UNIT=${GTSIZE: -1}
        else
            echo -e "${RED}ERROR: Invalid Input has been detected, Use G for Gigabytes and T for Terabytes.${RESET}"
            exit 1
        fi
        echo -e "${RED}WARNING: Do not use spaces in the label.${RESET}"
        echo -e -n "${YELLOW}Select the partition label/name: ${RESET}"
        read PARTLABEL
        echo -e -n "${YELLOW}What type is your motherboard? (UEFI/BIOS): ${RESET}"
        read MRDTPE 
        if [[ "$MRDTPE" == "UEFI" ]]; then
            echo -e "${YELLOW}Since you are on UEFI, the script will create a GPT partition table.${RESET}"
            echo -e "${GREEN}Selection Overview:${RESET}"
            echo -e "${GREEN}Motherboard Type: $MRDTPE ${RESET}"
            echo -e "${GREEN}Partition Type: $PARTYPSEL ${RESET}"
            echo -e "${GREEN}Partition Disk: $PARTON2 ${RESET}"
            echo -e "${GREEN}Partition Label: $PARTLABEL ${RESET}"
            echo -e "${GREEN}Partition Size: $GTSIZE ${RESET}"
            echo -e "${YELLOW}Does everything match up? (y/n): ${RESET}"
            read UEFIPARTCONFIRM
            DSKSZB=$(lsblk -b -o SIZE -n $PARTON2)
            DSKSZGT=$(echo "$DSKSZB / 1024 / 1024 / 1024" | bc)


            if [[ "$UNIT" == "G" ]]; then
                GTSIZE=$SIZE
            elif [[ "$UNIT" == "T" ]]; then
                GTSIZE=$((SIZE * 1024))
            fi

            if (( GTSIZE >= DSKSZGT )); then
                echo -e "${RED}ERROR: No Disk Space available for the given partition size.${RESET}"
                echo -e "${RED}Given Partition Size: $GTSIZE ${RESET}"
                echo -e "${RED}Disk Size: $DSKSZGT ${RESET}"
                exit 1
            fi

            PTSIZE=$(echo "scale=2; $GTSIZE / $DSKSZGT * 100" | bc)

            if [[ "$UEFIPARTCONFIRM" == 'Y' || "$UEFIPARTCONFIRM" == 'y' ]]; then
                parted $PARTON2 mklabel gpt
                parted $PARTON2 mkpart primary ext4 0% $PTSIZE%
                parted $PARTON2 set 1 boot on
                parted $PARTON2 name 1 "$PARTLABEL"
                parted $PARTON2 mkpart primary linux-swap $PTSIZE% 100%
                parted $PARTON2 set 2 swap on
            elif [[ "$UEFIPARTCONFIRM" == 'N' || "$UEFIPARTCONFIRM" == 'n' ]]; then
                echo -e "${RED}Disk Partition Setup aborted, skipping..${RESET}"
            fi
        elif [[ "$MRDTPE" == "BIOS" ]]; then
            echo -e "${YELLOW}Since you are on BIOS, the script will create an MBR partition table.${RESET}"
            echo -e "${GREEN}Selection Overview:${RESET}"
            echo -e "${GREEN}Motherboard Type: $MRDTPE ${RESET}"
            echo -e "${GREEN}Partition Type: $PARTYPSEL ${RESET}"
            echo -e "${GREEN}Partition Disk: $PARTON2 ${RESET}"
            echo -e "${GREEN}Partition Label: $PARTLABEL ${RESET}"
            echo -e "${YELLOW}Does everything match up? (y/n): ${RESET}"
            read MSDOSPARTCONFIRM
            DSKSZB=$(lsblk -b -o SIZE -n $PARTON2)
            DSKSZGT=$((DSKSZB / 1024 / 1024 / 1024))

            if [[ "$UNIT" == "G" ]]; then
                GTSIZE=$SIZE
            elif [[ "$UNIT" == "T" ]]; then
                GTSIZE=$((SIZE * 1024))
            fi

            if (( GTSIZE >= DSKSZGT )); then
                echo -e "${RED}ERROR: No Disk Space available for the given partition size.${RESET}"
                echo -e "${RED}Given Partition Size: $GTSIZE ${RESET}"
                echo -e "${RED}Disk Size: $DSKSZGT ${RESET}"
                exit 1
            fi

            PTSIZE=$(echo "scale=2; $GTSIZE / $DSKSZGT * 100" | bc)

            if [[ "$MSDOSPARTCONFIRM" == 'Y' || "$MSDOSPARTCONFIRM" == 'y' ]]; then
                parted $PARTON2 mklabel msdos
                parted $PARTON2 mkpart primary ext4 0% $PTSIZE%
                parted $PARTON2 set 1 boot on
                parted $PARTON2 name 1 "$PARTLABEL"
                parted $PARTON2 mkpart primary linux-swap $PTSIZE% 100%
                parted $PARTON2 set 2 swap on
            elif [[ "$MSDOSPARTCONFIRM" == 'N' || "$MSDOSPARTCONFIRM" == 'n' ]]; then
                echo -e "${RED}Disk Partition Setup aborted, skipping..${RESET}"
            fi
        elif [[ "$MRDTPE" != "UEFI" && "$MRDTPE" != "BIOS" ]]; then
            echo -e "${RED}ERROR: Invalid Motherboard Type, select from UEFI or BIOS."
            exit 1
        fi
    fi
elif [[ "$PARTCONFIRM" == "n" || "$PARTCONFIRM" == "N" ]]; then
    echo -e "${RED}Skipping Disk Partition Setup..${RESET}"
fi

while true; do
    echo -e -n "${YELLOW}Enter the partition to format: ${RESET}"
    read PARTON1

    if mount | grep -q "$PARTON1"; then
        echo -e "${YELLOW}Unmounting $PARTON1...${RESET}"
        umount $PARTON1
        if [ $? -ne 0 ]; then
            echo -e "${RED}ERROR: Failed to unmount $PARTON1, you have encountered a bug, report it in the issues section in the Github Repository so I can fix it."
            continue
        fi
    fi

    echo -e "${RED}Again, This will erase ALL data on $PARTON1, continue if you are aware of the risks and don't care (y/N)? ${RESET}"
    read -n 1 ERASECONFIRM
    echo  #

    if [[ "$ERASECONFIRM" == "y" || "$ERASECONFIRM" == "Y" ]]; then
        echo -e "${RED}You will have 5 seconds to revert this action by pressing CTRL+C, if this is intentional, do nothing.${RESET}"
        sleep 5
        echo -e "${RED}Formatting $PARTON1..."
        mkfs.ext4 $PARTON1

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}$PARTON1 formatted successfully${RESET}"
        else
            echo -e "${RED}ERROR: Failed to format $PARTON1, you have encountered a bug, report it in the issues section in the Github Repository so I can fix it.${RESET}"
        fi
    fi
done
