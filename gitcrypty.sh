#!/bin/sh
#
# Encrypts files before adding them to a git repo, decrypts them when pulling them back.

# cipher protocol can be changed
cipher="AES-256-CBC"

# first parameter passed to the script
option="$1"

# prints help readout
print_help() {
  printf "Usage: gitcrypty [add/decrypt] (file)\n"
  printf "\tEncrypt/decrypt files before pushing to a git repository.\n\n"
  printf "\tadd\tEncrypts all files in the dir, then add its to the repo\n"
  printf "\tpull\tPulls changes, then decrypts all encrypted files within the repo\n"
}

# checks compatiblity of openssl installation
check_openssl() {
  # checks if openssl is installed on the system
  which openssl
  if [ "$?" ]; then
    # if openssl IS installed, checks if installation supports the aes-256-cbc cipher
    if ! [ "$(openssl ciphers | grep "$cipher")" ]; then
      printf "Error: %s protocol not supported by openssl installation\n" "$cipher"
      exit 1
    fi
  else
    printf "Error: openssl not found on system\n"
    exit 1
  fi
}


# tries to decrypt all files in the directory if the 2nd arg is 'decrypt'
git_decrypt() {
  for file in *.e; do
    original_name="${file%.e}"
    if [ -f "$file" ]; then
      # head works by itself for plain ACII files but the grep pipe is necessary
      # for files that aren't, such as docx etc. grep errors get redirected to 
      # /dev/null (not great, but necessary to avoid redundant grep warnings about
      # parsing binary files with null bytes
      if [ "$(head -c 6 "$file" | grep -v '\x00' 2>/dev/null)" = "Salted" ]; then
        printf "Decrypting %s...\n" "$file"
        openssl "$cipher" -d -pbkdf2 -pass pass:"$GITCRYPTY" -in "$file" -out "$file".d
        # if decryption is successful, remove the original file, otherwise the original
        # file is unchanged
        if [ "$?" ]; then
          printf "File decryption successful\n"
          mv "$file".d "$original_name"
          rm "$file"
        else
          printf "Error: decryption of %s was unsuccessful, file unchanged\n" "$file"
        fi
      fi
      # after decrypting, any tar files are then extracted
      case "$original_name" in
        *.tar)
          git_untar "$original_name" ;;
      esac
    fi
  done
  exit 0
}

# encrypts files passed to it if they're writeable, exits the script if not or
# if it fails
git_encrypt() {
  enc_file="$1"
  if [ -w "$enc_file" ]; then
    openssl "$cipher" -e -pbkdf2 -pass pass:"$GITCRYPTY" -in "$enc_file" -out "$enc_file".e
    if [ "$?" ]; then
      printf "Encryption of %s was successful\n" "$enc_file"
    else
      printf "Encryption of %s failed\n" "$enc_file"
      exit 1
    fi
  fi
}

# pulls + rebases repo, if there are any changes it decrypts all the files
git_pull() {
 git fetch 
 if ! [ "$(git pull --rebase)" = "Already up to date." ]; then
   git_decrypt
 fi
}

# if a dir is found and it's writeable, creates an archive of it and RECURSIVELY
# removes the original dir
git_tar() {
  tar_dir="$1"
  printf "Found dir %s, archiving now\n" "$tar_dir"
  if [ -w "$tar_dir" ]; then
    tar -cf "$tar_dir".tar "$tar_dir"
    if [ "$?" ]; then
      printf "Archiving %s was successful\n" "$tar_dir"
      # !!!!! works for me
      rm -r "$tar_dir"
    else
      printf "Archiving %s failed\n" "$tar_dir"
      exit 1
    fi
  fi
}

# if a tar file is found, extracts the contents and removes the tar file
git_untar() {
  untar_file="$1"
  printf "Found archive %s, extracting now\n" "$untar_file"
  tar -xf "$untar_file"
  if [ "$?" ]; then
    rm "$untar_file"
    printf "Archive %s extraction successful\n" "$untar_file"
  else
    printf "Archive %s extraction unsuccessful\n" "$untar_file"
    exit 1
  fi
}

# encrypts files (creating encrypted archives of directories) then adds them 
# to a git repo
git_add() {
  # ignore files that are already encrypted
  for file in *; do
    case "$file" in
      *.e)
        continue ;;
    esac
    # if it's a directory, tar it before encryption 
    if [ -d "$file" ]; then
      git_tar "$file"
      git_encrypt "$file".tar
    else
      git_encrypt "$file"
    fi
    # only git adds files with the .e suffix
    if [ -f "$file".e ]; then
      git add --dry-run "$file".e
      # if a dry run succeeds, do it for real
      if [ "$?" ]; then
        git add "$file".e
        # once the file is successfully added, remove the original
        if [ "$?" ]; then
          printf "File %s was encrypted and added to the repo\n" "$file"
          rm "$file"
        else
          printf "File %s wasn't added to the repo\n" "$file"
        fi
      else
        printf "File %s wasn't added to the repo\n" "$file"
      fi
    # otherwise only git adds files with the .tar.e suffix
    elif [ -f "$file".tar.e ]; then
      git add --dry-run "$file".tar.e
      # if a dry run succeeds, do it for real
      if [ "$?" ]; then
        git add "$file".tar.e
        # once the file is successfully added, remove the original
        if [ "$?" ]; then
          printf "File %s was encrypted and added to the repo\n" "$file"
          rm "$file".tar
        else
          printf "File %s wasn't added to the repo\n" "$file"
        fi
      else
        printf "File %s wasn't added to the repo\n" "$file"
      fi
    fi
  done
  exit 0
}

main() {
  # first checks openssl compatiblity
  check_openssl

  # Only runs if within a git repo
  # a more elegant method would allow use in other folders within the repo, maybe later
  if ! [ -d ".git" ]; then
    printf "Error: No git repository found, must be run from the root directory\n"
    exit 1
  fi

  # first script parameter determines function
  case $option in
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
