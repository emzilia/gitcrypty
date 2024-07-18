# gitcrypty

Requires openssl, encrypts files using the aes-256-cbc cipher before adding them to a git repository. Decrypts those files when pulling changes from the repository.   
   
```
Usage: gitcrypty [add/pull]
        Encrypt files before pushing to a git repository. Decrypt them after pulling.

        add     Encrypts all files in the dir, then adds them to the repo
        pull    Pulls changes, then decrypts all encrypted files within the dir
```
