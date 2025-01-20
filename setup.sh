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

echo -e "${YELLOW}Updating Mirror..${RESET}"
sudo pacman -Sy --noconfirm >/dev/null 2>errlog
if [[ $? -ne 0 ]]; then
    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
    exit 1
else
    echo -e "${GREEN}Updated Mirrors!${RESET}"
fi

echo -e "${YELLOW}Creating errlog to log errors..${RESET}"
touch errlog || {
    echo -e "${RED}ERROR: Failed to create errlog file, this is not mandatory, so you can continue setup without it.${RESET}"
    echo -e "${RED}If you want to continue setup with errlog, try restarting the program, if nothing works, report it to https://github.com/RBM-S/JOne/issues${RESET}"
}

echo -e "${GREEN}Sect 1: Disks and Partitioning${RESET}"
echo -e "${RED}This will erase all data on your disk, so make sure to backup your data, otherwise, continue.${RESET}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | while IFS= read -r line; do
    echo -e "${YELLOW}$line${RESET}"
done

echo -e -n "${YELLOW}Do you have the packages: parted, bc? (y/n): ${RESET}"
read PACKCONF
if [[ "$PACKCONF" == 'Y' || "$PACKCONF" == 'y' ]]; then
    echo -e "${GREEN}Great, these are required.${RESET}"
elif [[ "$PACKCONF" == 'N' || "$PACKCONF" == 'n' ]]; then
    echo -e "${GREEN}Installing...${RESET}"
    sudo pacman -S parted bc --noconfirm >/dev/null 2>errlog
    echo -e "${GREEN}Installed!${RESET}"
fi

echo -e -n "${YELLOW}Would you like to partition your disk? (OPTIONAL) (y/n): ${RESET}"
read -n 1 PARTCONFIRM
echo

if [[ "$PARTCONFIRM" == "y" || "$PARTCONFIRM" == "Y" ]]; then
    echo -e "${YELLOW}What type of partitioning are you seeking?${RESET}"
    echo -e "${GREEN}1. Automatic Partitioning (Recommended for Beginners)${RESET}"
    echo -e "${YELLOW}2. Manual Partitioning${RESET}"
    read -p "${YELLOW}Select a number: ${RESET}" PARTYPSEL

    if [[ "$PARTYPSEL" == 1 ]]; then
        echo -e "${GREEN}Automatic Partitioning selected!${RESET}"
        echo -e -n "${YELLOW}Select the Disk to partition: ${RESET}"
        read PARTON2
        if [[ ! -e "$PARTON2" ]]; then
            echo -e "${RED}ERROR: Disk $PARTON2 does not exist."
            exit 1
        fi

        echo -e "${YELLOW}NOTE: Use G for Gigabytes and T for Terabytes.${RESET}"
        echo -e -n "${YELLOW}Enter the size for the new partition: "
        read GTSIZE

        if [[ "$GTSIZE" =~ ^[0-9]+(G|T)$ ]]; then
            SIZE=${GTSIZE%[GT]}
            UNIT=${GTSIZE: -1}
        else
            echo -e "${RED}ERROR: Invalid Input has been detected. Use G for Gigabytes and T for Terabytes.${RESET}"
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
            echo -e "${GREEN}Partition Disk: $PARTON2 ${RESET}"
            echo -e "${GREEN}Partition Label: $PARTLABEL ${RESET}"
            echo -e "${YELLOW}Does everything match up? (y/n): ${RESET}"
            read MSDOSPARTCONFIRM

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
        else
            echo -e "${RED}ERROR: Invalid Motherboard Type, select from UEFI or BIOS.${RESET}"
            exit 1
        fi
    fi
else
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
    echo  ""

    if [[ "$ERASECONFIRM" == "y" || "$ERASECONFIRM" == "Y" ]]; then
        echo -e "${RED}You will have 5 seconds to revert this action by pressing CTRL+C, if this is intentional, do nothing.${RESET}"
        sleep 5
        echo -e "${RED}Formatting $PARTON1..."
        mkfs.ext4 $PARTON1

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}$PARTON1 formatted successfully${RESET}"
            break
        else
            echo -e "${RED}ERROR: Failed to format $PARTON1, you have encountered a bug, report it in the issues section in the Github Repository so I can fix it.${RESET}"
        fi
    fi
