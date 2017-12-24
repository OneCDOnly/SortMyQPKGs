![icon](images/sort-my-qpkgs-cs.png) 

## Description

**SortMyQPKGs** is an automatic sorter for installed QPKGs so they launch in a predetermined order when your NAS next boots-up. Certain packages need to launch sequentially (example: Qmono before QSonarr) but due to flaws in QNAP's QPKG installation / reintegration process, this may not occur. This package will help ensure these QPKGs are correctly ordered.

Every QPKG will fit into one of three possible groups:

1. **ALPHA** - must be launched *before* other packages and in a specific order (these are high-level apps like command interpreters, virtual environments and the like),
2. **OMEGA** - packages that should be launched *after* everything else and in a specific order,
3. **UNSPECIFIED** - the majority of QPKGs out there that are not explicitly named, but should be launched *after* ALPHA and *before* OMEGA packages. 

The order is hardcoded into this QPKG but can be modified on request by posting in this topic. Please advise of new QPKGs to add and where on the current lists the new package should be placed. Only packages that *must* be placed correctly should be requested.

## How to install

- Available in the [Qnapclub Store!](https://www.qnapclub.eu/index.php?act=detail&qpkg_id=508)

- [Click here](https://qnapclub.eu/index.php?act=howto) to see how to add the **Qnapclub Store** as an App Center repo in QTS.


## Notes

- When the sorter is installed, there's not much to see. Find the package icon and click the 'Open' button to display the current log file - any changes made to your package order will be shown here. Sorting is automatically performed during each NAS shutdown and when *this* package is installed. No need to run it manually.

- The current internal order preference list can be viewed with:

    /etc/init.d/sort-my-qpkgs.sh pref
