package cache_pkg;

    // Definições do sistema de memória
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    // Configuração da Cache
    parameter BLOCK_SIZE = 4;          // 4 palavras (words) por bloco
    parameter CACHE_LINES = 64;        // 64 linhas na cache

    // ---- Matemática do Mapeamento Direto ----
    // Offset: 4 palavras * 4 bytes/palavra = 16 bytes por bloco. log2(16) = 4 bits
    parameter OFFSET_BITS = 4; 
    // Index: 64 linhas. log2(64) = 6 bits
    parameter INDEX_BITS = 6;  
    // Tag: O que sobra do endereço (32 - 6 - 4 = 22 bits)
    parameter TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;

    // Estados da FSM (Reduzidos para a política Write-Through)
    typedef enum logic [1:0] {
        IDLE,
        COMPARE_TAG,
        ALLOCATE,     // Traz o bloco da memória num Miss de Leitura
        RECOVER
    } cache_state_e;

endpackage : cache_pkg