done


clear
#!/bin/bash
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'
clear

echo -e "${GREEN}Sect 2: Installing Kernel${RESET}"

declare -A real_krnls=(
    ["krnl1"]="linux-lts"
    ["krnl2"]="linux-hardened"
    ["krnl3"]="linux-zen"
    ["krnl4"]="linux-rt"
)

getpacksc="null"

kch1="krnl1"
kch2="krnl2"
kch3="krnl3"
kch4="krnl4"

while true; do
    echo -n -e "${YELLOW}Do you want to select the kernel you want to use? If not, the regular linux kernel will be installed. (y/n): ${RESET}"
    read mrekrnl

    if [[ "$mrekrnl" == 'Y' || "$mrekrnl" == 'y' ]]; then
        echo -e "${YELLOW}Available Kernel Options:${RESET}"
        for key in "${!real_krnls[@]}"; do
            echo -e "${YELLOW}$key -> ${real_krnls[$key]}${RESET}"
        done

        echo -e "${GREEN}Kernel Options:${RESET}"
        echo -e "${GREEN}krnl1 = linux-lts${RESET}"
        echo -e "${GREEN}krnl2 = linux-hardened${RESET}"
        echo -e "${GREEN}krnl3 = linux-zen${RESET}"
        echo -e "${GREEN}krnl4 = linux-rt${RESET}"
        echo -n -e "${YELLOW}Name one or multiple kernel options (separated by space): ${RESET}"
        read -a kchi_list

        getpacksc="pacstrap -K /mnt base linux linux-firmware"
        for kchi in "${kchi_list[@]}"; do
            if [[ -n "${real_krnls[$kchi]}" ]]; then
                getpacksc="$getpacksc ${real_krnls[$kchi]}"
            else
                echo -e "${RED}Invalid kernel option: $kchi${RESET}"
                continue
            fi
        done

        echo -e "${YELLOW}Kernel Installation Command: $getpacksc${RESET}"
        echo -e "${YELLOW}Press Spacebar to continue or Backspace to cancel.${RESET}"

        read -n 1 -s glbe
        if [[ "$glbe" == $'\x7f' ]]; then
            echo -e "${RED}Cancelled. Restarting...${RESET}"
            clear
            continue
        elif [[ "$glbe" == " " ]]; then
            echo -e "${YELLOW}Validating...${RESET}"
            if [[ "$getpacksc" == *"linux"* ]]; then
                echo -e "${GREEN}Validated!${RESET}"
                sleep 2
                clear
                break
            else
                echo -e "${RED}No valid kernels selected. Restarting...${RESET}"
                continue
            fi
        fi

    elif [[ "$mrekrnl" == 'N' || "$mrekrnl" == 'n' ]]; then
        getpacksc="pacstrap -K /mnt base linux linux-firmware"
        echo -e "${YELLOW}Kernel Installation Command: $getpacksc${RESET}"
        break

        read -n 1 -s glbe
        if [[ "$glbe" == $'\x7f' ]]; then
            echo -e "${RED}Cancelled. Restarting...${RESET}"
            clear
            continue
        elif [[ "$glbe" == " " ]]; then
            echo -e "${YELLOW}Validating...${RESET}"
            echo -e "${GREEN}Validated!${RESET}"
            sleep 2
            clear
            break
        fi
    else
        echo -e "${RED}Invalid input. Please enter Y or N.${RESET}"
        continue
    fi
done

echo -e "${GREEN}Press any key to begin downloading kernel...${RESET}"
read -n 1 -s
echo -e "${GREEN}Sit back and relax while kernel installs!${RESET}"
sleep 2

eval "$getpacksc"


