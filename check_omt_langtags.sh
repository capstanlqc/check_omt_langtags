#!/usr/bin/env bash

echo ""

# == FUNCTIONS == 
# inspired from https://gist.github.com/hfossli/4368aa5a577742c3c9f9266ed214aa58
function die() { IFS="$OIFS"; printf '———\n'; printf "$*" 1>&2 ; printf '\n'; exit 1; }

function usage() {
  if [ -n "$1" ]; then
    echo -e "${RED}👉  $1${CLEAR}\n"; # » 
  fi
  echo "Usage: $0 -i path-to-omt-pkg -c convention [-r] [-s xx]"
  echo "  -i, --input         Path to the OMT package (required)"
  echo "  -c, --convention    Language code convention: PISA or cApStAn (required)"
  echo "  -r, --region        Whether region subtags should be considered (required for now)"
  echo "  -s, --source        Source language as BCP-47 subtag, without region or script, e.g. fr"
  echo "                      (required only if different from 'en')"
  echo ""
  echo "Example: bash $0 --input /path/to/packages/PISA_glg-ESP_OMT.omt --convention PISA --region --source en"
  exit 1
}

# call as:
# bash check_omt_langtags.sh --input files/PISA2022MS_nld-BEL_OMT_Questionnaires.omt --convention PISA --region --source en

# == ARGUMENTS == 
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) help="$2"; shift ;;
        -i|--input) input="$2"; shift ;;
        -s|--source) source="$2"; shift ;;
        -c|--convention) convention="$2"; shift ;;
        -r|--region) region=1 ;;
        *) echo "Unknown parameter passed: $1. Use the --help flag if you're not sure how to proceed."; exit 1 ;;
    esac
    shift
done

## VALIDATIONS

# verify params
if [ -z ${help+x} ]; then
	if [ -z ${input+x} ]; then usage "Path to the OMT package not provided."; fi
	if [ -z ${convention+x} ]; then usage "Language code convention not specified."; fi
  if [ -z ${source+x} ]; then source="en"; fi
else usage "You have asked for help, see below:"; fi

# validate region -- temporarily mandatory
if [ -z ${region+x} ]; then die "Only the full language tag (including region subtag) is considered at the moment.  
If you really need to analyze only the language subtags, get in touch with the script's author."; fi

# validate convention
if test "$convention" != "PISA" && test "$convention" != "cApStAn"; then
  usage "Accepted language code conventions include 'PISA' and 'cApStAn'. You have used '${convention}'."
fi


# == DEPENDENCIES ==
# for debian-based
if ! which curl > /dev/null || ! which jq > /dev/null; then
  echo "This script needs to install two dependencies (jq and curl) if they are not installed. Your sudo password might be required now."
  sudo apt -qq install jq > /dev/null 2>&1
  sudo apt -qq install curl > /dev/null 2>&1
fi


# == LOGIC == 

# fail output
output=()

# use only linebreak as file separator
OIFS="$IFS"
IFS=$'\n'

