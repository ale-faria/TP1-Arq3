`timescale 1ns / 1ps
import cache_pkg::*;

module tag_array (
    input  logic                    clk,
    input  logic                    rst_n,
    
    input  logic                    we_i,       // Write Enable
    input  logic [INDEX_BITS-1:0]   index_i,    // Índice da linha
    input  logic [TAG_BITS-1:0]     tag_i,      // Tag a ser gravada
    
    output logic [TAG_BITS-1:0]     tag_o,      // Tag lida
    output logic                    valid_o     // Bit de validade
);

    // Substituindo a struct por dois arrays independentes para contornar o bug do iverilog
    logic [TAG_BITS-1:0] tag_mem   [0:CACHE_LINES-1];
    logic                valid_mem [0:CACHE_LINES-1];

    // Lógica de Leitura (Assíncrona)
    assign tag_o   = tag_mem[index_i];
    assign valid_o = valid_mem[index_i];

    // Variável para o laço de repetição declarada fora para evitar warning de lifetime
    integer i;

    // Lógica de Escrita e Reset (Síncrona)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Invalida toda a cache no reset
            for (i = 0; i < CACHE_LINES; i = i + 1) begin
                valid_mem[i] <= 1'b0;
                tag_mem[i]   <= '0;
            end
        end else if (we_i) begin
            // Grava a nova tag e marca como válida
            valid_mem[index_i] <= 1'b1;
            tag_mem[index_i]   <= tag_i;
        end
    end

endmodule : tag_array