clear
echo -e "${GREEN}Sect 3: System Configuration${RESET}"
echo -e "${GREEN}Press any key to begin..${RESET}"
read -n 1 -s
echo -e "${YELLOW}Generating fstab file...${RESET}"
genfstab -U /mnt >> /mnt/etc/fstab
echo -e "${GREEN}fstab generated successfully!${RESET}"
echo -e "${YELLOW}Configuring chroot...${RESET}"
arch-chroot /mnt
echo -e "${GREEN}Configured chroot successfully!"
clear
echo -e "${GREEN}Configuring the Time${RESET}"
echo ""
echo ""
echo ""
while true; do
    echo -e "${YELLOW}NOTE: Type in whatisit for the definition of hwclock.${RESET}"
    echo -e -n "${YELLOW}Do you want to set up hwclock? (y/n): "
    read hclkcnf
    if [[ "$hclkcnf" == 'Y' || "$hclkcnf" == 'y' ]]; then
        echo -e "${GREEN}Setting up hwclock...${RESET}"
        sudo hwclock --systohc
        echo -e "${GREEN}hwclock was set up!${RESET}"
        break
    elif [[ "$hclkcnf" == 'N' || "$hclkcnf" == 'n' ]]; then
        echo -e "${GREEN}Skipping hwclock setup...${RESET}"
        break
    elif [[ "$hclkcnf" == "whatisit" ]]; then
        echo -e "${YELLOW}When you start up your computer, the system clock is one of the first things to initialize. This clock is responsible for keeping track of the current time while your computer is running. However, your system clock isn't the only clock in your computer. There’s also a hardware clock, known as the Real-Time Clock (RTC), that’s built into the motherboard and continues running even when the system is powered off.

The hardware clock stores the time and date and ensures that your system time is accurate when you boot up, even if you don’t have an internet connection or if the system clock was reset. This is especially important for maintaining time when your computer is off or after a power failure.

In this setup, you have the option to sync your system clock with the hardware clock (or vice versa) using the hwclock tool. This ensures that your system clock is accurate from the moment you start your computer. The system clock and hardware clock can work together to keep your computer’s time in sync, which can help avoid issues with time-based tasks or logs.

You can choose whether to set up this synchronization in the next step. If you're unsure or just want to leave it as is, you can skip this part. However, if you prefer your hardware clock to be in sync with your system time, this option will ensure everything stays accurate across reboots.${RESET}"
          echo -e "${YELLOW}Press any key to return...${RESET}"
          read -n 1 -s
          continue
    fi
done



tvar=$(timedatectl)
echo -e"${YELLOW}Is this information accurate?${RESET}"
echo -e "${YELLOW}$tvar${RESET}"
echo -e -n "${YELLOW}(y/n): ${RESET}"
read accek
if [[ "$accek" == "Y" || "$accek" == "y" ]]; then
    echo -e "${GREEN}Great, time is all set now.${RESET}"
    sleep 2
elif [[ "$accek" == "n" || "$accek" == 'n' ]]; then
    echo -e "${YELLOW}Attempting to fix..${RESET}"
    sudo hwclock --hctosys
    echo -e "${YELLOW}Is it accurate now?${RESET}"
    echo "${YELLOW}$tvar${RESET}"
    echo -e -n "${YELLOW}(y/n)${RESET}"
    read accek2
    if [[ "$accek2" == 'Y' || "$accek2" == 'y' ]]; then
        echo -e "${GREEN}Great, time is all set now.${RESET}"
    elif [[ $accek2 == 'N' || "$accek2" == 'n' ]]; then
        echo -e "${RED}Apologies for the inconvenience, you will have to set the time up manually, but it isn't hard, so don't worry.${RESET}"
        while true; do
            echo -e "${YELLOW}Enter time manually (YYYY-MM-DD HH:MM:SS)"
        read tinp
        if [[ -n "$tinp" ]]; then
            sudo hwclock --set --date="$tinp"
            echo -e "${GREEN}Time set as $tinp!${RESET}"
            break
        else
            echo -e "${RED}ERROR: Invalid Input ${RESET}"
            continue
        done
        fi
    fi
