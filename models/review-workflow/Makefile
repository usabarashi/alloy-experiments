MODEL=model.als
TRACE_FILE=traces.md

.PHONY: help test clean trace diagram

help:
	@echo "Available commands:"
	@echo "  make test     - Run run/check commands"
	@echo "  make trace    - Capture example trace"
	@echo "  make diagram  - Generate state transition diagram"
	@echo "  make clean    - Remove generated files"
	@echo "  make help     - Show this help message"

# run/check をまとめて実行
test:
	@./test.sh $(MODEL)

trace:
	@./trace.sh $(MODEL) $(TRACE_FILE)
	@echo "Markdown trace (run instances + assertion counterexamples) saved to $(TRACE_FILE)"

diagram:
	@./diagram.sh

clean:
	@rm -f $(TRACE_FILE)
	@echo "Clean completed."
