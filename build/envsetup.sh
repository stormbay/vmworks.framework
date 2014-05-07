function hmm() {
cat <<EOF
Invoke ". build/envsetup.sh" from your shell to add the following functions to your environment:
- lunch:   lunch <product_name>-<build_variant>
- croot:   Changes directory to the top of the tree.
- m:       Makes from the top of the tree.
- mm:      Builds all of the modules in the current directory, but not their dependencies.
- mmm:     Builds all of the modules in the supplied directories, but not their dependencies.
           To limit the modules being built use the syntax: mmm dir/:target1,target2.
- mma:     Builds all of the modules in the current directory, and their dependencies.
- mmma:    Builds all of the modules in the supplied directories, and their dependencies.
- cgrep:   Greps on all local C/C++ files.
- jgrep:   Greps on all local Java files.
- resgrep: Greps on all local res/*.xml files.
- godir:   Go to the directory containing a file.

Look at the source to view more functions. The complete list is:
EOF
    T=$(gettop)
    local A
    A=""
    for i in `cat $T/build/envsetup.sh | sed -n "/^function /s/function \([a-z_]*\).*/\1/p" | sort`; do
      A="$A $i"
    done
    echo $A
}

# Get the value of a build variable as an absolute path.
function get_abs_build_var()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    (\cd $T; CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
      make --no-print-directory -f build/core/config.mk dumpvar-abs-$1)
}

# Get the exact value of a build variable.
function get_build_var()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    (\cd $T; CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
      make --no-print-directory -f build/core/config.mk dumpvar-$1)
}

# check to see if the supplied product is one we can build
function check_product()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    CALLED_FROM_SETUP=true BUILD_SYSTEM=build/core \
        TARGET_PRODUCT=$1 \
        TARGET_BUILD_VARIANT= \
        TARGET_BUILD_TYPE= \
        get_build_var TARGET_DEVICE > /dev/null
    # hide successful answers, but allow the errors to show
}

VARIANT_CHOICES=(user userdebug eng)

# check to see if the supplied variant is valid
function check_variant()
{
    for v in ${VARIANT_CHOICES[@]}
    do
        if [ "$v" = "$1" ]
        then
            return 0
        fi
    done
    return 1
}

function setpaths()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return
    fi

    ##################################################################
    #                                                                #
    #              Read me before you modify this code               #
    #                                                                #
    #   This function sets VMWORKS_BUILD_PATHS to what it is adding  #
    #   to PATH, and the next time it is run, it removes that from   #
    #   PATH.  This is required so lunch can be run more than once   #
    #   and still have working paths.                                #
    #                                                                #
    ##################################################################

    # Note: on windows/cygwin, VMWORKS_BUILD_PATHS will contain spaces
    # due to "C:\Program Files" being in the path.

    # out with the old
    if [ -n "$VMWORKS_BUILD_PATHS" ] ; then
        export PATH=${PATH/$VMWORKS_BUILD_PATHS/}
    fi

    # and in with the new
    prebuiltdir=$(getprebuilt)
    gccprebuiltdir=$(get_abs_build_var VMWORKS_GCC_PREBUILTS)

    # defined in core/config.mk
    targetgccversion=$(get_build_var TARGET_GCC_VERSION)
    export TARGET_GCC_VERSION=$targetgccversion

    # The gcc toolchain does not exists for windows/cygwin. In this case, do not reference it.
    export VMWORKS_TOOLCHAIN=
    export VMWORKS_TOOLCHAIN_2ND_ARCH=
    local ARCH=$(get_build_var TARGET_ARCH)
    case $ARCH in
        arm) toolchaindir=arm/arm-linux-androideabi-$targetgccversion/bin
            ;;
        *)
            echo "Can't find toolchain for unknown architecture: $ARCH"
            toolchaindir=xxxxxxxxx
            ;;
    esac
    if [ -d "$gccprebuiltdir/$toolchaindir" ]; then
        export VMWORKS_TOOLCHAIN=$gccprebuiltdir/$toolchaindir
    fi

    if [ -d "$gccprebuiltdir/$toolchaindir2" ]; then
        export VMWORKS_TOOLCHAIN_2ND_ARCH=$gccprebuiltdir/$toolchaindir2
    fi

    unset VMWORKS_KERNEL_TOOLCHAIN_PATH
    case $ARCH in
        arm)
            # Legacy toolchain configuration used for ARM kernel compilation
            toolchaindir=arm/arm-none-linux-gnueabi-4.3.3/bin
            if [ -d "$gccprebuiltdir/$toolchaindir" ]; then
                 VMWORKS_KERNEL_TOOLCHAIN_PATH="$gccprebuiltdir/$toolchaindir"
                 export ARM_EABI_TOOLCHAIN=$VMWORKS_KERNEL_TOOLCHAIN_PATH
            fi
            ;;
        *)
            # No need to set ARM_EABI_TOOLCHAIN for other ARCHs
            ;;
    esac

    export VMWORKS_BUILD_PATHS=$(get_build_var VMWORKS_BUILD_PATHS):$VMWORKS_TOOLCHAIN:$VMWORKS_KERNEL_TOOLCHAIN_PATH:
    export PATH=$VMWORKS_BUILD_PATHS$PATH

    unset VMWORKS_PRODUCT_OUT
    export VMWORKS_PRODUCT_OUT=$(get_abs_build_var PRODUCT_OUT)
    export OUT=$VMWORKS_PRODUCT_OUT

    unset VMWORKS_HOST_OUT
    export VMWORKS_HOST_OUT=$(get_abs_build_var HOST_OUT)
}