fi

clear

echo -e "${GREEN}Configuring Localization${RESET}"
echo -e "${GREEN}Press any key to continue...${RESET}"
read -n 1 -s

echo -e "${YELLOW}Displaying available locales: ${RESET}"
sudo cat /etc/locale.gen | grep -i "UTF-8"

while true; do
    echo -e -n "${YELLOW}Enter locales to enable (comma separated): ${RESET}"
    read slcal
    if [[ -z "$slcal" ]]; then
        echo -e "${RED}ERROR: No locales selected. Please select at least one locale.${RESET}"
        sleep 1
        clear
        continue
    fi

    IFS=',' read -r -a locales <<< "$slcal"
    valid=true
    for locale in "${locales[@]}"; do
        locale=$(echo "$locale" | xargs)
        if ! grep -q "^#\s*$locale\s*" /etc/locale.gen; then
            echo -e "${RED}ERROR: Locale '$locale' is invalid or not found in /etc/locale.gen.${RESET}"
            valid=false
            break
        fi
    done

    if $valid; then
        break
    fi
done

for locale in "${locales[@]}"; do
    locale=$(echo "$locale" | xargs)  # Trim spaces
    sudo sed -i "s/^#\s*\($locale\s*\)/\1/" /etc/locale.gen
    echo -e "${GREEN}Enabled $locale in /etc/locale.gen${RESET}"
done

echo -e "${GREEN}Selected locales were enabled, press any key to generate locales...${RESET}"
read -n 1 -s
sudo locale-gen
echo -e "${GREEN}Locales were generated successfully!${RESET}"
sleep 3

clear
echo -e "${GREEN}Configuring Hostname${RESET}"
echo -e "${GREEN}Press any key to continue...${RESET}"
read -n 1 -s
echo -e -n "${YELLOW}What will be your hostname? ${RESET}"
read hostholder

echo "$hostholder" | sudo tee /etc/hostname > /dev/null
sudo sed -i "s/127.0.1.1\s.*$/127.0.1.1\t$hostname/" /etc/hosts

echo -e "${GREEN}$hostholder is now your hostname.${RESET}"

clear
echo "${GREEN}Network Configuration${RESET}"
echo ""
echo ""
echo ""
echo "${GREEN}Press any key to continue...${RESET}"
read -n 1 -s
sleep 1
echo "${YELLOW}Checkng your Network Connection..${RESET}"
ping -q -c 1 -W 2 "wiki.archlinux.org"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Network is not connected, trying different host..${RESET}"
    ping -q -c 1 -W 2 "github.com"
    if [[ $? -ne 0 ]]; then
        echo -e "${YELLOW}Note: Type skip to continue setup with no Wi-Fi connection."
        echo -e "${RED}Network is not connected, lets get you connected.${RESET}"
        echo -e -n "${YELLOW}What is your wireless interface name? ${RESET}"
        read wafai
        if [[ "$wafai" == "skip" ]]; then
            echo -e "${YELLOW}Skipping Network Configuration..${RESET}"
        sudo ip link set "$wafai"
        while true; do
            echo -e "${YELLOW}Scanning available Wi-Fi networks on your interface..${RESET}"
            scopt=$(sudo iwlist "$wafai" scanning | grep 'ESSID' | sed 's/ESSID://g')
            if [[ -z "$scopt" ]]; then
                echo -e "${RED}No networks were found, check your router and retry!${RESET}"
                echo -e "${RED}Press any button to retry...${RED}"
                read -n 1 -s
                continue
            fi

            echo -e "${GREEN}Wi-Fi Networks on $wafai: ${RESET}"
            ntlst=()
            index=1
            while IFS= read -r network; do
                echo "$index) $network"
                ntlst+=("$network")
                ((index++))
            done <<< "$scopt"

            echo -e "${YELLOW}NOTE: Type skip to continue setup with no Wi-Fi connection."

            echo -e "${YELLOW}Enter your Wi-Fi's number off the list.${RESET}"
            echo -e -n "Number: "
            read -r wislect

            if ! [[ "$wislect" =~ ^[0-9]+$ ]] || [ "$wislect" -lt 1 ] || [ "$wislect" -gt "${#ntlst[@]}" ]; then
                echo -e "${RED}ERROR: Unknown Wi-Fi selection.${RESET}"
                sleep 1
                continue
            elif [[ "$wislect" == "skip" ]]; then
                echo -e "${YELLOW}Skipping Network Configuration..${RESET}"
                sleep 1
                break

            selssid="${ntlst[$wislect]}"
            read -p "${YELLOW}Enter passphrase for $selssid: ${RESET}" -s pssp
            echo ""

            echo -e "network={
                ssid=\"$selssid\"
                psk=\"$pssp\"
            }" | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null


            echo -e "${GREEN}Connecting to $selssid..${RESET}"
            sudo wpa_cli reconfigure

            if sudo iw "$INTERFACE" link | grep -q "$selssid"; then
                echo -e "${GREEN}Connection successful!${RESET}"
                break
            else
                echo -e "${RED}Failed to connect to $selssid. Check your passphrase or router and retry..${RESET}"
                sleep 2
                continue
            fi
        done
    else
        echo "${GREEN}Connection is ensured!${RESET}"
        sleep 2
    fi
