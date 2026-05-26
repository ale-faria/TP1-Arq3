`timescale 1ns / 1ps
import cache_pkg::*;

module mock_memory (
    input  logic                                clk,
    input  logic                                rst_n,

    input  logic                                mem_req_i,
    input  logic [ADDR_WIDTH-1:0]               mem_addr_i,
    input  logic                                mem_write_i,
    input  logic [(DATA_WIDTH*BLOCK_SIZE)-1:0]  mem_wdata_i,

    output logic [(DATA_WIDTH*BLOCK_SIZE)-1:0]  mem_rdata_o,
    output logic                                mem_ready_o
);

    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] ram [0:255];
    logic [7:0] block_addr;
    assign block_addr = mem_addr_i[11:4];

    logic [2:0] delay_counter;
    
    // Declarado aqui fora para evitar o warning
    integer i; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready_o   <= 1'b0;
            mem_rdata_o   <= '0;
            delay_counter <= '0;

            for (i = 0; i < 256; i = i + 1) begin
                // Usando tamanhos super explícitos (32'd) para o iverilog não reclamar de indefinite width
                ram[i] <= {
                    (32'd3 + (i[31:0] * 32'd16)), 
                    (32'd2 + (i[31:0] * 32'd16)), 
                    (32'd1 + (i[31:0] * 32'd16)), 
                    (32'd0 + (i[31:0] * 32'd16))
                };
            end
        end else begin
            mem_ready_o <= 1'b0;

            if (mem_req_i && !mem_ready_o) begin
                if (delay_counter < 3) begin
                    delay_counter <= delay_counter + 1;
                end else begin
                    mem_ready_o   <= 1'b1;
                    delay_counter <= '0;

                    if (mem_write_i) begin
                        logic [1:0] w_offset;
                        w_offset = mem_addr_i[3:2];

                        if (w_offset == 2'b00) ram[block_addr][31:0]   <= mem_wdata_i[31:0];
                        if (w_offset == 2'b01) ram[block_addr][63:32]  <= mem_wdata_i[63:32];
                        if (w_offset == 2'b10) ram[block_addr][95:64]  <= mem_wdata_i[95:64];
                        if (w_offset == 2'b11) ram[block_addr][127:96] <= mem_wdata_i[127:96];
                    end else begin
                        mem_rdata_o <= ram[block_addr];
                    end
                end
            end else begin
                delay_counter <= '0;
            end
        end
    end

endmodule : mock_memory