# gitcrypty

Requires openssl, encrypts files using the aes-256-cbc cipher before adding them to a git repository. Decrypts those files when pulling changes from the repository.   

Currently, the files are encrypted/decrypted with a password from an environment variable ```GITCRYPTY``` which is deemed good enough. Alternatively, a keyfile can be used by changing the ```openssl``` command within the script.    
   
### to install
First, read the ```install.sh``` file to see what it's doing to your system.   
Then, run the file with ```sh install.sh``` from within the same directory.    
The ```install.sh``` can be run a second time to remove the file from your ```$HOME/.local/bin```
   
```
Usage: gitcrypty [add/pull]
        Encrypt files before pushing to a git repository. Decrypt them after pulling.

        add     Encrypts all files in the dir, then adds them to the repo
        pull    Pulls changes, then decrypts all encrypted files within the dir
```
