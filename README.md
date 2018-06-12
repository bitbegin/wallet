# A Desktop Client for Ledger Nano S

# How to build the wallet from source
We assume Windows as the target platform in the following, but the steps are the same for every supported platform.

Locations used:
- ```R:\``` as the root of your storage location.
- ```R:\Rebol``` as the storage location of REBOL/View.
- ```R:\red``` as the storage location of the Red git repository.
- ```R:\wallet``` as the storage location of the Wallet git repository.

Steps to compile the Red wallet:
- Download and install git for your system: https://git-scm.com/downloads
- Download REBOL/View for your system and save it into a location of your choice: http://www.rebol.com/download-view.html. For Windows that would be http://www.rebol.com/downloads/v278/rebol-view-278-3-1.exe
- Clone the Red git repository of red: ```git clone https://github.com/red/red.git```
- Clone the Wallet git repository: ```git clone https://github.com/red/wallet.git```
- Open a terminal
- The command you will need to type is of the following form:  
```<location of the REBOL/View executable> +s <location of the red.r REBOL-script> -r -t <your cross-compilation target> -o <location of the generated binary file> <location of the wallet Red-script```  
In our case, that would be the following:  
```R:\Rebol\rebol-view-278-3-1.exe +s R:\red\red.r -r -t Windows -o R:\wallet\wallet R:\wallet\wallet.red```

A REBOL/View does pop up and close after compilation of the wallet has finished.
The produced binary, in our case ```R:\wallet\wallet.exe``` is a complete application. There is no installation, configuration files or registry entries needed or created. Just use it.
