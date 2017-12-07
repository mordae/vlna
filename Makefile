#!/usr/bin/make -f

adocs = $(wildcard doc/*.adoc)
htmls = $(adocs:.adoc=.html)
dots  = $(shell find doc -name '*.dot')
dias  = $(shell find doc -name '*.dia')
pngs  = $(dots:.dot=.png) $(dias:.dia=.png)
pdfs  = $(adocs:.adoc=.pdf)

all: doc
doc: html pdf png

html: png ${htmls}
pdf: ${pdfs}
png: ${pngs}

clean:
	rm -f doc/*.html doc/*.png doc/*.cache doc/*.pdf ${pngs}
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

# EOF
