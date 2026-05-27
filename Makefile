TARGET = output/sim_cache
SRC = src/cache_pkg.sv src/tag_array.sv src/data_array.sv src/cache_controller.sv src/mock_memory.sv src/tb_cache.sv

all: compile run

compile:
	mkdir -p output
	iverilog -g2012 -o $(TARGET) $(SRC)

run:
	./$(TARGET) | tee output/output.txt
	mv dump.vcd output/

view:
	gtkwave output/dump.vcd

clean:
	rm -rf output/