else
    echo "${GREEN}Connection is ensured!${RESET}"
    sleep 2
fi

while true; do
    echo "${YELLOW}What Network Manager do you want to utilize?${RESET}"
    echo -e "${GREEN}Network Managers:${RESET}"
    echo -e "${YELLOW}1) NetworkManager${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo -e "${YELLOW}2) dhclient${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo -e "${YELLOW}3) dhcpcd${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo -e "${YELLOW}4) ConnMan${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo -e "${YELLOW}5) netctl${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo -e "${YELLOW}6) systemd-networkd${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo -e "${YELLOW}7) iwd${RESET}"
    echo -e "${YELLOW}------------------${RESET}"
    echo ""
    echo -e "${YELLOW}NOTE: It is recommended to have only one Network Manager on the system.${RESET}"
    echo -e "${RED}WARNING: NetworkManager is REQUIRED to graphically manage Network on GNOME and KDE Plasma.${RESET}"
    echo ""
    echo ""
    echo -e -n "${GREEN}Pick your Network Manager: ${RESET}"
    read chnm

    if [[ "$chnm" -gt 7 || ! "$chnm" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}ERROR: Invalid Choice '$chnm'${RESET}"
        continue
    fi

    case $chnm in
        1)
            echo -e "${GREEN}Selection: NetworkManager, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}Installing NetworkManager..${RESET}"
                sudo pacman -S networkmanager --noconfirm >/dev/null 2>errlog
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
                    sleep 4
                    continue
                else
                    echo -e "${GREEN}Installed NetworkManager!${RESET}"
                    sleep 3
                    break
                fi
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting NetworkManager installation..${RESET}"
                sleep 1
                continue
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'.${RESET}"
                sleep 1
                continue
            fi
            ;;
        2)
            echo -e "${GREEN}Selection: dhclient, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}Installing dhclient..${RESET}"
                sudo pacman -S dhclient --noconfirm >/dev/null 2>errlog
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
                    sleep 4
                    continue
                else
                    echo -e "${GREEN}Installed dhclient!${RESET}"
                    sleep 3
                    break
                fi
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting dhclient installation..${RESET}"
                sleep 1
                continue
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'${RESET}"
                sleep 1
                continue
            fi
            ;;
        3)
            echo -e "${GREEN}Selection: dhcpcd, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}Installing dhcpcd..${RESET}"
                sudo pacman -S dhcpcd --noconfirm >/dev/null 2>errlog
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
                    sleep 4
                    continue
                else
                    echo -e "${GREEN}Installed dhcpcd!${RESET}"
                fi
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting dhcpcd installation..${RESET}"
                sleep 1
                continue
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'${RESET}"
                sleep 1
                continue
            fi
            ;;
        4)
            echo -e "${GREEN}Selection: ConnMan, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}Installing ConnMan..${RESET}"
                sudo pacman -S connman --noconfirm >/dev/null 2>errlog
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
                    sleep 4
                    continue
                else
                    echo -e "${GREEN}Installed ConnMan!${RESET}"
                    sleep 3
                    break
                fi
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting ConnMan installation..${RESET}"
                sleep 1
                continue
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'${RESET}"
                sleep 1
                continue
            fi
            ;;
        5)
            echo -e "${GREEN}Selection: netctl, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}Installing netctl..${RESET}"
                sudo pacman -S netctl --noconfirm >/dev/null 2>errlog
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
                    sleep 4
                    continue
                else
                    echo -e "${GREEN}Installed netctl!${RESET}"
                    sleep 3
                    break
                fi
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting netctl installation..${RESET}"
                sleep 1
                continue
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'${RESET}"
            fi
            ;;
        6)
            echo -e "${GREEN}Selection: systemd-networkd, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}systemd-networkd comes with the entire systemd service manager, so this can be installed later.${RESET}"
                sleep 5
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting..${RESET}"
                sleep 1
                continue
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'${RESET}"
            fi
            ;;
        7)
            echo -e "${GREEN}Selection: iwd, is this correct?${RESET}"
            read chnmcn
            if [[ "$chnmcn" == 'Y' || "$chnmcn" == 'y' ]]; then
                echo -e "${GREEN}Installing iwd..${RESET}"
                sudo pacman -S iwd --noconfirm >/dev/null 2>errlog
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}ERROR: Pacman has stopped working unexpectedly, check errlog file and send it to https://github.com/RBM-S/JOne/issues${RESET}"
                    sleep 4
                    continue
                else
                    echo -e "${GREEN}Installed iwd!${RESET}"
                    sleep 3
                    break
                fi
            elif [[ "$chnmcn" == 'N' || "$chnmcn" == 'n' ]]; then
                echo -e "${YELLOW}Aborting iwd installation..${RESET}"
            else
                echo -e "${RED}ERROR: Invalid choice '$chnmcn'${RESET}"
            fi
            ;;
        *)
            echo -e "${RED}ERROR: Invalid choice!${RESET}"
            ;;
    esac
