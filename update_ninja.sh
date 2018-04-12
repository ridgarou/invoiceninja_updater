#!/bin/bash -ue
#Invoice Ninja Self-Hosted Update
#PLEASE SEE THE README AT https://pastebin.com/nwcSH0TH

printf "*******************************************************************************\n"
printf '%s - Begin Invoice Ninja update.\n' "$(date)"

#SET INVOICE NINJA INSTALL AND STORAGE PATHS
#--------------------------------------------------------
sudo updatedb
ninja_home="/var/www/ninja" #$(locate -b '\composer.json' | xargs grep -l "invoiceninja/invoiceninja" | xargs -n 1 dirname)"
ninja_storage="$ninja_home/storage"


#GET INSTALLED AND CURRENT VERSION NUMBERS
#--------------------------------------------------------
versiontxt="$ninja_storage/version.txt"
ninja_installed="$(cat "$versiontxt")"

printf "*******************************************************************************\n"
printf '%s - Invoice Ninja v%s found installed.\n' "$(date)" "$ninja_installed"

ninja_current="$((wget -qO- https://invoiceninja.org/index.php) | (grep -oP 'Download Version \K[0-9]+\.[0-9]+(\.[0-9]+)'))"

printf "*******************************************************************************\n"
printf '%s - Invoice Ninja v%s found to download.\n' "$(date)" "$ninja_current"

#SEE IF AN UPDATE IS REQUIRED
#--------------------------------------------------------
update_required="no"
set -f
array_ninja_installed=(${ninja_installed//./ })
array_ninja_current=(${ninja_current//./ })

if (( ${#array_ninja_installed[@]} == "2" ))
then
    array_ninja_installed+=("0")
fi

for ((i=0; i<${#array_ninja_installed[@]}; i++))
do
    if (( ${array_ninja_installed[$i]} < ${array_ninja_current[$i]} ))
    then
    update_required="yes"
    fi
done


#MAIN UPDATE SECTION
#--------------------------------------------------------
case $update_required in
    no)
	printf "*******************************************************************************\n"
        printf '%s - No update required.\n' "$(date)" 
	printf "*******************************************************************************\n"
        ;;
    yes)
	printf "*******************************************************************************\n"
        printf '%s - Invoice Ninja will be updated from v%s to v%s.\n' "$(date)" "$ninja_installed" "$ninja_current"

        #Set remaining variables
        tempdir="/usr/local/download/InvoiceNinja"
        ninja_temp="$tempdir/ninja"
        ninja_file="ninja-v$ninja_current.zip"
        ninja_url="https://download.invoiceninja.com/$ninja_file"
        ninja_zip="$tempdir/$ninja_file"
        ninja_env="$ninja_home/.env"

        update_url="$(grep -oP '(?<=APP_URL=).*' "$ninja_env")""/update"

        storage_owner="$(stat -c "%U" "$ninja_storage")"
        storage_group="$(stat -c "%G" "$ninja_storage")"
		
	printf "*******************************************************************************\n"
        printf '%s - Deleting file "%s" (if it exists)...\n' "$(date)" "$ninja_home/bootstrap/cache/compiled.php"
        set +e
        sudo rm "$ninja_home/bootstrap/cache/compiled.php"
        set -e

	printf "*******************************************************************************\n"
        printf '%s - Downloading Invoice Ninja v%s archive "%s" ...\n\n' "$(date)" "$ninja_current" "$ninja_url"
        sudo wget -P "$tempdir/" "$ninja_url"

	printf "*******************************************************************************\n"
        printf '%s - Extracting to temporary folder "%s" ...\n' "$(date)" "$tempdir"
        sudo unzip -q "$ninja_zip" -d "$tempdir/"

	printf "*******************************************************************************\n"
        printf '%s - Syncing to install folder "%s" ...\n\n' "$(date)" "$ninja_home"
        sudo rsync -tr --stats "$ninja_temp/" "$ninja_home/"

	printf "*******************************************************************************\n"
        printf '%s - Resetting permissions for "%s" ...\n' "$(date)" "$ninja_storage"
        sudo chown -R "$storage_owner":"$storage_group" "$ninja_storage/"
        sudo chmod -R 775 "$ninja_storage/"

	printf "*******************************************************************************\n"
        printf '%s - Removing downloaded ZIP file "%s" ...\n' "$(date)" "$ninja_zip" 
		printf '%s - Removing temporary folder "%s" ...\n' "$(date)" "$tempdir"
        sudo rm -rf "$tempdir/"

	printf "*******************************************************************************\n"
        printf '%s - Running update migration commands (%s)...\n\n' "$(date)" "$update_url"
        case $(grep -c "UPDATE_SECRET" "$ninja_env") in
        0)
            wget -q --spider "$update_url"
            ;;
        1)
            update_key="$(grep -oP '(?<=UPDATE_SECRET=).*' "$ninja_env")"
            wget -q --spider "$update_url"?secret="$update_key"
            ;;
        esac

	printf "*******************************************************************************\n"
        printf '%s - Invoice Ninja successfully updated to v%s!\n\n' "$(date)" "$ninja_current"
	printf "*******************************************************************************\n"
        ;;
esac
