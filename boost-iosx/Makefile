mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

DEST_DIR := $(mkfile_dir)/dest

.PHONY: build clean

build:
	cd ${mkfile_dir} && scripts/build.sh
	# 整理为 dest 目录结构
	rm -rf $(DEST_DIR)
	mkdir -p $(DEST_DIR)/include $(DEST_DIR)/lib
	cp -R $(mkfile_dir)/frameworks/Headers/boost $(DEST_DIR)/include/
	cp -R $(mkfile_dir)/frameworks/*.xcframework $(DEST_DIR)/lib/

clean:
	cd ${mkfile_dir} && rm -rf *.tar.xz boost frameworks frameworks.built.libs frameworks.built.platforms dest

