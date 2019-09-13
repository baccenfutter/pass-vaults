#!/bin/bash
# Script: Extension for password-store
# Description: support management of multiple password-stores
# Author: Brian Wiborg <brian.wiborg@bihealth.org>
# Date: 2019-09-12
# License: GNU/GPL-2.0
#
#
# Features
# ========
# 
# - support for managing multiple separate password-stores, called vaults.
# - vaults exist in distinct sub-directories of `~/.password-vaults/`.
# - the currently active vault is symlinked to `~/.password_store/`.
# - when activating another vault, the new vault is symlinked to
#   `~/.password-store`.
# - vaults can easily be created, renamed and destroyed
# - extensions are moved to `~/.password-vaults/.extensions` and then
#   automatically symlinked to all newly created vaults.
#
#
# Usage
# =====
# 
# - Type: `pass vault help` to view the usage information.
#
#
# Dependencies
# ============
#
# - pass-1.7.x (or later)
#
#
# Installation
# ============
#
# Type: make install
#
# or install it manually:
#
# ```
# mkdir ~/.password-store/.extensions
# cp vault.bash ~/.password-store/.extensions/
# chmod +x ~/.password-store/.extensions/vault.bash
# export PASSWORD_STORE_ENABLE_EXTENSIONS=true
# echo 'export PASSWORD_STORE_ENABLE_EXTENSIONS=true' >> ~/.bashrc
# ```
#

#####################
### CONFIGURATION ###
#####################

PASSWORD_STORE_DIR=~/.password-store
PASSWORD_STORE_VAULT_DIR=~/.password-vaults

###############
### GLOBALS ###
###############

VERS="0.1.0"
PROMPT_DELETE_ACTIVE="Only inactive vaults can be deleted! Please activate a different vault, first."
PROMPT_DELETE_RLY="Deleting a vault will permanently delete all secrets it contains!"
PROMPT_DELETE_RLY_RLY="Are you absolutely sure you want to delete the vault:"
PROMPT_INIT="vault-store not initialized! Try: 'pass vault init'"
PROMPT_INIT_NO_OVERWRITE="The directory ~/.password-vaults/ already exists, aborting!"
PROMPT_MV_ARG_MISSING='Please try: `pass vault mv <old-name> <new-name>`'
PROMPT_MV_ARG_TOO_MUCH="Please do not use spaces in your vault name!"
PROMPT_UNKNOWN_CMD="unknown command:"
PROMPT_VAULT_CREATED="Password vaults initialized."
PROMPT_VAULT_EXISTS="A vault has already been created with the name:"
PROMPT_VAULT_EXISTS_NOT="No vault has been created with the name:"
PROMPT_VAULT_NO_EMPTY_NAME="Please specify the vault's name!"
PROMPT_VAULT_SYMLINK_NOT_SYMLINK='Creating symlink `~/.password-store` would overwrite a real file, aborting!'
PROMPT_VERSION="
============================================
= Extension: vault                         =
= Multiple password-stores with ease!      =
=                                          =
=                  v$VERS                  =
=                                          =
=                Brian Wiborg              =
=          brian.wiborg@bihealth.org       =
=                                          =
=  https://github.com/baccenfutter/vault   =
============================================
"
PROMPT_USAGE="Usage:
    pass vault <name>
        Switch to the VAULT with the given name.
    pass vault [list]
        List all available VAULTS.
    pass vault init
        Initialize a new VAULT.
    pass vault add <name>
        Add a new VAULT with the given name.
    pass vault help
        Display usage information.
    pass vault version
        Display the version of the currently install VAULT extension.
"

###############
### HELPERS ###
###############

exit_ok() {
  echo "$@"
  exit 0
}

exit_err() {
  echo "Error:" "$@" >&2
  exit 1
}

is_vault_initialized() {
  stat "$PASSWORD_STORE_VAULT_DIR" &>/dev/null
}

extensions_folder_exists() {
  stat "$PASSWORD_STORE_VAULT_DIR/.extensions" &>/dev/null
}

vault_exists() {
  stat "$PASSWORD_STORE_VAULT_DIR/$1" &>/dev/null
}

symlink_extensions_to() {
  vault_name="$1"
	echo -n "ln: "
  ln -vs "$PASSWORD_STORE_VAULT_DIR/.extensions" "$PASSWORD_STORE_VAULT_DIR/$vault_name/.extensions"
}

activate_vault() {
  vault_name="$1"
  [[ -z "$vault_name" ]] && exit_err "$PROMPT_VAULT_NO_EMPTY_NAME"
  vault_dir="$PASSWORD_STORE_VAULT_DIR/$vault_name"
	if [[ -a "$PASSWORD_STORE_DIR" ]]; then
		[[ ! -L "$PASSWORD_STORE_DIR" ]] && exit_err "$PROMPT_VAULT_SYMLINK_NOT_SYMLINK"
		rm "$PASSWORD_STORE_DIR"
	fi
	echo -n "ln: "
  ln -sfv "$vault_dir" "$PASSWORD_STORE_DIR"
}

