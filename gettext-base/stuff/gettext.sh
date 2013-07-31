#!/bin/sh
eval_gettext() {
  gettext "$1" | (export PATH $(envsubst --variables "$1"); envsubst "$1")
}
eval_ngettext() {
  ngettext "$1" "$2" "$3" | (export PATH $(envsubst --variables "$1 $2"); envsubst "$1 $2")
}
