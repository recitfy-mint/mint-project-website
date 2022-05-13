# targets that aren't filenames
.PHONY: all clean deploy build serve

all: build

BIBBLE = bibble

_includes/pubs.html: bib/pubs.bib bib/publications.tmpl
	mkdir -p _includes
	$(BIBBLE) $+ > $@

build: _includes/pubs.html
	jekyll build

# Install Gemfiles
Gemfile.lock: Gemfile
	bundle install
	touch $@

dirs := _data _includes _layouts _posts _projects bib css img js
SRC := $(foreach dir, $(dirs), $(wildcard $(dir)/*))
SRC += $(shell git ls-tree -r --name-only HEAD -- *.md)
SRC += $(shell git ls-tree -r --name-only HEAD -- *.html)
SRC += _config.yml
BIB_FILES := _includes/pubs.html

# Build target for previewing on AWPS
PREVIEW_DIR ?= /collections/rectify
_site/ : Gemfile.lock $(BIB_FILES) $(SRC)
	rm -rf $@
	bundle exec jekyll build -d $(join $@, $(PREVIEW_DIR)) -b $(PREVIEW_DIR)
	touch $@

# Build target for publishing to AWPS
PUBLISH_DIR ?= /energy/rectify
_site-publish/ : Gemfile.lock $(BIB_FILES) $(SRC)
	rm -rf $@
	JEKYLL_ENV=production \
	bundle exec jekyll build -d $(join $@, $(PUBLISH_DIR)) -b $(PUBLISH_DIR)
	touch $@

# you can configure these at the shell, e.g.:
# SERVE_PORT=5001 make serve
SERVE_HOST ?= 127.0.0.1
SERVE_PORT ?= 5000

serve-local: _includes/pubs.html
	jekyll serve --port $(SERVE_PORT) --host $(SERVE_HOST)

serve: _site/ Gemfile.lock
	bundle exec jekyll serve -l -I \
		-b $(PREVIEW_DIR) -d $<$(PREVIEW_DIR) \
		--port $(SERVE_PORT) --host $(SERVE_HOST)

clean:
	$(RM) -r _site _includes/pubs.html

# DEPLOY_HOST ?= yourwebpage.com
# DEPLOY_PATH ?= www/
# RSYNC := rsync --compress --recursive --checksum --itemize-changes --delete -e ssh
deploy: clean build
	$(RSYNC) _site/ $(DEPLOY_HOST):$(DEPLOY_PATH)

# Configuration Options (Set on CLI)
#	DEPLOY_HOST rclone host for AWPS
# 	RELEASE_URL Location of the released zip file on github. Correctly set if cloned via https
# 	PREVIEW_DIR Folder on AWPS where files are copied
DEPLOY_HOST ?= cmu-awps
RELEASE_URL ?= https://github.com/rectify-minte/mint-project-website/releases/download/latest/site-publish.zip
deploy-publish: _site-publish/
	rclone sync -P $<$(PUBLISH_DIR) $(DEPLOY_HOST):$(PREVIEW_DIR)
deploy-preview: _site/
	rclone sync -P $<$(PREVIEW_DIR) $(DEPLOY_HOST):$(PREVIEW_DIR)
deploy-github:
	curl -L $(RELEASE_URL) -o github-publish.zip
	unzip -o -d github-publish github-publish
	rclone sync -P github-publish $(DEPLOY_HOST):$(PREVIEW_DIR)
	rm -rf github-publish github-publish.zip

# Run test on the website using htmlproofer
test: Gemfile.lock _site/ _site-publish/
	@echo "Checking preview version"
	bundle exec htmlproofer \
	--disable-external \
	--check-html --check-img-http --enforce-https \
	--typhoeus-config='{"headers":{"UserAgent":"htmlproofer"}}' \
	_site

	@echo "Checking published version"
	bundle exec htmlproofer \
	--http-status-ignore 999 \
	--disable-external \
	--check-html --check-img-http --enforce-https \
	--typhoeus-config='{"headers":{"UserAgent":"htmlproofer"}}' \
	_site-publish/

# Archive Site for Publishing
site-publish.zip: _site-publish/
	cd _site-publish/$(PUBLISH_DIR) &&  zip -r $(abspath site-publish.zip) .
