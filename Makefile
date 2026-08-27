CC = gcc
LINKER = gcc

SRCDIR = src
OBJDIR = obj
BINDIR = bin

CFLAGS = -Wall -I/usr/include/lua5.3 -fPIC
LDFLAGS = -shared
LDLIBS = -llua5.3 -lrabbitmq -lrt

SOURCES = $(wildcard $(SRCDIR)/*.c)
OBJECTS = $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)

TARGET = $(BINDIR)/amqp.so

all: $(TARGET)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

$(OBJDIR)/%.o: $(SRCDIR)/%.c | $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@
	@echo "Compiled $< successfully!"

$(TARGET): $(OBJECTS) | $(BINDIR)
	$(LINKER) $(LDFLAGS) -o $@ $(OBJECTS) $(LDLIBS)
	@echo "Linking complete!"

clean:
	rm -rf $(OBJDIR) $(TARGET)