function printconfig()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
        return
    fi
    get_build_var report_config
}

function set_stuff_for_environment()
{
    settitle
    setpaths
    set_sequence_number

    export VMWORKS_BUILD_TOP=$(gettop)
    # With this environment variable new GCC can apply colors to warnings/errors
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
}

function set_sequence_number()
{
    export BUILD_ENV_SEQUENCE_NUMBER=10
}

function settitle()
{
    if [ "$STAY_OFF_MY_LAWN" = "" ]; then
        local arch=$(gettargetarch)
        local product=$TARGET_PRODUCT
        local variant=$TARGET_BUILD_VARIANT

		export PROMPT_COMMAND="echo -ne \"\033]0;[${arch}-${product}-${variant}] ${USER}@${HOSTNAME}: ${PWD}\007\""
    fi
}

function addcompletions()
{
    local T dir f

    # Keep us from trying to run in something that isn't bash.
    if [ -z "${BASH_VERSION}" ]; then
        return
    fi

    # Keep us from trying to run in bash that's too old.
    if [ ${BASH_VERSINFO[0]} -lt 3 ]; then
        return
    fi

    dir="sdk/bash_completion"
    if [ -d ${dir} ]; then
        for f in `/bin/ls ${dir}/[a-z]*.bash 2> /dev/null`; do
            echo "including $f"
            . $f
        done
    fi
}

function choosetype()
{
    echo "Build type choices are:"
    echo "     1. release"
    echo "     2. debug"
    echo

    local DEFAULT_NUM DEFAULT_VALUE
    DEFAULT_NUM=1
    DEFAULT_VALUE=release

    export TARGET_BUILD_TYPE=
    local ANSWER
    while [ -z $TARGET_BUILD_TYPE ]
    do
        echo -n "Which would you like? ["$DEFAULT_NUM"] "
        if [ -z "$1" ] ; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi
        case $ANSWER in
        "")
            export TARGET_BUILD_TYPE=$DEFAULT_VALUE
            ;;
        1)
            export TARGET_BUILD_TYPE=release
            ;;
        release)
            export TARGET_BUILD_TYPE=release
            ;;
        2)
            export TARGET_BUILD_TYPE=debug
            ;;
        debug)
            export TARGET_BUILD_TYPE=debug
            ;;
        *)
            echo
            echo "I didn't understand your response.  Please try again."
            echo
            ;;
        esac
        if [ -n "$1" ] ; then
            break
        fi
    done

    set_stuff_for_environment
}

#
# This function isn't really right:  It chooses a TARGET_PRODUCT
# based on the list of boards.  Usually, that gets you something
# that kinda works with a generic product, but really, you should
# pick a product by name.
#
function chooseproduct()
{
    if [ "x$TARGET_PRODUCT" != x ] ; then
        default_value=$TARGET_PRODUCT
    else
        default_value=full
    fi

    export TARGET_PRODUCT=
    local ANSWER
    while [ -z "$TARGET_PRODUCT" ]
    do
        echo -n "Which product would you like? [$default_value] "
        if [ -z "$1" ] ; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ] ; then
            export TARGET_PRODUCT=$default_value
        else
            if check_product $ANSWER
            then
                export TARGET_PRODUCT=$ANSWER
            else
                echo "** Not a valid product: $ANSWER"
            fi
        fi
        if [ -n "$1" ] ; then
            break
        fi
    done

    set_stuff_for_environment
}

