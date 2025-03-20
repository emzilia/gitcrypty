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
			# head works by itself for plain ACII files but the grep pipe is necessary
			# for files that aren't, such as docx etc. grep errors get redirected to 
			# /dev/null (not great, but necessary to avoid redundant grep warnings about
			# parsing binary files
			if [ "$(head -c 6 "$file" | grep -v ''\x00'' 2>/dev/null)" = "Salted" ]; then
				printf "Decrypting %s...\n" "$file"
				eval "openssl "$cypher" -d -pbkdf2 -pass pass:"$GITCRYPTY" -in "$file" -out "$file.d""
				if [ "$?" ]; then
					printf "File decryption successful\n"
					mv "$file.d" "$file"
					enc="$file"
				else
					printf "Error: decryption of %s was unsuccessful, file unchanged\n" "$file"
				fi
			fi
                       if ! [ "$enc" = $file ]; then
			       printf "Skipping unencrypted file %s...\n" "$file"
		       fi   
		fi
	done
	exit 0
}

git_add() {
	if [ "$totalargs" -eq 2 ]; then
		if [ -f "$inputfile" ]; then
			printf "Encrypting %s...\n" "$inputfile"
			eval "openssl "$cypher" -e -pbkdf2 -pass pass:"$GITCRYPTY" -in "$inputfile" -out "$inputfile.e""
			if [ "$?" ]; then
				printf "File encryption successful\n"
				mv "$inputfile.e" "$inputfile"
				git add "$inputfile"
				exit 0
			else
				printf "Error: file encryption unsuccessful, file unchanged\n"
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
	printf "Error: No git repository found, must be run from the root\n"
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

