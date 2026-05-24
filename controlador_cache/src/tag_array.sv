import cache_pkg::*;

module tag_array (
    input  logic                    clk,
    input  logic                    rst_n,
    
    input  logic                    we_i,       // Write Enable (Ativado ao carregar um bloco novo)
    input  logic [INDEX_BITS-1:0]   index_i,    // Índice da linha acessada
    input  logic [TAG_BITS-1:0]     tag_i,      // Tag a ser gravada no Miss
    
    output logic [TAG_BITS-1:0]     tag_o,      // Tag lida da cache
    output logic                    valid_o     // Bit de validade da linha
);

    // Estrutura de dados interna para a memória de Tags
    typedef struct packed {
        logic valid;
        logic [TAG_BITS-1:0] tag;
    } tag_line_t;

    // A memória RAM real (64 posições)
    tag_line_t tag_mem [0:CACHE_LINES-1];

    // Lógica de Leitura (Assíncrona para facilitar a comparação no mesmo ciclo)
    assign tag_o   = tag_mem[index_i].tag;
    assign valid_o = tag_mem[index_i].valid;

    // Lógica de Escrita e Reset (Síncrona)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Invalida toda a cache no reset
            for (int i = 0; i < CACHE_LINES; i++) begin
                tag_mem[i].valid <= 1'b0;
                tag_mem[i].tag   <= '0;
            end
        end else if (we_i) begin
            // Grava a nova tag e marca como válida ao trazer o bloco da memória
            tag_mem[index_i].valid <= 1'b1;
            tag_mem[index_i].tag   <= tag_i;
        end
    end

endmodule : tag_array