done

clear

echo -e "${GREEN}Accounts Configuration${RESET}"
echo -e "${GREEN}Press any button to continue..${RESET}"
read -n 1 -s

while true; do
    echo -e "${GREEN}Root Password${RESET}"
    echo -e "${RED}WARNING: Memorize this root password, it is impossible to recover if you forget it.${RESET}"
    echo -e -n "${YELLOW}Write in your Root Password: ${RESET}"
    read -s rtps

    echo -e "$rtps\n$rtps" | passwd root
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Root password initialized successfully!${RESET}"
        break
else
    echo -e "${RED}ERROR: Failed to set root password, type in 1 to retry and 2 to skip.${RESET}"
    read rrosi
    if [[ "$rrosi" == 1 || "$rrosi" == "one" || "$rrosi" == "One" || "$rrosi" == "ONE" ]]; then
        continue
    elif [[ "$rrosi" == 2 || "$rrosi" == "two" || "$rrosi" == "Two" || "$rrosi" == "TWO" ]]; then
        break
    else
        echo -e "${RED}Invalid option '$rrosi', retrying by default.${RESET}"
        continue
    fi
done

echo ""
echo ""
echo ""
clear

while true; do
    echo -e "${GREEN}User Creation${RESET}"
    echo ""
    echo ""
    echo -e -n "${YELLOW}Enter a username for the user: ${RESET}"
    read usrn

    echo -e -n "${YELLOW}Do you want to set a password for $usrn? (Y/n): ${RESET}"
    read psswchc
    if [[ "$psswchc" == 'Y' || "$psswchc" == 'y' ]]; then
        echo -e -n "${YELLOW}Enter a password for $usrn: ${RESET}"
        read usrnpssd
        echo -e ""

        useradd -m -s /bin/bash "$usrn"
        echo -e "$usrnpssd\n$usrnpssd" | passwd "$usrn"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Successfully set a password for $usrn!${RESET}"
        else
            echo -e "${RED}ERROR: Failed to set password for $usrn.${RESET}"
            continue
        fi
    elif [[ "$psswchc" == 'N' || "$psswchc" == 'n' ]]; then
        echo -e "${RED}WARNING: No password was set for $usrn, which could expose your system to security vulnerabilities.${RESET}"
        echo -e "${GREEN}No password set for $usrn!${RESET}"
    else
        echo -e "${RED}ERROR: Invalid choice '$psswchc', no password was set.${RESET}"
        continue
    fi

    useradd -m -s /bin/bash "$usrn"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}$usrn was created successfully!${RESET}"
    else
        echo -e "${RED}ERROR: Failed to create $usrn, retrying in 5 seconds..${RESET}"
        sleep 5
        continue
    fi

    while true; do
        echo -e -n "${YELLOW}Do you want to add $usrn to the sudoers group? (Y/n): ${RESET}"
        read schc

        if [[ "$schc" == 'Y' || "$schc" == 'y' ]]; then
            sudo usermod -aG wheel "$usrn"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Added $usrn to the sudoers group, granting sudo permissions!${RESET}"
            else
                echo -e "${RED}ERROR: Failed to add $usrn to the sudoers group.${RESET}"
            fi
            break
        elif [[ "$schc" == 'N' || "$schc" == 'n' ]]; then
            echo -e "${GREEN}$usrn was not added to the sudoers group, therefore, they will not have sudo permissions.${RESET}"
            break
        else
            echo -e "${RED}ERROR: Invalid choice '$schc', please enter 'Y' or 'N'.${RESET}"
            continue
        fi
    done

    echo -e -n "${YELLOW}Do you want to create another user? (Y/n): ${RESET}"
    read create_another
    if [[ "$create_another" == 'N' || "$create_another" == 'n' ]]; then
        break
    fi
