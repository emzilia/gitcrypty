#!/bin/sh

cypher="aes-256-cbc"
totalargs="$#"
inputfile="$2"

# prints help readout
print_help() {
	printf "Usage: gitcrypty [add/decrypt] (file)\n"
	printf "\tEncrypt/decrypt files before pushing to a git repository.\n\n"
	printf "\tadd\tEncrypts the file, then add its to the repo\n"
	printf "\tdecrypt\tDecrypts all encrypted files within the folder\n"
}

# tries to decrypt all files in the directory if the 2nd arg is 'decrypt'
git_decrypt() {
	for file in *; do
		if [ -f "$file" ]; then
			if [ "$(head -c 6 "$file")" = "Salted" ]; then
				printf "Decrypting %s...\n" "$file"
				eval "openssl $cypher -d -pbkdf2 -pass pass:$GITCRYPTY -in $file -out $file.d"
				mv "$file.d" "$file"
			fi
			printf "Skipping unencrypted file %s...\n" "$file"
		fi
	done
	exit 0
}

git_add() {
	if [ "$totalargs" -eq 2 ]; then
		if [ -f "$inputfile" ]; then
			printf "Encrypting file...\n"
			eval "openssl $cypher -e -pbkdf2 -pass pass:$GITCRYPTY -in $inputfile -out $inputfile.e"
			if [ "$?" ]; then
				mv "$inputfile.e" "$inputfile"
				git add --dry-run "$inputfile"
				exit 0
			else
				printf "Error: file encryption unsuccessful\n"
				exit 1
			fi
		else
			printf "Error: %s wasn't found in the working directory\n" "$inputfile"
			exit 1
		fi
	else
		printf "Error: no file specified\n"
		exit 1
	fi

}

# Only runs if within a git repo
# a more elegant method would allow use in other folders within the repo, maybe later
if ! [ -d ".git" ]; then
	printf "Error: No git repository found\n"
	exit 0
fi

case $1 in
	"decrypt")
		git_decrypt ;;
	"add")
		git_add ;;
	*)
		print_help ;;
esac

