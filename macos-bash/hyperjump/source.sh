# Set Up the Database if it does not exist yet
function _hyperjumpdatabase() {
    local dbdir="$HOME"/.local/lib
    local db="$dbdir"/hyperjumpdb
    local db_old="$HOME"/.hyperjumpdb
    if [[ ! -f "$db" ]]; then
        # Create ~/.local/lib directory if it fors not exists
        if [[ ! -d "$dbdir" ]]; then
            mkdir -p "$dbdir" >> /dev/null
        fi
        # If old DB exists, move it to the new location
        if [[ -f "$db_old" ]]; then
            mv "$db_old" "$db"
        else
            touch "$db"
            echo "home:$HOME" >> "$db"
        fi
    fi
    echo "$db"
}

# Jump Remamber - Adds a jump to the database
function jr() {
    local db=$(_hyperjumpdatabase)
    local wd=$(pwd)
    local nick=${wd##*/}
    local nick=${nick// /_}

    if grep -q "$wd$" "$db"; then
        echo "This directory is already added to the database. Run 'jf' to forget it."
    else
        if [[ -z "$1" ]]; then
            echo "We need a nickname for this directory. Use jr <name> or specify it now."
            read -p "[C]ancel, [U]se \"$nick\", Enter [N]ickname [C/U/N]: " -n 1 -e choice
            case "$choice" in
                "U" | "u" )
                    echo "We are going to use $nick as the nickname for this directory."
                    ;;
                "N" | "n" )
                    local nick=
                    while [[ "$nick" = "" ]]; do
                       read -p "Enter a Nickname for this Directory and Press [Enter]: " -e nick
                    done
                    ;;
                * )
                    echo "Nothing was added to the database. Quitting."
                    return
                    ;;
            esac
        else
            local nick=$1
        fi

        local nick=${nick// /_}

        if grep -q "^$nick:" "$db"; then
            echo "Oops, the nickname '$nick' is already in use :( Try again...."
        else
            echo "$nick:$wd" >> "$db"
            echo "Added $wd with Nickname \"$nick\" to the database."
        fi
    fi
}

# Jump Forget - Removes a jump location from the database
function jf() {
    local db=$(_hyperjumpdatabase)

    if [[ -z "$1" ]]; then
        local wd=$(pwd)
        if grep -q ":$wd$" "$db"; then
            local dbline=$(grep ":$wd$" "$db" | head -n 1)
            local nickname=${dbline%:*}
        else
            echo "This directory is not in the database!"
            return
        fi
    else
        local nickname=$1
        if grep -q "^$nickname:" "$db"; then
            local line=$(grep "^$nickname:" "$db" | head -n 1)
            local wd=${line#*:}
        else
            echo "This nickname is not in the database!"
            return
        fi
    fi

    echo "$nickname : $wd"
    read -p "Forget It? [Y/N]: " -n 1 -e choice
    case "$choice" in
        "Y" | "y" )
            local tempfile=$(mktemp -t "XXXjumpdb")
            grep -v ":$wd$" "$db" > "$tempfile"
            cat "$tempfile" > "$db"
            rm "$tempfile"
            echo "$nickname is forgotten!"
            ;;
        * )
            echo "Nothing was deleted from the database. Quitting."
            return
            ;;
    esac
}

# Jump to Nickname - Shows the Dialog Menu with all of the jumps in the db
function jj() {
    local db=$(_hyperjumpdatabase)
    local foundDialog=0

    # If no name on the prompt, than pop up the dialog, else use $1
    if [[ -z "$1" ]]; then
        if ! type dialog > /dev/null 2>&1; then
            # Dialog Utility NOT found, so show alternative
            echo Dialog utility NOT found. Install Dialog to get a nice menu of jump locations.
            echo List of Saved Locations:
            while read line
            do
                printf "    %-25s %s \n" "${line%:*}" "${line#*:}"
            done < <(cat "$db")
        else
            local foundDialog=1
            local list=""
            while read line
            do
                line="'${line%:*}' '${line#*:}' "
                list+=$line
            done < <(cat "$db")

            if [[ "$list" == "" ]]; then
                echo The HyperJump Database is Empty. Bookmark a directory with the jr command to get started.
            else
                local cmd="dialog --menu 'Where do you want to jump to?' 22 76 16 $list"
                local choice=$(eval "$cmd" 2>&1 >/dev/tty)
                clear
            fi
        fi
    else
        local choice=$1
    fi

    # Check if the Jump is legit, and jump
    if grep -q "^$choice:" "$db"; then
        local line=$(grep "^$choice:" "$db" | head -n 1)
        local target=${line#*:}
        echo Navigating to "$choice" at "$target"
        cd "$target"
        # Run Additional Commands If Specified
        local param
        for param in ${@:2}
        do
            if [[ ! -z "$param" && "$param" != "" ]]; then
                local cmd="$param ./"
                echo Running \"$cmd\" inside $choice
                eval "$cmd"
            fi
        done
    else
        if [[ -z "$choice" ]]; then
            # Do not show the message if Dialog was not found
            if [[ "$foundDialog" -eq 1 ]]; then
                echo "Jump Cancelled"
            fi
        else
            echo "Jump Nickname isn't in the Database"
        fi
    fi
}

# Autocomplete for Jump to Nickname
_jj() {
    local db=$(_hyperjumpdatabase)

    local list=""
    while read line
    do
        local list+=" ${line%:*}"
    done < <(cat "$db")

    local cur=${COMP_WORDS[COMP_CWORD]}
    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$list" -- "$cur") )
    else
        COMPREPLY=( $(compgen -c "$cur") )
    fi
}

_jr() {
    local wd=$(pwd)
    local nick=${wd##*/}
    local nick=${nick// /_}
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$nick" -- "$cur") )
}

if [[ -n "${ZSH_VERSION-}" ]]; then
    autoload -U +X bashcompinit && bashcompinit
fi

complete -F _jj jj
complete -F _jj jf
complete -F _jr jr
