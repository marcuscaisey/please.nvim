PWD=$(shell pwd)

docs:
	docker build gendocs -t gendocs && \
	docker run -it --rm --name gendocs -v $(PWD)/doc:/doc -v $(PWD)/lua:/lua -v $(PWD)/gendocs/doc_files.txt:/gendocs/doc_files.txt gendocs
