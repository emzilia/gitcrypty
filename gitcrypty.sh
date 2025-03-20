#!/bin/sh
#
# Encrypts files before adding them to a git repo, 

cypher="aes-256-cbc"
total_args="$#"
first_arg="$1"
second_arg="$2"

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
      # parsing binary files with null bytes
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
  if [ "$total_args" -eq 2 ]; then
    # ensures the file is actually writeable by the user before encrypting
    if [ -w "$second_arg" ]; then
      printf "Encrypting %s...\n" "$second_arg"
      eval "openssl "$cypher" -e -pbkdf2 -pass pass:"$GITCRYPTY" -in "$second_arg" -out "$second_arg.e""
      if [ "$?" ]; then
        printf "File encryption successful\n"
        mv "$second_arg.e" "$second_arg"
        if ! [ "$?" ]; then
          printf "Error: unable to overwrite file, file unchanged\n"
          exit 1
        fi
        git add "$second_arg"
        if [ "$?" ]; then
          printf "File added to git repo\n"
        fi
        exit 0
      else
        printf "Error: file encryption unsuccessful, file unchanged\n"
        exit 1
      fi
    else
      printf "Error: %s wasn't found in the working directory\n" "$second_arg"
      exit 1
    fi
  else
    printf "Error: no file specified\n"
    exit 1
  fi
}

main() {
  # Only runs if within a git repo
  # a more elegant method would allow use in other folders within the repo, maybe later
  if ! [ -d ".git" ]; then
    printf "Error: No git repository found, must be run from the root directory\n"
    exit 0
  fi

  case $first_arg in
    "decrypt")
      git_decrypt ;;
    "add")
      git_add ;;
    *)
      print_help ;;
  esac
}

main "$@"
