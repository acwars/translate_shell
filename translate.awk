#!/usr/bin/gawk -f

@include "metainfo.awk"

@include "include/commons.awk"
@include "include/utils.awk"

@include "include/languages.awk"
@include "include/help.awk"
@include "include/parser.awk"
@include "include/theme.awk"

@include "include/translate.awk"
@include "include/translator_interface.awk"
@include "include/translators/*"

@include "include/script.awk"
@include "include/REPL.awk"

@include "include/main.awk"
