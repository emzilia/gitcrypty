#!/bin/sh

cypher="aes-256-cbc"
totalargs="$#"
inputfile="$2"

# only runs if within a git repo
# a more elegant method would allow use in other folders within the repo, maybe later
if ! [ -d ".git" ]; then
	printf "Error: No git repository found\n"
	exit 0
fi

# prints help readout
print_help() {
	printf "This is a help readout\n"
}

# tries to decrypt all files in the directory if the 2nd arg is 'decrypt'
git_decrypt() {
	for files in *; do
		if [ -f "$files" ]; then
			if [ "$(head -c 6 "$files")" = "Salted" ]; then
				printf "Decrypting $files...\n"
				`openssl $cypher -d -pbkdf2 -pass pass:$GITCRYPTY -in "$files" -out "$files.d"`
				mv "$files.d" "$files"
			fi
			printf "Skipping unencrypted file $files...\n"
		fi
	done
	exit 0
}

git_add() {
	if [ "$totalargs" -eq 2 ]; then
		if [ -f "$inputfile" ]; then
			printf "Encrypting file...\n"
			`openssl $cypher -e -pbkdf2 -pass pass:$GITCRYPTY -in "$inputfile" -out "$inputfile.e"`
			if [ "$?" ]; then
				mv "$inputfile.e" "$inputfile"
				git add --dry-run "$inputfile"
				printf "success?\n"
				exit 0
			else
				printf "Error: file encryption unsuccessful\n"
				exit 1
			fi
		else
			printf "Error: $inputfile wasn't found in the working directory\n"
			exit 1
		fi
	else
		printf "Error: no file specified\n"
		exit 1
	fi

}

case $1 in
	"decrypt")
		git_decrypt ;;
	"add")
		git_add ;;
	*)
		print_help ;;
esac

