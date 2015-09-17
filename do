#!/bin/bash

# this function read a commented data block inside this script
# @$1 : the name of the data block
# @echo : the content of the data block with the first '#' char removed at
#         each returned line
function read_data_block() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # this marker is used to mark the beginning of a data block
  local marker_begin='#<<<'

  # ths is the end marker of a data block
  local marker_end='#>>>'

  # the first argument of the function is the data block name
  local data_block_name=$1

  output_verbose 3 'data block to extract '$data_block_name

  # let's extract some data
  # the first sed command look for a data block name
  # the second sed command remove the first and the last line of the result and
  # remove the first # char of each line
  local read_command=$(\
cat << EOI
sed -n '/^${marker_begin}${data_block_name}\$/,/^${marker_end}\$/p'
  $script_file_name |
sed -n '1,1d;\$,\$d;s/^#//;p'
EOI
  )

  output_verbose 3 'sed command to read data : '$read_command

  # execute the sed commands. Using eval as string is multi line defined without
  # '\' usage
  eval $read_command

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# this function updates a commented data block inside this script
# $1 : the name of the data block
# $2 : the data to use to update the block
function update_data_block() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # this marker is used to mark the beginning of a data block
  local marker_begin='#<<<'

  # ths is the end marker of a data block
  local marker_end='#>>>'

  # the first argument of the function is the data block name
  local data_block_name=$1

  output_verbose 3 'data block to update : '$data_block_name

  # the second argument represents the data to use for the update. multi line
  # defined data are possible here; using "
  local data="$2"

  # data is not empty
  if (( ${#data} > 0 )); then
    # modify the data content to add a starting # at each line
    data=$(sed 's/^/#/' <<< "$data")

    # surrounds data with markers and data block name
    data=$(\
cat << EOI
${marker_begin}$data_block_name
$data
$marker_end
EOI
    )
  else
    # only use the markers and the data block name
    data=$(\
cat << EOI
${marker_begin}$data_block_name
$marker_end
EOI
    )
  fi

  # remove old data block if any
  local delete_command=$(\
cat << EOI
sed -i '' '/^${marker_begin}${data_block_name}\$/,/^$marker_end\$/d'
  $script_file_name
EOI
  )

  output_verbose 3 'delete command to run : '$delete_command
  eval $delete_command
  
  # adding data
  cat <<< "$data" >> $script_file_name

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to output text depending of the verbosity level. Output occurs
# on stderr
# @$1 verbosity level required to display the message
# @echo message to output, may be made of several words
function output_verbose {
  local required_verbosity=$1
  shift

  local message=$@

  if [[ $verbose_level -ge $required_verbosity ]]; then
    echo '/!\ '$required_verbosity' : '$message 1>&2
  fi
}

# function displaying help
# @echo the content of the help data block
function display_help() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  echo "$(read_data_block 'script help')"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to parse remaining options after the specified command
# options specified here can be context free such as the verbose_level option
# such as context related depending on the specified command
# $@ all remaining options specified after the command
function parse_options() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # browse all arguments
  for opt in $@; do
    output_verbose 3 'option read : '$opt

    # check the iterated argument with valid options
    if ! arg_matches_one_of $opt ${all_options[@]}; then
      output_verbose 1 'Invalid option used : '$opt
      output_verbose 3 'Valid options are : '${all_options[@]}

      return 1
    fi
  done

  # set a global variable with options passed as argument
  options=$@

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to parse the first argument passed to the script.
# $1 the command passed to the launch script
function parse_command() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # the passed command
  local input_command=$1
  input_command=${input_command:-help}

  # check if provided command is valid. Input command is used as a regex to
  # recognize in the valid commands list
  if ! arg_matches_one_of $input_command ${valid_commands[@]}; then
    output_verbose 1 'Invalid command specified : '$input_command
    output_verbose 3 'Valid command must one of these : '$valid_commands
    return 1
  fi

  # set a global variable when ok
  command=$input_command

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to parse arguments passed to this script
# $@ all arguments passed to the script
function parse_arguments() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  local input_command=$1

  output_verbose 3 'specified command : '$input_command

  # get out of here if failed in command parsing
  parse_command $input_command || return $?

  shift

  output_verbose 3 'specified option(s) : '$@

  # get out of here if failed in options parsing
  parse_options $@ || return $?

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function intended to extract the name of an option eventually prefixed by '-'
# or '--'.  if an option is made of 2 part (name=value...) only the left
# component of the option is extracted (in the case of name=value..., name will
# be returned
# $1 an option prefixed by '-' or '--' and eventually postfixed by a value part
# $echo the option name
function extract_option_name() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # remove the prefix made of - or --
  local without_prefix=$(sed -n -E 's/^-?-?//;p' <<< $1)

  # remove the possible value associated to the option. Value is declared after
  # a = char
  local name_only=$(sed -E 's/=.*//' <<< $without_prefix)

  echo $name_only

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to extract the value of an option made of 2 parts where the
# first part is the name of the option and the second part is the value assigned
# to this option. Such an option has the form --option=value...
# $1 an option
# $echo the value part of the option
function extract_option_value() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # remove the name associated with the value to make the option. Value is
  # declared after a = char
  local value_only=$(sed -E 's/^.*=//' <<< $1 )

  # should be one lined
  echo $value_only

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# this function is called to interactively configure the dev data block
function run_configure_dev() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # launch the interactive menu to configure the dev configuration data block
  run_configure_interactive 'custom dev configuration' \
                            "$(read_data_block 'custom dev configuration')"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# this function is called to interactively configure the external data block
function run_configure_external() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # launch the interactive menu to configure the dev configuration data block
  run_configure_interactive 'custom external configuration' \
                            "$(read_data_block 'custom external configuration')"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function showing the current configuration of the launcher
# $echo the custom dev configuration block
function run_configure_show() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # show the content of the custom dev configuration data block
  echo "$(read_data_block 'custom dev configuration')"

  # show the content of the custom external configuration data block
  echo "$(read_data_block 'custom external configuration')"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to reinitialize the configuration of the launcher
function run_configure_reset() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # reinitialize custome data block with empty value
  update_data_block 'custom dev configuration'
  update_data_block 'custom external configuration'
  update_data_block 'vim session data'

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# create an interactive menu allowing the user to specify the value of each
# option of the script configuration
# $1 the data block name
# $2 the data block containing variables to configure
function run_configure_interactive() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # the data block name
  local data_block_name="$1"

  # the data block content
  local data_block="$2"

  # this is the pattern of a variable assignation
  local variable_pattern='^[a-z_][0-9a-z_]*=.*$'

  # looping through the data block, each sed reducing the remaining data to
  # compute
  local remaining="$data_block"
  while (( ${#remaining} > 0 )); do
    # extract the description of the variable and the variable definition
    local variable_description=$(\
      sed -n '1,/'$variable_pattern'/p' <<< "$remaining")

    # extract the option assignation, this is the last line
    local variable_definition=$(sed -n '$,$p' <<< "$variable_description")

    # the variable name
    local variable_name=$(extract_option_name $variable_definition)

    # the variable value
    local variable_value=$(extract_option_value $variable_definition)

    # display the variable description, the comment lines and the definition
    echo "$variable_description"

    echo \
--------------------------------------------------------------------------------

    # read the user input for this variable
    local user_input=
    while [[ ( $user_input != k ) &&\
             ( $user_input != m ) &&\
	     ( $user_input != l ) ]]; do
      echo '(k)eep this value; (m)odify this value; (l)eave configuration'
      read -s -n 1 user_input
    done

    # user asks to keep the current value
    if [[ $user_input == k ]]; then
      echo '-->OK I keep this one!'
    fi

    if [[ $user_input == m ]]; then
      echo '-->Be nice and enter the new value for this one :'

      # who can more can less, register the value as an array
      read -a variable_value

      # if the value is an array, modify its text with parenthesises
      if [[ ${#variable_value[@]} > 0 ]]; then
        variable_value='('${variable_value[@]}')'
      # if the user enter nothing, don't touch the value
      else
        echo '-->OK I don''t touch this one!'
        echo \
--------------------------------------------------------------------------------

        # remove the block corresponding to the extracted data from the block
        remaining=$(sed '1,/'$variable_pattern'/d' <<< "$remaining")

	continue
      fi

      # modify the variable value at runtime
      eval $variable_name'='"$variable_value"
      
      echo '-->OK the new definition is '$variable_name="$variable_value"

      # before updating the value, I need to escape few chars for the
      # substitute operation in sed. Indeed, &, / and \ have special meaning
      # and have to be escaped in this order
      variable_value=$(sed 's/\&/\\\&/g' <<<\
        $(sed 's/\//\\\//g' <<<\
        $(sed 's/\\/\\\\/g' <<< "$variable_value")))

      # update the value in the extracted data block
      data_block=$(\
        sed 's/^'$variable_name'=.*$/'$variable_name'='"$variable_value"'/'\
            <<< "$data_block"\
      )
    fi

    # user asks to leave
    if [[ $user_input == l ]]; then
      echo '--> OK, bye.'
      break
    fi

    echo \
--------------------------------------------------------------------------------

    # remove the block corresponding to the extracted data from the block
    remaining=$(sed '1,/'$variable_pattern'/d' <<< "$remaining")
  done

  # configuration done, updating the data block with the new content
  update_data_block "$data_block_name" "$data_block"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to configure the script. Configuration can consist in :
# -show the current configuration of the script
# -interactively configure the script with new custom values for a data block
# -reset the configuration to its original state specified in data blocks
function run_configure() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # valid options that are specifically usable with the configure command
  # they are mutually exclusive, the first option encountered take the
  # precedence
  for opt in $options; do
    if arg_matches_one_of $opt ${configure_options[@]}; then
      # call to the run_configure-{show/reset} function
      run_configure_$(extract_option_name $opt) || return $?

      # after executing the specific function, get out of here
      output_verbose 3 'Exiting '$FUNCNAME' function...'
      return 0;
    fi
  done

  output_verbose 2 'No option specified, display the current configuration'
  # in case of no option specified, show the configuration
  run_configure_show

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used when the 'edit' command is passed as first argument. It intends
# to lauch the vim editor with a startup configuration and a potentially set
# session data
function run_edit() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # first, get the vim startup configuration
  local vim_configuration=$(\
    read_data_block 'vim startup configuration'
    )

  # and get the vim session data
  local vim_session=$(\
    read_data_block 'vim session data'
    )

  # the file in which vim will read and write its session data
  vim_session_file_name=$script_path/'.vim_session'

  # then, create a file with all stuff
  echo "$vim_configuration" > $vim_session_file_name
  echo "$vim_session" >> $vim_session_file_name

  # launch vim in a subshell in background. The subshell exits when vim exits
  # and, following commands are executed
  ( exec $vim_command -S $vim_session_file_name )

  # quicly erase the vim data file
  rm -f $vim_configuration_file_name

  # update the vim session data block
  vim_session_data="$(cat $vim_session_file_name)"
  update_data_block 'vim session data' "$vim_session_data"

  # quickly erase vim session data file
  rm -f $vim_session_file_name

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# utility function shifting an array that is global
# $1 the name of the array
# $@ elements of the array
function shift_args_in_global_array() {
  local array_name=$1

  if (( ${#@} > 1 )); then
    shift 2
    eval $array_name'=('$@')'
  else
    eval $array_name'='
  fi
}

# function designed to compile a unique file
# $1 ignored parameter
# $2 the file name to compile
function compile_file() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  local file=$2

  output_verbose 2 'Compiling '$file'...'

  # create the compilation command
  local compile_command=$cxx' '$generic_cxx_flags' -S '$file' -o /dev/null'

  output_verbose 3 $compile_command

  $compile_command

  # store the result of the compilation process
  local result=$?

  output_verbose 3 'Exiting '$FUNCNAME' function...'

  return $result
}

# function used to explore a directory to look for files depending of their
# extensions
# $1 the directory in which to look for files
# $2 the extension of file searched
# $3..@ a list of existing file names
# echo a list of file names
function append_files_from_in() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # meaningful alias
  local dir=$1

  # extension of files
  local ext=$2

  shift 2

  # constructed list of file names
  local files=$@

  # iterate through all objects in the directory
  for f in $dir/*; do
    # if directory found, recurse
    if [[ ( -f $f ) && ( $f =~ .*${ext} ) ]]; then
      files+=($f)
    # if file found, add to the list
    elif [ -d $f ]; then
      files=($(append_files_from_in $f $ext ${files[@]}))
    fi
  done

  # echoing the result
  echo ${files[@]}

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to compile the project
function run_compile() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # specific files the user want to be compiled
  local files=()

  # iterate through all options
  for opt in $options; do
    if arg_matches_one_of $opt ${generic_build_compile_options[@]}; then
      files=($(sed 's/,/ /g' <<< $(extract_option_value $opt)))
    fi
  done

  # if files have been specified, take these, otherwise, take all source files
  # that are in source directories
  if (( ${#files[@]} == 0 )); then
    output_verbose 3 'No files specified, compiling all in source directories'

    for dir in ${source_directories[@]};do
      files+=$(append_files_from_in $dir '.cpp' ${files[@]})
    done
  else
    output_verbose 3 'Specific file names detected'

    # verify if all files exist
    for file in ${files[@]}; do
      if [ ! -f $file ]; then
        output_verbose 1 'Error, file '$file' not found'
	return 1
      fi
    done
  fi

  # launch the compilation of files
  run_on_files 0 ${files[@]}

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function designed to build a unique file
# $1 the file name to compile
function build_file() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # flag indicating a build will be perform on the file even if it is up to date
  local overwrite=$1

  # the file to build
  local src_file=$2

  local output_obj_directory=$(\
    sed 's/\/+/\//g' <<<\
    ${output_directory}/${obj_dir_name}/${default_build_mode})

  # build the destination object file name
  local obj_file=$(\
    sed 's/\/+/\//g;s/\.cpp$/.o/' <<< ${output_obj_directory}/${src_file})
  mkdir -p $(dirname $obj_file)

  # determines complete flags depending of mode (debug or release)
  local cxx_flags=$generic_cxx_flags

  if [[ $default_build_mode == 'debug' ]]; then
    cxx_flags+=' '$debug_cxx_flags
  else
    cxx_flags+=' '$release_cxx_flags
  fi

  # create the compilation command
  local build_command=$cxx' '$cxx_flags' -c '$src_file' -o '$obj_file

  output_verbose 3 $build_command

  # the result of the build
  local result=

  if [[ $overwrite == 1 ]]; then
    $build_command

    # store the result of the build process
    result=$?
  else
    # get all dependencies associated to the source file
    local dep_command=$cxx' '$cxx_dep_flags' '$src_file
    local src_files=$(\
      sed 's/^.*:\ *//;s/\\//g' <<< $($dep_command))

    # age of src file and obj file
    local stat_src_file=0
    local stat_obj_file=0

    # get how old is the object file
    if [ -f $obj_file ]; then
      stat_obj_file=$($stat_command $obj_file)
    fi

    # default build message
    local build_msg=$obj_file' is up to date'

    for f in $src_files; do
      # if the object file is older than on of the dependancy, build it
      stat_src_file=$($stat_command $f)

      if [[ $stat_obj_file < $stat_src_file ]]; then
        build_msg='Building '$src_file'...'
        $build_command

        # store the result of the build process
        result=$?

	break
      fi
    done

    # build is not needed here
    output_verbose 2 $build_msg
  fi

  output_verbose 3 'Exiting '$FUNCNAME' function...'

  return $result
}

# function running something on a set of file names. The taks run depends on
# the command used
# $@ the list of file names
function run_on_files() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # flag indicating a file will be built even if it is up to date
  local overwrite=$1
  shift

  # meaningful alias
  files=($@)

  # user may have specified an array for this variable
  job_count=${job_count[0]}

  # check job count
  if [[ $job_count == 0 ]];then
    job_count=1
  fi

  output_verbose 1 'Starting '${command}' with '$job_count' jobs'

  # while files remain in the list...
  while (( ${#files[@]} > 0 )); do
    # in the particular case working with one job
    if (( $job_count == 1 )); then
      local file=${files[0]}
      shift_args_in_global_array 'files' ${files[@]}

      ${command}_file $overwrite $file || exit $?
      continue
    fi

    # multiple jobs running, check file list and job count
    while (( ( $(sed -n '$=' <<< "$(jobs)") < $job_count ) &&\
	     ( ${#files[@]} > 0 ) )); do
      local file=${files[0]}
      shift_args_in_global_array 'files' ${files[@]}

      # launch a parallel command, exit on fail
      ${command}_file $overwrite $file || exit $? &
    done
  done

  # wait my jobs!
  wait

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to link object files between us to get the binary
function run_link() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  output_verbose 1 'Starting linkage...'

  # create the name of the binary output with its directory
  local output_bin_directory=$(\
    sed 's/\/+/\//g' <<<\
    ${output_directory}/${bin_dir_name}/${default_build_mode})
  mkdir -p $output_bin_directory

  local bin_file=$(\
    sed 's/\/+/\//g' <<< ${output_bin_directory}/${program_name})

  # get all object files to be linked
  local input_obj_directory=$(\
    sed 's/\/+/\//g' <<<\
    ${output_directory}/${obj_dir_name}/${default_build_mode})

  local obj_files=()
  
  obj_files+=$(\
    append_files_from_in $input_obj_directory '.o' ${obj_files[@]})

  # determines complete flags depending of mode (debug or release)
  local cxx_flags=$generic_cxx_flags
  local ld_flags=$generic_ld_flags

  if [[ $default_build_mode == 'debug' ]]; then
    cxx_flags+=' '$debug_cxx_flags
    ld_flags+=' '$debug_ld_flags
  else
    cxx_flags+=' '$release_cxx_flags
    ld_flags+=' '$release_ld_flags
  fi

  local link_command=\
$cxx' -o '$bin_file' '$cxx_flags' '$ld_flags' '${obj_files[@]}

  # store the age of the binary file
  local bin_file_stat=0

  # age of the youngest object file
  local youngest_obj_file_stat=0

  # age of an obj file
  local obj_file_stat=0

  # store the age of the youngest object file
  for file in ${obj_files[@]}; do
    obj_file_stat=$($stat_command $file)

    # update the age of the youngest obj file if necessary
    if [[ $obj_file_stat > $youngest_obj_file_stat ]]; then
      youngest_obj_file_stat=$obj_file_stat
    fi
  done

  if [ -f $bin_file ]; then
    bin_file_stat=$($stat_command $bin_file)
  fi

  # default link message
  link_msg=$bin_file' is up to date'

  # perform the linkage if necessary
  if [[ $bin_file_stat < $youngest_obj_file_stat ]]; then
    link_msg='Linking '$bin_file'...'
    $link_command
  fi

  output_verbose 2 $link_msg

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function cleaning the obj directory
function clean_only_obj() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  output_verbose 1 'Cleaning object files...'

  local output_obj_directory=$(\
    sed 's/\/+/\//g' <<< ${output_directory}/${obj_dir_name})

  rm -rf $output_obj_directory

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function cleaning the bin directory
function clean_only_bin() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  output_verbose 1 'Cleaning binary files...'

  local output_bin_directory=$(\
    sed 's/\/+/\//g' <<< ${output_directory}/${bin_dir_name})

  rm -rf $output_bin_directory

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to perform a clean in obj and/or bin directories
function run_clean() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # iterate through all options, the first found take the precedence
  for opt in $options; do
    if arg_matches_one_of $opt ${clean_options[@]}; then
      clean_$(extract_option_name $opt)

      output_verbose 3 'Exiting '$FUNCNAME' function...'
      return 0
    fi
  done

  # no clean option specified, clean all
  clean_only_obj
  clean_only_bin

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# this function finish the vim configuration process by adding a vim command
# consisting to initialize a vim variable with the full path of this script
# @$1 the vim configuration data block
function finish_vim_configuration() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # get the vim startup configuration in argument
  local vim_configuration="$1"

  # remove the default assignation variable, replacing it with the full path of
  # this script
  vim_configuration=$(\
cat << EOI
let launch_script_directory='$script_path'
$(sed '1,1d' <<< "$vim_configuration")
EOI)

  # update the custom vim startup configuration data block
  update_data_block 'vim startup configuration' "$vim_configuration"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# internal function used to check and apply the content of a custom
# configuration data block. If no content exists, take one from a related
# default configuration data block to initialize the custom configuration data
# block
# $1 the custom data block name
# $2 the related default data block name
function apply_custom_data_block() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  local custom_data_block_name="$1"
  local default_data_block_name="$2"

  # read the custom data block
  local custom_data_block_content=$(\
    read_data_block "$custom_data_block_name"\
  )

  # if no custom configuration found, initialize it with default configuration
  if (( ${#custom_data_block_content} == 0 )); then
    # extract the default configuration
    local default_data_block_content=$(\
        read_data_block "$default_data_block_name"\
      )

    output_verbose 3 'setting up default configuration for ' \
                     "$custom_data_block_name"'...'

    # udpate or create the data block
    update_data_block "$custom_data_block_name"\
                      "$default_data_block_content"

    custom_data_block_content="$default_data_block_content"
  fi

  # now, 'source' data read from the custom configuration data block It defines
  # and initialize all variables
  eval "$custom_data_block_content"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# initialize all custom data block of the script if they are empty
function pre_init_with_default() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # check and apply dev configuration
  apply_custom_data_block 'custom external configuration'\
	  		  'external configuration'

  # check and apply external configuration
  apply_custom_data_block 'custom dev configuration'\
	  		  'dev configuration'

  output_verbose 3 'setting up startup vim configuration...'

  # extract the vim startup configuration
  local vim_startup_configuration=$(\
      read_data_block 'vim startup configuration'\
    )

  # now, change the vim variable assignation about the path of this script
  finish_vim_configuration "$vim_startup_configuration"

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function displaying help
function run_help() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # reading the help data block
  read_data_block 'help'

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to build the project or specific files that are specified in
# arguments
# This function will establish a complete file list that need to be rebuilt and
# pass this list in the run_rebuild function
# Moreover, if a file list is already specified here, the binary won'y be linked
function run_build() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # specific files the user want to be compiled
  local files=();

  # flag specifying a link won't be performed after a build
  local without_link=0

  # flag indicating that the build will occur even if the file is up to date
  local overwrite=0

  # iterate through all options
  for opt in $options; do
    if arg_matches_one_of $opt ${generic_build_compile_options[@]}; then
      if [[ $(extract_option_name $opt) == 'files' ]]; then
        files=($(sed 's/,/ /g' <<< $(extract_option_value $opt)))

        # specific files specified, no link
        without_link=1
      fi
    fi

    if arg_matches_one_of $opt ${specific_build_options[@]}; then
      # check for mode chosen
      if [[ $(extract_option_name $opt) == 'mode' ]]; then
        # redefine the target of the build
        default_build_mode=$(extract_option_value $opt)
      fi

      # check for --without_link option
      if [[ $(extract_option_name $opt) == 'without_link' ]]; then
        without_link=1
      fi

      # check for --overwrite option
      if [[ $(extract_option_name $opt) == 'overwrite' ]]; then
        overwrite=1
      fi
    fi
  done

  # if files have been specified, take these, otherwise, take all source files
  # that are in source directories
  if (( ${#files[@]} == 0 )); then
    output_verbose 3 'No files specified, \
	              rebuilding from all files in source directories'

    for dir in ${source_directories[@]}; do
      files+=$(append_files_from_in $dir '.cpp' ${files[@]})
    done
  else
    output_verbose 3 'Specific file names detected'

    # verify if all files exist
    for file in ${files[@]}; do
      if [ ! -f $file ]; then
        output_verbose 1 'Error, file '$file' not found'
	return 1
      fi
    done
  fi

  # launch the build of files
  run_on_files $overwrite ${files[@]}

  # perform a link to get the final binary file
  if [[ $without_link == 0 ]]; then
    run_link
  fi

  output_verbose 1 'Building complete'

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# Run the built binary after generating it if necessary
function run_run() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # first, the binary needs to be built
  command=build
  run_$command

  # after that, construct the line to execute
  local bin_file_path=${output_directory}/${bin_dir_name}/\
${default_build_mode}/${program_name}

  bin_file_path=$(sed 's/\/+/\//g' <<< $bin_file_path)

  # the command to execute
  local invoke_command=''

  # iterate through all options
  for opt in $options; do
    if arg_matches_one_of $opt ${run_options[@]}; then
      if [[ $(extract_option_name $opt) == 'with_debugger' ]]; then
        invoke_command+=$debugger' '
      fi
    fi
  done

  invoke_command+=$(echo ${run_command_left_args}\
                         ${bin_file_path}\
		         ${run_command_right_args})

  output_verbose 3 'Exiting '$FUNCNAME' function...'

  # bye bye...
  exec $invoke_command
}

# function used to pack the complete content of this script. The effect is to
# compress the content of the script, transform binary data into base64 format
# and append the result in a new script file that will be self extractible and
# will forward all of its arguments to its unpacked counterpart
function run_pack() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  # create the binary data from this script's content and add a '#' char at the
  # beginning of the data
  local commented_base64_data='#'$(xz -z9ec $script_file_name | base64 )
  local sfx_code_block=$(read_data_block 'sfx code')

  local packed_content=$(cat << EOI
$sfx_code_block
$commented_base64_data
EOI)

  output_verbose 3 'Exiting '$FUNCNAME' function...'

  # write sfx in itself, then exit
  echo "$packed_content" > $script_file_name && exit
}

# main function of this script
# $@ all arguments passed to the script
function run() {
  output_verbose 3 'Entering '$FUNCNAME' function...'
  output_verbose 3 'arguments : '$@

  output_verbose 3 'Lauching pre initialization...'

  # pre initialization with default value if needed
  pre_init_with_default

  output_verbose 3 'parsing arguments...'

  # parse arguments
  parse_arguments $@ || return $?

  # reporting execution flow
  output_verbose 2 'Executing script'
  output_verbose 2 'command : '$command
  output_verbose 2 'options : '$options

  output_verbose 3 'Running the specified command...'
  # run the command
  run_$command

  output_verbose 3 'Exiting '$FUNCNAME' function...'
}

# function used to know if a specific argument is matching one entry of a list
# of regexes
# $1 argument to check
# $2 array of regexes
# @return 0 if arg is matched, 1 otherwise
function arg_matches_one_of() {
  # the argument to test
  local arg=$1
  shift

  # remaining regexes
  local regexes=$@

  for regex in $regexes; do
    # test for the whole word
    if [[ $arg =~ (^| )$regex($| ) ]]; then
      return 0
    fi
  done

  # error if not returned from inside the loop
  return 1
}

# function intended to parse arguments passed to the script to configure its
# execution flow
# $@ all argument passed to the script
function configure_global_options() {
  # iterate through all arguments passed to the script
  for arg in $@; do
    # look for a verbose level option usage
    if arg_matches_one_of $arg ${verbose_level_options[@]}; then
      # create an array of value that separates the option name of the option
      # value
      local array=(${arg//=/ })

      # initialize the verbose level with the argument value
      verbose_level=${array[1]}
      continue
    fi;
  done
}

# evaluate the script absolute directory path and the script base name and store
# it in global variables
function evaluate_script_path_and_name() {
  # put directory on top of the stack, making a new current working directory
  pushd $(dirname $0) > /dev/null

  # get the absolute path of the script
  script_path=$(pwd -P)

  # restore the previous current working directory
  popd > /dev/null

  # get this script file name with absolute path used
  script_name=$(basename $0)
  script_file_name=$script_path/$(basename $0)
}

# script directory absolute path.
script_path=

# script base name
script_name=

# script absolute file name
script_file_name=

# indicate the command passed as first argument of the script. This command has
# been checked and is valid onece initialized
command=

# options (global or contextual) used with the command
options=

# flag indicating the verbose level of the execution flow
# 0 means no output, 1 means normal output, 2 means detailled output, 3 means
# full/debug output
verbose_level=1

# these are valid command that can be passed to the script as first argument
valid_commands=(\
  'help' 'configure' 'edit' 'compile' 'build' 'run' 'clean' 'pack')

# here are all the global options
verbose_level_options=('--verbose_level=[0-3]')

# aggregate of all global options
global_options=(\
 ${verbose_level_options[@]}\
)

# contextual options for configure command
# these options are used in the run_configure function
configure_options=('--show' '--reset' '--dev' '--external')

# generic contextual options for building and compiling
generic_build_compile_options=('--files=.*\.cpp')

# specific build options
specific_build_options=('--mode=(debug|release)' '--without_link' '--overwrite')

# clean options
clean_options=('--only_obj' '--only_bin')

# run options
run_options=('--with_debugger')

# group all options, global and contextual
all_options=(\
  ${verbose_level_options[@]}\
  ${configure_options[@]}\
  ${generic_build_compile_options[@]}\
  ${specific_build_options[@]}\
  ${run_options[@]}\
  ${clean_options[@]}\
)

# evaluate the script path and name
evaluate_script_path_and_name

# configure the flow of execution with global options such as --help
configure_global_options $@

# run th script
run $@

# return execution status of the last executed statement
exit $?

############################# data blocks section ##############################
#<<<help
# Usage :
# -------
# Elements inside '<>' are mandatory and elements inside '[]' are optionals.
#
# <directory>/do [command] [related to command switches] [global switches]
#
# Examples :
# ----------
# Considering the user's current directory contains the 'do' script :
#
# ./do      +-------------------------------------------------------------------
# ./do help |Invoke the 'do' script and display this help message. Moreover,
# __________|create a custom configuration generated from the default one.
#
# ./do configure            +---------------------------------------------------
# ./do configure --show     |Uses the configuration toolset of 'do' to see
# ./do configure --dev      |the current configuration, modify it or reset it.
# ./do configure --external |If you ask to look at the current configuration and
# ./do configure --reset    |it doesn't exist yet, it is created from the default
# __________________________|one provided with 'do'. using the '--dev' switch
# causes the user to enter in an interactive menu allowing the configuration of
# the development environment. Try it yourself to know more about that.
#
# ./do edit +-------------------------------------------------------------------
# __________|This command allow editing of your project through vim editor. You
# need vim V7.4 or greater in order to use this feature. This command allow you
# to keep track of your editing session in order to restore it the next time
# you invoke 'do' with the edit command.
#
# ./do compile                       +-------------------------------------------
# ./do compile --files=f1.cpp,f2.cpp |This command launch a compilation process
# ___________________________________|on all source files of your project if the
# '--files' switch is not used. If the switch is used, only specified files are
# compiled. Files have to be separated by a comma and have the .cpp extension.
#
# ./do build                        +-------------------------------------------
# ./do build --files=f1.cpp,f2.cpp  |This command build your current project. If
# ./do build --mode=(debug|release) |specified without any switch, the build will
# ./do build --without_link         |be incremental (only source files that need
# ./do build --overwrite            |to be built will be built) and the default
# __________________________________|build mode specified in the configuration
# will be used. If files are specified with the '--files' switch, only these
# files will be built, incrementally, and no link will be performed. If
# '--mode' switch is used, its value will be used to override the default build
# configuration specified in the development environment configuration (see
# 'configure' command used with '--dev' switch). If '--without_link' switch is
# specified, object files will be generated from source files, incrementally,
# but the link process won't be performed. Finally, if '--overwrite' switch is
# used, object files will be re-generated even if the related source file is
# older than the previous destination object file.
#
# ./do run                 +-----------------------------------------------------
# ./do run --with_debugger |This command allow the user to run the result of the
# _________________________|building of this project. This command is closely
# related to the 'build' command. Indeed, if 'do' consider that your project
# need a rebuild for 'run' command to execute properly, it will act like if you
# invoked 'do' with the 'build' command before to start running your project.
# If the '--with_debugger' switch is used, it will invoke the debugger
# specified in the development environment option attached to the binary built
# from your project's source files.
#
# ./do clean            +-------------------------------------------------------
# ./do clean --only_obj |This command clean the binary files built from your
# ./do clean --only_bin |project's source files. If this command is used without
# ______________________|any related switches, it will delete all object files
# and the generated executable file if they exist. If '--only_obj' switch is
# used, only object files will be deleted. If '--only_bin' switch is specified,
# on the final binary executable file will be deleted.
#
# ./do pack +-------------------------------------------------------------------
# __________|This command, when used, compress the 'do' script and transform it
# into a self-extractible script. After this command executed, your 'do' script
# will be drastically smaller than before. Moreover, all commands and switches
# will be usable in this compress form and invoking the script in its
# compressed form will automatically uncompress it. Try it, just for fun :)
#>>>
#<<<dev configuration
## This is the script consfiguration for development tools. These variables are
## used to configure the behavior of tools that are responsible of the
## project binary generation
#
## Indicates the sources directories that are scanned to compile or build the
## current project. If more than 1 directory is specified, you have to separate
## them with a space.
#source_directories=./src
#
## This is the root directory used for output files. If this directory name
## contains space, you have to surround it with quotes
#output_directory=.
#
## This is the name of the directory that will receive object files after their
## generation. the variable $output_directory will be used to construct the full
## object file directory path
#obj_dir_name=obj
#
## This is the name of the directory that will receive binary files after their
## linkage. the variable $output_directory will be used to construct the full
## binary file directory path
#bin_dir_name=bin
#
## This is the default build mode that is used if not any mode is explicitly
## specified while a generation is lauched. Correct values are 'debug' and
## 'release'. If an incorrect value is specified, 'debug' will be taken as
## default
#default_build_mode=debug
#
## This is the number of build jobs that are launched in parallel. The more, the
## quicker but take care not to have a job count greater than your current
## physical thread of your CPU
#job_count=1
#
## This is the name of the output binary after the build and the linkage are
## successfull
#program_name=program
#
## This is the text used to decorate the invocation of the binary. For example,
## you could use time to measure time taken by the program to execute
#run_command_left_args=
#
## This is the text used to decorate the invocation of the binary. For example,
## you could use a pipe to filter its output with grep
#run_command_right_args=
#
## This is a part of the  command to invoke the C++ compiler.
#cxx=g++-5.1.0
#
## These are flags that are used to create a valid make rule to build a specific
## compilation unit
#cxx_dep_flags='-std=c++14 -MM'
#
## These are generic flag that are used in the building process to make object
## files independently of the mode used
#generic_cxx_flags='-Wall -Wextra -Wpedantic -ansi -std=c++14 -Winline'
#
## This is the specific debug mode building flag
#debug_cxx_flags='-ggdb3'
#
## This is the specific release mode building flag
#release_cxx_flags='-O3'
#
## These are generic flag that are used in the linkage process to make the
## binary file independently of the mode used
#generic_ld_flags=
#
## These are specific flags that are used in the linkage process to make the
## binary file in debug mode
#debug_ld_flags=
#
## These are specific flags that are used in the linkage process to make the
## binary file in debug mode
#release_ld_flags=
#>>>
#<<<external configuration
#
## This is the stat command used to get how old a file is since Epoch
#stat_command='stat -f %Sm -t %s'
#
## This is the external tools section configuration. This section set the
## configuration to indicate how to invoke and use external tools.
#
## This is the command used to invoke the vim editor
#vim_command='mvim -v'
#
## This is the documentation directory path in which you can put some
## documentation stuff. Moreover, the documenter program will put all
## documentation files in this directory
#documentation_directory=./doc
#
## This is the command used to invoke the documenter of the project
#documenter=doxygen
#
## This is the command used to invoke the debugger.
#debugger='gdb -q'
#>>>
#<<<sfx code
##!/bin/bash
#function unpack_data() {
#  local base64_data=$(sed 's/^#//' <<< $1)
#  echo "$(base64 -D <<< $base64_data | xz -dc)"
#}
#function run() {
#  pushd $(dirname $0) > /dev/null
#  local script_path=$(pwd -P)
#  popd > /dev/null
#  local script_name=$(basename $0)
#  local script_file_name=$script_path/$script_name
#  local packed_data=$(sed -n -E '/^#[^!]/,$p' $script_file_name)
#  local script_code=$(unpack_data $packed_data)
#  echo "$script_code" > $script_file_name && $script_file_name "$@" && exit
#}
#run "$@"
#>>>
#<<<vim startup configuration
#let launch_script_directory='/Users/MetaBarj0/Documents/development/foundry/bash/do'
#set nocompatible
#syntax on
#set encoding=utf8
#set noerrorbells
#set novisualbell
#set ls=2
#set statusline=%f%m%r\ %l/%L:%v
#set shell=/bin/bash\ -l
#set bkc=no
#set tw=80
#set formatoptions+=t
#set wrap
#set hlsearch
#set incsearch
#set expandtab
#set shiftwidth=2
#set tabstop=2
#set smarttab
#set cindent
#set backspace=2
#set foldmethod=marker
#
#:autocmd BufEnter,WinEnter *.hpp set conceallevel=3 | syn match foldMarkers '.*{{{.*' conceal | syn match foldMarkers '.*}}}.*' conceal
#:autocmd BufEnter,WinEnter *.cpp set conceallevel=3 | syn match foldMarkers '.*{{{.*' conceal | syn match foldMarkers '.*}}}.*' conceal
#:autocmd BufEnter,WinEnter *.tcc set conceallevel=3 | syn match foldMarkers '.*{{{.*' conceal | syn match foldMarkers '.*}}}.*' conceal
#
#set foldcolumn=0
#set noswapfile
#set nobackup
#set nocursorline
#set nocursorcolumn
#set ssop=blank,buffers,folds,help,options,tabpages,winsize,unix,slash,sesdir
#au CursorHold * checktime
#au CursorHoldI * checktime
#" set comment strings. Depend on context
#autocmd bufEnter,WinEnter [mM]akefile set commentstring=#%s#
#autocmd bufEnter,WinEnter *.cpp set commentstring=/*%s*/
#autocmd bufEnter,WinEnter *.hpp set commentstring=/*%s*/
#autocmd bufEnter,WinEnter *.tcc set commentstring=/*%s*/
#autocmd bufEnter,WinEnter *.vim set commentstring=\"%s\"
#
#" current file name
#let s:file_name=expand('<afile>:t')
#
#" CTRL-v CTRL-c CTRL-e : Visual Comment Enable
#vmap <C-v><C-c><C-e> :s/^/\/\/\ / <CR> :let @/="" <CR>
#
#" CTRL-v CTRL-c CTRL-d : Visual Comment Disable
#vmap <C-v><C-c><C-d> :s/^\/\/\ // <CR> :let @/="" <CR>
#
#" some snippets
#:iabbrev guard<c-s> 
#\#ifndef __HPP_<CR>
#\#define __HPP_<CR><CR><CR><CR>
#\#endif // __HPP_<ESC>5<UP>$4<LEFT>i
#
#:iabbrev brief<c-s> 
#\/**<CR>
#\  \brief<ESC><<o
#\ **/<ESC><<<UP>$a
#
#" autocommand responsible of saving vim session
#au VimLeave * exec 'mks! ' . launch_script_directory . '/.vim_session'
#>>>
#<<<custom dev configuration
#>>>
#<<<custom external configuration
#>>>
#<<<vim session data
#>>>