# echo "Fetching language tags data..."
langtags=$(curl --silent -X GET https://capps.capstan.be/langtags_json.php) # > /dev/null 2>&1
if [ -z ${langtags+x} ]; then die "Unable to fetch language tags data, make sure you have an Internet connection."; fi
echo "OMT package: ${input}"
echo "Convention: ${convention}"
echo "Language tags data: Fetched"
#echo "Region is: Set (should be included in checks)"

# get XXX language code from omt filename
target_xxx_code=$(echo "$input" | grep -Poh '(?<=\b|_)([a-z]{3}-[A-Z]{3})(?=\b|_)')
if [ -z $target_xxx_code ]; then output+=("👉 No target language code detected in the OMT package's filename"); fi
#[ -e "$target_xxx_code" ] || output+=("👉 No language code detected in the OMT package's filename.")
echo "${convention} language code: ${target_xxx_code}"

# get correspondent omegat target language tag
omt_tgtlang_tag=$(echo $langtags | jq -cr --arg CODE "$target_xxx_code" --arg CONV "$convention" 'map(select(.[$CONV] == $CODE))'[].OmegaT)
if [ -z $omt_tgtlang_tag ]; then output+=("👉 Target language code '${target_xxx_code}' not valid in package name"); fi
#[ -e "$target_xxx_code" ] || output+=("👉 No language code detected in the OMT package's filename.")
echo "OmegaT target language tag: ${omt_tgtlang_tag}"


# get language tags from project settings
## extract project settings
unzip -p "$input" omegat.project >omegat.project

## extract target_lang and check that it matches $omt_tgtlang_tag
target_lang_in_project=$(grep -Poh '(?<=target_lang>)[^<]+' omegat.project)
[[ "$omt_tgtlang_tag" == "$target_lang_in_project" ]] || output+=("👉 Target language tag '${target_lang_in_project}' not valid in project settings")
echo "Target language tag in project settings: ${target_lang_in_project}"

## extract source_lang
source_lang_in_project=$(grep -Poh '(?<=source_lang>)[^<]+' omegat.project)
[[ $source_lang_in_project =~ $source ]] || output+=("👉 Source language tag '${source_lang_in_project}' in project settings is not a variant of '${source}'")
echo "Source language tag in project settings: ${source_lang_in_project}"

# get correspondent omegat target language tag
source_xxx_code=$(echo $langtags | jq -cr --arg CODE "$source_lang_in_project" 'map(select(.OmegaT == $CODE))'[].$convention)
if [ -z $source_xxx_code ]; then output+=("👉 Source language code '${source_lang_in_project}' not valid in project settings"); fi
#[ -e "$target_xxx_code" ] || output+=("👉 No language code detected in the OMT package's filename.")
echo "${convention} source language code: ${source_xxx_code}"


# unzip project
prj_pkg="${input##*/}"
prj_dir="${prj_pkg%.omt}"
unzip -qo -d $prj_dir "$input"

# ----------------------------------------------------------------------
# XLIFF files

# check target language code in source xliff files
for f in $(find "$prj_dir/source" -name "*.xlf" -type f); do
  for code in $(grep -Poh '(?<=(<target xml:lang| target-language)=")[^"]+' $f | sort | uniq); do
    if test "$code" != "$target_xxx_code" && test "$code" != "$target_lang_in_project"; then
      output+=("👉 Target language code '${code}' not valid in file '${f}'")
    fi
  done
done

# check source language code in source xliff files
for f in $(find "$prj_dir/source" -name "*.xlf" -type f); do
  for code in $(grep -Poh '(?<=(<source xml:lang| source-language)=")[^"]+' $f | sort | uniq); do
    if test "$code" != "$source_xxx_code" && test "$code" != "$source_lang_in_project"; then
      output+=("👉 Source language code '${code}' not valid in file '${f}'")
    fi
  done
done

# ----------------------------------------------------------------------
# TMX files 


# check source language code in source xliff files
for f in $(find $prj_dir/{tm,omegat} -name "*.tmx" -type f); do
  srclang=$(grep -Poh '(?<=srclang=")[^"]+' $f)
  for code in $(grep -Poh '(?<=(xml:lang|tuv lang| srclang)=")[^"]+' $f | sort | uniq); do
    if test $code == $srclang; then
      if test "$code" != "$source_lang_in_project" && [[ ! "$source_lang_in_project" =~ "$code" ]] && [[ ! "$code" =~ "$source" ]]; then
        output+=("👉 Source language code '${code}' in file '${f}' does not match source language of the project '${source_lang_in_project}'")
      fi
    fi
  done
done

# check target language code in source xliff files
for f in $(find $prj_dir/{tm,omegat} -name "*.tmx" -type f); do
  srclang=$(grep -Poh '(?<=srclang=")[^"]+' $f)
  for code in $(grep -Poh '(?<=(xml:lang|tuv lang)=")[^"]+' $f | sort | uniq); do
    if test $code != $srclang; then
      if test "$code" != "$target_lang_in_project" && [[ ! "$target_lang_in_project" =~ "$code" ]]; then
        output+=("👉 Target language code '${code}' in file '${f}' does not match target language of the project '${target_lang_in_project}'.")
      fi
    fi
  done
done

# ----------------------------------------------------------------------

if [ -d "$prj_dir" ]; then rm -r $prj_dir; fi
rm omegat.project

# ${#output[@]} is length of the output array
#if test "${#output[@]}" -gt 0; then die "test"; fi
if test "${#output[@]}" == 0; then printf '———\nPASS\n'; else printf '———\nFAIL\n'; fi
for i in ${output[@]}; do echo $i; done

IFS="$OIFS"

# print to output text file