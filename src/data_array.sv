`timescale 1ns / 1ps
import cache_pkg::*;

module data_array (
    input  logic                                clk,
    input  logic                                we_i,           // Gravação ativa
    input  logic [1:0]                          word_en_i,      // 00 = Bloco todo, outros = palavra específica
    input  logic [INDEX_BITS-1:0]               index_i,        // Linha mapeada da cache
    input  logic [(DATA_WIDTH*BLOCK_SIZE)-1:0]   data_i,         // Entrada de dados (128 bits)
    output logic [(DATA_WIDTH*BLOCK_SIZE)-1:0]   data_o          // Saída de dados (128 bits)
);

    // Banco de memória interna: 64 linhas contendo 128 bits cada (4 palavras de 32 bits)
    logic [31:0] data_mem [0:CACHE_LINES-1][0:BLOCK_SIZE-1];

    // Lógica de Leitura Combinacional (Assíncrona)
    assign data_o = {data_mem[index_i][3], data_mem[index_i][2], data_mem[index_i][1], data_mem[index_i][0]};

    // Lógica de Escrita Síncrona
    always_ff @(posedge clk) begin
        if (we_i) begin
            if (word_en_i == 2'b00) begin
                // Gravação paralela de todas as 4 palavras (vinda da memória principal)
                data_mem[index_i][0] <= data_i[31:0];
                data_mem[index_i][1] <= data_i[63:32];
                data_mem[index_i][2] <= data_i[95:64];
                data_mem[index_i][3] <= data_i[127:96];
            end else begin
                // Gravação pontual de apenas uma palavra (vinda de um Hit de escrita da CPU)
                data_mem[index_i][word_en_i] <= data_i[31:0];
            end
        end
    end

endmodule : data_array