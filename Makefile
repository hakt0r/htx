PATH := ./node_modules/.bin:${PATH}

all: clean test

dist: clean init test

test: 
	mkdir test
	htx -v -W -w src/test -t index.html -d test/out.html
	cmp test/out.html src/test/compare.html

clean:
	rm -rf test

init:
	npm install

publish: dist
	npm publish