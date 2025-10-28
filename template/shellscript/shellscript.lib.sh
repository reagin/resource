#!/usr/bin/env bash

# name: shellscript.lib.sh
# author: reagin
# github: https://github.com/reagin/resource
# description: template file used to create shellscript library

# enable the following shell options:
# -E: ensure that err trap is also valid in function, subshell, and command replacements
# -e: when any command exits in a non-zero state, exit the script immediately
# -u: when using undefined variables, the script will report an error and exit
# -x: the command and its parameters will be printed when executing the command (for debugging)
# -o: pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuxo pipefail

export lib_command_dependency=() # CONFIG: commands appearing in script library
export lib_package_dependency=() # CONFIG: corresponding package name of the command

# -------------------------------------------------------------------
# function_name
#
# description:
#   description for function
#
# arguments:
#   $1 - argument 1 (e.g. "demo1")
#   $2 - argument 2 (e.g. "demo2")
#
# returns:
#   0 - success
#   1 - error
#
# usage:
#   function_name "demo1" "demo2"
# -------------------------------------------------------------------
# function_name() {
#   return 0
# }
