#!/usr/bin/make -f

pos = $(wildcard */site/translations/*/*/*.po)
mos = $(pos:.po=.mo)
pot = vlna/site/translations/messages.pot

pys = $(shell find vlna -name '*.py')
htmls = $(shell find vlna -name '*.html')
src = ${pys} ${htmls}

all: lang
lang: ${mos}

clean:
	rm -f ${mos} ${pot}

%.mo: %.po
	pybabel -q compile -o $@ -i $<

${pos}: ${pot}
	pybabel -q update -i ${pot} -d $(dir ${pot})

${pot}: ${src}
	pybabel -q extract -F babel.cfg vlna -o ${pot} --omit-header --no-location


.PHONY: all lang clean

# EOF
