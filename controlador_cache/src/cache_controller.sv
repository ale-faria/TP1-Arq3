`timescale 1ns / 1ps
import cache_pkg::*;

module cache_controller (
    input  logic                    clk,
    input  logic                    rst_n,

    // Interface com a CPU
    input  logic                    cpu_req_i,     // Solicitação de acesso da CPU
    input  logic [ADDR_WIDTH-1:0]   cpu_addr_i,    // Endereço enviado pela CPU
    input  logic                    cpu_write_i,   // 1 = Escrita, 0 = Leitura
    input  logic [DATA_WIDTH-1:0]   cpu_wdata_i,   // Dado de escrita da CPU
    output logic [DATA_WIDTH-1:0]   cpu_rdata_o,   // Dado de leitura enviado para a CPU
    output logic                    cpu_ready_o,   // Sinal de pronto (fim da operação)

    // Interface com a Memória Principal
    output logic                    mem_req_o,     // Solicitação de acesso à memória
    output logic [ADDR_WIDTH-1:0]   mem_addr_o,    // Endereço enviado para a memória
    output logic                    mem_write_o,   // 1 = Escrita, 0 = Leitura
    output logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] mem_wdata_o, // Bloco de dados para a memória
    input  logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] mem_rdata_i, // Bloco de dados lido da memória
    input  logic                    mem_ready_i    // Memória informa que concluiu a operação
);

    // ---- Decodificação e Fatiamento do Endereço da CPU ----
    logic [TAG_BITS-1:0]   cpu_tag;
    logic [INDEX_BITS-1:0] cpu_index;
    logic [1:0]            word_offset; // Bits [3:2] selecionam a palavra dentro do bloco de 4 palavras

    assign cpu_tag     = cpu_addr_i[ADDR_WIDTH-1 : ADDR_WIDTH-TAG_BITS];
    assign cpu_index   = cpu_addr_i[OFFSET_BITS+INDEX_BITS-1 : OFFSET_BITS];
    assign word_offset = cpu_addr_i[3:2]; 

    // ---- Sinais de Controle Internos ----
    cache_state_e current_state, next_state;
    
    logic                    tag_we;
    logic [TAG_BITS-1:0]     tag_from_cache;
    logic                    valid_from_cache;
    
    logic                    data_we;
    logic [1:0]              data_word_mask; // Controla se grava o bloco to do ou apenas uma palavra
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] data_from_cache;
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] data_to_cache;

    // ---- Lógica de Identificação de Hit / Miss ----
    logic cache_hit;
    assign cache_hit = valid_from_cache && (tag_from_cache == cpu_tag); [cite: 66, 68]

    // ---- Multiplexação do Dado de Saída (Leitura CPU) ----
    // Seleciona a palavra correta de 32 bits dentro do bloco de 128 bits retornado pela cache
    assign cpu_rdata_o = (word_offset == 2'b00) ? data_from_cache[31:0]   :
                         (word_offset == 2'b01) ? data_from_cache[63:32]  :
                         (word_offset == 2'b10) ? data_from_cache[95:64]  :
                                                  data_from_cache[127:96];

    // ---- Instanciação do Array de Tags ----
    tag_array u_tag_array (
        .clk     (clk),
        .rst_n   (rst_n),
        .we_i    (tag_we),
        .index_i (cpu_index),
        .tag_i   (cpu_tag),
        .tag_o   (tag_from_cache),
        .valid_o (valid_from_cache)
    );

    // ---- Instanciação do Array de Dados ----
    data_array u_data_array (
        .clk       (clk),
        .we_i      (data_we),
        .word_en_i (data_word_mask),
        .index_i   (cpu_index),
        .data_i    (data_to_cache),
        .data_o    (data_from_cache)
    );

    // ---- Registrador de Estados da FSM (Síncrono) ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // ---- Lógica Combinacional da FSM (Próximo Estado e Saídas) ----
    always_comb begin
        // Valores padrão (Evita geração de Latches indesejados)
        next_state     = current_state;
        cpu_ready_o    = 1'b0;
        mem_req_o      = 1'b0;
        mem_write_o    = 1'b0;
        mem_addr_o     = cpu_addr_i;
        mem_wdata_o    = '0;
        
        tag_we         = 1'b0;
        data_we        = 1'b0;
        data_word_mask = 2'b00; // 00 indica operação no bloco completo (128 bits)
        data_to_cache  = '0;

        case (current_state)
            
            IDLE: begin
                if (cpu_req_i) begin
                    next_state = COMPARE_TAG;
                end
            end

            COMPARE_TAG: begin
                if (cache_hit) begin [cite: 66]
                    if (cpu_write_i) begin [cite: 70]
                        // --- HIT DE ESCRITA (Write-Through) ---
                        // 1. Atualiza a palavra correspondente na Cache
                        data_we        = 1'b1;
                        data_word_mask = word_offset; // Atualiza apenas a palavra modificada
                        data_to_cache  = {4{cpu_wdata_i}}; // Alinha o dado em todas as posições
                        
                        // 2. Repassa a escrita simultaneamente para a Memória Principal 
                        mem_req_o   = 1'b1;
                        mem_write_o = 1'b1;
                        mem_addr_o  = cpu_addr_i;
                        // Formata o barramento de escrita da memória baseado na palavra da CPU
                        mem_wdata_o = (word_offset == 2'b00) ? {96'b0, cpu_wdata_i} :
                                      (word_offset == 2'b01) ? {64'b0, cpu_wdata_i, 32'b0} :
                                      (word_offset == 2'b10) ? {32'b0, cpu_wdata_i, 64'b0} :
                                                               {cpu_wdata_i, 96'b0};

                        if (mem_ready_i) begin
                            cpu_ready_o = 1'b1;
                            next_state  = IDLE;
                        end
                    end else begin
                        // --- HIT DE LEITURA ---
                        cpu_ready_o = 1'b1;
                        next_state  = IDLE;
                    end
                end 
                else begin
                    // --- CACHE MISS --- [cite: 67, 71]
                    if (cpu_write_i) begin [cite: 72]
                        // --- MISS DE ESCRITA (No-Write-Allocate) ---
                        // Escreve direto na memória principal e não traz o bloco para a cache
                        mem_req_o   = 1'b1;
                        mem_write_o = 1'b1;
                        mem_addr_o  = cpu_addr_i;
                        mem_wdata_o = {4{cpu_wdata_i}}; 

                        if (mem_ready_i) begin
                            cpu_ready_o = 1'b1;
                            next_state  = IDLE;
                        end
                    end else begin
                        // --- MISS DE LEITURA ---
                        // Necessário buscar o bloco completo alinhado na memória principal [cite: 67]
                        next_state = ALLOCATE;
                    end
                end
            end
            
            ALLOCATE: begin [cite: 67]
                // Solicita leitura do bloco completo à memória principal (endereço alinhado ao bloco)
                mem_req_o   = 1'b1;
                mem_write_o = 1'b0;
                mem_addr_o  = {cpu_addr_i[ADDR_WIDTH-1:4], 4'b0000}; 

                if (mem_ready_i) begin
                    // Grava o bloco recebido da memória na cache
                    data_we        = 1'b1;
                    data_word_mask = 2'b00; // Grava os 128 bits completos
                    data_to_cache  = mem_rdata_i;
                    
                    // Atualiza a tabela de tags e ativa a validade da linha [cite: 68]
                    tag_we         = 1'b1;
                    
                    next_state     = RECOVER;
                end
            end

            RECOVER: begin
                // Período de estabilização de 1 ciclo de clock para leitura das novas tags/dados
                next_state = COMPARE_TAG;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule : cache_controller