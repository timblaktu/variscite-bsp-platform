SHELL := bash
.EXPORT_ALL_VARIABLES:
.DEFAULT_GOAL := $(IMAGE)
.PHONY: clean clean_imported_submodules submodules $(IMAGE)

# Make variables 
#   - Simply-expanded: https://www.gnu.org/software/make/manual/html_node/Simple-Assignment.html
#   - Provide defaults; can be over-ridden at command line, e.g. 'make <target> VAR=foo
#   - Available to child processes in recipes because .EXPORT_ALL_VARIABLES
# makes common definitions available in child shell processes
BASH_ENV := bash.env
BUILD_DIR := build_xwayland
REPO_MANIFEST_URL := https://github.com/varigit/variscite-bsp-platform.git 
REPO_MANIFEST_BRANCH := mickledore 
REPO_MANIFEST_FILEPATH := imx-6.1.36-2.1.0.xml
IMAGE := fsl-image-gui

clean:  ## Delete all intermediate files and build output (does not affect bitbake dl/sstate caches)
	@recipehdr $@ $?
	@clean_super_project
	
clean_imported_submodules:  ## Remove all git submodules previously imported from a repo manifest
	@recipehdr $@ $?
	@clean_imported_submodules $(REPO_MANIFEST_URL) $(REPO_MANIFEST_BRANCH) $(REPO_MANIFEST_FILEPATH)
	
submodules:  ## Import and synchronize a git-repo tool xml manifest into the root git superproject
	@recipehdr $@ $?
	./import_submodules_from_repo_manifest $(REPO_MANIFEST_URL) $(REPO_MANIFEST_BRANCH) $(REPO_MANIFEST_FILEPATH)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(IMAGE): $(BUILD_DIR)  ## bitbake some IMAGE provided by the yocto meta-project
	@recipehdr $@ $?
	bitbake $(IMAGE)

help:  ## Displays this auto-generated usage message
	@./mkhelp $(MAKEFILE_LIST) 2>&1 
