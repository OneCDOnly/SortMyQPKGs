![icon](images/sort-my-qpkgs.original.png)

## Description

**SortMyQPKGs** is an automated sorter for installed QPKGs to ensure they launch in correct sequence when your NAS next powers-up.

There are a few known packages need to launch sequentially (example: Qmono before QSonarr) but due to flaws in QNAP's package registration process, this may not occur.

This package will automatically ensure the launch-order of your other QPKGs is correct.

> [!IMPORTANT]
> SortMyQPKGs is no-longer effective on QTS 5.2.0 or-later, as these QTS versions have been modified to start QPKGs asynchronously. I can't force QTS to load QPKGs in a specific order anymore.
>
> QPKGs must now make use of the 'Dependency' key. This requires QPKG developers to name any other QPKGs their QPKG depends-on and to set this key post-install with the other QPKG names as the key value.
>
> If you're running QTS 5.2.0 or-later, you can uninstall SortMyQPKGs.

Every QPKG will fit into one of three possible groups:

1. **ALPHA** - must be launched *before* other packages, and in a specific order (these are high-level apps like command interpreters, virtual environments and the like),

2. **UNSPECIFIED** - the majority of QPKGs out there that are not explicitly named, but should be launched *after* ALPHA and *before* OMEGA packages,

3. **OMEGA** - packages that should be launched *after* everything else, and in a specific order. These are generally dependent on some other package.

The order is hardcoded into this QPKG but can be modified on request by posting in the [forum topic](https://forum.qnap.com/viewtopic.php?f=320&t=133132). Please advise of new QPKGs to add and where on the current lists the new package should be placed. Only packages that *must* be placed correctly should be requested.

This package was initially suggested by @father_mande & @zyxmon in [this thread](https://forum.qnap.com/viewtopic.php?f=351&t=130320), and is thanks to the research efforts of @zyxmon, @father_mande, myself and many other QNAP community members. Thank you to all who have contributed with feedback and suggestions.

## Installation

- Download the latest QPKG [here](https://github.com/OneCDOnly/SortMyQPKGs/releases/latest).

- Also available via [sherpa](https://github.com/OneCDOnly/sherpa).

- And it's in the [myQNAP repository](https://www.myqnap.org/product/sortmyqpkgs).

## Notes

- When the sorter is installed, there's not much to see. Find the package icon and click the 'Open' button to display the current log file - any changes made to your package order will be shown here. Sorting is automatically performed during each NAS shutdown. No need to run it manually.

- The log is viewable via your web browser but is not a real web document, so it can change without your browser noticing. Whenever viewing the log, ensure you force a page refresh: CTRL+F5.

- The current internal order preference list can be viewed with:

```
    /etc/init.d/sortmyqpkgs.sh pref
```

- [Changelog](changelog.txt)
