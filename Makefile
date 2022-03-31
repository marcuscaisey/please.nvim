PWD=$(shell pwd)

gendocs:
	docker build gendocs -t gendocs && \
	docker run -it --rm --name gendocs -v $(PWD)/doc:/doc -v $(PWD)/lua/please:/please -v $(PWD)/gendocs/doc_files.txt:/gendocs/doc_files.txt gendocs
