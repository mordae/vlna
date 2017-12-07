#!/usr/bin/make -f

adocs = $(wildcard doc/*.adoc)
htmls = $(adocs:.adoc=.html)
dots  = $(shell find doc -name '*.dot')
dias  = $(shell find doc -name '*.dia')
pngs  = $(dots:.dot=.png) $(dias:.dia=.png)
pdfs  = $(adocs:.adoc=.pdf)

pos = $(wildcard */site/translations/*/*/*.po)
mos = $(pos:.po=.mo)
pot = vlna/site/translations/messages.pot

pys = $(shell find vlna -name '*.py')
htmls = $(shell find vlna -name '*.html')
src = ${pys} ${htmls}

all: doc lang
doc: html pdf png
lang: ${mos}
html: png ${htmls}
pdf: ${pdfs}
png: ${pngs}

clean:
	rm -f doc/*.html doc/*.png doc/*.cache doc/*.pdf ${pngs}
	rm -f ${mos} ${pot}
	rm -rf doc/.asciidoctor

%.html: %.adoc Makefile
	asciidoctor -b html5 -r asciidoctor-diagram -o $@ $< -a imagesdir="." -a imagesoutdir="."

%.pdf: %.adoc $(wildcard doc/media/*.*) ${pngs} Makefile
	asciidoctor-pdf -r asciidoctor-diagram -o $@ $< -a imagesdir="." -a imagesoutdir="."

%.png: %.dot Makefile
	dot $< -Tpng -o $@

%.png: %.dia Makefile
	dia -e $@ $<
	mogrify -bordercolor white -border 32x32 $@

%.mo: %.po
	pybabel -q compile -o $@ -i $<

${pos}: ${pot}
	pybabel -q update -i ${pot} -d $(dir ${pot})

${pot}: ${src}
	pybabel -q extract -F babel.cfg vlna -o ${pot} --omit-header --no-location


.PHONY: all lang clean

# EOF
