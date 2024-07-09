#!/bin/sh
#
# Encrypts files before adding them to a git repo, 

cypher="aes-256-cbc"
first_arg="$1"

# prints help readout
print_help() {
  printf "Usage: gitcrypty [add/decrypt] (file)\n"
  printf "\tEncrypt/decrypt files before pushing to a git repository.\n\n"
  printf "\tadd\tEncrypts all files in the dir, then add its to the repo\n"
  printf "\tpull\tPulls changes, then decrypts all encrypted files within the repo\n"
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
        openssl "$cypher" -d -pbkdf2 -pass pass:"$GITCRYPTY" -in "$file" -out "$file".d
        if [ "$?" ]; then
          printf "File decryption successful\n"
          mv "$file".d "$file"
          enc="$file"
        else
          printf "Error: decryption of %s was unsuccessful, file unchanged\n" "$file"
        fi
      fi
      if ! [ "$enc" = "$file" ]; then
        printf "Skipping unencrypted file %s...\n" "$file"
      fi   
    fi
  done
  exit 0
}

git_pull() {
 git fetch 
 if ! [ $(git pull --rebase) = "Already up to date."]; then
   git_decrypt
 fi
}

git_add() {
  for file in *; do
    # ensures the file is actually writeable by the user before encrypting
    if [ -w "$file" ]; then
      printf "Encrypting %s...\n" "$file"
      openssl "$cypher" -e -pbkdf2 -pass pass:"$GITCRYPTY" -in "$file" -out "$file".e
      if [ "$?" ]; then
        printf "File encryption successful\n"
        mv "$file".e "$file"
        if ! [ "$?" ]; then
          printf "Error: unable to overwrite file, file unchanged\n"
          exit 1
        fi
        git add "$file"
        if [ "$?" ]; then
          printf "File added to git repo\n"
        fi
        exit 0
      else
        printf "Error: file encryption unsuccessful, file unchanged\n"
        exit 1
      fi
    else
      printf "Error: %s not a writeable file\n" "$file"
      exit 1
    fi
  done
  exit 0
}

main() {
  # Only runs if within a git repo
  # a more elegant method would allow use in other folders within the repo, maybe later
  if ! [ -d ".git" ]; then
    printf "Error: No git repository found, must be run from the root directory\n"
    exit 0
  fi

  case $first_arg in
    "pull")
      git_pull ;;
    "add")
      git_add ;;
    *)
      print_help ;;
  esac
}

main "$@"