function choosevariant()
{
    echo "Variant choices are:"
    local index=1
    local v
    for v in ${VARIANT_CHOICES[@]}
    do
        # The product name is the name of the directory containing
        # the makefile we found, above.
        echo "     $index. $v"
        index=$(($index+1))
    done

    local default_value=eng
    local ANSWER

    export TARGET_BUILD_VARIANT=
    while [ -z "$TARGET_BUILD_VARIANT" ]
    do
        echo -n "Which would you like? [$default_value] "
        if [ -z "$1" ] ; then
            read ANSWER
        else
            echo $1
            ANSWER=$1
        fi

        if [ -z "$ANSWER" ] ; then
            export TARGET_BUILD_VARIANT=$default_value
        elif (echo -n $ANSWER | grep -q -e "^[0-9][0-9]*$") ; then
            if [ "$ANSWER" -le "${#VARIANT_CHOICES[@]}" ] ; then
                export TARGET_BUILD_VARIANT=${VARIANT_CHOICES[$(($ANSWER-1))]}
            fi
        else
            if check_variant $ANSWER
            then
                export TARGET_BUILD_VARIANT=$ANSWER
            else
                echo "** Not a valid variant: $ANSWER"
            fi
        fi
        if [ -n "$1" ] ; then
            break
        fi
    done
}

function choosecombo()
{
    choosetype $1

    echo
    echo
    chooseproduct $2

    echo
    echo
    choosevariant $3

    echo
    set_stuff_for_environment
    printconfig
}

# Clear this variable.  It will be built up again when the vendorsetup.sh
# files are included at the end of this file.
unset LUNCH_MENU_CHOICES
function add_lunch_combo()
{
    local new_combo=$1
    local c
    for c in ${LUNCH_MENU_CHOICES[@]} ; do
        if [ "$new_combo" = "$c" ] ; then
            return
        fi
    done
    LUNCH_MENU_CHOICES=(${LUNCH_MENU_CHOICES[@]} $new_combo)
}

function print_lunch_menu()
{
    local uname=$(uname)
    echo
    echo "You're building on" $uname
    echo
    echo "Lunch menu... pick a combo:"

    local i=1
    local choice
    for choice in ${LUNCH_MENU_CHOICES[@]}
    do
        echo "     $i. $choice"
        i=$(($i+1))
    done

    echo
}

