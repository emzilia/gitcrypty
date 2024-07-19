#!/bin/sh
#
# Encrypts files before adding them to a git repo, decrypts them when pulling them back.

# prints help readout
print_help() {
  printf "Usage: gitcrypty [add/pull]\n"
  printf "\tEncrypt files before pushing to a git repository. Decrypt them when pulling.\n\n"
  printf "\tadd\tEncrypts all files in the dir, then add them to the repo\n"
  printf "\tpull\tPulls changes, then decrypts all encrypted files within the dir\n"
}

# checks compatiblity of openssl installation with selected cipher
check_openssl() {
  # $1 is the name of the cipher
  cipher="$1"
  # checks if openssl is installed on the system
  command -v openssl >/dev/null 2>&1
  if [ "$?" ]; then
    # if openssl IS installed, checks if installation supports the selected cipher
    if ! openssl ciphers | grep -q "$cipher" ; then
      printf "Error: %s protocol not supported by openssl installation\n" "$cipher"
      exit 1
    fi
  else
    printf "Error: openssl not found on system\n"
    exit 1
  fi
}

# decrypts all files within the directory whose name ends with .e and whose content
# begins with the string "Salted"
git_decrypt() {
  for file in *.e; do
    # gets name of original file by removing the extension
    original_name="${file%.e}"
    if [ -f "$file" ]; then
      # head works by itself for plain ACII files but the grep pipe is necessary
      # for files that aren't, such as docx etc. grep errors get redirected to 
      # /dev/null (not great, but necessary to avoid redundant grep warnings about
      # parsing binary files with null bytes)
      if [ $(head -c 6 "$file" | grep -v '\x00' 2>/dev/null) = "Salted" ] ; then
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
  # $1 is the name of the file being looped through
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
 if ! git pull --rebase = "Already up to date." ; then
   git_decrypt
 fi
}

# if a dir is found and it's writeable, creates an archive of it and RECURSIVELY
# removes the original dir
git_tar() {
  # $1 is the name of the directory
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
  # $1 is the name of the tar archive
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
    # only git adds files with the .e or .tar.e extension
    if [ -f "$file".e ]; then
      enc_file="$file".e
    elif [ -f "$file".tar.e ]; then
      enc_file="$file".tar.e
    fi
    git add --dry-run "$enc_file"
    # if a dry run succeeds, do it for real
    if [ "$?" ]; then
      git add "$enc_file"
      # once the file is successfully added, remove the original
      if [ "$?" ]; then
        printf "File %s was encrypted and added to the repo\n" "$enc_file"
        case "$enc_file" in
          *.tar.e)
            rm "$file".tar ;;
          *.e)
            rm "$file" ;;
        esac
      else
        printf "File %s wasn't added to the repo\n" "$enc_file"
      fi
    else
      printf "File %s wasn't added to the repo\n" "$enc_file"
    fi
  done
  exit 0
}


main() {
  # first checks openssl compatiblity with selected cipher
  cipher="AES-256-CBC"
  check_openssl "$cipher"

  # only runs if within a git repo
  # a more elegant method would allow use in other folders within the repo, maybe later
  if ! [ -d ".git" ]; then
    printf "Error: No git repository found, must be run from the root directory\n"
    exit 1
  fi

  # first parameter passed to the script determines the function
  option="$1"
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