is_vault_active() {
  vault_dir="$1"
  if [[ "$(readlink -- "$PASSWORD_STORE_DIR")" == "$vault_dir" ]]; then
    return 0
  fi
  return 1
}

rly_rly_delete_prompt() {
	vault_name="$1"
	echo "$PROMPT_DELETE_RLY"
	echo -n "$PROMPT_DELETE_RLY_RLY" "$vault_name" "[y|N]"
	read -n 1 rly_delete
	echo
	[[ "$rly_delete" == "y" ]] || [[ $rly_delete == "Y" ]]
}

######################
### CORE FUNCTIONS ###
######################

cmd_init() {
  is_vault_initialized && exit_err "$PROMPT_INIT_NO_OVERWRITE"

  mkdir -v "$PASSWORD_STORE_VAULT_DIR"
  extensions_dir="$PASSWORD_STORE_DIR/.extensions"
  if stat "$extensions_dir" &>/dev/null; then
		echo -n "mv: "
    mv -v "$extensions_dir" "$PASSWORD_STORE_VAULT_DIR/"
  fi

	echo -n "mv: "
  mv -v "$PASSWORD_STORE_DIR" "$PASSWORD_STORE_VAULT_DIR/main"
  symlink_extensions_to main
  activate_vault main
	echo "$PROMPT_VAULT_CREATED"
}

cmd_add() {
  vault_name="$1"

  is_vault_initialized || exit_err "$PROMPT_INIT"
  [[ -z "$vault_name" ]] && exit_err "$PROMPT_VAULT_NO_EMPTY_NAME"
  vault_exists "$vault_name" && exit_err "$PROMPT_VAULT_EXISTS" "$vault_name"
  
  vault_dir="$PASSWORD_STORE_VAULT_DIR/$vault_name"
  gpg_id="$(head -n1 "$PASSWORD_STORE_DIR/.gpg-id")"
  PASSWORD_STORE_DIR="$vault_dir" pass init "$gpg_id"
  symlink_extensions_to "$vault_name"
  activate_vault "$vault_name"
}

cmd_list() {
  is_vault_initialized || exit_err "$PROMPT_INIT"

  echo "Vaults:"
  for vault in "$PASSWORD_STORE_VAULT_DIR"/*; do
    vault_name="$(basename "$vault")"
    active=" "
    is_vault_active "$vault" && active="*"
    echo "$active $vault_name"
  done
}

cmd_switch() {
  vault_name="$1"
  [[ -z "$vault_name" ]] && exit_err "$PROMPT_VAULT_NO_EMPTY_NAME" 
  vault_dir="$PASSWORD_STORE_VAULT_DIR/$vault_name"
  stat $vault_dir &>/dev/null || exit_err "$PROMPT_VAULT_EXISTS_NOT" "$vault_name"
  activate_vault "$vault_name"
}

cmd_mv() {
  old_name="$1"
  new_name="$2"
  ([[ -z "$old_name" ]] || [[ -z "$new_name" ]]) && exit_err "$PROMPT_MV_ARG_MISSING"
  src_dir="$PASSWORD_STORE_VAULT_DIR/$old_name"
  dest_dir="$PASSWORD_STORE_VAULT_DIR/$new_name"
	echo -n "mv: "
	mv -v "$src_dir" "$dest_dir"
	activate_vault "$new_name"
}

cmd_rm() {
	vault_name="$1"
	[[ -z "$vault_name" ]] && exit_err "$PROMPT_VAULT_NO_EMPTY_NAME"
	vault_dir="$PASSWORD_STORE_VAULT_DIR/$vault_name"
	is_vault_active "$vault_dir" && exit_err "$PROMPT_DELETE_ACTIVE"
	[[ ! -d "$vault_dir" ]] && exit_err "$PROMPT_VAULT_EXISTS_NOT" "$vault_name"
	rly_rly_delete_prompt "$vault_name" || exit_ok "Aborting."
	rm -rfv "$vault_dir"
}

###################
### COORDINATOR ###
###################

sub_command="$1"; shift
case "$sub_command" in
  i|init) cmd_init "$@";;
  a|add) cmd_add "$@";;
	m|mv|move) cmd_mv "$@";;
	r|d|rm|remove|del|delete) cmd_rm "$@";;
  ''|l|list) cmd_list "$@";;
  h|help)
    echo "$PROMPT_VERSION"
    exit_ok "$PROMPT_USAGE"
    ;;
  v|version) exit_ok "$PROMPT_VERSION";;
  *) cmd_switch "$sub_command";;
esac

##################
### ¯\_(ツ)_/¯ ###
##################

