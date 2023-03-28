

ELM_SRC=$(wildcard src/Build/*.elm)
ELM_OUT=$(patsubst src/Build/%.elm,build/%.elm.js,$(ELM_SRC))
JS_SRC=$(wildcard src/Build/*.js)
JS_OUT=$(patsubst src/Build/%.js,build/%.js,$(JS_SRC))
HTML_SRC=$(wildcard src/Build/*.html)
HTML_OUT=$(patsubst src/Build/%.html,build/%.html,$(HTML_SRC))
CSS_SRC=$(wildcard src/Build/*.css)
CSS_OUT=$(patsubst src/Build/%.css,build/%.css,$(CSS_SRC))


dev: $(ELM_OUT) $(JS_OUT) $(HTML_OUT) $(CSS_OUT)


build/%.elm.js: src/Build/%.elm FORCE
	elm make --output $@ $< > /dev/null

build/Server.elm.js: src/Build/Server.elm FORCE
	elm make --output $@ $< > /dev/null
	echo 'module.exports = this.Elm;' >> $@

build/%.js: src/Build/%.js
	cp $< $@

build/%.html: src/Build/%.html
	cp $< $@

build/%.css: src/Build/%.css
	cp $< $@


FORCE:
