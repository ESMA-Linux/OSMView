#!/bin/bash

###################################################
# Variables                                       #
###################################################

export ES_WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"

export ES_VERSION_PROGRAM_FILE="$ES_ROOT_DIR/VERSION_PROGRAM"

export ES_TEMP_DIR="$ES_ROOT_DIR/temp"
export ES_CACHE_DIR="$ES_ROOT_DIR/cache"
export ES_WINE_DIR="$ES_ROOT_DIR/wine"
export ES_INSTALL_DIR="$ES_WINE_DIR/drive_c/Program Files/$ES_PROGRAM_NAME/"
export ES_SETTINGS_DIR="$ES_WINE_DIR/drive_c/users/$USER/Application Data/ESMA/$ES_PROGRAM_NAME/"    

###################################################
# Parts from winetricks. Winetricks authors, GPL2 #
###################################################
wt_parse_wget_progress()
{    
    # Parse a percentage, a size, and a time into $1, $2 and $3 then use them to create the output line.
    perl -p -e '$| = 1; s/^.* +([0-9]+%) +([0-9,.]+[GMKB]) +([0-9hms,.]+).*$/\1\n# Downloading... \2 (\3)/'
}

wt_wget_progress()
{
    if [ "$USE_ZENITY" != "" ]; then
	    # Usa a subshell so if the user clicks 'Cancel',
	    # the --auto-kill kills the subshell, not the current shell
	    (
	        wget "$@" 2>&1 |
	        wt_parse_wget_progress | \
	        zenity --progress --no-cancel --width 400 --title="$_W_title" --auto-kill --auto-close
	    )
	    err=$?
	    if test $err -gt 128
	    then
	        # 129 is 'killed by SIGHUP'
	        # Sadly, --auto-kill only applies to parent process,
	        # which was the subshell, not all the elements of the pipeline...
	        # have to go find and kill the wget.
	        # If we ran wget in the background, we could kill it more directly, perhaps...
	        if pid=`ps augxw | grep ."$_W_file" | grep -v grep | awk '{print $2}'`
	        then
		    echo User aborted download, killing wget
		    kill $pid
	        fi
	    fi
	    return $err
    else
        wget "$@"
    fi
}

wt_download()
{
	_W_url="$1"
	_W_file="$2"
	_W_title="$3"
	_W_checksum="$4"

	es_common_get_sha1sum "$_W_file"

    if [ "$ES_TEMPVAR_SHA1SUM"x != "$_W_checksum"x ] || [ "$_W_checksum" = "" ];
    then
        rm -r "$_W_file"
	    wt_wget_progress -O "$_W_file" -nd -c --read-timeout=300 --retry-connrefused "$_W_url"
    fi
}


###################################################
# Common function                                 #
###################################################

es_common_get_sha1sum()
{
    local FILE="$1"

    if [ -f "$FILE" ] || [ -h "$FILE" ]
    then
        ES_TEMPVAR_SHA1SUM=`sha1sum < "$FILE" | sed 's/(stdin)= //;s/ .*//'`
    else
        return
    fi
}


###################################################
# Wine helpers                                    #
###################################################

es_wine_createPrefix()
{
	WINEPREFIX="$ES_WINE_DIR" WINEARCH="win32" WINEDLLOVERRIDES="mscoree,mshtml=" wineboot
}

###################################################
# Winetricks helpers                              #
###################################################

es_winetricks_download()
{
	cd "$ES_TEMP_DIR"

	wt_download "$ES_WINETRICKS_URL" "$ES_TEMP_DIR/winetricks" "Downloading winetricks"
	chmod +x "$ES_TEMP_DIR/winetricks"
}

es_winetricks_ie7()
{
    cd "$ES_TEMP_DIR"

	wt_download "http://download.microsoft.com/download/3/8/8/38889DC1-848C-4BF2-8335-86C573AD86D9/IE7-WindowsXP-x86-enu.exe" "$HOME/.cache/winetricks/ie7/IE7-WindowsXP-x86-enu.exe" "Downloading IE7" "d39b89c360fbaa9706b5181ae4718100687a5326"

    if [ "$USE_ZENITY" != "" ]; then
        zenity --progress --no-cancel --pulsate --title="Installing IE7" &
        zpid=$!
    fi

	WINEPREFIX="$ES_WINE_DIR" "$ES_TEMP_DIR/winetricks" --force --optout --unattended ie7

    if [ "$USE_ZENITY" != "" ]; then
        kill $zpid
    fi
}



