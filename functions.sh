shopt_was_set() {
    opts="$1"
    test "$-" != "${-#*"$opts"}"
}
shopt_was_set a && shopt_a_was_set=1
set -a

super_project_root_path() {
    git rev-parse --show-toplevel
}

assert_pwd_is_root() {
    # Validate we're in root path of repo working tree
    ROOT_DIR="$(super_project_root_path)"
    if [ "$ROOT_DIR" != "$(pwd)" ]; then
        echo "ERROR: pwd must be the root of the containing repository (expected $ROOT_DIR, got $(pwd))!"
        exit 1
    fi
}

repo_manifest_hash() {
    if [ $# -lt 1 ]; then
        printf "repo_manifest_hash: ERROR! REPO_MANIFEST_ABSFILEPATH argument is required!\n"
        return 1
    fi
    _REPO_MANIFEST_ABSFILEPATH="$1"; shift
    sha256sum "$_REPO_MANIFEST_ABSFILEPATH" | cut -d' ' -f 1
}

clean_imported_submodules() {
    if [ $# -lt 3 ]; then
        printf "clean_imported_submodules: ERROR! All 3 arguments are required!\n"
        printf "clean_imported_submodules:        REPO_MANIFEST_URL, REPO_MANIFEST_BRANCH, REPO_MANIFEST_FILEPATH\n"
        return 1
    fi
    _REPO_MANIFEST_URL="$1"; shift
    _REPO_MANIFEST_BRANCH="$1"; shift
    _REPO_MANIFEST_FILEPATH="$1"; shift

    cat << EOF
clean_imported_submodules:  Currently we assume there is only a single external superproject 
clean_imported_submodules:  being imported by repo manifest xml, to simplify operations that 
clean_imported_submodules:  require differentiating between imported submodules and any that 
clean_imported_submodules:  may exist in the local superproject. These simplification means
clean_imported_submodules:  that "imported submodules" always means "the ones specified in
clean_imported_submodules:  the single external superproject, which is defined by the constants:
clean_imported_submodules:  REPO_MANIFEST_URL REPO_MANIFEST_BRANCH REPO_MANIFEST_FILEPATH.
clean_imported_submodules:  
clean_imported_submodules:  This restriction could be easily lifted by tracking each external
clean_imported_submodules:  superproject's contents (submodules and links) under a unique
clean_imported_submodules:  directory, easily identifiable by the location specs (url,path,branch)
clean_imported_submodules:  of the manifest that originally created it.

EOF
    assert_pwd_is_root
    _RRD=.repo_manifest_repo_working_dir
    _RMP="$_RRD/$_REPO_MANIFEST_FILEPATH" 
    if [ ! -f "$_RMP" ]; then  # clean and clone repo manifest repo working dir
        rm -rf $_RRD  
        git clone --quiet --depth 1 --branch $_REPO_MANIFEST_BRANCH $_REPO_MANIFEST_URL $_RRD
    fi
    _REPO_MANIFEST_SUMMARY_FILE="imported-repo-manifest-summary-$(repo_manifest_hash $_RMP)"
    
    while read -r _NAME _PATH _URL _BRANCH _REV _LINKFILES; do
        git rm --force --ignore-unmatch "$_PATH" 2>/dev/null || true
        rm -rf "$_PATH" 2>/dev/null || true
        rm -rf .git/modules/"$_NAME" 2>/dev/null || true
        git config --remove-section submodule."$_NAME" 2>/dev/null || true
    done < $_REPO_MANIFEST_SUMMARY_FILE
    rm -rf $_RRD  
}

superproject_has_submodules() {
    test -n "$(git -C "$(super_project_root_path)" submodule)"
}

git_submodule_status_detailed() {
    # outputs single line for each submodule recorded in the .gitmodules index, as:
    #
    #    "$name" "$sm_path" "$displaypath" "$sha1" "$toplevel"'
    #
    assert_pwd_is_root
    if superproject_has_submodules; then
        HDRS="\
${BLUE}${UNDER}name${RESET},\
${BLUE}${UNDER}sm_path${RESET},\
${BLUE}${UNDER}displaypath${RESET},\
${BLUE}${UNDER}sha1${RESET},\
${BLUE}${UNDER}toplevel${RESET}"
        git -C "$(super_project_root_path)" submodule -q foreach 'echo "$name $sm_path $displaypath $sha1 $toplevel"' | column --table --output-width 120 --table-columns "$HDRS"
    fi
}

remove_all_submodules() {
    if ! superproject_has_submodules; then printf "no submodules to remove\n" && return; fi
    gslines="$(git_submodule_status_detailed)"
    printf "\n${RED}${gslines}${RESET}

${BOLD}${RED}WARNING!!${RESET}
${BOLD}${RED}WARNING!!${RESET}
${BOLD}${RED}WARNING!! Are you sure you want to delete all $(( $(echo "$gslines" | wc -l) - 1 )) of the superproject's submodules??${RESET} [yn] "
    read -n1 c && [[ "$c" != "y" ]] && echo " aborting" && return
    (
        echo; set -x; 
        git rm --force --ignore-unmatch sources/*;
        rm -rf sources/* .git/modules/*
        echo '' >.gitmodules
    )
}

clean_super_project() {
    ROOT_DIR="$(super_project_root_path)"
	rm -rf "${ROOT_DIR}"/"${BUILD_DIR}"
}

progress() {
    # Usage: 
    # 
    #     progress [INTERVAL_SECONDS] [CHAR_TO_PRINT] &
    #     PROGPID=$!
    #     # do stuff
    #     kill $PROGPID  # also trap 'kill $PROGPID' EXIT
    #     PROGPID=0
         
    _PROGRESS_INTERVAL_SEC="${1:-1}"
    _PROGRESS_CHAR="${2:-.}"
    while true; do 
        sleep $_PROGRESS_INTERVAL_SEC
        printf "$_PROGRESS_CHAR"
    done
}

recipehdr() {
    _RECIPEHDR="$1"; shift
    _TRIGGERSTRING="triggered by newer pre-reqs: ${GREEN}$*${RESET}"
    printf "\n${BLUE}============================================================================\n==>${RESET} Recipe ${YELLOW}${_RECIPEHDR}${RESET} ${TRIGGERSTRING} \n\n"
}

test -v shopt_a_was_set && set +a
