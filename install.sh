#!/bin/sh

script='gitcrypty.sh'
scriptpath="${HOME}/.local/bin/gitcrypty"

# If the script has been installed, remove it, otherwise copy it over
if [ -f "${scriptpath}" ]; then
	printf "Uninstalling gitcrypty script\n"
	rm "${scriptpath}"
	if [ ! -f "${scriptpath}" ]; then
		printf "Script successfully uninstalled!\n"
	else
		printf "Error: Uninstallation failed\n"
	fi
elif [ ! -f "${scriptpath}" ]; then
	printf "Installing gitcrypty script\n"
	cp "${script}" "${scriptpath}"
	if [ -f "${scriptpath}" ]; then
		printf "Script successfully installed!\n"
	else
		printf "Error: installation failed\n"
	fi
fi