###################################################
# LibKasnerik helpers                             #
###################################################

#libkasnerik
es_libKasnerik_download()
{
	wt_download "$ES_LIBKASNERIK_URL" "$ES_CACHE_DIR/$ES_LIBKASNERIK_FILENAME" "Downloading LibKasnerik" "$ES_LIBKASNERIK_CHECKSUM"
}

es_libKasnerik_unpack()
{
	cd "$ES_TEMP_DIR"

    cp "$ES_CACHE_DIR/$ES_LIBKASNERIK_FILENAME" "$ES_TEMP_DIR/$ES_LIBKASNERIK_FILENAME"

	unzip -o "./$ES_LIBKASNERIK_FILENAME" -d lib
}

es_libKasnerik_copy()
{
	cd "$ES_TEMP_DIR"
	cp -R "./lib/." "$ES_INSTALL_DIR/"
}


###################################################
# Program helpers                                 #
###################################################

es_program_download()
{
	wt_download "$ES_PROGRAM_URL" "$ES_CACHE_DIR/$ES_PROGRAM_FILENAME" "Downloading $ES_PROGRAM_NAME" "$ES_PROGRAM_CHECKSUM"
}

es_program_unpack()
{
    cd "$ES_TEMP_DIR"

    cp "$ES_CACHE_DIR/$ES_PROGRAM_FILENAME" "$ES_TEMP_DIR/$ES_PROGRAM_FILENAME"

    filename=$(basename "$ES_PROGRAM_FILENAME")
    extension="${filename##*.}"

    if [ "$extension" == "zip" ]; then
        unzip -o "./$ES_PROGRAM_FILENAME" -d app
    elif [ "$extension" == "exe" ]; then
        innoextract "./$ES_PROGRAM_FILENAME"
    fi 
	
}

es_program_copy()
{
    cd "$ES_TEMP_DIR"

    mkdir -p "$ES_INSTALL_DIR"
	cp -R "./app/." "$ES_INSTALL_DIR"
}

es_program_bugfix()
{
    if [ -f "$ES_PROGRAM_BUGFIXFILE" ]; then
	    mkdir -p "$ES_SETTINGS_DIR/"
	    cp "$ES_PROGRAM_BUGFIXFILE" "$ES_SETTINGS_DIR/"
    fi
}


###################################################
# Version helpers                                 #
###################################################

es_version_checkInstalled()
{
    if [ -f "$ES_VERSION_PROGRAM_FILE" ];
    then
	    export ES_VERSION_INSTALLED=$(cat "$ES_VERSION_PROGRAM_FILE")
	else
        export ES_VERSION_INSTALLED="-1"
	fi
}

es_version_isUpdateNeeded()
{
    if [ $ES_VERSION_PROGRAM \> $ES_VERSION_INSTALLED ];
	then 
	    return 0
    else
        return 1
	fi
}

###################################################
# Directories helpers                             #
###################################################

es_directories_prepare()
{
	rm -rf "$ES_WINE_DIR/"
	rm -rf "$ES_TEMP_DIR/"

	mkdir -p "$ES_ROOT_DIR/"
	mkdir -p "$ES_CACHE_DIR/"
	mkdir -p "$ES_TEMP_DIR/"

}

es_directories_clean()
{
	rm -rf "$ES_TEMP_DIR/"
}


###################################################
# Installation helpers                            #
###################################################

es_installation()
{
	es_directories_prepare

	es_wine_createPrefix

	es_winetricks_download
    es_winetricks_ie7
    
	es_program_download
	es_program_unpack
    es_program_copy
    es_program_bugfix

	es_libKasnerik_download
	es_libKasnerik_unpack
    es_libKasnerik_copy

	es_directories_clean

	echo "$ES_VERSION_PROGRAM" > "$ES_VERSION_PROGRAM_FILE"
}
