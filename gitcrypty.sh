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
  for file in *.e; do
    if [ -f "$file" ]; then
      # head works by itself for plain ACII files but the grep pipe is necessary
      # for files that aren't, such as docx etc. grep errors get redirected to 
      # /dev/null (not great, but necessary to avoid redundant grep warnings about
      # parsing binary files with null bytes
      if [ "$(head -c 6 "$file" | grep -v ''\x00'' 2>/dev/null)" = "Salted" ]; then
        printf "Decrypting %s...\n" "$file"
        openssl "$cypher" -d -none -pbkdf2 -pass pass:"$GITCRYPTY" -in "$file" -out "$file".d
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

git_tar() {
  tar_file="$1"
  printf "Found dir, archiving now"
  if [ -w "$tar_file" ]; then
    tar -cf "$tar_file".tar "$tar_file"
    if [ "$?" ]; then
      printf "Archiving %s was successful\n" $1
    else
      printf "Archiving %s failed\n" $1
      exit 1
    fi
  fi
}

git_encrypt() {
  enc_file="$1"
  if [ -w "$enc_file" ]; then
    openssl "$cypher" -e -none -pbkdf2 -pass pass:"$GITCRYPTY" -in "$enc_file" -out "$enc_file".e
    if [ "$?" ]; then
      printf "Encryption of %s was successful\n" "$enc_file"
    else
      printf "Encryption of %s failed\n" "$enc_file"
      exit 1
    fi
  fi
}

git_add() {
  for file in *; do
    # if it's a directory, tar it before encryption 
    if [ -d "$file" ]; then
      git_tar "$file"
      git_encrypt "$file".tar
    else
      git_encrypt "$file"
    fi
    if [ -f "$file".e ]; then
      git add --dry-run "$file".e
      if [ "$?" ]; then
       git add "$file".e
       if [ "$?" ]; then
         printf "File %s was encrypted and added to the repo" "$file"
       else
         printf "File %s wasn't added to the repo" "$file"
       fi
      else
       printf "File %s wasn't added to the repo" "$file"
      fi
    elif [ -f "$file".tar.e ]; then
      git add --dry-run "$file".tar.e
      if [ "$?" ]; then
       git add "$file".tar.e
       if [ "$?" ]; then
         printf "File %s was encrypted and added to the repo" "$file"
       else
         printf "File %s wasn't added to the repo" "$file"
       fi
      else
       printf "File %s wasn't added to the repo" "$file"
      fi
    fi
  done
  exit 0
}

main() {
  # Only runs if within a git repo
  # a more elegant method would allow use in other folders within the repo, maybe later
  if ! [ -d ".git" ]; then
    printf "Error: No git repository found, must be run from the root directory\n"
    exit 1
  fi

  case $first_arg in
    "decrypt")
      git_decrypt ;;
    "pull")
      git_pull ;;
    "add")
      git_add ;;
    *)
      print_help ;;
  esac
}

main "$@"