done

clear
echo -e "${GREEN}Sect 4: System Initialization${RESET}" > /dev/null 2>> /root/errlog
echo "" >> /root/errlog
echo "" >> /root/errlog
echo "" >> /root/errlog
while true; do
    echo -e "${GREEN}Installing Bootloader${RESET}" > /dev/null 2>> /root/errlog
    echo -e "" >> /root/errlog
    echo -e "" >> /root/errlog
    echo -e "${GREEN}Bootloaders: ${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}1) systemd-boot${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}2) GRUB${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}3) Limine${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}4) rEFInd (Does not support BIOS)" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}5) LILO (Discontinued, this is discouraged)" > /dev/null 2>> /root/errlog
    echo -e "" >> /root/errlog
    echo -e "" >> /root/errlog
    echo -e "${YELLOW}According to archlinux.org, UEFI bootloaders support Secure Boot, so you can have it on.${RESET}" > /dev/null 2>> /root/errlog
    echo -e -n "${YELLOW}Pick your Bootloader: " > /dev/null 2>> /root/errlog
    read botldchc

    case $botldchc in
        1)
             bootctl --path=/boot install > /dev/null 2>> /root/errlog
            echo -e "${GREEN}Systemd-boot installation completed!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        2)
            pacman -S grub efibootmgr os-prober --noconfirm > /dev/null 2>> /root/errlog
            grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB > /dev/null 2>> /root/errlog
            grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>> /root/errlog
            echo -e "${GREEN}GRUB installation completed!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        3)
            pacman -S limine --noconfirm > /dev/null 2>> /root/errlog
            limine-install > /dev/null 2>> /root/errlog
            echo -e "${GREEN}Limine installation completed!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        4)
            pacman -S refind --noconfirm > /dev/null 2>> /root/errlog
            refind-install > /dev/null 2>> /root/errlog
            echo -e "${GREEN}rEFInd installation completed!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        5)
            pacman -S lilo --noconfirm > /dev/null 2>> /root/errlog
        
            lilo -M /dev/sda mbr > /dev/null 2>> /root/errlog
            lilo > /dev/null 2>> /root/errlog
            echo -e "${GREEN}LILO installation completed! Please note that LILO is discontinued and discouraged for modern systems.${RESET}" > /dev/null 2>> /root/errlog
            ;;
        *)
            echo -e "${RED}Invalid choice, please select a valid bootloader option!${RESET}" > /dev/null 2>> /root/errlog
            continue
            ;;
    esac