function lunch()
{
    local answer

    if [ "$1" ] ; then
        answer=$1
    else
        print_lunch_menu
        echo -n "Which would you like? "
        read answer
    fi

    local selection=

    if [ -z "$answer" ]
    then
        echo
        echo "Invalid lunch combo: $answer"
        return 1
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$")
    then
        if [ $answer -le ${#LUNCH_MENU_CHOICES[@]} ]
        then
            selection=${LUNCH_MENU_CHOICES[$(($answer-1))]}
        fi
    elif (echo -n $answer | grep -q -e "^[^\-][^\-]*-[^\-][^\-]*$")
    then
        selection=$answer
    fi

    if [ -z "$selection" ]
    then
        echo
        echo "Invalid lunch combo: $answer"
        return 1
    fi

    local device=$(echo -n $selection | sed -e "s/^.*_//" -e "s/-.*$//")
    if [ -z $device ]
    then
        echo
        echo "** Don't have a device spec for: '$device'"
        echo "** Do you have the right product($product)?"
        device=
    fi
    export TARGET_DEVICE=$device

	local product=$(echo -n $selection | sed -e "s/_.*$//")
    check_product $product
    if [ $? -ne 0 ]
    then
        echo
        echo "** Don't have a product spec for: '$product'"
        echo "** Do you have the right repo manifest?"
        product=
    fi

	local variant=$(echo -n $selection | sed -e "s/^[^\-]*-//")
    check_variant $variant
    if [ $? -ne 0 ]
    then
        echo
        echo "** Invalid variant: '$variant'"
        echo "** Must be one of ${VARIANT_CHOICES[@]}"
        variant=
    fi

    if [ -z "$product" -o -z "$variant" ]
    then
        echo
        return 1
    fi

    export TARGET_PRODUCT=$product
    export TARGET_BUILD_VARIANT=$variant
    export TARGET_BUILD_TYPE=release

    echo

    set_stuff_for_environment
    printconfig
}

# Tab completion for lunch.
function _lunch()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    COMPREPLY=( $(compgen -W "${LUNCH_MENU_CHOICES[*]}" -- ${cur}) )
    return 0
}
complete -F _lunch lunch

function gettop
{
    local TOPFILE=build/core/envsetup.mk
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        echo $TOP
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                \cd ..
                T=`PWD= /bin/pwd -P`
            done
            \cd $HERE
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}

function m()
{
    local T=$(gettop)
    if [ "$T" ]; then
        make -C $T -f build/core/main.mk $@
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function findmakefile()
{
    TOPFILE=build/core/envsetup.mk
    local HERE=$PWD
	local M=$(get_build_var VMW_MAKEFILE_NAME)
    T=
    while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
        T=`PWD= /bin/pwd`
        if [ -f "$T/$M" ]; then
            echo $T/$M
            \cd $HERE
            return
        fi
        \cd ..
    done
    \cd $HERE
}

function mm()
{
    local T=$(gettop)
    # If we're sitting in the root of the build tree, just do a
    # normal make.
    if [ -f build/core/envsetup.mk -a -f Makefile ]; then
        make $@
    else
        # Find the closest $(VMW_MAKEIFLE_NAME) file.
        local M=$(findmakefile)
        local MODULES=
        local GET_INSTALL_PATH=
        local ARGS=
        # Remove the path to top as the makefilepath needs to be relative
        local M=`echo $M|sed 's:'$T'/::'`
        if [ ! "$T" ]; then
            echo "Couldn't locate the top of the tree.  Try setting TOP."
        elif [ ! "$M" ]; then
            echo "Couldn't locate a makefile from the current directory."
        else
            for ARG in $@; do
                case $ARG in
                  GET-INSTALL-PATH) GET_INSTALL_PATH=$ARG;;
                esac
            done
            if [ -n "$GET_INSTALL_PATH" ]; then
              MODULES=
              ARGS=GET-INSTALL-PATH
            else
              MODULES=all_modules
              ARGS=$@
            fi
            ONE_SHOT_MAKEFILE=$M make -C $T -f build/core/main.mk $MODULES $ARGS
        fi
    fi
}

function mmm()
{
    local T=$(gettop)
	local M=$(get_build_var VMW_MAKEFILE_NAME)
    if [ "$T" ]; then
        local MAKEFILE=
        local MODULES=
        local ARGS=
        local DIR TO_CHOP
        local GET_INSTALL_PATH=
        local DASH_ARGS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^-.*$/')
        local DIRS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^[^-].*$/')
        for DIR in $DIRS ; do
            MODULES=`echo $DIR | sed -n -e 's/.*:\(.*$\)/\1/p' | sed 's/,/ /'`
            if [ "$MODULES" = "" ]; then
                MODULES=all_modules
            fi
            DIR=`echo $DIR | sed -e 's/:.*//' -e 's:/$::'`
            if [ -f $DIR/$M ]; then
                local TO_CHOP=`(\cd -P -- $T && pwd -P) | wc -c | tr -d ' '`
                local TO_CHOP=`expr $TO_CHOP + 1`
                local START=`PWD= /bin/pwd`
                local MFILE=`echo $START | cut -c${TO_CHOP}-`
                if [ "$MFILE" = "" ] ; then
                    MFILE=$DIR/$M
                else
                    MFILE=$MFILE/$DIR/$M
                fi
                MAKEFILE="$MAKEFILE $MFILE"
            else
                case $DIR in
                  showcommands | snod | dist | incrementaljavac) ARGS="$ARGS $DIR";;
                  GET-INSTALL-PATH) GET_INSTALL_PATH=$DIR;;
                  *) echo "No $M in $DIR."; return 1;;
                esac
            fi
        done
        if [ -n "$GET_INSTALL_PATH" ]; then
          ARGS=$GET_INSTALL_PATH
          MODULES=
        fi
        ONE_SHOT_MAKEFILE="$MAKEFILE" make -C $T -f build/core/main.mk $DASH_ARGS $MODULES $ARGS
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function mma()
{
  local T=$(gettop)
  if [ -f build/core/envsetup.mk -a -f Makefile ]; then
    make $@
  else
    if [ ! "$T" ]; then
      echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
    local MY_PWD=`PWD= /bin/pwd|sed 's:'$T'/::'`
    make -C $T -f build/core/main.mk $@ all_modules BUILD_MODULES_IN_PATHS="$MY_PWD"
  fi
}

