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
    fi
done