clear
while true; do
    echo -e "${GREEN}Installing Minimal Desktop Environments and Packages${RESET}" > /dev/null 2>> /root/errlog
    echo "" >> /root/errlog
    echo "" >> /root/errlog
    echo -e "${YELLOW}1) GNOME (Minimal)${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}2) KDE Plasma (Minimal)${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}3) Cinnamon (Minimal)${RESET}" > /dev/null 2>> /root/errlog
    echo -e "${YELLOW}4) XFCE4 (Minimal)${RESET}" > /dev/null 2>> /root/errlog
    echo -e "" >> /root/errlog
    echo -e "" >> /root/errlog
    echo -e -n "${YELLOW}Choose your Environment: ${RESET}" > /dev/null 2>> /root/errlog
    read envchc

    case $envchc in
        1)
            pacman -S gnome gdm --noconfirm > /dev/null 2>> /root/errlog
            systemctl enable gdm.service --now > /dev/null 2>> /root/errlog
            echo -e "${GREEN}GNOME desktop environment installed successfully!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        2)
            pacman -S plasma sddm --noconfirm > /dev/null 2>> /root/errlog
            systemctl enable sddm.service --now > /dev/null 2>> /root/errlog
            echo -e "${GREEN}KDE Plasma desktop environment installed successfully!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        3)
            pacman -S cinnamon lightdm --noconfirm > /dev/null 2>> /root/errlog
            systemctl enable lightdm.service --now > /dev/null 2>> /root/errlog
            echo -e "${GREEN}Cinnamon desktop environment installed successfully!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        4)
            pacman -S xfce4 lightdm --noconfirm > /dev/null 2>> /root/errlog
            systemctl enable lightdm.service --now > /dev/null 2>> /root/errlog
            echo -e "${GREEN}XFCE4 desktop environment installed successfully!${RESET}" > /dev/null 2>> /root/errlog
            ;;
        *)
            echo -e "${RED}Invalid choice, please select a valid desktop environment option!${RESET}" > /dev/null 2>> /root/errlog
            continue
            ;;
    esac

done

echo -e "${GREEN}Applying Final Tweaks${RESET}"

joeinit() {
    local file=$1
    local search="Arch"
    local replace="JOne OS"
    
    if [ -f "$file" ]; then
        sudo sed -i "s/$search/$replace/g" "$file"
    fi
}

replace_arch "/etc/os-release"
sudo sed -i 's/ID=arch/ID=joneos/' /etc/os-release
sudo sed -i 's/PRETTY_NAME="Arch Linux"/PRETTY_NAME="JOne OS"/' /etc/os-release
sudo sed -i 's/VERSION=".*"/VERSION="JOne OS 1.0"/' /etc/os-release

replace_arch "/etc/issue"
echo "Welcome to JOne OS" | sudo tee /etc/issue > /dev/null

replace_arch "/etc/default/grub"
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
sudo sed -i 's/GRUB_DISTRIBUTOR="Arch"/GRUB_DISTRIBUTOR="JOne OS"/' /etc/default/grub



sudo grub-mkconfig -o /boot/grub/grub.cfg

sudo mkinitcpio -P

echo -e "${GREEN}Finished JOne OS Installation Setup! Rebooting in 15 seconds, you may reboot yourself by pressing CTRL+C and then typing in reboot or holding the power button and powering your PC on again.${RESET}"
sleep 15
reboot
