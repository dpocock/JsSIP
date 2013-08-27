#!/usr/bin/make -f
##################### configurable stuff ###################################
#
# Tools we require
#
# UglifyJS
UGLIFY ?= uglifyjs
#
# PEG.js
PEGJS ?= pegjs
#
# Google Closure Compiler (minify)
MINIFY_GCC ?= closure-compiler
# hack for Debian bug 705565:
#MINIFY_GCC ?= java -classpath /usr/share/java/closure-compiler.jar:/usr/share/java/args4j.jar:/usr/share/java/guava.jar:/usr/share/java/json.jar com.google.javascript.jscomp.CommandLineRunner

#############################################################################
#
# Version we are building
VERSION = $(shell cat package.json | grep version.: | cut -f4 -d'"')

# Sources
SOURCES = $(shell cat Gruntfile.js | grep 'src/.*js' | grep -v Grammar | tr -d " ',")


all:	normal minified
	@echo JsSIP version = $(VERSION)

normal:	dist/JsSIP-$(VERSION).js

minified:	dist/JsSIP-$(VERSION).min.js

#
# Compile and minify the SIP grammar
#

src/Grammar/dist/Grammar.js:	src/Grammar/src/Grammar.pegjs
	$(PEGJS) -e JsSIP.Grammar src/Grammar/src/Grammar.pegjs src/Grammar/dist/Grammar.js
	perl -0777 -pi -e 's/throw new this\.SyntaxError\(([\s\S]*?)\);([\s\S]*?)}([\s\S]*?)return result;/new this.SyntaxError(\1);\n        return -1;\2}\3return data;/' src/Grammar/dist/Grammar.js

src/Grammar/dist/Grammar.min.js:	src/Grammar/dist/Grammar.js
	$(MINIFY_GCC) --js src/Grammar/dist/Grammar.js --js_output_file src/Grammar/dist/Grammar.min.js

#
# Do the concate and replacement stuff
#

tmp/JsSIP-$(VERSION).js.part:	$(SOURCES)
	mkdir -p tmp
	cat $(SOURCES) \
	   | sed -e '/^var RequestSender.*= /r src/RTCSession/RequestSender.js' \
	   | sed -e '/^var RTCMediaHandler.*= /r src/RTCSession/RTCMediaHandler.js' \
	   | sed -e '/^var DTMF.*= /r src/RTCSession/DTMF.js' \
	   | sed -e 's/@@include.*$$//' \
	   | sed -e '$$a\\window.JsSIP = JsSIP;\n}(window));' \
	   > tmp/JsSIP-$(VERSION).js.part

dist/JsSIP-$(VERSION).js:	src/Grammar/dist/Grammar.js tmp/JsSIP-$(VERSION).js.part
	mkdir -p dist
	cat tmp/JsSIP-$(VERSION).js.part src/Grammar/dist/Grammar.js\
	   > dist/JsSIP-$(VERSION).js

dist/JsSIP-$(VERSION).min.js:	src/Grammar/dist/Grammar.min.js tmp/JsSIP-$(VERSION).js.part
	mkdir -p dist
	$(UGLIFY) tmp/JsSIP-$(VERSION).js.part > tmp/JsSIP-$(VERSION).min.js.part
	cat tmp/JsSIP-$(VERSION).min.js.part src/Grammar/dist/Grammar.min.js \
	    > dist/JsSIP-$(VERSION).min.js

clean:
	-rm -rf tmp dist

srcdist:
	-rm -rf jssip-$(VERSION)
	mkdir jssip-$(VERSION)
	cp -r AUTHORS.md BUILDING.md CHANGELOG.md Gruntfile.js LICENSE Makefile package.json README.md src test THANKS.md jssip-$(VERSION)
	tar czf jssip-$(VERSION).tar.gz jssip-$(VERSION)

