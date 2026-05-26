`timescale 1ns / 1ps
import cache_pkg::*;

module mock_memory (
    input  logic                                clk,
    input  logic                                rst_n,

    // Sinais conectados ao controlador de cache
    input  logic                                mem_req_i,
    input  logic [ADDR_WIDTH-1:0]               mem_addr_i,
    input  logic                                mem_write_i,
    input  logic [(DATA_WIDTH*BLOCK_SIZE)-1:0]  mem_wdata_i,

    output logic [(DATA_WIDTH*BLOCK_SIZE)-1:0]  mem_rdata_o,
    output logic                                mem_ready_o
);
    // RAM: 256 blocos de 128 bits (4096 bytes) 
    // É pequena de propósito para simular rápido e não travar o PC
    // mas grande o suficiente para testar a cache inteira (64 linhas)
    // ~dom
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] ram [0:255];

    // O endereço de bloco ignora os 4 bits de offset de byte (pois o bloco tem 16 bytes)
    logic [7:0] block_addr;
    assign block_addr = mem_addr_i[11:4];

    // Variável para criar um atraso "falso" e simular a latência da memória
    logic [2:0] delay_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready_o   <= 1'b0;
            mem_rdata_o   <= '0;
            delay_counter <= '0;

            // Inicializa a RAM com valores sequenciais para facilitar o debug visual no GTKWave
            for (int i = 0; i < 256; i++) begin
                // Cada palavra do bloco recebe um valor único
                ram[i] <= {32'h00000003 + (i*16), 32'h00000002 + (i*16), 32'h00000001 + (i*16), 32'h00000000 + (i*16)};
            end
        end else begin
            // Valor padrão para não gerar latch
            mem_ready_o <= 1'b0;

            if (mem_req_i && !mem_ready_o) begin
                if (delay_counter < 3) begin
                    // Conta 3 ciclos de clock de "espera"
                    delay_counter <= delay_counter + 1;
                end else begin
                    // Terminou o atraso, a memória responde
                    mem_ready_o   <= 1'b1;
                    delay_counter <= '0; // Reseta para o próximo acesso

                    if (mem_write_i) begin
                        // LÓGICA DE ESCRITA:
                        // Como a CPU escreve palavras de 32 bits, mas o barramento tem 128 bits
                        // usamos os bits [3:2] do endereço para saber qual parte do bloco atualizar
                        // evitando destruir o resto do bloco que já estava na memória
                        logic [1:0] w_offset = mem_addr_i[3:2];

                        if (w_offset == 2'b00) ram[block_addr][31:0]   <= mem_wdata_i[31:0];
                        if (w_offset == 2'b01) ram[block_addr][63:32]  <= mem_wdata_i[63:32];
                        if (w_offset == 2'b10) ram[block_addr][95:64]  <= mem_wdata_i[95:64];
                        if (w_offset == 2'b11) ram[block_addr][127:96] <= mem_wdata_i[127:96];
                    end else begin
                        // LÓGICA DE LEITURA:
                        // Entrega o bloco de 128 bits inteiro para a cache
                        mem_rdata_o <= ram[block_addr];
                    end
                end
            end else begin
                // Se a requisição cair, zera o contador
                delay_counter <= '0;
            end
        end
    end

endmodule : mock_memory