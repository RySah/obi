# # ----------- #
# #  Variables  #
# # ----------- #

# CFLAGS = -Wall -Wextra --std=c99 --pedantic -Wno-unused-parameter

# # --------------- #
# #  Phony Targets  #
# # --------------- #

# help: ## Prints available commands.
# 	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / \
# 	{printf "\033[1;36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# all: ## Compiles all binaries.
# 	@make ex1
# 	@make ex2
# 	@make tests

# ex1: ## Compiles the example1.c file.
# 	@mkdir -p build
# 	$(CC) $(CFLAGS) -o build/ex1 src/example1.c src/args.c

# ex2: ## Compile. the example2.c file.
# 	@mkdir -p build
# 	$(CC) $(CFLAGS) -o build/ex2 src/example2.c src/args.c

# tests: ## Compiles the test binary.
# 	@mkdir -p build
# 	$(CC) $(CFLAGS) -o build/tests src/tests.c src/args.c

# check: ## Runs tests.
# 	@make tests
# 	./build/tests

# clean: ## Deletes all build artifacts.
# 	rm -f ./build/*



# 
# Tweaked version that can work with `mingw32-make`. 
# And build the static libaries on its own
# 

# ----------- #
#  Variables  #
# ----------- #

CC      ?= gcc
AR      ?= ar
CFLAGS  ?= -Wall -Wextra --std=c99 --pedantic -Wno-unused-parameter

BUILD_DIR := build
LIB_NAME  := args

# Platform detection
ifeq ($(OS),Windows_NT)
    EXE       := .exe
    SEP       := /
    SHELL_SEP := \
    MKDIR     := mkdir $(BUILD_DIR) 2>NUL || exit 0
    RM        := del /Q
else
    EXE       :=
    SEP       := /
    SHELL_SEP := /
    MKDIR     := mkdir -p $(BUILD_DIR)
    RM        := rm -f
endif

# Files
LIB_OBJ := $(BUILD_DIR)$(SEP)args.o
LIB_A   := $(BUILD_DIR)$(SEP)lib$(LIB_NAME).a

# ---------------- #
#  Library Target  #
# ---------------- #

libs: $(LIB_A)

# ---------------- #
#  Default Target  #
# ---------------- #

all: ex1 ex2 tests

# -------------------- #
#  Static Library      #
# -------------------- #

$(LIB_OBJ): src/args.c
	@$(MKDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB_A): $(LIB_OBJ)
	$(AR) rcs $@ $^

# ---------------- #
#  Build Targets   #
# ---------------- #

ex1: $(LIB_A) src/example1.c
	$(CC) $(CFLAGS) -o $(BUILD_DIR)$(SEP)ex1$(EXE) \
	    src/example1.c $(LIB_A)

ex2: $(LIB_A) src/example2.c
	$(CC) $(CFLAGS) -o $(BUILD_DIR)$(SEP)ex2$(EXE) \
	    src/example2.c $(LIB_A)

tests: $(LIB_A) src/tests.c
	$(CC) $(CFLAGS) -o $(BUILD_DIR)$(SEP)tests$(EXE) \
	    src/tests.c $(LIB_A)

check: tests
	$(BUILD_DIR)$(SEP)tests$(EXE)

# ---------------- #
#  Utility Targets #
# ---------------- #

clean:
	$(RM) $(BUILD_DIR)$(SHELL_SEP)* 2>NUL || true

help:
	@echo Available targets:
	@echo   libs    - Build all static libaries
	@echo   all     - Build all binaries
	@echo   ex1     - Build example 1
	@echo   ex2     - Build example 2
	@echo   tests   - Build tests
	@echo   check   - Run tests
	@echo   clean   - Remove build artifacts