function mmma()
{
  local T=$(gettop)
  if [ "$T" ]; then
    local DASH_ARGS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^-.*$/')
    local DIRS=$(echo "$@" | awk -v RS=" " -v ORS=" " '/^[^-].*$/')
    local MY_PWD=`PWD= /bin/pwd`
    if [ "$MY_PWD" = "$T" ]; then
      MY_PWD=
    else
      MY_PWD=`echo $MY_PWD|sed 's:'$T'/::'`
    fi
    local DIR=
    local MODULE_PATHS=
    local ARGS=
    for DIR in $DIRS ; do
      if [ -d $DIR ]; then
        if [ "$MY_PWD" = "" ]; then
          MODULE_PATHS="$MODULE_PATHS $DIR"
        else
          MODULE_PATHS="$MODULE_PATHS $MY_PWD/$DIR"
        fi
      else
        case $DIR in
          showcommands | snod | dist | incrementaljavac) ARGS="$ARGS $DIR";;
          *) echo "Couldn't find directory $DIR"; return 1;;
        esac
      fi
    done
    make -C $T -f build/core/main.mk $DASH_ARGS $ARGS all_modules BUILD_MODULES_IN_PATHS="$MODULE_PATHS"
  else
    echo "Couldn't locate the top of the tree.  Try setting TOP."
  fi
}

function croot()
{
    T=$(gettop)
    if [ "$T" ]; then
        \cd $(gettop)
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function cproj()
{
    TOPFILE=build/core/envsetup.mk
    local HERE=$PWD
	local M=$(get_build_var VMW_MAKEFILE_NAME)
    T=
    while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
        T=$PWD
        if [ -f "$T/$M" ]; then
            \cd $T
            return
        fi
        \cd ..
    done
    \cd $HERE
    echo "can't find $M"
}

function sgrep()
{
	find . -name .repo -prune -o -name .git -prune -o  -type f -iregex '.*\.\(c\|h\|cpp\|S\|xml\|sh\|mk\)' -print0 | xargs -0 grep --color -n "$@"
}

function gettargetarch
{
    get_build_var TARGET_ARCH
}

function cgrep()
{
    find . -name .repo -prune -o -name .git -prune -o -name out -prune -o -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' \) -print0 | xargs -0 grep --color -n "$@"
}

function resgrep()
{
    for dir in `find . -name .repo -prune -o -name .git -prune -o -name out -prune -o -name res -type d`; do find $dir -type f -name '*\.xml' -print0 | xargs -0 grep --color -n "$@"; done;
}

function mgrep()
{
	find . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -regextype posix-egrep -iregex '(.*\/Makefile|.*\/Makefile\..*|.*\.make|.*\.mak|.*\.mk)' -type f -print0 | xargs -0 grep --color -n "$@"
}

function treegrep()
{
	find . -name .repo -prune -o -name .git -prune -o -regextype posix-egrep -iregex '.*\.(c|h|cpp|S|xml)' -type f -print0 | xargs -0 grep --color -n -i "$@"
}

function getprebuilt
{
    get_abs_build_var VMWORKS_PREBUILTS
}

function godir () {
    if [[ -z "$1" ]]; then
        echo "Usage: godir <regex>"
        return
    fi
    T=$(gettop)
    if [[ ! -f $T/filelist ]]; then
        echo -n "Creating index..."
        (\cd $T; find . -wholename ./out -prune -o -wholename ./.repo -prune -o -type f > filelist)
        echo " Done"
        echo ""
    fi
    local lines
    lines=($(\grep "$1" $T/filelist | sed -e 's/\/[^/]*$//' | sort | uniq))
    if [[ ${#lines[@]} = 0 ]]; then
        echo "Not found"
        return
    fi
    local pathname
    local choice
    if [[ ${#lines[@]} > 1 ]]; then
        while [[ -z "$pathname" ]]; do
            local index=1
            local line
            for line in ${lines[@]}; do
                printf "%6s %s\n" "[$index]" $line
                index=$(($index + 1))
            done
            echo
            echo -n "Select one: "
            unset choice
            read choice
            if [[ $choice -gt ${#lines[@]} || $choice -lt 1 ]]; then
                echo "Invalid choice"
                continue
            fi
            pathname=${lines[$(($choice-1))]}
        done
    else
        pathname=${lines[0]}
    fi
    \cd $T/$pathname
}

# Print colored exit condition
function pez {
    "$@"
    local retval=$?
    if [ $retval -ne 0 ]
    then
        echo -e "\e[0;31mFAILURE\e[00m"
    else
        echo -e "\e[0;32mSUCCESS\e[00m"
    fi
    return $retval
}

if [ "x$SHELL" != "x/bin/bash" ]; then
    case `ps -o command -p $$` in
        *bash*)
            ;;
        *)
            echo "WARNING: Only bash is supported, use of other shell would lead to erroneous results"
            ;;
    esac
fi

# Execute the contents of any productsetup.sh files we can find.
for f in `test -d platform && find platform -maxdepth 4 -name 'productsetup.sh' 2> /dev/null`
do
    echo "including $f"
    . $f
done
unset f

addcompletions

