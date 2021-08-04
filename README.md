# Check OMT package language tags

This script can be used to check language tags in OMT packages (packed OmegaT projects).

## Requirements

-   A Debian-based operating system (because of two packages installed with `apt`, that the script can run on other platforms if you update the lines that check for and install those dependencies)
-   A terminal emulator (command line) running GNU bash.
-   An internet connection.

## Checks

The script will look for the following items:

-   A valid ETS or cApStAn target language code in the package name.
-   A valid OmergaT target language tag in the project settings that corresponds to the language code in the package name.
-   A valid OmergaT source language tag in the project settings that is a variant of `en` unless a different one is provided with argument `--source`.
-   Valid source and target language codes in source XLIFF files, that correspond to the project settings
-   Valid source and target language codes in TMX files, that correspond to the project settings

## How to run it

You can clone this repository in your machine, and then call the script like:

    bash check_omt_langtags.sh --input path/to/package.omt --convention PISA --region

In case of doubt, check the script's help:

    bash check_omt_langtags.sh --help

or write to [manuel.souto@capstan.be](manuel.souto@capstan.be).
